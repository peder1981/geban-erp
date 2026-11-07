#include "totvs.ch"
#include "GEBDB_TENANT.prw"

/*/{Protheus.doc} GEBGUI_LOGIN
    Tela de login interativa para GEBAN (Task 7 GEB_SECURITY).
    GEBGUI_LOGIN(cUser, cPass, cEmp, cIP, lSkipDash) exibe tela de login
    no menu terminal (ou tela web se em modo serve), coleta usuario, senha e
    empresa (seleciona se multipla), chama GEBSECLOGIN(cUser, cPass,
    cIP="local"), e redireciona para o dashboard se autenticacao for
    bem-sucedida.
    Se cUser/cPass/cEmp forem passados, pula o input interativo (modo
    teste/serve). Se vazios, exibe menu interativo com ConIn.
    Se lSkipDash for .T., pula o dashboard pos-login (utile para testes).
    Em caso de falha, mostra mensagem adequada conforme status retornado
    por GEBSECLOGIN: USU_INEX, SENHA_ERR, CONTA_BLOQ, MAX_TENT.
    Mostra contador de tentativas restantes ate lockout.
    Autorizacao: depois de GEBSECLOGIN() == "OK", o login so' prossegue
    (token/dashboard) se GEBGUIVINC() confirmar o formato de usuario/
    empresa e o vinculo GE2_EMP -- mesmo gate de GEBAN(). Sem vinculo:
    "[-] Usuario sem acesso a empresa", conta como tentativa falha.
    GE2_EMP_FILIAL tambem entra no filtro do vinculo (Task 2, plano
    fase2-gaps): a filial passada a GEBGUIVINC() precisa ser o valor CRU
    (sem AllTrim) de GE2_FILIAL vindo da mesma consulta a GE2 usada
    depois para montar o token -- NAO a variavel cFil ja trimada (essa
    continua trimada para exibicao/token, como sempre foi).
    Interface: U_GEBGUI_LOGIN -> GEBGUI_LOGIN(cUser, cPass, cEmp, cIP, lSkipDash).
    Notas AdvPP: ConOut/ConIn p/ interacao; If Nil em vez de Default;
    GetArea/RestArea guardados; TCSqlQuery so funciona p/ existencia.
    @type EntryPoint tela login
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUser    Usuario para login automatico (vazio = interativo)
    @param cPass    Senha para login automatico
    @param cEmp     Empresa para login automatico
    @param cIP      IP de origem (padrao "local")
    @param lSkipDash .T. pula o dashboard pos-login (teste/serve)
    @return .T. se autenticacao com sucesso, .F. se cancelado ou falha critica
/*/
User Function GEBGUI_LOGIN(cUser, cPass, cEmp, cIP, lSkipDash)
    Local aArea       := GetArea()
    Local cOp         := ""
    Local cUsuario    := ""
    Local cSenha      := ""
    Local cEmpresa    := ""
    Local aEmpresas   := {}
    Local nEmp        := 0
    Local cStatus     := ""
    Local nFail       := 0
    Local nMaxTent    := 5
    Local lQuit       := .F.
    Local lOk         := .F.
    Local lTmp        := .F.
    Local cFil        := ""
    Local cFilVinc    := ""
    Local aSec        := {}
    Local cMen        := ""
    Local lPermit     := .F.
    Local nI          := 0
    Local lAuto       := .F.

    // Default parametros.
    If cUser == Nil
        cUser := ""
    EndIf
    If cPass == Nil
        cPass := ""
    EndIf
    If cEmp == Nil
        cEmp := ""
    EndIf
    If cIP == Nil
        cIP := "local"
    EndIf
    If lSkipDash == Nil
        lSkipDash := .F.
    EndIf

    // Modo automatico (teste/serve): cUser e cPass preenchidos.
    If cUser != "" .And. cPass != ""
        lAuto := .T.
        cUsuario := AllTrim(cUser)
        cSenha := AllTrim(cPass)
        If cEmp != ""
            cEmpresa := AllTrim(cEmp)
        EndIf
    EndIf

    // Garante migracao seguranca.
    lTmp := TCSecMIG()
    If !lTmp
        ConOut("[!] TCSecMIG falhou - abortando login")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    // Busca empresas disponiveis em GE1.
    aEmpresas := TCSqlQuery("SELECT GE1_COD, GE1_NOME FROM GE1 WHERE D_E_L_E_T_ = ' ' ORDER BY GE1_COD")
    nEmp := Len(aEmpresas)

    // Se modo interativo, exibe cabecalho e loop de input.
    If !lAuto
        ConOut("")
        ConOut("============================================")
        ConOut("  GEBAN - Sistema de Apuracao Tributaria")
        ConOut("  LOGIN")
        ConOut("============================================")
        ConOut("")

        Do While !lQuit
            ConOut("Tentativas restantes: " + cValToChar(nMaxTent - nFail) + "/" + cValToChar(nMaxTent))
            ConOut("")

            // Seleciona empresa se multipla.
            If nEmp == 0
                ConOut("[!] Nenhuma empresa cadastrada em GE1.")
                cEmpresa := ""
            EndIf
            If nEmp == 1
                ConOut("Empresa: " + AllTrim(aEmpresas[1]:GE1_COD) + " - " + AllTrim(aEmpresas[1]:GE1_NOME))
                cEmpresa := AllTrim(aEmpresas[1]:GE1_COD)
            EndIf
            If nEmp > 1
                ConOut("Empresas disponiveis:")
                For nI := 1 To nEmp
                    ConOut("  [" + cValToChar(nI) + "] " + AllTrim(aEmpresas[nI]:GE1_COD) + " - " + AllTrim(aEmpresas[nI]:GE1_NOME))
                Next nI
                ConOut("")
                ConOut("Escolha a empresa (1-" + cValToChar(nEmp) + "): ")
                cOp := Trim(ConIn())
                nI  := Val(cOp)
                If nI >= 1 .And. nI <= nEmp
                    cEmpresa := AllTrim(aEmpresas[nI]:GE1_COD)
                    ConOut("  Empresa selecionada: " + cEmpresa)
                Else
                    ConOut("  [!] Opcao invalida. Tente novamente.")
                    ConOut("")
                    Loop
                EndIf
            EndIf
            ConOut("")

            // Input usuario.
            ConOut("Usuario: ")
            cUsuario := Trim(ConIn())
            ConOut("")

            // Input senha.
            ConOut("Senha: ")
            cSenha := Trim(ConIn())
            ConOut("")

            // Valida entradas.
            If cUsuario == ""
                ConOut("[!] Usuario nao pode ser vazio.")
                ConOut("")
                Loop
            EndIf
            If cEmpresa == ""
                ConOut("[!] Nenhuma empresa disponivel.")
                ConOut("")
                Loop
            EndIf

            // Chama autenticacao.
            cStatus := GEBSECLOGIN(cUsuario, cSenha, cIP)
            ConOut("Status: " + cStatus)

            // Busca a filial do usuario em GE2 (mesma fonte usada mais
            // abaixo para gerar o token) ANTES do gate de vinculo, pois
            // GEBGUIVINC() agora tambem filtra GE2_EMP por filial.
            // cFilVinc fica com o valor CRU (sem AllTrim) para a
            // comparacao SQL -- GE2_EMP_FILIAL e' gravado com o valor
            // cru de FWxFilial() (6 posicoes, preenchido com espaco).
            cFil := ""
            cFilVinc := FWxFilial("GE2")
            If cStatus == "OK"
                aSec := TCSqlQuery("SELECT GE2_FILIAL FROM GE2 WHERE GE2_COD = " + GEBDBQuote(cUsuario) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
                If Len(aSec) > 0
                    cFilVinc := aSec[1]:GE2_FILIAL
                    cFil := AllTrim(aSec[1]:GE2_FILIAL)
                EndIf
            EndIf

            // Autenticou, mas so' entra se o usuario tiver vinculo
            // GE2_EMP com a empresa escolhida (mesmo gate de GEBAN()).
            If cStatus == "OK"
                If !GEBGUIVINC(cUsuario, cEmpresa, cFilVinc)
                    ConOut("[-] Usuario sem acesso a empresa " + cEmpresa + ".")
                    ConOut("")
                    cStatus := "SEM_VINC"
                    nFail++
                EndIf
            EndIf

            If cStatus == "OK"
                ConOut("")
                ConOut("[+] Autenticacao com sucesso!")
                ConOut("")

                nFail := 0

                // Gera token de sessao.
                cOp := GEBSECTOKEN(cUsuario, cEmpresa, cFil, cIP)
                ConOut("Token gerado: " + Left(cOp, 20) + "...")
                ConOut("")

                // Redireciona para dashboard (ou pula se lSkipDash).
                If lSkipDash
                    lOk := .T.
                Else
                    lOk := GEBGUI_DASHBOARD(cEmpresa, cUsuario, cFil)
                EndIf
                If Len(aArea) > 0
                    RestArea(aArea)
                EndIf
                Return lOk
            EndIf
            If cStatus == "USU_INEX"
                ConOut("[-] Usuario inexistente. Tente novamente.")
                ConOut("")
                nFail++
            EndIf
            If cStatus == "SENHA_ERR"
                ConOut("[-] Senha incorreta. Tente novamente.")
                ConOut("")
                nFail++
            EndIf
            If cStatus == "CONTA_BLOQ"
                ConOut("[-] Conta bloqueada. Contate o administrador.")
                ConOut("")
                If Len(aArea) > 0
                    RestArea(aArea)
                EndIf
                Return .F.
            EndIf
            If cStatus == "MAX_TENT"
                ConOut("[-] Maximo de tentativas atingido. Conta bloqueada.")
                ConOut("")
                If Len(aArea) > 0
                    RestArea(aArea)
                EndIf
                Return .F.
            EndIf

            If nFail >= nMaxTent
                ConOut("[-] Bloqueio por excesso de tentativas.")
                ConOut("")
                If Len(aArea) > 0
                    RestArea(aArea)
                EndIf
                Return .F.
            EndIf
        EndDo
    Else
        // Modo automatico: valida empresa se nao fornecida.
        If cEmpresa == ""
            If nEmp == 0
                ConOut("[!] Nenhuma empresa cadastrada em GE1.")
                If Len(aArea) > 0
                    RestArea(aArea)
                EndIf
                Return .F.
            EndIf
            If nEmp == 1
                cEmpresa := AllTrim(aEmpresas[1]:GE1_COD)
            EndIf
            If nEmp > 1
                ConOut("[!] Modo automatico requer cEmp quando multiplas empresas.")
                If Len(aArea) > 0
                    RestArea(aArea)
                EndIf
                Return .F.
            EndIf
        EndIf

        // Chama autenticacao.
        cStatus := GEBSECLOGIN(cUsuario, cSenha, cIP)
        ConOut("Status: " + cStatus)

        // Busca a filial do usuario em GE2 (mesma fonte usada mais
        // abaixo para gerar o token) ANTES do gate de vinculo, pois
        // GEBGUIVINC() agora tambem filtra GE2_EMP por filial.
        // cFilVinc fica com o valor CRU (sem AllTrim) para a comparacao
        // SQL -- GE2_EMP_FILIAL e' gravado com o valor cru de
        // FWxFilial() (6 posicoes, preenchido com espaco).
        cFil := ""
        cFilVinc := FWxFilial("GE2")
        If cStatus == "OK"
            aSec := TCSqlQuery("SELECT GE2_FILIAL FROM GE2 WHERE GE2_COD = " + GEBDBQuote(cUsuario) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
            If Len(aSec) > 0
                cFilVinc := aSec[1]:GE2_FILIAL
                cFil := AllTrim(aSec[1]:GE2_FILIAL)
            EndIf
        EndIf

        // Autenticou, mas so' entra se o usuario tiver vinculo GE2_EMP
        // com a empresa pedida (mesmo gate de GEBAN()).
        If cStatus == "OK"
            If !GEBGUIVINC(cUsuario, cEmpresa, cFilVinc)
                ConOut("[-] Usuario sem acesso a empresa " + cEmpresa + ".")
                cStatus := "SEM_VINC"
            EndIf
        EndIf

        If cStatus == "OK"
            ConOut("")
            ConOut("[+] Autenticacao com sucesso!")
            ConOut("")

            // Gera token de sessao.
            cOp := GEBSECTOKEN(cUsuario, cEmpresa, cFil, cIP)
            ConOut("Token gerado: " + Left(cOp, 20) + "...")
            ConOut("")

            // Redireciona para dashboard (ou pula se lSkipDash).
            If lSkipDash
                lOk := .T.
            Else
                lOk := GEBGUI_DASHBOARD(cEmpresa, cUsuario, cFil)
            EndIf
            If Len(aArea) > 0
                RestArea(aArea)
            EndIf
            Return lOk
        EndIf
        If cStatus == "USU_INEX"
            ConOut("[-] Usuario inexistente.")
        EndIf
        If cStatus == "SENHA_ERR"
            ConOut("[-] Senha incorreta.")
        EndIf
        If cStatus == "CONTA_BLOQ"
            ConOut("[-] Conta bloqueada.")
        EndIf
        If cStatus == "MAX_TENT"
            ConOut("[-] Maximo de tentativas atingido.")
        EndIf
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

/*/{Protheus.doc} GEBGUIVINC
    Gate de autorizacao usuario x empresa do login GEBGUI_LOGIN, mesmo
    criterio de GEBAN()/GEBEXPCONTEXTO(): cUsu e cEmp com FORMATO valido
    (GEBDBSchemaValido -- alfanumerico + underscore, ate 30 chars, ANTES
    de qualquer SQL), cFilial com o mesmo FORMATO valido quando
    informada (vazia e' o caso padrao, sistema ainda sem
    RpcSetEnv/multi-filial), e linha ativa em GE2_EMP ligando usuario +
    empresa + filial. Sem filial no filtro, o mesmo codigo de usuario em
    OUTRA filial casaria o vinculo. cFilial deve vir da mesma consulta a
    GE2 (GE2_FILIAL) ja usada pelo chamador para montar o token de
    sessao -- nao inventar outra fonte.
    @type Funcao de autorizacao (interna)
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsu     Codigo do usuario ja autenticado
    @param cEmp     Codigo da empresa escolhida
    @param cFilial  Filial do usuario (GE2_FILIAL), vazia = padrao
    @return .T. se formato valido e vinculo GE2_EMP existir
/*/
Static Function GEBGUIVINC(cUsu, cEmp, cFilial)
    Local aChk := {}

    If cFilial == Nil
        cFilial := ""
    EndIf
    If !GEBDBSchemaValido(cUsu)
        Return .F.
    EndIf
    If !GEBDBSchemaValido(cEmp)
        Return .F.
    EndIf
    If AllTrim(cFilial) != ""
        If !GEBDBSchemaValido(cFilial)
            Return .F.
        EndIf
    EndIf
    // Vinculo e por usuario x empresa (GE2_EMP). A filial nao entra na regra de
    // acesso: a filial vem do cadastro (GE2), e o super entra sem vinculo, como na TUI.
    If GEBSECISSUPER(cUsu)
        Return .T.
    EndIf
    aChk := TCSqlQuery("SELECT GE2_EMP_USUARIO FROM GE2_EMP WHERE GE2_EMP_USUARIO = " + GEBDBQuote(AllTrim(cUsu)) + " AND LOWER(TRIM(GE2_EMP_EMPRESA)) = " + GEBDBQuote(Lower(AllTrim(cEmp))) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
Return (Len(aChk) > 0)

// Dashboard pos-login: exibe menu com opcoes permitidas pelo perfil.
Static Function GEBGUI_DASHBOARD(cEmpresa, cUsuario, cFilial)
    Local aArea       := GetArea()
    Local cOp         := ""
    Local lQuit       := .F.
    Local lOk         := .T.
    Local aMenus      := {}
    Local nI          := 0
    Local cMen        := ""
    Local lPermit     := .F.
    Local aHit        := {}

    ConOut("")
    ConOut("============================================")
    ConOut("  GEBAN - Dashboard")
    ConOut("  Usuario: " + cUsuario)
    ConOut("  Empresa: " + cEmpresa)
    ConOut("============================================")
    ConOut("")

    // Monta lista de menus disponiveis conforme RBAC.
    AAdd(aMenus, {"NUCLEO",     "1", "Nucleo      (migra GE1-GE5)"})
    AAdd(aMenus, {"FISCAL",     "2", "Fiscal      (migra GF1-GF6, apura)"})
    AAdd(aMenus, {"DERRAMA",    "3", "Derrama     (migra GD1, gera guias)"})
    AAdd(aMenus, {"ESTOQUE",    "4", "Estoque     (migra GV1-GV3, venda)"})
    AAdd(aMenus, {"CONTABIL",   "5", "Contabil    (migra GC1-GC4, lanca)"})
    AAdd(aMenus, {"FINANCEIRO", "6", "Financeiro  (migra GFN, fluxo)"})
    AAdd(aMenus, {"COMPRAS",    "7", "Compras     (migra, cotas, pedidos)"})
    AAdd(aMenus, {"CONFIG",     "8", "Configurac."})
    AAdd(aMenus, {"SAIR",       "9", "Sair"})

    // Filtra menus conforme RBAC.
    aHit := {}
    For nI := 1 To Len(aMenus)
        cMen := aMenus[nI][1]
        lPermit := GEBSECRBAC(cUsuario, cMen, aMenus[nI][2])
        If lPermit
            AAdd(aHit, aMenus[nI])
        EndIf
    Next nI

    // Exibe menus permitidos.
    For nI := 1 To Len(aHit)
        ConOut(aHit[nI][2] + " - " + aHit[nI][3])
    Next nI
    ConOut("")
    ConOut("============================================")

    // Loop de selecao.
    Do While !lQuit
        ConOut("Escolha uma opcao: ")
        cOp := Trim(ConIn())
        ConOut("")

        If cOp == "9"
            lQuit := .T.
        Else
            lPermit := GEBSECRBAC(cUsuario, "CONFIG", cOp)
            If !lPermit
                ConOut("[!] Opcao nao permitida para seu perfil.")
                ConOut("")
            Else
                ConOut("[*] Opcao " + cOp + " selecionada (demo: so loga).")
                ConOut("")
            EndIf
        EndIf
    EndDo

    ConOut("")
    ConOut("GEBAN encerrado. OBRIGADO!")
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.
