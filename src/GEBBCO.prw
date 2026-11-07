#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBCTX.prw"
#include "GEBFNX.prw"

/*/{Protheus.doc} GEBBCO
    Banco: boleto, CNAB 400 e CNAB 240 (remessa/retorno) e conciliacao por
    OFX (inspirado em SEE/SEA/FINA150/FINA200/FINA380 do Protheus).
    - GBC1: dados de cobranca da conta financeira (banco, agencia, conta,
      carteira, codigo do beneficiario/convenio, modalidade, leiaute 400/240).
    - Boleto (GBC2): codigo de barras de 44 posicoes e linha digitavel no
      padrao FEBRABAN (DV geral modulo 11, campos modulo 10, fator de
      vencimento com o reinicio em 1000 a partir de 22/02/2025). Campo livre
      e nosso numero por banco (GEBBCOLIVRE), conferidos com os exemplos dos
      manuais:
      237 Bradesco: agencia(4) + carteira(2) + NN(11) + conta(7) + 0; DV do NN
          modulo 11 base 7 sobre carteira + NN (resto 1 = "P").
      341 Itau (manual de cobranca 01/2017): carteira(3) + NN(8) + DAC + agencia(4)
          + conta(5) + DAC(agencia+conta) + 000; DAC modulo 10 sobre agencia +
          conta + carteira + NN (carteiras 126/131/145/146/150/168: so' carteira + NN).
      033 Santander (manual v36 04/2025): 9 + codigo do beneficiario(7) + NN(12)
          + DV (modulo 11, pesos 2-9, resto 0/1 = 0) + 0 + modalidade(101/104).
      104 Caixa SIGCB (manual oficial): beneficiario(6) + DV + NN 3-5 + 1
          (registrada) + NN 6-8 + 4 (emissao pelo beneficiario) + NN 9-17 + DV
          do campo livre (modulo 11; maior que 9 = 0). NN = 14 + sequencial(15).
      001 Banco do Brasil (convenio de 7): 000000 + convenio(7) + sequencial(10)
          + carteira(2).
      756 Sicoob: carteira(1) + cooperativa(4) + modalidade(2) + cliente(7) +
          NN(7) + DV (pesos 3,1,9,7 sobre cooperativa + cliente(10) + NN; resto
          0/1 = 0) + parcela 001.
    - CNAB 400: Bradesco e Itau. CNAB 240 FEBRABAN (versao 10.3: header de
      arquivo, header de lote, segmentos P e Q na remessa; T e U no retorno;
      trailers) para todos os bancos acima. O nosso numero do segmento P vai
      alinhado a esquerda (posicoes 38-57) e o retorno casa pelo nosso numero
      contido no campo. Liquidacao: 240 = movimento 06/17; Bradesco 400 =
      06/15/17; Itau 400 = 06/07/08. Conferir com o banco antes do primeiro
      arquivo real (cada banco tem particularidades no leiaute FEBRABAN).
    - OFX (GBC3): importa o extrato (sem repetir FITID), concilia sozinho
      com os movimentos da conta (GFX4) de mesmo valor e sentido em ate
      GE4 BCO_DIAS_CONC dias (padrao 3), concilia na mao, ou lanca a linha
      que so' existe no banco (tarifa) como movimento avulso.
    - Relatorio GEBBCOREL: conciliado, pendente no banco e pendente no
      sistema, com os saldos dos dois lados.
    @type Modulo financeiro
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBBCOMIG()
    Local lOk := GEBFXMIG()
    lOk := lOk .And. BOTAB("GBC1", "GBC1_CONTA TEXT NOT NULL, GBC1_BANCO TEXT NOT NULL, GBC1_AGENCIA TEXT NOT NULL, GBC1_AGDV TEXT NOT NULL, " + ;
        "GBC1_CC TEXT NOT NULL, GBC1_CCDV TEXT NOT NULL, GBC1_CARTEIRA TEXT NOT NULL, GBC1_CODEMP TEXT NOT NULL, GBC1_BENEF TEXT NOT NULL, " + ;
        "GBC1_CNPJ TEXT NOT NULL, GBC1_LAYOUT TEXT NOT NULL, GBC1_MODAL TEXT NOT NULL", "GBC1_CONTA")
    lOk := lOk .And. BOTAB("GBC2", "GBC2_DOC TEXT NOT NULL, GBC2_CONTA TEXT NOT NULL, GBC2_NN TEXT NOT NULL, GBC2_NNDV TEXT NOT NULL, " + ;
        "GBC2_NNFULL TEXT NOT NULL, GBC2_VENC TEXT NOT NULL, GBC2_VALOR NUMERIC(18,2) NOT NULL, GBC2_LINHA TEXT NOT NULL, GBC2_BARRAS TEXT NOT NULL, " + ;
        "GBC2_STATUS TEXT NOT NULL, GBC2_REMESSA TEXT NOT NULL", "GBC2_DOC")
    lOk := lOk .And. BOTAB("GBC3", "GBC3_CONTA TEXT NOT NULL, GBC3_FITID TEXT NOT NULL, GBC3_DATA TEXT NOT NULL, GBC3_VALOR NUMERIC(18,2) NOT NULL, " + ;
        "GBC3_MEMO TEXT NOT NULL, GBC3_STATUS TEXT NOT NULL, GBC3_MOVRN INTEGER NOT NULL", "GBC3_FITID")
Return lOk

/*/{Protheus.doc} GEBBCOCFG
    Dados de cobranca de uma conta financeira (GFN1). cCodEmp = codigo do
    beneficiario/convenio no banco (Bradesco: codigo da empresa de 20
    digitos do CNAB; Santander: codigo do beneficiario de 7; Caixa: codigo do
    beneficiario de 6; BB: convenio de 7; Sicoob: codigo do cliente de 7).
    cModal = modalidade (Sicoob, padrao 01). cLayout = 400 (Bradesco e Itau)
    ou 240 (todos).
    @type Cadastro financeiro
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBBCOCFG(cConta, cBanco, cAgencia, cAgDv, cCC, cCCDv, cCarteira, cCodEmp, cBenef, cCnpj, cLayout, cModal)
    Local cFil := FWxFilial("GBC1")
    cConta := BOCOL(cConta)
    cBanco := BOCOL(cBanco)
    cLayout := BOCOL(cLayout)
    cModal := BOCOL(cModal)
    If cBanco == ""
        cBanco := "237"
    EndIf
    If AScan({"001", "033", "104", "237", "341", "756"}, cBanco) == 0
        Return {.F., "banco_nao_suportado: use 001, 033, 104, 237, 341 ou 756"}
    EndIf
    If cLayout == ""
        cLayout := "240"
        If cBanco == "237" .Or. cBanco == "341"
            cLayout := "400"
        EndIf
    EndIf
    If !(cLayout == "240" .Or. cLayout == "400") .Or. (cLayout == "400" .And. !(cBanco == "237" .Or. cBanco == "341"))
        Return {.F., "leiaute_invalido: 240 para todos; 400 so' Bradesco e Itau"}
    EndIf
    If !BCODig(cAgencia, 4) .Or. !(BOCOL(cCC) == "" .Or. BCODig(cCC, 12)) .Or. !BCODig(cCarteira, 3)
        Return {.F., "dados_invalidos: agencia (ate 4 digitos), conta (ate 12), carteira (ate 3)"}
    EndIf
    If (cBanco == "237" .And. Len(BOCOL(cCC)) > 7) .Or. (cBanco == "341" .And. Len(BOCOL(cCC)) > 5)
        Return {.F., "conta_longa_para_o_banco"}
    EndIf
    If (cBanco == "033" .Or. cBanco == "001" .Or. cBanco == "756") .And. !BCODig(cCodEmp, 7)
        Return {.F., "codigo_do_beneficiario_ou_convenio_obrigatorio: ate 7 digitos"}
    EndIf
    If cBanco == "104" .And. !BCODig(cCodEmp, 6)
        Return {.F., "codigo_do_beneficiario_obrigatorio: ate 6 digitos"}
    EndIf
    If cBanco == "756" .And. cModal == ""
        cModal := "01"
    EndIf
    If !GEBBCOMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    If Len(TCSqlQuery("SELECT GFN1_CONTA FROM GFN1 WHERE GFN1_FILIAL = " + GEBDBQuote(FWxFilial("GFN1")) + " AND GFN1_CONTA = " + GEBDBQuote(cConta) + ;
            " AND D_E_L_E_T_ = ' '")) == 0
        Return {.F., "conta_inexistente: " + cConta}
    EndIf
    TCSqlExec("UPDATE GBC1 SET D_E_L_E_T_ = '*' WHERE GBC1_FILIAL = " + GEBDBQuote(cFil) + " AND GBC1_CONTA = " + GEBDBQuote(cConta) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GBC1 (D_E_L_E_T_, GBC1_FILIAL, GBC1_CONTA, GBC1_BANCO, GBC1_AGENCIA, GBC1_AGDV, GBC1_CC, GBC1_CCDV, GBC1_CARTEIRA, GBC1_CODEMP, " + ;
        "GBC1_BENEF, GBC1_CNPJ, GBC1_LAYOUT, GBC1_MODAL) VALUES (' ', " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cConta) + ", " + GEBDBQuote(cBanco) + ", " + ;
        GEBDBQuote(BOCOL(cAgencia)) + ", " + GEBDBQuote(BOCOL(cAgDv)) + ", " + GEBDBQuote(BOCOL(cCC)) + ", " + GEBDBQuote(BOCOL(cCCDv)) + ", " + ;
        GEBDBQuote(BOCOL(cCarteira)) + ", " + GEBDBQuote(BOCOL(cCodEmp)) + ", " + GEBDBQuote(BOCOL(cBenef)) + ", " + GEBDBQuote(BOCOL(cCnpj)) + ", " + ;
        GEBDBQuote(cLayout) + ", " + GEBDBQuote(cModal) + ")")
