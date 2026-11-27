#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBCTX.prw"
#include "GEBEST.prw"
#include "GEBFNX.prw"
#include "GEBFAT.prw"
#include "GEBTEF.prw"
#include "GEBLOJ_CAD.prw"
#include "GEBSEC_LOGIN.prw"
#include "GEBSEC_RBA.prw"
#include "GEBDFE.prw"
#include "GEBCRY.prw"
#include "GESSAR.prw"

/*/{Protheus.doc} GEBLOJ
    Frente de loja (inspirado em SLG/LOJA120, LOJA701 e SL1/SL2/SL4 do
    Protheus: caixa, venda assistida, cupom, itens e pagamentos).
    - GLJ1 caixas (conta financeira do dinheiro e armazem); GLJ2 sessao
      (abertura com fundo de troco, fechamento com valor contado,
      esperado e diferenca).
    - GEBLOJVEN: cupom com varios itens (preco da tabela PADRAO se nao
      informado), desconto em valor rateado nos itens, NFC-e pelo escritor
      do faturamento (GEBFATNOTA), saida do estoque ao CM e pagamentos:
      DINHEIRO (troco so' em dinheiro) entra na conta do caixa; PIX na conta
      GE4 LOJ_CONTA_PIX (padrao BANCO); DEBITO/CREDITO viram titulo a
      receber da administradora (D+1 / D+30, liquido da taxa GE4
      LOJ_TAXA_DEB / LOJ_TAXA_CRED, padrao 1,5% / 3%); FIADO vira titulo do
      cliente (GE4 LOJ_FIADO_DIAS, padrao 30). Lancamentos LOJ_DINHEIRO,
      LOJ_PIX, LOJ_CARTAO, LOJ_TAXA, LOJ_FIADO e VENDA_CMV.
    - GEBLOJCAN: cancela o cupom da sessao aberta (estoque volta, nota
      CANCELADA, dinheiro/PIX estornados, titulos de cartao/fiado
      cancelados se ainda sem baixa, lancamentos estornados).
    - GEBLOJSAN: sangria (caixa -> GE4 LOJ_CONTA_COFRE, padrao BANCO) e
      suprimento (cofre -> caixa).
    - GEBLOJFECHA: esperado = fundo + dinheiro liquido + suprimentos -
      sangrias; a diferenca do contado entra/sai da conta do caixa
      (movimento avulso, contabilizado).
    - Relatorios: GEBLOJRESUMO (sessao) e GEBLOJVENDAS (dia, por produto).
    - Ampliacao (19/10/2026, GEBLOJ_CAD e GEBLOJ_OPE): codigo de barras e
      balanca, promocoes, vendedor, CPF na nota, limite de desconto (GE4
      LOJ_DESC_MAX, % do bruto) com liberacao do supervisor (LOJA/DESCONTO),
      vale-troca como pagamento (VALE), orcamento, devolucao no caixa,
      segunda via, consulta de preco, gerencial e comissao.
    @type Modulo frente de loja
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBLOJMIG()
    Local lOk := GEBFATMIG() .And. GEBTEFMIG() .And. GEBLOJCADMIG()
    lOk := lOk .And. BOTAB("GLJ1", "GLJ1_COD TEXT NOT NULL, GLJ1_NOME TEXT NOT NULL, GLJ1_CONTA TEXT NOT NULL, GLJ1_LOCAL TEXT NOT NULL, GLJ1_CC TEXT NOT NULL", "GLJ1_COD")
    lOk := lOk .And. BOTAB("GLJ2", "GLJ2_SESSAO TEXT NOT NULL, GLJ2_CAIXA TEXT NOT NULL, GLJ2_OPER TEXT NOT NULL, GLJ2_ABERT TEXT NOT NULL, " + ;
        "GLJ2_HORA TEXT NOT NULL, GLJ2_FUNDO NUMERIC(18,2) NOT NULL, GLJ2_STATUS TEXT NOT NULL, GLJ2_FECH TEXT NOT NULL, " + ;
        "GLJ2_CONTADO NUMERIC(18,2) NOT NULL, GLJ2_ESPERADO NUMERIC(18,2) NOT NULL, GLJ2_DIFER NUMERIC(18,2) NOT NULL", "GLJ2_SESSAO")
    lOk := lOk .And. BOTAB("GLJ3", "GLJ3_CUPOM TEXT NOT NULL, GLJ3_SESSAO TEXT NOT NULL, GLJ3_CLI TEXT NOT NULL, GLJ3_DATA TEXT NOT NULL, " + ;
        "GLJ3_BRUTO NUMERIC(18,2) NOT NULL, GLJ3_DESC NUMERIC(18,2) NOT NULL, GLJ3_TOTAL NUMERIC(18,2) NOT NULL, GLJ3_CUSTO NUMERIC(18,2) NOT NULL, " + ;
        "GLJ3_STATUS TEXT NOT NULL, GLJ3_NOTA TEXT NOT NULL", "GLJ3_CUPOM")
    lOk := lOk .And. BOTAB("GLJ4", "GLJ4_CUPOM TEXT NOT NULL, GLJ4_PROD TEXT NOT NULL, GLJ4_QTD NUMERIC(18,4) NOT NULL, " + ;
        "GLJ4_PRECO NUMERIC(18,6) NOT NULL, GLJ4_VALOR NUMERIC(18,2) NOT NULL, GLJ4_CUSTO NUMERIC(18,2) NOT NULL", "GLJ4_CUPOM")
    lOk := lOk .And. BOTAB("GLJ5", "GLJ5_CUPOM TEXT NOT NULL, GLJ5_FORMA TEXT NOT NULL, GLJ5_VALOR NUMERIC(18,2) NOT NULL, " + ;
        "GLJ5_TROCO NUMERIC(18,2) NOT NULL, GLJ5_TAXA NUMERIC(18,2) NOT NULL, GLJ5_DOC TEXT NOT NULL, GLJ5_PARC INTEGER NOT NULL, GLJ5_TEF TEXT NOT NULL", "GLJ5_CUPOM")
    lOk := lOk .And. BOTAB("GLJ6", "GLJ6_SESSAO TEXT NOT NULL, GLJ6_TIPO TEXT NOT NULL, GLJ6_VALOR NUMERIC(18,2) NOT NULL, " + ;
        "GLJ6_MOTIVO TEXT NOT NULL, GLJ6_DATA TEXT NOT NULL", "GLJ6_SESSAO")
    // Regime da venda (comprovante x fiscal) e crypto: colunas novas nas
    // tabelas antigas + tabelas dos modulos novos.
    lOk := lOk .And. TCSqlExec("ALTER TABLE GLJ3 ADD COLUMN IF NOT EXISTS GLJ3_REGIME TEXT NOT NULL DEFAULT ' '")
    lOk := lOk .And. GEBCRYMIG() .And. GESSARMIG()
Return lOk

/*/{Protheus.doc} GEBLOJCX
    Cadastra/altera um caixa. A conta financeira (padrao CAIXA<cod>) e'
    criada se nao existir.
    @type Cadastro frente de loja
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBLOJCX(cCod, cNome, cConta, cLocal, cCC)
    Local cFil := FWxFilial("GLJ1")
    cCod := Upper(BOCOL(cCod))
    cConta := Upper(BOCOL(cConta))
    If cCod == "" .Or. Len(cCod) > 10
        Return {.F., "codigo_invalido: 1 a 10 caracteres"}
    EndIf
    If cConta == ""
        cConta := "CAIXA" + cCod
    EndIf
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    If !GEBCTXRATEIA(cCC, 1)[1]
        Return {.F., GEBCTXRATEIA(cCC, 1)[2]}
    EndIf
    GEBFNCON(cConta, "Caixa " + cCod)
    TCSqlExec("UPDATE GLJ1 SET D_E_L_E_T_ = '*' WHERE GLJ1_FILIAL = " + GEBDBQuote(cFil) + " AND GLJ1_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GLJ1 (D_E_L_E_T_, GLJ1_FILIAL, GLJ1_COD, GLJ1_NOME, GLJ1_CONTA, GLJ1_LOCAL, GLJ1_CC) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
        GEBDBQuote(cCod) + ", " + GEBDBQuote(BOCOL(cNome)) + ", " + GEBDBQuote(cConta) + ", " + GEBDBQuote(BOCOL(cLocal)) + ", " + GEBDBQuote(Upper(BOCOL(cCC))) + ")")
