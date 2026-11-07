#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBCTX.prw"
#include "GEBEST.prw"
#include "GEBFNX.prw"
#include "GEBFIS_MIG.prw"
#include "GEBDFE_NFE.prw"

/*/{Protheus.doc} GEBFAT
    Faturamento do backoffice (inspirado em SA1/DA1/MATA410/MATA440/MATA460
    e devolucao de venda do Protheus).
    - GFT1 clientes (limite de credito, condicao e tabela de preco
      padrao); GFT2 tabela de preco (tabela + produto).
    - GFT3/GFT4 pedido de venda (varios itens, desconto % no pedido).
      GEBFATLIB libera checando credito (GFT1_LIMITE contra titulos abertos
      do cliente + saldo do pedido; 0 = sem limite) e estoque; falha =
      BLOQUEADO com motivo (lForca libera mesmo assim).
    - GEBFATFAT: documento de saida (todo o saldo ou itens informados).
      Nota fiscal com varios itens (GEBFATNOTA: GF3 + uma GF4 por item,
      IBS/CBS pela aliquota vigente da NCM do produto), saida do estoque ao
      custo medio, titulos a receber pela condicao, VENDA_RECEITA e
      VENDA_CMV. GFT5/GFT6 guardam o documento e o custo por item.
    - GEBFATDEV: devolucao (volta ao estoque pelo custo unitario da saida;
      abate o titulo aberto da nota, da ultima parcela para a primeira; o
      que ja foi recebido vira credito do cliente em GFN3 DEVC-...; lanca
      DEVOL_VENDA e DEVOL_CMV).
    - Relatorios: GEBFATREL (por cliente ou produto: quantidade, valor
      liquido de devolucao, custo, margem), GEBFATCARTEIRA (saldo a
      faturar) e GEBFATABC (curva ABC por valor).
    @type Modulo faturamento
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBFATMIG()
    Local lOk := GEBFMIG() .And. GEBESTMIG() .And. GEBFXMIG()
    lOk := lOk .And. BOTAB("GFT1", "GFT1_COD TEXT NOT NULL, GFT1_NOME TEXT NOT NULL, GFT1_DOC TEXT NOT NULL, GFT1_UF TEXT NOT NULL, " + ;
        "GFT1_LIMITE NUMERIC(18,2) NOT NULL, GFT1_COND TEXT NOT NULL, GFT1_TABELA TEXT NOT NULL", "GFT1_COD")
    lOk := lOk .And. BOTAB("GFT2", "GFT2_TAB TEXT NOT NULL, GFT2_PROD TEXT NOT NULL, GFT2_PRECO NUMERIC(18,6) NOT NULL", "GFT2_TAB")
    lOk := lOk .And. BOTAB("GFT3", "GFT3_NUM TEXT NOT NULL, GFT3_CLI TEXT NOT NULL, GFT3_COND TEXT NOT NULL, GFT3_EMISSAO TEXT NOT NULL, " + ;
        "GFT3_LOCAL TEXT NOT NULL, GFT3_DESC NUMERIC(8,4) NOT NULL, GFT3_STATUS TEXT NOT NULL, GFT3_MOTIVO TEXT NOT NULL, GFT3_CC TEXT NOT NULL", "GFT3_NUM")
    lOk := lOk .And. BOTAB("GFT4", "GFT4_NUM TEXT NOT NULL, GFT4_PROD TEXT NOT NULL, GFT4_QTD NUMERIC(18,4) NOT NULL, " + ;
        "GFT4_PRECO NUMERIC(18,6) NOT NULL, GFT4_QTDFAT NUMERIC(18,4) NOT NULL", "GFT4_NUM")
    lOk := lOk .And. BOTAB("GFT5", "GFT5_NOTA TEXT NOT NULL, GFT5_PED TEXT NOT NULL, GFT5_CLI TEXT NOT NULL, GFT5_DATA TEXT NOT NULL, " + ;
        "GFT5_TOTAL NUMERIC(18,2) NOT NULL, GFT5_CUSTO NUMERIC(18,2) NOT NULL, GFT5_IBS NUMERIC(18,2) NOT NULL, GFT5_CBS NUMERIC(18,2) NOT NULL", "GFT5_NOTA")
    lOk := lOk .And. BOTAB("GFT6", "GFT6_NOTA TEXT NOT NULL, GFT6_PROD TEXT NOT NULL, GFT6_QTD NUMERIC(18,4) NOT NULL, " + ;
        "GFT6_PRECO NUMERIC(18,6) NOT NULL, GFT6_VALOR NUMERIC(18,2) NOT NULL, GFT6_CUSTO NUMERIC(18,2) NOT NULL, GFT6_QTDDEV NUMERIC(18,4) NOT NULL", "GFT6_NOTA")
    lOk := lOk .And. BOTAB("GFT7", "GFT7_DEV TEXT NOT NULL, GFT7_NOTA TEXT NOT NULL, GFT7_PROD TEXT NOT NULL, GFT7_QTD NUMERIC(18,4) NOT NULL, " + ;
        "GFT7_VALOR NUMERIC(18,2) NOT NULL, GFT7_CUSTO NUMERIC(18,2) NOT NULL, GFT7_DATA TEXT NOT NULL", "GFT7_NOTA")
Return lOk

/*/{Protheus.doc} GEBFATCLI
    Cadastra/altera cliente.
    @type Cadastro faturamento
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBFATCLI(cCod, cNome, cDoc, cUF, nLimite, cCond, cTab)
    Local cFil := FWxFilial("GFT1")
    cCod := Upper(BOCOL(cCod))
    nLimite := BOVAL(nLimite)
    If cCod == "" .Or. BOCOL(cNome) == ""
        Return {.F., "codigo_e_nome_obrigatorios"}
    EndIf
    If nLimite < 0
        Return {.F., "limite_negativo"}
    EndIf
    If !GEBFATMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    If !(BOCOL(cCond) == "") .And. !GEBFXPARC(cCond, 1, BOHOJE())[1]
        Return {.F., "condicao_inexistente: " + BOCOL(cCond)}
    EndIf
    TCSqlExec("UPDATE GFT1 SET D_E_L_E_T_ = '*' WHERE GFT1_FILIAL = " + GEBDBQuote(cFil) + " AND GFT1_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")
    If !TCSqlExec("INSERT INTO GFT1 (D_E_L_E_T_, GFT1_FILIAL, GFT1_COD, GFT1_NOME, GFT1_DOC, GFT1_UF, GFT1_LIMITE, GFT1_COND, GFT1_TABELA) VALUES (' ', " + ;
            GEBDBQuote(cFil) + ", " + GEBDBQuote(cCod) + ", " + GEBDBQuote(BOCOL(cNome)) + ", " + GEBDBQuote(BOCOL(cDoc)) + ", " + ;
            GEBDBQuote(Upper(BOCOL(cUF))) + ", " + BONUM(nLimite, 2) + ", " + GEBDBQuote(Upper(BOCOL(cCond))) + ", " + GEBDBQuote(Upper(BOCOL(cTab))) + ")")
        Return {.F., "falha_gravacao"}
    EndIf
