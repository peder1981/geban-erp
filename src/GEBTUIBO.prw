#include "totvs.ch"
#include "GEBBO.prw"

/*/{Protheus.doc} GEBTUIBO
    Telas do backoffice: estoque/custos, financeiro, contabil, compras
    (submenus "Avancado" dos modulos existentes), faturamento e frente de
    loja (modulos novos do menu principal). Cada acao checa a mesma
    permissao da rota da API (GEBBOROTAS). Relatorios abrem em grade (GBR1;
    a primeira linha e' o cabecalho).
    @type Tela
    @author Peder Munksgaard
    @since 18/10/2026
/*/
// DANFE NFC-e do cupom: mostra na grade e da' o link de impressao (token novo da sessao).
Static Function TBODanfe(cEmp, cFil, cUsu, cCupom)
    Local aH := TCSqlQuery("SELECT GLJ3_NOTA AS N FROM GLJ3 WHERE GLJ3_FILIAL = " + GEBDBQuote(FWxFilial("GLJ3")) + " AND GLJ3_CUPOM = " + ;
        GEBDBQuote(Upper(BOCOL(cCupom))) + " AND D_E_L_E_T_ = ' '")
    Local aT := {}
    Local aRel := {{"DANFE NFC-e"}}
    Local cTok := ""
    Local nI := 0
    If Len(aH) == 0
        MsgStop("Cupom inexistente: " + cCupom, "DANFE")
        Return .F.
    EndIf
    aT := GEBDFEDANFETXT(BOCOL(aH[1]:N))
    If !aT[1]
        MsgStop("Cupom sem NFC-e eletronica (emissao interna).", "DANFE")
        Return .F.
    EndIf
    For nI := 1 To Len(aT[3])
        If !(aT[3][nI] == "---")
            aAdd(aRel, {StrTran(StrTran(StrTran(StrTran(aT[3][nI], "== ", ""), "!! ", "*** "), "|| ", ""), "|", "  ")})
        EndIf
    Next nI
    BOREL(aRel)
    cTok := GEBSECTOKEN(cUsu, cEmp, cFil, "danfe")
    MsgInfo("Para imprimir, abra no navegador: " + BOPARM("GEBAN_URL", "https://SEU-DOMINIO") + "/api/dfe/danfe?empresa=" + cEmp + ;
        "&cupom=" + Upper(BOCOL(cCupom)) + "&token=" + cTok, "DANFE NFC-e")
Return GEBTUIBRW("GBR1", "DANFE NFC-e " + cCupom)

Static Function TBOJ(oJ, cCampo)
    If oJ == Nil
        Return ""
    EndIf
Return BOCOL(oJ[cCampo])

