# 06 — Guia Funcional do ERP GEBAN (fluxos, integrações e operação)

> **Autor:** Peder Munksgaard · **Data:** 26/09/2026 · **Idioma:** PT-BR
> **Fontes:** `docs/02-regras-negocio.md`, `src/*.prw`, suíte 67/67 PASS em 26/09/2026.
> Este guia mostra **como o sistema funciona na prática**: quem usa, em que ordem,
> o que acontece em cada passo e como os módulos conversam. Detalhe de API e
> assinatura de função está na Referência Técnica (`docs/05-referencia-tecnica.md`).
> PDFs gerados com o template `jmpm` (`md2pdf.py --template jmpm --cover`).

---

## 1. A promessa (MVP)

> **O MEI emite NF-e/NFS-e certo e quita a derrama sem multa.**

Tudo o mais existe para sustentar essa promessa quando a internet cai (fila GE5),
o cliente pede fiado (GV3) e o contador inventa lançamento direto às 23h58 (GC2 `DIRETO`).

## 2. Quem usa: perfis

- **Empresas:** MEI da barraca (`SIMPLES`), mercadinho (`SIMPLES`/`REGULAR`), prestador
  (`REGULAR`, NBS em vez de NCM). Sem GE1 ⇒ `REGULAR` (na dúvida, presume-se grande).
- **Usuários:** `CAIXA` (direta só com `PERMITE_DIRETA=S`), demais perfis liberados,
  miss nega. Conta global **`super`**: entra direto em qualquer empresa provisionada,
  cria empresas, altera qualquer usuário; nunca via REST sem ela mesma.
- **Mentor B** (o conselheiro): `AVISA_E_TRAVA` (bloqueia), `AVISA_E_LIBERA_COM_BO`
  (grava B.O. em GE3 e libera — botão "Assumo o B.O."), `DESLIGADO`/miss (libera sem
  rastro). Eventos: `EMISSAO`, `VENDA_IMPULSIVA`, `ESTOQUE_MINIMO` (só alerta),
  `LANC_DIRETO`, `PAG_IMPULSIVO`, `COMPRA_IMPULSIVA`.

## 3. Jornada completa do MEI (ponta a ponta)

1. **Login** (TUI 8081 ou `POST /api/login`): super/usuário + senha → empresa → filial
   → token/sessão. Primeira vez: o super cria a empresa no próprio login (bootstrap).
2. **Cadastros:** produto (`GF1_COD` + NCM + descrição), alíquota vigente (`GF2`),
   cliente do fiado, fornecedor, conta `CAIXA` (`SALDO 0`).
3. **Venda no balcão:** `GEBVVEN` baixa `GV1`, grava `GV2 VENDIDA`, chama o fiscal
   (`GEBFEMI` → `GF3 AUTORIZADA` + `GF4` + `CTBLAN`) ou `CTBLAN` direto.
4. **Sem internet:** modo `SO_FILA`/`ONLINE_FILA` → nota `EM_FILA` + fila `GE5`.
5. **Virada do mês:** `GEBFAPU(AAAAMM)` soma `IBS+CBS` → `GF5 SALDO` → `GEBDGER`
   gera guia `GD+competência ABERTA`.
6. **Quitar:** `GEBDBAI` concilia + `CTBLAN`. Atrasou? `GEBDJUR` (0,33%/dia, teto 20%,
   multa 2%), `GEBDPAR` (2+ parcelas, última ajusta), calote total `GEBDPRO` (protesto).
7. **Fechar:** balancete `GEBBAL` (débito == crédito por conta), DRE `GEBDRE`
   (receitas grupo 3 − despesas grupo 4), fluxo `GEBNFLX` (`{rec, pag, saldo}`).

## 4. Fluxos por módulo

### 4.1 Fiscal — emitir, apurar, creditar

> **Alíquota primeiro (02/10/2026):** NCM sem alíquota vigente tributa a zero. Cadastre em
> Fiscal → **+ Nova aliquota (NCM)** (IBS e CBS em %, vigência AAAAMMDD) antes de emitir.
`GEBFPRO/GEBFALI` (cadastros) → `GEBFEMI` (modos `ONLINE_PURO/ONLINE_FILA/SO_FILA`;
base > 0 autoriza; miss de produto tributa zero sem travar; idempotente por chave;
CTB nos dois caminhos) → `GEBFSPL` (divide total, última ajusta centavo) →
`GEBFAPU` (idempotente por competência: baixa lógica e reinsere; sem movimento = `.F.`)
→ `GEBFCRE` (`TRANSF`/`RESSARC`, sem lastro = `.F.`). Glosas: vigência (zero sem
alíquota), competência (só itens com header GF3 no mês), crédito sem origem.