Return {.T., "caixa " + cCod + " gravado (conta " + cConta + ")"}

/*/{Protheus.doc} GEBLOJABRE
    Abre a sessao do caixa (uma aberta por caixa).
    @type Operacao frente de loja
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, cSessao}
/*/
User Function GEBLOJABRE(cCaixa, cOper, nFundo, cData)
    Local cSes := ""
    cCaixa := Upper(BOCOL(cCaixa))
    nFundo := Round(BOVAL(nFundo), 2)
    cData := BODATA(cData)
    If cData == "" .Or. nFundo < 0
        Return {.F., "data_ou_fundo_invalidos", ""}
    EndIf
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas", ""}
    EndIf
    If Len(LOJCaixa(cCaixa)) == 0
        Return {.F., "caixa_inexistente: " + cCaixa, ""}
    EndIf
    If Len(TCSqlQuery("SELECT GLJ2_SESSAO FROM GLJ2 WHERE GLJ2_FILIAL = " + GEBDBQuote(FWxFilial("GLJ2")) + " AND GLJ2_CAIXA = " + GEBDBQuote(cCaixa) + ;
            " AND GLJ2_STATUS = 'ABERTA' AND D_E_L_E_T_ = ' '")) > 0
        Return {.F., "caixa_ja_aberto: " + cCaixa, ""}
    EndIf
    // Transacoes de cartao que ficaram pendentes (venda interrompida) sao desfeitas.
    GEBTEFRESOLVE()
    cSes := "S" + BOSEQ("LOJ_SESSAO", 7)
    TCSqlExec("INSERT INTO GLJ2 (D_E_L_E_T_, GLJ2_FILIAL, GLJ2_SESSAO, GLJ2_CAIXA, GLJ2_OPER, GLJ2_ABERT, GLJ2_HORA, GLJ2_FUNDO, GLJ2_STATUS, " + ;
        "GLJ2_FECH, GLJ2_CONTADO, GLJ2_ESPERADO, GLJ2_DIFER) VALUES (' ', " + GEBDBQuote(FWxFilial("GLJ2")) + ", " + GEBDBQuote(cSes) + ", " + ;
        GEBDBQuote(cCaixa) + ", " + GEBDBQuote(BOCOL(cOper)) + ", " + GEBDBQuote(cData) + ", " + GEBDBQuote(Time()) + ", " + BONUM(nFundo, 2) + ;
        ", 'ABERTA', '', 0, 0, 0)")
Return {.T., "sessao " + cSes + " aberta", cSes}

