#include "totvs.ch"
#include "GEBDB_CORE.prw"
#include "GEBAUD.prw"

/*/{Protheus.doc} GENUC_MNT
    Mentor GE4 + Fila GE5 + stub CTB_Lanca (Task 4).
    Mapeamento 1:1 com as interfaces do plano (chamadas sem prefixo U_):
    U_GEBMNT -> GEBMNT | U_GEBFILA -> GEBFILA | U_CTBLAN -> CTBLAN.
    O prefixo U_ nao e usado nas chamadas porque o runtime AdvPP so
    resolve U_ em StartJob/FindFunction; chamada direta U_X() da
    "unknown function".
    GEBMNT(cEvento) le o modo em GE4 via GEBCFG (Task 1): AVISA_E_TRAVA
    -> .F.; AVISA_E_LIBERA_COM_BO -> grava GE3 via GEBAUD (Task 3) e
    retorna .T.; DESLIGADO, "" (miss) ou outro -> .T. sem BO. Miss sem
    BO evita trilhas espurias em evento desconhecido (desvio do default
    B do plano, documentado no report).
    GEBFILA(cChave, cPayload) enfileira linha real em GE5 com filial da
    sessao + D_E_L_E_T_ = ' ' + GE5_STATUS = 'PENDENTE' via DbAppend() +
    RecLock("GE5", .T.) + atribuicoes + MsUnlock. O DbAppend() antes
    e obrigatorio: RecLock sozinho aborta ("no current record") em
    tabela vazia. O .T. aqui e append (registro novo), nao lock
    indefinido: UNICO caminho de escrita via workarea que persiste no
    AdvPP (probes Task 3, ver registro interno).
    CTBLAN(cOrigem, nValor) e partida dobrada real: le o param do
    evento em GC4 (com fallback PADRAO), grava GC2 + 2xGC3 via
    CTBGRV com TIPO AUTO e confere debito igual a credito;
    retorna .F. se desbalancear, faltar param ou valor zerado.
    Compat: com GC4 ausente ou sem nenhum param (contabil ainda
    nao migrada/parametrizada) age como o stub antigo (.T., so
    loga), preservando fiscal/derrama/venda.
    CTBGRV(cOrigem, cDeb, cCred, nValor, cTipo) e o writer
    compartilhado (usado pelo CTBLAN e pelo GEBCDIR): gera lote
    sequencial, grava GC2 + perna D + perna C em GC3, confere as
    somas e retorna o lote ("" se falhar).
    Notas AdvPP (balisador, ver registro interno):
    log via ConOut (FWLogMsg nao existe no runtime); If Nil em vez
    de Default (Default sobrescreve incondicionalmente); alias
    literal (GetNextAlias nao existe); GetArea/RestArea guardados
    (GetArea retorna "" sem workarea aberta; RestArea("") aborta);
    sem BeginSql standalone (no-op no pre-processador); sem SELECT *,
    sem concat SQL, sem cFilial, sem IIF.
    @type Modulo do mentor
    @author Peder Munksgaard
    @since 23/09/2026
    @param cEvento Evento do mentor em GE4 (GEBMNT)
    @param cChave Chave da fila em GE5 (GEBFILA)
    @param cPayload Payload da fila em GE5 (GEBFILA)
    @param cOrigem Origem do lancamento (CTBLAN/CTBGRV)
    @param nValor Valor do lancamento (CTBLAN/CTBGRV)
    @param cDeb Conta de debito (CTBGRV)
    @param cCred Conta de credito (CTBGRV)
    @param cTipo Tipo do lote AUTO ou DIRETO (CTBGRV)
    @return .T. liberado/enfileirado/balanceado, .F. travado ou erro
/*/
User Function GEBMNT(cEvento)
    Local aArea := GetArea()
    Local cModo := ""
    Local lLib := .T.

    If cEvento == Nil
        cEvento := "GENERICO"
    EndIf

    cModo := GEBCFG(cEvento)

    If cModo == "AVISA_E_TRAVA"
        lLib := .F.
        ConOut("Mentor travou " + cEvento)
    Else
        If cModo == "AVISA_E_LIBERA_COM_BO"
            GEBAUD("USER", cEvento, "assumiu BO mentor")
            ConOut("Mentor liberou com BO " + cEvento)
        Else
            ConOut("Mentor liberou " + cEvento)
        EndIf
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lLib

User Function GEBFILA(cChave, cPayload)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GE5")
    Local lOk := .T.

    If cChave == Nil
        cChave := ""
    EndIf
    If cPayload == Nil
        cPayload := ""
    EndIf

    // Guarda: GE5 pode nao existir (GENMIG ainda nao rodou).
    If !GEBDBTableExistsHere("GE5")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GE5")
    DbAppend()
    RecLock("GE5", .T.)
    GE5->GE5_FILIAL := cFil
    GE5->D_E_L_E_T_ := " "
    GE5->GE5_CHAVE := cChave
    GE5->GE5_PAYLD := cPayload
    GE5->GE5_STATUS := "PENDENTE"
    MsUnlock()
    DbCloseArea()

    ConOut("FILA " + cChave)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

