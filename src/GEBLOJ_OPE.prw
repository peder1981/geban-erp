#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBCTX.prw"
#include "GEBEST.prw"
#include "GEBFNX.prw"
#include "GEBFAT.prw"
#include "GEBLOJ_CAD.prw"
#include "GEBLOJ.prw"
#include "GEBDFE_DANFE.prw"
#include "GEBDFE_NFE.prw"

/*/{Protheus.doc} GEBLOJ_OPE
    Operacoes da frente de loja ampliada (inspirado em LOJA701 orcamento,
    LOJA720 troca/devolucao e LOJR relatorios do Protheus).
    - Orcamento (pre-venda, GLJD/GLJE): o vendedor monta, o preco fica
      congelado (tabela ou promocao do dia), vale GE4 LOJ_ORC_DIAS (padrao
      7) dias; o caixa finaliza com os pagamentos (vira cupom) ou cancela.
      Nao reserva estoque.
    - Devolucao no caixa (GLJH): itens de um cupom vendido, ate o que falta
      devolver, pelo valor liquido do desconto. Estoque volta pelo custo da
      saida; a devolucao entra em GFT7 (abate o IBS/CBS na apuracao e a
      receita do Simples). Modo DINHEIRO sai da gaveta (D 3.02.001 / C
      caixa); modo VALE gera vale-troca (GLJF, D 3.02.001 / C 2.01.003),
      usado depois como pagamento VALE.
    - GEBLOJCUPOM: segunda via do cupom em texto. GEBLOJCONS: consulta de
      preco (tabela, promocao e saldo). GEBLOJVALE: saldo do vale.
    - Relatorios: GEBLOJGER (por dia, caixa, operador ou vendedor: cupons,
      cancelados, vendas, descontos, ticket medio, devolucoes e liquido) e
      GEBLOJCOMIS (comissao por vendedor: vendas - devolucoes x %).
    @type Modulo frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
/*/

/*/{Protheus.doc} GEBLOJORC
    Grava o orcamento.
    @type Operacao frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
    @param aItens {{cProd ou codigo de barras, nQtd[, nPreco]}...}
    @return {lOk, cMsg, {cOrc, nTotal, cValidade}}
/*/
User Function GEBLOJORC(aItens, cCli, cVend, nDesc, cData)
    Local aIt := {}
    Local aR := {}
    Local cOrc := ""
    Local cValid := ""
    Local nBruto := 0
    Local nPreco := 0
    Local nI := 0
    cCli := Upper(BOCOL(cCli))
    cVend := Upper(BOCOL(cVend))
    nDesc := Round(BOVAL(nDesc), 2)
    cData := BODATA(cData)
    If aItens == Nil .Or. Len(aItens) == 0 .Or. cData == ""
        Return {.F., "itens_e_data_obrigatorios", {}}
    EndIf
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    If !(cVend == "") .And. !GEBLOJVENDOK(cVend)
        Return {.F., "vendedor_inexistente: " + cVend, {}}
    EndIf
    For nI := 1 To Len(aItens)
        nPreco := 0
        If Len(aItens[nI]) >= 3
            nPreco := BOVAL(aItens[nI][3])
        EndIf
        If BOCOL(aItens[nI][1]) == "" .Or. BOVAL(aItens[nI][2]) <= 0
            Return {.F., "item_invalido: " + BONUM(nI, 0), {}}
        EndIf
        aR := GEBLOJRESOLVE(aItens[nI][1], aItens[nI][2], nPreco)
        If !aR[1]
            Return {.F., aR[2], {}}
        EndIf
        nPreco := aR[3][3]
        If nPreco <= 0
            nPreco := GEBLOJPRECO(aR[3][1], aR[3][2], cData)[1]
        EndIf
        If nPreco <= 0
            Return {.F., "produto_sem_preco: " + aR[3][1], {}}
        EndIf
        aAdd(aIt, {aR[3][1], aR[3][2], nPreco})
        nBruto := nBruto + Round(aR[3][2] * nPreco, 2)
    Next nI
    If nDesc < 0 .Or. Round(nBruto - nDesc, 2) <= 0
        Return {.F., "desconto_invalido", {}}
    EndIf
    cOrc := "OR" + BOSEQ("LOJ_ORC", 8)
    cValid := BODTADD(cData, Int(BOVAL(BOPARM("LOJ_ORC_DIAS", "7"))))
    For nI := 1 To Len(aIt)
        TCSqlExec("INSERT INTO GLJE (D_E_L_E_T_, GLJE_FILIAL, GLJE_ORC, GLJE_PROD, GLJE_QTD, GLJE_PRECO) VALUES (' ', " + GEBDBQuote(FWxFilial("GLJE")) + ", " + ;
            GEBDBQuote(cOrc) + ", " + GEBDBQuote(aIt[nI][1]) + ", " + BONUM(aIt[nI][2], 4) + ", " + BONUM(aIt[nI][3], 6) + ")")
    Next nI
    TCSqlExec("INSERT INTO GLJD (D_E_L_E_T_, GLJD_FILIAL, GLJD_ORC, GLJD_CLI, GLJD_VEND, GLJD_DATA, GLJD_VALID, GLJD_DESC, GLJD_TOTAL, GLJD_STATUS, GLJD_CUPOM) VALUES (' ', " + ;
        GEBDBQuote(FWxFilial("GLJD")) + ", " + GEBDBQuote(cOrc) + ", " + GEBDBQuote(cCli) + ", " + GEBDBQuote(cVend) + ", " + GEBDBQuote(cData) + ", " + ;
        GEBDBQuote(cValid) + ", " + BONUM(nDesc, 2) + ", " + BONUM(nBruto - nDesc, 2) + ", 'ABERTO', '')")
