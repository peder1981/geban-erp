#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBFIS_MIG.prw"
#include "GEBDFE_XML.prw"
#include "GEBDFE_IE.prw"
#include "GEBDFE_MUN.prw"

/*/{Protheus.doc} GEBDFE_CAD
    Cadastros dos documentos fiscais eletronicos (por empresa e filial):
    - GDF1 emitente (CNPJ, IE, regime, endereco com municipio IBGE).
    - GDF2 certificado A1: o .pfx chega em Base64, e' convertido pelo
      openssl do servidor (ProcRun, sem shell) em cert.pem e key.pem com
      permissao 0600 numa pasta 0700 (DFE_CERT_DIR/<empresa>/<filial>); a
      senha e o .pfx sao apagados na hora. Guarda titular, CNPJ e validade.
    - GDF4 perfil fiscal do produto (unidade, GTIN, CFOP, CSOSN/CST,
      aliquotas, CEST, origem, CST de PIS/COFINS). O que ficar vazio usa o
      padrao da empresa (GEBDFECONFIG); o GTIN vem do codigo de barras da
      loja (GLJ8) quando o perfil nao tiver.
    - GEBDFECONFIG: ambiente, NFC-e ligada, serie, CSC (QR v2), responsavel
      tecnico, padroes fiscais e prazos (parametros DFE_* em GE4).
    - Numeracao por modelo e serie (GBS1, chave DFE<mod><serie>).
    GDF5 (documentos) e GDF6 (eventos) sao usadas por GEBDFE.prw.
    @type Modulo fiscal
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBDFECADMIG()
    Local lOk := GEBFMIG() .And. BOMIG()
    lOk := lOk .And. BOTAB("GDF1", "GDF1_CNPJ TEXT NOT NULL, GDF1_IE TEXT NOT NULL, GDF1_IM TEXT NOT NULL, GDF1_CNAE TEXT NOT NULL, " + ;
        "GDF1_RAZAO TEXT NOT NULL, GDF1_FANTASIA TEXT NOT NULL, GDF1_CRT TEXT NOT NULL, GDF1_LGR TEXT NOT NULL, GDF1_NRO TEXT NOT NULL, " + ;
        "GDF1_CPL TEXT NOT NULL, GDF1_BAIRRO TEXT NOT NULL, GDF1_CMUN TEXT NOT NULL, GDF1_XMUN TEXT NOT NULL, GDF1_UF TEXT NOT NULL, " + ;
        "GDF1_CEP TEXT NOT NULL, GDF1_FONE TEXT NOT NULL, GDF1_EMAIL TEXT NOT NULL", "GDF1_CNPJ")
    lOk := lOk .And. BOTAB("GDF2", "GDF2_CNPJ TEXT NOT NULL, GDF2_TITULAR TEXT NOT NULL, GDF2_VALIDADE TEXT NOT NULL, GDF2_CERT TEXT NOT NULL, " + ;
        "GDF2_KEY TEXT NOT NULL, GDF2_INSTALADO TEXT NOT NULL", "GDF2_CNPJ")
    lOk := lOk .And. BOTAB("GDF4", "GDF4_PROD TEXT NOT NULL, GDF4_UNID TEXT NOT NULL, GDF4_GTIN TEXT NOT NULL, GDF4_CFOP TEXT NOT NULL, " + ;
        "GDF4_CSOSN TEXT NOT NULL, GDF4_CST TEXT NOT NULL, GDF4_PICMS NUMERIC(8,4) NOT NULL, GDF4_CEST TEXT NOT NULL, GDF4_ORIG TEXT NOT NULL, " + ;
        "GDF4_PISCST TEXT NOT NULL, GDF4_COFCST TEXT NOT NULL, GDF4_PPIS NUMERIC(8,4) NOT NULL, GDF4_PCOF NUMERIC(8,4) NOT NULL", "GDF4_PROD")
    lOk := lOk .And. BOTAB("GDFA", "GDFA_PROD TEXT NOT NULL, GDFA_PREDBC NUMERIC(8,4) NOT NULL, GDFA_MVA NUMERIC(8,4) NOT NULL, " + ;
        "GDFA_PICMSST NUMERIC(8,4) NOT NULL, GDFA_PREDBCST NUMERIC(8,4) NOT NULL", "GDFA_PROD")
    lOk := lOk .And. BOTAB("GDFB", "GDFB_UF TEXT NOT NULL, GDFB_NCM TEXT NOT NULL, GDFB_EX TEXT NOT NULL, GDFB_NACF NUMERIC(8,4) NOT NULL, " + ;
        "GDFB_IMPF NUMERIC(8,4) NOT NULL, GDFB_EST NUMERIC(8,4) NOT NULL, GDFB_MUN NUMERIC(8,4) NOT NULL, GDFB_INI TEXT NOT NULL, GDFB_FIM TEXT NOT NULL, " + ;
        "GDFB_VERSAO TEXT NOT NULL, GDFB_FONTE TEXT NOT NULL", "GDFB_UF, GDFB_NCM")
    lOk := lOk .And. BOTAB("GDF5", "GDF5_CHAVE TEXT NOT NULL, GDF5_MOD TEXT NOT NULL, GDF5_SERIE INTEGER NOT NULL, GDF5_NNF INTEGER NOT NULL, " + ;
        "GDF5_TPEMIS TEXT NOT NULL, GDF5_TPAMB TEXT NOT NULL, GDF5_STATUS TEXT NOT NULL, GDF5_CSTAT TEXT NOT NULL, GDF5_MOTIVO TEXT NOT NULL, " + ;
        "GDF5_PROT TEXT NOT NULL, GDF5_DHEMI TEXT NOT NULL, GDF5_DHAUT TEXT NOT NULL, GDF5_ORIGEM TEXT NOT NULL, GDF5_DOC TEXT NOT NULL, " + ;
        "GDF5_VNF NUMERIC(18,2) NOT NULL, GDF5_XML TEXT NOT NULL, GDF5_QR TEXT NOT NULL, GDF5_URLCH TEXT NOT NULL, GDF5_DEST TEXT NOT NULL, " + ;
        "GDF5_CHORIG TEXT NOT NULL, GDF5_DATA TEXT NOT NULL, GDF5_XMLORIG TEXT NOT NULL", "GDF5_CHAVE")
    lOk := lOk .And. BOTAB("GDF6", "GDF6_CHAVE TEXT NOT NULL, GDF6_TIPO TEXT NOT NULL, GDF6_SEQ INTEGER NOT NULL, GDF6_CSTAT TEXT NOT NULL, " + ;
        "GDF6_MOTIVO TEXT NOT NULL, GDF6_PROT TEXT NOT NULL, GDF6_DH TEXT NOT NULL, GDF6_JUST TEXT NOT NULL, GDF6_XML TEXT NOT NULL, " + ;
        "GDF6_MOD TEXT NOT NULL, GDF6_SERIE INTEGER NOT NULL, GDF6_NINI INTEGER NOT NULL, GDF6_NFIM INTEGER NOT NULL", "GDF6_CHAVE")
Return lOk

// CPF (11) ou CNPJ (14) com digitos verificadores; recusa digitos repetidos.
User Function GEBDFEDOCOK(cDoc)
    Local aPesos := {}
    Local cD := GEBDFEDIG(cDoc)
    Local nSoma := 0
    Local nDv := 0
    Local nI := 0
    Local nJ := 0
    If !(Len(cD) == 11 .Or. Len(cD) == 14) .Or. cD == Replicate(Left(cD, 1), Len(cD))
        Return .F.
    EndIf
    For nJ := 1 To 2
        nSoma := 0
        If Len(cD) == 11
            For nI := 1 To 8 + nJ
                nSoma += Val(SubStr(cD, nI, 1)) * (10 + nJ - nI)
            Next nI
            nDv := (nSoma * 10) % 11
            If nDv == 10
                nDv := 0
            EndIf
        Else
            If nJ == 1
                aPesos := {5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2}
            Else
                aPesos := {6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2}
            EndIf
            For nI := 1 To Len(aPesos)
                nSoma += Val(SubStr(cD, nI, 1)) * aPesos[nI]
            Next nI
            nDv := nSoma % 11
            If nDv < 2
                nDv := 0
            Else
                nDv := 11 - nDv
            EndIf
        EndIf
        If !(Val(SubStr(cD, Len(cD) - 2 + nJ, 1)) == nDv)
            Return .F.
        EndIf
    Next nJ
Return .T.

// Nome do municipio pelo codigo IBGE ("" se nao existir).
User Function GEBDFEMUNNOME(cCod)
    Local aT := GEBDFEMUNTAB()
    Local nP := 0
    cCod := GEBDFEDIG(cCod)
    nP := AScan(aT, {|x| Left(x, 8) == cCod + "|"})
    If Len(cCod) != 7 .Or. nP == 0
        Return ""
    EndIf
Return SubStr(aT[nP], 9)

// Municipios da UF cujo nome contem cTexto (sem acento, maiusculas): {{codigo, nome}...}.
User Function GEBDFEMUNBUSCA(cTexto, cUF)
    Local aT := GEBDFEMUNTAB()
    Local aR := {}
    Local cCUF := GEBDFECUF(cUF)
    Local nI := 0
    cTexto := Upper(StrTran(StrTran(StrTran(GEBDFETXT(cTexto, 60), "&amp;", "&"), "&lt;", "<"), "&gt;", ">"))
    For nI := 1 To Len(aT)
        If Left(aT[nI], 2) == cCUF .And. cTexto $ SubStr(aT[nI], 9)
            aAdd(aR, {Left(aT[nI], 7), SubStr(aT[nI], 9)})
        EndIf
    Next nI
Return aR

/*/{Protheus.doc} GEBDFEEMIT
    Grava o emitente da filial. o (JsonObject): CNPJ, IE, IM, CNAE, RAZAO,
    FANTASIA, CRT (1 Simples, 2 Simples excesso, 3 normal, 4 MEI),
    LOGRADOURO, NUMERO, COMPLEMENTO, BAIRRO, MUNICIPIO (codigo IBGE), UF,
    CEP, FONE, EMAIL.
    @type Cadastro fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBDFEEMIT(o)
    Local cFil := FWxFilial("GDF1")
    Local cCNPJ := GEBDFEDIG(BOQ(o, "CNPJ"))
    Local cUF := Upper(BOQ(o, "UF"))
    Local cIE := GEBDFEDIG(BOQ(o, "IE"))
    Local cMun := GEBDFEDIG(BOQ(o, "MUNICIPIO"))
    Local cXMun := ""
    Local cCEP := GEBDFEDIG(BOQ(o, "CEP"))
    Local cCRT := BOQ(o, "CRT")
    If !(Len(cCNPJ) == 14) .Or. !GEBDFEDOCOK(cCNPJ)
        Return {.F., "cnpj_invalido"}
    EndIf
    If GEBDFECUF(cUF) == ""
        Return {.F., "uf_invalida"}
    EndIf
    If cUF == "SP" .And. Left(Upper(BOQ(o, "IE")), 1) == "P"
        cIE := Upper(StrTran(StrTran(StrTran(BOQ(o, "IE"), ".", ""), "-", ""), "/", ""))
    EndIf
    If !GEBDFEIEOK(cIE, cUF)
        Return {.F., "inscricao_estadual_invalida_para_" + cUF}
    EndIf
    If BOQ(o, "RAZAO") == "" .Or. BOQ(o, "LOGRADOURO") == "" .Or. BOQ(o, "BAIRRO") == ""
        Return {.F., "razao_social_logradouro_e_bairro_obrigatorios"}
    EndIf
    If !(cCRT $ "1|2|3|4") .Or. Len(cCRT) != 1
        Return {.F., "regime_invalido (1 Simples, 2 Simples com excesso, 3 normal, 4 MEI)"}
    EndIf
    cXMun := GEBDFEMUNNOME(cMun)
    If cXMun == "" .Or. !(Left(cMun, 2) == GEBDFECUF(cUF))
        Return {.F., "municipio_ibge_invalido_para_" + cUF}
    EndIf
    If !(Len(cCEP) == 8)
        Return {.F., "cep_invalido"}
    EndIf
    If !GEBDFECADMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    TCSqlExec("UPDATE GDF1 SET D_E_L_E_T_ = '*' WHERE GDF1_FILIAL = " + GEBDBQuote(cFil) + " AND D_E_L_E_T_ = ' '")
    If !TCSqlExec("INSERT INTO GDF1 (D_E_L_E_T_, GDF1_FILIAL, GDF1_CNPJ, GDF1_IE, GDF1_IM, GDF1_CNAE, GDF1_RAZAO, GDF1_FANTASIA, GDF1_CRT, " + ;
            "GDF1_LGR, GDF1_NRO, GDF1_CPL, GDF1_BAIRRO, GDF1_CMUN, GDF1_XMUN, GDF1_UF, GDF1_CEP, GDF1_FONE, GDF1_EMAIL) VALUES (' ', " + ;
            GEBDBQuote(cFil) + ", " + GEBDBQuote(cCNPJ) + ", " + GEBDBQuote(cIE) + ", " + GEBDBQuote(BOQ(o, "IM")) + ", " + ;
            GEBDBQuote(GEBDFEDIG(BOQ(o, "CNAE"))) + ", " + GEBDBQuote(BOQ(o, "RAZAO")) + ", " + GEBDBQuote(BOQ(o, "FANTASIA")) + ", " + ;
            GEBDBQuote(cCRT) + ", " + GEBDBQuote(BOQ(o, "LOGRADOURO")) + ", " + GEBDBQuote(BOQ(o, "NUMERO")) + ", " + ;
            GEBDBQuote(BOQ(o, "COMPLEMENTO")) + ", " + GEBDBQuote(BOQ(o, "BAIRRO")) + ", " + GEBDBQuote(cMun) + ", " + GEBDBQuote(cXMun) + ", " + ;
            GEBDBQuote(cUF) + ", " + GEBDBQuote(cCEP) + ", " + GEBDBQuote(GEBDFEDIG(BOQ(o, "FONE"))) + ", " + GEBDBQuote(BOQ(o, "EMAIL")) + ")")
        Return {.F., "falha_gravacao"}
    EndIf
