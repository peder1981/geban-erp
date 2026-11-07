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
User Function GEBTUIBOEST(cUsu)
    Local aOps := {"icon:plus|Movimento com custo (E/S)", "icon:check-circle|Inventario (contagem)", "icon:check-circle|Transferencia entre armazens", ;
        "icon:clipboard|Saldo e custo medio", "icon:clipboard|Relatorio: kardex", "icon:clipboard|Relatorio: posicao valorizada", ;
        "icon:gear|Controle de lote/serie/endereco do produto", "icon:plus|Cadastrar endereco", "icon:check-circle|Mudar lote de endereco", ;
        "icon:clipboard|Relatorio: saldo por lote/endereco", "icon:clipboard|Relatorio: lotes a vencer", "icon:check-circle|Fechar mes", ;
        "icon:check-circle|Reabrir ultimo mes fechado", "icon:clipboard|Relatorio: fechamento do mes", "icon:arrow-left|< Voltar"}
    Local nOp := 0
    Local cP := ""
    Local cL := ""
    Local cT := ""
    Local cQ := ""
    Local cC := ""
    Local cD := ""
    Local aR := {}
    Do While .T.
        nOp := FWMenuSelect(aOps, "Estoque avancado:")
        If nOp == Nil .Or. nOp <= 0 .Or. nOp == Len(aOps)
            Exit
        EndIf
        If !TBOPerm(cUsu, "ESTOQUE", "ESTOQ")
            Loop
        EndIf
        If nOp == 1
            cP := FWGetText("Produto:", "")
            cL := FWGetText("Armazem:", "01")
            cT := FWGetText("Tipo E (entrada) ou S (saida):", "E")
            cQ := FWGetText("Quantidade:", "")
            cC := FWGetText("Custo unitario (entrada):", "0")
            cD := FWGetText("Documento:", "")
            TBORes(GEBESTMOV(cP, cL, cT, Val(cQ), Val(cC), "TELA", cD, FWGetText("Data AAAAMMDD:", BOHOJE()), TBOLote(Val(cQ))), "Estoque")
        ElseIf nOp == 2
            cP := FWGetText("Produto:", "")
            cL := FWGetText("Armazem:", "01")
            cQ := FWGetText("Quantidade contada:", "")
            cC := FWGetText("Custo se o produto nao tem custo medio:", "0")
            cD := FWGetText("Documento:", "")
            aR := GEBESTSLD(cP, cL)
            TBORes(GEBESTAJU(cP, cL, Val(cQ), Val(cC), cD, FWGetText("Data AAAAMMDD:", BOHOJE()), TBOLote(Abs(Val(cQ) - aR[1]))), "Inventario")
        ElseIf nOp == 3
            cP := FWGetText("Produto:", "")
            cL := FWGetText("Armazem de origem:", "01")
            cT := FWGetText("Armazem de destino:", "")
            cQ := FWGetText("Quantidade:", "")
            cD := FWGetText("Documento:", "")
            cC := FWGetText("Data AAAAMMDD:", BOHOJE())
            aR := TBOLote(Val(cQ))
            TBORes(GEBESTTRF(cP, cL, cT, Val(cQ), cD, cC, aR, FWGetText("Endereco de destino (vazio = o mesmo):", "")), "Transferencia")
        ElseIf nOp == 4
            cP := FWGetText("Produto:", "")
            aR := GEBESTSLD(cP, FWGetText("Armazem (vazio = todos):", ""))
            MsgInfo("Produto " + cP + " | quantidade " + BONUM(aR[1], 4) + " | custo medio " + BONUM(aR[2], 4) + " | valor " + BONUM(aR[3], 2), "Estoque")
        ElseIf nOp == 5
            cP := FWGetText("Produto:", "")
            cL := FWGetText("Armazem (vazio = todos):", "")
            TBORel(GEBESTKARDEX(cP, cL, FWGetText("Inicio AAAAMMDD:", Left(BOHOJE(), 6) + "01"), FWGetText("Fim AAAAMMDD:", BOHOJE())), "Kardex " + cP)
        ElseIf nOp == 6
            TBORel(GEBESTPOS(FWGetText("Armazem (vazio = todos):", "")), "Posicao do estoque")
        ElseIf nOp == 7
            cP := FWGetText("Produto:", "")
            cT := FWGetText("Rastro N (nenhum), L (lote) ou S (serie):", "N")
            TBORes(GEBESTCTL(cP, cT, FWGetText("Controla endereco? S/N:", "N")), "Controle")
        ElseIf nOp == 8
            cL := FWGetText("Armazem:", "01")
            cT := FWGetText("Endereco (ex.: A-01-03):", "")
            TBORes(GEBESTENDER(cL, cT, FWGetText("Descricao:", "")), "Endereco")
        ElseIf nOp == 9
            cP := FWGetText("Produto:", "")
            cL := FWGetText("Armazem:", "01")
            cT := FWGetText("Lote/serie (vazio se nao controla lote):", "")
            cC := FWGetText("Endereco de origem:", "")
            cD := FWGetText("Endereco de destino:", "")
            TBORes(GEBESTENDTRF(cP, cL, cT, cC, cD, Val(FWGetText("Quantidade:", "")), BOHOJE()), "Endereco")
        ElseIf nOp == 10
            cP := FWGetText("Produto (vazio = todos):", "")
            TBORel(GEBESTLOTES(cP, FWGetText("Armazem (vazio = todos):", ""), BOHOJE()), "Saldo por lote/endereco")
        ElseIf nOp == 11
            TBORel(GEBESTVENCER(Val(FWGetText("Vencendo em ate quantos dias:", "30")), BOHOJE()), "Lotes a vencer")
        ElseIf nOp == 12
            TBORes(GEBESTFECHA(FWGetText("Competencia AAAAMM:", BOMESADD(Left(BOHOJE(), 6), -1))), "Fechamento")
        ElseIf nOp == 13
            TBORes(GEBESTREABRE(FWGetText("Competencia AAAAMM:", BOPARM("EST_FECHADO", ""))), "Reabertura")
        Else
            TBORel(GEBESTFECHREL(FWGetText("Competencia AAAAMM:", BOPARM("EST_FECHADO", ""))), "Fechamento do estoque")
        EndIf
    EndDo
Return .T.

