#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCOM_FOR.prw"
#include "../src/GEBCOM_PED.prw"

/*{Protheus.doc} T_GEBCOM_PED
    Teste pedido de compra + item + trava mentor (Task 3 GEB_COM).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se passar, .F. caso contrario
/*/
User Function T_GEBCOM_PED()
    Local lOk := .T.
    Local cRet := ""

    If !GEBDBConecta()
        ConOut("T_GEBCOM_PED: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebcom_ped CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebcom_ped")
    TCSqlExec("SET search_path TO test_gebcom_ped")
    GBAUDINIC()

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBCMMIG()
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM GCP1 WHERE GCP1_COD LIKE 'F-T3-%'")
    TCSqlExec("DELETE FROM GCP3 WHERE GCP3_NUM LIKE 'PED-T3-%'")
    TCSqlExec("DELETE FROM GCP4 WHERE GCP4_PED LIKE 'PED-T3-%'")

    If !GEBCMFOR("F-T3-01", "Forn T3")
        lOk := .F.
    EndIf

    cRet := GEBCMPED("PED-T3-01", "F-T3-01")
    If !(cRet == "ABERTO")
        lOk := .F.
    EndIf
    cRet := GEBCMPED("PED-T3-01", "F-T3-01")
    If !(cRet == "ABERTO")
        lOk := .F.
    EndIf
    cRet := GEBCMPED("", "F-T3-01")
    If !(cRet == "BLOQUEADO")
        lOk := .F.
    EndIf
    cRet := GEBCMPED("PED-T3-02", "")
    If !(cRet == "BLOQUEADO")
        lOk := .F.
    EndIf

    If !GEBCMIT("PED-T3-01", "P-T3-A", 5, 10)
        lOk := .F.
    EndIf
    If GEBCMIT("PED-T3-01", "P-T3-A", 0, 10)
        lOk := .F.
    EndIf
    If GEBCMIT("PED-T3-99", "P-T3-A", 5, 10)
        lOk := .F.
    EndIf

    TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'COMPRA_IMPULSIVA', 'AVISA_E_TRAVA')")
    cRet := GEBCMPED("PED-T3-99", "F-T3-01")
    If !(cRet == "BLOQUEADO")
        lOk := .F.
    EndIf
    TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'COMPRA_IMPULSIVA'")

    If !TCSqlExec("DELETE FROM GCP4 WHERE GCP4_PED LIKE 'PED-T3-%'")
        lOk := .F.
    EndIf
    If !TCSqlExec("DELETE FROM GCP3 WHERE GCP3_NUM LIKE 'PED-T3-%'")
        lOk := .F.
    EndIf
    If !TCSqlExec("DELETE FROM GCP1 WHERE GCP1_COD LIKE 'F-T3-%'")
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebcom_ped CASCADE")

    If lOk
        ConOut("T_GEBCOM_PED PASS")
    Else
        ConOut("T_GEBCOM_PED FAIL")
    EndIf
Return lOk