Return {.T., "emitente " + cCNPJ + " gravado (" + cXMun + "/" + cUF + ")"}

/*/{Protheus.doc} GEBDFEEMITLE
    Emitente da filial no formato do montador de XML (EMIT de
    GEBDFEMONTA), ou Nil se nao houver.
    @type Cadastro fiscal
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBDFEEMITLE()
    Local aH := {}
    Local oE := Nil
    If !GEBDFECADMIG()
        Return Nil
    EndIf
    aH := TCSqlQuery("SELECT GDF1_CNPJ AS CNPJ, GDF1_IE AS IE, GDF1_IM AS IM, GDF1_CNAE AS CNAE, GDF1_RAZAO AS RAZAO, GDF1_FANTASIA AS FANT, " + ;
        "GDF1_CRT AS CRT, GDF1_LGR AS LGR, GDF1_NRO AS NRO, GDF1_CPL AS CPL, GDF1_BAIRRO AS BAIRRO, GDF1_CMUN AS CMUN, GDF1_XMUN AS XMUN, " + ;
        "GDF1_UF AS UF, GDF1_CEP AS CEP, GDF1_FONE AS FONE, GDF1_EMAIL AS EMAIL FROM GDF1 WHERE GDF1_FILIAL = " + GEBDBQuote(FWxFilial("GDF1")) + ;
        " AND D_E_L_E_T_ = ' '")
    If Len(aH) == 0
        Return Nil
    EndIf
    oE := JsonObject():New()
    oE["CNPJ"] := BOCOL(aH[1]:CNPJ)
    oE["IE"] := BOCOL(aH[1]:IE)
    oE["IM"] := BOCOL(aH[1]:IM)
    oE["CNAE"] := BOCOL(aH[1]:CNAE)
    oE["XNOME"] := BOCOL(aH[1]:RAZAO)
    oE["XFANT"] := BOCOL(aH[1]:FANT)
    oE["CRT"] := BOCOL(aH[1]:CRT)
    oE["XLGR"] := BOCOL(aH[1]:LGR)
    oE["NRO"] := BOCOL(aH[1]:NRO)
    oE["XCPL"] := BOCOL(aH[1]:CPL)
    oE["XBAIRRO"] := BOCOL(aH[1]:BAIRRO)
    oE["CMUN"] := BOCOL(aH[1]:CMUN)
    oE["XMUN"] := BOCOL(aH[1]:XMUN)
    oE["UF"] := BOCOL(aH[1]:UF)
    oE["CEP"] := BOCOL(aH[1]:CEP)
    oE["FONE"] := BOCOL(aH[1]:FONE)
    oE["EMAIL"] := BOCOL(aH[1]:EMAIL)
Return oE

// Pasta dos certificados da empresa/filial corrente.
User Function GEBDFECERTDIR()
    Local cBase := BOPARM("DFE_CERT_DIR", "")
    Local cFil := AllTrim(FWxFilial("GDF2"))
    If cBase == ""
        cBase := AllTrim(BOSTR(GetEnv("GEBAN_CERT_DIR")))
    EndIf
    If cBase == ""
        cBase := "cert"
    EndIf
    If cFil == ""
        cFil := "00"
    EndIf
Return cBase + "/" + GEBDBTenantAtual() + "/" + cFil

/*/{Protheus.doc} GEBDFECERT
    Instala o certificado A1 da filial. cPfxB64 e' o arquivo .pfx em
    Base64; a senha so' e' usada na conversao (nao fica gravada). Confere:
    conversao, validade, chave do par e CNPJ (raiz igual a do emitente).
    @type Cadastro fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {cTitular, cCNPJ, cValidade}}
