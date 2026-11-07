#include "totvs.ch"
#include "GEBBOLIB.prw"

/*/{Protheus.doc} GEBTEF
    TEF (transferencia eletronica de fundos) da frente de loja: autorizacao
    de cartao com confirmacao em duas fases, como no TEF do Protheus
    (LOJA1906/SiTef): autorizar -> gravar a venda -> confirmar; se a venda
    falhar, desfazer; cancelamento do cupom = cancelar (estorno) na
    adquirente. Transacoes que ficaram pendentes (queda no meio da venda)
    sao desfeitas na abertura do caixa (GEBTEFRESOLVE).
    Provedor em GE4 LOJ_TEF_PROVEDOR:
    - SIMULADOR (padrao): aprova tudo, menos valor com centavos 51 (nega
      "saldo insuficiente") -- para homologacao e testes.
    - HTTP: POST JSON em GE4 LOJ_TEF_URL + /autorizar | /confirmar |
      /desfazer | /cancelar, com "Authorization: Bearer " + GE4 LOJ_TEF_TOKEN
      e tempo limite GE4 LOJ_TEF_TIMEOUT (s, padrao 30). Corpo enviado:
      {operacao, id, forma, valor, parcelas, referencia, nsu}; resposta
      esperada: {aprovada, nsu, autorizacao, bandeira, mensagem}. Para uma
      adquirente especifica (SiTef, PayGo, Stone...), um adaptador dela
      traduz esse contrato.
    - CIELO: API e-Commerce 3.0 da Cielo (sandbox gratuita, ou o emulador
      local tests/emuladores/cielo_emulador.py). Autorizar = POST /1/sales
      com Capture false (pre-autorizacao); confirmar = PUT /1/sales/{id}/capture;
      desfazer = PUT /1/sales/{id}/void; cancelar = PUT /1/sales/{id}/void?amount=.
      GE4: LOJ_CIELO_URL (padrao https://apisandbox.cieloecommerce.cielo.com.br),
      LOJ_CIELO_MERCHANTID, LOJ_CIELO_MERCHANTKEY, LOJ_CIELO_CARTAO (cartao de
      teste; o ultimo digito decide o resultado na sandbox: 0/1/4 aprova, 2
      nega, 3 expirado, 5 bloqueado...) e LOJ_CIELO_BANDEIRA (padrao Visa).
      A frente de loja nao le o cartao (nao ha pinpad): o cartao de teste
      vale para homologar o fluxo. Debito vai como credito a vista (a API de
      e-commerce exige autenticacao 3DS no debito).
    Usa HttpPost porque o runtime AdvPP nao tem FWRest.
    GLJ7 guarda cada transacao (PENDENTE, CONFIRMADA, DESFEITA, CANCELADA,
    NEGADA).
    @type Modulo frente de loja
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBTEFMIG()
Return BOMIG() .And. BOTAB("GLJ7", "GLJ7_ID TEXT NOT NULL, GLJ7_REF TEXT NOT NULL, GLJ7_FORMA TEXT NOT NULL, GLJ7_VALOR NUMERIC(18,2) NOT NULL, " + ;
    "GLJ7_PARC INTEGER NOT NULL, GLJ7_NSU TEXT NOT NULL, GLJ7_AUT TEXT NOT NULL, GLJ7_BAND TEXT NOT NULL, GLJ7_STATUS TEXT NOT NULL, " + ;
    "GLJ7_PROV TEXT NOT NULL, GLJ7_MSG TEXT NOT NULL, GLJ7_DATA TEXT NOT NULL, GLJ7_HORA TEXT NOT NULL, GLJ7_EXTID TEXT NOT NULL", "GLJ7_ID")

/*/{Protheus.doc} GEBTEFCFG
    Configura o TEF da empresa (GE4): provedor SIMULADOR, HTTP ou CIELO e os
    dados do provedor. Campos vazios mantem o valor atual. A chave do
    lojista (MerchantKey/token) nunca e' devolvida.
    @type Cadastro TEF
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBTEFCFG(cProv, cUrl, cMerchantId, cChave, cCartao, cBandeira)
    cProv := Upper(BOCOL(cProv))
    If !(cProv == "") .And. AScan({"SIMULADOR", "HTTP", "CIELO"}, cProv) == 0
        Return {.F., "provedor_invalido: SIMULADOR, HTTP ou CIELO"}
    EndIf
    If !(cProv == "")
        BOSETPARM("LOJ_TEF_PROVEDOR", cProv)
    Else
        cProv := Upper(BOPARM("LOJ_TEF_PROVEDOR", "SIMULADOR"))
    EndIf
    If !(BOCOL(cUrl) == "")
        If cProv == "HTTP"
            BOSETPARM("LOJ_TEF_URL", BOCOL(cUrl))
        Else
            BOSETPARM("LOJ_CIELO_URL", BOCOL(cUrl))
        EndIf
    EndIf
    If !(BOCOL(cMerchantId) == "")
        BOSETPARM("LOJ_CIELO_MERCHANTID", BOCOL(cMerchantId))
    EndIf
    If !(BOCOL(cChave) == "")
        If cProv == "HTTP"
            BOSETPARM("LOJ_TEF_TOKEN", BOCOL(cChave))
        Else
            BOSETPARM("LOJ_CIELO_MERCHANTKEY", BOCOL(cChave))
        EndIf
    EndIf
    If !(BOCOL(cCartao) == "")
        BOSETPARM("LOJ_CIELO_CARTAO", BOCOL(cCartao))
    EndIf
    If !(BOCOL(cBandeira) == "")
        BOSETPARM("LOJ_CIELO_BANDEIRA", BOCOL(cBandeira))
    EndIf
