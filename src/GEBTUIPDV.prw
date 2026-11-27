#include "totvs.ch"

/*/{Protheus.doc} GEBTUIPDV
    Frente de loja embutida no TUI: o PDV vive dentro do ERP, na mesma
    sessao e com a mesma permissao LOJA dos demais modulos — sem aba
    extra, sem segundo login. As operacoes chamam direto as funcoes de
    negocio GEBLOJ, GEBLOJ_OPE, GEBLOJ_CAD, GEBTEF, GEBDFE, GEBCRY, as mesmas
    que a API /api/pdv/* usa, entao validacoes, TEF, NFC-e, crypto,
    vale/fiado e Sarney sao identicos aos do PDV web.
    Estado da venda em Static: cada sessao do advplc serve tem o seu.
    @type function
    @author Peder Munksgaard
    @since 27/11/2026
/*/

// Estado da janela (por sessao).
Static s_cPdvUsu := ""
Static s_oPdvApp := Nil
Static s_cPdvSes := ""
Static s_cPdvOrc := ""
Static s_nPdvSeq := 0
Static s_nPdvIt  := 0
Static s_nPdvPg  := 0
Static s_nPdvDv  := 0
Static s_aPdvIt  := {}
Static s_aPdvPg  := {}
Static s_aPdvDv  := {}

// Widgets compartilhados entre abas (tabelas e infos de resultado).
Static s_oPdvSesI := Nil
Static s_oPdvTotI := Nil
Static s_oPdvTitI := Nil
Static s_oPdvItT  := Nil
Static s_oPdvPgT  := Nil
Static s_oPdvDvT  := Nil
Static s_oPdvSesT := Nil
Static s_oPdvOrcT := Nil
Static s_oPdvResI := Nil
Static s_oPdvResT := Nil
Static s_oPdvDesI := Nil
Static s_nPdvDesc := 0

/*/{Protheus.doc} TUIPdvPg
    Pagina "Frente de loja" com as abas do PDV.
    @type function
/*/
Static Function TUIPdvPg(oApp, cUsu)
    Local oPg   := PoPage():New(oApp, "Frente de loja")
    Local oTabs := PoTabs():New(oPg)
    Local aSes  := {}

    s_oPdvApp := oApp
    s_cPdvUsu := cUsu
    s_cPdvSes := ""
    s_cPdvOrc := ""
    s_aPdvIt  := {}
    s_aPdvPg  := {}
    s_aPdvDv  := {}
    s_nPdvSeq := 0
    s_nPdvIt  := 0
    s_nPdvPg  := 0
    s_nPdvDv  := 0
    GEBLOJMIG()
    aSes := TUIPdvPickSes(cUsu)
    If Len(aSes) > 0
        s_cPdvSes := aSes[1]
    EndIf
    TUIPdvVendaTab(PoTab():New(oTabs, "Venda"), oApp, cUsu)
    TUIPdvCaixaTab(PoTab():New(oTabs, "Caixa"), oApp, cUsu)
    TUIPdvOrcTab(PoTab():New(oTabs, "Orcamentos"), oApp, cUsu)
    TUIPdvDevTab(PoTab():New(oTabs, "Devolucao"), oApp, cUsu)
    TUIPdvConsTab(PoTab():New(oTabs, "Consultas"), oApp, cUsu)
    TUIPdvCadTab(PoTab():New(oTabs, "Cadastros"), oApp, cUsu)
    TUIPdvRelTab(PoTab():New(oTabs, "Relatorios"), oApp, cUsu)
    TUIPdvTefTab(PoTab():New(oTabs, "TEF / NFC-e"), oApp, cUsu)
    oPg:AddAction("Atualizar", {|| TUIPdvRefreshAll()})
    TUIPdvRefreshAll()
Return oPg

// Sessao de caixa aberta: prefere a do proprio operador; senao a 1a.
Static Function TUIPdvPickSes(cUsu)
    Local aHit := {}
    Local aSes := {}
    Local nI := 0 as Numeric

    aHit := TCSqlQuery("SELECT GLJ2_SESSAO AS S, GLJ2_CAIXA AS C, GLJ2_OPER AS O, GLJ2_FUNDO AS F, GLJ2_ABERT AS A, GLJ2_HORA AS H " + ;
        "FROM GLJ2 WHERE GLJ2_FILIAL = " + GEBDBQuote(FWxFilial("GLJ2")) + " AND GLJ2_STATUS = 'ABERTA' AND D_E_L_E_T_ = ' ' ORDER BY GLJ2_ABERT, GLJ2_SESSAO")
    For nI := 1 To Len(aHit)
        If Upper(BOCOL(aHit[nI]:O)) == Upper(cUsu)
            aSes := {BOCOL(aHit[nI]:S), BOCOL(aHit[nI]:C), BOCOL(aHit[nI]:O), BOVAL(aHit[nI]:F), BOCOL(aHit[nI]:A), BOCOL(aHit[nI]:H)}
            Exit
        EndIf
    Next nI
    If Len(aSes) == 0 .And. Len(aHit) > 0
        aSes := {BOCOL(aHit[1]:S), BOCOL(aHit[1]:C), BOCOL(aHit[1]:O), BOVAL(aHit[1]:F), BOCOL(aHit[1]:A), BOCOL(aHit[1]:H)}
    EndIf
Return aSes

Static Function TUIPdvMsg(oApp, aR)
    If ValType(aR) == "A" .And. Len(aR) >= 2
        If aR[1] == .T.
            oApp:Notify(BOSTR(aR[2]), "success")
        Else
            oApp:Notify(BOSTR(aR[2]), "error")
        EndIf
    EndIf
Return aR

// ===== VENDA =====

