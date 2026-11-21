#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/_init.prw"
#include "../src/GEBMON.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBSEC_LOGIN.prw"

/*/{Protheus.doc} T_GEBSEC_ACESSO_EMP
    Testes da gestao de acessos por empresa (docs/superpowers/specs/2026-11-07-gestao-acessos-design.md).
    Cobre: login independente da filial do GE2; permissao exige vinculo com a empresa;
    linha exata da empresa sobrepoe a linha '*'; ADMIN vale so' na propria empresa;
    super sem vinculo.
    Schema descartavel test_gebsec_acc (catalogo) + emp_tst (tenant, via search_path).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 07/11/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBSEC_ACESSO_EMP()
    Local lOk    := .T.
    Local lTmp   := .F.
    Local cSenha := "Ab3$qmv9Qw"

    lTmp := GEBDBConecta()
    If !lTmp
        ConOut("FALHA: GEBDBConecta")
        Return .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebsec_acc CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_tst CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebsec_acc")
    TCSqlExec("SET search_path TO test_gebsec_acc")

    If !TEST_INIT()
        ConOut("TEST_INIT failed")
        TCSqlExec("DROP SCHEMA IF EXISTS test_gebsec_acc CASCADE")
        Return .F.
    EndIf

    ConOut("=== T_GEBSEC_ACESSO_EMP ===")

    lTmp := GENMIG()
    lOk := lOk .And. lTmp
    lTmp := TCSecMIG()
    lOk := lOk .And. lTmp
    lTmp := TCSecMIG()
    lOk := lOk .And. lTmp
    lOk := Chk(lTmp, "migracao TCSecMIG idempotente") .And. lOk

    // Usuario com credencial e vinculo na empresa tst.
    lTmp := GEBSECCRIAUSU("t_usu", cSenha, {}, "Usuario Teste", "USUARIO", .F., "01")
    lOk := Chk(lTmp, "cria usuario t_usu") .And. lOk
    TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA, GE2_EMP_PERFIL) VALUES (' ', '01', 't_usu', 'tst', 'USUARIO')")

    // 1. Login nao depende da filial: GE2_FILIAL divergente do SEC_FILIAL.
    TCSqlExec("UPDATE GE2 SET GE2_FILIAL = '02' WHERE GE2_COD = 't_usu'")
    lOk := Chk(GEBSECLOGIN("t_usu", cSenha, "test") == "OK", "login com GE2_FILIAL divergente do SEC_FILIAL") .And. lOk
    lOk := Chk(GEBSECLOGIN("t_usu", "errada", "test") == "SENHA_ERR", "senha errada retorna SENHA_ERR") .And. lOk

    // Sessao na empresa tst (tenant = schema emp_tst).
    TCSqlExec("CREATE SCHEMA emp_tst")
    TCSqlExec("SET search_path TO emp_tst, test_gebsec_acc")
    lOk := Chk(GEBDBTenantAtual() == "tst", "tenant atual = tst") .And. lOk

    // 2. Sem permissao explicita, negado (regra padrao).
    lOk := Chk(!GEBSECRBAC("t_usu", "FATURAMENTO", "LIBERA"), "sem permissao: negado") .And. lOk

    // 3. Permissao global ('*') liberando, com vinculo: permitido.
    GEBSECRBACADD("USUARIO", "FATURAMENTO", "LIBERA", .T.)
    lOk := Chk(GEBSECRBAC("t_usu", "FATURAMENTO", "LIBERA"), "permissao '*' com vinculo: permitido") .And. lOk

    // 4. Linha exata da empresa tst negando sobrepoe a linha '*'.
    GEBSECRBACADDEMP("USUARIO", "tst", "FATURAMENTO", "LIBERA", .F.)
    lOk := Chk(!GEBSECRBAC("t_usu", "FATURAMENTO", "LIBERA"), "linha exata tst nega sobre '*'") .And. lOk

    // 5. Sem vinculo com a empresa, negado mesmo com '*' liberando.
    GEBSECRBACADD("USUARIO", "CONTABIL", "DIR", .T.)
    lTmp := GEBSECCRIAUSU("t_sem", cSenha, {}, "Sem Vinculo", "USUARIO", .F., "01")
    lOk := Chk(lTmp, "cria usuario t_sem") .And. lOk
    lOk := Chk(!GEBSECRBAC("t_sem", "CONTABIL", "DIR"), "sem vinculo com a empresa: negado") .And. lOk

    // 6. ADMIN vale so' na propria empresa.
    lTmp := GEBSECCRIAUSU("t_adm", cSenha, {}, "Admin tst", "USUARIO", .F., "01")
    TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA, GE2_EMP_PERFIL) VALUES (' ', '01', 't_adm', 'tst', 'ADMIN')")
    lOk := Chk(GEBSECRBAC("t_adm", "PDV", "01"), "ADMIN da empresa tst: permitido") .And. lOk
    lTmp := GEBSECCRIAUSU("t_adm2", cSenha, {}, "Admin Outra", "USUARIO", .F., "01")
    TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA, GE2_EMP_PERFIL) VALUES (' ', '01', 't_adm2', 'outra', 'ADMIN')")
    lOk := Chk(!GEBSECRBAC("t_adm2", "PDV", "01"), "ADMIN de outra empresa: negado na tst") .And. lOk

    // 7. Super: sempre permitido, mesmo sem vinculo.
    lOk := Chk(GEBSECRBAC("super", "FATURAMENTO", "LIBERA"), "super: permitido sem vinculo") .And. lOk

    TCSqlExec("SET search_path TO test_gebsec_acc")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_tst CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebsec_acc CASCADE")

    If lOk
        ConOut("T_GEBSEC_ACESSO_EMP PASS")
    Else
        ConOut("T_GEBSEC_ACESSO_EMP FAIL")
    EndIf
Return lOk

Static Function Chk(lCond, cMsg)
    If lCond
        ConOut("  OK " + cMsg)
    Else
        ConOut("  FAIL " + cMsg)
    EndIf
Return lCond
