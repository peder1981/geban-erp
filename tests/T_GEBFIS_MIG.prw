#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBFIS_MIG.prw"

User Function T_GEBFIS_MIG()
    Local lOk := .T.
    Local aRes := {}

    If !GEBDBConecta()
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_fis CASCADE")
    TCSqlExec("CREATE SCHEMA IF NOT EXISTS emp_test_fis")
    TCSqlExec("SET search_path TO emp_test_fis")

    If !GEBFMIG()
        lOk := .F.
    EndIf
    If !GEBDBTableExists("GF1") .Or. !GEBDBTableExists("GF2") .Or. ;
       !GEBDBTableExists("GF3") .Or. !GEBDBTableExists("GF4") .Or. ;
       !GEBDBTableExists("GF5") .Or. !GEBDBTableExists("GF6")
        lOk := .F.
    EndIf

    aRes := CALCIBS(1000, 8.5, 0.9)
    If aRes[1] != 85 .Or. aRes[2] != 9
        lOk := .F.
    EndIf

    // ALIQF sem vigencia cadastrada: {0, 0}.
    aRes := ALIQF("12345678", "20260101")
    If aRes[1] != 0 .Or. aRes[2] != 0
        lOk := .F.
    EndIf

    // Cadastra vigencia e confirma que ALIQF encontra.
    TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) " + ;
        "VALUES (' ', '      ', '12345678', 8.5, 0.9, '20260101', '20261231')")
    aRes := ALIQF("12345678", "20260615")
    If aRes[1] != 8.5 .Or. aRes[2] != 0.9
        lOk := .F.
    EndIf
    // Fora da vigencia: {0, 0}.
    aRes := ALIQF("12345678", "20270101")
    If aRes[1] != 0 .Or. aRes[2] != 0
        lOk := .F.
    EndIf

    // Testa isolamento por filial: insere mesma NCM com filial diferente
    // e confirma ALIQF retorna a aliquota da filial correta (nao cross-filial).
    TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) " + ;
        "VALUES (' ', '999999', '12345678', 99.9, 99.9, '20260101', '20261231')")
    aRes := ALIQF("12345678", "20260615")
    If aRes[1] != 8.5 .Or. aRes[2] != 0.9
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_fis CASCADE")

    If lOk
        ConOut("T_GEBFIS_MIG: PASS")
    Else
        ConOut("T_GEBFIS_MIG: FAIL")
    EndIf
Return lOk
