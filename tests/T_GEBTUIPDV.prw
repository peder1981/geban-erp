#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GENUC_CAD.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBSEC_TOKEN.prw"
#include "../src/GEBEXP_CTX.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBMON.prw"
#include "../src/GEBEXP_REL_BIZ.prw"
#include "../src/GEBEXP_REL_NUC.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GEBFIN_FLX.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBV_VEN.prw"
#include "../src/GEBV_FIA.prw"
#include "../src/GEBCTB_DIR.prw"
#include "../src/GEBCTB_BAL.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBCOM_FOR.prw"
#include "../src/GEBCOM_PED.prw"
#include "../src/GEBCOM_ENT.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBSN.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBREST.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBCTX.prw"
#include "../src/GEBEST.prw"
#include "../src/GEBFNX.prw"
#include "../src/GEBCPX.prw"
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
#include "../src/GEBBO.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBWEB_API.prw"
#include "../src/GEBBCO.prw"
#include "../src/GEBTUIBO.prw"
#include "../src/GEBTUI.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBEXP_TRAK.prw"
#include "../src/GEBTUIPDV.prw"

/*/{Protheus.doc} T_GEBTUIPDV
    PDV da Frente de loja (GEBTUIPDV.prw) sem interface: monta a pagina e
    exercita os handlers contra o banco -- caixa, carrinho (soma de quantidade,
    preco da tabela), pagamento com troco, venda, orcamento e fechamento.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 21/11/2026
/*/
User Function T_GEBTUIPDV()
    Local lOk  := .T.
    Local oApp := Nil
    Local oPg  := Nil
    Local aSt  := {"", "", {}, {}, "", ""}
    Local aUi  := {}
    Local aR   := {}
    Local aT   := {}

    If !GEBDBConecta()
        ConOut("T_GEBTUIPDV FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebtuipdv CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_tuipdv CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebtuipdv")
    TCSqlExec("CREATE SCHEMA emp_tuipdv")
    TCSqlExec("SET search_path TO emp_tuipdv, test_gebtuipdv")
    lOk := Chk(lOk, "mig", GENMIG() .And. TCSecMIG() .And. GEBFMIG() .And. GEBLOJMIG())
    GEBFNCON("BANCO", "Banco")
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'P1', 'N1', 'Banana prata kg')")
    TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'N1', 10, 5, '20200101', '20991231')")
    GEBFATPRC("", "P1", 10)
    GEBESTMOV("P1", "", "E", 100, 4, "COMPRA", "X", "20261001")

    oApp := PoApp():New("t")
    oPg := PoPage():New(oApp, "PDV")
    aUi := TUIPdvVenda(oApp, oPg, aSt, "super")
    lOk := Chk(lOk, "sem caixa nao finaliza", !TUIPdvFinaliza(oApp, aSt, aUi, "super"))

    GEBLOJCX("01", "Caixa 1", "", "")
    aR := TUIPdvAbre(aSt, "super", {"01", 100})
    lOk := Chk(lOk, "abre caixa", aR[1] .And. !Empty(aSt[1]) .And. aSt[2] == "01")
    lOk := Chk(lOk, "sessao aberta do operador", Len(TUIPdvSessao("super")) == 2)

    lOk := Chk(lOk, "produto inexistente", !TUIPdvAdd(oApp, aSt, aUi, "NAOEXISTE", 1, 0))
    TUIPdvAdd(oApp, aSt, aUi, "P1", 2, 0)
    TUIPdvAdd(oApp, aSt, aUi, "P1", 1, 0)
    lOk := Chk(lOk, "mesmo produto soma", Len(aSt[3]) == 1 .And. aSt[3][1][3] == 3)
    lOk := Chk(lOk, "preco da tabela e descricao", aSt[3][1][5] == 10 .And. aSt[3][1][6] == 30 .And. "Banana" $ aSt[3][1][2])
    aT := TUIPdvTotais(aSt, aUi)
    lOk := Chk(lOk, "total 30", aT[3] == 30 .And. aT[4] == 30)
    lOk := Chk(lOk, "sem pagamento nao finaliza", !TUIPdvFinaliza(oApp, aSt, aUi, "super"))

    TUIPdvPaga(oApp, aSt, aUi, "DINHEIRO", 50, 1, "")
    aT := TUIPdvTotais(aSt, aUi)
    lOk := Chk(lOk, "troco 20", aT[6] == 20 .And. aT[4] == 0)
    lOk := Chk(lOk, "vale sem numero recusado", !TUIPdvPaga(oApp, aSt, aUi, "VALE", 5, 1, ""))
    lOk := Chk(lOk, "finaliza", TUIPdvFinaliza(oApp, aSt, aUi, "super"))
    ConOut("  ultima venda: " + aSt[6])
    lOk := Chk(lOk, "troco na venda e carrinho limpo", "R$ 20,00" $ aSt[6] .And. Len(aSt[3]) == 0 .And. Len(aSt[4]) == 0)

    // devolucao do cupom da venda (grade de itens: P1 x 1) em vale-troca
    aR := TUIPdvDevolve(aSt, {SubStr(aSt[6], At("CP", aSt[6]), 10), "VALE", "teste", "", "", "", "", "", "", "", "", "", ""}, {{"P1", 1}})
    ConOut("  devolucao: " + BOSTR(aR[2]))
    lOk := Chk(lOk, "devolucao com item em vale", aR[1])
    lOk := Chk(lOk, "devolucao sem item recusada", !TUIPdvDevolve(aSt, {"CP00000001", "VALE", "x", "", "", "", "", "", "", "", "", "", ""}, {})[1])

    TUIPdvAdd(oApp, aSt, aUi, "P1", 1, 0)
    lOk := Chk(lOk, "orcamento", TUIPdvOrcamento(oApp, aSt, aUi, "super") .And. Len(aSt[3]) == 0)

    aR := TUIPdvFecha(aSt, {130})
    ConOut("  fechamento: " + aR[2])
    lOk := Chk(lOk, "fecha caixa", aR[1] .And. "diferenca" $ aR[2] .And. Empty(aSt[1]))
    lOk := Chk(lOk, "sem sessao depois de fechar", Len(TUIPdvSessao("super")) == 0)

    oPg := TUIPdvPg(oApp, "tuipdv", "", "super")
    lOk := Chk(lOk, "pagina completa monta", oPg != Nil)

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebtuipdv CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_tuipdv CASCADE")
    If lOk
        ConOut("T_GEBTUIPDV PASS")
    Else
        ConOut("T_GEBTUIPDV FAIL")
    EndIf
Return lOk

Static Function Chk(lOk, cNome, lCond)
    If lCond
        ConOut("  OK " + cNome)
        Return lOk
    EndIf
    ConOut("  FAIL " + cNome)
Return .F.
