#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/_init.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBFAT.prw"
#include "../src/GESSAR.prw"

/*/{Protheus.doc} T_GESSAR
    Gatilho Sarney (src/GESSAR.prw): validacao da regra, decisao pura
    GESSARDEVE (horario, vezes, slot unico) e aplicacao real sobre GFT2
    PADRAO com override por produto e auditoria em GSK3.
    aCfg de GESSARDEVE/GESSARAPLICA = {cod, descr, pct, vezes, horas,
    feitas, ulthora, ativo}.
    Schema descartavel test_gessar.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 26/11/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GESSAR()
    Local lOk := .T.
    Local aR := {}
    Local aCfg := {}
    Local aHit := {}

    If !GEBDBConecta()
        ConOut("T_GESSAR FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gessar CASCADE")
    TCSqlExec("CREATE SCHEMA test_gessar")
    TCSqlExec("SET search_path TO test_gessar")
    lOk := Chk(GENMIG() .And. GEBFATMIG() .And. GESSARMIG(), "mig", lOk)
    ConOut("=== T_GESSAR ===")

    // Catalogo de precos PADRAO: P1 = 10,00 e P2 = 20,00.
    lOk := Chk(GEBFATPRC("", "P1", 10)[1] .And. GEBFATPRC("", "P2", 20)[1], "precos", lOk)

    // 1. Cadastro da regra: validacoes.
    lOk := Chk(!GESSARCFG("R1", "Teste", 0, 3, "0800", "S")[1], "cfg pct zero", lOk)
    lOk := Chk(!GESSARCFG("R1", "Teste", 101, 3, "0800", "S")[1], "cfg pct alto", lOk)
    lOk := Chk(!GESSARCFG("R1", "Teste", 10, 3, "", "S")[1], "cfg sem horario", lOk)
    lOk := Chk(!GESSARCFG("R1", "Teste", 10, 3, "0800 25h0", "S")[1], "cfg horario invalido", lOk)
    lOk := Chk(!GESSARCFG("R1", "Teste", 10, 0, "0800", "S")[1], "cfg vezes zero", lOk)
    lOk := Chk(GESSARCFG("R1", "Reajuste teste", 10, 3, "0800 1200", "S")[1], "cfg ok", lOk)
    // Regravar o mesmo codigo substitui (soft-delete + insert).
    lOk := Chk(GESSARCFG("R1", "Reajuste teste v2", 10, 3, "0800 1200", "S")[1], "cfg regravar", lOk)
    aHit := TCSqlQuery("SELECT GSK1_DESCR AS D FROM GSK1 WHERE GSK1_COD = 'R1' AND D_E_L_E_T_ = ' '")
    lOk := Chk(Len(aHit) == 1 .And. BOCOL(aHit[1]:D) == "Reajuste teste v2", "cfg substituida", lOk)

    // 2. Override por produto.
    lOk := Chk(!GESSARPROD("R1", "P1", 101)[1], "override pct invalido", lOk)
    lOk := Chk(GESSARPROD("R1", "P1", 50)[1], "override ok", lOk)

    // 3. Decisao pura GESSARDEVE.
    //    aCfg = {cod, descr, pct, vezes, horas, feitas, ulthora, ativo}.
    aCfg := {"R1", "Reajuste teste v2", 10, 3, "0800 1200", 0, "", "S"}
    lOk := Chk(GESSARDEVE("20261126", "0800", aCfg), "deve no slot 0800", lOk)
    lOk := Chk(GESSARDEVE("20261126", "1200", aCfg), "deve no slot 1200", lOk)
    lOk := Chk(!GESSARDEVE("20261126", "0900", aCfg), "nao deve fora do slot", lOk)
    aCfg[8] := "N"
    lOk := Chk(!GESSARDEVE("20261126", "0800", aCfg), "inativa nao deve", lOk)
    aCfg[8] := "S"
    aCfg[6] := 3
    lOk := Chk(!GESSARDEVE("20261126", "0800", aCfg), "vezes esgotadas nao deve", lOk)
    aCfg[6] := 0
    aCfg[7] := "202611260800"
    lOk := Chk(!GESSARDEVE("20261126", "0800", aCfg), "slot ja aplicado nao repete", lOk)
    lOk := Chk(GESSARDEVE("20261126", "1200", aCfg), "proximo slot do dia ainda deve", lOk)

    // 4. Aplicacao real: P1 tem override 50%, P2 usa o geral 10%.
    //    P1: 10 * 1,5 = 15 ; P2: 20 * 1,1 = 22.
    aCfg := {"R1", "Reajuste teste v2", 10, 3, "0800 1200", 0, "", "S"}
    aR := GESSARAPLICA("20261126", "0800", aCfg)
    lOk := Chk(aR[1] .And. (aR[3] == 2), "aplica ok", lOk)
    aHit := TCSqlQuery("SELECT GFT2_PRECO AS P FROM GFT2 WHERE GFT2_PROD = 'P1' AND GFT2_TAB = 'PADRAO' AND D_E_L_E_T_ = ' '")
    lOk := Chk(Len(aHit) == 1 .And. BOVAL(aHit[1]:P) == 15, "P1 override 50%", lOk)
    aHit := TCSqlQuery("SELECT GFT2_PRECO AS P FROM GFT2 WHERE GFT2_PROD = 'P2' AND GFT2_TAB = 'PADRAO' AND D_E_L_E_T_ = ' '")
    lOk := Chk(Len(aHit) == 1 .And. BOVAL(aHit[1]:P) == 22, "P2 geral 10%", lOk)
    // Auditoria: uma linha por produto em GSK3.
    aHit := TCSqlQuery("SELECT GSK3_PROD AS P, GSK3_PCT AS PC, GSK3_ANT AS A, GSK3_NOV AS N FROM GSK3 WHERE GSK3_CFG = 'R1' AND D_E_L_E_T_ = ' ' ORDER BY GSK3_PROD")
    lOk := Chk(Len(aHit) == 2, "log GSK3 duas linhas", lOk)
    If Len(aHit) == 2
        lOk := Chk(BOCOL(aHit[1]:P) == "P1" .And. BOVAL(aHit[1]:PC) == 50 .And. BOVAL(aHit[1]:A) == 10 .And. BOVAL(aHit[1]:N) == 15, "log P1", lOk)
        lOk := Chk(BOCOL(aHit[2]:P) == "P2" .And. BOVAL(aHit[2]:PC) == 10 .And. BOVAL(aHit[2]:A) == 20 .And. BOVAL(aHit[2]:N) == 22, "log P2", lOk)
    EndIf
    // Contadores da regra: feitas + 1 e ulthora = slot.
    aHit := TCSqlQuery("SELECT GSK1_FEITAS AS F, GSK1_ULTHORA AS U FROM GSK1 WHERE GSK1_COD = 'R1' AND D_E_L_E_T_ = ' '")
    lOk := Chk(Len(aHit) == 1 .And. BOVAL(aHit[1]:F) == 1 .And. BOCOL(aHit[1]:U) == "202611260800", "feitas e ulthora", lOk)

    // Segunda aplicacao no proximo slot: composto sobre o preco novo.
    // P1: 15 * 1,5 = 22,5 ; P2: 22 * 1,1 = 24,2.
    aR := GESSARAPLICA("20261126", "1200", aCfg)
    lOk := Chk(aR[1] .And. (aR[3] == 2), "segunda aplica", lOk)
    aHit := TCSqlQuery("SELECT GFT2_PRECO AS P FROM GFT2 WHERE GFT2_PROD = 'P1' AND D_E_L_E_T_ = ' '")
    lOk := Chk(BOVAL(aHit[1]:P) == 22.5, "P1 composto", lOk)
    aHit := TCSqlQuery("SELECT GFT2_PRECO AS P FROM GFT2 WHERE GFT2_PROD = 'P2' AND D_E_L_E_T_ = ' '")
    lOk := Chk(BOVAL(aHit[1]:P) == 24.2, "P2 composto", lOk)

    // Override removido (pct 0) volta ao geral.
    lOk := Chk(GESSARPROD("R1", "P1", 0)[1], "override removido", lOk)
    aR := GESSARAPLICA("20261127", "0800", {"R1", "Reajuste teste v2", 10, 3, "0800 1200", 0, "", "S"})
    lOk := Chk(aR[1], "sem override", lOk)
    aHit := TCSqlQuery("SELECT GFT2_PRECO AS P FROM GFT2 WHERE GFT2_PROD = 'P1' AND D_E_L_E_T_ = ' '")
    lOk := Chk(BOVAL(aHit[1]:P) == 24.75, "P1 geral na 3a", lOk)

    // 5. Consultas.
    aR := GESSARLISTA()
    lOk := Chk(aR[1] .And. Len(aR[3]) >= 2, "lista regras", lOk)
    aR := GESSARHIST("R1")
    lOk := Chk(aR[1] .And. Len(aR[3]) == 7, "historico", lOk)

    // 6. Executor: smoke test no horario corrente (nao falha se nada vencer).
    lOk := Chk(GESSARRUN() >= 0, "run smoke", lOk)

    TCSqlExec("SET search_path TO test_gessar")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gessar CASCADE")

    If lOk
        ConOut("T_GESSAR PASS")
    Else
        ConOut("T_GESSAR FAIL")
    EndIf
Return lOk

Static Function Chk(lCond, cMsg, lOk)
    If lCond
        ConOut("  OK " + cMsg)
    Else
        ConOut("  FAIL " + cMsg)
    EndIf
Return lCond .And. lOk
