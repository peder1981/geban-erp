#!/usr/bin/env bash
# Funcao chamada que nao existe: o "advplc check" nao valida simbolos, entao o erro
# so' aparece ao executar aquela linha ("unknown function"). Ja' passou para producao
# assim: Today() na abertura de caixa do PDV, GEBSECRENDE no monitor; e, em
# 2026-11-21, um patch apagou TUICarrega e a interface parava logo apos o login.
# Junta as chamadas Nome( de src/, tira as funcoes definidas em src/ e pergunta ao
# proprio advplc se cada nome restante e' nativo. Sobrou algum: reprova.
#   ADVPLC=/caminho/advplc tests/local/T_LOCAL_FUNCOES.sh   (padrao: advplc do PATH)
cd "$(dirname "$0")/../.."
ADVPLC=${ADVPLC:-advplc}
command -v "$ADVPLC" > /dev/null || { echo "T_LOCAL_FUNCOES FAIL (advplc nao encontrado: defina ADVPLC)"; exit 1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
python3 - src > "$TMP/cand" <<'EOF'
import re, sys, glob
src = {f: open(f, encoding='cp1252').read() for f in glob.glob(sys.argv[1] + '/*.prw')}
defs = set()
for s in src.values():
    defs |= {m.upper() for m in re.findall(r'(?im)^\s*(?:user\s+|static\s+)?function\s+(\w+)', s)}
kw = {'IF', 'ELSEIF', 'WHILE', 'RETURN', 'FOR', 'CASE', 'AND', 'OR', 'NOT', 'LOCAL', 'PRIVATE'}
usos = {}
for f, s in src.items():
    s = re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group(0).count('\n'), s, flags=re.S)
    for n, linha in enumerate(s.split('\n'), 1):
        linha = re.sub(r'"[^"]*"|\'[^\']*\'', '""', re.sub(r'//.*', '', linha))
        for m in re.finditer(r'(?<![\w:.])([A-Za-z_]\w*)\s*\(', linha):
            nome = m.group(1).upper()
            base = nome[2:] if nome.startswith('U_') else nome
            if nome in kw or nome in defs or base in defs:
                continue
            usos.setdefault(nome, f'{f}:{n}')
for nome, onde in sorted(usos.items()):
    print(nome, onde)
EOF
falhas=0
while read -r nome onde; do
    printf 'User Function P()\n    Local x := %s()\nReturn\n' "$nome" > "$TMP/p.prw"
    if timeout 10 "$ADVPLC" run "$TMP/p.prw" 2>&1 | grep -qi 'unknown function'; then
        echo "  funcao inexistente: $nome ($onde)"
        falhas=$((falhas + 1))
    fi
done < "$TMP/cand"
if [ "$falhas" -gt 0 ]; then echo "T_LOCAL_FUNCOES FAIL"; exit 1; fi
echo "T_LOCAL_FUNCOES PASS"
