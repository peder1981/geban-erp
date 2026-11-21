#!/usr/bin/env python3
"""Gera a secao 8 de docs/05-referencia-tecnica.md (User Functions por fonte).

Uso: python3 scripts/doc-funcoes.py > /tmp/secao8.md
Assinatura lida da declaracao; proposito = 1a linha do Protheus.doc da funcao
(ou o comentario // logo acima). Fonte sem grupo conhecido cai em "OUTROS".
"""
import os
import re
import sys

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# Grupo de cada fonte, pelo prefixo (o mais longo que casar vence).
GRUPOS = [
    ("GEB_NUCLEO", ["GENUC_", "GEBDB_", "GEBFIL_", "GEBUNI_", "GEBSCH", "GEBAUD", "GEBMON"]),
    ("GEB_FISCAL", ["GEBFIS_", "GEBSN", "GEBRET"]),
    ("GEB_DFE (documentos eletronicos)", ["GEBDFE"]),
    ("GEB_DERRAMA", ["GEBDER_"]),
    ("GEB_ESTOQ_VENDA", ["GEBV_"]),
    ("GEB_CONTABIL", ["GEBCTB_"]),
    ("GEB_FIN", ["GEBFIN_"]),
    ("GEB_COM", ["GEBCOM_"]),
    ("GEB_BACKOFFICE", ["GEBBO", "GEBEST", "GEBFAT", "GEBFNX", "GEBCPX", "GEBCTX", "GEBBCO", "GEBDER_FIN"]),
    ("GEB_LOJA (frente de loja e PDV)", ["GEBLOJ", "GEBTEF", "GEBPDV_", "GEBPERIF_"]),
    ("GEB_EXPANSAO", ["GEBEXP_"]),
    ("GEB_SEGURANCA", ["GEBSEC_"]),
    ("GEB_TUI (interface PO-UI)", ["GEBTUI"]),
    ("GEB_REST_WEB", ["GEBREST", "GEBWEB"]),
]


def grupo(arq):
    melhor, tam = "OUTROS", 0
    for nome, prefs in GRUPOS:
        for p in prefs:
            if arq.upper().startswith(p) and len(p) > tam:
                melhor, tam = nome, len(p)
    return melhor


def proposito(txt, pos, nome):
    antes = txt[:pos]
    doc = antes.rfind("/*/{Protheus.doc}")
    if doc != -1 and antes.find("/*/", doc + 3) != -1:
        bloco = antes[doc:antes.find("/*/", doc + 3)]
        # so' vale se o bloco e' desta funcao e nao ha outra Function no meio
        if nome.upper() in bloco.upper().split("\n")[0] and "Function " not in antes[doc:]:
            desc = []
            for l in bloco.split("\n")[1:]:
                l = l.strip()
                if l.startswith("@") or (not l and desc):
                    break
                if l:
                    desc.append(l)
            texto = " ".join(desc)
            fim = texto.find(". ")
            if fim != -1:
                texto = texto[:fim + 1]
            if len(texto) > 180:
                texto = texto[:177].rsplit(" ", 1)[0] + "..."
            if texto:
                return texto
    linha_ant = antes.rstrip("\n").split("\n")[-1].strip()
    if linha_ant.startswith("//"):
        return linha_ant[2:].strip()
    return ""


def main():
    fontes = sorted(f for f in os.listdir(os.path.join(RAIZ, "src")) if f.lower().endswith(".prw"))
    por_grupo, total = {}, 0
    for arq in fontes:
        txt = open(os.path.join(RAIZ, "src", arq), encoding="cp1252").read()
        funcs = []
        for m in re.finditer(r"(?im)^User Function (\w+)\s*\(([^)]*)\)", txt):
            nome, params = m.group(1), re.sub(r"\s+", " ", m.group(2)).strip()
            prop = proposito(txt, m.start(), nome).replace("|", "/") or "—"
            funcs.append((nome, f"{nome}({params})", prop))
        if funcs:
            por_grupo.setdefault(grupo(arq), []).append((arq, funcs))
            total += len(funcs)
    out = [f"## 8. Referência completa de funções por arquivo ({total} funções)", "",
           "Gerada por `scripts/doc-funcoes.py` a partir dos fontes: assinatura exata da",
           "declaração e propósito da primeira linha do `Protheus.doc` (ou do comentário",
           "logo acima). Só `User Function` (as `Static Function` são internas ao fonte).", ""]
    ordem = [g for g, _ in GRUPOS] + ["OUTROS"]
    for g in ordem:
        if g not in por_grupo:
            continue
        out += [f"### {g}", ""]
        for arq, funcs in por_grupo[g]:
            out += [f"**`src/{arq}`** — {len(funcs)} funções", "", "| Função | Assinatura | Propósito |", "|---|---|---|"]
            out += [f"| `{n}` | `{a}` | {p} |" for n, a, p in funcs]
            out.append("")
    sys.stdout.write("\n".join(out))


if __name__ == "__main__":
    main()
