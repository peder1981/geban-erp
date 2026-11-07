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
#include "../src/GEBBOLIB.prw"
#include "../src/GEBCTX.prw"
#include "../src/GEBEST.prw"
#include "../src/GEBFNX.prw"
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
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBTEF
    Teste do TEF (GEBTEF) e da venda com cartao na frente de loja.
    - simulador: aprova, confirma, cancela; nega valor com centavos 51;
      debito nao parcela; pendentes sao desfeitos (GEBTEFRESOLVE).
    - resposta JSON do gateway HTTP: aprovada, negada, invalida, vazia.
    - venda: credito 3x de 90,00 => 3 parcelas a 30/60/90 dias, transacao
      CONFIRMADA; cartao negado na mesma venda desfaz o debito ja aprovado e
      nada e' gravado; cancelamento do cupom estorna (CANCELADA); provedor
      HTTP sem URL recusa; LOJ_TEF = N registra o cartao sem TEF.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 18/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBTEF()
    Local lOk := .T.
    Local aR := {}
    Local cSes := ""
    Local cCup := ""
    Local cId := ""
    Local nCup := 0

    If !GEBDBConecta()
        ConOut("T_GEBTEF FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebtef CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebtef")
    TCSqlExec("SET search_path TO test_gebtef")
    lOk := Chk(lOk, "mig", GENMIG() .And. GEBFMIG() .And. GEBLOJMIG())

    // Fases no simulador
    aR := GEBTEFAUT("CREDITO", 100, 3, "REF1")
    lOk := Chk(lOk, "autoriza", aR[1] .And. !(aR[3][2] == "") .And. Len(aR[3][3]) == 6)
    cId := aR[3][1]
    lOk := Chk(lOk, "pendente", BOCOL(TCSqlQuery("SELECT GLJ7_STATUS AS S FROM GLJ7 WHERE GLJ7_ID = " + GEBDBQuote(cId))[1]:S) == "PENDENTE")
    lOk := Chk(lOk, "cancela pendente", !GEBTEFCANC(cId)[1])
    lOk := Chk(lOk, "confirma", GEBTEFCONF(cId)[1])
    lOk := Chk(lOk, "confirma de novo", !GEBTEFCONF(cId)[1])
    lOk := Chk(lOk, "cancela", GEBTEFCANC(cId)[1])
    aR := GEBTEFAUT("DEBITO", 10.51, 1, "REF2")
    lOk := Chk(lOk, "negado", !aR[1] .And. "saldo insuficiente" $ aR[2])
    lOk := Chk(lOk, "negado gravado", BOCOL(TCSqlQuery("SELECT GLJ7_STATUS AS S FROM GLJ7 WHERE GLJ7_REF = 'REF2'")[1]:S) == "NEGADA")
    lOk := Chk(lOk, "debito parcelado", !GEBTEFAUT("DEBITO", 10, 2, "REF3")[1])
    GEBTEFAUT("DEBITO", 5, 1, "REF4")
    GEBTEFAUT("CREDITO", 6, 1, "REF5")
    aR := GEBTEFRESOLVE()
    lOk := Chk(lOk, "resolve pendentes", aR[1] .And. aR[3] == 2)

    // Resposta do gateway HTTP
    aR := GEBTEFRESP('{"aprovada":true,"nsu":"000123","autorizacao":"A1B2","bandeira":"VISA","mensagem":"ok"}')
    lOk := Chk(lOk, "resp aprovada", aR[1] .And. aR[3][1] == "000123" .And. aR[3][3] == "VISA")
    aR := GEBTEFRESP('{"aprovada":false,"mensagem":"cartao bloqueado"}')
    lOk := Chk(lOk, "resp negada", !aR[1] .And. aR[2] == "cartao bloqueado")
    lOk := Chk(lOk, "resp invalida", !GEBTEFRESP("<html>erro</html>")[1])
    lOk := Chk(lOk, "resp vazia", !GEBTEFRESP("")[1])

    // Venda com cartao
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'P1', 'N1', 'Produto 1')")
    GEBFATPRC("", "P1", 10)
    GEBESTMOV("P1", "", "E", 100, 4, "COMPRA", "X", "20261001")
    GEBLOJCX("01", "Caixa 1", "", "", "")
    cSes := GEBLOJABRE("01", "maria", 0, "20261015")[3]
    lOk := Chk(lOk, "parcela no debito", !GEBLOJVEN(cSes, {{"P1", 1}}, {{"DEBITO", 10, 2}}, "", 0)[1])
    aR := GEBLOJVEN(cSes, {{"P1", 9}}, {{"CREDITO", 90, 3}}, "", 0)
    lOk := Chk(lOk, "venda credito 3x", aR[1])
    cCup := aR[3][1]
    aR := TCSqlQuery("SELECT GFN2_VENC AS V, GFN2_VALOR AS VL FROM GFN2 WHERE GFN2_DOC LIKE " + GEBDBQuote("CRT-" + cCup + "-01/%") + " ORDER BY GFN2_DOC")
    lOk := Chk(lOk, "parcelas do cartao", Len(aR) == 3 .And. BOCOL(aR[3]:V) == "20270113" .And. BOVAL(aR[1]:VL) == 29.1)
    lOk := Chk(lOk, "tef confirmada", BOCOL(TCSqlQuery("SELECT GLJ7_STATUS AS S FROM GLJ7 WHERE GLJ7_REF = " + GEBDBQuote(cCup))[1]:S) == "CONFIRMADA")
    nCup := Len(TCSqlQuery("SELECT GLJ3_CUPOM FROM GLJ3"))
    aR := GEBLOJVEN(cSes, {{"P1", 2}}, {{"DEBITO", 9.49}, {"CREDITO", 10.51}}, "", -0.0)
    lOk := Chk(lOk, "cartao negado", !aR[1] .And. "negado" $ aR[2])
    lOk := Chk(lOk, "nada gravado", Len(TCSqlQuery("SELECT GLJ3_CUPOM FROM GLJ3")) == nCup .And. GEBESTSLD("P1", "01")[1] == 91)
    lOk := Chk(lOk, "debito desfeito", Len(TCSqlQuery("SELECT GLJ7_ID FROM GLJ7 WHERE GLJ7_FORMA = 'DEBITO' AND GLJ7_VALOR = 9.49 AND GLJ7_STATUS = 'DESFEITA'")) == 1)
    lOk := Chk(lOk, "cancela cupom", GEBLOJCAN(cCup, "teste")[1])
    lOk := Chk(lOk, "tef estornada", BOCOL(TCSqlQuery("SELECT GLJ7_STATUS AS S FROM GLJ7 WHERE GLJ7_REF = " + GEBDBQuote(cCup))[1]:S) == "CANCELADA")
    // Provedor CIELO contra o emulador local (tests/emuladores/cielo_emulador.py, porta 18765).
    aR := GEBTEFCIELO("autorizar", '{"Payment":{"Status":3,"ReturnCode":"05","ReturnMessage":"Not Authorized"}}', "")
    lOk := Chk(lOk, "cielo resp negada", !aR[1] .And. "05" $ aR[2])
    aR := GEBTEFCIELO("confirmar", '[{"Code":308,"Message":"Transaction not available to capture"}]', "X")
    lOk := Chk(lOk, "cielo resp erro", !aR[1] .And. "308" $ aR[2])
    aR := GEBTEFCIELO("autorizar", '{"Payment":{"PaymentId":"abc","Status":1,"ProofOfSale":"000123","AuthorizationCode":"654321","ReturnMessage":"ok","CreditCard":{"Brand":"Master"}}}', "")
    lOk := Chk(lOk, "cielo resp aprovada", aR[1] .And. aR[3][1] == "000123" .And. aR[3][3] == "Master" .And. aR[3][4] == "abc")
    BOSETPARM("LOJ_TEF_PROVEDOR", "CIELO")
    lOk := Chk(lOk, "cielo sem credencial", !GEBTEFAUT("CREDITO", 10, 1, "RC0")[1])
    lOk := Chk(lOk, "cfg provedor invalido", !GEBTEFCFG("XPTO", "", "", "", "", "")[1])
    lOk := Chk(lOk, "cfg cielo", GEBTEFCFG("cielo", "http://127.0.0.1:18765", "mid-teste", "key-teste", "", "")[1] .And. ;
        BOPARM("LOJ_CIELO_URL", "") == "http://127.0.0.1:18765" .And. BOPARM("LOJ_CIELO_MERCHANTKEY", "") == "key-teste" .And. ;
        GEBTEFCFG("", "", "", "", "", "")[2] == "TEF configurado: provedor CIELO")
    BOSETPARM("LOJ_CIELO_CARTAO", "4024007153763191")
    aR := GEBLOJVEN(cSes, {{"P1", 3}}, {{"CREDITO", 30, 2}}, "", 0)
    lOk := Chk(lOk, "cielo venda", aR[1])
    cCup := aR[3][1]
    aR := TCSqlQuery("SELECT GLJ7_STATUS AS S, GLJ7_EXTID AS X, GLJ7_NSU AS N FROM GLJ7 WHERE GLJ7_REF = " + GEBDBQuote(cCup))
    lOk := Chk(lOk, "cielo capturada", Len(aR) == 1 .And. BOCOL(aR[1]:S) == "CONFIRMADA" .And. Len(BOCOL(aR[1]:X)) == 36 .And. !(BOCOL(aR[1]:N) == ""))
    lOk := Chk(lOk, "cielo cancela", GEBLOJCAN(cCup, "teste")[1])
    lOk := Chk(lOk, "cielo estornada", BOCOL(TCSqlQuery("SELECT GLJ7_STATUS AS S FROM GLJ7 WHERE GLJ7_REF = " + GEBDBQuote(cCup))[1]:S) == "CANCELADA")
    BOSETPARM("LOJ_CIELO_CARTAO", "4024007153763192")
    aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"CREDITO", 10}}, "", 0)
    lOk := Chk(lOk, "cielo negada", !aR[1] .And. "05" $ aR[2])
    BOSETPARM("LOJ_CIELO_CARTAO", "4024007153763191")
    BOSETPARM("LOJ_TEF_PROVEDOR", "HTTP")
    lOk := Chk(lOk, "http sem url", !GEBLOJVEN(cSes, {{"P1", 1}}, {{"DEBITO", 10}}, "", 0)[1])
    BOSETPARM("LOJ_TEF", "N")
    lOk := Chk(lOk, "sem tef", GEBLOJVEN(cSes, {{"P1", 1}}, {{"DEBITO", 10}}, "", 0)[1])
    aR := GEBTEFREL(BOHOJE())
    lOk := Chk(lOk, "rel tef", aR[1] .And. Len(aR[3][1]) >= 8)

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebtef CASCADE")
    If lOk
        ConOut("T_GEBTEF PASS")
    Else
        ConOut("T_GEBTEF FAIL")
    EndIf
Return lOk

Static Function Chk(lOk, cNome, lCond)
    If !lCond
        ConOut("  FAIL: " + cNome)
        Return .F.
    EndIf
Return lOk