/*/{Protheus.doc} GEBLOJVEN
    Venda no caixa (cupom).
    @type Operacao frente de loja
    @author Peder Munksgaard
    @since 18/10/2026
    @param aItens {{cProd, nQtd[, nPreco]}...}: produto, codigo de barras ou
           etiqueta de balanca (GEBLOJRESOLVE). Sem preco = tabela PADRAO ou
           promocao vigente (GEBLOJPRECO).
    @param aPagtos {{cForma, nValor[, nParcelas[, cDoc]]}...}: DINHEIRO, PIX,
           DEBITO, CREDITO (parcelado em nParcelas x 30 dias), FIADO, VALE
           (cDoc = numero do vale-troca). Cartao passa pelo TEF (GEBTEF) se
           GE4 LOJ_TEF <> N: autoriza antes de gravar, confirma depois;
           negado = venda recusada e as aprovadas desfeitas.
    @param nDesc Desconto em valor sobre o cupom. Acima de GE4 LOJ_DESC_MAX
           (% do bruto; vazio = sem limite) exige operador ou supervisor
           (cSuperv + cSenhaSup) com permissao LOJA/DESCONTO.
    @param cVend Vendedor (GLJC); cCPF CPF/CNPJ na nota; cOrc orcamento de origem
    @return {lOk, cMsg, {cCupom, nTotal, nTroco, cNota}}
/*/
User Function GEBLOJVEN(cSessao, aItens, aPagtos, cCli, nDesc, cVend, cCPF, cSuperv, cSenhaSup, cOrc, cRegime)
    Local aSes := {}
    Local aCx := {}
    Local aIt := {}
    Local aNF := {}
    Local aR := {}
    Local cCupom := ""
    Local cNota := ""
    Local cForma := ""
    Local cData := ""
    Local cDoc := ""
    Local cPix := ""
    Local cCryConta := ""
    Local cMoeda := ""
    Local cEndereco := ""
    Local aCry := {}
    Local aCryQ := {}
    Local lDin := .F.
    Local nBruto := 0
    Local nTot := 0
    Local nPago := 0
    Local nDin := 0
    Local nTroco := 0
    Local nCusto := 0
    Local nTaxa := 0
    Local nVal := 0
    Local nAc := 0
    Local nPreco := 0
    Local nI := 0
    Local nJ := 0
    Local aTef := {}
    Local aPro := {}
    Local aVales := {}
    Local cAutor := ""
    Local nMax := 0
    Local aTefAut := {}
    Local aBrutoIt := {}
    Local aDfe := {}
    Local cStDfe := ""

    cSessao := Upper(BOCOL(cSessao))
    cVend := Upper(BOCOL(cVend))
    cCPF := GEBLOJDIGITOS(cCPF)
    cOrc := Upper(BOCOL(cOrc))
    cCli := Upper(BOCOL(cCli))
    // Regime da venda: COMPROVANTE = so' comprovante interno (sem NFC-e);
    // FISCAL/vazio = comportamento padrao (NFC-e se DFE_NFCE=S).
    cRegime := Upper(BOCOL(cRegime))
    If cRegime == ""
        cRegime := "FISCAL"
    EndIf
    If !(cRegime == "FISCAL" .Or. cRegime == "COMPROVANTE")
        Return {.F., "regime_invalido: FISCAL ou COMPROVANTE", {}}
    EndIf
    nDesc := Round(BOVAL(nDesc), 2)
    If aItens == Nil .Or. Len(aItens) == 0 .Or. aPagtos == Nil .Or. Len(aPagtos) == 0
        Return {.F., "itens_e_pagamentos_obrigatorios", {}}
    EndIf
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aSes := LOJSessao(cSessao)
    If Len(aSes) == 0 .Or. !(aSes[3] == "ABERTA")
        Return {.F., "sessao_nao_aberta: " + cSessao, {}}
    EndIf
    aCx := LOJCaixa(aSes[2])
    cData := aSes[4]
    If !(cVend == "") .And. !GEBLOJVENDOK(cVend)
        Return {.F., "vendedor_inexistente: " + cVend, {}}
    EndIf
    If !(cCPF == "") .And. !GEBLOJCPFOK(cCPF)
        Return {.F., "cpf_cnpj_invalido", {}}
    EndIf
    For nI := 1 To Len(aItens)
        If BOCOL(aItens[nI][1]) == "" .Or. BOVAL(aItens[nI][2]) <= 0
            Return {.F., "item_invalido: " + BONUM(nI, 0), {}}
        EndIf
        nPreco := 0
        If Len(aItens[nI]) >= 3
            nPreco := BOVAL(aItens[nI][3])
        EndIf
        aR := GEBLOJRESOLVE(aItens[nI][1], aItens[nI][2], nPreco)
        If !aR[1]
            Return {.F., aR[2], {}}
        EndIf
        cDoc := aR[3][1]
        nVal := aR[3][2]
        nPreco := aR[3][3]
        aAdd(aPro, {"", 0})
        If nPreco <= 0
            aR := GEBLOJPRECO(cDoc, nVal, cData)
            nPreco := aR[1]
            aPro[nI] := {aR[2], aR[3]}
        EndIf
        If nPreco <= 0
            Return {.F., "produto_sem_preco: " + cDoc, {}}
        EndIf
        If GEBESTSLD(cDoc, aCx[3])[1] < nVal .And. !(BOPARM("EST_NEGATIVO", "N") == "S")
            Return {.F., "saldo_insuficiente: " + cDoc, {}}
        EndIf
        aR := GEBESTVALLOTE(cDoc, aCx[3], "S", nVal, {}, "", cData)
        If !aR[1]
            Return {.F., aR[2], {}}
        EndIf
        aAdd(aIt, {cDoc, nVal, nPreco, Round(nVal * nPreco, 2)})
        nBruto := nBruto + aIt[nI][4]
    Next nI
    cDoc := ""
    nVal := 0
    nTot := Round(nBruto - nDesc, 2)
    If nDesc < 0 .Or. nTot <= 0
        Return {.F., "desconto_invalido", {}}
    EndIf
    // Desconto acima do limite: o operador ou um supervisor com LOJA/DESCONTO libera.
    // Com LOJ_REG_ATIVO=S o teto depende do regime e de haver dinheiro.
    For nI := 1 To Len(aPagtos)
        If Upper(BOCOL(aPagtos[nI][1])) == "DINHEIRO"
            lDin := .T.
        EndIf
    Next nI
    nMax := LOJDescMax(cRegime, lDin)
    If nDesc > Round(nBruto * nMax / 100, 2)
        If GEBSECRBAC(aSes[6], "LOJA", "DESCONTO")
            cAutor := aSes[6]
        ElseIf BOCOL(cSuperv) == ""
            Return {.F., "desconto_acima_do_limite: " + BONUM(nMax, 2) + "% (pede liberacao do supervisor)", {}}
        ElseIf !(GEBSECLOGIN(BOCOL(cSuperv), BOSTR(cSenhaSup), "pdv") == "OK") .Or. !GEBSECRBAC(BOCOL(cSuperv), "LOJA", "DESCONTO")
            Return {.F., "liberacao_recusada: supervisor sem senha valida ou sem LOJA/DESCONTO", {}}
        Else
            cAutor := BOCOL(cSuperv)
        EndIf
    EndIf
    For nI := 1 To Len(aPagtos)
        cForma := Upper(BOCOL(aPagtos[nI][1]))
        If AScan({"DINHEIRO", "PIX", "DEBITO", "CREDITO", "FIADO", "VALE", "CRYPTO"}, cForma) == 0 .Or. BOVAL(aPagtos[nI][2]) <= 0
            Return {.F., "pagamento_invalido: " + cForma, {}}
        EndIf
        If cForma == "CRYPTO"
            // Doc do pagamento crypto: "MOEDA|ENDERECO".
            aCry := StrTokArr(LOJDocPg(aPagtos[nI]), "|")
            If Len(aCry) < 2
                Return {.F., "crypto_invalido: informe MOEDA|ENDERECO", {}}
            EndIf
            cMoeda := Upper(BOCOL(aCry[1]))
            cEndereco := BOCOL(aCry[2])
            If GEBCRYMOEDAPOS(cMoeda) == 0 .Or. cEndereco == ""
                Return {.F., "crypto_invalido: moeda ou endereco", {}}
            EndIf
        EndIf
        If cForma == "VALE"
            cDoc := LOJDocPg(aPagtos[nI])
            aR := TCSqlQuery("SELECT GLJF_SALDO AS S FROM GLJF WHERE GLJF_FILIAL = " + GEBDBQuote(FWxFilial("GLJF")) + " AND GLJF_VALE = " + ;
                GEBDBQuote(cDoc) + " AND GLJF_STATUS = 'ABERTO' AND D_E_L_E_T_ = ' '")
            If Len(aR) == 0 .Or. AScan(aVales, cDoc) > 0
                Return {.F., "vale_invalido: " + cDoc, {}}
            EndIf
            If BOVAL(aPagtos[nI][2]) > BOVAL(aR[1]:S)
                Return {.F., "vale_sem_saldo: " + cDoc + " tem " + BONUM(BOVAL(aR[1]:S), 2), {}}
            EndIf
            aAdd(aVales, cDoc)
            cDoc := ""
        EndIf
        If cForma == "FIADO" .And. cCli == ""
            Return {.F., "fiado_exige_cliente", {}}
        EndIf
        If LOJParc(aPagtos[nI]) > 1 .And. !(cForma == "CREDITO")
            Return {.F., "so_credito_parcela: " + cForma, {}}
        EndIf
        If LOJParc(aPagtos[nI]) > 12
            Return {.F., "parcelas_acima_de_12", {}}
        EndIf
        If cForma == "DINHEIRO"
            nDin := nDin + BOVAL(aPagtos[nI][2])
        EndIf
        nPago := nPago + BOVAL(aPagtos[nI][2])
    Next nI
    nPago := Round(nPago, 2)
    nTroco := Round(nPago - nTot, 2)
    If nTroco < 0
        Return {.F., "pagamento_insuficiente: falta " + BONUM(-nTroco, 2), {}}
    EndIf
    If nTroco > nDin
        Return {.F., "troco_so_em_dinheiro", {}}
    EndIf
    cPix := BOPARM("LOJ_CONTA_PIX", "BANCO")
    cCryConta := BOPARM("CRY_CONTA", "")
    For nI := 1 To Len(aPagtos)
        aAdd(aCryQ, {})
    Next nI
    For nI := 1 To Len(aPagtos)
        If Upper(BOCOL(aPagtos[nI][1])) == "PIX" .And. Len(TCSqlQuery("SELECT GFN1_CONTA FROM GFN1 WHERE GFN1_FILIAL = " + ;
                GEBDBQuote(FWxFilial("GFN1")) + " AND GFN1_CONTA = " + GEBDBQuote(cPix) + " AND D_E_L_E_T_ = ' '")) == 0
            Return {.F., "conta_pix_inexistente: " + cPix, {}}
        EndIf
        If Upper(BOCOL(aPagtos[nI][1])) == "CRYPTO"
            If cCryConta == "" .Or. Len(TCSqlQuery("SELECT GFN1_CONTA FROM GFN1 WHERE GFN1_FILIAL = " + GEBDBQuote(FWxFilial("GFN1")) + ;
                    " AND GFN1_CONTA = " + GEBDBQuote(cCryConta) + " AND D_E_L_E_T_ = ' '")) == 0
                Return {.F., "conta_crypto_inexistente: configure CRY_CONTA com uma conta do financeiro", {}}
            EndIf
            aCry := StrTokArr(LOJDocPg(aPagtos[nI]), "|")
            cMoeda := Upper(BOCOL(aCry[1]))
            // Uma chamada ao CoinGecko por pagamento: a liquidacao reusa a
            // cotacao guardada aqui (aR[3] = {uri, endereco, qtd, cot}).
            aR := GEBCRYQRCODE(cMoeda, Round(BOVAL(aPagtos[nI][2]), 2))
            If !aR[1]
                Return {.F., "crypto: " + aR[2], {}}
            EndIf
            aCryQ[nI] := aR
        EndIf
    Next nI

    // TEF: autoriza os cartoes antes de gravar qualquer coisa.
    cCupom := "CP" + BOSEQ("LOJ_CUPOM", 8)
    aTef := {}
    For nI := 1 To Len(aPagtos)
        aAdd(aTef, "")
        aAdd(aTefAut, {})
        cForma := Upper(BOCOL(aPagtos[nI][1]))
        If (cForma == "DEBITO" .Or. cForma == "CREDITO") .And. !(BOPARM("LOJ_TEF", "S") == "N")
            aR := GEBTEFAUT(cForma, BOVAL(aPagtos[nI][2]), LOJParc(aPagtos[nI]), cCupom)
            If !aR[1]
                For nJ := 1 To Len(aTef)
                    If !(aTef[nJ] == "")
                        GEBTEFDESF(aTef[nJ])
                    EndIf
                Next nJ
                Return {.F., aR[2], {}}
            EndIf
            aTef[nI] := aR[3][1]
            aTefAut[nI] := aR[3]
        EndIf
    Next nI

    // Desconto rateado nos itens (o ultimo fica com o centavo) para a nota.
    cNota := "NFC" + BOSEQ("LOJ_NFC", 8)
    For nI := 1 To Len(aIt)
        aAdd(aBrutoIt, aIt[nI][4])
        nVal := Round(aIt[nI][4] * nTot / nBruto, 2)
        If nI == Len(aIt)
            nVal := Round(nTot - nAc, 2)
        EndIf
        nAc := nAc + nVal
        aIt[nI][4] := nVal
    Next nI

    // NFC-e real (GE4 DFE_NFCE = S): autorizada ou em contingencia segue; rejeitada desfaz o TEF.
    // Regime COMPROVANTE nunca emite documento fiscal (so' comprovante interno).
    If BOPARM("DFE_NFCE", "N") == "S" .And. !(cRegime == "COMPROVANTE")
        aDfe := GEBDFENFCE(cCupom, LOJItensDfe(aIt, aBrutoIt), LOJPagDfe(aPagtos, aTefAut), cCPF)
        If !aDfe[1]
            For nJ := 1 To Len(aTef)
                If !(aTef[nJ] == "")
                    GEBTEFDESF(aTef[nJ])
                EndIf
            Next nJ
            Return {.F., aDfe[2], {}}
        EndIf
        cNota := aDfe[3][1]
        cStDfe := aDfe[3][2]
    EndIf
    aR := {}
    For nI := 1 To Len(aIt)
        aAdd(aR, {aIt[nI][1], aIt[nI][2], Round(aIt[nI][4] / aIt[nI][2], 6)})
    Next nI
    If cRegime == "COMPROVANTE"
        // Comprovante interno nao e' documento fiscal: sem GF3/GF4 (nao entra
        // na apuracao de IBS/CBS nem no DAS). Devolucao usa GLJ4, nao GF4.
        aNF := {"comprovante", 0, 0, 0}
    Else
        aNF := GEBFATNOTA(cNota, aR, cData)
    EndIf
    If cStDfe == "CONTINGENCIA"
        // Livro interno: so' entra na apuracao quando a SEFAZ autorizar (GEBDFETRANSMITE).
        TCSqlExec("UPDATE GF3 SET GF3_STATUS = 'CONTINGENCIA' WHERE GF3_FILIAL = " + GEBDBQuote(FWxFilial("GF3")) + " AND GF3_CHAVE = " + ;
            GEBDBQuote(cNota) + " AND D_E_L_E_T_ = ' '")
        aNF[1] := "NFC-e em contingencia"
    ElseIf cStDfe == "AUTORIZADA"
        TCSqlExec("UPDATE GF3 SET GF3_STATUS = 'AUTORIZADA' WHERE GF3_FILIAL = " + GEBDBQuote(FWxFilial("GF3")) + " AND GF3_CHAVE = " + ;
            GEBDBQuote(cNota) + " AND D_E_L_E_T_ = ' '")
        aNF[1] := "NFC-e autorizada"
    EndIf
    For nI := 1 To Len(aIt)
        aR := GEBESTMOV(aIt[nI][1], aCx[3], "S", aIt[nI][2], 0, "PDV", cCupom, cData)
        nCusto := nCusto + aR[3][2]
        TCSqlExec("INSERT INTO GLJ4 (D_E_L_E_T_, GLJ4_FILIAL, GLJ4_CUPOM, GLJ4_PROD, GLJ4_QTD, GLJ4_PRECO, GLJ4_VALOR, GLJ4_CUSTO) VALUES (' ', " + ;
            GEBDBQuote(FWxFilial("GLJ4")) + ", " + GEBDBQuote(cCupom) + ", " + GEBDBQuote(aIt[nI][1]) + ", " + BONUM(aIt[nI][2], 4) + ", " + ;
            BONUM(aIt[nI][3], 6) + ", " + BONUM(aIt[nI][4], 2) + ", " + BONUM(aR[3][2], 2) + ")")
    Next nI

    // Pagamentos (o troco sai do dinheiro).
    For nI := 1 To Len(aPagtos)
        cForma := Upper(BOCOL(aPagtos[nI][1]))
        nVal := Round(BOVAL(aPagtos[nI][2]), 2)
        cDoc := ""
        nTaxa := 0
        If cForma == "DINHEIRO"
            If nTroco > 0
                nVal := Round(nVal - nTroco, 2)
            EndIf
            If nVal > 0
                GEBFXMOVCONTA(aCx[2], "C", nVal, "Venda " + cCupom, cCupom, cData)
                GEBCTXLP("LOJ_DINHEIRO", nVal, cCupom, cData, GEBCTXFIN(aCx[2]), "", aCx[4])
            EndIf
        ElseIf cForma == "PIX"
            GEBFXMOVCONTA(cPix, "C", nVal, "PIX " + cCupom, cCupom, cData)
            GEBCTXLP("LOJ_PIX", nVal, cCupom, cData, GEBCTXFIN(cPix), "", aCx[4])
        ElseIf cForma == "VALE"
            cDoc := LOJDocPg(aPagtos[nI])
            TCSqlExec("UPDATE GLJF SET GLJF_SALDO = GLJF_SALDO - " + BONUM(nVal, 2) + ", GLJF_STATUS = CASE WHEN GLJF_SALDO - " + BONUM(nVal, 2) + ;
                " <= 0 THEN 'USADO' ELSE 'ABERTO' END WHERE GLJF_FILIAL = " + GEBDBQuote(FWxFilial("GLJF")) + " AND GLJF_VALE = " + GEBDBQuote(cDoc) + ;
                " AND D_E_L_E_T_ = ' '")
            GEBCTXLP("LOJ_VALE", nVal, cCupom, cData, "", "", aCx[4])
        ElseIf cForma == "CRYPTO"
            // Blockchain: valor em BRL cai na conta CRY_CONTA; a quantidade
            // crypto e a cotacao do momento ficam em GCK2 (auditoria).
            cDoc := LOJDocPg(aPagtos[nI])
            aCry := StrTokArr(cDoc, "|")
            cMoeda := Upper(BOCOL(aCry[1]))
            aR := aCryQ[nI]
            If Len(aR) == 0 .Or. !aR[1]
                Return {.F., "crypto: cotacao_nao_revalidada", {}}
            EndIf
            GEBFXMOVCONTA(cCryConta, "C", nVal, "Crypto " + cMoeda + " " + cCupom, cCupom, cData)
            GEBCTXLP("LOJ_CRYPTO", nVal, cCupom, cData, GEBCTXFIN(cCryConta), "", aCx[4])
            GEBCRYPAGA(cCupom, cMoeda, BOCOL(aCry[2]), nVal, aR[3][3], aR[3][4])
        ElseIf cForma == "DEBITO" .Or. cForma == "CREDITO"
            If cForma == "DEBITO"
                nTaxa := Round(nVal * BOVAL(BOPARM("LOJ_TAXA_DEB", "1.5")) / 100, 2)
                cDoc := "CRT-" + cCupom + "-" + StrZero(nI, 2)
                GEBFXTIT("R", cDoc, "ADM_CARTAO", nVal - nTaxa, "1", cData, "PDV " + cCupom, "1.01.005")
            Else
                nTaxa := Round(nVal * BOVAL(BOPARM("LOJ_TAXA_CRED", "3")) / 100, 2)
                cDoc := "CRT-" + cCupom + "-" + StrZero(nI, 2)
                GEBFXTIT("R", cDoc, "ADM_CARTAO", nVal - nTaxa, LOJDias(LOJParc(aPagtos[nI])), cData, "PDV " + cCupom, "1.01.005")
            EndIf
            GEBCTXLP("LOJ_CARTAO", nVal, cCupom, cData, "", "", aCx[4])
            GEBCTXLP("LOJ_TAXA", nTaxa, cCupom, cData, "", "", aCx[4])
        Else
            cDoc := "FIA-" + cCupom
            GEBFXTIT("R", cDoc, cCli, nVal, BOPARM("LOJ_FIADO_DIAS", "30"), cData, "PDV " + cCupom, "1.01.003")
            GEBCTXLP("LOJ_FIADO", nVal, cCupom, cData, "", "", aCx[4])
        EndIf
        TCSqlExec("INSERT INTO GLJ5 (D_E_L_E_T_, GLJ5_FILIAL, GLJ5_CUPOM, GLJ5_FORMA, GLJ5_VALOR, GLJ5_TROCO, GLJ5_TAXA, GLJ5_DOC, GLJ5_PARC, GLJ5_TEF) VALUES (' ', " + ;
            GEBDBQuote(FWxFilial("GLJ5")) + ", " + GEBDBQuote(cCupom) + ", " + GEBDBQuote(cForma) + ", " + BONUM(nVal, 2) + ", " + ;
            BONUM(LOJTroco(cForma, nTroco), 2) + ", " + BONUM(nTaxa, 2) + ", " + GEBDBQuote(cDoc) + ", " + BONUM(LOJParc(aPagtos[nI]), 0) + ", " + GEBDBQuote(aTef[nI]) + ")")
        If cForma == "DINHEIRO"
            nTroco := 0
        EndIf
    Next nI
    GEBCTXLP("VENDA_CMV", nCusto, cCupom, cData, "", "", aCx[4])
    For nI := 1 To Len(aPro)
        If !(aPro[nI][1] == "")
            TCSqlExec("INSERT INTO GLJA (D_E_L_E_T_, GLJA_FILIAL, GLJA_CUPOM, GLJA_PROD, GLJA_PROMO, GLJA_DESC) VALUES (' ', " + ;
                GEBDBQuote(FWxFilial("GLJA")) + ", " + GEBDBQuote(cCupom) + ", " + GEBDBQuote(aIt[nI][1]) + ", " + GEBDBQuote(aPro[nI][1]) + ", " + ;
                BONUM(aPro[nI][2], 2) + ")")
        EndIf
    Next nI
    TCSqlExec("INSERT INTO GLJB (D_E_L_E_T_, GLJB_FILIAL, GLJB_CUPOM, GLJB_VEND, GLJB_CPF, GLJB_ORC, GLJB_AUTOR, GLJB_HORA) VALUES (' ', " + ;
        GEBDBQuote(FWxFilial("GLJB")) + ", " + GEBDBQuote(cCupom) + ", " + GEBDBQuote(cVend) + ", " + GEBDBQuote(cCPF) + ", " + GEBDBQuote(cOrc) + ", " + ;
        GEBDBQuote(cAutor) + ", " + GEBDBQuote(Time()) + ")")
    TCSqlExec("INSERT INTO GLJ3 (D_E_L_E_T_, GLJ3_FILIAL, GLJ3_CUPOM, GLJ3_SESSAO, GLJ3_CLI, GLJ3_DATA, GLJ3_BRUTO, GLJ3_DESC, GLJ3_TOTAL, GLJ3_CUSTO, GLJ3_STATUS, GLJ3_NOTA, GLJ3_REGIME) VALUES (' ', " + ;
        GEBDBQuote(FWxFilial("GLJ3")) + ", " + GEBDBQuote(cCupom) + ", " + GEBDBQuote(cSessao) + ", " + GEBDBQuote(cCli) + ", " + GEBDBQuote(cData) + ", " + ;
        BONUM(nBruto, 2) + ", " + BONUM(nDesc, 2) + ", " + BONUM(nTot, 2) + ", " + BONUM(nCusto, 2) + ", 'VENDIDO', " + GEBDBQuote(cNota) + ", " + GEBDBQuote(cRegime) + ")")
    // TEF: venda gravada, confirma as transacoes.
    For nI := 1 To Len(aTef)
        If !(aTef[nI] == "")
            GEBTEFCONF(aTef[nI])
        EndIf
    Next nI
