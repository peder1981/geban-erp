#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCOM_FOR.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBCTX.prw"
#include "../src/GEBEST.prw"
#include "../src/GEBFNX.prw"
#include "../src/GEBCPX.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBFAT.prw"
#include "../src/GEBTEF.prw"
#include "../src/GEBLOJ.prw"
#include "../src/GEBDFE_XML.prw"
#include "../src/GEBDFE_WS.prw"
#include "../src/GEBDFE_MUN.prw"
#include "../src/GEBDFE_IE.prw"
#include "../src/GEBDFE_CAD.prw"
#include "../src/GEBDFE.prw"
#include "../src/GEBDFE_QR.prw"
#include "../src/GEBDFE_DANFE.prw"
#include "../src/GEBLOJ_CAD.prw"
#include "../src/GEBLOJ_OPE.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBDFE_NFE
    NF-e modelo 55 de ponta a ponta contra o emulador da SEFAZ (porta 18766):
    - faturamento sem cadastro fiscal do cliente => recusa; consumidor (SP,
      nao contribuinte): indFinal 1, CFOP 5102, texto do Simples, DANFE A4
      com codigo de barras; cliente contribuinte do RJ a prazo (30,60):
      idDest 2, CFOP 6102, duas duplicatas; carta de correcao (seq 1 e 2).
    - devolucao do consumidor => NF-e de entrada (finalidade 4, 1202,
      NF-e referenciada); do contribuinte sem chave => recusa, com chave =>
      vinculo DEVCLI.
    - devolucao de compra => NF-e de saida 5202 referenciando a chave da
      NF-e do fornecedor informada na entrada.
    - sem resposta da SEFAZ => PENDENTE; resolver: nao consta (217) =>
      liberada; SEFAZ autorizou sem resposta => cancelada.
    - regime normal vendendo a nao contribuinte de outra UF => DIFAL (4% + FCP 1%) e titulo.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 19/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBDFE_NFE()
    Local lOk := .T.
    Local aR := {}
    Local aD := {}
    Local aServ := {"NfeAutorizacao", "NfeStatusServico", "NfeConsultaProtocolo", "RecepcaoEvento", "NfeInutilizacao"}
    Local o := Nil
    Local cDir := "/tmp/geban-tdfenfe-" + StrZero(Randomize(1, 999999), 6)
    Local cCh1 := ""
    Local cCh2 := ""
    Local cChF := ""
    Local cX := ""
    Local nI := 0

    If !GEBDBConecta()
        ConOut("T_GEBDFE_NFE FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdfenfe CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebdfenfe")
    TCSqlExec("SET search_path TO test_gebdfenfe")
    lOk := Chk(lOk, "mig", GENMIG() .And. GEBFMIG() .And. GEBCPXMIG() .And. GEBFATMIG() .And. GEBDFENFEMIG())
    GEBFNCON("CAIXA", "Caixa")
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'P1', '08039000', 'Banana prata caixa')")
    GEBFATPRC("", "P1", 50)
    GEBESTMOV("P1", "01", "E", 100, 20, "COMPRA", "X", "20261001")
    BOSETPARM("DFE_CERT_DIR", cDir + "/cert")
    For nI := 1 To Len(aServ)
        BOSETPARM("DFE_URL_" + Upper(aServ[nI]), "https://127.0.0.1:18766/sefaz")
    Next nI
    BOSETPARM("DFE_TIMEOUT", "10")
    BOSETPARM("DFE_NFE", "S")
    ProcRun("mkdir", {"-p", cDir}, {|c| c})
    Openssl({"req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", cDir + "/k.pem", "-out", cDir + "/c.pem", "-days", "60", "-subj", ;
        "/C=BR/O=ICP-Brasil/CN=EMPRESA TESTE LTDA:12345678000195"})
    Openssl({"pkcs12", "-export", "-inkey", cDir + "/k.pem", "-in", cDir + "/c.pem", "-out", cDir + "/emp.pfx", "-passout", "pass:Senha123"})
    lOk := Chk(lOk, "emitente", GEBDFEEMIT(Emit("1"))[1])
    lOk := Chk(lOk, "certificado", GEBDFECERT(Encode64(MemoRead(cDir + "/emp.pfx")), "Senha123")[1])

    // Clientes: consumidor de SP e contribuinte do RJ (30/60 dias).
    GEBFATCLI("C1", "Consumidor Final", "52998224725", "SP", 0, "", "")
    GEBFATCLI("C2", "Atacado Rio SA", "11222333000181", "RJ", 0, "30,60", "")
    GEBFATPED("", "C1", {{"P1", 2}}, "", 0, "", BOHOJE())
    GEBFATLIB("PV000001")
    aR := GEBFATFAT("PV000001", {}, BOHOJE(), "")
    lOk := Chk(lOk, "sem cadastro fiscal recusa", !aR[1] .And. "cadastro_fiscal" $ aR[2])
    lOk := Chk(lOk, "cadastro fiscal invalido", !GEBDFEPART(Part("C", "C1", "52998224724", "9", "", "SP", "3550308"))[1])
    lOk := Chk(lOk, "cadastro fiscal C1", GEBDFEPART(Part("C", "C1", "529.982.247-25", "9", "", "SP", "3550308"))[1])
    lOk := Chk(lOk, "ie errada do RJ", !GEBDFEPART(Part("C", "C2", "11222333000181", "1", "86532187", "RJ", "3304557"))[1])
    lOk := Chk(lOk, "cadastro fiscal C2", GEBDFEPART(Part("C", "C2", "11222333000181", "1", "86532182", "RJ", "3304557"))[1])

    // Venda ao consumidor.
    aR := GEBFATFAT("PV000001", {}, BOHOJE(), "")
    lOk := Chk(lOk, "nfe consumidor", aR[1] .And. Len(aR[3][1]) == 44 .And. SubStr(aR[3][1], 21, 2) == "55")
    If !aR[1]
        ConOut("    " + aR[2])
        Return Fim(.F., cDir)
    EndIf
    cCh1 := aR[3][1]
    cX := GEBDFEDOC(cCh1)[3]
    lOk := Chk(lOk, "xml consumidor", "<indFinal>1</indFinal>" $ cX .And. "<idDest>1</idDest>" $ cX .And. "<CFOP>5102</CFOP>" $ cX .And. ;
        "OPTANTE PELO SIMPLES NACIONAL" $ cX .And. "<protNFe" $ cX .And. "<CPF>52998224725</CPF>" $ cX)
    lOk := Chk(lOk, "livro e titulo", BOCOL(TCSqlQuery("SELECT GF3_STATUS AS S FROM GF3 WHERE GF3_CHAVE = " + GEBDBQuote(cCh1))[1]:S) == "AUTORIZADA" .And. ;
        Len(TCSqlQuery("SELECT GFN2_DOC FROM GFN2 WHERE GFN2_DOC LIKE " + GEBDBQuote(cCh1 + "%"))) >= 1)
    aR := GEBDFEDANFE(cCh1)
    lOk := Chk(lOk, "danfe a4", aR[1] .And. "DANFE" $ aR[3] .And. "<svg" $ aR[3] .And. "HOMOLOGACAO" $ aR[3] .And. "529.982.247-25" $ aR[3])

    // Contribuinte do RJ, a prazo.
    GEBFATPED("", "C2", {{"P1", 10}}, "", 0, "", BOHOJE())
    GEBFATLIB("PV000002")
    aR := GEBFATFAT("PV000002", {}, BOHOJE(), "")
    lOk := Chk(lOk, "nfe interestadual", aR[1])
    If aR[1]
        cCh2 := aR[3][1]
        cX := GEBDFEDOC(cCh2)[3]
        lOk := Chk(lOk, "xml interestadual", "<idDest>2</idDest>" $ cX .And. "<CFOP>6102</CFOP>" $ cX .And. "<indFinal>0</indFinal>" $ cX .And. ;
            "<indIEDest>1</indIEDest><IE>86532182</IE>" $ cX .And. "<nDup>002</nDup>" $ cX .And. "<indPag>1</indPag><tPag>15</tPag>" $ cX)
        lOk := Chk(lOk, "carta de correcao curta", !GEBDFECCE(cCh2, "curta")[1])
        lOk := Chk(lOk, "carta de correcao 1", GEBDFECCE(cCh2, "Corrige o complemento do endereco de entrega")[1])
        aR := GEBDFECCE(cCh2, "Corrige o telefone de contato do destinatario")
        lOk := Chk(lOk, "carta de correcao 2", aR[1] .And. "correcao 2" $ aR[2])
        lOk := Chk(lOk, "cce em nfc-e/inexistente", !GEBDFECCE(Replicate("1", 44), "Corrige o endereco do destinatario")[1])
    EndIf

    // Devolucoes de venda.
    aR := GEBFATDEV(cCh1, {{"P1", 1}}, BOHOJE())
    lOk := Chk(lOk, "devolucao do consumidor emite nf-e de entrada", aR[1])
    If !aR[1]
        ConOut("    " + aR[2])
    EndIf
    aD := TCSqlQuery("SELECT GDF5_CHAVE AS C, GDF5_XML AS X FROM GDF5 WHERE GDF5_ORIGEM = 'FATDEV' AND GDF5_STATUS = 'AUTORIZADA'")
    lOk := Chk(lOk, "xml da devolucao", Len(aD) == 1 .And. "<tpNF>0</tpNF>" $ aD[1]:X .And. "<finNFe>4</finNFe>" $ aD[1]:X .And. ;
        "<refNFe>" + cCh1 + "</refNFe>" $ aD[1]:X .And. "<CFOP>1202</CFOP>" $ aD[1]:X .And. "<CSOSN>900</CSOSN>" $ aD[1]:X)
    If !(cCh2 == "")
        lOk := Chk(lOk, "devolucao do contribuinte sem chave", "chave" $ GEBFATDEV(cCh2, {{"P1", 1}}, BOHOJE())[2])
        cX := "3326101122233300018155001000000123100000123"
        aR := GEBFATDEV(cCh2, {{"P1", 1}}, BOHOJE(), cX + GEBDFEDV(cX))
        lOk := Chk(lOk, "devolucao do contribuinte com chave", aR[1] .And. Len(TCSqlQuery("SELECT GDF8_CHAVE FROM GDF8 WHERE GDF8_TIPO = 'DEVCLI'")) == 1)
    EndIf

    // Compra com a chave do fornecedor e devolucao de compra.
    GEBCMFOR("F1", "Fornecedor 1")
    lOk := Chk(lOk, "cadastro fiscal F1", GEBDFEPART(Part("F", "F1", "11444777000161", "1", "110042490114", "SP", "3509502"))[1])
    GEBCPXPED("PC1", "F1", {{"P1", 10, 20}}, "0", "", BOHOJE())
    cChF := "35261011444777000161550010000004561000004562"
    cChF := Left(cChF, 43) + GEBDFEDV(Left(cChF, 43))
    lOk := Chk(lOk, "entrada com chave invalida", !GEBCPXENT("NFF1", "PC1", {}, 0, BOHOJE(), "", "123")[1])
    lOk := Chk(lOk, "entrada com chave", GEBCPXENT("NFF1", "PC1", {}, 0, BOHOJE(), "", cChF)[1])
    aR := GEBCPXDEV("NFF1", "F1", {{"P1", 2}}, BOHOJE())
    lOk := Chk(lOk, "devolucao de compra", aR[1])
    If !aR[1]
        ConOut("    " + aR[2])
    EndIf
    aD := TCSqlQuery("SELECT GDF5_XML AS X FROM GDF5 WHERE GDF5_ORIGEM = 'CPXDEV' AND GDF5_STATUS = 'AUTORIZADA'")
    lOk := Chk(lOk, "xml devolucao de compra", Len(aD) == 1 .And. "<refNFe>" + cChF + "</refNFe>" $ aD[1]:X .And. "<CFOP>5202</CFOP>" $ aD[1]:X .And. ;
        "<tpNF>1</tpNF><idDest>1</idDest>" $ aD[1]:X)

    // Sem resposta: nao chegou (217 => liberada) e chegou (autorizada => cancelada).
    BOSETPARM("DFE_URL_NFEAUTORIZACAO", "https://127.0.0.1:1/sefaz")
    GEBFATPED("", "C1", {{"P1", 1}}, "", 0, "", BOHOJE())
    GEBFATLIB("PV000003")
    aR := GEBFATFAT("PV000003", {}, BOHOJE(), "")
    lOk := Chk(lOk, "sem resposta fica pendente", !aR[1] .And. "pendente" $ aR[2])
    BOSETPARM("DFE_URL_NFEAUTORIZACAO", "https://127.0.0.1:18766/sefaz")
    BOSETPARM("DFE_NFE_INFCPL", "DEMORA")
    BOSETPARM("DFE_TIMEOUT", "2")
    aR := GEBFATFAT("PV000003", {}, BOHOJE(), "")
    lOk := Chk(lOk, "sefaz lenta fica pendente", !aR[1] .And. "pendente" $ aR[2])
    BOSETPARM("DFE_NFE_INFCPL", "")
    BOSETPARM("DFE_TIMEOUT", "10")
    aR := GEBDFERESOLVE()
    lOk := Chk(lOk, "resolver pendentes", aR[1] .And. aR[3][1] == 1 .And. aR[3][2] == 1)
    If !aR[1]
        ConOut("    " + aR[2])
    EndIf
    lOk := Chk(lOk, "pedido segue a faturar", GEBFATFAT("PV000003", {}, BOHOJE(), "")[1])

    // Regime normal: DIFAL para nao contribuinte de outra UF ainda nao.
    GEBDFEEMIT(Emit("3"))
    GEBFATCLI("C3", "Consumidor Rio", "11144477735", "RJ", 0, "", "")
    GEBDFEPART(Part("C", "C3", "11144477735", "9", "", "RJ", "3304557"))
    GEBFATPED("", "C3", {{"P1", 1}}, "", 0, "", BOHOJE())
    GEBFATLIB("PV000004")
    // 50,00 a 12% interestadual; DIFAL RJ (20 - 12)% = 4,00 + FCP 2% = 1,00 => titulo de 5,00.
    aR := GEBFATFAT("PV000004", {}, BOHOJE(), "")
    lOk := Chk(lOk, "nfe com difal", aR[1])
    If aR[1]
        cX := GEBDFEDOC(aR[3][1])[3]
        lOk := Chk(lOk, "xml difal", "<pICMS>12.00</pICMS>" $ cX .And. "<pICMSUFDest>20.00</pICMSUFDest>" $ cX .And. "<vICMSUFDest>4.00</vICMSUFDest>" $ cX .And. ;
            "<vFCPUFDest>1.00</vFCPUFDest>" $ cX)
        aD := TCSqlQuery("SELECT GFN3_VALOR AS V FROM GFN3 WHERE GFN3_DOC LIKE 'DIFAL-RJ-%'")
        lOk := Chk(lOk, "titulo do difal", Len(aD) == 1 .And. BOVAL(aD[1]:V) == 5)
    Else
        ConOut("    " + aR[2])
    EndIf
