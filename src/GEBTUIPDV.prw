/*/{Protheus.doc} GEBTUIPDV
    Frente de loja em componentes PO-UI: PDV de tela unica (situacao do caixa,
    entrada de produto ou codigo de barras, carrinho ao vivo com preco e
    promocao resolvidos, totais, pagamentos multiplos com troco, CPF na nota,
    vendedor e supervisor) e abas de caixa, orcamentos, consultas, cadastros,
    relatorios e TEF/NFC-e. Usa as mesmas funcoes de negocio da tela antiga e
    da API (GEBLOJVEN, GEBLOJABRE, GEBLOJRESOLVE, GEBLOJPRECO...).
    Estado da venda (aSt): {sessao, caixa, carrinho, pagamentos, linha selecionada, ultima venda}.
    Carrinho: {produto, descricao, qtd, preco informado, unitario, total, promocao}.
    Pagamento: {forma, valor, parcelas, numero do vale}.
    @type file
    @author Peder Munksgaard
    @since 21/11/2026
/*/

/*/{Protheus.doc} TUIPdvPg
    Monta a pagina da Frente de loja.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
    @return object, pagina
/*/
Static Function TUIPdvPg(oApp, cEmp, cFil, cUsu)
    Local oPg   := PoPage():New(oApp, "Frente de loja")
    Local oTabs := PoTabs():New(oPg)
    Local aSt   := {"", "", {}, {}, "", ""} as Array
    Local aUi   := {} as Array
    Local aCx   := TUIPdvSessao(cUsu) as Array
    Local bRef  := Nil
    Local oTab  := Nil

    If Len(aCx) > 0
        aSt[1] := aCx[1]
        aSt[2] := aCx[2]
    EndIf
    aUi := TUIPdvVenda(oApp, PoTab():New(oTabs, "Venda"), aSt, cUsu)
    bRef := {|| TUIPdvAtualiza(aSt, aUi)}
    TUIPdvCaixa(oApp, PoTab():New(oTabs, "Caixa"), aSt, cUsu, bRef)
    oTab := PoTab():New(oTabs, "Orcamentos")
    TUIPdvForms(oApp, oTab, cUsu, bRef, { ;
        {"Frente de loja", 0, 0, "Cancelar orcamento", {{"Orcamento", "C", ""}}, {|u, a| GEBLOJORCCAN(a[1])}, "BO", "", {"LOJA", "ORCAM"}}, ;
        {"Frente de loja", 0, 0, "Relatorio: orcamentos", {{"Situacao", {{"Abertos", "ABERTO"}, {"Finalizados", "FINALIZADO"}, {"Cancelados", "CANCELADO"}}, "ABERTO"}}, ;
            {|u, a| GEBLOJORCS(a[1])}, "REL", "", {"LOJA", "ORCAM"}} })
    PoInfo():New(oTab, "", "Para criar um orcamento, monte o carrinho na aba Venda e use 'Salvar como orcamento'. Para finalizar no caixa, informe o numero do orcamento no campo 'Orcamento' da venda.")
    TUIPdvConsultas(oApp, PoTab():New(oTabs, "Consultas"), cEmp, cFil, cUsu)
    TUIPdvForms(oApp, PoTab():New(oTabs, "Cadastros"), cUsu, bRef, TUIPdvCadastros())
    TUIPdvForms(oApp, PoTab():New(oTabs, "Relatorios"), cUsu, bRef, TUIPdvRelatorios())
    TUIPdvForms(oApp, PoTab():New(oTabs, "TEF e NFC-e"), cUsu, bRef, TUIPdvTef())
    TUIPdvDevolucao(oApp, PoTab():New(oTabs, "Devolucao"), aSt, cUsu, bRef)
    oPg:AddAction("Atualizar", bRef)
    Eval(bRef)
Return oPg

