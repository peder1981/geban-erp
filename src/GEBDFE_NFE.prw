#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBDFE_XML.prw"
#include "GEBDFE_CAD.prw"
#include "GEBDFE.prw"
#include "GEBFNX.prw"
#include "GEBCTX.prw"

/*/{Protheus.doc} GEBDFE_NFE
    NF-e modelo 55 (faturamento, devolucao de venda e devolucao de compra).
    - GDF7 participante fiscal (cliente C / fornecedor F): CPF/CNPJ, IE e
      indicador (1 contribuinte, 2 isento, 9 nao contribuinte), endereco com
      municipio IBGE. GEBDFEPART grava, GEBDFEPARTLE devolve o DEST do XML.
    - GDF8 vinculos: chave da NF-e do fornecedor de uma entrada (ENT) e
      chave da NF-e de devolucao emitida pelo cliente (DEVCLI).
    - GEBDFENFE: emite (saida ou entrada, normal ou devolucao com NFref).
      Destino na mesma UF => idDest 1 (CFOP 5/1), outra UF => 2 (6/2);
      consumidor nao contribuinte => indFinal 1. Regime normal: aliquota
      interestadual (4% importado, 7% S/SE -> N/NE/CO/ES, 12% demais) e, na
      venda a nao contribuinte de outra UF, o DIFAL (grupo ICMSUFDest, base
      unica ou dupla por UF) com titulo a pagar a SEFAZ de destino. Sem resposta da SEFAZ => documento PENDENTE (nao ha
      contingencia offline na NF-e): GEBDFERESOLVE consulta e, se a SEFAZ
      autorizou um documento que ficou sem operacao, cancela; se nao
      autorizou, o numero vai para inutilizar.
    - GEBDFECCE: carta de correcao (evento 110110, ate 20 por nota).
    @type Modulo fiscal
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBDFENFEMIG()
    Local lOk := GEBDFECADMIG()
    lOk := lOk .And. BOTAB("GDF7", "GDF7_TIPO TEXT NOT NULL, GDF7_COD TEXT NOT NULL, GDF7_DOC TEXT NOT NULL, GDF7_IE TEXT NOT NULL, GDF7_INDIE TEXT NOT NULL, " + ;
        "GDF7_NOME TEXT NOT NULL, GDF7_LGR TEXT NOT NULL, GDF7_NRO TEXT NOT NULL, GDF7_CPL TEXT NOT NULL, GDF7_BAIRRO TEXT NOT NULL, GDF7_CMUN TEXT NOT NULL, " + ;
        "GDF7_XMUN TEXT NOT NULL, GDF7_UF TEXT NOT NULL, GDF7_CEP TEXT NOT NULL, GDF7_FONE TEXT NOT NULL, GDF7_EMAIL TEXT NOT NULL", "GDF7_TIPO, GDF7_COD")
    lOk := lOk .And. BOTAB("GDF8", "GDF8_TIPO TEXT NOT NULL, GDF8_DOC TEXT NOT NULL, GDF8_PART TEXT NOT NULL, GDF8_CHAVE TEXT NOT NULL", "GDF8_TIPO, GDF8_DOC")
Return lOk

/*/{Protheus.doc} GEBDFEPART
    Cadastro fiscal do cliente (TIPO C, codigo da GFT1) ou do fornecedor
    (TIPO F, codigo da GCP1). o: TIPO, CODIGO, DOC, IE, CONTRIBUINTE (1, 2
    ou 9), NOME, LOGRADOURO, NUMERO, COMPLEMENTO, BAIRRO, MUNICIPIO (IBGE),
    UF, CEP, FONE, EMAIL.
    @type Cadastro fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBDFEPART(o)
    Local cFil := FWxFilial("GDF7")
    Local cTipo := Upper(BOQ(o, "TIPO"))
    Local cCod := Upper(BOQ(o, "CODIGO"))
    Local cDoc := GEBDFEDIG(BOQ(o, "DOC"))
    Local cIE := GEBDFEDIG(BOQ(o, "IE"))
    Local cInd := BOQ(o, "CONTRIBUINTE")
    Local cUF := Upper(BOQ(o, "UF"))
    Local cMun := GEBDFEDIG(BOQ(o, "MUNICIPIO"))
    Local cXMun := ""
    Local aH := {}
    If !(cTipo == "C" .Or. cTipo == "F" .Or. cTipo == "L")
        Return {.F., "tipo_deve_ser_C_cliente_F_fornecedor_ou_L_consumidor_da_loja"}
    EndIf
    If !GEBDFENFEMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    If cTipo == "L"
        // Consumidor da loja (devolucao de NFC-e): o codigo e' o proprio CPF/CNPJ.
        cCod := cDoc
        If BOQ(o, "NOME") == ""
            Return {.F., "nome_do_consumidor_obrigatorio"}
        EndIf
        aH := {{"L"}}
    ElseIf cTipo == "C"
        aH := TCSqlQuery("SELECT GFT1_NOME AS N FROM GFT1 WHERE GFT1_FILIAL = " + GEBDBQuote(FWxFilial("GFT1")) + " AND GFT1_COD = " + GEBDBQuote(cCod) + ;
            " AND D_E_L_E_T_ = ' '")
    ElseIf GEBDBTableExistsHere("GCP1")
        aH := TCSqlQuery("SELECT GCP1_NOME AS N FROM GCP1 WHERE GCP1_FILIAL = " + GEBDBQuote(FWxFilial("GCP1")) + " AND GCP1_COD = " + GEBDBQuote(cCod) + ;
            " AND D_E_L_E_T_ = ' '")
    EndIf
    If Len(aH) == 0
        Return {.F., "participante_inexistente: " + cTipo + " " + cCod}
    EndIf
    If cTipo == "L"
        aH := {}
    EndIf
    If !GEBDFEDOCOK(cDoc)
        Return {.F., "cpf_cnpj_invalido"}
    EndIf
    If cInd == ""
        cInd := "9"
    EndIf
    If !(cInd == "1" .Or. cInd == "2" .Or. cInd == "9")
        Return {.F., "contribuinte_deve_ser_1_2_ou_9"}
    EndIf
    If cInd == "1" .And. !GEBDFEIEOK(cIE, cUF)
        Return {.F., "inscricao_estadual_invalida_para_" + cUF}
    EndIf
    If cInd == "1" .And. Len(cDoc) == 11 .And. cIE == ""
        Return {.F., "contribuinte_sem_inscricao_estadual"}
    EndIf
    If !(cInd == "1")
        cIE := ""
    EndIf
    cXMun := GEBDFEMUNNOME(cMun)
    If GEBDFECUF(cUF) == "" .Or. cXMun == "" .Or. !(Left(cMun, 2) == GEBDFECUF(cUF))
        Return {.F., "municipio_ibge_invalido_para_" + cUF}
    EndIf
    If BOQ(o, "LOGRADOURO") == "" .Or. BOQ(o, "BAIRRO") == ""
        Return {.F., "logradouro_e_bairro_obrigatorios"}
    EndIf
    TCSqlExec("UPDATE GDF7 SET D_E_L_E_T_ = '*' WHERE GDF7_FILIAL = " + GEBDBQuote(cFil) + " AND GDF7_TIPO = " + GEBDBQuote(cTipo) + " AND GDF7_COD = " + ;
        GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GDF7 (D_E_L_E_T_, GDF7_FILIAL, GDF7_TIPO, GDF7_COD, GDF7_DOC, GDF7_IE, GDF7_INDIE, GDF7_NOME, GDF7_LGR, GDF7_NRO, GDF7_CPL, " + ;
        "GDF7_BAIRRO, GDF7_CMUN, GDF7_XMUN, GDF7_UF, GDF7_CEP, GDF7_FONE, GDF7_EMAIL) VALUES (' ', " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cTipo) + ", " + ;
        GEBDBQuote(cCod) + ", " + GEBDBQuote(cDoc) + ", " + GEBDBQuote(cIE) + ", " + GEBDBQuote(cInd) + ", " + GEBDBQuote(DFENomePart(o, aH)) + ", " + ;
        GEBDBQuote(BOQ(o, "LOGRADOURO")) + ", " + GEBDBQuote(BOQ(o, "NUMERO")) + ", " + GEBDBQuote(BOQ(o, "COMPLEMENTO")) + ", " + GEBDBQuote(BOQ(o, "BAIRRO")) + ", " + ;
        GEBDBQuote(cMun) + ", " + GEBDBQuote(cXMun) + ", " + GEBDBQuote(cUF) + ", " + GEBDBQuote(GEBDFEDIG(BOQ(o, "CEP"))) + ", " + ;
        GEBDBQuote(GEBDFEDIG(BOQ(o, "FONE"))) + ", " + GEBDBQuote(BOQ(o, "EMAIL")) + ")")
