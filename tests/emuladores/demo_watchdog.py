#!/usr/bin/env python3
"""Watchdog do demo GEBAN (opcao B): sobe os emuladores sob demanda.

  GET /health   checagem somente-leitura: estado TCP de cada servico.
  GET /ensure   para cada servico fora do ar, dispara o start (systemd
                --user ou fallback Popen) e responde rapido (<3s): o
                spawn e' fire-and-forget, quem precisa esperar faz poll
                em /health (o `geban-demo.sh seed` ja faz isso).
  GET /         informacao basica.

Escuta em 127.0.0.1:18768 (so' localhost). Disparado pelo hook de login
da empresa 99 em src/GEBDEMO.prw (GEBWEB.prw/GEBTUI.prw, HttpQuote GET
/ensure, timeout ~2s) e pelo `geban-demo.sh seed`. A unit geban-demo-watchdog.service e'
a unica peca sempre-online do modo sob-demanda; as 4 units de emulador
ficam instaladas mas desabilitadas — o watchdog prefere
`systemctl --user start` (logs no journal) e cai para Popen com log em
~/.local/state/geban-demo/<nome>.log quando a unit nao existe/falha.

Teto de simplificacao (ponytail): "saudavel" = aceita conexao TCP na
porta; nao valida protocolo nem autenticacao. Upgrade: endpoints /health
reais por servico e readiness probe antes de reportar "up".
"""
import json
import os
import socket
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]          # tests/emuladores/../..
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "geban-demo"
PORT = 18768
TCP_TIMEOUT = 0.6          # checagem de porta: rapida, fire-and-forget
SYSTEMCTL_TIMEOUT = 15     # systemctl --user start pode demorar
ENSURE_WAIT = 1.8          # /ensure espera ate aqui por portas subirem
POLL_STEP = 0.25

# name -> dict(port, unit, argv, cwd, env_extra)
SERVICES = {
    "sefaz": {
        "port": 18766,
        "unit": "geban-emu-sefaz.service",
        "argv": [sys.executable, "tests/emuladores/sefaz_emulador.py"],
        "cwd": ROOT,
        "env": {"SEFAZ_SEED_NOTAS": "9"},
    },
    "cielo": {
        "port": 18765,
        "unit": "geban-emu-cielo.service",
        "argv": [sys.executable, "tests/emuladores/cielo_emulador.py"],
        "cwd": ROOT,
        "env": {},
    },
    "banco": {
        "port": 18767,
        "unit": "geban-emu-banco.service",
        "argv": [sys.executable, "tests/emuladores/banco_emulador.py"],
        "cwd": ROOT,
        "env": {},
    },
    "periferico": {
        "port": 9100,
        "unit": "geban-periferico.service",
        # WebSocket, nao HTTP — o teste e' so' TCP connect.
        "argv": [sys.executable, "periferico/periferico_service.py",
                 "--config", "periferico/config/perifericos.json"],
        "cwd": ROOT,
        "env": {},
    },
}

_lock = threading.Lock()          # serializa /ensure inteiro
_starting = set()                 # nomes com start em andamento (dedup)
_procs = {}                       # nome -> Popen do fallback (evita double-spawn)


def tcp_up(port):
    try:
        with socket.create_connection(("127.0.0.1", port), TCP_TIMEOUT):
            return True
    except OSError:
        return False


def _systemctl_start(unit):
    """True se o systemctl aceitou o start; False para cair no Popen."""
    try:
        r = subprocess.run(
            ["systemctl", "--user", "start", unit],
            timeout=SYSTEMCTL_TIMEOUT,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        return r.returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def _popen_start(name, svc):
    """Fallback sem systemd: processo destacado, log em STATE_DIR."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    log = open(STATE_DIR / (name + ".log"), "ab", buffering=0)
    env = dict(os.environ)
    env.update(svc["env"])
    proc = subprocess.Popen(
        svc["argv"], cwd=str(svc["cwd"]), env=env,
        stdout=log, stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL, start_new_session=True,
    )
    log.close()  # o filho ficou com o fd dup'd; nao vaza fd no watchdog
    _procs[name] = proc


def _start_one(name, svc):
    try:
        if not _systemctl_start(svc["unit"]):
            _popen_start(name, svc)
    except Exception:
        # Nunca deixa excecao matar a thread do watchdog.
        pass
    finally:
        with _lock:
            _starting.discard(name)


def _spawn(name, svc):
    """Dispara o start em background (dedup via _starting)."""
    with _lock:
        if name in _starting:
            return
        proc = _procs.get(name)
        if proc is not None and proc.poll() is None:
            return  # Popen anterior ainda subindo; nao duplica.
        _starting.add(name)
    threading.Thread(target=_start_one, args=(name, svc), daemon=True).start()


def _state(name, svc, spawn):
    port = svc["port"]
    if tcp_up(port):
        return {"name": name, "port": port, "state": "up", "via": "tcp"}
    if not spawn:
        return {"name": name, "port": port, "state": "down", "via": "tcp"}
    _spawn(name, svc)
    return {"name": name, "port": port, "state": "starting", "via": "spawn"}


def collect(spawn):
    out = [_state(n, s, spawn) for n, s in SERVICES.items()]
    if not spawn:
        return out
    # Espera curta: quem ja' bindou durante o spawn vira "up".
    deadline = time.monotonic() + ENSURE_WAIT
    while time.monotonic() < deadline:
        if all(x["state"] == "up" for x in out):
            break
        time.sleep(POLL_STEP)
        out = [{"name": x["name"], "port": x["port"],
                "state": "up" if tcp_up(x["port"]) else x["state"],
                "via": x.get("via", "tcp")} for x in out]
    return out


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _json(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/health":
            states = collect(spawn=False)
            self._json({"ok": all(x["state"] == "up" for x in states),
                        "services": states})
        elif path == "/ensure":
            # Sem lock externo: _spawn ja' deduplica via _starting/_procs.
            # (Lock nao-reentrante — segurar aqui deadlockaria o handler.)
            states = collect(spawn=True)
            self._json({"ok": True, "services": states})
        elif path in ("/", "/info"):
            self._json({"ok": True, "watchdog": "geban-demo", "port": PORT,
                        "services": {n: {"port": s["port"], "unit": s["unit"]}
                                     for n, s in SERVICES.items()}})
        else:
            self._json({"ok": False, "erro": "rota desconhecida"}, 404)

    def log_message(self, fmt, *args):
        sys.stderr.write("watchdog: " + fmt % args + "\n")


def main():
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    httpd = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    httpd.daemon_threads = True
    print("GEBAN demo watchdog em http://127.0.0.1:%d (/health /ensure)" % PORT, flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
