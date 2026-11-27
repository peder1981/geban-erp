#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBCRY
    Pagamento em crypto na frente de loja. O proprietario cadastra a wallet
    de cada moeda aceita (GCK1); na venda o valor em BRL e' convertido pela
    cotacao CoinGecko (BRL) e o QR code e' montado no caixa (pdv.html).
    - GCK1 wallet: GCK1_MOEDA (BTC/ETH/XMR/USDC/USDT), GCK1_ENDERECO,
      GCK1_ATIVO.
    - GCK2 pagamento do cupom: moeda, endereco, BRL, quantidade crypto e a
      cotacao usada (auditoria; a segunda via mostra o detalhe).
    - Moedas: BTC bitcoin:, ETH ethereum:, XMR monero:, USDC/USDT ERC-20
      (ethereum:<contrato>/transfer?address=<wallet>&uint256=<qtd*1e6>).
    - Financeiro: o valor cai na conta GFN1 apontada por GE4 CRY_CONTA
      (o proprietario cadastra uma conta "CRIPTO" no financeiro).
    - Cotacao: CoinGecko simple/price, timeout GE4 CRY_TIMEOUT (15s).
      A venda em si busca a cotacao no servidor na hora do pagamento.
    @type Modulo pagamentos crypto
    @author Peder Munksgaard
    @since 26/11/2026
/*/

// Cria as tabelas crypto no tenant corrente (idempotente).
User Function GEBCRYMIG()
    Local lOk := BOTAB("GCK1", "GCK1_MOEDA TEXT NOT NULL, GCK1_ENDERECO TEXT NOT NULL, GCK1_ATIVO TEXT NOT NULL", "GCK1_MOEDA")
    lOk := lOk .And. BOTAB("GCK2", "GCK2_CUPOM TEXT NOT NULL, GCK2_MOEDA TEXT NOT NULL, GCK2_ENDERECO TEXT NOT NULL, " + ;
        "GCK2_BRL NUMERIC(18,2) NOT NULL, GCK2_QTD NUMERIC(18,8) NOT NULL, GCK2_COT NUMERIC(18,8) NOT NULL", "GCK2_CUPOM")
Return lOk

/*/{Protheus.doc} GEBCRYMOEDAS
    Lista fechada de moedas aceitas: {moeda, id CoinGecko, contrato ERC-20}.
    Contrato "" = nao e' token (BTC/ETH/XMR).
    @type Funcao utilitaria
    @author Peder Munksgaard
    @since 26/11/2026
/*/
User Function GEBCRYMOEDAS()
Return {{"BTC", "bitcoin", ""}, {"ETH", "ethereum", ""}, {"XMR", "monero", ""}, ;
    {"USDC", "usd-coin", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"}, ;
    {"USDT", "tether", "0xdAC17F958D2ee523a2206206994597C13D831ec7"}}

/*/{Protheus.doc} GEBCRYWAL
    Cadastra/altera a wallet de uma moeda. Endereco vazio desativa.
    @type Cadastro crypto
    @author Peder Munksgaard
    @since 26/11/2026
    @return {lOk, cMsg}
/*/
User Function GEBCRYWAL(cMoeda, cEndereco, cAtivo)
    Local cFil := FWxFilial("GCK1")
    cMoeda := Upper(BOCOL(cMoeda))
    cEndereco := BOCOL(cEndereco)
    If cMoeda == "" .Or. GEBCRYMOEDAPOS(cMoeda) == 0
        Return {.F., "moeda_invalida: BTC, ETH, XMR, USDC ou USDT"}
    EndIf
    If !(cAtivo == "N")
        cAtivo := "S"
    EndIf
    If cEndereco == ""
        cAtivo := "N"
    EndIf
    If !GEBCRYMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    TCSqlExec("UPDATE GCK1 SET D_E_L_E_T_ = '*' WHERE GCK1_FILIAL = " + GEBDBQuote(cFil) + " AND GCK1_MOEDA = " + GEBDBQuote(cMoeda) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GCK1 (D_E_L_E_T_, GCK1_FILIAL, GCK1_MOEDA, GCK1_ENDERECO, GCK1_ATIVO) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
        GEBDBQuote(cMoeda) + ", " + GEBDBQuote(cEndereco) + ", " + GEBDBQuote(cAtivo) + ")")
Return {.T., "wallet " + cMoeda + " gravada"}

/*/{Protheus.doc} GEBCRYWALLST
    Lista as wallets da filial (ativas primeiro).
    @type Consulta crypto
    @author Peder Munksgaard
    @since 26/11/2026
    @return {lOk, cMsg, aLinhas}
