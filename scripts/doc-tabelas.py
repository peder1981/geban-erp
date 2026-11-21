#!/usr/bin/env python3
"""Gera a secao 4 de docs/05-referencia-tecnica.md (inventario de tabelas).

Uso: python3 scripts/doc-tabelas.py > /tmp/secao4.md
Le as definicoes direto dos fontes: CREATE TABLE literal, BOTAB(cTab, cCols)
(que acrescenta TAB_FILIAL), SNTab (DDL do Simples) e ALTER TABLE ... ADD
COLUMN. A descricao vem da secao 4 atual do documento (curada a mao); tabela
nova sem descricao sai so' com as colunas.
"""
import os
import re
import sys

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from importlib import import_module  # noqa: E402

grupo = import_module("doc-funcoes").grupo
TECNICAS = {"R_E_C_N_O_", "D_E_L_E_T_"}


def junta(txt):
    # "abc" + ;\n   "def"  ->  "abcdef" (concatenacao de literais em varias linhas)
    return re.sub(r'"\s*\+\s*;?\s*\n\s*"', "", re.sub(r'"\s*\+\s*"', "", txt))


def colunas(ddl):
    out, nivel, atual = [], 0, ""
    for ch in ddl:
        if ch == "(":
            nivel += 1
        elif ch == ")":
            nivel -= 1
        if ch == "," and nivel == 0:
            out.append(atual); atual = ""
        else:
            atual += ch
    out.append(atual)
    nomes = []
    for c in out:
        n = c.strip().split(" ")[0].strip().upper() if c.strip() else ""
        if n and n not in TECNICAS and n not in ("PRIMARY", "UNIQUE", "CONSTRAINT", "FOREIGN") and re.match(r"^[A-Z0-9_]+$", n):
            nomes.append(n)
    return nomes


def ler():
    tabs = {}
    for arq in sorted(os.listdir(os.path.join(RAIZ, "src"))):
        if not arq.lower().endswith(".prw"):
            continue
        txt = junta(open(os.path.join(RAIZ, "src", arq), encoding="cp1252").read())
        sn_id = 'CREATE TABLE %T (' if "SNTab(" in txt else None

        def poe(tab, cols):
            tab = tab.upper()
            t = tabs.setdefault(tab, {"arq": arq, "cols": []})
            for c in cols:
                if c not in t["cols"]:
                    t["cols"].append(c)

        for m in re.finditer(r'CREATE TABLE (?:IF NOT EXISTS )?([A-Za-z][A-Za-z0-9_]*) \((.*?)\)"', txt, re.S):
            if m.group(1) not in ("cTab",):
                poe(m.group(1), colunas(m.group(2)))
        for m in re.finditer(r'BOTAB\("([A-Z0-9_]+)", "([^"]*)"', txt):
            poe(m.group(1), [m.group(1) + "_FILIAL"] + colunas(m.group(2)))
        if sn_id:
            for m in re.finditer(r'SNTab\("([A-Z0-9_]+)", cId \+ "([^"]*)"', txt):
                poe(m.group(1), colunas(m.group(2).rstrip(")")))
        for m in re.finditer(r"ALTER TABLE ([A-Za-z0-9_]+) ADD COLUMN (?:IF NOT EXISTS )?([A-Za-z0-9_]+)", txt):
            if m.group(1).upper() in tabs or re.match(r"^[A-Z0-9_]+$", m.group(1)):
                poe(m.group(1), [m.group(2).upper()])
    return tabs


def curadas(doc):
    s = open(doc).read()
    a = s.index("\n## 4.")
    b = s.index("\n## 5.", a)
    desc = {}
    for linha in s[a:b].split("\n"):
        m = re.match(r"\| (`[^|]+`) \| ([^|]+) \| (.+) \|$", linha)
        if m:
            nomes = re.findall(r"`([A-Z0-9_]+)`", m.group(1))
            texto = m.group(3).strip()
            for n in nomes:
                desc[n] = (m.group(2).strip(), texto.split(":")[0] if ":" in texto else texto)
    return desc


def main():
    doc = os.path.join(RAIZ, "docs", "05-referencia-tecnica.md")
    tabs, desc = ler(), curadas(doc)
    out = [f"## 4. Inventário de tabelas ({len(tabs)} tabelas)", "",
           "Gerado por `scripts/doc-tabelas.py` a partir das definições nos fontes (`CREATE TABLE`,",
           "`BOTAB`, `SNTab` e `ALTER TABLE ... ADD COLUMN`). Toda tabela tem ainda `R_E_C_N_O_`",
           "(identidade) e `D_E_L_E_T_` (exclusão lógica). As do catálogo (`GE1`, `GE2*`, `SEC_*`)",
           "ficam no schema `public`; as demais, no schema de cada empresa.", "",
           "| Tabela | Módulo | Conteúdo | Colunas |", "|---|---|---|---|"]
    for t in sorted(tabs):
        mod, texto = desc.get(t, (grupo(tabs[t]["arq"]).split(" (")[0].replace("GEB_", "").title(), "—"))
        cols = ", ".join(f"`{c}`" for c in tabs[t]["cols"])
        out.append(f"| `{t}` | {mod} | {texto} | {cols} |")
    sys.stdout.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
