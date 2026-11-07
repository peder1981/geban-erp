#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBDFE_XML.prw"
#include "GEBDFE_CAD.prw"
#include "GEBDFE_DIST.prw"

/*/{Protheus.doc} GEBDFE_EFD
    EFD ICMS/IPI (SPED Fiscal) da filial, gerada dos XML guardados:
    - saidas e entradas de emissao propria (GDF5, modelos 55 e 65): C100 +
      C101 (DIFAL) + C190; sem C170 (excecao do Guia para NF-e propria);
      canceladas (02), denegadas (04) e numeros inutilizados (05) so' com a
      identificacao.
    - entradas de terceiros importadas da distribuicao (GDF8 ENT + GCQ4 +
      GDFE): C100 + C170 com o codigo do item do GEBAN (de-para GDFF) +
      C190; 0150, 0190, 0200 e 0220 dos participantes e itens usados.
    - E110/E116 (operacoes proprias), E200/E210/E250 (ST retido por UF),
      E300/E310/E316 (DIFAL e FCP por UF de destino); saldo credor
      transportado guardado por competencia em GDFG.
    - blocos B, D, G, H, K sem movimento; 1010 tudo N; bloco 9 contado.
    Formato: campos entre pipes, decimal com virgula, datas DDMMAAAA,
    linhas com CRLF, texto ASCII (sem acento: valido em Latin-1).
    Campos e ordem pelos leiautes do Guia Pratico (COD_VER por ano: 2026 =
    020). A conferencia final e' do PVA da Receita.
    @type Modulo fiscal
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBDFEEFDMIG()
Return BOMIG() .And. BOTAB("GDFG", "GDFG_COMP TEXT NOT NULL, GDFG_FIN TEXT NOT NULL, GDFG_SLDCRED NUMERIC(18,2) NOT NULL, " + ;
    "GDFG_RECOLHER NUMERIC(18,2) NOT NULL, GDFG_LINHAS INTEGER NOT NULL, GDFG_DATA TEXT NOT NULL, GDFG_ARQ TEXT NOT NULL", "GDFG_COMP")

// Versao do leiaute pelo ano da competencia (DFE_EFD_CODVER sobrepoe).
User Function GEBDFEEFDVER(cComp)
    Local nAno := Val(Left(cComp, 4))
    If nAno >= 2027
        Return "021"
    EndIf
    If nAno <= 2023
        Return "017"
    EndIf
Return StrZero(nAno - 2006, 3)

/*/{Protheus.doc} GEBDFEEFD
    Gera, guarda (GDFG) e devolve a EFD ICMS/IPI da competencia.
    @type Obrigacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @param cComp, character, competencia AAAAMM
    @param cFin, character, 0 original, 1 substituto
    @return array, {lOk, cMsg, cArquivo, {nDebitos, nCreditos, nRecolher, nSldCredor, nDocs, nLinhas}}
