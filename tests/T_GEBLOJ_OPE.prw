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

/*/{Protheus.doc} T_GEBLOJ_OPE
    Teste da frente de loja ampliada (GEBLOJ_CAD, GEBLOJ_OPE). Valores a mao:
    - tabela P1 10,00, P2 20,00, P3 50,00/kg; promocoes LV1 (P1 leve 3 pague
      2), QT1 (P1 25% a partir de 10) e PR1 (P2 por 18,00).
    - venda A (sessao 1, 15/10): EAN de P1 x3 = 20,00 (LV1, -10,00), P2 =
      18,00 (PR1, -2,00), etiqueta 2001230015008 = 15,00 (0,3 kg de P3);
      total 53,00, dinheiro 60,00, troco 7,00; vendedor V1, CPF na nota.
    - venda B: caixa de 12 (GTIN-14, fator 12) = 12 P1: LV1 80,00 < QT1
      90,00; PIX 80,00.
    - LOJ_DESC_MAX 10%: venda C 2 P2 a 20,00 com desconto 5,00 (12,5%) so'
      com o supervisor: 35,00 em dinheiro.
    - devolucao de A: 1 P1 em vale (20/3 = 6,67) e 2 P1 em dinheiro (resto
      13,33). Venda D: P2 20,00 = vale 6,67 + dinheiro 13,33, cancelada (o
      vale volta). Orcamento de 2 P2 (PR1) = 36,00, finalizado em dinheiro.
    - gaveta: 100 + 53 + 35 + 36 - 13,33 = 210,67. Gerencial do dia: 4
      vendidos, 1 cancelado, vendas 204,00, devolucoes 20,00. Comissao V1:
      (53 + 36 - 20) x 5% = 3,45.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 19/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBLOJ_OPE()
    Local lOk := .T.
    Local aR := {}
    Local cSes := ""
    Local cA := ""
    Local cD := ""
    Local cVale := ""
    Local cOrc := ""

    If !GEBDBConecta()
        ConOut("T_GEBLOJ_OPE FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_geblojope CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_lojope CASCADE")
    TCSqlExec("CREATE SCHEMA test_geblojope")
    TCSqlExec("CREATE SCHEMA emp_lojope")
    TCSqlExec("SET search_path TO emp_lojope, test_geblojope")
    lOk := Chk(lOk, "mig", GENMIG() .And. TCSecMIG() .And. GEBFMIG() .And. GEBLOJMIG())
    GEBFNCON("BANCO", "Banco")
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'P1', 'N1', 'Produto 1'), " + ;
        "(' ', '      ', 'P2', 'N2', 'Produto 2'), (' ', '      ', 'P3', 'N2', 'Queijo kg')")
    TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'N1', 10, 5, '20200101', '20991231')")
    // Supervisor ADMIN com senha (perfil ADMIN tem LOJA/DESCONTO).
    TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '      ', 'sup1', 'Supervisor', 'ADMIN')")
    TCSqlExec("INSERT INTO GE2_SEC (D_E_L_E_T_, SEC_FILIAL, SEC_USUARIO, SEC_SALT, SEC_HASH) VALUES (' ', '      ', 'sup1', 'salgadinho123456', " + ;
        GEBDBQuote(HashSenha("Senha#Forte1", "salgadinho123456")) + ")")
    // Perfil e' por empresa (GE2_EMP): supervisor ADMIN na empresa do teste.
    TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA, GE2_EMP_PERFIL) VALUES (' ', '', 'sup1', 'lojope', 'ADMIN')")
    GEBFATPRC("", "P1", 10)
    GEBFATPRC("", "P2", 20)
    GEBFATPRC("", "P3", 50)
    GEBESTMOV("P1", "", "E", 100, 4, "COMPRA", "X", "20261001")
    GEBESTMOV("P2", "", "E", 50, 12, "COMPRA", "X", "20261001")
    GEBESTMOV("P3", "", "E", 10, 30, "COMPRA", "X", "20261001")

    // Utilitarios
    lOk := Chk(lOk, "ean ok", GEBLOJEANOK("7891234567895") .And. GEBLOJEANOK("17891234567892") .And. !GEBLOJEANOK("7891234567890"))
    lOk := Chk(lOk, "cpf/cnpj", GEBLOJCPFOK("529.982.247-25") .And. !GEBLOJCPFOK("52998224724") .And. !GEBLOJCPFOK("11111111111") .And. ;
        GEBLOJCPFOK("11.222.333/0001-81") .And. !GEBLOJCPFOK("11222333000180"))

    // Cadastros
    lOk := Chk(lOk, "barra digito errado", !GEBLOJBAR("7891234567890", "P1", 1)[1])
    lOk := Chk(lOk, "barra produto inexistente", !GEBLOJBAR("7891234567895", "PX", 1)[1])
    lOk := Chk(lOk, "barra", GEBLOJBAR("7891234567895", "P1", 1)[1] .And. GEBLOJBAR("17891234567892", "P1", 12)[1] .And. GEBLOJBAR("00123", "P3", 1)[1])
    lOk := Chk(lOk, "promo preco maior", !GEBLOJPROMO("PRX", "P2", "PRECO", 0, 25, "20261001", "")[1])
    lOk := Chk(lOk, "promo leve invalida", !GEBLOJPROMO("LVX", "P1", "LEVE", 3, 3, "20261001", "")[1])
    lOk := Chk(lOk, "promos", GEBLOJPROMO("LV1", "P1", "LEVE", 3, 2, "20261001", "")[1] .And. GEBLOJPROMO("QT1", "P1", "QTD", 10, 25, "20261001", "")[1] .And. ;
        GEBLOJPROMO("PR1", "P2", "PRECO", 0, 18, "20261001", "")[1])
    lOk := Chk(lOk, "vendedor", GEBLOJVEND("V1", "Vendedor 1", 5)[1] .And. !GEBLOJVEND("V2", "", 100)[1])
    aR := GEBLOJPRECO("P1", 12, "20261015")
    lOk := Chk(lOk, "melhor promocao", aR[2] == "LV1" .And. aR[3] == 40)
    lOk := Chk(lOk, "promo fora da vigencia", GEBLOJPRECO("P2", 1, "20260930")[1] == 20)
    BOSETPARM("LOJ_BALANCA", "PESO")
    aR := GEBLOJRESOLVE("2001230015008", 1, 0)
    lOk := Chk(lOk, "balanca peso", aR[1] .And. aR[3][1] == "P3" .And. aR[3][2] == 1.5)
    BOSETPARM("LOJ_BALANCA", "PRECO")

    // Caixa e vendas
    GEBLOJCX("01", "Caixa 1", "", "")
    cSes := GEBLOJABRE("01", "maria", 100, "20261015")[3]
    lOk := Chk(lOk, "cpf invalido", !GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 0, "", "52998224724")[1])
    lOk := Chk(lOk, "vendedor inexistente", !GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 0, "VX", "")[1])
    aR := GEBLOJVEN(cSes, {{"7891234567895", 3}, {"P2", 1}, {"2001230015008", 1}}, {{"DINHEIRO", 60}}, "", 0, "V1", "529.982.247-25")
    lOk := Chk(lOk, "venda A", aR[1] .And. aR[3][2] == 53 .And. aR[3][3] == 7)
    cA := aR[3][1]
    lOk := Chk(lOk, "promocoes do cupom", aR[1] .And. BOVAL(TCSqlQuery("SELECT SUM(GLJA_DESC) AS D FROM GLJA WHERE GLJA_CUPOM = " + GEBDBQuote(cA))[1]:D) == 12)
    lOk := Chk(lOk, "complemento", aR[1] .And. BOCOL(TCSqlQuery("SELECT GLJB_CPF AS C FROM GLJB WHERE GLJB_CUPOM = " + GEBDBQuote(cA))[1]:C) == "52998224725")
    lOk := Chk(lOk, "balanca estoque", GEBESTSLD("P3", "01")[1] == 9.7)
    aR := GEBLOJVEN(cSes, {{"17891234567892", 1}}, {{"PIX", 80}}, "", 0)
    lOk := Chk(lOk, "venda B caixa de 12", aR[1] .And. aR[3][2] == 80)

    // Limite de desconto
    BOSETPARM("LOJ_DESC_MAX", "10")
    aR := GEBLOJVEN(cSes, {{"P2", 2, 20}}, {{"DINHEIRO", 35}}, "", 5)
    lOk := Chk(lOk, "desconto acima", !aR[1] .And. "desconto_acima_do_limite" $ aR[2])
    lOk := Chk(lOk, "supervisor senha errada", !GEBLOJVEN(cSes, {{"P2", 2, 20}}, {{"DINHEIRO", 35}}, "", 5, "", "", "sup1", "errada")[1])
    aR := GEBLOJVEN(cSes, {{"P2", 2, 20}}, {{"DINHEIRO", 35}}, "", 5, "", "", "sup1", "Senha#Forte1")
    lOk := Chk(lOk, "venda C liberada", aR[1] .And. aR[3][2] == 35)
    lOk := Chk(lOk, "quem liberou", aR[1] .And. BOCOL(TCSqlQuery("SELECT GLJB_AUTOR AS A FROM GLJB WHERE GLJB_CUPOM = " + GEBDBQuote(aR[3][1]))[1]:A) == "sup1")

    // Devolucao e vale-troca
    lOk := Chk(lOk, "devolucao fora do cupom", !GEBLOJDEV(cSes, cA, {{"P9", 1}}, "VALE", "")[1])
    aR := GEBLOJDEV(cSes, cA, {{"P1", 1}}, "VALE", "nao serviu")
    lOk := Chk(lOk, "devolucao vale", aR[1] .And. aR[3][2] == 6.67 .And. aR[3][3] == 4)
    cVale := aR[3][4]
    aR := GEBLOJDEV(cSes, cA, {{"P1", 2}}, "DINHEIRO", "")
    lOk := Chk(lOk, "devolucao dinheiro", aR[1] .And. aR[3][2] == 13.33 .And. aR[3][3] == 8)
    lOk := Chk(lOk, "devolucao acima", !GEBLOJDEV(cSes, cA, {{"P1", 1}}, "VALE", "")[1])
    lOk := Chk(lOk, "cancela com devolucao", !GEBLOJCAN(cA, "")[1])
    lOk := Chk(lOk, "gft7", BOVAL(TCSqlQuery("SELECT SUM(GFT7_VALOR) AS V FROM GFT7")[1]:V) == 20)
    lOk := Chk(lOk, "estoque devolvido", GEBESTSLD("P1", "01")[1] == 100 - 3 - 12 + 3)
    lOk := Chk(lOk, "vale sem saldo", !GEBLOJVEN(cSes, {{"P2", 1, 20}}, {{"VALE", 10, 0, cVale}, {"DINHEIRO", 10}}, "", 0)[1])
    aR := GEBLOJVEN(cSes, {{"P2", 1, 20}}, {{"VALE", 6.67, 0, cVale}, {"DINHEIRO", 13.33}}, "", 0)
    lOk := Chk(lOk, "venda D com vale", aR[1] .And. Chave(GEBLOJVALE(cVale)[3], "saldo") == 0 .And. Chave(GEBLOJVALE(cVale)[3], "status") == "USADO")
    cD := aR[3][1]
    lOk := Chk(lOk, "vale usado", !GEBLOJVEN(cSes, {{"P2", 1, 20}}, {{"VALE", 1, 0, cVale}, {"DINHEIRO", 19}}, "", 0)[1])
    lOk := Chk(lOk, "cancela D", GEBLOJCAN(cD, "")[1] .And. Chave(GEBLOJVALE(cVale)[3], "saldo") == 6.67 .And. Chave(GEBLOJVALE(cVale)[3], "status") == "ABERTO")

    // Orcamento
    aR := GEBLOJORC({{"P2", 2}}, "", "V1", 0, "20261015")
    lOk := Chk(lOk, "orcamento", aR[1] .And. aR[3][2] == 36)
    cOrc := aR[3][1]
    aR := GEBLOJORCFIN(cSes, cOrc, {{"DINHEIRO", 40}}, "")
    lOk := Chk(lOk, "orcamento finalizado", aR[1] .And. aR[3][2] == 36 .And. aR[3][3] == 4)
    lOk := Chk(lOk, "orcamento de novo", !GEBLOJORCFIN(cSes, cOrc, {{"DINHEIRO", 40}}, "")[1])
    aR := GEBLOJORC({{"P1", 1}}, "", "", 0, "20261015")
    lOk := Chk(lOk, "orcamento cancelado", GEBLOJORCCAN(aR[3][1])[1] .And. !GEBLOJORCCAN(aR[3][1])[1])
    aR := GEBLOJORC({{"P1", 1}}, "", "", 0, "20261001")
    lOk := Chk(lOk, "orcamento vencido", !GEBLOJORCFIN(cSes, aR[3][1], {{"DINHEIRO", 10}}, "")[1])
    lOk := Chk(lOk, "lista orcamentos", GEBLOJORCS("FINALIZADO")[1] .And. Len(GEBLOJORCS("FINALIZADO")[3]) == 2)

    // Consultas
    aR := GEBLOJCONS("P2", "01")
    lOk := Chk(lOk, "consulta", aR[1] .And. Chave(aR[3], "preco_hoje") == 18 .And. Chave(aR[3], "promocao") == "PR1" .And. Chave(aR[3], "saldo") == 45)
    aR := GEBLOJCUPOM(cA)
    lOk := Chk(lOk, "segunda via", aR[1] .And. Tem(aR[3], "CPF/CNPJ do consumidor: 52998224725") .And. Tem(aR[3], "Vendedor: V1") .And. ;
        Tem(aR[3], "DINHEIRO 60.00") .And. Tem(aR[3], "TROCO 7.00") .And. Tem(aR[3], "promocao LV1"))

    // Fechamento, gerencial e comissao
    lOk := Chk(lOk, "esperado", GEBLOJESP(cSes) == 210.67)
    aR := GEBLOJRESUMO(cSes)
    lOk := Chk(lOk, "resumo", aR[1] .And. Chave(aR[3], "devolucoes em dinheiro") == 13.33 .And. Chave(aR[3], "devolucoes em vale") == 6.67 .And. ;
        Chave(aR[3], "forma VALE") == 0)
    aR := GEBLOJGER("20261015", "20261015", "DIA")
    lOk := Chk(lOk, "gerencial dia", aR[1] .And. Chave(aR[3][2], "cupons") == 4 .And. Chave(aR[3][2], "cancelados") == 1 .And. ;
        Chave(aR[3][2], "vendas") == 204 .And. Chave(aR[3][2], "devolucoes") == 20 .And. Chave(aR[3][2], "ticket_medio") == 51)
    aR := GEBLOJGER("20261015", "20261015", "VENDEDOR")
    lOk := Chk(lOk, "gerencial vendedor", aR[1] .And. Len(aR[3][1]) == 3)
    aR := GEBLOJCOMIS("20261015", "20261015")
    lOk := Chk(lOk, "comissao", aR[1] .And. aR[3][2] == 3.45)
    lOk := Chk(lOk, "fecha sem diferenca", GEBLOJFECHA(cSes, 210.67)[3][3] == 0)

    // Operador com LOJA/DESCONTO libera sozinho.
    GEBLOJCX("02", "Caixa 2", "", "")
    cSes := GEBLOJABRE("02", "sup1", 0, "20261016")[3]
    lOk := Chk(lOk, "operador libera", GEBLOJVEN(cSes, {{"P2", 1, 20}}, {{"DINHEIRO", 15}}, "", 5)[1])

    // Contabil
    lOk := Chk(lOk, "devolucao contabil", Abs(Chave(GEBCTXRAZAO("3.02.001", "20261001", "20261031")[3][1], "saldo_final")) == 20)
    lOk := Chk(lOk, "vale contabil", Abs(Chave(GEBCTXRAZAO("2.01.003", "20261001", "20261031")[3][1], "saldo_final")) == 6.67)

    TCSqlExec("DROP SCHEMA IF EXISTS test_geblojope CASCADE")
    If lOk
        ConOut("T_GEBLOJ_OPE PASS")
    Else
        ConOut("T_GEBLOJ_OPE FAIL")
    EndIf
Return lOk

Static Function Tem(aTxt, cParte)
    Local nI := 0
    For nI := 1 To Len(aTxt)
        If cParte $ aTxt[nI]
            Return .T.
        EndIf
    Next nI
    ConOut("  linha ausente: " + cParte)
Return .F.

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
