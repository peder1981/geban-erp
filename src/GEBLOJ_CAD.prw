#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBFAT.prw"

/*/{Protheus.doc} GEBLOJ_CAD
    Cadastros e regras de preco da frente de loja (inspirado em SLK codigo
    de barras, MEI/MB8 regras de desconto e SA3 vendedores do Protheus).
    - GLJ8 codigos de barras: GTIN-8/12/13/14 (digito conferido) ou PLU de
      balanca (5 digitos) -> produto e fator (caixa com 12 = 12).
    - Etiqueta de balanca: EAN-13 "2" + PLU(5) + valor(6) + DV. GE4
      LOJ_BALANCA = PRECO (valor em centavos, padrao) ou PESO (gramas).
    - GLJ9 promocoes por produto e vigencia: PRECO (preco promocional),
      LEVE (leve N pague M) e QTD (percentual a partir de N unidades). Vale
      a que deixar o item mais barato; so' quando o preco nao e' informado.
    - GLJC vendedores com percentual de comissao.
    - GEBLOJCPFOK: CPF ou CNPJ com digitos conferidos.
    Tabelas da frente de loja ampliada criadas aqui: GLJ8, GLJ9, GLJA
    (promocao aplicada por item), GLJB (complemento do cupom: vendedor, CPF,
    orcamento, quem liberou o desconto, hora), GLJC, GLJD/GLJE (orcamento),
    GLJF (vale-troca) e GLJH (devolucao no caixa).
    @type Modulo frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBLOJCADMIG()
    Local lOk := GEBFATMIG()
    lOk := lOk .And. BOTAB("GLJ8", "GLJ8_COD TEXT NOT NULL, GLJ8_PROD TEXT NOT NULL, GLJ8_FATOR NUMERIC(18,4) NOT NULL", "GLJ8_COD")
    lOk := lOk .And. BOTAB("GLJ9", "GLJ9_COD TEXT NOT NULL, GLJ9_PROD TEXT NOT NULL, GLJ9_TIPO TEXT NOT NULL, GLJ9_QTDMIN NUMERIC(18,4) NOT NULL, " + ;
        "GLJ9_VALOR NUMERIC(18,6) NOT NULL, GLJ9_INI TEXT NOT NULL, GLJ9_FIM TEXT NOT NULL", "GLJ9_PROD")
    lOk := lOk .And. BOTAB("GLJA", "GLJA_CUPOM TEXT NOT NULL, GLJA_PROD TEXT NOT NULL, GLJA_PROMO TEXT NOT NULL, GLJA_DESC NUMERIC(18,2) NOT NULL", "GLJA_CUPOM")
    lOk := lOk .And. BOTAB("GLJB", "GLJB_CUPOM TEXT NOT NULL, GLJB_VEND TEXT NOT NULL, GLJB_CPF TEXT NOT NULL, GLJB_ORC TEXT NOT NULL, " + ;
        "GLJB_AUTOR TEXT NOT NULL, GLJB_HORA TEXT NOT NULL", "GLJB_CUPOM")
    lOk := lOk .And. BOTAB("GLJC", "GLJC_COD TEXT NOT NULL, GLJC_NOME TEXT NOT NULL, GLJC_COMIS NUMERIC(8,4) NOT NULL", "GLJC_COD")
    lOk := lOk .And. BOTAB("GLJD", "GLJD_ORC TEXT NOT NULL, GLJD_CLI TEXT NOT NULL, GLJD_VEND TEXT NOT NULL, GLJD_DATA TEXT NOT NULL, " + ;
        "GLJD_VALID TEXT NOT NULL, GLJD_DESC NUMERIC(18,2) NOT NULL, GLJD_TOTAL NUMERIC(18,2) NOT NULL, GLJD_STATUS TEXT NOT NULL, GLJD_CUPOM TEXT NOT NULL", "GLJD_ORC")
    lOk := lOk .And. BOTAB("GLJE", "GLJE_ORC TEXT NOT NULL, GLJE_PROD TEXT NOT NULL, GLJE_QTD NUMERIC(18,4) NOT NULL, GLJE_PRECO NUMERIC(18,6) NOT NULL", "GLJE_ORC")
    lOk := lOk .And. BOTAB("GLJF", "GLJF_VALE TEXT NOT NULL, GLJF_CLI TEXT NOT NULL, GLJF_VALOR NUMERIC(18,2) NOT NULL, GLJF_SALDO NUMERIC(18,2) NOT NULL, " + ;
        "GLJF_DATA TEXT NOT NULL, GLJF_ORIGEM TEXT NOT NULL, GLJF_STATUS TEXT NOT NULL", "GLJF_VALE")
    lOk := lOk .And. BOTAB("GLJH", "GLJH_DEV TEXT NOT NULL, GLJH_CUPOM TEXT NOT NULL, GLJH_SESSAO TEXT NOT NULL, GLJH_PROD TEXT NOT NULL, " + ;
        "GLJH_QTD NUMERIC(18,4) NOT NULL, GLJH_VALOR NUMERIC(18,2) NOT NULL, GLJH_CUSTO NUMERIC(18,2) NOT NULL, GLJH_DATA TEXT NOT NULL, " + ;
        "GLJH_MODO TEXT NOT NULL, GLJH_VALE TEXT NOT NULL", "GLJH_CUPOM")
Return lOk

/*/{Protheus.doc} GEBLOJBAR
    Cadastra o codigo de barras (GTIN com digito valido) ou o PLU de balanca
    (5 digitos) do produto. Fator = unidades do produto por leitura.
    @type Cadastro frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBLOJBAR(cCodigo, cProd, nFator)
    Local cFil := FWxFilial("GLJ8")
    cCodigo := BOCOL(cCodigo)
    cProd := BOCOL(cProd)
    nFator := BOVAL(nFator)
    If nFator <= 0
        nFator := 1
    EndIf
    If !(Len(cCodigo) == 5 .And. StrZero(Val(cCodigo), 5) == cCodigo) .And. !GEBLOJEANOK(cCodigo)
        Return {.F., "codigo_invalido: GTIN-8/12/13/14 com digito certo ou PLU de 5 digitos"}
    EndIf
    If !GEBLOJCADMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    If Len(TCSqlQuery("SELECT GF1_COD FROM GF1 WHERE GF1_FILIAL = " + GEBDBQuote(FWxFilial("GF1")) + " AND GF1_COD = " + GEBDBQuote(cProd) + ;
            " AND D_E_L_E_T_ = ' '")) == 0
        Return {.F., "produto_inexistente: " + cProd}
    EndIf
    TCSqlExec("UPDATE GLJ8 SET D_E_L_E_T_ = '*' WHERE GLJ8_FILIAL = " + GEBDBQuote(cFil) + " AND GLJ8_COD = " + GEBDBQuote(cCodigo) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GLJ8 (D_E_L_E_T_, GLJ8_FILIAL, GLJ8_COD, GLJ8_PROD, GLJ8_FATOR) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
        GEBDBQuote(cCodigo) + ", " + GEBDBQuote(cProd) + ", " + BONUM(nFator, 4) + ")")
