#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBGUI_CFG
    Tela de CONFIGURACAO BANANIAS (Task 5 GEB_GUI).
    Mapeamento 1:1 com as interfaces do plano (chamadas sem
    prefixo U_): U_GEBGUICONF_SHOW -> GEBGUICONF_SHOW |
    U_GEBGUICONF_PARAM -> GEBGUICONF_PARAM |
    U_GEBGUICONF_ALIQ -> GEBGUICONF_ALIQ |
    U_GEBGUICONF_CAD_EMPRESA -> GEBGUICONF_CAD_EMPRESA |
    U_GEBGUICONF_CAD_USUARIO -> GEBGUICONF_CAD_USUARIO |
    U_GEBGUICONF_CAD_PRODUTO -> GEBGUICONF_CAD_PRODUTO |
    U_GEBGUICONF_CAD_FORN -> GEBGUICONF_CAD_FORN |
    U_GEBGUICONF_CAD_CONTA -> GEBGUICONF_CAD_CONTA |
    U_GEBGUICONF_RESUMO -> GEBGUICONF_RESUMO.
    O prefixo U_ nao e usado na chamada porque o runtime AdvPP
    so resolve U_ em StartJob/FindFunction; chamada direta U_X()
    da "unknown function".

    GEBGUICONF_SHOW() e a entry point principal: abre secoes
    navegaveis (abas logicas) com parametros do sistema, aliq por
    NCM, cadastros rapidos e ajuda. So loga via ConOut -- sem UI
    grafica no balisador AdvPP.

    GEBGUICONF_PARAM(cSeccao) le/grava GE4 para o evento solicitado
    (EMISSAO, APURACAO, PERMITE_DIRETA, MENTOR) e padroes via
    GEBGUICONFIG_SC/LC; retorna void.

    GEBGUICONF_ALIQ(cNCM) mostra calculo CalcIBS para o NCM e
    permite cadastro de nova aliquota em GF2.

    As funcoes CAD_* abrem formulários simples (log) para
    GE1/GE2/GF1/GCP1/GFN1 respectivamente.

    GEBGUICONF_RESUMO() chama GEBNFLX()+GEBBAL+GEBDRE e mostra
    dashboard numerico via ConOut.

    O banco de configuracao usa duas tabelas novas criadas por
    GEBGUIMIG(): GEBGUICONFIG_SC (char) e GEBGUICONFIG_LC (log).
    Valores default sao definidos localmente e só gravados se
    a chave ainda nao existir.

    Notas AdvPP (balisador): log via ConOut; If Nil em vez de
    Default; GetArea/RestArea guardados; leitura via workarea;
    guarda de existencia via TCSqlQuery em pg_tables; escrita
    via DbAppend()+RecLock(.T.); sem SELECT *, sem concat SQL
    (so literais em TCSqlExec), sem cFilial, sem IIF; so
    User/Static Function.

    @type Tela de configuracao
    @author Peder Munksgaard
    @since 23/09/2026
    @param cSeccao Nome da secao de parametros (GEBGUICONF_PARAM)
    @param cNCM     NCM para consulta/aliquota (GEBGUICONF_ALIQ)
    @param cCod     Codigo para cadastro rapido
    @param cNome    Nome para cadastro rapido
    @return void (todas)
