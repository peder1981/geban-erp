#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"

/*/{Protheus.doc} T_GEBFIS_CAD
    Teste dos cadastros fiscais GF1/GF2 (Task 2 GEB_FISCAL).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP (registro interno).
    Asserts: GEBFMIG() retorna .T.; GEBFPRO() hit apos INSERT
    temporario em GF1 (retorna {COD, NCM, DESC} com NCM
    conferido); GEBFPRO() miss retorna array vazio; GEBFALI()
    hit apos INSERT temporario em GF2 (retorna {IBS, CBS}
    conferidos na vigencia); GEBFALI() miss retorna {0, 0};
    linhas temporarias removidas com DELETE ao final (rerun
    limpo). Sem SELECT * e sem concat SQL: so literais em
    TCSqlExec.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBFIS_CAD()
    Local lOk := .T.
    Local lTmp := .F.
    Local aProd := {}
    Local aMiss := {}
    Local aTaxa := {}
    Local aZero := {}

    If !GEBDBConecta()
        ConOut("T_GEBFIS_CAD: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfis_cad CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebfis_cad")
    TCSqlExec("SET search_path TO test_gebfis_cad")
    GBAUDINIC()

    If !GEBFMIG()
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'PROD_T2_RT', 'NCM_T2_RT', 'Produto T2 round-trip')")
    If !lTmp
        lOk := .F.
    EndIf

    aProd := GEBFPRO("PROD_T2_RT")
    If Len(aProd) == 3
        If !(aProd[1] == "PROD_T2_RT")
            lOk := .F.
        EndIf
        If !(aProd[2] == "NCM_T2_RT")
            lOk := .F.
        EndIf
    Else
        lOk := .F.
    EndIf

    aMiss := GEBFPRO("PROD_T2_INEXISTENTE")
    If !(Len(aMiss) == 0)
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'NCM_T2_RT', 7.7, 1.1, '20200101', '20301231')")
    If !lTmp
        lOk := .F.
    EndIf

    aTaxa := GEBFALI("NCM_T2_RT", "20260601")
    If !(aTaxa[1] == 7.7)
        lOk := .F.
    EndIf
    If !(aTaxa[2] == 1.1)
        lOk := .F.
    EndIf

    aZero := GEBFALI("NCM_T2_INEXISTENTE", "20260601")
    If !(aZero[1] == 0)
        lOk := .F.
    EndIf
    If !(aZero[2] == 0)
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GF1 WHERE GF1_COD = 'PROD_T2_RT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF2 WHERE GF2_NCM = 'NCM_T2_RT'")
    If !lTmp
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfis_cad CASCADE")

    If lOk
        ConOut("T_GEBFIS_CAD PASS")
    Else
        ConOut("T_GEBFIS_CAD FAIL")
    EndIf
Return lOk
