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
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBCTX.prw"
#include "../src/GEBEST.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBCOM_MIG.prw"
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
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBEST
    Teste de estoque/custos (GEBEST) e da contabilidade do backoffice
    (GEBCTX). Valores calculados a mao:
    - custo medio: 10 a 5,00 + 10 a 7,00 = 20 a 6,00; saida de 5 = 30,00;
      saida dos 15 restantes = 90,00 (saldo e valor zerados); saida sem
      saldo e' recusada.
    - centavo: 3 a 3,333333 = 10,00; tres saidas de 1 = 3,33 + 3,33 + 3,34.
    - inventario: 10 a 2,00, contado 8 => saida 4,00 (EST_AJ_NEG); contado
      12 => entrada 8,00 (EST_AJ_POS).
    - transferencia de 4 do armazem 01 para o 02 ao CM 2,00.
    - lancamento padrao, estorno, balancete fechado, razao e DRE.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 18/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBEST()
    Local lOk := .T.
    Local aR := {}
    Local aHit := {}

    If !GEBDBConecta()
        ConOut("T_GEBEST FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebest CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebest")
    TCSqlExec("SET search_path TO test_gebest")
    lOk := Chk(lOk, "mig", GENMIG() .And. GEBFMIG() .And. GEBESTMIG() .And. GEBCTXMIG())

    // Datas e sequencia
    lOk := Chk(lOk, "dtadd", BODTADD("20261230", 3) == "20270102" .And. BODTADD("20240228", 1) == "20240229")
    lOk := Chk(lOk, "dataok", BODATAOK("20261018") .And. !BODATAOK("20261332") .And. !BODATAOK("20260230"))
    lOk := Chk(lOk, "seq", BOSEQ("T", 4) == "0001" .And. BOSEQ("T", 4) == "0002")

    // Custo medio
    lOk := Chk(lOk, "ent1", GEBESTMOV("A", "", "E", 10, 5, "COMPRA", "NF1", "20261001")[1])
    aR := GEBESTMOV("A", "01", "E", 10, 7, "COMPRA", "NF2", "20261002")
    lOk := Chk(lOk, "ent2 cm", aR[1] .And. aR[3][3] == 6 .And. aR[3][4] == 20)
    aR := GEBESTMOV("A", "01", "S", 5, 0, "VENDA", "NS1", "20261003")
    lOk := Chk(lOk, "sai1", aR[1] .And. aR[3][1] == 6 .And. aR[3][2] == 30)
    aR := GEBESTMOV("A", "01", "S", 15, 0, "VENDA", "NS2", "20261004")
    lOk := Chk(lOk, "sai2 zera", aR[1] .And. aR[3][2] == 90 .And. aR[3][4] == 0)
    lOk := Chk(lOk, "sem saldo", !GEBESTMOV("A", "01", "S", 1, 0, "VENDA", "NS3", "20261005")[1])
    lOk := Chk(lOk, "tipo invalido", !GEBESTMOV("A", "01", "X", 1, 0, "", "", "")[1])
    aHit := TCSqlQuery("SELECT GV1_SALDO AS S FROM GV1 WHERE GV1_PROD = 'A' AND D_E_L_E_T_ = ' '")
    lOk := Chk(lOk, "gv1 sincronizada", Len(aHit) == 1 .And. BOVAL(aHit[1]:S) == 0)

    // Centavo na ultima saida
    GEBESTMOV("C", "01", "E", 3, 3.333333, "COMPRA", "NF3", "20261001")
    lOk := Chk(lOk, "cent1", GEBESTMOV("C", "01", "S", 1, 0, "VENDA", "X1", "20261002")[3][2] == 3.33)
    lOk := Chk(lOk, "cent2", GEBESTMOV("C", "01", "S", 1, 0, "VENDA", "X2", "20261002")[3][2] == 3.33)
    lOk := Chk(lOk, "cent3", GEBESTMOV("C", "01", "S", 1, 0, "VENDA", "X3", "20261002")[3][2] == 3.34)

    // Inventario e transferencia
    GEBESTMOV("B", "01", "E", 10, 2, "COMPRA", "NF4", "20261001")
    aR := GEBESTAJU("B", "01", 8, 0, "INV1", "20261010")
    lOk := Chk(lOk, "inv falta", aR[1] .And. aR[3][1] == -2 .And. aR[3][2] == 4)
    aR := GEBESTAJU("B", "01", 12, 0, "INV2", "20261011")
    lOk := Chk(lOk, "inv sobra", aR[1] .And. aR[3][1] == 4 .And. aR[3][2] == 8)
    lOk := Chk(lOk, "inv igual", GEBESTAJU("B", "01", 12, 0, "INV3", "20261011")[2] == "sem_diferenca")
    lOk := Chk(lOk, "trf", GEBESTTRF("B", "01", "02", 4, "T1", "20261012")[1])
    lOk := Chk(lOk, "trf iguais", !GEBESTTRF("B", "01", "01", 1, "T2", "20261012")[1])
    aR := GEBESTSLD("B", "02")
    lOk := Chk(lOk, "sld 02", aR[1] == 4 .And. aR[2] == 2)
    aR := GEBESTSLD("B", "")
    lOk := Chk(lOk, "sld total", aR[1] == 12 .And. aR[3] == 24)

    // Relatorios de estoque
    aR := GEBESTKARDEX("A", "", "20261001", "20261031")
    lOk := Chk(lOk, "kardex", aR[1] .And. Len(aR[3][2]) == 5 .And. Chave(aR[3][1], "entradas") == 20 .And. Chave(aR[3][1], "saldo_final_qtd") == 0)
    aR := GEBESTKARDEX("A", "", "20261003", "20261031")
    lOk := Chk(lOk, "kardex saldo inicial", aR[1] .And. Chave(aR[3][1], "saldo_inicial_qtd") == 20 .And. Chave(aR[3][1], "saldo_inicial_valor") == 120)
    aR := GEBESTPOS("")
    lOk := Chk(lOk, "posicao", aR[1] .And. Chave(aR[3][2], "valor_total") == 24)
    lOk := Chk(lOk, "grade", Len(TCSqlQuery("SELECT GBR1_ORDEM FROM GBR1")) >= 5)

    // Contabilidade
    lOk := Chk(lOk, "lp evento invalido", !GEBCTXLP("NAO_EXISTE", 10, "X", "20261015")[1])
    lOk := Chk(lOk, "lp zero", GEBCTXLP("VENDA_RECEITA", 0, "X", "20261015")[1])
    lOk := Chk(lOk, "lp venda", GEBCTXLP("VENDA_RECEITA", 100, "NS9", "20261015")[1])
    lOk := Chk(lOk, "lp cmv", GEBCTXLP("VENDA_CMV", 60, "NS9", "20261015")[1])
    lOk := Chk(lOk, "lp override", GEBCTXLP("FIN_REC", 100, "NS9", "20261016", GEBCTXFIN("CAIXA"), "")[1])
    lOk := Chk(lOk, "estorno", GEBCTXREV("VENDA_CMV", 10, "NS9", "20261017")[1])
    aR := GEBCTXBALAN("20261001", "20261031")
    lOk := Chk(lOk, "balancete fechado", aR[1] .And. Chave(aR[3][2], "fechado") == "S")
    aR := GEBCTXRAZAO("1.01.004", "20261001", "20261031")
    // estoque: +8 (sobra) -4 (falta) -60 (cmv) +10 (estorno) = -46
    lOk := Chk(lOk, "razao estoque", aR[1] .And. Chave(aR[3][1], "saldo_final") == -46)
    aR := GEBCTXRAZAO("1.01.001", "20261001", "20261031")
    lOk := Chk(lOk, "razao caixa", aR[1] .And. Chave(aR[3][1], "saldo_final") == 100)
    aR := GEBCTXDRE("20261001", "20261031")
    // receita 100 - cmv (60 - 10) = 50; + outras receitas 8 - perdas 4 = 54
    lOk := Chk(lOk, "dre", aR[1] .And. Chave(aR[3], "receita_bruta") == 100 .And. Chave(aR[3], "cmv") == 50 .And. Chave(aR[3], "resultado") == 54)

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebest CASCADE")
    If lOk
        ConOut("T_GEBEST PASS")
    Else
        ConOut("T_GEBEST FAIL")
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