/*/
User Function GEBDFECERT(cPfxB64, cSenha)
    Local oE := GEBDFEEMITLE()
    Local cDir := GEBDFECERTDIR()
    Local cPfx := ""
    Local cTmp := ""
    Local cSubj := ""
    Local cCN := ""
    Local cCNPJ := ""
    Local cFim := ""
    Local aOut := {}
    Local aInfo := {}
    Local nRc := 0
    Local nI := 0
    If oE == Nil
        Return {.F., "cadastre_o_emitente_antes_do_certificado", {}}
    EndIf
    cPfx := Decode64(StrTran(StrTran(BOSTR(cPfxB64), Chr(13), ""), Chr(10), ""))
    If Len(cPfx) < 100
        Return {.F., "arquivo_pfx_vazio_ou_invalido", {}}
    EndIf
    If !(ProcRun("mkdir", {"-p", "-m", "700", cDir}, {|c| aAdd(aOut, c)}) == 0)
        Return {.F., "nao_foi_possivel_criar_a_pasta_do_certificado: " + cDir, {}}
    EndIf
    ProcRun("chmod", {"700", cDir}, {|c| aAdd(aOut, c)})
    cTmp := cDir + "/novo"
    MemoWrite(cTmp + ".pfx", cPfx)
    MemoWrite(cTmp + ".pass", BOSTR(cSenha))
    // Primeiro sem e depois com -legacy (A1 antigos usam RC2/3DES).
    nRc := DFEPkcs12(cTmp, {"-clcerts", "-nokeys"}, cTmp + ".cert.pem")
    If nRc == 0
        nRc := DFEPkcs12(cTmp, {"-nocerts", "-nodes"}, cTmp + ".key.pem")
    EndIf
    FErase(cTmp + ".pass")
    FErase(cTmp + ".pfx")
    If !(nRc == 0)
        FErase(cTmp + ".cert.pem")
        FErase(cTmp + ".key.pem")
        Return {.F., "senha_incorreta_ou_arquivo_nao_e_um_certificado_pfx", {}}
    EndIf
    ProcRun("chmod", {"600", cTmp + ".cert.pem"}, {|c| aAdd(aOut, c)})
    ProcRun("chmod", {"600", cTmp + ".key.pem"}, {|c| aAdd(aOut, c)})
    aInfo := PEMInfo(cTmp + ".cert.pem")
    If aInfo == Nil .Or. Len(aInfo) == 0
        Return {.F., "certificado_ilegivel", {}}
    EndIf
    cSubj := BOSTR(aInfo[1][2])
    cFim := StrTran(Left(BOSTR(aInfo[1][5]), 10), "-", "")
    // CN do e-CNPJ: "RAZAO SOCIAL:CNPJ".
    nI := At("CN=", cSubj)
    If nI > 0
        cCN := SubStr(cSubj, nI + 3)
        If At(",", cCN) > 0
            cCN := Left(cCN, At(",", cCN) - 1)
        EndIf
    EndIf
    If RAt(":", cCN) > 0
        cCNPJ := GEBDFEDIG(SubStr(cCN, RAt(":", cCN) + 1))
    EndIf
    If !(Len(cCNPJ) == 14) .Or. !(Left(cCNPJ, 8) == Left(oE["CNPJ"], 8))
        FErase(cTmp + ".cert.pem")
        FErase(cTmp + ".key.pem")
        Return {.F., "certificado_de_outro_cnpj: " + cCNPJ + " (emitente " + oE["CNPJ"] + ")", {}}
    EndIf
    If cFim < BOHOJE()
        FErase(cTmp + ".cert.pem")
        FErase(cTmp + ".key.pem")
        Return {.F., "certificado_vencido_em_" + cFim, {}}
    EndIf
    If !DFEParConfere(cTmp + ".key.pem", cTmp + ".cert.pem")
        FErase(cTmp + ".cert.pem")
        FErase(cTmp + ".key.pem")
        Return {.F., "a_chave_nao_corresponde_ao_certificado", {}}
    EndIf
    FRename(cTmp + ".cert.pem", cDir + "/cert.pem")
    FRename(cTmp + ".key.pem", cDir + "/key.pem")
    If !GEBDFECADMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    TCSqlExec("UPDATE GDF2 SET D_E_L_E_T_ = '*' WHERE GDF2_FILIAL = " + GEBDBQuote(FWxFilial("GDF2")) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GDF2 (D_E_L_E_T_, GDF2_FILIAL, GDF2_CNPJ, GDF2_TITULAR, GDF2_VALIDADE, GDF2_CERT, GDF2_KEY, GDF2_INSTALADO) VALUES (' ', " + ;
        GEBDBQuote(FWxFilial("GDF2")) + ", " + GEBDBQuote(cCNPJ) + ", " + GEBDBQuote(Left(cCN, RAt(":", cCN) - 1)) + ", " + GEBDBQuote(cFim) + ", " + ;
        GEBDBQuote(cDir + "/cert.pem") + ", " + GEBDBQuote(cDir + "/key.pem") + ", " + GEBDBQuote(BOHOJE()) + ")")
Return {.T., "certificado de " + Left(cCN, RAt(":", cCN) - 1) + " instalado, valido ate " + Right(cFim, 2) + "/" + SubStr(cFim, 5, 2) + "/" + Left(cFim, 4), ;
    {Left(cCN, RAt(":", cCN) - 1), cCNPJ, cFim}}

Static Function DFEPkcs12(cTmp, aOpc, cSaida)
    Local aArg := {"pkcs12", "-in", cTmp + ".pfx", "-out", cSaida, "-passin", "file:" + cTmp + ".pass"}
    Local aLeg := {}
    Local aOut := {}
    Local nRc := 0
    Local nI := 0
    For nI := 1 To Len(aOpc)
        aAdd(aArg, aOpc[nI])
    Next nI
    nRc := ProcRun("openssl", aArg, {|c| aAdd(aOut, c)}, {|c| aAdd(aOut, c)})
    If nRc == 0
        Return 0
    EndIf
    aLeg := AClone(aArg)
    aAdd(aLeg, "-legacy")
Return ProcRun("openssl", aLeg, {|c| aAdd(aOut, c)}, {|c| aAdd(aOut, c)})

// A chave privada assina e a chave publica do certificado confere (mesmo par).
Static Function DFEParConfere(cKey, cCert)
    Local aOut := {}
    Local aMk := {}
    Local aMc := {}
    ProcRun("openssl", {"rsa", "-in", cKey, "-noout", "-modulus"}, {|c| aAdd(aMk, c)}, {|c| aAdd(aOut, c)})
    ProcRun("openssl", {"x509", "-in", cCert, "-noout", "-modulus"}, {|c| aAdd(aMc, c)}, {|c| aAdd(aOut, c)})
    If Len(aMk) == 0 .Or. Len(aMc) == 0
        Return .F.
    EndIf
Return aMk[1] == aMc[1]

/*/{Protheus.doc} GEBDFECERTLE
    Certificado instalado da filial.
    @type Cadastro fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {cTitular, cCNPJ, cValidade, cCertPath, cKeyPath} ou {}