Return {.T., "TEF configurado: provedor " + cProv}

/*/{Protheus.doc} GEBTEFAUT
    Autoriza um pagamento em cartao (DEBITO/CREDITO). A transacao fica
    PENDENTE ate GEBTEFCONF ou GEBTEFDESF.
    @type Servico TEF
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {cId, cNSU, cAutorizacao, cBandeira}}
/*/
User Function GEBTEFAUT(cForma, nValor, nParc, cRef)
    Local cId := ""
    Local cProv := Upper(BOPARM("LOJ_TEF_PROVEDOR", "SIMULADOR"))
    Local aR := {}
    Local cSt := "PENDENTE"
    cForma := Upper(BOCOL(cForma))
    nValor := Round(BOVAL(nValor), 2)
    nParc := Int(BOVAL(nParc))
    If nParc <= 0
        nParc := 1
    EndIf
    If !(cForma == "DEBITO" .Or. cForma == "CREDITO") .Or. nValor <= 0
        Return {.F., "pagamento_tef_invalido", {}}
    EndIf
    If cForma == "DEBITO" .And. nParc > 1
        Return {.F., "debito_nao_parcela", {}}
    EndIf
    If !GEBTEFMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    cId := "T" + BOSEQ("TEF_ID", 9)
    aR := TEFChama(cProv, "autorizar", cId, cForma, nValor, nParc, BOCOL(cRef), "", "")
    If !aR[1]
        cSt := "NEGADA"
    EndIf
    TCSqlExec("INSERT INTO GLJ7 (D_E_L_E_T_, GLJ7_FILIAL, GLJ7_ID, GLJ7_REF, GLJ7_FORMA, GLJ7_VALOR, GLJ7_PARC, GLJ7_NSU, GLJ7_AUT, GLJ7_BAND, GLJ7_STATUS, " + ;
        "GLJ7_PROV, GLJ7_MSG, GLJ7_DATA, GLJ7_HORA, GLJ7_EXTID) VALUES (' ', " + GEBDBQuote(FWxFilial("GLJ7")) + ", " + GEBDBQuote(cId) + ", " + GEBDBQuote(BOCOL(cRef)) + ", " + ;
        GEBDBQuote(cForma) + ", " + BONUM(nValor, 2) + ", " + BONUM(nParc, 0) + ", " + GEBDBQuote(aR[3][1]) + ", " + GEBDBQuote(aR[3][2]) + ", " + ;
        GEBDBQuote(aR[3][3]) + ", " + GEBDBQuote(cSt) + ", " + GEBDBQuote(cProv) + ", " + GEBDBQuote(Left(aR[2], 120)) + ", " + GEBDBQuote(BOHOJE()) + ", " + ;
        GEBDBQuote(Time()) + ", " + GEBDBQuote(aR[3][4]) + ")")
    If !aR[1]
        Return {.F., "cartao_negado: " + aR[2], {cId, "", "", ""}}
    EndIf
