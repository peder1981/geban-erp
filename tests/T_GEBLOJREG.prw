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
#include "../src/GEBDFE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBLOJREG
    DIFAL extraoficial + crypto no PDV/faturamento:
    - regime COMPROVANTE/FISCAL em GEBLOJVEN (GLJ3_REGIME) e GEBFATPED
      (GFT3_REGIME); regime invalido recusado; COMPROVANTE nao emite NF-e.
    - teto de desconto por regime (GE4 LOJ_REG_ATIVO/LOJ_REG_DESCC/DESCF):
      COMPROVANTE + dinheiro usa DESCC; demais casos DESCF.
      No PDV o desconto e' em R$, no pedido de faturamento e' em %.
    - crypto: sem conta CRY_CONTA falha; com wallet+cotacao grava GLJ5
      FORMA=CRYPTO e auditoria em GCK2 (cotacao depende de rede).
    Schema descartavel test_geblojreg.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 26/11/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBLOJREG()
    Local lOk := .T.
    Local aR := {}
    Local cSes := ""
    Local cNumC := ""
    Local cNumF := ""
    Local cEnd := "1A1zP1eBV4YqeZqSypBkMYbB"

    If !GEBDBConecta()
        ConOut("T_GEBLOJREG FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_geblojreg CASCADE")
    TCSqlExec("CREATE SCHEMA test_geblojreg")
    TCSqlExec("SET search_path TO test_geblojreg")
    lOk := Chk(GENMIG() .And. GEBFMIG() .And. GEBLOJMIG(), "mig", lOk)
    ConOut("=== T_GEBLOJREG ===")

    // Massa basica (mesmo padrao de T_GEBLOJ): P1 = 10,00 com estoque.
    GEBFNCON("BANCO", "Banco")
    GEBFNCON("CRYPTO", "Crypto")
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'P1', 'N1', 'Produto 1')")
    TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'N1', 10, 5, '20200101', '20991231')")
    GEBFATPRC("", "P1", 10)
    GEBFATCLI("C1", "Cliente 1", "", "SP", 0, "", "")
    GEBESTMOV("P1", "", "E", 100, 4, "COMPRA", "X", "20261101")
    lOk := Chk(GEBLOJCX("01", "Caixa 1", "", "")[1], "caixa", lOk)
    aR := GEBLOJABRE("01", "maria", 100, "20261126")
    lOk := Chk(aR[1], "abrir", lOk)
    cSes := aR[3]

    // 1. Regime no PDV.
    aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 0, "", "", "", "", "", "XPTO")
    lOk := Chk(!aR[1] .And. ("regime_invalido" $ BOSTR(aR[2])), "regime invalido", lOk)
    aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 0, "", "", "", "", "", "COMPROVANTE")
    lOk := Chk(aR[1], "venda comprovante", lOk)
    lOk := Chk(Len(TCSqlQuery("SELECT GLJ3_REGIME AS R FROM GLJ3 WHERE GLJ3_CUPOM = " + GEBDBQuote(aR[3][1]))[1]:R) > 0, "cupom gravado", lOk)
    aR := TCSqlQuery("SELECT GLJ3_REGIME AS R, GLJ3_NOTA AS N FROM GLJ3 WHERE GLJ3_CUPOM = " + GEBDBQuote(aR[3][1]))
    lOk := Chk(BOCOL(aR[1]:R) == "COMPROVANTE", "regime gravado", lOk)
    aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 0)
    lOk := Chk(aR[1], "venda padrao", lOk)
    aR := TCSqlQuery("SELECT GLJ3_REGIME AS R FROM GLJ3 WHERE GLJ3_CUPOM = " + GEBDBQuote(aR[3][1]))
    lOk := Chk(BOCOL(aR[1]:R) == "FISCAL", "regime padrao fiscal", lOk)

    // 2. Teto de desconto por regime (bruto = 10,00; desconto em R$).
    BOSETPARM("LOJ_REG_ATIVO", "S")
    BOSETPARM("LOJ_REG_DESCC", "10")
    BOSETPARM("LOJ_REG_DESCF", "3")
    // COMPROVANTE + dinheiro: teto 10% = 1,00. Desconto 1,50 (15%) recusa.
    aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 1.5, "", "", "", "", "", "COMPROVANTE")
    lOk := Chk(!aR[1] .And. ("desconto_acima_do_limite" $ BOSTR(aR[2])), "comp+din acima do teto", lOk)
    // COMPROVANTE + pix: teto cai para 3% = 0,30.
    aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"PIX", 10}}, "", 1.5, "", "", "", "", "", "COMPROVANTE")
    lOk := Chk(!aR[1] .And. ("desconto_acima_do_limite" $ BOSTR(aR[2])), "comp+pix acima do teto", lOk)
    // COMPROVANTE + dinheiro dentro do teto: 0,50 (5%) passa.
    aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 0.5, "", "", "", "", "", "COMPROVANTE")
    lOk := Chk(aR[1] .And. (aR[3][2] == 9.5), "comp+din dentro do teto", lOk)
    // FISCAL sempre usa DESCF (3% = 0,30), mesmo em dinheiro.
    aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 0.5, "", "", "", "", "", "FISCAL")
    lOk := Chk(!aR[1] .And. ("desconto_acima_do_limite" $ BOSTR(aR[2])), "fiscal acima do teto", lOk)
    aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 0.2, "", "", "", "", "", "FISCAL")
    lOk := Chk(aR[1] .And. (aR[3][2] == 9.8), "fiscal dentro do teto", lOk)
    BOSETPARM("LOJ_REG_ATIVO", "N")

    // 3. Crypto no PDV: sem conta configurada falha antes da cotacao.
    aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"CRYPTO", 10, 1, "BTC|" + cEnd}}, "", 0, "", "", "", "", "", "FISCAL")
    lOk := Chk(!aR[1] .And. ("conta_crypto" $ BOSTR(aR[2])), "crypto sem conta", lOk)
    BOSETPARM("CRY_CONTA", "CRYPTO")
    lOk := Chk(GEBCRYWAL("BTC", cEnd, "S")[1], "wallet btc", lOk)
    // Sem carteira de outro lado: XMR nao tem wallet -> recusa deterministica.
    aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"CRYPTO", 10, 1, "XMR|4" + cEnd}}, "", 0, "", "", "", "", "", "FISCAL")
    lOk := Chk(!aR[1] .And. ("crypto" $ BOSTR(aR[2])), "crypto sem wallet", lOk)
    // Caminho feliz depende da rede (CoinGecko). Sem rede: registra e segue.
    aR := GEBCRYCOT("BTC")
    If Len(aR) > 0 .And. aR[1][2] > 0
        aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"CRYPTO", 10, 1, "BTC|" + cEnd}}, "", 0, "", "", "", "", "", "FISCAL")
        lOk := Chk(aR[1], "venda crypto", lOk)
        If aR[1]
            aR := TCSqlQuery("SELECT GLJ5_FORMA AS F, GLJ5_VALOR AS V FROM GLJ5 WHERE GLJ5_CUPOM = " + GEBDBQuote(aR[3][1]) + " AND GLJ5_FORMA = 'CRYPTO'")
            lOk := Chk(Len(aR) == 1 .And. (BOVAL(aR[1]:V) == 10), "glj5 crypto", lOk)
            aR := TCSqlQuery("SELECT GCK2_MOEDA AS M, GCK2_BRL AS B, GCK2_QTD AS Q FROM GCK2 WHERE GCK2_CUPOM = " + GEBDBQuote(aR[3][1]))
            lOk := Chk(Len(aR) == 1 .And. (BOCOL(aR[1]:M) == "BTC") .And. (BOVAL(aR[1]:B) == 10) .And. (BOVAL(aR[1]:Q) > 0), "gck2 auditoria", lOk)
            aR := TCSqlQuery("SELECT GFN1_SALDO AS S FROM GFN1 WHERE GFN1_CONTA = 'CRYPTO'")
            lOk := Chk(Len(aR) == 1 .And. (BOVAL(aR[1]:S) == 10), "conta crypto creditada", lOk)
        EndIf
    Else
        ConOut("  SKIP venda crypto (sem rede para CoinGecko)")
    EndIf

    // 4. Regime no faturamento (GFT3). Aqui nDesc e' PERCENTUAL.
    BOSETPARM("LOJ_REG_ATIVO", "S")
    BOSETPARM("LOJ_REG_DESCC", "10")
    BOSETPARM("LOJ_REG_DESCF", "3")
    lOk := Chk(!GEBFATPED("", "C1", {{"P1", 1}}, "", 0, "", "20261126", "", "XPTO")[1], "ped regime invalido", lOk)
    aR := GEBFATPED("", "C1", {{"P1", 1}}, "", 0.5, "", "20261126", "", "COMPROVANTE")
    lOk := Chk(aR[1], "ped comprovante", lOk)
    cNumC := aR[3][1]
    aR := TCSqlQuery("SELECT GFT3_REGIME AS R FROM GFT3 WHERE GFT3_NUM = " + GEBDBQuote(cNumC))
    lOk := Chk(BOCOL(aR[1]:R) == "COMPROVANTE", "gft3 regime", lOk)
    // FISCAL teto 3%: 5% recusa; COMPROVANTE teto 10%: 15% recusa.
    aR := GEBFATPED("", "C1", {{"P1", 1}}, "", 5, "", "20261126", "", "FISCAL")
    lOk := Chk(!aR[1] .And. ("desconto_acima_do_limite" $ BOSTR(aR[2])), "ped fiscal acima do teto", lOk)
    aR := GEBFATPED("", "C1", {{"P1", 1}}, "", 15, "", "20261126", "", "COMPROVANTE")
    lOk := Chk(!aR[1] .And. ("desconto_acima_do_limite" $ BOSTR(aR[2])), "ped comp acima do teto", lOk)
    aR := GEBFATPED("", "C1", {{"P1", 1}}, "", 2, "", "20261126", "", "FISCAL")
    lOk := Chk(aR[1], "ped fiscal dentro", lOk)
    cNumF := aR[3][1]
    BOSETPARM("LOJ_REG_ATIVO", "N")

    // 5. COMPROVANTE nao emite NF-e mesmo com DFE_NFE=S; FISCAL tenta e falha
    //    sem certificado (prova que o desvio do regime funciona).
    lOk := Chk(GEBFATLIB(cNumC, .F.)[1], "libera comp", lOk)
    lOk := Chk(GEBFATLIB(cNumF, .F.)[1], "libera fiscal", lOk)
    BOSETPARM("DFE_NFE", "S")
    aR := GEBFATFAT(cNumC, {}, "20261126", "")
    lOk := Chk(aR[1], "fat comprovante sem nf-e", lOk)
    aR := GEBFATFAT(cNumF, {}, "20261126", "")
    lOk := Chk(!aR[1], "fat fiscal tenta nf-e", lOk)
    BOSETPARM("DFE_NFE", "N")

    TCSqlExec("SET search_path TO test_geblojreg")
    TCSqlExec("DROP SCHEMA IF EXISTS test_geblojreg CASCADE")

    If lOk
        ConOut("T_GEBLOJREG PASS")
    Else
        ConOut("T_GEBLOJREG FAIL")
    EndIf
Return lOk

Static Function Chk(lCond, cMsg, lOk)
    If lCond
        ConOut("  OK " + cMsg)
    Else
        ConOut("  FAIL " + cMsg)
    EndIf
Return lCond .And. lOk
