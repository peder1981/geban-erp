# GEBAN — Manual de Utilização (para MEI)

> **Para operar pela interface web, use o [Manual do usuário](08-manual-do-usuario.md)**
> (também em PDF), com o passo a passo de todas as telas e capturas anotadas.
> Este documento continua valendo para os conceitos e para o uso pela linha de comando.

> Linguagem simples, sem jargão escondido. Toda palavra difícil vem com explicação na hora.
> Público: você que vende banana (ou qualquer produto) e precisa emitir nota, pagar imposto e fechar o mês sem dor de cabeça.

**O que é o GEBAN?** Um programinha de gestão ("ERP", que é só um nome chique para "sistema que junta vendas + estoque + imposto + contas"). Ele roda no seu computador usando dois programas: **AdvPP** (o motor que entende a linguagem) e **advplc** (o comando que você digita para rodar, conferir e abrir o sistema).

**Atualização:** o sistema agora suporta **múltiplas empresas** (você pode ter a banquinha da esquina E o mercadão no mesmo banco, isolados) e uma **interface web com dashboard** (além do menu terminal clássico).

**Palavras que vão aparecer muito (cola aqui):**

- **AdvPP / advplc** — AdvPP é o motor; advplc é o comando que você digita no terminal (aquela tela preta).
- **serve** — modo que abre o GEBAN no navegador (como um site, mas rodando na sua máquina).
- **NCM** — código de 8 números que diz o que o produto é para o imposto. Ex.: banana tem um NCM, sabão tem outro. Você cadastra uma vez.
- **NF-e** — Nota Fiscal eletrônica (o recibo oficial da venda, que vai para o governo).
- **SEFAZ** — o computador do governo que autoriza a nota. Se ele está "fora do ar", a nota não autoriza na hora.
- **IBS + CBS** — os dois impostos novos que somem na nota. O sistema calcula sozinho: `IBS = base x alíquota / 100`.
- **Apurar o mês** — somar todo o imposto do mês para saber quanto pagar.
- **Guia / DARF** — o boleto do imposto. No GEBAN a guia se chama `GD + mês` (ex.: `GD202609`).
- **Mentor** — um guardião dentro do sistema. Ele avisa ou trava uma ação perigosa (ex.: vender sem pensar, lançar direto no contas). Quando ele "avisa", você decide.
- **Fila (GE5)** — caderninho de "pendências". Quando a internet cai ou a SEFAZ trava, a nota entra na fila como `PENDENTE` e você resolve depois. Nada se perde.
- **Competência (AAAAMM)** — o mês no formato ano+mês. Ex.: setembro de 2026 = `202609`.
- **Fiado** — vender para receber depois. Tem limite de R$ 1.000 por cliente.
- **Lançamento direto** — mexer direto nos contas (só para quem sabe o que está fazendo, e com permissão).
- **Conta (GFN1)** — pote de dinheiro. A principal se chama `CAIXA`. Toda baixa de receber/pagar mexe na `CAIXA`.
- **Receber (GFN2) / Pagar (GFN3)** — caderninhos de "tenho para receber" e "tenho para pagar". Cada linha tem documento, valor, saldo e estado (`ABERTO`, `RECEBIDA`/`PAGA`).
- **Baixa** — marcar que o dinheiro entrou ou saiu (total ou aos poucos). Cada baixa grava um movimento (GFN4).
- **Fluxo de caixa** — conta rápida: quanto tenho para receber, quanto para pagar e o saldo (receber menos pagar).
- **Fornecedor (GCP1)** — de quem você compra (ex.: atacadão).
- **Cotação (GCP2)** — preço que cada fornecedor cobra pelo produto. Serve para comparar e pegar o menor.
- **Pedido (GCP3+GCP4)** — papel de compra: cabeçalho (número + fornecedor) mais itens (produto + quantidade + preço).
- **Entrada / NF de entrada (GCP5)** — quando a mercadoria chega com a nota do fornecedor. Dá entrada no estoque e cria a conta a pagar sozinha.
- **Balancete / DRE** — dois relatórios: balancete mostra quanto entrou e saiu por conta; DRE mostra se deu lucro ou prejuízo (receitas menos despesas).

---

## 1. Instalar o AdvPP + advplc (uma vez só)

Passo a passo:

1. Abra o terminal (tela preta do Linux).
2. Confira se o `advplc` já existe:
   ```bash
   advplc version
   ```
   Se aparecer algo como `advplc v4.0.1`, está pronto. Pule para o capítulo 2.
3. Se disser "comando não encontrado", instale. O jeito mais comum (Linux):
   ```bash
   # Baixe a versão do seu computador (exemplo Linux 64 bits) e instale
   # Troque o link pela versão atual que o técnico te passar
   curl -sL <link-do-instalador-advpp> -o /tmp/advpp-install.sh
   bash /tmp/advpp-install.sh
   advplc version
   ```
   > Não entendeu o link? Peça ao técnico o "instalador do AdvPP para o meu sistema". Ele te passa um arquivo, você clica e instala.
4. Confira que o motor funciona:
   ```bash
   advplc check src/GEBTUI.prw --include src
   ```
   Se não mostrar erro, está tudo certo.

**Onde fica o banco?** O GEBAN guarda tudo num banco **Postgres** (não é mais um arquivinho único tipo SQLite). Cada empresa tem seu próprio "compartimento" isolado dentro do mesmo banco (chamado de "schema"). Quem configura a conexão é o técnico, através de 5 variáveis de ambiente: `GEBAN_PG_HOST` (endereço do servidor), `GEBAN_PG_PORT` (porta), `GEBAN_PG_DB` (nome do banco), `GEBAN_PG_USER` e `GEBAN_PG_PASSWORD` (usuário e senha de acesso ao Postgres — não confundir com o seu usuário/senha de login no GEBAN, capítulo 18). Você não precisa mexer nisso no dia a dia; só precisa saber que não existe mais `geban.db` nem a flag `--db-path`.

---

## 2. Conferir que está tudo certo (check) e rodar (run)

Você tem 3 comandos principais. Decore estes 3:

```bash
# 1) Conferir se o código está sem erro (não roda, só confere)
advplc check src/GEBTUI.prw --include src

# Conferir vários arquivos de uma vez
advplc check src/GEBTUI.prw src/GEBWEB.prw --include src

# 2) Rodar um programa direto no terminal (ex.: a API REST, porta 8090)
advplc run src/GEBWEB.prw

# 3) Abrir no navegador (jeito normal de usar todo dia) — veja capítulo 3
advplc serve src/GEBTUI.prw --port 8081
advplc serve src/GEBTUI.prw --port 8081 --watch
```

- `check` = "está tudo escrito certo?".
- `run` = "roda agora no terminal e mostra o resultado".
- `serve` = "abre como site no navegador para clicar".

> Dica: `--include src` (no `check`) diz onde estão os outros arquivos. `--watch` faz recarregar sozinho quando o técnico muda algo. `--port 8081` escolhe a porta (a "porta" é só o número do endereço local). As 5 variáveis `GEBAN_PG_*` (capítulo 1) precisam estar configuradas no ambiente **antes** de rodar `run`/`serve` — sem elas, o GEBAN não consegue conectar no banco.

---

## 3. Abrir o sistema todo dia (serve + porta)

1. No terminal, entre na pasta do GEBAN (com as variáveis `GEBAN_PG_*` já configuradas — capítulo 1):
   ```bash
   advplc serve src/GEBTUI.prw --port 8081
   ```
2. Abra o navegador e digite:
   ```
   http://localhost:8081
   ```
   > `localhost` significa "minha própria máquina". `8081` é a porta que você escolheu. Se ela estiver ocupada (mensagem de erro), troque para 8082, 8083, etc.
3. Na primeira vez o sistema cria o catálogo sozinho (conexão Postgres + tabelas compartilhadas `GE1`/`GE2`/segurança). Você vai ver mensagens como:
   ```
   OK: GEBDBConecta
   OK: GEBDBProvisionaCatalogo
   ```
   Isso é normal. Significa "banco conectado, catálogo pronto".
4. Aparece a tela **Acesso**: informe usuário e senha e clique em **Entrar** (capítulo 18). Numa instalação nova existe só a conta `super`, com a senha inicial da instalação; o primeiro login pede a troca da senha na hora.
5. Para fechar: volte ao terminal e aperte `Ctrl+C`.

### 3.1 Como a tela funciona

- **Menu lateral:** Início, os módulos que você tem permissão para usar, Rastreabilidade, Minha senha e Sair.
- **Início:** empresa, filial, usuário e data da sessão; indicadores (saldo em contas, títulos em aberto, guias da Derrama, estoque abaixo do mínimo) e o gráfico de saldo por conta.
- **Página do módulo:** em cima, as tabelas do módulo em abas (atualizam sozinhas depois de cada operação; clicar numa linha preenche os campos ligados dos formulários). Embaixo, os formulários em abas: **Operações**, **Relatórios** e, conforme o módulo, **Banco**, **NF-e de fornecedores**, **Simples Nacional** e **Documentos eletrônicos**.
- **Formulário:** cada operação é uma tela única. Preencha e clique em **Confirmar**; o resultado aparece numa mensagem verde (feito) ou vermelha (recusado, com o motivo).
- **Operações com vários itens** (pedido de compra ou de venda, entrada, devolução, movimento com lote, rateio): preencha o cabeçalho, digite cada item e clique em **Incluir item**; para tirar um, selecione na tabela e clique em **Remover item selecionado**. Depois, **Confirmar**.
- **Relatórios:** abrem na página **Resultado** (botão **Voltar** para retornar).
- **Rastreabilidade:** escolha a origem (pedido, nota...) e o número; o caminho do documento aparece em árvore (itens, entrada, estoque, contas, lançamentos).
- **Minha senha:** troca a sua senha a qualquer momento.

**Se não abrir:** veja o capítulo 15 ("Mentor trava / sem internet / SEFAZ fora").