Return {.T., "codigo " + cCodigo + " -> " + cProd}

/*/{Protheus.doc} GEBLOJEANOK
    GTIN-8/12/13/14 com digito verificador certo (modulo 10, pesos 3 e 1).
    @type Funcao utilitaria
    @author Peder Munksgaard
    @since 19/10/2026
    @return lOk
/*/
User Function GEBLOJEANOK(cCodigo)
    Local nSoma := 0
    Local nI := 0
    Local nPeso := 3
    cCodigo := BOCOL(cCodigo)
    If AScan({8, 12, 13, 14}, Len(cCodigo)) == 0 .Or. !(StrZero(Val(cCodigo), Len(cCodigo)) == cCodigo)
        Return .F.
    EndIf
    For nI := Len(cCodigo) - 1 To 1 Step -1
        nSoma := nSoma + Val(SubStr(cCodigo, nI, 1)) * nPeso
        nPeso := 4 - nPeso
    Next nI
Return BOMOD(10 - BOMOD(nSoma, 10), 10) == Val(Right(cCodigo, 1))

/*/{Protheus.doc} GEBLOJRESOLVE
    Traduz o que foi lido no caixa em produto, quantidade e preco: codigo do
    produto, codigo de barras (quantidade x fator) ou etiqueta de balanca.
    Codigo desconhecido volta como veio (a venda recusa pelo preco).
    @type Funcao frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {cProd, nQtd, nPreco}} nPreco 0 = tabela/promocao
/*/
User Function GEBLOJRESOLVE(cCodigo, nQtd, nPreco)
    Local aHit := {}
    Local nVal := 0
    Local nTab := 0
    Local nQ := 0
    cCodigo := BOCOL(cCodigo)
    nQtd := BOVAL(nQtd)
    nPreco := BOVAL(nPreco)
    If Len(TCSqlQuery("SELECT GF1_COD FROM GF1 WHERE GF1_FILIAL = " + GEBDBQuote(FWxFilial("GF1")) + " AND GF1_COD = " + GEBDBQuote(cCodigo) + ;
            " AND D_E_L_E_T_ = ' '")) > 0
        Return {.T., "produto", {cCodigo, nQtd, nPreco}}
    EndIf
    aHit := LOJBarra(cCodigo)
    If Len(aHit) > 0
        Return {.T., "codigo_de_barras", {BOCOL(aHit[1]:P), Round(nQtd * BOVAL(aHit[1]:F), 4), nPreco}}
    EndIf
    If Len(cCodigo) == 13 .And. Left(cCodigo, 1) == "2" .And. GEBLOJEANOK(cCodigo)
        aHit := LOJBarra(SubStr(cCodigo, 2, 5))
        If Len(aHit) > 0
            nVal := Val(SubStr(cCodigo, 7, 6))
            If BOPARM("LOJ_BALANCA", "PRECO") == "PESO"
                Return {.T., "balanca_peso", {BOCOL(aHit[1]:P), Round(nQtd * nVal / 1000, 4), nPreco}}
            EndIf
            nVal := Round(nVal / 100, 2)
            nTab := GEBFATPRECO("", BOCOL(aHit[1]:P))
            If nTab <= 0 .Or. nVal <= 0
                Return {.F., "etiqueta_sem_preco: " + cCodigo, {}}
            EndIf
            nQ := Round(nVal / nTab, 4)
            If nQ <= 0
                nQ := 0.0001
            EndIf
            Return {.T., "balanca_preco", {BOCOL(aHit[1]:P), Round(nQ * nQtd, 4), Round(nVal / nQ, 6)}}
        EndIf
    EndIf
