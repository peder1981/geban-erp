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

/*/{Protheus.doc} T_GEBCPX
    Teste de compras do backoffice (GEBCPX). Valores calculados a mao:
    - solicitacao P1 (10) + P2 (4); cotacoes P1: F1 10,00 / F2 9,00; P2: F1
      5,00 => pedidos PC000001 (F2, P1 a 9,00) e PC000002 (F1, P2 a 5,00).
    - alcada 1.000: pedido de 100 x 20,00 fica PENDENTE ate aprovar.
    - entrada parcial de 40 + frete 50,00 => custo 21,25; resto 60 a 20,00
      => CM 20,50; pedido RECEBIDO.
    - entrada de PC000001 em 30/60 com frete 10,00 => 2 parcelas de 50,00.
    - rateio do frete 10,00 sobre 100,00 + 200,00 => 3,33 + 6,67.
    - contabil: estoque = fornecedores = 2.460,00; relatorios.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 18/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBCPX()
    Local lOk := .T.
    Local aR := {}
    Local cSC := ""

    If !GEBDBConecta()
        ConOut("T_GEBCPX FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebcpx CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebcpx")
    TCSqlExec("SET search_path TO test_gebcpx")
    lOk := Chk(lOk, "mig", GENMIG() .And. GEBFMIG() .And. GEBCPXMIG())
    GEBFNCON("CAIXA", "Caixa")
    GEBCMFOR("F1", "Fornecedor 1")
    GEBCMFOR("F2", "Fornecedor 2")
    GEBCMCOT("F1", "P1", 10)
    GEBCMCOT("F2", "P1", 9)
    GEBCMCOT("F1", "P2", 5)

    // Solicitacao -> pedidos pelo menor preco
    lOk := Chk(lOk, "sc invalida", !GEBCPXSC("", {{"P1", 0, ""}}, "joao")[1])
    aR := GEBCPXSC("", {{"P1", 10, "20261201"}, {"P2", 4, "20261020"}}, "joao")
    lOk := Chk(lOk, "sc", aR[1] .And. aR[3] == "SC000001")
    cSC := aR[3]
    aR := GEBCPXSCPEND()
    lOk := Chk(lOk, "sc pendente", aR[1] .And. Len(aR[3]) == 3 .And. aR[3][2][2] == "P2" .And. aR[3][3][6] == 9)
    aR := GEBCPXGERA(cSC, "30,60", "01", "20261001")
    lOk := Chk(lOk, "gera", aR[1] .And. Len(aR[3]) == 2 .And. aR[3][1] == "PC000001")
    lOk := Chk(lOk, "gera de novo", !GEBCPXGERA(cSC, "", "", "20261001")[1])
    lOk := Chk(lOk, "sc atendida", Len(TCSqlQuery("SELECT GCQ1_NUM FROM GCQ1 WHERE GCQ1_STATUS = 'ATENDIDA' AND GCQ1_PED = 'PC000001'")) == 1)
    lOk := Chk(lOk, "pedido F2", BOCOL(TCSqlQuery("SELECT GCP3_FORN AS F FROM GCP3 WHERE GCP3_NUM = 'PC000001'")[1]:F) == "F2")

    // Alcada
    TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'COM_ALCADA', '1000')")
    lOk := Chk(lOk, "ped repetido", !GEBCPXPED("PCY", "F1", {{"P3", 1, 1}, {"P3", 1, 1}}, "0", "", "20261001")[1])
    lOk := Chk(lOk, "ped forn inexistente", !GEBCPXPED("PCY", "F9", {{"P3", 1, 1}}, "0", "", "20261001")[1])
    lOk := Chk(lOk, "ped cond inexistente", !GEBCPXPED("PCY", "F1", {{"P3", 1, 1}}, "NADA", "", "20261001")[1])
    aR := GEBCPXPED("PCX", "F1", {{"P3", 100, 20}}, "0", "", "20261001")
    lOk := Chk(lOk, "ped pendente", aR[1] .And. aR[3][3] == "PENDENTE" .And. aR[3][2] == 2000)
    lOk := Chk(lOk, "entrada pendente", !GEBCPXENT("NFE1", "PCX", {}, 0, "20261005")[1])
    lOk := Chk(lOk, "aprova", GEBCPXAPR("PCX", "super", .T.)[1])
    lOk := Chk(lOk, "aprova de novo", !GEBCPXAPR("PCX", "super", .T.)[1])

    // Entradas
    aR := GEBCPXENT("NFE1", "PCX", {{"P3", 40}}, 50, "20261005")
    lOk := Chk(lOk, "entrada parcial", aR[1] .And. aR[3][1] == 850 .And. aR[3][2] == "PARCIAL")
    aR := GEBESTSLD("P3", "01")
    lOk := Chk(lOk, "custo com frete", aR[1] == 40 .And. aR[2] == 21.25)
    lOk := Chk(lOk, "acima do pendente", !GEBCPXENT("NFE2", "PCX", {{"P3", 61}}, 0, "20261006")[1])
    lOk := Chk(lOk, "fora do pedido", !GEBCPXENT("NFE2", "PCX", {{"P9", 1}}, 0, "20261006")[1])
    aR := GEBCPXENT("NFE2", "PCX", {}, 0, "20261006")
    lOk := Chk(lOk, "entrada resto", aR[1] .And. aR[3][1] == 1200 .And. aR[3][2] == "RECEBIDO")
    aR := GEBESTSLD("P3", "01")
    lOk := Chk(lOk, "cm final", aR[1] == 100 .And. aR[2] == 20.5)
    lOk := Chk(lOk, "pedido recebido", !GEBCPXENT("NFE3", "PCX", {}, 0, "20261006")[1])
    aR := GEBCPXENT("NFG1", "PC000001", {}, 10, "20261007")
    lOk := Chk(lOk, "entrada parcelada", aR[1] .And. Len(aR[3][3]) == 2 .And. aR[3][3][1][3] == 50 .And. aR[3][3][2][2] == "20261206")
    lOk := Chk(lOk, "titulo duplicado", !GEBCPXENT("NFG1", "PC000002", {}, 0, "20261007")[1])
    GEBCPXPED("PCR", "F1", {{"A1", 1, 100}, {"A2", 2, 100}}, "0", "", "20261001")
    lOk := Chk(lOk, "entrada rateio", GEBCPXENT("NFR", "PCR", {}, 10, "20261008")[1])
    lOk := Chk(lOk, "rateio A1", GEBESTSLD("A1", "01")[2] == 103.33)
    lOk := Chk(lOk, "rateio A2", GEBESTSLD("A2", "01")[3] == 206.67)

    // Contabil e relatorios
    lOk := Chk(lOk, "razao estoque", Chave(GEBCTXRAZAO("1.01.004", "20261001", "20261031")[3][1], "saldo_final") == 2460)
    lOk := Chk(lOk, "razao fornecedores", Chave(GEBCTXRAZAO("2.01.001", "20261001", "20261031")[3][1], "saldo_final") == -2460)
    aR := GEBCPXABERTOS()
    lOk := Chk(lOk, "abertos", aR[1] .And. Len(aR[3][1]) == 2 .And. Chave(aR[3][2], "valor_pendente") == 20)
    aR := GEBCPXPORFORN("20261001", "20261031")
    lOk := Chk(lOk, "por fornecedor", aR[1] .And. Len(aR[3][1]) == 3 .And. aR[3][1][2][1] == "F1" .And. aR[3][1][2][6] == 2360 .And. Chave(aR[3][2], "total") == 2460)
    lOk := Chk(lOk, "sc sem pendencia", Len(GEBCPXSCPEND()[3]) == 1)

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebcpx CASCADE")
    If lOk
        ConOut("T_GEBCPX PASS")
    Else
        ConOut("T_GEBCPX FAIL")
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
