#include "totvs.ch"

/*/{Protheus.doc} GEBDER_FIN
    Derrama <-> financeiro: toda guia de tributo (IBS/CBS, DAS, ICMS/ISS fora
    do DAS, retencoes) nasce aqui, com o titulo a pagar de mesmo numero no
    financeiro (GFN3 + GFX2, origem "DERRAMA <tipo>"). O titulo e' pago pela
    Derrama (GEBDERPAGA) ou por qualquer baixa do financeiro; a baixa do
    ultimo titulo baixa a guia (GEBFXBAI). GD4 guarda tipo, competencia,
    vencimento, conta contabil e credor da guia.
    @type Fonte
    @author Peder Munksgaard
    @since 19/10/2026
/*/

/*/{Protheus.doc} GEBDERFMIG
    Garante as tabelas da Derrama, do financeiro e o complemento GD4.
    @type Migracao
    @author Peder Munksgaard
    @since 19/10/2026
    @return .T. se tudo existe
/*/
User Function GEBDERFMIG()
    If !GEBDMIG() .Or. !GEBFXMIG()
        Return .F.
    EndIf
Return BOTAB("GD4", "GD4_GUIA TEXT NOT NULL, GD4_TIPO TEXT NOT NULL, GD4_COMP TEXT NOT NULL, GD4_VENC TEXT NOT NULL, " + ;
    "GD4_CTACTB TEXT NOT NULL, GD4_CREDOR TEXT NOT NULL", "GD4_GUIA")