Return {.T., "cliente " + cCod + " gravado"}

/*/{Protheus.doc} GEBFATPRC
    Preco do produto numa tabela (vazia = PADRAO).
    @type Cadastro faturamento
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBFATPRC(cTab, cProd, nPreco)
    Local cFil := FWxFilial("GFT2")
    cTab := Upper(BOCOL(cTab))
    If cTab == ""
        cTab := "PADRAO"
    EndIf
    If BOCOL(cProd) == "" .Or. BOVAL(nPreco) <= 0
        Return {.F., "produto_e_preco_obrigatorios"}
    EndIf
    If !GEBFATMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    TCSqlExec("UPDATE GFT2 SET D_E_L_E_T_ = '*' WHERE GFT2_FILIAL = " + GEBDBQuote(cFil) + " AND GFT2_TAB = " + GEBDBQuote(cTab) + ;
        " AND GFT2_PROD = " + GEBDBQuote(BOCOL(cProd)) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GFT2 (D_E_L_E_T_, GFT2_FILIAL, GFT2_TAB, GFT2_PROD, GFT2_PRECO) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
        GEBDBQuote(cTab) + ", " + GEBDBQuote(BOCOL(cProd)) + ", " + BONUM(nPreco, 6) + ")")
Return {.T., "preco gravado na tabela " + cTab}

/*/{Protheus.doc} GEBFATPED
    Pedido de venda. cNum vazio = numerado (PV000001...). Preco do item
    vazio/zero = tabela do cliente (ou PADRAO); condicao vazia = do cliente.
    @type Operacao faturamento
    @author Peder Munksgaard
    @since 18/10/2026
    @param aItens {{cProd, nQtd[, nPreco]}...}
    @return {lOk, cMsg, {cNum, nTotal}}
