# 02 — Regras de Negócio do ERP GEBAN

> República das Bananias · vigente em 23/09/2026 · fontes: `documentacao interna`, planos `documentacao interna`, `src/*.prw`.
> Tom: bem-humorado, porém preciso. Se a piada e o código discordarem, o código vence — e a piada vai para a fila GE5.
> **Atualização multi-empresa + GUI:** expandiu-se de 7 para 9 módulos com `GEB_EXPANSAO` (multi-empresa) e `GEB_GUI` (interfaces).

---

## 1. A República das Bananias

O GEBAN é o ERP oficial da fictícia **República das Bananias**, terra onde a banana é moeda moral, o fisco ama carimbo e todo contribuinte sonha com o mesmo milagre: **emitir a nota certa e quitar a derrama sem multa**.

O MVP tem uma promessa só, escrita no design aprovado:

> **O MEI emite NF-e/NFS-e certo e quita a derrama sem multa.**

Tudo o mais — Mentor, fila offline, split, parcelamento, protesto, partida dobrada — existe para sustentar essa promessa quando a internet cai, o cliente pede fiado e o contador inventa um lançamento direto às 23h58.

Arquitetura em uma casca de banana: monolito modular AdvPL, Postgres com um schema por empresa (originalmente SQLite `geban.db`), interface web PO-UI (`src/GEBTUI.prw`) e API REST (`src/GEBWEB.prw`), ordem de construção `GEB_NUCLEO > GEB_FISCAL > GEB_DERRAMA > GEB_ESTOQ_VENDA > GEB_CONTABIL`. Nenhum caminho pula o `CTB_Lanca()` — muda só quem aperta o botão.

---

## 2. Quem mora nas Bananias — perfis

### 2.1 Perfis de empresa (GE1)

A mesma lei vale para todos, mas o regime muda o jogo. O regime vem de `GEBREGIME()`:

1. parâmetro `REGIME` da empresa (GE4), gravado como `SIMPLES` quando o Simples Nacional é configurado;
2. sem o parâmetro, a convenção antiga: a linha da própria empresa na GE1 com `GE1_NOME == "SIMPLES"`;
3. sem nenhum dos dois, `REGULAR`.

| Perfil | Quem é | Regime no GEBAN | Peculiaridade |
|---|---|---|---|
| **MEI da barraca** | Zé da esquina, uma barraca, um caixa, zero paciência | `SIMPLES` (`GE1_NOME == "SIMPLES"`) | Emite pouco, apura simples, quer a derrama paga ontem |
| **Mercadinho** | 3 caixas, estoque de verdade, fiado no caderninho | `SIMPLES` ou `REGULAR`, conforme GE1 | Usa estoque mínimo, venda guiada e limite de fiado |
| **Prestador de serviço** | Faz serviço, emite NFS-e, quase não tem estoque | `REGULAR` (padrão quando GE1 ausente/vazio) | Base é serviço (NBS em GF1), split de recebimento é rotina |

**Isolamento multi-empresa (nova regra):** cada tabela tem coluna `EMPRESA CHAR(02)`. Todas as queries filtram por `EMPRESA` (ou ignoram quando vazio = relatório global). Usuários podem ser repetidos entre empresas — o mesmo código `USR01` existe em empresa `01` e em empresa `02` sem conflito. O isolamento é garantido por `EMPRESA + FILIAL` em GE2, GE3, GE4, e por `EMPRESA` em todas as tabelas de negócio.

**Regra dura: sem parâmetro e sem a convenção ⇒ `REGULAR`. Na dúvida, o fisco banânico presume que você é grande.** O Simples apura o DAS (só no regime `SIMPLES`); o `REGULAR` apura o IBS/CBS com guia própria na Derrama.

### 2.2 Perfis de usuário (GE2)

`GEBUSR(cCodUser)` valida o perfil (`GENUC_CAD.prw`):

- **Miss (usuário inexistente) ⇒ `.F.`** Ninguém fantasma lança nada.
- **Perfil `CAIXA` ⇒ só autoriza lançamento direto se `GEBCFG("PERMITE_DIRETA") == "S"`**. O caixa mexe no dinheiro, não no razão.
- **Demais perfis ⇒ `.T.`** (contador, gerente, admin — gente que supostamente sabe o que é débito).

**Regra multi-empresa de usuários:** o mesmo código de usuário pode existir em empresas diferentes (ex.: `USR01` em empresa `01` e também em empresa `02`). A validação `GEBEXPCONTEXTO` checa o triplete `(EMPRESA, FILIAL, COD)` em GE2 — se o usuário existe naquela empresa, a sessão é iniciada; senão, `.F.`.

---

## 3. Reforma Tributária 2026 — IBS/CBS à banânica

A Reforma chegou às Bananias como chega a chuva: todo mundo sabia que vinha, ninguém guardou o varal. O GEBAN implementa o essencial:

- **Dois impostos novos**: `IBS` (dos estados/municípios) + `CBS` (da União), calculados por item em GF4 (`GF4_BASE`, `GF4_IBS`, `GF4_CBS`).
- **Cálculo isolado**: `CALCIBS(nBase, nAliqIBS, nAliqCBS)` retorna `{nIBS, nCBS}` — aritmética pura, `nBase × alíquota`, sem efeito colateral. Alíquota vem de `ALIQF(cNCM, dData)`, que lê GF2 respeitando **vigência** (a alíquota que contém a data da emissão vence).
- **Cadastro**: GF1 guarda produto/serviço (`GF1_COD`, `GF1_NCM`, `GF1_DESC` — NCM para mercadoria, NBS para serviço); GF2 guarda alíquotas com vigência. Produto desconhecido ⇒ `{0, 0}` — **miss tributa a zero**, não trava a emissão.
- **Dois regimes, uma apuração** (`GEBFAPU`, `GEBFIS_APU.prw`):
  - `GF5_DEB` = IBS + CBS dos itens das notas **autorizadas** emitidas na competência (cancelada e em fila não contam), menos o IBS/CBS das devoluções de venda do mês (proporcional ao valor devolvido sobre a base do item na nota de origem);
  - `GF5_CRED` = IBS + CBS das entradas de compra do mês (gravados na entrada, GCQ7, pela alíquota vigente da NCM);
  - `GF5_SALDO = DEB − CRED`;
  - `GF5_REGIME` = `GEBREGIME()`.
  - Os créditos de GF6 (transferência/ressarcimento) continuam à parte e não abatem o saldo automaticamente.
- **Créditos que andam** (`GEBFCRE`, GF6): `cTipo` = `TRANSF` (transfere o crédito para outro período/estabelecimento) ou `RESSARC` (pede o dinheiro de volta); miss ou valor inválido ⇒ `TRANSF`. Crédito não some: ou transfere, ou ressarce, ou é glosado (seção 10).
- **Split de pagamento** (`GEBFSPL`): divide `nTotal` em `nPartes`, última parcela ajusta o resíduo para a soma fechar no centavo. É o famoso "passa metade no Pix, metade no cartão" — agora com exatidão contábil.

---

## 4. Emissão — EMISSAO configurável (`GEBFIS_EMI.prw`)

`GEBFEMI(cChave, cCod, nQtd, nPreco)` emite NF-e/NFS-e. Modo lido de `GEBCFG("EMISSAO")`, **miss ⇒ `ONLINE_FILA`**:

| Modo | Comportamento |
|---|---|
| `ONLINE_PURO` | Tenta autorizar; se falhar, retorna `EM_FILA` **puro, sem enfileirar** — purista sofre em silêncio |
| `ONLINE_FILA` (padrão) | Tenta autorizar; se falhar (ou o Mentor travar), grava GF3/GF4 como `EM_FILA` e enfileira em GE5 |
| `SO_FILA` | Nem tenta o mock SEFAZ — vai direto para a fila (modo "internet de banana") |

Detalhes que evitam dor de cabeça:

- **Intercept do Mentor primeiro**: `GEBMNT("EMISSAO")` travando ⇒ força fila, sem tocar no SEFAZ.
- **Mock SEFAZ hoje, SEFAZ real amanhã**: autoriza se `base = nQtd × nPreco > 0`. Base zerada nunca autoriza (nem banana de graça passa no fisco).
- **Grava sempre GF3** (header: `TIPO NFE`, `STATUS`, `EMIS = DToS(Date())`) **+ GF4** (item `001`) e, nos dois caminhos, gera o título a receber `CONSUMIDOR` à vista e a receita (`VENDA_RECEITA`) — **autorizada ou em fila, o financeiro e o contábil ficam sabendo**. Só a nota autorizada entra na apuração.
- **Idempotência por chave**: a mesma `cChave` identifica GF3/GF4/GE5 — reemissão não duplica, só reencontra.

---

## 5. Apuração — APURACAO configurável (`GEBFIS_APU.prw`)

Modo lido de `GEBCFG("APURACAO")`, **miss ⇒ `AUTO`**. Os três modos gravam igual (a chamada direta já é o ato manual) e diferem só no log:

| Modo | Significado |
|---|---|
| `AUTO` (padrão) | O sistema apura sozinho na virada — o contador dorme tranquilo |
| `MANUAL` | Alguém chama `GEBFAPU(cComp)` com a competência `YYYYMM` — o contador quer sentir o poder |
| `CONTABIL_DIRETA` | Apuração iniciada pelo lançamento direto (só se `PERMITE_DIRETA`, seção 8) |

**Idempotência por competência**: antes do insert, as linhas GF5 ativas da mesma competência recebem baixa lógica (`D_E_L_E_T_ := "*"`) — reapurar o mês não duplica, substitui. Sem GF3/GF4/GF5 ⇒ retorna `.F.` (não apura no vazio).

No regime `REGULAR`, a apuração:
- lança a provisão do saldo positivo (D 3.02.002 IBS/CBS sobre vendas / C 2.01.004 IBS/CBS a recolher); a reapuração lança só a diferença;
- gera ou atualiza a guia da Derrama `GD<comp>` (seção 6) pelo `GEBDGER(cComp)`.

No `SIMPLES`, o IBS/CBS vai dentro do DAS: a apuração só grava a GF5, sem guia e sem lançamento.

---

## 5.1 Simples Nacional — DAS (`GEBSN.prw`, GSN1–GSN8)

Regras da LC 123/2006, na redação da LC 155/2016. As faixas e os percentuais de repartição são os mesmos que o Protheus carrega no `FISA150`.

**Receita e RBT12**
- **Receita do mês** = itens de notas `AUTORIZADA` da competência (`GF4_BASE`) + receita informada fora do GEBAN (`GSN1_REC`). Nota em fila não conta.
- **RBT12** = receita dos 12 meses **anteriores** à competência, somando mercado interno e exportação. **Início de atividade** (`GE4 SN_INICIO`, há menos de 12 meses): no mês de início, receita do mês × 12; nos meses seguintes, média dos meses desde o início × 12. A folha do Fator R segue a mesma regra.
- **Receita do ano** (RBA) = de janeiro até o mês apurado. Serve para os alertas de sublimite e de limite.

**Segregação por atividade**
- Cada atividade (`GSN3`) tem um Anexo: `I` a `V`, ou `FR` (Fator R).
- Cada produto (`GSN7`) aponta para uma atividade e pode ser marcado como **ST** (ICMS por substituição tributária) e/ou **monofásico** (PIS/COFINS).
- Cada nota (`GSN8`) pode ser marcada como **exportação**.
- Produto sem atividade usa o Anexo padrão (`GE4 SN_ANEXO`). A receita do mês é separada por atividade + ST + monofásico + exportação, e cada parte tem uma linha em `GSN4`.
- **Fator R** = folha de 12 meses / RBT12, calculado para a empresa toda. Para atividades `FR`: Anexo III se for ≥ 28%, senão Anexo V. A folha é informada só na linha sem atividade.