Return {.T., "cupom " + cCupom + " (" + aNF[1] + ")", {cCupom, nTot, Round(nPago - nTot, 2), cNota, cStDfe}}

// Itens da NFC-e: {cProd, nQtd, nPrecoUnit, nDesconto}; o desconto do item e' bruto - liquido
// (o centavo negativo de arredondamento, se houver, passa para o item de maior desconto).
Static Function LOJItensDfe(aIt, aBrutoIt)
    Local aR := {}
    Local nI := 0
    Local nMaior := 1
    For nI := 1 To Len(aIt)
        aAdd(aR, {aIt[nI][1], aIt[nI][2], aIt[nI][3], Round(aBrutoIt[nI] - aIt[nI][4], 2)})
        If aR[nI][4] > aR[nMaior][4]
            nMaior := nI
        EndIf
    Next nI
    For nI := 1 To Len(aR)
        If aR[nI][4] < 0 .And. !(nI == nMaior)
            aR[nMaior][4] := Round(aR[nMaior][4] + aR[nI][4], 2)
            aR[nI][4] := 0
        EndIf
    Next nI
Return aR

// Pagamentos da NFC-e: {cTPag, nValor, cTpIntegra, cCNPJCredenciadora, cBandeira, cAutorizacao, cXPag}.
Static Function LOJPagDfe(aPagtos, aTefAut)
    Local aR := {}
    Local aAux := {}
    Local aForma := {{"DINHEIRO", "01"}, {"CREDITO", "03"}, {"DEBITO", "04"}, {"FIADO", "05"}, {"VALE", "05"}, {"PIX", "17"}}
    Local cForma := ""
    Local cTp := ""
    Local nP := 0
    Local nI := 0
    For nI := 1 To Len(aPagtos)
        cForma := Upper(BOCOL(aPagtos[nI][1]))
        nP := AScan(aForma, {|x| x[1] == cForma})
        cTp := "99"
        If nP > 0
            cTp := aForma[nP][2]
        EndIf
        If Len(aTefAut[nI]) >= 4 .And. Upper(BOPARM("LOJ_TEF_PROVEDOR", "SIMULADOR")) == "CIELO"
            // Cartao integrado (TEF): credenciadora, bandeira e autorizacao vao para a nota.
            aAdd(aR, {cTp, Round(BOVAL(aPagtos[nI][2]), 2), "1", "01027058000191", LOJBandeira(aTefAut[nI][4]), aTefAut[nI][3], ""})
        Else
            // 7a posicao = xPag (obrigatorio quando tPag = 99). Crypto leva a moeda.
            cDoc := ""
            If cTp == "99"
                cDoc := cForma
                If cForma == "CRYPTO"
                    aAux := StrTokArr(LOJDocPg(aPagtos[nI]), "|")
                    If Len(aAux) >= 1 .And. !(BOCOL(aAux[1]) == "")
                        cDoc := "Crypto " + Upper(BOCOL(aAux[1]))
                    EndIf
                EndIf
            EndIf
            aAdd(aR, {cTp, Round(BOVAL(aPagtos[nI][2]), 2), "2", "", "", "", cDoc})
        EndIf
    Next nI