/*/
User Function GEBFATPED(cNum, cCli, aItens, cCond, nDesc, cLocal, cData, cCC)
    Local aCli := {}
    Local aIt := {}
    Local nPreco := 0
    Local nTot := 0
    Local nI := 0
    Local nJ := 0

    cNum := Upper(BOCOL(cNum))
    cCli := Upper(BOCOL(cCli))
    nDesc := BOVAL(nDesc)
    cData := BODATA(cData)
    If cData == "" .Or. nDesc < 0 .Or. nDesc >= 100
        Return {.F., "data_ou_desconto_invalidos", {}}
    EndIf
    If aItens == Nil .Or. Len(aItens) == 0
        Return {.F., "sem_itens", {}}
    EndIf
    If !GEBFATMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aCli := FATCliente(cCli)
    If Len(aCli) == 0
        Return {.F., "cliente_inexistente: " + cCli, {}}
    EndIf
    If BOCOL(cCond) == ""
        cCond := aCli[4]
    EndIf
    If !GEBFXPARC(cCond, 1, cData)[1]
        Return {.F., "condicao_inexistente: " + BOCOL(cCond), {}}
    EndIf
    If !GEBCTXRATEIA(cCC, 1)[1]
        Return {.F., GEBCTXRATEIA(cCC, 1)[2], {}}
    EndIf
    For nI := 1 To Len(aItens)
        If BOCOL(aItens[nI][1]) == "" .Or. BOVAL(aItens[nI][2]) <= 0
            Return {.F., "item_invalido: " + BONUM(nI, 0), {}}
        EndIf
        For nJ := 1 To Len(aIt)
            If aIt[nJ][1] == BOCOL(aItens[nI][1])
                Return {.F., "produto_repetido: " + aIt[nJ][1], {}}
            EndIf
        Next nJ
        nPreco := 0
        If Len(aItens[nI]) >= 3
            nPreco := BOVAL(aItens[nI][3])
        EndIf
        If nPreco <= 0
            nPreco := FATPreco(aCli[5], BOCOL(aItens[nI][1]))
        EndIf
        If nPreco <= 0
            Return {.F., "produto_sem_preco: " + BOCOL(aItens[nI][1]), {}}
        EndIf
        aAdd(aIt, {BOCOL(aItens[nI][1]), BOVAL(aItens[nI][2]), nPreco})
        nTot := nTot + Round(BOVAL(aItens[nI][2]) * nPreco * (1 - nDesc / 100), 2)
    Next nI
    If cNum == ""
        cNum := "PV" + BOSEQ("FAT_PV", 6)
    ElseIf Len(FATPedido(cNum)) > 0
        Return {.F., "pedido_duplicado: " + cNum, {}}
    EndIf
    TCSqlExec("INSERT INTO GFT3 (D_E_L_E_T_, GFT3_FILIAL, GFT3_NUM, GFT3_CLI, GFT3_COND, GFT3_EMISSAO, GFT3_LOCAL, GFT3_DESC, GFT3_STATUS, GFT3_MOTIVO, GFT3_CC) VALUES (' ', " + ;
        GEBDBQuote(FWxFilial("GFT3")) + ", " + GEBDBQuote(cNum) + ", " + GEBDBQuote(cCli) + ", " + GEBDBQuote(Upper(BOCOL(cCond))) + ", " + ;
        GEBDBQuote(cData) + ", " + GEBDBQuote(BOCOL(cLocal)) + ", " + BONUM(nDesc, 4) + ", 'ABERTO', '', " + GEBDBQuote(Upper(BOCOL(cCC))) + ")")
    For nI := 1 To Len(aIt)
        TCSqlExec("INSERT INTO GFT4 (D_E_L_E_T_, GFT4_FILIAL, GFT4_NUM, GFT4_PROD, GFT4_QTD, GFT4_PRECO, GFT4_QTDFAT) VALUES (' ', " + ;
            GEBDBQuote(FWxFilial("GFT4")) + ", " + GEBDBQuote(cNum) + ", " + GEBDBQuote(aIt[nI][1]) + ", " + BONUM(aIt[nI][2], 4) + ", " + ;
            BONUM(aIt[nI][3], 6) + ", 0)")
    Next nI
Return {.T., "pedido " + cNum + " gravado", {cNum, nTot}}

/*/{Protheus.doc} GEBFATLIB
    Liberacao do pedido (credito e estoque). lForca libera mesmo bloqueado.
    @type Operacao faturamento
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, cStatus}
/*/
User Function GEBFATLIB(cNum, lForca)
    Local aP := {}
    Local aCli := {}
    Local aPend := {}
    Local aHit := {}
    Local cMot := ""
    Local cSt := "LIBERADO"
    Local nAberto := 0
    Local nPedido := 0
    Local nI := 0

    cNum := Upper(BOCOL(cNum))
    If lForca == Nil
        lForca := .F.
    EndIf
    If !GEBFATMIG()
        Return {.F., "falha_tabelas", ""}
    EndIf
    aP := FATPedido(cNum)
    If Len(aP) == 0
        Return {.F., "pedido_inexistente: " + cNum, ""}
    EndIf
    If !(aP[5] == "ABERTO") .And. !(aP[5] == "BLOQUEADO") .And. !(aP[5] == "LIBERADO")
        Return {.F., "pedido_nao_pode_ser_liberado: " + aP[5], ""}
    EndIf
    aCli := FATCliente(aP[2])
    aPend := FATPendente(cNum)
    For nI := 1 To Len(aPend)
        nPedido := nPedido + Round(aPend[nI][2] * aPend[nI][3] * (1 - aP[6] / 100), 2)
        If GEBESTSLD(aPend[nI][1], FATLocal(aP[4]))[1] < aPend[nI][2] .And. !(BOPARM("EST_NEGATIVO", "N") == "S")
            cMot := cMot + "estoque " + aPend[nI][1] + "; "
        EndIf
    Next nI
    If Len(aCli) > 0 .And. aCli[3] > 0
        aHit := TCSqlQuery("SELECT COALESCE(SUM(GFN2_SALDO), 0) AS S FROM GFN2 WHERE GFN2_FILIAL = " + GEBDBQuote(FWxFilial("GFN2")) + ;
            " AND GFN2_CLI = " + GEBDBQuote(aP[2]) + " AND GFN2_STATUS = 'ABERTO' AND D_E_L_E_T_ = ' '")
        nAberto := BOVAL(aHit[1]:S)
        If nAberto + nPedido > aCli[3]
            cMot := cMot + "credito: em aberto " + BONUM(nAberto, 2) + " + pedido " + BONUM(nPedido, 2) + " > limite " + BONUM(aCli[3], 2) + "; "
        EndIf
    EndIf
    If !(cMot == "") .And. !lForca
        cSt := "BLOQUEADO"
    EndIf
    TCSqlExec("UPDATE GFT3 SET GFT3_STATUS = " + GEBDBQuote(cSt) + ", GFT3_MOTIVO = " + GEBDBQuote(Left(cMot, 200)) + ;
        " WHERE GFT3_FILIAL = " + GEBDBQuote(FWxFilial("GFT3")) + " AND GFT3_NUM = " + GEBDBQuote(cNum) + " AND D_E_L_E_T_ = ' '")
    If cSt == "BLOQUEADO"
        Return {.T., "pedido bloqueado: " + AllTrim(cMot), cSt}
    EndIf
Return {.T., "pedido liberado", cSt}

/*/{Protheus.doc} GEBFATCAN
    Cancela pedido sem nenhum faturamento.
    @type Operacao faturamento
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBFATCAN(cNum)
    Local aP := {}
    cNum := Upper(BOCOL(cNum))
    If !GEBFATMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    aP := FATPedido(cNum)
    If Len(aP) == 0
        Return {.F., "pedido_inexistente: " + cNum}
    EndIf
    If aP[5] == "PARCIAL" .Or. aP[5] == "FATURADO" .Or. aP[5] == "CANCELADO"
        Return {.F., "pedido_nao_pode_ser_cancelado: " + aP[5]}
    EndIf
    TCSqlExec("UPDATE GFT3 SET GFT3_STATUS = 'CANCELADO' WHERE GFT3_FILIAL = " + GEBDBQuote(FWxFilial("GFT3")) + ;
        " AND GFT3_NUM = " + GEBDBQuote(cNum) + " AND D_E_L_E_T_ = ' '")
Return {.T., "pedido " + cNum + " cancelado"}