/*/
User Function GEBDFECERTLE()
    Local aH := {}
    If !GEBDFECADMIG()
        Return {}
    EndIf
    aH := TCSqlQuery("SELECT GDF2_TITULAR AS T, GDF2_CNPJ AS C, GDF2_VALIDADE AS V, GDF2_CERT AS CE, GDF2_KEY AS K FROM GDF2 WHERE GDF2_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GDF2")) + " AND D_E_L_E_T_ = ' '")
    If Len(aH) == 0
        Return {}
    EndIf
Return {BOCOL(aH[1]:T), BOCOL(aH[1]:C), BOCOL(aH[1]:V), BOCOL(aH[1]:CE), BOCOL(aH[1]:K)}

/*/{Protheus.doc} GEBDFEPRODFIS
    Perfil fiscal do produto (GDF4). o: PRODUTO, UNIDADE, GTIN, CFOP,
    CSOSN, CST, ALIQ_ICMS, CEST, ORIGEM, PIS_CST, COFINS_CST, ALIQ_PIS,
    ALIQ_COFINS, RED_BC (CST 20), MVA, ALIQ_ST e RED_BC_ST (ST: CSOSN 201/202/203
    e CST 10). Campo vazio = padrao da empresa.
    @type Cadastro fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBDFEPRODFIS(o)
    Local cFil := FWxFilial("GDF4")
    Local cProd := Upper(BOQ(o, "PRODUTO"))
    Local cGtin := GEBDFEDIG(BOQ(o, "GTIN"))
    Local cCfop := GEBDFEDIG(BOQ(o, "CFOP"))
    Local cCsosn := BOQ(o, "CSOSN")
    Local cCst := BOQ(o, "CST")
    Local cCest := GEBDFEDIG(BOQ(o, "CEST"))
    Local cOrig := BOQ(o, "ORIGEM")
    Local cPis := BOQ(o, "PIS_CST")
    Local cCof := BOQ(o, "COFINS_CST")
    Local aH := {}
    If !GEBDFECADMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    aH := TCSqlQuery("SELECT GF1_COD FROM GF1 WHERE GF1_FILIAL = " + GEBDBQuote(FWxFilial("GF1")) + " AND GF1_COD = " + GEBDBQuote(cProd) + ;
        " AND D_E_L_E_T_ = ' '")
    If Len(aH) == 0
        Return {.F., "produto_inexistente: " + cProd}
    EndIf
    If !(cGtin == "") .And. !DFEGtinOk(cGtin)
        Return {.F., "gtin_invalido"}
    EndIf
    If !(cCfop == "") .And. !(Len(cCfop) == 4 .And. Left(cCfop, 1) $ "567")
        Return {.F., "cfop_de_saida_invalido (5xxx, 6xxx ou 7xxx)"}
    EndIf
    If !(cCsosn == "") .And. !(cCsosn $ "101|102|103|201|202|203|300|400|500|900" .And. Len(cCsosn) == 3)
        Return {.F., "csosn_nao_suportado (101, 102, 103, 201, 202, 203, 300, 400, 500, 900)"}
    EndIf
    If !(cCst == "") .And. !(cCst $ "00|10|20|40|41|50|60" .And. Len(cCst) == 2)
        Return {.F., "cst_icms_nao_suportado (00, 10, 20, 40, 41, 50, 60)"}
    EndIf
    If (cCsosn $ "201|202|203" .And. !(cCsosn == "")) .Or. cCst == "10"
        If BOQN(o, "MVA") <= 0 .Or. BOQN(o, "ALIQ_ST") <= 0
            Return {.F., "st_exige_mva_e_aliquota_st"}
        EndIf
    EndIf
    If cCst == "20" .And. (BOQN(o, "RED_BC") <= 0 .Or. BOQN(o, "RED_BC") >= 100)
        Return {.F., "cst_20_exige_reducao_de_base_entre_0_e_100"}
    EndIf
    If !(cCest == "") .And. !(Len(cCest) == 7)
        Return {.F., "cest_invalido (7 digitos)"}
    EndIf
    If !(cOrig == "") .And. !(cOrig $ "012345678" .And. Len(cOrig) == 1)
        Return {.F., "origem_invalida (0 a 8)"}
    EndIf
    If !(cPis == "") .And. !DFECstPisOk(cPis)
        Return {.F., "cst_pis_invalido"}
    EndIf
    If !(cCof == "") .And. !DFECstPisOk(cCof)
        Return {.F., "cst_cofins_invalido"}
    EndIf
    If BOQN(o, "ALIQ_ICMS") < 0 .Or. BOQN(o, "ALIQ_ICMS") >= 100 .Or. BOQN(o, "ALIQ_PIS") < 0 .Or. BOQN(o, "ALIQ_COFINS") < 0
        Return {.F., "aliquota_invalida"}
    EndIf
    TCSqlExec("UPDATE GDF4 SET D_E_L_E_T_ = '*' WHERE GDF4_FILIAL = " + GEBDBQuote(cFil) + " AND GDF4_PROD = " + GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GDF4 (D_E_L_E_T_, GDF4_FILIAL, GDF4_PROD, GDF4_UNID, GDF4_GTIN, GDF4_CFOP, GDF4_CSOSN, GDF4_CST, GDF4_PICMS, GDF4_CEST, " + ;
        "GDF4_ORIG, GDF4_PISCST, GDF4_COFCST, GDF4_PPIS, GDF4_PCOF) VALUES (' ', " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cProd) + ", " + ;
        GEBDBQuote(Upper(BOQ(o, "UNIDADE"))) + ", " + GEBDBQuote(cGtin) + ", " + GEBDBQuote(cCfop) + ", " + GEBDBQuote(cCsosn) + ", " + ;
        GEBDBQuote(cCst) + ", " + BONUM(BOQN(o, "ALIQ_ICMS"), 4) + ", " + GEBDBQuote(cCest) + ", " + GEBDBQuote(cOrig) + ", " + ;
        GEBDBQuote(cPis) + ", " + GEBDBQuote(cCof) + ", " + BONUM(BOQN(o, "ALIQ_PIS"), 4) + ", " + BONUM(BOQN(o, "ALIQ_COFINS"), 4) + ")")
    TCSqlExec("UPDATE GDFA SET D_E_L_E_T_ = '*' WHERE GDFA_FILIAL = " + GEBDBQuote(cFil) + " AND GDFA_PROD = " + GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GDFA (D_E_L_E_T_, GDFA_FILIAL, GDFA_PROD, GDFA_PREDBC, GDFA_MVA, GDFA_PICMSST, GDFA_PREDBCST) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
        GEBDBQuote(cProd) + ", " + BONUM(BOQN(o, "RED_BC"), 4) + ", " + BONUM(BOQN(o, "MVA"), 4) + ", " + BONUM(BOQN(o, "ALIQ_ST"), 4) + ", " + ;
        BONUM(BOQN(o, "RED_BC_ST"), 4) + ")")
