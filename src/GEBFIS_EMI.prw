#include "totvs.ch"
#include "GEBDB_CORE.prw"
#include "GEBAUD.prw"

/*/{Protheus.doc} GEBFIS_EMI
    Emissao fiscal ONLINE_FILA + split (Task 3 GEB_FISCAL).
    Mapeamento 1:1 com as interfaces do plano (chamadas sem prefixo U_):
    U_GEBFEMI -> GEBFEMI | U_GEBFSPL -> GEBFSPL. O prefixo U_ nao e usado
    nas chamadas porque o runtime AdvPP so resolve U_ em
    StartJob/FindFunction; chamada direta U_X() da "unknown function".
    GEBFEMI(cChave, cCod, nQtd, nPreco) emite NF-e/NFS-e:
    intercept GEBMNT("EMISSAO") (trava => EM_FILA + fila); modo via
    GEBCFG("EMISSAO") (ONLINE_PURO/ONLINE_FILA/SO_FILA, miss => ONLINE_FILA);
    produto via GEBFPRO(cCod) + aliquotas via GEBFALI(NCM) (miss => {0,0});
    base = nQtd * nPreco; impostos via CALCIBS(base, IBS, CBS);
    mock SEFAZ: autoriza se base > 0 (SO_FILA forca fila sem tentar);
    grava GF3 header (TIPO NFE, STATUS, EMIS DToS(Date())) + GF4 item
    (ITEM 001); em todos os casos gera o titulo a receber do CONSUMIDOR
    a vista e a receita (VENDA_RECEITA); EM_FILA => GEBFILA (exceto
    ONLINE_PURO puro, que retorna sem enfileirar). Nota em fila nao entra
    na apuracao do IBS/CBS ate ser autorizada.
    GEBFSPL(nTotal, nPartes) divide o valor em parcelas (ultima ajusta
    por diferenca para soma exata); nPartes <= 0 => {nTotal}.
    Notas AdvPP (balisador, ver registro interno):
    log via ConOut (FWLogMsg nao existe no runtime); If Nil em vez
    de Default (Default sobrescreve incondicionalmente);
    GetArea/RestArea guardados (GetArea retorna "" sem workarea
    aberta; RestArea("") aborta); leitura via workarea porque
    BeginSql standalone e no-op no pre-processador; guarda de
    existencia via TCSqlQuery em pg_tables (Select() e Used()
    sao stubs que sempre retornam 0/.F.); escrita via workarea usa
    DbAppend() + RecLock(.T.) (DbAppend puro nao persiste, RecLock
    sozinho aborta em tabela vazia); FWxFilial retorna 6 espacos
    sem RpcSetEnv.
    @type Modulo de emissao
    @author Peder Munksgaard
    @since 23/09/2026
    @param cChave Chave da NF em GF3/GF4/GE5 (GEBFEMI)
    @param cCod Codigo do produto em GF1 (GEBFEMI)
    @param nQtd Quantidade do item (GEBFEMI)
    @param nPreco Preco unitario do item (GEBFEMI)
    @param nTotal Valor total a dividir (GEBFSPL)
    @param nPartes Numero de parcelas (GEBFSPL)
    @return Status AUTORIZADA ou EM_FILA (GEBFEMI); array de parcelas (GEBFSPL)
/*/
User Function GEBFEMI(cChave, cCod, nQtd, nPreco)
    Local aArea := GetArea()
    Local cModo := ""
    Local lLib := .T.
    Local aProd := {}
    Local cNCM := ""
    Local aTaxa := {0, 0}
    Local nBase := 0
    Local aCalc := {0, 0}
    Local nIBS := 0
    Local nCBS := 0
    Local cStatus := "EM_FILA"
    Local lAutoriza := .F.

    If cChave == Nil
        cChave := ""
    EndIf
    If cCod == Nil
        cCod := ""
    EndIf
    If nQtd == Nil
        nQtd := 0
    EndIf
    If nPreco == Nil
        nPreco := 0
    EndIf

    // Intercept do mentor: trava => forca fila.
    lLib := GEBMNT("EMISSAO")

    // Modo de emissao via GEBCFG; miss => ONLINE_FILA.
    cModo := GEBCFG("EMISSAO")
    If cModo == ""
        cModo := "ONLINE_FILA"
    EndIf

    // Produto + aliquotas (miss => base tributada a zero).
    aProd := GEBFPRO(cCod)
    If Len(aProd) == 3
        cNCM := aProd[2]
    EndIf
    aTaxa := GEBFALI(cNCM, DToS(Date()))
    If Len(aTaxa) < 2
        aTaxa := {0, 0}
    EndIf

    nBase := nQtd * nPreco
    aCalc := CALCIBS(nBase, aTaxa[1], aTaxa[2])
    nIBS := aCalc[1]
    nCBS := aCalc[2]

    // Mock SEFAZ: autoriza se base > 0. SO_FILA nem tenta.
    lAutoriza := (nBase > 0)
    If cModo == "SO_FILA"
        lAutoriza := .F.
    EndIf
    If !lLib
        lAutoriza := .F.
    EndIf

    If lAutoriza
        cStatus := "AUTORIZADA"
    Else
        cStatus := "EM_FILA"
    EndIf

    // Guardas: GF3/GF4 podem nao existir (GEBFMIG ainda nao rodou).
    If !GEBDBTableExistsHere("GF3")
        GEBFILA(cChave, cChave)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return "EM_FILA"
    EndIf
    If !GEBDBTableExistsHere("GF4")
        GEBFILA(cChave, cChave)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return "EM_FILA"
    EndIf

    GrvGF3(cChave, nBase, nIBS, nCBS, cStatus)
    GrvGF4(cChave, cCod, nQtd, nPreco, nBase, nIBS, nCBS)

    // Audit: log insercao GF3.
    GBAUDLOG("GF3", "INS", cChave, "USER", "01", "      ")

    If cStatus == "AUTORIZADA"
        FISFinanceiro(cChave, nBase)
        ConOut("EMI AUTORIZADA " + cChave)
    Else
        // ONLINE_PURO e puro: falha sem enfileirar. Demais modos + trava enfileiram.
        If cModo == "ONLINE_PURO" .AND. lLib
            FISFinanceiro(cChave, nBase)
            ConOut("EMI EM_FILA puro " + cChave)
        Else
            GEBFILA(cChave, cChave)
            FISFinanceiro(cChave, nBase)
            ConOut("EMI EM_FILA " + cChave)
        EndIf
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return cStatus

