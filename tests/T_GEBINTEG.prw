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
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBV_VEN.prw"
#include "../src/GEBV_FIA.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCOM_FOR.prw"
#include "../src/GEBCOM_PED.prw"
#include "../src/GEBCOM_ENT.prw"
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
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBINTEG
    Integracao entre os modulos (docs/superpowers/specs/2026-10-19-integracao-modulos-design.md).
    Valores calculados a mao (IBS 10% + CBS 5% = 15% na NCM N1):
    - Apuracao 202610 (regime REGULAR): cupom de 10 (1,50) + cupom
      cancelado de 20 (fora) + nota NS000001 de 100 (15,00) - devolucao de
      40 (6,00) = debito 10,50; compra de 20 = credito 3,00; saldo 7,50.
      Guia GD202610 de 7,50 com titulo no financeiro, vencimento
      20261123 (20/11 e' feriado nacional) e provisao D 3.02.002 de 7,50.
    - Novo cupom de 10: saldo 9,00 (guia e provisao acompanham); paga no
      BANCO (D 2.01.004 / C 1.01.002); outro cupom: guia complementar
      GD202610-C1 de 1,50.
    - Guia GDX de 300 + juros de 10 dias (9,90 + 6,00) parcelada em 3 de
      105,30; juros embutidos 15,90 em 4.02.002; parcela 1 paga baixa a
      GD2 001; pagar a guia quita o resto e baixa a guia.
    - Retencoes ISS 5% + IRRF 1,5% sobre 1000: titulo 935, guias
      RET-ISS 50 e RET-IRRF 15; nova entrada de 400 com ISS: RET-ISS 70.
    - Caminhos antigos: pagar e baixar (despesa, sem receita), fiado
      recebido quita o GV3, venda do balcao com kardex e caixa, entrada
      antiga pelo documento de entrada.
    - Correcao de lancamentos antigos: 5 lotes PADRAO reconhecidos (guia,
      entrada, pagamento da entrada, pagar, receber) e 1 ignorado; rodar de
      novo nao corrige nada.
    - Simples: em T_GEBINTEGSN (outro processo, outro schema).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 19/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBINTEG()
    Local lOk := .T.
    Local aR := {}
    Local aH := {}
    Local cSes := ""
    Local cRec := ""

    If !GEBDBConecta()
        ConOut("T_GEBINTEG FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebinteg CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebinteg")
    TCSqlExec("SET search_path TO test_gebinteg")
    GBAUDINIC()
    lOk := Chk(lOk, "mig", GENMIG() .And. GEBFMIG() .And. GEBVMIG() .And. GEBLOJMIG() .And. GEBCPXMIG() .And. GEBDERFMIG() .And. GEBRETMIG())
    BOSETPARM("REGIME", "REGULAR")
    lOk := Chk(lOk, "regime regular", GEBREGIME() == "REGULAR")
    GEBFNCON("CAIXA", "Caixa")
    GEBFNCON("BANCO", "Banco")
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'P1', 'N1', 'Produto 1'), (' ', '      ', 'S1', 'N9', 'Servico')")
    TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'N1', 10, 5, '20200101', '20991231')")
    GEBESTMOV("P1", "", "E", 100, 4, "COMPRA", "X", "20261001")
    GEBFATPRC("", "P1", 10)
    GEBFATCLI("C1", "Cliente 1", "", "SP", 0, "", "")
    GEBCMFOR("F1", "Fornecedor 1")
    GEBCMFOR("F2", "Fornecedor 2")

    // ===== Apuracao do IBS/CBS
    GEBLOJCX("01", "Caixa 1", "", "")
    cSes := GEBLOJABRE("01", "maria", 0, "20261015")[3]
    aR := GEBLOJVEN(cSes, {{"P1", 2}}, {{"PIX", 20}}, "", 0)
    lOk := Chk(lOk, "cupom cancelado", aR[1] .And. GEBLOJCAN(aR[3][1], "teste")[1])
    lOk := Chk(lOk, "cupom", GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 0)[1])
    GEBFATPED("", "C1", {{"P1", 10}}, "", 0, "", "20261016")
    GEBFATLIB("PV000001")
    lOk := Chk(lOk, "nota", GEBFATFAT("PV000001", {}, "20261016", "")[1])
    lOk := Chk(lOk, "devolucao", GEBFATDEV("NS000001", {{"P1", 4}}, "20261020")[1])
    GEBCPXPED("PC1", "F1", {{"P1", 4, 5}}, "0", "", "20261005")
    lOk := Chk(lOk, "compra", GEBCPXENT("NFC1", "PC1", {}, 0, "20261010", {})[1])
    lOk := Chk(lOk, "credito gcq7", Soma("SELECT SUM(GCQ7_IBS + GCQ7_CBS) AS V FROM GCQ7 WHERE GCQ7_NF = 'NFC1'") == 3)
    lOk := Chk(lOk, "apura", GEBFAPU("202610"))
    aH := TCSqlQuery("SELECT GF5_DEB AS D, GF5_CRED AS C, GF5_SALDO AS S, GF5_REGIME AS R FROM GF5 WHERE GF5_COMP = '202610' AND D_E_L_E_T_ = ' '")
    lOk := Chk(lOk, "gf5", Len(aH) == 1 .And. BOVAL(aH[1]:D) == 10.5 .And. BOVAL(aH[1]:C) == 3 .And. BOVAL(aH[1]:S) == 7.5 .And. BOCOL(aH[1]:R) == "REGULAR")
    lOk := Chk(lOk, "guia", Soma("SELECT GD1_VALOR AS V FROM GD1 WHERE GD1_GUIA = 'GD202610' AND GD1_STATUS = 'ABERTA' AND D_E_L_E_T_ = ' '") == 7.5)
    aH := TCSqlQuery("SELECT GFN3_VALOR AS V, GFN3_VENC AS D, GFN3_FORN AS F FROM GFN3 WHERE GFN3_DOC = 'GD202610' AND D_E_L_E_T_ = ' '")
    lOk := Chk(lOk, "titulo da guia", Len(aH) == 1 .And. BOVAL(aH[1]:V) == 7.5 .And. BOCOL(aH[1]:D) == "20261123" .And. BOCOL(aH[1]:F) == "FISCO")
    lOk := Chk(lOk, "titulo origem", Len(TCSqlQuery("SELECT GFX2_DOC FROM GFX2 WHERE GFX2_DOC = 'GD202610' AND GFX2_ORIGEM = 'DERRAMA IBSCBS'")) == 1)
    lOk := Chk(lOk, "provisao", Perna("APU_IBSCBS:GD202610", "D", "3.02.002") - Perna("APU_IBSCBS:GD202610", "D", "2.01.004") == 7.5)
    GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 0)
    GEBFAPU("202610")
    lOk := Chk(lOk, "reapura guia", Soma("SELECT GFN3_VALOR AS V FROM GFN3 WHERE GFN3_DOC = 'GD202610' AND D_E_L_E_T_ = ' '") == 9)
    lOk := Chk(lOk, "reapura provisao", Perna("APU_IBSCBS:GD202610", "D", "3.02.002") - Perna("APU_IBSCBS:GD202610", "D", "2.01.004") == 9)
    aR := GEBDERPAGA("GD202610", "BANCO", "20261120")
    lOk := Chk(lOk, "paga guia", aR[1] .And. aR[3] == 9)
    lOk := Chk(lOk, "guia baixada", Len(TCSqlQuery("SELECT GD1_GUIA FROM GD1 WHERE GD1_GUIA = 'GD202610' AND GD1_STATUS = 'BAIXADA'")) == 1)
    lOk := Chk(lOk, "banco", Soma("SELECT GFN1_SALDO AS V FROM GFN1 WHERE GFN1_CONTA = 'BANCO' AND D_E_L_E_T_ = ' '") == -9)
    lOk := Chk(lOk, "contabil pagamento", Perna("FIN_PAG:GD202610", "D", "2.01.004") == 9 .And. Perna("FIN_PAG:GD202610", "C", "1.01.002") == 9)
    lOk := Chk(lOk, "paga de novo", GEBDERPAGA("GD202610", "BANCO", "20261120")[3] == 0)
    GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 0)
    GEBFAPU("202610")
    lOk := Chk(lOk, "complementar", Soma("SELECT GD1_VALOR AS V FROM GD1 WHERE GD1_GUIA = 'GD202610-C1' AND D_E_L_E_T_ = ' '") == 1.5 .And. ;
        Soma("SELECT GFN3_VALOR AS V FROM GFN3 WHERE GFN3_DOC = 'GD202610-C1' AND D_E_L_E_T_ = ' '") == 1.5)

    // ===== Parcelamento da guia
    lOk := Chk(lOk, "guia gdx", GEBDERGUIA("GDX", "IBSCBS", "202609", 300, "20261020", "2.01.004", "")[1])
    GEBDJUR("GDX", 10)
    lOk := Chk(lOk, "parcela", GEBDPAR("GDX", 3))
    aH := TCSqlQuery("SELECT GFN3_DOC AS D, GFN3_VALOR AS V FROM GFN3 WHERE GFN3_DOC LIKE 'GDX%' AND D_E_L_E_T_ = ' ' ORDER BY GFN3_DOC")
    lOk := Chk(lOk, "titulos parcelas", Len(aH) == 3 .And. BOCOL(aH[1]:D) == "GDX/01" .And. BOVAL(aH[1]:V) == 105.3 .And. BOVAL(aH[3]:V) == 105.3)
    lOk := Chk(lOk, "juros embutidos", Perna("FIN_JUROS_PAG:GDX", "D", "4.02.002") == 15.9)
    lOk := Chk(lOk, "paga parcela", GEBFXBAI("P", "GDX/01", 105.3, 0, 0, 0, "BANCO", "20261021")[1])
    lOk := Chk(lOk, "gd2 baixada", Len(TCSqlQuery("SELECT GD2_PARC FROM GD2 WHERE GD2_GUIA = 'GDX' AND GD2_PARC = '001' AND GD2_STATUS = 'BAIXADA' AND D_E_L_E_T_ = ' '")) == 1 .And. ;
        Len(TCSqlQuery("SELECT GD1_GUIA FROM GD1 WHERE GD1_GUIA = 'GDX' AND GD1_STATUS = 'PARCELADA'")) == 1)
    lOk := Chk(lOk, "reparcela recusado", !GEBDPAR("GDX", 2))
    lOk := Chk(lOk, "quita parcelas", GEBDERPAGA("GDX", "BANCO", "20261021")[1] .And. ;
        Len(TCSqlQuery("SELECT GD1_GUIA FROM GD1 WHERE GD1_GUIA = 'GDX' AND GD1_STATUS = 'BAIXADA'")) == 1 .And. ;
        Len(TCSqlQuery("SELECT GD2_PARC FROM GD2 WHERE GD2_GUIA = 'GDX' AND GD2_STATUS = 'BAIXADA' AND D_E_L_E_T_ = ' '")) == 3)

    // ===== Retencoes
    lOk := Chk(lOk, "ret tributo invalido", !GEBRETCAD("XX", "ICMS", 5, "")[1])
    lOk := Chk(lOk, "ret cadastro", GEBRETCAD("ISS5", "ISS", 5, "ISS")[1] .And. GEBRETCAD("IR15", "IRRF", 1.5, "IRRF")[1] .And. GEBRETCAD("ISS2", "ISS", 2, "")[1])
    lOk := Chk(lOk, "ret tributo repetido", !GEBRETVAL("ISS5,ISS2")[1])
    GEBCPXPED("PC2", "F2", {{"S1", 1, 1000}}, "0", "", "20261012")
    GEBCPXPED("PC3", "F2", {{"S1", 1, 400}}, "0", "", "20261013")
    lOk := Chk(lOk, "ret codigo inexistente", !GEBCPXENT("NFS0", "PC3", {}, 0, "20261013", "NADA")[1] .And. ;
        Len(TCSqlQuery("SELECT GFN3_DOC FROM GFN3 WHERE GFN3_DOC = 'NFS0'")) == 0)
    aR := GEBCPXENT("NFS1", "PC2", {}, 0, "20261012", "ISS5,IR15")
    lOk := Chk(lOk, "ret entrada", aR[1] .And. aR[3][4] == 65 .And. Soma("SELECT GFN3_VALOR AS V FROM GFN3 WHERE GFN3_DOC = 'NFS1' AND D_E_L_E_T_ = ' '") == 935)
    lOk := Chk(lOk, "ret guias", Soma("SELECT GD1_VALOR AS V FROM GD1 WHERE GD1_GUIA = 'RET-ISS-202610' AND D_E_L_E_T_ = ' '") == 50 .And. ;
        Soma("SELECT GFN3_VALOR AS V FROM GFN3 WHERE GFN3_DOC = 'RET-IRRF-202610' AND D_E_L_E_T_ = ' '") == 15)
    lOk := Chk(lOk, "ret contabil", Perna("RET_FORN:NFS1 ISS", "C", "2.01.005") == 50 .And. Perna("RET_FORN:NFS1 IRRF", "D", "2.01.001") == 15)
    lOk := Chk(lOk, "ret acumula", GEBCPXENT("NFS2", "PC3", {}, 0, "20261013", {"ISS5"})[1] .And. ;
        Soma("SELECT GFN3_VALOR AS V FROM GFN3 WHERE GFN3_DOC = 'RET-ISS-202610' AND D_E_L_E_T_ = ' '") == 70)
    aR := GEBRETREL("202610")
    lOk := Chk(lOk, "ret relatorio", aR[1] .And. Chave(aR[3][1], "total_retido") == 85 .And. Len(aR[3][2]) == 4)

    // ===== Caminhos antigos
    lOk := Chk(lOk, "antigo pagar", GEBFNPAG("LP1", "F9", 100, "20261231") .And. Perna("FIN_DESPESA:LP1", "D", "4.02.006") == 100)
    lOk := Chk(lOk, "antigo baixa", GEBFNBAI("PAG", "LP1", 100) .And. Perna("FIN_PAG:LP1", "D", "2.01.001") == 100 .And. ;
        Perna("FIN_PAG:LP1", "C", "1.01.001") == 100 .And. Perna("FIN_PAG:LP1", "C", "3.01.001") == 0)
    lOk := Chk(lOk, "antigo fiado", GEBVFIA("CF1", 300))
    cRec := BOCOL(TCSqlQuery("SELECT MAX(R_E_C_N_O_) AS R FROM GV3")[1]:R)
    lOk := Chk(lOk, "fiado titulo", Soma("SELECT GFN2_VALOR AS V FROM GFN2 WHERE GFN2_DOC = " + GEBDBQuote("FIA-" + cRec) + " AND D_E_L_E_T_ = ' '") == 300)
    lOk := Chk(lOk, "fiado recebido", GEBFNBAI("REC", "FIA-" + cRec, 300) .And. ;
        Len(TCSqlQuery("SELECT GV3_CLI FROM GV3 WHERE R_E_C_N_O_ = " + cRec + " AND GV3_STATUS = 'QUITADA'")) == 1)
    lOk := Chk(lOk, "balcao", GEBVVEN("VV1", "P1", 2, 10) == "VENDIDA")
    lOk := Chk(lOk, "balcao kardex", Len(TCSqlQuery("SELECT GES2_DOC FROM GES2 WHERE GES2_DOC = 'VV1' AND GES2_TIPO = 'S'")) == 1 .And. Perna("VENDA_CMV:VV1", "D", "4.01.001") > 0)
    lOk := Chk(lOk, "balcao recebido", Len(TCSqlQuery("SELECT GFN2_DOC FROM GFN2 WHERE GFN2_DOC = 'VV1' AND GFN2_STATUS = 'RECEBIDA'")) == 1)
    GEBCMFOR("F5", "Fornecedor 5")
    GEBCMPED("PL1", "F5")
    GEBCMIT("PL1", "P1", 2, 5)
    lOk := Chk(lOk, "entrada antiga", GEBCMENT("NFL1", "PL1") .And. Len(TCSqlQuery("SELECT GCQ4_NF FROM GCQ4 WHERE GCQ4_NF = 'NFL1'")) == 1 .And. ;
        Soma("SELECT GFN3_VALOR AS V FROM GFN3 WHERE GFN3_DOC = 'NFL1' AND D_E_L_E_T_ = ' '") == 10 .And. ;
        Len(TCSqlQuery("SELECT GES2_DOC FROM GES2 WHERE GES2_DOC = 'NFL1' AND GES2_TIPO = 'E'")) == 1)

    // ===== Correcao dos lancamentos antigos (PADRAO D caixa / C receita)
    CTBLAN("GDX", 50)
    CTBLAN("NFL1", 10)
    CTBLAN("NFL1", 10)
    CTBLAN("LP1", 100)
    CTBLAN("VV1", 20)
    CTBLAN("ZZ9", 5)
    aR := GEBCTXCORRIGE()
    lOk := Chk(lOk, "corrige", aR[1] .And. Len(aR[3]) == 6 .And. Len(TCSqlQuery("SELECT GC2_LOTE FROM GC2 WHERE GC2_TIPO = 'ESTORNO'")) == 5)
    lOk := Chk(lOk, "corrige tipos", Perna("FIN_PAG:GDX", "D", "3.02.002") == 50 .And. Perna("COMPRA_ESTOQUE:NFL1", "D", "1.01.004") == 20 .And. ;
        Perna("FIN_PAG:NFL1", "D", "2.01.001") == 10 .And. Perna("FIN_PAG:LP1", "D", "4.02.006") == 100 .And. Perna("FIN_REC:VV1", "C", "1.01.003") == 40)
    lOk := Chk(lOk, "corrige de novo", Len(GEBCTXCORRIGE()[3]) == 1)

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebinteg CASCADE")

    If lOk
        ConOut("T_GEBINTEG PASS")
    Else
        ConOut("T_GEBINTEG FAIL")
    EndIf
Return lOk

// Soma das pernas da origem (GC2_ORIGEM) na conta e no lado D/C.
Static Function Perna(cOrigem, cDC, cConta)
Return Soma("SELECT SUM(GC3_VALOR) AS V FROM GC3 JOIN GC2 ON GC2_LOTE = GC3_LOTE WHERE GC2_ORIGEM = " + GEBDBQuote(cOrigem) + ;
    " AND GC3_DC = " + GEBDBQuote(cDC) + " AND GC3_CONTA = " + GEBDBQuote(cConta) + " AND GC3.D_E_L_E_T_ = ' '")

// Primeiro valor V da consulta (0 se vazio ou nulo).
Static Function Soma(cSql)
    Local aH := TCSqlQuery(cSql)
    If Len(aH) == 0
        Return 0
    EndIf
Return Round(BOVAL(aH[1]:V), 2)

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