Static Function TUIPdvVendaTab(oTab, oApp, cUsu)
    Local wSes := PoWidget():New(oTab, "Sessao de caixa")
    Local wAdd := PoWidget():New(oTab, "Adicionar item")
    Local wCar := PoWidget():New(oTab, "Itens do cupom")
    Local wPag := PoWidget():New(oTab, "Pagamentos")
    Local wCli := PoWidget():New(oTab, "Cliente / operador / regime")
    Local wAco := PoWidget():New(oTab, "Finalizar")
    Local oCod := PoInput():New(wAdd, "Produto / codigo de barras / etiqueta de balanca")
    Local oQtd := PoNumber():New(wAdd, "Quantidade", 1)
    Local oIt  := PoTable():New(wCar)
    Local oPgT := PoTable():New(wPag)
    Local oCli := PoInput():New(wCli, "Cliente (opcional)")
    Local oVen := PoInput():New(wCli, "Vendedor (opcional)")
    Local oCpf := PoInput():New(wCli, "CPF/CNPJ do consumidor (opcional)")
    Local oDes := PoNumber():New(wCli, "Desconto no cupom (R$)", 0)
    Local oReg := PoSelect():New(wCli, "Regime", {{"Fiscal (NFC-e)", "FISCAL"}, {"Comprovante (sem NFC-e)", "COMPROVANTE"}}, "FISCAL")
    Local oSup := PoInput():New(wCli, "Supervisor (se desconto acima do limite)")
    Local oSupS := PoPassword():New(wCli, "Senha do supervisor")
    Local oForma := PoSelect():New(wPag, "Forma", {{"Dinheiro", "DINHEIRO"}, {"PIX", "PIX"}, {"Debito", "DEBITO"}, {"Credito", "CREDITO"}, {"Fiado", "FIADO"}, {"Vale-troca", "VALE"}, {"Crypto", "CRYPTO"}}, "DINHEIRO")
    Local oVal  := PoNumber():New(wPag, "Valor (R$)", 0)
    Local oParc := PoNumber():New(wPag, "Parcelas (so credito, ate 12)", 1)
    Local oDoc  := PoInput():New(wPag, "Documento (vale / MOEDA|ENDERECO / NSU TEF)")
    Local oBruto := PoInfo():New(wAco, "Bruto", "0,00")
    Local oDesc  := PoInfo():New(wAco, "Desconto", "0,00")
    Local oTota  := PoInfo():New(wAco, "TOTAL", "0,00")
    Local oPago  := PoInfo():New(wAco, "Pago", "0,00")
    Local oTroc  := PoInfo():New(wAco, "Troco previsto", "0,00")
    Local oRes   := PoInfo():New(wAco, "Resultado", "")
    Local oB     := Nil

    wSes:SetCols(4)
    wAdd:SetCols(4)
    wCar:SetCols(8)
    wPag:SetCols(8)
    wCli:SetCols(4)
    wAco:SetCols(6)
    s_oPdvSesI := PoInfo():New(wSes, "", "")
    s_oPdvTitI := s_oPdvSesI
    oCod:SetCols(3)
    oQtd:SetCols(1)
    oIt:SetColumns({{"n", "#"}, {"c1", "Cod"}, {"c2", "Descricao"}, {"c3", "Qtd"}, {"c4", "Preco"}, {"c5", "Total"}})
    oIt:OnSelect({|o, aLin| s_nPdvIt := Val(BOSTR(aLin[1]))})
    oPgT:SetColumns({{"n", "#"}, {"c1", "Forma"}, {"c2", "Valor"}, {"c3", "Parc"}, {"c4", "Doc"}})
    oPgT:OnSelect({|o, aLin| s_nPdvPg := Val(BOSTR(aLin[1]))})
    oB := PoButton():New(wAdd, "Adicionar item", {|| TUIPdvAddItem(oApp, cUsu, oCod, oQtd)})
    oB:Set("kind", "primary")
    oB:Set("icon", "an an-plus")
    oB := PoButton():New(wCar, "Remover item selecionado", {|| TUIPdvDelItem(oApp)})
    oB:Set("kind", "tertiary")
    oB := PoButton():New(wPag, "Adicionar pagamento", {|| TUIPdvAddPgto(oApp, oForma, oVal, oParc, oDoc)})
    oB:Set("kind", "secondary")
    oB := PoButton():New(wPag, "Limpar pagamentos", {|| TUIPdvLimpaPag()})
    oB:Set("kind", "tertiary")
    oB := PoButton():New(wAco, "FINALIZAR VENDA", {|| TUIPdvFinaliza(oApp, cUsu, oCli, oVen, oCpf, oDes, oReg, oSup, oSupS)})
    oB:Set("kind", "primary")
    oB:Set("icon", "an an-check")
    oB := PoButton():New(wAco, "Salvar como orcamento", {|| TUIPdvSalvaOrc(oApp, cUsu, oCli, oVen, oDes)})
    oB:Set("kind", "secondary")
    s_oPdvDesI := oDes
    s_oPdvItT := oIt
    s_oPdvPgT := oPgT
    s_oPdvTotI := {oBruto, oDesc, oTota, oPago, oTroc, oRes}
Return

// Sessao corrente rotulada; sem sessao aberta avisa para usar a aba Caixa.
Static Function TUIPdvSessaoTxt()
    Local aSes := {} as Array
    Local cTxt := "" as Character

    If s_cPdvSes == ""
        aSes := TUIPdvPickSes(s_cPdvUsu)
        If Len(aSes) > 0
            s_cPdvSes := aSes[1]
        EndIf
    EndIf
    If s_cPdvSes == ""
        Return "Sem sessao de caixa aberta - abra na aba Caixa"
    EndIf
    aSes := GEBLOJSES(s_cPdvSes)
    If Len(aSes) == 0
        cTxt := "Sessao " + s_cPdvSes + " nao existe mais - abra na aba Caixa"
        s_cPdvSes := ""
        Return cTxt
    EndIf
Return "Sessao " + aSes[1] + "  Caixa " + aSes[2] + "  Operador " + aSes[6] + "  Fundo " + BONUM(aSes[5], 2) + "  Status " + aSes[3]

Static Function TUIPdvAddItem(oApp, cUsu, oCod, oQtd)
    Local cCod  := AllTrim(BOSTR(oCod:GetValue())) as Character
    Local nQtd  := BOVAL(oQtd:GetValue()) as Numeric
    Local aR    := {} as Array
    Local aP    := {} as Array
    Local cDoc  := "" as Character
    Local cDesc := "" as Character
    Local nQ    := 0 as Numeric
    Local nPr   := 0 as Numeric
    Local nI    := 0 as Numeric
    Local aHit  := {} as Array

    If cCod == ""
        oApp:Notify("Informe o produto, codigo de barras ou etiqueta.", "warning")
        Return
    EndIf
    If nQtd <= 0
        nQtd := 1
    EndIf
    aR := GEBLOJRESOLVE(cCod, nQtd, 0)
    If !aR[1]
        oApp:Notify(aR[2], "error")
        Return
    EndIf
    cDoc := aR[3][1]
    nQ := aR[3][2]
    nPr := aR[3][3]
    If nPr <= 0
        aP := GEBLOJPRECO(cDoc, nQ, BOHOJE())
        nPr := aP[1]
    EndIf
    If nPr <= 0
        oApp:Notify("Produto sem preco: " + cDoc, "error")
        Return
    EndIf
    aHit := TCSqlQuery("SELECT GF1_DESC AS D FROM GF1 WHERE GF1_FILIAL = " + GEBDBQuote(FWxFilial("GF1")) + " AND GF1_COD = " + GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) > 0
        cDesc := BOCOL(aHit[1]:D)
    Else
        cDesc := cDoc
    EndIf
    // Mesmo produto soma a quantidade.
    For nI := 1 To Len(s_aPdvIt)
        If s_aPdvIt[nI][1] == cDoc
            s_aPdvIt[nI][3] := s_aPdvIt[nI][3] + nQ
            oCod:SetValue("")
            oQtd:SetValue(1)
            TUIPdvRefreshItens()
            Return
        EndIf
    Next nI
    s_nPdvSeq := s_nPdvSeq + 1
    aAdd(s_aPdvIt, {cDoc, cDesc, nQ, nPr, s_nPdvSeq})
    oCod:SetValue("")
    oQtd:SetValue(1)
    TUIPdvRefreshItens()
Return

Static Function TUIPdvDelItem(oApp)
    Local nI := 0 as Numeric

    If s_nPdvIt < 1 .Or. s_nPdvIt > Len(s_aPdvIt)
        oApp:Notify("Selecione um item na tabela.", "warning")
        Return
    EndIf
    aDel(s_aPdvIt, s_nPdvIt)
    aSize(s_aPdvIt, Len(s_aPdvIt))
    s_nPdvIt := 0
    TUIPdvRefreshItens()
Return

// Reconstroi a grade do carrinho a partir de s_aPdvIt {cod,desc,qtd,preco,seq}.
Static Function TUIPdvRefreshItens()
    Local aLin := {} as Array
    Local nI   := 0 as Numeric

    For nI := 1 To Len(s_aPdvIt)
        aAdd(aLin, {cValToChar(nI), s_aPdvIt[nI][1], s_aPdvIt[nI][2], TUIQtd(s_aPdvIt[nI][3]), ;
            BONUM(s_aPdvIt[nI][4], 2), BONUM(Round(s_aPdvIt[nI][3] * s_aPdvIt[nI][4], 2), 2), s_aPdvIt[nI][5]})
    Next nI
    If s_oPdvItT != Nil
        s_oPdvItT:SetItems(aLin)
    EndIf
    TUIPdvTotais()
Return