---

## 4. Cadastrar empresa e usuário (primeiro uso)

Você precisa de 1 empresa (sua banquinha/loja) e 1 usuário (você).

- **Empresa (tabela GE1, catálogo):** guarda `GE1_COD` (apelido curto, ex.: `01`) e `GE1_NOME` (nome, ex.: `BANCA DA MARIA`). Cada empresa tem seu próprio schema Postgres isolado (`emp_01`, `emp_02`, ...) — os dados de módulo (vendas, notas, financeiro etc.) de uma empresa nunca aparecem para outra.
  > Truque: se o nome for exatamente `SIMPLES`, o sistema entende que você é do Simples Nacional na hora de apurar. Senão, usa `REGULAR`.
- **Usuário (tabela GE2, catálogo — compartilhado entre empresas):** guarda `GE2_COD` (apelido, ex.: `MARIA`), `GE2_NOME` e `GE2_PERFIL` (o cargo), mais a senha de acesso (Argon2id, tabela `GE2_SEC` — veja capítulo 18).
  - Perfis: `ADMIN` (faz tudo), `VENDEDOR` (vende), `CAIXA` (só mexe no direto se a permissão `PERMITE_DIRETA` for `S`).
  - **Mesmo usuário em empresas diferentes:** o código `MARIA` é a **mesma pessoa** em qualquer empresa (usuário e senha são únicos no catálogo). O que muda por empresa é o **vínculo**: `MARIA` só entra na empresa `02` se alguém autorizar esse vínculo (tabela `GE2_EMP`). Sem vínculo, o login é recusado mesmo com senha certa.

Como cadastrar (pelo navegador, módulo **Núcleo**, aba **Operações**; precisa ser o `super` ou o ADMIN da empresa):

1. **Nova empresa:** código e nome → Confirmar. O sistema cria o compartimento (schema) da empresa.
2. **Novo usuário:** código (letras, números e `_`), nome, perfil, senha e confirmação, empresa e filial (vazio = matriz) → Confirmar. A senha precisa passar pela política (mínimo de 8 caracteres, com maiúscula, minúscula, dígito e caractere especial; sem sequências como `abc`/`123`). Para dar acesso a outra empresa, use **Vincular usuário a empresa**.
3. Pronto. Tudo que você fizer fica registrado na **Auditoria (GE3)** — um caderninho automático de "quem fez o quê e quando".

> Não cadastre senha inserindo linhas em `GE2_SEC` na mão: salt/hash vazios são sempre recusados no login, e um hash calculado com outro salt nunca confere. Use `GEBSECCRIAUSU()`. Você não precisa decorar isso.

> **Recuperar a conta `ADMIN`**: por segurança, `GEBSECCRIAUSU()` recusa silenciosamente qualquer chamada para o código `admin` (maiúsculo ou minúsculo) a menos que o técnico passe o 6º parâmetro explícito `lPermiteAdmin := .T.`. Isso evita resetar a conta administrativa por engano — não impede o reset deliberado, só exige que o técnico confirme a intenção.

---

## 5. Cadastrar produto + NCM e alíquota (antes de vender)

Sem produto cadastrado, não sai nota.

1. Fiscal → aba **Operações** → **Novo produto**:
   - `Código` (ex.: `BAN01`), `NCM` (os 8 números do produto), `Descrição` (ex.: `Banana prata kg`).
2. Confira a alíquota (tabela GF2): para aquele NCM, quanto é de IBS e CBS e de quando até quando vale (`INI` até `FIM`, no formato `AAAAMMDD`).
   > Alíquota é só a porcentagem do imposto. Vigência é o período em que ela vale.
3. Salve. Para conferir se gravou, o sistema lê com `GEBFPRO(código)` (devolve código+NCM+descrição) e `GEBFALI(NCM)` (devolve IBS e CBS).

Exemplo: produto `BAN01`, NCM `08030000`, IBS 5%, CBS 3%. Numa venda de R$ 100, o imposto é R$ 5 de IBS + R$ 3 de CBS.

---

## 6. Emitir NF-e: online ou fila (o caminho feliz e o desvio)

Função que faz isso: `GEBFEMI(chave, código, quantidade, preço)`.

- **chave** = apelido único da nota (ex.: `NF001`).
- Retorno: `AUTORIZADA` (deu certo na hora) ou `EM_FILA` (ficou para depois).

Passo a passo no navegador:

1. **Fiscal → Operações → Emitir nota** → preencha chave, produto, quantidade e preço → Confirmar.
2. O sistema faz sozinho, nesta ordem:
   a. Pergunta ao **Mentor** (`EMISSAO`). Se ele travar, vai para a fila.
   b. Busca produto + alíquota. Se não achar, calcula imposto zerado (não trava).
   c. Calcula `base = quantidade x preço`, depois IBS e CBS.
   d. Tenta autorizar (na prática: autoriza se `base > 0`).
   e. Grava o cabeçalho (GF3) e o item (GF4) e registra no contas (CTBLAN).
3. Resultado:
   - `AUTORIZADA` = nota pronta.
   - `EM_FILA` = entrou na **fila (GE5)** como `PENDENTE`. Não é erro: é proteção.

**Os 3 modos de emissão** (o técnico escolhe em `GEBCFG("EMISSAO")`):

| Modo | O que faz | Quando usar |
|------|-----------|-------------|
| `ONLINE_FILA` (padrão) | Tenta online; se falhar, põe na fila | Dia a dia normal |
| `ONLINE_PURO` | Tenta online; se falhar, NÃO põe na fila | Só se você quer decidir na hora |
| `SO_FILA` | Nem tenta, já põe na fila | Sem internet / SEFAZ fora do ar |

**Parcelar nota para o cliente (em quantas vezes):** `GEBFSPL(total, partes)` divide e ajusta os centavos na última parcela. Ex.: R$ 100 em 3x = 33,33 + 33,33 + 33,34.

---

## 7. Apurar o mês (somar o imposto)

Função: `GEBFAPU(competência)`. Ex.: `GEBFAPU("202609")`.

1. **Fiscal → Operações → Apurar competência** → informe a competência (`202609`) → Confirmar.
2. O sistema grava em GF5, junto com o regime (`SIMPLES` ou `REGULAR`):
   - **débito:** IBS+CBS das notas **autorizadas** do mês (cancelada e em fila não contam), menos o IBS/CBS das devoluções de venda do mês;
   - **crédito:** IBS+CBS das compras que entraram no mês;
   - **saldo** = débito − crédito.
3. Na empresa `REGULAR`, a apuração já gera (ou atualiza) a guia `GD<mês>` na Derrama, com o título a pagar no financeiro, e lança a provisão no contábil. Na empresa do Simples, o IBS/CBS vai dentro do DAS, então não sai guia.
4. Pode repetir sem medo: ele apaga a linha antiga do mês antes de gravar a nova (é "idempotente", palavra chique para "pode apertar de novo que não duplica").
5. Crédito especial (transferir ou devolver imposto): `GEBFCRE(comp, origem, valor, tipo)` com tipo `TRANSF` ou `RESSARC`.

**Modos de apuração** (`GEBCFG("APURACAO")` = `AUTO`, `MANUAL` ou `DIRETA`): os três gravam do mesmo jeito, muda só o que aparece no registro. O padrão é `AUTO`.

---

## 7.1 Simples Nacional: apurar o DAS do mês

Para empresas do Simples Nacional, inclusive as que já passaram do porte de MEI. O caminho é **Fiscal → aba Simples Nacional** (configuração, atividades, produtos, folha, feriados e apuração do DAS); os relatórios do Simples ficam na aba **Relatórios**.

**Uma vez só**
1. **Configurar anexo padrão:** o Anexo usado pelos produtos sem atividade (`I` comércio, `II` indústria, `III`, `IV` ou `V` serviços, ou `FR` para atividade sujeita ao Fator R). Se a empresa abriu há menos de 12 meses, informe também o mês de início (`AAAAMM`).
2. **Atividade:** se a empresa tem mais de uma atividade (por exemplo, revenda no Anexo I e serviço no Anexo III), cadastre cada uma com seu Anexo.
3. **Produto: atividade, ST, monofásico:** ligue cada produto à sua atividade. Marque `S` em ST se o ICMS vem por substituição tributária, e em monofásico se o PIS/COFINS é monofásico.
4. **Feriado:** cadastre os feriados municipais e estaduais da cidade. Os nacionais, Carnaval, Sexta-feira Santa e Corpus Christi o sistema já conhece.

**Todo mês**
1. **Nota de exportação:** marque as notas de venda para o exterior.
2. **Folha e receita externa do mês:** informe a folha (salários + pró-labore + encargos), sem atividade, porque ela entra no Fator R. Informe também a receita que não passou pelo GEBAN, por atividade se for o caso. Os 12 meses antes da implantação entram aqui, para o RBT12 sair certo desde o primeiro mês.
3. **Apurar mês (DAS):**
   - calcula tudo e gera a guia `DAS-AAAAMM` na Derrama, com o título a pagar no financeiro (credor RFB), vencendo no dia 20 do mês seguinte ou no próximo dia útil, e a provisão no contábil;
   - acima do sublimite, o ICMS ou o ISS que sai do DAS vira a guia `ICMS-AAAAMM` ou `ISS-AAAAMM`;
   - apurar de novo atualiza as guias que ainda não foram pagas; se a guia já foi paga e o valor subiu, sai a guia complementar (`DAS-AAAAMM-C1`); se baixou, aparece o aviso de restituição;
   - configurar o Simples marca a empresa como `SIMPLES`; numa empresa `REGULAR`, a apuração do DAS é recusada.
4. **Relatório: extrato da apuração:** o resumo do mês, cada atividade com IRPJ, CSLL, COFINS, PIS, CPP, ICMS, ISS e IPI, e o total por tributo. É o espelho para conferir com o PGDAS-D.
5. **Relatório: acompanhamento anual:** mês a mês, com receita, RBT12, alíquota, DAS e situação da guia, mais quanto do sublimite (R$ 3,6 milhões) e do limite (R$ 4,8 milhões) já foi usado no ano.

