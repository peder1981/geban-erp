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

/*/{Protheus.doc} T_GEBDFE_DIST
    Recebimento de NF-e de fornecedores contra o emulador (Ambiente Nacional):
    distribuicao por NSU (resumos e cancelamento do emitente), 137 e 656,
    ciencia da operacao (nota completa), de-para com fator, importacao como
    entrada de compra (pedido gerado da nota) e chave vinculada.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 19/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBDFE_DIST()
    Local lOk := .T.
    Local aR := {}
    Local aServ := {"NfeDistribuicaoDFe", "RecepcaoEvento"}
    Local cDir := "/tmp/geban-tdfedist-" + StrZero(Randomize(1, 999999), 6)
    Local cA := ""
    Local cB := ""
    Local nI := 0

    If !GEBDBConecta()
        ConOut("T_GEBDFE_DIST FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdfedist CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebdfedist")
    TCSqlExec("SET search_path TO test_gebdfedist")
    lOk := Chk(lOk, "mig", GENMIG() .And. GEBFMIG() .And. GEBCPXMIG() .And. GEBDFEDISTMIG())
    GEBFNCON("CAIXA", "Caixa")
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'P1', '08039000', 'Banana unidade'), " + ;
        "(' ', '      ', 'P2', '08081000', 'Maca kg')")
    BOSETPARM("DFE_CERT_DIR", cDir + "/cert")
    For nI := 1 To Len(aServ)
        BOSETPARM("DFE_URL_" + Upper(aServ[nI]), "https://127.0.0.1:18766/sefaz")
    Next nI
    ProcRun("mkdir", {"-p", cDir}, {|c| c})
    Openssl({"req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", cDir + "/k.pem", "-out", cDir + "/c.pem", "-days", "60", "-subj", ;
        "/C=BR/O=ICP-Brasil/CN=MERCADO RECEBEDOR LTDA:11222333000181"})
    Openssl({"pkcs12", "-export", "-inkey", cDir + "/k.pem", "-in", cDir + "/c.pem", "-out", cDir + "/emp.pfx", "-passout", "pass:Senha123"})
    lOk := Chk(lOk, "emitente", GEBDFEEMIT(Emit())[1])
    lOk := Chk(lOk, "certificado", GEBDFECERT(Encode64(MemoRead(cDir + "/emp.pfx")), "Senha123")[1])

    // Busca: 2 resumos + cancelamento da 2a pelo emitente.
    aR := GEBDFEDISTBUSCA()
    lOk := Chk(lOk, "busca", aR[1] .And. aR[3] == 3)
    If !aR[1]
        ConOut("    " + aR[2])
        Return Fim(.F., cDir)
    EndIf
    aR := TCSqlQuery("SELECT GDFE_CHAVE AS C, GDFE_SIT AS S, GDFE_VNF AS V FROM GDFE ORDER BY GDFE_VNF DESC")
    lOk := Chk(lOk, "notas recebidas", Len(aR) == 2 .And. BOCOL(aR[1]:S) == "AUTORIZADA" .And. BOVAL(aR[1]:V) == 288 .And. BOCOL(aR[2]:S) == "CANCELADA")
    cA := BOCOL(aR[1]:C)
    cB := BOCOL(aR[2]:C)
    lOk := Chk(lOk, "ultimo nsu", Val(BOPARM("DFE_ULTNSU", "0")) == 3)
    aR := GEBDFEDISTBUSCA()
    lOk := Chk(lOk, "nada novo (137)", aR[1] .And. aR[3] == 0)
    aR := GEBDFEDISTBUSCA()
    lOk := Chk(lOk, "consumo indevido (656)", !aR[1] .And. "656" $ aR[2])

    // Importar so' com o resumo: recusa. Ciencia baixa a nota completa.
    lOk := Chk(lOk, "importar resumo", "ciencia" $ GEBDFEIMPORTA(cA, "", BOHOJE())[2])
    lOk := Chk(lOk, "manifestacao sem justificativa", !GEBDFEMANIF(cB, "NAO_REALIZADA", "")[1])
    aR := GEBDFEMANIF(cA, "CIENCIA", "")
    lOk := Chk(lOk, "ciencia", aR[1] .And. "<det " $ BOSTR(TCSqlQuery("SELECT GDFE_XML AS X FROM GDFE WHERE GDFE_CHAVE = " + GEBDBQuote(cA))[1]:X))
    If !aR[1]
        ConOut("    " + aR[2])
    EndIf

    // De-para e importacao (fornecedor criado pelo CNPJ: F77000161).
    aR := GEBDFEIMPORTA(cA, "", BOHOJE())
    lOk := Chk(lOk, "importar sem de-para", !aR[1] .And. "FORN-BAN" $ aR[2] .And. "FORN-MAC" $ aR[2] .And. ;
        BOCOL(TCSqlQuery("SELECT GCP1_CNPJ AS C FROM GCP1 WHERE GCP1_COD = 'F77000161'")[1]:C) == "11444777000161")
    lOk := Chk(lOk, "de-para", GEBDFEDEPARA("F77000161", "FORN-BAN", "P1", 12)[1] .And. GEBDFEDEPARA("F77000161", "FORN-MAC", "P2", 1)[1])
    aR := GEBDFEIMPORTA(cA, "", BOHOJE())
    lOk := Chk(lOk, "importada", aR[1] .And. GEBESTSLD("P1", "01")[1] == 120 .And. GEBESTSLD("P2", "01")[1] == 5)
    If !aR[1]
        ConOut("    " + aR[2])
    EndIf
    lOk := Chk(lOk, "chave vinculada a entrada", GEBDFEVINCLE("ENT", "456", "F77000161") == cA)
    lOk := Chk(lOk, "importar de novo", "ja_importada" $ GEBDFEIMPORTA(cA, "", BOHOJE())[2])
    lOk := Chk(lOk, "nota cancelada nao importa", "cancelada" $ GEBDFEIMPORTA(cB, "", BOHOJE())[2])
    lOk := Chk(lOk, "confirmacao", GEBDFEMANIF(cA, "CONFIRMACAO", "")[1])
    lOk := Chk(lOk, "relatorio", GEBDFERECEBIDAS("")[3] == 2)
Return Fim(lOk, cDir)

Static Function Fim(lOk, cDir)
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdfedist CASCADE")
    ProcRun("rm", {"-rf", cDir}, {|c| c})
    If lOk
        ConOut("T_GEBDFE_DIST PASS")
    Else
        ConOut("T_GEBDFE_DIST FAIL")
    EndIf
Return lOk

Static Function Openssl(aArgs)
    Local aOut := {}
Return ProcRun("openssl", aArgs, {|c| aAdd(aOut, c)}, {|c| aAdd(aOut, c)})

Static Function Emit()
    Local o := JsonObject():New()
    o["CNPJ"] := "11222333000181"
    o["IE"] := "110042490114"
    o["RAZAO"] := "Mercado Recebedor Ltda"
    o["CRT"] := "1"
    o["LOGRADOURO"] := "Rua A"
    o["NUMERO"] := "1"
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
