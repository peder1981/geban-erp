#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBEXP_CTX.prw"

/*/{Protheus.doc} T_GEBSECLOGIN_FAILCNT
    Regressao das correcoes de seguranca da revisao final da Fase 2:
    (1) SEC_FAILCNT vem de TCSqlQuery como STRING -- "nFail + 1"
        concatenava ("0"+1 -> "01", "1"+1 -> "11") e a conta bloqueava na
        2a senha errada. Prova: tentativas 1..4 erradas devolvem
        "SENHA_ERR" (nunca bloqueio) com SEC_FAILCNT = 1..4 exatos, a 5a
        devolve "MAX_TENT" e depois disso ate' a senha certa da
        "CONTA_BLOQ".
    (3) SEC_SALT/SEC_HASH vazios (linha corrompida/semeada a mao):
        Argon2id(x, "") devolve "" e "" == "" aceitava QUALQUER senha.
        Prova: nenhuma senha (inclusive "") autentica com salt e/ou hash
        vazio.
    (5a) Validacao de formato DENTRO de GEBSECLOGIN()/GEBEXPCONTEXTO()
        (defesa em profundidade): um cUsuario/cEmpresa com injecao SQL e'
        recusado sem tocar o banco -- antes, o UPDATE de falha de
        GEBSECLOGIN() com "x' OR '1'='1" incrementaria o contador de
        TODOS os usuarios, e GEBEXPCONTEXTO() aceitaria vinculo com
        qualquer empresa.
    Schema descartavel test_gebseclogin_failcnt; usuarios de teste
    T_FAILCNT/T_VAZIO no catalogo (public), limpos no inicio e no fim.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 25/09/2026
    @return .T. se todas as assercoes passarem
/*/
User Function T_GEBSECLOGIN_FAILCNT()
    Local lOk    := .T.
    Local cRes   := ""
    Local cFil   := ""
    Local cHash  := ""
    Local nI     := 0
    Local aRow   := {}
    Local cSchema := "test_gebseclogin_failcnt"

    If !GEBDBConecta()
        ConOut("T_GEBSECLOGIN_FAILCNT: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS " + cSchema + " CASCADE")
    TCSqlExec("CREATE SCHEMA " + cSchema)
    TCSqlExec("SET search_path TO " + cSchema)

    // Catalogo (GE1/GE2/GE2_SEC/GE2_EMP) em public; forca search_path public.
    If !GEBDBProvisionaCatalogo()
        lOk := .F.
        ConOut("FAIL: GEBDBProvisionaCatalogo")
    EndIf

    cFil := FWxFilial("GE2")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO IN ('T_FAILCNT', 'T_VAZIO')")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO IN ('T_FAILCNT', 'T_VAZIO')")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD IN ('T_FAILCNT', 'T_VAZIO')")

    cHash := HashSenha("certa123", "SALTFC01")
    TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '" + cFil + "', 'T_FAILCNT', 'Teste Contador', 'USUARIO')")
    TCSqlExec("INSERT INTO GE2_SEC (D_E_L_E_T_, SEC_FILIAL, SEC_USUARIO, SEC_SALT, SEC_HASH, SEC_FAILCNT, SEC_LOCKED, SEC_LASTLOGIN, SEC_PWDLAST) VALUES (' ', '" + cFil + "', 'T_FAILCNT', 'SALTFC01', '" + cHash + "', 0, '00000000', '00000000', '" + DToS(Date()) + "')")

    // === (1) contador de falhas: 4 erradas nao bloqueiam ===
    If lOk
        For nI := 1 To 4
            cRes := GEBSECLOGIN("T_FAILCNT", "errada" + cValToChar(nI), "local")
            If cRes != "SENHA_ERR"
                lOk := .F.
                ConOut("FAIL: tentativa errada " + cValToChar(nI) + " devolveu " + cRes + " (esperado SENHA_ERR)")
                Exit
            EndIf
            aRow := TCSqlQuery("SELECT SEC_FAILCNT FROM GE2_SEC WHERE SEC_USUARIO = 'T_FAILCNT' AND D_E_L_E_T_ = ' '")
            If Len(aRow) == 0
                lOk := .F.
                ConOut("FAIL: linha GE2_SEC de T_FAILCNT sumiu")
                Exit
            EndIf
            If Val(cValToChar(aRow[1]:SEC_FAILCNT)) != nI
                lOk := .F.
                ConOut("FAIL: SEC_FAILCNT apos " + cValToChar(nI) + " erro(s) = " + cValToChar(aRow[1]:SEC_FAILCNT) + " (esperado " + cValToChar(nI) + ")")
                Exit
            EndIf
            ConOut("OK: tentativa errada " + cValToChar(nI) + " -> SENHA_ERR, SEC_FAILCNT=" + cValToChar(aRow[1]:SEC_FAILCNT))
        Next nI
    EndIf
    If lOk
        cRes := GEBSECLOGIN("T_FAILCNT", "errada5", "local")
        If cRes != "MAX_TENT"
            lOk := .F.
            ConOut("FAIL: 5a tentativa errada devolveu " + cRes + " (esperado MAX_TENT)")
        Else
            ConOut("OK: 5a tentativa errada -> MAX_TENT")
        EndIf
    EndIf
    If lOk
        cRes := GEBSECLOGIN("T_FAILCNT", "certa123", "local")
        If cRes != "CONTA_BLOQ"
            lOk := .F.
            ConOut("FAIL: senha certa apos bloqueio devolveu " + cRes + " (esperado CONTA_BLOQ)")
        Else
            ConOut("OK: senha certa apos bloqueio -> CONTA_BLOQ")
        EndIf
    EndIf

    // Desbloqueia e confirma: 2 erradas + certa = OK, contador zera.
    If lOk
        TCSqlExec("UPDATE GE2_SEC SET SEC_FAILCNT = 0, SEC_LOCKED = '00000000' WHERE SEC_USUARIO = 'T_FAILCNT'")
        GEBSECLOGIN("T_FAILCNT", "x1", "local")
        GEBSECLOGIN("T_FAILCNT", "x2", "local")
        cRes := GEBSECLOGIN("T_FAILCNT", "certa123", "local")
        If cRes != "OK"
            lOk := .F.
            ConOut("FAIL: 2 erradas + certa devolveu " + cRes + " (esperado OK)")
        Else
            aRow := TCSqlQuery("SELECT SEC_FAILCNT FROM GE2_SEC WHERE SEC_USUARIO = 'T_FAILCNT' AND D_E_L_E_T_ = ' '")
            If Len(aRow) == 0
                lOk := .F.
                ConOut("FAIL: linha GE2_SEC de T_FAILCNT sumiu")
            ElseIf Val(cValToChar(aRow[1]:SEC_FAILCNT)) != 0
                lOk := .F.
                ConOut("FAIL: SEC_FAILCNT nao zerou apos login OK")
            Else
                ConOut("OK: 2 erradas + certa -> OK, SEC_FAILCNT zerado")
            EndIf
        EndIf
    EndIf

    // === (5a) injecao no cUsuario de GEBSECLOGIN: recusado sem SQL ===
    If lOk
        cRes := GEBSECLOGIN("x' OR '1'='1", "qualquer", "local")
        If cRes != "USU_INEX"
            lOk := .F.
            ConOut("FAIL: GEBSECLOGIN com injecao no usuario devolveu " + cRes + " (esperado USU_INEX)")
        Else
            aRow := TCSqlQuery("SELECT SEC_FAILCNT FROM GE2_SEC WHERE SEC_USUARIO = 'T_FAILCNT' AND D_E_L_E_T_ = ' '")
            If Len(aRow) == 0
                lOk := .F.
                ConOut("FAIL: linha GE2_SEC de T_FAILCNT sumiu")
            ElseIf Val(cValToChar(aRow[1]:SEC_FAILCNT)) != 0
                lOk := .F.
                ConOut("FAIL: injecao alterou SEC_FAILCNT de outro usuario")
            Else
                ConOut("OK: injecao no usuario -> USU_INEX, nenhum contador alterado")
            EndIf
        EndIf
    EndIf

    // === (3) salt/hash vazios: NENHUMA senha autentica ===
    If lOk
        TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '" + cFil + "', 'T_VAZIO', 'Teste Credencial Vazia', 'ADMIN')")
        TCSqlExec("INSERT INTO GE2_SEC (D_E_L_E_T_, SEC_FILIAL, SEC_USUARIO, SEC_SALT, SEC_HASH, SEC_FAILCNT, SEC_LOCKED, SEC_LASTLOGIN, SEC_PWDLAST) VALUES (' ', '" + cFil + "', 'T_VAZIO', '', '', 0, '00000000', '00000000', '" + DToS(Date()) + "')")
        lOk := VazioRecusa("salt e hash vazios")
    EndIf
    If lOk
        TCSqlExec("UPDATE GE2_SEC SET SEC_SALT = 'SALTNAOVAZIO', SEC_HASH = '', SEC_FAILCNT = 0, SEC_LOCKED = '00000000' WHERE SEC_USUARIO = 'T_VAZIO'")
        lOk := VazioRecusa("so' hash vazio")
    EndIf
    If lOk
        TCSqlExec("UPDATE GE2_SEC SET SEC_SALT = '', SEC_HASH = '" + cHash + "', SEC_FAILCNT = 0, SEC_LOCKED = '00000000' WHERE SEC_USUARIO = 'T_VAZIO'")
        lOk := VazioRecusa("so' salt vazio")
    EndIf

    // === (5a) injecao em GEBEXPCONTEXTO: recusada; controle positivo OK ===
    If lOk
        TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA) VALUES (' ', '" + cFil + "', 'T_FAILCNT', 'zzfcvinc')")
        // GEX/GEH criadas por GEBEXPCONTEXTO ficam no schema descartavel.
        TCSqlExec("SET search_path TO " + cSchema + ", public")
        // GEBEXPCONTEXTO() grava em GEH no caminho de sucesso (controle
        // positivo abaixo); cria GEH/GEX no schema descartavel.
        GEXBINIT()
        If GEBEXPCONTEXTO("zz' OR '1'='1", cFil, "T_FAILCNT")
            lOk := .F.
            ConOut("FAIL: GEBEXPCONTEXTO aceitou empresa com injecao SQL")
        Else
            ConOut("OK: GEBEXPCONTEXTO recusou empresa com injecao")
        EndIf
        If GEBEXPCONTEXTO("zzfcvinc", cFil, "T_FAILCNT' OR '1'='1")
            lOk := .F.
            ConOut("FAIL: GEBEXPCONTEXTO aceitou usuario com injecao SQL")
        Else
            ConOut("OK: GEBEXPCONTEXTO recusou usuario com injecao")
        EndIf
        If GEBEXPCONTEXTO("zzoutra", cFil, "T_FAILCNT")
            lOk := .F.
            ConOut("FAIL: GEBEXPCONTEXTO aceitou empresa sem vinculo GE2_EMP")
        Else
            ConOut("OK: GEBEXPCONTEXTO recusou empresa sem vinculo")
        EndIf
        If !GEBEXPCONTEXTO("zzfcvinc", cFil, "T_FAILCNT")
            lOk := .F.
            ConOut("FAIL: GEBEXPCONTEXTO recusou usuario/empresa validos e vinculados")
        Else
            ConOut("OK: GEBEXPCONTEXTO aceitou usuario/empresa vinculados")
        EndIf
        TCSqlExec("SET search_path TO public")
    EndIf

    // Teardown.
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO IN ('T_FAILCNT', 'T_VAZIO')")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO IN ('T_FAILCNT', 'T_VAZIO')")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD IN ('T_FAILCNT', 'T_VAZIO')")
    TCSqlExec("DROP SCHEMA IF EXISTS " + cSchema + " CASCADE")

    If lOk
        ConOut("T_GEBSECLOGIN_FAILCNT PASS")
    Else
        ConOut("T_GEBSECLOGIN_FAILCNT FAIL")
    EndIf
Return lOk

// Tenta varias senhas (inclusive "" e a senha que gerou o hash valido)
// contra T_VAZIO e exige que NENHUMA devolva "OK".
Static Function VazioRecusa(cCaso)
    Local aSenhas := {"", "qualquer", "certa123", "outra#1"}
    Local nI      := 0
    Local cRes    := ""

    For nI := 1 To Len(aSenhas)
        cRes := GEBSECLOGIN("T_VAZIO", aSenhas[nI], "local")
        If cRes == "OK"
            ConOut("FAIL: credencial com " + cCaso + " aceitou a senha '" + aSenhas[nI] + "'")
            Return .F.
        EndIf
    Next nI
    ConOut("OK: credencial com " + cCaso + " recusou " + cValToChar(Len(aSenhas)) + " senhas")
Return .T.