Return {.T., "cadastro fiscal de " + cCod + " gravado (" + cXMun + "/" + cUF + ")"}

Static Function DFENomePart(o, aH)
    If !(BOQ(o, "NOME") == "") .Or. Len(aH) == 0
        Return BOQ(o, "NOME")
    EndIf
Return BOCOL(aH[1]:N)

// Destinatario do XML (DEST de GEBDFEMONTA) ou Nil.
User Function GEBDFEPARTLE(cTipo, cCod)
    Local aH := {}
    Local oD := Nil
    GEBDFENFEMIG()
    aH := TCSqlQuery("SELECT GDF7_DOC AS D, GDF7_IE AS IE, GDF7_INDIE AS I, GDF7_NOME AS N, GDF7_LGR AS L, GDF7_NRO AS NR, GDF7_CPL AS C, GDF7_BAIRRO AS B, " + ;
        "GDF7_CMUN AS M, GDF7_XMUN AS XM, GDF7_UF AS U, GDF7_CEP AS CE, GDF7_FONE AS F, GDF7_EMAIL AS E FROM GDF7 WHERE GDF7_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GDF7")) + " AND GDF7_TIPO = " + GEBDBQuote(Upper(cTipo)) + " AND GDF7_COD = " + GEBDBQuote(Upper(BOCOL(cCod))) + " AND D_E_L_E_T_ = ' '")
    If Len(aH) == 0
        Return Nil
    EndIf
    oD := JsonObject():New()
    If Len(BOCOL(aH[1]:D)) == 14
        oD["CNPJ"] := BOCOL(aH[1]:D)
    Else
        oD["CPF"] := BOCOL(aH[1]:D)
    EndIf
    oD["XNOME"] := BOCOL(aH[1]:N)
    oD["XLGR"] := BOCOL(aH[1]:L)
    oD["NRO"] := BOCOL(aH[1]:NR)
    oD["XCPL"] := BOCOL(aH[1]:C)
    oD["XBAIRRO"] := BOCOL(aH[1]:B)
    oD["CMUN"] := BOCOL(aH[1]:M)
    oD["XMUN"] := BOCOL(aH[1]:XM)
    oD["UF"] := BOCOL(aH[1]:U)
    oD["CEP"] := BOCOL(aH[1]:CE)
    oD["FONE"] := BOCOL(aH[1]:F)
    oD["EMAIL"] := BOCOL(aH[1]:E)
    oD["INDIEDEST"] := BOCOL(aH[1]:I)
    oD["IE"] := BOCOL(aH[1]:IE)