// Pagamentos {forma,valor,parcelas,doc,seq}.
Static Function TUIPdvAddPgto(oApp, oForma, oVal, oParc, oDoc)
    Local cForma := Upper(BOSTR(oForma:GetValue())) as Character
    Local nVal   := Round(BOVAL(oVal:GetValue()), 2) as Numeric
    Local nParc  := Int(BOVAL(oParc:GetValue())) as Numeric
    Local cDoc   := AllTrim(BOSTR(oDoc:GetValue())) as Character
    Local nTot   := TUIPdvTotal() as Numeric

    If nVal <= 0
        oApp:Notify("Informe o valor do pagamento.", "warning")
        Return
    EndIf
    If (cForma == "VALE" .Or. cForma == "CRYPTO") .And. cDoc == ""
        oApp:Notify("Pagamento " + cForma + " exige o documento (vale ou MOEDA|ENDERECO).", "warning")
        Return
    EndIf
    If cForma == "CREDITO"
        If nParc < 1
            nParc := 1
        EndIf
        If nParc > 12
            oApp:Notify("Credito parcela em ate 12x.", "warning")
            Return
        EndIf
    Else
        nParc := 1
    EndIf
    s_nPdvSeq := s_nPdvSeq + 1
    aAdd(s_aPdvPg, {cForma, nVal, nParc, cDoc, s_nPdvSeq})
    oVal:SetValue(0)
    oDoc:SetValue("")
    TUIPdvRefreshPagtos()
Return

Static Function TUIPdvLimpaPag()
    aSize(s_aPdvPg, 0)
    TUIPdvRefreshPagtos()
Return

Static Function TUIPdvRefreshPagtos()
    Local aLin := {} as Array
    Local nI   := 0 as Numeric

    For nI := 1 To Len(s_aPdvPg)
        aAdd(aLin, {cValToChar(nI), s_aPdvPg[nI][1], BONUM(s_aPdvPg[nI][2], 2), s_aPdvPg[nI][3], s_aPdvPg[nI][4], s_aPdvPg[nI][5]})
    Next nI
    If s_oPdvPgT != Nil
        s_oPdvPgT:SetItems(aLin)
    EndIf
    TUIPdvTotais()
Return

Static Function TUIPdvBruto()
    Local nB := 0 as Numeric
    Local nI := 0 as Numeric

    For nI := 1 To Len(s_aPdvIt)
        nB := nB + s_aPdvIt[nI][3] * s_aPdvIt[nI][4]
    Next nI
Return Round(nB, 2)

Static Function TUIPdvTotal()
    Local nD := 0 as Numeric

    nD := BOVAL(BOSTR(s_oPdvTotI[2]:GetValue()))
Return Round(TUIPdvBruto() - nD, 2)

Static Function TUIPdvTotais()
    Local aPg := {} as Array
    Local nB   := TUIPdvBruto() as Numeric
    Local nD   := 0 as Numeric
    Local nT   := 0 as Numeric
    Local nP   := 0 as Numeric
    Local nI   := 0 as Numeric

    If s_oPdvTotI == Nil
        Return
    EndIf
    // Desconto vem do campo: guardado no proprio info? nao — lido do input
    // em TUIPdvTotaisD. Aqui usa o ultimo desconto calculado em s_nPdvDesc.
    nD := s_nPdvDesc
    nT := Round(nB - nD, 2)
    For nI := 1 To Len(s_aPdvPg)
        nP := nP + s_aPdvPg[nI][2]
    Next nI
    s_oPdvTotI[1]:SetValue(BONUM(nB, 2))
    s_oPdvTotI[2]:SetValue(BONUM(nD, 2))
    s_oPdvTotI[3]:SetValue(BONUM(nT, 2))
    s_oPdvTotI[4]:SetValue(BONUM(nP, 2))
    If nP - nT > 0
        s_oPdvTotI[5]:SetValue(BONUM(nP - nT, 2))
    Else
        s_oPdvTotI[5]:SetValue("0,00")
    EndIf
Return

// Desconto lido do formulario na hora da finalizacao/orcamento.
Static Function TUIPdvDescAtual(oDes)
    Local nD := Round(BOVAL(oDes:GetValue()), 2) as Numeric
    s_nPdvDesc := nD
Return nD

// Itens no formato GEBLOJVEN/GEBLOJORC: {cod, qtd, preco}.
Static Function TUIPdvItensVEN()
    Local aIt := {} as Array
    Local nI  := 0 as Numeric

    For nI := 1 To Len(s_aPdvIt)
        aAdd(aIt, {s_aPdvIt[nI][1], s_aPdvIt[nI][3], s_aPdvIt[nI][4]})
    Next nI
Return aIt

Static Function TUIPdvPagtosVEN()
    Local aPg := {} as Array
    Local nI  := 0 as Numeric

    For nI := 1 To Len(s_aPdvPg)
        aAdd(aPg, {s_aPdvPg[nI][1], s_aPdvPg[nI][2], s_aPdvPg[nI][3], s_aPdvPg[nI][4]})
    Next nI
Return aPg

Static Function TUIPdvFinaliza(oApp, cUsu, oCli, oVen, oCpf, oDes, oReg, oSup, oSupS)
    Local aR := {} as Array

    If s_cPdvSes == ""
        oApp:Notify("Nenhuma sessao de caixa aberta - abra na aba Caixa.", "warning")
        Return
    EndIf
    If Len(s_aPdvIt) == 0
        oApp:Notify("Carrinho vazio - adicione itens.", "warning")
        Return
    EndIf
    If Len(s_aPdvPg) == 0
        oApp:Notify("Informe ao menos um pagamento.", "warning")
        Return
    EndIf
    s_nPdvDesc := TUIPdvDescAtual(oDes)
    aR := GEBLOJVEN(s_cPdvSes, TUIPdvItensVEN(), TUIPdvPagtosVEN(), ;
        AllTrim(BOSTR(oCli:GetValue())), s_nPdvDesc, AllTrim(BOSTR(oVen:GetValue())), ;
        AllTrim(BOSTR(oCpf:GetValue())), AllTrim(BOSTR(oSup:GetValue())), ;
        AllTrim(BOSTR(oSupS:GetValue())), "", Upper(BOSTR(oReg:GetValue())))
    If aR[1]
        If Len(aR) >= 3 .And. Len(aR[3]) > 0
            s_oPdvTotI[6]:SetValue("Cupom " + BOCOL(aR[3][1]) + "  Total " + BONUM(BOVAL(aR[3][2]), 2) + ;
                "  Troco " + BONUM(BOVAL(aR[3][3]), 2) + "  " + BOCOL(aR[3][4]))
        Else
            s_oPdvTotI[6]:SetValue(aR[2])
        EndIf
        aSize(s_aPdvIt, 0)
        aSize(s_aPdvPg, 0)
        TUIPdvRefreshItens()
        TUIPdvRefreshPagtos()
        TUIPdvRefreshSes()
    Else
        TUIPdvMsg(oApp, aR)
    EndIf
Return

Static Function TUIPdvSalvaOrc(oApp, cUsu, oCli, oVen, oDes)
    Local aR := {} as Array

    If Len(s_aPdvIt) == 0
        oApp:Notify("Carrinho vazio - adicione itens.", "warning")
        Return
    EndIf
    s_nPdvDesc := TUIPdvDescAtual(oDes)
    aR := GEBLOJORC(TUIPdvItensVEN(), AllTrim(BOSTR(oCli:GetValue())), AllTrim(BOSTR(oVen:GetValue())), s_nPdvDesc, BOHOJE())
    TUIPdvMsg(oApp, aR)
    If aR[1]
        aSize(s_aPdvIt, 0)
        TUIPdvRefreshItens()
        TUIPdvRefreshOrc()
    EndIf
Return

// ===== CAIXA =====