### 4.2 Derrama — a conta do fisco
`GEBDGER` (idempotente, `VALOR = saldo GF5`) → `GEBDJUR` (fórmula da seção 2;
guia vazia/dias nulos = 0 sem gravar) → `GEBDPAR` (1x não é parcelar; reparcelar
substitui; guia `PARCELADA`, parcelas `ABERTA`) → `GEBDPRO` (GD3 `PROTESTO` + guia
`PROTESTADA`; fantasma = `.F.`) → `GEBDBAI` (concilia + `CTBLAN`). Números-guia:
base 1500, 10 dias → juros 49,50 + multa 30 = **1579,50**; 3x de 526,50.

### 4.3 Estoque, venda e fiado — o balcão
`GEBVEST` (positivo entra, negativo sai; novo produto nasce `MINIMO 10`; abaixo do
mínimo = alerta do Mentor, não trava) → `GEBVVEN` (guardas → `BLOQUEADA`; sem
tabela/saldo → `SEM_ESTOQUE` sem tocar o banco; Mentor travando → `BLOQUEADA` sem
tocar o banco; preço miss = 10) → `GEBVFIA` (teto duro **1000** = soma ABERTA +
novo; estourou = `.F.`) → `GEBVJUR` (mesma fórmula da Derrama por linha ABERTA).
Exemplo: em aberto 800 + pedido 300 = 1100 → nega; + 200 = 1000 → abre; atraso 30
dias em 200 → 19,80 + 4 = **223,80**.

### 4.4 Contábil — partida dobrada ou nada
`CTBLAN` (lê GC4, fallback `PADRAO`; sem parâmetro = stub que só loga) → `CTBGRV`
(GC2 + 2 pernas GC3, confere débito == crédito) → `GEBCDIR` (4 cadeados em ordem:
flag, perfil, GC4, Mentor; carimbo `DIRETO`) → `GEBBAL`/`GEBDRE`. Glosa contábil:
desbalanceado, conta vazia ou valor zerado = recusado, sem meio-lançamento.

### 4.5 Financeiro — o cofre de três rastros
`GEBFNCON` (conta nasce `SALDO 0`, idempotente) → `GEBFNREC` (receber, sem Mentor;
dup/zero nega) / `GEBFNPAG` (pagar, com guia `PAG_IMPULSIVO`) → `GEBFNBAI`
(parcial/total com clamp sem troco; `RECEBIDA`/`PAGA` × `ABERTO`; 1 movimento GFN4
+ `CAIXA` + `CTBLAN` por baixa) → `GEBNFLX` (só `ABERTO`; tabelas ausentes = zero).
Massa-guia: 50×100 receber + 50×50 pagar, tudo baixado → `CAIXA` **2500**, 100 movs.

### 4.6 Compras — o mercadão (pedido promete, NF cumpre)
`GEBCMFOR` (idempotente) → `GEBCMCOT` (só registra) → `GEBCMMEL` (menor preço) →
`GEBCPXPED` (itens + alçada GCQ2: acima de `COM_ALCADA` = `PENDENTE`) →
`GEBCPXAPR` (libera/rejeita) → `GEBCPXENT` (custo de entrada → `GEBFXTIT`/`GEBFNPAG` (se o Mentor/duplicidade
negar, aborta sem tocar nada) → estoque + `CTBLAN` + `RECEBIDO/RECEBIDA`). Massa-guia:
50 pedidos 2×10 → 50 `RECEBIDO` + 50 pagar de 20 + 100 un em estoque.
**Dois pagares, dois reis:** `GD1` = fisco (juros/parcela/protesto, morre em `GEBDBAI`);
`GFN3` = fornecedor (Mentor/baixa/fluxo, morre em `GEBFNBAI`). **Fiado × compra:**
fiado estoura no número (1000), compra estoura no conselho (Mentor, sem teto).

## 5. Integrações entre módulos (quem chama quem)

| De → Para | Gatilho | Efeito |
|---|---|---|
| Venda → Fiscal | `GF1+GF3` existem | `GEBFEMI` mesma chave (GF3/GF4 + CTB) |
| Venda → Contábil | sem fiscal | `CTBLAN` direto, uma vez só |
| Emissão → Contábil | sempre | `CTBLAN` em autorizada **e** em fila |
| Apuração → Derrama | `GEBFAPU` | `GEBDGER` cria a guia |
| Guia → Contábil | `GEBDBAI` | conciliação + `CTBLAN` |
| Pedido → Financeiro | `GEBCPXENT` | `GEBFXTIT`/`GEBFNPAG` (Mentor pode abortar tudo) |
| Pedido → Estoque | `GEBCPXENT` | `GEBVEST` por item (custo de entrada GCQ5) |
| Pedido → Contábil | `GEBCPXENT` | `CTBLAN` do total + retenções |
| Receber/Pagar → Contábil | `GEBFNBAI` | movimento + `CAIXA` + `CTBLAN` |
| Mentor → tudo | `GEBMNT(evento)` | trava/libera/B.O. antes de tocar o banco |
| Login → Tenant | `GEBSECLOGIN` OK | vínculo → schema → `GEBEXPCONTEXTO` → token |
| REST → tudo | dispatcher | mesmos endpoints de negócio da TUI |