User Function GEBTUIBOFIN(cUsu)
    Local aOps := {"icon:plus|Condicao de pagamento", "icon:plus|Titulo parcelado", "icon:check-circle|Baixa (juros, multa, desconto)", ;
        "icon:check-circle|Transferencia entre contas", "icon:plus|Movimento avulso", "icon:clipboard|Relatorio: titulos por atraso", ;
        "icon:clipboard|Relatorio: extrato da conta", "icon:clipboard|Relatorio: fluxo de caixa projetado", "icon:plus|Despesa a pagar (centro de custo)", ;
        "icon:bank|Banco: boleto, CNAB e conciliacao", "icon:arrow-left|< Voltar"}
    Local nOp := 0
    Local cA := ""
    Local cB := ""
    Local cC := ""
    Local cD := ""
    Local cE := ""
    Local aC := {}
    Do While .T.
        nOp := FWMenuSelect(aOps, "Financeiro avancado:")
        If nOp == Nil .Or. nOp <= 0 .Or. nOp == Len(aOps)
            Exit
        EndIf
        If nOp == 10
            GEBTUIBOBCO(cUsu)
            Loop
        EndIf
        If !TBOPerm(cUsu, "FINANCEIRO", "FLUXO")
            Loop
        EndIf
        If nOp == 1
            cA := FWGetText("Codigo:", "")
            cB := FWGetText("Descricao:", "")
            TBORes(GEBFXCOND(cA, cB, FWGetText("Dias das parcelas (ex.: 30,60,90; 0 = a vista):", "")), "Condicao")
        ElseIf nOp == 2
            cA := Upper(FWGetText("Tipo R (receber) ou P (pagar):", "R"))
            cB := FWGetText("Documento:", "")
            cC := FWGetText("Cliente/fornecedor:", "")
            TBORes(GEBFXTIT(cA, cB, cC, Val(FWGetText("Valor total:", "")), FWGetText("Condicao (codigo ou dias):", "0"), ;
                FWGetText("Emissao AAAAMMDD:", BOHOJE()), "TELA", ""), "Titulos")
        ElseIf nOp == 3
            cA := Upper(FWGetText("Tipo R (receber) ou P (pagar):", "R"))
            cB := FWGetText("Documento (com a parcela, ex.: NF1/01):", "")
            cC := FWGetText("Data AAAAMMDD:", BOHOJE())
            aC := GEBFXCALC(cA, cB, cC)
            If !aC[1]
                MsgStop(aC[2], "Baixa")
                Loop
            EndIf
            TBORes(GEBFXBAI(cA, cB, Val(FWGetText("Principal (saldo " + BONUM(aC[3][1], 2) + "):", BONUM(aC[3][1], 2))), ;
                Val(FWGetText("Juros (" + BONUM(aC[3][2], 0) + " dias de atraso):", BONUM(aC[3][3], 2))), ;
                Val(FWGetText("Multa:", BONUM(aC[3][4], 2))), Val(FWGetText("Desconto:", "0")), FWGetText("Conta:", "CAIXA"), cC), "Baixa")
        ElseIf nOp == 4
            cA := FWGetText("Conta de origem:", "")
            cB := FWGetText("Conta de destino:", "")
            TBORes(GEBFXTRF(cA, cB, Val(FWGetText("Valor:", "")), FWGetText("Data AAAAMMDD:", BOHOJE()), FWGetText("Historico:", "")), "Transferencia")
        ElseIf nOp == 5
            cA := FWGetText("Conta:", "")
            cB := Upper(FWGetText("C (entrada) ou D (saida):", "D"))
            cC := FWGetText("Valor:", "")
            cD := FWGetText("Historico:", "")
            cE := FWGetText("Data AAAAMMDD:", BOHOJE())
            TBORes(GEBFXMOV(cA, cB, Val(cC), cD, cE, FWGetText("Conta contabil (vazio = padrao):", ""), FWGetText("Centro de custo ou rateio (vazio = nenhum):", "")), "Movimento")
        ElseIf nOp == 6
            cA := Upper(FWGetText("Tipo R (receber) ou P (pagar):", "R"))
            TBORel(GEBFXPOSICAO(cA, FWGetText("Posicao em AAAAMMDD:", BOHOJE())), "Titulos por atraso")
        ElseIf nOp == 7
            cA := FWGetText("Conta:", "CAIXA")
            TBORel(GEBFXEXTRATO(cA, FWGetText("Inicio AAAAMMDD:", Left(BOHOJE(), 6) + "01"), FWGetText("Fim AAAAMMDD:", BOHOJE())), "Extrato " + cA)
        ElseIf nOp == 8
            TBORel(GEBFXFLUXO(FWGetText("Inicio AAAAMMDD:", BOHOJE()), Val(FWGetText("Dias:", "30"))), "Fluxo de caixa projetado")
        Else
            cA := FWGetText("Documento:", "")
            cB := FWGetText("Fornecedor:", "")
            cC := FWGetText("Valor:", "")
            cD := FWGetText("Condicao (codigo ou dias):", "0")
            cE := FWGetText("Emissao AAAAMMDD:", BOHOJE())
            TBORes(GEBFXDESP(cA, cB, Val(cC), cD, cE, FWGetText("Conta de despesa (vazio = 4.02.006):", ""), ;
                FWGetText("Centro de custo ou rateio:", ""), FWGetText("Historico:", "")), "Despesa")
        EndIf
    EndDo
Return .T.