Static Function TUIPdvCaixaTab(oTab, oApp, cUsu)
    Local wSes := PoWidget():New(oTab, "Sessoes abertas")
    Local wAbr := PoWidget():New(oTab, "Abrir sessao")
    Local wFec := PoWidget():New(oTab, "Fechar sessao")
    Local wSan := PoWidget():New(oTab, "Sangria / Suprimento")
    Local wRes := PoWidget():New(oTab, "Resumo e resultado")
    Local oSes := PoTable():New(wSes)
    Local aCxs := {} as Array
    Local aOps := {} as Array
    Local nI   := 0 as Numeric
    Local oCx  := Nil
    Local oFun := PoNumber():New(wAbr, "Fundo de troco (R$)", 100)
    Local oSesF := PoInput():New(wFec, "Sessao")
    Local oCon := PoNumber():New(wFec, "Dinheiro contado (R$)", 0)
    Local oTip := PoSelect():New(wSan, "Tipo", {{"Sangria (caixa -> cofre)", "SANGRIA"}, {"Suprimento (cofre -> caixa)", "SUPRIMENTO"}}, "SANGRIA")
    Local oVal := PoNumber():New(wSan, "Valor (R$)", 0)
    Local oMot := PoInput():New(wSan, "Motivo")
    Local oRes := PoInfo():New(wRes, "", "")
    Local oB   := Nil

    wSes:SetCols(8)
    wAbr:SetCols(4)
    wFec:SetCols(4)
    wSan:SetCols(4)
    wRes:SetCols(4)
    oSes:SetColumns({{"c1", "Sessao"}, {"c2", "Caixa"}, {"c3", "Operador"}, {"c4", "Fundo"}, {"c5", "Abertura"}, {"c6", "Hora"}})
    s_oPdvSesT := oSes
    // Caixas cadastrados (GLJ1) como opcoes do select.
    aCxs := TCSqlQuery("SELECT GLJ1_COD AS C, GLJ1_NOME AS N FROM GLJ1 WHERE GLJ1_FILIAL = " + GEBDBQuote(FWxFilial("GLJ1")) + " AND D_E_L_E_T_ = ' ' ORDER BY GLJ1_COD")
    For nI := 1 To Len(aCxs)
        aAdd(aOps, {BOCOL(aCxs[nI]:C) + " - " + BOCOL(aCxs[nI]:N), BOCOL(aCxs[nI]:C)})
    Next nI
    If Len(aOps) == 0
        aAdd(aOps, {"(nenhum caixa cadastrado)", ""})
    EndIf
    oCx := PoSelect():New(wAbr, "Caixa", aOps, aOps[1][2])
    oB := PoButton():New(wAbr, "Abrir", {|| TUIPdvAbre(oApp, oCx, oFun)})
    oB:Set("kind", "primary")
    oSesF:SetValue(s_cPdvSes)
    oB := PoButton():New(wFec, "Fechar", {|| TUIPdvFecha(oApp, oSesF, oCon)})
    oB:Set("kind", "primary")
    oB := PoButton():New(wSan, "Lancar", {|| TUIPdvSan(oApp, oTip, oVal, oMot)})
    oB:Set("kind", "secondary")
    oB := PoButton():New(wRes, "Resumo da sessao", {|| TUIPdvResumo(oApp)})
    oB:Set("kind", "secondary")
    s_oPdvResI := oRes
Return

Static Function TUIPdvAbre(oApp, oCx, oFun)
    Local aR := {} as Array

    If Upper(BOSTR(oCx:GetValue())) == ""
        oApp:Notify("Selecione o caixa.", "warning")
        Return
    EndIf
    aR := GEBLOJABRE(Upper(BOSTR(oCx:GetValue())), s_cPdvUsu, BOVAL(oFun:GetValue()), BOHOJE())
    TUIPdvMsg(oApp, aR)
    If aR[1] .And. Len(aR) >= 3
        s_cPdvSes := aR[3]
    EndIf
    TUIPdvRefreshSes()
    TUIPdvRefreshAll()
Return

Static Function TUIPdvFecha(oApp, oSesF, oCon)
    Local aR := {} as Array

    If BOSTR(oSesF:GetValue()) == ""
        oApp:Notify("Informe a sessao.", "warning")
        Return
    EndIf
    aR := GEBLOJFECHA(AllTrim(BOSTR(oSesF:GetValue())), BOVAL(oCon:GetValue()))
    TUIPdvMsg(oApp, aR)
    If aR[1] .And. AllTrim(BOSTR(oSesF:GetValue())) == s_cPdvSes
        s_cPdvSes := ""
        aR := TUIPdvPickSes(s_cPdvUsu)
        If Len(aR) > 0
            s_cPdvSes := aR[1]
        EndIf
    EndIf
    TUIPdvRefreshAll()
Return

Static Function TUIPdvSan(oApp, oTip, oVal, oMot)
    Local aR := {} as Array

    If s_cPdvSes == ""
        oApp:Notify("Nenhuma sessao aberta.", "warning")
        Return
    EndIf
    aR := GEBLOJSAN(s_cPdvSes, Upper(BOSTR(oTip:GetValue())), BOVAL(oVal:GetValue()), AllTrim(BOSTR(oMot:GetValue())), "")
    TUIPdvMsg(oApp, aR)
Return

Static Function TUIPdvResumo(oApp)
    Local aR := {} as Array
    Local cT := "" as Character

    If s_cPdvSes == ""
        oApp:Notify("Nenhuma sessao aberta.", "warning")
        Return
    EndIf
    aR := GEBLOJRESUMO(s_cPdvSes)
    If aR[1] .And. Len(aR) >= 3
        cT := "Esperado " + BONUM(BOVAL(aR[3][1]), 2) + "  Vendido " + BONUM(BOVAL(aR[3][2]), 2) + "  " + BOCOL(aR[2])
        If Len(aR[3]) > 3
            cT += "  " + BOCOL(aR[3][4])
        EndIf
        s_oPdvResI:SetValue(cT)
    Else
        TUIPdvMsg(oApp, aR)
    EndIf
Return

// Sessoes abertas na tabela da aba Caixa.
Static Function TUIPdvRefreshSes()
    Local aHit := {} as Array
    Local aLin := {} as Array
    Local nI   := 0 as Numeric

    aHit := TCSqlQuery("SELECT GLJ2_SESSAO AS S, GLJ2_CAIXA AS C, GLJ2_OPER AS O, GLJ2_FUNDO AS F, GLJ2_ABERT AS A, GLJ2_HORA AS H " + ;
        "FROM GLJ2 WHERE GLJ2_FILIAL = " + GEBDBQuote(FWxFilial("GLJ2")) + " AND GLJ2_STATUS = 'ABERTA' AND D_E_L_E_T_ = ' ' ORDER BY GLJ2_ABERT, GLJ2_SESSAO")
    For nI := 1 To Len(aHit)
        aAdd(aLin, {BOCOL(aHit[nI]:S), BOCOL(aHit[nI]:C), BOCOL(aHit[nI]:O), BONUM(BOVAL(aHit[nI]:F), 2), BOCOL(aHit[nI]:A), BOCOL(aHit[nI]:H)})
    Next nI
    If s_oPdvSesT != Nil
        s_oPdvSesT:SetItems(aLin)
    EndIf
Return

// ===== ORCAMENTOS =====