Return {.T., "orcamento " + cOrc + " gravado (valido ate " + cValid + ")", {cOrc, Round(nBruto - nDesc, 2), cValid}}

/*/{Protheus.doc} GEBLOJORCFIN
    Finaliza o orcamento no caixa: vira cupom (GEBLOJVEN) com os precos do
    orcamento.
    @type Operacao frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {cCupom, nTotal, nTroco, cNota}}
/*/
User Function GEBLOJORCFIN(cSessao, cOrc, aPagtos, cCPF, cSuperv, cSenhaSup)
    Local aO := {}
    Local aSes := {}
    Local aHit := {}
    Local aIt := {}
    Local aR := {}
    Local nI := 0
    cOrc := Upper(BOCOL(cOrc))
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aO := LOJOrc(cOrc)
    If Len(aO) == 0
        Return {.F., "orcamento_inexistente: " + cOrc, {}}
    EndIf
    If !(BOCOL(aO[1]:ST) == "ABERTO")
        Return {.F., "orcamento_nao_aberto: " + BOCOL(aO[1]:ST), {}}
    EndIf
    aSes := GEBLOJSES(cSessao)
    If Len(aSes) > 0 .And. aSes[4] > BOCOL(aO[1]:VA)
        Return {.F., "orcamento_vencido: valia ate " + BOCOL(aO[1]:VA), {}}
    EndIf
    aHit := TCSqlQuery("SELECT GLJE_PROD AS P, GLJE_QTD AS Q, GLJE_PRECO AS PR FROM GLJE WHERE GLJE_FILIAL = " + GEBDBQuote(FWxFilial("GLJE")) + ;
        " AND GLJE_ORC = " + GEBDBQuote(cOrc) + " AND D_E_L_E_T_ = ' ' ORDER BY R_E_C_N_O_")
    For nI := 1 To Len(aHit)
        aAdd(aIt, {BOCOL(aHit[nI]:P), BOVAL(aHit[nI]:Q), BOVAL(aHit[nI]:PR)})
    Next nI
    aR := GEBLOJVEN(cSessao, aIt, aPagtos, BOCOL(aO[1]:CL), BOVAL(aO[1]:DE), BOCOL(aO[1]:VE), cCPF, cSuperv, cSenhaSup, cOrc)
    If aR[1]
        TCSqlExec("UPDATE GLJD SET GLJD_STATUS = 'FINALIZADO', GLJD_CUPOM = " + GEBDBQuote(aR[3][1]) + " WHERE GLJD_FILIAL = " + ;
            GEBDBQuote(FWxFilial("GLJD")) + " AND GLJD_ORC = " + GEBDBQuote(cOrc) + " AND D_E_L_E_T_ = ' '")
    EndIf
Return aR

/*/{Protheus.doc} GEBLOJORCCAN
    Cancela o orcamento aberto.
    @type Operacao frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBLOJORCCAN(cOrc)
    Local aO := {}
    cOrc := Upper(BOCOL(cOrc))
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    aO := LOJOrc(cOrc)
    If Len(aO) == 0
        Return {.F., "orcamento_inexistente: " + cOrc}
    EndIf
    If !(BOCOL(aO[1]:ST) == "ABERTO")
        Return {.F., "orcamento_nao_aberto: " + BOCOL(aO[1]:ST)}
    EndIf
    TCSqlExec("UPDATE GLJD SET GLJD_STATUS = 'CANCELADO' WHERE GLJD_FILIAL = " + GEBDBQuote(FWxFilial("GLJD")) + " AND GLJD_ORC = " + ;
        GEBDBQuote(cOrc) + " AND D_E_L_E_T_ = ' '")
Return {.T., "orcamento " + cOrc + " cancelado"}

/*/{Protheus.doc} GEBLOJORCS
    Relatorio: orcamentos pelo status (vazio = ABERTO).
    @type Relatorio
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, aLinhas (1a = cabecalho)}
/*/
User Function GEBLOJORCS(cStatus)
    Local aHit := {}
    Local aLin := {{"orcamento", "data", "validade", "cliente", "vendedor", "total", "status", "cupom"}}
    Local nI := 0
    cStatus := Upper(BOCOL(cStatus))
    If cStatus == ""
        cStatus := "ABERTO"
    EndIf
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GLJD_ORC AS O, GLJD_DATA AS D, GLJD_VALID AS VA, GLJD_CLI AS C, GLJD_VEND AS V, GLJD_TOTAL AS T, GLJD_STATUS AS S, " + ;
        "GLJD_CUPOM AS CP FROM GLJD WHERE GLJD_FILIAL = " + GEBDBQuote(FWxFilial("GLJD")) + " AND GLJD_STATUS = " + GEBDBQuote(cStatus) + ;
        " AND D_E_L_E_T_ = ' ' ORDER BY GLJD_ORC")
    For nI := 1 To Len(aHit)
        aAdd(aLin, {BOCOL(aHit[nI]:O), BOCOL(aHit[nI]:D), BOCOL(aHit[nI]:VA), BOCOL(aHit[nI]:C), BOCOL(aHit[nI]:V), BOVAL(aHit[nI]:T), ;
            BOCOL(aHit[nI]:S), BOCOL(aHit[nI]:CP)})
    Next nI
    BOREL(aLin)
Return {.T., "orcamentos", aLin}

/*/{Protheus.doc} GEBLOJDEV
    Devolucao/troca no caixa (sessao aberta) de itens de um cupom vendido.
    @type Operacao frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
    @param aItens {{cProd, nQtd}...}
    @param cModo DINHEIRO (sai da gaveta) ou VALE (vale-troca; padrao)
    @param oCons Consumidor (JsonObject: DOC, NOME, LOGRADOURO, NUMERO,
           COMPLEMENTO, BAIRRO, MUNICIPIO, UF, CEP, FONE, EMAIL) quando o cupom
           tem NFC-e: a devolucao emite NF-e de entrada (finalidade 4) que
           referencia a NFC-e. Consumidor ja cadastrado (GDF7 tipo L) basta o DOC
           (ou o CPF do cupom).
    @return {lOk, cMsg, {cDev, nValor, nCusto, cVale, cChaveNFe}}
