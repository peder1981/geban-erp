#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBEXP_CTX.prw"

/*/{Protheus.doc} T_GeExp_CTX
    Teste de contexto de sessao multi-empresa (Task 2 GEB_EXPANSAO).
    Reescrito para usar GE2_EMP (vinculo real usuario-empresa) em vez
    da coluna GE2.EMPRESA aposentada -- GEBEXPCONTEXTO() (src/GEBEXP_CTX.prw)
    agora consulta GE2_EMP para validar pertencimento, nao mais uma coluna
    manual criada so' para este teste.
    Asserts (inalterados):
    1. GEBEXPIST() inicial => .F.
    2. GEBEXPCONTEXTO com usuario valido empresa A => .T.
    3. GEBEXPIST() apos inicio => .T.
    4. GEBEXPCONTEXTO() retorna {empresa, filial, usuario} corretos.
    5. Mesmo usuario em empresa B (sem vinculo) => .F.
    6. GEBEXPIST() mantem .T. (empresa B falha nao altera sessao A).
    7. GEBEXPCLEAR() encerra => GEBEXPIST() => .F.
    8. GEBEXPCONTEXTO() apos clear => {"","",""}.
    Schema descartavel test_geexp_ctx.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 24/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GeExp_CTX()
    If !GEBDBConecta()
        ConOut("T_GeExp_CTX: FALHA GEBDBConecta")
        Return .F.
    EndIf
    GBAUDINIC()
    Local lOk := .T.
    Local lTmp := .F.
    Local lAkt := .F.
    Local aCtx := {}
    Local cEmpA := "01"
    Local cEmpB := "02"
    Local cFil := "      "
    Local cUsu := "T_GCTX01"

    TCSqlExec("DROP SCHEMA IF EXISTS test_geexp_ctx CASCADE")
    TCSqlExec("CREATE SCHEMA test_geexp_ctx")
    TCSqlExec("SET search_path TO test_geexp_ctx")

    If !GENMIGCatalogo()
        lOk := .F.
    EndIf
    If lOk .AND. !TCSecMIG()
        lOk := .F.
    EndIf
    GEXBINIT()

    // 1. GEBEXPIST() inicial => .F.
    lAkt := GEBEXPIST()
    If lAkt
        lOk := .F.
    EndIf

    // Insere usuario TESTE01 vinculado SO a empresa A (NAO a empresa B) via GE2_EMP.
    // Catalogo (GE2/GE2_EMP) e' global em public: GEBEXPCONTEXTO consulta
    // public.<tabela> explicitamente, entao o fixture grava la' e limpa depois.
    TCSqlExec("INSERT INTO public.GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '      ', 'T_GCTX01', 'Usuario Teste', 'ADMIN')")
    TCSqlExec("INSERT INTO public.GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA) VALUES (' ', '      ', 'T_GCTX01', '01')")

    // 2. GEBEXPCONTEXTO usuario valido empresa A => .T.
    lTmp := GEBEXPCONTEXTO(cEmpA, cFil, cUsu)
    If !lTmp
        lOk := .F.
    EndIf

    // 3. GEBEXPIST() apos inicio => .T.
    lAkt := GEBEXPIST()
    If !lAkt
        lOk := .F.
    EndIf

    // 4. GEBEXPCONTEXTO() retorna valores corretos.
    aCtx := GEBEXPCONTEXT_GET()
    If aCtx[1] != cEmpA .Or. aCtx[2] != cFil .Or. aCtx[3] != cUsu
        lOk := .F.
    EndIf

    // 5. Mesmo usuario em empresa B (sem vinculo GE2_EMP) => .F.
    lTmp := GEBEXPCONTEXTO(cEmpB, cFil, cUsu)
    If lTmp
        lOk := .F.
    EndIf

    // 6. Sessao empresa A mantida apos falha em B.
    lAkt := GEBEXPIST()
    If !lAkt
        lOk := .F.
    EndIf
    aCtx := GEBEXPCONTEXT_GET()
    If aCtx[1] != cEmpA
        lOk := .F.
    EndIf

    // 7. GEBEXPCLEAR() => GEBEXPIST() => .F.
    GEBEXPCLEAR()
    lAkt := GEBEXPIST()
    If lAkt
        lOk := .F.
    EndIf

    // 8. GEBEXPCONTEXTO() apos clear => {"","",""}.
    aCtx := GEBEXPCONTEXT_GET()
    If aCtx[1] != "" .Or. aCtx[2] != "" .Or. aCtx[3] != ""
        lOk := .F.
    EndIf

    // Cleanup.
    TCSqlExec("DELETE FROM GEH WHERE GEH_USUARIO = 'T_GCTX01'")
    TCSqlExec("DELETE FROM GEX WHERE D_E_L_E_T_ = ' '")
    TCSqlExec("DELETE FROM public.GE2_EMP WHERE GE2_EMP_USUARIO = 'T_GCTX01'")
    TCSqlExec("DELETE FROM public.GE2 WHERE GE2_COD = 'T_GCTX01'")

    TCSqlExec("DROP SCHEMA IF EXISTS test_geexp_ctx CASCADE")

    If lOk
        ConOut("T_GeExp_CTX PASS")
    Else
        ConOut("T_GeExp_CTX FAIL")
    EndIf
Return lOk