**Avisos que podem aparecer**
- **Sublimite excedido:** o ICMS/ISS sai do DAS e tem de ser pago por fora, e o aviso mostra o valor.
- **Receita do ano acima de 3,6 ou de 4,8 milhões.**
- **Exportação acima do limite adicional.**
- **Sujeita a exclusão.**

**Pela API**
- `POST /api/fiscal/simples/config` (`anexo`, `inicio`)
- `POST /api/fiscal/simples/atividade` (`codigo`, `descricao`, `anexo`)
- `POST /api/fiscal/simples/produto` (`produto`, `atividade`, `st`, `monofasico`)
- `POST /api/fiscal/simples/exportacao` (`chave`, `exportacao`)
- `POST /api/fiscal/simples/feriado` (`data`, `descricao`)
- `POST /api/fiscal/simples/folha` (`competencia`, `folha`, `receita_externa`, `atividade`)
- `POST /api/fiscal/simples/apurar` (`competencia`)
- `GET /api/fiscal/simples/extrato/{AAAAMM}` (devolve 404 se o mês não foi apurado)
- `GET /api/fiscal/simples/anual/{AAAA}`

A permissão é a mesma da apuração (Fiscal / apuração).

## 8. Gerar, pagar e parcelar a guia (o "DARF banânico")

Pense na guia como o boleto do imposto do mês.

### 8.1 Gerar a guia

Função: `GEBDGER("202609")` → devolve `GD202609`.

1. **Derrama → Operações → Gerar guia** → informe a competência → Confirmar.
2. Ela copia o saldo da apuração (GF5) para a guia (GD1): valor, juros 0, multa 0, total = valor, estado `ABERTA`. Normalmente você nem precisa disso, porque a apuração já gera a guia.
3. A guia aparece no **financeiro** como título a pagar de mesmo número (`GD202609`), com vencimento no dia 20 do mês seguinte em dia útil: entra no fluxo de caixa e na posição de títulos.
4. Se você gerar de novo o mesmo mês, ele atualiza a mesma guia sem duplicar. Se a guia já foi paga e o imposto subiu, sai a guia complementar `GD202609-C1`.
5. Empresa do Simples não tem essa guia (o IBS/CBS vai no DAS).

### 8.2 Pagar (dar baixa)

Função: `GEBDBAI("GD202609")` → devolve `.T.` (verdadeiro = pagou).

1. **Derrama → Operações → Baixar guia** → informe a guia (clicar na linha da tabela Guias preenche) → Confirmar. O dinheiro sai da conta `DER_CONTA` (padrão `CAIXA`). Pela API, `POST /api/bo/derrama/pagar` aceita a conta e a data.
2. Também dá para pagar pelo financeiro (Financeiro → Baixa com juros e multa), como qualquer título: quando o último título da guia é pago, a guia fica `BAIXADA`.
3. O contábil registra a saída: débito no imposto a recolher, crédito na conta paga. Juros e multa de atraso seguem a regra da Derrama.
4. Pagar de novo uma guia já paga não faz nada.

### 8.3 Juros, parcela e protesto (quando atrasa)

- **Juros + multa:** `GEBDJUR("GD202609", dias de atraso)`.
  Conta banânica: `juros = valor x 0,33% x dias` (com teto de 20%) + `multa fixa de 2%`. Ex.: R$ 1.000 com 10 dias = R$ 33 de juros + R$ 20 de multa = R$ 1.053.
- **Parcelar:** `GEBDPAR("GD202609", 3)` divide o total em 3 linhas (GD2, parcelas `001`, `002`, `003`; a última ajusta os centavos). A guia vira `PARCELADA`. Precisa de no mínimo 2 parcelas. No financeiro, o título da guia vira 3 títulos (`GD202609/01`…) de 30 em 30 dias. Guia que já teve pagamento não pode ser parcelada.
- **Protestar:** `GEBDPRO("GD202609")` marca como `PROTESTADA` e abre um registro em GD3. Só use se for mesmo protestar.

---

## 9. Vender com estoque (baixa automática)

Funções: `GEBVEST(produto, quantidade)` mexe no estoque; `GEBVVEN(venda, produto, quantidade [, preço])` vende.

### 9.1 Mexer no estoque

- Entrada: `GEBVEST("BAN01", 100)` soma 100.
- Saída manual: `GEBVEST("BAN01", -5)` tira 5.
- Produto novo cria a linha sozinho com mínimo 10.
- Se ficar abaixo do mínimo, o **Mentor** (`ESTOQUE_MINIMO`) só **avisa** (não trava).

### 9.2 Vender (o jeito certo)

1. **Estoque → Operações → Vender** → preencha código da venda (ex.: `V001`), produto, quantidade e preço → Confirmar.
2. O sistema:
   a. Pergunta ao Mentor (`VENDA_IMPULSIVA`). Se travar → `BLOQUEADA` (não mexe em nada).
   b. Confere estoque (GV1). Se não tem → `SEM_ESTOQUE` (não mexe em nada).
   c. Baixa o estoque, grava a venda (GV2) como `VENDIDA`.
   d. Chama a NF-e (`GEBFEMI`) com a mesma chave; se o fiscal não existir, registra direto no contas (`CTBLAN`).
3. Retornos possíveis: `VENDIDA` (ok), `BLOQUEADA` (mentor ou dado vazio/zerado), `SEM_ESTOQUE` (sem saldo ou sem tabela).

> Preço padrão é 10 se você não informar. Para nota certa, sempre informe o preço.

---

## 10. Fiado (vender para receber depois) + juros

Funções: `GEBVFIA(cliente, valor)` abre o fiado; `GEBVJUR(cliente, dias)` cobra atraso.

Regras simples:

- Limite: **R$ 1.000 em aberto por cliente**. Acima disso, o sistema nega (`.F.`) sem gravar.
- Valor zerado ou cliente vazio também nega.
- Juros iguais aos da guia: **0,33% ao dia (teto 20%) + multa 2%**, gravados por linha (juros, multa, total).

Passo a passo:

1. **Estoque → Operações → Vender fiado** → cliente (ex.: `JOAO`) + valor → Confirmar.
2. Se passar do limite, aparece `LIMITE`. É proteção, não erro seu: receba uma parte antes de vender mais.
3. Para cobrar atraso: **Estoque → Operações → Juros do fiado** → cliente + dias → o sistema atualiza todas as linhas `ABERTA` e mostra a soma.

---

## 11. Lançamento direto no contas (só com permissão)

Função: `GEBCDIR(conta débito, conta crédito, valor [, usuário])`.

> Lançamento direto = escrever à mão no livro de contas. Todo resto do sistema já lança sozinho (venda, nota, guia paga). O direto é exceção e tem 4 travas.

As 4 travas (todas precisam liberar):

1. Permissão geral `PERMITE_DIRETA` precisa ser `S`.
2. Seu usuário precisa passar em `GEBUSR` (perfil `CAIXA` só com a permissão `S`; `ADMIN`/`VENDEDOR` liberam; usuário desconhecido nega).
3. A regra `LANC_DIRETO` em GC4: se existir com `PERM = N`, nega. Se não existir, libera.
4. O Mentor (`LANC_DIRETO`): se travar, nega.

Se alguma travar, retorna `.F.` (falso = não gravou). Se passar, grava um lote tipo `DIRETO` com débito = crédito (partida dobrada: todo dinheiro que sai de um lugar entra em outro).

**Quando usar:** ajuste pedido pelo contador. No dia a dia, você não precisa disso.

---

## 12. Balancete e DRE (ver se deu lucro)

Funções: `GEBBAL("202609")` e `GEBDRE("202609")`.

- **Balancete:** lista por conta quanto foi débito e crédito no mês. Ex.: conta `3.01` teve 500 de crédito e 0 de débito.
- **DRE banânica:** `receitas (contas que começam com 3: crédito menos débito) menos despesas (contas que começam com 4: débito menos crédito)`. Resultado positivo = lucro; negativo = prejuízo.

Passo a passo: **Contábil → aba Relatórios → Relatório: balancete do período** (ou **DRE do período**) → informe o período → Confirmar; o resultado abre na página Resultado. Se voltar vazio, é porque não há lançamento naquele mês (ou a contabilidade ainda não foi criada).

---

## 13. Controlar o caixa (conta, receber, pagar, baixar, fluxo)

> Onde: módulo **Financeiro**. Tabelas: contas GFN1, receber GFN2, pagar GFN3, movimento GFN4.

### 13.1 Criar a conta (uma vez só)

Função: `GEBFNCON(conta, nome)`. Ex.: `GEBFNCON("CAIXA", "Caixa loja")`.

1. **Financeiro → Operações → Nova conta** → preencha conta (ex.: `CAIXA`) e nome → Confirmar.
2. A conta nasce com saldo 0. Se criar de novo a mesma conta, o sistema só devolve "já existe" sem duplicar.
3. Conta vazia não grava (retorna `.F.`).

> A baixa sempre movimenta a conta `CAIXA`. Se ela não existir, a baixa do título funciona mesmo assim, só não atualiza saldo nenhum. Crie a `CAIXA` logo no começo para o saldo bater.

### 13.2 Lançar uma conta a receber

Função: `GEBFNREC(documento, cliente, valor, vencimento)`. Ex.: `GEBFNREC("REC-001", "JOAO", 500, "20261231")`.

- **documento** = apelido único da conta (ex.: `REC-001`). Não pode repetir na mesma empresa.
- **cliente** = quem vai pagar você.
- **valor** = precisa ser maior que zero.
- **vencimento** = data como texto `AAAAMMDD` (ex.: `20261231` = 31/12/2026) ou data de verdade.

