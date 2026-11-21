#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_CAD.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCOM_FOR.prw"
#include "../src/GEBCOM_PED.prw"
#include "../src/GEBCOM_ENT.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBCTB_DIR.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBEXP_CTX.prw"
#include "../src/GEBEXP_REL_BIZ.prw"
#include "../src/GEBEXP_TRAK.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBCTX.prw"
#include "../src/GEBEST.prw"
#include "../src/GEBFNX.prw"
#include "../src/GEBFAT.prw"
#include "../src/GEBTEF.prw"
#include "../src/GEBLOJ.prw"
#include "../src/GEBDFE_XML.prw"
#include "../src/GEBDFE_WS.prw"
#include "../src/GEBDFE_MUN.prw"
#include "../src/GEBDFE_IE.prw"
#include "../src/GEBDFE_CAD.prw"
#include "../src/GEBDFE.prw"
#include "../src/GEBDFE_QR.prw"
#include "../src/GEBDFE_DANFE.prw"
#include "../src/GEBLOJ_CAD.prw"
#include "../src/GEBLOJ_OPE.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GeExp_MASSA
    Teste de massa multi-empresa GEB_EXPANSAO (Task 8, redesign da Fase 2).
    Cria 3 empresas REAIS (schemas Postgres independentes emp_<cod>, via
    GEBDBProvisionaEmpresa) em vez de simular multiplas empresas com uma
    coluna EMPRESA sombra dentro de um unico schema compartilhado (design
    aposentado -- ver docs/superpowers/plans/2026-09-24-geban-entrypoint-
    postgres-bootstrap.md e o Task 8 brief). Para cada empresa, dentro do
    seu proprio schema (GEBDBSetTenant), roda de ponta a ponta: cadastro
    de produtos/fornecedor/contas, emissao de 20 NFs, apuracao do mes,
    geracao de 5 guias derrama, baixa de parte delas, compra de 10
    pedidos com entrada, 10 lancamentos contabeis diretos, verificacao de
    GEBRELGERAL e de 1-2 trackers (GEBTRAKCOMPRA/NOTAFISCAL/DERRAMA).
    Nenhum INSERT/WHERE usa mais a coluna EMPRESA -- o proprio schema e' o
    isolamento (mesmo mecanismo usado pelo resto do sistema agora).
    Cleanup via DROP SCHEMA por empresa (mais forte que o antigo DELETE
    por EMPRESA: remove literalmente todas as tabelas do tenant).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GeExp_MASSA()
    Local lOk := .T.
    Local aRel := {}
    Local aTrak := {}
    Local cEmp := ""
    Local cNome := ""
    Local cComp := ""
    Local cData := ""
    Local cGuia := ""
    Local cSql := ""
    Local nI := 0
    Local cChave := ""
    Local cPed := ""
    Local cNF := ""
    Local cLote := ""
    Local nIdx := 0
    Local nBaixar := 0
    Local aEmps := {"gxm1", "gxm2", "gxm3"}
    Local aNomes := {"Empresa Massa GXM1", "Empresa Massa GXM2", "Empresa Massa GXM3"}
    Local aBaixaQtd := {4, 3, 3}

    If !GEBDBConecta()
        ConOut("T_GeExp_MASSA: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")

    // Pre-cleanup (rerun limpo): dropa os schemas das 3 empresas de teste
    // e remove os cadastros de GE1 (catalogo, schema public) de uma
    // execucao anterior que tenha falhado no meio.
    For nIdx := 1 To Len(aEmps)
        cEmp := aEmps[nIdx]
        TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cEmp + " CASCADE")
        TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cEmp + "'")
    Next

    If !GEBDBProvisionaCatalogo()
        lOk := .F.
        ConOut("FAIL GEBDBProvisionaCatalogo")
    EndIf

    cComp := SubStr(DToS(Date()), 1, 6)
    cData := DToS(Date())

    // ============================================================
    // FASE 1: provisiona TODOS os schemas + semeia cadastros estaticos
    // (GE4/GF1/GF2/GCP1/GFN1/GC1/GC4) das 3 empresas ANTES de chamar
    // qualquer funcao de negocio que use workarea (GEBFAPU/GEBDBAI/
    // GEBRELGERAL/GEBTRAK*, mais abaixo na Fase 2). Achado empirico
    // desta task (reproduzido contra o Postgres real do servidor), causa
    // raiz rastreada no codigo Go do runtime AdvPP (~/Projetos/AdvPP):
    //   1. DBCLOSEAREA() e' NO-OP neste runtime (pkg/vm/natives.go:1108)
    //      -- nao fecha nada de verdade; a alias "fechada" continua
    //      sendo a alias corrente do processo.
    //   2. GETAREA() retorna essa alias (ainda corrente) como string.
    //   3. RESTAREA(cAlias), mais tarde, chama SelectArea(cAlias), que
    //      executa um SELECT * FROM <alias> NOVO sob o search_path que
    //      estiver ativo NAQUELE MOMENTO -- nao o search_path que
    //      estava ativo quando GetArea() foi originalmente chamado.
    //   4. Concretamente aqui: GEBFAPU() (empresa N) deixa GF5 como
    //      alias "corrente" sem a fechar de fato. Ao provisionar a
    //      empresa N+1, GENMIGEmpresa() faz seu proprio round-trip
    //      GetArea()/RestArea("GF5") -- so' que agora sob o search_path
    //      da empresa N+1 (onde GF5 ainda nao foi criada), produzindo
    //      "Error: table GF5 not found", apesar de GENMIGEmpresa() nao
    //      ter nada a ver com GF5. Mesmo mecanismo do sintoma com GCP1
    //      documentado em T_GeExp_WEB.prw e T_GEBAN_LOGIN_REAL.
    // Mitigado aqui separando estritamente as duas fases: toda CRIACAO
    // de schema/tabela primeiro (sem workarea nenhuma), toda
    // LEITURA/ESCRITA via workarea depois (Fase 2), uma vez que todos
    // os schemas ja existem e nenhuma outra criacao de schema vai mais
    // acontecer no meio. Bug de runtime AdvPP preexistente, fora de
    // escopo corrigir aqui (ver Pendencias do plano para o risco de
    // producao futura).
    // ============================================================
    For nIdx := 1 To Len(aEmps)
        cEmp := aEmps[nIdx]
        cNome := aNomes[nIdx]

        If lOk .AND. !GEBDBProvisionaEmpresa(cEmp, cNome)
            lOk := .F.
            ConOut("FAIL GEBDBProvisionaEmpresa(" + cEmp + ")")
        EndIf

        If !lOk
            Exit
        EndIf

        // GEBDBProvisionaEmpresa() ja deixa o search_path em
        // emp_<cEmp>,public; reafirma explicitamente por clareza.
        GEBDBSetTenant(cEmp)
        // GBAUDINIC() so' faz DDL condicional via TCSqlExec/TCSqlQuery
        // (GEBDBTableEnsure), sem workarea -- seguro na Fase 1. Precisa
        // rodar aqui porque CTBLAN() (GENUC_MNT.prw:204, usado por
        // GEBDBAI() na Fase 2) chama GBAUDLOG() incondicionalmente, que
        // por sua vez grava direto em GEI_AUDIT sem checar se a tabela
        // existe.
        GBAUDINIC()

        // --- SETUP: parametros GE4 (por-tenant desde o redesign) ---
        TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'EMISSAO', 'ONLINE_FILA')")
        TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'APURACAO', 'AUTO')")
        TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'PERMITE_DIRETA', 'S')")

        // --- SETUP: produtos, fornecedor, contas ---
        TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'PROD-" + cEmp + "-01', 'NCM-M8', 'Produto Massa " + cEmp + "')")
        TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'PROD-" + cEmp + "-02', 'NCM-M8', 'Produto Massa " + cEmp + " 02')")
        TCSqlExec("INSERT INTO GCP1 (D_E_L_E_T_, GCP1_FILIAL, GCP1_COD, GCP1_NOME, GCP1_CNPJ) VALUES (' ', '      ', 'FORN-" + cEmp + "', 'Fornecedor Massa " + cEmp + "', '')")
        TCSqlExec("INSERT INTO GFN1 (D_E_L_E_T_, GFN1_FILIAL, GFN1_CONTA, GFN1_NOME, GFN1_SALDO) VALUES (' ', '      ', 'CAIXA-" + cEmp + "', 'Caixa " + cEmp + "', 1000.00)")
        TCSqlExec("INSERT INTO GC1 (D_E_L_E_T_, GC1_FILIAL, GC1_CONTA, GC1_NOME, GC1_TIPO) VALUES (' ', '      ', '1.01.00" + cEmp + "', 'Caixa " + cEmp + "', 'A')")
        TCSqlExec("INSERT INTO GC1 (D_E_L_E_T_, GC1_FILIAL, GC1_CONTA, GC1_NOME, GC1_TIPO) VALUES (' ', '      ', '3.01.00" + cEmp + "', 'Receita " + cEmp + "', 'R')")
        TCSqlExec("INSERT INTO GC1 (D_E_L_E_T_, GC1_FILIAL, GC1_CONTA, GC1_NOME, GC1_TIPO) VALUES (' ', '      ', '4.01.00" + cEmp + "', 'Custo " + cEmp + "', 'A')")

        // Aliquota (sem EMPRESA no DDL atual).
        TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'NCM-M8', 10, 5, '20200101', '20301231')")

        // GC4: lancamento direto e evento padrao.
        TCSqlExec("INSERT INTO GC4 (D_E_L_E_T_, GC4_FILIAL, GC4_EVENTO, GC4_CTADEB, GC4_CTACRED, GC4_PERM) VALUES (' ', '      ', 'LANC_DIRETO', '1.01.00" + cEmp + "', '3.01.00" + cEmp + "', 'S')")
        TCSqlExec("INSERT INTO GC4 (D_E_L_E_T_, GC4_FILIAL, GC4_EVENTO, GC4_CTADEB, GC4_CTACRED, GC4_PERM) VALUES (' ', '      ', 'PADRAO-" + cEmp + "', '1.01.00" + cEmp + "', '3.01.00" + cEmp + "', 'S')")

        // --- EMITE 20 notas (raw SQL, nao usa workarea) ---
        ConOut("--- " + cEmp + ": EMITINDO 20 NFs ---")
        For nI := 1 To 20
            cChave := "NF-" + cEmp + "-" + cValToChar(nI)
            cSql := "INSERT INTO GF3 (D_E_L_E_T_, GF3_FILIAL, GF3_CHAVE, GF3_TIPO, GF3_STATUS, GF3_BASE, GF3_IBS, GF3_CBS, GF3_EMIS) VALUES (' ', '      ', '" + cChave + "', 'NFE', 'AUTORIZADA', 100, 10, 5, '" + cData + "')"
            TCSqlExec(cSql)
            cSql := "INSERT INTO GF4 (D_E_L_E_T_, GF4_FILIAL, GF4_CHAVE, GF4_ITEM, GF4_PROD, GF4_QTD, GF4_PRECO, GF4_BASE, GF4_IBS, GF4_CBS) VALUES (' ', '      ', '" + cChave + "', '001', 'PROD-" + cEmp + "-01', 1, 100, 100, 10, 5)"
            TCSqlExec(cSql)
            // CTBLAN simulado: grava GC2 + GC3.
            cLote := "L-FISC-" + cEmp + "-" + cValToChar(nI)
            cSql := "INSERT INTO GC2 (D_E_L_E_T_, GC2_FILIAL, GC2_LOTE, GC2_ORIGEM, GC2_VALOR, GC2_DATA, GC2_COMP, GC2_TIPO) VALUES (' ', '      ', '" + cLote + "', '" + cChave + "', 115, '" + cData + "', '" + cComp + "', 'AUTO')"
            TCSqlExec(cSql)
            cSql := "INSERT INTO GC3 (D_E_L_E_T_, GC3_FILIAL, GC3_LOTE, GC3_DC, GC3_CONTA, GC3_VALOR) VALUES (' ', '      ', '" + cLote + "', 'D', '1.01.00" + cEmp + "', 115)"
            TCSqlExec(cSql)
            cSql := "INSERT INTO GC3 (D_E_L_E_T_, GC3_FILIAL, GC3_LOTE, GC3_DC, GC3_CONTA, GC3_VALOR) VALUES (' ', '      ', '" + cLote + "', 'C', '3.01.00" + cEmp + "', 115)"
            TCSqlExec(cSql)
        Next

        // --- GERA 5 guias ---
        ConOut("--- " + cEmp + ": GERANDO 5 GUIAS ---")
        For nI := 1 To 5
            cGuia := "GD-" + cEmp + "-" + cValToChar(nI)
            cSql := "INSERT INTO GD1 (D_E_L_E_T_, GD1_FILIAL, GD1_GUIA, GD1_COMP, GD1_VALOR, GD1_JUROS, GD1_MULTA, GD1_TOTAL, GD1_STATUS) VALUES (' ', '      ', '" + cGuia + "', '" + cComp + "', 100, 0, 0, 100, 'ABERTA')"
            TCSqlExec(cSql)
        Next

        // --- COMPRAS: 10 pedidos com entrada e CTBLAN ---
        ConOut("--- " + cEmp + ": COMPRAS 10 PEDIDOS ---")
        For nI := 1 To 10
            cPed := "PED-" + cEmp + "-" + cValToChar(nI)
            cNF := "NF-ENT-" + cEmp + "-" + cValToChar(nI)
            cSql := "INSERT INTO GCP3 (D_E_L_E_T_, GCP3_FILIAL, GCP3_NUM, GCP3_FORN, GCP3_STATUS) VALUES (' ', '      ', '" + cPed + "', 'FORN-" + cEmp + "', 'RECEBIDO')"
            TCSqlExec(cSql)
            cSql := "INSERT INTO GCP4 (D_E_L_E_T_, GCP4_FILIAL, GCP4_PED, GCP4_PROD, GCP4_QTD, GCP4_PRECO) VALUES (' ', '      ', '" + cPed + "', 'PROD-" + cEmp + "-01', 2, 50)"
            TCSqlExec(cSql)
            cSql := "INSERT INTO GCP5 (D_E_L_E_T_, GCP5_FILIAL, GCP5_NF, GCP5_PED, GCP5_STATUS) VALUES (' ', '      ', '" + cNF + "', '" + cPed + "', 'RECEBIDA')"
            TCSqlExec(cSql)
            // Titulo a pagar (GFN3).
            cSql := "INSERT INTO GFN3 (D_E_L_E_T_, GFN3_FILIAL, GFN3_DOC, GFN3_FORN, GFN3_VALOR, GFN3_SALDO, GFN3_VENC, GFN3_STATUS) VALUES (' ', '      ', '" + cNF + "', 'FORN-" + cEmp + "', 100, 100, '20261231', 'ABERTO')"
            TCSqlExec(cSql)
            // CTBLAN simulado para entrada.
            cLote := "L-COMPR-" + cEmp + "-" + cValToChar(nI)
            cSql := "INSERT INTO GC2 (D_E_L_E_T_, GC2_FILIAL, GC2_LOTE, GC2_ORIGEM, GC2_VALOR, GC2_DATA, GC2_COMP, GC2_TIPO) VALUES (' ', '      ', '" + cLote + "', '" + cNF + "', 100, '" + cData + "', '" + cComp + "', 'AUTO')"
            TCSqlExec(cSql)
            cSql := "INSERT INTO GC3 (D_E_L_E_T_, GC3_FILIAL, GC3_LOTE, GC3_DC, GC3_CONTA, GC3_VALOR) VALUES (' ', '      ', '" + cLote + "', 'D', '4.01.00" + cEmp + "', 100)"
            TCSqlExec(cSql)
            cSql := "INSERT INTO GC3 (D_E_L_E_T_, GC3_FILIAL, GC3_LOTE, GC3_DC, GC3_CONTA, GC3_VALOR) VALUES (' ', '      ', '" + cLote + "', 'C', '2.01.00" + cEmp + "', 100)"
            TCSqlExec(cSql)
            // Movimentacao estoque GV1.
            cSql := "INSERT INTO GV1 (D_E_L_E_T_, GV1_FILIAL, GV1_PROD, GV1_SALDO, GV1_MIN) VALUES (' ', '      ', 'PROD-" + cEmp + "-01', 100, 10)"
            TCSqlExec(cSql)
        Next

        // --- LANCAMENTOS CONTABIL DIRETO: 10 ---
        ConOut("--- " + cEmp + ": LANCAMENTOS CONTABIL DIRETO ---")
        For nI := 1 To 10
            cLote := "DIR-" + cEmp + "-" + cValToChar(nI)
            cSql := "INSERT INTO GC2 (D_E_L_E_T_, GC2_FILIAL, GC2_LOTE, GC2_ORIGEM, GC2_VALOR, GC2_DATA, GC2_COMP, GC2_TIPO) VALUES (' ', '      ', '" + cLote + "', 'DIRETO-" + cEmp + "', 50, '" + cData + "', '" + cComp + "', 'DIRETO')"
            TCSqlExec(cSql)
            cSql := "INSERT INTO GC3 (D_E_L_E_T_, GC3_FILIAL, GC3_LOTE, GC3_DC, GC3_CONTA, GC3_VALOR) VALUES (' ', '      ', '" + cLote + "', 'D', '1.01.00" + cEmp + "', 50)"
            TCSqlExec(cSql)
            cSql := "INSERT INTO GC3 (D_E_L_E_T_, GC3_FILIAL, GC3_LOTE, GC3_DC, GC3_CONTA, GC3_VALOR) VALUES (' ', '      ', '" + cLote + "', 'C', '3.01.00" + cEmp + "', 50)"
            TCSqlExec(cSql)
        Next

    Next

    // ============================================================
    // FASE 2: agora que TODOS os schemas/tabelas das 3 empresas ja
    // existem (nenhuma outra CREATE SCHEMA/CREATE TABLE vai acontecer
    // depois deste ponto), roda as funcoes de negocio que usam
    // workarea (GEBFAPU, GEBDBAI, GEBRELGERAL, GEBTRAK*) -- ver nota na
    // Fase 1 sobre por que essa separacao e' necessaria (DBCLOSEAREA
    // no-op + RestArea relendo a tabela sob o search_path errado).
    // ============================================================
    For nIdx := 1 To Len(aEmps)
        cEmp := aEmps[nIdx]

        If !lOk
            Exit
        EndIf

        GEBDBSetTenant(cEmp)

        // --- APURA mes (por-schema: cada empresa apura so a
        // competencia do proprio schema) ---
        ConOut("--- " + cEmp + ": APURACAO " + cComp + " ---")
        If !GEBFAPU(cComp)
            lOk := .F.
            ConOut("FAIL GEBFAPU[" + cEmp + "]")
        EndIf

        // --- BAIXA algumas guias desta empresa (10 no total entre as
        // 3 empresas, distribuicao 4/3/3 -- mesmo total do design
        // original, agora sem precisar alternar entre schemas). Roda
        // POR ULTIMO em cada empresa (depois de todo INSERT bruto em
        // GC2/GC3 na Fase 1) por um achado empirico desta task,
        // tambem rastreado no codigo Go do runtime AdvPP
        // (~/Projetos/AdvPP): GEBDBAI() grava em GC2/GC3 via workarea
        // (RecLock+DbAppend, dentro de CTBLAN()/GENUC_MNT.prw:204).
        // RemoteSQLEngine.Append (pkg/db/remote_engine.go, ~linhas
        // 274-318) calcula o proximo R_E_C_N_O_ como (maior valor na
        // copia EM MEMORIA carregada no ultimo SelectArea) + 1 e
        // insere esse valor EXPLICITAMENTE -- isso nunca avanca a
        // sequence IDENTITY real do Postgres para essa coluna. Um
        // INSERT bruto (via TCSqlExec) subsequente na mesma tabela USA
        // a sequence, que ficou para tras, e colide com um
        // R_E_C_N_O_ ja reivindicado pela camada de workarea
        // ("duplicate key value violates unique constraint gc2_pkey").
        // Mitigado mantendo todo INSERT bruto em GC2/GC3 (Fase 1)
        // estritamente ANTES do unico ponto que grava nessas tabelas
        // via workarea (GEBDBAI, aqui). Bug de runtime AdvPP
        // preexistente, fora de escopo corrigir aqui (ver Pendencias
        // do plano para o risco de producao futura).
        nBaixar := aBaixaQtd[nIdx]
        ConOut("--- " + cEmp + ": BAIXANDO " + cValToChar(nBaixar) + " GUIAS ---")
        For nI := 1 To nBaixar
            cGuia := "GD-" + cEmp + "-" + cValToChar(nI)
            If !GEBDBAI(cGuia)
                lOk := .F.
                ConOut("FAIL GEBDBAI[" + cEmp + "] guia=" + cGuia)
            EndIf
        Next

        // --- VERIFICA GEBRELGERAL desta empresa ---
        ConOut("--- " + cEmp + ": VERIFICACAO GEBRELGERAL ---")
        aRel := GEBRELGERAL(cEmp)
        If Len(aRel) != 6
            lOk := .F.
            ConOut("FAIL GEBRELGERAL[" + cEmp + "] len=" + cValToChar(Len(aRel)))
        Else
            // Fiscal: 20 notas, base > 0.
            If aRel[1][1] != 20
                lOk := .F.
                ConOut("FAIL GEBRELFISCAL[" + cEmp + "] nNotas=" + cValToChar(aRel[1][1]))
            EndIf
            If aRel[1][2] <= 0
                lOk := .F.
                ConOut("FAIL GEBRELFISCAL[" + cEmp + "] nBase<=0")
            EndIf
            // Derrama: 5 guias semeadas + a guia GD<comp> que a apuracao gera.
            If aRel[2][1] != 6
                lOk := .F.
                ConOut("FAIL GEBRELDERRAMA[" + cEmp + "] nGuias=" + cValToChar(aRel[2][1]))
            EndIf
            // Compras: 1 forn, 10 pedidos, 10 recebidos.
            If aRel[5][1] < 1
                lOk := .F.
                ConOut("FAIL GEBRELCOMPRAS[" + cEmp + "] nForn=" + cValToChar(aRel[5][1]))
            EndIf
            If aRel[5][2] != 10
                lOk := .F.
                ConOut("FAIL GEBRELCOMPRAS[" + cEmp + "] nPed=" + cValToChar(aRel[5][2]))
            EndIf
            If aRel[5][3] != 10
                lOk := .F.
                ConOut("FAIL GEBRELCOMPRAS[" + cEmp + "] nRecb=" + cValToChar(aRel[5][3]))
            EndIf
            // Financeiro: 1 conta Caixa.
            If aRel[3][1] < 1
                lOk := .F.
                ConOut("FAIL GEBRELFIN[" + cEmp + "] nContas=" + cValToChar(aRel[3][1]))
            EndIf
            ConOut("OK GEBRELGERAL[" + cEmp + "] notas=" + cValToChar(aRel[1][1]) + " guias=" + cValToChar(aRel[2][1]) + " ped=" + cValToChar(aRel[5][2]))
        EndIf

        // --- TRACKERS: mesma distribuicao do design original (empresa
        // 1 e 3 recebem tracker de compra+NF, empresa 2 recebe tracker
        // de guia derrama) ---
        If nIdx == 1 .Or. nIdx == 3
            aTrak := GEBTRAKCOMPRA("PED-" + cEmp + "-1")
            If Len(aTrak) != 6
                lOk := .F.
                ConOut("FAIL GEBTRAKCOMPRA[" + cEmp + "] len=" + cValToChar(Len(aTrak)))
            ElseIf Len(aTrak[1]) < 1 .Or. Len(aTrak[2]) < 1 .Or. Len(aTrak[3]) < 1
                lOk := .F.
                ConOut("FAIL GEBTRAKCOMPRA[" + cEmp + "] dados incompletos")
            Else
                ConOut("OK GEBTRAKCOMPRA[" + cEmp + "] header=" + cValToChar(Len(aTrak[1])) + " itens=" + cValToChar(Len(aTrak[2])) + " ent=" + cValToChar(Len(aTrak[3])))
            EndIf

            aTrak := GEBTRAKNOTAFISCAL("NF-" + cEmp + "-1")
            If Len(aTrak) != 6
                lOk := .F.
                ConOut("FAIL GEBTRAKNOTAFISCAL[" + cEmp + "] len=" + cValToChar(Len(aTrak)))
            ElseIf Len(aTrak[1]) < 1 .Or. Len(aTrak[2]) < 1
                lOk := .F.
                ConOut("FAIL GEBTRAKNOTAFISCAL[" + cEmp + "] dados incompletos")
            Else
                ConOut("OK GEBTRAKNOTAFISCAL[" + cEmp + "] header=" + cValToChar(Len(aTrak[1])) + " itens=" + cValToChar(Len(aTrak[2])))
            EndIf
        Else
            aTrak := GEBTRAKDERRAMA("GD-" + cEmp + "-1")
            If Len(aTrak) != 7
                lOk := .F.
                ConOut("FAIL GEBTRAKDERRAMA[" + cEmp + "] len=" + cValToChar(Len(aTrak)))
            ElseIf Len(aTrak[2]) < 1
                lOk := .F.
                ConOut("FAIL GEBTRAKDERRAMA[" + cEmp + "] guia vazia")
            Else
                ConOut("OK GEBTRAKDERRAMA[" + cEmp + "] guia=" + cValToChar(Len(aTrak[2])) + " parc=" + cValToChar(Len(aTrak[3])))
            EndIf
        EndIf
    Next

    // ============================================================
    // CLEANUP: DROP SCHEMA por empresa (mais forte que DELETE por
    // EMPRESA -- remove de fato todas as tabelas do tenant).
    // ============================================================
    ConOut("--- CLEANUP ---")
    TCSqlExec("SET search_path TO public")
    For nIdx := 1 To Len(aEmps)
        cEmp := aEmps[nIdx]
        TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cEmp + " CASCADE")
        TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cEmp + "'")
    Next

    // ============================================================
    // RERUN CHECK: schema de cada empresa realmente nao existe mais
    // (equivalente ao antigo "tudo zerado", agora no nivel de schema).
    // ============================================================
    For nIdx := 1 To Len(aEmps)
        cEmp := aEmps[nIdx]
        If GEBDBSchemaExists(cEmp)
            lOk := .F.
            ConOut("FAIL cleanup: schema emp_" + cEmp + " ainda existe")
        EndIf
    Next

    If lOk
        ConOut("T_GeExp_MASSA PASS")
    Else
        ConOut("T_GeExp_MASSA FAIL")
    EndIf
Return lOk