Return {.T., "perfil fiscal de " + cProd + " gravado"}

Static Function DFECstPisOk(cCst)
Return Len(cCst) == 2 .And. cCst $ "01|02|04|05|06|07|08|09|49|99"

// GTIN-8/12/13/14 com digito verificador (modulo 10, pesos 3 e 1 da direita).
Static Function DFEGtinOk(cG)
    Local nSoma := 0
    Local nI := 0
    Local nP := 3
    If !(Len(cG) == 8 .Or. Len(cG) == 12 .Or. Len(cG) == 13 .Or. Len(cG) == 14)
        Return .F.
    EndIf
    For nI := Len(cG) - 1 To 1 Step -1
        nSoma += Val(SubStr(cG, nI, 1)) * nP
        If nP == 3
            nP := 1
        Else
            nP := 3
        EndIf
    Next nI
Return Val(Right(cG, 1)) == (10 - nSoma % 10) % 10

/*/{Protheus.doc} GEBDFEPRODITEM
    Item do XML (ITENS de GEBDFEMONTA) do produto: GF1 + perfil (GDF4) +
    padroes da empresa; GTIN do cadastro de codigos de barras da loja
    (GLJ8) quando o perfil nao tiver. lSimples (CRT 1/4) escolhe CSOSN ou CST.
    @type Cadastro fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return JsonObject ou Nil (produto inexistente)
/*/
User Function GEBDFEPRODITEM(cProd, lSimples)
    Local aG := {}
    Local aP := {}
    Local aV := {}
    Local oI := Nil
    Local cGtin := ""
    Local nI := 0
    aG := TCSqlQuery("SELECT GF1_DESC AS D, GF1_NCM AS N FROM GF1 WHERE GF1_FILIAL = " + GEBDBQuote(FWxFilial("GF1")) + " AND GF1_COD = " + ;
        GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' '")
    If Len(aG) == 0
        Return Nil
    EndIf
    GEBDFECADMIG()
    aP := TCSqlQuery("SELECT GDF4_UNID AS U, GDF4_GTIN AS G, GDF4_CFOP AS F, GDF4_CSOSN AS S, GDF4_CST AS C, GDF4_PICMS AS PI, GDF4_CEST AS E, " + ;
        "GDF4_ORIG AS O, GDF4_PISCST AS PC, GDF4_COFCST AS CC, GDF4_PPIS AS PP, GDF4_PCOF AS PF FROM GDF4 WHERE GDF4_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GDF4")) + " AND GDF4_PROD = " + GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' '")
    aV := {"", "", "", "", "", "", "", ""}
    If Len(aP) > 0
        aV := {BOCOL(aP[1]:U), BOCOL(aP[1]:F), BOCOL(aP[1]:O), BOCOL(aP[1]:E), BOCOL(aP[1]:S), BOCOL(aP[1]:C), BOCOL(aP[1]:PC), BOCOL(aP[1]:CC)}
    EndIf
    oI := JsonObject():New()
    oI["CPROD"] := cProd
    oI["XPROD"] := BOCOL(aG[1]:D)
    oI["NCM"] := GEBDFEDIG(BOCOL(aG[1]:N))
    oI["UCOM"] := DFEOuPadrao(aV[1], "DFE_UNIDADE", "UN")
    oI["CFOP"] := DFEOuPadrao(aV[2], "DFE_CFOP", "5102")
    oI["ORIG"] := DFEOuPadrao(aV[3], "DFE_ORIGEM", "0")
    oI["CEST"] := DFEOuPadrao(aV[4], "", "")
    oI["PICMS"] := 0
    If lSimples
        oI["CSOSN"] := DFEOuPadrao(aV[5], "DFE_CSOSN", "102")
        oI["PISCST"] := DFEOuPadrao(aV[7], "DFE_PIS_CST", "49")
        oI["COFINSCST"] := DFEOuPadrao(aV[8], "DFE_COFINS_CST", "49")
    Else
        oI["CST"] := DFEOuPadrao(aV[6], "DFE_CST", "00")
        oI["PISCST"] := DFEOuPadrao(aV[7], "DFE_PIS_CST", "01")
        oI["COFINSCST"] := DFEOuPadrao(aV[8], "DFE_COFINS_CST", "01")
        If Len(aP) > 0 .And. BOVAL(aP[1]:PI) > 0
            oI["PICMS"] := BOVAL(aP[1]:PI)
        Else
            oI["PICMS"] := BOVAL(BOPARM("DFE_ALIQ_ICMS", "0"))
        EndIf
    EndIf
    oI["PPIS"] := 0
    oI["PCOFINS"] := 0
    If Len(aP) > 0
        oI["PPIS"] := BOVAL(aP[1]:PP)
        oI["PCOFINS"] := BOVAL(aP[1]:PF)
    EndIf
    If Len(aP) > 0
        cGtin := BOCOL(aP[1]:G)
    EndIf
    aP := TCSqlQuery("SELECT GDFA_PREDBC AS R, GDFA_MVA AS M, GDFA_PICMSST AS S, GDFA_PREDBCST AS RS FROM GDFA WHERE GDFA_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GDFA")) + " AND GDFA_PROD = " + GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' '")
    If Len(aP) > 0
        oI["PREDBC"] := BOVAL(aP[1]:R)
        oI["MVA"] := BOVAL(aP[1]:M)
        oI["PICMSST"] := BOVAL(aP[1]:S)
        oI["PREDBCST"] := BOVAL(aP[1]:RS)
    EndIf
    If lSimples .And. BOCOL(oI["CSOSN"]) $ "201|202|203" .And. !(BOCOL(oI["CSOSN"]) == "")
        // ICMS proprio usado so' para deduzir da ST: aliquota interna da UF do emitente.
        oI["PICMS"] := BOVAL(BOPARM("DFE_ALIQ_ICMS", "0"))
    EndIf
    If cGtin == "" .And. GEBDBTableExistsHere("GLJ8")
        aG := TCSqlQuery("SELECT GLJ8_COD AS C FROM GLJ8 WHERE GLJ8_FILIAL = " + GEBDBQuote(FWxFilial("GLJ8")) + " AND GLJ8_PROD = " + ;
            GEBDBQuote(cProd) + " AND GLJ8_FATOR = 1 AND D_E_L_E_T_ = ' ' ORDER BY GLJ8_COD")
        For nI := 1 To Len(aG)
            If DFEGtinOk(BOCOL(aG[nI]:C))
                cGtin := BOCOL(aG[nI]:C)
                Exit
            EndIf
        Next nI
    EndIf
    oI["CEAN"] := cGtin
