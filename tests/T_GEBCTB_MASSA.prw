#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_CAD.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBCTB_DIR.prw"
#include "../src/GEBCTB_BAL.prw"

/*/{Protheus.doc} T_GEBCTB_MASSA
    Teste de massa contabil GEBAN (Task 5 GEB_CONTABIL).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP (ver .superpowers/sdd/task-1-report.md).
    Carga: 200 lancamentos (100 CTBLAN MASSA_VENDA de 10 via GC4
    + 100 GEBCDIR custo de 5 com perfil ADMIN e flag S).
    Asserts: 200 lotes GC2; 200 pernas D e 200 C em GC3;
    balancete com caixa 1000/500, receita 0/1000 e custo 500/0;
    debito total igual a credito total; DRE igual a 500
    (receita 1000 menos custo 500); cleanup total com contagem
    zero (rerun limpo). Log via ConOut.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBCTB_MASSA()
    Local lOk := .T.
    Local lTmp := .F.
    Local aHit := {}
    Local aBal := {}
    Local nRes := 0
    Local cComp := SubStr(DToS(Date()), 1, 6)
    Local nI := 0
    Local nDeb := 0
    Local nCred := 0
    Local lCx := .F.
    Local lRec := .F.
    Local lCus := .F.

    If !GEBDBConecta()
        ConOut("T_GEBCTB_MASSA: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebctb_massa CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebctb_massa")
    TCSqlExec("SET search_path TO test_gebctb_massa")

    GBAUDINIC()

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBCMIG()
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '      ', 'MASSA_CTB', 'MASSA CTB', 'ADMIN')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'PERMITE_DIRETA', 'S')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GC4 (D_E_L_E_T_, GC4_FILIAL, GC4_EVENTO, GC4_CTADEB, GC4_CTACRED, GC4_PERM) VALUES (' ', '      ', 'MASSA_VENDA', '1.01.001', '3.01.001', 'S')")
    If !lTmp
        lOk := .F.
    EndIf

    // Carga 200: pares CTBLAN venda 10, impares GEBCDIR custo 5.
    For nI := 1 To 200
        If nI % 2 == 0
            If !CTBLAN("MASSA_VENDA", 10.00)
                lOk := .F.
            EndIf
        Else
            If !GEBCDIR("4.01.001", "1.01.001", 5.00, "MASSA_CTB")
                lOk := .F.
            EndIf
        EndIf
    Next

    // 200 lotes e 200 pernas de cada lado.
    aHit := TCSqlQuery("SELECT GC2_LOTE FROM GC2 WHERE D_E_L_E_T_ = ' '")
    If Len(aHit) != 200
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GC3_DC FROM GC3 WHERE GC3_DC = 'D' AND D_E_L_E_T_ = ' '")
    If Len(aHit) != 200
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GC3_DC FROM GC3 WHERE GC3_DC = 'C' AND D_E_L_E_T_ = ' '")
    If Len(aHit) != 200
        lOk := .F.
    EndIf

    // Balancete: caixa 1000/500, receita 0/1000, custo 500/0.
    aBal := GEBBAL(cComp)
    For nI := 1 To Len(aBal)
        If aBal[nI][1] == "1.01.001"
            If aBal[nI][2] == 1000 .AND. aBal[nI][3] == 500
                lCx := .T.
            EndIf
        EndIf
        If aBal[nI][1] == "3.01.001"
            If aBal[nI][2] == 0 .AND. aBal[nI][3] == 1000
                lRec := .T.
            EndIf
        EndIf
        If aBal[nI][1] == "4.01.001"
            If aBal[nI][2] == 500 .AND. aBal[nI][3] == 0
                lCus := .T.
            EndIf
        EndIf
        nDeb := nDeb + aBal[nI][2]
        nCred := nCred + aBal[nI][3]
    Next
    If !lCx
        lOk := .F.
    EndIf
    If !lRec
        lOk := .F.
    EndIf
    If !lCus
        lOk := .F.
    EndIf
    If nDeb != nCred
        lOk := .F.
    EndIf

    // DRE: 1000 menos 500 igual a 500.
    nRes := GEBDRE(cComp)
    If nRes != 500
        lOk := .F.
    EndIf

    // Cleanup total (rerun limpo; GC4 vazia = modo compativel).
    lTmp := TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'MASSA_CTB'")
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
    aHit := TCSqlQuery("SELECT GC2_LOTE FROM GC2 WHERE D_E_L_E_T_ = ' '")
    If Len(aHit) != 0
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GC3_LOTE FROM GC3 WHERE D_E_L_E_T_ = ' '")
    If Len(aHit) != 0
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebctb_massa CASCADE")

    If lOk
        ConOut("T_GEBCTB_MASSA PASS")
    Else
        ConOut("T_GEBCTB_MASSA FAIL")
    EndIf
Return lOk