Static Function TUIPdvOrcTab(oTab, oApp, cUsu)
    Local wLst := PoWidget():New(oTab, "Orcamentos abertos")
    Local wFin := PoWidget():New(oTab, "Finalizar orcamento")
    Local wCanc := PoWidget():New(oTab, "")
    Local oOrc := PoTable():New(wLst)
    Local oOrcS := PoInput():New(wFin, "Orcamento")
    Local oFor := PoSelect():New(wFin, "Forma", {{"Dinheiro", "DINHEIRO"}, {"PIX", "PIX"}, {"Debito", "DEBITO"}, {"Credito", "CREDITO"}, {"Fiado", "FIADO"}, {"Vale-troca", "VALE"}, {"Crypto", "CRYPTO"}}, "DINHEIRO")
    Local oVlr := PoNumber():New(wFin, "Valor (vazio = total do orcamento)", 0)
    Local oPar := PoNumber():New(wFin, "Parcelas (so credito)", 1)
    Local oDco := PoInput():New(wFin, "Documento (vale / MOEDA|ENDERECO)")
    Local oCpf := PoInput():New(wFin, "CPF/CNPJ (opcional)")
    Local oB   := Nil

    wLst:SetCols(8)
    wFin:SetCols(4)
    wCanc:SetCols(4)
    oOrc:SetColumns({{"c1", "Orcamento"}, {"c2", "Data"}, {"c3", "Validade"}, {"c4", "Cliente"}, {"c5", "Vendedor"}, {"c6", "Total"}, {"c7", "Status"}, {"c8", "Cupom"}})
    oOrc:OnSelect({|o, aLin| s_cPdvOrc := BOCOL(aLin[1])})
    s_oPdvOrcT := oOrc
    oOrcS:SetValue("")
    oB := PoButton():New(wFin, "Finalizar", {|| TUIPdvOrcFin(oApp, oOrcS, oFor, oVlr, oPar, oDco, oCpf)})
    oB:Set("kind", "primary")
    oB := PoButton():New(wCanc, "Cancelar orcamento", {|| TUIPdvOrcCan(oApp, oOrcS)})
    oB:Set("kind", "tertiary")
Return

Static Function TUIPdvOrcFin(oApp, oOrcS, oFor, oVlr, oPar, oDco, oCpf)
    Local aR   := {} as Array
    Local cOrc := AllTrim(BOSTR(oOrcS:GetValue())) as Character
    Local nVlr := BOVAL(oVlr:GetValue()) as Numeric
    Local aPg  := {} as Array

    If cOrc == ""
        oApp:Notify("Informe o orcamento.", "warning")
        Return
    EndIf
    If s_cPdvSes == ""
        oApp:Notify("Nenhuma sessao de caixa aberta.", "warning")
        Return
    EndIf
    If nVlr <= 0
        // Valor zerado: descobre o total do orcamento na tabela de exibicao.
        nVlr := TUIPdvOrcTotal(cOrc)
        If nVlr <= 0
            oApp:Notify("Informe o valor do pagamento.", "warning")
            Return
        EndIf
    EndIf
    aAdd(aPg, {Upper(BOSTR(oFor:GetValue())), nVlr, Int(BOVAL(oPar:GetValue())), AllTrim(BOSTR(oDco:GetValue()))})
    aR := GEBLOJORCFIN(s_cPdvSes, cOrc, aPg, AllTrim(BOSTR(oCpf:GetValue())), "", "", "FISCAL")
    If aR[1] .And. Len(aR) >= 3
        oApp:Notify("Cupom " + BOCOL(aR[3][1]) + "  Total " + BONUM(BOVAL(aR[3][2]), 2) + "  Troco " + BONUM(BOVAL(aR[3][3]), 2), "success")
    Else
        TUIPdvMsg(oApp, aR)
    EndIf
    TUIPdvRefreshOrc()
Return

// Total do orcamento a partir da ultima grade carregada (GLJD).
Static Function TUIPdvOrcTotal(cOrc)
    Local aHit := TCSqlQuery("SELECT GLJD_TOTAL AS T FROM GLJD WHERE GLJD_FILIAL = " + GEBDBQuote(FWxFilial("GLJD")) + " AND GLJD_ORC = " + ;
        GEBDBQuote(cOrc) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) > 0
        Return BOVAL(aHit[1]:T)
    EndIf
Return 0

Static Function TUIPdvOrcCan(oApp, oOrcS)
    Local aR := {} as Array

    If AllTrim(BOSTR(oOrcS:GetValue())) == ""
        oApp:Notify("Informe o orcamento.", "warning")
        Return
    EndIf
    aR := GEBLOJORCCAN(AllTrim(BOSTR(oOrcS:GetValue())))
    TUIPdvMsg(oApp, aR)
    TUIPdvRefreshOrc()
Return

Static Function TUIPdvRefreshOrc()
    Local aR  := {} as Array
    Local aLn := {} as Array
    Local nI  := 0 as Numeric

    aR := GEBLOJORCS("")
    If aR[1] .And. Len(aR) >= 3 .And. Len(aR[3]) > 1
        For nI := 2 To Len(aR[3])
            aAdd(aLn, {aR[3][nI][1], aR[3][nI][2], aR[3][nI][3], aR[3][nI][4], aR[3][nI][5], BONUM(aR[3][nI][6], 2), aR[3][nI][7], aR[3][nI][8]})
        Next nI
    EndIf
    If s_oPdvOrcT != Nil
        s_oPdvOrcT:SetItems(aLn)
    EndIf
Return

// ===== DEVOLUCAO =====

Static Function TUIPdvDevTab(oTab, oApp, cUsu)
    Local wCab := PoWidget():New(oTab, "Cupom e modo")
    Local wIte := PoWidget():New(oTab, "Itens devolvidos")
    Local wCon := PoWidget():New(oTab, "Consumidor (so se o cupom teve NFC-e)")
    Local wAco := PoWidget():New(oTab, "")
    Local oCup := PoInput():New(wCab, "Cupom")
    Local oMod := PoSelect():New(wCab, "Modo", {{"Vale-troca", "VALE"}, {"Dinheiro", "DINHEIRO"}}, "VALE")
    Local oMot := PoInput():New(wCab, "Motivo")
    Local oP   := PoInput():New(wIte, "Produto")
    Local oQ   := PoNumber():New(wIte, "Quantidade", 1)
    Local oDvT := PoTable():New(wIte)
    Local oDoc := PoInput():New(wCon, "CPF/CNPJ")
    Local oNom := PoInput():New(wCon, "Nome")
    Local oFone := PoInput():New(wCon, "Telefone")
    Local oLog := PoInput():New(wCon, "Logradouro")
    Local oNum := PoInput():New(wCon, "Numero")
    Local oCpl := PoInput():New(wCon, "Complemento")
    Local oBai := PoInput():New(wCon, "Bairro")
    Local oUF  := PoInput():New(wCon, "UF")
    Local oMun := PoInput():New(wCon, "Municipio (nome ou IBGE)")
    Local oCep := PoInput():New(wCon, "CEP")
    Local oB   := Nil

    wCab:SetCols(4)
    wIte:SetCols(6)
    wCon:SetCols(4)
    wAco:SetCols(4)
    oDvT:SetColumns({{"c1", "#"}, {"c2", "Produto"}, {"c3", "Qtd"}})
    oDvT:OnSelect({|o, aLin| s_nPdvDv := Val(BOSTR(aLin[1]))})
    s_oPdvDvT := oDvT
    oB := PoButton():New(wIte, "Adicionar item", {|| TUIPdvDevAdd(oApp, oP, oQ)})
    oB:Set("kind", "secondary")
    oB := PoButton():New(wIte, "Remover selecionado", {|| TUIPdvDevDel(oApp)})
    oB:Set("kind", "tertiary")
    oB := PoButton():New(wAco, "Registrar devolucao", {|| TUIPdvDevEnv(oApp, cUsu, oCup, oMod, oMot, oDoc, oNom, oFone, oLog, oNum, oCpl, oBai, oUF, oMun, oCep)})
    oB:Set("kind", "primary")
    oB:Set("icon", "an an-undo")
Return