/*/{Protheus.doc} GEBDERGUIA
    Cria ou atualiza a guia da Derrama e o titulo a pagar. Sem baixa, valor e
    vencimento acompanham a reapuracao (valor zero cancela). Com baixa, a
    diferenca positiva vira guia complementar <guia>-C<n>.
    @type Servico Derrama
    @author Peder Munksgaard
    @since 19/10/2026
    @param cGuia Numero da guia (= documento do titulo)
    @param cTipo IBSCBS, DAS, ICMS, ISS ou RET_<tributo>
    @param cComp Competencia AAAAMM
    @param nValor Valor da guia
    @param cVenc Vencimento AAAAMMDD
    @param cCtaCtb Conta contabil da obrigacao (contrapartida na baixa)
    @param cCredor Credor do titulo (padrao FISCO)
    @return {lOk, cMsg, cGuiaGravada}
/*/
User Function GEBDERGUIA(cGuia, cTipo, cComp, nValor, cVenc, cCtaCtb, cCredor)
    Local aG := {}
    Local aT := {}
    Local aR := {}
    Local cCompl := ""
    Local nDif := 0

    cGuia := BOCOL(cGuia)
    cTipo := Upper(BOCOL(cTipo))
    cComp := BOCOL(cComp)
    cVenc := BODATA(cVenc)
    cCtaCtb := BOCOL(cCtaCtb)
    cCredor := BOCOL(cCredor)
    nValor := Round(BOVAL(nValor), 2)
    If cCredor == ""
        cCredor := "FISCO"
    EndIf
    If cGuia == "" .Or. cTipo == "" .Or. cVenc == "" .Or. cCtaCtb == ""
        Return {.F., "parametros_invalidos: guia, tipo, vencimento e conta", ""}
    EndIf
    If !GEBDERFMIG()
        Return {.F., "falha_tabelas", ""}
    EndIf
    aG := DERGuia(cGuia)
    aT := GEBDERTITS(cGuia)
    If Len(aG) == 0
        If nValor <= 0
            Return {.T., "sem_valor", ""}
        EndIf
        TCSqlExec("INSERT INTO GD1 (D_E_L_E_T_, GD1_FILIAL, GD1_GUIA, GD1_COMP, GD1_VALOR, GD1_JUROS, GD1_MULTA, GD1_TOTAL, GD1_STATUS) VALUES (' ', " + ;
            GEBDBQuote(FWxFilial("GD1")) + ", " + GEBDBQuote(cGuia) + ", " + GEBDBQuote(cComp) + ", " + BONUM(nValor, 2) + ", 0, 0, " + ;
            BONUM(nValor, 2) + ", 'ABERTA')")
        DERGrvGD4(cGuia, cTipo, cComp, cVenc, cCtaCtb, cCredor)
        aR := DERCriaTit(cGuia, cTipo, nValor, cVenc, cCtaCtb, cCredor)
        If !aR[1]
            Return {.F., aR[2], ""}
        EndIf
        Return {.T., "guia " + cGuia + " gerada", cGuia}
    EndIf
    If aG[1] == "BAIXADA" .Or. DERTemBaixa(aT)
        nDif := Round(nValor - aG[2] - DERCompl(cGuia, .F.), 2)
        If nDif > 0
            cCompl := cGuia + "-C" + cValToChar(DERCompl(cGuia, .T.) + 1)
            aR := GEBDERGUIA(cCompl, cTipo, cComp, nDif, cVenc, cCtaCtb, cCredor)
            Return {aR[1], "guia " + cGuia + " ja tem pagamento; guia complementar " + cCompl + " de " + BONUM(nDif, 2), cCompl}
        EndIf
        If nDif < 0
            Return {.T., "guia " + cGuia + " ja tem pagamento; valor menor em " + BONUM(-nDif, 2) + " (pedir restituicao)", cGuia}
        EndIf
        Return {.T., "guia " + cGuia + " sem alteracao", cGuia}
    EndIf
    If aG[1] == "PARCELADA"
        If nValor == aG[2]
            Return {.T., "guia " + cGuia + " sem alteracao", cGuia}
        EndIf
        Return {.F., "guia_parcelada: refaca o parcelamento para mudar o valor de " + cGuia, cGuia}
    EndIf
    If nValor <= 0
        TCSqlExec("UPDATE GD1 SET GD1_STATUS = 'CANCELADA'" + DERWhere("GD1", cGuia))
        DERApagaTit(cGuia)
        Return {.T., "guia " + cGuia + " cancelada", cGuia}
    EndIf
    TCSqlExec("UPDATE GD1 SET GD1_VALOR = " + BONUM(nValor, 2) + ", GD1_JUROS = 0, GD1_MULTA = 0, GD1_TOTAL = " + BONUM(nValor, 2) + ;
        ", GD1_COMP = " + GEBDBQuote(cComp) + DERWhere("GD1", cGuia))
    TCSqlExec("UPDATE GD1 SET GD1_STATUS = 'ABERTA'" + DERWhere("GD1", cGuia) + " AND GD1_STATUS = 'CANCELADA'")
    DERGrvGD4(cGuia, cTipo, cComp, cVenc, cCtaCtb, cCredor)
    If Len(aT) == 0
        aR := DERCriaTit(cGuia, cTipo, nValor, cVenc, cCtaCtb, cCredor)
        If !aR[1]
            Return {.F., aR[2], cGuia}
        EndIf
    Else
        TCSqlExec("UPDATE GFN3 SET GFN3_VALOR = " + BONUM(nValor, 2) + ", GFN3_SALDO = " + BONUM(nValor, 2) + ", GFN3_VENC = " + GEBDBQuote(cVenc) + ;
            DERWhere("GFN3", cGuia, "DOC"))
        TCSqlExec("UPDATE GFX2 SET GFX2_VLORIG = " + BONUM(nValor, 2) + DERWhere("GFX2", cGuia, "DOC") + " AND GFX2_TIPO = 'P'")
    EndIf
Return {.T., "guia " + cGuia + " atualizada", cGuia}