Return Fim(lOk, cDir)

Static Function Fim(lOk, cDir)
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdfenfe CASCADE")
    ProcRun("rm", {"-rf", cDir}, {|c| c})
    If lOk
        ConOut("T_GEBDFE_NFE PASS")
    Else
        ConOut("T_GEBDFE_NFE FAIL")
    EndIf
Return lOk

Static Function Openssl(aArgs)
    Local aOut := {}
Return ProcRun("openssl", aArgs, {|c| aAdd(aOut, c)}, {|c| aAdd(aOut, c)})

Static Function Part(cTipo, cCod, cDoc, cInd, cIE, cUF, cMun)
    Local o := JsonObject():New()
    o["TIPO"] := cTipo
    o["CODIGO"] := cCod
    o["DOC"] := cDoc
    o["CONTRIBUINTE"] := cInd
    o["IE"] := cIE
    o["LOGRADOURO"] := "Rua do Cliente"
    o["NUMERO"] := "10"
    o["BAIRRO"] := "Centro"
    o["UF"] := cUF
    o["MUNICIPIO"] := cMun
    o["CEP"] := "20000000"
Return o

Static Function Emit(cCRT)
    Local o := JsonObject():New()
    o["CNPJ"] := "12345678000195"
    o["IE"] := "110042490114"
    o["RAZAO"] := "Empresa Teste Ltda"
    o["CRT"] := cCRT
    o["LOGRADOURO"] := "Rua das Bananeiras"
    o["NUMERO"] := "100"
    o["BAIRRO"] := "Centro"
    o["UF"] := "SP"
    o["MUNICIPIO"] := "3550308"
    o["CEP"] := "01001000"
Return o

Static Function Chk(lOk, cNome, lCond)
    If lCond
        ConOut("  OK " + cNome)
        Return lOk
    EndIf
    ConOut("  FAIL: " + cNome)
Return .F.