/*/{Protheus.doc} GEBFATFAT
    Documento de saida do pedido liberado.
    @type Operacao faturamento
    @author Peder Munksgaard
    @since 18/10/2026
    @param aItens {{cProd, nQtd}...}; vazio = todo o saldo
    @return {lOk, cMsg, {cNota, nTotal, nCusto, cStatusPedido, aTitulos}}
/*/
User Function GEBFATFAT(cNum, aItens, cData, cNota)
    Local oDfe := Nil
    Local aP := {}
    Local aPend := {}
    Local aFat := {}
    Local aNF := {}
    Local aR := {}
    Local aTit := {}
    Local cLocal := ""
    Local cSt := "FATURADO"
    Local nPos := 0
    Local nQtd := 0
    Local nTot := 0
    Local nCusto := 0
    Local nI := 0
    Local nJ := 0

    cNum := Upper(BOCOL(cNum))
    cData := BODATA(cData)
    cNota := Upper(BOCOL(cNota))
    If aItens == Nil
        aItens := {}
    EndIf
    If cData == ""
        Return {.F., "data_invalida", {}}
    EndIf
    If !GEBFATMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aP := FATPedido(cNum)
    If Len(aP) == 0
        Return {.F., "pedido_inexistente: " + cNum, {}}
    EndIf
    If !(aP[5] == "LIBERADO") .And. !(aP[5] == "PARCIAL")
        Return {.F., "pedido_nao_liberado: " + aP[5], {}}
    EndIf
    cLocal := FATLocal(aP[4])
    aPend := FATPendente(cNum)
    If Len(aItens) == 0
        For nI := 1 To Len(aPend)
            If aPend[nI][2] > 0
                aAdd(aFat, {aPend[nI][1], aPend[nI][2], Round(aPend[nI][3] * (1 - aP[6] / 100), 6)})
            EndIf
        Next nI
    Else
        For nI := 1 To Len(aItens)
            nPos := 0
            For nJ := 1 To Len(aPend)
                If aPend[nJ][1] == BOCOL(aItens[nI][1])
                    nPos := nJ
                EndIf
            Next nJ
            nQtd := BOVAL(aItens[nI][2])
            If nPos == 0
                Return {.F., "produto_fora_do_pedido: " + BOCOL(aItens[nI][1]), {}}
            EndIf
            If nQtd <= 0 .Or. nQtd > aPend[nPos][2]
                Return {.F., "quantidade_acima_do_saldo: " + aPend[nPos][1] + " saldo " + BONUM(aPend[nPos][2], 4), {}}
            EndIf
            aAdd(aFat, {aPend[nPos][1], nQtd, Round(aPend[nPos][3] * (1 - aP[6] / 100), 6)})
        Next nI
    EndIf
    If Len(aFat) == 0
        Return {.F., "nada_a_faturar", {}}
    EndIf
    // Confere estoque (e lotes) e numeracao antes de gravar qualquer coisa.
    For nI := 1 To Len(aFat)
        If GEBESTSLD(aFat[nI][1], cLocal)[1] < aFat[nI][2] .And. !(BOPARM("EST_NEGATIVO", "N") == "S")
            Return {.F., "saldo_insuficiente: " + aFat[nI][1], {}}
        EndIf
        aR := GEBESTVALLOTE(aFat[nI][1], cLocal, "S", aFat[nI][2], {}, "", cData)
        If !aR[1]
            Return {.F., aR[2], {}}
        EndIf
        nTot := nTot + Round(aFat[nI][2] * aFat[nI][3], 2)
    Next nI
    If cNota == ""
        cNota := "NS" + BOSEQ("FAT_NF", 6)
    EndIf
    If Len(TCSqlQuery("SELECT GF3_CHAVE FROM GF3 WHERE GF3_FILIAL = " + GEBDBQuote(FWxFilial("GF3")) + " AND GF3_CHAVE = " + GEBDBQuote(cNota) + " AND D_E_L_E_T_ = ' '")) > 0
        Return {.F., "nota_duplicada: " + cNota, {}}
    EndIf
    If Len(TCSqlQuery("SELECT GFN2_DOC FROM GFN2 WHERE GFN2_FILIAL = " + GEBDBQuote(FWxFilial("GFN2")) + " AND (GFN2_DOC = " + GEBDBQuote(cNota) + ;
            " OR GFN2_DOC LIKE " + GEBDBQuote(cNota + "/%") + ") AND D_E_L_E_T_ = ' '")) > 0
        Return {.F., "titulo_ja_existe: " + cNota, {}}
    EndIf

    // NF-e real (GE4 DFE_NFE = S): autorizada antes de gravar; recusada = nada gravado.
    If BOPARM("DFE_NFE", "N") == "S"
        aR := GEBFXPARC(aP[3], nTot, cData)
        oDfe := JsonObject():New()
        oDfe["ORIGEM"] := "FAT"
        oDfe["DOC"] := cNum
        oDfe["TIPO_PART"] := "C"
        oDfe["PART"] := aP[2]
        oDfe["TPNF"] := "1"
        oDfe["FINNFE"] := "1"
        oDfe["NATOP"] := "VENDA DE MERCADORIA"
        oDfe["NFAT"] := cNum
        oDfe["ITENS"] := {}
        For nI := 1 To Len(aFat)
            aAdd(oDfe["ITENS"], {aFat[nI][1], aFat[nI][2], aFat[nI][3], 0})
        Next nI
        If aR[1]
            oDfe["PARCELAS"] := aR[3]
        EndIf
        aR := GEBDFENFE(oDfe)
        If !aR[1]
            Return {.F., aR[2], {}}
        EndIf
        cNota := aR[3][1]
    EndIf
    aNF := GEBFATNOTA(cNota, aFat, cData)
    If BOPARM("DFE_NFE", "N") == "S"
        TCSqlExec("UPDATE GF3 SET GF3_STATUS = 'AUTORIZADA' WHERE GF3_FILIAL = " + GEBDBQuote(FWxFilial("GF3")) + " AND GF3_CHAVE = " + GEBDBQuote(cNota) + ;
            " AND D_E_L_E_T_ = ' '")
        aNF[1] := "NF-e autorizada"
    EndIf
    For nI := 1 To Len(aFat)
        aR := GEBESTMOV(aFat[nI][1], cLocal, "S", aFat[nI][2], 0, "VENDA", cNota, cData)
        nCusto := nCusto + aR[3][2]
        TCSqlExec("INSERT INTO GFT6 (D_E_L_E_T_, GFT6_FILIAL, GFT6_NOTA, GFT6_PROD, GFT6_QTD, GFT6_PRECO, GFT6_VALOR, GFT6_CUSTO, GFT6_QTDDEV) VALUES (' ', " + ;
            GEBDBQuote(FWxFilial("GFT6")) + ", " + GEBDBQuote(cNota) + ", " + GEBDBQuote(aFat[nI][1]) + ", " + BONUM(aFat[nI][2], 4) + ", " + ;
            BONUM(aFat[nI][3], 6) + ", " + BONUM(Round(aFat[nI][2] * aFat[nI][3], 2), 2) + ", " + BONUM(aR[3][2], 2) + ", 0)")
        TCSqlExec("UPDATE GFT4 SET GFT4_QTDFAT = GFT4_QTDFAT + " + BONUM(aFat[nI][2], 4) + " WHERE GFT4_FILIAL = " + GEBDBQuote(FWxFilial("GFT4")) + ;
            " AND GFT4_NUM = " + GEBDBQuote(cNum) + " AND GFT4_PROD = " + GEBDBQuote(aFat[nI][1]) + " AND D_E_L_E_T_ = ' '")
    Next nI
    aR := GEBFXTIT("R", cNota, aP[2], nTot, aP[3], cData, "VENDA " + cNum, "")
    If aR[1]
        aTit := aR[3]
    EndIf
    GEBCTXLP("VENDA_RECEITA", nTot, cNota, cData, "", "", aP[7])
    GEBCTXLP("VENDA_CMV", nCusto, cNota, cData, "", "", aP[7])
    TCSqlExec("INSERT INTO GFT5 (D_E_L_E_T_, GFT5_FILIAL, GFT5_NOTA, GFT5_PED, GFT5_CLI, GFT5_DATA, GFT5_TOTAL, GFT5_CUSTO, GFT5_IBS, GFT5_CBS) VALUES (' ', " + ;
        GEBDBQuote(FWxFilial("GFT5")) + ", " + GEBDBQuote(cNota) + ", " + GEBDBQuote(cNum) + ", " + GEBDBQuote(aP[2]) + ", " + GEBDBQuote(cData) + ", " + ;
        BONUM(nTot, 2) + ", " + BONUM(nCusto, 2) + ", " + BONUM(aNF[2], 2) + ", " + BONUM(aNF[3], 2) + ")")
    aPend := FATPendente(cNum)
    For nI := 1 To Len(aPend)
        If aPend[nI][2] > 0
            cSt := "PARCIAL"
        EndIf
    Next nI
    TCSqlExec("UPDATE GFT3 SET GFT3_STATUS = " + GEBDBQuote(cSt) + " WHERE GFT3_FILIAL = " + GEBDBQuote(FWxFilial("GFT3")) + ;
        " AND GFT3_NUM = " + GEBDBQuote(cNum) + " AND D_E_L_E_T_ = ' '")