/*/{Protheus.doc} GEBDERPAGA
    Paga a guia pela Derrama: baixa no financeiro todos os titulos abertos
    da guia (o dinheiro sai da conta). Juros e multa: os gravados por
    GEBDJUR (guia sem parcelas) ou a regra da Derrama pelo atraso.
    @type Servico Derrama
    @author Peder Munksgaard
    @since 19/10/2026
    @param cConta Conta financeira (vazio = DER_CONTA, padrao CAIXA)
    @param cData Data do pagamento (vazio = hoje)
    @return {lOk, cMsg, nTotalPago}
/*/
User Function GEBDERPAGA(cGuia, cConta, cData)
    Local aG := {}
    Local aT := {}
    Local aR := {}
    Local aC := {}
    Local nTot := 0
    Local nI := 0

    cGuia := BOCOL(cGuia)
    cConta := BOCOL(cConta)
    cData := BOCOL(cData)
    If cConta == ""
        cConta := BOPARM("DER_CONTA", "CAIXA")
    EndIf
    If cData == ""
        cData := BOHOJE()
    EndIf
    If !GEBDERFMIG()
        Return {.F., "falha_tabelas", 0}
    EndIf
    aG := DERGuia(cGuia)
    If Len(aG) == 0
        Return {.F., "guia_inexistente: " + cGuia, 0}
    EndIf
    If aG[1] == "BAIXADA"
        // Idempotente: guia ja paga nao paga de novo.
        Return {.T., "guia " + cGuia + " ja estava baixada", 0}
    EndIf
    If aG[1] == "CANCELADA"
        Return {.F., "guia_cancelada: " + cGuia, 0}
    EndIf
    aT := GEBDERTITS(cGuia)
    If Len(aT) == 0 .And. !(aG[1] == "PARCELADA")
        // Guia anterior a integracao: o titulo nasce agora pelo valor da guia.
        aC := DERCfg(cGuia)
        aR := DERCriaTit(cGuia, aC[1], aG[2], cData, aC[2], aC[3])
        If !aR[1]
            Return {.F., aR[2], 0}
        EndIf
        aT := GEBDERTITS(cGuia)
    EndIf
    If Len(aT) == 0
        Return {.F., "guia_sem_titulos: " + cGuia, 0}
    EndIf
    GEBFNCON(cConta, cConta)
    For nI := 1 To Len(aT)
        If aT[nI][4] == "ABERTO"
            If Len(aT) == 1 .And. aG[3] + aG[4] > 0
                aR := GEBFXBAI("P", aT[nI][1], aT[nI][3], aG[3], aG[4], 0, cConta, cData)
            Else
                aR := GEBFXBAI("P", aT[nI][1], aT[nI][3], Nil, Nil, 0, cConta, cData)
            EndIf
            If !aR[1]
                Return {.F., aR[2], nTot}
            EndIf
            nTot := nTot + aR[3][2]
        EndIf
    Next nI
Return {.T., "guia " + cGuia + " paga: " + BONUM(nTot, 2), Round(nTot, 2)}

/*/{Protheus.doc} GEBDERPODEPAR
    A guia pode ser parcelada? Nao se ja tem pagamento ou esta baixada.
    @type Servico Derrama
    @author Peder Munksgaard
    @since 19/10/2026
    @return .T. se pode
/*/
User Function GEBDERPODEPAR(cGuia)
    Local aG := {}
    If !GEBDERFMIG()
        Return .F.
    EndIf
    aG := DERGuia(BOCOL(cGuia))
    If Len(aG) == 0 .Or. aG[1] == "BAIXADA" .Or. aG[1] == "CANCELADA"
        Return .F.
    EndIf
Return !DERTemBaixa(GEBDERTITS(BOCOL(cGuia)))

/*/{Protheus.doc} GEBDERPARTIT
    Troca os titulos abertos da guia por um titulo por parcela (30 em 30
    dias). Juros e multa ja somados ao total da guia viram despesa e
    obrigacao.
    @type Servico Derrama
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, aTitulos}
/*/
User Function GEBDERPARTIT(cGuia, nParc, nTot)
    Local aG := {}
    Local aC := {}
    Local aR := {}
    Local cCond := ""
    Local nI := 0

    cGuia := BOCOL(cGuia)
    nTot := Round(BOVAL(nTot), 2)
    If !GEBDERFMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aG := DERGuia(cGuia)
    If Len(aG) == 0
        Return {.F., "guia_inexistente: " + cGuia, {}}
    EndIf
    aC := DERCfg(cGuia)
    DERApagaTit(cGuia)
    For nI := 1 To nParc
        If nI > 1
            cCond := cCond + ","
        EndIf
        cCond := cCond + cValToChar(30 * nI)
    Next nI
    aR := GEBFXTIT("P", cGuia, aC[3], nTot, cCond, BOHOJE(), "DERRAMA " + aC[1], aC[2])
    If !aR[1]
        Return aR
    EndIf
    GEBDERPROV("FIN_JUROS_PAG", cGuia, nTot - aG[2], BOHOJE(), "", aC[2])
Return aR