Return {.T., "autorizado", {cId, aR[3][1], aR[3][2], aR[3][3]}}

/*/{Protheus.doc} GEBTEFCONF
    Confirma a transacao pendente (CONFIRMADA).
    @type Funcao auxiliar
    @author Peder Munksgaard
    @since 19/10/2026
    @param cId
/*/
User Function GEBTEFCONF(cId)
Return TEFFase(cId, "confirmar", "PENDENTE", "CONFIRMADA")

/*/{Protheus.doc} GEBTEFDESF
    Desfaz a transacao pendente (DESFEITA).
    @type Funcao auxiliar
    @author Peder Munksgaard
    @since 19/10/2026
    @param cId
/*/
User Function GEBTEFDESF(cId)
Return TEFFase(cId, "desfazer", "PENDENTE", "DESFEITA")

/*/{Protheus.doc} GEBTEFCANC
    Cancela/estorna a transacao confirmada (CANCELADA).
    @type Funcao auxiliar
    @author Peder Munksgaard
    @since 19/10/2026
    @param cId
/*/
User Function GEBTEFCANC(cId)
Return TEFFase(cId, "cancelar", "CONFIRMADA", "CANCELADA")

/*/{Protheus.doc} GEBTEFRESOLVE
    Desfaz as transacoes que ficaram PENDENTE (venda interrompida). Chamado
    na abertura do caixa.
    @type Servico TEF
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, nDesfeitas}
/*/
User Function GEBTEFRESOLVE()
    Local aHit := {}
    Local nOk := 0
    Local nI := 0
    If !GEBTEFMIG()
        Return {.F., "falha_tabelas", 0}
    EndIf
    aHit := TCSqlQuery("SELECT GLJ7_ID AS I FROM GLJ7 WHERE GLJ7_FILIAL = " + GEBDBQuote(FWxFilial("GLJ7")) + " AND GLJ7_STATUS = 'PENDENTE' AND D_E_L_E_T_ = ' '")
    For nI := 1 To Len(aHit)
        If GEBTEFDESF(BOCOL(aHit[nI]:I))[1]
            nOk := nOk + 1
        EndIf
    Next nI
Return {.T., BONUM(nOk, 0) + " transacao(oes) pendente(s) desfeita(s)", nOk}

/*/{Protheus.doc} GEBTEFREL
    Relatorio: transacoes TEF do dia (para conferir com a adquirente):
    cada transacao e os totais confirmados por forma e bandeira.
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {aLinhas (1a = cabecalho), aTotais}}
/*/
User Function GEBTEFREL(cData)
    Local aHit := {}
    Local aLin := {{"id", "referencia", "forma", "bandeira", "parcelas", "valor", "nsu", "status"}}
    Local aTot := {}
    Local nI := 0
    cData := BODATA(cData)
    If cData == ""
        Return {.F., "data_invalida", {}}
    EndIf
    If !GEBTEFMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GLJ7_ID AS I, GLJ7_REF AS R, GLJ7_FORMA AS F, GLJ7_BAND AS B, GLJ7_PARC AS P, GLJ7_VALOR AS V, GLJ7_NSU AS N, GLJ7_STATUS AS S " + ;
        "FROM GLJ7 WHERE GLJ7_FILIAL = " + GEBDBQuote(FWxFilial("GLJ7")) + " AND GLJ7_DATA = " + GEBDBQuote(cData) + " AND D_E_L_E_T_ = ' ' ORDER BY GLJ7_ID")
    For nI := 1 To Len(aHit)
        aAdd(aLin, {BOCOL(aHit[nI]:I), BOCOL(aHit[nI]:R), BOCOL(aHit[nI]:F), BOCOL(aHit[nI]:B), BOVAL(aHit[nI]:P), BOVAL(aHit[nI]:V), BOCOL(aHit[nI]:N), BOCOL(aHit[nI]:S)})
    Next nI
    aHit := TCSqlQuery("SELECT GLJ7_FORMA || ' ' || GLJ7_BAND AS K, SUM(GLJ7_VALOR) AS V FROM GLJ7 WHERE GLJ7_FILIAL = " + GEBDBQuote(FWxFilial("GLJ7")) + ;
        " AND GLJ7_DATA = " + GEBDBQuote(cData) + " AND GLJ7_STATUS = 'CONFIRMADA' AND D_E_L_E_T_ = ' ' GROUP BY 1 ORDER BY 1")
    For nI := 1 To Len(aHit)
        aAdd(aTot, {BOCOL(aHit[nI]:K), Round(BOVAL(aHit[nI]:V), 2)})
        aAdd(aLin, {"total", "", BOCOL(aHit[nI]:K), "", "", Round(BOVAL(aHit[nI]:V), 2), "", "CONFIRMADA"})
    Next nI
    BOREL(aLin)
