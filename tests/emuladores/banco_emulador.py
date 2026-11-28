#!/usr/bin/env python3
"""Emulador local de banco CNAB240 para demonstracao do GEBAN.

  POST /cnab/remessa   arquivo texto CNAB240; retorna {ok, boletos}
  GET  /cnab/retorno   arquivo CNAB240: vencidos liquidados (06), invalidos (02)
  GET  /boleto/{nn}    linha_digitavel, codigo_barras, valor, vencimento, status
  GET  /health         {ok, boletos} (quantidade acumulada)

Uso: python3 banco_emulador.py [porta] (padrao 18767, so' em 127.0.0.1)
     python3 banco_emulador.py --selfcheck

Teto de simplificacao: interpreta somente segmento P da remessa (Q ignorado),
com NN 38-57, vencimento 78-85 DDMMAAAA e centavos 86-100. Retorno usa T/U
minimos exigidos por BCORet240/GEBBCORET, nao P: NN 38-57 e ocorrencia 16-17
no T; pago 78-92 e data 138-145 no U. Preserva modelos da remessa, muda
indicador de retorno/operacao e recalcula contagens. Aceita somente entrada
01, NN numerico, data valida e valor positivo; demais instrucoes geram 02
(conforme contrato da demo, nao uma tabela bancaria completa).
Upgrade path: segmentos Q/T/U completos e homologacao por banco.
Estado apenas em memoria; cada retorno consome os eventos disponiveis, sem
reliquidar boletos. Reenvio de NN conhecido nao altera o boleto existente.
Codigo de barras (44 digitos, prefixo 44) e linha digitavel (47 digitos) sao
identificadores sinteticos SEM validade bancaria, sem calculo de DVs.
Nao usar para pagamentos reais; sem autenticacao, apenas ambiente local.
"""
import json
import sys
import threading
from datetime import date, datetime
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import unquote, urlparse
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def campo(linha, inicio, fim, valor):
    """Substitui colunas inclusivas, contadas a partir de 1."""
    assert len(valor) == fim - inicio + 1
    return linha[:inicio - 1] + valor + linha[fim:]


def ler_remessa(texto):
    linhas = texto.splitlines()
    if (len(linhas) < 4 or any(len(l) != 240 for l in linhas)
            or linhas[0][7] != '0' or linhas[-1][7] != '9'
            or not any(l[7] == '1' for l in linhas)):
        raise ValueError('esperado CNAB240 com header 0, lote 1 e trailer 9')
    boletos = []
    lote = None
    for linha in linhas[1:-1]:
        if linha[7] == '1':
            lote = linha
        elif linha[7] == '3' and linha[13] == 'P':
            if lote is None or lote[3:7] != linha[3:7]:
                raise ValueError('segmento P sem header do lote correspondente')
            nn = linha[37:57].strip()
            vencimento = ''
            centavos = 0
            valido = bool(nn) and nn.isascii() and nn.isdigit() and linha[15:17] == '01'
            try:
                data = linha[77:85]
                if not data.isascii() or not data.isdigit():
                    raise ValueError('data invalida')
                vencimento = datetime.strptime(data, '%d%m%Y').strftime('%Y%m%d')
                valor = linha[85:100]
                if not valor.isascii() or not valor.isdigit():
                    raise ValueError('valor invalido')
                centavos = int(valor)
                valido = valido and centavos > 0
            except ValueError:
                valido = False
            boletos.append({'nn': nn, 'centavos': centavos, 'vencimento': vencimento,
                            'status': 'REMETIDO' if valido else 'REJEITADO',
                            'pendente': True, 'linha': linha, 'lote': lote,
                            'header': linhas[0], 'trailer': linhas[-1]})
    return boletos