**Cálculo**
- **Alíquota efetiva** = (RBT12 × alíquota nominal − parcela a deduzir) / RBT12, por Anexo e sempre com o RBT12 da empresa toda.
- **Repartição** pelos percentuais da faixa entre IRPJ, CSLL, COFINS, PIS, CPP, ICMS, ISS e IPI. O **ISS** fica limitado a 5% da receita, e o excedente vai para os demais tributos, na proporção dos percentuais. Cada tributo é arredondado ao centavo, e a diferença de centavo fica no maior.
- **ST** tira o ICMS. **Monofásico** tira PIS e COFINS. **Exportação** tira PIS, COFINS, ICMS, ISS e IPI.
- **6ª faixa** (RBT12 acima de R$ 3,6 milhões): o ICMS (Anexos I e II) ou o ISS (Anexos III a V) sai do DAS pelo percentual da 5ª faixa e é pago por fora. O restante segue os percentuais da 6ª faixa. Com ST, o ICMS não sai como "por fora", porque já foi recolhido.

**Alertas**
- RBT12 acima de R$ 4,8 milhões.
- Sublimite excedido, com o valor de ICMS/ISS que sai do DAS.
- Receita do ano acima de R$ 3,6 milhões (ICMS/ISS fora do DAS a partir do mês seguinte) ou acima de R$ 4,8 milhões (exclusão).
- Exportação acima do limite adicional de R$ 4,8 milhões.
- Guia já paga com valor diferente (guia complementar gerada, ou restituição a pedir).

**Guia e vencimento**
- A apuração só roda no regime `SIMPLES`; configurar o Simples grava esse regime.
- O DAS vira a guia `DAS-AAAAMM` na Derrama, com título a pagar de mesmo número (fornecedor `RFB`, conta 2.01.002) e provisão contábil (D 4.02.005 / C 2.01.002) pela diferença do que já foi lançado. Vencimento no dia 20 do mês seguinte.
- O ICMS e o ISS que saem do DAS (6ª faixa) viram as guias `ICMS-AAAAMM` (Anexos I e II) e `ISS-AAAAMM` (Anexos III a V), com título e provisão (D 4.02.007 / C 2.01.006). Vencimento no dia `DER_DIA_ICMS`/`DER_DIA_ISS` (padrão 20) do mês seguinte.
- Sábado, domingo e feriado passam para o dia útil seguinte. Contam os feriados nacionais fixos (1/1, 21/4, 1/5, 7/9, 12/10, 2/11, 15/11, 20/11 e 25/12), os bancários móveis calculados pela Páscoa (Carnaval, Sexta-feira Santa e Corpus Christi) e os feriados cadastrados em `GSN5` (municipais e estaduais).
- Uma reapuração atualiza valor e vencimento enquanto a guia não tiver pagamento. Depois do pagamento, uma diferença para mais gera a guia complementar `<guia>-C<n>`; para menos, um alerta de restituição.

**Relatórios**
- **Extrato da apuração** (`GEBSNEXTRATO`): resumo (RBT12, exportação, receita do ano, folha, Fator R, faixa, alíquota, DAS, ICMS/ISS por fora, vencimento, situação da guia, alertas), uma linha por atividade/tipo com cada tributo, e o total por tributo.
- **Acompanhamento anual** (`GEBSNANUAL`): mês a mês (receita, RBT12, alíquota, DAS, guia), totais do ano e quanto do sublimite e do limite já foi consumido.
- Na tela, os dois aparecem na página Resultado (grade de relatório da sessão). Na API, saem em JSON.

**Fora do escopo:**
- ISS retido na fonte;
- receita externa (`GSN1`) com ST, monofásico ou exportação (conta sempre como receita normal de mercado interno);
- os limites de mercado interno e externo para a faixa (a faixa usa o RBT12 total);
- feriados sem cadastro na `GSN5`.

Exemplos (`tests/T_GEBSN.prw`):
- Anexo III, 3ª faixa, RBT12 de 480.000: (480.000 × 13,5% − 17.640) / 480.000 = 9,825%, e DAS de 4.912,50 sobre receita de 50.000.
- Anexo I, 3ª faixa, alíquota de 6,6125% sobre receita de 10.000: DAS normal de 661,25; com ST, 439,73; monofásico, 558,76; exportação, 337,24.

## 6. A Derrama — o DARF-CBS banânico (`GEBDER_*.prw`)

A Derrama é o livro único dos tributos a pagar: IBS/CBS (`GD<comp>`), DAS (`DAS-<comp>`), ICMS/ISS fora do DAS (`ICMS-<comp>`, `ISS-<comp>`) e retenções (`RET-<tributo>-<comp>`, seção 20). Toda guia nasce por `GEBDERGUIA` (`GEBDER_FIN.prw`):

- grava a guia (GD1) e o complemento GD4 (tipo, competência, **vencimento**, conta contábil da obrigação, credor);
- cria no financeiro o título a pagar de **mesmo número** (GFN3 + GFX2, origem `DERRAMA <tipo>`), que aparece no fluxo de caixa, na posição de títulos e no extrato;
- sem pagamento, reapurar atualiza valor e vencimento da guia e do título (valor zero cancela);
- com pagamento, a diferença para mais vira a guia complementar `<guia>-C<n>`; para menos, só o aviso de restituição.

A guia do IBS/CBS sai de `GEBDGER(cComp)` com o saldo da GF5, vencimento no dia `DER_DIA_IBSCBS` (padrão 20) do mês seguinte em dia útil (sábado, domingo e feriado empurram) e conta 2.01.004. Empresa do Simples não tem essa guia (o IBS/CBS vai no DAS).

### 6.1 Juros + multa — a matemática do atraso (`GEBDJUR`)

Para a guia `cGuia` com `nDias` de atraso, sobre o `VALOR` de GD1:

```
nJur = VALOR × 0,0033 × nDias        (0,33% ao dia)
nJur = min(nJur, VALOR × 0,20)       (teto de 20% — o agiota tem limite, o fisco também)
nMul = VALOR × 0,02                  (multa fixa de 2%)
nTot = VALOR + nJur + nMul           (gravado em GD1_JUROS / GD1_MULTA / GD1_TOTAL)
```

Guia vazia, dias nulos ou guia inexistente ⇒ retorna `0` sem gravar. A mesma fórmula vale para o fiado atrasado (seção 9) — nas Bananias, juro é juro, seja do fisco ou do caderninho.

### 6.2 Parcelamento (`GEBDPAR`)

`GEBDPAR(cGuia, nParc)` parcela o `TOTAL` (ou o `VALOR`, se o total ainda estiver zerado):

- `nParc < 2` ⇒ `.F.` — parcelar em 1x chama-se "pagar".
- Baixa lógica das parcelas ativas da guia antes de gerar as novas (reparcelar substitui, não acumula).
- `PARC` em 3 dígitos (`001`…`999`), parcelas iguais, **última ajusta o resíduo**.
- Guia vira `STATUS PARCELADA`, parcelas nascem `ABERTA` em GD2.
- No financeiro, o título da guia vira um título por parcela (`<guia>/01`…, de 30 em 30 dias). Os juros e a multa já somados ao total viram despesa (D 4.02.002 / C obrigação).
- Guia com algum pagamento não pode ser parcelada.

### 6.3 Saqueadores e protesto (`GEBDPRO`)

Quem ignora a Derrama conhece os **Saqueadores** — o departamento de cobrança banânico, temido e pontual. `GEBDPRO(cGuia)`:

1. Grava GD3 com `ACAO PROTESTO`, `DATA` de hoje, `STATUS ABERTA`;
2. Marca GD1 como `PROTESTADA`.

Guia inexistente ou tabelas ausentes ⇒ `.F.` (nem os Saqueadores protestam fantasma).

### 6.4 Baixa (`GEBDBAI`)

`GEBDBAI(cGuia[, cConta, cData])` paga pela Derrama (`GEBDERPAGA`): baixa no financeiro todos os títulos abertos da guia na conta informada (padrão `DER_CONTA`, ou `CAIXA`). O dinheiro sai da conta (GFX4/GFN1) e o lançamento é D obrigação (conta da guia) / C conta financeira, com os juros e a multa em 4.02.002.

- O título também pode ser pago por qualquer baixa do financeiro; quando o último título da guia é quitado, a guia e as parcelas ficam `BAIXADA`.
- Juros e multa do título de uma guia seguem a regra da Derrama (0,33% ao dia, teto de 20%, multa de 2%), não os parâmetros do financeiro. Se a guia tem juros gravados por `GEBDJUR` (sem parcelas), eles são usados.
- Pagar de novo uma guia já baixada não movimenta nada (resposta idempotente).

---

## 7. Mentor B — o conselheiro que trava (`GENUC_MNT.prw`, GE4/GE3)

O Mentor é aquele tio que avisa antes de você fazer besteira. Cada evento tem um modo em GE4 (lido via `GEBCFG(cEvento)`):

| Modo | Efeito de `GEBMNT(cEvento)` |
|---|---|
| `AVISA_E_TRAVA` | Retorna `.F.` — a operação **não acontece** (venda vira `BLOQUEADA`, emissão vai para fila) |
| `AVISA_E_LIBERA_COM_BO` (**padrão B**) | Grava o B.O. em GE3 via `GEBAUD` e retorna `.T.` — "pode passar, mas está registrado" |
| `DESLIGADO` (ou miss, ou modo desconhecido) | Retorna `.T.` sem gravar nada — miss **não** gera trilha espúria |

**O botão "Assumo o B.O."** é o modo B em ação: o operador confirma, o sistema grava em **GE3** (`cUsuario`, `cEvento`, `cMotivo`) e libera. Auditoria de verdade: quem assumiu, o quê, por quê — para o dia em que o fiscal perguntar "quem autorizou esta venda impulsiva às 23h58?".

Eventos mentorados: `EMISSAO`, `VENDA_IMPULSIVA`, `ESTOQUE_MINIMO` (só alerta, não trava a movimentação), `LANC_DIRETO`, e qualquer outro cadastrado em GE4.

---

## 8. Contábil — partida dobrada ou nada (`GEBCTB_*.prw`, `GENUC_MNT.prw`)

### 8.1 Todo caminho passa pelo `CTBLAN`

`CTBLAN(cOrigem, nValor)` (em `GENUC_MNT.prw`) é partida dobrada de verdade. **Os módulos não o chamam mais com o número do documento** (isso caía no `PADRAO` e transformava pagamentos em receita; ver seção 20): cada fato usa o lançamento padrão do seu evento pelo `GEBCTXLP`. O `CTBLAN` continua para quem o chama pelo nome do evento:

1. Lê o parâmetro do evento em GC4 (origem → conta débito + conta crédito), com fallback para o parâmetro `PADRAO`;
2. `CTBGRV` grava GC2 (lote: `LOTE`, `ORIGEM`, `VALOR`, `DATA`, `COMP AAAAMM`, `TIPO`) + **2 pernas em GC3** (`D` e `C`);
3. **Confere: Σ débito == Σ crédito** — desbalanceou ⇒ retorna `.F.`/`""`, sem meio-termo;
4. Valor zerado, contas vazias ou parâmetro ausente ⇒ recusa.

Compatibilidade: sem GC4 ou sem nenhum parâmetro (contábil ainda não migrada), age como o stub antigo (`.T.`, só loga) — fiscal, derrama e venda seguem funcionando.

### 8.2 Lançamento direto — com 4 cadeados (`GEBCDIR`)

`GEBCDIR(cContaD, cContaC, nValor[, cUser])` grava com **carimbo `DIRETO`** (`TIPO DIRETO` em GC2). Só passa se **todas** as travas liberarem, nesta ordem:

1. **Flag global**: `GEBCFG("PERMITE_DIRETA") == "S"` — o dono da empresa decide se direta existe;
2. **Perfil**: `GEBUSR(cUser)` autoriza (`CAIXA` só com a flag `S`; miss nega);
3. **GC4**: linha `LANC_DIRETO` com `PERM N` nega (linha ausente = sem restrição extra);
4. **Mentor**: `GEBMNT("LANC_DIRETO")` precisa liberar (`AVISA_E_TRAVA` nega).

Qualquer trava ⇒ `.F.` com log do motivo (`DIR negado flag/perfil/GC4/mentor`). O carimbo `DIRETO` permite ao balancete e à auditoria separar o que veio do fluxo normal (`AUTO`) do que o contador digitou na mão.

### 8.3 Balancete e DRE (`GEBBAL`, `GEBDRE`)

- `GEBBAL(cComp)` soma as pernas GC3 dos lotes GC2 da competência e retorna `{cConta, nDebito, nCredito}` por conta. Competência vazia ou contábil ausente ⇒ array vazio.
- `GEBDRE(cComp)` — a DRE banânica: **receitas (grupo `3`, crédito − débito) menos despesas e custos (grupo `4`, débito − crédito)**. Plano de contas seed: `1.01.001 CAIXA`, `2.01.001 FORNECEDORES`, `3.01.001 RECEITA VENDAS`…

---

## 9. Venda, estoque e fiado — o balcão (`GEBV_*.prw`)

### 9.1 Venda guiada (`GEBVVEN`)

`GEBVVEN(cVenda, cProd, nQtd[, nPreco])` — miss de preço vale `10`:

1. Guardas ⇒ `BLOQUEADA` (venda/produto vazio, quantidade ≤ 0);
2. Sem GV1/GV2 ⇒ `SEM_ESTOQUE`;
3. Mentor `VENDA_IMPULSIVA` travando ⇒ `BLOQUEADA` **sem tocar o banco**;
4. Produto ausente ou saldo < quantidade ⇒ `SEM_ESTOQUE` **sem tocar o banco**;
5. Vende à vista no `CAIXA`: saída pelo estoque com custo (`GEBESTMOV`: kardex, custo médio, GV1) com o CMV contabilizado; GV2 `VENDIDA`; nota pelo fiscal (`GEBFEMI`, que gera o título a receber e a receita) ou, sem fiscal, o título e a receita direto; o título é recebido na hora no `CAIXA`.

### 9.2 Estoque com mínimo (`GEBVEST`)

`GEBVEST(cProd, nQtd)` ajusta a quantidade pelo estoque com custo (`GEBESTMOV`, entrada ao custo médio atual; saída acima do saldo é recusada), que também atualiza a GV1; produto novo nasce com **`MINIMO 10`**. Novo saldo abaixo do mínimo ⇒ chama o Mentor com `ESTOQUE_MINIMO` **só como alerta** — a movimentação acontece mesmo assim. Banana pouca avisa, mas não trava.

### 9.3 Fiado — o caderninho com limite (`GEBVFIA`, `GEBVJUR`, GV3)

- `GEBVFIA(cCli, nValor)`: abre fiado `ABERTA` **se `soma dos em aberto do cliente + nValor ≤ 1000`** (limite fixo, soma usa `TOTAL`, caindo para `VALOR` se total zerado). Acima do limite ⇒ `.F.` sem gravar. Cliente vazio, valor ≤ 0 ou GV3 ausente ⇒ `.F.`. O fiado vira o título a receber `FIA-<registro>` (vencimento em `LOJ_FIADO_DIAS` dias) com a receita; receber o título quita a linha GV3 (`QUITADA`).
- `GEBVJUR(cCli, nDias)`: mesma fórmula da Derrama (0,33%/dia, teto 20%, multa 2%) aplicada sobre o `VALOR` de **cada linha `ABERTA`** do cliente; grava `JUROS/MULTA/TOTAL` por linha e retorna a soma dos totais. Sem linha em aberto ⇒ `0`.

---

## 10. Glosas — quando o crédito é barrado

Nem todo crédito que entra é crédito que fica. As regras de glosa:

1. **Glosa de vigência**: item emitido com NCM sem alíquota vigente em GF2 tributa a zero (`{0, 0}`) — o imposto some, mas a nota sai. Na apuração, esse zero não gera débito nem crédito: é como se o fisco dissesse "desta vez passa, mas anotei".
2. **Glosa de competência**: `GEBFAPU` soma **só** os itens cujas chaves estão em GF3 com `EMIS` na competência — item de competência errada ou sem header GF3 não entra no débito. Nota órfã não apura.
3. **Glosa de crédito (GF6)**: crédito `TRANSF`/`RESSARC` sem origem, sem valor ou sem GF6 ⇒ `.F.`, nada gravado. Crédito precisa de lastro: competência, origem e valor, ou volta para a fila da vergonha.
4. **Glosa contábil**: lançamento desbalanceado, conta vazia ou valor zerado é recusado por `CTBGRV` — não existe "meio lançamento" nas Bananias.
5. **Glosa do direto**: qualquer das 4 travas da seção 8.2 negando ⇒ nada gravado, motivo logado. Direta sem permissão é só rascunho.

---

## 11. Exemplos numéricos — com banana e calculadora

> Alíquotas didáticas (não oficiais): `IBS 10%`, `CBS 5%`. A fórmula é a lei; os percentuais são do exemplo.

### 11.1 Nota de R$ 2.000

Zé da barraca vende 10 cachos a R$ 200 (`GEBVVEN("V-0001","BANANA-PRATA",10,200)`):

- `base = 10 × 200 = 2000`
- `CALCIBS(2000, 0.10, 0.05)` ⇒ `nIBS = 200`, `nCBS = 100`
- GF3: `BASE 2000`, `IBS 200`, `CBS 100`, `STATUS AUTORIZADA`; GF4 item `001` idem
- financeiro: título `V-0001` de 2000 recebido na hora no `CAIXA`; contábil: `VENDA_RECEITA` 2000 (D clientes / C receita), `FIN_REC` 2000 (D caixa / C clientes) e o CMV pelo custo médio

### 11.2 Massa de 100 notas ⇒ apuração DEB 1500

Massa de teste: 100 emissões mix Simples/Regular somando `IBS + CBS = 1500`:

- `GEBFAPU("202609")` ⇒ GF5: `DEB 1500`, `CRED 0`, `SALDO 1500`, `REGIME` conforme `GEBREGIME()`
- `GEBDGER("202609")` ⇒ guia `GD202609`, `VALOR 1500`, `TOTAL 1500`, `ABERTA`
- Atraso de 10 dias: `GEBDJUR("GD202609",10)` ⇒ `juros = 1500×0,0033×10 = 49,50` (< teto `300`), `multa = 30`, **`TOTAL 1579,50`**
- Em 3x: `GEBDPAR("GD202609",3)` ⇒ `001 = 526,50`, `002 = 526,50`, `003 = 526,50` (última ajusta resíduo), guia `PARCELADA`
- Calote total: `GEBDPRO("GD202609")` ⇒ GD3 `PROTESTO/ABERTA`, guia `PROTESTADA` — os Saqueadores agradecem a preferência

### 11.3 DRE 500

Competência com receitas de 2000 (grupo `3`) e despesas de 1500 (grupo `4`):

- `GEBDRE("202609")` ⇒ `receitas (2000 − 0) − despesas (1500 − 0)` = **`500`**
- O lucro banânico: 500 motivos para continuar vendendo banana

### 11.4 Fiado no limite

Cliente com 800 em aberto pede 300: `800 + 300 = 1100 > 1000` ⇒ `.F.`, nada gravado — o caderninho tem teto. Pede 200: `800 + 200 = 1000 ≤ 1000` ⇒ `.T.`, linha `ABERTA`. Atraso de 30 dias numa linha de 200: `juros = 200×0,0033×30 = 19,80` (< teto `40`), `multa = 4`, `total 223,80`.

### 11.5 CAIXA 2500 — a massa dos 100 títulos (`T_GEBFIN_MASSA`)

O teste de estresse do cofre: 50 a receber de 100 + 50 a pagar de 50, tudo baixado até zerar:

- `GEBFNCON("CAIXA","Caixa M5")` ⇒ conta `CAIXA` com `SALDO 0` — o cofre nasce vazio, como todo cofre honesto;
- loop 50× `GEBFNREC("REC-M5-N","CLI-M5",100,"20261231")` ⇒ `50 × 100 = 5000` em GFN2 `ABERTO`;
- loop 50× `GEBFNPAG("PAG-M5-N","FORN-M5",50,"20261231")` ⇒ `50 × 50 = 2500` em GFN3 `ABERTO`;
- `GEBNFLX()` ⇒ `{5000, 2500, 2500}` — receber, pagar, saldo;
- baixa total dos 100 (`GEBFNBAI("REC",cDoc,100)` + `GEBFNBAI("PAG",cDoc,50)`) ⇒ `GEBNFLX()` ⇒ `{0, 0, 0}`;
- GFN1 `CAIXA = 5000 − 2500 = 2500` — entrou 5000, saiu 2500, sobrou 2500 para a festa da banana;
- GFX4 `CAIXA` (movimentos do financeiro) com **100 movimentos** — um por baixa, sem exceção, porque baixa sem movimento é boato.

### 11.6 50 pedidos round-trip — a massa do mercadão (`T_GEBCOM_MASSA`)

O teste de estresse da compra: 50 pedidos nascem, viram NF, viram estoque e viram pagar:

- `GEBCMFOR("FORN-M5","Forn Massa")` + `GEBCMCOT("FORN-M5","P-M5-A",10)` ⇒ `GEBCMMEL("P-M5-A") == 10`;
- loop 50×: `GEBCMPED("PED-M5-N","FORN-M5") == "ABERTO"` + `GEBCMIT(cPed,"P-M5-A",2,10)` (total `2 × 10 = 20`) + `GEBCMENT("NF-M5-N",cPed)`;
- final: **50 GCP3 `RECEBIDO` + 50 GCP5 `RECEBIDA` + 50 GFN3** — cada NF de 20 virou um pagar de 20;
- estoque `P-M5-A` soma `50 × 2 = 100` unidades via `GEBVEST` — o mercadão encheu a dispensa sozinho.

---

## 12. Mapa rápido — função × tabela