Return oI

Static Function DFEOuPadrao(cPerfil, cParm, cPadrao)
    Local cV := BOCOL(cPerfil)
    If cV == "" .And. !(cParm == "")
        cV := BOPARM(cParm, cPadrao)
    EndIf
    If cV == ""
        cV := cPadrao
    EndIf
Return cV

/*/{Protheus.doc} GEBDFECONFIG
    Configuracao dos documentos eletronicos da empresa (parametros DFE_*).
    o: AMBIENTE (1 producao, 2 homologacao), NFCE (S/N), SERIE_NFCE,
    PROXIMO_NFCE (proximo numero; para quem vem de outro sistema), CSC_ID,
    CSC, RT_CNPJ, RT_CONTATO, RT_EMAIL, RT_FONE, CFOP, CSOSN, CST,
    ALIQ_ICMS, UNIDADE, ORIGEM, PIS_CST, COFINS_CST, CANC_MIN, TIMEOUT,
    QR_VERSAO (3 padrao; 2 = com CSC), MENSAGEM (texto do cupom), NFE (S/N), SERIE_NFE,
    NFE_TPAG (forma de pagamento da NF-e de venda, padrao 15 boleto). A pasta dos
    certificados (DFE_CERT_DIR) e os enderecos da SEFAZ (DFE_URL_*) nao vem
    por aqui: sao do operador do servidor (o servico roda como root). So' grava o que vier preenchido.
    @type Cadastro fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBDFECONFIG(o)
    Local aCampos := {{"AMBIENTE", "DFE_AMBIENTE"}, {"NFCE", "DFE_NFCE"}, {"SERIE_NFCE", "DFE_SERIE_65"}, {"CSC_ID", "DFE_CSC_ID"}, ;
        {"CSC", "DFE_CSC"}, {"RT_CNPJ", "DFE_RT_CNPJ"}, {"RT_CONTATO", "DFE_RT_CONTATO"}, {"RT_EMAIL", "DFE_RT_EMAIL"}, {"RT_FONE", "DFE_RT_FONE"}, ;
        {"CFOP", "DFE_CFOP"}, {"CSOSN", "DFE_CSOSN"}, {"CST", "DFE_CST"}, {"ALIQ_ICMS", "DFE_ALIQ_ICMS"}, {"UNIDADE", "DFE_UNIDADE"}, ;
        {"ORIGEM", "DFE_ORIGEM"}, {"PIS_CST", "DFE_PIS_CST"}, {"COFINS_CST", "DFE_COFINS_CST"}, {"CANC_MIN", "DFE_CANC_MIN"}, ;
        {"TIMEOUT", "DFE_TIMEOUT"}, {"QR_VERSAO", "DFE_QR_VERSAO"}, {"MENSAGEM", "DFE_INFCPL"}, ;
        {"NFE", "DFE_NFE"}, {"SERIE_NFE", "DFE_SERIE_55"}, {"NFE_TPAG", "DFE_NFE_TPAG"}, {"NFSE", "DFE_NFSE"}, {"SERIE_NFSE", "DFE_SERIE_NFSE"}, ;
        {"NFSE_REGIME_SN", "DFE_NFSE_REGAPSN"}, {"NFSE_PERC_TRIB_SN", "DFE_NFSE_PTOTTRIBSN"}, ;
        {"EFD_PERFIL", "DFE_EFD_PERFIL"}, {"EFD_ATIVIDADE", "DFE_EFD_ATIV"}, {"EFD_COD_REC", "DFE_EFD_COD_REC"}, {"EFD_COD_REC_ST", "DFE_EFD_COD_REC_ST"}, ;
        {"EFD_COD_REC_DIFAL", "DFE_EFD_COD_REC_DIFAL"}, {"EFD_COD_REC_FCP", "DFE_EFD_COD_REC_FCP"}, {"EFD_DIA_VENC", "DFE_EFD_DIA_VENC"}, ;
        {"EFD_SALDO_CREDOR_INICIAL", "DFE_EFD_SLD_CRED_INI"}, {"CONT_NOME", "DFE_EFD_CONT_NOME"}, {"CONT_CPF", "DFE_EFD_CONT_CPF"}, ;
        {"CONT_CRC", "DFE_EFD_CONT_CRC"}, {"CONT_CNPJ", "DFE_EFD_CONT_CNPJ"}, {"CONT_CEP", "DFE_EFD_CONT_CEP"}, {"CONT_END", "DFE_EFD_CONT_END"}, ;
        {"CONT_NUM", "DFE_EFD_CONT_NUM"}, {"CONT_COMPL", "DFE_EFD_CONT_COMPL"}, {"CONT_BAIRRO", "DFE_EFD_CONT_BAIRRO"}, {"CONT_FONE", "DFE_EFD_CONT_FONE"}, ;
        {"CONT_EMAIL", "DFE_EFD_CONT_EMAIL"}, {"CONT_MUNICIPIO", "DFE_EFD_CONT_MUN"}}
    Local cV := ""
    Local nI := 0
    Local nGrav := 0
    If !(BOQ(o, "AMBIENTE") == "") .And. !(BOQ(o, "AMBIENTE") $ "1|2" .And. Len(BOQ(o, "AMBIENTE")) == 1)
        Return {.F., "ambiente_invalido (1 producao, 2 homologacao)"}
    EndIf
    If !(BOQ(o, "QR_VERSAO") == "") .And. !(BOQ(o, "QR_VERSAO") == "2" .Or. BOQ(o, "QR_VERSAO") == "3")
        Return {.F., "versao_do_qrcode_deve_ser_2_ou_3"}
    EndIf
    If !(BOQ(o, "NFCE") == "") .And. !(Upper(BOQ(o, "NFCE")) == "S" .Or. Upper(BOQ(o, "NFCE")) == "N")
        Return {.F., "nfce_deve_ser_S_ou_N"}
    EndIf
    If !(BOQ(o, "NFE") == "") .And. !(Upper(BOQ(o, "NFE")) == "S" .Or. Upper(BOQ(o, "NFE")) == "N")
        Return {.F., "nfe_deve_ser_S_ou_N"}
    EndIf
    If !(BOQ(o, "NFSE") == "") .And. !(Upper(BOQ(o, "NFSE")) == "S" .Or. Upper(BOQ(o, "NFSE")) == "N")
        Return {.F., "nfse_deve_ser_S_ou_N"}
    EndIf
    If !(BOQ(o, "NFSE_REGIME_SN") == "") .And. !(BOQ(o, "NFSE_REGIME_SN") $ "1|2|3" .And. Len(BOQ(o, "NFSE_REGIME_SN")) == 1)
        Return {.F., "regime_de_apuracao_do_simples_na_nfse_deve_ser_1_2_ou_3"}
    EndIf
    If !(BOQ(o, "SERIE_NFCE") == "") .And. (BOQN(o, "SERIE_NFCE") < 0 .Or. BOQN(o, "SERIE_NFCE") > 889)
        Return {.F., "serie_invalida (0 a 889)"}
    EndIf
    If !(BOQ(o, "EFD_PERFIL") == "") .And. !(Upper(BOQ(o, "EFD_PERFIL")) $ "A|B|C" .And. Len(BOQ(o, "EFD_PERFIL")) == 1)
        Return {.F., "perfil_da_efd_deve_ser_A_B_ou_C"}
    EndIf
    If !(BOQ(o, "CONT_CPF") == "") .And. !(Len(GEBDFEDIG(BOQ(o, "CONT_CPF"))) == 11 .And. GEBDFEDOCOK(BOQ(o, "CONT_CPF")))
        Return {.F., "cpf_do_contabilista_invalido"}
    EndIf
    If !(BOQ(o, "CONT_MUNICIPIO") == "") .And. GEBDFEMUNNOME(GEBDFEDIG(BOQ(o, "CONT_MUNICIPIO"))) == ""
        Return {.F., "municipio_ibge_do_contabilista_invalido"}
    EndIf
    If !(BOQ(o, "EFD_DIA_VENC") == "") .And. (BOQN(o, "EFD_DIA_VENC") < 1 .Or. BOQN(o, "EFD_DIA_VENC") > 28)
        Return {.F., "dia_de_vencimento_do_icms_deve_ser_de_1_a_28"}
    EndIf
    If !(BOQ(o, "RT_CNPJ") == "") .And. !GEBDFEDOCOK(BOQ(o, "RT_CNPJ"))
        Return {.F., "cnpj_do_responsavel_tecnico_invalido"}
    EndIf
    If !(BOQ(o, "PROXIMO_NFCE") == "") .And. (BOQN(o, "PROXIMO_NFCE") < 1 .Or. BOQN(o, "PROXIMO_NFCE") > 999999999)
        Return {.F., "proximo_numero_invalido"}
    EndIf
    For nI := 1 To Len(aCampos)
        cV := BOQ(o, aCampos[nI][1])
        If !(cV == "")
            If aCampos[nI][1] == "NFCE" .Or. aCampos[nI][1] == "NFE" .Or. aCampos[nI][1] == "NFSE"
                cV := Upper(cV)
            EndIf
            BOSETPARM(aCampos[nI][2], cV)
            nGrav++
        EndIf
    Next nI
    If !(BOQ(o, "PROXIMO_NFCE") == "")
        GEBDFESETNUM("65", BOVAL(BOPARM("DFE_SERIE_65", "1")), BOQN(o, "PROXIMO_NFCE"))
        nGrav++
    EndIf
Return {.T., cValToChar(nGrav) + " configuracao(oes) gravada(s)"}

// Proximo numero do modelo/serie (GBS1).
User Function GEBDFEPROXNUM(cMod, nSerie)
Return Val(BOSEQ("DFE" + cMod + StrZero(nSerie, 3), 9))

// Ajusta a numeracao para que o proximo seja nProximo.
User Function GEBDFESETNUM(cMod, nSerie, nProximo)
    Local cChave := "DFE" + cMod + StrZero(nSerie, 3)
    Local cFil := FWxFilial("GBS1")
    BOMIG()
    TCSqlExec("UPDATE GBS1 SET D_E_L_E_T_ = '*' WHERE GBS1_FILIAL = " + GEBDBQuote(cFil) + " AND GBS1_CHAVE = " + GEBDBQuote(cChave) + " AND D_E_L_E_T_ = ' '")
Return TCSqlExec("INSERT INTO GBS1 (D_E_L_E_T_, GBS1_FILIAL, GBS1_CHAVE, GBS1_ULT) VALUES (' ', " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cChave) + ", " + ;
    BONUM(nProximo - 1, 0) + ")")

/*/{Protheus.doc} GEBDFEIBPTIMP
    Importa a tabela do IBPT (Lei 12.741/2012, "De Olho no Imposto"): o CSV
    oficial da UF (codigo;ex;tipo;descricao;nacionalfederal;importadosfederal;
    estadual;municipal;vigenciainicio;vigenciafim;chave;versao;fonte). So' as
    linhas de NCM (tipo 0). Substitui a tabela anterior da UF.
    @type Cadastro fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, nLinhas}