Return {.T., "nota " + cNota + " emitida (" + aNF[1] + "); pedido " + cSt, {cNota, Round(nTot, 2), Round(nCusto, 2), cSt, aTit}}

/*/{Protheus.doc} GEBFATNOTA
    Nota fiscal com varios itens: GF3 (cabecalho) + GF4 (um por item). IBS
    e CBS pela aliquota vigente da NCM do produto (GF1/GF2). GE4 EMISSAO =
    SO_FILA grava EM_FILA; senao AUTORIZADA (o GEBAN simula a SEFAZ).
    cTipo: NFE (venda, padrao) ou DEVC (devolucao de compra; nao e' receita).
    Usada pelo faturamento, pela frente de loja e pela devolucao de compra.
    @type Servico fiscal
    @author Peder Munksgaard
    @since 18/10/2026
    @param aItens {{cProd, nQtd, nPrecoLiquido}...}
    @return {cStatus, nIBS, nCBS, nBase}
/*/
User Function GEBFATNOTA(cChave, aItens, cData, cTipo)
    Local aHit := {}
    Local aTx := {}
    Local cStatus := "AUTORIZADA"
    Local cNCM := ""
    Local nBase := 0
    Local nIBS := 0
    Local nCBS := 0
    Local nB := 0
    Local nI1 := 0
    Local nC1 := 0
    Local nI := 0

    If cTipo == Nil .Or. BOCOL(cTipo) == ""
        cTipo := "NFE"
    EndIf
    If GEBCFG("EMISSAO") == "SO_FILA"
        cStatus := "EM_FILA"
    EndIf
    For nI := 1 To Len(aItens)
        cNCM := ""
        aHit := TCSqlQuery("SELECT GF1_NCM AS N FROM GF1 WHERE GF1_FILIAL = " + GEBDBQuote(FWxFilial("GF1")) + " AND GF1_COD = " + ;
            GEBDBQuote(aItens[nI][1]) + " AND D_E_L_E_T_ = ' '")
        If Len(aHit) > 0
            cNCM := BOCOL(aHit[1]:N)
        EndIf
        aTx := ALIQF(cNCM, cData)
        nB := Round(aItens[nI][2] * aItens[nI][3], 2)
        nI1 := Round(nB * aTx[1] / 100, 2)
        nC1 := Round(nB * aTx[2] / 100, 2)
        nBase := nBase + nB
        nIBS := nIBS + nI1
        nCBS := nCBS + nC1
        TCSqlExec("INSERT INTO GF4 (D_E_L_E_T_, GF4_FILIAL, GF4_CHAVE, GF4_ITEM, GF4_PROD, GF4_QTD, GF4_PRECO, GF4_BASE, GF4_IBS, GF4_CBS) VALUES (' ', " + ;
            GEBDBQuote(FWxFilial("GF4")) + ", " + GEBDBQuote(cChave) + ", " + GEBDBQuote(StrZero(nI, 3)) + ", " + GEBDBQuote(aItens[nI][1]) + ", " + ;
            BONUM(aItens[nI][2], 4) + ", " + BONUM(aItens[nI][3], 2) + ", " + BONUM(nB, 2) + ", " + BONUM(nI1, 2) + ", " + BONUM(nC1, 2) + ")")
    Next nI
    TCSqlExec("INSERT INTO GF3 (D_E_L_E_T_, GF3_FILIAL, GF3_CHAVE, GF3_TIPO, GF3_STATUS, GF3_BASE, GF3_IBS, GF3_CBS, GF3_EMIS) VALUES (' ', " + ;
        GEBDBQuote(FWxFilial("GF3")) + ", " + GEBDBQuote(cChave) + ", " + GEBDBQuote(cTipo) + ", " + GEBDBQuote(cStatus) + ", " + BONUM(nBase, 2) + ", " + ;
        BONUM(nIBS, 2) + ", " + BONUM(nCBS, 2) + ", " + GEBDBQuote(cData) + ")")
Return {cStatus, Round(nIBS, 2), Round(nCBS, 2), Round(nBase, 2)}

