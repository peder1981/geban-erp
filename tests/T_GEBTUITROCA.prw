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
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBTUITROCA
    Testes da logica pura GEBTUITROCASENHA (Trocar senha do menu Nucleo).
    Cobre: troca da propria senha (login velho nega, novo OK), troca de
    nome/perfil, guarda do super (nao-super nao toca super e a credencial
    real segue intacta, via comparacao de salt/hash), usuario inexistente,
    senha fraca recusada, super alterando terceiros, nada-a-alterar.
    Catalogo compartilhado (GE2/GE2_SEC): usuarios prefixo T_WTROCA com
    cleanup DELETE no fim (padrao T_GEBSECCRIAUSU). Nunca cria nem usa a
    senha real do super.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 26/09/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBTUITROCA()
    Local lOk := .T.
    Local aRes := {}
    Local aRow := {}
    Local aRowAdm := {}
    Local cS1 := "Senha#Forte1"
    Local cS2 := "Senha#Forte2"
    Local cS3 := "Senha#Forte3"

    ConOut("=== T_GEBTUITROCA ===")

    If !GEBDBConecta()
        ConOut("T_GEBTUITROCA: GEBDBConecta fail")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO IN ('T_WTROCA1','T_WTROCA2')")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO IN ('T_WTROCA1','T_WTROCA2')")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD IN ('T_WTROCA1','T_WTROCA2')")

    If !GEBSECCRIAUSU("T_WTROCA1", cS1, {}, "Troca Um", "OPERADOR", .F.)
        ConOut("FAIL: setup T_WTROCA1")
        Return .F.
    EndIf
    If !GEBSECCRIAUSU("T_WTROCA2", cS1, {}, "Troca Dois", "OPERADOR", .F.)
        ConOut("FAIL: setup T_WTROCA2")
        lOk := .F.
    EndIf

    // T1: troca da propria senha (alvo vazio = si mesmo).
    aRes := GEBTUITROCASENHA("T_WTROCA1", "", cS2, Nil, Nil)
    If !(Len(aRes) >= 2 .And. aRes[1])
        lOk := .F.
        ConOut("FAIL: T1 troca propria retornou " + cValToChar(aRes[2]))
    EndIf
    If GEBSECLOGIN("T_WTROCA1", cS1, "local") == "OK"
        lOk := .F.
        ConOut("FAIL: T1 senha velha ainda autentica")
    EndIf
    If GEBSECLOGIN("T_WTROCA1", cS2, "local") != "OK"
        lOk := .F.
        ConOut("FAIL: T1 senha nova nao autentica")
    EndIf
    If lOk
        ConOut("  OK T1 troca propria")
    EndIf

    // T2: troca o proprio nome; o proprio perfil NAO (ninguem se promove).
    aRes := GEBTUITROCASENHA("T_WTROCA1", "T_WTROCA1", "", "Troca Um Novo", "GERENTE")
    If !(Len(aRes) >= 2 .And. !aRes[1])
        lOk := .F.
        ConOut("FAIL: T2 proprio perfil deveria ser recusado, veio " + cValToChar(aRes[2]))
    EndIf
    aRes := GEBTUITROCASENHA("T_WTROCA1", "T_WTROCA1", "", "Troca Um Novo", "")
    If !(Len(aRes) >= 2 .And. aRes[1])
        lOk := .F.
        ConOut("FAIL: T2 proprio nome retornou " + cValToChar(aRes[2]))
    EndIf
    aRow := TCSqlQuery("SELECT GE2_NOME, GE2_PERFIL FROM GE2 WHERE GE2_COD = 'T_WTROCA1' AND D_E_L_E_T_ = ' '")
    If !(Len(aRow) == 1 .And. AllTrim(cValToChar(aRow[1]:GE2_NOME)) == "Troca Um Novo" .And. AllTrim(cValToChar(aRow[1]:GE2_PERFIL)) != "GERENTE")
        lOk := .F.
        ConOut("FAIL: T2 GE2 deveria ter o nome novo e o perfil antigo")
    EndIf
    If GEBSECLOGIN("T_WTROCA1", cS2, "local") != "OK"
        lOk := .F.
        ConOut("FAIL: T2 senha intacta apos troca de nome")
    EndIf
    If lOk
        ConOut("  OK T2 nome sim, proprio perfil nao")
    EndIf

    // T3: nao-super nao toca o super; credencial real intacta (salt/hash).
    aRowAdm := TCSqlQuery("SELECT SEC_SALT, SEC_HASH FROM GE2_SEC WHERE SEC_USUARIO = 'super' AND D_E_L_E_T_ = ' '")
    aRes := GEBTUITROCASENHA("T_WTROCA1", "super", cS3, Nil, Nil)
    If !(Len(aRes) >= 2 .And. !aRes[1] .And. AllTrim(cValToChar(aRes[2])) == "somente_super")
        lOk := .F.
        ConOut("FAIL: T3 deveria barrar com somente_super, veio " + cValToChar(aRes[2]))
    EndIf
    aRow := TCSqlQuery("SELECT SEC_SALT, SEC_HASH FROM GE2_SEC WHERE SEC_USUARIO = 'super' AND D_E_L_E_T_ = ' '")
    If Len(aRow) != Len(aRowAdm)
        lOk := .F.
        ConOut("FAIL: T3 linhas do super alteradas")
    Else
        If Len(aRow) > 0
            If AllTrim(cValToChar(aRow[1]:SEC_HASH)) != AllTrim(cValToChar(aRowAdm[1]:SEC_HASH))
                lOk := .F.
                ConOut("FAIL: T3 hash real do super alterado")
            EndIf
            If AllTrim(cValToChar(aRow[1]:SEC_SALT)) != AllTrim(cValToChar(aRowAdm[1]:SEC_SALT))
                lOk := .F.
                ConOut("FAIL: T3 salt real do super alterado")
            EndIf
        EndIf
    EndIf
    If lOk
        ConOut("  OK T3 guarda do super")
    EndIf

    // T4: usuario inexistente.
    aRes := GEBTUITROCASENHA("T_WTROCA1", "ZZINEXISTE", cS3, Nil, Nil)
    If !(Len(aRes) >= 2 .And. !aRes[1] .And. AllTrim(cValToChar(aRes[2])) == "usuario_inexistente")
        lOk := .F.
        ConOut("FAIL: T4 deveria dar usuario_inexistente, veio " + cValToChar(aRes[2]))
    Else
        ConOut("  OK T4 inexistente")
    EndIf

    // T5: senha fraca recusada e credencial intacta.
    aRes := GEBTUITROCASENHA("T_WTROCA1", "T_WTROCA1", "abc", Nil, Nil)
    If !(Len(aRes) >= 2 .And. !aRes[1])
        lOk := .F.
        ConOut("FAIL: T5 deveria recusar senha fraca")
    EndIf
    If GEBSECLOGIN("T_WTROCA1", cS2, "local") != "OK"
        lOk := .F.
        ConOut("FAIL: T5 senha boa foi alterada pela tentativa fraca")
    EndIf
    If lOk
        ConOut("  OK T5 senha fraca")
    EndIf

    // T6: super (por username) altera terceiros.
    aRes := GEBTUITROCASENHA("super", "T_WTROCA2", cS3, Nil, Nil)
    If !(Len(aRes) >= 2 .And. aRes[1])
        lOk := .F.
        ConOut("FAIL: T6 super deveria alterar terceiro, veio " + cValToChar(aRes[2]))
    EndIf
    If GEBSECLOGIN("T_WTROCA2", cS3, "local") != "OK"
        lOk := .F.
        ConOut("FAIL: T6 senha nova do terceiro nao autentica")
    EndIf
    If lOk
        ConOut("  OK T6 super altera terceiro")
    EndIf

    // T7: nada a alterar.
    aRes := GEBTUITROCASENHA("T_WTROCA1", "T_WTROCA1", "", Nil, Nil)
    If !(Len(aRes) >= 2 .And. !aRes[1] .And. AllTrim(cValToChar(aRes[2])) == "nada_a_alterar")
        lOk := .F.
        ConOut("FAIL: T7 deveria dar nada_a_alterar, veio " + cValToChar(aRes[2]))
    Else
        ConOut("  OK T7 nada a alterar")
    EndIf

    // === CLEANUP ===
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO IN ('T_WTROCA1','T_WTROCA2')")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO IN ('T_WTROCA1','T_WTROCA2')")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD IN ('T_WTROCA1','T_WTROCA2')")

    If lOk
        ConOut("T_GEBTUITROCA PASS")
    Else
        ConOut("T_GEBTUITROCA FAIL")
    EndIf
Return lOk