Return aR

// Codigo da bandeira (tabela tBand da NF-e).
Static Function LOJBandeira(cBand)
    Local aB := {{"VISA", "01"}, {"MASTER", "02"}, {"AMEX", "03"}, {"SOROCRED", "04"}, {"DINERS", "05"}, {"ELO", "06"}, {"HIPER", "07"}, ;
        {"AURA", "08"}, {"CABAL", "09"}}
    Local nI := 0
    cBand := Upper(BOCOL(cBand))
    If cBand == ""
        Return ""
    EndIf
    For nI := 1 To Len(aB)
        If aB[nI][1] $ cBand
            Return aB[nI][2]
        EndIf
    Next nI
Return "99"

/*/{Protheus.doc} GEBLOJCAN
    Cancela um cupom da sessao aberta.
    @type Operacao frente de loja
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBLOJCAN(cCupom, cMotivo)
    Local aC := {}
    Local aSes := {}
    Local aCx := {}
    Local aIt := {}
    Local aPg := {}
    Local aT := {}
    Local aDfe := {}
    Local cData := ""
    Local cForma := ""
    Local cCryConta := ""
    Local cJust := ""
    Local cAviso := ""
    Local lDfeCanc := .F.
    Local nI := 0

    cCupom := Upper(BOCOL(cCupom))
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    aC := TCSqlQuery("SELECT GLJ3_SESSAO AS S, GLJ3_STATUS AS ST, GLJ3_NOTA AS N, GLJ3_CUSTO AS CU FROM GLJ3 WHERE GLJ3_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GLJ3")) + " AND GLJ3_CUPOM = " + GEBDBQuote(cCupom) + " AND D_E_L_E_T_ = ' '")
    If Len(aC) == 0
        Return {.F., "cupom_inexistente: " + cCupom}
    EndIf
    If !(BOCOL(aC[1]:ST) == "VENDIDO")
        Return {.F., "cupom_ja_cancelado"}
    EndIf
    aSes := LOJSessao(BOCOL(aC[1]:S))
    If !(aSes[3] == "ABERTA")
        Return {.F., "sessao_fechada: cancele por devolucao"}
    EndIf
    If Len(TCSqlQuery("SELECT GLJH_DEV FROM GLJH WHERE GLJH_FILIAL = " + GEBDBQuote(FWxFilial("GLJH")) + " AND GLJH_CUPOM = " + GEBDBQuote(cCupom) + ;
            " AND D_E_L_E_T_ = ' '")) > 0
        Return {.F., "cupom_com_devolucao: use devolucao"}
    EndIf
    aCx := LOJCaixa(aSes[2])
    cData := aSes[4]
    // NFC-e real: o cancelamento na SEFAZ vem antes de desfazer a venda.
    aDfe := GEBDFEDOC(BOCOL(aC[1]:N))
    If Len(aDfe) > 0
        If aDfe[1] == "CONTINGENCIA"
            Return {.F., "nfce_em_contingencia: transmita as contingencias e depois cancele"}
        EndIf
        If aDfe[1] == "AUTORIZADA"
            cJust := BOCOL(cMotivo)
            If Len(cJust) < 15
                cJust := "Cancelamento da venda no caixa: " + cJust
            EndIf
            aT := GEBDFECANCELA(BOCOL(aC[1]:N), cJust)
            If !aT[1]
                Return {.F., aT[2]}
            EndIf
            lDfeCanc := .T.
            cAviso := " NFC-e cancelada (protocolo " + aT[3] + ")."
        EndIf
    EndIf
    aPg := TCSqlQuery("SELECT GLJ5_FORMA AS F, GLJ5_VALOR AS V, GLJ5_TAXA AS TX, GLJ5_DOC AS D, GLJ5_TEF AS T FROM GLJ5 WHERE GLJ5_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GLJ5")) + " AND GLJ5_CUPOM = " + GEBDBQuote(cCupom) + " AND D_E_L_E_T_ = ' '")
    // Titulos de cartao/fiado ja baixados impedem o cancelamento.
    For nI := 1 To Len(aPg)
        If !(BOCOL(aPg[nI]:D) == "")
            aT := TCSqlQuery("SELECT GFN2_DOC FROM GFN2 WHERE GFN2_FILIAL = " + GEBDBQuote(FWxFilial("GFN2")) + " AND (GFN2_DOC = " + ;
                GEBDBQuote(BOCOL(aPg[nI]:D)) + " OR GFN2_DOC LIKE " + GEBDBQuote(BOCOL(aPg[nI]:D) + "/%") + ") AND GFN2_SALDO < GFN2_VALOR AND D_E_L_E_T_ = ' '")
            If Len(aT) > 0
                Return {.F., "titulo_ja_baixado: " + BOCOL(aPg[nI]:D)}
            EndIf
        EndIf
    Next nI
    // TEF: estorna os cartoes na adquirente antes de desfazer o resto. Com a NFC-e ja
    // cancelada na SEFAZ nao ha volta: o cupom e' cancelado e o estorno fica pendente.
    For nI := 1 To Len(aPg)
        If !(BOCOL(aPg[nI]:T) == "")
            aT := GEBTEFCANC(BOCOL(aPg[nI]:T))
            If !aT[1]
                If lDfeCanc
                    cAviso += " ATENCAO: estorno do cartao pendente (" + aT[2] + "), faca na adquirente."
                Else
                    Return {.F., "estorno_do_cartao_recusado: " + aT[2]}
                EndIf
            EndIf
        EndIf
    Next nI
    aIt := TCSqlQuery("SELECT GLJ4_PROD AS P, GLJ4_QTD AS Q, GLJ4_CUSTO AS CU FROM GLJ4 WHERE GLJ4_FILIAL = " + GEBDBQuote(FWxFilial("GLJ4")) + ;
        " AND GLJ4_CUPOM = " + GEBDBQuote(cCupom) + " AND D_E_L_E_T_ = ' '")
    For nI := 1 To Len(aIt)
        GEBESTMOV(BOCOL(aIt[nI]:P), aCx[3], "E", BOVAL(aIt[nI]:Q), Round(BOVAL(aIt[nI]:CU) / BOVAL(aIt[nI]:Q), 6), "PDV_CANCEL", cCupom, cData, {}, cCupom)
    Next nI
    For nI := 1 To Len(aPg)
        cForma := BOCOL(aPg[nI]:F)
        If cForma == "DINHEIRO"
            GEBFXMOVCONTA(aCx[2], "D", BOVAL(aPg[nI]:V), "Cancelamento " + cCupom, cCupom, cData)
            GEBCTXREV("LOJ_DINHEIRO", BOVAL(aPg[nI]:V), cCupom, cData, GEBCTXFIN(aCx[2]), "", aCx[4])
        ElseIf cForma == "PIX"
            GEBFXMOVCONTA(BOPARM("LOJ_CONTA_PIX", "BANCO"), "D", BOVAL(aPg[nI]:V), "Estorno PIX " + cCupom, cCupom, cData)
            GEBCTXREV("LOJ_PIX", BOVAL(aPg[nI]:V), cCupom, cData, GEBCTXFIN(BOPARM("LOJ_CONTA_PIX", "BANCO")), "", aCx[4])
        ElseIf cForma == "VALE"
            TCSqlExec("UPDATE GLJF SET GLJF_SALDO = GLJF_SALDO + " + BONUM(BOVAL(aPg[nI]:V), 2) + ", GLJF_STATUS = 'ABERTO' WHERE GLJF_FILIAL = " + ;
                GEBDBQuote(FWxFilial("GLJF")) + " AND GLJF_VALE = " + GEBDBQuote(BOCOL(aPg[nI]:D)) + " AND D_E_L_E_T_ = ' '")
            GEBCTXREV("LOJ_VALE", BOVAL(aPg[nI]:V), cCupom, cData, "", "", aCx[4])
        ElseIf cForma == "CRYPTO"
            // Estorno: o valor em BRL sai da conta crypto (a transacao on-chain
            // e' responsabilidade do operador, como no PIX estornado).
            cCryConta := BOPARM("CRY_CONTA", "")
            If !(cCryConta == "")
                GEBFXMOVCONTA(cCryConta, "D", BOVAL(aPg[nI]:V), "Estorno crypto " + cCupom, cCupom, cData)
            EndIf
            GEBCTXREV("LOJ_CRYPTO", BOVAL(aPg[nI]:V), cCupom, cData, GEBCTXFIN(cCryConta), "", aCx[4])
        Else
            TCSqlExec("UPDATE GFN2 SET GFN2_SALDO = 0, GFN2_STATUS = 'CANCELADO' WHERE GFN2_FILIAL = " + GEBDBQuote(FWxFilial("GFN2")) + ;
                " AND (GFN2_DOC = " + GEBDBQuote(BOCOL(aPg[nI]:D)) + " OR GFN2_DOC LIKE " + GEBDBQuote(BOCOL(aPg[nI]:D) + "/%") + ") AND D_E_L_E_T_ = ' '")
            If cForma == "FIADO"
                GEBCTXREV("LOJ_FIADO", BOVAL(aPg[nI]:V), cCupom, cData, "", "", aCx[4])
            Else
                GEBCTXREV("LOJ_CARTAO", BOVAL(aPg[nI]:V), cCupom, cData, "", "", aCx[4])
                GEBCTXREV("LOJ_TAXA", BOVAL(aPg[nI]:TX), cCupom, cData, "", "", aCx[4])
            EndIf
        EndIf
    Next nI
    GEBCTXREV("VENDA_CMV", BOVAL(aC[1]:CU), cCupom, cData, "", "", aCx[4])
    TCSqlExec("UPDATE GF3 SET GF3_STATUS = 'CANCELADA' WHERE GF3_FILIAL = " + GEBDBQuote(FWxFilial("GF3")) + " AND GF3_CHAVE = " + ;
        GEBDBQuote(BOCOL(aC[1]:N)) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("UPDATE GLJ3 SET GLJ3_STATUS = 'CANCELADO' WHERE GLJ3_FILIAL = " + GEBDBQuote(FWxFilial("GLJ3")) + " AND GLJ3_CUPOM = " + ;
        GEBDBQuote(cCupom) + " AND D_E_L_E_T_ = ' '")
    // Orcamento de origem volta a ficar aberto.
    TCSqlExec("UPDATE GLJD SET GLJD_STATUS = 'ABERTO', GLJD_CUPOM = '' WHERE GLJD_FILIAL = " + GEBDBQuote(FWxFilial("GLJD")) + " AND GLJD_CUPOM = " + ;
        GEBDBQuote(cCupom) + " AND D_E_L_E_T_ = ' '")
Return {.T., "cupom " + cCupom + " cancelado " + BOCOL(cMotivo) + cAviso}

/*/{Protheus.doc} GEBLOJSAN
    Sangria (SANGRIA: caixa -> cofre) ou suprimento (SUPRIMENTO: cofre ->
    caixa). Cofre = cConta ou GE4 LOJ_CONTA_COFRE (padrao BANCO).
    @type Operacao frente de loja
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBLOJSAN(cSessao, cTipo, nValor, cMotivo, cConta)
    Local aSes := {}
    Local aCx := {}
    Local aR := {}
    cSessao := Upper(BOCOL(cSessao))
    cTipo := Upper(BOCOL(cTipo))
    nValor := Round(BOVAL(nValor), 2)
    cConta := BOCOL(cConta)
    If !(cTipo == "SANGRIA" .Or. cTipo == "SUPRIMENTO") .Or. nValor <= 0
        Return {.F., "parametros_invalidos: SANGRIA/SUPRIMENTO e valor > 0"}
    EndIf
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    aSes := LOJSessao(cSessao)
    If Len(aSes) == 0 .Or. !(aSes[3] == "ABERTA")
        Return {.F., "sessao_nao_aberta: " + cSessao}
    EndIf
    aCx := LOJCaixa(aSes[2])
    If cConta == ""
        cConta := BOPARM("LOJ_CONTA_COFRE", "BANCO")
    EndIf
    If cTipo == "SANGRIA"
        If nValor > LOJEsperado(cSessao)
            Return {.F., "sangria_maior_que_o_dinheiro_do_caixa"}
        EndIf
        aR := GEBFXTRF(aCx[2], cConta, nValor, aSes[4], "Sangria " + cSessao + " " + BOCOL(cMotivo))
    Else
        aR := GEBFXTRF(cConta, aCx[2], nValor, aSes[4], "Suprimento " + cSessao + " " + BOCOL(cMotivo))
    EndIf
    If !aR[1]
        Return aR
    EndIf
    TCSqlExec("INSERT INTO GLJ6 (D_E_L_E_T_, GLJ6_FILIAL, GLJ6_SESSAO, GLJ6_TIPO, GLJ6_VALOR, GLJ6_MOTIVO, GLJ6_DATA) VALUES (' ', " + ;
        GEBDBQuote(FWxFilial("GLJ6")) + ", " + GEBDBQuote(cSessao) + ", " + GEBDBQuote(cTipo) + ", " + BONUM(nValor, 2) + ", " + ;
        GEBDBQuote(BOCOL(cMotivo)) + ", " + GEBDBQuote(aSes[4]) + ")")