/*/{Protheus.doc} GEBTUIBOBCO
    Banco: cobranca, boleto, CNAB 400 (arquivos lidos/gravados no servidor)
    e conciliacao por OFX. Permissao FINANCEIRO/BANCO.
    @type Tela
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBTUIBOBCO(cUsu)
    Local aOps := {"icon:gear|Dados de cobranca da conta", "icon:plus|Gerar boleto do titulo", "icon:check-circle|Gerar remessa CNAB 400", ;
        "icon:check-circle|Ler retorno CNAB 400 (baixa)", "icon:check-circle|Importar extrato OFX", "icon:check-circle|Conciliar automatico", ;
        "icon:check-circle|Conciliar na mao", "icon:plus|Lancar linha do extrato (tarifa)", "icon:clipboard|Relatorio: conciliacao", "icon:arrow-left|< Voltar"}
    Local nOp := 0
    Local cA := ""
    Local cB := ""
    Local cC := ""
    Local cD := ""
    Local cE := ""
    Local cF := ""
    Local cG := ""
    Local cH := ""
    Local cI := ""
    Local cJ := ""
    Local cK := ""
    Local aR := {}
    Do While .T.
        nOp := FWMenuSelect(aOps, "Banco:")
        If nOp == Nil .Or. nOp <= 0 .Or. nOp == Len(aOps)
            Exit
        EndIf
        If !TBOPerm(cUsu, "FINANCEIRO", "BANCO")
            Loop
        EndIf
        If nOp == 1
            cA := FWGetText("Conta financeira:", "BANCO")
            cH := FWGetText("Banco (001 BB, 033 Santander, 104 Caixa, 237 Bradesco, 341 Itau, 756 Sicoob):", "237")
            cB := FWGetText("Agencia/cooperativa (4 digitos):", "")
            cC := FWGetText("DV da agencia:", "")
            cD := FWGetText("Conta corrente:", "")
            cE := FWGetText("DV da conta:", "")
            cF := FWGetText("Carteira (Santander: 101/104):", "")
            cG := FWGetText("Codigo do beneficiario/convenio/cliente no banco:", "")
            cI := FWGetText("Beneficiario (razao social):", "")
            cJ := FWGetText("CNPJ:", "")
            cK := FWGetText("Leiaute CNAB 240 ou 400 (400 so' Bradesco/Itau; vazio = padrao do banco):", "")
            TBORes(GEBBCOCFG(cA, cH, cB, cC, cD, cE, cF, cG, cI, cJ, cK, FWGetText("Modalidade (Sicoob; vazio = 01):", "")), "Cobranca")
        ElseIf nOp == 2
            cA := FWGetText("Titulo a receber (documento com a parcela):", "")
            aR := GEBBCOBOL(cA, FWGetText("Conta de cobranca:", "BANCO"))
            If aR[1]
                MsgInfo("Linha digitavel: " + aR[3][1] + " | nosso numero " + aR[3][3] + " | vencimento " + aR[3][4], "Boleto")
            Else
                MsgStop("Boleto recusado: " + aR[2], "Boleto")
            EndIf
        ElseIf nOp == 3
            cA := FWGetText("Conta de cobranca:", "BANCO")
            aR := GEBBCOREM(cA, FWGetText("Gravar em (caminho no servidor):", "/tmp/remessa_" + cA + ".rem"))
            TBORes(aR, "Remessa")
        ElseIf nOp == 4 .Or. nOp == 5
            cA := FWGetText("Conta:", "BANCO")
            cB := FWGetText("Arquivo (caminho no servidor):", "")
            cC := MemoRead(cB)
            If BOSTR(cC) == ""
                MsgStop("Arquivo vazio ou nao encontrado: " + cB, "Banco")
                Loop
            EndIf
            If nOp == 4
                TBORes(GEBBCORET(cA, cC), "Retorno")
            Else
                TBORes(GEBBCOOFX(cA, cC), "Extrato OFX")
            EndIf
        ElseIf nOp == 6
            TBORes(GEBBCOCONC(FWGetText("Conta:", "BANCO")), "Conciliacao")
        ElseIf nOp == 7
            cA := FWGetText("Conta:", "BANCO")
            cB := FWGetText("FITID da linha do extrato:", "")
            TBORes(GEBBCOCONCMAN(cA, cB, Val(FWGetText("Movimento (numero 'mov' do relatorio; 0 desfaz):", ""))), "Conciliacao")
        ElseIf nOp == 8
            cA := FWGetText("Conta:", "BANCO")
            cB := FWGetText("FITID da linha do extrato:", "")
            cC := FWGetText("Conta contabil (vazio = padrao):", "")
            TBORes(GEBBCOLANCA(cA, cB, cC, FWGetText("Centro de custo (vazio = nenhum):", "")), "Extrato")
        Else
            cA := FWGetText("Conta:", "BANCO")
            TBORel(GEBBCOREL(cA, FWGetText("Inicio AAAAMMDD:", Left(BOHOJE(), 6) + "01"), FWGetText("Fim AAAAMMDD:", BOHOJE())), "Conciliacao " + cA)
        EndIf
    EndDo
Return .T.

User Function GEBTUIBOCTB(cUsu)
    Local aOps := {"icon:clipboard|Relatorio: razao da conta", "icon:clipboard|Relatorio: balancete do periodo", "icon:clipboard|Relatorio: DRE do periodo", ;
        "icon:plus|Centro de custo", "icon:plus|Rateio entre centros", "icon:clipboard|Relatorio: resultado por centro de custo", ;
        "icon:check-circle|Corrigir lancamentos antigos (estorno e lancamento certo)", "icon:arrow-left|< Voltar"}
    Local nOp := 0
    Local cA := ""
    Local cI := ""
    Local cF := ""
    Do While .T.
        nOp := FWMenuSelect(aOps, "Contabil avancado:")
        If nOp == Nil .Or. nOp <= 0 .Or. nOp == Len(aOps)
            Exit
        EndIf
        If nOp == 7
            If TBOPerm(cUsu, "CONTABIL", "DIR")
                TBORel(GEBCTXCORRIGE(), "Lancamentos antigos corrigidos")
            EndIf
            Loop
        EndIf
        If !TBOPerm(cUsu, "CONTABIL", "LANCTO")
            Loop
        EndIf
        If nOp == 4
            cA := FWGetText("Codigo do centro:", "")
            cI := FWGetText("Descricao:", "")
            TBORes(GEBCTXCC(cA, cI, FWGetText("Bloqueado? S/N:", "N")), "Centro de custo")
            Loop
        EndIf
        If nOp == 5
            cA := FWGetText("Codigo do rateio:", "")
            TBORes(GEBCTXRAT(cA, TBOItens({"Centro (vazio termina):", "Percentual:"}, {2})), "Rateio")
            Loop
        EndIf
        If nOp == 1
            cA := FWGetText("Conta (ex.: 1.01.001):", "")
        EndIf
        cI := FWGetText("Inicio AAAAMMDD:", Left(BOHOJE(), 6) + "01")
        cF := FWGetText("Fim AAAAMMDD:", BOHOJE())
        If nOp == 1
            TBORel(GEBCTXRAZAO(cA, cI, cF), "Razao " + cA)
        ElseIf nOp == 2
            TBORel(GEBCTXBALAN(cI, cF, FWGetText("Centro de custo (vazio = todos):", "")), "Balancete")
        ElseIf nOp == 3
            TBORel(GEBCTXDRE(cI, cF, FWGetText("Centro de custo (vazio = todos):", "")), "DRE")
        Else
            TBORel(GEBCTXCCRES(cI, cF), "Resultado por centro de custo")
        EndIf
    EndDo
Return .T.

User Function GEBTUIBOCOM(cUsu)
    Local aOps := {"icon:plus|Solicitacao de compra", "icon:check-circle|Gerar pedidos da solicitacao (menor preco)", "icon:plus|Pedido com itens", ;
        "icon:check-circle|Aprovar/rejeitar pedido (alcada)", "icon:check-circle|Documento de entrada", "icon:clipboard|Relatorio: pedidos em aberto", ;
        "icon:clipboard|Relatorio: compras por fornecedor", "icon:clipboard|Relatorio: solicitacoes pendentes", "icon:check-circle|Devolucao de compra", ;
        "icon:plus|Regra de retencao (ISS, IRRF, INSS, PIS, COFINS, CSLL)", "icon:clipboard|Relatorio: retencoes do mes", ;
        "icon:check-circle|NF-e de fornecedores: buscar na SEFAZ", "icon:clipboard|NF-e de fornecedores: recebidas", "icon:check-circle|NF-e de fornecedores: manifestar", ;
        "icon:plus|NF-e de fornecedores: produto do fornecedor = produto do GEBAN", "icon:check-circle|NF-e de fornecedores: importar como entrada", ;
        "icon:arrow-left|< Voltar"}
    Local nOp := 0
    Local cA := ""
    Local cB := ""
    Local cC := ""
    Do While .T.
        nOp := FWMenuSelect(aOps, "Compras avancado:")
        If nOp == Nil .Or. nOp <= 0 .Or. nOp == Len(aOps)
            Exit
        EndIf
        If nOp == 4
            If !TBOPerm(cUsu, "COMPRAS", "APROVA")
                Loop
            EndIf
        ElseIf nOp >= 10 .And. nOp <= 11
            If !TBOPerm(cUsu, "FISCAL", "APURA")
                Loop
            EndIf
        ElseIf !TBOPerm(cUsu, "COMPRAS", "PEDID")
            Loop
        EndIf
        If nOp == 1
            TBORes(GEBCPXSC("", TBOItens({"Produto (vazio termina):", "Quantidade:", "Necessidade AAAAMMDD (vazio = hoje):"}, {2}), cUsu), "Solicitacao")
        ElseIf nOp == 2
            cA := FWGetText("Solicitacao:", "")
            cB := FWGetText("Condicao de pagamento:", "")
            TBORes(GEBCPXGERA(cA, cB, FWGetText("Armazem de entrega:", "01"), FWGetText("Data AAAAMMDD:", BOHOJE())), "Pedidos")
        ElseIf nOp == 3
            cA := FWGetText("Fornecedor:", "")
            cB := FWGetText("Condicao de pagamento:", "")
            cC := FWGetText("Armazem de entrega:", "01")
            TBORes(GEBCPXPED("", cA, TBOItens({"Produto (vazio termina):", "Quantidade:", "Preco:"}, {2, 3}), cB, cC, BOHOJE()), "Pedido de compra")
        ElseIf nOp == 4
            cA := FWGetText("Pedido:", "")
            TBORes(GEBCPXAPR(cA, cUsu, !(Upper(FWGetText("Aprovar? S/N:", "S")) == "N")), "Aprovacao")
        ElseIf nOp == 5
            cA := FWGetText("Nota fiscal:", "")
            cB := FWGetText("Pedido:", "")
            cC := FWGetText("Frete:", "0")
            TBORes(GEBCPXENT(cA, cB, TBOItens({"Produto recebido (vazio = todo o pendente):", "Quantidade:", "Preco (vazio = do pedido):", ;
                "Lote/series separadas por ; (vazio se nao controla):", "Validade AAAAMMDD:", "Endereco:"}, {2, 3}), ;
                Val(cC), FWGetText("Data AAAAMMDD:", BOHOJE()), FWGetText("Retencoes (codigos separados por virgula; vazio = nenhuma):", ""), ;
                FWGetText("Chave de acesso da NF-e do fornecedor (44 digitos; vazio = sem):", "")), "Entrada")
        ElseIf nOp == 6
            TBORel(GEBCPXABERTOS(), "Pedidos em aberto")
        ElseIf nOp == 7
            cA := FWGetText("Inicio AAAAMMDD:", Left(BOHOJE(), 6) + "01")
            TBORel(GEBCPXPORFORN(cA, FWGetText("Fim AAAAMMDD:", BOHOJE())), "Compras por fornecedor")
        ElseIf nOp == 8
            TBORel(GEBCPXSCPEND(), "Solicitacoes pendentes")
        ElseIf nOp == 9
            cA := FWGetText("Nota fiscal de entrada:", "")
            cB := FWGetText("Fornecedor:", "")
            TBORes(GEBCPXDEV(cA, cB, TBOItens({"Produto devolvido (vazio termina):", "Quantidade:"}, {2}), FWGetText("Data AAAAMMDD:", BOHOJE()), ;
                FWGetText("Chave da NF-e do fornecedor (vazio = a informada na entrada):", "")), "Devolucao de compra")
        ElseIf nOp == 12
            TBORes(GEBDFEDISTBUSCA(), "NF-e de fornecedores")
        ElseIf nOp == 13
            TBORel(GEBDFERECEBIDAS(FWGetText("Situacao (vazio = todas; AUTORIZADA, CANCELADA):", "")), "NF-e recebidas")
        ElseIf nOp == 14
            cA := FWGetText("Chave da NF-e recebida:", "")
            cB := Upper(FWGetText("CIENCIA, CONFIRMACAO, DESCONHECIMENTO ou NAO_REALIZADA:", "CIENCIA"))
            cC := ""
            If cB == "NAO_REALIZADA"
                cC := FWGetText("Justificativa (minimo 15 letras):", "")
            EndIf
            TBORes(GEBDFEMANIF(cA, cB, cC), "Manifestacao")
        ElseIf nOp == 15
            cA := FWGetText("Fornecedor (codigo no GEBAN):", "")
            cB := FWGetText("Codigo do produto na nota do fornecedor:", "")
            cC := FWGetText("Produto no GEBAN:", "")
            TBORes(GEBDFEDEPARA(cA, cB, cC, Val(FWGetText("Fator (unidades do GEBAN por unidade da nota):", "1"))), "De-para")
        ElseIf nOp == 16
            cA := FWGetText("Chave da NF-e recebida:", "")
            TBORes(GEBDFEIMPORTA(cA, FWGetText("Pedido de compra (vazio = gera da nota):", ""), FWGetText("Data AAAAMMDD:", BOHOJE())), "Importar")
        ElseIf nOp == 10
            cA := FWGetText("Codigo da retencao:", "")
            cB := FWGetText("Tributo (ISS, IRRF, INSS, PIS, COFINS, CSLL):", "")
            cC := FWGetText("Aliquota %:", "")
            TBORes(GEBRETCAD(cA, cB, Val(cC), FWGetText("Descricao:", "")), "Retencao")
        Else
            TBORel(GEBRETREL(FWGetText("Competencia AAAAMM:", Left(BOHOJE(), 6))), "Retencoes")
        EndIf
    EndDo
Return .T.

/*/{Protheus.doc} GEBTUIFAT
    Tela do modulo Faturamento.
    @type Tela
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBTUIFAT(cEmp, cFil, cUsu)
    Local aOps := {"icon:clipboard|Clientes", "icon:plus|Cliente (novo/alterar)", "icon:plus|Preco na tabela", "icon:plus|Pedido de venda", ;
        "icon:check-circle|Liberar pedido (credito/estoque)", "icon:check-circle|Faturar (documento de saida)", "icon:check-circle|Devolucao de venda", ;
        "icon:check-circle|Cancelar pedido", "icon:clipboard|Pedidos", "icon:clipboard|Relatorio: faturamento e margem", ;
        "icon:clipboard|Relatorio: carteira de pedidos", "icon:clipboard|Relatorio: curva ABC", "icon:arrow-left|< Voltar"}
    Local nOp := 0
    Local cA := ""
    Local cB := ""
    Local cC := ""
    Local cD := ""
    Local cE := ""
    Do While .T.
        nOp := FWMenuSelect(aOps, "Faturamento:")
        If nOp == Nil .Or. nOp <= 0 .Or. nOp == Len(aOps)
            Exit
        EndIf
        If !TBOPerm(cUsu, "FATURAMENTO", "FATUR")
            Loop
        EndIf
        If nOp == 1
            GEBFATMIG()
            GEBTUIBRW("GFT1", "Clientes")
        ElseIf nOp == 2
            cA := FWGetText("Codigo:", "")
            cB := FWGetText("Nome:", "")
            cC := FWGetText("CNPJ/CPF:", "")
            cD := FWGetText("UF:", "")
            cE := FWGetText("Limite de credito (0 = sem limite):", "0")
            TBORes(GEBFATCLI(cA, cB, cC, cD, Val(cE), FWGetText("Condicao padrao:", ""), FWGetText("Tabela de preco (vazio = PADRAO):", "")), "Cliente")
        ElseIf nOp == 3
            cA := FWGetText("Tabela (vazio = PADRAO):", "")
            cB := FWGetText("Produto:", "")
            TBORes(GEBFATPRC(cA, cB, Val(FWGetText("Preco:", ""))), "Preco")
        ElseIf nOp == 4
            cA := FWGetText("Cliente:", "")
            cB := FWGetText("Condicao (vazio = do cliente):", "")
            cC := FWGetText("Desconto % no pedido:", "0")
            cD := FWGetText("Armazem:", "01")
            cE := FWGetText("Centro de custo (vazio = nenhum):", "")
            TBORes(GEBFATPED("", cA, TBOItens({"Produto (vazio termina):", "Quantidade:", "Preco (vazio = tabela):"}, {2, 3}), cB, Val(cC), cD, BOHOJE(), cE), "Pedido de venda")
        ElseIf nOp == 5
            cA := FWGetText("Pedido:", "")
            cB := Upper(FWGetText("Forcar a liberacao mesmo bloqueado? S/N:", "N"))
            If cB == "S" .And. !TBOPerm(cUsu, "FATURAMENTO", "LIBERA")
                Loop
            EndIf
            TBORes(GEBFATLIB(cA, cB == "S"), "Liberacao")
        ElseIf nOp == 6
            cA := FWGetText("Pedido:", "")
            TBORes(GEBFATFAT(cA, TBOItens({"Produto a faturar (vazio = todo o saldo):", "Quantidade:"}, {2}), FWGetText("Data AAAAMMDD:", BOHOJE()), ""), "Faturamento")
        ElseIf nOp == 7
            cA := FWGetText("Nota:", "")
            TBORes(GEBFATDEV(cA, TBOItens({"Produto devolvido (vazio termina):", "Quantidade:"}, {2}), FWGetText("Data AAAAMMDD:", BOHOJE()), ;
                FWGetText("Chave da NF-e de devolucao do cliente (so' se ele for contribuinte; vazio = o GEBAN emite):", "")), "Devolucao")
        ElseIf nOp == 8
            TBORes(GEBFATCAN(FWGetText("Pedido:", "")), "Cancelamento")
        ElseIf nOp == 9
            GEBFATMIG()
            GEBTUIBRW("GFT3", "Pedidos de venda")
        ElseIf nOp == 10
            cA := FWGetText("Inicio AAAAMMDD:", Left(BOHOJE(), 6) + "01")
            cB := FWGetText("Fim AAAAMMDD:", BOHOJE())
            TBORel(GEBFATREL(cA, cB, FWGetText("Agrupar por CLIENTE ou PRODUTO:", "CLIENTE")), "Faturamento")
        ElseIf nOp == 11
            TBORel(GEBFATCARTEIRA(), "Carteira de pedidos")
        Else
            cA := FWGetText("Inicio AAAAMMDD:", Left(BOHOJE(), 6) + "01")
            TBORel(GEBFATABC(cA, FWGetText("Fim AAAAMMDD:", BOHOJE())), "Curva ABC")
        EndIf
    EndDo
