#include "totvs.ch"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBSEC_TOKEN.prw"
#include "../src/GEBEXP_CTX.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBMON.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GENUC_CAD.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIN_FLX.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBV_VEN.prw"
#include "../src/GEBV_FIA.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBCTB_DIR.prw"
#include "../src/GEBCTB_BAL.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCOM_FOR.prw"
#include "../src/GEBCOM_PED.prw"
#include "../src/GEBCOM_ENT.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBREST.prw"
#include "../src/GEBEXP_REL_BIZ.prw"
#include "../src/GEBEXP_REL_NUC.prw"
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
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBTUI_FLUXOS
    Fase 4 da revisao geral: cada acao da tela (GEBTUI) executada pela
    MESMA funcao que a tela chama, em empresa descartavel zzflx, com os
    valores conferidos no banco contra docs/02-regras-negocio.md (sec. 11,
    aliquotas didaticas IBS 10% / CBS 5%, juros 0,33%/dia, multa 2%).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 02/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBTUI_FLUXOS()
    Local lOk   := .T.
    Local cEmp  := "zzflx"
    Local cUsu  := "T_FLX"
    Local cComp := Left(DToS(Date()), 6)
    Local cGuia := ""
    Local aRes  := {}
    Local aChk  := {}

    If !GEBDBConecta()
        ConOut("T_GEBTUI_FLUXOS FAIL")
        Return .F.
    EndIf
    GEBFLXLIMPA(cEmp, cUsu)
    If !GEBDBProvisionaCatalogo() .Or. !GEBDBProvisionaEmpresa(cEmp, "Empresa Fluxos")
        ConOut("T_GEBTUI_FLUXOS FAIL")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    DbSelectArea("GE1")
    If !GEBSECCRIAUSU(cUsu, "Senha#Forte1", {cEmp}, "Usuario Fluxos", "ADMIN")
        ConOut("T_GEBTUI_FLUXOS FAIL")
        Return .F.
    EndIf
    GEBDBSetTenant(cEmp)
    GEBFMIG()
    GEBFNMIG()
    GEBDMIG()
    GEBVMIG()
    GEBCMIG()
    GEBCMMIG()
    GEFFILMIG()
    GEUNIMIG()
    GEBDBSetTenant(cEmp)

    // ===== FISCAL: produto -> nota R$ 2.000 -> apuracao (sec. 11.1 / 11.2)
    aRes := GEBFLXRUN("ALISC", {|| GEBRESTALISC(cUsu, {"08039000", 10, 5, "20260101", "20301231"})})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2", "FIS aliquota NCM 08039000 IBS 10% CBS 5% (" + aRes[1] + ")")
    aRes := GEBFLXRUN("ALISC-SOBREPOSTA", {|| GEBRESTALISC(cUsu, {"08039000", 12, 6, "20270101", "20271231"})})
    lOk := GEBFLXOK(lOk, aRes[1] == "409", "FIS aliquota com vigencia sobreposta recusada (" + aRes[1] + ")")
    aRes := GEBFLXRUN("ALISC-VAZIA", {|| GEBRESTALISC(cUsu, {"08039002", "", "5", "20260101", "20301231"})})
    lOk := GEBFLXOK(lOk, aRes[1] == "400", "FIS aliquota com IBS em branco recusada (" + aRes[1] + ")")
    aRes := GEBFLXRUN("ALISC-NCM", {|| GEBRESTALISC(cUsu, {"BANANA", 10, 5, "20260101", "20301231"})})
    lOk := GEBFLXOK(lOk, aRes[1] == "400", "FIS NCM nao numerica recusada (" + aRes[1] + ")")
    aRes := GEBFLXRUN("ALISC-INVALIDA", {|| GEBRESTALISC(cUsu, {"08039001", 150, 5, "20260101", "20301231"})})
    lOk := GEBFLXOK(lOk, aRes[1] == "400", "FIS aliquota acima de 100% recusada (" + aRes[1] + ")")
    aRes := GEBFLXRUN("PRDLSC", {|| GEBRESTPRDLSC(cUsu, {"BANANA-PRATA", "08039000", "Banana prata"})})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2", "FIS produto cadastrado (" + aRes[1] + ")")
    aRes := GEBFLXRUN("NOTPOST", {|| GEBRESTNOTPOST(cUsu, {"NF-0001", "BANANA-PRATA", 10, 200})})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2", "FIS nota emitida (" + aRes[1] + ")")
    aChk := TCSqlQuery("SELECT GF3_BASE AS B, GF3_IBS AS I, GF3_CBS AS C, GF3_STATUS AS S FROM GF3 WHERE GF3_CHAVE = 'NF-0001' AND D_E_L_E_T_ = ' '")
    lOk := GEBFLXOK(lOk, Len(aChk) == 1 .And. Val(aChk[1]:B) == 2000 .And. Val(aChk[1]:I) == 200 .And. Val(aChk[1]:C) == 100, ;
        "FIS nota BASE 2000 IBS 200 CBS 100 (" + GEBFLXROW(aChk) + ")")
    aRes := GEBFLXRUN("FISAPU", {|| GEBRESTFISAPU(cUsu, {cComp})})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2", "FIS apuracao " + cComp + " (" + aRes[1] + ")")
    aChk := TCSqlQuery("SELECT GF5_DEB AS D, GF5_CRED AS C, GF5_SALDO AS S FROM GF5 WHERE GF5_COMP = '" + cComp + "' AND D_E_L_E_T_ = ' '")
    lOk := GEBFLXOK(lOk, Len(aChk) == 1 .And. Val(aChk[1]:D) == 300 .And. Val(aChk[1]:S) == 300, "FIS apuracao DEB 300 SALDO 300 (" + GEBFLXROW(aChk) + ")")

    // ===== DERRAMA: guia -> juros 10 dias -> parcelamento 3x (sec. 11.2, base 300)
    aRes := GEBFLXRUN("DERGER", {|| GEBRESTDERGER(cUsu, {cComp})})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2", "DER guia gerada (" + aRes[1] + ")")
    cGuia := "GD" + cComp
    aChk := TCSqlQuery("SELECT GD1_VALOR AS V, GD1_TOTAL AS T, GD1_STATUS AS S FROM GD1 WHERE GD1_GUIA = '" + cGuia + "' AND D_E_L_E_T_ = ' '")
    lOk := GEBFLXOK(lOk, Len(aChk) == 1 .And. Val(aChk[1]:V) == 300 .And. AllTrim(aChk[1]:S) == "ABERTA", "DER guia " + cGuia + " VALOR 300 ABERTA (" + GEBFLXROW(aChk) + ")")
    aRes := GEBFLXRUN("DERJUR", {|| GEBRESTDERJUR(cUsu, {cGuia, 10})})
    aChk := TCSqlQuery("SELECT GD1_JUROS AS J, GD1_MULTA AS M, GD1_TOTAL AS T FROM GD1 WHERE GD1_GUIA = '" + cGuia + "' AND D_E_L_E_T_ = ' '")
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2" .And. Len(aChk) == 1 .And. Abs(Val(aChk[1]:J) - 9.9) < 0.005 .And. Abs(Val(aChk[1]:M) - 6) < 0.005 .And. Abs(Val(aChk[1]:T) - 315.9) < 0.005, ;
        "DER juros 10 dias: juros 9,90 multa 6 total 315,90 (" + aRes[1] + " " + GEBFLXROW(aChk) + ")")
    aRes := GEBFLXRUN("DERPAR", {|| GEBRESTDERPAR(cUsu, {cGuia, 3})})
    aChk := TCSqlQuery("SELECT SUM(GD2_VALOR) AS T, COUNT(*) AS N FROM GD2 WHERE GD2_GUIA = '" + cGuia + "' AND D_E_L_E_T_ = ' '")
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2" .And. Len(aChk) == 1 .And. Val(aChk[1]:N) == 3 .And. Abs(Val(aChk[1]:T) - 315.9) < 0.005, ;
        "DER parcelado 3x somando 315,90 (" + aRes[1] + " " + GEBFLXROW(aChk) + ")")

    // Parcelas somam o total ao centavo (100 em 3 = 33,33 + 33,33 + 33,34).
    TCSqlExec("INSERT INTO GD1 (D_E_L_E_T_, GD1_FILIAL, GD1_GUIA, GD1_COMP, GD1_VALOR, GD1_JUROS, GD1_MULTA, GD1_TOTAL, GD1_STATUS) VALUES (' ', '" + FWxFilial("GE1") + "', 'GDCEM', '202601', 100, 0, 0, 100, 'ABERTA')")
    aRes := GEBFLXRUN("DERPAR100", {|| GEBRESTDERPAR(cUsu, {"GDCEM", 3})})
    aChk := TCSqlQuery("SELECT SUM(GD2_VALOR)::text AS T, MAX(GD2_VALOR)::text AS X FROM GD2 WHERE GD2_GUIA = 'GDCEM' AND D_E_L_E_T_ = ' '")
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2" .And. Len(aChk) == 1 .And. AllTrim(aChk[1]:T) == "100.00", "DER 100 em 3 parcelas soma 100,00 (" + aRes[1] + " " + GEBFLXROW(aChk) + ")")

    // ===== VENDA / ESTOQUE / FIADO (sec. 9 e 11.4)
    // Estoque com custo (kardex + GV1): 50 a 4,00.
    GEBESTMOV("BANANA-PRATA", "", "E", 50, 4, "COMPRA", "SEED", BOHOJE())
    aRes := GEBFLXRUN("ESTVEN", {|| GEBRESTESTVEN(cUsu, {"V-0001", "BANANA-PRATA", 10, 200})})
    aChk := TCSqlQuery("SELECT GV1_SALDO AS S FROM GV1 WHERE GV1_PROD = 'BANANA-PRATA' AND D_E_L_E_T_ = ' '")
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2" .And. Len(aChk) == 1 .And. Val(aChk[1]:S) == 40, "EST venda de 10 baixa o saldo 50 -> 40 (" + aRes[1] + " " + GEBFLXROW(aChk) + ")")
    aChk := TCSqlQuery("SELECT GF3_BASE AS B FROM GF3 WHERE GF3_CHAVE = 'V-0001' AND D_E_L_E_T_ = ' '")
    lOk := GEBFLXOK(lOk, Len(aChk) == 1 .And. Val(aChk[1]:B) == 2000, "EST venda emite nota BASE 2000 (" + GEBFLXROW(aChk) + ")")
    aRes := GEBFLXRUN("ESTFIA800", {|| GEBRESTESTFIA(cUsu, {"CLI-01", 800})})
    aRes := GEBFLXRUN("ESTFIA300", {|| GEBRESTESTFIA(cUsu, {"CLI-01", 300})})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "4", "FIA 800 + 300 > limite 1000 recusado (" + aRes[1] + ")")
    aRes := GEBFLXRUN("ESTFIA200", {|| GEBRESTESTFIA(cUsu, {"CLI-01", 200})})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2", "FIA 800 + 200 = 1000 aceito (" + aRes[1] + ")")
    aChk := TCSqlQuery("SELECT SUM(GV3_VALOR) AS T FROM GV3 WHERE GV3_CLI = 'CLI-01' AND D_E_L_E_T_ = ' '")
    lOk := GEBFLXOK(lOk, Len(aChk) == 1 .And. Val(aChk[1]:T) == 1000, "FIA caderninho do CLI-01 soma 1000 (" + GEBFLXROW(aChk) + ")")

    // ===== FINANCEIRO: conta -> baixa (sec. 13)
    aRes := GEBFLXRUN("FINCON", {|| GEBRESTFINCON(cUsu, {"CAIXA", "Caixa"})})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2", "FIN conta CAIXA (" + aRes[1] + ")")
    TCSqlExec("INSERT INTO GFN2 (D_E_L_E_T_, GFN2_FILIAL, GFN2_DOC, GFN2_CLI, GFN2_VALOR, GFN2_SALDO, GFN2_VENC, GFN2_STATUS) VALUES (' ', '" + FWxFilial("GE1") + "', 'REC-01', 'CLI-01', 100, 100, '20261231', 'ABERTO')")
    aRes := GEBFLXRUN("FINBAI", {|| GEBRESTFINBAI(cUsu, {"REC", "REC-01", 100})})
    aChk := TCSqlQuery("SELECT GFN1_SALDO AS S FROM GFN1 WHERE GFN1_CONTA = 'CAIXA' AND D_E_L_E_T_ = ' '")
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2" .And. Len(aChk) == 1 .And. Val(aChk[1]:S) == 2100, "FIN baixa de 100 entra no CAIXA, que ja tinha a venda a vista de 2000 (" + aRes[1] + " " + GEBFLXROW(aChk) + ")")

    // ===== CONTABIL: lancamento direto -> DRE (sec. 8 e 11.3)
    aRes := GEBFLXRUN("CTBDIR-DESLIGADO", {|| GEBRESTCTBDIR(cUsu, {"1.01.001", "3.01.001", 2000})})
    lOk := GEBFLXOK(lOk, aRes[1] == "403" .And. At("PERMITE_DIRETA", aRes[2]) > 0, "CTB direto desligado diz o motivo (" + aRes[1] + ")")
    TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '" + FWxFilial("GE4") + "', 'PERMITE_DIRETA', 'S')")
    aRes := GEBFLXRUN("CTBDIR", {|| GEBRESTCTBDIR(cUsu, {"1.01.001", "3.01.001", 2000})})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2", "CTB lancamento direto receita 2000 (" + aRes[1] + " " + Left(aRes[2], 160) + ")")
    aRes := GEBFLXRUN("CTBDIR2", {|| GEBRESTCTBDIR(cUsu, {"4.01.001", "1.01.001", 1500})})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2", "CTB lancamento direto despesa 1500 (" + aRes[1] + " " + Left(aRes[2], 160) + ")")
    aRes := GEBFLXRUN("CTBDRE", {|| GEBRESTCTBDRE(cUsu, cComp)})
    // DRE da competencia = receitas (grupo 3) - despesas (grupo 4), com a
    // contabilizacao integrada: nota 2000 + venda 2000 + fiados 1000 de
    // receita, - 300 de IBS/CBS apurado, - 15,90 de juros embutidos no
    // parcelamento da guia, - 40 de CMV (10 a 4,00); a baixa do recebivel
    // nao e' receita (caixa x clientes). Mais os diretos (2000 - 1500 = 500,
    // o exemplo da sec. 11.3): 5144,10.
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2" .And. At('"resultado",5144.1', StrTran(aRes[2], " ", "")) > 0, "CTB DRE integrada = 5144,10 (" + aRes[1] + " " + Left(aRes[2], 160) + ")")
    aRes := GEBFLXRUN("CTBBAL", {|| GEBRESTCTBBAL(cUsu, cComp)})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2" .And. At("3.01.001", aRes[2]) > 0 .And. At("4.01.001", aRes[2]) > 0, "CTB balancete da competencia traz as contas movimentadas (" + aRes[1] + " " + Left(aRes[2], 200) + ")")

    // ===== COMPRAS: fornecedor -> pedido -> item -> entrada NF (sec. 14)
    aRes := GEBFLXRUN("COMFOR", {|| GEBRESTCOMFOR(cUsu, {"FORN-01", "Fornecedor 01"})})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2", "COM fornecedor (" + aRes[1] + ")")
    aRes := GEBFLXRUN("COMPED", {|| GEBRESTCOMPED(cUsu, {"PED-01", "FORN-01"})})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2", "COM pedido (" + aRes[1] + ")")
    aRes := GEBFLXRUN("COMIT", {|| GEBRESTCOMIT(cUsu, {"PED-01", "BANANA-PRATA", 2, 10})})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2", "COM item 2 x 10 (" + aRes[1] + ")")
    aRes := GEBFLXRUN("COMENT", {|| GEBRESTCOMENT(cUsu, {"NF-C01", "PED-01"})})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2", "COM entrada da NF (" + aRes[1] + ")")
    aChk := TCSqlQuery("SELECT GFN3_VALOR AS V FROM GFN3 WHERE GFN3_DOC = 'NF-C01' AND D_E_L_E_T_ = ' '")
    lOk := GEBFLXOK(lOk, Len(aChk) == 1 .And. Val(aChk[1]:V) == 20, "COM entrada gera pagar de 20 (" + GEBFLXROW(aChk) + ")")
    aChk := TCSqlQuery("SELECT GV1_SALDO AS S FROM GV1 WHERE GV1_PROD = 'BANANA-PRATA' AND D_E_L_E_T_ = ' '")
    lOk := GEBFLXOK(lOk, Len(aChk) == 1 .And. Val(aChk[1]:S) == 42, "COM entrada soma 2 no estoque 40 -> 42 (" + GEBFLXROW(aChk) + ")")

    // ===== NUCLEO: nova empresa (com schema), unidade, filial
    aRes := GEBFLXRUN("EMPLSC-ADMIN", {|| GEBRESTEMPLSC(cUsu, {"zzflx2", "Empresa Fluxos 2"})})
    lOk := GEBFLXOK(lOk, aRes[1] == "403", "NUC ADMIN nao cria empresa (so o super) (" + aRes[1] + ")")
    aRes := GEBFLXRUN("EMPLSC", {|| GEBRESTEMPLSC("super", {"zzflx2", "Empresa Fluxos 2"})})
    TCSqlExec("SET search_path TO public")
    aChk := TCSqlQuery("SELECT nspname FROM pg_namespace WHERE nspname = 'emp_zzflx2'")
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2" .And. Len(aChk) == 1, "NUC super cria empresa e o schema emp_zzflx2 (" + aRes[1] + ")")
    GEBDBSetTenant(cEmp)
    aRes := GEBFLXRUN("UNILSC", {|| GEBRESTUNILSC(cUsu, {"01", "Unidade 01"})})
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2", "NUC unidade (" + aRes[1] + " " + Left(aRes[2], 120) + ")")
    aRes := GEBFLXRUN("FILSC", {|| GEBRESTFILSC(cUsu, {"ZZ0101", "Filial D'Avila"})})
    aChk := TCSqlQuery("SELECT GEF1_NOME AS N FROM GEF1 WHERE GEF1_COD = 'ZZ0101' AND D_E_L_E_T_ = ' '")
    lOk := GEBFLXOK(lOk, Left(aRes[1], 1) == "2" .And. Len(aChk) == 1 .And. AllTrim(aChk[1]:N) == "Filial D'Avila", "NUC filial com apostrofo gravada sem aspas dobradas (" + aRes[1] + " " + GEBFLXROW(aChk) + ")")

    GEBFLXLIMPA(cEmp, cUsu)
    If lOk
        ConOut("T_GEBTUI_FLUXOS PASS")
    Else
        ConOut("T_GEBTUI_FLUXOS FAIL")
    EndIf
