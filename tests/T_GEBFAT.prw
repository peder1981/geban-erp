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
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBFAT
    Teste do faturamento (GEBFAT). Valores calculados a mao:
    - estoque P1 100 a 6,00; P2 10 a 30,00. Precos PADRAO P1 10, P2 50.
    - PV000001 (C1, desconto 10%): 50 P1 + 4 P2 = 630,00.
    - nota 1: 30 P1 = 270,00 (IBS 10% 27,00, CBS 5% 13,50), custo 180,00,
      30/60 = 135,00 + 135,00; nota 2: 20 P1 + 4 P2 = 360,00, custo 240,00.
    - PV000002 (60 P1 = 600,00) bloqueado: credito (630 + 600 > 1.000) e
      estoque (50 < 60).
    - devolucao de 10 P1 da nota 1 = 90,00 (custo 60,00) abate a 2a parcela;
      devolucao de 2 P2 da nota 2 ja recebida = credito de 90,00 (GFN3).
    - DRE: receita 630, deducoes 180, CMV 300, lucro bruto 150.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 18/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBFAT()
    Local lOk := .T.
    Local aR := {}

    If !GEBDBConecta()
        ConOut("T_GEBFAT FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfat CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebfat")
    TCSqlExec("SET search_path TO test_gebfat")
    lOk := Chk(lOk, "mig", GENMIG() .And. GEBFMIG() .And. GEBFATMIG())
    GEBFNCON("CAIXA", "Caixa")
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'P1', 'N1', 'Produto 1'), (' ', '      ', 'P2', 'N2', 'Produto 2')")
    TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'N1', 10, 5, '20200101', '20991231')")
    GEBESTMOV("P1", "", "E", 100, 6, "COMPRA", "X", "20261001")
    GEBESTMOV("P2", "", "E", 10, 30, "COMPRA", "X", "20261001")

    // Cadastros
    lOk := Chk(lOk, "cli", GEBFATCLI("C1", "Cliente 1", "123", "sp", 1000, "30,60", "")[1])
    lOk := Chk(lOk, "cli sem limite", GEBFATCLI("C2", "Cliente 2", "", "RJ", 0, "", "T2")[1])
    lOk := Chk(lOk, "cli cond inexistente", !GEBFATCLI("C3", "x", "", "", 0, "NADA", "")[1])
    lOk := Chk(lOk, "preco P1", GEBFATPRC("", "P1", 10)[1])
    lOk := Chk(lOk, "preco P2", GEBFATPRC("PADRAO", "P2", 50)[1])
    lOk := Chk(lOk, "preco T2", GEBFATPRC("T2", "P1", 9)[1])

    // Pedido
    lOk := Chk(lOk, "ped sem preco", !GEBFATPED("", "C1", {{"P9", 1}}, "", 0, "", "20261002")[1])
    lOk := Chk(lOk, "ped cli inexistente", !GEBFATPED("", "C9", {{"P1", 1}}, "", 0, "", "20261002")[1])
    lOk := Chk(lOk, "ped repetido", !GEBFATPED("", "C1", {{"P1", 1}, {"P1", 2}}, "", 0, "", "20261002")[1])
    aR := GEBFATPED("", "C1", {{"P1", 50}, {"P2", 4, 0}}, "", 10, "", "20261002")
    lOk := Chk(lOk, "ped", aR[1] .And. aR[3][1] == "PV000001" .And. aR[3][2] == 630)
    lOk := Chk(lOk, "fat sem liberar", !GEBFATFAT("PV000001", {}, "20261005", "")[1])
    aR := GEBFATLIB("PV000001")
    lOk := Chk(lOk, "lib", aR[1] .And. aR[3] == "LIBERADO")

    // Faturamento parcial e total
    aR := GEBFATFAT("PV000001", {{"P1", 30}}, "20261005", "")
    lOk := Chk(lOk, "fat parcial", aR[1] .And. aR[3][1] == "NS000001" .And. aR[3][2] == 270 .And. aR[3][3] == 180 .And. aR[3][4] == "PARCIAL")
    lOk := Chk(lOk, "fat titulos", aR[1] .And. Len(aR[3][5]) == 2 .And. aR[3][5][2][3] == 135 .And. aR[3][5][1][2] == "20261104")
    aR := TCSqlQuery("SELECT GF3_BASE AS B, GF3_IBS AS I, GF3_CBS AS C, GF3_STATUS AS S FROM GF3 WHERE GF3_CHAVE = 'NS000001'")
    lOk := Chk(lOk, "nota fiscal", Len(aR) == 1 .And. BOVAL(aR[1]:B) == 270 .And. BOVAL(aR[1]:I) == 27 .And. BOVAL(aR[1]:C) == 13.5 .And. BOCOL(aR[1]:S) == "AUTORIZADA")
    lOk := Chk(lOk, "fat acima do saldo", !GEBFATFAT("PV000001", {{"P1", 21}}, "20261006", "")[1])
    aR := GEBFATFAT("PV000001", {}, "20261006", "")
    lOk := Chk(lOk, "fat resto", aR[1] .And. aR[3][2] == 360 .And. aR[3][3] == 240 .And. aR[3][4] == "FATURADO")
    lOk := Chk(lOk, "nota 2 itens", Len(TCSqlQuery("SELECT GF4_ITEM FROM GF4 WHERE GF4_CHAVE = 'NS000002'")) == 2)
    lOk := Chk(lOk, "fat de novo", !GEBFATFAT("PV000001", {}, "20261006", "")[1])
    lOk := Chk(lOk, "estoque P1", GEBESTSLD("P1", "01")[1] == 50)

    // Bloqueio por credito e estoque
    GEBFATPED("", "C1", {{"P1", 60}}, "", 0, "", "20261007")
    aR := GEBFATLIB("PV000002")
    lOk := Chk(lOk, "bloqueio", aR[1] .And. aR[3] == "BLOQUEADO" .And. "credito" $ aR[2] .And. "estoque" $ aR[2])
    lOk := Chk(lOk, "fat bloqueado", !GEBFATFAT("PV000002", {}, "20261007", "")[1])
    lOk := Chk(lOk, "lib forcada", GEBFATLIB("PV000002", .T.)[3] == "LIBERADO")
    lOk := Chk(lOk, "fat sem estoque", !GEBFATFAT("PV000002", {}, "20261007", "")[1])
    lOk := Chk(lOk, "cancela", GEBFATCAN("PV000002")[1])
    lOk := Chk(lOk, "cancela faturado", !GEBFATCAN("PV000001")[1])

    // Devolucoes
    aR := GEBFATDEV("NS000001", {{"P1", 10}}, "20261008")
    lOk := Chk(lOk, "dev abate", aR[1] .And. aR[3][2] == 90 .And. aR[3][3] == 60 .And. aR[3][4] == 90 .And. aR[3][5] == 0)
    lOk := Chk(lOk, "dev saldo titulo", BOVAL(TCSqlQuery("SELECT GFN2_SALDO AS S FROM GFN2 WHERE GFN2_DOC = 'NS000001/02'")[1]:S) == 45)
    lOk := Chk(lOk, "dev estoque", GEBESTSLD("P1", "01")[1] == 60)
    GEBFXBAI("R", "NS000002/01", 180, 0, 0, 0, "CAIXA", "20261009")
    GEBFXBAI("R", "NS000002/02", 180, 0, 0, 0, "CAIXA", "20261009")
    aR := GEBFATDEV("NS000002", {{"P2", 2}}, "20261010")
    lOk := Chk(lOk, "dev credito", aR[1] .And. aR[3][2] == 90 .And. aR[3][5] == 90)
    lOk := Chk(lOk, "credito cliente", BOVAL(TCSqlQuery("SELECT GFN3_VALOR AS V FROM GFN3 WHERE GFN3_DOC = 'DEVC-DV000002'")[1]:V) == 90)
    lOk := Chk(lOk, "dev acima", !GEBFATDEV("NS000002", {{"P2", 3}}, "20261010")[1])
    lOk := Chk(lOk, "dev fora da nota", !GEBFATDEV("NS000002", {{"P9", 1}}, "20261010")[1])

    // Contabil
    aR := GEBCTXDRE("20261001", "20261031")
    lOk := Chk(lOk, "dre", aR[1] .And. Chave(aR[3], "receita_bruta") == 630 .And. Chave(aR[3], "deducoes") == 180 .And. ;
        Chave(aR[3], "cmv") == 300 .And. Chave(aR[3], "lucro_bruto") == 150)
    lOk := Chk(lOk, "credito de clientes", Chave(GEBCTXRAZAO("2.01.003", "20261001", "20261031")[3][1], "saldo_final") == -90)

    // Relatorios
    aR := GEBFATREL("20261001", "20261031", "PRODUTO")
    lOk := Chk(lOk, "rel produto", aR[1] .And. Len(aR[3][1]) == 3 .And. aR[3][1][2][1] == "P1" .And. aR[3][1][2][2] == 40 .And. aR[3][1][2][3] == 360 .And. ;
        aR[3][1][2][5] == 120 .And. Chave(aR[3][2], "margem") == 150)
    aR := GEBFATREL("20261001", "20261031", "CLIENTE")
    lOk := Chk(lOk, "rel cliente", aR[1] .And. Len(aR[3][1]) == 2 .And. aR[3][1][2][3] == 450)
    aR := GEBFATABC("20261001", "20261031")
    lOk := Chk(lOk, "abc", aR[1] .And. aR[3][2][5] == "A" .And. aR[3][3][5] == "C" .And. aR[3][2][3] == 80)
    lOk := Chk(lOk, "carteira vazia", Len(GEBFATCARTEIRA()[3][1]) == 1)
    aR := GEBFATPED("", "C2", {{"P1", 5}}, "", 0, "", "20261011")
    lOk := Chk(lOk, "preco da tabela", aR[1] .And. aR[3][2] == 45)
    aR := GEBFATCARTEIRA()
    lOk := Chk(lOk, "carteira", aR[1] .And. Len(aR[3][1]) == 2 .And. Chave(aR[3][2], "valor_a_faturar") == 45)

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfat CASCADE")
    If lOk
        ConOut("T_GEBFAT PASS")
    Else
        ConOut("T_GEBFAT FAIL")
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