Return .T.

/*/{Protheus.doc} GEBTUILOJ
    Tela da frente de loja. Guarda a sessao aberta nesta tela. Cada opcao
    checa o item da API: LOJA/CAIXA (operacao do caixa), LOJA/ORCAM
    (orcamento), LOJA/GEREN (cadastros e gerencial) e CONFIG/EMPRES (TEF).
    @type Tela
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBTUILOJ(cEmp, cFil, cUsu)
    Local aOps := {"icon:plus|Cadastrar caixa", "icon:check-circle|Abrir caixa", "icon:check-circle|Vender", "icon:check-circle|Finalizar orcamento no caixa", ;
        "icon:check-circle|Cancelar cupom", "icon:check-circle|Devolucao / troca (dinheiro ou vale-troca)", "icon:check-circle|Sangria", "icon:check-circle|Suprimento", ;
        "icon:check-circle|Fechar caixa", "icon:eye|Consulta de preco", "icon:eye|Saldo do vale-troca", "icon:clipboard|Segunda via do cupom", ;
        "icon:clipboard|Relatorio: resumo do caixa", "icon:clipboard|Relatorio: vendas do dia", "icon:clipboard|Relatorio: transacoes TEF do dia", ;
        "icon:check-circle|Desfazer TEF pendente", "icon:plus|Novo orcamento", "icon:check-circle|Cancelar orcamento", "icon:clipboard|Relatorio: orcamentos", ;
        "icon:plus|Codigo de barras / PLU de balanca", "icon:plus|Promocao", "icon:plus|Vendedor", "icon:clipboard|Relatorio: gerencial da loja", ;
        "icon:clipboard|Relatorio: comissao dos vendedores", "icon:gear|Configurar TEF (simulador, gateway HTTP ou Cielo)", ;
        "icon:check-circle|NFC-e: transmitir as emitidas em contingencia", "icon:clipboard|NFC-e: DANFE do cupom (ver e imprimir)", "icon:arrow-left|< Voltar"}
    Local nOp := 0
    Local cSes := ""
    Local cA := ""
    Local cB := ""
    Local aR := {}
    Local aIt := {}
    Local aPg := {}
    Local cC := ""
    Local cD := ""
    Local cItem := ""
    Local nI := 0
    Do While .T.
        nOp := FWMenuSelect(aOps, "Frente de loja " + cSes + ":")
        If nOp == Nil .Or. nOp <= 0 .Or. nOp == Len(aOps)
            Exit
        EndIf
        cItem := "CAIXA"
        If nOp >= 17 .And. nOp <= 19
            cItem := "ORCAM"
        ElseIf nOp >= 20 .And. nOp <= 24
            cItem := "GEREN"
        EndIf
        If nOp == 25
            If !TBOPerm(cUsu, "CONFIG", "EMPRES")
                Loop
            EndIf
        ElseIf !TBOPerm(cUsu, "LOJA", cItem)
            Loop
        EndIf
        If nOp == 1
            cA := FWGetText("Codigo do caixa:", "")
            cB := FWGetText("Nome:", "")
            cC := FWGetText("Conta do dinheiro (vazio = CAIXA<codigo>):", "")
            cD := FWGetText("Armazem:", "01")
            TBORes(GEBLOJCX(cA, cB, cC, cD, FWGetText("Centro de custo (vazio = nenhum):", "")), "Caixa")
        ElseIf nOp == 2
            cA := FWGetText("Caixa:", "")
            aR := GEBLOJABRE(cA, cUsu, Val(FWGetText("Fundo de troco:", "0")), BOHOJE())
            If aR[1]
                cSes := aR[3]
            EndIf
            TBORes(aR, "Abertura")
        ElseIf nOp == 3
            cSes := FWGetText("Sessao:", cSes)
            aIt := TBOItens({"Produto ou codigo de barras (vazio fecha o cupom):", "Quantidade:", "Preco (vazio = tabela/promocao):"}, {2, 3})
            cA := FWGetText("Desconto em valor:", "0")
            cB := FWGetText("Vendedor (vazio = nenhum):", "")
            cC := FWGetText("CPF/CNPJ na nota (vazio = nao):", "")
            aPg := TBOPagtos()
            TBOFinal(cSes, "", aIt, Val(cA), cB, cC, aPg[1], aPg[2])
        ElseIf nOp == 4
            cSes := FWGetText("Sessao:", cSes)
            cA := FWGetText("Orcamento:", "")
            cC := FWGetText("CPF/CNPJ na nota (vazio = nao):", "")
            aPg := TBOPagtos()
            TBOFinal(cSes, cA, {}, 0, "", cC, aPg[1], "")
        ElseIf nOp == 5
            cA := FWGetText("Cupom:", "")
            TBORes(GEBLOJCAN(cA, FWGetText("Motivo:", "")), "Cancelamento")
        ElseIf nOp == 6
            cSes := FWGetText("Sessao:", cSes)
            cA := FWGetText("Cupom da venda:", "")
            aIt := TBOItens({"Produto devolvido (vazio termina):", "Quantidade:"}, {2})
            cB := Upper(FWGetText("Devolver em VALE (vale-troca) ou DINHEIRO:", "VALE"))
            cC := FWGetText("Motivo:", "")
            aR := GEBLOJDEV(cSes, cA, aIt, cB, cC)
            If !aR[1] .And. "devolucao_de_nfce" $ aR[2]
                // Cupom com NFC-e: a NF-e de devolucao precisa do consumidor identificado.
                aR := GEBLOJDEV(cSes, cA, aIt, cB, cC, TBOConsumidor())
            EndIf
            TBORes(aR, "Devolucao")
        ElseIf nOp == 7 .Or. nOp == 8
            cSes := FWGetText("Sessao:", cSes)
            cA := FWGetText("Valor:", "")
            If nOp == 7
                TBORes(GEBLOJSAN(cSes, "SANGRIA", Val(cA), FWGetText("Motivo:", ""), FWGetText("Conta de destino (vazio = cofre):", "")), "Sangria")
            Else
                TBORes(GEBLOJSAN(cSes, "SUPRIMENTO", Val(cA), FWGetText("Motivo:", ""), FWGetText("Conta de origem (vazio = cofre):", "")), "Suprimento")
            EndIf
        ElseIf nOp == 9
            cSes := FWGetText("Sessao:", cSes)
            aR := GEBLOJFECHA(cSes, Val(FWGetText("Dinheiro contado na gaveta:", "")))
            If aR[1]
                MsgInfo("Esperado " + BONUM(aR[3][1], 2) + " | contado " + BONUM(aR[3][2], 2) + " | diferenca " + BONUM(aR[3][3], 2), "Fechamento")
                TBORel(GEBLOJRESUMO(cSes), "Resumo do caixa " + cSes)
                cSes := ""
            Else
                MsgStop("Fechamento recusado: " + aR[2], "Fechamento")
            EndIf
        ElseIf nOp == 10 .Or. nOp == 11
            If nOp == 10
                aR := GEBLOJCONS(FWGetText("Produto ou codigo de barras:", ""), "")
            Else
                aR := GEBLOJVALE(FWGetText("Numero do vale:", ""))
            EndIf
            If aR[1]
                cA := ""
                For nI := 1 To Len(aR[3])
                    cA := cA + aR[3][nI][1] + ": " + BOSTR(aR[3][nI][2]) + " | "
                Next nI
                MsgInfo(cA, aR[2])
            Else
                MsgStop("Recusado: " + aR[2], "Consulta")
            EndIf
        ElseIf nOp == 12
            cA := FWGetText("Cupom:", "")
            TBORel(GEBLOJCUPOM(cA), "Cupom " + cA)
        ElseIf nOp == 13
            cSes := FWGetText("Sessao:", cSes)
            TBORel(GEBLOJRESUMO(cSes), "Resumo do caixa " + cSes)
        ElseIf nOp == 14
            cA := FWGetText("Data AAAAMMDD:", BOHOJE())
            TBORel(GEBLOJVENDAS(cA, FWGetText("Caixa (vazio = todos):", "")), "Vendas do dia")
        ElseIf nOp == 15
            TBORel(GEBTEFREL(FWGetText("Data AAAAMMDD:", BOHOJE())), "Transacoes TEF")
        ElseIf nOp == 16
            TBORes(GEBTEFRESOLVE(), "TEF")
        ElseIf nOp == 17
            aIt := TBOItens({"Produto ou codigo de barras (vazio fecha):", "Quantidade:", "Preco (vazio = tabela/promocao):"}, {2, 3})
            cA := FWGetText("Desconto em valor:", "0")
            cB := FWGetText("Cliente (vazio = consumidor):", "")
            TBORes(GEBLOJORC(aIt, cB, FWGetText("Vendedor:", ""), Val(cA), BOHOJE()), "Orcamento")
        ElseIf nOp == 18
            TBORes(GEBLOJORCCAN(FWGetText("Orcamento:", "")), "Orcamento")
        ElseIf nOp == 19
            TBORel(GEBLOJORCS(FWGetText("Status ABERTO/FINALIZADO/CANCELADO:", "ABERTO")), "Orcamentos")
        ElseIf nOp == 20
            cA := FWGetText("Codigo de barras (GTIN) ou PLU da balanca (5 digitos):", "")
            cB := FWGetText("Produto:", "")
            TBORes(GEBLOJBAR(cA, cB, Val(FWGetText("Unidades por leitura (fator):", "1"))), "Codigo de barras")
        ElseIf nOp == 21
            cA := FWGetText("Codigo da promocao:", "")
            cB := FWGetText("Produto:", "")
            cC := Upper(FWGetText("Tipo PRECO (preco promocional), LEVE (leve N pague M) ou QTD (% a partir de N):", "PRECO"))
            cD := FWGetText("N (quantidade minima / leve; vazio no PRECO):", "0")
            TBORes(GEBLOJPROMO(cA, cB, cC, Val(cD), Val(FWGetText("Valor (preco, pague M ou %; 0 encerra):", "")), ;
                FWGetText("Inicio AAAAMMDD:", BOHOJE()), FWGetText("Fim AAAAMMDD (vazio = sem fim):", "")), "Promocao")
        ElseIf nOp == 22
            cA := FWGetText("Codigo do vendedor:", "")
            cB := FWGetText("Nome:", "")
            TBORes(GEBLOJVEND(cA, cB, Val(FWGetText("Comissao %:", "0"))), "Vendedor")
        ElseIf nOp == 23
            cA := FWGetText("Inicio AAAAMMDD:", Left(BOHOJE(), 6) + "01")
            cB := FWGetText("Fim AAAAMMDD:", BOHOJE())
            TBORel(GEBLOJGER(cA, cB, FWGetText("Agrupar por DIA, CAIXA, OPERADOR ou VENDEDOR:", "DIA")), "Gerencial da loja")
        ElseIf nOp == 24
            cA := FWGetText("Inicio AAAAMMDD:", Left(BOHOJE(), 6) + "01")
            TBORel(GEBLOJCOMIS(cA, FWGetText("Fim AAAAMMDD:", BOHOJE())), "Comissao dos vendedores")
        ElseIf nOp == 26
            TBORes(GEBDFETRANSMITE(), "NFC-e em contingencia")
        ElseIf nOp == 27
            cA := FWGetText("Cupom:", "")
            TBODanfe(cEmp, cFil, cUsu, cA)
        Else
            cA := FWGetText("Provedor SIMULADOR, HTTP ou CIELO (vazio = mantem):", "")
            cB := FWGetText("URL (vazio = mantem; Cielo padrao = sandbox):", "")
            cC := FWGetText("MerchantId (Cielo; vazio = mantem):", "")
            cD := FWGetText("MerchantKey / token (vazio = mantem):", "")
            TBORes(GEBTEFCFG(cA, cB, cC, cD, FWGetText("Cartao de teste (Cielo; vazio = mantem):", ""), FWGetText("Bandeira (vazio = mantem):", "")), "TEF")
        EndIf
    EndDo
Return .T.

// Pagamentos do cupom: {aPagtos, cClienteDoFiado}. VALE pede o numero do vale.
Static Function TBOPagtos()
    Local aPg := TBOItens({"Forma DINHEIRO/PIX/DEBITO/CREDITO/FIADO/VALE (vazio termina):", "Valor:", "Parcelas (so' credito; vazio = 1):"}, {2, 3})
    Local cCli := ""
    Local nI := 0
    For nI := 1 To Len(aPg)
        aPg[nI][1] := Upper(aPg[nI][1])
        If aPg[nI][1] == "FIADO"
            cCli := FWGetText("Cliente do fiado:", "")
        EndIf
        If aPg[nI][1] == "VALE"
            aAdd(aPg[nI], FWGetText("Numero do vale-troca:", ""))
        EndIf
    Next nI
Return {aPg, cCli}

// Fecha a venda (ou o orcamento); desconto acima do limite pede o supervisor e tenta de novo.
Static Function TBOFinal(cSes, cOrc, aIt, nDesc, cVend, cCPF, aPg, cCli)
    Local aR := {}
    Local cSup := ""
    Local cSen := ""
    Local nTenta := 0
    Do While nTenta < 2
        If cOrc == ""
            aR := GEBLOJVEN(cSes, aIt, aPg, cCli, nDesc, cVend, cCPF, cSup, cSen)
        Else
            aR := GEBLOJORCFIN(cSes, cOrc, aPg, cCPF, cSup, cSen)
        EndIf
        If aR[1] .Or. !("desconto_acima_do_limite" $ aR[2]) .Or. nTenta > 0
            Exit
        EndIf
        cSup := FWGetText("Desconto acima do limite. Supervisor:", "")
        cSen := FWGetText("Senha do supervisor:", "", .T.)
        nTenta := nTenta + 1
    EndDo
    If aR[1]
        MsgInfo(aR[2] + " | total " + BONUM(aR[3][2], 2) + " | troco " + BONUM(aR[3][3], 2), "Venda")
    Else
        MsgStop("Venda recusada: " + aR[2], "Venda")
    EndIf
Return aR[1]

// Permissao da tela (mesmo mapa da API).
Static Function TBOPerm(cUsu, cMenu, cItem)
    If GEBSECRBAC(cUsu, cMenu, cItem)
        Return .T.
    EndIf
    MsgStop("Sem permissao para " + cMenu + "/" + cItem + ". Peca ao super: Nucleo > Permissoes.", "GEBAN")
Return .F.

Static Function TBORes(aR, cTitulo)
    If aR[1]
        MsgInfo(aR[2], cTitulo)
    Else
        MsgStop("Recusado: " + aR[2], cTitulo)
    EndIf
Return aR[1]

Static Function TBORel(aR, cTitulo)
    If !aR[1]
        MsgStop("Relatorio recusado: " + aR[2], cTitulo)
        Return .F.
    EndIf
    BOMIG()
Return GEBTUIBRW("GBR1", cTitulo)

// Lote/serie/endereco do movimento (vazio = produto sem controle): {{lote, validade, endereco, qtd}...}.
Static Function TBOLote(nQtd)
    Local cLote := AllTrim(BOSTR(FWGetText("Lote/series separadas por ; (vazio se nao controla):", "")))
    Local cVal := ""
    Local cEnd := ""
    If !(cLote == "")
        cVal := AllTrim(BOSTR(FWGetText("Validade AAAAMMDD (vazio = sem validade):", "")))
    EndIf
    cEnd := AllTrim(BOSTR(FWGetText("Endereco (vazio se nao controla):", "")))
Return GEBESTDET(cLote, cVal, cEnd, nQtd)

// Le itens ate o primeiro campo vazio. aPerg = perguntas; aNum = posicoes numericas.
Static Function TBOItens(aPerg, aNum)
    Local aRet := {}
    Local aLin := {}
    Local cV := ""
    Local nI := 0
    Do While Len(aRet) < 200
        aLin := {}
        For nI := 1 To Len(aPerg)
            cV := AllTrim(BOSTR(FWGetText(aPerg[nI], "")))
            If nI == 1 .And. cV == ""
                Return aRet
            EndIf
            If AScan(aNum, nI) > 0
                aAdd(aLin, Val(cV))
            Else
                aAdd(aLin, cV)
            EndIf
        Next nI
        aAdd(aRet, aLin)
    EndDo
Return aRet

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

/*/{Protheus.doc} GEBTUIDFE
    Fiscal > Documentos eletronicos (NF-e/NFC-e): roteiro do que falta,
    emitente, configuracao, perfil fiscal de produto, status da SEFAZ,
    transmissao de contingencias, consulta, cancelamento, inutilizacao e
    relatorio. O certificado A1 (.pfx) e' enviado pela pagina
    /api/dfe/configurar (a tela nao le arquivos). Permissao FISCAL/DFE.
    @type Tela
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBTUIDFE(cEmp, cFil, cUsu)
    Local aOps := {"icon:clipboard|O que falta para emitir (roteiro + teste com a SEFAZ)", "icon:plus|Emitente (CNPJ, IE, regime, endereco)", ;
        "icon:gear|Certificado digital A1", "icon:gear|Configuracao (ambiente, NFC-e, serie, CSC, padroes)", "icon:plus|Perfil fiscal de produto", ;
        "icon:eye|Status do servico da SEFAZ", "icon:check-circle|Transmitir NFC-e em contingencia", "icon:eye|Consultar documento na SEFAZ", ;
        "icon:check-circle|Cancelar documento", "icon:check-circle|Inutilizar faixa de numeros", "icon:check-circle|Inutilizar numeros das notas rejeitadas", ;
        "icon:clipboard|Relatorio: documentos eletronicos", "icon:plus|Cadastro fiscal de cliente ou fornecedor (NF-e)", ;
        "icon:check-circle|Carta de correcao (NF-e)", "icon:check-circle|Resolver NF-e/NFS-e sem resposta da SEFAZ", "icon:clipboard|DANFE/DANFSe de um documento (link)", ;
        "icon:plus|Servico fiscal (NFS-e)", "icon:check-circle|Faturar servico (NFS-e)", "icon:check-circle|Cancelar NFS-e", ;
        "icon:clipboard|SPED Fiscal (EFD ICMS/IPI) da competencia", "icon:gear|Configuracao da EFD (contabilista, receitas, vencimento)", "icon:arrow-left|< Voltar"}
    Local oE := Nil
    Local o := Nil
    Local aR := {}
    Local cA := ""
    Local cB := ""
    Local nOp := 0
    Local nI := 0
    Do While .T.
        nOp := FWMenuSelect(aOps, "Documentos eletronicos:")
        If nOp == Nil .Or. nOp <= 0 .Or. nOp == Len(aOps)
            Exit
        EndIf
        If nOp == 7
            If !TBOPerm(cUsu, "LOJA", "CAIXA")
                Loop
            EndIf
        ElseIf !TBOPerm(cUsu, "FISCAL", "DFE")
            Loop
        EndIf
        If nOp == 1
            aR := GEBDFEROTEIRO(MsgYesNo("Testar a comunicacao com a SEFAZ agora?", "Roteiro"))
            If aR[1]
                MsgInfo("Tudo pronto para emitir NFC-e.", "Roteiro")
            Else
                MsgStop("Ha itens em FALTA: veja o roteiro.", "Roteiro")
            EndIf
            GEBTUIBRW("GBR1", "O que falta para emitir")
        ElseIf nOp == 2
            oE := GEBDFEEMITLE()
            o := JsonObject():New()
            o["CNPJ"] := FWGetText("CNPJ:", TBOJ(oE, "CNPJ"))
            o["IE"] := FWGetText("Inscricao estadual:", TBOJ(oE, "IE"))
            o["RAZAO"] := FWGetText("Razao social:", TBOJ(oE, "XNOME"))
            o["FANTASIA"] := FWGetText("Nome fantasia:", TBOJ(oE, "XFANT"))
            o["CRT"] := FWGetText("Regime: 1 Simples, 4 MEI, 2 Simples com excesso, 3 normal:", TBOJ(oE, "CRT"))
            o["IM"] := FWGetText("Inscricao municipal (vazio = nao tem):", TBOJ(oE, "IM"))
            o["CNAE"] := FWGetText("CNAE (vazio = nao informa):", TBOJ(oE, "CNAE"))
            o["LOGRADOURO"] := FWGetText("Logradouro:", TBOJ(oE, "XLGR"))
            o["NUMERO"] := FWGetText("Numero:", TBOJ(oE, "NRO"))
            o["COMPLEMENTO"] := FWGetText("Complemento:", TBOJ(oE, "XCPL"))
            o["BAIRRO"] := FWGetText("Bairro:", TBOJ(oE, "XBAIRRO"))
            o["UF"] := Upper(FWGetText("UF:", TBOJ(oE, "UF")))
            o["MUNICIPIO"] := TBOMun(o["UF"], TBOJ(oE, "CMUN"), TBOJ(oE, "XMUN"))
            o["CEP"] := FWGetText("CEP:", TBOJ(oE, "CEP"))
            o["FONE"] := FWGetText("Telefone:", TBOJ(oE, "FONE"))
            o["EMAIL"] := FWGetText("E-mail:", TBOJ(oE, "EMAIL"))
            TBORes(GEBDFEEMIT(o), "Emitente")
        ElseIf nOp == 3
            aR := GEBDFECERTLE()
            cA := "Nenhum certificado instalado."
            If Len(aR) > 0
                cA := "Instalado: " + aR[1] + " (CNPJ " + aR[2] + "), valido ate " + Right(aR[3], 2) + "/" + SubStr(aR[3], 5, 2) + "/" + Left(aR[3], 4) + "."
            EndIf
            MsgInfo(cA + " Para enviar o arquivo .pfx abra no navegador: " + BOPARM("GEBAN_URL", "https://SEU-DOMINIO") + ;
                "/api/dfe/configurar (entre com a mesma empresa, usuario e senha).", "Certificado A1")
        ElseIf nOp == 4
            o := JsonObject():New()
            o["AMBIENTE"] := FWGetText("Ambiente 1 producao / 2 homologacao:", BOPARM("DFE_AMBIENTE", "2"))
            o["NFCE"] := Upper(FWGetText("NFC-e na frente de loja S/N:", BOPARM("DFE_NFCE", "N")))
            o["SERIE_NFCE"] := FWGetText("Serie da NFC-e:", BOPARM("DFE_SERIE_65", "1"))
            o["NFE"] := Upper(FWGetText("NF-e no faturamento e nas devolucoes S/N:", BOPARM("DFE_NFE", "N")))
            o["SERIE_NFE"] := FWGetText("Serie da NF-e:", BOPARM("DFE_SERIE_55", "1"))
            o["NFE_TPAG"] := FWGetText("Forma de pagamento da NF-e de venda (15 boleto, 99 outros...):", BOPARM("DFE_NFE_TPAG", "15"))
            o["NFSE"] := Upper(FWGetText("NFS-e (servicos, padrao nacional) S/N:", BOPARM("DFE_NFSE", "N")))
            o["SERIE_NFSE"] := FWGetText("Serie da DPS:", BOPARM("DFE_SERIE_NFSE", "1"))
            o["PROXIMO_NFCE"] := FWGetText("Proximo numero (vazio = segue a numeracao do GEBAN):", "")
            o["CFOP"] := FWGetText("CFOP padrao:", BOPARM("DFE_CFOP", "5102"))
            o["CSOSN"] := FWGetText("CSOSN padrao (Simples):", BOPARM("DFE_CSOSN", "102"))
            o["UNIDADE"] := FWGetText("Unidade padrao:", BOPARM("DFE_UNIDADE", "UN"))
            o["CSC_ID"] := FWGetText("ID do CSC (so' se a UF usar QR Code versao 2):", BOPARM("DFE_CSC_ID", ""))
            o["CSC"] := FWGetText("Codigo CSC:", BOPARM("DFE_CSC", ""), .T.)
            o["RT_CNPJ"] := FWGetText("Responsavel tecnico - CNPJ (vazio = nao informa):", BOPARM("DFE_RT_CNPJ", ""))
            If !(BOCOL(o["RT_CNPJ"]) == "")
                o["RT_CONTATO"] := FWGetText("Responsavel tecnico - contato:", BOPARM("DFE_RT_CONTATO", ""))
                o["RT_EMAIL"] := FWGetText("Responsavel tecnico - e-mail:", BOPARM("DFE_RT_EMAIL", ""))
                o["RT_FONE"] := FWGetText("Responsavel tecnico - telefone:", BOPARM("DFE_RT_FONE", ""))
            EndIf
            TBORes(GEBDFECONFIG(o), "Configuracao")
        ElseIf nOp == 5
            o := JsonObject():New()
            o["PRODUTO"] := FWGetText("Produto:", "")
            o["UNIDADE"] := FWGetText("Unidade (vazio = padrao):", "")
            o["GTIN"] := FWGetText("GTIN/EAN (vazio = do codigo de barras da loja):", "")
            o["CFOP"] := FWGetText("CFOP (vazio = padrao):", "")
            o["CSOSN"] := FWGetText("CSOSN (Simples; vazio = padrao):", "")
            o["CST"] := FWGetText("CST do ICMS (regime normal; vazio = padrao):", "")
            o["ALIQ_ICMS"] := FWGetText("Aliquota do ICMS % (regime normal):", "0")
            o["CEST"] := FWGetText("CEST (vazio = nao tem):", "")
            o["ORIGEM"] := FWGetText("Origem 0 a 8 (vazio = padrao):", "")
            o["PIS_CST"] := FWGetText("CST do PIS (vazio = padrao):", "")
            o["COFINS_CST"] := FWGetText("CST da COFINS (vazio = padrao):", "")
            TBORes(GEBDFEPRODFIS(o), "Perfil fiscal")
        ElseIf nOp == 6
            TBORes(GEBDFESTATSVC("65"), "SEFAZ")
        ElseIf nOp == 7
            TBORes(GEBDFETRANSMITE(), "Contingencia")
        ElseIf nOp == 8
            TBORes(GEBDFECONSULTAR(FWGetText("Chave de acesso:", ""), .T.), "Consulta")
        ElseIf nOp == 9
            cA := FWGetText("Chave de acesso:", "")
            TBORes(GEBDFECANCELA(cA, FWGetText("Justificativa (minimo 15 letras):", "")), "Cancelamento")
        ElseIf nOp == 10
            cA := FWGetText("Modelo 65 (NFC-e) ou 55 (NF-e):", "65")
            cB := FWGetText("Serie:", BOPARM("DFE_SERIE_65", "1"))
            nI := Val(FWGetText("Numero inicial:", ""))
            TBORes(GEBDFEINUTILIZA(cA, Val(cB), nI, Val(FWGetText("Numero final:", cValToChar(nI))), FWGetText("Justificativa (minimo 15 letras):", "")), ;
                "Inutilizacao")
        ElseIf nOp == 11
            TBORes(GEBDFEINUTPEND(FWGetText("Justificativa (minimo 15 letras):", "Numero rejeitado pela SEFAZ e nao utilizado")), "Inutilizacao")
        ElseIf nOp == 12
            cA := FWGetText("Inicio AAAAMMDD:", Left(BOHOJE(), 6) + "01")
            cB := FWGetText("Fim AAAAMMDD:", BOHOJE())
            TBORel(GEBDFEDOCS(cA, cB, FWGetText("Situacao (vazio = todas):", "")), "Documentos eletronicos")
        ElseIf nOp == 13
            o := JsonObject():New()
            o["TIPO"] := Upper(FWGetText("C (cliente) ou F (fornecedor):", "C"))
            o["CODIGO"] := FWGetText("Codigo do cliente/fornecedor:", "")
            o["DOC"] := FWGetText("CPF ou CNPJ:", "")
            o["CONTRIBUINTE"] := FWGetText("1 contribuinte (com IE), 2 isento, 9 nao contribuinte:", "1")
            o["IE"] := FWGetText("Inscricao estadual (vazio se nao contribuinte):", "")
            o["NOME"] := FWGetText("Nome/razao social (vazio = o do cadastro):", "")
            o["LOGRADOURO"] := FWGetText("Logradouro:", "")
            o["NUMERO"] := FWGetText("Numero:", "")
            o["COMPLEMENTO"] := FWGetText("Complemento:", "")
            o["BAIRRO"] := FWGetText("Bairro:", "")
            o["UF"] := Upper(FWGetText("UF:", ""))
            o["MUNICIPIO"] := TBOMun(o["UF"], "", "")
            o["CEP"] := FWGetText("CEP:", "")
            o["FONE"] := FWGetText("Telefone:", "")
            o["EMAIL"] := FWGetText("E-mail:", "")
            TBORes(GEBDFEPART(o), "Cadastro fiscal")
        ElseIf nOp == 14
            cA := FWGetText("Chave de acesso da NF-e:", "")
            TBORes(GEBDFECCE(cA, FWGetText("Correcao (15 a 1000 letras; nao corrige valores, impostos, quantidades, datas nem quem compra/vende):", "")), ;
                "Carta de correcao")
        ElseIf nOp == 15
            aR := GEBDFERESOLVE()
            MsgInfo("NF-e: " + aR[2] + " | NFS-e: " + GEBDFENFSERESOLVE()[2], "Pendentes")
        ElseIf nOp == 17
            o := JsonObject():New()
            o["CODIGO"] := FWGetText("Codigo do servico:", "")
            o["DESCRICAO"] := FWGetText("Descricao:", "")
            o["TRIB_NACIONAL"] := FWGetText("Codigo de tributacao nacional (6 digitos, ex.: 010101):", "")
            o["TRIB_MUNICIPAL"] := FWGetText("Codigo de tributacao municipal (3 digitos; vazio = nao tem):", "")
            o["NBS"] := FWGetText("NBS (9 digitos; vazio = nao informa):", "")
            o["ALIQ_ISS"] := FWGetText("Aliquota do ISS % (so' usada quando o tomador retem):", "0")
            TBORes(GEBDFESERV(o), "Servico fiscal")
        ElseIf nOp == 18
            If !TBOPerm(cUsu, "FATURAMENTO", "FATUR")
                Loop
            EndIf
            cA := FWGetText("Cliente:", "")
            cB := FWGetText("Servico:", "")
            nI := Val(FWGetText("Valor:", ""))
            TBORes(GEBFATSERV(cA, cB, nI, FWGetText("Descricao complementar:", ""), FWGetText("Condicao de pagamento (vazio = a vista):", ""), ;
                FWGetText("Data AAAAMMDD:", BOHOJE()), Upper(FWGetText("ISS retido pelo tomador S/N:", "N")) == "S", Val(FWGetText("Desconto:", "0"))), "Servico")
        ElseIf nOp == 19
            cA := FWGetText("Chave da NFS-e (50 digitos):", "")
            cB := FWGetText("Motivo 1 erro na emissao, 2 servico nao prestado, 9 outros:", "1")
            TBORes(GEBDFENFSECANC(cA, cB, FWGetText("Justificativa (minimo 15 letras):", "")), "Cancelar NFS-e")
        ElseIf nOp == 20
            cA := FWGetText("Competencia AAAAMM:", Left(BOMESADD(Left(BOHOJE(), 6), -1), 6))
            aR := GEBDFEEFD(cA, FWGetText("Finalidade 0 original, 1 substituto:", "0"))
            If aR[1]
                MsgInfo(aR[2] + ". Baixe o arquivo na pagina " + BOPARM("GEBAN_URL", "https://SEU-DOMINIO") + ;
                    "/api/dfe/configurar (secao SPED Fiscal) e valide no PVA.", "EFD ICMS/IPI")
            Else
                MsgStop(aR[2], "EFD ICMS/IPI")
            EndIf
        ElseIf nOp == 21
            o := JsonObject():New()
            o["EFD_PERFIL"] := Upper(FWGetText("Perfil de apresentacao (A, B ou C, conforme a UF):", BOPARM("DFE_EFD_PERFIL", "A")))
            o["EFD_ATIVIDADE"] := FWGetText("Atividade 0 industrial ou equiparado, 1 outros:", BOPARM("DFE_EFD_ATIV", "1"))
            o["EFD_COD_REC"] := FWGetText("Codigo de receita do ICMS proprio (UF):", BOPARM("DFE_EFD_COD_REC", ""))
            o["EFD_COD_REC_ST"] := FWGetText("Codigo de receita do ICMS ST:", BOPARM("DFE_EFD_COD_REC_ST", ""))
            o["EFD_COD_REC_DIFAL"] := FWGetText("Codigo de receita do DIFAL:", BOPARM("DFE_EFD_COD_REC_DIFAL", ""))
            o["EFD_COD_REC_FCP"] := FWGetText("Codigo de receita do FCP:", BOPARM("DFE_EFD_COD_REC_FCP", ""))
            o["EFD_DIA_VENC"] := FWGetText("Dia do vencimento do ICMS no mes seguinte:", BOPARM("DFE_EFD_DIA_VENC", "20"))
            o["EFD_SALDO_CREDOR_INICIAL"] := FWGetText("Saldo credor de ICMS antes do 1o arquivo (0 se nao ha):", BOPARM("DFE_EFD_SLD_CRED_INI", "0"))
            o["CONT_NOME"] := FWGetText("Contabilista - nome:", BOPARM("DFE_EFD_CONT_NOME", ""))
            o["CONT_CPF"] := FWGetText("Contabilista - CPF:", BOPARM("DFE_EFD_CONT_CPF", ""))
            o["CONT_CRC"] := FWGetText("Contabilista - CRC:", BOPARM("DFE_EFD_CONT_CRC", ""))
            o["CONT_CNPJ"] := FWGetText("Escritorio de contabilidade - CNPJ (vazio = nao tem):", BOPARM("DFE_EFD_CONT_CNPJ", ""))
            o["CONT_EMAIL"] := FWGetText("Contabilista - e-mail:", BOPARM("DFE_EFD_CONT_EMAIL", ""))
            o["CONT_FONE"] := FWGetText("Contabilista - telefone:", BOPARM("DFE_EFD_CONT_FONE", ""))
            o["CONT_CEP"] := FWGetText("Contabilista - CEP:", BOPARM("DFE_EFD_CONT_CEP", ""))
            o["CONT_END"] := FWGetText("Contabilista - logradouro:", BOPARM("DFE_EFD_CONT_END", ""))
            o["CONT_NUM"] := FWGetText("Contabilista - numero:", BOPARM("DFE_EFD_CONT_NUM", ""))
            o["CONT_BAIRRO"] := FWGetText("Contabilista - bairro:", BOPARM("DFE_EFD_CONT_BAIRRO", ""))
            o["CONT_MUNICIPIO"] := TBOMun(Upper(FWGetText("Contabilista - UF:", "")), BOPARM("DFE_EFD_CONT_MUN", ""), "")
            TBORes(GEBDFECONFIG(o), "Configuracao da EFD")
        ElseIf nOp == 16
            cA := GEBDFEDIG(FWGetText("Chave de acesso:", ""))
            MsgInfo("Para ver e imprimir, abra no navegador: " + BOPARM("GEBAN_URL", "https://SEU-DOMINIO") + "/api/dfe/danfe?empresa=" + cEmp + ;
                "&chave=" + cA + "&token=" + GEBSECTOKEN(cUsu, cEmp, cFil, "danfe"), "DANFE")
        EndIf
    EndDo