/*/{Protheus.doc} GEBFATDEV
    Devolucao de venda (itens de uma nota).
    @type Operacao faturamento
    @author Peder Munksgaard
    @since 18/10/2026
    @param aItens {{cProd, nQtd}...}
    @return {lOk, cMsg, {cDev, nValor, nCusto, nAbatido, nCredito}}
/*/
User Function GEBFATDEV(cNota, aItens, cData, cChaveCli)
    Local oDfe := Nil
    Local oPart := Nil
    Local aDoc := {}
    Local aN := {}
    Local aIt := {}
    Local aHit := {}
    Local cDev := ""
    Local cCli := ""
    Local cLocal := ""
    Local nVal := 0
    Local nCus := 0
    Local nTotV := 0
    Local nTotC := 0
    Local nAbat := 0
    Local nResto := 0
    Local nTira := 0
    Local nQtd := 0
    Local nI := 0
    Local nJ := 0
    Local nK := 0
    Local cCC := ""

    cNota := Upper(BOCOL(cNota))
    cData := BODATA(cData)
    If aItens == Nil .Or. Len(aItens) == 0 .Or. cData == ""
        Return {.F., "itens_e_data_obrigatorios", {}}
    EndIf
    If !GEBFATMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GFT5_CLI AS C, GFT5_PED AS P FROM GFT5 WHERE GFT5_FILIAL = " + GEBDBQuote(FWxFilial("GFT5")) + ;
        " AND GFT5_NOTA = " + GEBDBQuote(cNota) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {.F., "nota_inexistente: " + cNota, {}}
    EndIf
    cCli := BOCOL(aHit[1]:C)
    cLocal := FATLocal(FATPedido(BOCOL(aHit[1]:P))[4])
    cCC := FATPedido(BOCOL(aHit[1]:P))[7]
    aN := TCSqlQuery("SELECT GFT6_PROD AS P, GFT6_QTD AS Q, GFT6_PRECO AS PR, GFT6_CUSTO AS CU, GFT6_QTDDEV AS QD FROM GFT6 WHERE GFT6_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GFT6")) + " AND GFT6_NOTA = " + GEBDBQuote(cNota) + " AND D_E_L_E_T_ = ' '")
    For nI := 1 To Len(aItens)
        nQtd := BOVAL(aItens[nI][2])
        nJ := 0
        For nK := 1 To Len(aN)
            If BOCOL(aN[nK]:P) == BOCOL(aItens[nI][1])
                nJ := nK
            EndIf
        Next nK
        If nJ == 0
            Return {.F., "produto_fora_da_nota: " + BOCOL(aItens[nI][1]), {}}
        EndIf
        If nQtd <= 0 .Or. nQtd > BOVAL(aN[nJ]:Q) - BOVAL(aN[nJ]:QD)
            Return {.F., "quantidade_acima_do_devolvivel: " + BOCOL(aItens[nI][1]), {}}
        EndIf
        nVal := Round(nQtd * BOVAL(aN[nJ]:PR), 2)
        nCus := Round(BOVAL(aN[nJ]:CU) / BOVAL(aN[nJ]:Q) * nQtd, 2)
        aAdd(aIt, {BOCOL(aItens[nI][1]), nQtd, nVal, nCus})
    Next nI
    For nI := 1 To Len(aIt)
        aHit := GEBESTVALLOTE(aIt[nI][1], cLocal, "E", aIt[nI][2], {}, cNota, cData)
        If !aHit[1]
            Return {.F., aHit[2], {}}
        EndIf
    Next nI
    // Nota eletronica: cliente contribuinte devolve com a NF-e dele (chave obrigatoria);
    // consumidor/nao contribuinte => o GEBAN emite a NF-e de entrada referenciando a nota.
    aDoc := GEBDFEDOC(cNota)
    If Len(aDoc) > 0
        oPart := GEBDFEPARTLE("C", cCli)
        If oPart != Nil .And. oPart["INDIEDEST"] == "1"
            If !(Len(GEBDFEDIG(cChaveCli)) == 44)
                Return {.F., "cliente_contribuinte: informe a chave da NF-e de devolucao emitida pelo cliente", {}}
            EndIf
        Else
            oDfe := JsonObject():New()
            oDfe["ORIGEM"] := "FATDEV"
            oDfe["DOC"] := cNota
            oDfe["TIPO_PART"] := "C"
            oDfe["PART"] := cCli
            oDfe["TPNF"] := "0"
            oDfe["FINNFE"] := "4"
            oDfe["NATOP"] := "DEVOLUCAO DE VENDA"
            oDfe["REFS"] := {cNota}
            oDfe["ITENS"] := {}
            For nI := 1 To Len(aIt)
                aAdd(oDfe["ITENS"], {aIt[nI][1], aIt[nI][2], Round(aIt[nI][3] / aIt[nI][2], 6), 0})
            Next nI
            aHit := GEBDFENFE(oDfe)
            If !aHit[1]
                Return {.F., aHit[2], {}}
            EndIf
            cChaveCli := ""
        EndIf
    EndIf
    cDev := "DV" + BOSEQ("FAT_DEV", 6)
    If Len(GEBDFEDIG(cChaveCli)) == 44
        GEBDFEVINC("DEVCLI", cDev, cCli, cChaveCli)
    EndIf
    For nI := 1 To Len(aIt)
        GEBESTMOV(aIt[nI][1], cLocal, "E", aIt[nI][2], Round(aIt[nI][4] / aIt[nI][2], 6), "DEVOLUCAO", cDev, cData, {}, cNota)
        TCSqlExec("UPDATE GFT6 SET GFT6_QTDDEV = GFT6_QTDDEV + " + BONUM(aIt[nI][2], 4) + " WHERE GFT6_FILIAL = " + GEBDBQuote(FWxFilial("GFT6")) + ;
            " AND GFT6_NOTA = " + GEBDBQuote(cNota) + " AND GFT6_PROD = " + GEBDBQuote(aIt[nI][1]) + " AND D_E_L_E_T_ = ' '")
        TCSqlExec("INSERT INTO GFT7 (D_E_L_E_T_, GFT7_FILIAL, GFT7_DEV, GFT7_NOTA, GFT7_PROD, GFT7_QTD, GFT7_VALOR, GFT7_CUSTO, GFT7_DATA) VALUES (' ', " + ;
            GEBDBQuote(FWxFilial("GFT7")) + ", " + GEBDBQuote(cDev) + ", " + GEBDBQuote(cNota) + ", " + GEBDBQuote(aIt[nI][1]) + ", " + ;
            BONUM(aIt[nI][2], 4) + ", " + BONUM(aIt[nI][3], 2) + ", " + BONUM(aIt[nI][4], 2) + ", " + GEBDBQuote(cData) + ")")
        nTotV := nTotV + aIt[nI][3]
        nTotC := nTotC + aIt[nI][4]
    Next nI
    // Abate titulos abertos da nota (da ultima parcela para a primeira).
    nResto := Round(nTotV, 2)
    aHit := TCSqlQuery("SELECT GFN2_DOC AS D, GFN2_SALDO AS S FROM GFN2 WHERE GFN2_FILIAL = " + GEBDBQuote(FWxFilial("GFN2")) + " AND (GFN2_DOC = " + ;
        GEBDBQuote(cNota) + " OR GFN2_DOC LIKE " + GEBDBQuote(cNota + "/%") + ") AND GFN2_STATUS = 'ABERTO' AND D_E_L_E_T_ = ' ' ORDER BY GFN2_DOC DESC")
    For nI := 1 To Len(aHit)
        If nResto <= 0
            Exit
        EndIf
        nTira := BOVAL(aHit[nI]:S)
        If nResto < nTira
            nTira := nResto
        EndIf
        TCSqlExec("UPDATE GFN2 SET GFN2_SALDO = GFN2_SALDO - " + BONUM(nTira, 2) + ", GFN2_STATUS = CASE WHEN GFN2_SALDO - " + BONUM(nTira, 2) + ;
            " <= 0 THEN 'ABATIDO' ELSE 'ABERTO' END WHERE GFN2_FILIAL = " + GEBDBQuote(FWxFilial("GFN2")) + " AND GFN2_DOC = " + GEBDBQuote(BOCOL(aHit[nI]:D)) + ;
            " AND D_E_L_E_T_ = ' '")
        nAbat := nAbat + nTira
        nResto := Round(nResto - nTira, 2)
    Next nI
    GEBCTXLP("DEVOL_VENDA", nAbat, cDev + " " + cNota, cData, "", "", cCC)
    If nResto > 0
        GEBFXTIT("P", "DEVC-" + cDev, cCli, nResto, "0", cData, "DEVOLUCAO " + cNota, "2.01.003")
        GEBCTXLP("DEVOL_VENDA", nResto, cDev + " " + cNota, cData, "", "2.01.003", cCC)
    EndIf
    GEBCTXLP("DEVOL_CMV", nTotC, cDev + " " + cNota, cData, "", "", cCC)
