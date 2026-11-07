#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBSEC_RBA
    Controle de acesso baseado em permissoes por perfil/menu/item (Task 4 GEB_SECURITY).
    Tabela SEC_PERM: {CODIGO UNIQUE, PERFIL, MENU, ITEM, PERMITE (.T./.F.)}.
    GEBSECRBAC(cUsuario,cMenu,cItem) -> .T./.F. :
      - busca perfil usuario em GE2 (GE2_PERFIL);
      - consulta SEC_PERM por PERFIL+MENU+ITEM;
      - se miss usa regra padrao: ADMIN = sempre .T.; outros perfis = sempre .F.
        exceto se exposto explicitamente em SEC_PERM com PERMITE=.T.
    GEBSECRBACADD(cPerfil,cMenu,cItem,lPermite) -> .T./.F. : adiciona/altera
    registro em SEC_PERM (INSERT OR REPLACE).
    GEBSECRBACLIST(cPerfil) -> array {menu,item,permite} : lista permissoes
    do perfil informado.
    Rotinas que usam: GEBVLD (validadores GUI) devem chamar GEBSECRBAC
    antes de qualquer operacao escrita (ex: GEBGUIFIN_BAI, GEBGUICTB_DIR).
    Notas AdvPP: ConOut p/ log; GetArea/RestArea guardados;
    workarea p/ leitura de GE2/SEC_PERM; guarda de existencia via GEBDBTableExists;
    escrito via DbAppend()+RecLock(.T.);
    sem SELECT *, sem concat SQL em queries de leitura, so literais. Portabilidade Postgres.
    @type Modulo de controle de acesso RBAC
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario  Codigo do usuario em GE2 (para GEBSECRBAC)
    @param cMenu     Nome do menu (ex: "NUCLEO", "FISCAL") (para GEBSECRBAC)
    @param cItem     Item do menu (ex: "1", "2") (para GEBSECRBAC)
    @param cPerfil   Codigo do perfil (para GEBSECRBACADD/GEBSECRBACLIST)
    @param lPermite  .T. permite, .F. nega (para GEBSECRBACADD)
    @return .T./.F. (GEBSECRBAC/GEBSECRBACADD) ou array {menu,item,permite} (GEBSECRBACLIST)