/*/
User Function GEBCRYWALLST()
    Local aHit := {}
    Local aLin := {{"moeda", "endereco", "ativo"}}
    Local nI := 0
    If !GEBCRYMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GCK1_MOEDA AS M, GCK1_ENDERECO AS E, GCK1_ATIVO AS A FROM GCK1 WHERE GCK1_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GCK1")) + " AND D_E_L_E_T_ = ' ' ORDER BY GCK1_MOEDA")
    For nI := 1 To Len(aHit)
        aAdd(aLin, {BOCOL(aHit[nI]:M), BOCOL(aHit[nI]:E), BOCOL(aHit[nI]:A)})
    Next nI
    BOREL(aLin)
Return {.T., "wallets_crypto", aLin}

/*/{Protheus.doc} GEBCRYCOT
    Cotacao BRL das moedas informadas (ou das que tem wallet ativa) via
    CoinGecko. Devolve {{moeda, brl}...}; {} se a API falhar ou nao houver
    rede.
    @type Consulta crypto
    @author Peder Munksgaard
    @since 26/11/2026
/*/
User Function GEBCRYCOT(cMoedas)
    Local aMoedas := GEBCRYMOEDAS()
    Local aIds := {}
    Local aMap := {}
    Local cUrl := ""
    Local cResp := Nil
    Local oJ := Nil
    Local xErr := Nil
    Local oSub := Nil
    Local aRet := {}
    Local nI := 0
    Local cM := ""
    Local lQuero := .F.
    Local xV := Nil
    Local nTmo := Int(BOVAL(BOPARM("CRY_TIMEOUT", "15")))
    Local aHead := {"Accept: application/json"}

    If !GEBCRYMIG()
        Return {}
    EndIf
    // Quais moedas consultar: as pedidas ou as com wallet ativa.
    For nI := 1 To Len(aMoedas)
        cM := aMoedas[nI][1]
        lQuero := .F.
        If !(cMoedas == Nil) .And. !(cMoedas == "")
            lQuero := ("," + cM + ",") $ ("," + Upper(cValToChar(cMoedas)) + ",")
        Else
            lQuero := Len(TCSqlQuery("SELECT GCK1_MOEDA FROM GCK1 WHERE GCK1_FILIAL = " + GEBDBQuote(FWxFilial("GCK1")) + ;
                " AND GCK1_MOEDA = " + GEBDBQuote(cM) + " AND GCK1_ATIVO = 'S' AND D_E_L_E_T_ = ' '")) > 0
        EndIf
        If lQuero
            aAdd(aIds, aMoedas[nI][2])
            aAdd(aMap, cM)
        EndIf
    Next nI
    If Len(aIds) == 0
        Return {}
    EndIf
    For nI := 1 To Len(aIds)
        cUrl := cUrl + Iif(nI > 1, ",", "") + aIds[nI]
    Next nI
    cResp := HttpQuote("https://api.coingecko.com/api/v3/simple/price?ids=" + cUrl + "&vs_currencies=brl", "GET", "", "", nTmo, aHead)
    If cResp == Nil .Or. BOCOL(cResp) == ""
        Return {}
    EndIf
    oJ := JsonObject():New()
    xErr := oJ:FromJson(BOSTR(cResp))
    If ValType(xErr) == "C"
        Return {}
    EndIf
    For nI := 1 To Len(aMap)
        oSub := oJ[aIds[nI]]
        If ValType(oSub) $ "OJ"
            xV := oSub["brl"]
            If xV == Nil
                xV := oSub["BRL"]
            EndIf
            If !(xV == Nil)
                aAdd(aRet, {aMap[nI], BOVAL(xV)})
            EndIf
        EndIf
    Next nI
Return aRet

/*/{Protheus.doc} GEBCRYQRCODE
    Monta o pagamento crypto: wallet ativa da moeda + cotacao BRL do valor.
    Devolve {lOk, cMsg, {cUri, cEndereco, nQtd, nCot}}.
    @type Operacao crypto
    @author Peder Munksgaard
    @since 26/11/2026