Return oD

// Vinculo de chave (ENT: NF-e do fornecedor da entrada; DEVCLI: NF-e de devolucao do cliente).
User Function GEBDFEVINC(cTipo, cDoc, cPart, cChave)
    Local cFil := FWxFilial("GDF8")
    cChave := GEBDFEDIG(cChave)
    If !(Len(cChave) == 44) .Or. !(GEBDFEDV(Left(cChave, 43)) == Right(cChave, 1))
        Return {.F., "chave_de_acesso_invalida"}
    EndIf
    If !GEBDFENFEMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    TCSqlExec("UPDATE GDF8 SET D_E_L_E_T_ = '*' WHERE GDF8_FILIAL = " + GEBDBQuote(cFil) + " AND GDF8_TIPO = " + GEBDBQuote(cTipo) + " AND GDF8_DOC = " + ;
        GEBDBQuote(Upper(BOCOL(cDoc))) + " AND GDF8_PART = " + GEBDBQuote(Upper(BOCOL(cPart))) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GDF8 (D_E_L_E_T_, GDF8_FILIAL, GDF8_TIPO, GDF8_DOC, GDF8_PART, GDF8_CHAVE) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
        GEBDBQuote(cTipo) + ", " + GEBDBQuote(Upper(BOCOL(cDoc))) + ", " + GEBDBQuote(Upper(BOCOL(cPart))) + ", " + GEBDBQuote(cChave) + ")")
Return {.T., "chave vinculada"}

User Function GEBDFEVINCLE(cTipo, cDoc, cPart)
    Local aH := {}
    GEBDFENFEMIG()
    aH := TCSqlQuery("SELECT GDF8_CHAVE AS C FROM GDF8 WHERE GDF8_FILIAL = " + GEBDBQuote(FWxFilial("GDF8")) + " AND GDF8_TIPO = " + GEBDBQuote(cTipo) + ;
        " AND GDF8_DOC = " + GEBDBQuote(Upper(BOCOL(cDoc))) + " AND GDF8_PART = " + GEBDBQuote(Upper(BOCOL(cPart))) + " AND D_E_L_E_T_ = ' '")
    If Len(aH) == 0
        Return ""
    EndIf
Return BOCOL(aH[1]:C)

// Aliquota interna modal do ICMS da UF (padrao: tabela publicada em 2026; DFE_ALIQ_INT_<UF> sobrepoe).
User Function GEBDFEALIQINT(cUF)
    Local aT := {{"AC", "19"}, {"AL", "20.5"}, {"AM", "20"}, {"AP", "18"}, {"BA", "20.5"}, {"CE", "20"}, {"DF", "20"}, {"ES", "17"}, {"GO", "19"}, ;
        {"MA", "23"}, {"MG", "18"}, {"MS", "17"}, {"MT", "17"}, {"PA", "19"}, {"PB", "20"}, {"PE", "20.5"}, {"PI", "22.5"}, {"PR", "19.5"}, ;
        {"RJ", "20"}, {"RN", "20"}, {"RO", "19.5"}, {"RR", "20"}, {"RS", "17"}, {"SC", "17"}, {"SE", "19"}, {"SP", "18"}, {"TO", "20"}}
    Local nP := AScan(aT, {|x| x[1] == Upper(cUF)})
    Local cPad := "18"
    If nP > 0
        cPad := aT[nP][2]
    EndIf
