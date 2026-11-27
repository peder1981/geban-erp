#include "totvs.ch"
#include "GEBDB_CORE.prw"
#include "GEBREST.prw"
#include "GEBSEC_LOGIN.prw"
#include "GEBSEC_RBA.prw"
#include "GEBLOJ.prw"
#include "GEBLOJ_OPE.prw"
#include "GEBPERIF_MIG.prw"

/*/{Protheus.doc} GEBPDVCAIXALST
    Lista caixas cadastrados via API REST.
    @type Consulta caixa
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVCAIXALST(cUsuario)
    Local aArea := GetArea()
    Local cFil  := FWxFilial("GLJ1")
    Local aHit  := {}
    Local aR    := {}
    Local nI    := 0

    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf

    If !GEBDBTableExistsHere("GLJ1")
        Return PDVRES(.F., "tabela_nao_existente", {})
    EndIf

    aHit := TCSqlQuery("SELECT GLJ1_COD, GLJ1_NOME, GLJ1_CONTA, GLJ1_LOCAL FROM GLJ1 " + ;
        "WHERE GLJ1_FILIAL = " + GEBDBQuote(cFil) + " AND D_E_L_E_T_ = ' ' " + ;
        "ORDER BY GLJ1_COD")

    For nI := 1 To Len(aHit)
        aAdd(aR, {BOCOL(aHit[nI]:GLJ1_COD), BOCOL(aHit[nI]:GLJ1_NOME), BOCOL(aHit[nI]:GLJ1_CONTA), BOCOL(aHit[nI]:GLJ1_LOCAL)})
    Next

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf

Return PDVRES(.T., "caixas_listados", aR)

/*/{Protheus.doc} GEBPDVCAIXASS
    Lista sessoes de caixa abertas (GLJ2) via API REST -- permite ao PDV web
    retomar uma sessao ja aberta em vez de depender so do GLJ1.
    @type Consulta caixa
    @author Peder Munksgaard
    @since 26/11/2026
/*/
User Function GEBPDVCAIXASS(cUsuario)
    Local aArea := GetArea()
    Local cFil  := FWxFilial("GLJ2")
    Local aHit  := {}
    Local aR    := {}
    Local nI    := 0

    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf

    If !GEBDBTableExistsHere("GLJ2")
        Return PDVRES(.F., "tabela_nao_existente", {})
    EndIf

    aHit := TCSqlQuery("SELECT GLJ2_SESSAO, GLJ2_CAIXA, GLJ2_OPER, GLJ2_FUNDO, GLJ2_ABERT, GLJ2_HORA FROM GLJ2 " + ;
        "WHERE GLJ2_FILIAL = " + GEBDBQuote(cFil) + " AND GLJ2_STATUS = 'ABERTA' AND D_E_L_E_T_ = ' ' " + ;
        "ORDER BY GLJ2_ABERT, GLJ2_SESSAO")

    For nI := 1 To Len(aHit)
        aAdd(aR, {BOCOL(aHit[nI]:GLJ2_SESSAO), BOCOL(aHit[nI]:GLJ2_CAIXA), BOCOL(aHit[nI]:GLJ2_OPER), BOVAL(aHit[nI]:GLJ2_FUNDO), BOCOL(aHit[nI]:GLJ2_ABERT), BOCOL(aHit[nI]:GLJ2_HORA)})
    Next

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf

Return PDVRES(.T., "sessoes_listadas", aR)

/*/{Protheus.doc} GEBPDVCAIXAABR
    Abre sessao de caixa via API REST.
    @type Operacao caixa
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVCAIXAABR(cUsuario, aBody)
    Local cCaixa  := ""
    Local cOper   := ""
    Local nFundo  := 0
    Local aR      := {}
    Local cData   := ""

    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf

    cCaixa  := BOCOL(aBody:CAIXA)
    cOper   := BOCOL(aBody:OPERADOR)
    nFundo  := BOVAL(aBody:FUNDO)
    cData   := BOHOJE()

    If cCaixa == ""
        Return PDVRES(.F., "caixa_obrigatorio", {})
    EndIf

    aR := GEBLOJABRE(cCaixa, cOper, nFundo, cData)

