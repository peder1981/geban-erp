#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBMON.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBEXP_CTX.prw"
#include "../src/GEBEXP_REL_BIZ.prw"
#include "../src/GEBEXP_REL_NUC.prw"
#include "../src/GEBEXP_WEB.prw"
#include "../src/GEBGUI_MAIN.prw"
#include "../src/GEBAN.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBDER_MIG.prw"

/*/{Protheus.doc} T_GeExp_WEB
    Teste da tela web de boas-vindas GEB_EXPANSAO (Task 8, redesign da
    Fase 2). Substitui a simulacao antiga de 2 empresas dentro de UM
    schema compartilhado (coluna EMPRESA sombra) por 2 empresas REAIS
    (schemas Postgres independentes emp_<cod>, via GEBDBProvisionaEmpresa)
    -- o mesmo mecanismo de isolamento usado pelo resto do sistema desde
    o redesign multi-tenant. Os asserts de login (11-12) agora exercitam
    de verdade o fluxo GEBAN() da Task 5 (GEBSECLOGIN Argon2id real ->
    GE2_EMP -> GEBDBSetTenant -> GEBEXPCONTEXTO), em vez de um caminho
    conhecido como quebrado (GEBAN() so aceitava 3 args antes da Task 5;
    o teste original chamava GEBAN(cEmp, cUsu, "MENU") passando "MENU" na
    posicao de senha).
    Achados corrigidos nesta task (bugs reais de coluna morta expostos
    ao exercitar estas funcoes pela primeira vez com isolamento real):
    - src/GEBEXP_WEB.prw: GCP1->EMPRESA (coluna aposentada) e um typo
      cFisc[9] (variavel inexistente, deveria ser aFisc[9]).
    - src/GEBEXP_REL_NUC.prw: GEBRELMENTOR() referenciava GE4->EMPRESA
      (coluna aposentada) -- GEBRELEMPRESAS/GEBRELUSUARIOS/GEBRELCADASTROS
      tinham o mesmo padrao; ja corrigidas e cobertas por
      tests/T_GeExp_REL_NUC.prw (nao sao chamadas por GEBEXP_WEB nem por
      GEBAN(), entao continuam fora do escopo deste teste especifico).
    Asserts:
    1. GEBEXP_WEB direto com empresa 1 valida (tenant selecionado) => .T.
    2. GEBEXP_WEB com empresa inexistente (sem vinculo GE2_EMP) => .F.
    3. GEBEXP_WEB direto com empresa 2 valida (tenant selecionado) => .T.
    4. GEBRELFIN empresa 1: array 7 elementos, valores consistentes.
    5. GEBRELFIN empresa 2: array 7 elementos, valores consistentes.
    6. GEBRELFISCAL empresa 1: array 9 elementos, valores consistentes.
    7. GEBRELFISCAL empresa 2: array 9 elementos, valores consistentes.
    8. GEBRELMENTOR empresa 1: array nao vazio.
    9. GEBRELMENTOR empresa 2: array nao vazio.
    10. Isolamento: dados financeiros/fiscais de empresa 1 != empresa 2.
    11. GEBAN() com credenciais reais + vinculo GE2_EMP correto => login
        real (retorna .T. E GEBEXPIST() == .T. apos a chamada).
    12. GEBAN() com credenciais reais mas SEM vinculo GE2_EMP para a
        empresa pedida => cai no fallback menu terminal (retorna .T.,
        mas nenhuma sessao real e' aberta -- verificado via ausencia de
        GEI_AUDIT no schema da empresa alvo, nao apenas GEX, pelo mesmo
        motivo documentado em T_GEBAN_LOGIN_REAL: GEBEXPCONTEXTO() tem
        sua propria checagem redundante de GE2_EMP).
    ORDEM DE EXECUCAO (os asserts 12 e 11 rodam PRIMEIRO no codigo --
    logo apos o setup, antes de 1/2/3 -- apesar da numeracao): achado
    empirico desta task, reproduzido contra o Postgres real do ambiente de homologacao:
    GEBAN() falha no proprio GEBDBProvisionaCatalogo() se QUALQUER
    chamada anterior no mesmo processo ja tiver aberto/fechado a workarea
    GCP1 (dentro de GEBEXP_WEB()) -- inclusive uma chamada DIRETA a
    GEBEXP_WEB(), nao so' uma chamada anterior a GEBAN(). Por isso os
    asserts de GEBAN() (12 primeiro -- caso negativo, sem render -- depois
    11 -- caso positivo, primeiro render do processo) rodam ANTES de
    qualquer chamada direta a GEBEXP_WEB(). Ver comentario detalhado no
    corpo da funcao, logo apos o setup. GEBEXPIST() e' chamada uma UNICA
    vez neste processo (dentro do assert 11), pelo mesmo motivo (cache
    indevido da workarea GEX entre schemas diferentes, documentado em
    T_GEBAN_LOGIN_REAL).
    Setup: 2 empresas provisionadas de verdade (GEBDBProvisionaEmpresa) +
    seed de dados isolados por schema + 2 usuarios reais em GE2/GE2_SEC
    (catalogo, schema public), cada um vinculado a APENAS uma empresa via
    GE2_EMP.
    Cleanup: DROP SCHEMA por empresa + DELETE dos usuarios/GE1 no catalogo.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos asserts passarem, .F. caso contrario
/*/
User Function T_GeExp_WEB()
    Local lOk := .T.
    Local lTmp := .F.
    Local aFin := {}
    Local aFin02 := {}
    Local aFisc := {}
    Local aFisc02 := {}
    Local aMent := {}
    Local cComp := ""
    Local cData := ""
    Local cGuia := ""
    Local cSql := ""
    Local cCod1 := "gxw1"
    Local cCod2 := "gxw2"
    Local cCodInv := "gxw9"
    Local cNome1 := "BANANIAS FILIAL GXW1"
    Local cNome2 := "BANANIAS FILIAL GXW2"
    Local cUsu1 := "TGXW01"
    Local cUsu2 := "TGXW02"
    Local cSenha1 := "senhaGxw1Real"
    Local cSenha2 := "senhaGxw2Real"
    Local cSalt1 := "SALTGXW01"
    Local cSalt2 := "SALTGXW02"
    Local cFil := ""

    If !GEBDBConecta()
        ConOut("T_GeExp_WEB: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")

    // Pre-cleanup (rerun limpo).
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod1 + " CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod2 + " CASCADE")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO IN ('" + cUsu1 + "','" + cUsu2 + "')")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO IN ('" + cUsu1 + "','" + cUsu2 + "')")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD IN ('" + cUsu1 + "','" + cUsu2 + "')")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD IN ('" + cCod1 + "','" + cCod2 + "')")

    If !GEBDBProvisionaCatalogo()
        lOk := .F.
        ConOut("FAIL GEBDBProvisionaCatalogo")
    EndIf

    cComp := SubStr(DToS(Date()), 1, 6)
    cGuia := "GD" + cComp
    cData := DToS(Date())

    // ============================================================
    // SEED EMPRESA 1 (gxw1), inteiramente dentro do seu proprio schema.
    // ============================================================
    If lOk .AND. !GEBDBProvisionaEmpresa(cCod1, cNome1)
        lOk := .F.
        ConOut("FAIL GEBDBProvisionaEmpresa(" + cCod1 + ")")
    EndIf
    If lOk
        GEBDBSetTenant(cCod1)

        TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'REGIME', 'SIMPLES')")
        TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'MENTOR_ATIVADO', 'AUTO')")

        TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'PROD-RB-01', 'NCM0001', 'Produto Teste RB')")
        TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'PROD-RB-02', 'NCM0002', 'Produto Teste RB 2')")

        TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'NCM0001', 10, 5, '20200101', '20301231')")
        TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'NCM0002', 8, 3, '20200101', '20301231')")

        cSql := "INSERT INTO GF3 (D_E_L_E_T_, GF3_FILIAL, GF3_CHAVE, GF3_TIPO, GF3_STATUS, GF3_BASE, GF3_IBS, GF3_CBS, GF3_EMIS) VALUES (' ', '      ', 'NF-RB-01', 'NFE', 'AUTORIZADA', 1000, 100, 50, '" + cComp + "01')"
        TCSqlExec(cSql)
        cSql := "INSERT INTO GF3 (D_E_L_E_T_, GF3_FILIAL, GF3_CHAVE, GF3_TIPO, GF3_STATUS, GF3_BASE, GF3_IBS, GF3_CBS, GF3_EMIS) VALUES (' ', '      ', 'NF-RB-02', 'NFE', 'AUTORIZADA', 500, 40, 20, '" + cComp + "01')"
        TCSqlExec(cSql)

        TCSqlExec("INSERT INTO GF4 (D_E_L_E_T_, GF4_FILIAL, GF4_CHAVE, GF4_ITEM, GF4_PROD, GF4_QTD, GF4_PRECO, GF4_BASE, GF4_IBS, GF4_CBS) VALUES (' ', '      ', 'NF-RB-01', '001', 'PROD-RB-01', 2, 500, 1000, 100, 50)")
        TCSqlExec("INSERT INTO GF4 (D_E_L_E_T_, GF4_FILIAL, GF4_CHAVE, GF4_ITEM, GF4_PROD, GF4_QTD, GF4_PRECO, GF4_BASE, GF4_IBS, GF4_CBS) VALUES (' ', '      ', 'NF-RB-02', '001', 'PROD-RB-02', 1, 500, 500, 40, 20)")

        cSql := "INSERT INTO GF5 (D_E_L_E_T_, GF5_FILIAL, GF5_COMP, GF5_DEB, GF5_CRED, GF5_SALDO, GF5_REGIME) VALUES (' ', '      ', '" + cComp + "', 210, 0, 210, 'REGULAR')"
        TCSqlExec(cSql)

        cSql := "INSERT INTO GD1 (D_E_L_E_T_, GD1_FILIAL, GD1_GUIA, GD1_COMP, GD1_VALOR, GD1_JUROS, GD1_MULTA, GD1_TOTAL, GD1_STATUS) VALUES (' ', '      ', '" + cGuia + "', '" + cComp + "', 210, 0, 0, 210, 'ABERTA')"
        TCSqlExec(cSql)
        cSql := "INSERT INTO GD1 (D_E_L_E_T_, GD1_FILIAL, GD1_GUIA, GD1_COMP, GD1_VALOR, GD1_JUROS, GD1_MULTA, GD1_TOTAL, GD1_STATUS) VALUES (' ', '      ', 'GD-VENC-01', '" + cComp + "', 100, 5, 2, 107, 'VENCIDA')"
        TCSqlExec(cSql)
        cSql := "INSERT INTO GD1 (D_E_L_E_T_, GD1_FILIAL, GD1_GUIA, GD1_COMP, GD1_VALOR, GD1_JUROS, GD1_MULTA, GD1_TOTAL, GD1_STATUS) VALUES (' ', '      ', 'GD-PAGA-01', '" + cComp + "', 50, 0, 0, 50, 'BAIXADA')"
        TCSqlExec(cSql)

        TCSqlExec("INSERT INTO GFN1 (D_E_L_E_T_, GFN1_FILIAL, GFN1_CONTA, GFN1_NOME, GFN1_SALDO) VALUES (' ', '      ', 'CAIXA', 'Caixa 01', 1000)")
        TCSqlExec("INSERT INTO GFN1 (D_E_L_E_T_, GFN1_FILIAL, GFN1_CONTA, GFN1_NOME, GFN1_SALDO) VALUES (' ', '      ', 'BANCO', 'Banco 01', 5000)")

        TCSqlExec("INSERT INTO GFN2 (D_E_L_E_T_, GFN2_FILIAL, GFN2_DOC, GFN2_CLI, GFN2_VALOR, GFN2_SALDO, GFN2_VENC, GFN2_STATUS) VALUES (' ', '      ', 'REC-RB-01', 'CLI-RB', 500, 500, '20261231', 'ABERTO')")
        TCSqlExec("INSERT INTO GFN2 (D_E_L_E_T_, GFN2_FILIAL, GFN2_DOC, GFN2_CLI, GFN2_VALOR, GFN2_SALDO, GFN2_VENC, GFN2_STATUS) VALUES (' ', '      ', 'REC-RB-02', 'CLI-RB', 300, 300, '20261231', 'ABERTO')")

        TCSqlExec("INSERT INTO GFN3 (D_E_L_E_T_, GFN3_FILIAL, GFN3_DOC, GFN3_FORN, GFN3_VALOR, GFN3_SALDO, GFN3_VENC, GFN3_STATUS) VALUES (' ', '      ', 'PAG-RB-01', 'FORN-RB', 400, 400, '20261231', 'ABERTO')")

        cSql := "INSERT INTO GFN4 (D_E_L_E_T_, GFN4_FILIAL, GFN4_CONTA, GFN4_TIPO, GFN4_VALOR, GFN4_DATA) VALUES (' ', '      ', 'CAIXA', 'REC', 200, '" + cData + "')"
        TCSqlExec(cSql)
        cSql := "INSERT INTO GFN4 (D_E_L_E_T_, GFN4_FILIAL, GFN4_CONTA, GFN4_TIPO, GFN4_VALOR, GFN4_DATA) VALUES (' ', '      ', 'CAIXA', 'PAG', 100, '" + cData + "')"
        TCSqlExec(cSql)

        TCSqlExec("INSERT INTO GCP1 (D_E_L_E_T_, GCP1_FILIAL, GCP1_COD, GCP1_NOME, GCP1_CNPJ) VALUES (' ', '      ', 'FORN-RB-01', 'Fornecedor Teste RB', '12345678000199')")
    EndIf

    // ============================================================
    // SEED EMPRESA 2 (gxw2), inteiramente dentro do seu proprio schema.
    // ============================================================
    If lOk .AND. !GEBDBProvisionaEmpresa(cCod2, cNome2)
        lOk := .F.
        ConOut("FAIL GEBDBProvisionaEmpresa(" + cCod2 + ")")
    EndIf
    If lOk
        GEBDBSetTenant(cCod2)

        TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'REGIME', 'REGULAR')")
        TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'MENTOR_SUSPENSO', 'MANUAL')")

        TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'PROD-XZ-01', 'NCM0001', 'Produto Teste XZ')")

        TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'NCM0001', 12, 6, '20200101', '20301231')")

        cSql := "INSERT INTO GF3 (D_E_L_E_T_, GF3_FILIAL, GF3_CHAVE, GF3_TIPO, GF3_STATUS, GF3_BASE, GF3_IBS, GF3_CBS, GF3_EMIS) VALUES (' ', '      ', 'NF-XZ-01', 'NFE', 'AUTORIZADA', 2000, 240, 120, '" + cComp + "01')"
        TCSqlExec(cSql)

        TCSqlExec("INSERT INTO GF4 (D_E_L_E_T_, GF4_FILIAL, GF4_CHAVE, GF4_ITEM, GF4_PROD, GF4_QTD, GF4_PRECO, GF4_BASE, GF4_IBS, GF4_CBS) VALUES (' ', '      ', 'NF-XZ-01', '001', 'PROD-XZ-01', 4, 500, 2000, 240, 120)")

        cSql := "INSERT INTO GF5 (D_E_L_E_T_, GF5_FILIAL, GF5_COMP, GF5_DEB, GF5_CRED, GF5_SALDO, GF5_REGIME) VALUES (' ', '      ', '" + cComp + "', 360, 0, 360, 'SIMPLES')"
        TCSqlExec(cSql)

        cSql := "INSERT INTO GD1 (D_E_L_E_T_, GD1_FILIAL, GD1_GUIA, GD1_COMP, GD1_VALOR, GD1_JUROS, GD1_MULTA, GD1_TOTAL, GD1_STATUS) VALUES (' ', '      ', '" + cGuia + "', '" + cComp + "', 360, 0, 0, 360, 'ABERTA')"
        TCSqlExec(cSql)

        TCSqlExec("INSERT INTO GFN1 (D_E_L_E_T_, GFN1_FILIAL, GFN1_CONTA, GFN1_NOME, GFN1_SALDO) VALUES (' ', '      ', 'CAIXA', 'Caixa 02', 2000)")
        TCSqlExec("INSERT INTO GFN1 (D_E_L_E_T_, GFN1_FILIAL, GFN1_CONTA, GFN1_NOME, GFN1_SALDO) VALUES (' ', '      ', 'BANCO', 'Banco 02', 8000)")

        TCSqlExec("INSERT INTO GFN2 (D_E_L_E_T_, GFN2_FILIAL, GFN2_DOC, GFN2_CLI, GFN2_VALOR, GFN2_SALDO, GFN2_VENC, GFN2_STATUS) VALUES (' ', '      ', 'REC-XZ-01', 'CLI-XZ', 800, 800, '20261231', 'ABERTO')")

        TCSqlExec("INSERT INTO GFN3 (D_E_L_E_T_, GFN3_FILIAL, GFN3_DOC, GFN3_FORN, GFN3_VALOR, GFN3_SALDO, GFN3_VENC, GFN3_STATUS) VALUES (' ', '      ', 'PAG-XZ-01', 'FORN-XZ', 600, 600, '20261231', 'ABERTO')")

        cSql := "INSERT INTO GFN4 (D_E_L_E_T_, GFN4_FILIAL, GFN4_CONTA, GFN4_TIPO, GFN4_VALOR, GFN4_DATA) VALUES (' ', '      ', 'CAIXA', 'REC', 300, '" + cData + "')"
        TCSqlExec(cSql)

        TCSqlExec("INSERT INTO GCP1 (D_E_L_E_T_, GCP1_FILIAL, GCP1_COD, GCP1_NOME, GCP1_CNPJ) VALUES (' ', '      ', 'FORN-XZ-01', 'Fornecedor Teste XZ', '98765432000199')")
    EndIf

    // ============================================================
    // SEED USUARIOS REAIS (catalogo, schema public): TGXW01 vinculado
    // SOMENTE a gxw1, TGXW02 vinculado SOMENTE a gxw2 (GE2_EMP). Hash
    // real Argon2id via HashSenha() (src/GEBSEC_LOGIN.prw), mesmo
    // mecanismo usado pelo login de producao (GEBSECLOGIN).
    // ============================================================
    If lOk
        TCSqlExec("SET search_path TO public")
        cFil := FWxFilial("GE2")

        TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '" + cFil + "', '" + cUsu1 + "', 'Usuario Teste GXW1', 'ADMIN')")
        TCSqlExec("INSERT INTO GE2_SEC (D_E_L_E_T_, SEC_FILIAL, SEC_USUARIO, SEC_SALT, SEC_HASH, SEC_FAILCNT, SEC_LOCKED, SEC_LASTLOGIN, SEC_PWDLAST) VALUES (' ', '" + cFil + "', '" + cUsu1 + "', '" + cSalt1 + "', '" + HashSenha(cSenha1, cSalt1) + "', 0, '00000000', '00000000', '" + DToS(Date()) + "')")
        TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA) VALUES (' ', '" + cFil + "', '" + cUsu1 + "', '" + cCod1 + "')")

        TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '" + cFil + "', '" + cUsu2 + "', 'Usuario Teste GXW2', 'ADMIN')")
        TCSqlExec("INSERT INTO GE2_SEC (D_E_L_E_T_, SEC_FILIAL, SEC_USUARIO, SEC_SALT, SEC_HASH, SEC_FAILCNT, SEC_LOCKED, SEC_LASTLOGIN, SEC_PWDLAST) VALUES (' ', '" + cFil + "', '" + cUsu2 + "', '" + cSalt2 + "', '" + HashSenha(cSenha2, cSalt2) + "', 0, '00000000', '00000000', '" + DToS(Date()) + "')")
        TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA) VALUES (' ', '" + cFil + "', '" + cUsu2 + "', '" + cCod2 + "')")
    EndIf

    ConOut("--- SETUP MULTI-EMPRESA OK ---")

    // === ASSERT 12 e 11 (GEBAN(), Task 5): rodam PRIMEIRO, antes de
    // qualquer chamada direta a GEBEXP_WEB() (asserts 1/3 abaixo) --
    // achado empirico desta task (reproduzido rodando contra o Postgres
    // real do ambiente de homologacao, nao apenas hipotetico), causa raiz rastreada no
    // codigo Go do runtime AdvPP (~/Projetos/AdvPP):
    //   1. DBCLOSEAREA() e' NO-OP neste runtime
    //      (pkg/vm/natives.go:1108) -- nao fecha nada de verdade; a
    //      alias "fechada" continua sendo a alias corrente.
    //   2. GETAREA() retorna essa alias (ainda corrente) como string.
    //   3. RESTAREA(cAlias), mais tarde, chama SelectArea(cAlias), que
    //      executa um SELECT * FROM <alias> NOVO, sob o search_path que
    //      estiver ativo NAQUELE MOMENTO -- nao o search_path que
    //      estava ativo quando GetArea() foi originalmente chamado.
    //   4. Concretamente aqui: uma chamada anterior (GEBEXP_WEB() direta
    //      ou renderizacao previa) deixa GCP1 como alias "corrente" sem
    //      nunca a fechar de fato. GEBDBProvisionaCatalogo(), dentro da
    //      chamada seguinte a GEBAN(), troca o search_path para public.
    //      GENMIGCatalogo() entao faz seu proprio round-trip
    //      GetArea()/RestArea("GCP1"), que agora tenta SELECT * FROM
    //      GCP1 contra public (onde GCP1 pode nao existir) --
    //      produzindo "Error: table GCP1 not found", apesar de
    //      GENMIGCatalogo() nao ter nada a ver com GCP1. Mesmo mecanismo
    //      explica o sintoma analogo com GF5 em T_GeExp_MASSA.prw.
    // Mesma familia de quirk documentada em T_GEBAN_LOGIN_REAL (workarea
    // GCP1 reaberta contra schemas diferentes no mesmo processo), so'
    // que la' GEBAN() nunca era chamado depois de um render feito por
    // chamada DIRETA a GEBEXP_WEB() -- aqui e' exatamente essa
    // combinacao. Mitigacao: GEBAN() roda ANTES de qualquer coisa que
    // abra GCP1 (negativo primeiro, positivo depois -- mesma ordem de
    // T_GEBAN_LOGIN_REAL), garantindo que o PRIMEIRO uso de GCP1 no
    // processo inteiro seja o render de dashboard dentro do proprio
    // GEBAN() bem-sucedido. Bug de runtime AdvPP preexistente, nao
    // introduzido por esta task e fora de escopo corrigir aqui (ver
    // Pendencias do plano para o risco de producao futura). ===

    // === ASSERT 12: GEBAN() com senha real e vinculo GE2_EMP para OUTRA
    // empresa (cUsu1 so' esta' vinculado a cCod1) cai no fallback menu
    // terminal -- verificado via ausencia de GEI_AUDIT no schema alvo
    // (GBAUDINIC roda logo apos o gate GE2_EMP de GEBAN() e ANTES de
    // GEBEXPCONTEXTO(), mesma tecnica de T_GEBAN_LOGIN_REAL). ===
    ConOut("--- ASSERT 12: GEBAN sem vinculo GE2_EMP para a empresa pedida ---")
    lTmp := GEBAN(cCod2, cUsu1, cSenha1)
    If !lTmp
        ConOut("FAIL ASSERT 12: GEBAN(" + cCod2 + "," + cUsu1 + ",<senha>) retornou .F. (esperado .T., fallback menu terminal)")
        lOk := .F.
    Else
        If Len(TCSqlQuery("SELECT tablename FROM pg_tables WHERE schemaname = 'emp_" + cCod2 + "' AND tablename = 'gei_audit'")) > 0
            ConOut("FAIL ASSERT 12: GEI_AUDIT existe em emp_" + cCod2 + " apos GEBAN sem vinculo GE2_EMP -- sessao real foi aberta indevidamente")
            lOk := .F.
        Else
            ConOut("OK ASSERT 12: GEBAN(" + cCod2 + "," + cUsu1 + ",<senha>) caiu no fallback (nenhuma sessao real aberta em " + cCod2 + ")")
        EndIf
    EndIf

    // === ASSERT 11: GEBAN() com credenciais reais e vinculo GE2_EMP
    // correto abre sessao real (nao apenas fallback). GEBEXPIST() e'
    // chamada uma UNICA vez neste processo, aqui. ===
    ConOut("--- ASSERT 11: GEBAN com credenciais reais e vinculo correto ---")
    lTmp := GEBAN(cCod1, cUsu1, cSenha1)
    If !lTmp
        ConOut("FAIL ASSERT 11: GEBAN(" + cCod1 + "," + cUsu1 + ",<senha>) retornou .F.")
        lOk := .F.
    Else
        If !GEBEXPIST()
            ConOut("FAIL ASSERT 11: GEBEXPIST() retornou .F. apos GEBAN() com credenciais validas -- login real nao ocorreu")
            lOk := .F.
        Else
            ConOut("OK ASSERT 11: GEBAN(" + cCod1 + "," + cUsu1 + ",<senha>) abriu sessao real (GEBEXPIST()==.T.)")
        EndIf
    EndIf

    // === ASSERT 1: GEBEXP_WEB empresa 1 valida (tenant selecionado) ===
    ConOut("--- ASSERT 1: GEBEXP_WEB empresa 1 ---")
    GEBDBSetTenant(cCod1)
    lTmp := GEBEXP_WEB(cCod1, cUsu1)
    If !lTmp
        ConOut("FAIL ASSERT 1: GEBEXP_WEB empresa 1 retornou .F.")
        lOk := .F.
    Else
        ConOut("OK ASSERT 1: GEBEXP_WEB empresa 1 retornou .T.")
    EndIf

    // === ASSERT 2: GEBEXP_WEB empresa inexistente (sem vinculo GE2_EMP) => .F. ===
    ConOut("--- ASSERT 2: GEBEXP_WEB empresa inexistente ---")
    lTmp := GEBEXP_WEB(cCodInv, cUsu1)
    If lTmp
        ConOut("FAIL ASSERT 2: GEBEXP_WEB empresa " + cCodInv + " deveria retornar .F.")
        lOk := .F.
    Else
        ConOut("OK ASSERT 2: GEBEXP_WEB empresa " + cCodInv + " retornou .F. (correto)")
    EndIf

    // === ASSERT 3: GEBEXP_WEB empresa 2 valida (tenant selecionado) ===
    ConOut("--- ASSERT 3: GEBEXP_WEB empresa 2 ---")
    GEBDBSetTenant(cCod2)
    lTmp := GEBEXP_WEB(cCod2, cUsu2)
    If !lTmp
        ConOut("FAIL ASSERT 3: GEBEXP_WEB empresa 2 retornou .F.")
        lOk := .F.
    Else
        ConOut("OK ASSERT 3: GEBEXP_WEB empresa 2 retornou .T.")
    EndIf

    // === ASSERT 4: Resumo financeiro empresa 1 (7 elementos) ===
    ConOut("--- ASSERT 4: GEBRELFIN empresa 1 ---")
    GEBDBSetTenant(cCod1)
    aFin := GEBRELFIN(cCod1)
    If Len(aFin) != 7
        ConOut("FAIL ASSERT 4: GEBRELFIN Len=" + cValToChar(Len(aFin)) + " (esperado 7)")
        lOk := .F.
    ElseIf aFin[1] < 2 .Or. aFin[2] < 2 .Or. aFin[3] < 1 .Or. aFin[4] <= 0 .Or. aFin[5] <= 0 .Or. aFin[7] < 2
        ConOut("FAIL ASSERT 4: valores inconsistentes fin emp 1")
        lOk := .F.
    Else
        ConOut("OK ASSERT 4: GEBRELFIN emp 1 OK (contas=" + cValToChar(aFin[1]) + " receber=" + cValToChar(aFin[2]) + " pagar=" + cValToChar(aFin[3]) + ")")
    EndIf

    // === ASSERT 5: Resumo financeiro empresa 2 (7 elementos) ===
    ConOut("--- ASSERT 5: GEBRELFIN empresa 2 ---")
    GEBDBSetTenant(cCod2)
    aFin := GEBRELFIN(cCod2)
    If Len(aFin) != 7
        ConOut("FAIL ASSERT 5: GEBRELFIN Len=" + cValToChar(Len(aFin)) + " (esperado 7)")
        lOk := .F.
    ElseIf aFin[1] < 2 .Or. aFin[2] < 1 .Or. aFin[3] < 1 .Or. aFin[4] <= 0 .Or. aFin[5] <= 0
        ConOut("FAIL ASSERT 5: valores inconsistentes fin emp 2")
        lOk := .F.
    Else
        ConOut("OK ASSERT 5: GEBRELFIN emp 2 OK")
    EndIf

    // === ASSERT 6: Resumo fiscal empresa 1 (9 elementos) ===
    ConOut("--- ASSERT 6: GEBRELFISCAL empresa 1 ---")
    GEBDBSetTenant(cCod1)
    aFisc := GEBRELFISCAL(cCod1, cComp)
    If Len(aFisc) != 9
        ConOut("FAIL ASSERT 6: GEBRELFISCAL Len=" + cValToChar(Len(aFisc)) + " (esperado 9)")
        lOk := .F.
    ElseIf aFisc[1] < 2 .Or. aFisc[2] <= 0 .Or. aFisc[8] < 1
        ConOut("FAIL ASSERT 6: valores inconsistentes fisc emp 1")
        lOk := .F.
    Else
        ConOut("OK ASSERT 6: GEBRELFISCAL emp 1 OK (notas=" + cValToChar(aFisc[1]) + " base=" + cValToChar(aFisc[2]) + ")")
    EndIf

    // === ASSERT 7: Resumo fiscal empresa 2 (9 elementos) ===
    ConOut("--- ASSERT 7: GEBRELFISCAL empresa 2 ---")
    GEBDBSetTenant(cCod2)
    aFisc := GEBRELFISCAL(cCod2, cComp)
    If Len(aFisc) != 9
        ConOut("FAIL ASSERT 7: GEBRELFISCAL Len=" + cValToChar(Len(aFisc)) + " (esperado 9)")
        lOk := .F.
    ElseIf aFisc[1] < 1 .Or. aFisc[2] <= 0 .Or. aFisc[8] < 1
        ConOut("FAIL ASSERT 7: valores inconsistentes fisc emp 2")
        lOk := .F.
    Else
        ConOut("OK ASSERT 7: GEBRELFISCAL emp 2 OK")
    EndIf

    // === ASSERT 8: Alertas mentor empresa 1 ===
    ConOut("--- ASSERT 8: GEBRELMENTOR empresa 1 ---")
    GEBDBSetTenant(cCod1)
    aMent := GEBRELMENTOR(cCod1)
    If Len(aMent) < 1
        ConOut("FAIL ASSERT 8: GEBRELMENTOR emp 1 vazio")
        lOk := .F.
    Else
        ConOut("OK ASSERT 8: GEBRELMENTOR emp 1 = " + cValToChar(Len(aMent)) + " alertas")
    EndIf

    // === ASSERT 9: Alertas mentor empresa 2 ===
    ConOut("--- ASSERT 9: GEBRELMENTOR empresa 2 ---")
    GEBDBSetTenant(cCod2)
    aMent := GEBRELMENTOR(cCod2)
    If Len(aMent) < 1
        ConOut("FAIL ASSERT 9: GEBRELMENTOR emp 2 vazio")
        lOk := .F.
    Else
        ConOut("OK ASSERT 9: GEBRELMENTOR emp 2 = " + cValToChar(Len(aMent)) + " alertas")
    EndIf

    // === ASSERT 10: Isolamento multi-empresa (fin 1 != fin 2) ===
    ConOut("--- ASSERT 10: Isolamento multi-empresa ---")
    GEBDBSetTenant(cCod1)
    aFin := GEBRELFIN(cCod1)
    aFisc := GEBRELFISCAL(cCod1, cComp)
    GEBDBSetTenant(cCod2)
    aFin02 := GEBRELFIN(cCod2)
    aFisc02 := GEBRELFISCAL(cCod2, cComp)
    // Empresas diferentes (schemas diferentes) devem ter valores financeiros diferentes.
    If aFin[4] == aFin02[4] .And. aFin[5] == aFin02[5]
        ConOut("FAIL ASSERT 10: valores financeiros iguais entre empresas (isolamento falhou)")
        lOk := .F.
    Else
        ConOut("OK ASSERT 10: isolamento emp 1 vs 2 OK (receber 1=" + cValToChar(aFin[4]) + " vs 2=" + cValToChar(aFin02[4]) + ")")
    EndIf
    If aFisc[1] == aFisc02[1] .And. aFisc[2] == aFisc02[2]
        ConOut("FAIL ASSERT 10: valores fiscais iguais entre empresas (isolamento falhou)")
        lOk := .F.
    Else
        ConOut("OK ASSERT 10: isolamento fiscal emp 1 vs 2 OK")
    EndIf

    // === CLEANUP ===
    ConOut("--- CLEANUP ---")
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod1 + " CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod2 + " CASCADE")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO IN ('" + cUsu1 + "','" + cUsu2 + "')")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO IN ('" + cUsu1 + "','" + cUsu2 + "')")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD IN ('" + cUsu1 + "','" + cUsu2 + "')")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD IN ('" + cCod1 + "','" + cCod2 + "')")

    ConOut("")
    If lOk
        ConOut("T_GeExp_WEB PASS")
    Else
        ConOut("T_GeExp_WEB FAIL")
    EndIf
Return lOk