/*/{Protheus.doc} TUIPdvSessao
    Sessao de caixa aberta do operador (a mais recente), {sessao, caixa} ou {}.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIPdvSessao(cUsu)
    Local aHit := {} as Array

    If !GEBDBTableExists("GLJ2")
        Return {}
    EndIf
    aHit := TCSqlQuery("SELECT GLJ2_SESSAO AS S, GLJ2_CAIXA AS C FROM GLJ2 WHERE GLJ2_FILIAL = " + GEBDBQuote(FWxFilial("GLJ2")) + ;
        " AND GLJ2_OPER = " + GEBDBQuote(cUsu) + " AND GLJ2_STATUS = 'ABERTA' AND D_E_L_E_T_ = ' ' ORDER BY R_E_C_N_O_ DESC LIMIT 1")
    If Len(aHit) == 0
        Return {}
    EndIf
Return {BOCOL(aHit[1]:S), BOCOL(aHit[1]:C)}

/*/{Protheus.doc} TUIPdvVenda
    Aba Venda. Devolve as referencias dos componentes que mudam (aUi):
    {tag do caixa, info sessao, tabela do carrinho, widget total, info subtotal,
    campo desconto, info recebido, info troco/falta, tabela pagamentos, campo
    valor do pagamento, info ultimo cupom, campos de finalizacao}.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIPdvVenda(oApp, oPai, aSt, cUsu)
    Local aUi   := Array(16) as Array
    Local oWCx  := PoWidget():New(oPai, "Caixa")
    Local oWIt  := PoWidget():New(oPai, "Itens da venda")
    Local oWTot := PoWidget():New(oPai, "Total R$ 0,00")
    Local oWPg  := PoWidget():New(oPai, "Pagamento")
    Local oWFim := PoWidget():New(oPai, "Finalizar")
    Local oCod  := Nil
    Local oQtd  := Nil
    Local oPre  := Nil
    Local oFor  := Nil
    Local oVal  := Nil
    Local oPar  := Nil
    Local oVale := Nil
    Local oB    := Nil
    Local oT    := Nil

    oWCx:SetCols(12)
    aUi[1] := PoTag():New(oWCx, "CAIXA FECHADO", "danger")
    aUi[2] := TUIInfo(oWCx, "Sessao / caixa", "-", 4)
    aUi[11] := TUIInfo(oWCx, "Ultima venda", "-", 6)

    oWIt:SetCols(8)
    oCod := PoInput():New(oWIt, "Produto ou codigo de barras")
    oCod:SetCols(6)
    oQtd := PoNumber():New(oWIt, "Quantidade", 1)
    oQtd:SetCols(2)
    oPre := PoNumber():New(oWIt, "Preco", 0)
    oPre:SetCols(2)
    oB := PoButton():New(oWIt, "Adicionar", {|| TUIPdvAdd(oApp, aSt, aUi, BOCOL(oCod:GetValue()), BOVAL(oQtd:GetValue()), BOVAL(oPre:GetValue())), ;
        oCod:SetValue(""), oQtd:SetValue(1), oPre:SetValue(0)})
    oB:Set("kind", "primary")
    oB:Set("icon", "an an-plus")
    oB:SetCols(2)
    oT := PoTable():New(oWIt)
    oT:SetColumns({{"n", "#"}, {"item", "Item"}, {"qtd", "Qtd"}, {"unit", "Unitario"}, {"total", "Total"}, {"promo", "Promocao"}})
    oT:OnSelect({|o, aLin| aSt[5] := BOSTR(aLin[1])})
    aUi[3] := oT
    oB := PoButton():New(oWIt, "Remover item selecionado", {|| TUIPdvRemove(oApp, aSt, aUi, 3)})
    oB:Set("kind", "tertiary")
    oB:Set("icon", "an an-trash")
    oB:SetCols(4)
    oB := PoButton():New(oWIt, "Limpar venda", {|| TUIPdvLimpa(aSt, aUi)})
    oB:Set("kind", "tertiary")
    oB:Set("icon", "an an-x")
    oB:SetCols(4)

    oWTot:SetCols(4)
    aUi[4] := oWTot
    aUi[5] := PoInfo():New(oWTot, "Subtotal", "R$ 0,00")
    aUi[6] := PoNumber():New(oWTot, "Desconto (R$)", 0)
    aUi[6]:OnChange({|| TUIPdvAtualiza(aSt, aUi)})
    aUi[7] := PoInfo():New(oWTot, "Recebido", "R$ 0,00")
    aUi[8] := PoInfo():New(oWTot, "Falta / troco", "R$ 0,00")

    oWPg:SetCols(8)
    oFor := PoSelect():New(oWPg, "Forma", {{"Dinheiro", "DINHEIRO"}, {"PIX", "PIX"}, {"Debito", "DEBITO"}, {"Credito", "CREDITO"}, {"Fiado", "FIADO"}, {"Vale-troca", "VALE"}}, "DINHEIRO")
    oFor:SetCols(3)
    oVal := PoNumber():New(oWPg, "Valor", 0)
    oVal:SetCols(3)
    aUi[10] := oVal
    oPar := PoNumber():New(oWPg, "Parcelas", 1)
    oPar:SetCols(2)
    oVale := PoInput():New(oWPg, "Vale")
    oVale:SetCols(2)
    oB := PoButton():New(oWPg, "Incluir", {|| TUIPdvPaga(oApp, aSt, aUi, BOSTR(oFor:GetValue()), BOVAL(oVal:GetValue()), BOVAL(oPar:GetValue()), BOCOL(oVale:GetValue())), ;
        oVale:SetValue("")})
    oB:Set("kind", "secondary")
    oB:SetCols(2)
    oT := PoTable():New(oWPg)
    oT:SetColumns({{"n", "#"}, {"forma", "Forma"}, {"valor", "Valor"}, {"parcelas", "Parcelas"}, {"vale", "Vale"}})
    oT:OnSelect({|o, aLin| aSt[5] := "P" + BOSTR(aLin[1])})
    aUi[9] := oT
    oB := PoButton():New(oWPg, "Remover pagamento selecionado", {|| TUIPdvRemove(oApp, aSt, aUi, 4)})
    oB:Set("kind", "tertiary")
    oB:Set("icon", "an an-trash")
    oB:SetCols(6)

    oWFim:SetCols(4)
    aUi[12] := PoInput():New(oWFim, "CPF/CNPJ na nota")
    aUi[13] := PoInput():New(oWFim, "Vendedor")
    aUi[14] := PoInput():New(oWFim, "Cliente (fiado ou orcamento)")
    aUi[15] := PoInput():New(oWFim, "Orcamento (finalizar no caixa)")
    aUi[16] := {PoInput():New(oWFim, "Supervisor (desconto acima do limite)"), PoPassword():New(oWFim, "Senha do supervisor")}
    oB := PoButton():New(oWFim, "Finalizar venda", {|| TUIPdvFinaliza(oApp, aSt, aUi, cUsu)})
    oB:Set("kind", "primary")
    oB:Set("icon", "an an-check-circle")
    oB := PoButton():New(oWFim, "Salvar como orcamento", {|| TUIPdvOrcamento(oApp, aSt, aUi, cUsu)})
    oB:Set("kind", "secondary")
    oB:Set("icon", "an an-file-text")
