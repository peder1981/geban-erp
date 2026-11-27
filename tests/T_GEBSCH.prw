#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/_init.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBDFE_XML.prw"
#include "../src/GEBDFE_CAD.prw"
#include "../src/GEBDFE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBCPX.prw"
#include "../src/GEBCOM_FOR.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBSN.prw"
#include "../src/GEBSCH.prw"

/*/{Protheus.doc} T_GEBSCH
    Agendador (src/GEBSCH.prw): validacao de horario e dia, decisao de execucao (com atraso),
    lista fechada de rotinas, permissao para agendar e persistencia.
    Schema descartavel test_gebsch + emp_tst.
    @type Teste automatizado
    @since 07/11/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBSCH()
    Local lOk    := .T.
    Local lTmp   := .F.
    Local cSenha := "Ab3$qmv9Qw"
    Local aRes   := {}
    Local aHit   := {}

    lTmp := GEBDBConecta()
    If !lTmp
        ConOut("FALHA: GEBDBConecta")
        Return .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebsch CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_tst CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebsch")
    TCSqlExec("SET search_path TO test_gebsch")
    If !TEST_INIT()
        ConOut("TEST_INIT failed")
        Return .F.
    EndIf
    ConOut("=== T_GEBSCH ===")

    // 1. Validacao de horario e dia.
    lOk := Chk(GEBSCHVALIDA("0230", "D"), "horario 0230 diario valido", lOk)
    lOk := Chk(GEBSCHVALIDA("0230", "M28"), "dia do mes M28 valido", lOk)
    lOk := Chk(!GEBSCHVALIDA("2400", "D"), "hora 24 recusada", lOk)
    lOk := Chk(!GEBSCHVALIDA("0260", "D"), "minuto 60 recusado", lOk)
    lOk := Chk(!GEBSCHVALIDA("02a0", "D"), "horario com letra recusado", lOk)
    lOk := Chk(!GEBSCHVALIDA("0230", "M29"), "dia 29 recusado (limite 28)", lOk)
    lOk := Chk(!GEBSCHVALIDA("0230", "X"), "dia invalido recusado", lOk)

    // 2. Decisao de execucao (funcao pura).
    lOk := Chk(GEBSCHDEVE("20261107", "0235", "D", "0230", ""), "diario: devido apos o horario", lOk)
    lOk := Chk(!GEBSCHDEVE("20261107", "0225", "D", "0230", ""), "diario: nao devido antes do horario", lOk)
    lOk := Chk(!GEBSCHDEVE("20261107", "0235", "D", "0230", "20261107"), "ja rodou hoje: nao roda de novo", lOk)
    lOk := Chk(GEBSCHDEVE("20261107", "0235", "D", "0230", "20261106"), "atraso: rodou ontem, roda hoje", lOk)
    lOk := Chk(GEBSCHDEVE("20261107", "0235", "M07", "0230", ""), "mensal dia 07 devido no dia 07", lOk)
    lOk := Chk(!GEBSCHDEVE("20261107", "0235", "M08", "0230", ""), "mensal dia 08 nao devido no dia 07", lOk)

    // 3. Lista fechada.
    lOk := Chk(GEBSCHROTINAOK("DFE_DIST"), "DFE_DIST esta na lista", lOk)
    lOk := Chk(!GEBSCHROTINAOK("DROP_TABLE"), "rotina fora da lista recusada", lOk)

    // 4. Agendar: super cria; alterar nao duplica; rotina invalida e horario invalido recusados.
    TCSqlExec("CREATE SCHEMA emp_tst")
    TCSqlExec("SET search_path TO emp_tst, test_gebsch")
    lOk := Chk(GEBSECCRIAUSU("t_usu", cSenha, {"tst"}, "Usuario", "USUARIO", .F., "01"), "cria t_usu (USUARIO de tst)", lOk)
    aRes := GEBSCHAGENDA("super", "DFE_DIST", "0230", "D", "S")
    lOk := Chk(aRes[1], "super agenda DFE_DIST", lOk)
    aRes := GEBSCHAGENDA("super", "DFE_DIST", "0300", "D", "S")
    aHit := TCSqlQuery("SELECT SCH_HORA FROM SCH_JOB WHERE SCH_ROTINA = 'DFE_DIST' AND D_E_L_E_T_ = ' '")
    lOk := Chk(aRes[1] .And. Len(aHit) == 1 .And. cValToChar(aHit[1]:SCH_HORA) == "0300", "alterar o agendamento nao duplica", lOk)
    aRes := GEBSCHAGENDA("super", "DROP_TABLE", "0230", "D", "S")
    lOk := Chk(!aRes[1], "rotina fora da lista nao e' agendada", lOk)
    aRes := GEBSCHAGENDA("super", "SN_APU", "2500", "D", "S")
    lOk := Chk(!aRes[1], "horario invalido nao e' agendado", lOk)
    aRes := GEBSCHAGENDA("t_usu", "SN_APU", "0230", "M01", "S")
    lOk := Chk(!aRes[1], "usuario comum nao agenda rotina", lOk)

    // 5. Agendamento desligado nao roda (executor sem trabalho devido devolve 0).
    aRes := GEBSCHDESATIVA("t_usu", "DFE_DIST")
    lOk := Chk(!aRes[1], "usuario comum nao desativa agendamento", lOk)
    aRes := GEBSCHDESATIVA("super", "DFE_DIST")
    aHit := TCSqlQuery("SELECT SCH_HORA, SCH_ATIVO FROM SCH_JOB WHERE SCH_ROTINA = 'DFE_DIST' AND D_E_L_E_T_ = ' '")
    lOk := Chk(aRes[1] .And. Len(aHit) == 1 .And. cValToChar(aHit[1]:SCH_ATIVO) == "N" .And. cValToChar(aHit[1]:SCH_HORA) == "0300", "super desativa sem mudar o horario", lOk)
    TCSqlExec("UPDATE SCH_JOB SET SCH_ATIVO = 'N' WHERE D_E_L_E_T_ = ' '")
    lOk := Chk(GEBSCHRODA() == 0, "agendamento inativo nao roda", lOk)
    // Trava por empresa: depois da execucao precisa estar livre (o S/N do SQL e' a parte que falhava).
    aHit := TCSqlQuery("SELECT CASE WHEN pg_try_advisory_lock(hashtext('geban_sch_tst')) THEN 'S' ELSE 'N' END AS L")
    lOk := Chk(AllTrim(cValToChar(aHit[1]:L)) == "S", "trava por empresa liberada apos a execucao", lOk)
    TCSqlQuery("SELECT pg_advisory_unlock(hashtext('geban_sch_tst')) AS U")

    TCSqlExec("SET search_path TO test_gebsch")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_tst CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebsch CASCADE")

    If lOk
        ConOut("T_GEBSCH PASS")
    Else
        ConOut("T_GEBSCH FAIL")
    EndIf
Return lOk

Static Function Chk(lCond, cMsg, lOk)
    If lCond
        ConOut("  OK " + cMsg)
    Else
        ConOut("  FAIL " + cMsg)
    EndIf
Return lCond .And. lOk