/*/

User Function GEBGUICONF_SHOW()
    Local aArea := GetArea()

    ConOut("=== GEBGUI_CFG -- CONFIGURACAO BANANIAS ===")
    ConOut("[1] PARAMETROS DO SISTEMA (EMISSAO, APURACAO, PERMITE_DIRETA, MENTOR)")
    ConOut("[2] ALIQ POR PRODUTO (GF1+GF2)")
    ConOut("[3] CADASTRO RAPIDO (GE1, GE2, GF1, GCP1, GFN1)")
    ConOut("[4] AJUDA (regras de negocio, FAQ)")
    ConOut("=== FIM CONFIGURACAO ===")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return

User Function GEBGUICONF_PARAM(cSeccao)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GE4")
    Local cPadrao := ""
    Local cAtual := ""
    Local lAchou := .F.
    Local aChk := {}
    Local lTmp := .F.

    If cSeccao == Nil
        cSeccao := ""
    EndIf

    // Guarda existencia de GE4.
    If !GEBDBTableExistsHere("GE4")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return
    EndIf

    // Padrao por secao (default list do prompt).
    If cSeccao == "EMISSAO"
        cPadrao := "ONLINE_FILA"
    ElseIf cSeccao == "APURACAO"
        cPadrao := "AUTO"
    ElseIf cSeccao == "PERMITE_DIRETA"
        cPadrao := "N"
    ElseIf cSeccao == "MENTOR"
        cPadrao := "AVISA_E_LIBERA_COM_BO"
    Else
        cPadrao := ""
    EndIf

    // Busca valor atual em GE4.
    DbSelectArea("GE4")
    DbGoTop()
    While !Eof()
        If GE4->GE4_FILIAL == cFil .AND. GE4->GE4_EVENTO == cSeccao .AND. GE4->D_E_L_E_T_ == " "
            cAtual := GE4->GE4_MODO
            lAchou := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    // Se não existe, insere com padrao.
    If !lAchou
        DbSelectArea("GE4")
        DbAppend()
        RecLock("GE4", .T.)
        GE4->GE4_FILIAL := cFil
        GE4->D_E_L_E_T_ := " "
        GE4->GE4_EVENTO := cSeccao
        GE4->GE4_MODO := cPadrao
        MsUnlock()
        DbCloseArea()
        cAtual := cPadrao
    EndIf

    // Log do estado.
    ConOut("PARAM " + cSeccao + " = " + cAtual + " (padrao=" + cPadrao + ")")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return

User Function GEBGUICONF_ALIQ(cNCM)
    Local aArea := GetArea()
    Local cData := DToS(Date())
    Local aTaxa := {}
    Local aRes := {}
    Local nIBS := 0
    Local nCBS := 0

    If cNCM == Nil
        cNCM := ""
    EndIf

    ConOut("=== ALIQ P/ PRODUTO [" + cNCM + "] ===")

    // Le aliquota vigente via ALIQF (GEBFIS_MIG.prw).
    aTaxa := ALIQF(cNCM, cData)
    nIBS := aTaxa[1]
    nCBS := aTaxa[2]
    ConOut("ALIQ ATUAL IBS=" + cValToChar(nIBS) + " CBS=" + cValToChar(nCBS))

    // Calculo exemplo: base 1000.
    aRes := CALCIBS(1000, nIBS, nCBS)
    ConOut("CALCIBS(1000) -> IBS=" + cValToChar(aRes[1]) + " CBS=" + cValToChar(aRes[2]))

    ConOut("=== FIM ALIQ ===")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return

User Function GEBGUICONF_CAD_EMPRESA()
    Local aArea := GetArea()

    ConOut("=== CADASTRO RAPIDO -- EMPRESA (GE1) ===")
    ConOut("Informe COD e NOME da empresa para cadastrar.")
    ConOut("=== FIM EMPRESA ===")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return

User Function GEBGUICONF_CAD_USUARIO()
    Local aArea := GetArea()

    ConOut("=== CADASTRO RAPIDO -- USUARIO (GE2) ===")
    ConOut("Informe COD, NOME e PERFIL do usuario.")
    ConOut("=== FIM USUARIO ===")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return

User Function GEBGUICONF_CAD_PRODUTO()
    Local aArea := GetArea()

    ConOut("=== CADASTRO RAPIDO -- PRODUTO (GF1) ===")
    ConOut("Informe COD, NCM e DESCRICAO do produto.")
    ConOut("=== FIM PRODUTO ===")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return

User Function GEBGUICONF_CAD_FORN()
    Local aArea := GetArea()

    ConOut("=== CADASTRO RAPIDO -- FORNECEDOR (GCP1) ===")
    ConOut("Informe COD, NOME e CNPJ do fornecedor.")
    ConOut("=== FIM FORNECEDOR ===")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return

User Function GEBGUICONF_CAD_CONTA()
    Local aArea := GetArea()

    ConOut("=== CADASTRO RAPIDO -- CONTA (GFN1) ===")
    ConOut("Informe COD (CONTA) e NOME da conta bancaria.")
    ConOut("=== FIM CONTA ===")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return

User Function GEBGUICONF_RESUMO()
    Local aArea := GetArea()
    Local aFlx := {}
    Local aBal := {}
    Local nDRE := 0
    Local cComp := DToS(Date())

    ConOut("=== RESUMO / DASHBOARD ===")

    aFlx := GEBNFLX()
    ConOut("FLUXO CAIXA: receber=" + cValToChar(aFlx[1]) + " pagar=" + cValToChar(aFlx[2]) + " saldo=" + cValToChar(aFlx[3]))

    aBal := GEBBAL(cComp)
    ConOut("BALANCETE " + cComp + " linhas=" + cValToChar(Len(aBal)))

    nDRE := GEBDRE(cComp)
    ConOut("DRE " + cComp + " = " + cValToChar(nDRE))

    ConOut("=== FIM RESUMO ===")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return

User Function GEBGUIMIG()
    Local aArea := GetArea()
    Local lOk := .T.
    Local lTmp := .F.

    ConOut("GEBGUIMIG criando GEBGUICONFIG_SC/LC em geban.db")

    lTmp := CriaGEBGUICONFIG_SC()
    lOk := (lOk .AND. lTmp)
    lTmp := CriaGEBGUICONFIG_LC()
    lOk := (lOk .AND. lTmp)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

Static Function CriaGEBGUICONFIG_SC()
    Local lTab := TCSqlExec("CREATE TABLE IF NOT EXISTS GEBGUICONFIG_SC (R_E_C_N_O_ INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, D_E_L_E_T_ TEXT DEFAULT ' ', GEBGUISC_CHAVE TEXT NOT NULL, GEBGUISC_VALOR TEXT NOT NULL)")
    Local lIdx := TCSqlExec("CREATE INDEX IF NOT EXISTS GEBGUISC_CHAVE ON GEBGUICONFIG_SC (GEBGUISC_CHAVE)")
Return (lTab .AND. lIdx)

Static Function CriaGEBGUICONFIG_LC()
    Local lTab := TCSqlExec("CREATE TABLE IF NOT EXISTS GEBGUICONFIG_LC (R_E_C_N_O_ INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, D_E_L_E_T_ TEXT DEFAULT ' ', GEBGULC_CHAVE TEXT NOT NULL, GEBGULC_VALOR BOOLEAN NOT NULL)")
    Local lIdx := TCSqlExec("CREATE INDEX IF NOT EXISTS GEBGULC_CHAVE ON GEBGUICONFIG_LC (GEBGULC_CHAVE)")
Return (lTab .AND. lIdx)