def gerar_retorno(boletos):
    hoje = date.today().strftime('%Y%m%d')
    eventos = [b for b in boletos.values() if b['pendente'] and
               (b['status'] == 'REJEITADO' or b['vencimento'] <= hoje)]
    modelos = list(boletos.values())
    header = modelos[-1]['header'] if modelos else '00000000'.ljust(240)
    trailer = modelos[-1]['trailer'] if modelos else '00099999'.ljust(240)
    linhas = [campo(header, 143, 143, '2')]
    # Um lote por evento evita misturar contas/modelos de remessas diferentes.
    for numero, boleto in enumerate(eventos, 1):
        lote = '%04d' % numero
        linhas.append(campo(campo(boleto['lote'], 4, 7, lote), 9, 9, 'T'))
        ocorrencia = '02' if boleto['status'] == 'REJEITADO' else '06'
        t = campo(boleto['linha'], 4, 7, lote)
        t = campo(campo(t, 9, 13, '00001'), 14, 14, 'T')
        t = campo(t, 16, 17, ocorrencia)
        u = t[:8] + '00002U ' + ocorrencia + '0' * 223
        u = campo(u, 78, 92, '%015d' % (boleto['centavos'] if ocorrencia == '06' else 0))
        u = campo(u, 138, 145, date.today().strftime('%d%m%Y'))
        fim_lote = t[:7] + '5' + ' ' * 232
        fim_lote = campo(fim_lote, 18, 23, '000004')
        linhas.extend([t, u, fim_lote])
    trailer = campo(trailer, 18, 23, '%06d' % len(eventos))
    linhas.append(campo(trailer, 24, 29, '%06d' % (len(linhas) + 1)))
    for boleto in eventos:
        boleto['pendente'] = False
        if boleto['status'] != 'REJEITADO':
            boleto['status'] = 'LIQUIDADO'
    return '\r\n'.join(linhas) + '\r\n'


class Handler(BaseHTTPRequestHandler):
    def _responde(self, codigo, corpo, tipo='application/json'):
        dados = json.dumps(corpo).encode() if tipo == 'application/json' else corpo.encode('latin-1')
        self.send_response(codigo)
        self.send_header('Content-Type', tipo)
        self.send_header('Content-Length', str(len(dados)))
        self.end_headers()
        self.wfile.write(dados)

    def do_POST(self):
        if urlparse(self.path).path != '/cnab/remessa':
            return self._responde(404, {'ok': False, 'erro': 'recurso inexistente'})
        try:
            tamanho = int(self.headers.get('Content-Length', '0'))
            if not 0 < tamanho <= 4 * 1024 * 1024:
                raise ValueError('remessa deve ter entre 1 byte e 4 MiB')
            boletos = ler_remessa(self.rfile.read(tamanho).decode('latin-1'))
        except ValueError as erro:
            return self._responde(400, {'ok': False, 'erro': str(erro)})
        for boleto in boletos:
            self.server.boletos.setdefault(boleto['nn'], boleto)
        self._responde(200, {'ok': True, 'boletos': len(boletos)})

    def do_GET(self):
        caminho = urlparse(self.path).path
        if caminho == '/health':
            return self._responde(200, {'ok': True, 'boletos': len(self.server.boletos)})
        if caminho == '/cnab/retorno':
            return self._responde(200, gerar_retorno(self.server.boletos), 'text/plain; charset=iso-8859-1')
        if caminho.startswith('/boleto/'):
            boleto = self.server.boletos.get(unquote(caminho[len('/boleto/'):]))
            if boleto is not None:
                digitos = ''.join(c for c in boleto['nn'] if c in '0123456789')
                barras = '44' + digitos.zfill(20)[-20:] + ('%022d' % boleto['centavos'])
                return self._responde(200, {'linha_digitavel': barras + '000',
                                          'codigo_barras': barras,
                                          'valor': boleto['centavos'] / 100,
                                          'vencimento': boleto['vencimento'],
                                          'status': boleto['status']})
        self._responde(404, {'ok': False, 'erro': 'recurso inexistente'})

    def log_message(self, *args):
        pass


def servidor(porta):
    httpd = HTTPServer(('127.0.0.1', porta), Handler)
    httpd.boletos = {}
    return httpd


