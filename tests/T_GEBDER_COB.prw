#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBCOM_MIG.prw"
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

/*/{Protheus.doc} T_GEBDER_COB
    Teste da cobranca derrama (Task 3 GEB_DERRAMA).
    Chamada sem prefixo U e include relativo: exigencia do
    runtime AdvPP.
    Asserts: migracoes OK; seed GF5 202607 saldo 1000; GEBDGER
    retorna GD202607; GEBDJUR 10 dias total 1053 (juros 33 mais
    multa 20); teto GEBDJUR 100 dias total 1220 (juros 200 mais
    multa 20); GEBDPAR 2 parcelas .T. mais 2 linhas GD2 de 610;
    GEBDPRO .T. mais GD3 PROTESTO mais GD1 PROTESTADA; cleanup
    DELETE rerun limpo. So literais; ConOut PASS-FAIL.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23-09-2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBDER_COB()
    Local lOk := .T.
    Local lTmp := .F.
    Local cGuia := ""
    Local nTot10 := 0
    Local nTot100 := 0
    Local cFil := ""
    Local nCount := 0
    Local nV1 := 0
    Local nV2 := 0
    Local lAchou := .F.
    Local cStatus := ""
    Local cAcao := ""

    If !GEBDBConecta()
        ConOut("T_GEBDER_COB: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebder_cob CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebder_cob")
    TCSqlExec("SET search_path TO test_gebder_cob")

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBFMIG()
        lOk := .F.
    EndIf
    If !GEBDMIG()
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GD1 WHERE GD1_GUIA = 'GD202607'")
    lTmp := TCSqlExec("DELETE FROM GD2 WHERE GD2_GUIA = 'GD202607'")
    lTmp := TCSqlExec("DELETE FROM GD3 WHERE GD3_GUIA = 'GD202607'")
    lTmp := TCSqlExec("DELETE FROM GF5 WHERE GF5_COMP = '202607'")
    lTmp := TCSqlExec("INSERT INTO GF5 (D_E_L_E_T_, GF5_FILIAL, GF5_COMP, GF5_DEB, GF5_CRED, GF5_SALDO, GF5_REGIME) VALUES (' ', '      ', '202607', 1000, 0, 1000, 'REGULAR')")
    If !lTmp
        lOk := .F.
    EndIf

    cGuia := GEBDGER("202607")
    If !(cGuia == "GD202607")
        lOk := .F.
    EndIf

    nTot10 := GEBDJUR("GD202607", 10)
    If !(nTot10 == 1053)
        lOk := .F.
    EndIf

    nTot100 := GEBDJUR("GD202607", 100)
    If !(nTot100 == 1220)
        lOk := .F.
    EndIf

    lTmp := GEBDPAR("GD202607", 2)
    If !lTmp
        lOk := .F.
    EndIf
    cFil := FWxFilial("GD2")
    nCount := 0
    nV1 := 0
    nV2 := 0
    DbSelectArea("GD2")
    DbGoTop()
    While !Eof()
        If GD2->GD2_FILIAL == cFil .AND. GD2->GD2_GUIA == "GD202607" .AND. GD2->D_E_L_E_T_ == " "
            nCount := nCount + 1
            If nCount == 1
                nV1 := GD2->GD2_VALOR
            EndIf
            If nCount == 2
                nV2 := GD2->GD2_VALOR
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !(nCount == 2)
        lOk := .F.
    EndIf
    If !(nV1 == 610)
        lOk := .F.
    EndIf
    If !(nV2 == 610)
        lOk := .F.
    EndIf

    lTmp := GEBDPRO("GD202607")
    If !lTmp
        lOk := .F.
    EndIf
    cFil := FWxFilial("GD1")
    lAchou := .F.
    DbSelectArea("GD1")
    DbGoTop()
    While !Eof()
        If GD1->GD1_FILIAL == cFil .AND. GD1->GD1_GUIA == "GD202607" .AND. GD1->D_E_L_E_T_ == " "
            lAchou := .T.
            cStatus := GD1->GD1_STATUS
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !lAchou
        lOk := .F.
    EndIf
    If !(cStatus == "PROTESTADA")
        lOk := .F.
    EndIf
    cFil := FWxFilial("GD3")
    lAchou := .F.
    DbSelectArea("GD3")
    DbGoTop()
    While !Eof()
        If GD3->GD3_FILIAL == cFil .AND. GD3->GD3_GUIA == "GD202607" .AND. GD3->D_E_L_E_T_ == " "
            lAchou := .T.
            cAcao := GD3->GD3_ACAO
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !lAchou
        lOk := .F.
    EndIf
    If !(cAcao == "PROTESTO")
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GD1 WHERE GD1_GUIA = 'GD202607'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GD2 WHERE GD2_GUIA = 'GD202607'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GD3 WHERE GD3_GUIA = 'GD202607'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF5 WHERE GF5_COMP = '202607'")
    If !lTmp
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebder_cob CASCADE")

    If lOk
        ConOut("T_GEBDER_COB PASS")
    Else
        ConOut("T_GEBDER_COB FAIL")
    EndIf
Return lOk
