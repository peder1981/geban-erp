#include "totvs.ch"

/*/{Protheus.doc} GEBSEC_TOKEN
    Gestao de tokens/sessoes GEB_SEC (Task 4 GEB_SECURITY).
    GEBSECTOKEN(cUsuario, cEmpresa, cFilial, cIP) gera token JWT-like
    simples (sem lib externa) e grava em GE2_TOK. Retorna o token.
    GEBSECTOKENDEL(cToken) invalida token (soft-delete em GE2_TOK).
    Interface: U_GEBSECTOKEN -> GEBSECTOKEN(cUsuario, cEmpresa, cFilial, cIP).
    Interface: U_GEBSECTOKENDEL -> GEBSECTOKENDEL(cToken).
    Notas AdvPP: ConOut p/ log; TCSqlQuery/TCSqlExec so literais;
    GetArea/RestArea guardados; If Nil em vez de Default; sem SELECT *.
    Nota TOK_EXPIRES: coluna TEXT no formato "YYYYMMDD HH:MM:SS" (igual
    TOK_CREATED), permite granularidade de minuto. GEBMONMETRICAS()
    (GEBMON.prw) compara so contra DToS(Date()) -- portanto o corte de
    "online" tem granularidade de dia mesmo com TOK_EXPIRES precisa; um
    token expirado mais cedo no mesmo dia ainda conta como online ate a
    virada do dia. Fora do escopo desta funcao corrigir.
    @type Funcao de gestao de sessao
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario   Codigo do usuario
    @param cEmpresa  Codigo da empresa (CHAR 02)
    @param cFilial    Codigo da filial
    @param cIP        IP de origem
    @return cToken    Token gerado ("") se falhar
/*/
User Function GEBSECTOKEN(cUsuario, cEmpresa, cFilial, cIP)
    Local aArea     := GetArea()
    Local cToken    := ""
    Local cData     := ""
    Local cHora     := ""
    Local cExpires  := ""
    Local cEmp      := ""
    Local cFil      := ""
    Local cIp       := ""
    Local nHoraAtu  := 0
    Local nMinAtu   := 0
    Local nSegAtu   := 0
    Local nMinTotal := 0
    Local nMinResto := 0
    Local nHoraExp  := 0
    Local cDataExp  := ""

    // Default parametros.
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If cEmpresa == Nil
        cEmp := ""
    Else
        cEmp := AllTrim(cEmpresa)
    EndIf
    If cFilial == Nil
        cFil := ""
    Else
        cFil := AllTrim(cFilial)
    EndIf
    If cIP == Nil
        cIp := "local"
    Else
        cIp := AllTrim(cIP)
    EndIf

    // Token = 2 UUID v4 (crypto/rand) em hex: 64 caracteres, 244 bits
    // aleatorios. O formato antigo (data+hora+hash de usuario/empresa/IP)
    // era previsivel e repetia para dois logins no mesmo segundo.
    cData  := DToS(Date())
    cHora  := Time()
    cToken := GBSTokAleatorio()
    If cToken == ""
        ConOut("GEBSECTOKEN: falha ao gerar token aleatorio")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return ""
    EndIf

    // Expiracao: 8 horas (480 min) a partir de agora. NAO usar
    // "Date() + N" diretamente: neste runtime AdvPP, "Date() + N" (para
    // qualquer N, inclusive 0 ou 1) nao
    // devolve tipo Date, e sim Numeric (ValType "N"), e DToS() desse
    // resultado retorna "" -- confirmado empiricamente rodando contra o
    // Postgres. Por isso a virada de dia e' calculada
    // manualmente em Y/M/D (GBSTokDiaSeguinte()), sem usar o operador "+"
    // sobre Date(). "/" tambem nao trunca aqui (retorna Double), entao
    // toda a aritmetica usa apenas "+", "-" e "%" (confirmados corretos).
    nHoraAtu  := Val(SubStr(cHora, 1, 2))
    nMinAtu   := Val(SubStr(cHora, 4, 2))
    nSegAtu   := Val(SubStr(cHora, 7, 2))
    nMinTotal := (nHoraAtu * 60) + nMinAtu + 480

    // nMinTotal cabe em no maximo 1 virada de dia (max 23:59 + 480min = 1919min).
    If nMinTotal >= 1440
        cDataExp  := GBSTokDiaSeguinte(cData)
        nMinResto := nMinTotal - 1440
    Else
        cDataExp  := cData
        nMinResto := nMinTotal
    EndIf

    // Extrai hora:minuto de nMinResto (0..1439) por subtracao.
    nHoraExp := 0
    Do While nMinResto >= 60
        nMinResto := nMinResto - 60
        nHoraExp  := nHoraExp + 1
    EndDo

    cExpires := cDataExp + " " + PadL(cValToChar(nHoraExp), 2, "0") + ;
        ":" + PadL(cValToChar(nMinResto), 2, "0") + ":" + PadL(cValToChar(nSegAtu), 2, "0")

    // Grava em GE2_TOK.
    TCSqlExec("INSERT INTO GE2_TOK (D_E_L_E_T_, TOK_TOKEN, TOK_USUARIO, TOK_EMPRESA, TOK_FILIAL, TOK_IP, TOK_CREATED, TOK_EXPIRES) VALUES (' ', " + GEBDBQuote(cToken) + ", " + GEBDBQuote(cUsuario) + ", " + GEBDBQuote(cEmp) + ", " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cIp) + ", " + GEBDBQuote(cData + " " + cHora) + ", " + GEBDBQuote(cExpires) + ")")
    ConOut("GEBSECTOKEN: token gerado para usuario " + cUsuario)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return cToken

