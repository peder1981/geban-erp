#include "totvs.ch"
#include "../../src/GEBDB_CORE.prw"
#include "../../src/GEBDB_TENANT.prw"
#include "../../src/GEBPERIF_MIG.prw"
#include "../../src/GENUC_MIG.prw"
#include "../../src/GENUC_MNT.prw"
#include "../../src/GEBEXP_MIG.prw"
#include "../../src/GEBSEC_MIG.prw"
#include "../../src/GEBAUD.prw"
#include "../../src/GEBFIS_MIG.prw"
#include "../../src/GEBFIN_MIG.prw"
#include "../../src/GEBCTB_MIG.prw"
#include "../../src/GEBV_MIG.prw"
#include "../../src/GEBV_EST.prw"
#include "../../src/GEBBOLIB.prw"
#include "../../src/GEBCTX.prw"
#include "../../src/GEBEST.prw"
#include "../../src/GEBFNX.prw"
#include "../../src/GEBFAT.prw"
#include "../../src/GEBTEF.prw"
#include "../../src/GEBLOJ.prw"
#include "../../src/GEBLOJ_CAD.prw"
#include "../../src/GEBLOJ_OPE.prw"
#include "../../src/GEBSEC_POL.prw"
#include "../../src/GEBSEC_LOGIN.prw"
#include "../../src/GEBSEC_RBA.prw"
#include "../../src/GEBFIS_CAD.prw"
#include "../../src/GEBFIS_EMI.prw"
#include "../../src/GEBFIS_APU.prw"
#include "../../src/GEBFIN_CON.prw"
#include "../../src/GEBFIN_BAI.prw"
#include "../../src/GEBDER_MIG.prw"
#include "../../src/GEBDER_GUI.prw"
#include "../../src/GEBDER_BAI.prw"
#include "../../src/GEBDER_COB.prw"
#include "../../src/GEBCOM_MIG.prw"
#include "../../src/GEBCPX.prw"
#include "../../src/GEBDFE.prw"
#include "../../src/GEBDFE_NFE.prw"
#include "../../src/GEBRET.prw"
#include "../../src/GEBSN.prw"
#include "../../src/GEBCRY.prw"
#include "../../src/GESSAR.prw"

/*/{Protheus.doc} SEED_DEMO
    Semeia a empresa 99 (TESTE) do geban_test para capturas de tela:
    produtos, precos, caixa aberto, wallets crypto, regra Sarney e
    parametros do recurso. NAO roda em producao.
/*/
User Function SEED_DEMO()
    Local lOk := .T.
    Local aR := {}
    Local cSes := ""

    If !GEBDBConecta()
        ConOut("SEED_DEMO FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO emp_99, public")

    lOk := GENMIG() .And. GEBFMIG() .And. GEBFATMIG() .And. GEBLOJMIG() .And. GEBLOJCADMIG() .And. ;
        GEBCRYMIG() .And. GESSARMIG() .And. GEBCTXMIG() .And. GEBFNMIG() .And. GEBCMMIG() .And. GEBVMIG()
    ConOut("migs: " + cValToChar(lOk))

    // Parametros do recurso (ge4 da empresa).
    BOSETPARM("DFE_NFCE", "N")
    BOSETPARM("LOJ_REG_ATIVO", "S")
    BOSETPARM("LOJ_REG_DESCC", "10")
    BOSETPARM("LOJ_REG_DESCF", "3")
    BOSETPARM("CRY_CONTA", "CRYPTO")

    // Contas financeiras.
    GEBFNCON("BANCO", "Banco do Brasil")
    GEBFNCON("CRYPTO", "Crypto (BTC/USDT)")

    // Catalogo: dois produtos com preco e aliquotas.
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) SELECT ' ', '      ', 'P1', 'N1', 'Banana prata kg' WHERE NOT EXISTS (SELECT 1 FROM GF1 WHERE GF1_COD = 'P1')")
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) SELECT ' ', '      ', 'P2', 'N1', 'Arroz branco 5kg' WHERE NOT EXISTS (SELECT 1 FROM GF1 WHERE GF1_COD = 'P2')")
    TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) SELECT ' ', '      ', 'N1', 10, 5, '20200101', '20991231' WHERE NOT EXISTS (SELECT 1 FROM GF2 WHERE GF2_NCM = 'N1')")
    GEBFATPRC("", "P1", 8.90)
    GEBFATPRC("", "P2", 24.90)
    GEBESTMOV("P1", "", "E", 200, 4, "COMPRA", "X", "20261101")
    GEBESTMOV("P2", "", "E", 100, 4, "COMPRA", "X", "20261101")
    GEBFATCLI("C1", "Cliente Demo", "11999990000", "SP", 0, "", "")

    // Caixa aberto para o PDV.
    GEBLOJCX("01", "Caixa 01", "BANCO", "")
    aR := GEBLOJABRE("01", "maria", 100, DToS(Date()))
    cSes := aR[3]
    ConOut("sessao: " + cSes)

    // Wallets crypto (endereco de demonstracao — QR real depende da cotacao).
    GEBCRYWAL("BTC", "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh", "S")
    GEBCRYWAL("USDT", "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb", "S")

    // Gatilho Sarney: regra geral + override no P2.
    GESSARCFG("GERAL", "Reajuste geral 10%", 10, 3, "0800 1400", "S")
    GESSARPROD("GERAL", "P2", 25)

    // Senha conhecida do super para a captura.
    lOk := GEBSECCRIAUSU("super", "Demo#2026", {"99"}, "Super", "ADMIN", .T., "") .And. lOk

    ConOut("SEED_DEMO " + IIf(lOk, "PASS", "FAIL"))
Return lOk
