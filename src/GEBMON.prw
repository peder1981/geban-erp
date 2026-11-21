#include "totvs.ch"

#include "GEBDB_CORE.prw"
#include "GEBEXP_CTX.prw"
/*/{Protheus.doc} GEBMON
    Monitoramento de sessoes e auditoria de acessos (Task 6 GEB_SECURITY).
    Funcoes:
    - GEBMONINIC(): inicializa tabela SEC_MON se nao existir.
    - GEBMONATUALIZA(cToken, cRotina): atualiza ultima acao do token.
    - GEBMONLISTAR(): retorna array de usuarios monitorados,
      filtrando por empresa do admin (ADMIN ve todas).
    - GEBMONDESLIGAR(cToken): remove da SEC_MON + encerra sessao via GEBSECTOKENDEL.
    - GEBMONMETRICAS(): retorna object {nUsuariosOnline, nEmpresasAtivas, nReqPorSeg, gargalos}.
    - GEBMONROTINA(cToken): retorna rotina em execucao.
    Tabela SEC_MON: TOKEN, USUARIO, EMPRESA, FILIAL, IP, LOGINEM, ULTIMAACAO, ROTINA, MEMORIAUSADA.
    Auditoria (GEI_AUDIT, funcoes de log e listagem) migrou para GEBAUD.prw,
    que e a fonte autoritativa (schema com colunas prefixadas GEI_AUDIT_*).
    Notas AdvPP: ConOut p/ log; GetArea/RestArea guardados; If Nil em vez de Default;
        sem SELECT *; so User/Static.
    @type Modulo de monitoramento e auditoria
    @author Peder Munksgaard
    @since 23/09/2026
/*/

// ============================================================
// SEC_MON - Tabela de monitoramento de sessoes
// ============================================================

/*/{Protheus.doc} GEBMONINIC
    Inicializa a tabela SEC_MON (monitoramento) se nao existir.
    Colunas: TOKEN, USUARIO, EMPRESA, FILIAL, IP, LOGINEM, ULTIMAACAO, ROTINA, MEMORIAUSADA.
    @type Migracao de tabela
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se sucesso, .F. se erro
/*/
User Function GEBMONINIC()
    Local aArea    := GetArea()
    Local lOk      := .T.
    Local cSql     := ""

    ConOut("GEBMON_INIC verificando tabela SEC_MON")

    If !GEBDBTableExistsHere("SEC_MON")
        cSql := "CREATE TABLE SEC_MON ("
        cSql += "R_E_C_N_O_ INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY, "
        cSql += "D_E_L_E_T_ TEXT DEFAULT ' ', "
        cSql += "TOKEN TEXT NOT NULL, "
        cSql += "USUARIO TEXT NOT NULL, "
        cSql += "EMPRESA TEXT NOT NULL, "
        cSql += "FILIAL TEXT NOT NULL, "
        cSql += "IP TEXT NOT NULL, "
        cSql += "LOGINEM TEXT NOT NULL, "
        cSql += "ULTIMAACAO TEXT NOT NULL, "
        cSql += "ROTINA TEXT, "
        cSql += "MEMORIAUSADA INTEGER DEFAULT 0)"
        lOk := TCSqlExec(cSql)
        If lOk
            ConOut("  SEC_MON criado")
            lOk := (lOk .And. TCSqlExec("CREATE INDEX IF NOT EXISTS SEC_MON_TOKEN ON SEC_MON (TOKEN, D_E_L_E_T_)"))
        Else
            ConOut("  ERR ao criar SEC_MON")
        EndIf
    Else
        If !GEBDBColumnExists("SEC_MON", "ROTINA")
            ConOut("  SEC_MON recriado com colunas completas")
            TCSqlExec("DROP TABLE IF EXISTS SEC_MON_OLD")
            TCSqlExec("ALTER TABLE SEC_MON RENAME TO SEC_MON_OLD")
            cSql := "CREATE TABLE SEC_MON ("
            cSql += "R_E_C_N_O_ INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY, "
            cSql += "D_E_L_E_T_ TEXT DEFAULT ' ', "
            cSql += "TOKEN TEXT NOT NULL, "
            cSql += "USUARIO TEXT NOT NULL, "
            cSql += "EMPRESA TEXT NOT NULL, "
            cSql += "FILIAL TEXT NOT NULL, "
            cSql += "IP TEXT NOT NULL, "
            cSql += "LOGINEM TEXT NOT NULL, "
            cSql += "ULTIMAACAO TEXT NOT NULL, "
            cSql += "ROTINA TEXT, "
            cSql += "MEMORIAUSADA INTEGER DEFAULT 0)"
            lOk := TCSqlExec(cSql)
            If !lOk
                ConOut("  ERR ao recriar SEC_MON")
            EndIf
            TCSqlExec("DROP TABLE IF EXISTS SEC_MON_OLD")
        Else
            ConOut("  SEC_MON ja existe")
        EndIf
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