| Função | Tabela(s) | O que faz |
|---|---|---|
| `GENMIG` / `GEBCFG` | GE1–GE5 | Migra núcleo; lê regra do Mentor/flag |
| `GEBAUD` | GE3 | Grava o B.O. ("Assumo o B.O.") |
| `GEBMNT` / `GEBFILA` | GE4 / GE5 | Decide trava/libera; enfileira `PENDENTE` |
| `CALCIBS` / `ALIQF` | GF2 | Calcula imposto; lê alíquota vigente |
| `GEBFPRO` / `GEBFALI` | GF1 / GF2 | Cadastro produto; alíquota por NCM |
| `GEBFEMI` / `GEBFSPL` | GF3 / GF4 (+GE5) | Emite NF-e/NFS-e; divide valores |
| `GEBFAPU` / `GEBFCRE` | GF5 / GF6 | Apura débito/crédito; transfere/ressarce |
| `GEBDGER` | GF5 ⇒ GD1 | Gera a guia DARF-CBS da competência |
| `GEBDJUR` / `GEBDPAR` / `GEBDPRO` | GD1 / GD2 / GD3 | Juros+multa; parcela; protesta |
| `GEBDBAI` | GD1/GD2 (+CTB) | Baixa e concilia com contábil |
| `GEBVEST` | GV1 | Ajusta a quantidade pelo estoque com custo (`GEBESTMOV`), alerta no mínimo 10 |
| `GEBVVEN` | GV1/GV2 (+fiscal/CTB) | Vende ou bloqueia sem tocar o banco |
| `GEBVFIA` / `GEBVJUR` | GV3 | Fiado até 1000; juros do caderninho |
| `CTBLAN` / `CTBGRV` | GC4 ⇒ GC2/GC3 | Partida dobrada, débito == crédito |
| `GEBCDIR` | GC4 ⇒ GC2/GC3 | Direta com 4 travas, carimbo `DIRETO` |
| `GEBBAL` / `GEBDRE` | GC2/GC3 | Balancete por conta; DRE grupos 3−4 |
| `GEBFNMIG` / `GEBFNCON` | GFN1–GFN4 | Migra cofre; cria conta `CAIXA` com `SALDO 0` |
| `GEBFNREC` / `GEBFNPAG` | GFN2 / GFN3 | Receber sem Mentor; pagar com `PAG_IMPULSIVO` |
| `GEBFNBAI` | GFN2/GFN3 ⇒ `GEBFXBAI` (GFX3+GFX4+GFN1+CTB) | Baixa parcial/total, `RECEBIDA`/`PAGA` |
| `GEBNFLX` | GFN2+GFN3 | Fluxo `{rec, pag, saldo}` só `ABERTO` |
| `GEBCMMIG` / `GEBCMFOR` | GCP1–GCP5 | Migra mercadão; cria fornecedor idempotente |
| `GEBCMCOT` / `GEBCMMEL` | GCP2 | Cota preço; menor preço do produto |
| `GEBCMPED` / `GEBCMIT` | GCP3 / GCP4 | Pedido com `COMPRA_IMPULSIVA`; item sem pedido nega |
| `GEBCMENT` | GCP3/GCP4 ⇒ GV1+GFN3+GCP5+CTB | Entrada NF: estoque + pagar + contábil |

---

## 13. FIN — o cofre banânico (`GEBFIN_*.prw`, GFN1–GFN4)

O FIN é o cofre: quatro gavetas, uma regra de ouro — **dinheiro que entra ou sai deixa três rastros**: o título baixado, o movimento da conta (GFX4; os antigos ficaram em GFN4) e o saldo da conta em GFN1, mais o carimbo do contábil.

### 13.1 Contas, receber e pagar — as gavetas

- **Contas (GFN1: `CONTA-NOME-SALDO`)**: `GEBFNMIG()` cria GFN1–GFN4 idempotente (retorna `.F.` se qualquer `CREATE` falhar); `GEBFNCON(cConta,cNome)` cria a conta com `SALDO 0` via `DbAppend()+RecLock(.T.)` — idempotente (conta existente ⇒ `.T.` sem duplicar), conta vazia ou GFN1 ausente ⇒ `.F.`. A `CAIXA` é conta como outra qualquer: se existir, a baixa atualiza; se não existir, a baixa antiga cria a `CAIXA` antes de baixar.
- **Receber (GFN2)**: `GEBFNREC(cDoc,cCli,nValor,dVenc)` lança pelo financeiro (`GEBFXTIT`, com o complemento GFX2) e contabiliza D clientes / C outras receitas (`FIN_RECEITA`). Recusa (`.F.` sem gravar) se doc vazio, `nValor ≤ 0` ou `DOC` duplicado na filial. `dVenc` aceita `YYYYMMDD` ou `Date`; vazio = à vista.
- **Pagar (GFN3)**: `GEBFNPAG(cDoc,cForn,nValor,dVenc)` — mesmas regras, contabiliza D despesas gerais / C fornecedores (`FIN_DESPESA`) e, antes de tocar o banco, passa pela guia do Mentor `GEBMNT("PAG_IMPULSIVO")`. Travado ⇒ `.F.` sem gravar nada.

### 13.2 Baixa parcial/total — o ritual (`GEBFNBAI`)

`GEBFNBAI(cTipo,cDoc,nValor)` — `cTipo` `REC`/`RECEBER` mexe em GFN2, `PAG`/`PAGAR` em GFN3; tipo inválido, doc vazio, valor ≤ 0, tabela ausente ou título inexistente ⇒ `.F.`:

1. **Guia do Mentor (só pagar)**: `GEBMNT("PAG_IMPULSIVO")` travando ⇒ `.F.` sem tocar o banco — nem lançar nem pagar escapam do conselheiro;
2. **`SALDO -= nValor`, com clamp**: pagou a maior? Quita — `nEf = min(nValor, nSaldo)`, sem troco, sem crédito fantasma;
3. **Status**: zerou ⇒ `RECEBIDA` (receber) ou `PAGA` (pagar); sobrou ⇒ continua `ABERTO` — parcial é parcial, não é "quase paga";
4. **Pelo financeiro**: a baixa é feita pelo `GEBFXBAI` na conta `CAIXA` (criada se faltar): histórico em GFX3, movimento em GFX4, saldo em GFN1 e lançamento pela conta do título (`FIN_REC` / `FIN_PAG`). Quitar sincroniza a origem (guia da Derrama, fiado).

### 13.3 Fluxo de caixa — o termômetro (`GEBNFLX`)

`GEBNFLX()` retorna `{nRec, nPagar, nSaldo}`: soma dos `SALDO` com `STATUS ABERTO` em GFN2 e GFN3 (filtros filial + `D_E_L_E_T_`), `nSaldo = rec − pag`. Quitados (`RECEBIDA`/`PAGA`) não entram — o fluxo mostra o futuro a vencer, não o passado quitado. Tabelas ausentes valem zero (guarda via `sqlite_master` antes do `DbSelectArea`, que aborta em tabela inexistente).

---

## 14. COM — o mercadão (`GEBCOM_*.prw`, GCP1–GCP5)

O COM é o mercadão: fornecedor, cotação, pedido, entrada. Regra de ouro — **pedido não é dívida, NF é**: o pedido promete, a entrada cumpre (estoque sobe, pagar nasce, contábil carimba).

### 14.1 Fornecedor, cotação e menor preço — a pechincha

- **Fornecedor (GCP1: `COD-NOME-CNPJ`)**: `GEBCMFOR(cCod,cNome)` cria com `CNPJ ""` — idempotente (código existente ⇒ `.T.` sem duplicar); código/nome vazio ou GCP1 ausente ⇒ `.F.`.
- **Cotação (GCP2: `FORN-PROD-PRECO`)**: `GEBCMCOT(cForn,cProd,nPreco)` grava cada oferta; fornecedor/produto vazio, `preço ≤ 0` ou GCP2 ausente ⇒ `.F.`. Cotação não trava nada — só registra quem pediu quanto.
- **Menor preço**: `GEBCMMEL(cProd)` varre GCP2 na filial e retorna o menor `PRECO` — `0` se produto vazio, GCP2 ausente ou sem cotação. É o "quem dá menos leva o pedido", em uma função.

### 14.2 Pedido — com o Mentor no ombro (`GEBCMPED`, `GEBCMIT`)

- **Header (GCP3: `NUM-FORN-STATUS`)**: `GEBCMPED(cPed,cForn)` cria `ABERTO` — **depois** da guia `GEBMNT("COMPRA_IMPULSIVA")`. Travado ⇒ `"BLOQUEADO"` sem tocar o banco. Idempotente (pedido existente ⇒ `"ABERTO"` sem duplicar); pedido/fornecedor vazio ou GCP3 ausente ⇒ `"BLOQUEADO"`. Pedido bloqueado não é erro: é o Mentor dizendo "dorme com essa ideia e me conta amanhã".
- **Item (GCP4: `PED-PROD-QTD-PRECO`)**: `GEBCMIT(cPed,cProd,nQtd,nPreco)` grava; `.F.` se pedido/produto vazio, `qtd/preço ≤ 0`, GCP4 ausente ou **pedido inexistente em GCP3** — item órfão não entra no mercadão.

### 14.3 Entrada NF — o batismo triplo (`GEBCMENT`)

`GEBCMENT(cNF,cPed)` passa as guardas abaixo e o Mentor `PAG_IMPULSIVO`, e então recebe todo o pendente pelo documento de entrada do backoffice (`GEBCPXENT`): estoque a custo de entrada (kardex), título pela condição do pedido (à vista se não tiver), `COMPRA_ESTOQUE` (D estoque / C fornecedores) e o crédito de IBS/CBS. A regra antiga era:

1. **Soma** os itens GCP4 (`Σ QTD × PRECO`) — pedido sem itens ⇒ `.F.`, NF de vento não entra;
2. **Gera o pagar** via `GEBFNPAG(cNF,cForn,nTotal,"20261231")` — se o Mentor `PAG_IMPULSIVO` ou a duplicidade recusar, a entrada aborta **sem tocar o banco** (nem estoque, nem status, nada);
3. **Entra no estoque** (`GEBVEST(cProd,nQtd)` por item) + **`CTBLAN(cNF,nTotal)`** + marca GCP3 `RECEBIDO` + grava GCP5 (`NF-PED-STATUS RECEBIDA`).

Guardas (todas ⇒ `.F.` sem tocar o banco): NF/pedido vazio, GCP3/GCP4/GCP5 ausente, pedido inexistente ou já `RECEBIDO`, NF duplicada em GCP5.

### 14.4 GD1 × GFN3 — a guia mora na Derrama e se paga no financeiro

Desde 19/10/2026 (decisão do operador) a Derrama e o contas a pagar andam juntos:

| | **GD1 — a guia (o Rei Fisco)** | **GFN3 — o título** |
|---|---|---|
| Nasce de | `GEBDERGUIA`: apuração do IBS/CBS, DAS, ICMS/ISS fora do DAS, retenções | O mesmo `GEBDERGUIA`, com o número da guia (origem `DERRAMA <tipo>`) |
| Rito próprio | Juros (`GEBDJUR`), parcelamento (`GEBDPAR`, um título por parcela), protesto (`GEBDPRO`), guia complementar | Vencimento, fluxo de caixa, posição, baixa parcial ou total |
| Morre em | `BAIXADA` quando o último título é quitado | `GEBDBAI`/`GEBDERPAGA` ou qualquer baixa do financeiro |

O fornecedor continua com o seu título comum (compras, despesas). A diferença é a conta: o título da guia baixa contra a obrigação tributária (2.01.002, 2.01.004, 2.01.005 ou 2.01.006), e o do fornecedor contra 2.01.001.

### 14.5 Limite do fiado × limite da compra — teto vs. conselheiro

- **Fiado (GV3, seção 9.3): teto numérico, duro como banana verde** — `soma dos ABERTA do cliente + nValor ≤ 1000`, senão `.F.` sem gravar. O caderninho tem calculadora e não negocia.
- **Compra (GCP3/GCP4): sem teto numérico, com teto moral** — nenhum código soma "compras em aberto do fornecedor"; o freio é o Mentor `COMPRA_IMPULSIVA` (`AVISA_E_TRAVA` bloqueia, modo B grava B.O. em GE3 e libera, `DESLIGADO`/miss libera sem rastro). O mercadão confia no conselheiro, não na calculadora.

Em resumo: **fiado estoura no número, compra estoura no conselho**. Um tem limite de 1000, o outro tem limite de bom-senso — adivinhe qual dá mais trabalho.

---

---

## 15. Multi-empresa — isolamento por EMPRESA + FILIAL

A expansão `GEB_EXPANSAO` (`src/GEBEXP_MIG.prw`) adicionou coluna `EMPRESA CHAR(02)` a **todas as 28 tabelas** do sistema (GE1–GE5, GF1–GF6, GD1–GD3, GV1–GV3, GFN1–GFN4, GCP1–GCP5, GC1–GC4) e criou duas tabelas de auditoria novas:

| Tabela | Finalidade | Campos-chave |
|--------|-----------|-------------|
| **GEH** | Histórico de acesso | `GEH_DATA`, `GEH_HORA`, `GEH_USUARIO`, `GEH_EMPRESA`, `GEH_FUNCAO`, `GEH_IP` |
| **GEI** | Audit log processual | `GEI_ORIGEM`, `GEI_TABELA`, `GEI_REGISTRO`, `GEI_ACAO`, `GEI_HORA` |