Return aUi

/*/{Protheus.doc} TUIPdvAdd
    Inclui no carrinho o produto (ou codigo de barras / PLU de balanca). O mesmo
    produto ao mesmo preco soma a quantidade; preco e promocao sao recalculados.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIPdvAdd(oApp, aSt, aUi, cCod, nQtd, nPreco)
    Local aR   := {} as Array
    Local aC   := {} as Array
    Local cDes := "" as Character
    Local nP   := 0 as Numeric

    If Empty(cCod)
        oApp:Notify("Informe o produto ou o codigo de barras.", "warning")
        Return .F.
    EndIf
    If nQtd <= 0
        nQtd := 1
    EndIf
    aR := GEBLOJRESOLVE(cCod, nQtd, nPreco)
    If !aR[1]
        oApp:Notify("Produto nao encontrado: " + BOSTR(aR[2]), "error")
        Return .F.
    EndIf
    // RESOLVE so' traduz codigo (barras/PLU) e aceita o desconhecido; quem diz
    // se o produto existe e' a ficha (GEBLOJCONS) -- recusa ja' no carrinho.
    aC := GEBLOJCONS(aR[3][1], "")
    If !aC[1]
        oApp:Notify("Produto nao encontrado: " + cCod, "error")
        Return .F.
    EndIf
    cDes := TUIPdvCampo(aC[3], "descricao")
    nP := aScan(aSt[3], {|x| x[1] == aR[3][1] .And. x[4] == aR[3][3]})
    If nP > 0
        aSt[3][nP][3] += aR[3][2]
    Else
        aAdd(aSt[3], {aR[3][1], cDes, aR[3][2], aR[3][3], 0, 0, ""})
        nP := Len(aSt[3])
    EndIf
    TUIPdvPreco(aSt[3][nP])
    TUIPdvAtualiza(aSt, aUi)
Return .T.

// Preco da linha: informado ou tabela/promocao do dia (a promocao depende da quantidade).
Static Function TUIPdvPreco(aL)
    Local aP := {} as Array

    If aL[4] > 0
        aL[5] := aL[4]
        aL[7] := ""
    Else
        aP := GEBLOJPRECO(aL[1], aL[3], BOHOJE())
        aL[5] := aP[1]
        aL[7] := BOSTR(aP[2])
    EndIf
    aL[6] := Round(aL[5] * aL[3], 2)
Return

// Valor de um campo nas listas {{campo, valor}} das consultas.
Static Function TUIPdvCampo(aPares, cCampo)
    Local nP := aScan(aPares, {|x| x[1] == cCampo}) as Numeric

    If nP == 0
        Return ""
    EndIf
Return BOSTR(aPares[nP][2])

/*/{Protheus.doc} TUIPdvPaga
    Inclui um pagamento. Valor 0 = o que falta pagar.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIPdvPaga(oApp, aSt, aUi, cForma, nValor, nParc, cVale)
    Local aTot := TUIPdvTotais(aSt, aUi) as Array

    If nValor <= 0
        nValor := aTot[4]
    EndIf
    If nValor <= 0
        oApp:Notify("Nada a receber: monte o carrinho ou informe o valor.", "warning")
        Return .F.
    EndIf
    If cForma == "VALE"
        If Empty(cVale)
            oApp:Notify("Informe o numero do vale-troca.", "warning")
            Return .F.
        EndIf
    EndIf
    If nParc <= 0
        nParc := 1
    EndIf
    aAdd(aSt[4], {cForma, Round(nValor, 2), nParc, cVale})
    TUIPdvAtualiza(aSt, aUi)
Return .T.