Return PDVRES(aR[1], aR[2], aR)

/*/{Protheus.doc} GEBPDVCAIXAFECH
    Fecha sessao de caixa via API REST.
    @type Operacao caixa
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVCAIXAFECH(cUsuario, aBody)
    Local cSessao := ""
    Local nContado := 0
    Local aR      := {}

    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf

    cSessao := BOCOL(aBody:SESSAO)
    nContado := BOVAL(aBody:CONTADO)

    If cSessao == ""
        Return PDVRES(.F., "sessao_obrigatoria", {})
    EndIf

    aR := GEBLOJFECHA(cSessao, nContado)

Return PDVRES(aR[1], aR[2], aR)

/*/{Protheus.doc} GEBPDVCUPOMNOV
    Cria novo cupom via API REST.
    @type Operacao cupom
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVCUPOMNOV(cUsuario, aBody)
    Local cSessao := ""
    Local aItens  := {}
    Local aPagtos := {}
    Local cCli    := ""
    Local nDesc   := 0
    Local cVend   := ""
    Local cCPF    := ""
    Local aR      := {}

    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf

    cSessao := BOCOL(aBody:SESSAO)
    aItens  := aBody:ITENS
    aPagtos := aBody:PAGAMENTOS
    cCli    := BOCOL(aBody:CLIENTE)
    nDesc   := BOVAL(aBody:DESCONTO)
    cVend   := BOCOL(aBody:VENDEDOR)
    cCPF    := BOCOL(aBody:CPF)

    If cSessao == ""
        Return PDVRES(.F., "sessao_obrigatoria", {})
    EndIf
    If Len(aItens) == 0
        Return PDVRES(.F., "itens_obrigatorios", {})
    EndIf
    If Len(aPagtos) == 0
        Return PDVRES(.F., "pagamentos_obrigatorios", {})
    EndIf

    aR := GEBLOJVEN(cSessao, aItens, aPagtos, cCli, nDesc, cVend, cCPF, "", "", "", BOCOL(aBody:REGIME))

Return PDVRES(aR[1], aR[2], aR)

/*/{Protheus.doc} GEBPDVCUPOMGET
    Busca cupom por ID (segunda via) via API REST.
    @type Consulta cupom
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVCUPOMGET(cUsuario, cCupom)
    Local aR      := {}

    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf

    cCupom := AllTrim(cValToChar(cCupom))
    If cCupom == ""
        Return PDVRES(.F., "cupom_obrigatorio", {})
    EndIf

    aR := GEBLOJCUPOM(cCupom)

Return PDVRES(aR[1], aR[2], aR)

/*/{Protheus.doc} GEBPDVCUPCANC
    Cancela cupom via API REST.
    @type Operacao cupom
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVCUPCANC(cUsuario, aBody)
    Local cCupom  := ""
    Local cMotivo := ""
    Local aR      := {}

    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf

    cCupom := BOCOL(aBody:ID)
    cMotivo := BOCOL(aBody:MOTIVO)

    If cCupom == ""
        Return PDVRES(.F., "cupom_obrigatorio", {})
    EndIf

    aR := GEBLOJCAN(cCupom, cMotivo)

Return PDVRES(aR[1], aR[2], aR)