### 15.1 Isolaemento por EMPRESA + FILIAL

- Todas as leituras em tabelas de negócio filtram por `EMPRESA` (quando fornecido). Relatório sem filtro de empresa retorna dados consolidados de todas.
- O código de empresa é `CHAR(02)` (ex.: `"01"`, `"02"`, `"99"`). O default é `"  "` (dois espaços) para dados antigos migrados — relatórios tratam tanto `"  "` quanto valor específico.
- Usuários podem ser **repetidos entre empresas**: o mesmo `GE2_COD = "USR01"` existe em empresa `01` e em empresa `02`. O triplete `(EMPRESA, FILIAL, COD)` é a chave única de usuário.

### 15.2 Sessão GEBEXPCONTEXTO

`GEBEXPCONTEXTO(cEmpresa, cFilial, cUsuario)` (em `src/GEBEXP_CTX.prw`):

1. Valida se o usuário existe em GE2 com o triplete `(EMPRESA, FILIAL, COD)` — `TCSqlQuery` com `SELECT *` (porque `COUNT(*)` sempre retorna Len≥1).
2. Se válido, grava entrada em **GEH** (histórico de acesso) e armazena contexto em **GEX** (linha temporária, sem `EMPRESA` — criada sob demanda pelo próprio módulo).
3. Retorna `.T.` se sucesso, `.F.` se usuário não existe naquela empresa.
4. `GEBEXPIST()` verifica se há sessão ativa em GEX (workarea, porque GEX é criada localmente).
5. `GEBEXPCONTEXT()` retorna `{empresa, filial, usuario}` lido de GEX.
6. `GEBEXPCLEAR()` encerra sessão (limpa linha de GEX).

**Regra:** uma sessão ativa é exclusiva por empresa — iniciar nova sessão na mesma empresa sobrescreve; iniciar em empresa diferente falha se já houver sessão ativa.

---

## 16. Navegação — interface PO-UI (`src/GEBTUI.prw`)

A interface roda no navegador (`advplc serve src/GEBTUI.prw`, porta 8081). Regras:

1. **Acesso:** usuário e senha conferidos com Argon2id; 5 erros seguidos bloqueiam a conta; a recusa
   é sempre genérica ("Credenciais inválidas"), para não revelar se o usuário existe. Senha vencida
   (90 dias) ou troca pedida pelo ADMIN obrigam a nova senha antes de entrar.
2. **Empresa e filial:** só as empresas vinculadas ao usuário (o `super` vê todas). Com o catálogo
   vazio, só o `super` entra, e cria a primeira empresa.
3. **Menu:** um módulo só aparece se o perfil tem ao menos um item permitido nele; ADMIN da empresa
   e `super` veem tudo.
4. **Operação:** cada formulário confere a permissão (menu/item) antes de executar e chama a mesma
   função de negócio da API REST — a regra vale igual pela tela e pela API.
5. **Validação:** fica na função de negócio, não na tela. A tela só mostra o resultado: mensagem de
   sucesso ou o motivo da recusa.
6. **Dados exibidos:** as tabelas ignoram registros excluídos (`D_E_L_E_T_`), filtram a filial da
   sessão (exceto empresas e usuários, que são do catálogo), mostram até 500 linhas e nunca exibem
   colunas de credencial (salt, hash, senha, token).
7. **Relatórios:** vão para a grade `GBR1` da sessão (cada janela do navegador tem a sua) e abrem
   na página Resultado; relatórios gerados ao mesmo tempo não se misturam. As grades de dias
   anteriores são apagadas automaticamente.
8. **Frente de loja:** venda, sangria, suprimento e cancelamento só com o caixa aberto; o cupom com
   devolução não se cancela (usa-se a devolução); desconto acima de `LOJ_DESC_MAX` exige usuário e
   senha de um supervisor com a permissão de liberar desconto.

## 17. Trackers — rastreio ponta a ponta

Os trackers (`src/GEBEXP_TRAK.prw`) permitem acompanhar o ciclo completo de cada operação, do início ao registro contábil. Cada função retorna **array de arrays**, onde cada posição corresponde a uma etapa do fluxo. Linhas ausentes são arrays vazios.

| Tracker | Entrada | Etapas retornadas |
|---------|---------|-------------------|
| **`GEBTRAKCOMPRA(cPedido)`** | Número do pedido | `[1]` Header GCP3 (num, forn, status); `[2]` Itens GCP4; `[3]` Entrada GCP5 (NF); `[4]` Estoque GV1 (saldo por produto); `[5]` Pagar GFN3 (títulos criados pela NF); `[6]` Lançamentos GC3 (partidas dobradas dos títulos) |
| **`GEBTRAKVENDA(cVenda)`** | Código da venda | `[1]` Header venda; `[2]` Itens GV2; `[3]` Estoque GV1 (pós-venda); `[4]` A receber GFN2 (se houver título vinculado); `[5]` Lançamentos GC3 |
| **`GEBTRAKNOTAFISCAL(cChave)`** | Chave da NF | `[1]` Header GF3 (chave, tipo, status, base, IBS, CBS, emis); `[2]` Itens GF4; `[3]` Cálculo IBS/CBS; `[4]` A receber GFN2; `[5]` Apuração GF5 (competência); `[6]` Guia GD1 (derrama) |
| **`GEBTRAKDERRAMA(cGuia)`** | Código da guia | `[1]` Apuração GF5 (origem); `[2]` Guia GD1 (valor, juros, multa, total, status); `[3]` Parcelas GD2; `[4]` Cobrança GD3 (protesto); `[5]` Pagar GFN3 (se vinculado); `[6]` Baixa (GFN4 antigos e pagamentos pelo financeiro em GFX4, inclusive das parcelas); `[7]` Lançamentos GC3 |

**Fluxos rastreados:**

- **COMPRA:** Pedido → Itens → Entrada (NF) → Estoque (GV1 aumenta) → Pagar (GFN3 nasce pela condição) → Contábil (`COMPRA_ESTOQUE`) → crédito de IBS/CBS
- **VENDA:** Venda → Estoque (GV1 baixa) → NF-e (GF3/GF4) → Apuração (GF5) → Guia derrama (GD1 + título GFN3) → Baixa pelo financeiro (conta, `FIN_PAG`) → A receber (GFN2)
- **NOTA_FISCAL:** NF → Itens → Cálculo IBS/CBS → Apuração competência → Guia derrama → Juros/Parcela/Protesto → Baixa → Contábil
- **DERRAMA:** Apuração → Guia → Juros (se atraso) → Parcelamento → Protesto (se glosa) → Baixa → Contábil

---

## 18. Relatórios gerenciais por módulo

`src/GEBEXP_REL_BIZ.prw` e `src/GEBEXP_REL_NUC.prw` implementam relatórios consolidados com filtro opcional por empresa:

| Função | Retorno | O que mostra |
|--------|---------|-------------|
| `GEBRELFISCAL(cEmpresa, cComp)` | `{nNotas, nBase, nIBS, nCBS, nDeb, nCred, nSaldo, nApur, cRegime}` | Notas, bases e impostos por competência |
| `GEBRELDERRAMA(cEmpresa, cComp)` | `{nGuias, nPagas, nVencidas, nValTot, nParc, nProv}` | Estado das guias DARF-CBS |
| `GEBRELFIN(cEmpresa)` | `{nContas, nRec, nPag, nValRec, nValPag, nSaldo, nMov}` | Posição financeira |
| `GEBRELSTOQUE(cEmpresa)` | `{nProd, nBaixMin, nValTot, nMov}` | Produtos, itens abaixo do mínimo, valor total |
| `GEBRELCOMPRAS(cEmpresa)` | `{nForn, nPed, nRecb, nValTot, nCot}` | Fornecedores, pedidos, recebidos, valor, cotações |
| `GEBRELCONTABIL(cEmpresa, cComp)` | `{nLan, nDec, nCred, valDec, valCred, nSaldo}` | Lançamentos por competência |
| `GEBRELGERAL(cEmpresa)` | `{aFiscal, aDerrama, aFin, aEstoque, aCompras, aContabil}` | Consolidado de todos os módulos |
| `GEBRELEMPRESAS()` | `{{COD, NOME, NUSUARIOS, NREGRE}, ...}` | Listagem de todas as empresas |
| `GEBRELUSUARIOS(cEmpresa)` | `{{COD, NOME, PERFIL}, ...}` | Usuários de uma empresa |
| `GEBRELAUDITORIA(cEmpresa, cInicio, cFim)` | `{{DATA, HORA, USUARIO, FUNCAO, IP}, ...}` | Histórico de acesso em GEH |
| `GEBRELMENTOR(cEmpresa)` | `{{evento, modo}, ...}` | Configurações do mentor por empresa |
| `GEBRELCADASTROS(cEmpresa)` | `{nProd, nForn, nCli, nCont}` | Contagem de cadastros ativos |

## 19. Backoffice inspirado no Protheus (estoque/custos, financeiro, contábil, compras, faturamento, frente de loja)

Fontes: `GEBBOLIB`, `GEBCTX`, `GEBEST`, `GEBFNX`, `GEBCPX`, `GEBFAT`, `GEBLOJ`, `GEBBO` (API) e `GEBTUIBO` (telas). Desenho: `documentacao interna`. Os fontes do Protheus 12.1.2510 serviram só de referência de regra; nenhum código foi copiado.

**Regras comuns**
- Tabelas novas no schema da empresa, criadas no primeiro uso. Nenhum `ALTER TABLE` em tabela antiga: dado novo de uma entidade antiga vai em tabela própria.
- Datas em texto `AAAAMMDD`, com aritmética por dia juliano (no AdvPP 4.4.5, `Date + n` devolve data vazia).

**Estoque e custos** (GES1 saldo por produto + armazém; GES2 kardex)
- Custo médio ponderado móvel. Entrada: valor += quantidade × custo, custo médio = valor / quantidade. Saída: sai ao custo médio. Saldo zerado leva o resto do valor (o centavo).
- Saída maior que o saldo é recusada (`GE4 EST_NEGATIVO = S` libera).
- Inventário: a diferença da contagem entra ou sai ao custo médio, com lançamento `EST_AJ_POS`/`EST_AJ_NEG`.
- Transferência entre armazéns ao custo médio da origem.
- A GV1 (saldo das telas antigas) é atualizada junto. **Atenção:** as rotinas antigas (Estoque > Vender e Compras > Dar entrada) só mexem na GV1, sem custo. Para levar o saldo antigo ao custo médio, faça um inventário (`Estoque avançado > Inventário`) informando o custo.

**Financeiro** (GFX1 condições; GFX2 complemento do título; GFX3 baixas; GFX4 movimentos)
- Condição de pagamento = dias das parcelas (`30,60,90`; `0` = à vista).
- Os títulos continuam em GFN2 (receber) e GFN3 (pagar), um por parcela (`DOC/01`, `DOC/02`...). A última parcela fica com o centavo.
- Juros por atraso = saldo × `FIN_JUROS_DIA` (% ao dia, padrão 0,033) × dias. Multa = saldo × `FIN_MULTA` (%, padrão 2). Na baixa parcial, os dois são proporcionais ao principal baixado; os valores podem ser informados à mão.
- Na baixa, o desconto não pode passar do principal. Saldo zerado = RECEBIDA/PAGA.
- Contabilização da baixa: principal líquido (`FIN_REC`/`FIN_PAG`), desconto (`FIN_DESC_CONC`/`FIN_DESC_OBT`) e juros + multa (`FIN_JUROS_REC`/`FIN_JUROS_PAG`). Conta financeira `CAIXA*` = 1.01.001; as demais = 1.01.002.