// Remove a linha selecionada do carrinho (nLista 3) ou dos pagamentos (4).
Static Function TUIPdvRemove(oApp, aSt, aUi, nLista)
    Local cSel := aSt[5] as Character
    Local nP   := 0 as Numeric

    If nLista == 4
        If Left(cSel, 1) != "P"
            oApp:Notify("Selecione um pagamento na tabela.", "warning")
            Return
        EndIf
        cSel := SubStr(cSel, 2)
    ElseIf Left(cSel, 1) == "P" .Or. Empty(cSel)
        oApp:Notify("Selecione um item na tabela.", "warning")
        Return
    EndIf
    nP := Val(cSel)
    If nP < 1 .Or. nP > Len(aSt[nLista])
        Return
    EndIf
    aDel(aSt[nLista], nP)
    aSize(aSt[nLista], Len(aSt[nLista]) - 1)
    aSt[5] := ""
    TUIPdvAtualiza(aSt, aUi)
Return

// Esvazia carrinho, pagamentos e campos da venda.
Static Function TUIPdvLimpa(aSt, aUi)
    Local nI := 0 as Numeric

    aSt[3] := {}
    aSt[4] := {}
    aSt[5] := ""
    aUi[6]:SetValue(0)
    For nI := 12 To 15
        aUi[nI]:SetValue("")
    Next nI
    aUi[16][1]:SetValue("")
    aUi[16][2]:SetValue("")
    TUIPdvAtualiza(aSt, aUi)
Return

/*/{Protheus.doc} TUIPdvTotais
    {subtotal, desconto, total, falta, recebido, troco}.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIPdvTotais(aSt, aUi)
    Local nSub := 0 as Numeric
    Local nRec := 0 as Numeric
    Local nDes := Max(0, BOVAL(aUi[6]:GetValue())) as Numeric
    Local nTot := 0 as Numeric
    Local nI   := 0 as Numeric

    For nI := 1 To Len(aSt[3])
        nSub += aSt[3][nI][6]
    Next nI
    For nI := 1 To Len(aSt[4])
        nRec += aSt[4][nI][2]
    Next nI
    nTot := Max(0, Round(nSub - nDes, 2))
Return {nSub, nDes, nTot, Max(0, Round(nTot - nRec, 2)), nRec, Max(0, Round(nRec - nTot, 2))}

/*/{Protheus.doc} TUIPdvAtualiza
    Redesenha caixa, carrinho, pagamentos e totais a partir do estado.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIPdvAtualiza(aSt, aUi)
    Local aTot := TUIPdvTotais(aSt, aUi) as Array
    Local aLin := {} as Array
    Local nI   := 0 as Numeric

    If Empty(aSt[1])
        aUi[1]:Set("value", "CAIXA FECHADO")
        aUi[1]:Set("type", "danger")
        aUi[2]:SetValue("Abra o caixa na aba Caixa")
    Else
        aUi[1]:Set("value", "CAIXA ABERTO")
        aUi[1]:Set("type", "success")
        aUi[2]:SetValue(aSt[1] + " / " + aSt[2])
    EndIf
    For nI := 1 To Len(aSt[3])
        aAdd(aLin, {cValToChar(nI), aSt[3][nI][1] + " - " + aSt[3][nI][2], TUIPdvQtd(aSt[3][nI][3]), TUIMoeda(aSt[3][nI][5]), TUIMoeda(aSt[3][nI][6]), aSt[3][nI][7]})
    Next nI
    aUi[3]:SetItems(aLin)
    aLin := {}
    For nI := 1 To Len(aSt[4])
        aAdd(aLin, {cValToChar(nI), aSt[4][nI][1], TUIMoeda(aSt[4][nI][2]), cValToChar(aSt[4][nI][3]), aSt[4][nI][4]})
    Next nI
    aUi[9]:SetItems(aLin)
    aUi[4]:Set("title", "Total " + TUIMoeda(aTot[3]))
    aUi[5]:SetValue(TUIMoeda(aTot[1]) + " (" + cValToChar(Len(aSt[3])) + " item(ns))")
    aUi[7]:SetValue(TUIMoeda(aTot[5]))
    If aTot[6] > 0
        aUi[8]:SetValue("Troco " + TUIMoeda(aTot[6]))
    Else
        aUi[8]:SetValue("Falta " + TUIMoeda(aTot[4]))
    EndIf
    aUi[10]:SetValue(aTot[4])
    If Empty(aSt[6])
        aUi[11]:SetValue("-")
    Else
        aUi[11]:SetValue(aSt[6])
    EndIf
Return

// Quantidade no formato brasileiro sem zeros inuteis: 1, 2,5, 0,375 ("1.000" se lia "mil").
Static Function TUIPdvQtd(nQtd)
    Local cQ := AllTrim(Str(nQtd, 18, 3)) as Character

    Do While "." $ cQ .And. Right(cQ, 1) == "0"
        cQ := Left(cQ, Len(cQ) - 1)
    EndDo
    If Right(cQ, 1) == "."
        cQ := Left(cQ, Len(cQ) - 1)
    EndIf
Return StrTran(cQ, ".", ",")

// Itens e pagamentos no formato das funcoes de negocio (GEBLOJVEN/GEBLOJORC).
Static Function TUIPdvItens(aSt)
    Local aIt := {} as Array
    Local nI  := 0 as Numeric

    For nI := 1 To Len(aSt[3])
        aAdd(aIt, {aSt[3][nI][1], aSt[3][nI][3], aSt[3][nI][4]})
    Next nI