## 6. Trackers e relatórios (rastreio e gerência)

- **Trackers** (array por etapa, ausência = vazio): `GEBTRAKCOMPRA` (pedido→itens→
  NF→estoque→pagar→contábil), `GEBTRAKVEND` (venda→estoque→NF→apuração→guia→baixa),
  `GEBTRAKNOTAFISCAL` (NF→itens→IBS/CBS→apuração→guia→juros/parcela/protesto→baixa),
  `GEBTRAKDERRAMA` (apuração→guia→juros→parcelas→protesto→baixa→contábil).
- **Relatórios:** fiscal (notas/base/IBS/CBS/débito/saldo/regime), derrama
  (guias/pagas/vencidas/parcelas), financeiro (contas/receber/pagar/saldo/movs),
  estoque (produtos/abaixo-mínimo/valor), compras (forn/pedidos/recebidos/cotações),
  contábil (lançamentos/débitos/créditos/saldo), geral (consolidado), empresas,
  usuários, auditoria (GEH), mentor, cadastros. Filtro de empresa opcional.

## 7. Telas (TUI 8081 e seus validadores)

> **Acesso (02/10/2026):** o menu Núcleo é só do ADMIN da empresa e do super; os demais
> usuários só trocam a própria senha. ADMIN só mexe em usuários exclusivos da própria
> empresa; usuário compartilhado entre empresas e criação de empresa são do super. As
> grades de Empresas/Unidades/Filiais/Usuários são só de consulta — use as ações do menu.

Login (usuário/senha/empresa/filial; super direto; bootstrap da 1ª empresa) → menu
7 módulos + Núcleo (11 opções, incl. **Trocar senha**: confirmação dupla, política,
guarda do super, nome/perfil). Browses 1:1 com tabelas (**somente leitura segura
para usuários** — Incluir/Alterar no browse não gera hash/vínculo). 13 validadores
centrais (`GEBGUI_VLD`) barram na porta: produto/fornecedor/cliente existentes,
estoque suficiente, teto do fiado, título/saldo para baixa, params de emissão e
apuração, `PERMITE_DIRETA`, leitura/escrita de config.

## 8. Tabela de guardas (condição → efeito, resumo executivo)

| Tentativa | Resultado |
|---|---|
| Usuário fantasma | `.F.`, nada acontece |
| Caixa sem `PERMITE_DIRETA` | direta negada com motivo logado |
| Mentor `AVISA_E_TRAVA` | operação não acontece (venda `BLOQUEADA`, nota vai à fila) |
| Venda sem estoque/saldo | `SEM_ESTOQUE` sem tocar o banco |
| Fiado acima de 1000 | `.F.` sem gravar |
| Apuração sem movimento | `.F.` (não apura no vazio) |
| Parcela em 1x | `.F.` ("parcelar em 1x chama-se pagar") |
| Lançamento desbalanceado/zerado | recusado |
| Escrita negada por RBAC | 403 **sem executar** (provado por teste) |
| Não-super criando empresa / tocando super | 403 / bloqueio total |
| Token/ chave com aspas | 400 sem SQL |
| Super sem vínculo em empresa nova | vínculo garantido na hora, entra direto |

## 9. Operação: dia a dia e fecha-mês

Dia: vender (online ou fila), baixar títulos (`RECEBIDA`/`PAGA`), conferir fluxo.
Mês: emitir tudo → `GEBFAPU(AAAAMM)` → conferir `GF5` → `GEBDGER` → pagar via
`GEBDBAI` (ou parcelar/protestar) → `GEBBAL` (débito == crédito) → `GEBDRE` →
`GEBNFLX`. Sem internet: `SO_FILA`, fila `GE5`, reprocessar depois (idempotência
por chave/competência: reemissão não duplica). Auditoria: GE3 (B.O.s), GEH
(acessos), trackers por documento. Detalhe de comandos e troubleshooting completo:
`docs/04-manual-utilizacao.md`.

## 10. Glossário rápido

`D_E_L_E_T_` (exclusão lógica), `R_E_C_N_O_` (chave interna), `ABERTA/RECEBIDA/PAGA/
PARCELADA/PROTESTADA/VENDIDA/BLOQUEADA/SEM_ESTOQUE/EM_FILA/AUTORIZADA`,
`AVISA_E_TRAVA/LIBERA_COM_BO/DESLIGADO`, `TRANSF/RESSARC`, `ONLINE_PURO/
ONLINE_FILA/SO_FILA`, `AUTO/MANUAL/CONTABIL_DIRETA`, `DIRETO/AUTO` (carimbo),
EEUUFF (filial), super (conta global por username).

*Divergência entre este texto e o fonte? O `.prw` vence — ver Referência Técnica.*