Return {.T., "desconhecido", {cCodigo, nQtd, nPreco}}

/*/{Protheus.doc} GEBLOJPROMO
    Cadastra/altera a promocao (cCod). Tipos:
    - PRECO: nValor = preco promocional (nQtdMin ignorado);
    - LEVE: leve nQtdMin pague nValor (inteiros, nValor < nQtdMin);
    - QTD: nValor % de desconto a partir de nQtdMin unidades.
    nValor 0 encerra a promocao.
    @type Cadastro frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBLOJPROMO(cCod, cProd, cTipo, nQtdMin, nValor, cIni, cFim)
    Local cFil := FWxFilial("GLJ9")
    cCod := Upper(BOCOL(cCod))
    cProd := BOCOL(cProd)
    cTipo := Upper(BOCOL(cTipo))
    nQtdMin := BOVAL(nQtdMin)
    nValor := BOVAL(nValor)
    cIni := BODATA(cIni)
    cFim := BOCOL(cFim)
    If cFim == ""
        cFim := "20991231"
    EndIf
    If cCod == "" .Or. Len(cCod) > 10
        Return {.F., "codigo_invalido: 1 a 10 caracteres"}
    EndIf
    If !GEBLOJCADMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    TCSqlExec("UPDATE GLJ9 SET D_E_L_E_T_ = '*' WHERE GLJ9_FILIAL = " + GEBDBQuote(cFil) + " AND GLJ9_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")
    If nValor == 0
        Return {.T., "promocao " + cCod + " encerrada"}
    EndIf
    If AScan({"PRECO", "LEVE", "QTD"}, cTipo) == 0
        Return {.F., "tipo_invalido: PRECO, LEVE ou QTD"}
    EndIf
    If cIni == "" .Or. !BODATAOK(cFim) .Or. cFim < cIni
        Return {.F., "vigencia_invalida"}
    EndIf
    If GEBFATPRECO("", cProd) <= 0
        Return {.F., "produto_sem_preco: " + cProd}
    EndIf
    If cTipo == "LEVE" .And. (nQtdMin < 2 .Or. nValor < 1 .Or. nValor >= nQtdMin .Or. !(Int(nQtdMin) == nQtdMin) .Or. !(Int(nValor) == nValor))
        Return {.F., "leve_pague_invalido: leve N pague M inteiros, M < N"}
    EndIf
    If cTipo == "QTD" .And. (nQtdMin <= 0 .Or. nValor <= 0 .Or. nValor >= 100)
        Return {.F., "desconto_por_quantidade_invalido"}
    EndIf
    If cTipo == "PRECO" .And. nValor >= GEBFATPRECO("", cProd)
        Return {.F., "preco_promocional_nao_e_menor_que_o_da_tabela"}
    EndIf
    TCSqlExec("INSERT INTO GLJ9 (D_E_L_E_T_, GLJ9_FILIAL, GLJ9_COD, GLJ9_PROD, GLJ9_TIPO, GLJ9_QTDMIN, GLJ9_VALOR, GLJ9_INI, GLJ9_FIM) VALUES (' ', " + ;
        GEBDBQuote(cFil) + ", " + GEBDBQuote(cCod) + ", " + GEBDBQuote(cProd) + ", " + GEBDBQuote(cTipo) + ", " + BONUM(nQtdMin, 4) + ", " + ;
        BONUM(nValor, 6) + ", " + GEBDBQuote(cIni) + ", " + GEBDBQuote(cFim) + ")")
Return {.T., "promocao " + cCod + " gravada"}

/*/{Protheus.doc} GEBLOJPRECO
    Preco unitario do item na data: o da tabela PADRAO ou o da promocao
    vigente que deixar o item mais barato.
    @type Funcao frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
    @return {nPrecoUnitario, cPromocao, nDescontoPromocao, nPrecoTabela}
