#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBFIS_APU
    Apuracao fiscal AUTO/MANUAL/DIRETA + creditos (Task 4 GEB_FISCAL).
    Mapeamento 1:1 com as interfaces do plano (chamadas sem prefixo U_):
    U_GEBFAPU -> GEBFAPU | U_GEBFCRE -> GEBFCRE. O prefixo U_ nao e usado
    nas chamadas porque o runtime AdvPP so resolve U_ em
    StartJob/FindFunction; chamada direta U_X() da "unknown function".
    GEBFAPU(cComp) apura o IBS/CBS do mes (competencia YYYYMM) e grava
    GF5: GF5_DEB = IBS + CBS dos itens GF4 de notas AUTORIZADA emitidas no
    mes (cancelada e em fila nao contam) menos o IBS/CBS das devolucoes de
    venda do mes (GFT7, proporcional a base do item de origem); GF5_CRED =
    IBS + CBS das entradas de compra do mes (GCQ7); GF5_SALDO = DEB - CRED;
    GF5_REGIME = GEBREGIME(). No regime REGULAR lanca a provisao do saldo
    pela diferenca (APU_IBSCBS: D 3.02.002 / C 2.01.004) e gera/atualiza a
    guia da Derrama (GEBDGER). No Simples o IBS/CBS vai no DAS: so' grava
    GF5.
    Modo via GEBCFG("APURACAO") (AUTO/MANUAL/DIRETA, miss => AUTO):
    a chamada direta ja e o ato manual, por isso os tres modos gravam;
    diferem so no log ConOut. Linhas GF5 anteriores da mesma competencia
    sao baixadas (D_E_L_E_T_ := "*") antes do insert (idempotencia por
    competencia sem concatenar SQL). Retorna .F. se GF3/GF4/GF5
    ausentes (guarda pg_tables antes de DbSelectArea, que aborta
    em tabela ausente).
    GEBFCRE(cComp, cOrig, nValor, cTipo) grava GF6 (transf/ressarc:
    cTipo TRANSF ou RESSARC, miss => TRANSF) com filial da sessao e
    D_E_L_E_T_ = ' '; retorna .F. se GF6 ausente.
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
    @type Modulo de apuracao
    @author Peder Munksgaard
    @since 23/09/2026
    @param cComp Competencia YYYYMM (GEBFAPU/GEBFCRE)
    @param cOrig Origem do credito em GF6 (GEBFCRE)
    @param nValor Valor do credito em GF6 (GEBFCRE)
    @param cTipo TRANSF ou RESSARC (GEBFCRE)
    @return .T. se apurou/gravou, .F. se tabelas ausentes (ambas)