User Function GEBFSPL(nTotal, nPartes)
    Local aParc := {}
    Local nVlr := 0
    Local nSoma := 0
    Local nI := 0

    If nTotal == Nil
        nTotal := 0
    EndIf
    If nPartes == Nil
        nPartes := 1
    EndIf
    If nPartes <= 0
        ConOut("SPL " + cValToChar(nTotal) + " x1")
        Return {nTotal}
    EndIf

    nVlr := nTotal / nPartes
    nSoma := 0
    For nI := 1 To nPartes
        If nI < nPartes
            aAdd(aParc, nVlr)
            nSoma := nSoma + nVlr
        Else
            aAdd(aParc, nTotal - nSoma)
        EndIf
    Next

    ConOut("SPL " + cValToChar(nTotal) + " x" + cValToChar(nPartes))
Return aParc

// Nota de venda: titulo a receber do CONSUMIDOR a vista e receita
// (VENDA_RECEITA: D clientes / C receita). Reemissao da mesma chave nao
// duplica o titulo nem a receita.
Static Function FISFinanceiro(cChave, nBase)
    Local aR := {}
    If nBase <= 0
        Return .F.
    EndIf
    aR := GEBFXTIT("R", cChave, "CONSUMIDOR", nBase, "", BOHOJE(), "NOTA " + cChave, "")
    If !aR[1]
        ConOut("EMI titulo nao gerado " + cChave + " " + aR[2])
        Return .F.
    EndIf
    GEBCTXLP("VENDA_RECEITA", nBase, cChave, BOHOJE())
Return .T.

Static Function GrvGF3(cChave, nBase, nIBS, nCBS, cStatus)
    Local cFil := FWxFilial("GF3")
    Local cEmis := DToS(Date())

    DbSelectArea("GF3")
    DbAppend()
    RecLock("GF3", .T.)
    GF3->GF3_FILIAL := cFil
    GF3->D_E_L_E_T_ := " "
    GF3->GF3_CHAVE := cChave
    GF3->GF3_TIPO := "NFE"
    GF3->GF3_STATUS := cStatus
    GF3->GF3_BASE := nBase
    GF3->GF3_IBS := nIBS
    GF3->GF3_CBS := nCBS
    GF3->GF3_EMIS := cEmis
    MsUnlock()
    DbCloseArea()
Return .T.

Static Function GrvGF4(cChave, cCod, nQtd, nPreco, nBase, nIBS, nCBS)
    Local cFil := FWxFilial("GF4")

    DbSelectArea("GF4")
    DbAppend()
    RecLock("GF4", .T.)
    GF4->GF4_FILIAL := cFil
    GF4->D_E_L_E_T_ := " "
    GF4->GF4_CHAVE := cChave
    GF4->GF4_ITEM := "001"
    GF4->GF4_PROD := cCod
    GF4->GF4_QTD := nQtd
    GF4->GF4_PRECO := nPreco
    GF4->GF4_BASE := nBase
    GF4->GF4_IBS := nIBS
    GF4->GF4_CBS := nCBS
    MsUnlock()
    DbCloseArea()
Return .T.
