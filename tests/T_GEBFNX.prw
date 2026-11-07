#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBCTX.prw"
#include "../src/GEBFNX.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBEST.prw"
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

/*/{Protheus.doc} T_GEBFNX
    Teste do financeiro do backoffice (GEBFNX). Valores calculados a mao:
    - 100,00 em 30/60/90 = 33,33 + 33,33 + 33,34 (31/10, 30/11, 30/12).
    - atraso de 10 dias sobre 33,33: juros 0,033%/dia = 0,11; multa 2% = 0,67.
    - baixa parcial de 20,00; o resto (13,33) 10 dias depois do vencimento
      com juros 0,04 + multa 0,27 = 13,64; desconto de 3,33 na 2a parcela;
      pagamento de 200,00 com juros de 5,00; transferencia de 10,00 e tarifa
      de 50,00.
    - contabil, posicao por faixa, extrato e fluxo projetado.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 18/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBFNX()
    Local lOk := .T.
    Local aR := {}

    If !GEBDBConecta()
        ConOut("T_GEBFNX FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfnx CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebfnx")
    TCSqlExec("SET search_path TO test_gebfnx")
    lOk := Chk(lOk, "mig", GENMIG() .And. GEBFXMIG())
    GEBFNCON("CAIXA", "Caixa")
    GEBFNCON("BANCO1", "Banco 1")

    // Condicao e parcelas
    lOk := Chk(lOk, "cond", GEBFXCOND("3x", "Tres vezes", "30, 60, 90")[1])
    lOk := Chk(lOk, "cond decrescente", !GEBFXCOND("X", "x", "60,30")[1])
    lOk := Chk(lOk, "cond texto", !GEBFXCOND("X", "x", "abc")[1])
    lOk := Chk(lOk, "cond vazia", !GEBFXCOND("X", "x", "")[1])
    aR := GEBFXPARC("3X", 100, "20261001")
    lOk := Chk(lOk, "parc", aR[1] .And. Len(aR[3]) == 3 .And. aR[3][1][2] == 33.33 .And. aR[3][3][2] == 33.34 .And. ;
        aR[3][1][1] == "20261031" .And. aR[3][3][1] == "20261230")
    aR := GEBFXPARC("0", 50, "20261001")
    lOk := Chk(lOk, "a vista", aR[1] .And. Len(aR[3]) == 1 .And. aR[3][1][1] == "20261001")
    lOk := Chk(lOk, "cond inexistente", !GEBFXPARC("NAOEXISTE", 50, "20261001")[1])

    // Titulos
    aR := GEBFXTIT("R", "NF10", "CLI1", 100, "3X", "20261001", "FAT", "")
    lOk := Chk(lOk, "tit", aR[1] .And. Len(aR[3]) == 3 .And. aR[3][2][1] == "NF10/02")
    lOk := Chk(lOk, "tit duplicado", !GEBFXTIT("R", "NF10", "CLI1", 100, "3X", "20261001", "FAT", "")[1])
    lOk := Chk(lOk, "tit gfn2", Len(TCSqlQuery("SELECT GFN2_DOC FROM GFN2 WHERE GFN2_CLI = 'CLI1' AND D_E_L_E_T_ = ' '")) == 3)
    aR := GEBFXCALC("R", "NF10/01", "20261110")
    lOk := Chk(lOk, "calc atraso", aR[1] .And. aR[3][2] == 10 .And. aR[3][3] == 0.11 .And. aR[3][4] == 0.67)
    aR := GEBFXCALC("R", "NF10/01", "20261020")
    lOk := Chk(lOk, "calc em dia", aR[1] .And. aR[3][2] == 0 .And. aR[3][3] == 0)

    // Baixas a receber
    aR := GEBFXBAI("R", "NF10/01", 20, 0, 0, 0, "BANCO1", "20261020")
    lOk := Chk(lOk, "bai parcial", aR[1] .And. aR[3][1] == 13.33 .And. aR[3][2] == 20)
    aR := GEBFXBAI("R", "NF10/01", 13.33, Nil, Nil, 0, "BANCO1", "20261110")
    lOk := Chk(lOk, "bai juros auto", aR[1] .And. aR[3][1] == 0 .And. aR[3][2] == 13.64)
    lOk := Chk(lOk, "bai quitado", !GEBFXBAI("R", "NF10/01", 1, 0, 0, 0, "BANCO1", "20261110")[1])
    lOk := Chk(lOk, "bai acima saldo", !GEBFXBAI("R", "NF10/02", 40, 0, 0, 0, "CAIXA", "20261101")[1])
    lOk := Chk(lOk, "bai conta inexistente", !GEBFXBAI("R", "NF10/02", 1, 0, 0, 0, "NADA", "20261101")[1])
    aR := GEBFXBAI("R", "NF10/02", 33.33, 0, 0, 3.33, "CAIXA", "20261101")
    lOk := Chk(lOk, "bai desconto", aR[1] .And. aR[3][2] == 30)
    lOk := Chk(lOk, "status recebida", BOCOL(TCSqlQuery("SELECT GFN2_STATUS AS S FROM GFN2 WHERE GFN2_DOC = 'NF10/02'")[1]:S) == "RECEBIDA")

    // Pagar, transferencia, movimento avulso
    lOk := Chk(lOk, "tit pagar", GEBFXTIT("P", "NFC1", "FORN1", 200, "0", "20261001", "COMPRA", "")[1])
    aR := GEBFXBAI("P", "NFC1", 200, 5, 0, 0, "BANCO1", "20261005")
    lOk := Chk(lOk, "pagamento", aR[1] .And. aR[3][2] == 205)
    lOk := Chk(lOk, "trf", GEBFXTRF("CAIXA", "BANCO1", 10, "20261006", "")[1])
    lOk := Chk(lOk, "trf mesma", !GEBFXTRF("CAIXA", "CAIXA", 10, "20261006", "")[1])
    lOk := Chk(lOk, "tarifa", GEBFXMOV("BANCO1", "D", 50, "Tarifa", "20261006", "")[1])
    lOk := Chk(lOk, "saldo banco", BOVAL(TCSqlQuery("SELECT GFN1_SALDO AS S FROM GFN1 WHERE GFN1_CONTA = 'BANCO1'")[1]:S) == -211.36)
    lOk := Chk(lOk, "saldo caixa", BOVAL(TCSqlQuery("SELECT GFN1_SALDO AS S FROM GFN1 WHERE GFN1_CONTA = 'CAIXA'")[1]:S) == 20)

    // Contabil
    aR := GEBCTXRAZAO("1.01.003", "20261001", "20261231")
    lOk := Chk(lOk, "razao clientes", aR[1] .And. Chave(aR[3][1], "saldo_final") == -66.66)
    aR := GEBCTXRAZAO("2.01.001", "20261001", "20261231")
    lOk := Chk(lOk, "razao fornecedores", aR[1] .And. Chave(aR[3][1], "saldo_final") == 200)
    aR := GEBCTXRAZAO("1.01.002", "20261001", "20261231")
    lOk := Chk(lOk, "razao bancos", aR[1] .And. Chave(aR[3][1], "saldo_final") == -211.36)
    aR := GEBCTXBALAN("20261001", "20261231")
    lOk := Chk(lOk, "balancete", aR[1] .And. Chave(aR[3][2], "fechado") == "S")
    aR := GEBCTXDRE("20261001", "20261231")
    // outras receitas 0,31 (juros+multa) - despesas (desconto 3,33 + juros 5 + tarifa 50) = -58,02
    lOk := Chk(lOk, "dre", aR[1] .And. Chave(aR[3], "outras_receitas") == 0.31 .And. Chave(aR[3], "resultado") == -58.02)

    // Relatorios
    aR := GEBFXPOSICAO("R", "20261231")
    lOk := Chk(lOk, "posicao", aR[1] .And. Len(aR[3][1]) == 2 .And. Chave(aR[3][2], "1-30") == 33.34)
    aR := GEBFXEXTRATO("BANCO1", "20261001", "20261031")
    lOk := Chk(lOk, "extrato", aR[1] .And. Chave(aR[3][1], "saldo_anterior") == 0 .And. Chave(aR[3][1], "saldo_final") == -225 .And. Len(aR[3][2]) == 5)
    aR := GEBFXFLUXO("20261101", 60)
    lOk := Chk(lOk, "fluxo", aR[1] .And. Chave(aR[3][2], "saldo_inicial") == -191.36 .And. Chave(aR[3][2], "saldo_final") == -158.02)

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfnx CASCADE")
    If lOk
        ConOut("T_GEBFNX PASS")
    Else
        ConOut("T_GEBFNX FAIL")
    EndIf
Return lOk

Static Function Chave(aP, cK)
    Local nI := 0
    For nI := 1 To Len(aP)
        If aP[nI][1] == cK
            Return aP[nI][2]
        EndIf
    Next nI
Return Nil

Static Function Chk(lOk, cNome, lCond)
    If !lCond
        ConOut("  FAIL: " + cNome)
        Return .F.
    EndIf
Return lOk