/*/
User Function GEBDFEIBPTIMP(cConteudo, cUF)
    Local cFil := FWxFilial("GDFB")
    Local aL := {}
    Local aC := {}
    Local cSql := ""
    Local cIns := "INSERT INTO GDFB (D_E_L_E_T_, GDFB_FILIAL, GDFB_UF, GDFB_NCM, GDFB_EX, GDFB_NACF, GDFB_IMPF, GDFB_EST, GDFB_MUN, GDFB_INI, GDFB_FIM, " + ;
        "GDFB_VERSAO, GDFB_FONTE) VALUES "
    Local cVer := ""
    Local nLote := 0
    Local nOk := 0
    Local nI := 0
    cUF := Upper(BOCOL(cUF))
    If GEBDFECUF(cUF) == ""
        Return {.F., "uf_invalida", 0}
    EndIf
    aL := StrTokArr(StrTran(BOSTR(cConteudo), Chr(13), ""), Chr(10))
    If Len(aL) < 2 .Or. !("codigo" $ Lower(aL[1]))
        Return {.F., "arquivo_nao_e_a_tabela_do_ibpt (cabecalho codigo;ex;tipo;...)", 0}
    EndIf
    If !GEBDFECADMIG()
        Return {.F., "falha_tabelas", 0}
    EndIf
    TCSqlExec("DELETE FROM GDFB WHERE GDFB_FILIAL = " + GEBDBQuote(cFil) + " AND GDFB_UF = " + GEBDBQuote(cUF))
    For nI := 2 To Len(aL)
        aC := StrTokArr(aL[nI], ";")
        If Len(aC) >= 13 .And. AllTrim(aC[3]) == "0" .And. Len(GEBDFEDIG(aC[1])) == 8
            cVer := AllTrim(aC[12])
            cSql += IIFStr(nLote > 0, ", ", "") + "(' ', " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cUF) + ", " + GEBDBQuote(GEBDFEDIG(aC[1])) + ", " + ;
                GEBDBQuote(AllTrim(aC[2])) + ", " + BONUM(Val(aC[5]), 4) + ", " + BONUM(Val(aC[6]), 4) + ", " + BONUM(Val(aC[7]), 4) + ", " + ;
                BONUM(Val(aC[8]), 4) + ", " + GEBDBQuote(DFEDataBr2(aC[9])) + ", " + GEBDBQuote(DFEDataBr2(aC[10])) + ", " + GEBDBQuote(cVer) + ", " + ;
                GEBDBQuote(Left(AllTrim(aC[13]), 60)) + ")"
            nLote++
            nOk++
            If nLote >= 500
                TCSqlExec(cIns + cSql)
                cSql := ""
                nLote := 0
            EndIf
        EndIf
    Next nI
    If nLote > 0
        TCSqlExec(cIns + cSql)
    EndIf
    If nOk == 0
        Return {.F., "nenhuma_ncm_no_arquivo", 0}
    EndIf
    BOSETPARM("DFE_IBPT_VERSAO_" + cUF, cVer)
Return {.T., cValToChar(nOk) + " NCM da tabela IBPT " + cVer + " (" + cUF + ") importadas", nOk}

Static Function IIFStr(lCond, cSim, cNao)
    If lCond
        Return cSim
    EndIf
Return cNao

// dd/mm/aaaa -> aaaammdd ("" se vazio).
Static Function DFEDataBr2(cD)
    cD := AllTrim(BOSTR(cD))
    If Len(cD) < 10
        Return ""
    EndIf
Return Right(cD, 4) + SubStr(cD, 4, 2) + Left(cD, 2)

/*/{Protheus.doc} GEBDFETRIB
    Completa os itens antes do XML: tributos aproximados (Lei 12.741, tabela
    IBPT da UF do emitente: federal nacional ou importado pela origem,
    estadual e municipal) e, se DFE_IBSCBS = S (padrao: so' no regime
    normal), o grupo IBS/CBS com as aliquotas vigentes da NCM (GF2; o IBS
    vai para a UF, salvo DFE_IBS_MUN_PCT % para o municipio).
    @type Funcao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lIbsCbs, cTextoLei12741}