/*/
User Function GEBLOJDEV(cSessao, cCupom, aItens, cModo, cMotivo, oCons)
    Local aSes := {}
    Local aCx := {}
    Local aC := {}
    Local aV := {}
    Local aIt := {}
    Local aR := {}
    Local cDev := ""
    Local cVale := ""
    Local cProd := ""
    Local cData := ""
    Local cCred := ""
    Local nQtd := 0
    Local nResta := 0
    Local nVal := 0
    Local nCus := 0
    Local nTotV := 0
    Local nTotC := 0
    Local nI := 0
    Local aProds := {}
    Local aDfe := {}
    Local oNfe := Nil
    Local cDocC := ""
    Local cChNFe := ""

    cSessao := Upper(BOCOL(cSessao))
    cCupom := Upper(BOCOL(cCupom))
    cModo := Upper(BOCOL(cModo))
    If cModo == ""
        cModo := "VALE"
    EndIf
    If !(cModo == "VALE" .Or. cModo == "DINHEIRO")
        Return {.F., "modo_invalido: VALE ou DINHEIRO", {}}
    EndIf
    If aItens == Nil .Or. Len(aItens) == 0
        Return {.F., "itens_obrigatorios", {}}
    EndIf
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aSes := GEBLOJSES(cSessao)
    If Len(aSes) == 0 .Or. !(aSes[3] == "ABERTA")
        Return {.F., "sessao_nao_aberta: " + cSessao, {}}
    EndIf
    aCx := GEBLOJCXA(aSes[2])
    cData := aSes[4]
    aC := TCSqlQuery("SELECT GLJ3_STATUS AS ST, GLJ3_NOTA AS N, GLJ3_CLI AS CL FROM GLJ3 WHERE GLJ3_FILIAL = " + GEBDBQuote(FWxFilial("GLJ3")) + ;
        " AND GLJ3_CUPOM = " + GEBDBQuote(cCupom) + " AND D_E_L_E_T_ = ' '")
    If Len(aC) == 0
        Return {.F., "cupom_inexistente: " + cCupom, {}}
    EndIf
    If !(BOCOL(aC[1]:ST) == "VENDIDO")
        Return {.F., "cupom_cancelado: " + cCupom, {}}
    EndIf
    For nI := 1 To Len(aItens)
        cProd := BOCOL(aItens[nI][1])
        nQtd := BOVAL(aItens[nI][2])
        If AScan(aProds, cProd) > 0
            Return {.F., "produto_repetido: " + cProd, {}}
        EndIf
        aAdd(aProds, cProd)
        // Vendido menos ja devolvido (o produto pode estar em mais de uma linha do cupom).
        aV := TCSqlQuery("SELECT COALESCE(SUM(GLJ4_QTD), 0) AS Q, COALESCE(SUM(GLJ4_VALOR), 0) AS V, COALESCE(SUM(GLJ4_CUSTO), 0) AS C, " + ;
            "(SELECT COALESCE(SUM(GLJH_QTD), 0) FROM GLJH WHERE GLJH_FILIAL = GLJ4_FILIAL AND GLJH_CUPOM = GLJ4_CUPOM AND GLJH_PROD = GLJ4_PROD AND GLJH.D_E_L_E_T_ = ' ') AS QD, " + ;
            "(SELECT COALESCE(SUM(GLJH_VALOR), 0) FROM GLJH WHERE GLJH_FILIAL = GLJ4_FILIAL AND GLJH_CUPOM = GLJ4_CUPOM AND GLJH_PROD = GLJ4_PROD AND GLJH.D_E_L_E_T_ = ' ') AS VD, " + ;
            "(SELECT COALESCE(SUM(GLJH_CUSTO), 0) FROM GLJH WHERE GLJH_FILIAL = GLJ4_FILIAL AND GLJH_CUPOM = GLJ4_CUPOM AND GLJH_PROD = GLJ4_PROD AND GLJH.D_E_L_E_T_ = ' ') AS CD " + ;
            "FROM GLJ4 WHERE GLJ4_FILIAL = " + GEBDBQuote(FWxFilial("GLJ4")) + " AND GLJ4_CUPOM = " + GEBDBQuote(cCupom) + " AND GLJ4_PROD = " + ;
            GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' ' GROUP BY GLJ4_FILIAL, GLJ4_CUPOM, GLJ4_PROD")
        If Len(aV) == 0
            Return {.F., "produto_fora_do_cupom: " + cProd, {}}
        EndIf
        nResta := Round(BOVAL(aV[1]:Q) - BOVAL(aV[1]:QD), 4)
        If nQtd <= 0 .Or. nQtd > nResta
            Return {.F., "quantidade_acima_do_devolvivel: " + cProd + " (resta " + BONUM(nResta, 4) + ")", {}}
        EndIf
        // O que sobrou inteiro leva o resto exato (sem centavo perdido no arredondamento).
        If nQtd == nResta
            nVal := Round(BOVAL(aV[1]:V) - BOVAL(aV[1]:VD), 2)
            nCus := Round(BOVAL(aV[1]:C) - BOVAL(aV[1]:CD), 2)
        Else
            nVal := Round(BOVAL(aV[1]:V) / BOVAL(aV[1]:Q) * nQtd, 2)
            nCus := Round(BOVAL(aV[1]:C) / BOVAL(aV[1]:Q) * nQtd, 2)
        EndIf
        aR := GEBESTVALLOTE(cProd, aCx[3], "E", nQtd, {}, cCupom, cData)
        If !aR[1]
            Return {.F., aR[2], {}}
        EndIf
        aAdd(aIt, {cProd, nQtd, nVal, nCus})
        nTotV := nTotV + nVal
        nTotC := nTotC + nCus
    Next nI
    nTotV := Round(nTotV, 2)
    If cModo == "DINHEIRO" .And. nTotV > GEBLOJESP(cSessao)
        Return {.F., "dinheiro_insuficiente_na_gaveta: use VALE", {}}
    EndIf
    // Cupom com NFC-e: a devolucao do consumidor e' uma NF-e de entrada que referencia a NFC-e.
    aDfe := GEBDFEDOC(BOCOL(aC[1]:N))
    If Len(aDfe) > 0 .And. aDfe[5] == "65"
        If !(aDfe[1] == "AUTORIZADA")
            Return {.F., "nfce_nao_autorizada (" + aDfe[1] + "): transmita a contingencia antes da devolucao", {}}
        EndIf
        If oCons != Nil
            cDocC := GEBDFEDIG(BOSTR(oCons["DOC"]))
        EndIf
        If cDocC == ""
            cDocC := aDfe[16]
        EndIf
        If oCons != Nil .And. !(BOCOL(oCons["LOGRADOURO"]) == "")
            oCons["TIPO"] := "L"
            oCons["CODIGO"] := cDocC
            oCons["DOC"] := cDocC
            oCons["CONTRIBUINTE"] := "9"
            aR := GEBDFEPART(oCons)
            If !aR[1]
                Return {.F., "consumidor: " + aR[2], {}}
            EndIf
        EndIf
        If cDocC == "" .Or. GEBDFEPARTLE("L", cDocC) == Nil
            Return {.F., "devolucao_de_nfce: informe CPF/CNPJ, nome e endereco do consumidor (a NF-e de devolucao exige)", {}}
        EndIf
        oNfe := JsonObject():New()
        oNfe["ORIGEM"] := "LOJDEV"
        oNfe["DOC"] := cCupom
        oNfe["TIPO_PART"] := "L"
        oNfe["PART"] := cDocC
        oNfe["TPNF"] := "0"
        oNfe["FINNFE"] := "4"
        oNfe["NATOP"] := "DEVOLUCAO DE VENDA"
        oNfe["REFS"] := {BOCOL(aC[1]:N)}
        oNfe["ITENS"] := {}
        For nI := 1 To Len(aIt)
            aAdd(oNfe["ITENS"], {aIt[nI][1], aIt[nI][2], Round(aIt[nI][3] / aIt[nI][2], 6), 0})
        Next nI
        aR := GEBDFENFE(oNfe)
        If !aR[1]
            Return {.F., aR[2], {}}
        EndIf
        cChNFe := aR[3][1]
    EndIf
    cDev := "DL" + BOSEQ("LOJ_DEV", 6)
    For nI := 1 To Len(aIt)
        GEBESTMOV(aIt[nI][1], aCx[3], "E", aIt[nI][2], Round(aIt[nI][4] / aIt[nI][2], 6), "PDV_DEV", cDev, cData, {}, cCupom)
        TCSqlExec("INSERT INTO GFT7 (D_E_L_E_T_, GFT7_FILIAL, GFT7_DEV, GFT7_NOTA, GFT7_PROD, GFT7_QTD, GFT7_VALOR, GFT7_CUSTO, GFT7_DATA) VALUES (' ', " + ;
            GEBDBQuote(FWxFilial("GFT7")) + ", " + GEBDBQuote(cDev) + ", " + GEBDBQuote(BOCOL(aC[1]:N)) + ", " + GEBDBQuote(aIt[nI][1]) + ", " + ;
            BONUM(aIt[nI][2], 4) + ", " + BONUM(aIt[nI][3], 2) + ", " + BONUM(aIt[nI][4], 2) + ", " + GEBDBQuote(cData) + ")")
    Next nI
    If cModo == "VALE"
        cVale := "VT" + BOSEQ("LOJ_VALE", 8)
        cCred := "2.01.003"
        TCSqlExec("INSERT INTO GLJF (D_E_L_E_T_, GLJF_FILIAL, GLJF_VALE, GLJF_CLI, GLJF_VALOR, GLJF_SALDO, GLJF_DATA, GLJF_ORIGEM, GLJF_STATUS) VALUES (' ', " + ;
            GEBDBQuote(FWxFilial("GLJF")) + ", " + GEBDBQuote(cVale) + ", " + GEBDBQuote(BOCOL(aC[1]:CL)) + ", " + BONUM(nTotV, 2) + ", " + BONUM(nTotV, 2) + ", " + ;
            GEBDBQuote(cData) + ", " + GEBDBQuote(cDev + " " + cCupom) + ", 'ABERTO')")
    Else
        cCred := GEBCTXFIN(aCx[2])
        GEBFXMOVCONTA(aCx[2], "D", nTotV, "Devolucao " + cDev + " " + cCupom + " " + BOCOL(cMotivo), cDev, cData)
    EndIf
    For nI := 1 To Len(aIt)
        TCSqlExec("INSERT INTO GLJH (D_E_L_E_T_, GLJH_FILIAL, GLJH_DEV, GLJH_CUPOM, GLJH_SESSAO, GLJH_PROD, GLJH_QTD, GLJH_VALOR, GLJH_CUSTO, GLJH_DATA, GLJH_MODO, GLJH_VALE) VALUES (' ', " + ;
            GEBDBQuote(FWxFilial("GLJH")) + ", " + GEBDBQuote(cDev) + ", " + GEBDBQuote(cCupom) + ", " + GEBDBQuote(cSessao) + ", " + GEBDBQuote(aIt[nI][1]) + ", " + ;
            BONUM(aIt[nI][2], 4) + ", " + BONUM(aIt[nI][3], 2) + ", " + BONUM(aIt[nI][4], 2) + ", " + GEBDBQuote(cData) + ", " + GEBDBQuote(cModo) + ", " + GEBDBQuote(cVale) + ")")
    Next nI
    GEBCTXLP("DEVOL_VENDA", nTotV, cDev + " " + cCupom, cData, "", cCred, aCx[4])
    GEBCTXLP("DEVOL_CMV", Round(nTotC, 2), cDev + " " + cCupom, cData, "", "", aCx[4])
    If cModo == "VALE"
        Return {.T., "devolucao " + cDev + ": vale-troca " + cVale + " de " + BONUM(nTotV, 2) + LOJTxtNFe(cChNFe), {cDev, nTotV, Round(nTotC, 2), cVale, cChNFe}}
    EndIf
Return {.T., "devolucao " + cDev + ": devolver " + BONUM(nTotV, 2) + " em dinheiro" + LOJTxtNFe(cChNFe), {cDev, nTotV, Round(nTotC, 2), "", cChNFe}}

Static Function LOJTxtNFe(cCh)
    If cCh == ""
        Return ""
    EndIf
Return " (NF-e de devolucao " + cCh + ")"

/*/{Protheus.doc} GEBLOJVALE
    Consulta o vale-troca.
    @type Consulta frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {{campo, valor}...}}
