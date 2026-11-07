#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/_init.prw"
#include "../src/GEBMON.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBSEC_LOGIN.prw"

/*/{Protheus.doc} T_GEBSEC_RBA
    Testes do modulo RBAC GEBSEC_RBA (Task 4 GEB_SECURITY).
    Testa: criacao da tabela SEC_PERM, GEBSECRBAC para ADMIN/OPERADOR/MISS,
    GEBSECRBACADD (add/alter), GEBSECRBACLIST (listagem), regressao basica.
    Postgres schema descartavel via GEBDBConecta(), DROP SCHEMA/CREATE SCHEMA/SET search_path.
    Cleanup DELETE em todas as tabelas tocadas (rerun limpo).
    So literais; ConOut PASS/FAIL.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBSEC_RBA()
    Local lOk    := .T.
    Local lTmp   := .F.
    Local lVal   := .F.
    Local aArr   := {}
    Local cStr   := ""
    Local cFil   := ""
    Local nIdx   := 0
    Local oItem  := Nil

    lTmp := GEBDBConecta()
    If !lTmp
        ConOut("FALHA: GEBDBConecta")
        Return .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebsec_rba CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebsec_rba")
    TCSqlExec("SET search_path TO test_gebsec_rba")

    If !TEST_INIT()
        ConOut("TEST_INIT failed")
        TCSqlExec("DROP SCHEMA IF EXISTS test_gebsec_rba CASCADE")
        Return .F.
    EndIf

    ConOut("=== T_GEBSEC_RBA ===")

    // Roda migracoes base.
    lTmp := GENMIG()
    If !lTmp
        lOk := .F.
        ConOut("  FAIL GENMIG")
    Else
        ConOut("  OK GENMIG")
    EndIf
    lTmp := TCSecMIG()
    If !lTmp
        lOk := .F.
        ConOut("  FAIL TCSecMIG")
    Else
        ConOut("  OK TCSecMIG")
    EndIf
    lTmp := TCSecMIG()
    If !lTmp
        lOk := .F.
        ConOut("  FAIL TCSecMIG")
    Else
        ConOut("  OK TCSecMIG")
    EndIf

    // Seed perfis em GE2 (se ainda nao existirem).
    cFil := FWxFilial("GE2")
    TCSqlExec("DELETE FROM GE2 WHERE D_E_L_E_T_ = ' ' AND GE2_COD IN ('ADMIN-RBA','OP-RBA','CAIXA-RBA')")
    TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '" + cFil + "', 'ADMIN-RBA', 'Admin RBAC', 'ADMIN')")
    TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '" + cFil + "', 'OP-RBA', 'Operador RBAC', 'OPERADOR')")
    TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '" + cFil + "', 'CAIXA-RBA', 'Caixa RBAC', 'CAIXA')")
    // Perfil e' por empresa: a regra de acesso exige contexto de empresa (emp_rba) e vinculo.
    TCSqlExec("DROP SCHEMA IF EXISTS emp_rba CASCADE")
    TCSqlExec("CREATE SCHEMA emp_rba")
    TCSqlExec("SET search_path TO emp_rba, test_gebsec_rba")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO IN ('ADMIN-RBA','OP-RBA','CAIXA-RBA')")
    TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA, GE2_EMP_PERFIL) VALUES (' ', '', 'ADMIN-RBA', 'rba', 'ADMIN'), (' ', '', 'OP-RBA', 'rba', 'OPERADOR'), (' ', '', 'CAIXA-RBA', 'rba', 'CAIXA')")

    // Limpa SEC_PERM de teste.
    TCSqlExec("DELETE FROM SEC_PERM WHERE D_E_L_E_T_ = ' ' AND SEC_PERM_PERFIL IN ('ADMIN-RBA','OP-RBA','CAIXA-RBA')")

    // ===== T1: GEBSECRBAC ADMIN = sempre .T. =====
    ConOut("")
    ConOut("  [T1] ADMIN sempre permitido")
    lVal := GEBSECRBAC("ADMIN-RBA", "NUCLEO", "1")
    If !lVal
        lOk := .F.
    EndIf
    lVal := GEBSECRBAC("ADMIN-RBA", "FISCAL", "2")
    If !lVal
        lOk := .F.
    EndIf
    lVal := GEBSECRBAC("ADMIN-RBA", "XPTO", "99")
    If !lVal
        lOk := .F.
    EndIf

    // ===== T2: GEBSECRBAC usuario inexistente =====
    ConOut("")
    ConOut("  [T2] usuario inexistente -> .F.")
    lVal := GEBSECRBAC("NAOEXISTE", "NUCLEO", "1")
    If lVal
        lOk := .F.
    EndIf

    // ===== T3: GEBSECRBAC miss parametrizacao -> OPERADOR sempre .F. =====
    ConOut("")
    ConOut("  [T3] OPERADOR sem permissoes -> .F.")
    lVal := GEBSECRBAC("OP-RBA", "NUCLEO", "1")
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBSECRBAC("OP-RBA", "FISCAL", "1")
    If lVal
        lOk := .F.
    EndIf

    // ===== T4: GEBSECRBACADD + verficacao =====
    ConOut("")
    ConOut("  [T4] GEBSECRBACADD + verificacao")
    lTmp := GEBSECRBACADD("OPERADOR", "NUCLEO", "1", .T.)
    If !lTmp
        lOk := .F.
        ConOut("    FAIL add NUCLEO/1")
    EndIf
    lTmp := GEBSECRBACADD("OPERADOR", "FISCAL", "2", .T.)
    If !lTmp
        lOk := .F.
        ConOut("    FAIL add FISCAL/2")
    EndIf
    lTmp := GEBSECRBACADD("OPERADOR", "FISCAL", "2", .F.)
    If !lTmp
        lOk := .F.
        ConOut("    FAIL alter FISCAL/2 -> .F.")
    EndIf
    // OP agora tem NUCLEO/1=.T. e FISCAL/2=.F.
    lVal := GEBSECRBAC("OP-RBA", "NUCLEO", "1")
    If !lVal
        lOk := .F.
    EndIf
    lVal := GEBSECRBAC("OP-RBA", "FISCAL", "2")
    If lVal
        lOk := .F.
    EndIf
    // Item nao cadastrado permanece .F.
    lVal := GEBSECRBAC("OP-RBA", "FISCAL", "3")
    If lVal
        lOk := .F.
    EndIf

    // ===== T5: GEBSECRBACLIST =====
    ConOut("")
    ConOut("  [T5] GEBSECRBACLIST")
    aArr := GEBSECRBACLIST("OPERADOR")
    If Len(aArr) != 2
        lOk := .F.
        ConOut("    FAIL: esperado 2 permissoes, got " + cValToChar(Len(aArr)))
    Else
        // Verifica presenca de NUCLEO/1 e FISCAL/2.
        If aArr[1][1] != "NUCLEO" .Or. aArr[1][2] != "1" .Or. aArr[1][3] != .T.
            lOk := .F.
            ConOut("    FAIL: permissao NUCLEO/1 incorreta")
        EndIf
        If aArr[2][1] != "FISCAL" .Or. aArr[2][2] != "2" .Or. aArr[2][3] != .F.
            lOk := .F.
            ConOut("    FAIL: permissao FISCAL/2 incorreta")
        EndIf
    EndIf
    // Listagem vazia para perfil inexistente.
    aArr := GEBSECRBACLIST("NAOPERFIL")
    If Len(aArr) != 0
        lOk := .F.
    EndIf
    // Listagem com cPerfil vazio.
    aArr := GEBSECRBACLIST("")
    If Len(aArr) != 0
        lOk := .F.
    EndIf

    // ===== T6: GEBSECRBACADD parametros invalidos =====
    ConOut("")
    ConOut("  [T6] GEBSECRBACADD invalido")
    lTmp := GEBSECRBACADD("", "M", "I", .T.)
    If lTmp
        lOk := .F.
    EndIf
    lTmp := GEBSECRBACADD(Nil, "M", "I", .T.)
    If lTmp
        lOk := .F.
    EndIf

    // ===== T7: CAIXA sem permissoes explicitas = .F. =====
    ConOut("")
    ConOut("  [T7] CAIXA sem SEC_PERM -> .F.")
    lVal := GEBSECRBAC("CAIXA-RBA", "NUCLEO", "1")
    If lVal
        lOk := .F.
    EndIf

    // ===== CLEANUP =====
    TCSqlExec("DELETE FROM SEC_PERM WHERE D_E_L_E_T_ = ' ' AND SEC_PERM_PERFIL IN ('ADMIN-RBA','OP-RBA','CAIXA-RBA')")
    TCSqlExec("DELETE FROM GE2 WHERE D_E_L_E_T_ = ' ' AND GE2_COD IN ('ADMIN-RBA','OP-RBA','CAIXA-RBA')")

    TCSqlExec("DROP SCHEMA IF EXISTS emp_rba CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebsec_rba CASCADE")

    If lOk
        ConOut("")
        ConOut("T_GEBSEC_RBA PASS")
    Else
        ConOut("")
        ConOut("T_GEBSEC_RBA FAIL")
    EndIf
Return lOk