Return {.T., "devolucao " + cDev + " registrada", {cDev, Round(nTotV, 2), Round(nTotC, 2), Round(nAbat, 2), nResto}}

/*/{Protheus.doc} GEBFATREL
    Relatorio: faturamento do periodo por CLIENTE ou PRODUTO: quantidade,
    valor liquido de devolucoes, custo, margem e margem %.
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {aLinhas (1a = cabecalho), aTotais}}
/*/
User Function GEBFATREL(cIni, cFim, cAgrupa)
    Local aHit := {}
    Local aLin := {}
    Local aRel := {}
    Local cK := ""
    Local nV := 0
    Local nC := 0
    Local nTV := 0
    Local nTC := 0
    Local nI := 0

    cIni := BODATA(cIni)
    cFim := BODATA(cFim)
    cAgrupa := Upper(BOCOL(cAgrupa))
    If cAgrupa == ""
        cAgrupa := "CLIENTE"
    EndIf
    If cIni == "" .Or. cFim == "" .Or. cIni > cFim .Or. !(cAgrupa == "CLIENTE" .Or. cAgrupa == "PRODUTO")
        Return {.F., "parametros_invalidos: periodo e CLIENTE/PRODUTO", {}}
    EndIf
    If !GEBFATMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    cK := "GFT5_CLI"
    If cAgrupa == "PRODUTO"
        cK := "GFT6_PROD"
    EndIf
    aHit := TCSqlQuery("SELECT " + cK + " AS K, SUM(GFT6_QTD - GFT6_QTDDEV) AS Q, " + ;
        "SUM(GFT6_VALOR - COALESCE((SELECT SUM(GFT7_VALOR) FROM GFT7 WHERE GFT7_FILIAL = GFT6_FILIAL AND GFT7_NOTA = GFT6_NOTA AND GFT7_PROD = GFT6_PROD AND GFT7.D_E_L_E_T_ = ' '), 0)) AS V, " + ;
        "SUM(GFT6_CUSTO - COALESCE((SELECT SUM(GFT7_CUSTO) FROM GFT7 WHERE GFT7_FILIAL = GFT6_FILIAL AND GFT7_NOTA = GFT6_NOTA AND GFT7_PROD = GFT6_PROD AND GFT7.D_E_L_E_T_ = ' '), 0)) AS C " + ;
        "FROM GFT6 JOIN GFT5 ON GFT5_FILIAL = GFT6_FILIAL AND GFT5_NOTA = GFT6_NOTA AND GFT5.D_E_L_E_T_ = ' ' " + ;
        "WHERE GFT6_FILIAL = " + GEBDBQuote(FWxFilial("GFT6")) + " AND GFT6.D_E_L_E_T_ = ' ' AND GFT5_DATA BETWEEN " + GEBDBQuote(cIni) + " AND " + GEBDBQuote(cFim) + ;
        " GROUP BY 1 ORDER BY 3 DESC")
    aLin := {{Lower(cAgrupa), "quantidade", "valor", "custo", "margem", "margem_pct"}}
    For nI := 1 To Len(aHit)
        nV := Round(BOVAL(aHit[nI]:V), 2)
        nC := Round(BOVAL(aHit[nI]:C), 2)
        nTV := nTV + nV
        nTC := nTC + nC
        aAdd(aLin, {BOCOL(aHit[nI]:K), BOVAL(aHit[nI]:Q), nV, nC, Round(nV - nC, 2), FATPct(nV - nC, nV)})
    Next nI
    For nI := 1 To Len(aLin)
        aAdd(aRel, aLin[nI])
    Next nI
    aAdd(aRel, {"total", "", Round(nTV, 2), Round(nTC, 2), Round(nTV - nTC, 2), FATPct(nTV - nTC, nTV)})
    BOREL(aRel)
Return {.T., "faturamento", {aLin, {{"valor", Round(nTV, 2)}, {"custo", Round(nTC, 2)}, {"margem", Round(nTV - nTC, 2)}, ;
    {"margem_pct", FATPct(nTV - nTC, nTV)}}}}