/*/
User Function GEBLOJVALE(cVale)
    Local aHit := {}
    cVale := Upper(BOCOL(cVale))
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GLJF_CLI AS C, GLJF_VALOR AS V, GLJF_SALDO AS S, GLJF_DATA AS D, GLJF_ORIGEM AS O, GLJF_STATUS AS ST FROM GLJF " + ;
        "WHERE GLJF_FILIAL = " + GEBDBQuote(FWxFilial("GLJF")) + " AND GLJF_VALE = " + GEBDBQuote(cVale) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {.F., "vale_inexistente: " + cVale, {}}
    EndIf
Return {.T., "vale " + cVale, {{"cliente", BOCOL(aHit[1]:C)}, {"valor", BOVAL(aHit[1]:V)}, {"saldo", BOVAL(aHit[1]:S)}, {"emissao", BOCOL(aHit[1]:D)}, ;
    {"origem", BOCOL(aHit[1]:O)}, {"status", BOCOL(aHit[1]:ST)}}}

/*/{Protheus.doc} GEBLOJCUPOM
    Segunda via do cupom em texto (uma linha por elemento; tambem na grade).
    @type Relatorio
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, aLinhas}
/*/
User Function GEBLOJCUPOM(cCupom)
    Local aC := {}
    Local aB := {}
    Local aHit := {}
    Local aTxt := {}
    Local aRel := {{"cupom"}}
    Local aDfe := {}
    Local nTroco := 0
    Local nI := 0
    cCupom := Upper(BOCOL(cCupom))
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aC := TCSqlQuery("SELECT GLJ3_SESSAO AS S, GLJ3_DATA AS D, GLJ3_CLI AS C, GLJ3_BRUTO AS B, GLJ3_DESC AS DE, GLJ3_TOTAL AS T, GLJ3_STATUS AS ST, " + ;
        "GLJ3_NOTA AS N FROM GLJ3 WHERE GLJ3_FILIAL = " + GEBDBQuote(FWxFilial("GLJ3")) + " AND GLJ3_CUPOM = " + GEBDBQuote(cCupom) + " AND D_E_L_E_T_ = ' '")
    If Len(aC) == 0
        Return {.F., "cupom_inexistente: " + cCupom, {}}
    EndIf
    aB := TCSqlQuery("SELECT GLJB_VEND AS V, GLJB_CPF AS CPF, GLJB_ORC AS O, GLJB_HORA AS H FROM GLJB WHERE GLJB_FILIAL = " + GEBDBQuote(FWxFilial("GLJB")) + ;
        " AND GLJB_CUPOM = " + GEBDBQuote(cCupom) + " AND D_E_L_E_T_ = ' '")
    aAdd(aTxt, "SEGUNDA VIA - CUPOM " + cCupom)
    aAdd(aTxt, "Data " + BOCOL(aC[1]:D) + "  Sessao " + BOCOL(aC[1]:S) + "  NFC-e " + BOCOL(aC[1]:N))
    If Len(aB) > 0
        If !(BOCOL(aB[1]:H) == "")
            aAdd(aTxt, "Hora " + BOCOL(aB[1]:H))
        EndIf
        If !(BOCOL(aB[1]:CPF) == "")
            aAdd(aTxt, "CPF/CNPJ do consumidor: " + BOCOL(aB[1]:CPF))
        EndIf
        If !(BOCOL(aB[1]:V) == "")
            aAdd(aTxt, "Vendedor: " + BOCOL(aB[1]:V))
        EndIf
        If !(BOCOL(aB[1]:O) == "")
            aAdd(aTxt, "Orcamento: " + BOCOL(aB[1]:O))
        EndIf
    EndIf
    If !(BOCOL(aC[1]:C) == "")
        aAdd(aTxt, "Cliente: " + BOCOL(aC[1]:C))
    EndIf
    aHit := TCSqlQuery("SELECT GLJ4_PROD AS P, COALESCE(GF1_DESC, '') AS DS, GLJ4_QTD AS Q, GLJ4_PRECO AS PR, GLJ4_VALOR AS V FROM GLJ4 LEFT JOIN GF1 ON GF1_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GF1")) + " AND GF1_COD = GLJ4_PROD AND GF1.D_E_L_E_T_ = ' ' WHERE GLJ4_FILIAL = " + GEBDBQuote(FWxFilial("GLJ4")) + ;
        " AND GLJ4_CUPOM = " + GEBDBQuote(cCupom) + " AND GLJ4.D_E_L_E_T_ = ' ' ORDER BY GLJ4.R_E_C_N_O_")
    For nI := 1 To Len(aHit)
        aAdd(aTxt, BOCOL(aHit[nI]:P) + " " + BOCOL(aHit[nI]:DS) + "  " + BONUM(BOVAL(aHit[nI]:Q), 3) + " x " + BONUM(BOVAL(aHit[nI]:PR), 2) + ;
            " = " + BONUM(BOVAL(aHit[nI]:V), 2))
    Next nI
    aHit := TCSqlQuery("SELECT GLJA_PROD AS P, GLJA_PROMO AS PM, GLJA_DESC AS D FROM GLJA WHERE GLJA_FILIAL = " + GEBDBQuote(FWxFilial("GLJA")) + ;
        " AND GLJA_CUPOM = " + GEBDBQuote(cCupom) + " AND D_E_L_E_T_ = ' '")
    For nI := 1 To Len(aHit)
        aAdd(aTxt, "  promocao " + BOCOL(aHit[nI]:PM) + " em " + BOCOL(aHit[nI]:P) + ": -" + BONUM(BOVAL(aHit[nI]:D), 2))
    Next nI
    aAdd(aTxt, "Bruto " + BONUM(BOVAL(aC[1]:B), 2) + "  Desconto " + BONUM(BOVAL(aC[1]:DE), 2) + "  TOTAL " + BONUM(BOVAL(aC[1]:T), 2))
    aHit := TCSqlQuery("SELECT GLJ5_FORMA AS F, GLJ5_VALOR AS V, GLJ5_TROCO AS T, GLJ5_PARC AS PC, GLJ5_DOC AS D FROM GLJ5 WHERE GLJ5_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GLJ5")) + " AND GLJ5_CUPOM = " + GEBDBQuote(cCupom) + " AND D_E_L_E_T_ = ' ' ORDER BY R_E_C_N_O_")
    For nI := 1 To Len(aHit)
        nTroco := nTroco + BOVAL(aHit[nI]:T)
        If BOCOL(aHit[nI]:F) == "DINHEIRO"
            // GLJ5 guarda o dinheiro liquido do troco; o cupom mostra o entregue.
            aAdd(aTxt, "DINHEIRO " + BONUM(BOVAL(aHit[nI]:V) + BOVAL(aHit[nI]:T), 2))
        ElseIf BOVAL(aHit[nI]:PC) > 1
            aAdd(aTxt, BOCOL(aHit[nI]:F) + " " + BONUM(BOVAL(aHit[nI]:V), 2) + " em " + BONUM(BOVAL(aHit[nI]:PC), 0) + "x")
        ElseIf BOCOL(aHit[nI]:F) == "VALE"
            aAdd(aTxt, "VALE " + BOCOL(aHit[nI]:D) + " " + BONUM(BOVAL(aHit[nI]:V), 2))
        Else
            aAdd(aTxt, BOCOL(aHit[nI]:F) + " " + BONUM(BOVAL(aHit[nI]:V), 2))
        EndIf
    Next nI
    aAdd(aTxt, "TROCO " + BONUM(nTroco, 2))
    aHit := TCSqlQuery("SELECT GLJH_DEV AS D, GLJH_PROD AS P, GLJH_QTD AS Q, GLJH_VALOR AS V, GLJH_MODO AS M FROM GLJH WHERE GLJH_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GLJH")) + " AND GLJH_CUPOM = " + GEBDBQuote(cCupom) + " AND D_E_L_E_T_ = ' ' ORDER BY R_E_C_N_O_")
    For nI := 1 To Len(aHit)
        aAdd(aTxt, "Devolucao " + BOCOL(aHit[nI]:D) + ": " + BOCOL(aHit[nI]:P) + " " + BONUM(BOVAL(aHit[nI]:Q), 3) + " = " + BONUM(BOVAL(aHit[nI]:V), 2) + ;
            " (" + BOCOL(aHit[nI]:M) + ")")
    Next nI
    If BOCOL(aC[1]:ST) == "CANCELADO"
        aAdd(aTxt, "*** CUPOM CANCELADO ***")
    EndIf
    // NFC-e real: situacao, chave, protocolo e onde consultar (DANFE completo em loja/danfe).
    aDfe := GEBDFEDOC(BOCOL(aC[1]:N))
    If Len(aDfe) > 0
        aAdd(aTxt, "NFC-e " + aDfe[1] + " - serie " + cValToChar(aDfe[6]) + " numero " + cValToChar(aDfe[7]))
        aAdd(aTxt, "Chave " + BOCOL(aC[1]:N))
        If !(aDfe[2] == "")
            aAdd(aTxt, "Protocolo " + aDfe[2] + " em " + aDfe[4])
        EndIf
        If !(aDfe[13] == "")
            aAdd(aTxt, "Consulte em " + aDfe[13])
        EndIf
    EndIf
    For nI := 1 To Len(aTxt)
        aAdd(aRel, {aTxt[nI]})
    Next nI
    BOREL(aRel)
Return {.T., "cupom " + cCupom, aTxt}

/*/{Protheus.doc} GEBLOJCONS
    Consulta de preco: produto (ou codigo de barras), descricao, preco da
    tabela, promocao vigente e saldo no armazem do caixa (vazio = 01).
    @type Consulta frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {{campo, valor}...}}
