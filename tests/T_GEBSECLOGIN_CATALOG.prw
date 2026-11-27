#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBSEC_LOGIN.prw"

/*/{Protheus.doc} T_GEBSECLOGIN_CATALOG
    Prova que GEBSECLOGIN() nao quebra mais quando chamado em nivel de
    catalogo (nenhum tenant selecionado, GEH ainda nao existe). Schema
    descartavel test_gebseclogin_catalog.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 2026-09-24
    @return .T. se login OK sem crash, .F. caso contrario
/*/
User Function T_GEBSECLOGIN_CATALOG()
    Local lOk := .T.
    Local cRes := ""
    Local cFil := ""

    If !GEBDBConecta()
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebseclogin_catalog CASCADE")
    TCSqlExec("SET search_path TO public")

    If !GEBDBProvisionaCatalogo()
        lOk := .F.
    EndIf

    // O cenario do bug original: login em nivel de catalogo SEM GEH (ela
    // so' e' criada por GEBDBProvisionaEmpresa/GEBEXPCriaAuditoria, por
    // empresa). Como o codigo agora usa o catalogo real (public.<tabela>),
    // esconde a GEH real por renome durante o login e restaura depois.
    Local lGeh := GEBDBTableExistsHere("GEH")
    If lGeh
        TCSqlExec("ALTER TABLE public.GEH RENAME TO GEH_BAK_T")
    EndIf

    cFil := FWxFilial("GE2")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_CATLOGIN'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_CATLOGIN'")
    TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '" + cFil + "', 'T_CATLOGIN', 'Teste Catalogo', 'ADMIN')")
    // SEC_HASH: usar a mesma tecnica escolhida na Task 3 Passo 4 para
    // calcular o hash de "senha123" com salt "SALT2" -- literal exato ou
    // chamada a HashSenha() se ela tiver sido promovida a User Function.
    TCSqlExec("INSERT INTO GE2_SEC (D_E_L_E_T_, SEC_FILIAL, SEC_USUARIO, SEC_SALT, SEC_HASH, SEC_FAILCNT, SEC_LOCKED, SEC_LASTLOGIN, SEC_PWDLAST) VALUES (' ', '" + cFil + "', 'T_CATLOGIN', 'SALT2', 'b2481807aa54ca4b6396adb5d375b0a86b69796be70fa2b8b718d7dc3d6c2591844a7c57b2b23ad0ca7ec50d9e2f2d7cc4191e32186014b85956102dbb99a01bbf1c6d85941111fbfb306f2d95094866c7fb0919326136c7ad32eb2e0ed6a789c16bf0d38fa43a903bf384bfa116066c4c435a31988ee3c6291d388ee9d6b52f', 0, '00000000', '00000000', '" + DToS(Date()) + "')")

    If lOk
        cRes := GEBSECLOGIN("T_CATLOGIN", "senha123", "127.0.0.1")
        If cRes != "OK"
            lOk := .F.
            ConOut("FAIL: GEBSECLOGIN em nivel de catalogo, status=" + cRes)
        EndIf
    EndIf

    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_CATLOGIN'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_CATLOGIN'")
    If lGeh
        TCSqlExec("ALTER TABLE public.GEH_BAK_T RENAME TO GEH")
    EndIf

    If lOk
        ConOut("T_GEBSECLOGIN_CATALOG PASS")
    Else
        ConOut("T_GEBSECLOGIN_CATALOG FAIL")
    EndIf
Return lOk