1. **Financeiro → Operações → Título parcelado** → tipo **Receber**, documento, cliente, valor e condição (`0` = um título só, à vista; um código ou dias gera as parcelas) → Confirmar.
2. O título nasce com `SALDO = VALOR` e estado `ABERTO`.
3. Se der `.F.`: documento vazio, valor zerado, documento repetido ou tabela ainda não criada (`GEBFNMIG` não rodou).

### 13.3 Lançar uma conta a pagar

Função: `GEBFNPAG(documento, fornecedor, valor, vencimento)`. Ex.: `GEBFNPAG("PAG-001", "FOR01", 200, "20261231")`.

Mesmas regras do receber, com 1 diferença: **antes de gravar, passa pelo Mentor (`PAG_IMPULSIVO`)**. Se o Mentor travar, retorna `.F.` sem gravar nada (veja capítulo 15).

### 13.4 Baixar (receber o dinheiro ou pagar a conta)

Função: `GEBFNBAI(tipo, documento, valor)`. Ex.: `GEBFNBAI("REC", "REC-001", 500)` ou `GEBFNBAI("PAG", "PAG-001", 200)`.

- **tipo**: `REC` ou `RECEBER` (para receber), `PAG` ou `PAGAR` (para pagar). Qualquer outro tipo nega na hora.
- Pode baixar **aos poucos**: pagou metade, o saldo cai pela metade e o estado continua `ABERTO`. Quitou tudo, vira `RECEBIDA` (receber) ou `PAGA` (pagar).
- Cada baixa: grava 1 movimento na `CAIXA` (GFN4), soma/subtrai o saldo da conta `CAIXA` (GFN1) e registra no contas (`CTBLAN`).
- Se tentar baixar **mais do que o saldo**, o sistema ajusta sozinho e quita (não deixa saldo negativo).
- Baixar conta já quitada, documento que não existe, valor zerado ou tipo errado retorna `.F.`.
- Baixa de **pagar** também passa pelo Mentor (`PAG_IMPULSIVO`): se travar, não mexe em nada.

### 13.5 Ver o fluxo de caixa

Função: `GEBNFLX()` → devolve `{receber, pagar, saldo}`.

1. **Financeiro → Relatórios → Relatório: fluxo de caixa projetado** → Confirmar.
2. O sistema soma só os títulos `ABERTO` (quitados não entram): `saldo = receber - pagar`.
3. Ex.: receber 5.000 + pagar 2.500 = saldo 2.500.

**Comandos do técnico (cola rápida do financeiro):**

```bash
advplc check src/GEBFIN_MIG.prw src/GEBFIN_CON.prw src/GEBFIN_BAI.prw src/GEBFIN_FLX.prw --include src
advplc serve src/GEBTUI.prw --port 8081
```

---

## 14. Comprar (fornecedor, cotação, pedido, receber a NF)

> Onde: módulo **Compras**. Tabelas: fornecedor GCP1, cotação GCP2, pedido GCP3+GCP4, entrada GCP5. Primeira vez: o técnico roda `GEBCMMIG()` para criar GCP1–GCP5.

### 14.1 Cadastrar fornecedor

Função: `GEBCMFOR(código, nome)`. Ex.: `GEBCMFOR("FOR01", "Atacadao do Ze")`.

1. **Compras → Operações → Novo fornecedor** → código + nome → Confirmar.
2. Código ou nome vazio nega (`.F.`). Código repetido não duplica: devolve `.T.` como "já existe".

### 14.2 Cotar e pegar o menor preço

Funções: `GEBCMCOT(fornecedor, produto, preço)` grava; `GEBCMMEL(produto)` mostra o menor.

1. **Compras → Operações → Cotação de fornecedor** → fornecedor + produto + preço → Confirmar. Ex.: `GEBCMCOT("FOR01", "BAN01", 4.50)`.
2. Repita para cada fornecedor (ex.: FOR02 a 4,20).
3. Para comparar: **Compras → Operações → Menor preço cotado** → informe o produto. Ex.: `GEBCMMEL("BAN01")` devolve `4.20`.
4. Preço zerado, fornecedor/produto vazio negam. Sem cotação, o menor volta 0.

### 14.3 Fazer o pedido (com itens de uma vez)

Função: `GEBCPXPED(pedido, fornecedor, itens, condição, local, data)`. Itens = lista `{produto, quantidade, preço}`.

1. **Compras → Operações → Pedido de compra com itens** (ou **Pedido direto**) → preencha fornecedor, condição de pagamento, local e a grade de itens → Confirmar.
   - Pedido em branco ganha número automático (`PC` + sequencial).
   - Retorno: `{.T., "pedido <num> LIBERADO|PENDENTE", {...}}`.
2. **Alçada**: se o total passar do limite `COM_ALCADA` (parâmetro do técnico), o pedido nasce `PENDENTE` — ele existe, mas **não pode receber entrada** até alguém aprovar:
   - **Compras → Operações → Aprovar/rejeitar pedido** → número do pedido + usuário + decisão. Liberado vira `LIBERADO`; rejeitado vira `REJEITADO`.
3. Regras: fornecedor precisa existir (cadastre antes, 14.1); quantidade e preço maiores que zero; produto repetido no mesmo pedido recusa; pedido repetido recusa.
4. **Pelo cotado**: **Solicitação de compra** (`GEBCPXSC`) lista o que a loja precisa; **Gerar pedidos da solicitação** (`GEBCPXGERA`) cria um pedido por fornecedor usando automaticamente o menor preço cotado (14.2). Item sem cotação recusa tudo.

### 14.4 Receber a NF / dar entrada

Função: `GEBCPXENT(nota, pedido, itens, frete, data, retenções, chaveNF)`. Ex.: `GEBCPXENT("NF-001", "PED-001", {}, 0, "20261127", {}, "")` — itens vazio = recebe tudo que está pendente.

1. **Compras → Operações → Documento de entrada** → nota do fornecedor + pedido + itens (ou tudo pendente) + frete → Confirmar.
2. O sistema faz sozinho, nesta ordem:
   a. Confere o pedido: precisa existir e estar `LIBERADO` (se está `PENDENTE`, aprove antes no 14.3; se já `RECEBIDO`, nega).
   b. Confere a nota: não pode repetir (NF duplicada nega).
   c. Dá entrada de cada item no estoque **ao custo de entrada** (preço + frete rateado) — o custo médio do produto se acerta sozinho.
   d. Lança o total a pagar pela **condição do pedido** (à vista se não tiver), já descontando as **retenções** informadas (ISS/IRRF/etc. — o retido vira guia na Derrama).
   e. Registra no contas (`COMPRA_ESTOQUE`), credita IBS/CBS da compra e marca o pedido `PARCIAL` ou `RECEBIDO`.
3. Retorno: `{.T., msg, {total, status do pedido, títulos, retido}}` ou `.F.` com o motivo.
4. **Devolução ao fornecedor**: **Compras → Operações → Devolução de compra** (`GEBCPXDEV`) estorna itens de uma NF recebida.

**Comandos do técnico (cola rápida de compras):**

```bash
advplc check src/GEBCOM_MIG.prw src/GEBCOM_FOR.prw src/GEBCPX.prw --include src
advplc serve src/GEBTUI.prw --port 8081
```

---

## 15. O que fazer quando... (guia de susto)

### 15.1 "Mentor avisou" — e agora?

O Mentor tem 3 humores (gravados em GE4):

- `DESLIGADO` (ou vazio/desconhecido) = libera direto, sem recado.
- `AVISA_E_LIBERA_COM_BO` = libera, mas grava um **BO** na auditoria (GE3) com "assumiu BO mentor". BO aqui é "termo de responsabilidade": fica registrado que você viu o aviso e seguiu mesmo assim.
- `AVISA_E_TRAVA` = trava mesmo (retorna `.F.` / `BLOQUEADA` / `EM_FILA`).

| Onde | Evento do Mentor | Se travar, o que acontece |
|------|------------------|--------------------------|
| Emitir nota | `EMISSAO` | Nota vai para a fila |
| Vender | `VENDA_IMPULSIVA` | Venda `BLOQUEADA`, nada mexe |
| Estoque baixo | `ESTOQUE_MINIMO` | Só avisa, não trava |
| Lançar direto | `LANC_DIRETO` | Direto negado (`.F.`) |
| Lançar/baixar conta a pagar | `PAG_IMPULSIVO` | `GEBFNPAG`/`GEBFNBAI` devolvem `.F.` sem gravar |
| Liberar etapas de compra | `COMPRA_IMPULSIVA` | pedido/entrada via TUI ou `/bo/compras/*` ficam bloqueados até o Mentor liberar |

**O que fazer:** leia o aviso. Se for `TRAVA` e você acha que está errado, chame o responsável (ADMIN) ou o técnico para mudar o modo em GE4. Não tente "dar um jeitinho": o BO fica gravado.

### 15.2 Sem internet

1. Não se desespere. Mude (ou peça ao técnico para mudar) a emissão para `SO_FILA`.
2. Venda e emita normalmente: tudo cai em `EM_FILA` / `PENDENTE`.
3. Quando a internet voltar, processe a fila (o técnico reemite cada `GE5_CHAVE`). Confira no menu Fiscal quais ficaram `EM_FILA`.

### 15.3 SEFAZ fora do ar

Igual ao sem internet: use `SO_FILA` ou deixe no `ONLINE_FILA` (ele tenta e, falhando, enfileira sozinho). O importante: **não reemitir a mesma chave duas vezes sem conferir** — confira GF3 antes para não duplicar.

### 15.4 Mentor trava tudo (nada passa)

1. Anote qual tela travou (venda? nota? direto?).
2. Peça ao ADMIN para ver GE4: qual evento está `AVISA_E_TRAVA`?
3. Se for emergência real, o ADMIN pode mudar para `AVISA_E_LIBERA_COM_BO` (libera com registro) ou `DESLIGADO`. Isso fica auditado.
4. Depois resolva a causa (ex.: estoque zerado, permissão do CAIXA).