/*/
User Function GEBFAPU(cComp)
    Local aArea := GetArea()
    Local cModo := ""
    Local cRegime := "REGULAR"
    Local nDeb := 0
    Local nCred := 0
    Local nSaldo := 0

    If cComp == Nil
        cComp := ""
    EndIf

    // Guardas: GF3/GF4/GF5 podem nao existir (GEBFMIG ainda nao rodou).
    // DbSelectArea em tabela ausente aborta o runtime, entao retorna
    // .F. aqui antes de abrir.
    If !GEBDBTableExistsHere("GF3")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If !GEBDBTableExistsHere("GF4")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If !GEBDBTableExistsHere("GF5")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    // Modo de apuracao via GEBCFG; miss => AUTO.
    cModo := GEBCFG("APURACAO")
    If cModo == ""
        cModo := "AUTO"
    EndIf

    // Regime unico da empresa (GEBREGIME).
    cRegime := GEBREGIME()

    // Debito: IBS + CBS das notas AUTORIZADA da competencia (cancelada e em
    // fila nao contam), menos as devolucoes de venda do mes. Credito: IBS +
    // CBS das entradas de compra do mes (GCQ7).
    nDeb := Round(ApuDebito(cComp) - ApuDevol(cComp), 2)
    nCred := Round(ApuCredito(cComp), 2)
    nSaldo := Round(nDeb - nCred, 2)

    If cModo == "MANUAL"
        ConOut("APU MANUAL " + cComp + " " + cRegime)
    Else
        If cModo == "DIRETA"
            ConOut("APU DIRETA " + cComp + " " + cRegime)
        Else
            ConOut("APU AUTO " + cComp + " " + cRegime)
        EndIf
    EndIf

    BaixaGF5(cComp)
    GrvGF5(cComp, nDeb, nCred, nSaldo, cRegime)

    ConOut("APU " + cComp + " DEB " + cValToChar(nDeb))

    // Regime REGULAR: provisao do saldo (pela diferenca) e guia da Derrama.
    // No Simples o IBS/CBS vai dentro do DAS.
    If cRegime == "REGULAR"
        GEBDERPROV("APU_IBSCBS", "GD" + cComp, Max(nSaldo, 0), BOFIMMES(cComp), "", "")
        GEBDGER(cComp)
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function GEBFCRE(cComp, cOrig, nValor, cTipo)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GF6")

    If cComp == Nil
        cComp := ""
    EndIf
    If cOrig == Nil
        cOrig := ""
    EndIf
    If nValor == Nil
        nValor := 0
    EndIf
    If cTipo == Nil
        cTipo := "TRANSF"
    EndIf
    If !(cTipo == "TRANSF") .AND. !(cTipo == "RESSARC")
        cTipo := "TRANSF"
    EndIf

    // Guarda: GF6 pode nao existir (GEBFMIG ainda nao rodou).
    If !GEBDBTableExistsHere("GF6")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GF6")
    DbAppend()
    RecLock("GF6", .T.)
    GF6->GF6_FILIAL := cFil
    GF6->D_E_L_E_T_ := " "
    GF6->GF6_COMP := cComp
    GF6->GF6_ORIG := cOrig
    GF6->GF6_VALOR := nValor
    GF6->GF6_TIPO := cTipo
    MsUnlock()
    DbCloseArea()

    ConOut("CRE " + cComp + " " + cTipo + " " + cValToChar(nValor))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

// IBS + CBS dos itens de notas AUTORIZADA emitidas na competencia.
Static Function ApuDebito(cComp)
    Local cFil := FWxFilial("GF4")
    Local aHit := TCSqlQuery("SELECT COALESCE(SUM(GF4_IBS + GF4_CBS), 0) AS V FROM GF4 WHERE GF4_FILIAL = " + GEBDBQuote(cFil) + ;
        " AND D_E_L_E_T_ = ' ' AND EXISTS (SELECT 1 FROM GF3 WHERE GF3_FILIAL = GF4_FILIAL AND GF3_CHAVE = GF4_CHAVE AND " + ;
        "GF3_STATUS = 'AUTORIZADA' AND SUBSTR(GF3_EMIS, 1, 6) = " + GEBDBQuote(cComp) + " AND GF3.D_E_L_E_T_ = ' ')")
Return Round(BOVAL(aHit[1]:V), 2)

// IBS + CBS devolvidos nas devolucoes de venda do mes (GFT7), na proporcao do
// valor devolvido sobre a base do item na nota de origem.
Static Function ApuDevol(cComp)
    Local cFil := FWxFilial("GF4")
    Local aHit := {}
    If !GEBDBTableExistsHere("GFT7")
        Return 0
    EndIf
    aHit := TCSqlQuery("SELECT COALESCE(SUM(T.GFT7_VALOR * I.TX / I.BS), 0) AS V FROM GFT7 T JOIN (SELECT GF4_CHAVE AS CH, GF4_PROD AS PR, " + ;
        "SUM(GF4_IBS + GF4_CBS) AS TX, SUM(GF4_BASE) AS BS FROM GF4 WHERE GF4_FILIAL = " + GEBDBQuote(cFil) + " AND D_E_L_E_T_ = ' ' " + ;
        "GROUP BY GF4_CHAVE, GF4_PROD) I ON I.CH = T.GFT7_NOTA AND I.PR = T.GFT7_PROD WHERE T.D_E_L_E_T_ = ' ' AND T.GFT7_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GFT7")) + " AND SUBSTR(T.GFT7_DATA, 1, 6) = " + GEBDBQuote(cComp) + " AND I.BS > 0")
Return Round(BOVAL(aHit[1]:V), 2)

// IBS + CBS das entradas de compra do mes (GCQ7).
Static Function ApuCredito(cComp)
    Local aHit := {}
    If !GEBDBTableExistsHere("GCQ7")
        Return 0
    EndIf
    aHit := TCSqlQuery("SELECT COALESCE(SUM(GCQ7_IBS + GCQ7_CBS), 0) AS V FROM GCQ7 WHERE GCQ7_FILIAL = " + GEBDBQuote(FWxFilial("GCQ7")) + ;
        " AND D_E_L_E_T_ = ' ' AND SUBSTR(GCQ7_DATA, 1, 6) = " + GEBDBQuote(cComp))
Return Round(BOVAL(aHit[1]:V), 2)

Static Function BaixaGF5(cComp)
    Local cFil := FWxFilial("GF5")

    // Idempotencia por competencia: baixa logica das linhas ativas
    // da competencia antes do insert (sem concatenar SQL).
    DbSelectArea("GF5")
    DbGoTop()
    While !Eof()
        If GF5->GF5_FILIAL == cFil .AND. GF5->GF5_COMP == cComp .AND. GF5->D_E_L_E_T_ == " "
            RecLock("GF5", .F.)
            GF5->D_E_L_E_T_ := "*"
            MsUnlock()
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
Return .T.

Static Function GrvGF5(cComp, nDeb, nCred, nSaldo, cRegime)
    Local cFil := FWxFilial("GF5")

    DbSelectArea("GF5")
    DbAppend()
    RecLock("GF5", .T.)
    GF5->GF5_FILIAL := cFil
    GF5->D_E_L_E_T_ := " "
    GF5->GF5_COMP := cComp
    GF5->GF5_DEB := nDeb
    GF5->GF5_CRED := nCred
    GF5->GF5_SALDO := nSaldo
    GF5->GF5_REGIME := cRegime
    MsUnlock()
    DbCloseArea()
Return .T.
