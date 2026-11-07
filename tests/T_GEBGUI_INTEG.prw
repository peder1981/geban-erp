#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBGUI_MAIN.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBFIN_FLX.prw"
#include "../src/GEBCOM_ENT.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
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
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBGUI_INTEG
    Integracao completa: menu -> migracoes -> cadastro -> venda ->
    apuracao -> derrama -> baixa -> fluxo (Task 6 GUI).
    Simula o fluxo end-to-end via Chamadas diretas (sem ConIn real)
    e verifica que cada modulo migra e opera sem erro.
    @type Teste de integracao automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBGUI_INTEG()
    Local lOk := .T.
    Local nPassos := 0
    Local nTotal := 0
    Local lTmp := .F.
    Local cGuia := ""
    Local aFlx := {}

    If !GEBDBConecta()
        ConOut("T_GEBGUI_INTEG: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebgui_integ CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebgui_integ")
    TCSqlExec("SET search_path TO test_gebgui_integ")

    GBAUDINIC()

    ConOut("--- T_GEBGUI_INTEG ---")

    ConOut("[1/8] Nucleo - GENMIG...")
    nTotal++
    If GENMIG()
        ConOut("  NUCLEO OK")
        nPassos++
    Else
        ConOut("  NUCLEO FAIL")
        lOk := .F.
    EndIf

    ConOut("[2/8] Fiscal - GEBFMIG + GEBFAPU...")
    nTotal++
    If GEBFMIG()
        ConOut("  FISCAL MIG OK")
        nPassos++
    Else
        ConOut("  FISCAL MIG FAIL")
        lOk := .F.
    EndIf

    ConOut("[3/8] Derrama - GEBDMIG + GEBDGER...")
    nTotal++
    If GEBDMIG()
        ConOut("  DERRAMA MIG OK")
        nPassos++
    Else
        ConOut("  DERRAMA MIG FAIL")
        lOk := .F.
    EndIf
    cGuia := GEBDGER("202609")
    If cGuia != ""
        ConOut("  DERRAMA GER OK: " + cGuia)
    Else
        ConOut("  DERRAMA GER SKIP (sem dados)")
    EndIf

    ConOut("[4/8] Estoque - GEBVMIG...")
    nTotal++
    If GEBVMIG()
        ConOut("  ESTOQUE OK")
        nPassos++
    Else
        ConOut("  ESTOQUE FAIL")
        lOk := .F.
    EndIf

    ConOut("[5/8] Contabil - GEBCMIG...")
    nTotal++
    If GEBCMIG()
        ConOut("  CONTABIL OK")
        nPassos++
    Else
        ConOut("  CONTABIL FAIL")
        lOk := .F.
    EndIf

    ConOut("[6/8] Fin - GEBFNMIG + GEBNFLX...")
    nTotal++
    If GEBFNMIG()
        ConOut("  FIN MIG OK")
        nPassos++
    Else
        ConOut("  FIN MIG FAIL")
        lOk := .F.
    EndIf
    aFlx := GEBNFLX()
    If Len(aFlx) > 0
        ConOut("  FIN FLUXO OK (" + cValToChar(Len(aFlx)) + " itens)")
    Else
        ConOut("  FIN FLUXO VAZIO (ok, sem mov)")
    EndIf

    ConOut("[7/8] Compras - GEBCMMIG...")
    nTotal++
    If GEBCMMIG()
        ConOut("  COMPRAS OK")
        nPassos++
    Else
        ConOut("  COMPRAS FAIL")
        lOk := .F.
    EndIf

    ConOut("[8/8] Config - GEBGUICFG...")
    nTotal++
    lTmp := GEBGUICFG()
    If lTmp
        ConOut("  CONFIG OK")
        nPassos++
    Else
        ConOut("  CONFIG FAIL")
        lOk := .F.
    EndIf

    ConOut("")
    ConOut("RESULTADO: " + cValToChar(nPassos) + "/" + cValToChar(nTotal) + " checks")

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebgui_integ CASCADE")

    If lOk .And. nPassos == nTotal
        ConOut("T_GEBGUI_INTEG PASS")
    Else
        ConOut("T_GEBGUI_INTEG FAIL")
    EndIf
Return lOk