/*/
User Function GEBDFETRIB(aIt, cUF, cCRT, cData)
    Local aH := {}
    Local aTx := {}
    Local lIbs := BOPARM("DFE_IBSCBS", IIFStr(cCRT == "3", "S", "N")) == "S"
    Local nMun := BOVAL(BOPARM("DFE_IBS_MUN_PCT", "0"))
    Local nV := 0
    Local nF := 0
    Local nE := 0
    Local nM := 0
    Local nTF := 0
    Local nTE := 0
    Local nTM := 0
    Local cFonte := ""
    Local nI := 0
    GEBDFECADMIG()
    For nI := 1 To Len(aIt)
        nV := Round(BOVAL(aIt[nI]["QCOM"]) * BOVAL(aIt[nI]["VUNCOM"]), 2) - Round(BOVAL(aIt[nI]["VDESC"]), 2)
        aH := TCSqlQuery("SELECT GDFB_NACF AS NF, GDFB_IMPF AS IFE, GDFB_EST AS E, GDFB_MUN AS M, GDFB_VERSAO AS V, GDFB_FONTE AS FO FROM GDFB " + ;
            "WHERE GDFB_FILIAL = " + GEBDBQuote(FWxFilial("GDFB")) + " AND GDFB_UF = " + GEBDBQuote(cUF) + " AND GDFB_NCM = " + ;
            GEBDBQuote(BOCOL(aIt[nI]["NCM"])) + " AND D_E_L_E_T_ = ' ' ORDER BY GDFB_EX LIMIT 1")
        If Len(aH) > 0
            If BOCOL(aIt[nI]["ORIG"]) $ "1|2|6|7" .And. !(BOCOL(aIt[nI]["ORIG"]) == "")
                nF := Round(nV * BOVAL(aH[1]:IFE) / 100, 2)
            Else
                nF := Round(nV * BOVAL(aH[1]:NF) / 100, 2)
            EndIf
            nE := Round(nV * BOVAL(aH[1]:E) / 100, 2)
            nM := Round(nV * BOVAL(aH[1]:M) / 100, 2)
            aIt[nI]["VTOTTRIB"] := nF + nE + nM
            nTF += nF
            nTE += nE
            nTM += nM
            cFonte := "IBPT " + BOCOL(aH[1]:V)
        EndIf
        If lIbs
            aTx := ALIQF(BOCOL(aIt[nI]["NCM"]), cData)
            aIt[nI]["PIBSUF"] := Round(aTx[1] * (100 - nMun) / 100, 4)
            aIt[nI]["PIBSMUN"] := Round(aTx[1] * nMun / 100, 4)
            aIt[nI]["PCBS"] := aTx[2]
            aIt[nI]["IBSCST"] := BOPARM("DFE_IBSCBS_CST", "000")
            aIt[nI]["CCLASSTRIB"] := BOPARM("DFE_CCLASSTRIB", "000001")
        EndIf
    Next nI
    If cFonte == ""
        Return {lIbs, ""}
    EndIf
Return {lIbs, "Trib aprox R$ " + StrTran(BONUM(nTF, 2), ".", ",") + " Federal, R$ " + StrTran(BONUM(nTE, 2), ".", ",") + " Estadual, R$ " + ;
    StrTran(BONUM(nTM, 2), ".", ",") + " Municipal. Fonte: " + cFonte}