Return lOk

Static Function GEBFLXRUN(cNome, bAcao)
    Local aRes := Eval(bAcao)
    If ValType(aRes) != "A" .Or. Len(aRes) < 2
        aRes := {"000", "sem resposta"}
    EndIf
    aRes := {cValToChar(aRes[1]), cValToChar(aRes[2])}
    If Left(aRes[1], 1) != "2"
        ConOut("  [" + cNome + "] " + aRes[1] + " " + Left(aRes[2], 200))
    EndIf
Return aRes

Static Function GEBFLXROW(aChk)
    Local cTxt := ""
    Local aKeys := {}
    Local nI := 0
    If Len(aChk) == 0
        Return "sem linha"
    EndIf
    aKeys := aChk[1]:GetNames()
    For nI := 1 To Len(aKeys)
        cTxt := cTxt + aKeys[nI] + "=" + cValToChar(aChk[1][aKeys[nI]]) + " "
    Next nI
Return AllTrim(cTxt)

Static Function GEBFLXOK(lOk, lCond, cMsg)
    If lCond
        ConOut("  OK " + cMsg)
        Return lOk
    EndIf
    ConOut("FAIL: " + cMsg)
Return .F.

Static Function GEBFLXLIMPA(cEmp, cUsu)
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cEmp + " CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_zzflx2 CASCADE")
    TCSqlExec("DELETE FROM GE2_TOK WHERE TOK_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD IN ('zzflx', 'zzflx2')")
Return .T.