Return aIt

Static Function TUIPdvPagtos(aSt)
    Local aPg := {} as Array
    Local nI  := 0 as Numeric

    For nI := 1 To Len(aSt[4])
        If aSt[4][nI][1] == "VALE"
            aAdd(aPg, {aSt[4][nI][1], aSt[4][nI][2], aSt[4][nI][3], aSt[4][nI][4]})
        Else
            aAdd(aPg, {aSt[4][nI][1], aSt[4][nI][2], aSt[4][nI][3]})
        EndIf
    Next nI
Return aPg

/*/{Protheus.doc} TUIPdvFinaliza
    Fecha a venda (ou o orcamento informado) com os pagamentos incluidos.
    Desconto acima do limite: pede supervisor e senha nos campos da tela.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIPdvFinaliza(oApp, aSt, aUi, cUsu)
    Local cOrc := BOCOL(aUi[15]:GetValue()) as Character
    Local aTot := TUIPdvTotais(aSt, aUi) as Array
    Local aR   := {} as Array

    If !GEBSECRBAC(cUsu, "LOJA", "CAIXA")
        oApp:Notify("Sem permissao LOJA/CAIXA.", "error")
        Return .F.
    EndIf
    If Empty(aSt[1])
        oApp:Notify("Nenhum caixa aberto: abra o caixa na aba Caixa.", "warning")
        Return .F.
    EndIf
    If Empty(cOrc) .And. Len(aSt[3]) == 0
        oApp:Notify("O carrinho esta vazio.", "warning")
        Return .F.
    EndIf
    If Len(aSt[4]) == 0
        oApp:Notify("Inclua o pagamento antes de finalizar.", "warning")
        Return .F.
    EndIf
    If Empty(cOrc)
        If aTot[4] > 0
            oApp:Notify("Pagamento insuficiente: falta " + TUIMoeda(aTot[4]) + ".", "warning")
            Return .F.
        EndIf
        aR := GEBLOJVEN(aSt[1], TUIPdvItens(aSt), TUIPdvPagtos(aSt), BOCOL(aUi[14]:GetValue()), aTot[2], BOCOL(aUi[13]:GetValue()), ;
            BOCOL(aUi[12]:GetValue()), BOCOL(aUi[16][1]:GetValue()), BOSTR(aUi[16][2]:GetValue()))
    Else
        aR := GEBLOJORCFIN(aSt[1], cOrc, TUIPdvPagtos(aSt), BOCOL(aUi[12]:GetValue()), BOCOL(aUi[16][1]:GetValue()), BOSTR(aUi[16][2]:GetValue()))
    EndIf
    If !aR[1]
        If "desconto_acima_do_limite" $ BOSTR(aR[2])
            oApp:Notify("Desconto acima do limite: informe supervisor e senha e finalize de novo.", "warning")
        Else
            oApp:Notify("Venda recusada: " + BOSTR(aR[2]), "error")
        EndIf
        Return .F.
    EndIf
    aSt[6] := BOSTR(aR[2]) + " | total " + TUIMoeda(aR[3][2]) + " | troco " + TUIMoeda(aR[3][3])
    oApp:Notify("Venda concluida: " + aSt[6], "success")
    TUIPdvLimpa(aSt, aUi)
Return .T.

// Salva o carrinho como orcamento (sem pagamento).
Static Function TUIPdvOrcamento(oApp, aSt, aUi, cUsu)
    Local aTot := TUIPdvTotais(aSt, aUi) as Array
    Local aR   := {} as Array

    If !GEBSECRBAC(cUsu, "LOJA", "ORCAM")
        oApp:Notify("Sem permissao LOJA/ORCAM.", "error")
        Return .F.
    EndIf
    If Len(aSt[3]) == 0
        oApp:Notify("O carrinho esta vazio.", "warning")
        Return .F.
    EndIf
    aR := GEBLOJORC(TUIPdvItens(aSt), BOCOL(aUi[14]:GetValue()), BOCOL(aUi[13]:GetValue()), aTot[2], BOHOJE())
    If !aR[1]
        oApp:Notify("Orcamento recusado: " + BOSTR(aR[2]), "error")
        Return .F.
    EndIf
    oApp:Notify("Orcamento salvo: " + BOSTR(aR[2]), "success")
    TUIPdvLimpa(aSt, aUi)
Return .T.

/*/{Protheus.doc} TUIPdvCaixa
    Aba Caixa: abrir, sangria, suprimento, fechar e resumo da sessao atual.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIPdvCaixa(oApp, oPai, aSt, cUsu, bRef)
    Local aCx := TUIPdvCaixas() as Array

    TUIPdvForms(oApp, oPai, cUsu, bRef, { ;
        {"Frente de loja", 0, 0, "Abrir caixa", {{"Caixa", TUIPdvOpcCaixa(aCx), TUIPdvCaixaPadrao(aCx)}, {"Fundo de troco", "N", 0}}, ;
            {|u, a| TUIPdvAbre(aSt, u, a)}, "BO", "", {"LOJA", "CAIXA"}}, ;
        {"Frente de loja", 0, 0, "Sangria", {{"Valor", "N", 0}, {"Motivo", "C", ""}, {"Conta de destino (vazio = cofre)", "C", ""}}, ;
            {|u, a| TUIPdvSessaoOk(aSt, {|| GEBLOJSAN(aSt[1], "SANGRIA", a[1], a[2], a[3])})}, "BO", "", {"LOJA", "CAIXA"}}, ;
        {"Frente de loja", 0, 0, "Suprimento", {{"Valor", "N", 0}, {"Motivo", "C", ""}, {"Conta de origem (vazio = cofre)", "C", ""}}, ;
            {|u, a| TUIPdvSessaoOk(aSt, {|| GEBLOJSAN(aSt[1], "SUPRIMENTO", a[1], a[2], a[3])})}, "BO", "", {"LOJA", "CAIXA"}}, ;
        {"Frente de loja", 0, 0, "Fechar caixa", {{"Dinheiro contado na gaveta", "N", 0}}, ;
            {|u, a| TUIPdvFecha(aSt, a)}, "BO", "", {"LOJA", "CAIXA"}}, ;
        {"Frente de loja", 0, 0, "Relatorio: resumo do caixa", {{"Sessao (vazio = a aberta)", "C", ""}}, ;
            {|u, a| GEBLOJRESUMO(TUIPdvSesInf(aSt, a[1]))}, "REL", "", {"LOJA", "CAIXA"}} })