Static Function TUIPdvDevAdd(oApp, oP, oQ)
    Local cP := AllTrim(BOSTR(oP:GetValue())) as Character
    Local nQ := BOVAL(oQ:GetValue()) as Numeric

    If cP == ""
        oApp:Notify("Informe o produto.", "warning")
        Return
    EndIf
    If nQ <= 0
        nQ := 1
    EndIf
    s_nPdvSeq := s_nPdvSeq + 1
    aAdd(s_aPdvDv, {cP, nQ, s_nPdvSeq})
    oP:SetValue("")
    oQ:SetValue(1)
    TUIPdvRefreshDev()
Return

Static Function TUIPdvDevDel(oApp)
    If s_nPdvDv < 1 .Or. s_nPdvDv > Len(s_aPdvDv)
        oApp:Notify("Selecione um item.", "warning")
        Return
    EndIf
    aDel(s_aPdvDv, s_nPdvDv)
    s_nPdvDv := 0
    TUIPdvRefreshDev()
Return

Static Function TUIPdvRefreshDev()
    Local aLin := {} as Array
    Local nI   := 0 as Numeric

    For nI := 1 To Len(s_aPdvDv)
        aAdd(aLin, {cValToChar(nI), s_aPdvDv[nI][1], TUIQtd(s_aPdvDv[nI][2])})
    Next nI
    If s_oPdvDvT != Nil
        s_oPdvDvT:SetItems(aLin)
    EndIf
Return

Static Function TUIPdvDevEnv(oApp, cUsu, oCup, oMod, oMot, oDoc, oNom, oFone, oLog, oNum, oCpl, oBai, oUF, oMun, oCep)
    Local aR    := {} as Array
    Local aIt   := {} as Array
    Local oCons := Nil
    Local nI    := 0 as Numeric

    If s_cPdvSes == ""
        oApp:Notify("Nenhuma sessao de caixa aberta.", "warning")
        Return
    EndIf
    If AllTrim(BOSTR(oCup:GetValue())) == ""
        oApp:Notify("Informe o cupom.", "warning")
        Return
    EndIf
    If Len(s_aPdvDv) == 0
        oApp:Notify("Adicione os itens devolvidos.", "warning")
        Return
    EndIf
    For nI := 1 To Len(s_aPdvDv)
        aAdd(aIt, {s_aPdvDv[nI][1], s_aPdvDv[nI][2]})
    Next nI
    // Consumidor so vai se houver documento (NFC-e no cupom original).
    If AllTrim(BOSTR(oDoc:GetValue())) != ""
        oCons := JsonObject():New()
        oCons["DOC"] := AllTrim(BOSTR(oDoc:GetValue()))
        oCons["NOME"] := AllTrim(BOSTR(oNom:GetValue()))
        oCons["FONE"] := AllTrim(BOSTR(oFone:GetValue()))
        oCons["LOGRADOURO"] := AllTrim(BOSTR(oLog:GetValue()))
        oCons["NUMERO"] := AllTrim(BOSTR(oNum:GetValue()))
        oCons["COMPLEMENTO"] := AllTrim(BOSTR(oCpl:GetValue()))
        oCons["BAIRRO"] := AllTrim(BOSTR(oBai:GetValue()))
        oCons["UF"] := Upper(AllTrim(BOSTR(oUF:GetValue())))
        oCons["MUNICIPIO"] := AllTrim(BOSTR(oMun:GetValue()))
        oCons["CEP"] := AllTrim(BOSTR(oCep:GetValue()))
    EndIf
    aR := GEBLOJDEV(s_cPdvSes, AllTrim(BOSTR(oCup:GetValue())), aIt, Upper(BOSTR(oMod:GetValue())), ;
        AllTrim(BOSTR(oMot:GetValue())), oCons)
    If aR[1]
        oApp:Notify(aR[2], "success")
        aSize(s_aPdvDv, 0)
        s_nPdvDv := 0
        TUIPdvRefreshDev()
    Else
        TUIPdvMsg(oApp, aR)
    EndIf
Return

// ===== CONSULTAS =====

Static Function TUIPdvConsTab(oTab, oApp, cUsu)
    Local wPro := PoWidget():New(oTab, "Preco e saldo do produto")
    Local wVal := PoWidget():New(oTab, "Vale-troca")
    Local wFia := PoWidget():New(oTab, "Fiado do cliente")
    Local wCup := PoWidget():New(oTab, "Cupom (segunda via)")
    Local wRes := PoWidget():New(oTab, "Resultado")
    Local oPC  := PoInput():New(wPro, "Produto / codigo de barras")
    Local oVC  := PoInput():New(wVal, "Numero do vale")
    Local oFC  := PoInput():New(wFia, "Cliente")
    Local oCC  := PoInput():New(wCup, "Cupom")
    Local oResT := PoTable():New(wRes)
    Local oCupT := PoTable():New(wRes)
    Local oB   := Nil

    wPro:SetCols(4)
    wVal:SetCols(4)
    wFia:SetCols(4)
    wCup:SetCols(4)
    wRes:SetCols(4)
    oResT:SetColumns({{"c1", "Campo"}, {"c2", "Valor"}})
    oCupT:SetColumns({{"c1", " "}})
    oB := PoButton():New(wPro, "Consultar", {|| TUIPdvConsProd(oApp, oPC, oResT)})
    oB:Set("kind", "secondary")
    oB := PoButton():New(wVal, "Consultar", {|| TUIPdvConsVale(oApp, oVC, oResT)})
    oB:Set("kind", "secondary")
    oB := PoButton():New(wFia, "Consultar", {|| TUIPdvConsFiado(oApp, oFC, oResT)})
    oB:Set("kind", "secondary")
    oB := PoButton():New(wCup, "Segunda via", {|| TUIPdvConsCupom(oApp, oCC, oCupT)})
    oB:Set("kind", "secondary")
Return

Static Function TUIPdvGrade(oTab, aPares)
    Local aLin := {} as Array
    Local nI   := 0 as Numeric

    For nI := 1 To Len(aPares)
        If ValType(aPares[nI]) == "A" .And. Len(aPares[nI]) >= 2
            aAdd(aLin, {BOSTR(aPares[nI][1]), BOSTR(aPares[nI][2])})
        EndIf
    Next nI
    oTab:SetItems(aLin)
Return

Static Function TUIPdvConsProd(oApp, oPC, oResT)
    Local aR := {} as Array

    If AllTrim(BOSTR(oPC:GetValue())) == ""
        oApp:Notify("Informe o produto.", "warning")
        Return
    EndIf
    aR := GEBLOJCONS(AllTrim(BOSTR(oPC:GetValue())), "")
    If aR[1] .And. Len(aR) >= 3
        TUIPdvGrade(oResT, aR[3])
    Else
        oApp:Notify(aR[2], "error")
    EndIf
Return

Static Function TUIPdvConsVale(oApp, oVC, oResT)
    Local aR := {} as Array

    If AllTrim(BOSTR(oVC:GetValue())) == ""
        oApp:Notify("Informe o vale.", "warning")
        Return
    EndIf
    aR := GEBLOJVALE(AllTrim(BOSTR(oVC:GetValue())))
    If aR[1] .And. Len(aR) >= 3
        TUIPdvGrade(oResT, aR[3])
    Else
        oApp:Notify(aR[2], "error")
    EndIf
Return

Static Function TUIPdvConsFiado(oApp, oFC, oResT)
    Local cCli := Upper(AllTrim(BOSTR(oFC:GetValue()))) as Character
    Local aHit := {} as Array
    Local nAb  := 0 as Numeric
    Local aP   := {} as Array

    If cCli == ""
        oApp:Notify("Informe o cliente.", "warning")
        Return
    EndIf
    aHit := TCSqlQuery("SELECT COALESCE(SUM(GV3_TOTAL), 0) AS T FROM GV3 WHERE GV3_FILIAL = " + GEBDBQuote(FWxFilial("GV3")) + " AND GV3_CLI = " + ;
        GEBDBQuote(cCli) + " AND GV3_STATUS = 'ABERTA' AND D_E_L_E_T_ = ' '")
    If Len(aHit) > 0
        nAb := BOVAL(aHit[1]:T)
    EndIf
    aP := {{"cliente", cCli}, {"aberto", BONUM(nAb, 2)}, {"limite", "1000,00"}, {"disponivel", BONUM(1000 - nAb, 2)}}
    TUIPdvGrade(oResT, aP)
