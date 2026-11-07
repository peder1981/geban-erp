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
#include "../src/GEBFAT.prw"
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

/*/{Protheus.doc} T_GEBLOTE
    Teste de lote/serie/endereco, fechamento mensal e devolucao de compra.
    - entrada do pedido: L1 (lote) LA 6 val 10/12 + LB 4 val 20/11; S1 (serie)
      SN1;SN2; E1 (endereco) 5 em A1. Sem lote = recusado; serie repetida =
      recusada.
    - saida de 5 L1 em 01/11 por FEFO: LB 4 + LA 1. Lote LC vencido em 15/10
      e' pulado (e recusado se informado). Devolucao de 2 do documento volta
      LA 1 + LB 1.
    - E1: muda 2 de A1 para A2; transfere 1 de A2 (armazem 01) para B1
      (armazem 02). Inventario de L1 com lote LD.
    - fechamento: FX 10 a 5,00 em 08/2026, saida de 4 em 09/2026; fecha 08 e
      09 em ordem, bloqueia 20/09, reabre 09.
    - devolucao de compra de 1 S1 (100,00) abate o titulo NFL (320 -> 220);
      depois de pago, devolver 1 E1 (4,00) vira credito com o fornecedor.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 18/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBLOTE()
    Local lOk := .T.
    Local aR := {}
    Local aL := {}

    If !GEBDBConecta()
        ConOut("T_GEBLOTE FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_geblote CASCADE")
    TCSqlExec("CREATE SCHEMA test_geblote")
    TCSqlExec("SET search_path TO test_geblote")
    lOk := Chk(lOk, "mig", GENMIG() .And. GEBFMIG() .And. GEBFATMIG() .And. GEBCPXMIG())
    GEBFNCON("CAIXA", "Caixa")
    GEBCMFOR("F1", "Fornecedor 1")

    // Controle e enderecos
    lOk := Chk(lOk, "ctl L1", GEBESTCTL("L1", "L", "N")[1])
    lOk := Chk(lOk, "ctl S1", GEBESTCTL("S1", "S", "N")[1])
    lOk := Chk(lOk, "ctl E1", GEBESTCTL("E1", "N", "S")[1])
    lOk := Chk(lOk, "ctl invalido", !GEBESTCTL("X", "Z", "N")[1])
    GEBESTMOV("N1", "01", "E", 1, 1, "X", "X", "20261001")
    lOk := Chk(lOk, "ctl com saldo", !GEBESTCTL("N1", "L", "N")[1])
    lOk := Chk(lOk, "ender A1", GEBESTENDER("01", "a1", "")[1])
    GEBESTENDER("01", "A2", "")
    GEBESTENDER("02", "B1", "")

    // Entrada com lotes
    GEBCPXPED("PCL", "F1", {{"L1", 10, 10}, {"S1", 2, 100}, {"E1", 5, 4}}, "0", "01", "20261001")
    lOk := Chk(lOk, "entrada sem lote", !GEBCPXENT("NFL", "PCL", {}, 0, "20261002")[1])
    lOk := Chk(lOk, "entrada endereco inexistente", !GEBCPXENT("NFL", "PCL", {{"E1", 5, 0, "", "", "Z9"}}, 0, "20261002")[1])
    aR := GEBCPXENT("NFL", "PCL", {{"L1", 6, 0, "LA", "20261210", ""}, {"L1", 4, 0, "LB", "20261120", ""}, {"S1", 2, 0, "SN1;SN2", "", ""}, ;
        {"E1", 5, 0, "", "", "A1"}}, 0, "20261002")
    lOk := Chk(lOk, "entrada com lotes", aR[1] .And. aR[3][1] == 320)
    lOk := Chk(lOk, "lotes gravados", Len(GEBESTLOTES("L1", "01", "20261002")[3]) == 3)
    lOk := Chk(lOk, "serie repetida", !GEBESTMOV("S1", "01", "E", 1, 100, "X", "D1", "20261003", {{"SN1", "", "", 1}})[1])
    lOk := Chk(lOk, "serie qtd 1", !GEBESTMOV("S1", "01", "E", 2, 100, "X", "D1", "20261003", {{"SN9", "", "", 2}})[1])
    lOk := Chk(lOk, "lotes nao somam", !GEBESTMOV("L1", "01", "E", 3, 10, "X", "D1", "20261003", {{"LZ", "", "", 2}})[1])

    // FEFO, vencido, devolucao pelo documento
    GEBESTMOV("L1", "01", "E", 3, 10, "X", "DX", "20261001", {{"LC", "20261015", "", 3}})
    aR := GEBESTMOV("L1", "01", "S", 5, 0, "VENDA", "NSX", "20261101")
    aL := aR[3][5]
    lOk := Chk(lOk, "fefo", aR[1] .And. Len(aL) == 2 .And. aL[1][1] == "LB" .And. aL[1][4] == 4 .And. aL[2][1] == "LA" .And. aL[2][4] == 1)
    lOk := Chk(lOk, "lote vencido informado", !GEBESTMOV("L1", "01", "S", 1, 0, "VENDA", "NSY", "20261101", {{"LC", "", "", 1}})[1])
    lOk := Chk(lOk, "vencer", Len(GEBESTVENCER(30, "20261101")[3]) == 2)
    aR := GEBESTMOV("L1", "01", "E", 2, 10, "DEVOLUCAO", "DVX", "20261102", {}, "NSX")
    aL := aR[3][5]
    lOk := Chk(lOk, "devolucao pelos lotes", aR[1] .And. Len(aL) == 2 .And. aL[1][1] == "LA" .And. aL[2][1] == "LB")
    lOk := Chk(lOk, "devolucao acima", !GEBESTMOV("L1", "01", "E", 4, 10, "DEVOLUCAO", "DVY", "20261102", {}, "NSX")[1])

    // Enderecos e transferencia de armazem
    lOk := Chk(lOk, "endtrf", GEBESTENDTRF("E1", "01", "", "A1", "A2", 2, "20261101")[1])
    lOk := Chk(lOk, "endtrf sem saldo", !GEBESTENDTRF("E1", "01", "", "A1", "A2", 9, "20261101")[1])
    lOk := Chk(lOk, "trf armazem", GEBESTTRF("E1", "01", "02", 1, "T1", "20261101", {{"", "", "A2", 1}}, "B1")[1])
    aR := GEBESTLOTES("E1", "", "20261101")
    lOk := Chk(lOk, "enderecos", aR[1] .And. Len(aR[3]) == 4 .And. aR[3][2][5] == "A1" .And. aR[3][2][6] == 3 .And. aR[3][3][6] == 1 .And. aR[3][4][5] == "B1")
    lOk := Chk(lOk, "saida sem endereco usa saldo", GEBESTMOV("E1", "02", "S", 1, 0, "X", "SX", "20261101")[1])

    // Inventario por lote
    aR := GEBESTSLD("L1", "01")
    lOk := Chk(lOk, "inventario lote", GEBESTAJU("L1", "01", aR[1] + 2, 0, "INVL", "20261103", {{"LD", "", "", 2}})[1])
    lOk := Chk(lOk, "inventario sem lote", !GEBESTAJU("L1", "01", aR[1] + 5, 0, "INVL2", "20261103")[1])

    // Devolucao de compra
    lOk := Chk(lOk, "devc acima", !GEBCPXDEV("NFL", "F1", {{"S1", 3}}, "20261103")[1])
    lOk := Chk(lOk, "devc forn errado", !GEBCPXDEV("NFL", "F9", {{"S1", 1}}, "20261103")[1])
    aR := GEBCPXDEV("NFL", "F1", {{"S1", 1}}, "20261103")
    lOk := Chk(lOk, "devc abate", aR[1] .And. aR[3][2] == 100 .And. aR[3][3] == 100 .And. aR[3][4] == 0)
    lOk := Chk(lOk, "devc titulo", BOVAL(TCSqlQuery("SELECT GFN3_SALDO AS S FROM GFN3 WHERE GFN3_DOC = 'NFL'")[1]:S) == 220)
    lOk := Chk(lOk, "devc serie saiu", GEBESTSLD("S1", "01")[1] == 1 .And. Len(GEBESTLOTES("S1", "", "20261103")[3]) == 2)
    lOk := Chk(lOk, "devc nota", BOCOL(TCSqlQuery("SELECT GF3_TIPO AS T FROM GF3 WHERE GF3_CHAVE = " + GEBDBQuote(aR[3][1]))[1]:T) == "DEVC")
    GEBFXBAI("P", "NFL", 220, 0, 0, 0, "CAIXA", "20261104")
    aR := GEBCPXDEV("NFL", "F1", {{"E1", 1}}, "20261105")
    lOk := Chk(lOk, "devc credito", aR[1] .And. aR[3][4] == 4)
    lOk := Chk(lOk, "credito fornecedor", BOVAL(TCSqlQuery("SELECT GFN2_VALOR AS V FROM GFN2 WHERE GFN2_DOC = " + GEBDBQuote("DEVF-" + aR[3][1]))[1]:V) == 4)
    lOk := Chk(lOk, "razao fornecedores", Chave(GEBCTXRAZAO("2.01.001", "20261001", "20261130")[3][1], "saldo_final") == 0)
    lOk := Chk(lOk, "razao creditos", Chave(GEBCTXRAZAO("1.01.006", "20261001", "20261130")[3][1], "saldo_final") == 4)

    // Fechamento mensal
    GEBESTMOV("FX", "01", "E", 10, 5, "X", "F1", "20260815")
    GEBESTMOV("FX", "01", "S", 4, 0, "X", "F2", "20260910")
    lOk := Chk(lOk, "fecha 08", GEBESTFECHA("202608")[1])
    lOk := Chk(lOk, "fecha fora de ordem", !GEBESTFECHA("202610")[1])
    aR := GEBESTFECHA("202609")
    lOk := Chk(lOk, "fecha 09", aR[1])
    lOk := Chk(lOk, "mes aberto", !GEBESTFECHA(Left(DToS(Date()), 6))[1])
    lOk := Chk(lOk, "periodo fechado", !GEBESTMOV("FX", "01", "E", 1, 5, "X", "F3", "20260920")[1])
    aR := GEBESTFECHREL("202609")
    lOk := Chk(lOk, "fechamento rel", aR[1] .And. Len(aR[3][1]) == 2 .And. aR[3][1][2][3] == 10 .And. aR[3][1][2][6] == 20 .And. aR[3][1][2][8] == 30 .And. ;
        Chave(aR[3][2], "divergencias") == 0)
    lOk := Chk(lOk, "reabre nao ultima", !GEBESTREABRE("202608")[1])
    lOk := Chk(lOk, "reabre 09", GEBESTREABRE("202609")[1])
    lOk := Chk(lOk, "movimento liberado", GEBESTMOV("FX", "01", "E", 1, 5, "X", "F3", "20260920")[1])
    lOk := Chk(lOk, "agosto segue fechado", !GEBESTMOV("FX", "01", "E", 1, 5, "X", "F4", "20260820")[1])

    TCSqlExec("DROP SCHEMA IF EXISTS test_geblote CASCADE")
    If lOk
        ConOut("T_GEBLOTE PASS")
    Else
        ConOut("T_GEBLOTE FAIL")
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