/*/{Protheus.doc} GEBDERTITS
    Titulos a pagar de uma guia (o da guia ou os das parcelas).
    @type Consulta Derrama
    @author Peder Munksgaard
    @since 19/10/2026
    @return {{cDoc, nValor, nSaldo, cStatus}...}
/*/
User Function GEBDERTITS(cGuia)
    Local aHit := {}
    Local aT := {}
    Local nI := 0
    If !GEBDBTableExistsHere("GFN3") .Or. !GEBDBTableExistsHere("GFX2")
        Return {}
    EndIf
    aHit := TCSqlQuery("SELECT GFN3_DOC AS D, GFN3_VALOR AS V, GFN3_SALDO AS S, GFN3_STATUS AS ST FROM GFN3 JOIN GFX2 ON GFX2_FILIAL = GFN3_FILIAL " + ;
        "AND GFX2_DOC = GFN3_DOC AND GFX2_TIPO = 'P' AND GFX2.D_E_L_E_T_ = ' ' WHERE GFN3.D_E_L_E_T_ = ' ' AND GFN3_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GFN3")) + " AND GFX2_ORIGDOC = " + GEBDBQuote(cGuia) + " AND GFX2_ORIGEM LIKE 'DERRAMA%' ORDER BY GFN3_DOC")
    For nI := 1 To Len(aHit)
        aAdd(aT, {BOCOL(aHit[nI]:D), Round(BOVAL(aHit[nI]:V), 2), Round(BOVAL(aHit[nI]:S), 2), BOCOL(aHit[nI]:ST)})
    Next nI
Return aT

/*/{Protheus.doc} GEBDERPROV
    Lanca a provisao de um tributo: deixa o saldo lancado do evento para o
    documento igual a nAlvo, lancando so' a diferenca (positiva no sentido do
    evento, negativa com as pernas invertidas). cDeb/cCred vazios = GC4.
    @type Servico contabil
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, nDiferencaLancada}
/*/
User Function GEBDERPROV(cEvento, cDoc, nAlvo, cData, cDeb, cCred)
    Local aHit := {}
    Local aR := {}
    Local nJa := 0
    Local nDif := 0

    cDeb := BOCOL(cDeb)
    cCred := BOCOL(cCred)
    If !GEBCTXMIG()
        Return {.F., "falha_tabelas", 0}
    EndIf
    If cDeb == "" .Or. cCred == ""
        aHit := TCSqlQuery("SELECT GC4_CTADEB AS D, GC4_CTACRED AS C FROM GC4 WHERE GC4_EVENTO = " + GEBDBQuote(cEvento) + " AND D_E_L_E_T_ = ' '")
        If Len(aHit) == 0
            Return {.F., "evento_sem_lancamento_padrao: " + cEvento, 0}
        EndIf
        If cDeb == ""
            cDeb := BOCOL(aHit[1]:D)
        EndIf
        If cCred == ""
            cCred := BOCOL(aHit[1]:C)
        EndIf
    EndIf
    aHit := TCSqlQuery("SELECT COALESCE(SUM(CASE WHEN GC3_CONTA = " + GEBDBQuote(cDeb) + " THEN GC3_VALOR ELSE -GC3_VALOR END), 0) AS V " + ;
        "FROM GC3 JOIN GC2 ON GC2_LOTE = GC3_LOTE AND GC2.D_E_L_E_T_ = ' ' WHERE GC3.D_E_L_E_T_ = ' ' AND GC3_DC = 'D' AND GC2_ORIGEM = " + ;
        GEBDBQuote(Left(cEvento + ":" + cDoc, 120)))
    If Len(aHit) > 0
        nJa := Round(BOVAL(aHit[1]:V), 2)
    EndIf
    nDif := Round(BOVAL(nAlvo) - nJa, 2)
    If nDif > 0
        aR := GEBCTXLP(cEvento, nDif, cDoc, cData, cDeb, cCred)
    ElseIf nDif < 0
        aR := GEBCTXLP(cEvento, -nDif, cDoc, cData, cCred, cDeb)
    Else
        Return {.T., "sem_diferenca", 0}
    EndIf
Return {aR[1], aR[2], nDif}

// Guia ativa: {cStatus, nValor, nJuros, nMulta}; {} se nao existe.
Static Function DERGuia(cGuia)
    Local aHit := TCSqlQuery("SELECT GD1_STATUS AS ST, GD1_VALOR AS V, GD1_JUROS AS J, GD1_MULTA AS M FROM GD1" + DERWhere("GD1", cGuia))
    If Len(aHit) == 0
        Return {}
    EndIf
Return {AllTrim(BOCOL(aHit[1]:ST)), Round(BOVAL(aHit[1]:V), 2), Round(BOVAL(aHit[1]:J), 2), Round(BOVAL(aHit[1]:M), 2)}