// ============================================================
// GEBMONATUALIZA
// ============================================================

/*/{Protheus.doc} GEBMONATUALIZA
    Atualiza ultima acao e rotina do token na SEC_MON.
    Called por cada operacao do usuario.
    @type Atualizacao de monitoramento
    @author Peder Munksgaard
    @since 23/09/2026
    @param cToken    Token da sessao
    @param cRotina   Nome da rotina em execucao
    @return void
/*/
User Function GEBMONATUALIZA(cToken, cRotina)
    Local aArea    := GetArea()
    Local cTok     := ""
    Local cRot     := ""
    Local cDataH   := ""
    Local cSql     := ""
    Local aHit     := {}
    Local oRow     := Nil
    Local cUsu     := ""
    Local cEmp     := ""
    Local cFil     := ""
    Local cIp      := ""
    Local cLoginEm := ""
    Local lIns     := .F.
    Local cInsFlag := ""

    If cToken == Nil
        cTok := ""
    Else
        cTok := AllTrim(cToken)
    EndIf
    If cRotina == Nil
        cRot := ""
    Else
        cRot := AllTrim(cRotina)
    EndIf

    If cTok == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return
    EndIf

    cDataH := DToS(Date()) + " " + Time()

    aHit := TCSqlQuery( ;
        "SELECT USUARIO, EMPRESA, FILIAL, IP, LOGINEM FROM SEC_MON " + ;
        "WHERE TOKEN = " + GEBDBQuote(cTok) + " AND D_E_L_E_T_ = ' '"
    )

    If Len(aHit) > 0
        oRow := aHit[1]
        If oRow:USUARIO == Nil
            cUsu := ""
        Else
            cUsu := AllTrim(oRow:USUARIO)
        EndIf
        If oRow:GEI_AUDIT_EMPRESA == Nil
            cEmp := ""
        Else
            cEmp := AllTrim(oRow:GEI_AUDIT_EMPRESA)
        EndIf
        If oRow:GEI_AUDIT_FILIAL == Nil
            cFil := ""
        Else
            cFil := AllTrim(oRow:GEI_AUDIT_FILIAL)
        EndIf
        If oRow:IP == Nil
            cIp := ""
        Else
            cIp := AllTrim(oRow:IP)
        EndIf
        If oRow:LOGINEM == Nil
            cLoginEm := ""
        Else
            cLoginEm := AllTrim(oRow:LOGINEM)
        EndIf
        cSql := "UPDATE SEC_MON SET ULTIMAACAO = " + GEBDBQuote(cDataH) + ", ROTINA = " + GEBDBQuote(cRot) + " " + ;
               "WHERE TOKEN = " + GEBDBQuote(cTok) + " AND D_E_L_E_T_ = ' '"
        TCSqlExec(cSql)
    Else
        lIns := .T.
        cSql := "INSERT INTO SEC_MON (D_E_L_E_T_, TOKEN, USUARIO, EMPRESA, FILIAL, IP, LOGINEM, ULTIMAACAO, ROTINA, MEMORIAUSADA) " + ;
               "VALUES (' ', " + GEBDBQuote(cTok) + ", " + GEBDBQuote(cUsu) + ", " + GEBDBQuote(cEmp) + ", " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cIp) + ", " + GEBDBQuote(cDataH) + ", " + GEBDBQuote(cDataH) + ", " + GEBDBQuote(cRot) + ", 0)"
        TCSqlExec(cSql)
    EndIf

    If lIns
        cInsFlag := "SIM"
    Else
        cInsFlag := "NAO"
    EndIf
    ConOut("GEBMON_ATUALIZA token=" + cTok + " rotina=" + cRot + " ins=" + cInsFlag)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return

// ============================================================
// GEBMONLISTAR
// ============================================================