Return

Static Function TUIPdvConsCupom(oApp, oCC, oCupT)
    Local aR  := {} as Array
    Local aLn := {} as Array
    Local nI  := 0 as Numeric

    If AllTrim(BOSTR(oCC:GetValue())) == ""
        oApp:Notify("Informe o cupom.", "warning")
        Return
    EndIf
    aR := GEBLOJCUPOM(AllTrim(BOSTR(oCC:GetValue())))
    If aR[1] .And. Len(aR) >= 3
        For nI := 1 To Len(aR[3])
            If ValType(aR[3][nI]) == "A"
                aAdd(aLn, {AllTrim(BOSTR(aR[3][nI][1])) + " " + AllTrim(BOSTR(aR[3][nI][2]))})
            Else
                aAdd(aLn, {BOSTR(aR[3][nI])})
            EndIf
        Next nI
        oCupT:SetItems(aLn)
    Else
        oApp:Notify(aR[2], "error")
    EndIf
Return

// ===== CADASTROS =====

Static Function TUIPdvCadTab(oTab, oApp, cUsu)
    Local wCx  := PoWidget():New(oTab, "Caixa")
    Local wBar := PoWidget():New(oTab, "Codigo de barras / PLU / balanca")
    Local wPro := PoWidget():New(oTab, "Promocao")
    Local wVen := PoWidget():New(oTab, "Vendedor")
    Local oCxC := PoInput():New(wCx, "Codigo do caixa")
    Local oCxN := PoInput():New(wCx, "Nome")
    Local oCxK := PoInput():New(wCx, "Conta financeira (vazio = CAIXA+cod)")
    Local oCxL := PoInput():New(wCx, "Local (vazio = 01)")
    Local oCxE := PoInput():New(wCx, "Centro de custo")
    Local oBaC := PoInput():New(wBar, "Codigo de barras / PLU / etiqueta")
    Local oBaP := PoInput():New(wBar, "Produto")
    Local oBaF := PoNumber():New(wBar, "Fator (unidades por leitura)", 1)
    Local oPrC := PoInput():New(wPro, "Codigo da promocao")
    Local oPrP := PoInput():New(wPro, "Produto (vazio = todos)")
    Local oPrT := PoSelect():New(wPro, "Tipo", {{"Preco fixo", "PRECO"}, {"Leve X pague Y", "LEVE"}, {"Desconto % a partir de qtd", "QTD"}}, "PRECO")
    Local oPrQ := PoNumber():New(wPro, "Qtd minima", 0)
    Local oPrV := PoNumber():New(wPro, "Valor", 0)
    Local oPrI := PoInput():New(wPro, "Inicio (AAAAMMDD)")
    Local oPrF := PoInput():New(wPro, "Fim (AAAAMMDD)")
    Local oVeC := PoInput():New(wVen, "Codigo do vendedor")
    Local oVeN := PoInput():New(wVen, "Nome")
    Local oVeP := PoNumber():New(wVen, "Comissao %", 0)
    Local oB   := Nil

    wCx:SetCols(4)
    wBar:SetCols(4)
    wPro:SetCols(4)
    wVen:SetCols(4)
    oB := PoButton():New(wCx, "Salvar caixa", {|| TUIPdvCadMsg(oApp, GEBLOJCX(AllTrim(BOSTR(oCxC:GetValue())), AllTrim(BOSTR(oCxN:GetValue())), ;
        AllTrim(BOSTR(oCxK:GetValue())), AllTrim(BOSTR(oCxL:GetValue())), Upper(AllTrim(BOSTR(oCxE:GetValue())))))})
    oB:Set("kind", "primary")
    oB := PoButton():New(wBar, "Salvar codigo", {|| TUIPdvCadMsg(oApp, GEBLOJBAR(AllTrim(BOSTR(oBaC:GetValue())), AllTrim(BOSTR(oBaP:GetValue())), BOVAL(oBaF:GetValue())))})
    oB:Set("kind", "primary")
    oB := PoButton():New(wPro, "Salvar promocao", {|| TUIPdvCadMsg(oApp, GEBLOJPROMO(AllTrim(BOSTR(oPrC:GetValue())), AllTrim(BOSTR(oPrP:GetValue())), ;
        Upper(BOSTR(oPrT:GetValue())), BOVAL(oPrQ:GetValue()), BOVAL(oPrV:GetValue()), AllTrim(BOSTR(oPrI:GetValue())), AllTrim(BOSTR(oPrF:GetValue()))))})
    oB:Set("kind", "primary")
    oB := PoButton():New(wVen, "Salvar vendedor", {|| TUIPdvCadMsg(oApp, GEBLOJVEND(AllTrim(BOSTR(oVeC:GetValue())), AllTrim(BOSTR(oVeN:GetValue())), BOVAL(oVeP:GetValue())))})
    oB:Set("kind", "primary")
Return

Static Function TUIPdvCadMsg(oApp, aR)
    If aR[1]
        oApp:Notify(aR[2], "success")
    Else
        oApp:Notify(aR[2], "error")
    EndIf
Return

// ===== RELATORIOS =====

Static Function TUIPdvRelTab(oTab, oApp, cUsu)
    Local wPer := PoWidget():New(oTab, "Periodo")
    Local wVen := PoWidget():New(oTab, "Vendas do dia")
    Local wRel := PoWidget():New(oTab, "Relatorios")
    Local oIni := PoInput():New(wPer, "Inicio (AAAAMMDD)")
    Local oFim := PoInput():New(wPer, "Fim (AAAAMMDD)")
    Local oAgr := PoSelect():New(wPer, "Agrupar por", {{"Dia", "DIA"}, {"Caixa", "CAIXA"}, {"Operador", "OPERADOR"}, {"Vendedor", "VENDEDOR"}}, "DIA")
    Local oDat := PoInput():New(wVen, "Data (AAAAMMDD, vazio = hoje)")
    Local oCx  := PoInput():New(wVen, "Caixa (vazio = todos)")
    Local oRelT := PoTable():New(wRel)
    Local oB   := Nil

    wPer:SetCols(4)
    wVen:SetCols(4)
    wRel:SetCols(4)
    oIni:SetValue(Left(BOHOJE(), 8) + "01")
    oFim:SetValue(BOHOJE())
    oDat:SetValue(BOHOJE())
    oRelT:SetColumns({{"c1", " "}})
    s_oPdvResT := oRelT
    oB := PoButton():New(wVen, "Vendas do dia", {|| TUIPdvRelVendas(oApp, oDat, oCx)})
    oB:Set("kind", "secondary")
    oB := PoButton():New(wRel, "Gerencial do periodo", {|| TUIPdvRelGer(oApp, oIni, oFim, oAgr)})
    oB:Set("kind", "secondary")
    oB := PoButton():New(wRel, "Comissao dos vendedores", {|| TUIPdvRelCom(oApp, oIni, oFim)})
    oB:Set("kind", "secondary")
Return