**Contabilidade** (GC1 plano ampliado; GC4 lançamento padrão por evento; lotes `LP...` em GC2/GC3 na data do fato)
- Cada evento tem conta de débito e de crédito; quem chama pode trocar uma delas (ex.: o banco da baixa).
- Estorno = mesmo evento com as contas invertidas.
- Grupos: 1 ativo, 2 passivo, 3 receitas (3.02 deduções), 4 custos e despesas.
- DRE: receita bruta − deduções − CMV = lucro bruto; + outras receitas − despesas = resultado.

**Compras** (GCQ1 solicitação; GCQ2 complemento do pedido; GCQ3 recebido; GCQ4/GCQ5 documento de entrada)
- A solicitação vira pedidos pelo menor preço cotado (GCP2), um pedido por fornecedor.
- Pedido acima de `COM_ALCADA` (0 = sem alçada) fica PENDENTE até a aprovação (permissão COMPRAS/APROVA).
- Entrada: parcial ou total; o frete é rateado pelo valor dos itens e entra no custo.
- A entrada gera os títulos pela condição do pedido e o lançamento `COMPRA_ESTOQUE`. O pedido fica PARCIAL ou RECEBIDO.

**Faturamento** (GFT1 clientes; GFT2 preços; GFT3/GFT4 pedido; GFT5/GFT6 documento de saída; GFT7 devoluções)
- Preço vazio = tabela do cliente; se não houver, a PADRAO. Desconto % no pedido.
- Liberação: crédito (títulos abertos do cliente + saldo do pedido ≤ limite; limite 0 = sem limite) e estoque. Se falhar, fica BLOQUEADO com o motivo; a liberação forçada exige FATURAMENTO/LIBERA.
- Documento de saída:
  - nota com vários itens (GF3 + GF4), com IBS/CBS pela NCM do produto;
  - saída ao custo médio;
  - títulos pela condição;
  - lançamentos `VENDA_RECEITA` e `VENDA_CMV`;
  - faturamento parcial.
- Devolução: volta ao estoque pelo custo da saída e abate o título aberto da nota (da última parcela para a primeira). O que já foi recebido vira crédito do cliente (`DEVC-...` em GFN3, conta 2.01.003). Lançamentos `DEVOL_VENDA` e `DEVOL_CMV`.

**Frente de loja** (GLJ1 caixas; GLJ2 sessões; GLJ3/GLJ4/GLJ5 cupom, itens e pagamentos; GLJ6 sangria/suprimento)
- Uma sessão aberta por caixa. Desconto em valor, rateado nos itens da NFC-e.
- Formas de pagamento:
  - **dinheiro:** entra na conta do caixa; o troco só pode sair do dinheiro;
  - **PIX:** entra em `LOJ_CONTA_PIX`;
  - **débito e crédito:** viram título da administradora (D+1 e D+30), líquido da taxa `LOJ_TAXA_DEB`/`LOJ_TAXA_CRED`;
  - **fiado:** vira título do cliente (`LOJ_FIADO_DIAS`).
- Cancelamento só na sessão aberta e só se nenhum título do cupom tiver baixa: desfaz estoque, dinheiro/PIX, títulos e lançamentos, e a nota fica CANCELADA.
- Fechamento: esperado = fundo + dinheiro + suprimentos − sangrias − devoluções em dinheiro. A diferença do contado entra ou sai do caixa como movimento avulso.

**Frente de loja ampliada** (19/10/2026; GLJ8–GLJH)
- **Leitura do item:** o caixa aceita:
  - o código do produto;
  - o código de barras cadastrado (GTIN-8/12/13/14 com dígito conferido); o fator multiplica a quantidade, por exemplo uma caixa com 12;
  - a etiqueta da balança: EAN-13 `2` + PLU (5 dígitos) + valor (6) + dígito. Com `LOJ_BALANCA = PRECO` (padrão), o valor é o preço em centavos e a quantidade = valor ÷ preço da tabela. Com `PESO`, o valor é o peso em gramas.
- **Promoções** por produto e vigência:
  - `PRECO`: preço promocional menor que o da tabela;
  - `LEVE`: leve N pague M, com inteiros e M < N;
  - `QTD`: percentual de desconto a partir de N unidades.
  - Vale a que deixar o item mais barato. A promoção só se aplica quando o preço não é informado. O desconto de cada promoção fica registrado no cupom (GLJA).
- **Desconto:**
  - acima de `LOJ_DESC_MAX` (% do bruto; vazio = sem limite), só passa se o operador da sessão tiver a permissão LOJA/DESCONTO, ou se um supervisor com essa permissão digitar a senha;
  - a senha errada conta como tentativa de login (bloqueio em 5);
  - quem liberou fica gravado no cupom.
- **Vendedor e CPF/CNPJ na nota:** opcionais e validados (vendedor cadastrado; dígitos verificadores certos).
- **Orçamento (pré-venda):**
  - congela o preço do dia, com a promoção, e vale `LOJ_ORC_DIAS` dias (padrão 7);
  - o caixa finaliza com os pagamentos e ele vira cupom. Se o cupom for cancelado, o orçamento volta a ficar aberto;
  - não reserva estoque.
- **Devolução e troca no caixa:**
  - pede a sessão aberta, sobre um cupom vendido;
  - devolve até o que falta devolver de cada produto, pelo valor líquido do desconto (a última devolução leva o centavo que sobra);
  - o estoque volta pelo custo da saída;
  - entra em GFT7, então abate o IBS/CBS na apuração e a receita do Simples;
  - **dinheiro:** sai da gaveta (D 3.02.001 / C caixa) e só se houver dinheiro esperado suficiente;
  - **vale-troca:** fica em GLJF, com D 3.02.001 / C 2.01.003 (crédito do cliente);
  - cupom com devolução não pode mais ser cancelado.
- **Pagamento com vale (`VALE`):**
  - abate o saldo do vale (D 2.01.003 / C receita, evento `LOJ_VALE`);
  - o troco continua só em dinheiro;
  - cancelar o cupom devolve o saldo ao vale.
- **Relatórios:**
  - gerencial por dia, caixa, operador ou vendedor: cupons, cancelados, vendas, descontos, ticket médio, devoluções e líquido;
  - comissão por vendedor: (vendas − devoluções do período) × percentual. A comissão sai só no relatório: não gera título a pagar.

**Lote, série e endereço** (GES3 controle do produto; GES4 saldo por lote/endereço; GES5 endereços; GES6 detalhe de cada movimento)
- O controle só muda com o produto sem saldo (rastro N, L ou S; endereço S/N).
- A entrada exige lote (série = uma unidade por série, sem repetir série em estoque) e endereço cadastrado.
- A saída sem lote informado usa FEFO (vence primeiro, sai primeiro) e não usa lote vencido (`EST_VENCIDO = S` libera); lote vencido informado é recusado.
- Devolução e estorno voltam pelos lotes do documento de origem, menos o que já voltou.
- Transferência de armazém leva os mesmos lotes, com endereço de destino opcional. Mudança de endereço não mexe no custo.
- O custo continua sendo o médio do produto no armazém.

**Fechamento mensal** (GES7, como a virada de saldo do Protheus)
- Grava o saldo de cada produto/armazém no fim do mês, pelo kardex, e bloqueia movimentos com data até ele.
- Fecha em ordem, e o mês corrente não fecha. Só reabre o último mês fechado.
- O relatório confere saldo inicial + entradas − saídas = final.

**Devolução de compra** (GCQ6)
- Sai pelos lotes e pelo custo da entrada (com o frete rateado).
- Emite nota tipo DEVC, que não conta como receita no Simples.
- Abate o título a pagar aberto da nota (da última parcela para a primeira). O que já foi pago vira crédito com o fornecedor (GFN2 `DEVF-...`, conta 1.01.006).
- Lançamento `DEVOL_COMPRA`.

**Centro de custo** (GCC1 centros; GCC2 rateios em %, somando 100; GCX1 centro de cada lote contábil)
- O lançamento padrão recebe um centro ou um rateio. No rateio, sai um lote por centro e o último fica com o centavo. Centro bloqueado é recusado.
- O centro chega pelo movimento avulso, pela despesa a pagar (`FIN_DESPESA`), pelo pedido de venda (receita, CMV e devolução) e pelo caixa da loja.
- Balancete e DRE podem ser filtrados por centro. O resultado por centro inclui a linha "(sem centro)".

**Banco** (GBC1 cobrança da conta; GBC2 boletos; GBC3 extrato importado)
- **Boleto:** padrão FEBRABAN (44 posições, DV geral módulo 11, linha digitável módulo 10, fator de vencimento com o reinício de 22/02/2025). O campo livre e o nosso número seguem cada banco:

  | Banco | Nosso número | Campo livre | Conferido com |
  |---|---|---|---|
  | 001 Banco do Brasil | convênio 7 + sequência 10 (sem DV) | `000000` + convênio + sequência + carteira | exemplo do brcobranca |
  | 033 Santander | sequência 12 + DV mód. 11 (pesos 2–9) | `9` + código 7 + NN 13 + `0` + carteira | manual v36 |
  | 104 Caixa | `14` + sequência 15 + DV mód. 11 | beneficiário 6 + DV + NN intercalado + DV | manual SIGCB |
  | 237 Bradesco | carteira + sequência 11 + DV | agência + carteira + NN + conta + `0` | cálculo independente |
  | 341 Itaú | carteira + sequência 8 + DAC mód. 10 | carteira + NN + DAC + agência + conta + DAC + `000` | manual CNAB 400 |
  | 756 Sicoob | sequência 7 + DV (pesos 3, 1, 9, 7) | carteira + cooperativa + modalidade + cliente + NN + parcela `001` | exemplo do brcobranca |

  No Itaú, as carteiras 126, 131, 145, 146, 150 e 168 calculam o DAC só com carteira + nosso número. Banco do Brasil e Sicoob foram conferidos só pela biblioteca brcobranca (o manual do BB não estava acessível): **confira com o banco antes do primeiro boleto real.**
- **CNAB 240 FEBRABAN (v10.3)**, para todos os bancos: header de arquivo e de lote, segmentos P e Q por boleto, trailers. O retorno lê os segmentos T e U e baixa as ocorrências 06 e 17. O nosso número vai alinhado à esquerda nas posições 38–57; como alguns bancos usam esse campo de outro jeito, o retorno aceita a sequência, a sequência com DV ou o nosso número completo.
- **CNAB 400:** Itaú (baixa 06, 07, 08) e Bradesco (baixa 06, 15, 17). A ocorrência 15 do Itaú não baixa (é outra coisa no Itaú). As demais ocorrências são ignoradas.
- **Antes do primeiro arquivo real de cada banco, confira as posições com o manual vigente e faça a homologação com o banco.**
- **OFX:** importa sem repetir FITID e concilia sozinho por mesmo valor e sentido, com data a até `BCO_DIAS_CONC` dias. A conciliação manual também pode ser desfeita. A linha que só existe no banco (tarifa) vira movimento avulso conciliado.

**TEF** (GLJ7)
- O fluxo tem duas fases: os cartões são autorizados antes de gravar a venda e confirmados depois. Se algum for negado, os aprovados são desfeitos e nada é gravado.
- O cancelamento do cupom estorna na adquirente; se ela recusar, o cupom não é cancelado.
- Pendências são desfeitas na abertura do caixa. O crédito parcela em até 12×, em títulos de 30 em 30 dias.
- Provedores:
  - `SIMULADOR`: nega centavos 51;
  - `HTTP`: contrato JSON com autorizar/confirmar/desfazer/cancelar, Bearer token e tempo limite;
  - `CIELO`: API Cielo e-Commerce 3.0. Autorizar = venda sem captura (`POST /1/sales`); confirmar = captura; desfazer = `void`; cancelar = `void` com o valor. O débito vai como crédito à vista. Como a API é de venda não presencial, o número do cartão vem do parâmetro `LOJ_CIELO_CARTAO`: serve para a sandbox e para o emulador, **não para cobrar de verdade**. Uma loja física de verdade precisa de um terminal (Cielo LIO, SiTef, PayGo) ligado pelo provedor `HTTP`.
