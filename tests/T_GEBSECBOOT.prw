#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBTUI.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
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
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"

/*/{Protheus.doc} T_GEBSECBOOT
    Prova o bootstrap da conta administrativa em catalogo vazio:
    GEBDBProvisionaCatalogo() -> GEBSECBOOT() deve criar "super" com a
    senha padrao e SEC_FORCE='S'; GEBSECLOGIN com a padrao retorna
    "TROCA_OBRIGATORIA"; GEBTUITROCASENHA grava a nova senha e limpa a
    flag; login seguinte OK e a senha padrao morre. Reexecutar
    GEBSECBOOT() nao pode redefinir a credencial ja trocada.
    Estado inicial forjado com DELETE das linhas de "super" (o catalogo
    de teste e' compartilhado; o bootstrap so' dispara com GE2 vazio,
    entao esvaziamos GE2 inteiro no comeco e o provisionamento recria o
    catalogo -- mesmo efeito de instalacao nova).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 08/11/2026
    @return .T. se o fluxo bootstrap + troca obrigatoria passar
/*/
User Function T_GEBSECBOOT()
    Local lOk := .T.
    Local aRes := {}
    Local aRow := {}
    Local cPadrao := "Geban#2026"
    Local cNova := "Troca#Boot9"

    // === ESTADO INICIAL: catalogo de usuarios vazio (instalacao nova).
    // Conexao primeiro (TCSqlExec precisa do driver); esvaziar GE2 faz o
    // GEBSECBOOT disparar no provisionamento seguinte. Vinculos e
    // credenciais orfaos sao removidos junto para nao deixar lixo.
    If !GEBDBConecta()
        lOk := .F.
        ConOut("FAIL: T0 GEBDBConecta falhou")
    EndIf
    TCSqlExec("DELETE FROM public.GE2_EMP")
    TCSqlExec("DELETE FROM public.GE2_SEC")
    TCSqlExec("DELETE FROM public.GE2")

    // === T1: provisionamento do catalogo dispara o bootstrap.
    If !GEBDBProvisionaCatalogo()
        lOk := .F.
        ConOut("FAIL: T1 GEBDBProvisionaCatalogo falhou")
    EndIf
    aRow := TCSqlQuery("SELECT GE2_COD FROM GE2 WHERE GE2_COD = 'super' AND D_E_L_E_T_ = ' '")
    If Len(aRow) == 0
        lOk := .F.
        ConOut("FAIL: T1 super nao foi criado pelo bootstrap")
    Else
        ConOut("  OK T1 super criado no bootstrap")
    EndIf
    aRow := TCSqlQuery("SELECT SEC_FORCE FROM GE2_SEC WHERE SEC_USUARIO = 'super' AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aRow) == 0 .Or. AllTrim(cValToChar(aRow[1]:SEC_FORCE)) != "S"
        lOk := .F.
        ConOut("FAIL: T1 SEC_FORCE deveria ser 'S'")
    Else
        ConOut("  OK T1 SEC_FORCE='S' (troca obrigatoria)")
    EndIf

    // === T2: senha padrao autentica mas exige troca.
    If GEBSECLOGIN("super", cPadrao, "teste") != "TROCA_OBRIGATORIA"
        lOk := .F.
        ConOut("FAIL: T2 login com senha padrao deveria ser TROCA_OBRIGATORIA")
    Else
        ConOut("  OK T2 senha padrao -> TROCA_OBRIGATORIA")
    EndIf

    // === T3: troca via GEBTUITROCASENHA (mesmo caminho do login TUI).
    aRes := GEBTUITROCASENHA("super", "", cNova, "", "")
    If !(Len(aRes) >= 1 .And. aRes[1])
        lOk := .F.
        ConOut("FAIL: T3 troca de senha recusada: " + cValToChar(aRes[2]))
    Else
        ConOut("  OK T3 senha trocada")
    EndIf

    // === T4: nova senha OK; padrao nao vale mais; flag limpa.
    If GEBSECLOGIN("super", cNova, "teste") != "OK"
        lOk := .F.
        ConOut("FAIL: T4 nova senha nao autentica")
    Else
        ConOut("  OK T4 nova senha autentica")
    EndIf
    If GEBSECLOGIN("super", cPadrao, "teste") == "OK"
        lOk := .F.
        ConOut("FAIL: T4 senha padrao ainda autentica")
    Else
        ConOut("  OK T4 senha padrao recusada")
    EndIf
    aRow := TCSqlQuery("SELECT SEC_FORCE FROM GE2_SEC WHERE SEC_USUARIO = 'super' AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aRow) > 0 .And. AllTrim(cValToChar(aRow[1]:SEC_FORCE)) == "N"
        ConOut("  OK T4 SEC_FORCE limpo apos troca")
    Else
        lOk := .F.
        ConOut("FAIL: T4 SEC_FORCE nao foi limpo")
    EndIf

    // === T5: idempotencia -- reboot nao redefine a credencial trocada.
    If !GEBSECBOOT()
        lOk := .F.
        ConOut("FAIL: T5 GEBSECBOOT reexecucao falhou")
    EndIf
    If GEBSECLOGIN("super", cNova, "teste") != "OK"
        lOk := .F.
        ConOut("FAIL: T5 credencial trocada foi resetada pelo reboot")
    Else
        ConOut("  OK T5 bootstrap idempotente (credencial preservada)")
    EndIf
    If GEBSECLOGIN("super", cPadrao, "teste") == "OK"
        lOk := .F.
        ConOut("FAIL: T5 senha padrao voltou a valer")
    Else
        ConOut("  OK T5 senha padrao segue morta")
    EndIf

    // === CLEANUP: remove os usuarios de teste; super fica com a senha
    // trocada pelo proprio teste (estado coerente para a suite).
    TCSqlExec("DELETE FROM public.GE2_EMP WHERE GE2_EMP_USUARIO LIKE 'T_%'")
    TCSqlExec("DELETE FROM public.GE2_SEC WHERE SEC_USUARIO LIKE 'T_%'")
    TCSqlExec("DELETE FROM public.GE2 WHERE GE2_COD LIKE 'T_%'")

    If lOk
        ConOut("T_GEBSECBOOT PASS")
    Else
        ConOut("T_GEBSECBOOT FAIL")
    EndIf
Return lOk