/*/
User Function GEBDFEEFD(cComp, cFin)
    Local oE := Nil
    Local oP := JsonObject():New()
    Local aDocs := {}
    Local aItens := {}
    Local aH := {}
    Local aDet := {}
    Local aMapa := {}
    Local aF := {}
    Local aR := {}
    Local aCont := {}
    Local aContP := {"NOME", "CPF", "CRC", "CNPJ", "CEP", "END", "NUM", "COMPL", "BAIRRO", "FONE", "FAX", "EMAIL", "MUN"}
    Local cIni := ""
    Local cFim := ""
    Local cAmb := ""
    Local cFil := ""
    Local cSit := ""
    Local cX := ""
    Local cP := ""
    Local cFalta := ""
    Local cAviso := ""
    Local nI := 0
    Local nJ := 0
    Local nN := 0
    cComp := BOCOL(cComp)
    cFin := BOCOL(cFin)
    If cFin == ""
        cFin := "0"
    EndIf
    If !BOCOMPOK(cComp)
        Return {.F., "competencia_invalida (AAAAMM)", "", {}}
    EndIf
    If !(cFin == "0" .Or. cFin == "1")
        Return {.F., "finalidade_invalida (0 original, 1 substituto)", "", {}}
    EndIf
    If !GEBDFEEFDMIG() .Or. !GEBDFECADMIG() .Or. !GEBDFENFEMIG() .Or. !GEBDFEDISTMIG()
        Return {.F., "falha_tabelas", "", {}}
    EndIf
    oE := GEBDFEEMITLE()
    If oE == Nil
        Return {.F., "emitente_nao_cadastrado", "", {}}
    EndIf
    If !(oE["CRT"] == "3" .Or. oE["CRT"] == "2") .And. !(Upper(BOPARM("DFE_EFD_SIMPLES", "N")) == "S")
        Return {.F., "efd_icms_ipi_e_do_regime_normal: empresa do Simples Nacional so' entrega com obrigacao da UF (DFE_EFD_SIMPLES=S)", "", {}}
    EndIf
    For nI := 1 To Len(aContP)
        aAdd(aCont, BOPARM("DFE_EFD_CONT_" + aContP[nI], ""))
    Next nI
    If aCont[1] == "" .Or. aCont[3] == "" .Or. aCont[12] == "" .Or. !(Len(GEBDFEDIG(aCont[2])) == 11) .Or. !GEBDFEDOCOK(aCont[2]) .Or. ;
            GEBDFEMUNNOME(GEBDFEDIG(aCont[13])) == ""
        Return {.F., "contabilista_incompleto: informe nome, CPF, CRC, e-mail e municipio IBGE (configuracao EFD)", "", {}}
    EndIf
    cIni := cComp + "01"
    cFim := BODTADD(BOMESADD(cComp, 1) + "01", -1)
    cAmb := BOPARM("DFE_AMBIENTE", "2")
    cFil := GEBDBQuote(FWxFilial("GDF5"))

    aH := TCSqlQuery("SELECT COUNT(*) AS N FROM GDF5 WHERE GDF5_FILIAL = " + cFil + " AND GDF5_STATUS IN ('CONTINGENCIA', 'PENDENTE') " + ;
        "AND GDF5_DATA BETWEEN " + GEBDBQuote(cIni) + " AND " + GEBDBQuote(cFim) + " AND D_E_L_E_T_ = ' '")
    If BOVAL(aH[1]:N) > 0
        Return {.F., "documentos_pendentes_na_competencia: " + BONUM(aH[1]:N, 0) + " em contingencia ou pendente; transmita/resolva antes", "", {}}
    EndIf

    // Emissao propria.
    aH := TCSqlQuery("SELECT GDF5_CHAVE AS C, GDF5_MOD AS M, GDF5_SERIE AS S, GDF5_NNF AS N, GDF5_STATUS AS ST, GDF5_XML AS X FROM GDF5 " + ;
        "WHERE GDF5_FILIAL = " + cFil + " AND GDF5_MOD IN ('55', '65') AND GDF5_TPAMB = " + GEBDBQuote(cAmb) + ;
        " AND GDF5_STATUS IN ('AUTORIZADA', 'CANCELADA', 'DENEGADA') AND GDF5_DATA BETWEEN " + GEBDBQuote(cIni) + " AND " + GEBDBQuote(cFim) + ;
        " AND D_E_L_E_T_ = ' ' ORDER BY GDF5_MOD, GDF5_SERIE, GDF5_NNF")
    For nI := 1 To Len(aH)
        cSit := "00"
        If BOCOL(aH[nI]:ST) == "CANCELADA"
            cSit := "02"
        ElseIf BOCOL(aH[nI]:ST) == "DENEGADA"
            cSit := "04"
        EndIf
        aAdd(aDocs, {BOSTR(aH[nI]:X), cSit, .T., "", {}, BOCOL(aH[nI]:M), BONUM(aH[nI]:S, 0), BONUM(aH[nI]:N, 0), BOCOL(aH[nI]:C)})
    Next nI
    aH := TCSqlQuery("SELECT GDF6_MOD AS M, GDF6_SERIE AS S, GDF6_NINI AS I, GDF6_NFIM AS F FROM GDF6 WHERE GDF6_FILIAL = " + cFil + ;
        " AND GDF6_TIPO = 'INUT' AND GDF6_CSTAT = '102' AND REPLACE(LEFT(GDF6_DH, 10), '-', '') BETWEEN " + GEBDBQuote(cIni) + " AND " + ;
        GEBDBQuote(cFim) + " AND D_E_L_E_T_ = ' ' ORDER BY 1, 2, 3")
    For nI := 1 To Len(aH)
        For nN := BOVAL(aH[nI]:I) To BOVAL(aH[nI]:F)
            aAdd(aDocs, {"", "05", .T., "", {}, BOCOL(aH[nI]:M), BONUM(aH[nI]:S, 0), BONUM(nN, 0), ""})
        Next nN
    Next nI

    // Entradas de terceiros com a nota completa recebida.
    aH := TCSqlQuery("SELECT V.GDF8_CHAVE AS C, V.GDF8_PART AS P, E.GCQ4_DATA AS D, N.GDFE_XML AS X, N.GDFE_SIT AS S FROM GDF8 V " + ;
        "JOIN GCQ4 E ON E.GCQ4_FILIAL = V.GDF8_FILIAL AND E.GCQ4_NF = V.GDF8_DOC AND E.GCQ4_FORN = V.GDF8_PART AND E.D_E_L_E_T_ = ' ' " + ;
        "LEFT JOIN GDFE N ON N.GDFE_FILIAL = V.GDF8_FILIAL AND N.GDFE_CHAVE = V.GDF8_CHAVE AND N.D_E_L_E_T_ = ' ' " + ;
        "WHERE V.GDF8_FILIAL = " + cFil + " AND V.GDF8_TIPO = 'ENT' AND V.D_E_L_E_T_ = ' ' AND E.GCQ4_DATA BETWEEN " + GEBDBQuote(cIni) + ;
        " AND " + GEBDBQuote(cFim) + " ORDER BY E.GCQ4_DATA, V.GDF8_CHAVE")
    For nI := 1 To Len(aH)
        cX := BOSTR(aH[nI]:X)
        If !("<det " $ cX) .Or. BOCOL(aH[nI]:S) == "CANCELADA"
            cAviso += " " + BOCOL(aH[nI]:C)
            Loop
        EndIf
        aMapa := {}
        aDet := GEBDFEEFDBLOCOS(cX, "det")
        For nJ := 1 To Len(aDet)
            cP := GEBDFETAG(aDet[nJ], "cProd")
            aF := TCSqlQuery("SELECT GDFF_PROD AS P, GDFF_FATOR AS F FROM GDFF WHERE GDFF_FILIAL = " + cFil + " AND GDFF_FORN = " + ;
                GEBDBQuote(BOCOL(aH[nI]:P)) + " AND GDFF_CPROD = " + GEBDBQuote(cP) + " AND D_E_L_E_T_ = ' '")
            If Len(aF) == 0
                cFalta += " " + BOCOL(aH[nI]:P) + "/" + cP
                Loop
            EndIf
            aAdd(aMapa, {BOCOL(aF[1]:P), BOVAL(aF[1]:F)})
            If AScan(aItens, {|a| a[1] == BOCOL(aF[1]:P)}) == 0
                aAdd(aItens, EFDItemCad(BOCOL(aF[1]:P)))
            EndIf
        Next nJ
        aAdd(aDocs, {cX, "00", .F., BOCOL(aH[nI]:D), aMapa, "55", "", "", BOCOL(aH[nI]:C)})
    Next nI
    If !(cFalta == "")
        Return {.F., "itens_sem_de_para (fornecedor/produto):" + cFalta, "", {}}
    EndIf
    aH := TCSqlQuery("SELECT COUNT(*) AS N FROM GCQ4 E WHERE E.GCQ4_FILIAL = " + cFil + " AND E.D_E_L_E_T_ = ' ' AND E.GCQ4_DATA BETWEEN " + ;
        GEBDBQuote(cIni) + " AND " + GEBDBQuote(cFim) + " AND NOT EXISTS (SELECT 1 FROM GDF8 V WHERE V.GDF8_FILIAL = E.GCQ4_FILIAL " + ;
        "AND V.GDF8_TIPO = 'ENT' AND V.GDF8_DOC = E.GCQ4_NF AND V.GDF8_PART = E.GCQ4_FORN AND V.D_E_L_E_T_ = ' ')")
    If BOVAL(aH[1]:N) > 0
        cAviso += " " + BONUM(aH[1]:N, 0) + "_entrada(s)_sem_chave"
    EndIf

    oP["COMP"] := cComp
    oP["FIN"] := cFin
    oP["CODVER"] := BOPARM("DFE_EFD_CODVER", GEBDFEEFDVER(cComp))
    oP["PERFIL"] := Upper(BOPARM("DFE_EFD_PERFIL", "A"))
    oP["ATIV"] := BOPARM("DFE_EFD_ATIV", "1")
    oP["COD_REC"] := BOPARM("DFE_EFD_COD_REC", "")
    oP["COD_REC_ST"] := BOPARM("DFE_EFD_COD_REC_ST", "")
    oP["COD_REC_DIFAL"] := BOPARM("DFE_EFD_COD_REC_DIFAL", "")
    oP["COD_REC_FCP"] := BOPARM("DFE_EFD_COD_REC_FCP", "")
    oP["DIA_VENC"] := Val(BOPARM("DFE_EFD_DIA_VENC", "20"))
    oP["SLD_CRED_ANT"] := Val(BOPARM("DFE_EFD_SLD_CRED_INI", "0"))
    aH := TCSqlQuery("SELECT GDFG_SLDCRED AS S FROM GDFG WHERE GDFG_FILIAL = " + cFil + " AND GDFG_COMP = " + GEBDBQuote(BOMESADD(cComp, -1)) + ;
        " AND D_E_L_E_T_ = ' '")
    If Len(aH) > 0
        oP["SLD_CRED_ANT"] := BOVAL(aH[1]:S)
    EndIf
    oP["CONT"] := aCont
    oP["ITENS"] := aItens

    aR := GEBDFEEFDTXT(oE, oP, aDocs)
    If !aR[1]
        Return {.F., aR[2], "", {}}
    EndIf
    If aR[4][3] > 0 .And. oP["COD_REC"] == ""
        Return {.F., "codigo_de_receita_do_icms_nao_configurado (EFD_COD_REC): ha ICMS a recolher", "", {}}
    EndIf
    TCSqlExec("UPDATE GDFG SET D_E_L_E_T_ = '*' WHERE GDFG_FILIAL = " + cFil + " AND GDFG_COMP = " + GEBDBQuote(cComp) + " AND D_E_L_E_T_ = ' '")
    If !TCSqlExec("INSERT INTO GDFG (D_E_L_E_T_, GDFG_FILIAL, GDFG_COMP, GDFG_FIN, GDFG_SLDCRED, GDFG_RECOLHER, GDFG_LINHAS, GDFG_DATA, GDFG_ARQ) VALUES (' ', " + ;
            cFil + ", " + GEBDBQuote(cComp) + ", " + GEBDBQuote(cFin) + ", " + BONUM(aR[4][4], 2) + ", " + BONUM(aR[4][3], 2) + ", " + ;
            BONUM(aR[4][6], 0) + ", " + GEBDBQuote(BOHOJE()) + ", " + GEBDBQuote(aR[3]) + ")")
        Return {.F., "falha_gravacao", "", {}}
    EndIf
    If !(cAviso == "")
        aR[2] += "; fora do arquivo (sem XML da nota ou cancelada):" + cAviso
    EndIf
    If Right(cComp, 2) == "02"
        aR[2] += "; fevereiro: o inventario de 31/12 (bloco H) nao e' gerado, informe-o pelo PVA"
    EndIf
Return aR

// Arquivo guardado da competencia ("" se nao gerado).
User Function GEBDFEEFDLE(cComp)
    Local aH := {}
    GEBDFEEFDMIG()
    aH := TCSqlQuery("SELECT GDFG_ARQ AS A FROM GDFG WHERE GDFG_FILIAL = " + GEBDBQuote(FWxFilial("GDFG")) + " AND GDFG_COMP = " + ;
        GEBDBQuote(BOCOL(cComp)) + " AND D_E_L_E_T_ = ' '")
    If Len(aH) == 0
        Return ""
    EndIf
Return BOSTR(aH[1]:A)

// Item do GEBAN para o 0200: {cod, descr, unid, gtin, ncm, cest}.
Static Function EFDItemCad(cProd)
    Local aH := TCSqlQuery("SELECT P.GF1_DESC AS D, P.GF1_NCM AS N, F.GDF4_UNID AS U, F.GDF4_GTIN AS G, F.GDF4_CEST AS C FROM GF1 P " + ;
        "LEFT JOIN GDF4 F ON F.GDF4_FILIAL = P.GF1_FILIAL AND F.GDF4_PROD = P.GF1_COD AND F.D_E_L_E_T_ = ' ' WHERE P.GF1_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GF1")) + " AND P.GF1_COD = " + GEBDBQuote(cProd) + " AND P.D_E_L_E_T_ = ' '")
    Local cU := ""
    If Len(aH) == 0
        Return {cProd, cProd, BOPARM("DFE_UNIDADE", "UN"), "", "", ""}
    EndIf
    cU := BOCOL(aH[1]:U)
    If cU == ""
        cU := BOPARM("DFE_UNIDADE", "UN")
    EndIf
Return {cProd, BOCOL(aH[1]:D), cU, BOCOL(aH[1]:G), BOCOL(aH[1]:N), BOCOL(aH[1]:C)}

/*/{Protheus.doc} GEBDFEEFDTXT
    Monta o arquivo (funcao pura, sem banco).
    @type Obrigacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @param oE, object, emitente (GEBDFEEMITLE)
    @param oP, object, COMP, FIN, CODVER, PERFIL, ATIV, COD_REC, COD_REC_ST, COD_REC_DIFAL, COD_REC_FCP, DIA_VENC, SLD_CRED_ANT,
        CONT (13 campos do 0100), ITENS ({cod, descr, unid, gtin, ncm, cest})
    @param aDocs, array, {cXml, cCodSit, lPropria, cDtEntrada AAAAMMDD, {{cItem, nFator} por det}, cMod, cSerie, cNum, cChave}
    @return array, {lOk, cMsg, cArquivo, {nDebitos, nCreditos, nRecolher, nSldCredor, nDocs, nLinhas}}