- Emulador local da Cielo em `tests/emuladores/cielo_emulador.py`: imita a sandbox, sem internet nem credenciais. Para testar na sandbox real, cadastre-se em <https://docs.cielo.com.br/ecommerce-cielo/page/sandbox-api-ecommerce> e informe MerchantId e MerchantKey.

**Simples Nacional:** devoluções de venda (GFT7) deduzem a receita do mês no mesmo balde da venda e reduzem o RBT12 dos meses seguintes. A sobra sem receita gera aviso.

**Fora do escopo:**
- bancos além de BB, Santander, Caixa, Bradesco, Itaú e Sicoob;
- CNAB 400 de bancos além de Itaú e Bradesco;
- registro de boleto por API (PIX/boleto híbrido);
- custo por lote;
- inventário rotativo;
- terminal físico de cartão (o provedor `CIELO` usa a API de e-commerce).

*Documento gerado a partir do design aprovado, dos planos e dos 38 fontes `src/*.prw`. Divergência entre este texto e o fonte? Abra o `.prw` indicado — ele é a Constituição; isto aqui é o jornal das Bananias.*

## 20. Integração entre os módulos (19/10/2026)

Desenho: `documentacao interna`. Regra geral: **o que gera título ou guia aparece no financeiro; o que gera tributo a reter, recolher ou pagar aparece na Derrama; todo fato passa pelo contábil com o lançamento padrão do seu evento.**

| Origem | Financeiro | Derrama | Contábil |
|---|---|---|---|
| Nota avulsa (`GEBFEMI`) | Título a receber `CONSUMIDOR` à vista | IBS/CBS na apuração (se autorizada) | `VENDA_RECEITA` |
| Venda do balcão (`GEBVVEN`) | Título recebido na hora no `CAIXA` | Pela nota | `VENDA_RECEITA`, `VENDA_CMV`, `FIN_REC` |
| Fiado do balcão (`GEBVFIA`) | Título `FIA-<registro>` | — | `VENDA_RECEITA` |
| Faturamento, loja, compras novas | Títulos pela condição | IBS/CBS (débito nas notas, crédito nas entradas) | Eventos de cada módulo |
| Entrada antiga (`GEBCMENT`) | Pelo documento de entrada | Crédito de IBS/CBS | `COMPRA_ESTOQUE` |
| Títulos avulsos (`GEBFNREC`/`GEBFNPAG`) | Pelo `GEBFXTIT` | — | `FIN_RECEITA` / `FIN_DESPESA` |
| Apuração do IBS/CBS (REGULAR) | Título da guia | `GD<comp>` | `APU_IBSCBS` |
| Simples Nacional | Títulos das guias | `DAS-`, `ICMS-`, `ISS-<comp>` | `SN_DAS`, `SN_FORA` |
| Retenções na entrada | Abate o título do fornecedor; título da guia | `RET-<tributo>-<comp>` | `RET_FORN` |

**Retenções** (`GEBRET.prw`), feitas pela empresa como tomadora:
- Regras em GRT1: código, tributo (ISS, IRRF, INSS, PIS, COFINS, CSLL) e alíquota. No máximo uma por tributo em cada documento, e a soma das alíquotas abaixo de 100%.
- Na entrada de compra, cada código retém base (total da nota) × alíquota. O valor sai do título do fornecedor a partir da primeira parcela aberta, vai para 2.01.005 (D fornecedores / C tributos retidos a recolher) e acumula na guia `RET-<tributo>-AAAAMM`, com vencimento no dia `RET_DIA_<tributo>` (padrão 20) do mês seguinte em dia útil.
- Relatório: retenções do mês por documento, tributo e guia.
- Fora do escopo: retenção sofrida (quando o cliente retém).

**Correção dos lançamentos antigos** (`GEBCTXCORRIGE`, Contábil avançado ou `POST /api/bo/contabil/corrigir-legado`):
- Antes da integração, o lançamento antigo procurava a regra pelo número do documento e caía no `PADRAO` (D Caixa / C Receita): pagar guia ou fornecedor virava receita.
- A rotina reconhece esses lotes pelo documento: guia paga, entrada de compra (o primeiro lote é a entrada, os seguintes são pagamentos), título a pagar e título a receber dos módulos novos.
- Para cada um, lança o estorno (`ESTORNO:<lote>`, mesma data) e o lançamento certo. Venda à vista, nota e receber antigo ficam como estão, porque a receita no caixa está certa.
- Pode rodar de novo sem duplicar. Em 19/10/2026 a produção não tinha lançamentos a corrigir.

**Simplificação:** o crédito de IBS/CBS das compras reduz o imposto a recolher, mas o estoque continua ao custo cheio (sem separar o tributo recuperável).

## 21. Documentos fiscais eletrônicos: NFC-e real (19/10/2026)

**Princípio:** com a NFC-e ligada (`DFE_NFCE = S`), **não existe venda sem documento fiscal**. Sem a NFC-e ligada, a loja continua na emissão interna de antes, e o roteiro mostra isso.

**Emissão**, em `GEBLOJVEN`, depois do TEF e antes de gravar qualquer coisa:

| Resultado da SEFAZ | O que acontece |
|---|---|
| 100/150 (autorizada) | A venda é gravada. O livro interno (GF3/GF4) recebe a chave de acesso e fica `AUTORIZADA`. |
| Rejeição (2xx, 3xx, 4xx, 5xx, 7xx...) | A venda **não** é gravada, o TEF é desfeito e o caixa vê "nfce_rejeitada: cStat - motivo". O número fica "a inutilizar". Uma recusa local (NCM, CFOP ou CSOSN inválidos) não chega a gastar número. |
| Denegada (110, 301, 302, 303) | Igual à rejeição, mas o número fica consumido. |
| Sem comunicação, ou SEFAZ paralisada (108/109) | Contingência offline: mesmo número, `tpEmis 9`, `dhCont`/`xJust`, QR Code assinado. A venda é gravada com o livro `CONTINGENCIA` (fora da apuração até autorizar). Transmitir em até 24 h. |

**Contingência:**
- `GEBDFETRANSMITE` envia as pendentes. Autorizada: documento e livro ficam `AUTORIZADA`.
- **539** (duplicidade com outra chave) quer dizer que a tentativa online tinha chegado e sido autorizada. O GEBAN consulta essa chave e adota a autorização dela: chave, protocolo, livro e cupom. A contingência fica `SUBSTITUIDA`.
- Outra rejeição: `REJEITADA_CONTINGENCIA`. Isso exige correção do cadastro e reemissão, e é item `FALTA` do roteiro.

**QR Code:**
- Versão 3 por padrão (NT 2025.001):
  - online: `chave|3|tpAmb`, sem CSC;
  - offline: `chave|3|tpAmb|dia|vNF|tp_idDest|idDest|assinatura`, com RSA-SHA1 em Base64 da cadeia sem a assinatura.
- `DFE_QR_VERSAO = 2` usa o CSC (hash SHA-1, como a NT 2017).

**Itens:**
- O valor unitário é o preço praticado (tabela ou promoção).
- O desconto do cupom é rateado nos itens como antes. `vDesc` = bruto − líquido do item; se o arredondamento gerar −0,01 num item, o centavo vai para o item de maior desconto.
- `vNF` = Σ vProd − Σ vDesc = total do cupom.
- Em homologação, o 1º item sai com o texto obrigatório "NOTA FISCAL EMITIDA EM AMBIENTE DE HOMOLOGACAO - SEM VALOR FISCAL".

**Pagamentos:**

| Forma no caixa | tPag |
|---|---|
| Dinheiro | 01, o troco vai em `vTroco` |
| Crédito | 03 |
| Débito | 04 |
| Fiado e vale-troca | 05, crédito loja |
| PIX | 17 |

Cartão e PIX levam o grupo `card`: TEF Cielo = integrado (`tpIntegra 1`, CNPJ da Cielo, bandeira e autorização); simulador e PIX = `tpIntegra 2`.

**Regimes:**
- Simples (CRT 1) e MEI (CRT 4): CSOSN 101, 102, 103, 300, 400, 500 ou 900; PIS/COFINS com CST 49 por padrão, sem valor.
- Regime normal (CRT 3): CST 00 com a alíquota do perfil, ou 40, 41, 50, 60.
- Substituição tributária com cálculo (CSOSN 201–203, CST 10/70) ainda não é aceita: o cadastro recusa.

**Cancelamento:**
- Evento 110111, só de documento `AUTORIZADA`, dentro de `DFE_CANC_MIN` minutos (padrão 30) desde a autorização. Justificativa de 15 a 255 letras. Fora do prazo: devolução.
- No caixa, o cancelamento fiscal vem antes de desfazer a venda.

**Inutilização:** de faixa, ou de todos os números rejeitados pendentes. Uma faixa com número já autorizado é recusada pela SEFAZ (241).

**Emitente e certificado:**
- CNPJ e IE conferidos pelos dígitos verificadores (IE pelo algoritmo da UF); o município tem de ser da UF.
- O certificado precisa ter a mesma raiz de CNPJ do emitente, estar no prazo e ter chave e certificado do mesmo par.
- O roteiro avisa 30 dias antes do vencimento.

**Hora:** `dhEmi` é a hora local da UF do emitente, calculada do UTC (a SEFAZ recusa atraso de mais de 5 minutos na NFC-e). Fusos: AC −05:00; AM, RO, RR, MT, MS −04:00; demais −03:00.

### 21.1 NF-e modelo 55

- **Cadastro fiscal do participante:** a NF-e exige um cadastro fiscal completo do cliente ou fornecedor, sem o qual o faturamento é recusado. Esse cadastro tem:
  - CPF/CNPJ com DV;
  - indicador de contribuinte: 1 (com IE válida na UF), 2 isento, 9 não contribuinte;
  - endereço com município IBGE.
- **Destino e consumidor final:**
  - Mesma UF: `idDest 1` e CFOP 5xxx. Outra UF: `idDest 2` e CFOP 6xxx (o 5 do perfil vira 6).
  - Não contribuinte: `indFinal 1`.
  - No regime normal, a alíquota interestadual é 4% para mercadoria importada (origem 1, 2, 3 ou 8), 7% do S/SE (sem o ES) para N/NE/CO/ES e 12% nos demais casos.
  - Venda a não contribuinte de outra UF no regime normal (DIFAL) é recusada: ainda não é calculada.
- **Simples:** o GEBAN acrescenta "DOCUMENTO EMITIDO POR ME OU EPP OPTANTE PELO SIMPLES NACIONAL. NAO GERA DIREITO A CREDITO FISCAL DE IPI." (Res. CGSN 140, art. 59).
- **Pagamento e cobrança:**
  - Venda a prazo (mais de uma parcela ou vencimento futuro): `indPag 1` e duplicatas 001, 002...
  - À vista: `indPag 0`, sem duplicata (NT 2025.001 recusa duplicata à vista).
  - Devoluções: `tPag 90`, sem pagamento.
- **Devolução de venda:**
  - O contribuinte devolve com a NF-e dele: a chave é obrigatória e fica vinculada.
  - Consumidor e não contribuinte: o GEBAN emite a NF-e de entrada (finalidade 4, CFOP 1202/2202, CSOSN 900 no Simples, PIS/COFINS 98, nota original referenciada).