### 15.5 Mentor barrou minha compra ou meu pagamento — passo a passo

Vale para as operações de compra guiadas (`COMPRA_IMPULSIVA`) e `GEBFNPAG` / `GEBFNBAI` de pagar → `.F.` (evento `PAG_IMPULSIVO`).

1. **Anote o que você tentou:** número do pedido ou documento do pagar + valor + fornecedor.
2. **Confira o básico primeiro** (antes de culpar o Mentor):
   - Pedido: número e fornecedor preenchidos? O pedido já existe como `ABERTO`?
   - Pagar: documento vazio? Valor zerado? Documento repetido?
   - Se for pedido/entrada de compra: o pedido existe? Está `LIBERADO` (não `PENDENTE`)? Itens com quantidade e preço maiores que zero?
3. **Se os dados estão certos, é o Mentor:** peça ao ADMIN para olhar o modo em GE4 para `COMPRA_IMPULSIVA` (compra) ou `PAG_IMPULSIVO` (pagamento).
4. **Decida com o ADMIN:** ou corrige a causa (ex.: compra por impulso mesmo — cancele o pedido) ou o ADMIN muda para `AVISA_E_LIBERA_COM_BO` (libera registrando o BO em GE3) e você repete a operação.
5. **Entrada travada junto:** se a entrada (`GEBCPXENT`) negou por pagamento, é o `PAG_IMPULSIVO` travando o título da NF. Libere o pagamento primeiro, depois repita a entrada com a mesma nota e pedido. Não crie outra nota: a original não foi gravada, pode repetir igual.

### 15.6 "Sem estoque" na entrada — entenda de uma vez

- **Na entrada de compra não existe "sem estoque".** A entrada sempre **soma** no estoque ao custo de entrada (`GEBVEST`). Produto novo cria a linha sozinho. Então `GEBCPXENT` nunca nega por falta de estoque.
- **Se a entrada negou, a causa é outra:** pedido inexistente ou já `RECEBIDO`, NF duplicada, pedido sem itens, ou o pagar automático recusado (capítulo 15.5). Leia a mensagem e volte ao capítulo 14.4.
- **O `SEM_ESTOQUE` é da venda** (`GEBVVEN`): significa que não tem saldo para vender. Aí sim você repõe comprando (capítulo 14) ou ajusta com `GEBVEST` de entrada.

### 15.7 Paguei duplicado — e agora?

Como o sistema protege:

- **Lançar 2x o mesmo documento nega:** `GEBFNPAG` com documento repetido devolve `.F.` e mostra "duplicado". O segundo não grava.
- **Baixar a maior quita sem sobrar troco:** `GEBFNBAI` limita ao saldo (pagou R$ 600 numa conta de R$ 500, quita os R$ 500). Não fica saldo negativo.
- **Baixar conta já `PAGA` nega:** segunda baixa devolve `.F.`.

Se aconteceu mesmo (ex.: lançou `PAG-001` e `PAG-002` para a mesma conta real):

1. Não apague na mão. O sistema usa "apagar lógico" (`D_E_L_E_T_`).
2. Baixe só o documento certo; deixe o duplicado `ABERTO`.
3. Chame o técnico/contador para estornar o duplicado corretamente.
4. No próximo pedido, confira antes: documento já existe? (**Financeiro → Relatórios → Relatório: títulos por atraso**.)

### 15.8 Mensagens que parecem erro mas são proteção

- `SEM_ESTOQUE` = não tem produto suficiente. Reponha com `GEBVEST` (entrada).
- `BLOQUEADA` = Mentor travou ou faltou dado (código vazio, quantidade zerada).
- `EM_FILA` = nota guardada para depois. Não é perda.
- `LIMITE` (fiado) = cliente já deve R$ 1.000. Receba antes de vender mais.
- Retorno `.F.` / vazio = "não fiz". Confira os dados e tente de novo.
- `CTB stub ...` no registro = a contabilidade ainda não foi parametrizada; o sistema só registrou e seguiu. Avise o técnico para parametrizar GC4.

---

## 16. FAQ (perguntas de verdade)

**Preciso decorar código?** Não. Use o navegador (serve). Os nomes como `GEBFEMI`, `GEBFAPU` são para o técnico. Você decora o caminho no menu.

**Qual a diferença de NF-e AUTORIZADA e EM_FILA?** Autorizada = governo aceitou na hora. Em fila = guardada para tentar depois. As duas estão salvas; só o estado muda.

**Posso apagar uma nota errada?** Não apague. O sistema trabalha com "apagar lógico" (`D_E_L_E_T_`: espaço = vivo, `*` = apagado). Peça ao técnico/contador para estornar corretamente.

**O que é IBS/CBS na prática?** São os impostos da nota. Você não calcula na mão: o sistema pega a alíquota do NCM e multiplica pela base.

**Por que minha venda deu BLOQUEADA?** Ou o Mentor `VENDA_IMPULSIVA` travou, ou faltou código/quantidade, ou quantidade zerada. Confira os 3.

**Por que o fiado negou?** Ou passou de R$ 1.000 em aberto, ou valor zerado, ou cliente vazio.

**Posso parcelar a guia em quantas vezes?** No mínimo 2. A última parcela ajusta os centavos sozinha.

**O que o contador vai pedir no fim do mês?** Balancete + DRE da competência + guia paga. Está tudo no capítulo 12 e 8.

**Como funciona o caixa (receber/pagar)?** Conta `CAIXA` (GFN1) + receber (GFN2) + pagar (GFN3) + baixa (GFN4). Lança com `GEBFNREC`/`GEBFNPAG`, baixa com `GEBFNBAI`, confere com `GEBNFLX`. Detalhes no capítulo 13.

**Como compro mercadoria?** Fornecedor (`GEBCMFOR`) → cotação (`GEBCMCOT`) → menor preço (`GEBCMMEL`) → pedido com itens (`GEBCPXPED`, vira `PENDENTE` se passar da alçada → `GEBCPXAPR` libera) → entrada da NF (`GEBCPXENT`), que já cria o pagar e soma o estoque. Detalhes no capítulo 14.

**Meu pedido deu BLOQUEADO. E agora?** Ou faltou número/fornecedor, ou o Mentor `COMPRA_IMPULSIVA` travou. Veja o passo a passo no capítulo 15.5.

**Meu pagar não grava (só dá .F.). Por quê?** Confira: documento vazio, valor zerado, documento repetido ou Mentor `PAG_IMPULSIVO` travado. Capítulo 15.5.

**A entrada da NF negou. Perdi a mercadoria?** Não. Nada foi gravado: confira pedido `ABERTO`, NF não repetida, itens com quantidade/preço e o pagar liberado. Capítulo 14.4 + 15.5.

**Paguei a mesma conta duas vezes?** A segunda baixa nega e baixar a maior quita sem negativo. Se lançou 2 documentos iguais na conta real, baixe só o certo e chame o contador para estornar o outro. Capítulo 15.7.

**Posso baixar só metade da conta?** Sim. Baixa parcial abate o saldo e mantém `ABERTO`. Quite o resto depois com outra baixa.

**Onde vejo quem fez o quê?** Na Auditoria (GE3), menu Núcleo → Auditoria.

**Troquei de computador. E o banco?** Não é mais um arquivo para copiar: o banco é um servidor Postgres separado. Do computador novo, basta configurar as mesmas 5 variáveis `GEBAN_PG_*` (capítulo 1) apontando para o mesmo servidor — os dados continuam lá. Se apontar para um Postgres vazio, o sistema cria um catálogo novo (sem empresas/usuários).

---

## 17. Checklist do fecha-mês banânico estendido (imprima e cole na parede)

Faça nesta ordem, todo mês:

**Vendas + notas**
- [ ] 1. Todas as vendas do mês estão `VENDIDA`? (Confira `SEM_ESTOQUE`/`BLOQUEADA` e corrija.)
- [ ] 2. Todas as notas estão `AUTORIZADA`? (As `EM_FILA` precisam ser resolvidas: reemitir a fila GE5.)

**Compras**
- [ ] 3. Todos os pedidos chegaram? (Pedidos ainda `ABERTO` em GCP3: cobrar fornecedor ou cancelar com o contador.)
- [ ] 4. Todas as NFs de entrada foram recebidas? (`GEBCPXENT` de cada pedido; NF sem entrada = estoque e pagar faltando.)
- [ ] 5. Cotações do mês estão gravadas? (Serve de prova do menor preço depois.)

**Caixa (financeiro)**
- [ ] 6. Todo dinheiro que entrou foi baixado? (Receber ainda `ABERTO` em GFN2: cobrar ou dar baixa parcial com `GEBFNBAI("REC", doc, valor)`.)
- [ ] 7. Toda conta a pagar foi lançada e baixada? (Pagar `ABERTO` em GFN3 vira dívida do mês seguinte; confira duplicados pelo documento.)
- [ ] 8. Fluxo confere? (`GEBNFLX()` → receber, pagar e saldo batem com o extrato da `CAIXA`?)

**Imposto + fiado + estoque + contador**
- [ ] 9. Apurei o mês? (`GEBFAPU("202609")` — confira o saldo em GF5.)
- [ ] 10. Gerei a guia? (`GEBDGER("202609")` → `GD202609`.)
- [ ] 11. Paguei ou parcelei? (`GEBDBAI` para pagar; `GEBDPAR` + `GEBDJUR` se atrasou/parcelou.)
- [ ] 12. Fiados: cobrei os atrasados? (`GEBVJUR(cliente, dias)`.)
- [ ] 13. Estoque confere com a prateleira? (Se não, ajuste com entrada `GEBVEST`.)
- [ ] 14. Rodei balancete + DRE e mandei ao contador? (`GEBBAL` + `GEBDRE`.)
- [ ] 15. Auditoria ok? (Olhada rápida em GE3 para ver se não há BO estranho — inclusive BOs de compra/pagamento liberados.)
- [ ] 16. Fiz backup do banco Postgres? (Peça ao técnico para confirmar o backup/dump do banco. Sem cópia, sem choro.)

