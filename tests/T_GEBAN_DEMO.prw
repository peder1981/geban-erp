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
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
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
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"
#include "../src/GEBDEMO.prw"

/*/{Protheus.doc} T_GEBAN_DEMO
    Health-check ponta a ponta do ambiente de demonstracao (empresa 99,
    schema emp_99 do geban_test, semeado por tests/local/seed_full.prw via
    `scripts/geban-demo.sh seed`). READ-ONLY: nao grava nem apaga nada em
    emp_99 — so' le tabelas e faz UM probe barato na SEFAZ emulada
    (consStatServ via GEBDFESTATSVC("55"), que nao altera estado local nem
    no emulador).

    Antes do probe chama GEBDEMOENSURE() (GET :18768/ensure no watchdog,
    fire-and-forget) e tenta de novo ate 3x com Sleep — no modo
    sob-demanda os emuladores podem estar frios; o watchdog sobe tudo, so'
    que leva alguns segundos. O watchdog em si e' OPCIONAL para este
    teste: com as units de emulador sempre-online (ou qualquer outro meio
    de subir :18766) o teste passa do mesmo jeito.

    Periferico virtual: nao da' para falar WebSocket ESC/POS de dentro do
    AdvPL; o assert cobre o schema (tabela GEP_PERIFERICOS provisionada) e
    a geracao do cupom PNG em periferico/saidas/ fica coberta manualmente
    no roteiro (docs/demo-roteiro.md).

    Exige o ambiente demo semeado: sem emp_99 ou sem a massa DEM-* o teste
    falha com mensagem clara — nao e' um teste de unidade.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 05/12/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBAN_DEMO()
    Local lOk := .T.
    Local lTmp := .F.
    Local aH := {}
    Local aR := {}
    Local cSes := ""
    Local nI := 0
    Local aFormas := {"DINHEIRO", "PIX", "DEBITO", "CREDITO", "FIADO", "VALE"}

    If !GEBDBConecta()
        ConOut("T_GEBAN_DEMO FAIL (GEBDBConecta)")
        Return .F.
    EndIf

    // Ambiente demo: empresa 99 provisionada e com a massa semeada.
    If !GEBDBSchemaExists("99")
        ConOut("T_GEBAN_DEMO FAIL (schema emp_99 inexistente — rode scripts/geban-demo.sh up + seed)")
        Return .F.
    EndIf
    If !GEBDBSetTenant("99")
        ConOut("T_GEBAN_DEMO FAIL (GEBDBSetTenant 99)")
        Return .F.
    EndIf

    // ===== Nucleo / cadastros (prefixo DEM) =====
    lOk := Chk(lOk, "usuarios DEM_", HDM_CNT("public.GE2_EMP", "LEFT(GE2_EMP_USUARIO, 4) = 'DEM_' AND GE2_EMP_EMPRESA = '99' AND D_E_L_E_T_ = ' '") >= 8)
    lOk := Chk(lOk, "produtos DEM-P", HDM_CNT("GF1", "LEFT(GF1_COD, 5) = 'DEM-P' AND D_E_L_E_T_ = ' '") >= 60)
    lOk := Chk(lOk, "clientes DEM-C", HDM_CNT("GFT1", "LEFT(GFT1_COD, 5) = 'DEM-C' AND D_E_L_E_T_ = ' '") >= 40)
    lOk := Chk(lOk, "fornecedores DEM-F", HDM_CNT("GCP1", "LEFT(GCP1_COD, 5) = 'DEM-F' AND D_E_L_E_T_ = ' '") >= 15)
    lOk := Chk(lOk, "plano de contas DEM-", HDM_CNT("GC1", "LEFT(GC1_CONTA, 4) = 'DEM-' AND D_E_L_E_T_ = ' '") >= 10)

    // ===== Fiscal: NF-e/NFC-e emitidas, cancelamentos, CC-e, recebidas, EFD =====
    lOk := Chk(lOk, "NF-e 55 autorizadas", HDM_CNT("GDF5", "GDF5_MOD = '55' AND GDF5_STATUS = 'AUTORIZADA' AND D_E_L_E_T_ = ' '") >= 37)
    lOk := Chk(lOk, "NF-e 55 canceladas", HDM_CNT("GDF5", "GDF5_MOD = '55' AND GDF5_STATUS = 'CANCELADA' AND D_E_L_E_T_ = ' '") >= 3)
    lOk := Chk(lOk, "NFC-e 65 autorizadas", HDM_CNT("GDF5", "GDF5_MOD = '65' AND GDF5_STATUS = 'AUTORIZADA' AND D_E_L_E_T_ = ' '") >= 15)
    lOk := Chk(lOk, "evento CC-e", HDM_CNT("GDF6", "GDF6_TIPO = 'CCE' AND D_E_L_E_T_ = ' '") >= 1)
    lOk := Chk(lOk, "NF-e recebidas (distribuicao)", HDM_CNT("GDFE", "GDFE_SIT = 'AUTORIZADA' AND GDFE_IMPORT <> '' AND D_E_L_E_T_ = ' '") >= 8)
    aH := TCSqlQuery("SELECT GDFG_COMP AS C, length(GDFG_ARQ) AS L FROM GDFG WHERE D_E_L_E_T_ = ' ' ORDER BY GDFG_COMP DESC LIMIT 1")
    lOk := Chk(lOk, "EFD gerada (GDFG)", Len(aH) == 1 .And. BOVAL(aH[1]:L) > 0)

    // ===== Financeiro: titulos DEM-REC + boletos liquidados via CNAB =====
    lOk := Chk(lOk, "titulos DEM-REC", HDM_CNT("GFN2", "GFN2_DOC LIKE 'DEM-REC-%' AND D_E_L_E_T_ = ' '") >= 120)
    lOk := Chk(lOk, "boletos LIQUIDADO (CNAB)", HDM_CNT("GBC2", "GBC2_STATUS = 'LIQUIDADO' AND GBC2_DOC LIKE 'DEM-REC-%' AND D_E_L_E_T_ = ' '") >= 5)
    lOk := Chk(lOk, "contas financeiras", HDM_CNT("GFN1", "D_E_L_E_T_ = ' '") >= 3)

    // ===== Compras: solicitacoes atendidas + pedidos DEM-PED =====
    lOk := Chk(lOk, "solicitacoes DEM-SC atendidas", HDM_CNT("GCQ1", "GCQ1_NUM LIKE 'DEM-SC-%' AND GCQ1_STATUS = 'ATENDIDA' AND D_E_L_E_T_ = ' '") >= 5)
    lOk := Chk(lOk, "pedidos DEM-PED", HDM_CNT("GCP3", "GCP3_NUM LIKE 'DEM-PED-%' AND D_E_L_E_T_ = ' '") >= 30)
    lOk := Chk(lOk, "pedidos DEM-PED recebidos", HDM_CNT("GCP3", "GCP3_NUM LIKE 'DEM-PED-%' AND GCP3_STATUS = 'RECEBIDO' AND D_E_L_E_T_ = ' '") >= 18)

    // ===== Loja: ultima sessao de caixa com cupons e as 6 formas =====
    aH := TCSqlQuery("SELECT GLJ2_SESSAO AS S FROM GLJ2 WHERE D_E_L_E_T_ = ' ' ORDER BY GLJ2_SESSAO DESC LIMIT 1")
    If Len(aH) == 1
        cSes := BOCOL(aH[1]:S)
    EndIf
    If cSes == ""
        ConOut("  FAIL: sessao de caixa nao encontrada")
        lOk := .F.
    Else
        lOk := Chk(lOk, "cupons na sessao " + cSes, HDM_CNT("GLJ3", "GLJ3_SESSAO = " + GEBDBQuote(cSes) + " AND D_E_L_E_T_ = ' '") >= 18)
        lOk := Chk(lOk, "cancelamento no caixa", HDM_CNT("GLJ3", "GLJ3_SESSAO = " + GEBDBQuote(cSes) + " AND GLJ3_STATUS = 'CANCELADO' AND D_E_L_E_T_ = ' '") >= 1)
        For nI := 1 To Len(aFormas)
            lOk := Chk(lOk, "forma " + aFormas[nI], HDM_CNT("GLJ5", "GLJ5_FORMA = " + GEBDBQuote(aFormas[nI]) + " AND D_E_L_E_T_ = ' ' AND GLJ5_CUPOM IN (SELECT GLJ3_CUPOM FROM GLJ3 WHERE GLJ3_SESSAO = " + GEBDBQuote(cSes) + " AND GLJ3.D_E_L_E_T_ = ' ')") >= 1)
        Next
    EndIf
    lOk := Chk(lOk, "pedidos DEM-PV faturados", HDM_CNT("GFT3", "GFT3_NUM LIKE 'DEM-PV-%' AND GFT3_STATUS = 'FATURADO' AND D_E_L_E_T_ = ' '") >= 50)
    lOk := Chk(lOk, "devolucoes GFT7", HDM_CNT("GFT7", "D_E_L_E_T_ = ' '") >= 5)

    // ===== Contabil: lancamentos DEM-CTB + massa via modulos =====
    lOk := Chk(lOk, "lancamentos DEM-CTB", HDM_CNT("GC2", "GC2_ORIGEM LIKE 'DEMLP:DEM-CTB-%' AND D_E_L_E_T_ = ' '") >= 3)
    lOk := Chk(lOk, "livro-razao GC2", HDM_CNT("GC2", "D_E_L_E_T_ = ' '") >= 300)

    // ===== Simples Nacional: competencia com DAS apurado =====
    lOk := Chk(lOk, "folha RBT12 (GSN1)", HDM_CNT("GSN1", "GSN1_COMP <> '' AND D_E_L_E_T_ = ' '") >= 13)
    aH := TCSqlQuery("SELECT GSN2_COMP AS C, GSN2_DAS AS D, GSN2_FATORR AS F FROM GSN2 WHERE D_E_L_E_T_ = ' ' ORDER BY GSN2_COMP DESC LIMIT 1")
    lOk := Chk(lOk, "apuracao Simples (GSN2)", Len(aH) == 1 .And. BOVAL(aH[1]:D) > 0)
    If Len(aH) == 1
        ConOut("    competencia " + BOCOL(aH[1]:C) + " DAS=" + cValToChar(BOVAL(aH[1]:D)) + " fator_r=" + cValToChar(BOVAL(aH[1]:F)))
    EndIf
    lOk := Chk(lOk, "guia DAS no financeiro", HDM_CNT("GD1", "GD1_GUIA LIKE 'DAS-%' AND D_E_L_E_T_ = ' '") >= 1)

    // ===== Derrama: retencoes DEM e guias =====
    lOk := Chk(lOk, "regras de retencao DEM", HDM_CNT("GRT1", "LEFT(GRT1_COD, 4) = 'DEM-' AND D_E_L_E_T_ = ' '") >= 6)
    lOk := Chk(lOk, "retencoes aplicadas", HDM_CNT("GRT2", "LEFT(GRT2_DOC, 6) = 'DEM-NF' AND D_E_L_E_T_ = ' '") >= 3)
    lOk := Chk(lOk, "guias RET-/DEM-GD", HDM_CNT("GD1", "(GD1_GUIA LIKE 'RET-%' OR GD1_GUIA = 'DEM-GD-ICMS') AND D_E_L_E_T_ = ' '") >= 7)

    // ===== Periferico virtual: schema ok; cupom PNG e' cobertura manual =====
    lOk := Chk(lOk, "tabela GEP_PERIFERICOS", GEBDBTableExistsHere("GEP_PERIFERICOS"))
    ConOut("  INFO periferico: impressora virtual escpos_virtual (:9100) gera cupom-*.png em periferico/saidas/ — cobertura manual no roteiro (PDV web nao fala WS de dentro do AdvPL)")

    // ===== Probe SEFAZ emulada (unico acesso externo; consStatServ e' read-only) =====
    GEBDEMOENSURE()
    For nI := 1 To 3
        aR := GEBDFESTATSVC("55")
        If aR[1] .And. "107" $ aR[2]
            Exit
        EndIf
        If nI < 3
            Sleep(2000)
        EndIf
    Next
    lOk := Chk(lOk, "SEFAZ emulada consStatServ 107", aR[1] .And. "107" $ aR[2])
    If !(aR[1] .And. "107" $ aR[2])
        ConOut("    " + aR[2] + " (emuladores sobem sob demanda via watchdog :18768 — 'scripts/geban-demo.sh status' confere)")
    EndIf

    If lOk
        ConOut("T_GEBAN_DEMO PASS")
    Else
        ConOut("T_GEBAN_DEMO FAIL")
    EndIf
Return lOk

// Conta linhas do filtro no tenant corrente (search_path ja' e' emp_99).
Static Function HDM_CNT(cTab, cFiltro)
    Local aH := TCSqlQuery("SELECT R_E_C_N_O_ AS R FROM " + cTab + " WHERE " + cFiltro)
Return Len(aH)

Static Function Chk(lOk, cNome, lCond)
    If lCond
        ConOut("  OK " + cNome)
        Return lOk
    EndIf
    ConOut("  FAIL: " + cNome)
Return .F.
