#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBCTB_DIR
    Lancamento direto da contabilidade GEBAN (Task 3 GEB_CONTABIL).
    Mapeamento 1:1 com a interface do plano (chamada sem prefixo U_):
    U_GEBCDIR -> GEBCDIR. O prefixo U_ nao e usado na chamada porque
    o runtime AdvPP so resolve U_ em StartJob/FindFunction; chamada
    direta U_X() da "unknown function".
    GEBCDIR(cContaD, cContaC, nValor[, cUser]) grava lote direto
    via CTBGRV com TIPO DIRETO (carimbo) so se todas as travas
    liberarem: GEBCFG("PERMITE_DIRETA") == "S"; GEBUSR(cUser)
    autoriza o perfil (CAIXA so com a flag S, demais perfis
    liberados, miss nega); GC4 LANC_DIRETO com PERM N nega
    (linha ausente = sem restricao extra); GEBMNT("LANC_DIRETO")
    libera (AVISA_E_TRAVA nega). Contas vazias, valor zerado ou
    falha do writer retornam .F.
    Notas AdvPP (balisador, ver .superpowers/sdd/task-1-report.md):
    log via ConOut (FWLogMsg nao existe no runtime); If Nil em vez
    de Default (Default sobrescreve incondicionalmente); alias
    literal (GetNextAlias nao existe); GetArea/RestArea guardados
    (GetArea retorna "" sem workarea aberta; RestArea("") aborta);
    leitura via workarea porque BeginSql standalone e no-op no
    pre-processador; guarda de existencia via TCSqlQuery em
    pg_tables (Select() e Used() sao stubs); SQL so com
    literais (sem concat, sem SELECT estrela); sem cFilial, sem
    IIF; so User/Static Function.
    @type Modulo de lancamento direto
    @author Peder Munksgaard
    @since 23/09/2026
    @param cContaD Conta de debito
    @param cContaC Conta de credito
    @param nValor Valor do lancamento
    @param cUser Codigo do usuario em GE2 (opcional, miss nega)
    @return .T. se gravou direto, .F. se alguma trava negou
/*/
User Function GEBCDIR(cContaD, cContaC, nValor, cUser)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GC4")
    Local cLote := ""
    Local lOk := .F.
    Local lTem := .F.
    Local cPerm := ""

    If cContaD == Nil
        cContaD := ""
    EndIf
    If cContaC == Nil
        cContaC := ""
    EndIf
    If nValor == Nil
        nValor := 0
    EndIf
    If cUser == Nil
        cUser := ""
    EndIf
    If cContaD == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If cContaC == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If nValor <= 0
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    // Trava 1: flag global PERMITE_DIRETA em GE4 via GEBCFG.
    If GEBCFG("PERMITE_DIRETA") != "S"
        ConOut("DIR negado flag")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    // Trava 2: perfil do usuario em GE2 via GEBUSR.
    If !GEBUSR(cUser)
        ConOut("DIR negado perfil " + cUser)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    // Trava 3: GC4 LANC_DIRETO com PERM N nega (ausente libera).
    If GEBDBTableExistsHere("GC4")
        DbSelectArea("GC4")
        DbGoTop()
        While !Eof()
            If GC4->GC4_FILIAL == cFil .AND. GC4->GC4_EVENTO == "LANC_DIRETO" .AND. GC4->D_E_L_E_T_ == " "
                lTem := .T.
                cPerm := GC4->GC4_PERM
                Exit
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
        If lTem
            If cPerm != "S"
                ConOut("DIR negado GC4")
                If Len(aArea) > 0
                    RestArea(aArea)
                EndIf
                Return .F.
            EndIf
        EndIf
    EndIf

    // Trava 4: mentor LANC_DIRETO (trava nega, miss libera).
    If !GEBMNT("LANC_DIRETO")
        ConOut("DIR negado mentor")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    cLote := CTBGRV("DIRETO", cContaD, cContaC, nValor, "DIRETO")
    lOk := (cLote != "")

    ConOut("DIR " + cLote + " " + cValToChar(nValor))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk
