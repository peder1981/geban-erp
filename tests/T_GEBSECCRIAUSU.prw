#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBEXP_CTX.prw"
#include "../src/GEBEXP_REL_BIZ.prw"
#include "../src/GEBEXP_REL_NUC.prw"

/*/{Protheus.doc} T_GEBSECCRIAUSU
    Prova de ponta a ponta que GEBSECCRIAUSU() provisiona um usuario que
    CONSEGUE fazer login real via GEBAN(): empresa descartavel
    "zzcriausu" provisionada de verdade (schema emp_zzcriausu), usuario
    T_CRIAUSU criado SO' por GEBSECCRIAUSU() (nenhum INSERT manual em
    GE2/GE2_SEC/GE2_EMP), depois GEBAN(empresa, usuario, senha) abre
    sessao (GEBEXPIST() == .T.).
    Tambem cobre: validacao tudo-ou-nada antes de escrever (usuario com
    injecao, senha vazia, empresa com injecao, empresa nao provisionada
    -> .F. e nenhuma linha GE2 criada); salt aleatorio de 32 hex (nao o
    antigo literal fixo); vinculo GE2_EMP gravado em minusculas;
    reexecucao (redefinicao de senha) troca o salt sem duplicar vinculo;
    nome com aspas simples gravado sem quebrar o SQL.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 25/09/2026
    @return .T. se provisionamento + login real forem confirmados
/*/
User Function T_GEBSECCRIAUSU()
    Local lOk    := .T.
    Local lTmp   := .F.
    Local cCod   := "zzcriausu"
    Local cUsu   := "T_CRIAUSU"
    Local cSenha := "Senha#Forte1"
    Local cSalt1 := ""
    Local cSalt2 := ""
    Local aRow   := {}
    Local cSenhaNova := "NovaSenha9$"
    Local cAdmin      := "admin"
    Local cSenhaAdm1  := "AdminSenha1!"
    Local cSenhaAdm2  := "AdminSenha2@"
    Local aRowAdm     := {}

    If !GEBDBConecta()
        ConOut("T_GEBSECCRIAUSU: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")

    // Limpeza de execucao anterior (idempotencia).
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod + " CASCADE")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cAdmin + "'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = '" + cAdmin + "'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = '" + cAdmin + "'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod + "'")

    If !GEBDBProvisionaCatalogo()
        lOk := .F.
        ConOut("FAIL: GEBDBProvisionaCatalogo")
    EndIf
    If lOk
        If !GEBDBProvisionaEmpresa(cCod, "Empresa Teste CriaUsu")
            lOk := .F.
            ConOut("FAIL: GEBDBProvisionaEmpresa(" + cCod + ")")
        EndIf
    EndIf
    TCSqlExec("SET search_path TO public")

    // === Negativos: validacao antes de qualquer escrita ===
    If lOk
        If GEBSECCRIAUSU("x' OR '1'='1", cSenha, {cCod})
            lOk := .F.
            ConOut("FAIL: aceitou usuario com injecao SQL")
        EndIf
        If GEBSECCRIAUSU(cUsu, "", {cCod})
            lOk := .F.
            ConOut("FAIL: aceitou senha vazia")
        EndIf
        If GEBSECCRIAUSU(cUsu, "   ", {cCod})
            lOk := .F.
            ConOut("FAIL: aceitou senha so' de espacos")
        EndIf
        If GEBSECCRIAUSU(cUsu, "Ab1!", {cCod})
            lOk := .F.
            ConOut("FAIL: aceitou senha que reprova a politica GEBSEC_POL (curta demais)")
        EndIf
        If GEBSECCRIAUSU(cUsu, cSenha, {cCod, "zz' OR '1'='1"})
            lOk := .F.
            ConOut("FAIL: aceitou empresa com injecao SQL")
        EndIf
        If GEBSECCRIAUSU(cUsu, cSenha, {"zznaoexiste"})
            lOk := .F.
            ConOut("FAIL: aceitou empresa nao provisionada")
        EndIf
        If Len(TCSqlQuery("SELECT GE2_COD FROM GE2 WHERE GE2_COD = '" + cUsu + "'")) > 0
            lOk := .F.
            ConOut("FAIL: chamada rejeitada deixou linha em GE2")
        EndIf
        If lOk
            ConOut("OK: 6 chamadas invalidas rejeitadas sem escrever nada")
        EndIf
    EndIf

    // === Positivo: cria usuario (empresa em maiusculas, nome com aspas) ===
    If lOk
        If !GEBSECCRIAUSU(cUsu, cSenha, {Upper(cCod)}, "Usuario O'Teste")
            lOk := .F.
            ConOut("FAIL: GEBSECCRIAUSU retornou .F. para entrada valida")
        EndIf
    EndIf
    If lOk
        aRow := TCSqlQuery("SELECT SEC_SALT, SEC_FAILCNT, SEC_LOCKED FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "' AND D_E_L_E_T_ = ' '")
        If Len(aRow) != 1
            lOk := .F.
            ConOut("FAIL: esperado 1 linha GE2_SEC, veio " + cValToChar(Len(aRow)))
        Else
            cSalt1 := AllTrim(cValToChar(aRow[1]:SEC_SALT))
            If Len(cSalt1) != 32
                lOk := .F.
                ConOut("FAIL: salt com tamanho " + cValToChar(Len(cSalt1)) + " (esperado 32)")
            EndIf
            If Val(cValToChar(aRow[1]:SEC_FAILCNT)) != 0
                lOk := .F.
                ConOut("FAIL: SEC_FAILCNT inicial diferente de 0")
            EndIf
        EndIf
        If Len(TCSqlQuery("SELECT GE2_NOME FROM GE2 WHERE GE2_COD = '" + cUsu + "' AND GE2_NOME = 'Usuario O''Teste'")) != 1
            lOk := .F.
            ConOut("FAIL: GE2 nao gravou o nome com aspas corretamente")
        EndIf
        If Len(TCSqlQuery("SELECT GE2_EMP_EMPRESA FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "' AND GE2_EMP_EMPRESA = '" + cCod + "' AND D_E_L_E_T_ = ' '")) != 1
            lOk := .F.
            ConOut("FAIL: vinculo GE2_EMP ausente/duplicado")
        EndIf
        If lOk
            ConOut("OK: usuario criado, salt aleatorio de 32 hex, vinculo GE2_EMP gravado")
        EndIf
    EndIf

    // === Reexecucao: redefine senha (novo salt), nao duplica vinculo ===
    If lOk
        If !GEBSECCRIAUSU(cUsu, cSenha, {cCod})
            lOk := .F.
            ConOut("FAIL: reexecucao de GEBSECCRIAUSU retornou .F.")
        EndIf
    EndIf
    If lOk
        aRow := TCSqlQuery("SELECT SEC_SALT FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "' AND D_E_L_E_T_ = ' '")
        If Len(aRow) != 1
            lOk := .F.
            ConOut("FAIL: reexecucao deixou " + cValToChar(Len(aRow)) + " linhas GE2_SEC")
        Else
            cSalt2 := AllTrim(cValToChar(aRow[1]:SEC_SALT))
            If cSalt2 == cSalt1
                lOk := .F.
                ConOut("FAIL: reexecucao nao trocou o salt")
            EndIf
        EndIf
        If Len(TCSqlQuery("SELECT GE2_EMP_EMPRESA FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "' AND D_E_L_E_T_ = ' '")) != 1
            lOk := .F.
            ConOut("FAIL: reexecucao duplicou vinculo GE2_EMP")
        EndIf
        If Len(TCSqlQuery("SELECT GE2_COD FROM GE2 WHERE GE2_COD = '" + cUsu + "' AND D_E_L_E_T_ = ' '")) != 1
            lOk := .F.
            ConOut("FAIL: reexecucao duplicou linha GE2")
        EndIf
        If lOk
            ConOut("OK: reexecucao trocou salt sem duplicar GE2/GE2_SEC/GE2_EMP")
        EndIf
    EndIf

    // === Reset/desbloqueio de conta travada continua funcionando ===
    // Trava a conta manualmente (SEC_FAILCNT alto, SEC_LOCKED no futuro)
    // e chama GEBSECCRIAUSU() de novo com senha nova: deve desbloquear
    // e permitir login com a senha nova.
    If lOk
        If !TCSqlExec("UPDATE GE2_SEC SET SEC_FAILCNT = 99, SEC_LOCKED = '20991231' WHERE SEC_USUARIO = '" + cUsu + "' AND D_E_L_E_T_ = ' '")
            lOk := .F.
            ConOut("FAIL: nao consegui travar a conta manualmente para o teste de reset")
        EndIf
    EndIf
    If lOk
        If !GEBSECCRIAUSU(cUsu, cSenhaNova, {cCod})
            lOk := .F.
            ConOut("FAIL: GEBSECCRIAUSU retornou .F. ao redefinir conta travada")
        EndIf
    EndIf
    If lOk
        aRow := TCSqlQuery("SELECT SEC_FAILCNT, SEC_LOCKED FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "' AND D_E_L_E_T_ = ' '")
        If Len(aRow) != 1
            lOk := .F.
            ConOut("FAIL: esperado 1 linha GE2_SEC apos reset, veio " + cValToChar(Len(aRow)))
        Else
            If Val(cValToChar(aRow[1]:SEC_FAILCNT)) != 0
                lOk := .F.
                ConOut("FAIL: SEC_FAILCNT nao foi zerado no reset")
            EndIf
            If AllTrim(cValToChar(aRow[1]:SEC_LOCKED)) != "00000000"
                lOk := .F.
                ConOut("FAIL: SEC_LOCKED nao foi limpo no reset (" + AllTrim(cValToChar(aRow[1]:SEC_LOCKED)) + ")")
            EndIf
        EndIf
        If GEBSECLOGIN(cUsu, cSenhaNova, "local") != "OK"
            lOk := .F.
            ConOut("FAIL: login com a senha nova apos reset nao retornou OK")
        EndIf
        If lOk
            ConOut("OK: reset de conta travada desbloqueou (SEC_FAILCNT=0, SEC_LOCKED=00000000) e login com senha nova funciona")
        EndIf
    EndIf
    // A partir daqui a senha valida do usuario e' cSenhaNova (a senha
    // original cSenha foi substituida pelo reset acima).
    If lOk
        cSenha := cSenhaNova
    EndIf

    // === Senha errada nao autentica o usuario provisionado ===
    If lOk
        If GEBSECLOGIN(cUsu, "senhaErrada", "local") != "SENHA_ERR"
            lOk := .F.
            ConOut("FAIL: senha errada nao devolveu SENHA_ERR")
        EndIf
    EndIf

    // === Login REAL pelo mesmo caminho do GEBTUI (GEBSECLOGIN -> tenant -> contexto) ===
    If lOk
        If GEBSECLOGIN(cUsu, cSenha, "tui") != "OK"
            lOk := .F.
            ConOut("FAIL: GEBSECLOGIN(" + cUsu + ",<senha>) nao autenticou o usuario provisionado")
        EndIf
    EndIf
    If lOk
        If !GEBDBSetTenant(cCod) .Or. !GEBEXPCONTEXTO(cCod, Space(6), cUsu)
            lOk := .F.
            ConOut("FAIL: tenant/contexto nao abriu para " + cCod)
        EndIf
    EndIf
    If lOk
        If !GEBEXPIST()
            lOk := .F.
            ConOut("FAIL: GEBEXPIST() .F. apos login -- sessao real nao ocorreu")
        Else
            ConOut("OK: login real abriu sessao para o usuario provisionado por GEBSECCRIAUSU()")
        EndIf
    EndIf

        // === Guarda super: GEBSECISSUPER puro + recusa sem tocar o super real.
    // "super" e' conta global unica no catalogo compartilhado: este teste
    // NUNCA cria nem altera "super" (faria reset na credencial real).
    // O caminho COM flag fica para verificacao manual do operador.
    If GEBSECISSUPER("super")
        ConOut("OK: GEBSECISSUPER(super)")
    Else
        lOk := .F.
        ConOut("FAIL: GEBSECISSUPER(super) devia ser .T.")
    EndIf
    If GEBSECISSUPER("SUPER")
        ConOut("OK: GEBSECISSUPER(SUPER)")
    Else
        lOk := .F.
        ConOut("FAIL: GEBSECISSUPER(SUPER) devia ser .T.")
    EndIf
    If !GEBSECISSUPER("admin")
        ConOut("OK: GEBSECISSUPER(admin) e .F.")
    Else
        lOk := .F.
        ConOut("FAIL: GEBSECISSUPER(admin) devia ser .F.")
    EndIf
    If !GEBSECISSUPER("")
        ConOut("OK: GEBSECISSUPER(vazio) e .F.")
    Else
        lOk := .F.
        ConOut("FAIL: GEBSECISSUPER(vazio) devia ser .F.")
    EndIf
    If !GEBSECISSUPER(Nil)
        ConOut("OK: GEBSECISSUPER(Nil) e .F.")
    Else
        lOk := .F.
        ConOut("FAIL: GEBSECISSUPER(Nil) devia ser .F.")
    EndIf
    // Recusa criar "super" sem flag: retorna .F. ANTES de qualquer escrita
    // e nao altera a credencial real (compara hash antes/depois).
    If lOk
        aRowAdm := TCSqlQuery("SELECT SEC_SALT, SEC_HASH FROM GE2_SEC WHERE SEC_USUARIO = 'super' AND D_E_L_E_T_ = ' '")
        If GEBSECCRIAUSU("super", "Senha#Forte9", {cCod}, "X", "ADMIN")
            lOk := .F.
            ConOut("FAIL: GEBSECCRIAUSU(super,...) sem flag retornou .T. (deveria bloquear)")
        EndIf
    EndIf
    If lOk
        aRow := TCSqlQuery("SELECT SEC_SALT, SEC_HASH FROM GE2_SEC WHERE SEC_USUARIO = 'super' AND D_E_L_E_T_ = ' '")
        If Len(aRow) != Len(aRowAdm)
            lOk := .F.
            ConOut("FAIL: bloqueio do super alterou linhas em GE2_SEC")
        Else
            If Len(aRow) > 0
                If AllTrim(cValToChar(aRow[1]:SEC_HASH)) != AllTrim(cValToChar(aRowAdm[1]:SEC_HASH)) .Or. AllTrim(cValToChar(aRow[1]:SEC_SALT)) != AllTrim(cValToChar(aRowAdm[1]:SEC_SALT))
                    lOk := .F.
                    ConOut("FAIL: bloqueio do super alterou salt/hash reais")
                EndIf
            EndIf
        EndIf
        If lOk
            ConOut("OK: recusa do super sem flag nao tocou a credencial real")
        EndIf
    EndIf

// === CLEANUP ===
    If lOk
        GEBEXPCLEAR()
    EndIf
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cAdmin + "'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = '" + cAdmin + "'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = '" + cAdmin + "'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod + "'")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod + " CASCADE")

    If lOk
        ConOut("T_GEBSECCRIAUSU PASS")
    Else
        ConOut("T_GEBSECCRIAUSU FAIL")
    EndIf
Return lOk