Return {.T., Lower(cTipo) + " registrada"}

/*/{Protheus.doc} GEBLOJFECHA
    Fecha a sessao com o dinheiro contado.
    @type Operacao frente de loja
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {nEsperado, nContado, nDiferenca}}
/*/
User Function GEBLOJFECHA(cSessao, nContado)
    Local aSes := {}
    Local aCx := {}
    Local nEsp := 0
    Local nDif := 0
    cSessao := Upper(BOCOL(cSessao))
    nContado := Round(BOVAL(nContado), 2)
    If nContado < 0
        Return {.F., "contado_negativo", {}}
    EndIf
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aSes := LOJSessao(cSessao)
    If Len(aSes) == 0 .Or. !(aSes[3] == "ABERTA")
        Return {.F., "sessao_nao_aberta: " + cSessao, {}}
    EndIf
    aCx := LOJCaixa(aSes[2])
    nEsp := LOJEsperado(cSessao)
    nDif := Round(nContado - nEsp, 2)
    If nDif > 0
        GEBFXMOV(aCx[2], "C", nDif, "Sobra de caixa " + cSessao, aSes[4], "")
    ElseIf nDif < 0
        GEBFXMOV(aCx[2], "D", -nDif, "Falta de caixa " + cSessao, aSes[4], "")
    EndIf
    TCSqlExec("UPDATE GLJ2 SET GLJ2_STATUS = 'FECHADA', GLJ2_FECH = " + GEBDBQuote(BOHOJE()) + ", GLJ2_CONTADO = " + BONUM(nContado, 2) + ;
        ", GLJ2_ESPERADO = " + BONUM(nEsp, 2) + ", GLJ2_DIFER = " + BONUM(nDif, 2) + " WHERE GLJ2_FILIAL = " + GEBDBQuote(FWxFilial("GLJ2")) + ;
        " AND GLJ2_SESSAO = " + GEBDBQuote(cSessao) + " AND D_E_L_E_T_ = ' '")
