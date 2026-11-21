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
#include "../src/GEBEXP_TRAK.prw"
#include "../src/GEBTUIPDV.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"

/*/{Protheus.doc} T_GEBTUI_OPS
    Varredura das telas do app: todo modulo tem rotulos e TODA operacao,
    forcada sem interface (respostas vazias), volta sem derrubar o processo.
    Pega funcao inexistente, campo errado e travamento que so' aparecem
    executando (foi assim que Today() no PDV apareceu).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 21/11/2026
/*/
User Function T_GEBTUI_OPS()
    Local lOk   := .T.
    Local aMods := {}
    Local nM    := 0
    Local nO    := 0
    Local aForms := {}
    Local aVal  := {}
    Local aR    := {}

    If !GEBDBConecta()
        ConOut("T_GEBTUI_OPS FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebtuiops CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebtuiops")
    TCSqlExec("SET search_path TO test_gebtuiops, public")
    GENMIG()
    GEBFMIG()
    GEBLOJMIG()
    GEBCPXMIG()
    GEBBCOMIG()
    GEBTUIBRWAPP({|cAlias, cTit| ConOut("    grade " + cAlias + ": " + cTit), .T.})
    aMods := TUIModulos("zz", "", "super")
    lOk := Chk(lOk, "modulos", Len(aMods) >= 9)
    aForms := TUIFormularios("zz", "")
    // formularios do PDV que nao dependem da sessao de caixa
    aEval(TUIPdvCadastros(), {|x| aAdd(aForms, x)})
    aEval(TUIPdvRelatorios(), {|x| aAdd(aForms, x)})
    aEval(TUIPdvTef(), {|x| aAdd(aForms, x)})
    For nM := 1 To Len(aForms)
        aVal := {}
        For nO := 1 To Len(aForms[nM][5])
            aAdd(aVal, aForms[nM][5][nO][3])
        Next nO
        ConOut("  form " + aForms[nM][1] + ": " + aForms[nM][4])
        aR := Eval(aForms[nM][6], "super", aVal, {})
        lOk := Chk(lOk, "form " + aForms[nM][4] + " responde", ValType(aR) == "A" .And. Len(aR) >= 2)
    Next nM
    ConOut("  formularios executados: " + cValToChar(Len(aForms)))
    // Todas as operacoes sao formularios. Queda inesperada = operacao perdida.
    lOk := Chk(lOk, "formularios", Len(aForms) >= 140)

    // JSON dos formularios do DF-e: UF maiuscula, IBGE direto, CONT_UF nao vai
    aR := TUIDfeJson({|o| {.T., o:ToJson()}}, {"UF", "MUNICIPIO", "CONT_UF", "CONT_MUNICIPIO"}, {"sp", "3550308", "rj", "3304557"})
    ConOut("  dfe json: " + BOSTR(aR[2]))
    lOk := Chk(lOk, "dfe json uf e ibge", aR[1] .And. '"UF": "SP"' $ aR[2] .And. '"MUNICIPIO": "3550308"' $ aR[2] .And. '"CONT_MUNICIPIO": "3304557"' $ aR[2])
    lOk := Chk(lOk, "dfe json sem CONT_UF", !("CONT_UF" $ aR[2]))
    lOk := Chk(lOk, "menor preco sem cotacao recusado", !TUIMenorPreco("PRODUTO_SEM_COTACAO")[1])

    // Grade de relatorio por sessao: outra janela de hoje fica intacta, sobra de dia anterior sai
    BOMIG()
    TCSqlExec("INSERT INTO GBR1 (D_E_L_E_T_, GBR1_FILIAL, GBR1_SESSAO, GBR1_ORDEM, GBR1_C1, GBR1_C2, GBR1_C3, GBR1_C4, GBR1_C5, GBR1_C6, GBR1_C7, GBR1_C8) " + ;
        "VALUES (' ', " + GEBDBQuote(FWxFilial("GBR1")) + ", " + GEBDBQuote("S" + DToS(Date()) + "OUTRA") + ", 1, 'outra', '', '', '', '', '', '', ''), " + ;
        "(' ', " + GEBDBQuote(FWxFilial("GBR1")) + ", 'S20000101VELHA', 1, 'velha', '', '', '', '', '', '', '')")
    BOREL({{"Cab"}, {"minha"}})
    lOk := Chk(lOk, "relatorio de outra sessao intacto", Len(TCSqlQuery("SELECT 1 AS X FROM GBR1 WHERE GBR1_C1 = 'outra'")) == 1)
    lOk := Chk(lOk, "sobra de dia anterior apagada", Len(TCSqlQuery("SELECT 1 AS X FROM GBR1 WHERE GBR1_C1 = 'velha'")) == 0)
    lOk := Chk(lOk, "sessao ve so' o seu relatorio", Len(TCSqlQuery("SELECT 1 AS X FROM GBR1 WHERE GBR1_SESSAO = " + GEBDBQuote(BOSESSAO()))) == 2)
    lOk := Chk(lOk, "sessao com data de hoje", Left(BOSESSAO(), 9) == "S" + DToS(Date()))

    // Grade nunca mostra credencial
    lOk := Chk(lOk, "sigilo GE2 SEC_SALT", TUISigilo("GE2", "SEC_SALT"))
    lOk := Chk(lOk, "sigilo GE2_SEC SEC_HASH", TUISigilo("GE2_SEC", "SEC_HASH"))
    lOk := Chk(lOk, "sigilo coluna comum visivel", !TUISigilo("GE2", "GE2_NOME") .And. !TUISigilo("GF1", "GF1_COD"))

    // Nucleo: senha divergente, permissao concedida aparece no relatorio, ciclo sem usuario
    lOk := Chk(lOk, "nucleo senhas diferentes", !TUINucUsuario("super", {"u_x", "X", "USUARIO", "Abc!2345x", "Abc!2345y", "zz", ""})[1])
    aR := TUINucPerm("super", {"OPERTST", "1", "S", "E"}, GEBTUIAREAS(), "zz")
    ConOut("  nucleo perm: " + BOSTR(aR[2]))
    lOk := Chk(lOk, "nucleo concede permissao", aR[1])
    lOk := Chk(lOk, "nucleo relatorio de permissoes", TUINucPermRel({"OPERTST", "E"}, "zz")[1] .And. ;
        Len(TCSqlQuery("SELECT 1 AS X FROM GBR1 WHERE GBR1_C3 = 'permitido' AND D_E_L_E_T_ = ' '")) >= 1)
    lOk := Chk(lOk, "nucleo ciclo sem usuario", !TUINucCiclo("super", {"", "1", ""})[1])
    lOk := Chk(lOk, "dfe municipio inexistente recusado", !TUIDfeJson({|o| {.T., ""}}, {"UF", "MUNICIPIO"}, {"SP", "Xyzzyqwv"})[1])
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebtuiops CASCADE")
    If lOk
        ConOut("T_GEBTUI_OPS PASS")
    Else
        ConOut("T_GEBTUI_OPS FAIL")
    EndIf
Return lOk

Static Function Chk(lOk, cNome, lCond)
    If lCond
        ConOut("  OK " + cNome)
        Return lOk
    EndIf
    ConOut("  FAIL " + cNome)
Return .F.