/*/
User Function GEBDFEEFDTXT(oE, oP, aDocs)
    Local aC := {}
    Local aL := {}
    Local aPart := {}
    Local aUni := {}
    Local aItU := {}
    Local aConv := {}
    Local aSt := {}
    Local aDif := {}
    Local aDet := {}
    Local aG := {}
    Local aV := {}
    Local aIt := {}
    Local aV2 := {}
    Local aCont := oP["CONT"]
    Local aItens := oP["ITENS"]
    Local cComp := oP["COMP"]
    Local cIni := cComp + "01"
    Local cFim := BODTADD(BOMESADD(cComp, 1) + "01", -1)
    Local cVenc := ""
    Local cX := ""
    Local cIde := ""
    Local cTot := ""
    Local cPart := ""
    Local cUFD := ""
    Local cIcms := ""
    Local cCst := ""
    Local cCfop := ""
    Local cTxt := ""
    Local cReg := ""
    Local lNfce := .F.
    Local nDeb := 0
    Local nCred := 0
    Local nSld := 0
    Local nRec := 0
    Local nTransp := 0
    Local nBC := 0
    Local nIcms := 0
    Local nI := 0
    Local nJ := 0
    Local nK := 0
    Local nP := 0
    Local nOpr := 0
    Local nRed := 0
    Local nDocs := 0

    cVenc := EFDData(BOMESADD(cComp, 1) + StrZero(oP["DIA_VENC"], 2))
    aAdd(aC, {"C001", "0"})
    For nI := 1 To Len(aDocs)
        cX := aDocs[nI][1]
        If !(aDocs[nI][2] == "00")
            // Cancelado, denegado ou inutilizado: so' a identificacao.
            aV := {"C100", "1", "0", "", aDocs[nI][6], aDocs[nI][2], aDocs[nI][7], aDocs[nI][8], aDocs[nI][9]}
            If !(cX == "")
                aV[2] := GEBDFETAG(GEBDFEBLOCO(cX, "ide"), "tpNF")
            EndIf
            For nJ := 1 To 20
                aAdd(aV, "")
            Next nJ
            aAdd(aC, aV)
            nDocs++
            Loop
        EndIf
        nDocs++
        cIde := GEBDFEBLOCO(cX, "ide")
        cTot := GEBDFEBLOCO(cX, "ICMSTot")
        lNfce := GEBDFETAG(cIde, "mod") == "65"
        cPart := ""
        cUFD := oE["UF"]
        If aDocs[nI][3]
            If !lNfce .And. !(GEBDFEBLOCO(cX, "dest") == "")
                cPart := EFDPart(aPart, GEBDFEBLOCO(cX, "dest"), "enderDest")
                cUFD := GEBDFETAG(GEBDFEBLOCO(cX, "enderDest"), "UF")
            EndIf
        Else
            cPart := EFDPart(aPart, GEBDFEBLOCO(cX, "emit"), "enderEmit")
        EndIf
        aV := {"C100", GEBDFETAG(cIde, "tpNF"), "0", cPart, GEBDFETAG(cIde, "mod"), "00", GEBDFETAG(cIde, "serie"), GEBDFETAG(cIde, "nNF"), ;
            EFDChave(cX), EFDData(GEBDFETAG(cIde, "dhEmi")), "", EFDV(cTot, "vNF"), "0", EFDV(cTot, "vDesc"), "0,00", ;
            EFDV(cTot, "vProd"), GEBDFETAG(GEBDFEBLOCO(cX, "transp"), "modFrete"), EFDV(cTot, "vFrete"), EFDV(cTot, "vSeg"), EFDV(cTot, "vOutro"), ;
            "", "", EFDV(cTot, "vBCST"), EFDV(cTot, "vST"), EFDV(cTot, "vIPI"), EFDV(cTot, "vPIS"), EFDV(cTot, "vCOFINS"), "", ""}
        If aDocs[nI][3]
            aV[11] := EFDData(GEBDFETAG(cIde, "dhSaiEnt"))
            If aV[11] == ""
                aV[11] := aV[10]
            EndIf
        Else
            aV[2] := "0"
            aV[3] := "1"
            aV[11] := EFDData(aDocs[nI][4])
        EndIf
        If "<dup>" $ cX
            aV[13] := "1"
        EndIf
        If lNfce
            aV[17] := "9"
            For nJ := 23 To 29
                aV[nJ] := ""
            Next nJ
        EndIf

        // Itens: C170 (so' terceiros) e grupos do C190.
        aG := {}
        aIt := {}
        nBC := 0
        nIcms := 0
        aDet := GEBDFEEFDBLOCOS(cX, "det")
        For nJ := 1 To Len(aDet)
            cIcms := GEBDFEBLOCO(aDet[nJ], "ICMS")
            cCst := GEBDFETAG(cIcms, "orig") + GEBDFETAG(cIcms, "CST")
            If Len(cCst) < 3
                // ponytail: CSOSN de fornecedor do Simples vira 90 (sem credito); credito do art. 23 da LC 123 nao e' lancado
                cCst := GEBDFETAG(cIcms, "orig") + "90"
            EndIf
            cCfop := GEBDFETAG(aDet[nJ], "CFOP")
            nOpr := EFDN(aDet[nJ], "vProd") - EFDN(aDet[nJ], "vDesc") + EFDN(aDet[nJ], "vFrete") + EFDN(aDet[nJ], "vSeg") + EFDN(aDet[nJ], "vOutro")
            aV2 := {EFDN(cIcms, "vBC"), EFDN(cIcms, "pICMS"), EFDN(cIcms, "vICMS"), EFDN(cIcms, "vBCST"), EFDN(cIcms, "pICMSST"), ;
                EFDN(cIcms, "vICMSST"), EFDN(GEBDFEBLOCO(aDet[nJ], "IPI"), "vIPI")}
            If !aDocs[nI][3]
                cCfop := EFDCfopEnt(cCfop)
                If !(Right(cCst, 2) $ "00|10|20|51|70|90")
                    aV2[1] := 0
                    aV2[2] := 0
                    aV2[3] := 0
                EndIf
                nP := AScan(aItU, aDocs[nI][5][nJ][1])
                If nP == 0
                    aAdd(aItU, aDocs[nI][5][nJ][1])
                EndIf
                nK := AScan(aItens, {|a| a[1] == aDocs[nI][5][nJ][1]})
                If !(Upper(GEBDFETAG(aDet[nJ], "uCom")) == Upper(aItens[nK][3])) .And. ;
                        AScan(aConv, {|a| a[1] == aItens[nK][1] .And. a[2] == Upper(GEBDFETAG(aDet[nJ], "uCom"))}) == 0
                    aAdd(aConv, {aItens[nK][1], Upper(GEBDFETAG(aDet[nJ], "uCom")), aDocs[nI][5][nJ][2]})
                EndIf
                EFDUni(aUni, GEBDFETAG(aDet[nJ], "uCom"))
                aAdd(aIt, {"C170", cValToChar(nJ), aDocs[nI][5][nJ][1], EFDT(GEBDFETAG(aDet[nJ], "xProd"), 255), ;
                    EFDNum(EFDN(aDet[nJ], "qCom"), 5), Upper(GEBDFETAG(aDet[nJ], "uCom")), EFDNum(EFDN(aDet[nJ], "vProd"), 2), ;
                    EFDNum(EFDN(aDet[nJ], "vDesc"), 2), "0", cCst, cCfop, "", EFDNum(aV2[1], 2), EFDNum(aV2[2], 2), EFDNum(aV2[3], 2), ;
                    EFDNum(aV2[4], 2), EFDNum(aV2[5], 2), EFDNum(aV2[6], 2), "", "", "", "", "", EFDNum(aV2[7], 2), ;
                    "", "", "", "", "", "", "", "", "", "", "", "", "", ""})
                nBC += aV2[1]
                nIcms += aV2[3]
            EndIf
            nRed := 0
            If Right(cCst, 2) == "20" .Or. Right(cCst, 2) == "70"
                nRed := nOpr - aV2[1]
            EndIf
            nOpr += aV2[6] + EFDN(cIcms, "vFCPST") + aV2[7]
            nP := AScan(aG, {|a| a[1] == cCst .And. a[2] == cCfop .And. a[3] == aV2[2]})
            If nP == 0
                aAdd(aG, {cCst, cCfop, aV2[2], 0, 0, 0, 0, 0, 0, 0})
                nP := Len(aG)
            EndIf
            aG[nP][4] += nOpr
            aG[nP][5] += aV2[1]
            aG[nP][6] += aV2[3]
            aG[nP][7] += aV2[4]
            aG[nP][8] += aV2[6]
            aG[nP][9] += nRed
            aG[nP][10] += aV2[7]
        Next nJ
        If !aDocs[nI][3]
            // Entrada de terceiro: o C100 leva o ICMS creditado.
            aV[21] := EFDNum(nBC, 2)
            aV[22] := EFDNum(nIcms, 2)
        Else
            aV[21] := EFDV(cTot, "vBC")
            aV[22] := EFDV(cTot, "vICMS")
        EndIf
        aAdd(aC, aV)
        If EFDN(cTot, "vICMSUFDest") + EFDN(cTot, "vFCPUFDest") > 0
            aAdd(aC, {"C101", EFDV(cTot, "vFCPUFDest"), EFDV(cTot, "vICMSUFDest"), EFDV(cTot, "vICMSUFRemet")})
            nP := AScan(aDif, {|a| a[1] == cUFD})
            If nP == 0
                aAdd(aDif, {cUFD, 0, 0})
                nP := Len(aDif)
            EndIf
            aDif[nP][2] += EFDN(cTot, "vICMSUFDest")
            aDif[nP][3] += EFDN(cTot, "vFCPUFDest")
        EndIf
        For nJ := 1 To Len(aIt)
            aAdd(aC, aIt[nJ])
        Next nJ
        For nJ := 1 To Len(aG)
            aAdd(aC, {"C190", aG[nJ][1], aG[nJ][2], EFDNum(aG[nJ][3], 2), EFDNum(aG[nJ][4], 2), EFDNum(aG[nJ][5], 2), EFDNum(aG[nJ][6], 2), ;
                EFDNum(aG[nJ][7], 2), EFDNum(aG[nJ][8], 2), EFDNum(aG[nJ][9], 2), EFDNum(aG[nJ][10], 2), ""})
            If Left(aG[nJ][2], 1) $ "567"
                nDeb += aG[nJ][6]
                If aG[nJ][8] > 0
                    nP := AScan(aSt, {|a| a[1] == cUFD})
                    If nP == 0
                        aAdd(aSt, {cUFD, 0})
                        nP := Len(aSt)
                    EndIf
                    aSt[nP][2] += aG[nJ][8]
                EndIf
            Else
                nCred += aG[nJ][6]
            EndIf
        Next nJ
    Next nI
    aAdd(aC, {"C990", ""})

    // Bloco 0.
    aAdd(aL, {"0000", oP["CODVER"], oP["FIN"], EFDData(cIni), EFDData(cFim), EFDT(oE["XNOME"], 100), oE["CNPJ"], "", oE["UF"], oE["IE"], ;
        oE["CMUN"], EFDT(oE["IM"], 30), "", oP["PERFIL"], oP["ATIV"]})
    aAdd(aL, {"0001", "0"})
    aAdd(aL, {"0005", EFDT(oE["XFANT"], 60), oE["CEP"], EFDT(oE["XLGR"], 60), EFDT(oE["NRO"], 10), EFDT(oE["XCPL"], 60), EFDT(oE["XBAIRRO"], 60), ;
        Right(GEBDFEDIG(oE["FONE"]), 11), "", EFDT(oE["EMAIL"], 60)})
    aAdd(aL, {"0100", EFDT(aCont[1], 100), GEBDFEDIG(aCont[2]), EFDT(aCont[3], 15), GEBDFEDIG(aCont[4]), GEBDFEDIG(aCont[5]), EFDT(aCont[6], 60), ;
        EFDT(aCont[7], 10), EFDT(aCont[8], 60), EFDT(aCont[9], 60), Right(GEBDFEDIG(aCont[10]), 11), Right(GEBDFEDIG(aCont[11]), 11), ;
        EFDT(aCont[12], 60), GEBDFEDIG(aCont[13])})
    For nI := 1 To Len(aPart)
        aAdd(aL, aPart[nI])
    Next nI
    For nI := 1 To Len(aItU)
        nK := AScan(aItens, {|a| a[1] == aItU[nI]})
        EFDUni(aUni, aItens[nK][3])
    Next nI
    For nI := 1 To Len(aUni)
        aAdd(aL, {"0190", aUni[nI], aUni[nI]})
    Next nI
    For nI := 1 To Len(aItU)
        nK := AScan(aItens, {|a| a[1] == aItU[nI]})
        aIt := aItens[nK]
        aAdd(aL, {"0200", aIt[1], EFDT(aIt[2], 255), aIt[4], "", aIt[3], "00", aIt[5], "", Left(aIt[5], 2), "", "", aIt[6]})
        For nJ := 1 To Len(aConv)
            If aConv[nJ][1] == aIt[1]
                aAdd(aL, {"0220", aConv[nJ][2], EFDNum(aConv[nJ][3], 6), ""})
            EndIf
        Next nJ
    Next nI
    aAdd(aL, {"0990", ""})
    aL[Len(aL)][2] := cValToChar(Len(aL))

    aAdd(aL, {"B001", "1"})
    aAdd(aL, {"B990", "2"})
    nK := Len(aL)
    For nI := 1 To Len(aC)
        aAdd(aL, aC[nI])
    Next nI
    aL[Len(aL)][2] := cValToChar(Len(aC))
    aAdd(aL, {"D001", "1"})
    aAdd(aL, {"D990", "2"})

    // Bloco E: apuracao propria, ST e DIFAL.
    nK := Len(aL)
    aAdd(aL, {"E001", "0"})
    aAdd(aL, {"E100", EFDData(cIni), EFDData(cFim)})
    nSld := nDeb - nCred - oP["SLD_CRED_ANT"]
    nRec := 0
    nTransp := 0
    If nSld >= 0
        nRec := Round(nSld, 2)
    Else
        nTransp := Round(-nSld, 2)
    EndIf
    aAdd(aL, {"E110", EFDNum(nDeb, 2), "0,00", "0,00", "0,00", EFDNum(nCred, 2), "0,00", "0,00", "0,00", EFDNum(oP["SLD_CRED_ANT"], 2), ;
        EFDNum(nRec, 2), "0,00", EFDNum(nRec, 2), EFDNum(nTransp, 2), "0,00"})
    If nRec > 0
        aAdd(aL, {"E116", "000", EFDNum(nRec, 2), cVenc, oP["COD_REC"], "", "", "", "", Right(cComp, 2) + Left(cComp, 4)})
    EndIf
    For nI := 1 To Len(aSt)
        aAdd(aL, {"E200", aSt[nI][1], EFDData(cIni), EFDData(cFim)})
        aAdd(aL, {"E210", "1", "0,00", "0,00", "0,00", "0,00", "0,00", EFDNum(aSt[nI][2], 2), "0,00", "0,00", EFDNum(aSt[nI][2], 2), "0,00", ;
            EFDNum(aSt[nI][2], 2), "0,00", "0,00"})
        aAdd(aL, {"E250", EFDCodOr(aSt[nI][1] == oE["UF"], "002", "999"), EFDNum(aSt[nI][2], 2), cVenc, oP["COD_REC_ST"], "", "", "", "", ;
            Right(cComp, 2) + Left(cComp, 4)})
    Next nI
    For nI := 1 To Len(aDif)
        aAdd(aL, {"E300", aDif[nI][1], EFDData(cIni), EFDData(cFim)})
        aAdd(aL, {"E310", "1", "0,00", EFDNum(aDif[nI][2], 2), "0,00", "0,00", "0,00", EFDNum(aDif[nI][2], 2), "0,00", EFDNum(aDif[nI][2], 2), "0,00", ;
            "0,00", "0,00", EFDNum(aDif[nI][3], 2), "0,00", "0,00", "0,00", EFDNum(aDif[nI][3], 2), "0,00", EFDNum(aDif[nI][3], 2), "0,00", "0,00"})
        If aDif[nI][2] > 0
            aAdd(aL, {"E316", "000", EFDNum(aDif[nI][2], 2), cVenc, oP["COD_REC_DIFAL"], "", "", "", "", Right(cComp, 2) + Left(cComp, 4)})
        EndIf
        If aDif[nI][3] > 0
            aAdd(aL, {"E316", "006", EFDNum(aDif[nI][3], 2), cVenc, oP["COD_REC_FCP"], "", "", "", "", Right(cComp, 2) + Left(cComp, 4)})
        EndIf
    Next nI
    aAdd(aL, {"E990", cValToChar(Len(aL) - nK + 1)})
    aAdd(aL, {"G001", "1"})
    aAdd(aL, {"G990", "2"})
    aAdd(aL, {"H001", "1"})
    aAdd(aL, {"H990", "2"})
    aAdd(aL, {"K001", "1"})
    aAdd(aL, {"K990", "2"})
    aAdd(aL, {"1001", "0"})
    aAdd(aL, {"1010", "N", "N", "N", "N", "N", "N", "N", "N", "N", "N", "N", "N", "N"})
    aAdd(aL, {"1990", "3"})

    // Bloco 9: quantidade por registro.
    aG := {}
    For nI := 1 To Len(aL)
        nP := AScan(aG, {|a| a[1] == aL[nI][1]})
        If nP == 0
            aAdd(aG, {aL[nI][1], 0})
            nP := Len(aG)
        EndIf
        aG[nP][2]++
    Next nI
    aAdd(aG, {"9001", 1})
    aAdd(aG, {"9900", Len(aG) + 3})
    aAdd(aG, {"9990", 1})
    aAdd(aG, {"9999", 1})
    nK := Len(aL)
    aAdd(aL, {"9001", "0"})
    For nI := 1 To Len(aG)
        aAdd(aL, {"9900", aG[nI][1], cValToChar(aG[nI][2])})
    Next nI
    aAdd(aL, {"9990", cValToChar(Len(aL) - nK + 2)})
    aAdd(aL, {"9999", cValToChar(Len(aL) + 1)})

    For nI := 1 To Len(aL)
        cReg := "|"
        For nJ := 1 To Len(aL[nI])
            cReg += aL[nI][nJ] + "|"
        Next nJ
        cTxt += cReg + Chr(13) + Chr(10)
    Next nI
Return {.T., "EFD ICMS/IPI " + Right(cComp, 2) + "/" + Left(cComp, 4) + ": " + cValToChar(nDocs) + " documento(s), " + cValToChar(Len(aL)) + ;
    " linhas; debitos " + EFDNum(nDeb, 2) + ", creditos " + EFDNum(nCred, 2) + ", a recolher " + EFDNum(nRec, 2) + ;
    ", saldo credor " + EFDNum(nTransp, 2), cTxt, {nDeb, nCred, nRec, nTransp, nDocs, Len(aL)}}

// Blocos <cTag ...>...</cTag> em ordem.
User Function GEBDFEEFDBLOCOS(cXml, cTag)
    Local aR := {}
    Local cB := ""
    Do While .T.
        cB := GEBDFEBLOCO(cXml, cTag)
        If cB == ""
            Exit
        EndIf
        aAdd(aR, cB)
        cXml := SubStr(cXml, At(cB, cXml) + Len(cB))
    EndDo
Return aR

// Participante (0150) pelo bloco emit/dest; devolve COD_PART (CNPJ ou CPF).
Static Function EFDPart(aPart, cB, cTagEnd)
    Local cEnd := GEBDFEBLOCO(cB, cTagEnd)
    Local cCNPJ := GEBDFETAG(cB, "CNPJ")
    Local cCPF := GEBDFETAG(cB, "CPF")
    Local cCod := cCNPJ + cCPF
    Local cLgr := EFDT(GEBDFETAG(cEnd, "xLgr"), 60)
    If cCod == ""
        Return ""
    EndIf
    If AScan(aPart, {|a| a[2] == cCod}) == 0
        If cLgr == ""
            cLgr := "NAO INFORMADO"
        EndIf
        aAdd(aPart, {"0150", cCod, EFDT(GEBDFETAG(cB, "xNome"), 100), "01058", cCNPJ, cCPF, GEBDFETAG(cB, "IE"), GEBDFETAG(cEnd, "cMun"), "", cLgr, ;
            EFDT(GEBDFETAG(cEnd, "nro"), 10), EFDT(GEBDFETAG(cEnd, "xCpl"), 60), EFDT(GEBDFETAG(cEnd, "xBairro"), 60)})
    EndIf
Return cCod

Static Function EFDUni(aUni, cU)
    cU := Upper(AllTrim(cU))
    If !(cU == "") .And. AScan(aUni, cU) == 0
        aAdd(aUni, cU)
    EndIf
Return Nil

// ponytail: compra para revenda (x101/x102 -> x102; x401/x403/x405 -> x403); demais so' trocam o 1o digito
Static Function EFDCfopEnt(cCfop)
    Local cD := SubStr("123", At(Left(cCfop, 1), "567"), 1)
    Local cR := Right(cCfop, 3)
    If At(Left(cCfop, 1), "567") == 0
        Return cCfop
    EndIf
    If cR == "101" .Or. cR == "102"
        Return cD + "102"
    EndIf
    If cR == "401" .Or. cR == "403" .Or. cR == "405"
        Return cD + "403"
    EndIf
Return cD + cR

Static Function EFDCodOr(lC, cS, cN)
    If lC
        Return cS
    EndIf
Return cN

Static Function EFDChave(cX)
    Local nP := At('Id="NFe', cX)
    If nP == 0
        Return ""
    EndIf
Return SubStr(cX, nP + 7, 44)

// AAAA-MM-DD..., AAAAMMDD -> DDMMAAAA.
Static Function EFDData(cD)
    cD := StrTran(Left(BOSTR(cD), 10), "-", "")
    If Len(cD) < 8
        Return ""
    EndIf
Return Right(cD, 2) + SubStr(cD, 5, 2) + Left(cD, 4)

Static Function EFDN(cX, cTag)
Return Val(GEBDFETAG(cX, cTag))

Static Function EFDV(cX, cTag)
Return EFDNum(EFDN(cX, cTag), 2)

Static Function EFDNum(nV, nDec)
Return StrTran(AllTrim(Str(Round(nV, nDec), 20, nDec)), ".", ",")

// Texto sem acento, sem pipe, sem entidades XML.
Static Function EFDT(cT, nMax)
    cT := StrTran(StrTran(StrTran(StrTran(BOSTR(cT), "&lt;", "<"), "&gt;", ">"), "&quot;", '"'), "&amp;", "&")
    cT := GEBDFETXT(cT, nMax)
Return StrTran(StrTran(StrTran(StrTran(cT, "&lt;", "<"), "&gt;", ">"), "&amp;", "&"), "|", " ")
