#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/_init.prw"
#include "../src/GEBMON.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBSEC_POL.prw"

/*/{Protheus.doc} T_GEBSEC_POL
    Testes do modulo politica de senha GEBSEC_POL (Task 4 GEB_SECURITY).
    Testa: GEBSECPOL_VERIFICA (validas/invalidas), GEBSECPOL_EXPIRACAO
    (calcula data), GEBSECPOL_FORCA (flag GE4), GEBSECFORCAR (marca redefinicao),
    regressao basica. Postgres schema descartavel via GEBDBConecta(),
    DROP SCHEMA/CREATE SCHEMA/SET search_path. Cleanup DELETE em tabelas tocadas (rerun limpo).
    So literais; ConOut PASS/FAIL.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBSEC_POL()
    Local lOk     := .T.
    Local lTmp    := .F.
    Local aRet    := {}
    Local cMsg    := ""
    Local lVal    := .F.
    Local cFil    := ""
    Local dExp    := Date()
    Local cData   := ""
    Local aCfgs   := {}
    Local nIdx    := 0
    Local cCfg    := ""

    lTmp := GEBDBConecta()
    If !lTmp
        ConOut("FALHA: GEBDBConecta")
        Return .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebsec_pol CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebsec_pol")
    TCSqlExec("SET search_path TO test_gebsec_pol")

    If !TEST_INIT()
        ConOut("TEST_INIT failed")
        TCSqlExec("DROP SCHEMA IF EXISTS test_gebsec_pol CASCADE")
        Return .F.
    EndIf

    ConOut("=== T_GEBSEC_POL ===")

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

    // Configura SEG_FORCA=S e SEG_VIGENCIA=90 em GE4.
    cFil := FWxFilial("GE4")
    TCSqlExec("DELETE FROM GE4 WHERE D_E_L_E_T_ = ' ' AND GE4_EVENTO IN ('SEG_FORCA','SEG_VIGENCIA')")
    TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '" + cFil + "', 'SEG_FORCA', 'S')")
    TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '" + cFil + "', 'SEG_VIGENCIA', '90')")

    // Insere usuario de teste em GE2_SEC.
    TCSqlExec("DELETE FROM GE2_SEC WHERE D_E_L_E_T_ = ' ' AND SEC_USUARIO = 'POLUSER'")
    TCSqlExec("INSERT INTO GE2_SEC (D_E_L_E_T_, SEC_FILIAL, SEC_USUARIO, SEC_SALT, SEC_HASH, SEC_FAILCNT, SEC_LOCKED, SEC_LASTLOGIN, SEC_PWDLAST) VALUES (' ', '" + cFil + "', 'POLUSER', 'SALT1', 'HASH1', 0, '00000000', '00000000', '20260601')")

    // ===== T1: GEBSECPOL_VERIFICA -- senhas validas =====
    ConOut("")
    ConOut("  [T1] senhas validas")
    aRet := GEBSECPOL_VERIFICA("Xk9#mP2!")
    If Len(aRet) != 2 .Or. aRet[1] != .T.
        lOk := .F.
        ConOut("    FAIL: Abcdefg1!")
    EndIf
    aRet := GEBSECPOL_VERIFICA("Bn5!Km2#")
    If Len(aRet) != 2 .Or. aRet[1] != .T.
        lOk := .F.
        ConOut("    FAIL: Senha1!abc")
    EndIf

    // ===== T2: GEBSECPOL_VERIFICA -- curta demais =====
    ConOut("")
    ConOut("  [T2] senha curta (< 8)")
    aRet := GEBSECPOL_VERIFICA("Abc1!")
    If Len(aRet) != 2 .Or. aRet[1] != .F.
        lOk := .F.
        ConOut("    FAIL: Abc1!")
    EndIf
    If aRet[2] == ""
        lOk := .F.
    EndIf

    // ===== T3: GEBSECPOL_VERIFICA -- sem maiuscula =====
    ConOut("")
    ConOut("  [T3] sem maiuscula")
    aRet := GEBSECPOL_VERIFICA("m!n@p#q$1")
    If Len(aRet) != 2 .Or. aRet[1] != .F.
        lOk := .F.
        ConOut("    FAIL: abcdefgh1!")
    EndIf

    // ===== T4: GEBSECPOL_VERIFICA -- sem minuscula =====
    ConOut("")
    ConOut("  [T4] sem minuscula")
    aRet := GEBSECPOL_VERIFICA("M!N@P#Q$1")
    If Len(aRet) != 2 .Or. aRet[1] != .F.
        lOk := .F.
        ConOut("    FAIL: ABCDEFGH1!")
    EndIf

    // ===== T5: GEBSECPOL_VERIFICA -- sem digito =====
    ConOut("")
    ConOut("  [T5] sem digito")
    aRet := GEBSECPOL_VERIFICA("XyZ!@#mN")
    If Len(aRet) != 2 .Or. aRet[1] != .F.
        lOk := .F.
        ConOut("    FAIL: Abcdefgh!")
    EndIf

    // ===== T6: GEBSECPOL_VERIFICA -- sem especial =====
    ConOut("")
    ConOut("  [T6] sem especial")
    aRet := GEBSECPOL_VERIFICA("XyZ9aBc2")
    If Len(aRet) != 2 .Or. aRet[1] != .F.
        lOk := .F.
        ConOut("    FAIL: Abcdefg1")
    EndIf

    // ===== T7: GEBSECPOL_VERIFICA -- sequencia proibida abc =====
    ConOut("")
    ConOut("  [T7] sequencia abc")
    aRet := GEBSECPOL_VERIFICA("XabcYz1!")
    If Len(aRet) != 2 .Or. aRet[1] != .F.
        lOk := .F.
        ConOut("    FAIL: XabcYz1!")
    EndIf

    // ===== T8: GEBSECPOL_VERIFICA -- sequencia 123 =====
    ConOut("")
    ConOut("  [T8] sequencia 123")
    aRet := GEBSECPOL_VERIFICA("X123Yz!a")
    If Len(aRet) != 2 .Or. aRet[1] != .F.
        lOk := .F.
        ConOut("    FAIL: X123Yz!a")
    EndIf

    // ===== T9: GEBSECPOL_VERIFICA -- repeticao 3x =====
    ConOut("")
    ConOut("  [T9] repeticao 3x")
    aRet := GEBSECPOL_VERIFICA("aaaBC1!@")
    If Len(aRet) != 2 .Or. aRet[1] != .F.
        lOk := .F.
        ConOut("    FAIL: aaaBC1!@")
    EndIf

    // ===== T10: GEBSECPOL_VERIFICA -- parametro nil/vazio =====
    ConOut("")
    ConOut("  [T10] param nil/vazio")
    aRet := GEBSECPOL_VERIFICA(Nil)
    If Len(aRet) != 2 .Or. aRet[1] != .F.
        lOk := .F.
    EndIf
    aRet := GEBSECPOL_VERIFICA("")
    If Len(aRet) != 2 .Or. aRet[1] != .F.
        lOk := .F.
    EndIf

    // ===== T11: GEBSECPOL_EXPIRACAO =====
    ConOut("")
    ConOut("  [T11] GEBSECPOL_EXPIRACAO")
    cData := GEBSECPOL_EXPIRACAO("POLUSER")
    // 20260601 + 90 dias = 20260830
    ConOut("    expira=" + cData)
    If cData != "20260830"
        lOk := .F.
    EndIf
    // Usuario inexistente -> usa hoje como referencia
    cData := GEBSECPOL_EXPIRACAO("NAOEXISTE")
    If cData == "00000000"
        lOk := .F.
    EndIf
    // Param nil -> usa hoje como referencia
    cData := GEBSECPOL_EXPIRACAO(Nil)
    If cData == "00000000"
        lOk := .F.
    EndIf
    // ===== T12: GEBSECPOL_FORCA =====
    ConOut("")
    ConOut("  [T12] GEBSECPOL_FORCA")
    lVal := GEBSECPOL_FORCA(5)
    If !lVal
        lOk := .F.
    EndIf
    // Desliga politica.
    TCSqlExec("DELETE FROM GE4 WHERE D_E_L_E_T_ = ' ' AND GE4_EVENTO = 'SEG_FORCA'")
    lVal := GEBSECPOL_FORCA(5)
    If lVal
        lOk := .F.
    EndIf
    // Reativa.
    TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '" + cFil + "', 'SEG_FORCA', 'S')")

    // ===== T13: GEBSECFORCAR =====
    ConOut("")
    ConOut("  [T13] GEBSECFORCAR")
    lVal := GEBSECFORCAR("POLUSER")
    If !lVal
        lOk := .F.
    Else
        ConOut("    PASS: forca ativada")
    EndIf
    // Verifica que SEC_PWDLAST foi zerado (workarea, pois TCSqlQuery nao retorna valores).
    Local lPwdZerado := .F.
    DbSelectArea("GE2_SEC")
    DbGoTop()
    While !Eof()
        If GE2_SEC->SEC_USUARIO == "POLUSER" .And. GE2_SEC->D_E_L_E_T_ == " " .And. GE2_SEC->SEC_PWDLAST == "00000000"
            lPwdZerado := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !lPwdZerado
        lOk := .F.
        ConOut("    FAIL: SEC_PWDLAST nao zerado")
    Else
        ConOut("    PASS: SEC_PWDLAST zerado")
    EndIf
    // forca desabilitada.
    TCSqlExec("DELETE FROM GE4 WHERE D_E_L_E_T_ = ' ' AND GE4_EVENTO = 'SEG_FORCA'")
    lVal := GEBSECFORCAR("POLUSER")
    If lVal
        lOk := .F.
    EndIf
    // Reativa.
    TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '" + cFil + "', 'SEG_FORCA', 'S')")
    // Usuario inexistente.
    lVal := GEBSECFORCAR("NAOEXISTE")
    If lVal
        lOk := .F.
    EndIf
    // Param nil.
    lVal := GEBSECFORCAR(Nil)
    If lVal
        lOk := .F.
    EndIf

    // ===== CLEANUP =====
    TCSqlExec("DELETE FROM GE2_SEC WHERE D_E_L_E_T_ = ' ' AND SEC_USUARIO = 'POLUSER'")
    TCSqlExec("DELETE FROM GE4 WHERE D_E_L_E_T_ = ' ' AND GE4_EVENTO IN ('SEG_FORCA','SEG_VIGENCIA')")

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebsec_pol CASCADE")

    If lOk
        ConOut("")
        ConOut("T_GEBSEC_POL PASS")
    Else
        ConOut("")
        ConOut("T_GEBSEC_POL FAIL")
    EndIf
Return lOk