Return

// Caixas cadastrados (GLJ1): {{"codigo - nome", codigo}}.
Static Function TUIPdvCaixas()
    Local aHit := {} as Array
    Local aOut := {} as Array
    Local nI   := 0 as Numeric

    If !GEBDBTableExists("GLJ1")
        Return {}
    EndIf
    aHit := TCSqlQuery("SELECT GLJ1_COD AS C, GLJ1_NOME AS N FROM GLJ1 WHERE GLJ1_FILIAL = " + GEBDBQuote(FWxFilial("GLJ1")) + " AND D_E_L_E_T_ = ' ' ORDER BY GLJ1_COD")
    For nI := 1 To Len(aHit)
        aAdd(aOut, {BOCOL(aHit[nI]:C) + " - " + BOCOL(aHit[nI]:N), BOCOL(aHit[nI]:C)})
    Next nI
Return aOut

// Campo Caixa: lista dos cadastrados ou texto livre quando nao ha nenhum.
Static Function TUIPdvOpcCaixa(aCx)
    If Len(aCx) == 0
        Return "C"
    EndIf
Return aCx

Static Function TUIPdvCaixaPadrao(aCx)
    If Len(aCx) == 0
        Return ""
    EndIf
Return aCx[1][2]

Static Function TUIPdvAbre(aSt, cUsu, a)
    Local aR := GEBLOJABRE(a[1], cUsu, a[2], BOHOJE()) as Array

    If aR[1]
        aSt[1] := BOSTR(aR[3])
        aSt[2] := Upper(BOCOL(a[1]))
    EndIf
Return aR

// Operacao que exige caixa aberto.
Static Function TUIPdvSessaoOk(aSt, bOp)
    If Empty(aSt[1])
        Return {.F., "nenhum caixa aberto: abra o caixa primeiro"}
    EndIf
Return Eval(bOp)

Static Function TUIPdvFecha(aSt, a)
    Local aR := {} as Array

    If Empty(aSt[1])
        Return {.F., "nenhum caixa aberto"}
    EndIf
    aR := GEBLOJFECHA(aSt[1], a[1])
    If !aR[1]
        Return aR
    EndIf
    aSt[1] := ""
    aSt[2] := ""
Return {.T., "caixa fechado: esperado " + TUIMoeda(aR[3][1]) + ", contado " + TUIMoeda(aR[3][2]) + ", diferenca " + TUIMoeda(aR[3][3])}

Static Function TUIPdvSesInf(aSt, cSes)
    If Empty(cSes)
        Return aSt[1]
    EndIf
Return cSes