Return BOVAL(BOPARM("DFE_ALIQ_INT_" + Upper(cUF), cPad))

// FCP geral do destino (RJ 2%, SE 1%; nas demais UFs o FCP e' por produto e fica no parametro).
User Function GEBDFEFCPPAD(cUF)
    If Upper(cUF) == "RJ"
        Return "2"
    EndIf
    If Upper(cUF) == "SE"
        Return "1"
    EndIf
Return "0"

// Aliquota interestadual do ICMS (Res. Senado 22/1989 e 13/2012).
User Function GEBDFEALIQINTER(cUFOrig, cUFDest, cOrigem)
    If cOrigem $ "1238" .And. Len(cOrigem) == 1
        Return 4
    EndIf
    If cUFOrig $ "SP|RJ|MG|PR|SC|RS" .And. !(cUFDest $ "SP|RJ|MG|PR|SC|RS")
        Return 7
    EndIf
Return 12

// CFOP conforme destino e operacao (devolucao de venda 1202/2202; de compra 5202/6202).
Static Function DFECfop(cCfop, cIdDest, cTpNF, cFin)
    If cFin == "4" .And. cTpNF == "0"
        Return DFEDig(cIdDest, "1202", "2202")
    EndIf
    If cFin == "4"
        Return DFEDig(cIdDest, "5202", "6202")
    EndIf
    If cIdDest == "2" .And. Left(cCfop, 1) == "5"
        Return "6" + SubStr(cCfop, 2)
    EndIf
Return cCfop

Static Function DFEDig(cIdDest, cInterna, cInter)
    If cIdDest == "2"
        Return cInter
    EndIf
Return cInterna