/*/
User Function GEBCRYQRCODE(cMoeda, nBRL)
    Local aWal := {}
    Local aCot := {}
    Local nCot := 0
    Local nQtd := 0
    Local cUri := ""
    Local cContrato := ""
    Local nDec := 0
    cMoeda := Upper(BOCOL(cMoeda))
    nBRL := Round(BOVAL(nBRL), 2)
    If GEBCRYMOEDAPOS(cMoeda) == 0
        Return {.F., "moeda_invalida: BTC, ETH, XMR, USDC ou USDT", {}}
    EndIf
    If nBRL <= 0
        Return {.F., "valor_invalido", {}}
    EndIf
    If !GEBCRYMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aWal := TCSqlQuery("SELECT GCK1_ENDERECO AS E FROM GCK1 WHERE GCK1_FILIAL = " + GEBDBQuote(FWxFilial("GCK1")) + ;
        " AND GCK1_MOEDA = " + GEBDBQuote(cMoeda) + " AND GCK1_ATIVO = 'S' AND D_E_L_E_T_ = ' '")
    If Len(aWal) == 0
        Return {.F., "wallet_nao_cadastrada: " + cMoeda, {}}
    EndIf
    aCot := GEBCRYCOT(cMoeda)
    If Len(aCot) == 0
        Return {.F., "cotacao_indisponivel: tente de novo em instantes", {}}
    EndIf
    nCot := BOVAL(aCot[1][2])
    If nCot <= 0
        Return {.F., "cotacao_invalida", {}}
    EndIf
    nQtd := Round(nBRL / nCot, 8)
    If nQtd <= 0
        Return {.F., "valor_muito_pequeno_para_a_moeda", {}}
    EndIf
    cContrato := BOCOL(GEBCRYMOEDAS()[GEBCRYMOEDAPOS(cMoeda)][3])
    If cContrato == ""
        If cMoeda == "BTC"
            cUri := "bitcoin:" + BOCOL(aWal[1]:E) + "?amount=" + cValToChar(nQtd)
        ElseIf cMoeda == "ETH"
            cUri := "ethereum:" + BOCOL(aWal[1]:E) + "?value=" + cValToChar(nQtd)
        Else
            cUri := "monero:" + BOCOL(aWal[1]:E) + "?tx_amount=" + cValToChar(nQtd)
        EndIf
    Else
        // ERC-20 (USDC/USDT): EIP-681 transfer?address=&uint256= (6 decimais).
        nDec := 1000000
        cUri := "ethereum:" + cContrato + "/transfer?address=" + BOCOL(aWal[1]:E) + "&uint256=" + BONUM(nQtd * nDec, 0)
    EndIf
Return {.T., "pagamento " + cMoeda, {cUri, BOCOL(aWal[1]:E), nQtd, nCot}}

/*/{Protheus.doc} GEBCRYPAGA
    Grava o pagamento crypto do cupom em GCK2 (auditoria/segunda via).
    @type Operacao crypto
    @author Peder Munksgaard
    @since 26/11/2026
/*/
User Function GEBCRYPAGA(cCupom, cMoeda, cEndereco, nBRL, nQtd, nCot)
    If !GEBCRYMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    TCSqlExec("INSERT INTO GCK2 (D_E_L_E_T_, GCK2_FILIAL, GCK2_CUPOM, GCK2_MOEDA, GCK2_ENDERECO, GCK2_BRL, GCK2_QTD, GCK2_COT) VALUES (' ', " + ;
        GEBDBQuote(FWxFilial("GCK2")) + ", " + GEBDBQuote(Upper(BOCOL(cCupom))) + ", " + GEBDBQuote(Upper(BOCOL(cMoeda))) + ", " + ;
        GEBDBQuote(BOCOL(cEndereco)) + ", " + BONUM(BOVAL(nBRL), 2) + ", " + BONUM(BOVAL(nQtd), 8) + ", " + BONUM(BOVAL(nCot), 8) + ")")
Return {.T., "pago " + Upper(BOCOL(cMoeda)) + " registrado"}

/*/{Protheus.doc} GEBCRYPAGOS
    Pagamentos crypto de um cupom (para a segunda via).
    @type Consulta crypto
    @author Peder Munksgaard
    @since 26/11/2026
    @return {lOk, cMsg, aLinhas}
/*/
User Function GEBCRYPAGOS(cCupom)
    Local aHit := {}
    Local aLin := {{"moeda", "endereco", "brl", "quantidade", "cotacao"}}
    Local nI := 0
    cCupom := Upper(BOCOL(cCupom))
    If !GEBCRYMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GCK2_MOEDA AS M, GCK2_ENDERECO AS E, GCK2_BRL AS B, GCK2_QTD AS Q, GCK2_COT AS C FROM GCK2 " + ;
        "WHERE GCK2_FILIAL = " + GEBDBQuote(FWxFilial("GCK2")) + " AND GCK2_CUPOM = " + GEBDBQuote(cCupom) + " AND D_E_L_E_T_ = ' '")
    For nI := 1 To Len(aHit)
        aAdd(aLin, {BOCOL(aHit[nI]:M), BOCOL(aHit[nI]:E), BOVAL(aHit[nI]:B), BOVAL(aHit[nI]:Q), BOVAL(aHit[nI]:C)})
    Next nI
    BOREL(aLin)
Return {.T., "pagamentos_" + cCupom, aLin}

// Posicao da moeda na lista fechada (0 = invalida).
Static Function GEBCRYMOEDAPOS(cMoeda)
    Local aM := GEBCRYMOEDAS()
    Local nI := 0
    For nI := 1 To Len(aM)
        If aM[nI][1] == cMoeda
            Return nI
        EndIf
    Next nI
Return 0