/*/{Protheus.doc} TUIPdvConsultas
    Aba Consultas: preco do produto e saldo do vale-troca na propria tela;
    segunda via do cupom e DANFE da NFC-e.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIPdvConsultas(oApp, oPai, cEmp, cFil, cUsu)
    Local oW   := PoWidget():New(oPai, "Consulta de preco")
    Local oCod := PoInput():New(oW, "Produto ou codigo de barras")
    Local oLst := Nil
    Local oB   := Nil
    Local oWV  := PoWidget():New(oPai, "Saldo do vale-troca")
    Local oVal := PoInput():New(oWV, "Numero do vale")
    Local oLsV := Nil

    oW:SetCols(6)
    oB := PoButton():New(oW, "Consultar", {|| TUIPdvLista(oApp, oLst, GEBLOJCONS(BOCOL(oCod:GetValue()), ""))})
    oB:Set("kind", "primary")
    oB:Set("icon", "an an-magnifying-glass")
    oLst := PoList():New(oW)
    oWV:SetCols(6)
    oB := PoButton():New(oWV, "Consultar", {|| TUIPdvLista(oApp, oLsV, GEBLOJVALE(BOCOL(oVal:GetValue())))})
    oB:Set("kind", "primary")
    oB:Set("icon", "an an-magnifying-glass")
    oLsV := PoList():New(oWV)
    TUIPdvForms(oApp, oPai, cUsu, Nil, { ;
        {"Frente de loja", 0, 0, "Segunda via do cupom", {{"Cupom", "C", ""}}, {|u, a| GEBLOJCUPOM(a[1])}, "REL", "", {"LOJA", "CAIXA"}}, ;
        {"Frente de loja", 0, 0, "DANFE da NFC-e do cupom", {{"Cupom", "C", ""}}, {|u, a| TBODanfe(cEmp, cFil, u, a[1]), {.T., "DANFE do cupom " + a[1]}}, "BO", "", {"LOJA", "CAIXA"}} })
Return

// Resultado {lOk, cMsg, {{campo, valor}}} numa lista (campo: valor).
Static Function TUIPdvLista(oApp, oLst, aR)
    Local aIt := {} as Array
    Local nI  := 0 as Numeric

    If !aR[1]
        oLst:SetItems({})
        oApp:Notify("Nao encontrado: " + BOSTR(aR[2]), "error")
        Return
    EndIf
    For nI := 1 To Len(aR[3])
        aAdd(aIt, {TUIRotulo(Upper(BOSTR(aR[3][nI][1]))) + ": " + BOSTR(aR[3][nI][2])})
    Next nI
    oLst:SetItems(aIt)
Return

/*/{Protheus.doc} TUIPdvDevolucao
    Aba Devolucao: devolucao/troca do cupom (itens na grade) no caixa aberto.
    Se o cupom teve NFC-e, a NF-e de devolucao precisa do consumidor: os campos
    ficam no mesmo formulario (vazios = cupom sem NFC-e).
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIPdvDevolucao(oApp, oPai, aSt, cUsu, bRef)
    TUIPdvForms(oApp, oPai, cUsu, bRef, { ;
        {"Frente de loja", 0, 0, "Devolucao / troca", {{"Cupom da venda", "C", ""}, ;
            {"Devolver em", {{"Vale-troca", "VALE"}, {"Dinheiro", "DINHEIRO"}}, "VALE"}, {"Motivo", "C", ""}, ;
            {"Consumidor: CPF/CNPJ (so' se o cupom teve NFC-e)", "C", ""}, {"Nome", "C", ""}, {"Logradouro", "C", ""}, {"Numero", "C", ""}, ;
            {"Complemento", "C", ""}, {"Bairro", "C", ""}, {"UF", "C", ""}, {"Municipio (nome ou codigo IBGE)", "C", ""}, {"CEP", "C", ""}, {"Telefone", "C", ""}}, ;
            {|u, a, it| TUIPdvSessaoOk(aSt, {|| TUIPdvDevolve(aSt, a, it)})}, "BO", "", {"LOJA", "CAIXA"}, Nil, ;
            {{"Produto devolvido", "C", ""}, {"Quantidade", "N", 0}}} })
Return

Static Function TUIPdvDevolve(aSt, a, it)
    Local aR := {} as Array
    Local aM := {} as Array
    Local o  := Nil

    If Empty(a[4])
        aR := GEBLOJDEV(aSt[1], a[1], it, a[2], a[3])
        If !aR[1] .And. "devolucao_de_nfce" $ BOSTR(aR[2])
            Return {.F., "o cupom teve NFC-e: preencha os dados do consumidor e confirme de novo"}
        EndIf
        Return aR
    EndIf
    aM := TUIMunicipio(a[10], a[11])
    If !aM[1]
        Return aM
    EndIf
    o := JsonObject():New()
    o["DOC"] := a[4]
    o["NOME"] := a[5]
    o["LOGRADOURO"] := a[6]
    o["NUMERO"] := a[7]
    o["COMPLEMENTO"] := a[8]
    o["BAIRRO"] := a[9]
    o["UF"] := Upper(a[10])
    o["MUNICIPIO"] := aM[2]
    o["CEP"] := a[12]
    o["FONE"] := a[13]
Return GEBLOJDEV(aSt[1], a[1], it, a[2], a[3], o)

// Formularios das abas (mesmo motor de TUIForm; grupo pela aba).
Static Function TUIPdvForms(oApp, oPai, cUsu, bRef, aForms)
    Local nI := 0 as Numeric

    If bRef == Nil
        bRef := {|| .T.}
    EndIf
    For nI := 1 To Len(aForms)
        TUIForm(oApp, oPai, aForms[nI], cUsu, {}, bRef)
    Next nI
Return

Static Function TUIPdvCadastros()
    Local aGer := {"LOJA", "GEREN"} as Array