def selfcheck():
    httpd = servidor(0)
    thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    thread.start()
    base = 'http://127.0.0.1:%d' % httpd.server_port

    def pedido(caminho, dados=None):
        with urlopen(Request(base + caminho, data=dados), timeout=5) as resposta:
            return resposta.read()

    try:
        header = '00100000' + ' ' * 232
        lote = '00100011R01' + ' ' * 229
        linhas = [header, lote]
        for numero in (1, 2):
            p = '00100013' + '%05d' % numero + 'P 01' + ' ' * 223
            p = campo(p, 38, 57, ('%010d' % numero).ljust(20))
            p = campo(p, 78, 85, '01012000')
            linhas.append(campo(p, 86, 100, '%015d' % (numero * 12345)))
        linhas.extend(['00100015' + ' ' * 232, '00199999' + ' ' * 232])
        remessa = ('\r\n'.join(linhas) + '\r\n').encode()
        assert json.loads(pedido('/cnab/remessa', remessa)) == {'ok': True, 'boletos': 2}
        retorno = pedido('/cnab/retorno').decode().splitlines()
        assert all(len(l) == 240 for l in retorno)
        t = [l for l in retorno if l[7] == '3' and l[13] == 'T']
        u = [l for l in retorno if l[7] == '3' and l[13] == 'U']
        assert len(t) == len(u) == 2
        assert [l[37:57].strip() for l in t] == ['0000000001', '0000000002']
        assert all(l[15:17] == '06' for l in t)
        assert [int(l[77:92]) for l in u] == [12345, 24690]
        assert all(l[137:145] == date.today().strftime('%d%m%Y') for l in u)
        assert all(int(l[17:47]) == 0 for l in u)  # juros e desconto
        boleto = json.loads(pedido('/boleto/0000000001'))
        assert boleto['status'] == 'LIQUIDADO' and boleto['valor'] == 123.45
        assert boleto['vencimento'] == '20000101'
        assert len(boleto['codigo_barras']) == 44 and len(boleto['linha_digitavel']) == 47
        assert json.loads(pedido('/health')) == {'ok': True, 'boletos': 2}
        assert b'00001T' not in pedido('/cnab/retorno')
        pedido('/cnab/remessa', remessa)  # reenvio nao reabre liquidacao
        assert b'00001T' not in pedido('/cnab/retorno')
        adicionais = []
        for numero, vencimento, movimento in ((3, '31129999', '01'),
                                               (4, '31022000', '01'),
                                               (5, '01012000', '99')):
            p = campo(linhas[2], 38, 57, ('%010d' % numero).ljust(20))
            p = campo(campo(p, 78, 85, vencimento), 16, 17, movimento)
            adicionais.append(p)
        arquivo = '\r\n'.join([header, lote] + adicionais + linhas[-2:]).encode()
        assert json.loads(pedido('/cnab/remessa', arquivo))['boletos'] == 3
        rejeitados = pedido('/cnab/retorno').decode().splitlines()
        t = [l for l in rejeitados if l[7] == '3' and l[13] == 'T']
        assert len(t) == 2 and all(l[15:17] == '02' for l in t)
        assert json.loads(pedido('/boleto/0000000003'))['status'] == 'REMETIDO'
        assert json.loads(pedido('/boleto/0000000004'))['status'] == 'REJEITADO'
        for caminho, dados, esperado in (('/cnab/remessa', b'invalido', 400),
                                         ('/boleto/inexistente', None, 404)):
            try:
                pedido(caminho, dados)
            except HTTPError as erro:
                assert erro.code == esperado
                erro.close()
            else:
                raise AssertionError('esperado HTTP %d' % esperado)
        print('PASS: 2 liquidacoes T/U; rejeicao, futuro, reenvio e erros HTTP')
    finally:
        httpd.shutdown()
        thread.join(timeout=5)
        httpd.server_close()


if __name__ == '__main__':
    if sys.argv[1:] == ['--selfcheck']:
        selfcheck()
    else:
        with servidor(int(sys.argv[1]) if len(sys.argv) > 1 else 18767) as httpd:
            print('Banco emulador em http://127.0.0.1:%d' % httpd.server_port, flush=True)
            try:
                httpd.serve_forever()
            except KeyboardInterrupt:
                pass
