#!/usr/bin/env bash
# Confere a validacao de IE do GEBAN (src/GEBDFE_IE.prw) contra a implementacao
# de referencia gammasoft/ie (JavaScript), numero a numero. Uso:
#   T_GEBDFE_IE.sh /caminho/ie.js      (baixe de github.com/gammasoft/ie)
# Excecao conhecida da referencia: MT com 11 digitos (ela exige 9 na conta
# trivial e recusa todos); o GEBAN segue o SINTEGRA (11 digitos, ex. 0013000001-9).
set -uo pipefail
cd "$(dirname "$0")"
REF=${1:?informe o caminho do ie.js de referencia}
mkdir -p ../.out/local
node - "$REF" > ../.out/local/ie_vetores.txt <<'JSEOF'
const v = require(process.argv[2]);
let seed = 12345; const rnd = () => (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648;
const dig = n => Array.from({length: n}, () => Math.floor(rnd() * 10)).join('');
const casos = {AC:[[13,'01',2]], AL:[[9,'24',1]], AP:[[9,'03',1],[9,'0301',1],[9,'0302',1]], AM:[[9,'',1]], BA:[[8,'',2],[9,'',2],[8,'6',2],[9,'06',2]],
  CE:[[9,'06',1]], DF:[[13,'07',2]], ES:[[9,'',1]], GO:[[9,'10',1],[9,'11',1],[9,'15',1],[9,'101',1]], MA:[[9,'12',1]], MG:[[13,'',2]],
  MS:[[9,'28',1]], MT:[[9,'',1]], PA:[[9,'15',1]], PB:[[9,'',1]], PE:[[9,'',2],[14,'',2]], PI:[[9,'',1]], PR:[[10,'',2]], RJ:[[8,'',1]],
  RN:[[9,'20',1],[10,'20',1]], RO:[[9,'',1],[14,'',1]], RR:[[9,'24',1]], RS:[[10,'',1]], SC:[[9,'',1]], SE:[[9,'',1]],
  SP:[[12,'',1],[12,'',3]], TO:[[9,'',1],[11,'2901',1],[11,'2903',1]]};
for (const uf in casos) for (const [tam, pre, nfim] of casos[uf]) for (let b = 0; b < 40; b++) {
  const corpo = pre + dig(tam - pre.length - nfim);
  for (let f = 0; f < Math.pow(10, nfim); f++) {
    const ie = corpo + String(f).padStart(nfim, '0');
    console.log(uf + '|' + ie + '|' + (v(ie, uf) ? 1 : 0));
  }
}
JSEOF
echo "  vetores: $(wc -l < ../.out/local/ie_vetores.txt) (validos: $(grep -c '|1$' ../.out/local/ie_vetores.txt))"
advplc run T_GEBDFE_IE.prw 2>&1 | tail -35