Return .T.

Static Function TBOJ(oJ, cCampo)
    If oJ == Nil
        Return ""
    EndIf
Return BOCOL(oJ[cCampo])

// Municipio pelo nome dentro da UF (escolha na lista); devolve o codigo IBGE.
Static Function TBOMun(cUF, cCodAtual, cNomeAtual)
    Local aM := {}
    Local aOps := {}
    Local cNome := FWGetText("Municipio (nome ou parte dele):", cNomeAtual)
    Local nOp := 0
    Local nI := 0
    aM := GEBDFEMUNBUSCA(cNome, cUF)
    If Len(aM) == 0
        MsgStop("Nenhum municipio de " + cUF + " com '" + cNome + "'.", "Municipio")
        Return cCodAtual
    EndIf
    If Len(aM) == 1
        Return aM[1][1]
    EndIf
    For nI := 1 To Min(Len(aM), 30)
        aAdd(aOps, aM[nI][2] + " (" + aM[nI][1] + ")")
    Next nI
    nOp := FWMenuSelect(aOps, "Escolha o municipio:")
    If nOp == Nil .Or. nOp <= 0
        Return cCodAtual
    EndIf
Return aM[nOp][1]

// Dados do consumidor para a NF-e de devolucao da NFC-e.
Static Function TBOConsumidor()
    Local o := JsonObject():New()
    MsgInfo("O cupom tem NFC-e: a devolucao sai com NF-e de entrada e precisa do consumidor.", "Devolucao")
    o["DOC"] := FWGetText("CPF/CNPJ do consumidor:", "")
    o["NOME"] := FWGetText("Nome:", "")
    o["LOGRADOURO"] := FWGetText("Logradouro:", "")
    o["NUMERO"] := FWGetText("Numero:", "")
    o["COMPLEMENTO"] := FWGetText("Complemento:", "")
    o["BAIRRO"] := FWGetText("Bairro:", "")
    o["UF"] := Upper(FWGetText("UF:", ""))
    o["MUNICIPIO"] := TBOMun(o["UF"], "", "")
    o["CEP"] := FWGetText("CEP:", "")
    o["FONE"] := FWGetText("Telefone:", "")
Return o
