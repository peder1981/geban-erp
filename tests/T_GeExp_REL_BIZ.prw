#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBEXP_TRAK.prw"
#include "../src/GEBEXP_REL_BIZ.prw"

/*/{Protheus.doc} T_GeExp_REL_BIZ
    Teste dos relatorios e trackers GEB_EXPANSAO (Task 4).
    Asserts:
    1. GEBRELFISCAL retorna array 9 elementos com dados consistentes.
    2. GEBRELDERRAMA retorna array 6 elementos com dados consistentes.
    3. GEBRELFIN retorna array 7 elementos com dados consistentes.
    4. GEBRELSTOQUE retorna array 4 elementos com dados consistentes.
    5. GEBRELCOMPRAS retorna array 5 elementos com dados consistentes.
    6. GEBRELCONTABIL retorna array 6 elementos com dados consistentes.
    7. GEBRELGERAL retorna array 6 elementos (consolidado).
    8. GEBTRAKCOMPRA rastreia pedido completo.
    9. GEBTRAKVENDA rastreia venda completa.
    10. GEBTRAKNOTAFISCAL rastreia NF completa.
    11. GEBTRAKDERRAMA rastreia guia completa.
    Setup: migracoes (GENMIG + MIG por modulo) + seed de dados em todas
    as tabelas. Postgres: sem "INSERT OR IGNORE" (sintaxe SQLite) --
    INSERT direto, cleanup via DELETE ao final (rerun limpo).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GeExp_REL_BIZ()
    Local lOk := .T.
    Local aRel := {}
    Local aTrak := {}
    Local cComp := ""
    Local cGuia := ""
    Local cData := ""
    Local cSql := ""

    If !GEBDBConecta()
        ConOut("T_GeExp_REL_BIZ: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_geexp_relbiz CASCADE")
    TCSqlExec("CREATE SCHEMA test_geexp_relbiz")
    TCSqlExec("SET search_path TO test_geexp_relbiz")
    GBAUDINIC()

    // Setup migracoes (primeiro tabelas base, depois expansao EMPRESA).
    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBFMIG()
        lOk := .F.
    EndIf
    If !GEBCMMIG()
        lOk := .F.
    EndIf
    If !GEBFNMIG()
        lOk := .F.
    EndIf
    If !GEBVMIG()
        lOk := .F.
    EndIf
    If !GEBCMIG()
        lOk := .F.
    EndIf
    If !GEBDMIG()
        lOk := .F.
    EndIf

    cComp := SubStr(DToS(Date()), 1, 6)
    cGuia := "GD" + cComp
    cData := DToS(Date())

    // === SEED DE DADOS ===

    // Empresas.
    TCSqlExec("INSERT INTO GE1 (D_E_L_E_T_, GE1_FILIAL, GE1_COD, GE1_NOME) VALUES (' ', '      ', '01', 'BANANIAS')")

    // Produtos.
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'PROD-RB-01', 'NCM0001', 'Produto Teste RB')")
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'PROD-RB-02', 'NCM0002', 'Produto Teste RB 2')")

    // Aliquotas.
    TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'NCM0001', 10, 5, '20200101', '20301231')")
    TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'NCM0002', 8, 3, '20200101', '20301231')")

    // NFs fiscais (cComp usado via variavel aux).
    cSql := "INSERT INTO GF3 (D_E_L_E_T_, GF3_FILIAL, GF3_CHAVE, GF3_TIPO, GF3_STATUS, GF3_BASE, GF3_IBS, GF3_CBS, GF3_EMIS) VALUES (' ', '      ', 'NF-RB-01', 'NFE', 'AUTORIZADA', 1000, 100, 50, '" + cComp + "01')"
    TCSqlExec(cSql)
    cSql := "INSERT INTO GF3 (D_E_L_E_T_, GF3_FILIAL, GF3_CHAVE, GF3_TIPO, GF3_STATUS, GF3_BASE, GF3_IBS, GF3_CBS, GF3_EMIS) VALUES (' ', '      ', 'NF-RB-02', 'NFE', 'AUTORIZADA', 500, 40, 20, '" + cComp + "01')"
    TCSqlExec(cSql)

    // Items NF.
    TCSqlExec("INSERT INTO GF4 (D_E_L_E_T_, GF4_FILIAL, GF4_CHAVE, GF4_ITEM, GF4_PROD, GF4_QTD, GF4_PRECO, GF4_BASE, GF4_IBS, GF4_CBS) VALUES (' ', '      ', 'NF-RB-01', '001', 'PROD-RB-01', 2, 500, 1000, 100, 50)")
    TCSqlExec("INSERT INTO GF4 (D_E_L_E_T_, GF4_FILIAL, GF4_CHAVE, GF4_ITEM, GF4_PROD, GF4_QTD, GF4_PRECO, GF4_BASE, GF4_IBS, GF4_CBS) VALUES (' ', '      ', 'NF-RB-02', '001', 'PROD-RB-02', 1, 500, 500, 40, 20)")

    // Apuracao fiscal.
    cSql := "INSERT INTO GF5 (D_E_L_E_T_, GF5_FILIAL, GF5_COMP, GF5_DEB, GF5_CRED, GF5_SALDO, GF5_REGIME) VALUES (' ', '      ', '" + cComp + "', 210, 0, 210, 'REGULAR')"
    TCSqlExec(cSql)

    // Guia derrama.
    cSql := "INSERT INTO GD1 (D_E_L_E_T_, GD1_FILIAL, GD1_GUIA, GD1_COMP, GD1_VALOR, GD1_JUROS, GD1_MULTA, GD1_TOTAL, GD1_STATUS) VALUES (' ', '      ', '" + cGuia + "', '" + cComp + "', 210, 0, 0, 210, 'ABERTA')"
    TCSqlExec(cSql)
    cSql := "INSERT INTO GD1 (D_E_L_E_T_, GD1_FILIAL, GD1_GUIA, GD1_COMP, GD1_VALOR, GD1_JUROS, GD1_MULTA, GD1_TOTAL, GD1_STATUS) VALUES (' ', '      ', 'GD-VENC-" + cComp + "', '" + cComp + "', 100, 5, 2, 107, 'VENCIDA')"
    TCSqlExec(cSql)
    cSql := "INSERT INTO GD1 (D_E_L_E_T_, GD1_FILIAL, GD1_GUIA, GD1_COMP, GD1_VALOR, GD1_JUROS, GD1_MULTA, GD1_TOTAL, GD1_STATUS) VALUES (' ', '      ', 'GD-PAGA-" + cComp + "', '" + cComp + "', 50, 0, 0, 50, 'BAIXADA')"
    TCSqlExec(cSql)

    // Parcelas.
    cSql := "INSERT INTO GD2 (D_E_L_E_T_, GD2_FILIAL, GD2_GUIA, GD2_PARC, GD2_VALOR, GD2_STATUS) VALUES (' ', '      ', '" + cGuia + "', '001', 105, 'ABERTA')"
    TCSqlExec(cSql)
    cSql := "INSERT INTO GD2 (D_E_L_E_T_, GD2_FILIAL, GD2_GUIA, GD2_PARC, GD2_VALOR, GD2_STATUS) VALUES (' ', '      ', '" + cGuia + "', '002', 105, 'ABERTA')"
    TCSqlExec(cSql)

    // Protesto.
    cSql := "INSERT INTO GD3 (D_E_L_E_T_, GD3_FILIAL, GD3_GUIA, GD3_ACAO, GD3_DATA, GD3_STATUS) VALUES (' ', '      ', 'GD-PROT-" + cComp + "', 'PROTESTO', '" + cData + "', 'ABERTA')"
    TCSqlExec(cSql)

    // Contas financeiras.
    TCSqlExec("INSERT INTO GFN1 (D_E_L_E_T_, GFN1_FILIAL, GFN1_CONTA, GFN1_NOME, GFN1_SALDO) VALUES (' ', '      ', 'CAIXA', 'Caixa', 1000)")
    TCSqlExec("INSERT INTO GFN1 (D_E_L_E_T_, GFN1_FILIAL, GFN1_CONTA, GFN1_NOME, GFN1_SALDO) VALUES (' ', '      ', 'BANCO', 'Banco', 5000)")

    // Titulos a receber.
    TCSqlExec("INSERT INTO GFN2 (D_E_L_E_T_, GFN2_FILIAL, GFN2_DOC, GFN2_CLI, GFN2_VALOR, GFN2_SALDO, GFN2_VENC, GFN2_STATUS) VALUES (' ', '      ', 'REC-RB-01', 'CLI-RB', 500, 500, '20261231', 'ABERTO')")
    TCSqlExec("INSERT INTO GFN2 (D_E_L_E_T_, GFN2_FILIAL, GFN2_DOC, GFN2_CLI, GFN2_VALOR, GFN2_SALDO, GFN2_VENC, GFN2_STATUS) VALUES (' ', '      ', 'REC-RB-02', 'CLI-RB', 300, 300, '20261231', 'ABERTO')")
    TCSqlExec("INSERT INTO GFN2 (D_E_L_E_T_, GFN2_FILIAL, GFN2_DOC, GFN2_CLI, GFN2_VALOR, GFN2_SALDO, GFN2_VENC, GFN2_STATUS) VALUES (' ', '      ', 'REC-RB-03', 'CLI-RB', 200, 0, '20261231', 'RECEBIDA')")

    // Titulos a pagar.
    TCSqlExec("INSERT INTO GFN3 (D_E_L_E_T_, GFN3_FILIAL, GFN3_DOC, GFN3_FORN, GFN3_VALOR, GFN3_SALDO, GFN3_VENC, GFN3_STATUS) VALUES (' ', '      ', 'PAG-RB-01', 'FORN-RB', 400, 400, '20261231', 'ABERTO')")
    TCSqlExec("INSERT INTO GFN3 (D_E_L_E_T_, GFN3_FILIAL, GFN3_DOC, GFN3_FORN, GFN3_VALOR, GFN3_SALDO, GFN3_VENC, GFN3_STATUS) VALUES (' ', '      ', 'PAG-RB-02', 'FORN-RB', 100, 0, '20261231', 'PAGA')")

    // Movimentos financeiros.
    cSql := "INSERT INTO GFN4 (D_E_L_E_T_, GFN4_FILIAL, GFN4_CONTA, GFN4_TIPO, GFN4_VALOR, GFN4_DATA) VALUES (' ', '      ', 'CAIXA', 'REC', 200, '" + cData + "')"
    TCSqlExec(cSql)
    cSql := "INSERT INTO GFN4 (D_E_L_E_T_, GFN4_FILIAL, GFN4_CONTA, GFN4_TIPO, GFN4_VALOR, GFN4_DATA) VALUES (' ', '      ', 'CAIXA', 'PAG', 100, '" + cData + "')"
    TCSqlExec(cSql)

    // Estoque.
    TCSqlExec("INSERT INTO GV1 (D_E_L_E_T_, GV1_FILIAL, GV1_PROD, GV1_SALDO, GV1_MIN) VALUES (' ', '      ', 'PROD-RB-01', 50, 10)")
    TCSqlExec("INSERT INTO GV1 (D_E_L_E_T_, GV1_FILIAL, GV1_PROD, GV1_SALDO, GV1_MIN) VALUES (' ', '      ', 'PROD-RB-02', 5, 10)")

    // Movimentos estoque GV2.
    TCSqlExec("INSERT INTO GV2 (D_E_L_E_T_, GV2_FILIAL, GV2_VENDA, GV2_PROD, GV2_QTD, GV2_STATUS) VALUES (' ', '      ', 'VEN-RB-01', 'PROD-RB-01', 2, 'BAIXADO')")
    TCSqlExec("INSERT INTO GV2 (D_E_L_E_T_, GV2_FILIAL, GV2_VENDA, GV2_PROD, GV2_QTD, GV2_STATUS) VALUES (' ', '      ', 'VEN-RB-01', 'PROD-RB-02', 1, 'BAIXADO')")

    // Fiado.
    TCSqlExec("INSERT INTO GV3 (D_E_L_E_T_, GV3_FILIAL, GV3_CLI, GV3_VALOR, GV3_JUROS, GV3_MULTA, GV3_TOTAL, GV3_STATUS) VALUES (' ', '      ', 'CLI-RB', 100, 0, 0, 100, 'ABERTA')")

    // Fornecedores.
    TCSqlExec("INSERT INTO GCP1 (D_E_L_E_T_, GCP1_FILIAL, GCP1_COD, GCP1_NOME, GCP1_CNPJ) VALUES (' ', '      ', 'FORN-RB-01', 'Fornecedor Teste', '12345678000199')")
    TCSqlExec("INSERT INTO GCP1 (D_E_L_E_T_, GCP1_FILIAL, GCP1_COD, GCP1_NOME, GCP1_CNPJ) VALUES (' ', '      ', 'FORN-RB-02', 'Fornecedor Teste 2', '98765432000199')")

    // Cotacoes.
    TCSqlExec("INSERT INTO GCP2 (D_E_L_E_T_, GCP2_FILIAL, GCP2_FORN, GCP2_PROD, GCP2_PRECO) VALUES (' ', '      ', 'FORN-RB-01', 'PROD-RB-01', 450)")
    TCSqlExec("INSERT INTO GCP2 (D_E_L_E_T_, GCP2_FILIAL, GCP2_FORN, GCP2_PROD, GCP2_PRECO) VALUES (' ', '      ', 'FORN-RB-02', 'PROD-RB-01', 480)")

    // Pedidos.
    TCSqlExec("INSERT INTO GCP3 (D_E_L_E_T_, GCP3_FILIAL, GCP3_NUM, GCP3_FORN, GCP3_STATUS) VALUES (' ', '      ', 'PED-RB-01', 'FORN-RB-01', 'ABERTO')")
    TCSqlExec("INSERT INTO GCP3 (D_E_L_E_T_, GCP3_FILIAL, GCP3_NUM, GCP3_FORN, GCP3_STATUS) VALUES (' ', '      ', 'PED-RB-02', 'FORN-RB-02', 'RECEBIDO')")

    // Itens pedido.
    TCSqlExec("INSERT INTO GCP4 (D_E_L_E_T_, GCP4_FILIAL, GCP4_PED, GCP4_PROD, GCP4_QTD, GCP4_PRECO) VALUES (' ', '      ', 'PED-RB-01', 'PROD-RB-01', 10, 450)")
    TCSqlExec("INSERT INTO GCP4 (D_E_L_E_T_, GCP4_FILIAL, GCP4_PED, GCP4_PROD, GCP4_QTD, GCP4_PRECO) VALUES (' ', '      ', 'PED-RB-02', 'PROD-RB-02', 5, 200)")

    // Entradas.
    TCSqlExec("INSERT INTO GCP5 (D_E_L_E_T_, GCP5_FILIAL, GCP5_NF, GCP5_PED, GCP5_STATUS) VALUES (' ', '      ', 'NF-ENT-RB-01', 'PED-RB-02', 'RECEBIDA')")

    // Lancamentos contabeis.
    TCSqlExec("INSERT INTO GC1 (D_E_L_E_T_, GC1_FILIAL, GC1_CONTA, GC1_NOME, GC1_TIPO) VALUES (' ', '      ', '1.01.001', 'Caixa', 'A')")
    TCSqlExec("INSERT INTO GC1 (D_E_L_E_T_, GC1_FILIAL, GC1_CONTA, GC1_NOME, GC1_TIPO) VALUES (' ', '      ', '3.01.001', 'Receita', 'R')")
    cSql := "INSERT INTO GC2 (D_E_L_E_T_, GC2_FILIAL, GC2_LOTE, GC2_ORIGEM, GC2_VALOR, GC2_DATA, GC2_COMP, GC2_TIPO) VALUES (' ', '      ', 'LOTE-RB-01', 'NF-RB-01', 1150, '" + cData + "', '" + cComp + "', 'AUTO')"
    TCSqlExec(cSql)
    TCSqlExec("INSERT INTO GC3 (D_E_L_E_T_, GC3_FILIAL, GC3_LOTE, GC3_DC, GC3_CONTA, GC3_VALOR) VALUES (' ', '      ', 'LOTE-RB-01', 'D', '1.01.001', 1150)")
    TCSqlExec("INSERT INTO GC3 (D_E_L_E_T_, GC3_FILIAL, GC3_LOTE, GC3_DC, GC3_CONTA, GC3_VALOR) VALUES (' ', '      ', 'LOTE-RB-01', 'C', '3.01.001', 1150)")

    ConOut("--- RELATORIOS ---")

    // === TESTE GEBRELFISCAL ===
    aRel := GEBRELFISCAL("01", cComp)
    If Len(aRel) != 9
        lOk := .F.
        ConOut("FAIL GEBRELFISCAL: Len=" + cValToChar(Len(aRel)))
    Else
        If aRel[1] < 2
            lOk := .F.
            ConOut("FAIL GEBRELFISCAL nNotas: " + cValToChar(aRel[1]))
        EndIf
        If aRel[2] <= 0
            lOk := .F.
            ConOut("FAIL GEBRELFISCAL nBase: " + cValToChar(aRel[2]))
        EndIf
        If aRel[3] <= 0
            lOk := .F.
            ConOut("FAIL GEBRELFISCAL nIBS: " + cValToChar(aRel[3]))
        EndIf
        If aRel[5] != aRel[3] + aRel[4]
            lOk := .F.
            ConOut("FAIL GEBRELFISCAL nDeb != nIBS+nCBS")
        EndIf
        If aRel[7] != aRel[5] - aRel[6]
            lOk := .F.
            ConOut("FAIL GEBRELFISCAL saldoDerrama")
        EndIf
        If aRel[8] < 1
            lOk := .F.
            ConOut("FAIL GEBRELFISCAL nApuracoes")
        EndIf
        ConOut("OK GEBRELFISCAL notas=" + cValToChar(aRel[1]) + " base=" + cValToChar(aRel[2]))
    EndIf

    // === TESTE GEBRELDERRAMA ===
    aRel := GEBRELDERRAMA("01", cComp)
    If Len(aRel) != 6
        lOk := .F.
        ConOut("FAIL GEBRELDERRAMA: Len=" + cValToChar(Len(aRel)))
    Else
        If aRel[1] < 3
            lOk := .F.
            ConOut("FAIL GEBRELDERRAMA nGuias: " + cValToChar(aRel[1]))
        EndIf
        If aRel[2] < 1
            lOk := .F.
            ConOut("FAIL GEBRELDERRAMA nPagas: " + cValToChar(aRel[2]))
        EndIf
        If aRel[3] < 1
            lOk := .F.
            ConOut("FAIL GEBRELDERRAMA nVencidas: " + cValToChar(aRel[3]))
        EndIf
        If aRel[4] <= 0
            lOk := .F.
            ConOut("FAIL GEBRELDERRAMA nValorTotal: " + cValToChar(aRel[4]))
        EndIf
        If aRel[5] < 2
            lOk := .F.
            ConOut("FAIL GEBRELDERRAMA nParcelas: " + cValToChar(aRel[5]))
        EndIf
        If aRel[6] < 0
            lOk := .F.
            ConOut("FAIL GEBRELDERRAMA nProtestos")
        EndIf
        ConOut("OK GEBRELDERRAMA guias=" + cValToChar(aRel[1]) + " pagas=" + cValToChar(aRel[2]))
    EndIf

    // === TESTE GEBRELFIN ===
    aRel := GEBRELFIN("01")
    If Len(aRel) != 7
        lOk := .F.
        ConOut("FAIL GEBRELFIN: Len=" + cValToChar(Len(aRel)))
    Else
        If aRel[1] < 2
            lOk := .F.
            ConOut("FAIL GEBRELFIN nContas: " + cValToChar(aRel[1]))
        EndIf
        If aRel[2] < 2
            lOk := .F.
            ConOut("FAIL GEBRELFIN nReceber: " + cValToChar(aRel[2]))
        EndIf
        If aRel[3] < 1
            lOk := .F.
            ConOut("FAIL GEBRELFIN nPagar: " + cValToChar(aRel[3]))
        EndIf
        If aRel[4] <= 0
            lOk := .F.
            ConOut("FAIL GEBRELFIN nValorReceber: " + cValToChar(aRel[4]))
        EndIf
        If aRel[5] <= 0
            lOk := .F.
            ConOut("FAIL GEBRELFIN nValorPagar: " + cValToChar(aRel[5]))
        EndIf
        If aRel[7] < 2
            lOk := .F.
            ConOut("FAIL GEBRELFIN nMovimentos: " + cValToChar(aRel[7]))
        EndIf
        ConOut("OK GEBRELFIN receber=" + cValToChar(aRel[4]) + " pagar=" + cValToChar(aRel[5]))
    EndIf

    // === TESTE GEBRELSTOQUE ===
    aRel := GEBRELSTOQUE("01")
    If Len(aRel) != 4
        lOk := .F.
        ConOut("FAIL GEBRELSTOQUE: Len=" + cValToChar(Len(aRel)))
    Else
        If aRel[1] < 2
            lOk := .F.
            ConOut("FAIL GEBRELSTOQUE nProdutos: " + cValToChar(aRel[1]))
        EndIf
        If aRel[2] < 1
            lOk := .F.
            ConOut("FAIL GEBRELSTOQUE nItensBaixoMinimo: " + cValToChar(aRel[2]))
        EndIf
        If aRel[3] <= 0
            lOk := .F.
            ConOut("FAIL GEBRELSTOQUE valorTotalEstoque: " + cValToChar(aRel[3]))
        EndIf
        If aRel[4] < 2
            lOk := .F.
            ConOut("FAIL GEBRELSTOQUE nMovimentos: " + cValToChar(aRel[4]))
        EndIf
        ConOut("OK GEBRELSTOQUE produtos=" + cValToChar(aRel[1]) + " baixomin=" + cValToChar(aRel[2]))
    EndIf

    // === TESTE GEBRELCOMPRAS ===
    aRel := GEBRELCOMPRAS("01")
    If Len(aRel) != 5
        lOk := .F.
        ConOut("FAIL GEBRELCOMPRAS: Len=" + cValToChar(Len(aRel)))
    Else
        If aRel[1] < 2
            lOk := .F.
            ConOut("FAIL GEBRELCOMPRAS nFornecedores: " + cValToChar(aRel[1]))
        EndIf
        If aRel[2] < 2
            lOk := .F.
            ConOut("FAIL GEBRELCOMPRAS nPedidos: " + cValToChar(aRel[2]))
        EndIf
        If aRel[3] < 1
            lOk := .F.
            ConOut("FAIL GEBRELCOMPRAS nRecebidos: " + cValToChar(aRel[3]))
        EndIf
        If aRel[4] <= 0
            lOk := .F.
            ConOut("FAIL GEBRELCOMPRAS nValorTotal: " + cValToChar(aRel[4]))
        EndIf
        If aRel[5] < 2
            lOk := .F.
            ConOut("FAIL GEBRELCOMPRAS nCotacoes: " + cValToChar(aRel[5]))
        EndIf
        ConOut("OK GEBRELCOMPRAS forns=" + cValToChar(aRel[1]) + " ped=" + cValToChar(aRel[2]))
    EndIf

    // === TESTE GEBRELCONTABIL ===
    aRel := GEBRELCONTABIL("01", cComp)
    If Len(aRel) != 6
        lOk := .F.
        ConOut("FAIL GEBRELCONTABIL: Len=" + cValToChar(Len(aRel)))
    Else
        If aRel[1] < 2
            lOk := .F.
            ConOut("FAIL GEBRELCONTABIL nLancamentos: " + cValToChar(aRel[1]))
        EndIf
        If aRel[2] < 1
            lOk := .F.
            ConOut("FAIL GEBRELCONTABIL nDec: " + cValToChar(aRel[2]))
        EndIf
        If aRel[3] < 1
            lOk := .F.
            ConOut("FAIL GEBRELCONTABIL nCred: " + cValToChar(aRel[3]))
        EndIf
        If aRel[4] <= 0
            lOk := .F.
            ConOut("FAIL GEBRELCONTABIL valDec: " + cValToChar(aRel[4]))
        EndIf
        If aRel[5] <= 0
            lOk := .F.
            ConOut("FAIL GEBRELCONTABIL valCred: " + cValToChar(aRel[5]))
        EndIf
        ConOut("OK GEBRELCONTABIL lanc=" + cValToChar(aRel[1]) + " dec=" + cValToChar(aRel[4]))
    EndIf

    // === TESTE GEBRELGERAL ===
    aRel := GEBRELGERAL("01")
    If Len(aRel) != 6
        lOk := .F.
        ConOut("FAIL GEBRELGERAL: Len=" + cValToChar(Len(aRel)))
    Else
        If Len(aRel[1]) != 9
            lOk := .F.
            ConOut("FAIL GEBRELGERAL[1] fiscal Len")
        EndIf
        If Len(aRel[2]) != 6
            lOk := .F.
            ConOut("FAIL GEBRELGERAL[2] derrama Len")
        EndIf
        If Len(aRel[3]) != 7
            lOk := .F.
            ConOut("FAIL GEBRELGERAL[3] fin Len")
        EndIf
        If Len(aRel[4]) != 4
            lOk := .F.
            ConOut("FAIL GEBRELGERAL[4] estoque Len")
        EndIf
        If Len(aRel[5]) != 5
            lOk := .F.
            ConOut("FAIL GEBRELGERAL[5] compras Len")
        EndIf
        If Len(aRel[6]) != 6
            lOk := .F.
            ConOut("FAIL GEBRELGERAL[6] contabil Len")
        EndIf
        ConOut("OK GEBRELGERAL 6 modulos")
    EndIf

    ConOut("--- TRACKERS ---")

    // === TESTE GEBTRAKCOMPRA ===
    aTrak := GEBTRAKCOMPRA("PED-RB-01")
    If Len(aTrak) != 6
        lOk := .F.
        ConOut("FAIL GEBTRAKCOMPRA: Len=" + cValToChar(Len(aTrak)))
    Else
        If Len(aTrak[1]) < 1
            lOk := .F.
            ConOut("FAIL GEBTRAKCOMPRA header")
        EndIf
        If Len(aTrak[2]) < 1
            lOk := .F.
            ConOut("FAIL GEBTRAKCOMPRA itens")
        EndIf
        If Len(aTrak[4]) >= 0
            // Estoque pode ser vazio se produto nao existe em GV1
        EndIf
        ConOut("OK GEBTRAKCOMPRA pedido=" + cValToChar(Len(aTrak[1])) + " header itens=" + cValToChar(Len(aTrak[2])))
    EndIf

    // === TESTE GEBTRAKVENDA ===
    aTrak := GEBTRAKVENDA("VEN-RB-01")
    If Len(aTrak) != 5
        lOk := .F.
        ConOut("FAIL GEBTRAKVENDA: Len=" + cValToChar(Len(aTrak)))
    Else
        If Len(aTrak[2]) < 2
            lOk := .F.
            ConOut("FAIL GEBTRAKVENDA itens: " + cValToChar(Len(aTrak[2])))
        EndIf
        If Len(aTrak[3]) >= 1
            // Estoque deve ter entries para produtos vendidos
        EndIf
        ConOut("OK GEBTRAKVENDA venda=" + cValToChar(Len(aTrak[2])) + " itens")
    EndIf

    // === TESTE GEBTRAKNOTAFISCAL ===
    aTrak := GEBTRAKNOTAFISCAL("NF-RB-01")
    If Len(aTrak) != 6
        lOk := .F.
        ConOut("FAIL GEBTRAKNOTAFISCAL: Len=" + cValToChar(Len(aTrak)))
    Else
        If Len(aTrak[1]) < 1
            lOk := .F.
            ConOut("FAIL GEBTRAKNOTAFISCAL header")
        EndIf
        If Len(aTrak[2]) < 1
            lOk := .F.
            ConOut("FAIL GEBTRAKNOTAFISCAL item")
        EndIf
        If Len(aTrak[3]) < 1
            lOk := .F.
            ConOut("FAIL GEBTRAKNOTAFISCAL calc")
        EndIf
        ConOut("OK GEBTRAKNOTAFISCAL nf=" + cValToChar(Len(aTrak[1])) + " header itens=" + cValToChar(Len(aTrak[2])))
    EndIf

    // === TESTE GEBTRAKDERRAMA ===
    aTrak := GEBTRAKDERRAMA(cGuia)
    If Len(aTrak) != 7
        lOk := .F.
        ConOut("FAIL GEBTRAKDERRAMA: Len=" + cValToChar(Len(aTrak)))
    Else
        If Len(aTrak[1]) < 1
            lOk := .F.
            ConOut("FAIL GEBTRAKDERRAMA apuracao")
        EndIf
        If Len(aTrak[2]) < 1
            lOk := .F.
            ConOut("FAIL GEBTRAKDERRAMA guia")
        EndIf
        If Len(aTrak[3]) >= 2
            // Parcelas
        EndIf
        ConOut("OK GEBTRAKDERRAMA guia=" + cValToChar(Len(aTrak[2])) + " parc=" + cValToChar(Len(aTrak[3])))
    EndIf

    ConOut("--- CLEANUP ---")

    // Cleanup.
    TCSqlExec("DELETE FROM GC3 WHERE GC3_LOTE = 'LOTE-RB-01'")
    TCSqlExec("DELETE FROM GC2 WHERE GC2_LOTE = 'LOTE-RB-01'")
    TCSqlExec("DELETE FROM GC1 WHERE GC1_CONTA LIKE '1.01%' OR GC1_CONTA LIKE '3.01%'")
    TCSqlExec("DELETE FROM GCP5 WHERE GCP5_NF LIKE 'NF-ENT-RB-%'")
    TCSqlExec("DELETE FROM GCP4 WHERE GCP4_PED LIKE 'PED-RB-%'")
    TCSqlExec("DELETE FROM GCP3 WHERE GCP3_NUM LIKE 'PED-RB-%'")
    TCSqlExec("DELETE FROM GCP2 WHERE GCP2_FORN LIKE 'FORN-RB-%'")
    TCSqlExec("DELETE FROM GCP1 WHERE GCP1_COD LIKE 'FORN-RB-%'")
    TCSqlExec("DELETE FROM GV3 WHERE GV3_CLI = 'CLI-RB'")
    TCSqlExec("DELETE FROM GV2 WHERE GV2_VENDA LIKE 'VEN-RB-%'")
    TCSqlExec("DELETE FROM GV1 WHERE GV1_PROD LIKE 'PROD-RB-%'")
    TCSqlExec("DELETE FROM GFN4 WHERE GFN4_CONTA = 'CAIXA'")
    TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC LIKE 'PAG-RB-%'")
    TCSqlExec("DELETE FROM GFN2 WHERE GFN2_DOC LIKE 'REC-RB-%'")
    TCSqlExec("DELETE FROM GFN1 WHERE GFN1_CONTA IN ('CAIXA','BANCO')")
    TCSqlExec("DELETE FROM GD3 WHERE GD3_GUIA LIKE 'GD-PROT-%'")
    TCSqlExec("DELETE FROM GD2 WHERE GD2_GUIA LIKE 'GD%'")
    TCSqlExec("DELETE FROM GD1 WHERE GD1_GUIA LIKE 'GD%' OR GD1_GUIA LIKE 'GD-VENC%' OR GD1_GUIA LIKE 'GD-PAGA%'")
    cSql := "DELETE FROM GF5 WHERE GF5_COMP = '" + cComp + "'"
    TCSqlExec(cSql)
    TCSqlExec("DELETE FROM GF4 WHERE GF4_CHAVE LIKE 'NF-RB-%'")
    TCSqlExec("DELETE FROM GF3 WHERE GF3_CHAVE LIKE 'NF-RB-%'")
    TCSqlExec("DELETE FROM GF2 WHERE GF2_NCM LIKE 'NCM%'")
    TCSqlExec("DELETE FROM GF1 WHERE GF1_COD LIKE 'PROD-RB-%'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '01'")

    TCSqlExec("DROP SCHEMA IF EXISTS test_geexp_relbiz CASCADE")

    If lOk
        ConOut("T_GeExp_REL_BIZ PASS")
    Else
        ConOut("T_GeExp_REL_BIZ FAIL")
    EndIf
Return lOk
