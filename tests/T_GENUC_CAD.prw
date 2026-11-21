#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_CAD.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"

/*/{Protheus.doc} T_GENUC_CAD
    Teste de Empresas GE1 + Usuarios GE2 + Auditoria GE3 (Task 3 GEB_NUCLEO).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP (ver .superpowers/sdd/task-1-report.md).
    Asserts: GENMIG() OK; GEBAUD() retorna .T.; round-trip hit
    via TCSqlQuery em GE3 (linha temporaria removida com DELETE
    ao final, rerun limpo); GEBUSR() miss retorna .F.
    Log via ConOut (FWLogMsg nao existe no runtime).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GENUC_CAD()
    Local lOk := .T.
    Local lTmp := .F.
    Local aHit := {}
    Local cEvt := "ASSUMIU_BO_TESTE"

    If !GEBDBConecta()
        ConOut("T_GENUC_CAD: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_genuc_cad CASCADE")
    TCSqlExec("CREATE SCHEMA test_genuc_cad")
    TCSqlExec("SET search_path TO test_genuc_cad")

    If !GENMIG()
        lOk := .F.
    EndIf

    lTmp := GEBAUD("ZE", cEvt, "teste mentor")
    If !lTmp
        lOk := .F.
    EndIf

    // Round-trip: GEBAUD gravou linha em GE3 com filial da sessao
    // (6 espacos sem RpcSetEnv) + D_E_L_E_T_ = ' '. Usa TCSqlQuery
    // com literais (padrao Task 1), sem concat e sem SELECT *.
    aHit := TCSqlQuery("SELECT GE3_COD FROM GE3 WHERE GE3_EVENT = 'ASSUMIU_BO_TESTE' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE3 WHERE GE3_EVENT = 'ASSUMIU_BO_TESTE'")
    If !lTmp
        lOk := .F.
    EndIf

    // GEBUSR: usuario inexistente nao autoriza (miss -> .F.).
    If GEBUSR("ZE_INEXISTENTE_T3")
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_genuc_cad CASCADE")

    If lOk
        ConOut("T_GENUC_CAD PASS")
    Else
        ConOut("T_GENUC_CAD FAIL")
    EndIf
Return lOk
