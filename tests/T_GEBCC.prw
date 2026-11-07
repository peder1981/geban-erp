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

/*/{Protheus.doc} T_GEBCC
    Teste de centro de custo (GEBCTX + financeiro, faturamento e loja).
    Valores calculados a mao: aluguel de 100,00 no rateio ADM 60% / VEN 40%;
    despesa de 300,00 no ADM; pedido no VEN (10 x 10,00, custo 6,00) e caixa
    da loja no LOJA (5 x 10,00). DRE: ADM -360; VEN 100 - 60 - 40 = 0; LOJA
    50 - 30 = 20; total -340; sem centro 0.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 18/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBCC()
    Local lOk := .T.
    Local aR := {}
    Local cSes := ""

    If !GEBDBConecta()
        ConOut("T_GEBCC FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebcc CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebcc")
    TCSqlExec("SET search_path TO test_gebcc")
    lOk := Chk(lOk, "mig", GENMIG() .And. GEBFMIG() .And. GEBLOJMIG())
    GEBFNCON("CAIXA", "Caixa")
    GEBFATPRC("", "P1", 10)
    GEBFATCLI("C1", "Cliente 1", "", "SP", 0, "", "")
    GEBESTMOV("P1", "", "E", 100, 6, "COMPRA", "X", "20261001")

    // Cadastros
    lOk := Chk(lOk, "cc adm", GEBCTXCC("adm", "Administrativo", "")[1])
    GEBCTXCC("VEN", "Vendas", "")
    GEBCTXCC("LOJA", "Loja", "")
    GEBCTXCC("OLD", "Antigo", "S")
    lOk := Chk(lOk, "rateio", GEBCTXRAT("RAT1", {{"ADM", 60}, {"VEN", 40}})[1])
    lOk := Chk(lOk, "rateio soma", !GEBCTXRAT("RAT2", {{"ADM", 60}, {"VEN", 30}})[1])
    lOk := Chk(lOk, "rateio cc inexistente", !GEBCTXRAT("RAT2", {{"ADM", 60}, {"XXX", 40}})[1])
    lOk := Chk(lOk, "rateio com codigo de centro", !GEBCTXRAT("ADM", {{"VEN", 100}})[1])
    aR := GEBCTXRATEIA("RAT1", 100.01)
    lOk := Chk(lOk, "rateia centavo", aR[1] .And. aR[3][1][2] == 60.01 .And. aR[3][2][2] == 40)

    // Lancamentos com centro
    lOk := Chk(lOk, "mov rateio", GEBFXMOV("CAIXA", "D", 100, "Aluguel", "20261005", "", "RAT1")[1])
    lOk := Chk(lOk, "mov bloqueado", !GEBFXMOV("CAIXA", "D", 10, "x", "20261005", "", "OLD")[1])
    lOk := Chk(lOk, "mov inexistente", !GEBFXMOV("CAIXA", "D", 10, "x", "20261005", "", "NADA")[1])
    lOk := Chk(lOk, "caixa so o aluguel", BOVAL(TCSqlQuery("SELECT GFN1_SALDO AS S FROM GFN1 WHERE GFN1_CONTA = 'CAIXA'")[1]:S) == -100)
    lOk := Chk(lOk, "despesa", GEBFXDESP("NFD1", "F1", 300, "0", "20261006", "", "ADM", "Energia")[1])
    lOk := Chk(lOk, "despesa titulo", BOVAL(TCSqlQuery("SELECT GFN3_VALOR AS V FROM GFN3 WHERE GFN3_DOC = 'NFD1'")[1]:V) == 300)
    lOk := Chk(lOk, "despesa conta inexistente", !GEBFXDESP("NFD2", "F1", 10, "0", "20261006", "9.99", "ADM", "")[1])
    lOk := Chk(lOk, "pedido cc inexistente", !GEBFATPED("", "C1", {{"P1", 10}}, "", 0, "", "20261007", "NADA")[1])
    aR := GEBFATPED("", "C1", {{"P1", 10}}, "", 0, "", "20261007", "VEN")
    GEBFATLIB(aR[3][1])
    lOk := Chk(lOk, "fatura com cc", GEBFATFAT(aR[3][1], {}, "20261007", "")[1])
    lOk := Chk(lOk, "caixa com cc", GEBLOJCX("01", "Caixa 1", "", "", "LOJA")[1])
    cSes := GEBLOJABRE("01", "maria", 0, "20261008")[3]
    lOk := Chk(lOk, "venda loja", GEBLOJVEN(cSes, {{"P1", 5}}, {{"DINHEIRO", 50}}, "", 0)[1])

    // Relatorios
    aR := GEBCTXDRE("20261001", "20261031", "ADM")
    lOk := Chk(lOk, "dre adm", aR[1] .And. Chave(aR[3], "despesas") == 360 .And. Chave(aR[3], "resultado") == -360)
    aR := GEBCTXDRE("20261001", "20261031", "VEN")
    lOk := Chk(lOk, "dre ven", aR[1] .And. Chave(aR[3], "receita_bruta") == 100 .And. Chave(aR[3], "cmv") == 60 .And. Chave(aR[3], "resultado") == 0)
    aR := GEBCTXBALAN("20261001", "20261031", "LOJA")
    lOk := Chk(lOk, "balancete loja fechado", aR[1] .And. Chave(aR[3][2], "fechado") == "S" .And. Chave(aR[3][2], "debitos") == 80)
    aR := GEBCTXCCRES("20261001", "20261031")
    lOk := Chk(lOk, "resultado por centro", aR[1] .And. Len(aR[3]) == 6 .And. aR[3][2][1] == "ADM" .And. aR[3][2][8] == -360 .And. ;
        aR[3][3][8] == 20 .And. aR[3][6][1] == "(sem centro)" .And. aR[3][6][8] == 0)
    lOk := Chk(lOk, "dre total", Chave(GEBCTXDRE("20261001", "20261031")[3], "resultado") == -340)

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebcc CASCADE")
    If lOk
        ConOut("T_GEBCC PASS")
    Else
        ConOut("T_GEBCC FAIL")
    EndIf
Return lOk

Static Function Chave(aP, cK)
    Local nI := 0
    For nI := 1 To Len(aP)
        If aP[nI][1] == cK
            Return aP[nI][2]
        EndIf
    Next nI
Return Nil

Static Function Chk(lOk, cNome, lCond)
    If !lCond
        ConOut("  FAIL: " + cNome)
        Return .F.
    EndIf
Return lOk