Return {.T., "cobranca da conta " + cConta + " gravada (banco " + cBanco + ", CNAB " + cLayout + ")"}

/*/{Protheus.doc} GEBBCOBOL
    Gera (ou devolve, se ja existe) o boleto de um titulo a receber aberto.
    @type Operacao financeira
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {cLinhaDigitavel, cCodigoBarras, cNossoNumero, cVenc, nValor}}
/*/
User Function GEBBCOBOL(cDoc, cConta)
    Local aCfg := {}
    Local aT := {}
    Local aHit := {}
    Local aLiv := {}
    Local cSeq := ""
    Local cBar := ""
    Local cLin := ""
    cDoc := BOCOL(cDoc)
    cConta := BOCOL(cConta)
    If !GEBBCOMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GBC2_LINHA AS L, GBC2_BARRAS AS B, GBC2_NNFULL AS N, GBC2_VENC AS V, GBC2_VALOR AS VL FROM GBC2 WHERE GBC2_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GBC2")) + " AND GBC2_DOC = " + GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) > 0
        Return {.T., "boleto ja gerado", {BOCOL(aHit[1]:L), BOCOL(aHit[1]:B), BOCOL(aHit[1]:N), BOCOL(aHit[1]:V), BOVAL(aHit[1]:VL)}}
    EndIf
    aCfg := BCOCfg(cConta)
    If Len(aCfg) == 0
        Return {.F., "conta_sem_cobranca: configure a conta " + cConta, {}}
    EndIf
    aT := TCSqlQuery("SELECT GFN2_SALDO AS S, GFN2_VENC AS V, GFN2_STATUS AS ST FROM GFN2 WHERE GFN2_FILIAL = " + GEBDBQuote(FWxFilial("GFN2")) + ;
        " AND GFN2_DOC = " + GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' '")
    If Len(aT) == 0
        Return {.F., "titulo_inexistente: " + cDoc, {}}
    EndIf
    If !(BOCOL(aT[1]:ST) == "ABERTO") .Or. BOVAL(aT[1]:S) <= 0
        Return {.F., "titulo_nao_esta_aberto: " + cDoc, {}}
    EndIf
    If !BODATAOK(BOCOL(aT[1]:V))
        Return {.F., "titulo_sem_vencimento_valido: " + cDoc, {}}
    EndIf
    cSeq := BOSEQ("BOL_NN_" + cConta, BCOTamNN(aCfg[2]))
    aLiv := GEBBCOLIVRE(aCfg[2], aCfg[3], aCfg[5], aCfg[6], aCfg[9], aCfg[12], cSeq)
    cBar := GEBBCOBARRAS(aCfg[2], BCOFator(BOCOL(aT[1]:V)), BOVAL(aT[1]:S), aLiv[1])
    cLin := GEBBCOLINHA(cBar)
    TCSqlExec("INSERT INTO GBC2 (D_E_L_E_T_, GBC2_FILIAL, GBC2_DOC, GBC2_CONTA, GBC2_NN, GBC2_NNDV, GBC2_NNFULL, GBC2_VENC, GBC2_VALOR, GBC2_LINHA, GBC2_BARRAS, " + ;
        "GBC2_STATUS, GBC2_REMESSA) VALUES (' ', " + GEBDBQuote(FWxFilial("GBC2")) + ", " + GEBDBQuote(cDoc) + ", " + GEBDBQuote(cConta) + ", " + ;
        GEBDBQuote(cSeq) + ", " + GEBDBQuote(aLiv[3]) + ", " + GEBDBQuote(aLiv[2]) + ", " + GEBDBQuote(BOCOL(aT[1]:V)) + ", " + BONUM(aT[1]:S, 2) + ", " + ;
        GEBDBQuote(cLin) + ", " + GEBDBQuote(cBar) + ", 'GERADO', '')")
Return {.T., "boleto gerado", {cLin, cBar, aLiv[2], BOCOL(aT[1]:V), BOVAL(aT[1]:S)}}

/*/{Protheus.doc} GEBBCOLIVRE
    Campo livre (25 posicoes) e nosso numero do banco (calculo puro).
    @type Calculo bancario
    @author Peder Munksgaard
    @since 19/10/2026
    @param cSeq Sequencial do nosso numero (237: 11, 341: 8, 033: 12, 104: 15,
           001: 10, 756: 7 digitos)
    @return {cCampoLivre, cNossoNumeroExibido, cDV}
/*/
User Function GEBBCOLIVRE(cBanco, cAgencia, cConta, cCarteira, cCodEmp, cModal, cSeq)
    Local cAg := StrZero(Val(BOCOL(cAgencia)), 4)
    Local cDV := ""
    Local cDac := ""
    Local cL := ""
    Local cNN := ""
    cBanco := BOCOL(cBanco)
    cSeq := StrZero(Val(BOCOL(cSeq)), BCOTamNN(cBanco))
    If cBanco == "237"
        cDV := GEBBCONNDV(cCarteira, cSeq)
        Return {cAg + StrZero(Val(cCarteira), 2) + cSeq + StrZero(Val(BOCOL(cConta)), 7) + "0", StrZero(Val(cCarteira), 2) + "/" + cSeq + "-" + cDV, cDV}
    EndIf
    If cBanco == "341"
        cL := StrZero(Val(cCarteira), 3)
        If AScan({"126", "131", "145", "146", "150", "168"}, cL) > 0
            cDac := GEBBCOMOD10(cL + cSeq)
        Else
            cDac := GEBBCOMOD10(cAg + StrZero(Val(BOCOL(cConta)), 5) + cL + cSeq)
        EndIf
        Return {cL + cSeq + cDac + cAg + StrZero(Val(BOCOL(cConta)), 5) + GEBBCOMOD10(cAg + StrZero(Val(BOCOL(cConta)), 5)) + "000", cL + "/" + cSeq + "-" + cDac, cDac}
    EndIf
    If cBanco == "033"
        cDV := BCODV11(cSeq, 9, "R01")
        Return {"9" + StrZero(Val(BOCOL(cCodEmp)), 7) + cSeq + cDV + "0" + StrZero(Val(cCarteira), 3), cSeq + "-" + cDV, cDV}
    EndIf
    If cBanco == "104"
        cNN := "14" + cSeq
        cL := StrZero(Val(BOCOL(cCodEmp)), 6)
        cL := cL + BCODV11(cL, 9, "G9") + SubStr(cNN, 3, 3) + Left(cNN, 1) + SubStr(cNN, 6, 3) + SubStr(cNN, 2, 1) + SubStr(cNN, 9, 9)
        Return {cL + BCODV11(cL, 9, "G9"), cNN, ""}
    EndIf
    If cBanco == "001"
        cNN := StrZero(Val(BOCOL(cCodEmp)), 7) + cSeq
        Return {"000000" + cNN + StrZero(Val(cCarteira), 2), cNN, ""}
    EndIf
    If cBanco == "756"
        cDV := BCOSicoobDV(cAg, StrZero(Val(BOCOL(cCodEmp)), 10), cSeq)
        Return {Right(BOCOL(cCarteira), 1) + cAg + StrZero(Val(BOCOL(cModal)), 2) + StrZero(Val(BOCOL(cCodEmp)), 7) + cSeq + cDV + "001", cSeq + "-" + cDV, cDV}
    EndIf
Return {"", "", ""}

/*/{Protheus.doc} GEBBCOBARRAS
    Codigo de barras FEBRABAN: banco(3) + moeda 9 + DV + fator(4) +
    valor(10, centavos) + campo livre(25).
    @type Calculo bancario
    @author Peder Munksgaard
    @since 18/10/2026
    @return Texto de 44 digitos
/*/
User Function GEBBCOBARRAS(cBanco, cFator, nValor, cLivre)
    Local cSem := BOCOL(cBanco) + "9" + cFator + StrZero(Round(BOVAL(nValor) * 100, 0), 10) + cLivre
Return Left(cSem, 4) + GEBBCOMOD11(cSem) + SubStr(cSem, 5)

/*/{Protheus.doc} GEBBCOLINHA
    Linha digitavel (formatada) a partir do codigo de barras.
    @type Calculo bancario
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBBCOLINHA(cBar)
    Local cL := SubStr(cBar, 20, 25)
    Local c1 := Left(cBar, 4) + Left(cL, 5)
    Local c2 := SubStr(cL, 6, 10)
    Local c3 := SubStr(cL, 16, 10)
    c1 := c1 + GEBBCOMOD10(c1)
    c2 := c2 + GEBBCOMOD10(c2)
    c3 := c3 + GEBBCOMOD10(c3)
Return Left(c1, 5) + "." + SubStr(c1, 6) + " " + Left(c2, 5) + "." + SubStr(c2, 6) + " " + Left(c3, 5) + "." + SubStr(c3, 6) + " " + ;
    SubStr(cBar, 5, 1) + " " + SubStr(cBar, 6, 14)

/*/{Protheus.doc} GEBBCOMOD10
    Modulo 10 (pesos 2,1 da direita; produto > 9 soma os digitos).
    @type Funcao auxiliar
    @author Peder Munksgaard
    @since 19/10/2026
    @param cNum
/*/
User Function GEBBCOMOD10(cNum)
    Local nSoma := 0
    Local nPeso := 2
    Local nP := 0
    Local nI := 0
    For nI := Len(cNum) To 1 Step -1
        nP := Val(SubStr(cNum, nI, 1)) * nPeso
        If nP > 9
            nP := nP - 9
        EndIf
        nSoma := nSoma + nP
        nPeso := 3 - nPeso
    Next nI
Return Str(BOMOD(10 - BOMOD(nSoma, 10), 10), 1)

/*/{Protheus.doc} GEBBCOMOD11
    Modulo 11 do codigo de barras (pesos 2 a 9 da direita; 0, 10 e 11 viram 1).
    @type Funcao auxiliar
    @author Peder Munksgaard
    @since 19/10/2026
    @param cNum
/*/
User Function GEBBCOMOD11(cNum)
    Local nSoma := 0
    Local nPeso := 2
    Local nDV := 0
    Local nI := 0
    For nI := Len(cNum) To 1 Step -1
        nSoma := nSoma + Val(SubStr(cNum, nI, 1)) * nPeso
        nPeso := nPeso + 1
        If nPeso > 9
            nPeso := 2
        EndIf
    Next nI
    nDV := 11 - BOMOD(nSoma, 11)
    If nDV == 0 .Or. nDV == 10 .Or. nDV == 11
        nDV := 1
    EndIf
Return Str(nDV, 1)

/*/{Protheus.doc} GEBBCONNDV
    DV do nosso numero Bradesco: modulo 11 base 7 sobre carteira(2) + nosso numero(11).
    @type Funcao auxiliar
    @author Peder Munksgaard
    @since 19/10/2026
    @param cCarteira
    @param cNN
/*/
User Function GEBBCONNDV(cCarteira, cNN)
    Local cNum := StrZero(Val(cCarteira), 2) + cNN
    Local nSoma := 0
    Local nPeso := 2
    Local nResto := 0
    Local nI := 0
    For nI := Len(cNum) To 1 Step -1
        nSoma := nSoma + Val(SubStr(cNum, nI, 1)) * nPeso
        nPeso := nPeso + 1
        If nPeso > 7
            nPeso := 2
        EndIf
    Next nI
    nResto := BOMOD(nSoma, 11)
    If nResto == 0
        Return "0"
    EndIf
    If nResto == 1
        Return "P"
    EndIf
Return Str(11 - nResto, 1)

/*/{Protheus.doc} GEBBCOFATOR
    Fator de vencimento: dias desde 07/10/1997; a partir de 10.000 recomeca em 1.000 (ciclo de 9.000).
    @type Funcao auxiliar
    @author Peder Munksgaard
    @since 19/10/2026
    @param cVenc
/*/
User Function GEBBCOFATOR(cVenc)
Return BCOFator(cVenc)

/*/{Protheus.doc} GEBBCOHTML
    Pagina HTML do boleto (beneficiario, pagador, valores, linha
    digitavel e codigo de barras intercalado 2 de 5 desenhado em barras).
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, cHtml}
/*/
User Function GEBBCOHTML(cDoc)
    Local aHit := {}
    Local aCfg := {}
    Local aPag := {}
    Local cH := ""
    cDoc := BOCOL(cDoc)
    If !GEBBCOMIG()
        Return {.F., "falha_tabelas", ""}
    EndIf
    aHit := TCSqlQuery("SELECT GBC2_CONTA AS C, GBC2_NNFULL AS N, GBC2_VENC AS V, GBC2_VALOR AS VL, GBC2_LINHA AS L, GBC2_BARRAS AS B FROM GBC2 " + ;
        "WHERE GBC2_FILIAL = " + GEBDBQuote(FWxFilial("GBC2")) + " AND GBC2_DOC = " + GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {.F., "boleto_inexistente: " + cDoc, ""}
    EndIf
    aCfg := BCOCfg(BOCOL(aHit[1]:C))
    aPag := TCSqlQuery("SELECT GFN2_CLI AS C FROM GFN2 WHERE GFN2_FILIAL = " + GEBDBQuote(FWxFilial("GFN2")) + " AND GFN2_DOC = " + GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' '")
    cH := '<!doctype html><html><head><meta charset="utf-8"><title>Boleto ' + cDoc + '</title><style>body{font-family:Arial,sans-serif;margin:24px;color:#000;background:#fff}' + ;
        'table{border-collapse:collapse;width:100%}td{border:1px solid #000;padding:4px 6px;font-size:12px;vertical-align:top}.r{font-size:10px;color:#333}' + ;
        '.linha{font-size:18px;font-weight:bold;text-align:right}.cb{display:flex;height:50px;margin-top:12px}.cb span{display:block;height:50px}</style></head><body>'
    cH := cH + '<table><tr><td style="width:20%;font-size:20px;font-weight:bold">' + BCOBancoDV(aCfg[2]) + '</td><td class="linha">' + BOCOL(aHit[1]:L) + '</td></tr></table>'
    cH := cH + '<table><tr><td colspan="3"><span class="r">Beneficiario</span><br>' + BCOEsc(aCfg[7]) + ' ' + BCOEsc(aCfg[8]) + '</td><td><span class="r">Vencimento</span><br>' + ;
        BCODataBR(BOCOL(aHit[1]:V)) + '</td></tr><tr><td><span class="r">Agencia/Codigo beneficiario</span><br>' + aCfg[3] + "/" + aCfg[5] + BCOSufixo(aCfg[10]) + '</td>' + ;
        '<td><span class="r">Nosso numero</span><br>' + BOCOL(aHit[1]:N) + '</td><td><span class="r">Numero do documento</span><br>' + ;
        BCOEsc(cDoc) + '</td><td><span class="r">Valor do documento</span><br>' + BONUM(aHit[1]:VL, 2) + '</td></tr>'
    If Len(aPag) > 0
        cH := cH + '<tr><td colspan="4"><span class="r">Pagador</span><br>' + BCOEsc(BOCOL(aPag[1]:C)) + '</td></tr>'
    EndIf
    cH := cH + '</table><div class="cb">' + BCOI25(BOCOL(aHit[1]:B)) + '</div></body></html>'
Return {.T., "boleto", cH}

/*/{Protheus.doc} GEBBCOREM
    Remessa CNAB dos boletos GERADO da conta, no leiaute da conta (400
    Bradesco/Itau ou 240 FEBRABAN). Grava o arquivo em cArquivo se
    informado. Os boletos passam a REMETIDO.
    @type Operacao financeira
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {cNumeroRemessa, nBoletos, cConteudo}}
/*/
User Function GEBBCOREM(cConta, cArquivo)
    Local aCfg := {}
    Local aHit := {}
    Local cNum := ""
    Local cTxt := ""
    Local nI := 0
    cConta := BOCOL(cConta)
    If !GEBBCOMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aCfg := BCOCfg(cConta)
    If Len(aCfg) == 0
        Return {.F., "conta_sem_cobranca: " + cConta, {}}
    EndIf
    aHit := TCSqlQuery("SELECT GBC2_DOC AS DOC, GBC2_NN AS N, GBC2_NNDV AS D, GBC2_NNFULL AS F, GBC2_VENC AS V, GBC2_VALOR AS VL FROM GBC2 WHERE GBC2_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GBC2")) + " AND GBC2_CONTA = " + GEBDBQuote(cConta) + " AND GBC2_STATUS = 'GERADO' AND D_E_L_E_T_ = ' ' ORDER BY R_E_C_N_O_")
    If Len(aHit) == 0
        Return {.F., "sem_boletos_novos", {}}
    EndIf
    cNum := BOSEQ("CNAB_REM_" + cConta, 7)
    If aCfg[11] == "240"
        cTxt := BCORem240(aCfg, aHit, cNum)
    ElseIf aCfg[2] == "341"
        cTxt := BCORemItau(aCfg, aHit)
    Else
        cTxt := BCORemBradesco(aCfg, aHit, cNum)
    EndIf
    For nI := 1 To Len(aHit)
        TCSqlExec("UPDATE GBC2 SET GBC2_STATUS = 'REMETIDO', GBC2_REMESSA = " + GEBDBQuote(cNum) + " WHERE GBC2_FILIAL = " + GEBDBQuote(FWxFilial("GBC2")) + ;
            " AND GBC2_DOC = " + GEBDBQuote(BOCOL(aHit[nI]:DOC)) + " AND D_E_L_E_T_ = ' '")
    Next nI
    If !(BOCOL(cArquivo) == "")
        MemoWrite(BOCOL(cArquivo), cTxt)
    EndIf
Return {.T., "remessa " + cNum + " (CNAB " + aCfg[11] + ") com " + BONUM(Len(aHit), 0) + " boleto(s)", {cNum, Len(aHit), cTxt}}

/*/{Protheus.doc} GEBBCORET
    Le o retorno CNAB da conta (400 Bradesco/Itau ou 240 FEBRABAN) e baixa
    os titulos liquidados: principal = valor pago - juros + desconto
    (limitado ao saldo), com juros e desconto do arquivo.
    @type Operacao financeira
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, aLinhas {nosso numero, documento, ocorrencia, resultado}}
/*/
User Function GEBBCORET(cConta, cConteudo)
    Local aCfg := {}
    Local aEv := {}
    Local aRes := {}
    Local aHit := {}
    Local aB := {}
    Local aLiq := {}
    Local cDoc := ""
    Local nPrinc := 0
    Local nOk := 0
    Local nI := 0
    cConta := BOCOL(cConta)
    If !GEBBCOMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aCfg := BCOCfg(cConta)
    If Len(aCfg) == 0
        Return {.F., "conta_sem_cobranca: " + cConta, {}}
    EndIf
    // Eventos {nosso numero no arquivo, ocorrencia, data AAAAMMDD, pago, juros, desconto}.
    If aCfg[11] == "240"
        aEv := BCORet240(BOSTR(cConteudo))
        aLiq := {"06", "17"}
    ElseIf aCfg[2] == "341"
        aEv := BCORet400(BOSTR(cConteudo), 63, 8)
        aLiq := {"06", "07", "08"}
    Else
        aEv := BCORet400(BOSTR(cConteudo), 71, 11)
        aLiq := {"06", "15", "17"}
    EndIf
    For nI := 1 To Len(aEv)
        aHit := BCOAchaNN(cConta, aEv[nI][1])
        If Len(aHit) == 0
            aAdd(aRes, {aEv[nI][1], "", aEv[nI][2], "nosso numero desconhecido"})
            Loop
        EndIf
        cDoc := aHit[1]
        If AScan(aLiq, aEv[nI][2]) == 0
            aAdd(aRes, {aEv[nI][1], cDoc, aEv[nI][2], "ocorrencia sem baixa (" + BCOOcorr(aEv[nI][2]) + ")"})
            Loop
        EndIf
        If aHit[2] == "LIQUIDADO"
            aAdd(aRes, {aEv[nI][1], cDoc, aEv[nI][2], "ja liquidado"})
            Loop
        EndIf
        nPrinc := Round(aEv[nI][4] - aEv[nI][5] + aEv[nI][6], 2)
        aB := GEBFXCALC("R", cDoc, aEv[nI][3])
        If aB[1] .And. nPrinc > aB[3][1]
            nPrinc := aB[3][1]
        EndIf
        aB := GEBFXBAI("R", cDoc, nPrinc, aEv[nI][5], 0, aEv[nI][6], cConta, aEv[nI][3])
        If aB[1]
            nOk := nOk + 1
            TCSqlExec("UPDATE GBC2 SET GBC2_STATUS = 'LIQUIDADO' WHERE GBC2_FILIAL = " + GEBDBQuote(FWxFilial("GBC2")) + " AND GBC2_DOC = " + ;
                GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' '")
            aAdd(aRes, {aEv[nI][1], cDoc, aEv[nI][2], "baixado " + BONUM(aB[3][2], 2)})
        Else
            aAdd(aRes, {aEv[nI][1], cDoc, aEv[nI][2], "recusado: " + aB[2]})
        EndIf
    Next nI
Return {.T., BONUM(nOk, 0) + " titulo(s) baixado(s)", aRes}

// Remessa CNAB 400 Bradesco.
Static Function BCORemBradesco(aCfg, aHit, cNum)
    Local aCli := {}
    Local cTxt := ""
    Local cLin := ""
    Local cDoc := ""
    Local nSeq := 1
    Local nI := 0
    cLin := "0" + "1" + "REMESSA" + "01" + BCOAlf("COBRANCA", 15) + BCONum(aCfg[9], 20) + BCOAlf(aCfg[7], 30) + "237" + BCOAlf("BRADESCO", 15) + ;
        BCODDMMAA(BOHOJE()) + Space(8) + "MX" + cNum + Space(277) + StrZero(nSeq, 6)
    cTxt := cLin + Chr(13) + Chr(10)
    For nI := 1 To Len(aHit)
        nSeq := nSeq + 1
        cDoc := BOCOL(aHit[nI]:DOC)
        aCli := BCOPagador(cDoc)
        cLin := "1" + Replicate("0", 5) + "0" + Replicate("0", 5) + Replicate("0", 7) + "0" + ;
            "0" + StrZero(Val(aCfg[6]), 3) + StrZero(Val(aCfg[3]), 5) + StrZero(Val(aCfg[5]), 7) + BCONum(aCfg[10], 1) + ;
            BCOAlf(cDoc, 25) + "000" + "2" + StrZero(Round(BOVAL(BOPARM("FIN_MULTA", "2")) * 100, 0), 4) + ;
            BOCOL(aHit[nI]:N) + BOCOL(aHit[nI]:D) + Replicate("0", 10) + "2" + "N" + Space(10) + " " + "2" + Space(2) + "01" + ;
            BCOAlf(cDoc, 10) + BCODDMMAA(BOCOL(aHit[nI]:V)) + StrZero(Round(BOVAL(aHit[nI]:VL) * 100, 0), 13) + "000" + "00000" + "01" + "N" + ;
            BCODDMMAA(BOHOJE()) + "00" + "00" + BCOJurosDia(aHit[nI]:VL, 13) + ;
            Replicate("0", 6) + Replicate("0", 13) + Replicate("0", 13) + Replicate("0", 13) + BCOTpInsc(aCli[2]) + BCONum(aCli[2], 14) + BCOAlf(aCli[1], 40) + ;
            Space(40) + Space(12) + Replicate("0", 8) + Space(60) + StrZero(nSeq, 6)
        cTxt := cTxt + cLin + Chr(13) + Chr(10)
    Next nI
    nSeq := nSeq + 1
Return cTxt + "9" + Space(393) + StrZero(nSeq, 6) + Chr(13) + Chr(10)

// Remessa CNAB 400 Itau (manual "Cobranca CNAB 400", 01/2017).
Static Function BCORemItau(aCfg, aHit)
    Local aCli := {}
    Local cAg := StrZero(Val(aCfg[3]), 4)
    Local cCc := StrZero(Val(aCfg[5]), 5)
    Local cDacCC := GEBBCOMOD10(cAg + cCc)
    Local cTxt := ""
    Local cLin := ""
    Local cDoc := ""
    Local nSeq := 1
    Local nI := 0
    cLin := "0" + "1" + "REMESSA" + "01" + BCOAlf("COBRANCA", 15) + cAg + "00" + cCc + cDacCC + Space(8) + BCOAlf(aCfg[7], 30) + "341" + ;
        BCOAlf("BANCO ITAU SA", 15) + BCODDMMAA(BOHOJE()) + Space(294) + StrZero(nSeq, 6)
    cTxt := cLin + Chr(13) + Chr(10)
    For nI := 1 To Len(aHit)
        nSeq := nSeq + 1
        cDoc := BOCOL(aHit[nI]:DOC)
        aCli := BCOPagador(cDoc)
        cLin := "1" + "02" + BCONum(aCfg[8], 14) + cAg + "00" + cCc + cDacCC + Space(4) + "0000" + BCOAlf(cDoc, 25) + BOCOL(aHit[nI]:N) + ;
            Replicate("0", 13) + StrZero(Val(aCfg[6]), 3) + Space(21) + "I" + "01" + BCOAlf(cDoc, 10) + BCODDMMAA(BOCOL(aHit[nI]:V)) + ;
            StrZero(Round(BOVAL(aHit[nI]:VL) * 100, 0), 13) + "341" + "00000" + "01" + "N" + BCODDMMAA(BOHOJE()) + "00" + "00" + BCOJurosDia(aHit[nI]:VL, 13) + ;
            "000000" + Replicate("0", 13) + Replicate("0", 13) + Replicate("0", 13) + BCOTpInsc(aCli[2]) + BCONum(aCli[2], 14) + BCOAlf(aCli[1], 30) + ;
            Space(10) + Space(40) + Space(12) + Replicate("0", 8) + Space(15) + Space(2) + Space(30) + Space(4) + "000000" + "00" + " " + StrZero(nSeq, 6)
        cTxt := cTxt + cLin + Chr(13) + Chr(10)
    Next nI
    nSeq := nSeq + 1
Return cTxt + "9" + Space(393) + StrZero(nSeq, 6) + Chr(13) + Chr(10)

// Remessa CNAB 240 FEBRABAN (v10.3): header de arquivo, header de lote, P + Q por boleto, trailers.
Static Function BCORem240(aCfg, aHit, cNum)
    Local aCli := {}
    Local cB := aCfg[2]
    Local cEmp := "2" + BCONum(aCfg[8], 14)
    Local cConv := BCOAlf(aCfg[9], 20)
    Local cAgCc := StrZero(Val(aCfg[3]), 5) + BCOAlf(aCfg[4], 1) + StrZero(Val(aCfg[5]), 12) + BCOAlf(aCfg[10], 1) + " "
    Local cHoje := BCODDMMAAAA(BOHOJE())
    Local cTxt := ""
    Local cDoc := ""
    Local nTot := 0
    Local nReg := 0
    Local nI := 0
    // Header de arquivo (registro 0).
    cTxt := cB + "0000" + "0" + Space(9) + cEmp + cConv + cAgCc + BCOAlf(aCfg[7], 30) + BCOAlf(BCONomeBanco(cB), 30) + Space(10) + "1" + cHoje + ;
        StrTran(Time(), ":", "") + StrZero(Val(cNum), 6) + "103" + "00000" + Space(20) + Space(20) + Space(29) + Chr(13) + Chr(10)
    // Header de lote (registro 1): operacao R (remessa), servico 01 (cobranca), leiaute do lote 060.
    cTxt := cTxt + cB + "0001" + "1" + "R" + "01" + Space(2) + "060" + " " + "2" + "0" + BCONum(aCfg[8], 14) + cConv + cAgCc + BCOAlf(aCfg[7], 30) + ;
        Space(40) + Space(40) + StrZero(Val(cNum), 8) + cHoje + Replicate("0", 8) + Space(33) + Chr(13) + Chr(10)
    For nI := 1 To Len(aHit)
        cDoc := BOCOL(aHit[nI]:DOC)
        aCli := BCOPagador(cDoc)
        nTot := nTot + BOVAL(aHit[nI]:VL)
        nReg := nReg + 1
        // Segmento P.
        cTxt := cTxt + cB + "0001" + "3" + StrZero(nReg, 5) + "P" + " " + "01" + cAgCc + BCOAlf(BCOSoDig(BOCOL(aHit[nI]:F)), 20) + "1" + "1" + "1" + "2" + "2" + ;
            BCOAlf(cDoc, 15) + BCODDMMAAAA(BOCOL(aHit[nI]:V)) + StrZero(Round(BOVAL(aHit[nI]:VL) * 100, 0), 15) + "00000" + " " + "02" + "N" + cHoje + ;
            "1" + BCODDMMAAAA(BODTADD(BOCOL(aHit[nI]:V), 1)) + BCOJurosDia(aHit[nI]:VL, 15) + "0" + Replicate("0", 8) + Replicate("0", 15) + ;
            Replicate("0", 15) + Replicate("0", 15) + BCOAlf(cDoc, 25) + "3" + "00" + "1" + "060" + "09" + Replicate("0", 10) + " " + Chr(13) + Chr(10)
        nReg := nReg + 1
        // Segmento Q.
        cTxt := cTxt + cB + "0001" + "3" + StrZero(nReg, 5) + "Q" + " " + "01" + Right(BCOTpInsc(aCli[2]), 1) + BCONum(aCli[2], 15) + BCOAlf(aCli[1], 40) + ;
            Space(40) + Space(15) + "00000" + "000" + Space(15) + Space(2) + "0" + Replicate("0", 15) + Space(40) + "000" + Space(20) + Space(8) + Chr(13) + Chr(10)
    Next nI
    // Trailer de lote (registro 5) e de arquivo (registro 9).
    cTxt := cTxt + cB + "0001" + "5" + Space(9) + StrZero(nReg + 2, 6) + StrZero(Len(aHit), 6) + StrZero(Round(nTot * 100, 0), 17) + ;
        Replicate("0", 69) + Space(8) + Space(117) + Chr(13) + Chr(10)
Return cTxt + cB + "9999" + "9" + Space(9) + "000001" + StrZero(nReg + 4, 6) + "000000" + Space(205) + Chr(13) + Chr(10)

// Retorno CNAB 400: {nosso numero, ocorrencia, data, pago, juros, desconto} (pago em 254, juros em 267, desconto em 241).
Static Function BCORet400(cTxt, nPosNN, nTamNN)
    Local aLin := StrTokArr(StrTran(cTxt, Chr(13), ""), Chr(10))
    Local aEv := {}
    Local cL := ""
    Local nI := 0
    For nI := 1 To Len(aLin)
        cL := aLin[nI]
        If Left(cL, 1) == "1" .And. Len(cL) >= 300
            aAdd(aEv, {SubStr(cL, nPosNN, nTamNN), SubStr(cL, 109, 2), BCODe6(SubStr(cL, 111, 6)), Val(SubStr(cL, 254, 13)) / 100, ;
                Val(SubStr(cL, 267, 13)) / 100, Val(SubStr(cL, 241, 13)) / 100})
        EndIf
    Next nI
Return aEv

// Retorno CNAB 240: cada segmento T (nosso numero 38-57, movimento 16-17) com o U seguinte
// (juros 18-32, desconto 33-47, pago 78-92, data da ocorrencia 138-145 DDMMAAAA).
Static Function BCORet240(cTxt)
    Local aLin := StrTokArr(StrTran(cTxt, Chr(13), ""), Chr(10))
    Local aEv := {}
    Local cL := ""
    Local cNN := ""
    Local cOc := ""
    Local nI := 0
    For nI := 1 To Len(aLin)
        cL := aLin[nI]
        If Len(cL) >= 240 .And. SubStr(cL, 8, 1) == "3"
            If SubStr(cL, 14, 1) == "T"
                cNN := AllTrim(SubStr(cL, 38, 20))
                cOc := SubStr(cL, 16, 2)
            ElseIf SubStr(cL, 14, 1) == "U" .And. !(cNN == "")
                aAdd(aEv, {cNN, cOc, Right(SubStr(cL, 138, 8), 4) + SubStr(cL, 140, 2) + Left(SubStr(cL, 138, 8), 2), Val(SubStr(cL, 78, 15)) / 100, ;
                    Val(SubStr(cL, 18, 15)) / 100, Val(SubStr(cL, 33, 15)) / 100})
                cNN := ""
            EndIf
        EndIf
    Next nI
Return aEv

// Boleto da conta pelo nosso numero do arquivo: {cDoc, cStatus}; {} se nao acha.
// Casa pelo sequencial (com ou sem DV) ou pelo nosso numero completo contido no campo.
Static Function BCOAchaNN(cConta, cCampo)
    Local cDig := BCOSoDig(cCampo)
    Local aHit := TCSqlQuery("SELECT GBC2_DOC AS D, GBC2_STATUS AS S, GBC2_NN AS N, GBC2_NNDV AS V, GBC2_NNFULL AS F FROM GBC2 WHERE GBC2_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GBC2")) + " AND GBC2_CONTA = " + GEBDBQuote(cConta) + " AND D_E_L_E_T_ = ' '")
    Local cFull := ""
    Local nI := 0
    For nI := 1 To Len(aHit)
        cFull := BCOSoDig(BOCOL(aHit[nI]:F))
        If cDig == BOCOL(aHit[nI]:N) .Or. cDig == BOCOL(aHit[nI]:N) + BCOSoDig(BOCOL(aHit[nI]:V)) .Or. (Len(cFull) >= 8 .And. cFull $ cDig)
            Return {BOCOL(aHit[nI]:D), BOCOL(aHit[nI]:S)}
        EndIf
    Next nI
Return {}

/*/{Protheus.doc} GEBBCOOFX
    Importa extrato OFX da conta (sem repetir FITID) e concilia sozinho.
    @type Operacao financeira
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {nImportadas, nRepetidas, nConciliadas}}
/*/
User Function GEBBCOOFX(cConta, cConteudo)
    Local cTxt := BOSTR(cConteudo)
    Local cBloco := ""
    Local cFit := ""
    Local cData := ""
    Local nIni := 0
    Local nFim := 0
    Local nImp := 0
    Local nRep := 0
    Local nVal := 0
    Local aC := {}
    cConta := BOCOL(cConta)
    If !GEBBCOMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    If Len(TCSqlQuery("SELECT GFN1_CONTA FROM GFN1 WHERE GFN1_FILIAL = " + GEBDBQuote(FWxFilial("GFN1")) + " AND GFN1_CONTA = " + GEBDBQuote(cConta) + ;
            " AND D_E_L_E_T_ = ' '")) == 0
        Return {.F., "conta_inexistente: " + cConta, {}}
    EndIf
    If !("<STMTTRN>" $ Upper(cTxt))
        Return {.F., "arquivo_sem_lancamentos_ofx", {}}
    EndIf
    nIni := At("<STMTTRN>", Upper(cTxt))
    Do While nIni > 0
        cTxt := SubStr(cTxt, nIni + 9)
        nFim := At("</STMTTRN>", Upper(cTxt))
        If nFim == 0
            nFim := At("<STMTTRN>", Upper(cTxt))
        EndIf
        If nFim == 0
            cBloco := cTxt
        Else
            cBloco := Left(cTxt, nFim - 1)
        EndIf
        cFit := BCOTag(cBloco, "FITID")
        cData := Left(BCOTag(cBloco, "DTPOSTED"), 8)
        nVal := Val(StrTran(BCOTag(cBloco, "TRNAMT"), ",", "."))
        If cFit == "" .Or. !BODATAOK(cData) .Or. nVal == 0
            nRep := nRep + 1
        ElseIf Len(TCSqlQuery("SELECT GBC3_FITID FROM GBC3 WHERE GBC3_FILIAL = " + GEBDBQuote(FWxFilial("GBC3")) + " AND GBC3_CONTA = " + GEBDBQuote(cConta) + ;
                " AND GBC3_FITID = " + GEBDBQuote(cFit) + " AND D_E_L_E_T_ = ' '")) > 0
            nRep := nRep + 1
        Else
            TCSqlExec("INSERT INTO GBC3 (D_E_L_E_T_, GBC3_FILIAL, GBC3_CONTA, GBC3_FITID, GBC3_DATA, GBC3_VALOR, GBC3_MEMO, GBC3_STATUS, GBC3_MOVRN) VALUES (' ', " + ;
                GEBDBQuote(FWxFilial("GBC3")) + ", " + GEBDBQuote(cConta) + ", " + GEBDBQuote(cFit) + ", " + GEBDBQuote(cData) + ", " + BONUM(nVal, 2) + ", " + ;
                GEBDBQuote(Left(BCOTag(cBloco, "MEMO"), 120)) + ", 'PENDENTE', 0)")
            nImp := nImp + 1
        EndIf
        nIni := At("<STMTTRN>", Upper(cTxt))
    EndDo
    aC := GEBBCOCONC(cConta)
Return {.T., BONUM(nImp, 0) + " lancamento(s) importado(s), " + BONUM(aC[3], 0) + " conciliado(s)", {nImp, nRep, aC[3]}}

/*/{Protheus.doc} GEBBCOCONC
    Conciliacao automatica: cada linha pendente do extrato com um movimento
    da conta (GFX4) ainda nao conciliado, de mesmo valor e sentido, com data
    ate GE4 BCO_DIAS_CONC dias de diferenca (o mais proximo).
    @type Operacao financeira
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, nConciliadas}
/*/
User Function GEBBCOCONC(cConta)
    Local aExt := {}
    Local aMov := {}
    Local cDC := ""
    Local nDias := Int(BOVAL(BOPARM("BCO_DIAS_CONC", "3")))
    Local nOk := 0
    Local nI := 0
    cConta := BOCOL(cConta)
    If !GEBBCOMIG()
        Return {.F., "falha_tabelas", 0}
    EndIf
    aExt := TCSqlQuery("SELECT GBC3_FITID AS F, GBC3_DATA AS D, GBC3_VALOR AS V FROM GBC3 WHERE GBC3_FILIAL = " + GEBDBQuote(FWxFilial("GBC3")) + ;
        " AND GBC3_CONTA = " + GEBDBQuote(cConta) + " AND GBC3_STATUS = 'PENDENTE' AND D_E_L_E_T_ = ' ' ORDER BY GBC3_DATA, R_E_C_N_O_")
    For nI := 1 To Len(aExt)
        cDC := "C"
        If BOVAL(aExt[nI]:V) < 0
            cDC := "D"
        EndIf
        aMov := TCSqlQuery("SELECT R_E_C_N_O_ AS RN FROM GFX4 WHERE GFX4_FILIAL = " + GEBDBQuote(FWxFilial("GFX4")) + " AND GFX4_CONTA = " + GEBDBQuote(cConta) + ;
            " AND D_E_L_E_T_ = ' ' AND GFX4_DC = " + GEBDBQuote(cDC) + " AND GFX4_VALOR = " + BONUM(Abs(BOVAL(aExt[nI]:V)), 2) + ;
            " AND R_E_C_N_O_ NOT IN (SELECT GBC3_MOVRN FROM GBC3 WHERE GBC3_FILIAL = GFX4_FILIAL AND GBC3_STATUS = 'CONCILIADO' AND GBC3.D_E_L_E_T_ = ' ') " + ;
            "AND ABS(TO_DATE(GFX4_DATA, 'YYYYMMDD') - TO_DATE(" + GEBDBQuote(BOCOL(aExt[nI]:D)) + ", 'YYYYMMDD')) <= " + BONUM(nDias, 0) + ;
            " ORDER BY ABS(TO_DATE(GFX4_DATA, 'YYYYMMDD') - TO_DATE(" + GEBDBQuote(BOCOL(aExt[nI]:D)) + ", 'YYYYMMDD')), R_E_C_N_O_")
        If Len(aMov) > 0
            BCOLiga(cConta, BOCOL(aExt[nI]:F), BOVAL(aMov[1]:RN))
            nOk := nOk + 1
        EndIf
    Next nI
Return {.T., BONUM(nOk, 0) + " conciliado(s)", nOk}

/*/{Protheus.doc} GEBBCOCONCMAN
    Concilia na mao uma linha do extrato (FITID) com um movimento (numero
    R_E_C_N_O_ da GFX4, mostrado no relatorio), ou desfaz (nMov = 0).
    @type Operacao financeira
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBBCOCONCMAN(cConta, cFitid, nMov)
    Local aE := {}
    cConta := BOCOL(cConta)
    cFitid := BOCOL(cFitid)
    nMov := Int(BOVAL(nMov))
    If !GEBBCOMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    aE := TCSqlQuery("SELECT GBC3_VALOR AS V FROM GBC3 WHERE GBC3_FILIAL = " + GEBDBQuote(FWxFilial("GBC3")) + " AND GBC3_CONTA = " + GEBDBQuote(cConta) + ;
        " AND GBC3_FITID = " + GEBDBQuote(cFitid) + " AND D_E_L_E_T_ = ' '")
    If Len(aE) == 0
        Return {.F., "linha_do_extrato_inexistente: " + cFitid}
    EndIf
    If nMov == 0
        TCSqlExec("UPDATE GBC3 SET GBC3_STATUS = 'PENDENTE', GBC3_MOVRN = 0 WHERE GBC3_FILIAL = " + GEBDBQuote(FWxFilial("GBC3")) + ;
            " AND GBC3_CONTA = " + GEBDBQuote(cConta) + " AND GBC3_FITID = " + GEBDBQuote(cFitid) + " AND D_E_L_E_T_ = ' '")
        Return {.T., "conciliacao desfeita"}
    EndIf
    If Len(TCSqlQuery("SELECT R_E_C_N_O_ FROM GFX4 WHERE GFX4_FILIAL = " + GEBDBQuote(FWxFilial("GFX4")) + " AND GFX4_CONTA = " + GEBDBQuote(cConta) + ;
            " AND R_E_C_N_O_ = " + BONUM(nMov, 0) + " AND D_E_L_E_T_ = ' '")) == 0
        Return {.F., "movimento_inexistente_na_conta: " + BONUM(nMov, 0)}
    EndIf
    If Len(TCSqlQuery("SELECT GBC3_FITID FROM GBC3 WHERE GBC3_FILIAL = " + GEBDBQuote(FWxFilial("GBC3")) + " AND GBC3_MOVRN = " + BONUM(nMov, 0) + ;
            " AND GBC3_STATUS = 'CONCILIADO' AND D_E_L_E_T_ = ' '")) > 0
        Return {.F., "movimento_ja_conciliado: " + BONUM(nMov, 0)}
    EndIf
    BCOLiga(cConta, cFitid, nMov)