/*/
User Function GEBLOJCONS(cCodigo, cCaixa)
    Local aR := {}
    Local aP := {}
    Local aCx := {}
    Local aHit := {}
    Local cLocal := "01"
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aR := GEBLOJRESOLVE(cCodigo, 1, 0)
    If !aR[1]
        Return {.F., aR[2], {}}
    EndIf
    aHit := TCSqlQuery("SELECT GF1_DESC AS D FROM GF1 WHERE GF1_FILIAL = " + GEBDBQuote(FWxFilial("GF1")) + " AND GF1_COD = " + GEBDBQuote(aR[3][1]) + ;
        " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {.F., "produto_inexistente: " + BOCOL(cCodigo), {}}
    EndIf
    If !(BOCOL(cCaixa) == "")
        aCx := GEBLOJCXA(cCaixa)
        If Len(aCx) > 0
            cLocal := aCx[3]
        EndIf
    EndIf
    aP := GEBLOJPRECO(aR[3][1], 1, BOHOJE())
Return {.T., "consulta " + aR[3][1], {{"produto", aR[3][1]}, {"descricao", BOCOL(aHit[1]:D)}, {"preco_tabela", aP[4]}, {"preco_hoje", aP[1]}, ;
    {"promocao", aP[2]}, {"saldo", GEBESTSLD(aR[3][1], cLocal)[1]}, {"leitura", aR[2]}}}

/*/{Protheus.doc} GEBLOJGER
    Relatorio gerencial da loja no periodo, agrupado por DIA (padrao),
    CAIXA, OPERADOR ou VENDEDOR. Devolucoes contam pela data da devolucao
    (DIA) ou pelo caixa/operador/vendedor do cupom de origem.
    @type Relatorio
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {aLinhas (1a = cabecalho), aTotais}}
/*/
User Function GEBLOJGER(cIni, cFim, cAgrupa)
    Local aV := {}
    Local aD := {}
    Local aLin := {{"grupo", "cupons", "cancelados", "vendas", "descontos", "ticket_medio", "devolucoes", "liquido"}}
    Local aRel := {}
    Local aChaves := {}
    Local aVal := {}
    Local cK := ""
    Local cKD := ""
    Local cJoin := ""
    Local nP := 0
    Local nI := 0
    Local aTot := {0, 0, 0, 0, 0}
    cIni := BODATA(cIni)
    cFim := BODATA(cFim)
    cAgrupa := Upper(BOCOL(cAgrupa))
    If cIni == "" .Or. cFim == "" .Or. cFim < cIni
        Return {.F., "periodo_invalido", {}}
    EndIf
    If cAgrupa == ""
        cAgrupa := "DIA"
    EndIf
    If cAgrupa == "DIA"
        cK := "GLJ3_DATA"
        cKD := "GLJH_DATA"
    ElseIf cAgrupa == "CAIXA"
        cK := "GLJ2_CAIXA"
    ElseIf cAgrupa == "OPERADOR"
        cK := "GLJ2_OPER"
    ElseIf cAgrupa == "VENDEDOR"
        cK := "COALESCE(GLJB_VEND, '')"
    Else
        Return {.F., "agrupamento_invalido: DIA, CAIXA, OPERADOR ou VENDEDOR", {}}
    EndIf
    If cKD == ""
        cKD := cK
    EndIf
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    cJoin := " JOIN GLJ2 ON GLJ2_FILIAL = GLJ3_FILIAL AND GLJ2_SESSAO = GLJ3_SESSAO AND GLJ2.D_E_L_E_T_ = ' ' " + ;
        "LEFT JOIN GLJB ON GLJB_FILIAL = GLJ3_FILIAL AND GLJB_CUPOM = GLJ3_CUPOM AND GLJB.D_E_L_E_T_ = ' ' "
    aV := TCSqlQuery("SELECT " + cK + " AS K, SUM(CASE WHEN GLJ3_STATUS = 'VENDIDO' THEN 1 ELSE 0 END) AS N, " + ;
        "SUM(CASE WHEN GLJ3_STATUS = 'CANCELADO' THEN 1 ELSE 0 END) AS C, SUM(CASE WHEN GLJ3_STATUS = 'VENDIDO' THEN GLJ3_TOTAL ELSE 0 END) AS T, " + ;
        "SUM(CASE WHEN GLJ3_STATUS = 'VENDIDO' THEN GLJ3_DESC ELSE 0 END) AS D FROM GLJ3" + cJoin + "WHERE GLJ3_FILIAL = " + GEBDBQuote(FWxFilial("GLJ3")) + ;
        " AND GLJ3.D_E_L_E_T_ = ' ' AND GLJ3_DATA BETWEEN " + GEBDBQuote(cIni) + " AND " + GEBDBQuote(cFim) + " GROUP BY 1 ORDER BY 1")
    aD := TCSqlQuery("SELECT " + cKD + " AS K, SUM(GLJH_VALOR) AS V FROM GLJH JOIN GLJ3 ON GLJ3_FILIAL = GLJH_FILIAL AND GLJ3_CUPOM = GLJH_CUPOM AND GLJ3.D_E_L_E_T_ = ' '" + ;
        cJoin + "WHERE GLJH_FILIAL = " + GEBDBQuote(FWxFilial("GLJH")) + " AND GLJH.D_E_L_E_T_ = ' ' AND GLJH_DATA BETWEEN " + GEBDBQuote(cIni) + ;
        " AND " + GEBDBQuote(cFim) + " GROUP BY 1")
    For nI := 1 To Len(aV)
        aAdd(aChaves, BOCOL(aV[nI]:K))
        aAdd(aVal, {BOVAL(aV[nI]:N), BOVAL(aV[nI]:C), BOVAL(aV[nI]:T), BOVAL(aV[nI]:D), 0})
    Next nI
    For nI := 1 To Len(aD)
        nP := AScan(aChaves, BOCOL(aD[nI]:K))
        If nP == 0
            aAdd(aChaves, BOCOL(aD[nI]:K))
            aAdd(aVal, {0, 0, 0, 0, 0})
            nP := Len(aChaves)
        EndIf
        aVal[nP][5] := BOVAL(aD[nI]:V)
    Next nI
    For nI := 1 To Len(aChaves)
        aAdd(aLin, {aChaves[nI], aVal[nI][1], aVal[nI][2], aVal[nI][3], aVal[nI][4], LOJTicket(aVal[nI][3], aVal[nI][1]), aVal[nI][5], ;
            Round(aVal[nI][3] - aVal[nI][5], 2)})
        For nP := 1 To 5
            aTot[nP] := aTot[nP] + aVal[nI][nP]
        Next nP
    Next nI
    For nI := 1 To Len(aLin)
        aAdd(aRel, aLin[nI])
    Next nI
    aAdd(aRel, {"total", aTot[1], aTot[2], Round(aTot[3], 2), Round(aTot[4], 2), LOJTicket(aTot[3], aTot[1]), Round(aTot[5], 2), Round(aTot[3] - aTot[5], 2)})
    BOREL(aRel)
Return {.T., "gerencial_loja", {aLin, {{"cupons", aTot[1]}, {"cancelados", aTot[2]}, {"vendas", Round(aTot[3], 2)}, {"descontos", Round(aTot[4], 2)}, ;
    {"ticket_medio", LOJTicket(aTot[3], aTot[1])}, {"devolucoes", Round(aTot[5], 2)}, {"liquido", Round(aTot[3] - aTot[5], 2)}}}}

/*/{Protheus.doc} GEBLOJCOMIS
    Relatorio: comissao por vendedor no periodo. Base = vendas (cupons nao
    cancelados) - devolucoes do periodo dos cupons do vendedor.
    @type Relatorio
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {aLinhas (1a = cabecalho), nTotalComissao}}
/*/
User Function GEBLOJCOMIS(cIni, cFim)
    Local aHit := {}
    Local aLin := {{"vendedor", "nome", "vendas", "devolucoes", "base", "percentual", "comissao"}}
    Local aRel := {}
    Local nBase := 0
    Local nCom := 0
    Local nTot := 0
    Local nI := 0
    cIni := BODATA(cIni)
    cFim := BODATA(cFim)
    If cIni == "" .Or. cFim == "" .Or. cFim < cIni
        Return {.F., "periodo_invalido", {}}
    EndIf
    If !GEBLOJMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GLJC_COD AS C, GLJC_NOME AS N, GLJC_COMIS AS P, " + ;
        "(SELECT COALESCE(SUM(GLJ3_TOTAL), 0) FROM GLJ3 JOIN GLJB ON GLJB_FILIAL = GLJ3_FILIAL AND GLJB_CUPOM = GLJ3_CUPOM AND GLJB.D_E_L_E_T_ = ' ' " + ;
        "WHERE GLJ3_FILIAL = GLJC_FILIAL AND GLJB_VEND = GLJC_COD AND GLJ3_STATUS = 'VENDIDO' AND GLJ3.D_E_L_E_T_ = ' ' AND GLJ3_DATA BETWEEN " + ;
        GEBDBQuote(cIni) + " AND " + GEBDBQuote(cFim) + ") AS V, " + ;
        "(SELECT COALESCE(SUM(GLJH_VALOR), 0) FROM GLJH JOIN GLJB ON GLJB_FILIAL = GLJH_FILIAL AND GLJB_CUPOM = GLJH_CUPOM AND GLJB.D_E_L_E_T_ = ' ' " + ;
        "WHERE GLJH_FILIAL = GLJC_FILIAL AND GLJB_VEND = GLJC_COD AND GLJH.D_E_L_E_T_ = ' ' AND GLJH_DATA BETWEEN " + GEBDBQuote(cIni) + " AND " + ;
        GEBDBQuote(cFim) + ") AS D FROM GLJC WHERE GLJC_FILIAL = " + GEBDBQuote(FWxFilial("GLJC")) + " AND D_E_L_E_T_ = ' ' ORDER BY GLJC_COD")
    For nI := 1 To Len(aHit)
        nBase := Round(BOVAL(aHit[nI]:V) - BOVAL(aHit[nI]:D), 2)
        nCom := Round(nBase * BOVAL(aHit[nI]:P) / 100, 2)
        nTot := nTot + nCom
        aAdd(aLin, {BOCOL(aHit[nI]:C), BOCOL(aHit[nI]:N), BOVAL(aHit[nI]:V), BOVAL(aHit[nI]:D), nBase, BOVAL(aHit[nI]:P), nCom})
    Next nI
    For nI := 1 To Len(aLin)
        aAdd(aRel, aLin[nI])
    Next nI
    aAdd(aRel, {"total", "", "", "", "", "", Round(nTot, 2)})
    BOREL(aRel)
Return {.T., "comissao_vendedores", {aLin, Round(nTot, 2)}}

Static Function LOJOrc(cOrc)
Return TCSqlQuery("SELECT GLJD_CLI AS CL, GLJD_VEND AS VE, GLJD_VALID AS VA, GLJD_DESC AS DE, GLJD_STATUS AS ST FROM GLJD WHERE GLJD_FILIAL = " + ;
    GEBDBQuote(FWxFilial("GLJD")) + " AND GLJD_ORC = " + GEBDBQuote(cOrc) + " AND D_E_L_E_T_ = ' '")

Static Function LOJTicket(nValor, nCupons)
    If nCupons <= 0
        Return 0
    EndIf
Return Round(nValor / nCupons, 2)
