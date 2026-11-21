#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GENUC_CAD
    Cadastros do nucleo GEBAN (Task 3 GEB_NUCLEO): Empresas GE1,
    Usuarios GE2 e Auditoria GE3.
    Mapeamento 1:1 com as interfaces do plano (chamadas sem prefixo U_):
    U_GEBAUD -> GEBAUD | U_GEBUSR -> GEBUSR. O prefixo U_ nao e usado
    nas chamadas porque o runtime AdvPP so resolve U_ em
    StartJob/FindFunction; chamada direta U_X() da "unknown function".
    GEBAUD(cUsuario, cEvento, cMotivo) grava trilha real em GE3 com
    filial da sessao + D_E_L_E_T_ = ' ' via DbAppend() +
    RecLock("GE3", .T.) + atribuicoes + MsUnlock. O DbAppend() antes
    e obrigatorio: RecLock sozinho aborta ("no current record") em
    tabela vazia. O .T. aqui e append (registro novo),
    nao lock indefinido: e o UNICO caminho de escrita via workarea
    que persiste no AdvPP (probes Task 3: DbAppend puro nao gravou,
    RecLock(.T.) sozinho so gravou em tabela nao-vazia,
    DbAppend+RecLock(.T.) gravou em vazia e em duplo insert N=2; ver .superpowers/sdd/task-3-report.md).
    GEBUSR(cCodUser) valida perfil em GE2: miss -> .F.; perfil CAIXA
    so autoriza se GEBCFG("PERMITE_DIRETA") == "S"; demais perfis -> .T.
    Leitura de GE2 via workarea (DbSelectArea/DbGoTop/scan/DbSkip),
    com guarda de existencia via TCSqlQuery em pg_tables
    (DbSelectArea em tabela ausente aborta; Select()/Used() sao stubs).
    GEBCAD() e o ponto de entrada dos cadastros (futura acao Nucleo
    do MenuDef de GEBAN.prw); CADMenu() expoe Empresas/Usuarios/
    Auditoria. BrowseDef real chega em task futura; aqui stubs que
    so logam via ConOut.
    Notas AdvPP (balisador, ver .superpowers/sdd/task-1-report.md):
    log via ConOut (FWLogMsg nao existe no runtime); If Nil em vez
    de Default (Default sobrescreve incondicionalmente); alias
    literal (GetNextAlias nao existe); GetArea/RestArea guardados
    (GetArea retorna "" sem workarea aberta; RestArea("") aborta);
    sem BeginSql standalone (no-op no pre-processador); sem SELECT *,
    sem concat SQL, sem cFilial, sem IIF.
    @type Modulo de cadastros
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario da trilha (GEBAUD) / codigo em GE2 (GEBUSR)
    @param cEvento Evento auditado / nao usado em GEBUSR
    @param cMotivo Motivo da trilha (ex: "assumiu BO mentor")
    @return .T. se gravou/autorizado, .F. caso contrario
/*/
User Function GEBAUD(cUsuario, cEvento, cMotivo)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GE3")
    Local cData := DToS(Date())
    Local lOk := .T.

    If cUsuario == Nil
        cUsuario := "SYSTEM"
    EndIf
    If cEvento == Nil
        cEvento := "EVENTO"
    EndIf
    If cMotivo == Nil
        cMotivo := ""
    EndIf

    DbSelectArea("GE3")
    DbAppend()
    RecLock("GE3", .T.)
    GE3->GE3_FILIAL := cFil
    GE3->D_E_L_E_T_ := " "
    GE3->GE3_COD := cEvento
    GE3->GE3_USUAR := cUsuario
    GE3->GE3_EVENT := cEvento
    GE3->GE3_MOTIV := cMotivo
    GE3->GE3_DATA := cData
    MsUnlock()
    DbCloseArea()

    ConOut("AUD " + cUsuario + " " + cEvento + " " + cMotivo)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

User Function GEBUSR(cCodUser)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GE2")
    Local cPerfil := ""
    Local lAchou := .F.
    Local lOk := .F.

    If cCodUser == Nil
        cCodUser := ""
    EndIf

    // Guarda: GE2 pode nao existir (GENMIG ainda nao rodou).
    If !GEBDBTableExists("GE2")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return lOk
    EndIf

    DbSelectArea("GE2")
    DbGoTop()
    While !Eof()
        If GE2->GE2_FILIAL == cFil .AND. GE2->GE2_COD == cCodUser .AND. GE2->D_E_L_E_T_ == " "
            cPerfil := GE2->GE2_PERFIL
            lAchou := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    If lAchou
        If cPerfil == "CAIXA"
            If GEBCFG("PERMITE_DIRETA") == "S"
                lOk := .T.
            EndIf
        Else
            lOk := .T.
        EndIf
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

User Function GEBCAD()
    Local aArea := GetArea()

    ConOut("GEBCAD Cadastros GE1/GE2/GE3 online")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

Static Function CADMenu()
    Local aRotina := {}

    AAdd(aRotina, {"Empresas", "GEBCADemp()", 0, 1})
    AAdd(aRotina, {"Usuarios", "GEBCADusu()", 0, 2})
    AAdd(aRotina, {"Auditoria", "GEBCADaud()", 0, 3})
Return aRotina

Static Function GEBCADemp()
    ConOut("GEBCAD Empresas GE1 - stub BrowseDef futuro")
Return .T.

Static Function GEBCADusu()
    ConOut("GEBCAD Usuarios GE2 - stub BrowseDef futuro")
Return .T.

Static Function GEBCADaud()
    ConOut("GEBCAD Auditoria GE3 - stub BrowseDef futuro")
Return .T.