/*/
User Function GEBLOJPRECO(cProd, nQtd, cData)
    Local aHit := {}
    Local cPromo := ""
    Local nTab := 0
    Local nCheio := 0
    Local nMelhor := 0
    Local nT := 0
    Local nG := 0
    Local nI := 0
    cProd := BOCOL(cProd)
    nQtd := BOVAL(nQtd)
    cData := BODATA(cData)
    nTab := GEBFATPRECO("", cProd)
    If nTab <= 0 .Or. nQtd <= 0
        Return {nTab, "", 0, nTab}
    EndIf
    nCheio := nQtd * nTab
    nMelhor := nCheio
    aHit := TCSqlQuery("SELECT GLJ9_COD AS C, GLJ9_TIPO AS T, GLJ9_QTDMIN AS Q, GLJ9_VALOR AS V FROM GLJ9 WHERE GLJ9_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GLJ9")) + " AND GLJ9_PROD = " + GEBDBQuote(cProd) + " AND GLJ9_INI <= " + GEBDBQuote(cData) + ;
        " AND GLJ9_FIM >= " + GEBDBQuote(cData) + " AND D_E_L_E_T_ = ' ' ORDER BY GLJ9_COD")
    For nI := 1 To Len(aHit)
        nT := nCheio
        If BOCOL(aHit[nI]:T) == "PRECO"
            nT := nQtd * BOVAL(aHit[nI]:V)
        ElseIf BOCOL(aHit[nI]:T) == "LEVE"
            nG := Int(nQtd / BOVAL(aHit[nI]:Q))
            nT := (nG * BOVAL(aHit[nI]:V) + nQtd - nG * BOVAL(aHit[nI]:Q)) * nTab
        ElseIf nQtd >= BOVAL(aHit[nI]:Q)
            nT := nCheio * (1 - BOVAL(aHit[nI]:V) / 100)
        EndIf
        If nT < nMelhor
            nMelhor := nT
            cPromo := BOCOL(aHit[nI]:C)
        EndIf
    Next nI
    If cPromo == ""
        Return {nTab, "", 0, nTab}
    EndIf
Return {Round(nMelhor / nQtd, 6), cPromo, Round(nCheio - Round(nMelhor, 2), 2), nTab}

/*/{Protheus.doc} GEBLOJVEND
    Cadastra/altera o vendedor e o percentual de comissao.
    @type Cadastro frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBLOJVEND(cCod, cNome, nComis)
    Local cFil := FWxFilial("GLJC")
    cCod := Upper(BOCOL(cCod))
    nComis := BOVAL(nComis)
    If cCod == "" .Or. Len(cCod) > 10
        Return {.F., "codigo_invalido: 1 a 10 caracteres"}
    EndIf
    If nComis < 0 .Or. nComis >= 100
        Return {.F., "comissao_invalida: 0 a 99,99%"}
    EndIf
    If !GEBLOJCADMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    TCSqlExec("UPDATE GLJC SET D_E_L_E_T_ = '*' WHERE GLJC_FILIAL = " + GEBDBQuote(cFil) + " AND GLJC_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GLJC (D_E_L_E_T_, GLJC_FILIAL, GLJC_COD, GLJC_NOME, GLJC_COMIS) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
        GEBDBQuote(cCod) + ", " + GEBDBQuote(BOCOL(cNome)) + ", " + BONUM(nComis, 4) + ")")