/*/{Protheus.doc} GEBMONLISTAR
    Lista todos os usuarios monitorados.
    Usa GEBEXPCONTEXT para filtrar por empresa do admin
    (ADMIN pode ver todas as empresas).
    @type Listagem de monitoramento
    @author Peder Munksgaard
    @since 23/09/2026
    @return Array {token, usuario, empresa, filial, ip, loginem, tempoconectado, min, ultimaacao, rotina}
/*/
User Function GEBMONLISTAR()
    Local aArea      := GetArea()
    Local aRet       := {}
    Local aCtx       := {}
    Local cEmpCtx    := ""
    Local cPerfil    := ""
    Local aHit     := {}
    Local oRow     := Nil
    Local nIdx     := 0
    Local cToken     := ""
    Local cUsu       := ""
    Local cEmp       := ""
    Local cFil       := ""
    Local cIp        := ""
    Local cLoginEm   := ""
    Local cUltima    := ""
    Local cRotina    := ""
    Local nDiaIni    := 0
    Local nHoraIni   := 0
    Local nMinIni    := 0
    Local nTotIni    := 0
    Local nDiaFim    := 0
    Local nHoraFim   := 0
    Local nMinFim    := 0
    Local nTotFim    := 0
    Local nMinConn   := 0
    Local cDataH     := ""
    Local lAdmin     := .F.

    // Garante GEH/GEX existentes (delegado a GEXBINIT, ja portado para Postgres).
    GEXBINIT()

    aCtx := GEBEXPCONTEXT_GET()
    If Len(aCtx) >= 1 .And. aCtx[1] != Nil
        cEmpCtx := AllTrim(aCtx[1])
    Else
        cEmpCtx := ""
    EndIf

    // Verifica se eh ADMIN.
    If cEmpCtx != ""
        aHit := TCSqlQuery( ;
            "SELECT GE2_PERFIL FROM GE2 WHERE GE2_COD = " + GEBDBQuote(cEmpCtx) + " AND D_E_L_E_T_ = ' ' LIMIT 1"
        )
        If Len(aHit) > 0
            oRow := aHit[1]
            If oRow:GE2_PERFIL == Nil
                cPerfil := ""
            Else
                cPerfil := AllTrim(oRow:GE2_PERFIL)
            EndIf
            If Upper(cPerfil) == "ADMIN"
                lAdmin := .T.
            EndIf
        EndIf
    EndIf

    // Busca todos os monitorados.
    If lAdmin
        aHit := TCSqlQuery( ;
            "SELECT TOKEN, USUARIO, EMPRESA, FILIAL, IP, LOGINEM, ULTIMAACAO, ROTINA " + ;
            "FROM SEC_MON WHERE D_E_L_E_T_ = ' ' ORDER BY LOGINEM DESC"
        )
    Else
        aHit := TCSqlQuery( ;
            "SELECT TOKEN, USUARIO, EMPRESA, FILIAL, IP, LOGINEM, ULTIMAACAO, ROTINA " + ;
            "FROM SEC_MON WHERE D_E_L_E_T_ = ' ' AND EMPRESA = " + GEBDBQuote(cEmpCtx) + " ORDER BY LOGINEM DESC"
        )
    EndIf

    cDataH := DToS(Date()) + " " + Time()
    nDiaFim  := Val(SubStr(cDataH, 7, 2))
    nHoraFim := Val(SubStr(cDataH, 10, 2))
    nMinFim  := Val(SubStr(cDataH, 13, 2))
    nTotFim  := nDiaFim * 1440 + nHoraFim * 60 + nMinFim

    For nIdx := 1 To Len(aHit)
        oRow     := aHit[nIdx]
        If oRow:TOKEN == Nil
            cToken := ""
        Else
            cToken := AllTrim(oRow:TOKEN)
        EndIf
        If oRow:USUARIO == Nil
            cUsu := ""
        Else
            cUsu := AllTrim(oRow:USUARIO)
        EndIf
        If oRow:GEI_AUDIT_EMPRESA == Nil
            cEmp := ""
        Else
            cEmp := AllTrim(oRow:GEI_AUDIT_EMPRESA)
        EndIf
        If oRow:GEI_AUDIT_FILIAL == Nil
            cFil := ""
        Else
            cFil := AllTrim(oRow:GEI_AUDIT_FILIAL)
        EndIf
        If oRow:IP == Nil
            cIp := ""
        Else
            cIp := AllTrim(oRow:IP)
        EndIf
        If oRow:LOGINEM == Nil
            cLoginEm := ""
        Else
            cLoginEm := AllTrim(oRow:LOGINEM)
        EndIf
        If oRow:ULTIMAACAO == Nil
            cUltima := ""
        Else
            cUltima := AllTrim(oRow:ULTIMAACAO)
        EndIf
        If oRow:ROTINA == Nil
            cRotina := ""
        Else
            cRotina := AllTrim(oRow:ROTINA)
        EndIf

        If cLoginEm != "" .And. Len(cLoginEm) >= 13
            nDiaIni  := Val(SubStr(cLoginEm, 7, 2))
            nHoraIni := Val(SubStr(cLoginEm, 10, 2))
            nMinIni  := Val(SubStr(cLoginEm, 13, 2))
            nTotIni  := nDiaIni * 1440 + nHoraIni * 60 + nMinIni
            nMinConn := nTotFim - nTotIni
            If nMinConn < 0
                nMinConn := 0
            EndIf
        Else
            nMinConn := 0
        EndIf

        AAdd(aRet, {cToken, cUsu, cEmp, cFil, cIp, cLoginEm, nMinConn, cUltima, cRotina})
    Next nIdx

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