**Comandos de emergência do técnico (cola rápida):**

```bash
advplc check src/GEBTUI.prw --include src
advplc run src/GEBWEB.prw          # API REST (porta 8090)
advplc serve src/GEBTUI.prw --port 8081
```

---

## 18. Como fazer login (usuário + senha, empresa e filial)

O login é **de verdade**: senha conferida com hash seguro (Argon2id — a senha nunca fica salva "em claro" no banco) e bloqueio automático depois de tentativas erradas. Tudo pelo navegador:

1. Na tela **Acesso**, informe usuário e senha e clique em **Entrar**.
   - Senha errada soma 1 tentativa; **5 erradas seguidas bloqueiam a conta** (o ADMIN destrava em Núcleo → Ciclo do usuário).
   - O sistema não diz qual foi o motivo exato da recusa (de propósito — proteção contra quem tenta adivinhar usuário/senha de outra pessoa): aparece só "Credenciais inválidas".
2. **Troca obrigatória:** no primeiro acesso, depois que o ADMIN pediu a troca, ou quando a senha venceu (90 dias), o sistema pede a nova senha antes de continuar. As regras aparecem ao lado do formulário.
3. **Empresa:** se você está vinculado a uma só, ela já é escolhida; se a mais de uma, escolha na lista. Numa instalação nova, o `super` cria aqui a primeira empresa.
4. **Filial:** escolha a filial (ou a matriz).
5. Abre o **Início** (capítulo 19) com o menu dos módulos que você tem permissão para usar.

**Mesmo usuário, empresas diferentes:** `MARIA` é a **mesma pessoa e a mesma senha** em qualquer empresa — o que muda é o vínculo: ela só entra nas empresas em que foi autorizada (capítulo 4).

**Para trocar de empresa ou filial:** clique em **Sair** e entre de novo.

---

## 19. Início — explicação

Depois do login, a página **Início** mostra:

- **Sessão:** empresa, filial, usuário e data.
- **Indicadores:** saldo em contas (e quantas contas), títulos em aberto (valor e quantos vencidos), guias da Derrama em aberto (valor e quantas vencidas) e produtos com estoque abaixo do mínimo.
- **Saldo por conta:** gráfico de barras com o saldo de cada conta.
- **Acesso rápido:** um botão para cada módulo.

O botão **Atualizar** (no alto, à direita) relê os números.

---

## 20. Como usar os trackers (rastreio ponta a ponta)

Os trackers permitem acompanhar o caminho completo de uma operação. **Pela tela:** menu **Rastreabilidade** → escolha a origem e informe o número → **Rastrear**; o caminho aparece em árvore (cada nó mostra quantos registros achou). Para o técnico, são funções que recebem um código e devolvem todos os registros envolvidos:

### 20.1 Rastrear uma compra

```advpl
aDados := GEBTRAKCOMPRA("PED-001")
```

Retorna array com 6 posições:
1. Header do pedido (GCP3): `{num, forn, status}`
2. Itens do pedido (GCP4): `{{ped, prod, qtd, preco}, ...}`
3. Entrada/NF (GCP5): `{{nf, ped, status}, ...}`
4. Estoque por produto (GV1): `{{prod, saldo, min}, ...}`
5. Títulos a pagar criados (GFN3): `{{doc, forn, saldo, status}, ...}`
6. Lançamentos contábeis (GC3): `{{lote, DC, conta, valor}, ...}`

**Exemplo prático:** você quer saber se o pedido `PED-001` foi recebido, entrou no estoque e gerou o lançamento contábil. Chame `GEBTRAKCOMPRA("PED-001")` e confira se as posições 3, 4 e 6 não estão vazias.

### 20.2 Rastrear uma venda

```advpl
aDados := GEBTRAKVENDA("V-0001")
```

Retorna 5 posições: header da venda, itens (GV2), estoque pós-venda (GV1), título a receber (GFN2) e lançamentos contábeis (GC3).

### 20.3 Rastrear uma nota fiscal

```advpl
aDados := GEBTRAKNOTAFISCAL("NF001")
```

Retorna 6 posições: header GF3, itens GF4, cálculo IBS/CBS, título a receber GFN2, apuração GF5 (competência) e guia GD1 da derrama. Útil para verificar se uma nota foi bem emitida, apurada e gerou sua guia.

### 20.4 Rastrear uma guia de derrama

```advpl
aDados := GEBTRAKDERRAMA("GD202609")
```

Retorna 7 posições: apuração GF5 (origem), guia GD1 (valor/juros/multa/status), parcelas GD2, cobrança/protesto GD3, título a pagar GFN3, pagamentos (antigos e pelo financeiro, inclusive das parcelas) e lançamentos GC3. Mostra o ciclo completo da derrama do início ao fim.

---

## 21. Como gerar relatórios gerenciais

Os relatórios (`src/GEBEXP_REL_BIZ.prw` e `src/GEBEXP_REL_NUC.prw`) retornam arrays com dados consolidados. O técnico pode chamá-los direto; na tela, os relatórios de cada módulo ficam na aba **Relatórios** da página do módulo.

### 21.1 Relatório geral consolidado

```advpl
aGeral := GEBRELGERAL("01")  // empresa 01
```

Retorna array com 6 elementos, cada um sendo um array do relatório específico:
- `[1]` = resultado de `GEBRELFISCAL("01", "")`
- `[2]` = resultado de `GEBRELDERRAMA("01", "")`
- `[3]` = resultado de `GEBRELFIN("01")`
- `[4]` = resultado de `GEBRELSTOQUE("01")`
- `[5]` = resultado de `GEBRELCOMPRAS("01")`
- `[6]` = resultado de `GEBRELCONTABIL("01", "")`

### 21.2 Relatório por módulo

| Função | Para quê usar |
|--------|--------------|
| `GEBRELFISCAL("01", "202609")` | Ver notas, base, IBS/CBS e saldo da derrama de setembro |
| `GEBRELDERRAMA("01", "202609")` | Ver guias geradas, quantas pagas/vencidas, valor total |
| `GEBRELFIN("01")` | Posição financeira: quanto há para receber/pagar |
| `GEBRELSTOQUE("01")` | Produtos em estoque, itens abaixo do mínimo, valor total |
| `GEBRELCOMPRAS("01")` | Fornecedores, pedidos abertos/recebidos, cotações |
| `GEBRELCONTABIL("01", "202609")` | Lançamentos contábeis por competência |
| `GEBRELEMPRESAS()` | Listar todas as empresas com contagem de usuários e auditorias |
| `GEBRELUSUARIOS("01")` | Usuários cadastrados na empresa 01 |
| `GEBRELAUDITORIA("01", "20260901", "20260930")` | Histórico de acesso em setembro |
| `GEBRELMENTOR("01")` | Configurações do mentor na empresa 01 |
| `GEBRELCADASTROS("01")` | Quantidade de produtos, fornecedores, clientes e contas |

### 21.3 Pela tela

Os números do dia a dia estão no **Início** (capítulo 19). Os relatórios de cada módulo ficam na aba **Relatórios** da página do módulo (ex.: Financeiro → Relatório: fluxo de caixa projetado; Faturamento → Relatório: curva ABC); o resultado abre na página **Resultado**.

---

## 22. FAQ multi-empresa

**Posso ter mais de uma empresa no mesmo banco?** Sim. Cada empresa tem seu próprio "compartimento" (schema Postgres, ex.: `emp_01`, `emp_02`) e os dados de módulo ficam totalmente isolados entre empresas. O técnico provisiona uma empresa nova com `GEBDBProvisionaEmpresa(código, nome)`.

**O que acontece se eu usar o mesmo código de usuário em duas empresas?** O usuário é **um só**, cadastrado uma vez no catálogo compartilhado (GE2/GE2_SEC — mesma senha em qualquer empresa). O que existe por empresa é o **vínculo** (tabela GE2_EMP): sem vínculo com a empresa `02`, o usuário não entra lá mesmo com a senha certa.

**Como faço para logar em uma empresa específica?** Entre com usuário e senha e, se você estiver vinculado a mais de uma empresa, escolha-a na lista (capítulo 18). O sistema autentica a senha primeiro (nível de catálogo) e só lista as empresas em que você tem vínculo.

**O que é a tabela GEX?** É uma tabela temporária, dentro do schema da empresa ativa, que guarda o contexto da sessão (empresa, filial, usuário). Quando você loga, uma linha é criada; quando desloga (`GEBEXPCLEAR`), é removida. Você nunca precisa mexer nela manualmente.

**O que é a tabela GEH?** É o histórico de acesso — registra quem logou, em qual empresa, a que horas e de qual IP. Vive dentro do schema de cada empresa (só existe depois que uma empresa foi provisionada) e é útil para auditoria e segurança.

**E a GEI?** Audit log processual — registra operações internas do sistema (qual origem, qual tabela, qual registro, qual ação, que horas). Diferente do GEH (focado em login), o GEI acompanha o que o sistema faz por dentro.

**Posso ver dados de todas as empresas de uma vez?** Sim. Nos relatórios, se você passar `cEmpresa = ""` (vazio), o relatório considera todas as empresas. Ex.: `GEBRELGERAL("")` retorna dados consolidados de todas.

**Como crio uma empresa nova hoje?** Não existe mais uma migração que adiciona coluna `EMPRESA` a tabelas antigas — cada empresa ganha o próprio schema Postgres do zero, via `GEBDBProvisionaEmpresa(código, nome)`. Peça ao técnico para rodar o provisionamento antes do primeiro login naquela empresa.

---

## 23. Checklist do fecha-mês banânico estendido (multi-empresa)

Faça esta verificação **por empresa** (repete para cada uma das suas empresas):

**Vendas + notas**
- [ ] 1. Todas as vendas do mês estão `VENDIDA`? (Confira `SEM_ESTOQUE`/`BLOQUEADA` e corrija.)
- [ ] 2. Todas as notas estão `AUTORIZADA`? (As `EM_FILA` precisam ser resolvidas: reemitir a fila GE5.)