/*/{Protheus.doc} GEBDFENFE
    Emite a NF-e (modelo 55). oP: ORIGEM (FAT, FATDEV, CPXDEV), DOC,
    TIPO_PART (C|F), PART, ITENS {{cProd, nQtd, nVUnit, nVDesc}...}, TPNF
    (1 saida, 0 entrada), FINNFE (1 normal, 4 devolucao), NATOP, REFS
    (chaves referenciadas), PARCELAS {{dVenc AAAAMMDD, nValor}...} (vazio =
    sem cobranca), NFAT (numero da fatura).
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {cChave, cStatus, cProt, nNNF, nSerie}}
/*/
User Function GEBDFENFE(oP)
    Local oE := GEBDFEEMITLE()
    Local aC := GEBDFECERTLE()
    Local oD := Nil
    Local oNF := Nil
    Local oI := Nil
    Local oPg := Nil
    Local aIt := {}
    Local aDup := {}
    Local aNow := {}
    Local aR := {}
    Local aA := {}
    Local aEnv := {}
    Local aItens := oP["ITENS"]
    Local aParc := oP["PARCELAS"]
    Local cAmb := BOPARM("DFE_AMBIENTE", "2")
    Local cTpNF := BOCOL(oP["TPNF"])
    Local cFin := BOCOL(oP["FINNFE"])
    Local cIdDest := "1"
    Local cIndFinal := "0"
    Local cChave := ""
    Local cXml := ""
    Local cBloco := ""
    Local cCStat := ""
    Local cMotivo := ""
    Local cProt := ""
    Local lSimples := .F.
    Local lAPrazo := .F.
    Local aDif := Nil
    Local aTrib := {}
    Local nDifal := 0
    Local nSerie := BOVAL(BOPARM("DFE_SERIE_55", "1"))
    Local nNNF := 0
    Local nTot := 0
    Local nI := 0

    If oE == Nil
        Return {.F., "emitente_nao_cadastrado", {}}
    EndIf
    If Len(aC) == 0 .Or. aC[3] < BOHOJE()
        Return {.F., "certificado_nao_instalado_ou_vencido", {}}
    EndIf
    oD := GEBDFEPARTLE(BOCOL(oP["TIPO_PART"]), BOCOL(oP["PART"]))
    If oD == Nil
        Return {.F., "cadastro_fiscal_do_participante_incompleto: " + BOCOL(oP["PART"]) + " (Faturamento > cadastro fiscal do cliente/fornecedor)", {}}
    EndIf
    If cTpNF == ""
        cTpNF := "1"
    EndIf
    If cFin == ""
        cFin := "1"
    EndIf
    If !(oD["UF"] == oE["UF"])
        cIdDest := "2"
    EndIf
    If oD["INDIEDEST"] == "9"
        cIndFinal := "1"
    EndIf
    lSimples := oE["CRT"] == "1" .Or. oE["CRT"] == "4"
    // DIFAL (EC 87/2015): regime normal vendendo a nao contribuinte de outra UF. O Simples esta fora
    // (STF, ADI 5464). Aliquota interna e FCP do destino: parametros DFE_ALIQ_INT_<UF> / DFE_FCP_<UF>.
    If !lSimples .And. cIdDest == "2" .And. cIndFinal == "1" .And. cTpNF == "1" .And. cFin == "1"
        aDif := {GEBDFEALIQINT(oD["UF"]), BOVAL(BOPARM("DFE_FCP_" + oD["UF"], GEBDFEFCPPAD(oD["UF"]))), ;
            BOPARM("DFE_DIFAL_BASE_DUPLA_" + oD["UF"], "N") == "S"}
    EndIf
    For nI := 1 To Len(aItens)
        oI := GEBDFEPRODITEM(aItens[nI][1], lSimples)
        If oI == Nil
            Return {.F., "produto_inexistente: " + aItens[nI][1], {}}
        EndIf
        oI["CFOP"] := DFECfop(oI["CFOP"], cIdDest, cTpNF, cFin)
        oI["QCOM"] := aItens[nI][2]
        oI["VUNCOM"] := aItens[nI][3]
        oI["VDESC"] := aItens[nI][4]
        If cFin == "4"
            If lSimples
                oI["CSOSN"] := "900"
            EndIf
            If cTpNF == "0"
                oI["PISCST"] := "98"
                oI["COFINSCST"] := "98"
                oI["PPIS"] := 0
                oI["PCOFINS"] := 0
            EndIf
        EndIf
        If !lSimples .And. cIdDest == "2" .And. BOCOL(oI["CST"]) $ "00|10|20" .And. !(BOCOL(oI["CST"]) == "")
            oI["PICMS"] := GEBDFEALIQINTER(oE["UF"], oD["UF"], oI["ORIG"])
        EndIf
        nTot += Round(aItens[nI][2] * aItens[nI][3], 2) - Round(aItens[nI][4], 2)
        aAdd(aIt, oI)
    Next nI
    nTot := Round(nTot, 2)

    aNow := GEBDFEAGORA(oE["UF"])
    oNF := JsonObject():New()
    oNF["MOD"] := "55"
    oNF["SERIE"] := nSerie
    oNF["TPEMIS"] := "1"
    oNF["DHEMI"] := aNow[3]
    oNF["DHSAIENT"] := aNow[3]
    oNF["TPAMB"] := cAmb
    oNF["NATOP"] := BOCOL(oP["NATOP"])
    oNF["CMUNFG"] := oE["CMUN"]
    oNF["TPNF"] := cTpNF
    oNF["FINNFE"] := cFin
    oNF["IDDEST"] := cIdDest
    oNF["INDFINAL"] := cIndFinal
    oNF["INDPRES"] := BOPARM("DFE_NFE_INDPRES", "9")
    oNF["VERPROC"] := "GEBAN 1.0"
    oNF["EMIT"] := oE
    oNF["DEST"] := oD
    oNF["ITENS"] := aIt
    oNF["NFREF"] := oP["REFS"]
    oNF["DIFAL"] := aDif
    oNF["RESPTEC"] := GEBDFERESPTEC()
    oNF["INFCPL"] := AllTrim("Documento " + BOCOL(oP["DOC"]) + " " + BOPARM("DFE_NFE_INFCPL", ""))
    aTrib := GEBDFETRIB(aIt, oE["UF"], oE["CRT"], aNow[1])
    oNF["IBSCBS"] := aTrib[1]
    If !(aTrib[2] == "") .And. cFin == "1"
        oNF["INFCPL"] := oNF["INFCPL"] + ". " + aTrib[2]
    EndIf
    If lSimples
        // Texto obrigatorio do Simples Nacional no documento (Res. CGSN 140/2018, art. 59).
        oNF["INFCPL"] := oNF["INFCPL"] + ". DOCUMENTO EMITIDO POR ME OU EPP OPTANTE PELO SIMPLES NACIONAL. NAO GERA DIREITO A CREDITO FISCAL DE IPI."
    EndIf
    If cFin == "1" .And. cTpNF == "1"
        // Venda: a prazo (mais de uma parcela ou vencimento depois de hoje) leva duplicatas.
        If aParc != Nil .And. Len(aParc) > 0
            lAPrazo := Len(aParc) > 1 .Or. aParc[1][1] > aNow[1]
        EndIf
        oPg := JsonObject():New()
        oPg["INDPAG"] := "0"
        If lAPrazo
            oPg["INDPAG"] := "1"
        EndIf
        oPg["TPAG"] := BOPARM("DFE_NFE_TPAG", "15")
        oPg["VPAG"] := nTot
        If oPg["TPAG"] == "99"
            oPg["XPAG"] := "Conforme condicao de pagamento"
        EndIf
        oNF["PAG"] := {oPg}
        If lAPrazo
            For nI := 1 To Len(aParc)
                aAdd(aDup, {StrZero(nI, 3), aParc[nI][1], aParc[nI][2]})
            Next nI
            oNF["COBR"] := {BOCOL(oP["NFAT"]), nTot, 0, nTot, aDup}
        EndIf
    EndIf

    // Valida antes de consumir o numero.
    oNF["NNF"] := 1
    aR := GEBDFEMONTA(oNF)
    If !aR[1]
        Return {.F., aR[2], {}}
    EndIf
    nNNF := GEBDFEPROXNUM("55", nSerie)
    oNF["NNF"] := nNNF
    aR := GEBDFEMONTA(oNF)
    If !aR[1]
        Return {.F., aR[2], {}}
    EndIf
    cChave := aR[3][2]
    aA := GEBDFEASSINA(aR[3][1], "infNFe", "NFe", MemoRead(aC[5]), MemoRead(aC[4]))
    If !aA[1]
        Return {.F., aA[2], {}}
    EndIf
    cXml := aA[3]
    aEnv := GEBDFEENVIA("55", oE["UF"], cAmb, "NfeAutorizacao", GEBDFELOTE(cXml, StrZero(Val(BOSEQ("DFE_LOTE", 9)), 15)))
    If !aEnv[1]
        // Sem resposta: a SEFAZ pode ter autorizado. Fica PENDENTE ate GEBDFERESOLVE.
        DFEGrava55(cChave, nSerie, nNNF, cAmb, "PENDENTE", "", aEnv[3], "", aNow[3], "", oP, aR[3][3], cXml, oD)
        Return {.F., "sem_resposta_da_sefaz: o documento " + cValToChar(nNNF) + " ficou pendente; resolva em Documentos eletronicos > Resolver pendentes " + ;
            "antes de repetir a operacao (" + aEnv[3] + ")", {}}
    EndIf
    cBloco := GEBDFEBLOCO(aEnv[2], "protNFe")
    cCStat := GEBDFETAG(cBloco, "cStat")
    cMotivo := GEBDFETAG(cBloco, "xMotivo")
    If cBloco == ""
        cCStat := GEBDFETAG(aEnv[2], "cStat")
        cMotivo := GEBDFETAG(aEnv[2], "xMotivo")
    EndIf
    If cCStat == "100" .Or. cCStat == "150"
        cProt := GEBDFETAG(cBloco, "nProt")
        DFEGrava55(cChave, nSerie, nNNF, cAmb, "AUTORIZADA", cCStat, cMotivo, cProt, aNow[3], GEBDFETAG(cBloco, "dhRecbto"), oP, aR[3][3], ;
            GEBDFEPROC(cXml, cBloco), oD)
        // DIFAL + FCP do destino: titulo a pagar a SEFAZ da UF de destino e ICMS fora do DAS no contabil.
        nDifal := aR[3][6]
        If nDifal > 0
            GEBFXTIT("P", "DIFAL-" + oD["UF"] + "-" + cValToChar(nNNF), "SEFAZ-" + oD["UF"], nDifal, "0", aNow[1], "DIFAL NF-e " + cChave, "2.01.006")
            GEBCTXLP("SN_FORA", nDifal, "DIFAL " + cChave, aNow[1])
        EndIf
        Return {.T., "NF-e " + cValToChar(nNNF) + " autorizada: protocolo " + cProt, {cChave, "AUTORIZADA", cProt, nNNF, nSerie}}
    EndIf
    If cCStat $ "110|301|302|303" .And. Len(cCStat) == 3
        DFEGrava55(cChave, nSerie, nNNF, cAmb, "DENEGADA", cCStat, cMotivo, GEBDFETAG(cBloco, "nProt"), aNow[3], "", oP, aR[3][3], cXml, oD)
        Return {.F., "nfe_denegada: " + cCStat + " - " + cMotivo, {}}
    EndIf
    DFEGrava55(cChave, nSerie, nNNF, cAmb, "REJEITADA", cCStat, cMotivo, "", aNow[3], "", oP, aR[3][3], cXml, oD)