User Function CTBLAN(cOrigem, nValor)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GC4")
    Local cDeb := ""
    Local cCred := ""
    Local cLote := ""
    Local lOk := .F.
    Local aChk := {}

    If cOrigem == Nil
        cOrigem := ""
    EndIf
    If nValor == Nil
        nValor := 0
    EndIf
    If nValor <= 0
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    // Compat com chamadas antigas: sem GC4 ou sem nenhum param,
    // a contabil ainda nao foi parametrizada e o stub antigo vale.
    If !GEBDBTableExistsHere("GC4")
        ConOut("CTB stub " + cOrigem + " " + cValToChar(nValor))
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .T.
    EndIf
    aChk := TCSqlQuery("SELECT GC4_EVENTO FROM GC4 WHERE D_E_L_E_T_ = ' '")
    If Len(aChk) == 0
        ConOut("CTB stub " + cOrigem + " " + cValToChar(nValor))
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .T.
    EndIf

    // Param do evento via workarea; fallback PADRAO; falta recusa.
    DbSelectArea("GC4")
    DbGoTop()
    While !Eof()
        If GC4->GC4_FILIAL == cFil .AND. GC4->GC4_EVENTO == cOrigem .AND. GC4->D_E_L_E_T_ == " "
            cDeb := GC4->GC4_CTADEB
            cCred := GC4->GC4_CTACRED
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If cDeb == ""
        DbSelectArea("GC4")
        DbGoTop()
        While !Eof()
            If GC4->GC4_FILIAL == cFil .AND. GC4->GC4_EVENTO == "PADRAO" .AND. GC4->D_E_L_E_T_ == " "
                cDeb := GC4->GC4_CTADEB
                cCred := GC4->GC4_CTACRED
                Exit
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    If cDeb == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If cCred == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    cLote := CTBGRV(cOrigem, cDeb, cCred, nValor, "AUTO")
    lOk := (cLote != "")

    // Audit: log lancamento GC3.
    If lOk
        GBAUDLOG("GC3", "INS", cLote, "USER", "01", "      ")
    EndIf

    ConOut("CTB " + cOrigem + " " + cValToChar(nValor))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

User Function CTBGRV(cOrigem, cDeb, cCred, nValor, cTipo)
    Local aArea := GetArea()
    Local cLote := ""
    Local cData := DToS(Date())
    Local cComp := SubStr(cData, 1, 6)
    Local cFil2 := FWxFilial("GC2")
    Local cFil3 := FWxFilial("GC3")
    Local nDeb := 0
    Local nCred := 0

    If cOrigem == Nil
        cOrigem := ""
    EndIf
    If cDeb == Nil
        cDeb := ""
    EndIf
    If cCred == Nil
        cCred := ""
    EndIf
    If nValor == Nil
        nValor := 0
    EndIf
    If cTipo == Nil
        cTipo := "AUTO"
    EndIf
    If cDeb == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return ""
    EndIf
    If cCred == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return ""
    EndIf
    If nValor <= 0
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return ""
    EndIf

    // Guardas: GC2/GC3 podem nao existir (GEBCMIG ainda nao rodou).
    If !GEBDBTableExistsHere("GC2")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return ""
    EndIf
    If !GEBDBTableExistsHere("GC3")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return ""
    EndIf

    cLote := NovoLote()

    DbSelectArea("GC2")
    DbAppend()
    RecLock("GC2", .T.)
    GC2->GC2_FILIAL := cFil2
    GC2->D_E_L_E_T_ := " "
    GC2->GC2_LOTE := cLote
    GC2->GC2_ORIGEM := cOrigem
    GC2->GC2_VALOR := nValor
    GC2->GC2_DATA := cData
    GC2->GC2_COMP := cComp
    GC2->GC2_TIPO := cTipo
    MsUnlock()
    DbCloseArea()

    DbSelectArea("GC3")
    DbAppend()
    RecLock("GC3", .T.)
    GC3->GC3_FILIAL := cFil3
    GC3->D_E_L_E_T_ := " "
    GC3->GC3_LOTE := cLote
    GC3->GC3_DC := "D"
    GC3->GC3_CONTA := cDeb
    GC3->GC3_VALOR := nValor
    MsUnlock()
    DbCloseArea()

    DbSelectArea("GC3")
    DbAppend()
    RecLock("GC3", .T.)
    GC3->GC3_FILIAL := cFil3
    GC3->D_E_L_E_T_ := " "
    GC3->GC3_LOTE := cLote
    GC3->GC3_DC := "C"
    GC3->GC3_CONTA := cCred
    GC3->GC3_VALOR := nValor
    MsUnlock()
    DbCloseArea()

    // Conferencia: debito gravado igual a credito gravado.
    DbSelectArea("GC3")
    DbGoTop()
    While !Eof()
        If GC3->GC3_FILIAL == cFil3 .AND. GC3->GC3_LOTE == cLote .AND. GC3->D_E_L_E_T_ == " "
            If GC3->GC3_DC == "D"
                nDeb := nDeb + GC3->GC3_VALOR
            EndIf
            If GC3->GC3_DC == "C"
                nCred := nCred + GC3->GC3_VALOR
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If nDeb != nCred
        ConOut("CTB desbalanceado " + cLote)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return ""
    EndIf

    ConOut("CTBGRV " + cLote + " " + cTipo)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return cLote

Static Function NovoLote()
    Local aAll := {}
    Local cLote := ""

    aAll := TCSqlQuery("SELECT GC2_LOTE FROM GC2 WHERE D_E_L_E_T_ = ' '")
    cLote := "L" + cValToChar(Len(aAll) + 1)
Return cLote