/*/{Protheus.doc} GEBFATCARTEIRA
    Relatorio: carteira de pedidos (itens com saldo a faturar).
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {aLinhas (1a = cabecalho), aTotais}}
/*/
User Function GEBFATCARTEIRA()
    Local aHit := {}
    Local aLin := {{"pedido", "cliente", "status", "produto", "pedida", "faturada", "saldo", "valor_saldo"}}
    Local aRel := {}
    Local nS := 0
    Local nV := 0
    Local nTot := 0
    Local nI := 0
    If !GEBFATMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GFT3_NUM AS N, GFT3_CLI AS C, GFT3_STATUS AS ST, GFT3_DESC AS DS, GFT4_PROD AS P, GFT4_QTD AS Q, GFT4_QTDFAT AS F, GFT4_PRECO AS PR " + ;
        "FROM GFT3 JOIN GFT4 ON GFT4_FILIAL = GFT3_FILIAL AND GFT4_NUM = GFT3_NUM AND GFT4.D_E_L_E_T_ = ' ' WHERE GFT3_FILIAL = " + GEBDBQuote(FWxFilial("GFT3")) + ;
        " AND GFT3.D_E_L_E_T_ = ' ' AND GFT3_STATUS IN ('ABERTO', 'LIBERADO', 'BLOQUEADO', 'PARCIAL') AND GFT4_QTD > GFT4_QTDFAT ORDER BY GFT3_NUM, GFT4_PROD")
    For nI := 1 To Len(aHit)
        nS := BOVAL(aHit[nI]:Q) - BOVAL(aHit[nI]:F)
        nV := Round(nS * BOVAL(aHit[nI]:PR) * (1 - BOVAL(aHit[nI]:DS) / 100), 2)
        nTot := nTot + nV
        aAdd(aLin, {BOCOL(aHit[nI]:N), BOCOL(aHit[nI]:C), BOCOL(aHit[nI]:ST), BOCOL(aHit[nI]:P), BOVAL(aHit[nI]:Q), BOVAL(aHit[nI]:F), nS, nV})
    Next nI
    For nI := 1 To Len(aLin)
        aAdd(aRel, aLin[nI])
    Next nI
    aAdd(aRel, {"total", "", "", "", "", "", "", Round(nTot, 2)})
    BOREL(aRel)
Return {.T., "carteira", {aLin, {{"valor_a_faturar", Round(nTot, 2)}}}}

/*/{Protheus.doc} GEBFATABC
    Relatorio: curva ABC dos produtos pelo valor faturado no periodo (A ate
    80% acumulado, B ate 95%, C o resto).
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, aLinhas (1a = cabecalho)}
/*/
User Function GEBFATABC(cIni, cFim)
    Local aR := GEBFATREL(cIni, cFim, "PRODUTO")
    Local aLin := {{"produto", "valor", "pct", "pct_acumulado", "classe"}}
    Local aSrc := {}
    Local cCls := ""
    Local nTot := 0
    Local nAc := 0
    Local nI := 0
    If !aR[1]
        Return aR
    EndIf
    aSrc := aR[3][1]
    nTot := FATChave(aR[3][2], "valor")
    For nI := 2 To Len(aSrc)
        nAc := nAc + aSrc[nI][3]
        cCls := "C"
        If FATPct(nAc, nTot) <= 80 .Or. nI == 2
            cCls := "A"
        ElseIf FATPct(nAc, nTot) <= 95
            cCls := "B"
        EndIf
        aAdd(aLin, {aSrc[nI][1], aSrc[nI][3], FATPct(aSrc[nI][3], nTot), FATPct(nAc, nTot), cCls})
    Next nI
    BOREL(aLin)
Return {.T., "curva_abc", aLin}

// Preco do produto na tabela (vazia = PADRAO, cai para PADRAO se faltar); 0 se nao tem.
User Function GEBFATPRECO(cTab, cProd)
Return FATPreco(Upper(BOCOL(cTab)), BOCOL(cProd))

// Cliente: {cCod, cNome, nLimite, cCond, cTabela}; {} se nao existe.
Static Function FATCliente(cCli)
    Local aHit := TCSqlQuery("SELECT GFT1_NOME AS N, GFT1_LIMITE AS L, GFT1_COND AS C, GFT1_TABELA AS T FROM GFT1 WHERE GFT1_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GFT1")) + " AND GFT1_COD = " + GEBDBQuote(cCli) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {}
    EndIf
Return {cCli, BOCOL(aHit[1]:N), BOVAL(aHit[1]:L), BOCOL(aHit[1]:C), BOCOL(aHit[1]:T)}

// Pedido: {cNum, cCli, cCond, cLocal, cStatus, nDesc, cCentroCusto}; {} se nao existe.
Static Function FATPedido(cNum)
    Local aHit := TCSqlQuery("SELECT GFT3_CLI AS C, GFT3_COND AS CO, GFT3_LOCAL AS L, GFT3_STATUS AS S, GFT3_DESC AS D, GFT3_CC AS CC FROM GFT3 WHERE GFT3_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GFT3")) + " AND GFT3_NUM = " + GEBDBQuote(cNum) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {}
    EndIf
Return {cNum, BOCOL(aHit[1]:C), BOCOL(aHit[1]:CO), BOCOL(aHit[1]:L), BOCOL(aHit[1]:S), BOVAL(aHit[1]:D), BOCOL(aHit[1]:CC)}

// Itens com saldo: {{cProd, nSaldo, nPreco}...}.
Static Function FATPendente(cNum)
    Local aRet := {}
    Local aHit := TCSqlQuery("SELECT GFT4_PROD AS P, GFT4_QTD - GFT4_QTDFAT AS S, GFT4_PRECO AS PR FROM GFT4 WHERE GFT4_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GFT4")) + " AND GFT4_NUM = " + GEBDBQuote(cNum) + " AND D_E_L_E_T_ = ' ' ORDER BY R_E_C_N_O_")
    Local nI := 0
    For nI := 1 To Len(aHit)
        aAdd(aRet, {BOCOL(aHit[nI]:P), BOVAL(aHit[nI]:S), BOVAL(aHit[nI]:PR)})
    Next nI
Return aRet

Static Function FATPreco(cTab, cProd)
    Local aHit := {}
    If cTab == ""
        cTab := "PADRAO"
    EndIf
    aHit := TCSqlQuery("SELECT GFT2_PRECO AS P FROM GFT2 WHERE GFT2_FILIAL = " + GEBDBQuote(FWxFilial("GFT2")) + " AND GFT2_TAB = " + ;
        GEBDBQuote(cTab) + " AND GFT2_PROD = " + GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0 .And. !(cTab == "PADRAO")
        Return FATPreco("PADRAO", cProd)
    EndIf
    If Len(aHit) == 0
        Return 0
    EndIf
Return BOVAL(aHit[1]:P)

Static Function FATLocal(cLocal)
    If BOCOL(cLocal) == ""
        Return "01"
    EndIf
Return BOCOL(cLocal)

Static Function FATPct(nParte, nTotal)
    If nTotal == 0
        Return 0
    EndIf
Return Round(nParte / nTotal * 100, 2)

Static Function FATChave(aP, cK)
    Local nI := 0
    For nI := 1 To Len(aP)
        If aP[nI][1] == cK
            Return aP[nI][2]
        EndIf
    Next nI
Return Nil
