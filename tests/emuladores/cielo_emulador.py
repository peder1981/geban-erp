#!/usr/bin/env python3
"""Emulador local da API Cielo e-Commerce 3.0 (so' o que o TEF do GEBAN usa).

Imita a sandbox da Cielo (apisandbox.cieloecommerce.cielo.com.br) para testar
sem internet nem credenciais:
  POST /1/sales                      venda de cartao (Capture=false = pre-autorizacao)
  PUT  /1/sales/{PaymentId}/capture  captura (confirmacao)
  PUT  /1/sales/{PaymentId}/void     cancelamento/desfazimento (?amount= opcional)
  GET  /1/sales/{PaymentId}          consulta
Exige os cabecalhos MerchantId e MerchantKey (qualquer valor nao vazio).
Resultado pelo ultimo digito do cartao, como na sandbox:
  0, 1, 4 = autorizado (ReturnCode 4); 2 = nao autorizado (05); 3 = cartao
  expirado (57); 5 = bloqueado (78); 6 = time out (99); 7 = cancelado (77);
  8 = problema com o cartao (70); 9 = autorizado aqui (na sandbox e' aleatorio).
Status Cielo: 1 Authorized, 2 PaymentConfirmed, 3 Denied, 10 Voided, 11 Refunded.

Uso: python3 cielo_emulador.py [porta]   (padrao 18765, so' em 127.0.0.1)
"""
import json
import sys
import uuid
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

RESULTADO = {
    "0": (1, "4", "Operation Successful"), "1": (1, "4", "Operation Successful"),
    "4": (1, "4", "Operation Successful"), "9": (1, "4", "Operation Successful"),
    "2": (3, "05", "Not Authorized"), "3": (3, "57", "Card Expired"),
    "5": (3, "78", "Blocked Card"), "6": (3, "99", "Time Out"),
    "7": (3, "77", "Card Canceled"), "8": (3, "70", "Problems with Credit Card"),
}
VENDAS = {}
SEQ = [0]


class Handler(BaseHTTPRequestHandler):
    def _responde(self, codigo, corpo):
        dados = json.dumps(corpo).encode()
        self.send_response(codigo)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(dados)))
        self.end_headers()
        self.wfile.write(dados)

    def _autenticado(self):
        if not self.headers.get("MerchantId") or not self.headers.get("MerchantKey"):
            self._responde(401, [{"Code": 129, "Message": "MerchantId is required"}])
            return False
        return True

    def do_POST(self):
        if not self._autenticado():
            return
        if urlparse(self.path).path.rstrip("/") != "/1/sales":
            return self._responde(404, [{"Code": 404, "Message": "Resource not found"}])
        tam = int(self.headers.get("Content-Length", "0"))
        try:
            pedido = json.loads(self.rfile.read(tam) or b"{}")
            pag = pedido["Payment"]
            cartao = str(pag["CreditCard"]["CardNumber"])
            valor = int(pag["Amount"])
        except (ValueError, KeyError, TypeError):
            return self._responde(400, [{"Code": 126, "Message": "Invalid request"}])
        status, codigo, msg = RESULTADO.get(cartao[-1:], RESULTADO["2"])
        SEQ[0] += 1
        venda = {
            "PaymentId": str(uuid.uuid4()), "Type": pag.get("Type", "CreditCard"), "Amount": valor,
            "Installments": int(pag.get("Installments", 1)), "Capture": bool(pag.get("Capture", False)),
            "Status": status, "ReturnCode": codigo, "ReturnMessage": msg,
            "ProofOfSale": "%06d" % SEQ[0], "Tid": "%020d" % SEQ[0],
            "AuthorizationCode": ("%06d" % (SEQ[0] * 7919 % 999999)) if status == 1 else "",
            "CreditCard": {"CardNumber": cartao[:6] + "******" + cartao[-4:], "Brand": pag["CreditCard"].get("Brand", "Visa")},
        }
        if status == 1 and venda["Capture"]:
            venda["Status"] = 2
        VENDAS[venda["PaymentId"]] = venda
        self._responde(201, {"MerchantOrderId": pedido.get("MerchantOrderId", ""), "Payment": venda})

    def do_PUT(self):
        if not self._autenticado():
            return
        url = urlparse(self.path)
        partes = url.path.strip("/").split("/")
        if len(partes) != 4 or partes[:2] != ["1", "sales"] or partes[3] not in ("capture", "void"):
            return self._responde(404, [{"Code": 404, "Message": "Resource not found"}])
        venda = VENDAS.get(partes[2])
        if venda is None:
            return self._responde(404, [{"Code": 307, "Message": "Transaction not found"}])
        if partes[3] == "capture":
            if venda["Status"] != 1:
                return self._responde(400, [{"Code": 308, "Message": "Transaction not available to capture"}])
            venda.update(Status=2, ReturnCode="6", ReturnMessage="Operation Successful")
        else:
            if venda["Status"] not in (1, 2):
                return self._responde(400, [{"Code": 309, "Message": "Transaction not available to void"}])
            parcial = parse_qs(url.query).get("amount")
            if parcial and int(parcial[0]) > venda["Amount"]:
                return self._responde(400, [{"Code": 310, "Message": "Amount greater than authorized"}])
            venda.update(Status=10 if venda["Status"] == 1 else 11, ReturnCode="9", ReturnMessage="Operation Successful")
        self._responde(200, {k: venda[k] for k in ("Status", "ReturnCode", "ReturnMessage", "ProofOfSale", "Tid", "AuthorizationCode")})

    def do_GET(self):
        if not self._autenticado():
            return
        partes = urlparse(self.path).path.strip("/").split("/")
        venda = VENDAS.get(partes[2]) if len(partes) == 3 and partes[:2] == ["1", "sales"] else None
        if venda is None:
            return self._responde(404, [{"Code": 307, "Message": "Transaction not found"}])
        self._responde(200, {"Payment": venda})

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    porta = int(sys.argv[1]) if len(sys.argv) > 1 else 18765
    HTTPServer(("127.0.0.1", porta), Handler).serve_forever()
