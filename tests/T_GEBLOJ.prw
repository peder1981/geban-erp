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

/*/{Protheus.doc} T_GEBLOJ
    Teste da frente de loja (GEBLOJ). Valores calculados a mao:
    - venda 1: 3 P1 (10,00) + 1 P2 (20,00) = 50,00 - desconto 5,00 = 45,00
      (rateio 27,00 + 18,00), pago 50,00 em dinheiro, troco 5,00.
    - venda 2: 2 P1 = 20,00 em PIX; venda 3: 2 P2 = 40,00 em debito 10,00
      (taxa 1,5% = 0,15) + credito 30,00 (taxa 3% = 0,90); venda 4: 1 P1 =
      10,00 fiado. Vendas 2 e 4 canceladas.
    - fundo 100,00 + dinheiro 45,00 + suprimento 50,00 - sangria 30,00 =
      165,00 esperado; contado 160,00 => falta de 5,00.
    - contabil: receita 85,00, CMV 48,00, cartoes a receber 38,95, caixa 60,00.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 18/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBLOJ()
    Local lOk := .T.
    Local aR := {}
    Local cSes := ""
    Local cC2 := ""
    Local cC3 := ""
    Local cC4 := ""

    If !GEBDBConecta()
        ConOut("T_GEBLOJ FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebloj CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebloj")
    TCSqlExec("SET search_path TO test_gebloj")
    lOk := Chk(lOk, "mig", GENMIG() .And. GEBFMIG() .And. GEBLOJMIG())
    GEBFNCON("BANCO", "Banco")
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'P1', 'N1', 'Produto 1'), (' ', '      ', 'P2', 'N2', 'Produto 2')")
    TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'N1', 10, 5, '20200101', '20991231')")
    GEBFATPRC("", "P1", 10)
    GEBFATPRC("", "P2", 20)
    GEBFATCLI("C1", "Cliente 1", "", "SP", 0, "", "")
    GEBESTMOV("P1", "", "E", 100, 4, "COMPRA", "X", "20261001")
    GEBESTMOV("P2", "", "E", 50, 12, "COMPRA", "X", "20261001")

    // Caixa e sessao
    lOk := Chk(lOk, "caixa", GEBLOJCX("01", "Caixa 1", "", "")[1])
    lOk := Chk(lOk, "abrir caixa inexistente", !GEBLOJABRE("99", "maria", 100, "20261015")[1])
    aR := GEBLOJABRE("01", "maria", 100, "20261015")
    lOk := Chk(lOk, "abrir", aR[1])
    cSes := aR[3]
    lOk := Chk(lOk, "abrir de novo", !GEBLOJABRE("01", "joao", 0, "20261015")[1])

    // Vendas
    lOk := Chk(lOk, "sessao inexistente", !GEBLOJVEN("S9", {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 0)[1])
    lOk := Chk(lOk, "troco fora do dinheiro", !GEBLOJVEN(cSes, {{"P1", 1}}, {{"PIX", 15}}, "", 0)[1])
    lOk := Chk(lOk, "pagamento insuficiente", !GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 5}}, "", 0)[1])
    lOk := Chk(lOk, "fiado sem cliente", !GEBLOJVEN(cSes, {{"P1", 1}}, {{"FIADO", 10}}, "", 0)[1])
    lOk := Chk(lOk, "forma invalida", !GEBLOJVEN(cSes, {{"P1", 1}}, {{"CHEQUE", 10}}, "", 0)[1])
    lOk := Chk(lOk, "sem estoque", !GEBLOJVEN(cSes, {{"P1", 1000}}, {{"DINHEIRO", 99999}}, "", 0)[1])
    aR := GEBLOJVEN(cSes, {{"P1", 3}, {"P2", 1}}, {{"DINHEIRO", 50}}, "", 5)
    lOk := Chk(lOk, "venda dinheiro", aR[1] .And. aR[3][2] == 45 .And. aR[3][3] == 5)
    lOk := Chk(lOk, "nfc-e", aR[1] .And. BOVAL(TCSqlQuery("SELECT GF3_BASE AS B FROM GF3 WHERE GF3_CHAVE = " + GEBDBQuote(aR[3][4]))[1]:B) == 45)
    lOk := Chk(lOk, "rateio desconto", BOVAL(TCSqlQuery("SELECT GLJ4_VALOR AS V FROM GLJ4 WHERE GLJ4_PROD = 'P2'")[1]:V) == 18)
    aR := GEBLOJVEN(cSes, {{"P1", 2}}, {{"PIX", 20}}, "", 0)
    lOk := Chk(lOk, "venda pix", aR[1])
    cC2 := aR[3][1]
    aR := GEBLOJVEN(cSes, {{"P2", 2}}, {{"DEBITO", 10}, {"CREDITO", 30}}, "", 0)
    lOk := Chk(lOk, "venda cartao", aR[1])
    cC3 := aR[3][1]
    aR := TCSqlQuery("SELECT GFN2_VALOR AS V, GFN2_VENC AS D FROM GFN2 WHERE GFN2_DOC = " + GEBDBQuote("CRT-" + cC3 + "-02"))
    lOk := Chk(lOk, "titulo credito", Len(aR) == 1 .And. BOVAL(aR[1]:V) == 29.1 .And. BOCOL(aR[1]:D) == "20261114")
    aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"FIADO", 10}}, "C1", 0)
    lOk := Chk(lOk, "venda fiado", aR[1])
    cC4 := aR[3][1]
    lOk := Chk(lOk, "saldo banco", BOVAL(TCSqlQuery("SELECT GFN1_SALDO AS S FROM GFN1 WHERE GFN1_CONTA = 'BANCO'")[1]:S) == 20)

    // Cancelamentos
    lOk := Chk(lOk, "cancela pix", GEBLOJCAN(cC2, "teste")[1])
    lOk := Chk(lOk, "cancela de novo", !GEBLOJCAN(cC2, "")[1])
    lOk := Chk(lOk, "cancela fiado", GEBLOJCAN(cC4, "")[1])
    lOk := Chk(lOk, "pix estornado", BOVAL(TCSqlQuery("SELECT GFN1_SALDO AS S FROM GFN1 WHERE GFN1_CONTA = 'BANCO'")[1]:S) == 0)
    lOk := Chk(lOk, "estoque volta", GEBESTSLD("P1", "01")[1] == 97)
    lOk := Chk(lOk, "nota cancelada", Len(TCSqlQuery("SELECT GF3_CHAVE FROM GF3 WHERE GF3_STATUS = 'CANCELADA'")) == 2)

    // Sangria, suprimento, fechamento
    lOk := Chk(lOk, "sangria acima", !GEBLOJSAN(cSes, "SANGRIA", 1000, "", "")[1])
    lOk := Chk(lOk, "suprimento", GEBLOJSAN(cSes, "SUPRIMENTO", 50, "troco", "")[1])
    lOk := Chk(lOk, "sangria", GEBLOJSAN(cSes, "SANGRIA", 30, "cofre", "")[1])
    aR := GEBLOJFECHA(cSes, 160)
    lOk := Chk(lOk, "fechamento", aR[1] .And. aR[3][1] == 165 .And. aR[3][3] == -5)
    lOk := Chk(lOk, "venda fechado", !GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 0)[1])
    lOk := Chk(lOk, "saldo caixa", BOVAL(TCSqlQuery("SELECT GFN1_SALDO AS S FROM GFN1 WHERE GFN1_CONTA = 'CAIXA01'")[1]:S) == 60)

    // Relatorios
    aR := GEBLOJRESUMO(cSes)
    lOk := Chk(lOk, "resumo", aR[1] .And. Chave(aR[3], "cupons") == 4 .And. Chave(aR[3], "cancelados") == 2 .And. Chave(aR[3], "vendas") == 85 .And. ;
        Chave(aR[3], "forma DINHEIRO") == 45 .And. Chave(aR[3], "forma PIX") == 0 .And. Chave(aR[3], "forma CREDITO") == 30 .And. ;
        Chave(aR[3], "dinheiro_esperado") == 165 .And. Chave(aR[3], "diferenca") == -5)
    aR := GEBLOJVENDAS("20261015", "")
    lOk := Chk(lOk, "vendas do dia", aR[1] .And. Len(aR[3][1]) == 3 .And. aR[3][1][2][1] == "P2" .And. aR[3][1][2][3] == 58 .And. ;
        Chave(aR[3][2], "valor") == 85 .And. Chave(aR[3][2], "custo") == 48)

    // Contabil
    aR := GEBCTXDRE("20261001", "20261031")
    lOk := Chk(lOk, "dre", aR[1] .And. Chave(aR[3], "receita_bruta") == 85 .And. Chave(aR[3], "cmv") == 48)
    lOk := Chk(lOk, "cartoes", Chave(GEBCTXRAZAO("1.01.005", "20261001", "20261031")[3][1], "saldo_final") == 38.95)
    lOk := Chk(lOk, "caixa contabil", Chave(GEBCTXRAZAO("1.01.001", "20261001", "20261031")[3][1], "saldo_final") == 60)

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebloj CASCADE")
    If lOk
        ConOut("T_GEBLOJ PASS")
    Else
        ConOut("T_GEBLOJ FAIL")
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