Return {.T., "sessao " + cSessao + " fechada", {nEsp, nContado, nDif}}

/*/{Protheus.doc} GEBLOJRESUMO
    Relatorio: resumo da sessao (cupons, cancelados, total por forma de
    pagamento, sangrias, suprimentos, fundo, dinheiro esperado, contado e
    diferenca).
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, aLinhas {item, valor}}
/*/
User Function GEBLOJRESUMO(cSessao)
    Local aSes := {}
    Local aHit := {}
    Local aLin := {}
    Local aRel := {{"item", "valor"}}
    Local aFormas := {"DINHEIRO", "PIX", "DEBITO", "CREDITO", "FIADO", "VALE", "CRYPTO"}
    Local nI := 0
    cSessao := Upper(BOCOL(cSessao))
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aSes := LOJSessao(cSessao)
    If Len(aSes) == 0
        Return {.F., "sessao_inexistente: " + cSessao, {}}
    EndIf
    aHit := TCSqlQuery("SELECT COUNT(*) AS N, COALESCE(SUM(CASE WHEN GLJ3_STATUS = 'VENDIDO' THEN GLJ3_TOTAL ELSE 0 END), 0) AS T, " + ;
        "COALESCE(SUM(CASE WHEN GLJ3_STATUS = 'CANCELADO' THEN 1 ELSE 0 END), 0) AS C, COALESCE(SUM(CASE WHEN GLJ3_STATUS = 'VENDIDO' THEN GLJ3_DESC ELSE 0 END), 0) AS D " + ;
        "FROM GLJ3 WHERE GLJ3_FILIAL = " + GEBDBQuote(FWxFilial("GLJ3")) + " AND GLJ3_SESSAO = " + GEBDBQuote(cSessao) + " AND D_E_L_E_T_ = ' '")
    aAdd(aLin, {"caixa", aSes[2]})
    aAdd(aLin, {"operador", aSes[6]})
    aAdd(aLin, {"status", aSes[3]})
    aAdd(aLin, {"cupons", BOVAL(aHit[1]:N)})
    aAdd(aLin, {"cancelados", BOVAL(aHit[1]:C)})
    aAdd(aLin, {"descontos", BOVAL(aHit[1]:D)})
    aAdd(aLin, {"vendas", BOVAL(aHit[1]:T)})
    For nI := 1 To Len(aFormas)
        aAdd(aLin, {"forma " + aFormas[nI], LOJForma(cSessao, aFormas[nI])})
    Next nI
    aAdd(aLin, {"fundo", aSes[5]})
    aAdd(aLin, {"suprimentos", LOJMov(cSessao, "SUPRIMENTO")})
    aAdd(aLin, {"sangrias", LOJMov(cSessao, "SANGRIA")})
    aAdd(aLin, {"devolucoes em dinheiro", LOJDev(cSessao, "DINHEIRO")})
    aAdd(aLin, {"devolucoes em vale", LOJDev(cSessao, "VALE")})
    aAdd(aLin, {"dinheiro_esperado", LOJEsperado(cSessao)})
    If aSes[3] == "FECHADA"
        aAdd(aLin, {"contado", aSes[7]})
        aAdd(aLin, {"diferenca", aSes[8]})
    EndIf
    For nI := 1 To Len(aLin)
        aAdd(aRel, aLin[nI])
    Next nI
    BOREL(aRel)
Return {.T., "resumo_caixa", aLin}

/*/{Protheus.doc} GEBLOJVENDAS
    Relatorio: vendas do dia por produto (cupons nao cancelados; cCaixa
    vazio = todos).
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {aLinhas (1a = cabecalho), aTotais}}
/*/
User Function GEBLOJVENDAS(cData, cCaixa)
    Local aHit := {}
    Local aLin := {{"produto", "quantidade", "valor", "custo", "margem"}}
    Local aRel := {}
    Local cW := ""
    Local nTV := 0
    Local nTC := 0
    Local nI := 0
    cData := BODATA(cData)
    cCaixa := Upper(BOCOL(cCaixa))
    If cData == ""
        Return {.F., "data_invalida", {}}
    EndIf
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    If !(cCaixa == "")
        cW := " AND GLJ3_SESSAO IN (SELECT GLJ2_SESSAO FROM GLJ2 WHERE GLJ2_CAIXA = " + GEBDBQuote(cCaixa) + " AND GLJ2.D_E_L_E_T_ = ' ')"
    EndIf
    aHit := TCSqlQuery("SELECT GLJ4_PROD AS P, SUM(GLJ4_QTD) AS Q, SUM(GLJ4_VALOR) AS V, SUM(GLJ4_CUSTO) AS C FROM GLJ4 " + ;
        "JOIN GLJ3 ON GLJ3_FILIAL = GLJ4_FILIAL AND GLJ3_CUPOM = GLJ4_CUPOM AND GLJ3.D_E_L_E_T_ = ' ' WHERE GLJ4_FILIAL = " + GEBDBQuote(FWxFilial("GLJ4")) + ;
        " AND GLJ4.D_E_L_E_T_ = ' ' AND GLJ3_STATUS = 'VENDIDO' AND GLJ3_DATA = " + GEBDBQuote(cData) + cW + " GROUP BY GLJ4_PROD ORDER BY 3 DESC")
    For nI := 1 To Len(aHit)
        nTV := nTV + BOVAL(aHit[nI]:V)
        nTC := nTC + BOVAL(aHit[nI]:C)
        aAdd(aLin, {BOCOL(aHit[nI]:P), BOVAL(aHit[nI]:Q), BOVAL(aHit[nI]:V), BOVAL(aHit[nI]:C), Round(BOVAL(aHit[nI]:V) - BOVAL(aHit[nI]:C), 2)})
    Next nI
    For nI := 1 To Len(aLin)
        aAdd(aRel, aLin[nI])
    Next nI
    aAdd(aRel, {"total", "", Round(nTV, 2), Round(nTC, 2), Round(nTV - nTC, 2)})
    BOREL(aRel)