Return {.T., "conciliado"}

/*/{Protheus.doc} GEBBCOLANCA
    Lanca no sistema a linha do extrato que so' existe no banco (tarifa,
    rendimento) como movimento avulso (GEBFXMOV) e ja concilia.
    @type Operacao financeira
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBBCOLANCA(cConta, cFitid, cCtaCtb, cCC)
    Local aE := {}
    Local aR := {}
    Local aM := {}
    Local cDC := "C"
    cConta := BOCOL(cConta)
    cFitid := BOCOL(cFitid)
    If !GEBBCOMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    aE := TCSqlQuery("SELECT GBC3_DATA AS D, GBC3_VALOR AS V, GBC3_MEMO AS M, GBC3_STATUS AS S FROM GBC3 WHERE GBC3_FILIAL = " + GEBDBQuote(FWxFilial("GBC3")) + ;
        " AND GBC3_CONTA = " + GEBDBQuote(cConta) + " AND GBC3_FITID = " + GEBDBQuote(cFitid) + " AND D_E_L_E_T_ = ' '")
    If Len(aE) == 0
        Return {.F., "linha_do_extrato_inexistente: " + cFitid}
    EndIf
    If !(BOCOL(aE[1]:S) == "PENDENTE")
        Return {.F., "linha_ja_conciliada: " + cFitid}
    EndIf
    If BOVAL(aE[1]:V) < 0
        cDC := "D"
    EndIf
    aR := GEBFXMOV(cConta, cDC, Abs(BOVAL(aE[1]:V)), "Extrato " + cFitid + " " + BOCOL(aE[1]:M), BOCOL(aE[1]:D), cCtaCtb, cCC)
    If !aR[1]
        Return aR
    EndIf
    aM := TCSqlQuery("SELECT MAX(R_E_C_N_O_) AS RN FROM GFX4 WHERE GFX4_FILIAL = " + GEBDBQuote(FWxFilial("GFX4")) + " AND GFX4_CONTA = " + GEBDBQuote(cConta) + ;
        " AND D_E_L_E_T_ = ' '")
    BCOLiga(cConta, cFitid, BOVAL(aM[1]:RN))
Return {.T., "lancado e conciliado"}

/*/{Protheus.doc} GEBBCOREL
    Relatorio: conciliacao da conta no periodo: linhas conciliadas,
    pendentes no banco (extrato sem movimento) e pendentes no sistema
    (movimento sem extrato), com o total de cada lado.
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {aLinhas (1a = cabecalho), aTotais}}
/*/
User Function GEBBCOREL(cConta, cIni, cFim)
    Local aHit := {}
    Local aLin := {{"situacao", "data", "fitid_ou_movimento", "historico", "valor"}}
    Local nBanco := 0
    Local nSist := 0
    Local nPendB := 0
    Local nPendS := 0
    Local nI := 0
    Local nV := 0
    cConta := BOCOL(cConta)
    cIni := BODATA(cIni)
    cFim := BODATA(cFim)
    If cIni == "" .Or. cFim == "" .Or. cIni > cFim
        Return {.F., "periodo_invalido", {}}
    EndIf
    If !GEBBCOMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GBC3_STATUS AS S, GBC3_DATA AS D, GBC3_FITID AS F, GBC3_MEMO AS M, GBC3_VALOR AS V FROM GBC3 WHERE GBC3_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GBC3")) + " AND GBC3_CONTA = " + GEBDBQuote(cConta) + " AND D_E_L_E_T_ = ' ' AND GBC3_DATA BETWEEN " + GEBDBQuote(cIni) + ;
        " AND " + GEBDBQuote(cFim) + " ORDER BY GBC3_STATUS, GBC3_DATA")
    For nI := 1 To Len(aHit)
        nV := BOVAL(aHit[nI]:V)
        nBanco := nBanco + nV
        If BOCOL(aHit[nI]:S) == "CONCILIADO"
            aAdd(aLin, {"conciliado", BOCOL(aHit[nI]:D), BOCOL(aHit[nI]:F), BOCOL(aHit[nI]:M), nV})
        Else
            nPendB := nPendB + nV
            aAdd(aLin, {"pendente no banco", BOCOL(aHit[nI]:D), BOCOL(aHit[nI]:F), BOCOL(aHit[nI]:M), nV})
        EndIf
    Next nI
    aHit := TCSqlQuery("SELECT R_E_C_N_O_ AS RN, GFX4_DATA AS D, GFX4_HIST AS H, CASE WHEN GFX4_DC = 'C' THEN GFX4_VALOR ELSE -GFX4_VALOR END AS V, " + ;
        "CASE WHEN R_E_C_N_O_ IN (SELECT GBC3_MOVRN FROM GBC3 WHERE GBC3_FILIAL = GFX4_FILIAL AND GBC3_STATUS = 'CONCILIADO' AND GBC3.D_E_L_E_T_ = ' ') THEN 'S' ELSE 'N' END AS C " + ;
        "FROM GFX4 WHERE GFX4_FILIAL = " + GEBDBQuote(FWxFilial("GFX4")) + " AND GFX4_CONTA = " + GEBDBQuote(cConta) + " AND D_E_L_E_T_ = ' ' AND GFX4_DATA BETWEEN " + ;
        GEBDBQuote(cIni) + " AND " + GEBDBQuote(cFim) + " ORDER BY GFX4_DATA, R_E_C_N_O_")
    For nI := 1 To Len(aHit)
        nV := BOVAL(aHit[nI]:V)
        nSist := nSist + nV
        If BOCOL(aHit[nI]:C) == "N"
            nPendS := nPendS + nV
            aAdd(aLin, {"pendente no sistema", BOCOL(aHit[nI]:D), "mov " + BONUM(aHit[nI]:RN, 0), BOCOL(aHit[nI]:H), nV})
        EndIf
    Next nI
    BOREL(aLin)
Return {.T., "conciliacao", {aLin, {{"total_banco", Round(nBanco, 2)}, {"total_sistema", Round(nSist, 2)}, {"pendente_banco", Round(nPendB, 2)}, ;
    {"pendente_sistema", Round(nPendS, 2)}}}}

// Cobranca da conta: {cConta, cBanco, cAgencia, cAgDv, cConta, cCarteira, cBenef, cCnpj, cCodEmp, cContaDv, cLayout, cModal}; {} se nao ha.
Static Function BCOCfg(cConta)
    Local aHit := TCSqlQuery("SELECT GBC1_BANCO AS B, GBC1_AGENCIA AS A, GBC1_AGDV AS AD, GBC1_CC AS C, GBC1_CARTEIRA AS CA, GBC1_BENEF AS BE, " + ;
        "GBC1_CNPJ AS CN, GBC1_CODEMP AS CE, GBC1_CCDV AS CD, GBC1_LAYOUT AS LY, GBC1_MODAL AS MO FROM GBC1 WHERE GBC1_FILIAL = " + GEBDBQuote(FWxFilial("GBC1")) + ;
        " AND GBC1_CONTA = " + GEBDBQuote(cConta) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {}
    EndIf
Return {cConta, BOCOL(aHit[1]:B), BOCOL(aHit[1]:A), BOCOL(aHit[1]:AD), BOCOL(aHit[1]:C), BOCOL(aHit[1]:CA), BOCOL(aHit[1]:BE), BOCOL(aHit[1]:CN), ;
    BOCOL(aHit[1]:CE), BOCOL(aHit[1]:CD), BOCOL(aHit[1]:LY), BOCOL(aHit[1]:MO)}

// Tamanho do sequencial do nosso numero por banco.
Static Function BCOTamNN(cBanco)
    Local nP := AScan({"237", "341", "033", "104", "001", "756"}, cBanco)
    Local aTam := {11, 8, 12, 15, 10, 7}
    If nP == 0
        Return 11
    EndIf
Return aTam[nP]

// Modulo 11 com pesos 2..nMax da direita. cRegra: "R01" = 11 - resto, resto 0/1 vira 0
// (Santander); "G9" = 11 - resto, maior que 9 vira 0 (Caixa).
Static Function BCODV11(cNum, nMax, cRegra)
    Local nSoma := 0
    Local nPeso := 2
    Local nResto := 0
    Local nDV := 0
    Local nI := 0
    For nI := Len(cNum) To 1 Step -1
        nSoma := nSoma + Val(SubStr(cNum, nI, 1)) * nPeso
        nPeso := nPeso + 1
        If nPeso > nMax
            nPeso := 2
        EndIf
    Next nI
    nResto := BOMOD(nSoma, 11)
    If cRegra == "R01"
        If nResto <= 1
            Return "0"
        EndIf
        Return Str(11 - nResto, 1)
    EndIf
    nDV := 11 - nResto
    If nDV > 9
        nDV := 0
    EndIf
Return Str(nDV, 1)

// DV do nosso numero Sicoob: pesos 3,1,9,7 da esquerda sobre cooperativa(4) + cliente(10) + NN(7); resto 0/1 = 0.
Static Function BCOSicoobDV(cCoop, cCliente10, cNN)
    Local cNum := cCoop + cCliente10 + cNN
    Local aPeso := {3, 1, 9, 7}
    Local nSoma := 0
    Local nResto := 0
    Local nI := 0
    For nI := 1 To Len(cNum)
        nSoma := nSoma + Val(SubStr(cNum, nI, 1)) * aPeso[BOMOD(nI - 1, 4) + 1]
    Next nI
    nResto := BOMOD(nSoma, 11)
    If nResto <= 1
        Return "0"
    EndIf
Return Str(11 - nResto, 1)

Static Function BCONomeBanco(cBanco)
    Local nP := AScan({"001", "033", "104", "237", "341", "756"}, cBanco)
    Local aNom := {"BANCO DO BRASIL S.A.", "BANCO SANTANDER", "CAIXA ECONOMICA FEDERAL", "BRADESCO", "BANCO ITAU SA", "SICOOB"}
    If nP == 0
        Return ""
    EndIf
Return aNom[nP]

// Juros por dia de atraso em centavos com nTam digitos (GE4 FIN_JUROS_DIA % ao dia).
Static Function BCOJurosDia(xValor, nTam)
Return StrZero(Round(BOVAL(xValor) * BOVAL(BOPARM("FIN_JUROS_DIA", "0.033")), 0), nTam)

// Tipo de inscricao do pagador: 01 CPF, 02 CNPJ.
Static Function BCOTpInsc(cDoc)
    If Len(cDoc) > 11
        Return "02"
    EndIf
Return "01"

// Codigo do banco com DV para a ficha de compensacao.
Static Function BCOBancoDV(cBanco)
    Local nP := AScan({"001", "033", "104", "237", "341", "756"}, cBanco)
    Local aCod := {"001-9", "033-7", "104-0", "237-2", "341-7", "756-0"}
    If nP == 0
        Return cBanco
    EndIf
Return aCod[nP]

Static Function BCOSufixo(cDV)
    If BOCOL(cDV) == ""
        Return ""
    EndIf
Return "-" + BOCOL(cDV)

Static Function BCODDMMAAAA(cData)
Return Right(cData, 2) + SubStr(cData, 5, 2) + Left(cData, 4)

Static Function BCOFator(cVenc)
    Local nD := BODIAS("19971007", cVenc)
    If nD >= 10000
        nD := BOMOD(nD - 10000, 9000) + 1000
    EndIf
Return StrZero(nD, 4)

Static Function BCODig(cVal, nMax)
    cVal := BOCOL(cVal)
Return !(cVal == "") .And. Len(cVal) <= nMax .And. StrZero(Val(cVal), Len(cVal)) == cVal

Static Function BCOLiga(cConta, cFitid, nMov)
    TCSqlExec("UPDATE GBC3 SET GBC3_STATUS = 'CONCILIADO', GBC3_MOVRN = " + BONUM(nMov, 0) + " WHERE GBC3_FILIAL = " + GEBDBQuote(FWxFilial("GBC3")) + ;
        " AND GBC3_CONTA = " + GEBDBQuote(cConta) + " AND GBC3_FITID = " + GEBDBQuote(cFitid) + " AND D_E_L_E_T_ = ' '")
Return .T.

// Valor de uma tag OFX (SGML: <TAG>valor, com ou sem </TAG>).
Static Function BCOTag(cBloco, cTag)
    Local nP := At("<" + cTag + ">", Upper(cBloco))
    Local cV := ""
    Local nF := 0
    If nP == 0
        Return ""
    EndIf
    cV := SubStr(cBloco, nP + Len(cTag) + 2)
    nF := At("<", cV)
    If nF > 0
        cV := Left(cV, nF - 1)
    EndIf
Return AllTrim(StrTran(StrTran(cV, Chr(13), ""), Chr(10), ""))

// Pagador do boleto: {cNome, cDocumento so' digitos}.
Static Function BCOPagador(cDoc)
    Local aHit := TCSqlQuery("SELECT GFN2_CLI AS C FROM GFN2 WHERE GFN2_FILIAL = " + GEBDBQuote(FWxFilial("GFN2")) + " AND GFN2_DOC = " + GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' '")
    Local aCli := {}
    Local cCli := ""
    If Len(aHit) > 0
        cCli := BOCOL(aHit[1]:C)
    EndIf
    If GEBDBTableExistsHere("GFT1")
        aCli := TCSqlQuery("SELECT GFT1_NOME AS N, GFT1_DOC AS D FROM GFT1 WHERE GFT1_FILIAL = " + GEBDBQuote(FWxFilial("GFT1")) + " AND GFT1_COD = " + ;
            GEBDBQuote(cCli) + " AND D_E_L_E_T_ = ' '")
    EndIf
    If Len(aCli) > 0
        Return {BOCOL(aCli[1]:N), BCOSoDig(BOCOL(aCli[1]:D))}
    EndIf
Return {cCli, ""}

Static Function BCOSoDig(cTxt)
    Local cR := ""
    Local nI := 0
    For nI := 1 To Len(cTxt)
        If SubStr(cTxt, nI, 1) >= "0" .And. SubStr(cTxt, nI, 1) <= "9"
            cR := cR + SubStr(cTxt, nI, 1)
        EndIf
    Next nI
Return cR

// Campos do CNAB: alfanumerico (maiusculo, sem acento, completado com espacos) e numerico (zeros a esquerda).
Static Function BCOAlf(cTxt, nTam)
    cTxt := Upper(BOSTR(cTxt))
Return Left(cTxt + Space(nTam), nTam)

Static Function BCONum(cTxt, nTam)
    cTxt := BCOSoDig(BOSTR(cTxt))
    If Len(cTxt) > nTam
        cTxt := Right(cTxt, nTam)
    EndIf
Return Replicate("0", nTam - Len(cTxt)) + cTxt

Static Function BCODDMMAA(cData)
Return SubStr(cData, 7, 2) + SubStr(cData, 5, 2) + SubStr(cData, 3, 2)

// DDMMAA -> AAAAMMDD (seculo 20xx).
Static Function BCODe6(cD)
Return "20" + SubStr(cD, 5, 2) + SubStr(cD, 3, 2) + Left(cD, 2)

Static Function BCODataBR(cData)
Return Right(cData, 2) + "/" + SubStr(cData, 5, 2) + "/" + Left(cData, 4)

Static Function BCOOcorr(cOc)
    Local aCod := {"02", "03", "06", "09", "10", "15", "17"}
    Local aDes := {"entrada confirmada", "entrada rejeitada", "liquidacao", "baixa automatica", "baixa por instrucao", "liquidacao em cartorio", "liquidacao apos baixa"}
    Local nP := AScan(aCod, cOc)
    If nP == 0
        Return "ocorrencia " + cOc
    EndIf
Return aDes[nP]

Static Function BCOEsc(cTxt)
Return StrTran(StrTran(StrTran(BOSTR(cTxt), "&", "&amp;"), "<", "&lt;"), ">", "&gt;")

// Intercalado 2 de 5 em barras HTML (estreita 1px, larga 3px).
Static Function BCOI25(cCod)
    Local aPad := {"00110", "10001", "01001", "11000", "00101", "10100", "01100", "00011", "10010", "01010"}
    Local cH := ""
    Local cB := ""
    Local cE := ""
    Local nI := 0
    Local nJ := 0
    cH := BCOBarra(1, .T.) + BCOBarra(1, .F.) + BCOBarra(1, .T.) + BCOBarra(1, .F.)
    For nI := 1 To Len(cCod) Step 2
        cB := aPad[Val(SubStr(cCod, nI, 1)) + 1]
        cE := aPad[Val(SubStr(cCod, nI + 1, 1)) + 1]
        For nJ := 1 To 5
            cH := cH + BCOBarra(BCOLarg(SubStr(cB, nJ, 1)), .T.) + BCOBarra(BCOLarg(SubStr(cE, nJ, 1)), .F.)
        Next nJ
    Next nI
Return cH + BCOBarra(3, .T.) + BCOBarra(1, .F.) + BCOBarra(1, .T.)

Static Function BCOLarg(cBit)
    If cBit == "1"
        Return 3
    EndIf
Return 1

Static Function BCOBarra(nLarg, lPreta)
    If lPreta
        Return '<span style="width:' + BONUM(nLarg, 0) + 'px;background:#000"></span>'
    EndIf
Return '<span style="width:' + BONUM(nLarg, 0) + 'px;background:#fff"></span>'
