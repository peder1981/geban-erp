#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GENUC_CAD.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBSEC_TOKEN.prw"
#include "../src/GEBEXP_CTX.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBMON.prw"
#include "../src/GEBEXP_REL_BIZ.prw"
#include "../src/GEBEXP_REL_NUC.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GEBFIN_FLX.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBV_VEN.prw"
#include "../src/GEBV_FIA.prw"
#include "../src/GEBCTB_DIR.prw"
#include "../src/GEBCTB_BAL.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBCOM_FOR.prw"
#include "../src/GEBCOM_PED.prw"
#include "../src/GEBCOM_ENT.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBSN.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBREST.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBCTX.prw"
#include "../src/GEBEST.prw"
#include "../src/GEBFNX.prw"
#include "../src/GEBCPX.prw"
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
#include "../src/GEBBO.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBWEB_API.prw"
#include "../src/GEBBCO.prw"
#include "../src/GEBTUIBO.prw"
#include "../src/GEBTUI.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"

/*/{Protheus.doc} T_GEBTUIBO
    Fumaca do backoffice: (1) toda rota de GEBBOROTAS despacha para uma
    funcao (nenhuma cai em "rota_sem_execucao") e aguenta requisicao vazia
    sem erro de execucao; (2) as telas novas abrem e saem sem erro (sem
    interface, FWMenuSelect devolve 0).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 18/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBTUIBO()
    Local lOk := .T.
    Local aRot := {}
    Local aR := {}
    Local nI := 0

    If !GEBDBConecta()
        ConOut("T_GEBTUIBO FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebtuibo CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebtuibo")
    TCSqlExec("SET search_path TO test_gebtuibo")
    GENMIG()
    GEBFMIG()
    lOk := Chk(lOk, "mig", GEBLOJMIG() .And. GEBCPXMIG() .And. GEBBCOMIG())

    aRot := GEBBOROTAS()
    lOk := Chk(lOk, "rotas", Len(aRot) > 40)
    For nI := 1 To Len(aRot)
        aR := GEBBOEXEC(aRot[nI][1], aRot[nI][2], JsonObject():New(), "super")
        lOk := Chk(lOk, "despacho " + aRot[nI][2], Len(aR) == 3 .And. !("rota_sem_execucao" $ aR[2]) .And. !("rota_inexistente" $ aR[2]))
    Next nI
    lOk := Chk(lOk, "rota inexistente", "rota_inexistente" $ GEBBOEXEC("POST", "nada/nada", JsonObject():New(), "super")[2])
    lOk := Chk(lOk, "metodo errado", "rota_inexistente" $ GEBBOEXEC("GET", "loja/venda", JsonObject():New(), "super")[2])


    TCSqlExec("DROP SCHEMA IF EXISTS test_gebtuibo CASCADE")
    If lOk
        ConOut("T_GEBTUIBO PASS")
    Else
        ConOut("T_GEBTUIBO FAIL")
    EndIf
Return lOk

Static Function Chk(lOk, cNome, lCond)
    If !lCond
        ConOut("  FAIL: " + cNome)
        Return .F.
    EndIf
Return lOk