Return {.T., "vendas_do_dia", {aLin, {{"valor", Round(nTV, 2)}, {"custo", Round(nTC, 2)}, {"margem", Round(nTV - nTC, 2)}}}}

// Caixa: {cCod, cConta, cLocal, cCentroCusto}; {} se nao existe.
Static Function LOJCaixa(cCaixa)
    Local aHit := TCSqlQuery("SELECT GLJ1_CONTA AS C, GLJ1_LOCAL AS L, GLJ1_CC AS CC FROM GLJ1 WHERE GLJ1_FILIAL = " + GEBDBQuote(FWxFilial("GLJ1")) + ;
        " AND GLJ1_COD = " + GEBDBQuote(cCaixa) + " AND D_E_L_E_T_ = ' '")
    Local cLocal := "01"
    If Len(aHit) == 0
        Return {}
    EndIf
    If !(BOCOL(aHit[1]:L) == "")
        cLocal := BOCOL(aHit[1]:L)
    EndIf
Return {cCaixa, BOCOL(aHit[1]:C), cLocal, BOCOL(aHit[1]:CC)}

// Sessao: {cSessao, cCaixa, cStatus, cDataAbertura, nFundo, cOperador, nContado, nDiferenca}; {} se nao existe.
Static Function LOJSessao(cSessao)
    Local aHit := TCSqlQuery("SELECT GLJ2_CAIXA AS C, GLJ2_STATUS AS S, GLJ2_ABERT AS A, GLJ2_FUNDO AS F, GLJ2_OPER AS O, GLJ2_CONTADO AS CT, " + ;
        "GLJ2_DIFER AS D FROM GLJ2 WHERE GLJ2_FILIAL = " + GEBDBQuote(FWxFilial("GLJ2")) + " AND GLJ2_SESSAO = " + GEBDBQuote(cSessao) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {}
    EndIf
Return {cSessao, BOCOL(aHit[1]:C), BOCOL(aHit[1]:S), BOCOL(aHit[1]:A), BOVAL(aHit[1]:F), BOCOL(aHit[1]:O), BOVAL(aHit[1]:CT), BOVAL(aHit[1]:D)}

// Total de uma forma de pagamento nos cupons vendidos da sessao (dinheiro ja liquido do troco).
Static Function LOJForma(cSessao, cForma)
    Local aHit := TCSqlQuery("SELECT COALESCE(SUM(GLJ5_VALOR), 0) AS V FROM GLJ5 JOIN GLJ3 ON GLJ3_FILIAL = GLJ5_FILIAL AND GLJ3_CUPOM = GLJ5_CUPOM " + ;
        "AND GLJ3.D_E_L_E_T_ = ' ' WHERE GLJ5_FILIAL = " + GEBDBQuote(FWxFilial("GLJ5")) + " AND GLJ5.D_E_L_E_T_ = ' ' AND GLJ3_SESSAO = " + ;
        GEBDBQuote(cSessao) + " AND GLJ3_STATUS = 'VENDIDO' AND GLJ5_FORMA = " + GEBDBQuote(cForma))
Return Round(BOVAL(aHit[1]:V), 2)

Static Function LOJMov(cSessao, cTipo)
    Local aHit := TCSqlQuery("SELECT COALESCE(SUM(GLJ6_VALOR), 0) AS V FROM GLJ6 WHERE GLJ6_FILIAL = " + GEBDBQuote(FWxFilial("GLJ6")) + ;
        " AND GLJ6_SESSAO = " + GEBDBQuote(cSessao) + " AND GLJ6_TIPO = " + GEBDBQuote(cTipo) + " AND D_E_L_E_T_ = ' '")
Return Round(BOVAL(aHit[1]:V), 2)

// Dinheiro esperado na gaveta: fundo + dinheiro liquido + suprimentos - sangrias - devolucoes em dinheiro.
Static Function LOJEsperado(cSessao)
    Local aSes := LOJSessao(cSessao)
Return Round(aSes[5] + LOJForma(cSessao, "DINHEIRO") + LOJMov(cSessao, "SUPRIMENTO") - LOJMov(cSessao, "SANGRIA") - LOJDev(cSessao, "DINHEIRO"), 2)

// Devolucoes feitas na sessao pelo modo (DINHEIRO ou VALE).
Static Function LOJDev(cSessao, cModo)
    Local aHit := TCSqlQuery("SELECT COALESCE(SUM(GLJH_VALOR), 0) AS V FROM GLJH WHERE GLJH_FILIAL = " + GEBDBQuote(FWxFilial("GLJH")) + ;
        " AND GLJH_SESSAO = " + GEBDBQuote(cSessao) + " AND GLJH_MODO = " + GEBDBQuote(cModo) + " AND D_E_L_E_T_ = ' '")
Return Round(BOVAL(aHit[1]:V), 2)

// Documento do pagamento (4a posicao: numero do vale).
Static Function LOJDocPg(aPg)
    If Len(aPg) >= 4
        Return Upper(BOCOL(aPg[4]))
    EndIf
Return ""

/*/{Protheus.doc} GEBLOJSES
    Sessao do caixa: {cSessao, cCaixa, cStatus, cDataAbertura, nFundo,
    cOperador, nContado, nDiferenca}; {} se nao existe.
    @type Funcao frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBLOJSES(cSessao)
Return LOJSessao(Upper(BOCOL(cSessao)))

/*/{Protheus.doc} GEBLOJCXA
    Caixa: {cCod, cConta, cLocal, cCentroCusto}; {} se nao existe.
    @type Funcao frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBLOJCXA(cCaixa)
Return LOJCaixa(Upper(BOCOL(cCaixa)))

/*/{Protheus.doc} GEBLOJESP
    Dinheiro esperado na gaveta da sessao.
    @type Funcao frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBLOJESP(cSessao)
Return LOJEsperado(Upper(BOCOL(cSessao)))

// Teto de desconto (%) conforme o regime da venda. Com LOJ_REG_ATIVO=S:
// COMPROVANTE + dinheiro usa LOJ_REG_DESCC; demais casos LOJ_REG_DESCF.
// Sem o recurso ligado, vale LOJ_DESC_MAX (padrao 100 = sem teto).
Static Function LOJDescMax(cRegime, lDin)
    If !(BOPARM("LOJ_REG_ATIVO", "N") == "S")
        Return BOVAL(BOPARM("LOJ_DESC_MAX", "100"))
    EndIf
    If cRegime == "COMPROVANTE" .And. lDin
        Return BOVAL(BOPARM("LOJ_REG_DESCC", "10"))
    EndIf
Return BOVAL(BOPARM("LOJ_REG_DESCF", "3"))

// Parcelas de um pagamento (3a posicao; padrao 1).
Static Function LOJParc(aPg)
    If Len(aPg) >= 3 .And. BOVAL(aPg[3]) > 1
        Return Int(BOVAL(aPg[3]))
    EndIf
Return 1

// Dias das parcelas do cartao de credito: 30, 60, ... (n x 30).
Static Function LOJDias(nParc)
    Local cD := ""
    Local nI := 0
    For nI := 1 To nParc
        If nI > 1
            cD := cD + ","
        EndIf
        cD := cD + BONUM(nI * 30, 0)
    Next nI
Return cD

Static Function LOJTroco(cForma, nTroco)
    If cForma == "DINHEIRO"
        Return nTroco
    EndIf
Return 0