/*/
User Function GEBSECRBAC(cUsuario, cMenu, cItem)
    Local aArea     := GetArea()
    Local lPermit   := .F.
    Local cEmp      := ""
    Local cPerfil   := ""
    Local cMen      := ""
    Local cItm      := ""
    Local aVinc     := {}
    Local aPerm     := {}
    Local lExata    := .F.
    Local nI        := 0

    // Default de parametros (If Nil em vez de Default -- AdvPP bug).
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    cUsuario := AllTrim(cUsuario)
    If GEBSECISSUPER(cUsuario)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .T.
    EndIf
    If cMenu == Nil
        cMen := ""
    Else
        cMen := Upper(AllTrim(cMenu))
    EndIf
    If cItem == Nil
        cItm := ""
    Else
        cItm := Upper(AllTrim(cItem))
    EndIf

    // Regra 2: o usuario precisa de vinculo com a empresa da sessao (GE2_EMP).
    cEmp := Lower(AllTrim(cValToChar(GEBDBTenantAtual())))
    If cEmp == ""
        ConOut("GEBSECRBAC: sem empresa na sessao (usuario " + cUsuario + ")")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    aVinc := TCSqlQuery("SELECT UPPER(TRIM(GE2_EMP_PERFIL)) AS PERF FROM GE2_EMP WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cUsuario) + " AND LOWER(TRIM(GE2_EMP_EMPRESA)) = " + GEBDBQuote(cEmp) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aVinc) == 0
        ConOut("GEBSECRBAC: sem vinculo com a empresa " + cEmp + " (usuario " + cUsuario + ")")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    cPerfil := AllTrim(cValToChar(aVinc[1]:PERF))

    // Regra 3: ADMIN da empresa tem tudo, somente nesta empresa.
    If cPerfil == "ADMIN"
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .T.
    EndIf

    // Regra 4: linha da empresa tem precedencia sobre a linha '*' (todas as empresas).
    aPerm := TCSqlQuery("SELECT LOWER(TRIM(SEC_PERM_EMPRESA)) AS EMPR, SEC_PERM_PERMITE AS PERMT FROM SEC_PERM WHERE SEC_PERM_PERFIL = " + GEBDBQuote(cPerfil) + " AND SEC_PERM_MENU = " + GEBDBQuote(cMen) + " AND SEC_PERM_ITEM = " + GEBDBQuote(cItm) + " AND LOWER(TRIM(SEC_PERM_EMPRESA)) IN (" + GEBDBQuote(cEmp) + ", '*') AND D_E_L_E_T_ = ' '")
    For nI := 1 To Len(aPerm)
        If AllTrim(cValToChar(aPerm[nI]:EMPR)) == cEmp
            lPermit := (AllTrim(cValToChar(aPerm[nI]:PERMT)) == "T" .Or. AllTrim(cValToChar(aPerm[nI]:PERMT)) == "1")
            lExata  := .T.
            Exit
        EndIf
    Next nI
    If !lExata .And. Len(aPerm) > 0
        lPermit := (AllTrim(cValToChar(aPerm[1]:PERMT)) == "T" .Or. AllTrim(cValToChar(aPerm[1]:PERMT)) == "1")
    EndIf

    ConOut("GEBSECRBAC: user=" + cUsuario + " empresa=" + cEmp + " perfil=" + cPerfil + " menu=" + cMen + " item=" + cItm + " permit=" + Iif(lPermit, ".T.", ".F."))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lPermit

User Function GEBSECRBACADD(cPerfil, cMenu, cItem, lPermite)
    // Grava para todas as empresas ('*'). Por empresa, use GEBSECRBACADDEMP.
Return GEBSECRBACADDEMP(cPerfil, "*", cMenu, cItem, lPermite)

User Function GEBSECRBACADDEMP(cPerfil, cEmpresa, cMenu, cItem, lPermite)
    Local aArea   := GetArea()
    Local cPerf   := ""
    Local cEmp    := ""
    Local cMen    := ""
    Local cItm    := ""
    Local cPermTx := "F"
    Local lOk     := .F.
    Local lAchou  := .F.

    // Default de parametros.
    If cPerfil == Nil
        cPerf := ""
    Else
        cPerf := Upper(AllTrim(cPerfil))
    EndIf
    If cEmpresa == Nil
        cEmp := "*"
    Else
        cEmp := Lower(AllTrim(cEmpresa))
    EndIf
    If cMenu == Nil
        cMen := ""
    Else
        cMen := Upper(AllTrim(cMenu))
    EndIf
    If cItem == Nil
        cItm := ""
    Else
        cItm := Upper(AllTrim(cItem))
    EndIf
    If lPermite == Nil
        lPermite := .F.
    EndIf
    If lPermite
        cPermTx := "T"
    EndIf
    If cPerf == "" .Or. cEmp == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    // Guarda: SEC_PERM pode nao existir.
    If !GEBDBTableExists("SEC_PERM")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    // Trio unico: PERFIL + EMPRESA + MENU + ITEM.
    DbSelectArea("SEC_PERM")
    DbGoTop()
    While !Eof()
        If SEC_PERM->SEC_PERM_PERFIL == cPerf .And. SEC_PERM->SEC_PERM_EMPRESA == cEmp .And. SEC_PERM->SEC_PERM_MENU == cMen .And. SEC_PERM->SEC_PERM_ITEM == cItm .And. SEC_PERM->D_E_L_E_T_ == " "
            lAchou := .T.
            Exit
        EndIf
        DbSkip()
    EndDo

    If lAchou
        RecLock("SEC_PERM", .F.)
        SEC_PERM->SEC_PERM_PERMITE := cPermTx
        MsUnlock()
        lOk := .T.
    Else
        DbAppend()
        RecLock("SEC_PERM", .T.)
        SEC_PERM->SEC_PERM_FILIAL  := FWxFilial("SEC_PERM")
        SEC_PERM->D_E_L_E_T_       := " "
        SEC_PERM->SEC_PERM_PERFIL  := cPerf
        SEC_PERM->SEC_PERM_EMPRESA := cEmp
        SEC_PERM->SEC_PERM_MENU    := cMen
        SEC_PERM->SEC_PERM_ITEM    := cItm
        SEC_PERM->SEC_PERM_PERMITE := cPermTx
        MsUnlock()
        lOk := .T.
    EndIf
    DbCloseArea()

    ConOut("GEBSECRBACADDEMP: perfil=" + cPerf + " empresa=" + cEmp + " menu=" + cMen + " item=" + cItm + " permitem=" + Iif(lPermite, ".T.", ".F.") + " -> " + Iif(lOk, "OK", "FAIL"))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

User Function GEBSECRBACLIST(cPerfil)
    Local aArea   := GetArea()
    Local aRet    := {}
    Local cPerf   := ""
    Local cFil    := FWxFilial("SEC_PERM")

    // Default de parametro.
    If cPerfil == Nil
        cPerf := ""
    Else
        cPerf := Upper(AllTrim(cPerfil))
    EndIf
    If cPerf == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return aRet
    EndIf

    // Guarda: SEC_PERM pode nao existir.
    If !GEBDBTableExists("SEC_PERM")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return aRet
    EndIf

    // Lista so' as permissoes globais ('*'); as por empresa ficam na tela da empresa.
    DbSelectArea("SEC_PERM")
    DbGoTop()
    While !Eof()
        If SEC_PERM->SEC_PERM_FILIAL == cFil .And. SEC_PERM->SEC_PERM_PERFIL == cPerf .And. SEC_PERM->SEC_PERM_EMPRESA == "*" .And. SEC_PERM->D_E_L_E_T_ == " "
            Local lPermite := (SEC_PERM->SEC_PERM_PERMITE == "T" .Or. SEC_PERM->SEC_PERM_PERMITE == "1")
            AAdd(aRet, {SEC_PERM->SEC_PERM_MENU, SEC_PERM->SEC_PERM_ITEM, lPermite})
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

// GEBSECRBACLISTEMP(cPerfil, cEmpresa) -> {{menu, item, permite, empresa}, ...}
// Lista as permissoes do perfil para a empresa (linha exata) e as globais ('*').
// cEmpresa "*" lista so' as globais.
User Function GEBSECRBACLISTEMP(cPerfil, cEmpresa)
    Local aRet  := {}
    Local cPerf := ""
    Local cEmp  := ""
    Local aHit  := {}
    Local nI    := 0
    If cPerfil == Nil
        cPerf := ""
    Else
        cPerf := Upper(AllTrim(cPerfil))
    EndIf
    If cEmpresa == Nil
        cEmp := "*"
    Else
        cEmp := Lower(AllTrim(cEmpresa))
    EndIf
    If cPerf == "" .Or. !GEBDBTableExists("SEC_PERM")
        Return aRet
    EndIf
    aHit := TCSqlQuery("SELECT SEC_PERM_MENU AS MNU, SEC_PERM_ITEM AS ITM, SEC_PERM_PERMITE AS PRM, LOWER(TRIM(SEC_PERM_EMPRESA)) AS EMPR FROM SEC_PERM WHERE SEC_PERM_PERFIL = " + GEBDBQuote(cPerf) + " AND LOWER(TRIM(SEC_PERM_EMPRESA)) IN (" + GEBDBQuote(cEmp) + ", '*') AND D_E_L_E_T_ = ' ' ORDER BY SEC_PERM_MENU, SEC_PERM_ITEM")
    For nI := 1 To Len(aHit)
        AAdd(aRet, {AllTrim(cValToChar(aHit[nI]:MNU)), AllTrim(cValToChar(aHit[nI]:ITM)), (AllTrim(cValToChar(aHit[nI]:PRM)) == "T" .Or. AllTrim(cValToChar(aHit[nI]:PRM)) == "1"), AllTrim(cValToChar(aHit[nI]:EMPR))})
    Next nI
Return aRet