Return {.F., "nfe_rejeitada: " + cCStat + " - " + cMotivo, {}}

Static Function DFEGrava55(cChave, nSerie, nNNF, cAmb, cStatus, cCStat, cMotivo, cProt, cDhEmi, cDhAut, oP, nVNF, cXml, oD)
    Local cFil := FWxFilial("GDF5")
    Local cDest := ""
    If oD != Nil
        cDest := BOCOL(oD["CNPJ"]) + BOCOL(oD["CPF"])
    EndIf
    TCSqlExec("UPDATE GDF5 SET D_E_L_E_T_ = '*' WHERE GDF5_FILIAL = " + GEBDBQuote(cFil) + " AND GDF5_CHAVE = " + GEBDBQuote(cChave) + " AND D_E_L_E_T_ = ' '")
Return TCSqlExec("INSERT INTO GDF5 (D_E_L_E_T_, GDF5_FILIAL, GDF5_CHAVE, GDF5_MOD, GDF5_SERIE, GDF5_NNF, GDF5_TPEMIS, GDF5_TPAMB, GDF5_STATUS, " + ;
    "GDF5_CSTAT, GDF5_MOTIVO, GDF5_PROT, GDF5_DHEMI, GDF5_DHAUT, GDF5_ORIGEM, GDF5_DOC, GDF5_VNF, GDF5_XML, GDF5_QR, GDF5_URLCH, GDF5_DEST, " + ;
    "GDF5_CHORIG, GDF5_DATA, GDF5_XMLORIG) VALUES (' ', " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cChave) + ", '55', " + BONUM(nSerie, 0) + ", " + ;
    BONUM(nNNF, 0) + ", '1', " + GEBDBQuote(cAmb) + ", " + GEBDBQuote(cStatus) + ", " + GEBDBQuote(cCStat) + ", " + GEBDBQuote(Left(cMotivo, 250)) + ", " + ;
    GEBDBQuote(cProt) + ", " + GEBDBQuote(cDhEmi) + ", " + GEBDBQuote(cDhAut) + ", " + GEBDBQuote(BOCOL(oP["ORIGEM"])) + ", " + GEBDBQuote(BOCOL(oP["DOC"])) + ", " + ;
    BONUM(nVNF, 2) + ", " + GEBDBQuote(cXml) + ", '', '', " + GEBDBQuote(cDest) + ", '', " + GEBDBQuote(StrTran(Left(cDhEmi, 10), "-", "")) + ", '')")