// Grade generica: aLinhas[1] = cabecalho, demais = dados.
Static Function TUIPdvRelGrade(aR)
    Local aCol := {} as Array
    Local aLin := {} as Array
    Local nI   := 0 as Numeric
    Local nJ   := 0 as Numeric

    If !(ValType(aR) == "A" .And. aR[1] .And. Len(aR) >= 3 .And. ValType(aR[3]) == "A" .And. Len(aR[3]) > 1)
        Return .F.
    EndIf
    For nJ := 1 To Len(aR[3][1])
        aAdd(aCol, {"c" + cValToChar(nJ), BOSTR(aR[3][1][nJ])})
    Next nJ
    If s_oPdvResT != Nil
        s_oPdvResT:SetColumns(aCol)
    EndIf
    For nI := 2 To Len(aR[3])
        If ValType(aR[3][nI]) == "A"
            aAdd(aLin, aR[3][nI])
        EndIf
    Next nI
    BOREL(aLin)
    If s_oPdvResT != Nil
        s_oPdvResT:SetItems(aLin)
    EndIf
Return .T.

Static Function TUIPdvRelVendas(oApp, oDat, oCx)
    Local aR := {} as Array

    If BOSTR(oDat:GetValue()) == ""
        oApp:Notify("Informe a data.", "warning")
        Return
    EndIf
    aR := GEBLOJVENDAS(StrTran(BOSTR(oDat:GetValue()), "-", ""), AllTrim(BOSTR(oCx:GetValue())))
    If !TUIPdvRelGrade(aR)
        TUIPdvMsg(oApp, aR)
    EndIf
Return

Static Function TUIPdvRelGer(oApp, oIni, oFim, oAgr)
    Local aR := {} as Array

    aR := GEBLOJGER(StrTran(BOSTR(oIni:GetValue()), "-", ""), StrTran(BOSTR(oFim:GetValue()), "-", ""), Upper(BOSTR(oAgr:GetValue())))
    If !TUIPdvRelGrade(aR)
        TUIPdvMsg(oApp, aR)
    EndIf
Return

Static Function TUIPdvRelCom(oApp, oIni, oFim)
    Local aR := {} as Array

    aR := GEBLOJCOMIS(StrTran(BOSTR(oIni:GetValue()), "-", ""), StrTran(BOSTR(oFim:GetValue()), "-", ""))
    If !TUIPdvRelGrade(aR)
        TUIPdvMsg(oApp, aR)
    EndIf
Return

// ===== TEF / NFC-e / CRYPTO =====

Static Function TUIPdvTefTab(oTab, oApp, cUsu)
    Local wNf  := PoWidget():New(oTab, "NFC-e")
    Local wTef := PoWidget():New(oTab, "TEF")
    Local wCry := PoWidget():New(oTab, "Crypto")
    Local wRes := PoWidget():New(oTab, "")
    Local aOps := {} as Array
    Local oRes := PoInfo():New(wRes, "", "")
    Local oPrv := PoInput():New(wTef, "Provedor")
    Local oUrl := PoInput():New(wTef, "URL do TEF")
    Local oMid := PoInput():New(wTef, "Merchant ID")
    Local oMky := PoInput():New(wTef, "Merchant Key")
    Local oCar := PoInput():New(wTef, "Bandeira/cartao (vazio = todas)")
    Local oBif := PoInput():New(wTef, "Bandeira")
    Local oMoe := Nil
    Local oVlr := PoNumber():New(wCry, "Valor em R$ para previa", 0)
    Local oWEm := PoInput():New(wCry, "Endereco da wallet (cadastro)")
    Local oB   := Nil

    wNf:SetCols(4)
    wTef:SetCols(4)
    wCry:SetCols(4)
    wRes:SetCols(4)
    s_oPdvResI := oRes
    oB := PoButton():New(wNf, "Transmitir NFC-e em contingencia", {|| TUIPdvMsg(oApp, GEBDFETRANSMITE())})
    oB:Set("kind", "primary")
    oB := PoButton():New(wTef, "Salvar configuracao TEF", {|| TUIPdvCadMsg(oApp, GEBTEFCFG(AllTrim(BOSTR(oPrv:GetValue())), AllTrim(BOSTR(oUrl:GetValue())), ;
        AllTrim(BOSTR(oMid:GetValue())), AllTrim(BOSTR(oMky:GetValue())), Upper(AllTrim(BOSTR(oCar:GetValue()))), Upper(AllTrim(BOSTR(oBif:GetValue())))))})
    oB:Set("kind", "primary")
    oB := PoButton():New(wTef, "Desfazer TEF pendente", {|| TUIPdvMsg(oApp, GEBTEFRESOLVE())})
    oB:Set("kind", "secondary")
    oB := PoButton():New(wCry, "Cotacao das moedas", {|| TUIPdvCryCot(oApp)})
    oB:Set("kind", "secondary")
    oB := PoButton():New(wCry, "Previa do QR", {|| TUIPdvCryQr(oApp, oMoe, oVlr)})
    oB:Set("kind", "secondary")
    oB := PoButton():New(wCry, "Cadastrar wallet", {|| TUIPdvCadMsg(oApp, GEBCRYWAL(Upper(BOSTR(oMoe:GetValue())), AllTrim(BOSTR(oWEm:GetValue())), "S"))})
    oB:Set("kind", "secondary")
    aOps := TUIPdvCryMoedas()
    If Len(aOps) > 0
        oMoe := PoSelect():New(wCry, "Moeda", aOps, aOps[1][2])
    Else
        oMoe := PoSelect():New(wCry, "Moeda", {{"-", ""}}, "")
    EndIf
Return

// Opcoes {rotulo, valor} das moedas crypto ativas.
Static Function TUIPdvCryMoedas()
    Local aR   := {} as Array
    Local aOps := {} as Array
    Local nI   := 0 as Numeric

    aR := GEBCRYWALLST()
    If aR[1] .And. Len(aR) >= 3 .And. ValType(aR[3]) == "A"
        For nI := 1 To Len(aR[3])
            If ValType(aR[3][nI]) == "A" .And. Len(aR[3][nI]) >= 2
                aAdd(aOps, {BOCOL(aR[3][nI][1]), Upper(BOCOL(aR[3][nI][1]))})
            EndIf
        Next nI
    EndIf
Return aOps

Static Function TUIPdvCryCot(oApp)
    Local aR := {} as Array
    Local cT := "" as Character
    Local nI := 0 as Numeric

    aR := GEBCRYCOT("")
    If Len(aR) > 0
        For nI := 1 To Len(aR)
            If ValType(aR[nI]) == "A" .And. Len(aR[nI]) >= 2
                cT += BOCOL(aR[nI][1]) + " " + BONUM(BOVAL(aR[nI][2]), 4) + "   "
            EndIf
        Next nI
        s_oPdvResI:SetValue(cT)
    Else
        oApp:Notify("Cotacao indisponivel.", "warning")
    EndIf
Return

Static Function TUIPdvCryQr(oApp, oMoe, oVlr)
    Local aR := {} as Array

    If Upper(BOSTR(oMoe:GetValue())) == "" .Or. BOVAL(oVlr:GetValue()) <= 0
        oApp:Notify("Selecione a moeda e informe o valor.", "warning")
        Return
    EndIf
    aR := GEBCRYQRCODE(Upper(BOSTR(oMoe:GetValue())), BOVAL(oVlr:GetValue()))
    If aR[1] .And. Len(aR) >= 3 .And. Len(aR[3]) >= 4
        s_oPdvResI:SetValue(BOCOL(aR[3][1]) + "  " + BOCOL(aR[3][2]) + "  " + BOCOL(aR[3][3]) + "  " + BOCOL(aR[3][4]))
    Else
        oApp:Notify(aR[2], "error")
    EndIf
Return

// ===== ATUALIZACAO GERAL =====

Static Function TUIPdvRefreshAll()
    If s_oPdvSesI != Nil
        s_oPdvSesI:SetValue(TUIPdvSessaoTxt())
    EndIf
    TUIPdvRefreshItens()
    TUIPdvRefreshPagtos()
    TUIPdvRefreshSes()
    TUIPdvRefreshOrc()
Return Nil
