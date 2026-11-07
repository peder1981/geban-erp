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
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBV_VEN.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
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

/*/{Protheus.doc} T_GEBV_MASSA
    Teste de massa estoq 100 vendas (Task 5 GEB_ESTOQ_VENDA).
    Chamada sem prefixo U e include relativo: exigencia do
    runtime AdvPP.
    Asserts: migracoes GENMIG mais GEBVMIG mais GEBFMIG mais
    GEBDMIG OK; pre-cleanup E100; seed PROD_MASSA 1000 via
    GEBVEST; loop 100 vendas E100-1 ate E100-100 de 5 unidades
    via GEBVVEN todas VENDIDA; conta 100 GV2 ativas VENDIDA
    via workarea; saldo GV1 500 via workarea; regressao
    nucleo-fiscal-derrama; pos-cleanup conta zero; rerun
    limpo. So literais em TCSqlExec-TCSqlQuery fora do loop;
    massa via workarea; ConOut PASS-FAIL.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23-09-2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBV_MASSA()
    Local lOk := .T.
    Local nI := 0
    Local cVenda := ""
    Local cSt := ""
    Local nS := 0
    Local cFil1 := ""
    Local cFil2 := ""
    Local nCount := 0
    Local nVen := 0
    Local nSaldo := 0

    If !GEBDBConecta()
        ConOut("T_GEBV_MASSA: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebv_massa CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebv_massa")
    TCSqlExec("SET search_path TO test_gebv_massa")

    GBAUDINIC()

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBVMIG()
        lOk := .F.
    EndIf
    If !GEBFMIG()
        lOk := .F.
    EndIf
    If !GEBDMIG()
        lOk := .F.
    EndIf

    LimpaMassa()

    nS := GEBVEST("PROD_MASSA", 1000)
    If !(nS == 1000)
        lOk := .F.
    EndIf

    For nI := 1 To 100
        cVenda := "E100-" + cValToChar(nI)
        cSt := GEBVVEN(cVenda, "PROD_MASSA", 5)
        If !(cSt == "VENDIDA")
            lOk := .F.
        EndIf
    Next

    cFil2 := FWxFilial("GV2")
    nCount := 0
    nVen := 0
    DbSelectArea("GV2")
    DbGoTop()
    While !Eof()
        If GV2->GV2_FILIAL == cFil2 .AND. GV2->D_E_L_E_T_ == " "
            If SubStr(GV2->GV2_VENDA, 1, 5) == "E100-"
                nCount := nCount + 1
                If GV2->GV2_STATUS == "VENDIDA"
                    nVen := nVen + 1
                EndIf
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !(nCount == 100)
        lOk := .F.
    EndIf
    If !(nVen == 100)
        lOk := .F.
    EndIf

    cFil1 := FWxFilial("GV1")
    nSaldo := 0
    DbSelectArea("GV1")
    DbGoTop()
    While !Eof()
        If GV1->GV1_FILIAL == cFil1 .AND. GV1->GV1_PROD == "PROD_MASSA" .AND. GV1->D_E_L_E_T_ == " "
            nSaldo := GV1->GV1_SALDO
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !(nSaldo == 500)
        lOk := .F.
    EndIf

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBVMIG()
        lOk := .F.
    EndIf
    If !GEBFMIG()
        lOk := .F.
    EndIf
    If !GEBDMIG()
        lOk := .F.
    EndIf

    LimpaMassa()

    nCount := 0
    DbSelectArea("GV2")
    DbGoTop()
    While !Eof()
        If GV2->GV2_FILIAL == cFil2 .AND. GV2->D_E_L_E_T_ == " "
            If SubStr(GV2->GV2_VENDA, 1, 5) == "E100-"
                nCount := nCount + 1
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !(nCount == 0)
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebv_massa CASCADE")

    If lOk
        ConOut("T_GEBV_MASSA PASS")
    Else
        ConOut("T_GEBV_MASSA FAIL")
    EndIf
Return lOk

Static Function LimpaMassa()
    Local cFil1 := FWxFilial("GV1")
    Local cFil2 := FWxFilial("GV2")
    Local cFil3 := FWxFilial("GF3")
    Local cFil4 := FWxFilial("GF4")
    Local cFil5 := FWxFilial("GE5")

    DbSelectArea("GV1")
    DbGoTop()
    While !Eof()
        If GV1->GV1_FILIAL == cFil1 .AND. GV1->D_E_L_E_T_ == " "
            If GV1->GV1_PROD == "PROD_MASSA"
                RecLock("GV1", .F.)
                GV1->D_E_L_E_T_ := "*"
                MsUnlock()
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    DbSelectArea("GV2")
    DbGoTop()
    While !Eof()
        If GV2->GV2_FILIAL == cFil2 .AND. GV2->D_E_L_E_T_ == " "
            If SubStr(GV2->GV2_VENDA, 1, 5) == "E100-"
                RecLock("GV2", .F.)
                GV2->D_E_L_E_T_ := "*"
                MsUnlock()
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    DbSelectArea("GF3")
    DbGoTop()
    While !Eof()
        If GF3->GF3_FILIAL == cFil3 .AND. GF3->D_E_L_E_T_ == " "
            If SubStr(GF3->GF3_CHAVE, 1, 5) == "E100-"
                RecLock("GF3", .F.)
                GF3->D_E_L_E_T_ := "*"
                MsUnlock()
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    DbSelectArea("GF4")
    DbGoTop()
    While !Eof()
        If GF4->GF4_FILIAL == cFil4 .AND. GF4->D_E_L_E_T_ == " "
            If SubStr(GF4->GF4_CHAVE, 1, 5) == "E100-"
                RecLock("GF4", .F.)
                GF4->D_E_L_E_T_ := "*"
                MsUnlock()
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    DbSelectArea("GE5")
    DbGoTop()
    While !Eof()
        If GE5->GE5_FILIAL == cFil5 .AND. GE5->D_E_L_E_T_ == " "
            If SubStr(GE5->GE5_CHAVE, 1, 5) == "E100-"
                RecLock("GE5", .F.)
                GE5->D_E_L_E_T_ := "*"
                MsUnlock()
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
Return .T.