/*/{Protheus.doc} GEBDFERESOLVE
    Resolve as NF-e PENDENTE (sem resposta da SEFAZ): consulta cada chave.
    Autorizada => a operacao nao foi gravada, entao o documento e' cancelado
    (evento 110111). Nao encontrada (217) => REJEITADA (numero a
    inutilizar). Sem comunicacao => continua pendente.
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {nCanceladas, nLiberadas, nPendentes}}
/*/
User Function GEBDFERESOLVE()
    Local aH := {}
    Local aC := {}
    Local aX := {}
    Local cCh := ""
    Local nCanc := 0
    Local nLib := 0
    Local nPend := 0
    Local nI := 0
    GEBDFENFEMIG()
    aH := TCSqlQuery("SELECT GDF5_CHAVE AS C FROM GDF5 WHERE GDF5_FILIAL = " + GEBDBQuote(FWxFilial("GDF5")) + " AND GDF5_STATUS = 'PENDENTE' " + ;
        "AND D_E_L_E_T_ = ' ' ORDER BY GDF5_NNF")
    For nI := 1 To Len(aH)
        cCh := BOCOL(aH[nI]:C)
        aC := GEBDFECONSULTAR(cCh, .F.)
        If !aC[1]
            nPend++
        ElseIf aC[3][1] == "100"
            TCSqlExec("UPDATE GDF5 SET GDF5_STATUS = 'AUTORIZADA', GDF5_CSTAT = '100', GDF5_PROT = " + GEBDBQuote(aC[3][3]) + ", GDF5_DHAUT = " + ;
                GEBDBQuote(aC[3][4]) + ", GDF5_XML = " + GEBDBQuote(GEBDFEPROC(GEBDFEDOC(cCh)[3], aC[3][5])) + " WHERE GDF5_FILIAL = " + ;
                GEBDBQuote(FWxFilial("GDF5")) + " AND GDF5_CHAVE = " + GEBDBQuote(cCh) + " AND D_E_L_E_T_ = ' '")
            aX := GEBDFECANCELA(cCh, "Documento autorizado sem resposta da SEFAZ; operacao nao gravada")
            If aX[1]
                nCanc++
            Else
                nPend++
            EndIf
        ElseIf aC[3][1] == "217"
            TCSqlExec("UPDATE GDF5 SET GDF5_STATUS = 'REJEITADA', GDF5_CSTAT = '217', GDF5_MOTIVO = 'Nao consta na SEFAZ' WHERE GDF5_FILIAL = " + ;
                GEBDBQuote(FWxFilial("GDF5")) + " AND GDF5_CHAVE = " + GEBDBQuote(cCh) + " AND D_E_L_E_T_ = ' '")
            nLib++
        Else
            nPend++
        EndIf
    Next nI