// Configuracao da guia (GD4): {cTipo, cCtaCtb, cCredor}; guia antiga = IBS/CBS.
Static Function DERCfg(cGuia)
    Local aHit := TCSqlQuery("SELECT GD4_TIPO AS T, GD4_CTACTB AS C, GD4_CREDOR AS CR FROM GD4" + DERWhere("GD4", cGuia))
    If Len(aHit) == 0
        Return {"IBSCBS", "2.01.004", "FISCO"}
    EndIf
Return {BOCOL(aHit[1]:T), BOCOL(aHit[1]:C), BOCOL(aHit[1]:CR)}

Static Function DERGrvGD4(cGuia, cTipo, cComp, cVenc, cCtaCtb, cCredor)
    TCSqlExec("UPDATE GD4 SET D_E_L_E_T_ = '*'" + DERWhere("GD4", cGuia))
Return TCSqlExec("INSERT INTO GD4 (D_E_L_E_T_, GD4_FILIAL, GD4_GUIA, GD4_TIPO, GD4_COMP, GD4_VENC, GD4_CTACTB, GD4_CREDOR) VALUES (' ', " + ;
    GEBDBQuote(FWxFilial("GD4")) + ", " + GEBDBQuote(cGuia) + ", " + GEBDBQuote(cTipo) + ", " + GEBDBQuote(cComp) + ", " + ;
    GEBDBQuote(cVenc) + ", " + GEBDBQuote(cCtaCtb) + ", " + GEBDBQuote(cCredor) + ")")

// Titulo unico da guia; emissao hoje (ou no vencimento, se ja passou).
Static Function DERCriaTit(cGuia, cTipo, nValor, cVenc, cCtaCtb, cCredor)
    Local cEmis := BOHOJE()
    Local cCond := ""
    If cVenc < cEmis
        cEmis := cVenc
    Else
        cCond := cValToChar(BODIAS(cEmis, cVenc))
    EndIf
Return GEBFXTIT("P", cGuia, cCredor, nValor, cCond, cEmis, "DERRAMA " + cTipo, cCtaCtb)

// Apaga os titulos abertos sem baixa da guia (e o complemento GFX2).
Static Function DERApagaTit(cGuia)
    Local aT := GEBDERTITS(cGuia)
    Local nI := 0
    For nI := 1 To Len(aT)
        If aT[nI][4] == "ABERTO" .And. aT[nI][2] == aT[nI][3]
            TCSqlExec("UPDATE GFN3 SET D_E_L_E_T_ = '*'" + DERWhere("GFN3", aT[nI][1], "DOC"))
            TCSqlExec("UPDATE GFX2 SET D_E_L_E_T_ = '*'" + DERWhere("GFX2", aT[nI][1], "DOC") + " AND GFX2_TIPO = 'P'")
        EndIf
    Next nI
Return .T.

Static Function DERTemBaixa(aT)
    Local nI := 0
    For nI := 1 To Len(aT)
        If aT[nI][3] < aT[nI][2] .Or. !(aT[nI][4] == "ABERTO")
            Return .T.
        EndIf
    Next nI
Return .F.

// Guias complementares <guia>-C<n> ativas: quantidade (lQtd) ou soma do valor.
Static Function DERCompl(cGuia, lQtd)
    Local aHit := TCSqlQuery("SELECT COUNT(*) AS Q, COALESCE(SUM(GD1_VALOR), 0) AS V FROM GD1 WHERE GD1_FILIAL = " + GEBDBQuote(FWxFilial("GD1")) + ;
        " AND GD1_GUIA LIKE " + GEBDBQuote(cGuia + "-C%") + " AND GD1_STATUS <> 'CANCELADA' AND D_E_L_E_T_ = ' '")
    If lQtd
        Return BOVAL(aHit[1]:Q)
    EndIf
Return Round(BOVAL(aHit[1]:V), 2)

// WHERE por filial + chave da guia (GD1/GD4) ou documento (GFN3/GFX2).
Static Function DERWhere(cTab, cChave, cCampo)
    If cCampo == Nil
        cCampo := "GUIA"
    EndIf
Return " WHERE " + cTab + "_FILIAL = " + GEBDBQuote(FWxFilial(cTab)) + " AND " + cTab + "_" + cCampo + " = " + GEBDBQuote(cChave) + " AND D_E_L_E_T_ = ' '"