Return {.T., "tef_do_dia", {aLin, aTot}}

/*/{Protheus.doc} GEBTEFRESP
    Interpreta a resposta JSON do gateway HTTP.
    @type Servico TEF
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {cNSU, cAutorizacao, cBandeira}}
/*/
User Function GEBTEFRESP(cJson)
    Local oResp := JsonObject():New()
    Local xErr := Nil
    Local lAprov := .F.
    If BOCOL(cJson) == ""
        Return {.F., "sem_resposta_do_gateway", {"", "", ""}}
    EndIf
    xErr := oResp:FromJson(BOSTR(cJson))
    If ValType(xErr) == "C"
        Return {.F., "resposta_invalida: " + xErr, {"", "", ""}}
    EndIf
    lAprov := ValType(oResp["aprovada"]) == "L" .And. oResp["aprovada"]
    If ValType(oResp["APROVADA"]) == "L"
        lAprov := oResp["APROVADA"]
    EndIf
    If !lAprov
        Return {.F., BOCOL(TEFCampo(oResp, "mensagem")), {"", "", ""}}
    EndIf
Return {.T., BOCOL(TEFCampo(oResp, "mensagem")), {BOCOL(TEFCampo(oResp, "nsu")), BOCOL(TEFCampo(oResp, "autorizacao")), BOCOL(TEFCampo(oResp, "bandeira"))}}

// Chamada ao provedor: {lOk, cMsg, {cNSU, cAut, cBandeira, cIdExterno}}.
Static Function TEFChama(cProv, cOper, cId, cForma, nValor, nParc, cRef, cNSU, cExt)
    Local oB := Nil
    Local cResp := ""
    Local cUrl := ""
    Local aHead := {}
    Local aR := {}
    Local nSeq := 0
    If cProv == "SIMULADOR"
        If cOper == "autorizar"
            If Round((nValor - Int(nValor)) * 100, 0) == 51
                Return {.F., "saldo insuficiente (simulador)", {"", "", "", ""}}
            EndIf
            nSeq := Val(Right(cId, 6))
            Return {.T., "aprovada (simulador)", {StrZero(nSeq, 9), StrZero(BOMOD(nSeq * 7919, 999999), 6), "SIMULADA", ""}}
        EndIf
        Return {.T., cOper + " ok (simulador)", {cNSU, "", "", cExt}}
    EndIf
    If cProv == "CIELO"
        Return TEFCielo(cOper, cId, nValor, nParc, cRef, cExt)
    EndIf
    If !(cProv == "HTTP")
        Return {.F., "provedor_tef_desconhecido: " + cProv, {"", "", "", ""}}
    EndIf
    cUrl := BOPARM("LOJ_TEF_URL", "")
    If cUrl == ""
        Return {.F., "configure GE4 LOJ_TEF_URL", {"", "", "", ""}}
    EndIf
    oB := JsonObject():New()
    oB["operacao"] := cOper
    oB["id"] := cId
    oB["forma"] := cForma
    oB["valor"] := nValor
    oB["parcelas"] := nParc
    oB["referencia"] := cRef
    oB["nsu"] := cNSU
    aHead := {"Content-Type: application/json", "Authorization: Bearer " + BOPARM("LOJ_TEF_TOKEN", "")}
    cResp := HttpPost(cUrl + "/" + cOper, "", oB:ToJson(), Int(BOVAL(BOPARM("LOJ_TEF_TIMEOUT", "30"))), aHead)
    If cResp == Nil
        Return {.F., "gateway_tef_sem_resposta", {"", "", "", ""}}
    EndIf
    aR := GEBTEFRESP(cResp)