Return {nPend == 0, cValToChar(nCanc) + " cancelada(s), " + cValToChar(nLib) + " liberada(s) para inutilizar, " + cValToChar(nPend) + " ainda pendente(s)", ;
    {nCanc, nLib, nPend}}

/*/{Protheus.doc} GEBDFECCE
    Carta de correcao (evento 110110) da NF-e autorizada; texto de 15 a
    1000 letras; ate 20 por nota (cada uma substitui a anterior).
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, cProt}
/*/
User Function GEBDFECCE(cChave, cTexto)
    Local oE := GEBDFEEMITLE()
    Local aC := GEBDFECERTLE()
    Local aD := GEBDFEDOC(cChave)
    Local aH := {}
    Local aNow := {}
    Local aA := {}
    Local aEnv := {}
    Local cEv := ""
    Local cRet := ""
    Local cCStat := ""
    Local cMot := ""
    Local cProt := ""
    Local nSeq := 0
    cTexto := AllTrim(BOSTR(cTexto))
    If oE == Nil .Or. Len(aC) == 0
        Return {.F., "emitente_ou_certificado_nao_configurado", ""}
    EndIf
    If Len(aD) == 0 .Or. !(aD[5] == "55") .Or. !(aD[1] == "AUTORIZADA")
        Return {.F., "so_nfe_modelo_55_autorizada_aceita_carta_de_correcao", ""}
    EndIf
    If Len(GEBDFETXT(cTexto, 1000)) < 15
        Return {.F., "correcao_com_pelo_menos_15_letras", ""}
    EndIf
    aH := TCSqlQuery("SELECT COALESCE(MAX(GDF6_SEQ), 0) AS N FROM GDF6 WHERE GDF6_FILIAL = " + GEBDBQuote(FWxFilial("GDF6")) + " AND GDF6_CHAVE = " + ;
        GEBDBQuote(cChave) + " AND GDF6_TIPO = 'CCE' AND GDF6_CSTAT IN ('135', '136') AND D_E_L_E_T_ = ' '")
    nSeq := BOVAL(aH[1]:N) + 1
    If nSeq > 20
        Return {.F., "limite_de_20_cartas_de_correcao", ""}
    EndIf
    aNow := GEBDFEAGORA(oE["UF"])
    cEv := GEBDFEEVCCE(cChave, oE["CNPJ"], aD[8], cTexto, aNow[3], nSeq)
    aA := GEBDFEASSINA(cEv, "infEvento", "evento", MemoRead(aC[5]), MemoRead(aC[4]))
    If !aA[1]
        Return {.F., aA[2], ""}
    EndIf
    aEnv := GEBDFEENVIA("55", oE["UF"], aD[8], "RecepcaoEvento", GEBDFELOTEEV(aA[3], StrZero(Val(BOSEQ("DFE_LOTE", 9)), 15)))
    If !aEnv[1]
        Return {.F., aEnv[3] + ": tente de novo", ""}
    EndIf
    cRet := GEBDFEBLOCO(aEnv[2], "retEvento")
    cCStat := GEBDFETAG(cRet, "cStat")
    cMot := GEBDFETAG(cRet, "xMotivo")
    cProt := GEBDFETAG(cRet, "nProt")
    TCSqlExec("INSERT INTO GDF6 (D_E_L_E_T_, GDF6_FILIAL, GDF6_CHAVE, GDF6_TIPO, GDF6_SEQ, GDF6_CSTAT, GDF6_MOTIVO, GDF6_PROT, GDF6_DH, GDF6_JUST, GDF6_XML, " + ;
        "GDF6_MOD, GDF6_SERIE, GDF6_NINI, GDF6_NFIM) VALUES (' ', " + GEBDBQuote(FWxFilial("GDF6")) + ", " + GEBDBQuote(cChave) + ", 'CCE', " + ;
        BONUM(nSeq, 0) + ", " + GEBDBQuote(cCStat) + ", " + GEBDBQuote(Left(cMot, 250)) + ", " + GEBDBQuote(cProt) + ", " + GEBDBQuote(aNow[3]) + ", " + ;
        GEBDBQuote(cTexto) + ", " + GEBDBQuote('<procEventoNFe xmlns="http://www.portalfiscal.inf.br/nfe" versao="1.00">' + aA[3] + cRet + "</procEventoNFe>") + ;
        ", '55', " + BONUM(aD[6], 0) + ", " + BONUM(aD[7], 0) + ", " + BONUM(aD[7], 0) + ")")
    If !(cCStat == "135" .Or. cCStat == "136")
        Return {.F., "carta_de_correcao_rejeitada: " + cCStat + " - " + cMot, ""}
    EndIf
Return {.T., "carta de correcao " + cValToChar(nSeq) + " registrada: protocolo " + cProt, cProt}