Return { ;
    {"Frente de loja", 0, 0, "Cadastrar caixa", {{"Codigo do caixa", "C", ""}, {"Nome", "C", ""}, {"Conta do dinheiro (vazio = CAIXA<codigo>)", "C", ""}, ;
        {"Armazem", "C", "01"}, {"Centro de custo (vazio = nenhum)", "C", ""}}, {|u, a| GEBLOJCX(a[1], a[2], a[3], a[4], a[5])}, "BO", "", {"LOJA", "CAIXA"}}, ;
    {"Frente de loja", 0, 0, "Codigo de barras / PLU de balanca", {{"GTIN ou PLU da balanca (5 digitos)", "C", ""}, {"Produto", "C", ""}, ;
        {"Unidades por leitura (fator)", "N", 1}}, {|u, a| GEBLOJBAR(a[1], a[2], a[3])}, "BO", "", aGer}, ;
    {"Frente de loja", 0, 0, "Promocao", {{"Codigo da promocao", "C", ""}, {"Produto", "C", ""}, ;
        {"Tipo", {{"Preco promocional", "PRECO"}, {"Leve N pague M", "LEVE"}, {"% a partir de N unidades", "QTD"}}, "PRECO"}, ;
        {"N (quantidade minima / leve; 0 no preco)", "N", 0}, {"Valor (preco, pague M ou %; 0 encerra)", "N", 0}, ;
        {"Inicio (AAAAMMDD)", "C", BOHOJE()}, {"Fim (AAAAMMDD; vazio = sem fim)", "C", ""}}, ;
        {|u, a| GEBLOJPROMO(a[1], a[2], a[3], a[4], a[5], a[6], a[7])}, "BO", "", aGer}, ;
    {"Frente de loja", 0, 0, "Vendedor", {{"Codigo do vendedor", "C", ""}, {"Nome", "C", ""}, {"Comissao %", "N", 0}}, ;
        {|u, a| GEBLOJVEND(a[1], a[2], a[3])}, "BO", "", aGer} ;
    }

Static Function TUIPdvRelatorios()
    Local aGer := {"LOJA", "GEREN"} as Array
    Local cIni := Left(BOHOJE(), 6) + "01" as Character
Return { ;
    {"Frente de loja", 0, 0, "Relatorio: vendas do dia", {{"Data (AAAAMMDD)", "C", BOHOJE()}, {"Caixa (vazio = todos)", "C", ""}}, ;
        {|u, a| GEBLOJVENDAS(a[1], a[2])}, "REL", "", {"LOJA", "CAIXA"}}, ;
    {"Frente de loja", 0, 0, "Relatorio: gerencial da loja", {{"Inicio (AAAAMMDD)", "C", cIni}, {"Fim (AAAAMMDD)", "C", BOHOJE()}, ;
        {"Agrupar por", {{"Dia", "DIA"}, {"Caixa", "CAIXA"}, {"Operador", "OPERADOR"}, {"Vendedor", "VENDEDOR"}}, "DIA"}}, ;
        {|u, a| GEBLOJGER(a[1], a[2], a[3])}, "REL", "", aGer}, ;
    {"Frente de loja", 0, 0, "Relatorio: comissao dos vendedores", {{"Inicio (AAAAMMDD)", "C", cIni}, {"Fim (AAAAMMDD)", "C", BOHOJE()}}, ;
        {|u, a| GEBLOJCOMIS(a[1], a[2])}, "REL", "", aGer}, ;
    {"Frente de loja", 0, 0, "Relatorio: transacoes TEF do dia", {{"Data (AAAAMMDD)", "C", BOHOJE()}}, {|u, a| GEBTEFREL(a[1])}, "REL", "", {"LOJA", "CAIXA"}} ;
    }

Static Function TUIPdvTef()
Return { ;
    {"Frente de loja", 0, 0, "Configurar TEF", {{"Provedor", {{"Manter o atual", ""}, {"Simulador", "SIMULADOR"}, {"Gateway HTTP", "HTTP"}, {"Cielo", "CIELO"}}, ""}, ;
        {"URL (vazio = mantem; Cielo padrao = sandbox)", "C", ""}, {"MerchantId (Cielo; vazio = mantem)", "C", ""}, {"MerchantKey / token (vazio = mantem)", "C", ""}, ;
        {"Cartao de teste (Cielo; vazio = mantem)", "C", ""}, {"Bandeira (vazio = mantem)", "C", ""}}, ;
        {|u, a| GEBTEFCFG(a[1], a[2], a[3], a[4], a[5], a[6])}, "BO", "", {"CONFIG", "EMPRES"}}, ;
    {"Frente de loja", 0, 0, "Desfazer TEF pendente", {}, {|u, a| GEBTEFRESOLVE()}, "BO", "", {"LOJA", "CAIXA"}}, ;
    {"Frente de loja", 0, 0, "NFC-e: transmitir as emitidas em contingencia", {}, {|u, a| GEBDFETRANSMITE()}, "BO", "", {"LOJA", "CAIXA"}} ;
    }
