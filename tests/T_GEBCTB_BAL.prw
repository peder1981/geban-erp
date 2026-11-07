#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBCTB_BAL.prw"

/*/{Protheus.doc} T_GEBCTB_BAL
    Teste do balancete GEBBAL e da DRE GEBDRE (Task 4 GEB_CONTABIL).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP (registro interno).
    Asserts: GENMIG + GEBCMIG OK; venda 1000 + custo 400 via
    CTBLAN com params GC4; GEBBAL retorna as 3 contas com
    debito/credito exatos; GEBDRE retorna 600 (receita 1000
    menos custo 400); competencia vazia retorna balancete vazio
    e DRE zero; cleanup total (rerun limpo). Log via ConOut.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBCTB_BAL()
    Local lOk := .T.
    Local lTmp := .F.
    Local aBal := {}
    Local nRes := 0
    Local cComp := SubStr(DToS(Date()), 1, 6)
    Local nI := 0
    Local lCx := .F.
    Local lRec := .F.
    Local lCus := .F.

    If !GEBDBConecta()
        ConOut("T_GEBCTB_BAL: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebctb_bal CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebctb_bal")
    TCSqlExec("SET search_path TO test_gebctb_bal")
    GBAUDINIC()

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBCMIG()
        lOk := .F.
    EndIf

    // Params: venda (D caixa / C receita) e custo (D custo / C caixa).
    lTmp := TCSqlExec("INSERT INTO GC4 (D_E_L_E_T_, GC4_FILIAL, GC4_EVENTO, GC4_CTADEB, GC4_CTACRED, GC4_PERM) VALUES (' ', '      ', 'BAL_VENDA', '1.01.001', '3.01.001', 'S')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GC4 (D_E_L_E_T_, GC4_FILIAL, GC4_EVENTO, GC4_CTADEB, GC4_CTACRED, GC4_PERM) VALUES (' ', '      ', 'BAL_CUSTO', '4.01.001', '1.01.001', 'S')")
    If !lTmp
        lOk := .F.
    EndIf

    If !CTBLAN("BAL_VENDA", 1000.00)
        lOk := .F.
    EndIf
    If !CTBLAN("BAL_CUSTO", 400.00)
        lOk := .F.
    EndIf

    // Balancete: 3 contas com debito/credito exatos.
    aBal := GEBBAL(cComp)
    For nI := 1 To Len(aBal)
        If aBal[nI][1] == "1.01.001"
            If aBal[nI][2] == 1000 .AND. aBal[nI][3] == 400
                lCx := .T.
            EndIf
        EndIf
        If aBal[nI][1] == "3.01.001"
            If aBal[nI][2] == 0 .AND. aBal[nI][3] == 1000
                lRec := .T.
            EndIf
        EndIf
        If aBal[nI][1] == "4.01.001"
            If aBal[nI][2] == 400 .AND. aBal[nI][3] == 0
                lCus := .T.
            EndIf
        EndIf
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

    // DRE bananica: receita 1000 menos custo 400 igual a 600.
    nRes := GEBDRE(cComp)
    If nRes != 600
        lOk := .F.
    EndIf

    // Competencia vazia: balancete vazio e DRE zero.
    aBal := GEBBAL("190001")
    If Len(aBal) != 0
        lOk := .F.
    EndIf
    nRes := GEBDRE("190001")
    If nRes != 0
        lOk := .F.
    EndIf

    // Cleanup total (rerun limpo; GC4 vazia = modo compativel).
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

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebctb_bal CASCADE")

    If lOk
        ConOut("T_GEBCTB_BAL PASS")
    Else
        ConOut("T_GEBCTB_BAL FAIL")
    EndIf
Return lOk