**Compras**
- [ ] 3. Todos os pedidos chegaram? (Pedidos ainda `ABERTO` em GCP3: cobrar fornecedor ou cancelar com o contador.)
- [ ] 4. Todas as NFs de entrada foram recebidas? (`GEBCPXENT` de cada pedido; NF sem entrada = estoque e pagar faltando.)
- [ ] 5. Cotações do mês estão gravadas? (Serve de prova do menor preço depois.)

**Caixa (financeiro)**
- [ ] 6. Todo dinheiro que entrou foi baixado? (Receber ainda `ABERTO` em GFN2: cobrar ou dar baixa parcial com `GEBFNBAI("REC", doc, valor)`.)
- [ ] 7. Toda conta a pagar foi lançada e baixada? (Pagar `ABERTO` em GFN3 vira dívida do mês seguinte; confira duplicados pelo documento.)
- [ ] 8. Fluxo confere? (`GEBNFLX()` → receber, pagar e saldo batem com o extrato da `CAIXA`?)

**Imposto + fiado + estoque + contador**
- [ ] 9. Apurei o mês? (`GEBFAPU("202609")` — confira o saldo em GF5.)
- [ ] 10. Gerei a guia? (`GEBDGER("202609")` → `GD202609`.)
- [ ] 11. Paguei ou parcelei? (`GEBDBAI` para pagar; `GEBDPAR` + `GEBDJUR` se atrasou/parcelou.)
- [ ] 12. Fiados: cobrei os atrasados? (`GEBVJUR(cliente, dias)`.)
- [ ] 13. Estoque confere com a prateleira? (Se não, ajuste com entrada `GEBVEST`.)
- [ ] 14. Rodei balancete + DRE e mandei ao contador? (`GEBBAL` + `GEBDRE`.)
- [ ] 15. Auditoria ok? (Olhada rápida em GEH para ver se não há acessos estranhos por empresa.)
- [ ] 16. Fiz backup do banco Postgres? (Peça ao técnico para confirmar o backup/dump do banco. Sem cópia, sem choro.)
- [ ] 17. Consolidei relatórios entre empresas? (`GEBRELGERAL("")` para visão global.)

**Comandos de emergência do técnico (cola rápida):**

```bash
advplc check src/GEBTUI.prw --include src
advplc run src/GEBWEB.prw          # API REST (porta 8090)
advplc serve src/GEBTUI.prw --port 8081
```

## 24. Backoffice: estoque, financeiro, contábil, compras, faturamento e frente de loja

Todos os módulos ficam no menu lateral. Na página de cada um, as operações estão nas abas de formulários (**Operações**, **Relatórios** e, no Financeiro, **Banco**). Os relatórios abrem na página **Resultado**; a primeira linha é o cabeçalho.

**Primeiro uso (uma vez)**
1. **Financeiro → Condição de pagamento:** cadastre as condições (`30,60,90`).
2. **Faturamento → Cliente (novo ou alterar):** cadastre os clientes, com limite de crédito, condição e tabela. Em **Preço na tabela**, informe os preços (tabela vazia = PADRAO).
3. **Estoque → Inventário (contagem):** informe a quantidade e o custo de cada produto. É assim que o estoque antigo ganha custo médio.
4. **Frente de loja → aba Cadastros → Cadastrar caixa:** a conta do dinheiro é criada sozinha (`CAIXA<código>`). Para receber PIX, crie a conta `BANCO` em Financeiro → Nova conta, ou ajuste `LOJ_CONTA_PIX`.

**Compras**
1. **Compras → Solicitação de compra** (itens na grade: produto, quantidade e necessidade; **Incluir item** para cada um).
2. **Gerar pedidos da solicitação:** usa o menor preço cotado e faz um pedido por fornecedor. Se preferir, monte direto em **Pedido de compra com itens**.
3. Pedido acima da alçada (`COM_ALCADA`) espera em **Aprovar ou rejeitar pedido (alçada)**.
4. **Documento de entrada:** sem itens na grade = recebe todo o pendente. Informe o frete; ele entra no custo.
5. Relatórios: pedidos em aberto, compras por fornecedor, solicitações pendentes.

**Faturamento**
1. **Pedido de venda** (preço vazio = tabela).
2. **Liberar:** confere crédito e estoque. Se ficar bloqueado, o motivo aparece; "forçar" exige a permissão de liberação.
3. **Faturar pedido:** sem itens na grade = todo o saldo. Emite a nota, baixa o estoque, gera os títulos e contabiliza.
4. **Devolução de venda:** informe a nota e os itens na grade. O título é abatido ou vira crédito do cliente.
5. Relatórios: faturamento e margem (por cliente ou produto), carteira de pedidos, curva ABC.

**Financeiro**
- **Título parcelado:** à mão, para o que não veio de compra ou venda.
- **Baixa:** mostra o saldo e já sugere juros e multa pelo atraso; dá para mudar, dar desconto e escolher a conta.
- **Transferência entre contas** e **movimento avulso** (tarifa, receita sem título).
- Relatórios: títulos por faixa de atraso, extrato da conta, fluxo de caixa projetado.

**Estoque**
- Movimento com custo, inventário, transferência entre armazéns e saldo/custo médio.
- Relatórios: kardex e posição valorizada (com os itens abaixo do mínimo).

**Contábil**
- Razão da conta, balancete do período e DRE.
- As contas e os eventos de lançamento padrão estão em Plano (GC1) e na GC4.

**PDV — o dia do caixa** *(a frente de caixa é o PDV web: menu **Frente de loja** do ERP abre `/pdv` em nova aba — porta 8090 do GEBWEB, com abas Venda, Caixa, Orçamentos, Devolução, Consultas, Cadastros, Relatórios e TEF/NFC-e; as "abas" citadas abaixo correspondem às abas do PDV web)*
1. **Abrir caixa** (aba Caixa) com o fundo de troco. A situação do caixa fica sempre visível na aba Venda.
2. **Vender** (aba Venda): adicione os produtos ao carrinho (preço e promoção já aparecem), informe desconto em valor e inclua os pagamentos (dinheiro, PIX, débito, crédito, fiado ou vale; pode misturar). Total, recebido e troco aparecem ao lado; **Finalizar venda** grava o cupom.
3. **Cancelar cupom** (aba Caixa): só com o caixa aberto e se o cupom não teve devolução.
4. **Sangria** (manda dinheiro para o cofre/banco) e **suprimento** (traz troco).
5. **Fechar caixa:** informe o dinheiro contado. O sistema mostra o esperado e a diferença e lança a sobra ou a falta. Depois abre o resumo do caixa.

**Frente de loja: recursos de balcão** (menu **Frente de loja**, abas Venda, Caixa, Orçamentos, Consultas, Cadastros, Relatórios, TEF e NFC-e e Devolução; abra o caixa na aba **Caixa** antes de vender)
- **Ler o produto:** na aba **Venda**, digite o código, o código de barras ou a etiqueta da balança e clique em **Adicionar**. Cadastre os códigos em *Código de barras / PLU de balança* (aba Cadastros):
  - o fator é quantas unidades uma leitura vale (caixa com 12 = 12);
  - para a balança, cadastre o PLU de 5 dígitos;
  - `LOJ_BALANCA` diz se a etiqueta traz o preço (`PRECO`, padrão) ou o peso (`PESO`).
- **Promoções:** em *Promoção* (aba Cadastros), escolha o tipo:
  - `PRECO`: preço promocional;
  - `LEVE`: leve N pague M;
  - `QTD`: % a partir de N unidades.
  - Informe o início e o fim. Valor 0 encerra a promoção.
  - Deixe o preço vazio na venda para a promoção valer.
- **Vendedor e CPF:** ficam no quadro **Finalizar** da venda (podem ficar vazios). A comissão sai no relatório *Comissão dos vendedores*.
- **Desconto alto:** com `LOJ_DESC_MAX` definido (por exemplo, 10), um desconto acima disso pede o usuário e a senha de um supervisor com a permissão "Frente de loja - libera desconto" (Núcleo → Permissão de perfil).
- **Orçamento:**
  1. O vendedor monta o carrinho na aba **Venda** e clica em **Salvar como orçamento**.
  2. O caixa informa o número no campo **Orçamento** da venda, inclui os pagamentos e finaliza.
  3. O orçamento vale 7 dias (`LOJ_ORC_DIAS`).
- **Troca ou devolução:**
  1. Na aba **Devolução**, informe o cupom, os produtos (grade de itens) e o modo: `VALE` (gera um vale-troca) ou `DINHEIRO` (sai da gaveta).
  2. Na compra seguinte, pague com a forma `VALE` e o número do vale.
  3. O saldo do vale-troca aparece na aba **Consultas**.
- **Balcão:**
  - *Consulta de preço:* preço da tabela, preço de hoje (com a promoção) e saldo;
  - *Segunda via do cupom:* o cupom de novo, com CPF, promoções, troco e devoluções.
- **Gerência:** *Relatório: gerencial da loja*, por dia, caixa, operador ou vendedor.

**Lote, série e endereço:**
1. Em **Estoque → Operações**, defina o controle do produto (*Controle de lote/série/endereço*, sem saldo) e cadastre os endereços.
2. Na entrada de compra, informe o lote (séries separadas por `;`), a validade e o endereço de cada item.
3. Venda, faturamento e loja tiram sozinhos o lote que vence primeiro.
4. Os relatórios mostram o saldo por lote e os lotes a vencer.

**Fechamento do mês:** em **Estoque → Operações → Fechar mês**, sempre o mês anterior ao atual e em ordem. Depois de fechado, nada com data até ele pode ser lançado. Para corrigir, reabra o último mês fechado.

**Devolução de compra:** **Compras → Operações → Devolução de compra**. Informe a nota de entrada e o fornecedor, e os itens na grade.