Return {aR[1], aR[2], {aR[3][1], aR[3][2], aR[3][3], ""}}

// Provedor CIELO (API e-Commerce 3.0). HttpQuote porque captura e void sao PUT.
Static Function TEFCielo(cOper, cId, nValor, nParc, cRef, cExt)
    Local cUrl := BOPARM("LOJ_CIELO_URL", "https://apisandbox.cieloecommerce.cielo.com.br")
    Local cMid := BOPARM("LOJ_CIELO_MERCHANTID", "")
    Local cKey := BOPARM("LOJ_CIELO_MERCHANTKEY", "")
    Local nTmo := Int(BOVAL(BOPARM("LOJ_TEF_TIMEOUT", "30")))
    Local aHead := {}
    Local cBody := ""
    Local cResp := Nil
    Local cCents := BONUM(Round(nValor * 100, 0), 0)
    If cMid == "" .Or. cKey == ""
        Return {.F., "configure GE4 LOJ_CIELO_MERCHANTID e LOJ_CIELO_MERCHANTKEY", {"", "", "", ""}}
    EndIf
    aHead := {"Content-Type: application/json", "MerchantId: " + cMid, "MerchantKey: " + cKey, "RequestId: " + cId}
    If cOper == "autorizar"
        // Texto montado a mao: no AdvPP 4.4.5, ToJson nao serializa JsonObject aninhado.
        cBody := '{"MerchantOrderId":"' + TEFJs(cId) + '","Payment":{"Type":"CreditCard","Amount":' + cCents + ;
            ',"Installments":' + BONUM(nParc, 0) + ',"Capture":false,"SoftDescriptor":"GEBAN","CreditCard":{"CardNumber":"' + ;
            TEFJs(BOPARM("LOJ_CIELO_CARTAO", "4024007153763191")) + '","Holder":"GEBAN TEF","ExpirationDate":"12/2035","SecurityCode":"123",' + ;
            '"Brand":"' + TEFJs(BOPARM("LOJ_CIELO_BANDEIRA", "Visa")) + '"}}}'
        cResp := HttpQuote(cUrl + "/1/sales", "POST", "", cBody, nTmo, aHead)
    ElseIf cOper == "confirmar"
        cResp := HttpQuote(cUrl + "/1/sales/" + cExt + "/capture", "PUT", "", "", nTmo, aHead)
    ElseIf cOper == "desfazer"
        cResp := HttpQuote(cUrl + "/1/sales/" + cExt + "/void", "PUT", "", "", nTmo, aHead)
    Else
        cResp := HttpQuote(cUrl + "/1/sales/" + cExt + "/void?amount=" + cCents, "PUT", "", "", nTmo, aHead)
    EndIf
    If cResp == Nil
        Return {.F., "cielo_sem_resposta", {"", "", "", ""}}
    EndIf
Return GEBTEFCIELO(cOper, cResp, cExt)

