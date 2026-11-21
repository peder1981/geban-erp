#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBFIS_CAD
    Cadastros do fiscal GEBAN (Task 2 GEB_FISCAL): produtos GF1 e
    aliquotas GF2 com vigencia.
    Mapeamento 1:1 com as interfaces do plano (chamadas sem prefixo U_):
    U_GEBFPRO -> GEBFPRO | U_GEBFALI -> GEBFALI. O prefixo U_ nao e usado
    nas chamadas porque o runtime AdvPP so resolve U_ em
    StartJob/FindFunction; chamada direta U_X() da "unknown function".
    GEBFPRO(cCod) le GF1 via workarea e retorna {COD, NCM, DESC} do
    produto na filial da sessao com D_E_L_E_T_ = ' '; retorna {} se
    GF1 ausente ou se o codigo nao existir.
    GEBFALI(cNCM[, dData]) delega para ALIQF(cNCM, dData) de
    GEBFIS_MIG.prw (o teste inclui os dois fontes); sem dData usa a
    data atual via DToS(Date()). Retorna {IBS, CBS} da vigencia que
    contem dData, {0, 0} se GF2 ausente ou sem vigencia valida.
    Notas AdvPP (balisador, ver .superpowers/sdd/task-1-report.md e
    fis1-report.md): log via ConOut (FWLogMsg nao existe no runtime);
    If Nil em vez de Default (Default sobrescreve incondicionalmente);
    GetArea/RestArea guardados (GetArea retorna "" sem workarea
    aberta; RestArea("") aborta); leitura via workarea porque
    BeginSql standalone e no-op no pre-processador; guarda de
    existencia via TCSqlQuery em pg_tables (Select() e Used()
    sao stubs que sempre retornam 0/.F.); escrita via workarea usa
    DbAppend() + RecLock(.T.) (DbAppend puro nao persiste, RecLock
    sozinho aborta em tabela vazia); FWxFilial retorna 6 espacos
    sem RpcSetEnv (truncarFilial preenche ate 6).
    @type Modulo de cadastros
    @author Peder Munksgaard
    @since 23/09/2026
    @param cCod Codigo do produto em GF1 (GEBFPRO)
    @param cNCM NCM buscado em GF2 (GEBFALI)
    @param dData Data de vigencia YYYYMMDD ou Date (GEBFALI, opcional)
    @return Array {COD, NCM, DESC} ou {} (GEBFPRO); array {IBS, CBS} (GEBFALI)
/*/
User Function GEBFPRO(cCod)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GF1")
    Local aDados := {}

    If cCod == Nil
        cCod := ""
    EndIf

    // Guarda: GF1 pode nao existir (GEBFMIG ainda nao rodou).
    // DbSelectArea em tabela ausente aborta o runtime, entao retorna
    // {} aqui antes de abrir.
    If !GEBDBTableExistsHere("GF1")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return aDados
    EndIf

    // Scan sequencial com filtros FILIAL + COD + D_E_L_E_T_.
    // BeginSql standalone e no-op no pre-processador AdvPP,
    // por isso workarea. Primeiro match vence (COD e unico).
    DbSelectArea("GF1")
    DbGoTop()
    While !Eof()
        If GF1->GF1_FILIAL == cFil .AND. GF1->GF1_COD == cCod .AND. GF1->D_E_L_E_T_ == " "
            aDados := {GF1->GF1_COD, GF1->GF1_NCM, GF1->GF1_DESC}
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aDados

User Function GEBFALI(cNCM, dData)
    Local aTaxa := {0, 0}

    If cNCM == Nil
        cNCM := ""
    EndIf
    If dData == Nil
        dData := DToS(Date())
    EndIf

    // Leitura delegada: ALIQF (GEBFIS_MIG.prw) ja implementa o scan
    // de vigencia em GF2 com guarda de existencia, workarea e
    // conversao Date via DToS. Sem duplicar a regra aqui.
    aTaxa := ALIQF(cNCM, dData)
Return aTaxa
