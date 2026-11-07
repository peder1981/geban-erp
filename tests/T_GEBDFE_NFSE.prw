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

/*/{Protheus.doc} T_GEBDFE_NFSE
    NFS-e nacional de ponta a ponta contra o emulador (REST/JSON da Sefin
    Nacional na porta 18766): servico fiscal, faturamento de servico
    (NFS-e + livro + titulo), codigo de tributacao inexistente (400 E0310),
    Sefin lenta (DPS gerada sem resposta => resolver cancela), sem
    comunicacao (resolver: DPS nao consta => liberada), cancelamento e
    DANFSe em PDF.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 19/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBDFE_NFSE()
    Local lOk := .T.
    Local aR := {}
    Local o := Nil
    Local cDir := "/tmp/geban-tdfensfe-" + StrZero(Randomize(1, 999999), 6)
    Local cCh := ""
    Local cX := ""

    If !GEBDBConecta()
        ConOut("T_GEBDFE_NFSE FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdfensfe CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebdfensfe")
    TCSqlExec("SET search_path TO test_gebdfensfe")
    lOk := Chk(lOk, "mig", GENMIG() .And. GEBFMIG() .And. GEBFATMIG() .And. GEBDFENFSEMIG())
    GEBFNCON("CAIXA", "Caixa")
    BOSETPARM("DFE_CERT_DIR", cDir + "/cert")
    BOSETPARM("DFE_URL_SEFIN", "https://127.0.0.1:18766/SefinNacional")
    BOSETPARM("DFE_URL_ADN", "https://127.0.0.1:18766")
    BOSETPARM("DFE_TIMEOUT", "10")
    BOSETPARM("DFE_NFSE", "S")
    ProcRun("mkdir", {"-p", cDir}, {|c| c})
    Openssl({"req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", cDir + "/k.pem", "-out", cDir + "/c.pem", "-days", "60", "-subj", ;
        "/C=BR/O=ICP-Brasil/CN=EMPRESA TESTE LTDA:12345678000195"})
    Openssl({"pkcs12", "-export", "-inkey", cDir + "/k.pem", "-in", cDir + "/c.pem", "-out", cDir + "/emp.pfx", "-passout", "pass:Senha123"})
    o := Emit("")
    lOk := Chk(lOk, "emitente", GEBDFEEMIT(o)[1])
    lOk := Chk(lOk, "certificado", GEBDFECERT(Encode64(MemoRead(cDir + "/emp.pfx")), "Senha123")[1])

    // Servicos.
    lOk := Chk(lOk, "servico invalido", !GEBDFESERV(Serv("S0", "12"))[1])
    lOk := Chk(lOk, "servico", GEBDFESERV(Serv("S1", "010101"))[1] .And. GEBDFESERV(Serv("S9", "999999"))[1])
    GEBFATCLI("C1", "Cliente Servico", "11222333000181", "RJ", 0, "", "")
    lOk := Chk(lOk, "cadastro fiscal", GEBDFEPART(Part("C1"))[1])

    // Sem inscricao municipal: recusa. Com: gera.
    lOk := Chk(lOk, "nfse sem inscricao municipal", "inscricao_municipal" $ GEBFATSERV("C1", "S1", 1500, "outubro", "", BOHOJE())[2])
    GEBDFEEMIT(Emit("1234567"))
    aR := GEBFATSERV("C1", "S1", 1500, "Mensalidade outubro/2026", "30", BOHOJE(), .F., 50)
    lOk := Chk(lOk, "nfse gerada", aR[1] .And. Len(aR[3][1]) == 50 .And. aR[3][2] == 1450)
    If !aR[1]
        ConOut("    " + aR[2])
        Return Fim(.F., cDir)
    EndIf
    cCh := aR[3][1]
    cX := GEBDFEDOC(cCh)[3]
    lOk := Chk(lOk, "xml da nfse", "<NFSe" $ cX .And. "<cTribNac>010101</cTribNac>" $ cX .And. "<vDescIncond>50.00</vDescIncond>" $ cX .And. ;
        "<CNPJ>11222333000181</CNPJ>" $ cX .And. "<opSimpNac>3</opSimpNac>" $ cX)
    lOk := Chk(lOk, "livro e titulo", BOCOL(TCSqlQuery("SELECT GF3_STATUS AS S FROM GF3 WHERE GF3_CHAVE = " + GEBDBQuote(cCh))[1]:S) == "AUTORIZADA" .And. ;
        BOVAL(TCSqlQuery("SELECT SUM(GFN2_VALOR) AS V FROM GFN2 WHERE GFN2_DOC LIKE " + GEBDBQuote(cCh + "%"))[1]:V) == 1450)
    aR := GEBDFEDANFSE(cCh)
    lOk := Chk(lOk, "danfse pdf", aR[1] .And. Left(aR[3], 4) == "%PDF")

    // Rejeicao: codigo de tributacao inexistente.
    aR := GEBFATSERV("C1", "S9", 100, "", "", BOHOJE())
    lOk := Chk(lOk, "nfse rejeitada", !aR[1] .And. "E0310" $ aR[2] .And. Len(TCSqlQuery("SELECT GF3_CHAVE FROM GF3")) == 1)

    // Sefin lenta (gera e nao responde) e sem comunicacao.
    BOSETPARM("DFE_TIMEOUT", "2")
    aR := GEBFATSERV("C1", "S1", 200, "DEMORA", "", BOHOJE())
    lOk := Chk(lOk, "sefin lenta fica pendente", !aR[1] .And. "pendente" $ aR[2])
    BOSETPARM("DFE_URL_SEFIN", "https://127.0.0.1:1/SefinNacional")
    aR := GEBFATSERV("C1", "S1", 300, "", "", BOHOJE())
    lOk := Chk(lOk, "sem comunicacao fica pendente", !aR[1] .And. "pendente" $ aR[2])
    BOSETPARM("DFE_URL_SEFIN", "https://127.0.0.1:18766/SefinNacional")
    BOSETPARM("DFE_TIMEOUT", "10")
    aR := GEBDFENFSERESOLVE()
    lOk := Chk(lOk, "resolver pendentes", aR[1] .And. aR[3][1] == 1 .And. aR[3][2] == 1)
    If !aR[1]
        ConOut("    " + aR[2])
    EndIf

    // Cancelamento.
    lOk := Chk(lOk, "cancelamento justificativa curta", !GEBDFENFSECANC(cCh, "2", "curta")[1])
    aR := GEBDFENFSECANC(cCh, "2", "Servico nao prestado no periodo")
    lOk := Chk(lOk, "cancelamento", aR[1] .And. GEBDFEDOC(cCh)[1] == "CANCELADA" .And. ;
        BOCOL(TCSqlQuery("SELECT GF3_STATUS AS S FROM GF3 WHERE GF3_CHAVE = " + GEBDBQuote(cCh))[1]:S) == "CANCELADA")
    If !aR[1]
        ConOut("    " + aR[2])
    EndIf
    lOk := Chk(lOk, "cancelar de novo", !GEBDFENFSECANC(cCh, "2", "Servico nao prestado no periodo")[1])
Return Fim(lOk, cDir)

Static Function Fim(lOk, cDir)
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdfensfe CASCADE")
    ProcRun("rm", {"-rf", cDir}, {|c| c})
    If lOk
        ConOut("T_GEBDFE_NFSE PASS")
    Else
        ConOut("T_GEBDFE_NFSE FAIL")
    EndIf
Return lOk

Static Function Openssl(aArgs)
    Local aOut := {}
Return ProcRun("openssl", aArgs, {|c| aAdd(aOut, c)}, {|c| aAdd(aOut, c)})

Static Function Serv(cCod, cNac)
    Local o := JsonObject():New()
    o["CODIGO"] := cCod
    o["DESCRICAO"] := "Desenvolvimento de software"
    o["TRIB_NACIONAL"] := cNac
    o["NBS"] := "115013000"
    o["ALIQ_ISS"] := 5
Return o

Static Function Part(cCod)
    Local o := JsonObject():New()
    o["TIPO"] := "C"
    o["CODIGO"] := cCod
    o["DOC"] := "11222333000181"
    o["CONTRIBUINTE"] := "9"
    o["LOGRADOURO"] := "Av Brasil"
    o["NUMERO"] := "1"
    o["BAIRRO"] := "Centro"
    o["UF"] := "RJ"
    o["MUNICIPIO"] := "3304557"
    o["CEP"] := "20000000"
Return o

Static Function Emit(cIM)
    Local o := JsonObject():New()
    o["CNPJ"] := "12345678000195"
    o["IE"] := "110042490114"
    o["IM"] := cIM
    o["RAZAO"] := "Empresa Teste Ltda"
    o["CRT"] := "1"
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