**Centro de custo:**
- Cadastre os centros e os rateios em **Contábil → Operações** (*Centro de custo* e *Rateio entre centros de custo*).
- Informe o centro no movimento avulso, na despesa a pagar (Financeiro → Operações), no pedido de venda e no cadastro do caixa.
- Relatório: resultado por centro de custo.

**Banco** (Financeiro → aba **Banco**):
1. Configure a cobrança da conta: banco (001 BB, 033 Santander, 104 Caixa, 237 Bradesco, 341 Itaú, 756 Sicoob), agência, conta, carteira e o código do beneficiário (convênio). Escolha o layout: 240 (todos) ou 400 (só Itaú e Bradesco). No Sicoob, informe a modalidade (padrão 01).
2. Gere os boletos dos títulos e a remessa CNAB. Antes do primeiro arquivo real, homologue com o banco.
3. Leia o retorno, que baixa os títulos pagos.
4. Importe o OFX do extrato, concilie (sozinho ou na mão) e lance as tarifas que só estão no banco.
5. Os arquivos ficam no servidor (caminho informado na tela) ou vão pela API no campo `conteudo`.

**TEF:**
- O padrão é o simulador. Troque em Frente de loja → aba **TEF e NFC-e** → **Configurar TEF** (precisa da permissão de configurar a empresa):
  - `HTTP`: URL e token do gateway;
  - `CIELO`: MerchantId e MerchantKey (a URL padrão é a sandbox). Serve para testes: o cartão é o de teste do parâmetro, não o do cliente.
- A chave do lojista nunca aparece de volta na tela nem na API.
- Para testar sem internet, rode `python3 tests/emuladores/cielo_emulador.py` e use a URL `http://127.0.0.1:18765`.
- No crédito, informe as parcelas.
- O relatório de transações TEF do dia serve para conferir com a adquirente.
- Se o caixa caiu no meio de uma venda, **Desfazer TEF pendente** (ou só abrir o caixa) resolve.

**Pela API:** `POST|GET /api/bo/{modulo}/{acao}`. As rotas estão em `docs/05-referencia-tecnica.md`, seção 12.

## 25. Integração: regime, tributos, retenções e correção do contábil

**Regime da empresa.** Configurar o Simples Nacional marca a empresa como `SIMPLES`; sem isso ela é `REGULAR`.
- O `SIMPLES` apura o DAS, e o IBS/CBS vai dentro dele.
- O `REGULAR` apura o IBS/CBS com guia própria.
- Para mudar à mão, grave o parâmetro `REGIME` da empresa.

**Tudo o que é imposto está na Derrama, e tudo o que é guia está no financeiro.**
- **Guias da Derrama:** IBS/CBS (`GD<mês>`), DAS (`DAS-<mês>`), ICMS/ISS fora do DAS e retenções (`RET-<tributo>-<mês>`).
- **No financeiro:** cada guia é um título a pagar de mesmo número; pague pela Derrama ou pelo financeiro.
- **Vencimento:** dia 20 do mês seguinte em dia útil. Ajuste com os parâmetros `DER_DIA_IBSCBS`, `DER_DIA_ICMS`, `DER_DIA_ISS` e `RET_DIA_<tributo>`.

**Retenções (Compras → Operações):**
1. Cadastre a regra em **Regra de retenção**: código, tributo (ISS, IRRF, INSS, PIS, COFINS ou CSLL) e alíquota. Ex.: `ISS5` = ISS 5%.
2. No **Documento de entrada**, informe os códigos separados por vírgula (ex.: `ISS5,IR15`). Pela API, use o campo `retencoes` com o mesmo texto.
3. O valor retido sai do título do fornecedor e vai para a guia do tributo no mês.
4. O **Relatório: retenções do mês** mostra documento, tributo, base, alíquota, valor e guia.

**Caminhos antigos.** Vender, Vender fiado, Dar entrada (Compras) e Baixar título continuam nas telas de sempre, mas agora passam pelo estoque com custo, pelo financeiro e pelo contábil novos:
- o fiado vira um título a receber `FIA-<número>`;
- a venda do balcão entra no `CAIXA`.

**Correção do contábil antigo** (Contábil → Operações → **Corrigir lançamentos antigos**; precisa da permissão de lançamento direto):
- Antes da integração, alguns pagamentos eram lançados como receita. A rotina estorna esses lançamentos e faz o certo.
- Pode rodar quantas vezes quiser: o que já foi corrigido não é mexido de novo. A tela mostra o que foi corrigido.

## 26. Emitir NFC-e de verdade na frente de loja

A NFC-e é o cupom fiscal eletrônico: cada venda vai para a SEFAZ e volta autorizada, com QR Code para o consumidor consultar. O GEBAN faz tudo sozinho depois de configurado. Você só precisa de:
- o certificado digital **A1** da empresa (arquivo `.pfx` e a senha);
- os dados da empresa (CNPJ, inscrição estadual, endereço).

**Passo a passo**, de preferência no navegador, em `https://SEU-DOMINIO/api/dfe/configurar`:
1. **Entrar** com a mesma empresa, usuário e senha do GEBAN. O usuário precisa da permissão "Fiscal - documentos eletrônicos"; o ADMIN já tem.
2. **Emitente:** CNPJ, inscrição estadual, razão social, regime (Simples, MEI ou normal), endereço. Para o município, digite parte do nome e escolha na lista. O GEBAN confere CNPJ e IE na hora.
3. **Certificado:** escolha o arquivo `.pfx` e digite a senha. O GEBAN confere se é da sua empresa e se está no prazo. A senha não fica guardada.
4. **Emissão:** deixe "Homologação" e ligue a NFC-e. Se veio de outro sistema, informe o próximo número.
5. **Testar comunicação com a SEFAZ.** Depois faça uma venda de teste no caixa: o cupom sai "SEM VALOR FISCAL".
6. Deu tudo certo? Volte em **Emissão**, escolha **Produção** e salve.

A lista "O que falta para emitir" fica no alto da página e também em Fiscal > Documentos eletrônicos. Cada linha diz o que fazer:
- **FALTA:** impede a emissão;
- **ATENÇÃO:** é um aviso (por exemplo, certificado vencendo ou notas em contingência).

**No caixa nada muda:** a venda é feita como sempre.
- Se a SEFAZ recusar, o caixa vê o motivo e a venda não é gravada (o cartão é desfeito). Corrija o cadastro do produto e venda de novo.
- **Internet caiu ou a SEFAZ está fora?** A venda sai "em contingência" e o cupom avisa. Quando a internet voltar, use **Frente de loja → TEF e NFC-e → NFC-e: transmitir as emitidas em contingência**. O prazo é de 24 horas.
- **Imprimir o cupom (DANFE):** use **Frente de loja > NFC-e: DANFE do cupom**. A tela mostra o cupom e um link para abrir no navegador e imprimir; ele também está na página de configuração, em "Imprimir DANFE NFC-e".
- **Cancelar:** é o mesmo "Cancelar cupom" de sempre, até 30 minutos depois da venda. Depois disso, faça a devolução.

**Produtos:** basta ter a NCM de 8 dígitos. O resto (CFOP 5102, CSOSN 102, unidade UN) vem do padrão. Para um produto diferente (substituição tributária, por exemplo), use Fiscal > Documentos eletrônicos > Perfil fiscal de produto. O código de barras cadastrado na loja vai para a nota sozinho.

## 27. NF-e no faturamento e nas devoluções

1. Ligue a NF-e em Fiscal > Documentos eletrônicos > Configuração (ou na página `/api/dfe/configurar`): "NF-e no faturamento" = S.
2. Para cada cliente (e para os fornecedores a quem você devolve mercadoria), faça o **Cadastro fiscal de cliente ou fornecedor**: CPF/CNPJ, se é contribuinte (com inscrição estadual) ou consumidor, endereço e município.
3. Fature como sempre (Faturamento > Faturar). A NF-e sai autorizada, com duplicatas quando a condição é a prazo. O DANFE A4 com código de barras abre pelo link "DANFE de um documento".
4. **Errou um dado que não muda valor?** Por exemplo, endereço ou complemento: use a **Carta de correção**.
5. **Devolução do cliente:**
   - consumidor: o GEBAN emite a nota de entrada sozinho;
   - empresa contribuinte: ela emite a NF-e de devolução, e você informa a chave dessa nota na devolução.
6. **Devolver ao fornecedor:** informe a chave da NF-e dele na entrada (ou na devolução). O GEBAN emite a NF-e de devolução referenciando essa chave.
7. **A SEFAZ não respondeu?** O GEBAN avisa que o documento ficou pendente e não grava a venda. Use **Resolver NF-e sem resposta da SEFAZ** e depois fature de novo.

## 28. Gerar o SPED Fiscal (EFD ICMS/IPI)

1. Uma vez só, preencha os dados da EFD: Fiscal > Documentos eletrônicos > **Configuração da EFD** (ou a seção 5 da página `/api/dfe/configurar`).
   - Contabilista: nome, CPF, CRC, e-mail e município.
   - Perfil (A, B ou C, conforme a sua UF) e atividade.
   - Códigos de receita do ICMS próprio, ST, DIFAL e FCP, e o dia do vencimento.
   - Saldo credor de ICMS anterior ao primeiro arquivo, se houver.
2. Antes de gerar, resolva as pendências do mês: NFC-e em contingência, NF-e sem resposta e notas de fornecedor sem importar.
3. Gere em **SPED Fiscal (EFD ICMS/IPI) da competência**, informando o mês (AAAAMM). A mensagem traz débitos, créditos, ICMS a recolher e saldo credor, e avisa as entradas que ficaram fora.
4. Baixe o arquivo pela página `/api/dfe/configurar` (botão "Baixar arquivo"). Abra-o no PVA da Receita, valide, assine com o certificado e transmita.
5. Corrigiu algo depois? Gere de novo a mesma competência como **substituto** (finalidade 1).