- **Devolução de compra:** NF-e de saída, finalidade 4, CFOP 5202/6202, referenciando a NF-e do fornecedor. A chave vem da entrada ou é informada na devolução.
- **Sem contingência offline:** na NF-e não existe a contingência offline da NFC-e, porque o tpEmis 9 é só da NFC-e.
  - Sem resposta da SEFAZ, o documento fica `PENDENTE` e a operação não é gravada.
  - "Resolver pendentes" consulta cada chave:
    - autorizada (a SEFAZ recebeu, mas a resposta se perdeu): cancela, porque não há venda ligada a ela;
    - não consta (217): o número vai para inutilizar.
  - Depois disso, a operação pode ser repetida.
- **Carta de correção:**
  - só para NF-e autorizada;
  - texto de 15 a 1000 letras, até 20 por nota; a última vale;
  - não corrige valores, impostos, quantidades, datas nem as partes. O texto legal de condição de uso vai no evento.

### 21.2 Devolução de NFC-e no caixa, DIFAL e ICMS ST (19/10/2026)

- **Devolução de cupom com NFC-e autorizada:**
  - O caixa emite uma NF-e de entrada (modelo 55, finalidade 4, CFOP 1202/2202, CSOSN 900, PIS/COFINS 98) que referencia a NFC-e, antes de mexer no estoque, no vale ou na gaveta. Se a SEFAZ recusar, nada é gravado.
  - O consumidor precisa estar identificado: CPF/CNPJ, nome e endereço. Ele fica no cadastro fiscal como tipo `L`, e da próxima vez basta o CPF (ou o CPF já informado no cupom).
  - NFC-e em contingência não pode ser devolvida antes de ser transmitida.
- **DIFAL** (EC 87/2015, LC 190/2022):
  - Aplica-se na venda do regime normal a não contribuinte de outra UF. O ICMS próprio usa a alíquota interestadual, e o grupo `ICMSUFDest` vai por item:
    - base única: DIFAL = V × (interna − interestadual);
    - base dupla (`DFE_DIFAL_BASE_DUPLA_<UF> = S`): BC = (V − V × inter) / (1 − interna) e DIFAL = BC × interna − V × inter;
    - FCP = BC × FCP do destino.
  - A alíquota interna padrão vem da tabela de 2026: SP 18, RJ 20 (+2 FCP), MG 18, PR 19,5, RS 17, SC 17, BA 20,5, MA 23, PI 22,5, AL 20,5, SE 19 (+1 FCP) etc. Cada UF é ajustável por `DFE_ALIQ_INT_<UF>` e `DFE_FCP_<UF>`, porque as fontes divergem em BA, MA, PI, RO, SE e PR; confira com a SEFAZ de destino.
  - Autorizada a nota, o GEBAN gera o título a pagar `DIFAL-<UF>-<n>` para `SEFAZ-<UF>` (conta 2.01.006) e lança `SN_FORA`.
  - O Simples continua fora do DIFAL (STF, ADI 5464).
- **ICMS ST por MVA**, só na NF-e:
  - CSOSN 201 (com crédito), 202 e 203, e CST 10:
    - BCST = (V × (1 + MVA)) × (1 − redução da BC ST);
    - ST = BCST × alíquota ST − ICMS próprio (V × alíquota do produto);
    - o `vST` soma no `vNF`.
  - CST 20: BC = V × (1 − redução).
  - Os dados ficam no perfil fiscal do produto (`RED_BC`, `MVA`, `ALIQ_ST`, `RED_BC_ST`, na tabela GDFA).
  - Na NFC-e, ST com cálculo é recusada: use CSOSN 500 ou CST 60.

### 21.3 IBS/CBS no XML e tributos aproximados (Lei 12.741)

- **IBS/CBS** (NT 2025.002):
  - Com `DFE_IBSCBS = S`, cada item leva o grupo `IBSCBS`, e o total leva o `IBSCBSTot`. Por padrão ele vem ligado só no regime normal (CRT 3); no Simples a obrigação começa depois.
  - O grupo tem CST `DFE_IBSCBS_CST` (padrão 000), cClassTrib `DFE_CCLASSTRIB` (padrão 000001) e base = valor do item.
  - As alíquotas vêm da GF2 (alíquota vigente da NCM, a mesma da apuração). Cadastre as de 2026, CBS 0,9 e IBS 0,1.
  - O IBS vai para a UF; `DFE_IBS_MUN_PCT` reparte uma parte para o município.
  - Em 2026 o IBS/CBS não soma no `vNF`.
- **Tributos aproximados** (Lei 12.741/2012):
  - Use a tabela do IBPT da UF do emitente: o CSV oficial importado pela página de configuração ou pela rota `dfe/ibpt`.
  - Por item: federal (nacional ou importado, pela origem do produto), estadual e municipal sobre o valor do item, em `vTotTrib`.
  - Na NFC-e e na NF-e de venda vai o texto "Trib aprox R$ X Federal, R$ Y Estadual, R$ Z Municipal. Fonte: IBPT <versão>".
  - NCM fora da tabela fica sem o valor. O roteiro avisa quando a tabela da UF não foi importada.

### 21.4 NFS-e no padrão nacional (Sefin Nacional / ADN)

- **Pré-requisitos:**
  - inscrição municipal do emitente;
  - serviço fiscal cadastrado com o código de tributação nacional de 6 dígitos (item, subitem e desdobro da LC 116) e, se houver, o código municipal (3 dígitos) e a NBS (9 dígitos);
  - `DFE_NFSE = S`.
- **DPS** (leiaute 1.01):
  - Id `DPS` + município (7) + tipo de inscrição + CNPJ (14) + série (5) + número (15).
  - O prestador vai com o regime: Simples ME/EPP = `opSimpNac 3` com `regApTribSN` (`DFE_NFSE_REGAPSN`, padrão 1); MEI = 2; regime normal = 1.
  - O tomador vem do cadastro fiscal (opcional).
  - Município da prestação = o do emitente, salvo informado.
  - Desconto incondicionado.
  - ISS: `tribISSQN 1`. Se retido pelo tomador, `tpRetISSQN 2` e a alíquota do serviço; senão 1, e a alíquota sai dos parâmetros municipais.
  - Tributos totais: `pTotTribSN` (`DFE_NFSE_PTOTTRIBSN`) no Simples, senão `indTotTrib 0`.
- **Envio:** assinada como a NF-e (RSA-SHA1, C14N, namespace `http://www.sped.fazenda.gov.br/nfse`), compactada em gzip + Base64 dentro de JSON, `POST {sefin}/nfse` com o certificado A1.
  - 201: NFS-e gerada (chave de 50 posições, XML guardado).
  - 400: rejeitada, com o código e a descrição da Sefin; nada é gravado.
  - Sem resposta: `PENDENTE`. "Resolver pendentes" consulta pelo Id da DPS: gerada sem operação é cancelada; não consta é liberada.
- **Faturamento de serviço** (`GEBFATSERV`):
  - NFS-e;
  - livro GF3/GF4 tipo `NFE` com o código do serviço, para entrar no Simples e na apuração (cadastre a atividade/anexo do serviço no Simples);
  - títulos a receber pela condição;
  - `VENDA_RECEITA`.
- **Cancelamento:** evento e101101 com motivo 1 (erro), 2 (não prestado) ou 9 (outros) e justificativa de 15 a 255 letras.
- **DANFSe:** o oficial em PDF, baixado do ADN (`/api/dfe/danfe?chave=<50 dígitos>`).
- **Endereços:** produção restrita em homologação e produção conforme `DFE_AMBIENTE`; `DFE_URL_SEFIN` e `DFE_URL_ADN` sobrepõem (municípios com endereço próprio).

### 21.5 Recebimento de NF-e de fornecedores

- **Busca** (distribuição de DF-e do Ambiente Nacional):
  - a partir do último NSU (`DFE_ULTNSU`), em lotes, até alcançar o máximo;
  - resumo da nota (`resNFe`) entra como "recebida", e o cancelamento feito pelo emitente marca a nota como `CANCELADA`;
  - "nada novo" (137) encerra; 656 (consumo indevido) avisa que a SEFAZ pede uma hora entre consultas sem novidade.
- **Manifestação:**
  - ciência (210210), confirmação (210200), desconhecimento (210220), operação não realizada (210240, com justificativa);
  - ciência e confirmação baixam a nota completa (`procNFe`) logo em seguida.
- **Importação:**
  - Só da nota completa e autorizada, uma vez por nota.
  - Fornecedor pelo CNPJ; se não existir, é criado (`F` + 8 últimos dígitos do CNPJ) com o nome da nota.
  - Cada item precisa do de-para "código do fornecedor → produto do GEBAN × fator" (ex.: caixa com 12 → fator 12). Se faltar algum, a importação lista os códigos.
  - Sem pedido informado, o GEBAN gera um pedido da própria nota (`PN` + final da chave; sujeito à alçada) e faz a entrada com quantidade × fator, valor líquido do item e frete da nota.
  - A chave fica vinculada à entrada, pronta para a devolução de compra.
- **Assinatura:** o GEBAN não confere a assinatura da nota do fornecedor; a SEFAZ já a validou ao autorizar.

### 21.6 SPED Fiscal: EFD ICMS/IPI (19/10/2026)

- **Quem entrega:** regime normal (CRT 3) e Simples com excesso de sublimite (CRT 2). Simples Nacional só gera com `DFE_EFD_SIMPLES=S` (quando a UF obriga).
- **Leiaute:** COD_VER pelo ano da competência (2024 = 018, 2025 = 019, 2026 = 020, 2027 em diante = 021); `DFE_EFD_CODVER` sobrepõe.
- **De onde vem:** só dos XML guardados, no ambiente configurado (`DFE_AMBIENTE`).
  - Notas próprias (NF-e e NFC-e, saída ou entrada): C100 + C190, e C101 quando há DIFAL. Não há C170: o Guia dispensa os itens da NF-e de emissão própria.
  - Cancelada (02), denegada (04) e número inutilizado (05, pela data do protocolo): C100 só com a identificação. Rejeitadas e substituídas ficam fora.
  - Entrada de fornecedor: só a importada com a nota completa (vínculo da chave + entrada + XML). C100 + C170 com o código do produto do GEBAN (de-para), C190, 0150 do fornecedor, 0190/0200 e 0220 quando a unidade da nota difere da do produto (fator do de-para).
  - CFOP de entrada: 5/6/7 viram 1/2/3; compra para revenda vira x102 e com ST x403.
  - Crédito: o ICMS destacado nos CST 00, 10, 20, 51, 70 e 90. CSOSN de fornecedor do Simples vira CST x90 sem crédito (o crédito do art. 23 da LC 123 não é lançado).
- **Recusas:** documento em contingência ou pendente na competência, contabilista incompleto (nome, CPF, CRC, e-mail, município), item de fornecedor sem de-para, ICMS a recolher sem código de receita.
- **Apuração:**
  - E110: débitos = ICMS dos C190 com CFOP 5/6/7; créditos = os demais; saldo credor anterior = o transportado do arquivo da competência anterior (ou `DFE_EFD_SLD_CRED_INI` antes do primeiro).
  - E116 (código 000) com o ICMS a recolher, vencimento no dia `DFE_EFD_DIA_VENC` do mês seguinte.
  - ST retido nas saídas: E200/E210/E250 por UF (código 002 na própria UF, 999 em outra).
  - DIFAL e FCP de venda a consumidor de outra UF: E300/E310/E316 por UF de destino (códigos 000 e 006).
- **Sem movimento:** blocos B, D, G, H e K; 1010 todo "N". Fevereiro avisa que o inventário de 31/12 (bloco H) deve ser informado no PVA.
- **Avisos:** entradas sem XML completo ou sem chave aparecem na mensagem e ficam fora do arquivo.
- **Arquivo:** pipes, decimal com vírgula, datas DDMMAAAA, CRLF, texto sem acento. Guardado por competência (GDFG); gerar de novo substitui. A validação e a transmissão são do PVA da Receita.