// ============================================================
// GEBMONDESLIGAR
// ============================================================

/*/{Protheus.doc} GEBMONDESLIGAR
    Remove da SEC_MON e encerra sessao via GEBSECTOKENDEL.
    @type Desconexao forcada
    @author Peder Munksgaard
    @since 23/09/2026
    @param cToken Token da sessao a desligar
    @return .T. se sucesso, .F. se token invalido
/*/
User Function GEBMONDESLIGAR(cToken)
    Local aArea  := GetArea()
    Local lOk    := .F.
    Local cTok   := ""
    Local cSql   := ""

    If cToken == Nil
        cTok := ""
    Else
        cTok := AllTrim(cToken)
    EndIf

    If cTok == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    cSql := "UPDATE SEC_MON SET D_E_L_E_T_ = '*' WHERE TOKEN = " + GEBDBQuote(cTok) + " AND D_E_L_E_T_ = ' '"
    TCSqlExec(cSql)
    ConOut("GEBMON_DESLIGAR: removido da SEC_MON token=" + cTok)

    lOk := GEBSECTOKENDEL(cTok)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

// ============================================================
// GEBMONMETRICAS
// ============================================================

/*/{Protheus.doc} GEBMONMETRICAS
    Calcula metricas em tempo real.
    @type Metricas de monitoramento
    @author Peder Munksgaard
    @since 23/09/2026
    @return Object {nUsuariosOnline, nEmpresasAtivas, nReqPorSeg, gargalos}
/*/
User Function GEBMONMETRICAS()
    Local aArea      := GetArea()
    Local oRet       := Nil
    Local aAtivas    := {}
    Local oRow       := Nil
    Local nIdx       := 0
    Local nOnline    := 0
    Local aEmps      := {}
    Local nEmps      := 0
    Local cDataH     := ""
    Local cUltima    := ""
    Local nDia       := 0
    Local nHora      := 0
    Local nMin       := 0
    Local nTot       := 0
    Local nTotA      := 0
    Local aGargalos  := {}
    Local aHitMon    := {}
    Local nMinMon    := 0
    Local nTotalMon  := 0
    Local nReqSeg    := 0.0

    cDataH := DToS(Date()) + " " + Time()
    nDia   := Val(SubStr(cDataH, 7, 2))
    nHora  := Val(SubStr(cDataH, 10, 2))
    nMin   := Val(SubStr(cDataH, 13, 2))
    nTotA  := nDia * 1440 + nHora * 60 + nMin

    aAtivas := TCSqlQuery( ;
        "SELECT TOK_TOKEN, TOK_USUARIO, TOK_EMPRESA, TOK_CREATED " + ;
        "FROM GE2_TOK WHERE D_E_L_E_T_ = ' ' AND TOK_EXPIRES > " + GEBDBQuote(DToS(Date())) + ""
    )
    nOnline := Len(aAtivas)

    For nIdx := 1 To nOnline
        oRow := aAtivas[nIdx]
        If oRow:TOK_EMPRESA != Nil
            AAdd(aEmps, AllTrim(oRow:TOK_EMPRESA))
        EndIf
    Next nIdx
    aEmps := GEBMONUNICO(aEmps)
    nEmps := Len(aEmps)

    aHitMon := TCSqlQuery( ;
        "SELECT TOKEN, USUARIO, ULTIMAACAO FROM SEC_MON WHERE D_E_L_E_T_ = ' '"
    )
    nTotalMon := Len(aHitMon)
    For nIdx := 1 To nTotalMon
        oRow := aHitMon[nIdx]
        If oRow:ULTIMAACAO == Nil
            cUltima := ""
        Else
            cUltima := AllTrim(oRow:ULTIMAACAO)
        EndIf
        If cUltima != "" .And. Len(cUltima) >= 13
            nDia  := Val(SubStr(cUltima, 7, 2))
            nHora := Val(SubStr(cUltima, 10, 2))
            nMin  := Val(SubStr(cUltima, 13, 2))
            nTot  := nDia * 1440 + nHora * 60 + nMin
            nMinMon := nTotA - nTot
            If nMinMon > 30
                AAdd(aGargalos, {oRow:TOKEN, oRow:USUARIO, cUltima, nMinMon})
            EndIf
        EndIf
    Next nIdx

    If nTotalMon > 0
        nReqSeg := nTotalMon / 3600.0
    Else
        nReqSeg := 0.0
    EndIf

    oRet := {}
    // Retorna array ao invés de object para evitar problema de persistencia
    // de propriedades dinamicas no runtime AdvPP.
    Local aRetMet := {}
    AAdd(aRetMet, nOnline)       // [1] nUsuariosOnline
    AAdd(aRetMet, nEmps)        // [2] nEmpresasAtivas
    AAdd(aRetMet, nReqSeg)      // [3] nReqPorSeg
    AAdd(aRetMet, aGargalos)    // [4] gargalos
    AAdd(aRetMet, nTotalMon)    // [5] nTotalMonitorados

    ConOut("GEBMON_METRICAS: online=" + cValToChar(nOnline) + " emps=" + cValToChar(nEmps) + " garg=" + cValToChar(Len(aGargalos)))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRetMet

// ============================================================
// Helper: GEBMONUNICO
// ============================================================

/*/{Protheus.doc} GEBMONUNICO
    Remove duplicatas de array de strings.
    @type Auxiliar
    @author Peder Munksgaard
    @since 23/09/2026
    @param aArr Array de strings
    @return Array unico
/*/
Static Function GEBMONUNICO(aArr)
    Local aArea  := GetArea()
    Local aUni   := {}
    Local nIdx   := 0
    Local cVal   := ""
    Local lEncontrou := .F.
    Local nJdx   := 0

    For nIdx := 1 To Len(aArr)
        cVal := AllTrim(aArr[nIdx])
        If cVal == ""
            Continue
        EndIf
        lEncontrou := .F.
        If Len(aUni) > 0
            For nJdx := 1 To Len(aUni)
                If aUni[nJdx] == cVal
                    lEncontrou := .T.
                    Exit
                EndIf
            Next nJdx
        EndIf
        If !lEncontrou
            AAdd(aUni, cVal)
        EndIf
    Next nIdx

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aUni

// ============================================================
// GEBMONROTINA
// ============================================================

/*/{Protheus.doc} GEBMONROTINA
    Retorna o nome da rotina em execucao para o token informado.
    Busca em SEC_MON.
    @type Consulta de rotina
    @author Peder Munksgaard
    @since 23/09/2026
    @param cToken Token da sessao
    @return cRotina Nome da rotina ("" se nao encontrado)
/*/
User Function GEBMONROTINA(cToken)
    Local aArea   := GetArea()
    Local cTok    := ""
    Local cRot    := ""
    Local aHit    := {}
    Local oRow    := Nil

    If cToken == Nil
        cTok := ""
    Else
        cTok := AllTrim(cToken)
    EndIf

    If cTok == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return ""
    EndIf

    aHit := TCSqlQuery( ;
        "SELECT ROTINA FROM SEC_MON WHERE TOKEN = " + GEBDBQuote(cTok) + " AND D_E_L_E_T_ = ' ' LIMIT 1"
    )

    If Len(aHit) > 0
        oRow := aHit[1]
        If oRow:ROTINA == Nil
            cRot := ""
        Else
            cRot := AllTrim(oRow:ROTINA)
        EndIf
    Else
        cRot := ""
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return cRot
