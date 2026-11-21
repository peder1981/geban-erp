#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_CAD.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBCTB_DIR.prw"

/*/{Protheus.doc} T_GEBCTB_DIR
    Teste do lancamento direto GEBCDIR (Task 3 GEB_CONTABIL).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP (ver .superpowers/sdd/task-1-report.md).
    Asserts: GENMIG + GEBCMIG OK; GEBCDIR com flag S + perfil
    ADMIN grava GC2 carimbado DIRETO + 2xGC3 balanceado;
    perfil CAIXA tambem autoriza com flag S; sem usuario nega;
    flag N nega; usuario desconhecido nega; mentor LANC_DIRETO
    travando nega; GC4 LANC_DIRETO com PERM N nega; valor
    zerado nega; cleanup total (rerun limpo). Log via ConOut.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBCTB_DIR()
    Local lOk := .T.
    Local lTmp := .F.
    Local aHit := {}

    If !GEBDBConecta()
        ConOut("T_GEBCTB_DIR: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebctb_dir CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebctb_dir")
    TCSqlExec("SET search_path TO test_gebctb_dir")
    GBAUDINIC()

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBCMIG()
        lOk := .F.
    EndIf

    // Seeds: usuarios ADMIN + CAIXA e flag PERMITE_DIRETA = S.
    lTmp := TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '      ', 'DIR_T3', 'DIRETO T3', 'ADMIN')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '      ', 'DIR_T3C', 'DIRETO T3C', 'CAIXA')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'PERMITE_DIRETA', 'S')")
    If !lTmp
        lOk := .F.
    EndIf

    // Positivo ADMIN: carimbo DIRETO + partidas balanceadas.
    If !GEBCDIR("1.01.001", "3.01.001", 500.00, "DIR_T3")
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GC2_TIPO FROM GC2 WHERE GC2_TIPO = 'DIRETO' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GC2_TIPO FROM GC2 WHERE GC2_TIPO = 'AUTO' AND D_E_L_E_T_ = ' '")
    If Len(aHit) != 0
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GC3_DC FROM GC3 WHERE GC3_DC = 'D' AND GC3_CONTA = '1.01.001' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GC3_DC FROM GC3 WHERE GC3_DC = 'C' AND GC3_CONTA = '3.01.001' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf

    // Positivo CAIXA com flag S.
    If !GEBCDIR("1.01.001", "3.01.001", 50.00, "DIR_T3C")
        lOk := .F.
    EndIf

    // Sem usuario nega.
    If GEBCDIR("1.01.001", "3.01.001", 10.00)
        lOk := .F.
    EndIf

    // Usuario desconhecido nega.
    If GEBCDIR("1.01.001", "3.01.001", 10.00, "DIR_NAOEXISTE")
        lOk := .F.
    EndIf

    // Valor zerado nega.
    If GEBCDIR("1.01.001", "3.01.001", 0, "DIR_T3")
        lOk := .F.
    EndIf

    // Flag N nega (troca S por N e restaura).
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'PERMITE_DIRETA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'PERMITE_DIRETA', 'N')")
    If !lTmp
        lOk := .F.
    EndIf
    If GEBCDIR("1.01.001", "3.01.001", 10.00, "DIR_T3")
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'PERMITE_DIRETA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'PERMITE_DIRETA', 'S')")
    If !lTmp
        lOk := .F.
    EndIf

    // Mentor travando LANC_DIRETO nega.
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'LANC_DIRETO', 'AVISA_E_TRAVA')")
    If !lTmp
        lOk := .F.
    EndIf
    If GEBCDIR("1.01.001", "3.01.001", 10.00, "DIR_T3")
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'LANC_DIRETO'")
    If !lTmp
        lOk := .F.
    EndIf

    // GC4 LANC_DIRETO com PERM N nega.
    lTmp := TCSqlExec("INSERT INTO GC4 (D_E_L_E_T_, GC4_FILIAL, GC4_EVENTO, GC4_CTADEB, GC4_CTACRED, GC4_PERM) VALUES (' ', '      ', 'LANC_DIRETO', '1.01.001', '3.01.001', 'N')")
    If !lTmp
        lOk := .F.
    EndIf
    If GEBCDIR("1.01.001", "3.01.001", 10.00, "DIR_T3")
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GC4 WHERE GC4_EVENTO = 'LANC_DIRETO'")
    If !lTmp
        lOk := .F.
    EndIf

    // Cleanup total (rerun limpo; GC4 vazia = modo compativel).
    lTmp := TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'DIR_T3'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'DIR_T3C'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'PERMITE_DIRETA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GC3")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GC2")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GC4")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GC1")
    If !lTmp
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebctb_dir CASCADE")

    If lOk
        ConOut("T_GEBCTB_DIR PASS")
    Else
        ConOut("T_GEBCTB_DIR FAIL")
    EndIf
Return lOk