/*/{Protheus.doc} GEBPDVPRODUTBUSC
    Busca produto por codigo ou codigo de barras via API REST.
    @type Consulta produto
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVPRODUTBUSC(cUsuario, cCodigo)
    Local aR      := {}

    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf

    cCodigo := AllTrim(cValToChar(cCodigo))
    If cCodigo == ""
        Return PDVRES(.F., "codigo_obrigatorio", {})
    EndIf

    aR := GEBLOJCONS(cCodigo, "")

Return PDVRES(aR[1], aR[2], aR)

/*/{Protheus.doc} GEBPDVRELGER
    Relatorio gerencial da loja via API REST.
    @type Relatorio
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVRELGER(cUsuario, aBody)
    Local cIni   := ""
    Local cFim   := ""
    Local cAgrupa := ""
    Local aR     := {}

    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf

    cIni   := BOCOL(aBody:INICIO)
    cFim   := BOCOL(aBody:FIM)
    cAgrupa := BOCOL(aBody:AGRUPA)

    If cIni == "" .Or. cFim == ""
        Return PDVRES(.F., "periodo_obrigatorio", {})
    EndIf

    aR := GEBLOJGER(cIni, cFim, cAgrupa)

Return PDVRES(aR[1], aR[2], aR)

/*/{Protheus.doc} GEBPDVRELCOM
    Relatorio de comissao por vendedor via API REST.
    @type Relatorio
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVRELCOM(cUsuario, aBody)
    Local cIni   := ""
    Local cFim   := ""
    Local aR     := {}

    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf

    cIni := BOCOL(aBody:INICIO)
    cFim := BOCOL(aBody:FIM)

    If cIni == "" .Or. cFim == ""
        Return PDVRES(.F., "periodo_obrigatorio", {})
    EndIf

    aR := GEBLOJCOMIS(cIni, cFim)

Return PDVRES(aR[1], aR[2], aR)

/*/{Protheus.doc} GEBPDVPERIFLIST
    Lista periféricos configurados via API REST.
    @type Consulta periferico
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVPERIFLIST(cUsuario, cTipo)
    Local aArea := GetArea()
    Local cFil  := FWxFilial("GEP_PERIFERICOS")
    Local aHit  := {}
    Local aR    := {}
    Local nI    := 0
    Local cSql  := ""

    If !GEBSECRBAC(cUsuario, "CONFIG", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf

    If !GEBDBTableExistsHere("GEP_PERIFERICOS")
        Return PDVRES(.F., "tabela_nao_existente", {})
    EndIf

    cSql := "SELECT R_E_C_N_O_, GEP_TIPO, GEP_DRIVER, GEP_NOME, GEP_CONFIG, GEP_ATIVO, GEP_STATUS FROM GEP_PERIFERICOS " + ;
        "WHERE GEP_FILIAL = " + GEBDBQuote(cFil) + " AND D_E_L_E_T_ = ' '"

    If !(AllTrim(cValToChar(cTipo)) == "")
        cSql := cSql + " AND GEP_TIPO = " + GEBDBQuote(AllTrim(cValToChar(cTipo)))
    EndIf

    cSql := cSql + " ORDER BY GEP_TIPO, GEP_NOME"

    aHit := TCSqlQuery(cSql)

    For nI := 1 To Len(aHit)
        aAdd(aR, {BOCOL(aHit[nI]:R_E_C_N_O_), BOCOL(aHit[nI]:GEP_TIPO), BOCOL(aHit[nI]:GEP_DRIVER), BOCOL(aHit[nI]:GEP_NOME), BOCOL(aHit[nI]:GEP_CONFIG), BOCOL(aHit[nI]:GEP_ATIVO), BOCOL(aHit[nI]:GEP_STATUS)})
    Next

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf

Return PDVRES(.T., "perifericos_listados", aR)

/*/{Protheus.doc} GEBPDVPERIFREG
    Registra periférico via API REST.
    @type Cadastro periferico
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVPERIFREG(cUsuario, aBody)
    Local aArea := GetArea()
    Local cFil  := FWxFilial("GEP_PERIFERICOS")
    Local cData := BOHOJE()
    Local cTipo := ""
    Local cDriver := ""
    Local cNome := ""
    Local jConfig := ""
    Local nId   := 0
    Local aSeq  := {}

    If !GEBSECRBAC(cUsuario, "CONFIG", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf

    cTipo   := BOCOL(aBody:TIPO)
    cDriver := BOCOL(aBody:DRIVER)
    cNome   := BOCOL(aBody:NOME)
    jConfig := BOCOL(aBody:CONFIG)

    If cTipo == "" .Or. cDriver == "" .Or. cNome == ""
        Return PDVRES(.F., "parametros_obrigatorios", 0)
    EndIf

    If !GEBDBTableExistsHere("GEP_PERIFERICOS")
        Return PDVRES(.F., "tabela_nao_existente", 0)
    EndIf

    TCSqlExec("INSERT INTO GEP_PERIFERICOS (D_E_L_E_T_, GEP_FILIAL, GEP_TIPO, GEP_DRIVER, GEP_CONFIG, GEP_NOME, GEP_ATIVO, GEP_STATUS, GEP_DTALT, GEP_USALT) " + ;
        "VALUES (' ', " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cTipo) + ", " + GEBDBQuote(cDriver) + ", " + GEBDBQuote(jConfig) + ", " + GEBDBQuote(cNome) + ", 'S', 'DESCONNECTED', " + GEBDBQuote(cData) + ", '')")

    aSeq := TCSqlQuery("SELECT LAST_VALUE FROM GEP_PERIFERICOS_R_E_C_N_O_seq")
    If Len(aSeq) > 0
        nId := Val(cValToChar(aSeq[1]:LAST_VALUE))
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf

Return PDVRES(.T., "periferico_registrado: " + cNome, nId)

/*/{Protheus.doc} GEBPDVPERIFDEL
    Remove periférico via API REST.
    @type Remocao periferico
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVPERIFDEL(cUsuario, nId)
    Local aArea := GetArea()
    Local cFil  := FWxFilial("GEP_PERIFERICOS")
    Local nIdVal := 0

    If !GEBSECRBAC(cUsuario, "CONFIG", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf

    nIdVal := Val(cValToChar(nId))
    If nIdVal <= 0
        Return PDVRES(.F., "id_invalido", {})
    EndIf

    If !GEBDBTableExistsHere("GEP_PERIFERICOS")
        Return PDVRES(.F., "tabela_nao_existente", {})
    EndIf

    TCSqlExec("UPDATE GEP_PERIFERICOS SET D_E_L_E_T_ = '*', GEP_DTALT = " + GEBDBQuote(BOHOJE()) + " " + ;
        "WHERE R_E_C_N_O_ = " + cValToChar(nIdVal) + " AND GEP_FILIAL = " + GEBDBQuote(cFil) + " AND D_E_L_E_T_ = ' '")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf

Return PDVRES(.T., "periferico_removido: " + cValToChar(nIdVal), {})

// ===== SANGRIA / SUPRIMENTO =====

/*/{Protheus.doc} GEBPDVSANGRIA
    Sangria ou suprimento de caixa via API REST.
    @type Operacao caixa
    @author Peder Munksgaard
    @since 21/10/2026
    @param cSessao Sessao do caixa
    @param cTipo SANGRIA (caixa->cofre) ou SUPRIMENTO (cofre->caixa)
    @param nValor Valor
    @param cMotivo Motivo
    @return {lOk, cMsg}
/*/
User Function GEBPDVSANGRIA(cUsuario, aBody)
    Local cSessao := ""
    Local cTipo   := ""
    Local nValor  := 0
    Local cMotivo := ""
    Local aR      := {}

    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf

    cSessao := BOCOL(aBody:SESSAO)
    cTipo   := Upper(BOCOL(aBody:TIPO))
    nValor  := BOVAL(aBody:VALOR)
    cMotivo := BOCOL(aBody:MOTIVO)

    If cSessao == "" .Or. (cTipo != "SANGRIA" .And. cTipo != "SUPRIMENTO") .Or. nValor <= 0
        Return PDVRES(.F., "parametros_obrigatorios: sessao, tipo (SANGRIA/SUPRIMENTO), valor", {})
    EndIf

    aR := GEBLOJSAN(cSessao, cTipo, nValor, cMotivo, "")

Return PDVRES(aR[1], aR[2], {})

// ===== RELATÓRIOS COM EXPORTAÇÃO =====

/*/{Protheus.doc} GEBPDVRELGERCSV
    Relatorio gerencial exportado como CSV.
    @type Relatorio
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVRELGERCSV(cUsuario, aBody)
    Local cIni   := ""
    Local cFim   := ""
    Local cAgrupa := ""
    Local aR     := {}
    Local cCsv   := ""
    Local nI     := 0
    Local nJ     := 0
    Local cLine  := ""

    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", "")
    EndIf

    cIni   := BOCOL(aBody:INICIO)
    cFim   := BOCOL(aBody:FIM)
    cAgrupa := BOCOL(aBody:AGRUPA)

    If cIni == "" .Or. cFim == ""
        Return PDVRES(.F., "periodo_obrigatorio", "")
    EndIf

    aR := GEBLOJGER(cIni, cFim, cAgrupa)
    If !aR[1]
        Return PDVRES(.F., aR[2], "")
    EndIf

    // Converter array de linhas para CSV
    For nI := 1 To Len(aR[3])
        cLine := ""
        For nJ := 1 To Len(aR[3][nI])
            If nJ > 1
                cLine := cLine + ","
            EndIf
            cLine := cLine + GEBRESTCSVVAL(aR[3][nI][nJ])
        Next
        cCsv := cCsv + cLine + Chr(13) + Chr(10)
    Next

Return PDVRES(.T., "relatorio_gerencial_csv", cCsv)

/*/{Protheus.doc} GEBRESTCSVVAL
    Converte valor para campo CSV (entre aspas se contiver virgula).
    @type Helper
    @author Peder Munksgaard
    @since 21/10/2026
/*/
Static Function GEBRESTCSVVAL(xVal)
    Local cTxt := ""
    cTxt := AllTrim(cValToChar(xVal))
    If At(",", cTxt) > 0 .Or. At(Chr(34), cTxt) > 0 .Or. At(Chr(10), cTxt) > 0
        cTxt := Chr(34) + StrTran(cTxt, Chr(34), Chr(34) + Chr(34)) + Chr(34)
    EndIf
Return cTxt

/*/{Protheus.doc} GEBPDVRELCOMCSV
    Relatorio de comissao exportado como CSV.
    @type Relatorio
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVRELCOMCSV(cUsuario, aBody)
    Local cIni   := ""
    Local cFim   := ""
    Local aR     := {}
    Local cCsv   := ""
    Local nI     := 0
    Local nJ     := 0
    Local cLine  := ""

    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", "")
    EndIf

    cIni := BOCOL(aBody:INICIO)
    cFim := BOCOL(aBody:FIM)

    If cIni == "" .Or. cFim == ""
        Return PDVRES(.F., "periodo_obrigatorio", "")
    EndIf

    aR := GEBLOJCOMIS(cIni, cFim)
    If !aR[1]
        Return PDVRES(.F., aR[2], "")
    EndIf

    For nI := 1 To Len(aR[3])
        cLine := ""
        For nJ := 1 To Len(aR[3][nI])
            If nJ > 1
                cLine := cLine + ","
            EndIf
            cLine := cLine + GEBRESTCSVVAL(aR[3][nI][nJ])
        Next
        cCsv := cCsv + cLine + Chr(13) + Chr(10)
    Next

Return PDVRES(.T., "comissao_csv", cCsv)

/*/{Protheus.doc} GEBPDVCAIXARESUMO
    Resumo completo da sessao de caixa (para fechamento).
    @type Consulta caixa
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVCAIXARESUMO(cUsuario, cSessao)
    Local aArea := GetArea()
    Local cFil  := FWxFilial("GLJ2")
    Local aHit  := {}
    Local aR    := {}
    Local aFormas := {"DINHEIRO", "PIX", "DEBITO", "CREDITO", "FIADO", "VALE"}
    Local nI    := 0
    Local aMov  := {}
    Local aDev  := {}
    Local cSql  := ""
    Local aSes  := {}
    Local aLinhas := {}

    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf

    cSessao := Upper(BOCOL(cSessao))

    aSes := TCSqlQuery("SELECT GLJ2_CAIXA, GLJ2_OPER, GLJ2_ABERT, GLJ2_HORA, " + ;
        "GLJ2_FUNDO, GLJ2_STATUS, GLJ2_FECH, GLJ2_CONTADO, GLJ2_ESPERADO, GLJ2_DIFER " + ;
        "FROM GLJ2 WHERE GLJ2_FILIAL = " + GEBDBQuote(cFil) + " " + ;
        "AND GLJ2_SESSAO = " + GEBDBQuote(cSessao) + " AND D_E_L_E_T_ = ' '")

    If Len(aSes) == 0
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return PDVRES(.F., "sessao_nao_encontrada", {})
    EndIf

    aR := {;
        BOCOL(aSes[1]:GLJ2_CAIXA),;
        BOCOL(aSes[1]:GLJ2_OPER),;
        BOVAL(aSes[1]:GLJ2_FUNDO),;
        BOCOL(aSes[1]:GLJ2_ABERT),;
        BOCOL(aSes[1]:GLJ2_HORA),;
        BOCOL(aSes[1]:GLJ2_STATUS),;
        BOVAL(aSes[1]:GLJ2_CONTADO),;
        BOVAL(aSes[1]:GLJ2_ESPERADO),;
        BOVAL(aSes[1]:GLJ2_DIFER);
    }

    // Consultar movimentacoes (sangrias/suprimentos)
    aMov := TCSqlQuery("SELECT GLJ6_TIPO, GLJ6_VALOR, GLJ6_MOTIVO, GLJ6_DATA " + ;
        "FROM GLJ6 WHERE GLJ6_FILIAL = " + GEBDBQuote(cFil) + " " + ;
        "AND GLJ6_SESSAO = " + GEBDBQuote(cSessao) + " AND D_E_L_E_T_ = ' '" + ;
        " ORDER BY GLJ6_DATA")

    For nI := 1 To Len(aMov)
        aAdd(aLinhas, {BOCOL(aMov[nI]:GLJ6_TIPO), BOCOL(aMov[nI]:GLJ6_MOTIVO), BOVAL(aMov[nI]:GLJ6_VALOR), BOCOL(aMov[nI]:GLJ6_DATA)})
    Next

    // Consultar devolucoes por forma
    For nI := 1 To Len(aFormas)
        aDev := TCSqlQuery("SELECT COALESCE(SUM(GLJ5_VALOR), 0) AS V FROM GLJ5 " + ;
            "JOIN GLJ3 ON GLJ3_FILIAL = GLJ5_FILIAL AND GLJ3_CUPOM = GLJ5_CUPOM " + ;
            "AND GLJ3.D_E_L_E_T_ = ' ' " + ;
            "WHERE GLJ5_FILIAL = " + GEBDBQuote(cFil) + " " + ;
            "AND GLJ5_CUPOM IN (SELECT GLJ3_CUPOM FROM GLJ3 WHERE GLJ3_FILIAL = " + GEBDBQuote(cFil) + ;
            " AND GLJ3_SESSAO = " + GEBDBQuote(cSessao) + " AND GLJ3_STATUS = 'CANCELADO' AND D_E_L_E_T_ = ' ') " + ;
            "AND GLJ5_FORMA = " + GEBDBQuote(aFormas[nI]) + " AND GLJ5.D_E_L_E_T_ = ' '")
        aAdd(aLinhas, {"devolucao_" + aFormas[nI], "", BOVAL(aDev[1]:V), ""})
    Next

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf

Return PDVRES(.T., "resumo_caixa", aR)

// ===== CRYPTO =====

/*/{Protheus.doc} GEBPDVCRYCOT
    Cotacao crypto das moedas com wallet ativa (para o caixa montar o QR).
    @type Consulta crypto
    @author Peder Munksgaard
    @since 26/11/2026
/*/
User Function GEBPDVCRYCOT(cUsuario)
    Local aR := {}
    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf
    aR := GEBCRYCOT("")
Return PDVRES(Len(aR) > 0, Iif(Len(aR) > 0, "cotacao_ok", "cotacao_indisponivel"), aR)

/*/{Protheus.doc} GEBPDVCRYWAL LST
    Lista as wallets crypto da empresa.
    @type Consulta crypto
    @author Peder Munksgaard
    @since 26/11/2026
/*/
User Function GEBPDVCRYWALLST(cUsuario)
    Local aR := {}
    // PDV/01 basta: o caixa precisa ver as moedas ativas para cobrar.
    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf
    aR := GEBCRYWALLST()
Return PDVRES(aR[1], aR[2], aR[3])

/*/{Protheus.doc} GEBPDVCRYPREV
    Previa do pagamento crypto: cotacao + URI do QR para o caixa exibir
    antes de finalizar. A venda re-cota no servidor na hora (GEBLOJVEN).
    @type Consulta crypto
    @author Peder Munksgaard
    @since 26/11/2026
/*/
User Function GEBPDVCRYPREV(cUsuario, cMoeda, nBRL)
    Local aR := {}
    If !GEBSECRBAC(cUsuario, "PDV", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf
    aR := GEBCRYQRCODE(cMoeda, nBRL)
    If !aR[1]
        Return PDVRES(.F., aR[2], {})
    EndIf
Return PDVRES(.T., "qr_ok", {aR[3][1], aR[3][2], aR[3][3], aR[3][4], BOVAL(nBRL)})

/*/{Protheus.doc} GEBPDVCRYWAL REG
    Cadastra/altera a wallet de uma moeda (CONFIG).
    @type Cadastro crypto
    @author Peder Munksgaard
    @since 26/11/2026
/*/
User Function GEBPDVCRYWAL(cUsuario, aBody)
    Local aR := {}
    If !GEBSECRBAC(cUsuario, "CONFIG", "01")
        Return PDVRES(.F., "sem_permissao", {})
    EndIf
    aR := GEBCRYWAL(BOCOL(aBody:MOEDA), BOCOL(aBody:ENDERECO), BOCOL(aBody:ATIVO))
Return PDVRES(aR[1], aR[2], {})

/*/{Protheus.doc} PDVRES
    Resposta HTTP do PDV no envelope que public/pdv.html le:
    {"ok":bool,"msg":texto,"erro":texto|null,"dados":payload}. Volta como
    RAW_HTTP: string comum seria re-codificada pelo servidor (o navegador
    receberia uma string JSON e r.ok seria undefined).
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
    @param lOk, logical, sucesso
    @param cMsg, character, mensagem (vira "erro" quando lOk = .F.)
    @param xDados, variant, payload
    @return array, sentinela RAW_HTTP
/*/
Static Function PDVRES(lOk, cMsg, xDados)
    Local cMsgJ := GEBRESTJSONENC(cValToChar(cMsg)) as Character
    Local cErro := cMsgJ as Character

    If lOk
        cErro := "null"
    EndIf
Return {"__RAW_HTTP__", "application/json; charset=utf-8", '{"ok":' + GEBRESTJSONENC(lOk == .T.) + ',"msg":' + cMsgJ + ',"erro":' + cErro + ',"dados":' + GEBRESTJSONENC(xDados) + '}', 200}