/*/{Protheus.doc} GEBTEFCIELO
    Interpreta a resposta da Cielo (API e-Commerce 3.0) para a operacao:
    autorizar = Payment.Status 1; confirmar = 2; desfazer/cancelar = 10 ou
    11. Erro da API vem como lista [{Code, Message}].
    @type Servico TEF
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {cNSU, cAutorizacao, cBandeira, cPaymentId}}
/*/
User Function GEBTEFCIELO(cOper, cJson, cExt)
    Local oRes := JsonObject():New()
    Local xErr := Nil
    Local oP := Nil
    Local aErr := {}
    Local nSt := 0
    Local aOk := {}
    cJson := BOSTR(cJson)
    If BOCOL(cJson) == ""
        Return {.F., "cielo_sem_resposta", {"", "", "", ""}}
    EndIf
    If Left(AllTrim(cJson), 1) == "["
        // Lista de erros da API: [{"Code": 308, "Message": "..."}].
        oRes := JsonObject():New()
        xErr := oRes:FromJson('{"e":' + cJson + '}')
        aErr := oRes["e"]
        If ValType(aErr) == "A" .And. Len(aErr) > 0
            Return {.F., "cielo " + BOCOL(TEFCampo(aErr[1], "Code")) + ": " + BOCOL(TEFCampo(aErr[1], "Message")), {"", "", "", cExt}}
        EndIf
        Return {.F., "cielo_erro", {"", "", "", cExt}}
    EndIf
    xErr := oRes:FromJson(cJson)
    If ValType(xErr) == "C"
        Return {.F., "resposta_invalida: " + xErr, {"", "", "", ""}}
    EndIf
    oP := oRes["Payment"]
    If oP == Nil
        oP := oRes
    EndIf
    nSt := BOVAL(TEFCampo(oP, "Status"))
    If cOper == "autorizar"
        aOk := {1}
    ElseIf cOper == "confirmar"
        aOk := {2}
    Else
        aOk := {10, 11}
    EndIf
    If AScan(aOk, nSt) == 0
        Return {.F., BOCOL(TEFCampo(oP, "ReturnCode")) + " " + BOCOL(TEFCampo(oP, "ReturnMessage")), {"", "", "", cExt}}
    EndIf
    If !(BOCOL(TEFCampo(oP, "PaymentId")) == "")
        cExt := BOCOL(TEFCampo(oP, "PaymentId"))
    EndIf
Return {.T., BOCOL(TEFCampo(oP, "ReturnMessage")), {BOCOL(TEFCampo(oP, "ProofOfSale")), BOCOL(TEFCampo(oP, "AuthorizationCode")), ;
    BOCOL(TEFCampo(TEFCampo(oP, "CreditCard"), "Brand")), BOCOL(cExt)}}

Static Function TEFFase(cId, cOper, cDe, cPara)
    Local aHit := {}
    Local aR := {}
    cId := BOCOL(cId)
    If !GEBTEFMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    aHit := TCSqlQuery("SELECT GLJ7_STATUS AS S, GLJ7_PROV AS P, GLJ7_FORMA AS F, GLJ7_VALOR AS V, GLJ7_PARC AS PA, GLJ7_REF AS R, GLJ7_NSU AS N, GLJ7_EXTID AS X FROM GLJ7 " + ;
        "WHERE GLJ7_FILIAL = " + GEBDBQuote(FWxFilial("GLJ7")) + " AND GLJ7_ID = " + GEBDBQuote(cId) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {.F., "transacao_inexistente: " + cId}
    EndIf
    If !(BOCOL(aHit[1]:S) == cDe)
        Return {.F., "transacao_" + Lower(BOCOL(aHit[1]:S)) + ": nao da para " + cOper}
    EndIf
    aR := TEFChama(BOCOL(aHit[1]:P), cOper, cId, BOCOL(aHit[1]:F), BOVAL(aHit[1]:V), BOVAL(aHit[1]:PA), BOCOL(aHit[1]:R), BOCOL(aHit[1]:N), BOCOL(aHit[1]:X))
    If !aR[1]
        Return {.F., "adquirente_recusou_" + cOper + ": " + aR[2]}
    EndIf
    TCSqlExec("UPDATE GLJ7 SET GLJ7_STATUS = " + GEBDBQuote(cPara) + " WHERE GLJ7_FILIAL = " + GEBDBQuote(FWxFilial("GLJ7")) + " AND GLJ7_ID = " + ;
        GEBDBQuote(cId) + " AND D_E_L_E_T_ = ' '")
Return {.T., Lower(cPara)}

// Texto seguro dentro de uma string JSON.
Static Function TEFJs(cTxt)
Return StrTran(StrTran(BOSTR(cTxt), "\", ""), '"', "")

Static Function TEFCampo(oResp, cNome)
    If oResp == Nil .Or. !(ValType(oResp) == "O")
        Return ""
    EndIf
    If !(oResp[cNome] == Nil)
        Return oResp[cNome]
    EndIf
Return oResp[Upper(cNome)]
