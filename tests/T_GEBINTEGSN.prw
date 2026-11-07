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

/*/{Protheus.doc} T_GEBINTEGSN
    Integracao do Simples Nacional com a Derrama, o financeiro e o contabil:
    configurar o Simples opta pelo regime; receita externa de 400.000 nos 12
    meses anteriores (RBT12 4,8 milhoes, 6a faixa) e 100.000 no mes gera o
    DAS e o ISS fora do DAS (Anexo III) como guias da Derrama, com titulo
    (DAS para a RFB) e provisao (SN_DAS, SN_FORA); a apuracao do IBS/CBS no
    Simples nao gera guia; regime REGULAR recusa o DAS.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 19/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBINTEGSN()
    Local lOk := .T.
    Local aR := {}
    Local aH := {}
    Local nI := 0

    If !GEBDBConecta()
        ConOut("T_GEBINTEGSN FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebinteg_sn CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebinteg_sn")
    TCSqlExec("SET search_path TO test_gebinteg_sn")
    lOk := Chk(lOk, "sn mig", GENMIG() .And. GEBFMIG() .And. GEBFNMIG() .And. GEBSNMIG() .And. GEBDERFMIG())
    lOk := Chk(lOk, "sn opta", GEBSNCFG("III", "")[1] .And. GEBREGIME() == "SIMPLES")
    For nI := 1 To 12
        GEBSNFOL(BOMESADD("202610", -nI), 0, 400000)
    Next nI
    GEBSNFOL("202610", 0, 100000)
    aR := GEBSNAPU("202610")
    aH := TCSqlQuery("SELECT GSN2_DAS AS D, GSN2_FORA AS F FROM GSN2 WHERE GSN2_COMP = '202610' AND D_E_L_E_T_ = ' '")
    lOk := Chk(lOk, "sn apura", aR[1] .And. Len(aH) == 1 .And. BOVAL(aH[1]:D) > 0 .And. BOVAL(aH[1]:F) > 0)
    If Len(aH) == 1
        lOk := Chk(lOk, "sn guia das", Soma("SELECT GD1_VALOR AS V FROM GD1 WHERE GD1_GUIA = 'DAS-202610' AND D_E_L_E_T_ = ' '") == BOVAL(aH[1]:D) .And. ;
            Len(TCSqlQuery("SELECT GFN3_DOC FROM GFN3 WHERE GFN3_DOC = 'DAS-202610' AND GFN3_FORN = 'RFB'")) == 1 .And. ;
            Len(TCSqlQuery("SELECT GD4_GUIA FROM GD4 WHERE GD4_GUIA = 'DAS-202610' AND GD4_TIPO = 'DAS'")) == 1)
        lOk := Chk(lOk, "sn guia iss fora", Soma("SELECT GFN3_VALOR AS V FROM GFN3 WHERE GFN3_DOC = 'ISS-202610' AND D_E_L_E_T_ = ' '") == BOVAL(aH[1]:F))
        lOk := Chk(lOk, "sn provisoes", Perna("SN_DAS:DAS-202610", "D", "4.02.005") == BOVAL(aH[1]:D) .And. Perna("SN_FORA:ISS-202610", "C", "2.01.006") == BOVAL(aH[1]:F))
    EndIf
    GEBFAPU("202610")
    lOk := Chk(lOk, "sn sem guia ibs/cbs", Len(TCSqlQuery("SELECT GD1_GUIA FROM GD1 WHERE GD1_GUIA = 'GD202610'")) == 0)
    BOSETPARM("REGIME", "REGULAR")
    lOk := Chk(lOk, "regular recusa das", !GEBSNAPU("202610")[1])
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebinteg_sn CASCADE")

    If lOk
        ConOut("T_GEBINTEGSN PASS")
    Else
        ConOut("T_GEBINTEGSN FAIL")
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