Return {.T., "vendedor " + cCod + " gravado"}

/*/{Protheus.doc} GEBLOJVENDOK
    Vendedor cadastrado?
    @type Funcao frente de loja
    @author Peder Munksgaard
    @since 19/10/2026
    @return lOk
/*/
User Function GEBLOJVENDOK(cCod)
Return Len(TCSqlQuery("SELECT GLJC_COD FROM GLJC WHERE GLJC_FILIAL = " + GEBDBQuote(FWxFilial("GLJC")) + " AND GLJC_COD = " + ;
    GEBDBQuote(Upper(BOCOL(cCod))) + " AND D_E_L_E_T_ = ' '")) > 0

/*/{Protheus.doc} GEBLOJCPFOK
    CPF (11 digitos) ou CNPJ (14 digitos) com digitos verificadores certos.
    Pontos, barras e tracos sao ignorados.
    @type Funcao utilitaria
    @author Peder Munksgaard
    @since 19/10/2026
    @return lOk
/*/
User Function GEBLOJCPFOK(cDoc)
    Local cD := LOJDigitos(cDoc)
    If Len(cD) == 11
        If cD == Replicate(Left(cD, 1), 11)
            Return .F.
        EndIf
        Return LOJDV(Left(cD, 9), 10, 0) + LOJDV(Left(cD, 10), 11, 0) == Right(cD, 2)
    EndIf
    If Len(cD) == 14
        If cD == Replicate(Left(cD, 1), 14)
            Return .F.
        EndIf
        Return LOJDV(Left(cD, 12), 0, 9) + LOJDV(Left(cD, 13), 0, 9) == Right(cD, 2)
    EndIf
Return .F.

/*/{Protheus.doc} GEBLOJDIGITOS
    So' os digitos do texto.
    @type Funcao utilitaria
    @author Peder Munksgaard
    @since 19/10/2026
    @return cDigitos
/*/
User Function GEBLOJDIGITOS(cTxt)
Return LOJDigitos(cTxt)

Static Function LOJDigitos(cTxt)
    Local cD := ""
    Local nI := 0
    cTxt := BOCOL(cTxt)
    For nI := 1 To Len(cTxt)
        If SubStr(cTxt, nI, 1) >= "0" .And. SubStr(cTxt, nI, 1) <= "9"
            cD := cD + SubStr(cTxt, nI, 1)
        EndIf
    Next nI
Return cD

// Digito modulo 11. CPF: peso inicial nPeso (10 ou 11) descendo; CNPJ (nPeso 0): pesos 2..nMax da direita.
Static Function LOJDV(cBase, nPeso, nMax)
    Local nSoma := 0
    Local nP := 2
    Local nI := 0
    Local nR := 0
    If nPeso > 0
        For nI := 1 To Len(cBase)
            nSoma := nSoma + Val(SubStr(cBase, nI, 1)) * (nPeso - nI + 1)
        Next nI
    Else
        For nI := Len(cBase) To 1 Step -1
            nSoma := nSoma + Val(SubStr(cBase, nI, 1)) * nP
            nP := nP + 1
            If nP > nMax
                nP := 2
            EndIf
        Next nI
    EndIf
    nR := BOMOD(nSoma, 11)
    If nR < 2
        Return "0"
    EndIf
Return AllTrim(Str(11 - nR))

Static Function LOJBarra(cCodigo)
Return TCSqlQuery("SELECT GLJ8_PROD AS P, GLJ8_FATOR AS F FROM GLJ8 WHERE GLJ8_FILIAL = " + GEBDBQuote(FWxFilial("GLJ8")) + ;
    " AND GLJ8_COD = " + GEBDBQuote(cCodigo) + " AND D_E_L_E_T_ = ' '")
