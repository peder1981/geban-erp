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
#include "../src/GEBSN.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBCOM_MIG.prw"
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

/*/{Protheus.doc} T_GEBSN
    Teste do Simples Nacional (GEBSN.prw). Valores esperados calculados a
    mao: aliquota efetiva = (RBT12 x nominal - deducao) / RBT12.
    1. Calculo puro: Anexo III faixa 3; Anexo I faixa 6 (ICMS fora do DAS);
       teto de 5% do ISS (Anexo III faixa 5); ST, monofasico e exportacao
       no Anexo I faixa 3 (6,6125% sobre 10.000); soma dos tributos = DAS.
    2. Vencimento: sabado (20/06/2026 -> 22/06), feriado nacional
       (20/11/2026 -> 23/11) e Corpus Christi (20/06/2030 -> 21/06).
    3. Fator R (202605): RBT12 480.000, folha 0,30 => Anexo III, DAS
       4.912,50; folha baixa => Anexo V, 8.718,75; titulo com baixa nao
       muda (alerta de restituicao, valor menor que o pago); inicio de atividade no mes.
    4. Duas atividades (202610): comercio (Anexo I) normal + monofasico +
       exportacao e servico (Anexo III) = 661,25 + 558,76 + 337,24 + 982,50
       = 2.539,75; feriado municipal empurra o vencimento para 24/11.
    5. Relatorios: extrato (4 linhas, tributos somam o DAS) e anual.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 18/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBSN()
    Local lOk := .T.
    Local aR := {}
    Local aHit := {}
    Local nI := 0
    Local cComp := ""

    // 1. Calculo puro
    aR := GEBSNCALC(500000, "III", 50000)
    lOk := Chk(lOk, "III faixa", aR[1] == 3)
    lOk := Chk(lOk, "III aliq", Round(aR[2], 4) == 9.972)
    lOk := Chk(lOk, "III das", aR[5] == 4986)
    aR := GEBSNCALC(4000000, "I", 300000)
    lOk := Chk(lOk, "I f6 faixa", aR[1] == 6)
    lOk := Chk(lOk, "I f6 aliq", Round(aR[2], 4) == 9.55)
    lOk := Chk(lOk, "I f6 total", aR[3] == 28650)
    lOk := Chk(lOk, "I f6 fora", aR[4] == 9597.75)
    lOk := Chk(lOk, "I f6 das", aR[5] == 19052.25)
    aR := GEBSNCALC(100000, "I", 10000)
    lOk := Chk(lOk, "I f1", aR[1] == 1 .And. aR[5] == 400)
    lOk := Chk(lOk, "anexo invalido", Len(GEBSNCALC(100000, "VI", 10000)) == 0)
    aR := GEBSNREPART(500000, "III", 50000, .F., .F., .F.)
    lOk := Chk(lOk, "repart III irpj", aR[3][1] == 199.44)
    lOk := Chk(lOk, "repart III soma", SomaTrib(aR) == aR[5])
    aR := GEBSNREPART(3600000, "III", 100000, .F., .F., .F.)
    lOk := Chk(lOk, "teto ISS", aR[3][7] == 5000 .And. aR[5] == 17510 .And. SomaTrib(aR) == 17510)
    lOk := Chk(lOk, "I f3 normal", GEBSNREPART(480000, "I", 10000, .F., .F., .F.)[5] == 661.25)
    aR := GEBSNREPART(480000, "I", 10000, .F., .T., .F.)
    lOk := Chk(lOk, "I f3 mono", aR[5] == 558.76 .And. aR[3][3] == 0 .And. aR[3][4] == 0 .And. SomaTrib(aR) == aR[5])
    aR := GEBSNREPART(480000, "I", 10000, .T., .F., .F.)
    lOk := Chk(lOk, "I f3 ST", aR[5] == 439.73 .And. aR[3][6] == 0)
    aR := GEBSNREPART(480000, "I", 10000, .F., .F., .T.)
    lOk := Chk(lOk, "I f3 exportacao", aR[5] == 337.24 .And. aR[3][6] == 0 .And. aR[3][3] == 0)
    aR := GEBSNREPART(4000000, "I", 300000, .T., .F., .F.)
    lOk := Chk(lOk, "I f6 ST sem fora", aR[4] == 0)

    If !GEBDBConecta()
        ConOut("T_GEBSN FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebsn CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebsn")
    TCSqlExec("SET search_path TO test_gebsn")
    lOk := Chk(lOk, "mig", GENMIG() .And. GEBFMIG() .And. GEBFNMIG() .And. GEBSNMIG())

    // 2. Vencimento
    lOk := Chk(lOk, "venc sabado", GEBSNVENC("202605") == "20260622")
    lOk := Chk(lOk, "venc 20/11", GEBSNVENC("202610") == "20261123")
    lOk := Chk(lOk, "venc corpus christi", GEBSNVENC("203005") == "20300621")
    lOk := Chk(lOk, "venc util", GEBSNVENC("202602") == "20260320")

    // 3. Fator R
    lOk := Chk(lOk, "cfg invalido", !GEBSNCFG("VI", "")[1])
    lOk := Chk(lOk, "cfg FR", GEBSNCFG("FR", "")[1])
    lOk := Chk(lOk, "comp invalida", !GEBSNAPU("202613")[1])
    For nI := 1 To 12
        lOk := Chk(lOk, "fol", GEBSNFOL(MesT(nI), 12000, 40000)[1])
    Next nI
    NotaT("NF-SN-1", "PROD_SN", 50000, "20260515", "AUTORIZADA")
    NotaT("NF-SN-2", "PROD_SN", 999, "20260516", "EM_FILA")
    aR := GEBSNAPU("202605")
    lOk := Chk(lOk, "apu1 ok", aR[1])
    If aR[1]
        lOk := Chk(lOk, "apu1 anexo III", aR[3][1] == "III")
        lOk := Chk(lOk, "apu1 rbt12", aR[3][2] == 480000)
        lOk := Chk(lOk, "apu1 das", aR[3][5] == 4912.5)
        lOk := Chk(lOk, "apu1 venc", aR[3][6] == "20260622")
    EndIf
    aHit := TCSqlQuery("SELECT GFN3_VALOR AS VAL FROM GFN3 WHERE GFN3_DOC = 'DAS-202605' AND D_E_L_E_T_ = ' '")
    lOk := Chk(lOk, "titulo1", Len(aHit) == 1 .And. Val(cValToChar(aHit[1]:VAL)) == 4912.5)
    For nI := 1 To 12
        GEBSNFOL(MesT(nI), 1000, 40000)
    Next nI
    aR := GEBSNAPU("202605")
    lOk := Chk(lOk, "apu2 anexo V", aR[1] .And. aR[3][1] == "V" .And. aR[3][5] == 8718.75)
    aHit := TCSqlQuery("SELECT GFN3_VALOR AS VAL FROM GFN3 WHERE GFN3_DOC = 'DAS-202605' AND D_E_L_E_T_ = ' '")
    lOk := Chk(lOk, "titulo2", Len(aHit) == 1 .And. Val(cValToChar(aHit[1]:VAL)) == 8718.75)
    lOk := Chk(lOk, "gsn2 unica", Len(TCSqlQuery("SELECT GSN2_DAS FROM GSN2 WHERE GSN2_COMP = '202605' AND D_E_L_E_T_ = ' '")) == 1)
    TCSqlExec("UPDATE GFN3 SET GFN3_SALDO = 0, GFN3_STATUS = 'BAIXADO' WHERE GFN3_DOC = 'DAS-202605'")
    GEBSNCFG("III", "")
    aR := GEBSNAPU("202605")
    // DAS ja pago e reapuracao menor: alerta de restituicao, guia intacta.
    lOk := Chk(lOk, "apu3 alerta", aR[1] .And. "restituicao" $ aR[3][7])
    aHit := TCSqlQuery("SELECT GFN3_VALOR AS VAL FROM GFN3 WHERE GFN3_DOC = 'DAS-202605' AND D_E_L_E_T_ = ' '")
    lOk := Chk(lOk, "titulo3 intacto", Len(aHit) == 1 .And. Val(cValToChar(aHit[1]:VAL)) == 8718.75)
    GEBSNCFG("III", "202605")
    aR := GEBSNAPU("202605")
    lOk := Chk(lOk, "apu4 rbt12 inicio", aR[1] .And. aR[3][2] == 600000)
    lOk := Chk(lOk, "antes do inicio", !GEBSNAPU("202604")[1])

    // 4. Duas atividades
    TCSqlExec("DELETE FROM GSN1")
    TCSqlExec("DELETE FROM GSN2")
    TCSqlExec("DELETE FROM GSN4")
    TCSqlExec("DELETE FROM GF3")
    TCSqlExec("DELETE FROM GF4")
    TCSqlExec("DELETE FROM GFN3")
    GEBSNCFG("III", "")
    lOk := Chk(lOk, "atv COM", GEBSNATV("COM", "Comercio", "I")[1])
    lOk := Chk(lOk, "atv SRV", GEBSNATV("srv", "Servicos", "III")[1])
    lOk := Chk(lOk, "atv anexo invalido", !GEBSNATV("X", "x", "VII")[1])
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES " + ;
        "(' ', '      ', 'P_COM', '1', 'Revenda'), (' ', '      ', 'P_MONO', '2', 'Revenda monofasica'), (' ', '      ', 'P_SRV', '3', 'Servico')")
    lOk := Chk(lOk, "prd COM", GEBSNPRD("P_COM", "COM", "N", "N")[1])
    lOk := Chk(lOk, "prd MONO", GEBSNPRD("P_MONO", "COM", "N", "S")[1])
    lOk := Chk(lOk, "prd SRV", GEBSNPRD("P_SRV", "SRV", "N", "N")[1])
    lOk := Chk(lOk, "prd inexistente", !GEBSNPRD("NADA", "COM", "N", "N")[1])
    lOk := Chk(lOk, "prd atv inexistente", !GEBSNPRD("P_COM", "XXX", "N", "N")[1])
    lOk := Chk(lOk, "prd marca invalida", !GEBSNPRD("P_COM", "COM", "X", "N")[1])
    lOk := Chk(lOk, "folha com atividade", !GEBSNFOL("202610", 100, 0, "COM")[1])
    For nI := 1 To 12
        cComp := "2025" + StrZero(nI + 9, 2)
        If nI > 3
            cComp := "2026" + StrZero(nI - 3, 2)
        EndIf
        GEBSNFOL(cComp, 0, 40000)
    Next nI
    NotaT("NF-A", "P_COM", 10000, "20261005", "AUTORIZADA")
    NotaT("NF-B", "P_MONO", 10000, "20261006", "AUTORIZADA")
    NotaT("NF-C", "P_SRV", 10000, "20261007", "AUTORIZADA")
    NotaT("NF-D", "P_COM", 10000, "20261008", "AUTORIZADA")
    lOk := Chk(lOk, "exportacao", GEBSNEXP("NF-D", "S")[1])
    lOk := Chk(lOk, "exportacao nota inexistente", !GEBSNEXP("NF-Z", "S")[1])
    aR := GEBSNAPU("202610")
    lOk := Chk(lOk, "apu multi ok", aR[1])
    If aR[1]
        lOk := Chk(lOk, "apu multi anexos", aR[3][1] == "I,III")
        lOk := Chk(lOk, "apu multi rbt12", aR[3][2] == 480000)
        lOk := Chk(lOk, "apu multi das", aR[3][5] == 2539.75)
        lOk := Chk(lOk, "apu multi venc", aR[3][6] == "20261123")
    EndIf
    lOk := Chk(lOk, "gsn4 linhas", Len(TCSqlQuery("SELECT GSN4_ATIV FROM GSN4 WHERE GSN4_COMP = '202610' AND D_E_L_E_T_ = ' '")) == 4)
    lOk := Chk(lOk, "feriado invalido", !GEBSNFER("20261131", "x")[1])
    lOk := Chk(lOk, "feriado", GEBSNFER("20261123", "Feriado municipal")[1])
    aR := GEBSNAPU("202610")
    lOk := Chk(lOk, "apu feriado venc", aR[1] .And. aR[3][6] == "20261124")
    aHit := TCSqlQuery("SELECT GFN3_VENC AS VEN FROM GFN3 WHERE GFN3_DOC = 'DAS-202610' AND D_E_L_E_T_ = ' '")
    lOk := Chk(lOk, "titulo venc", Len(aHit) == 1 .And. AllTrim(cValToChar(aHit[1]:VEN)) == "20261124")

    // 4b. Devolucao de venda de 2.000 (comercio normal) no mes: receita 8.000 => 529,00; DAS 2.407,50
    TCSqlExec("CREATE TABLE GFT7 (R_E_C_N_O_ INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, D_E_L_E_T_ TEXT DEFAULT ' ', GFT7_FILIAL TEXT NOT NULL, " + ;
        "GFT7_DEV TEXT NOT NULL, GFT7_NOTA TEXT NOT NULL, GFT7_PROD TEXT NOT NULL, GFT7_QTD NUMERIC(18,4) NOT NULL, GFT7_VALOR NUMERIC(18,2) NOT NULL, " + ;
        "GFT7_CUSTO NUMERIC(18,2) NOT NULL, GFT7_DATA TEXT NOT NULL)")
    TCSqlExec("INSERT INTO GFT7 (D_E_L_E_T_, GFT7_FILIAL, GFT7_DEV, GFT7_NOTA, GFT7_PROD, GFT7_QTD, GFT7_VALOR, GFT7_CUSTO, GFT7_DATA) VALUES " + ;
        "(' ', '      ', 'DV1', 'NF-A', 'P_COM', 1, 2000, 0, '20261015')")
    aR := GEBSNAPU("202610")
    lOk := Chk(lOk, "devolucao deduz", aR[1] .And. aR[3][5] == 2407.5)
    // Devolucao maior que a receita do balde: deduz ate zerar e avisa.
    TCSqlExec("INSERT INTO GFT7 (D_E_L_E_T_, GFT7_FILIAL, GFT7_DEV, GFT7_NOTA, GFT7_PROD, GFT7_QTD, GFT7_VALOR, GFT7_CUSTO, GFT7_DATA) VALUES " + ;
        "(' ', '      ', 'DV2', 'NF-B', 'P_MONO', 1, 12000, 0, '20261016')")
    aR := GEBSNAPU("202610")
    lOk := Chk(lOk, "devolucao maior", aR[1] .And. aR[3][5] == 1848.74 .And. "sem receita" $ aR[3][7])
    // Sem devolucoes o mes volta ao valor original.
    TCSqlExec("DELETE FROM GFT7")
    // Devolucao de 4.000 em 09/2026 reduz o RBT12 de 10/2026 para 476.000.
    TCSqlExec("INSERT INTO GFT7 (D_E_L_E_T_, GFT7_FILIAL, GFT7_DEV, GFT7_NOTA, GFT7_PROD, GFT7_QTD, GFT7_VALOR, GFT7_CUSTO, GFT7_DATA) VALUES " + ;
        "(' ', '      ', 'DV3', 'NF-X', 'P_COM', 1, 4000, 0, '20260915')")
    aR := GEBSNAPU("202610")
    lOk := Chk(lOk, "devolucao no rbt12", aR[1] .And. aR[3][2] == 476000)
    TCSqlExec("DELETE FROM GFT7")
    aR := GEBSNAPU("202610")
    lOk := Chk(lOk, "sem devolucao volta", aR[1] .And. aR[3][5] == 2539.75)

    // 5. Relatorios
    lOk := Chk(lOk, "extrato nao apurado", !GEBSNEXTRATO("202609")[1])
    aR := GEBSNEXTRATO("202610")
    lOk := Chk(lOk, "extrato ok", aR[1])
    If aR[1]
        lOk := Chk(lOk, "extrato das", Chave(aR[3][1], "das") == 2539.75)
        lOk := Chk(lOk, "extrato guia", "aberto" $ Chave(aR[3][1], "guia"))
        lOk := Chk(lOk, "extrato linhas", Len(aR[3][2]) == 5)
        lOk := Chk(lOk, "extrato tributos", Round(SomaPares(aR[3][3]), 2) == 2539.75)
    EndIf
    lOk := Chk(lOk, "grade extrato", Len(TCSqlQuery("SELECT GBR1_ORDEM FROM GBR1 WHERE GBR1_SESSAO = " + GEBDBQuote(BOSESSAO()))) > 10)
    aR := GEBSNANUAL("2026")
    lOk := Chk(lOk, "anual ok", aR[1])
    If aR[1]
        lOk := Chk(lOk, "anual meses", Len(aR[3][1]) == 13)
        lOk := Chk(lOk, "anual outubro", aR[3][1][11][5] == 2539.75)
        lOk := Chk(lOk, "anual receita", Chave(aR[3][2], "receita_ano") == 40000)
    EndIf
    lOk := Chk(lOk, "anual invalido", !GEBSNANUAL("20")[1])

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebsn CASCADE")
    If lOk
        ConOut("T_GEBSN PASS")
    Else
        ConOut("T_GEBSN FAIL")
    EndIf
Return lOk

// Mes nI (1..12) da janela 202505..202604.
Static Function MesT(nI)
    If nI > 8
        Return "2026" + StrZero(nI - 8, 2)
    EndIf
Return "2025" + StrZero(nI + 4, 2)

Static Function NotaT(cChave, cProd, nBase, cEmis, cStatus)
    TCSqlExec("INSERT INTO GF3 (D_E_L_E_T_, GF3_FILIAL, GF3_CHAVE, GF3_TIPO, GF3_STATUS, GF3_BASE, GF3_IBS, GF3_CBS, GF3_EMIS) VALUES " + ;
        "(' ', '      ', '" + cChave + "', 'NFE', '" + cStatus + "', " + cValToChar(nBase) + ", 0, 0, '" + cEmis + "')")
    TCSqlExec("INSERT INTO GF4 (D_E_L_E_T_, GF4_FILIAL, GF4_CHAVE, GF4_ITEM, GF4_PROD, GF4_QTD, GF4_PRECO, GF4_BASE, GF4_IBS, GF4_CBS) VALUES " + ;
        "(' ', '      ', '" + cChave + "', '001', '" + cProd + "', 1, " + cValToChar(nBase) + ", " + cValToChar(nBase) + ", 0, 0)")
Return .T.

Static Function SomaTrib(aR)
    Local nS := 0
    Local nI := 0
    For nI := 1 To 8
        nS := nS + aR[3][nI]
    Next nI
Return Round(nS, 2)

Static Function SomaPares(aP)
    Local nS := 0
    Local nI := 0
    For nI := 1 To Len(aP)
        nS := nS + aP[nI][2]
    Next nI
Return nS

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