// Calcula o dia seguinte a cData ("YYYYMMDD") sem usar Date()+N (neste
// runtime AdvPP o operador nao devolve tipo Date -- ver nota em
// GEBSECTOKEN). Aritmetica pura em Y/M/D com "+", "-" e "%".
Static Function GBSTokDiaSeguinte(cData)
    Local nAno       := Val(SubStr(cData, 1, 4))
    Local nMes       := Val(SubStr(cData, 5, 2))
    Local nDia       := Val(SubStr(cData, 7, 2))
    Local nUltDia    := 31
    Local lBissexto  := .F.

    lBissexto := ((nAno % 4 == 0 .And. nAno % 100 != 0) .Or. nAno % 400 == 0)

    Do Case
        Case nMes == 4 .Or. nMes == 6 .Or. nMes == 9 .Or. nMes == 11
            nUltDia := 30
        Case nMes == 2
            If lBissexto
                nUltDia := 29
            Else
                nUltDia := 28
            EndIf
        Otherwise
            nUltDia := 31
    EndCase

    nDia := nDia + 1
    If nDia > nUltDia
        nDia := 1
        nMes := nMes + 1
        If nMes > 12
            nMes := 1
            nAno := nAno + 1
        EndIf
    EndIf

Return cValToChar(nAno) + PadL(cValToChar(nMes), 2, "0") + PadL(cValToChar(nDia), 2, "0")

// Invalida token (soft-delete).
User Function GEBSECTOKENDEL(cToken)
    Local aArea  := GetArea()
    Local lOk    := .F.
    Local cTok   := ""

    If cToken == Nil
        cTok := ""
    Else
        cTok := AllTrim(cToken)
    EndIf

    If cTok != ""
        TCSqlExec("UPDATE GE2_TOK SET D_E_L_E_T_ = '*' WHERE TOK_TOKEN = " + GEBDBQuote(cTok) + " AND D_E_L_E_T_ = ' '")
        lOk := .T.
        ConOut("GEBSECTOKENDEL: token invalidado")
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

// GBSTokAleatorio() -> 64 hex de 2 UUID v4 (crypto/rand), ou "" se falhar.
Static Function GBSTokAleatorio()
    Local cU1 := UUIDRandom()
    Local cU2 := UUIDRandom()
    Local cTok := ""
    If ValType(cU1) == "C" .And. ValType(cU2) == "C"
        cTok := Lower(StrTran(AllTrim(cU1), "-", "") + StrTran(AllTrim(cU2), "-", ""))
    EndIf
    If Len(cTok) != 64
        cTok := ""
    EndIf
Return cTok
