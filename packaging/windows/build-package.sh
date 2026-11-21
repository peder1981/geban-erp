#!/usr/bin/env bash
# Monta o pacote Windows all-in-one do GEBAN e gera geban-setup.exe (NSIS).
#
# Pré-requisitos: Go, makensis, unzip, curl.
# Variáveis:
#   GEBAN_SRC   raiz do geban-erp        (default: ../../.. a partir daqui)
#   ADVPP_SRC   checkout do repo AdvPP   (default: ~/Projetos/AdvPP)
#   PG_ZIP      zip de binários PostgreSQL Windows EDB
#               (default: baixa postgresql-16.10-1-windows-x64-binaries.zip)
#
# Saída: dist/geban-setup.exe + dist/payload/ (para inspeção)
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
GEBAN_SRC=${GEBAN_SRC:-$(cd "$HERE/../.." && pwd)}
ADVPP_SRC=${ADVPP_SRC:-$HOME/Projetos/AdvPP}
WORK=${WORK:-/tmp/geban-pkg}
PG_ZIP=${PG_ZIP:-$WORK/pgsql-binaries.zip}
PG_URL=${PG_URL:-https://get.enterprisedb.com/postgresql/postgresql-16.10-1-windows-x64-binaries.zip}
DIST="$HERE/dist"
PAYLOAD="$DIST/payload"

log() { echo "== $*"; }

log "1/6 payload"
rm -rf "$PAYLOAD"; mkdir -p "$PAYLOAD"
cp -a "$GEBAN_SRC/src" "$PAYLOAD/src"
cp -a "$GEBAN_SRC/public" "$PAYLOAD/public"
mkdir -p "$PAYLOAD/periferico"
cp "$GEBAN_SRC/periferico/periferico_service.py" "$GEBAN_SRC/periferico/requirements.txt" "$PAYLOAD/periferico/" 2>/dev/null || true

log "2/6 advplc.exe (Windows)"
if [ -n "${ADVPLC_WIN:-}" ]; then
    cp "$ADVPLC_WIN" "$PAYLOAD/advplc.exe"
else
    # O GEBAN exige AdvPP >= 4.8.4 (Nil como "", passagem por referencia @var).
    ADVPP_VER=$(cd "$ADVPP_SRC" && git describe --tags --abbrev=0 --match 'v[0-9]*')
    log "    AdvPP $ADVPP_VER"
    (cd "$ADVPP_SRC" && GOOS=windows GOARCH=amd64 CGO_ENABLED=0 \
        go build -trimpath -ldflags "-s -w -X main.version=$ADVPP_VER" \
        -o "$PAYLOAD/advplc.exe" ./cmd/advplc)
fi

log "3/6 geban-launcher.exe (Windows)"
(cd "$HERE/launcher" && GOOS=windows GOARCH=amd64 CGO_ENABLED=0 \
    go build -trimpath -ldflags "-s -w" -o "$PAYLOAD/geban-launcher.exe" .)

log "4/6 PostgreSQL embarcado"
if [ ! -f "$PG_ZIP" ]; then
    mkdir -p "$WORK"
    curl -fL --retry 3 -o "$PG_ZIP" "$PG_URL"
fi
mkdir -p "$WORK/pg-extract"
unzip -q -o "$PG_ZIP" "pgsql/bin/*" "pgsql/lib/*" "pgsql/share/*" -d "$WORK/pg-extract"
mkdir -p "$PAYLOAD/pg"
cp -a "$WORK/pg-extract/pgsql/." "$PAYLOAD/pg/"
# Os binários EDB exigem o VC++ Runtime, que NÃO vem no zip nem no
# Windows limpo — sem estas DLLs initdb/pg_ctl falham com 0xc0000135.
# Vendored em redist/vc (Microsoft Visual C++ 2015-2022 Redistributable,
# redistribuição permitida pela licença da Microsoft).
cp "$HERE/redist/vc/"*.dll "$PAYLOAD/pg/bin/"

log "5/6 verificações do payload"
for f in advplc.exe geban-launcher.exe src/GEBTUI.prw src/GEBWEB.prw src/GEBSCHJOB.prw \
         public/pdv.html pg/bin/initdb.exe pg/bin/pg_ctl.exe pg/bin/psql.exe \
         pg/bin/vcruntime140.dll pg/bin/msvcp140.dll pg/bin/vcruntime140_1.dll; do
    [ -f "$PAYLOAD/$f" ] || { echo "FALTA: $f"; exit 1; }
done
du -sh "$PAYLOAD"

log "6/6 instalador NSIS"
mkdir -p "$DIST"
# o payload já está em $DIST/payload — makensis resolve caminhos
# relativos ao diretório do script
cp "$HERE/geban.nsi" "$DIST/geban.nsi"
(cd "$DIST" && makensis geban.nsi)
rm -f "$DIST/geban.nsi"

echo
echo "PRONTO: $DIST/geban-setup.exe"
ls -lh "$DIST/geban-setup.exe"
