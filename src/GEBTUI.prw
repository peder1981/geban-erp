#include "totvs.ch"
#include "GEBDB_CORE.prw"
#include "GEBDB_TENANT.prw"
#include "GENUC_MIG.prw"
#include "GEBSEC_MIG.prw"
#include "GEBSEC_POL.prw"
#include "GEBSEC_LOGIN.prw"
#include "GEBSEC_CICLO.prw"
#include "GEBSCH.prw"
#include "GEBSEC_RBA.prw"
#include "GEBSEC_TOKEN.prw"
#include "GEBEXP_CTX.prw"
#include "GEBEXP_MIG.prw"
#include "GEBAUD.prw"
#include "GEBMON.prw"
#include "GENUC_MNT.prw"
#include "GENUC_CAD.prw"
#include "GEBFIS_MIG.prw"
#include "GEBFIS_CAD.prw"
#include "GEBFIS_EMI.prw"
#include "GEBFIS_APU.prw"
#include "GEBFIN_MIG.prw"
#include "GEBFIN_FLX.prw"
#include "GEBFIN_BAI.prw"
#include "GEBFIN_CON.prw"
#include "GEBDER_MIG.prw"
#include "GEBDER_GUI.prw"
#include "GEBDER_BAI.prw"
#include "GEBDER_COB.prw"
#include "GEBV_MIG.prw"
#include "GEBV_EST.prw"
#include "GEBV_VEN.prw"
#include "GEBV_FIA.prw"
#include "GEBCTB_MIG.prw"
#include "GEBCTB_DIR.prw"
#include "GEBCTB_BAL.prw"
#include "GEBCOM_MIG.prw"
#include "GEBCOM_FOR.prw"
#include "GEBCOM_PED.prw"
#include "GEBCOM_ENT.prw"
#include "GEBFIL_MIG.prw"
#include "GEBREST.prw"
#include "GEBTUIBO.prw"
#include "GEBEXP_REL_BIZ.prw"
#include "GEBEXP_REL_NUC.prw"
#include "GEBEXP_TRAK.prw"

// bTUIBrw: com o app ativo, GEBTUIBRW mostra a tabela na pagina Resultado.
Static bTUIBrw := Nil

// s_oTUIMenu: so existe um PoMenu por aplicacao; no relogin (apos "Sair")
// reusa o objeto com os itens zerados em vez de criar outro.
Static s_oTUIMenu := Nil

/*/{Protheus.doc} GEBTUI
    Interface do GEBAN em componentes PO-UI (PoApp): login (com troca de
    senha obrigatoria/expirada), empresa e filial, menu lateral com os
    modulos permitidos e uma pagina por modulo: tabelas ao vivo (PoTable)
    e as operacoes como formularios de tela unica, que chamam as mesmas
    funcoes de negocio da API (mesmas validacoes e permissoes).
    Roda sob `advplc serve src/GEBTUI.prw`; cada janela e' uma sessao.
    @type Entrada serve
    @author Peder Munksgaard
    @since 21/11/2026
/*/
User Function GEBTUI()
    Local oApp := PoApp():New("GEBAN")
    Local oPg  := Nil

    ConOut("GEBAN - Sistema de Gestao Empresarial")
    If !GEBDBConecta() .Or. !GEBDBProvisionaCatalogo()
        MsgStop("Banco ou catalogo indisponivel.", "GEBAN")
        Return .F.
    EndIf
    oPg := PoPage():New(oApp, "GEBAN - Entrar")
    TUILogin(oApp, oPg)
    oApp:Activate()
Return .T.

/*/{Protheus.doc} TUILogin
    Formulario de acesso.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUILogin(oApp, oPg)
    Local oApr := PoWidget():New(oPg, "GEBAN - gestao empresarial")
    Local oW   := PoWidget():New(oPg, "Acesso")
    Local oUsu := PoInput():New(oW, "Usuario")
    Local oSen := PoPassword():New(oW, "Senha")
    Local oBtn := PoButton():New(oW, "Entrar")
    Local aMod := {"Fiscal e NF-e", "Financeiro", "Estoque", "Contabil", "Compras", "Faturamento", "Simples Nacional"} as Array
    Local nI   := 0 as Numeric

    // Duas colunas: apresentacao a esquerda, acesso a direita (grade de 12).
    oApr:SetCols(7)
    PoInfo():New(oApr, "", "Varias empresas e filiais numa unica instalacao, com permissao por usuario, empresa e modulo, e trilha de auditoria.")
    For nI := 1 To Len(aMod)
        PoTag():New(oApr, aMod[nI], "info"):SetCols(3)
    Next nI
    oW:SetCols(5)
    oBtn:Set("kind", "primary")
    oBtn:Set("icon", "an an-sign-in")
    oBtn:OnClick({|| TUIEntra(oApp, AllTrim(BOSTR(oUsu:GetValue())), AllTrim(BOSTR(oSen:GetValue())))})
Return

/*/{Protheus.doc} TUIEntra
    Autentica. Senha certa com troca obrigatoria ou vencida leva a troca de
    senha (antes a tela dizia "credenciais invalidas" e o usuario ficava
    preso ate um admin mexer no cadastro).
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIEntra(oApp, cUsu, cSen)
    Local cRes := "" as Character

    If Empty(cUsu) .Or. Empty(cSen)
        oApp:Notify("Informe usuario e senha.", "warning")
        Return
    EndIf
    cRes := GEBSECLOGIN(cUsu, cSen, "tui")
    If cRes == "TROCA_OBRIGATORIA" .Or. cRes == "SENHA_EXP"
        TUISenhaPg(oApp, cUsu, "Defina uma nova senha para continuar", {|| TUIEntraOk(oApp, cUsu)})
        Return
    EndIf
    If cRes != "OK"
        oApp:Notify("Credenciais invalidas.", "error")
        Return
    EndIf
    TUIEntraOk(oApp, cUsu)
Return

/*/{Protheus.doc} TUISenhaPg
    Pagina de troca da propria senha (politica aplicada por GEBTUITROCASENHA).
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
    @param bDepois, codeblock, roda apos trocar
/*/
Static Function TUISenhaPg(oApp, cUsu, cTitulo, bDepois)
    Local oPg  := PoPage():New(oApp, cTitulo)
    Local oReg := PoWidget():New(oPg, "Regras da senha")
    Local oW   := PoWidget():New(oPg, "Nova senha de " + cUsu)
    Local oS1  := PoPassword():New(oW, "Nova senha")
    Local oS2  := PoPassword():New(oW, "Confirme a nova senha")
    Local oBtn := PoButton():New(oW, "Trocar senha")

    // Duas colunas, como o login: regras a esquerda, formulario a direita.
    oReg:SetCols(7)
    PoInfo():New(oReg, "Tamanho", "Minimo de 8 caracteres")
    PoInfo():New(oReg, "Composicao", "Maiuscula, minuscula, digito e caractere especial")
    PoInfo():New(oReg, "Evite", "Sequencias (abc, 123) e o mesmo caractere 3 vezes seguidas")
    PoInfo():New(oReg, "Validade", "90 dias; vencida, o login pede a troca")
    oW:SetCols(5)
    oBtn:Set("kind", "primary")
    oBtn:OnClick({|| TUISenhaGrava(oApp, cUsu, BOSTR(oS1:GetValue()), BOSTR(oS2:GetValue()), bDepois)})
    oApp:Navigate(oPg)
Return oPg

Static Function TUISenhaGrava(oApp, cUsu, cS1, cS2, bDepois)
    Local aRes := {} as Array

    If Empty(cS1) .Or. !(cS1 == cS2)
        oApp:Notify("As senhas nao conferem.", "error")
        Return
    EndIf
    aRes := GEBTUITROCASENHA(cUsu, "", cS1, "", "")
    If !aRes[1]
        oApp:Notify("Senha recusada: " + BOSTR(aRes[2]), "error")
        Return
    EndIf
    oApp:Notify("Senha alterada.", "success")
    If bDepois != Nil
        Eval(bDepois)
    EndIf
Return

/*/{Protheus.doc} TUIEntraOk
    Usuario autenticado: empresa (o super cria a primeira com o catalogo
    vazio) e depois filial.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIEntraOk(oApp, cUsu)
    Local aEmps := GEBTUIEMPRESAS(cUsu) as Array
    Local aOps  := {} as Array
    Local oPg   := Nil
    Local oW    := Nil
    Local oCod  := Nil
    Local oNome := Nil
    Local oSel  := Nil
    Local oBtn  := Nil
    Local nI    := 0 as Numeric

    If Len(aEmps) == 0
        If !GEBSECISSUPER(cUsu)
            oApp:Notify("Nenhuma empresa vinculada a este usuario. Peca ao administrador.", "error")
            Return
        EndIf
        oPg := PoPage():New(oApp, "Primeira empresa")
        TUIAjuda(oPg, "Instalacao nova", {{"Empresa", "cada empresa tem os dados separados (um schema proprio)"}, ;
            {"Codigo", "letras, digitos e _ (ex.: 01)"}, ;
            {"Depois", "no Nucleo: filiais, usuarios, vinculos e permissoes"}})
        oW := PoWidget():New(oPg, "Catalogo vazio: crie a primeira empresa")
        oW:SetCols(5)
        oCod := PoInput():New(oW, "Codigo (letras, digitos e _)")
        oNome := PoInput():New(oW, "Nome")
        oBtn := PoButton():New(oW, "Criar empresa")
        oBtn:Set("kind", "primary")
        oBtn:OnClick({|| TUIPrimeira(oApp, cUsu, AllTrim(BOSTR(oCod:GetValue())), AllTrim(BOSTR(oNome:GetValue())))})
        oApp:Navigate(oPg)
        Return
    EndIf
    If Len(aEmps) == 1
        TUIFilial(oApp, cUsu, AllTrim(aEmps[1][1]))
        Return
    EndIf
    For nI := 1 To Len(aEmps)
        aAdd(aOps, {AllTrim(aEmps[nI][1]) + " - " + AllTrim(aEmps[nI][2]), AllTrim(aEmps[nI][1])})
    Next nI
    oPg := PoPage():New(oApp, "Empresa")
    TUIAjuda(oPg, "Empresas", {{"Acesso", "voce esta vinculado a " + cValToChar(Len(aEmps)) + " empresas"}, ;
        {"Dados", "cada empresa tem os dados separados"}, {"Trocar depois", "Sair e entrar de novo"}})
    oW := PoWidget():New(oPg, "Escolha a empresa")
    oW:SetCols(5)
    oSel := PoSelect():New(oW, "Empresa", aOps, aOps[1][2])
    oBtn := PoButton():New(oW, "Continuar")
    oBtn:Set("kind", "primary")
    oBtn:OnClick({|| TUIFilial(oApp, cUsu, BOSTR(oSel:GetValue()))})
    oApp:Navigate(oPg)
Return

Static Function TUIPrimeira(oApp, cUsu, cCod, cNome)
    If Empty(cCod) .Or. Empty(cNome)
        oApp:Notify("Informe codigo e nome.", "warning")
        Return
    EndIf
    If !GEBDBProvisionaEmpresa(cCod, cNome)
        oApp:Notify("Falha ao criar a empresa. Confira o codigo (letras, digitos e _).", "error")
        Return
    EndIf
    TUIEntraOk(oApp, cUsu)
Return

/*/{Protheus.doc} TUIFilial
    Filial da empresa: entra direto quando ha' uma so' (ou e' o super).
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIFilial(oApp, cUsu, cEmp)
    Local aFils := GEBTUIFILIAL(cUsu, cEmp) as Array
    Local oPg   := Nil
    Local oW    := Nil
    Local oSel  := Nil
    Local oBtn  := Nil

    If Len(aFils) == 0
        oApp:Notify("Sem vinculo com esta empresa.", "error")
        Return
    EndIf
    If Len(aFils) == 1
        TUIAbre(oApp, cEmp, aFils[1][2], cUsu)
        Return
    EndIf
    oPg := PoPage():New(oApp, "Filial")
    TUIAjuda(oPg, "Filiais", {{"Matriz", "a empresa sem filial"}, ;
        {"Dados", "as tabelas e os relatorios mostram os dados da filial escolhida"}, ;
        {"Trocar depois", "Sair e entrar de novo"}})
    oW := PoWidget():New(oPg, "Escolha a filial")
    oW:SetCols(5)
    oSel := PoSelect():New(oW, "Filial", aFils, aFils[1][2])
    oBtn := PoButton():New(oW, "Entrar")
    oBtn:Set("kind", "primary")
    oBtn:OnClick({|| TUIAbre(oApp, cEmp, BOSTR(oSel:GetValue()), cUsu)})
    oApp:Navigate(oPg)
Return

/*/{Protheus.doc} TUIAbre
    Abre a sessao na empresa/filial e monta menu e paginas dos modulos que o
    usuario pode ver.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIAbre(oApp, cEmp, cFil, cUsu)
    Local oMenu := Nil
    Local oRes  := Nil
    Local oResT := Nil
    Local aNav  := {Nil} as Array
    Local aMods := {} as Array
    Local oPg   := Nil
    Local oIni  := Nil
    Local aForms := {} as Array
    Local aAtalhos := {} as Array
    Local nI    := 0 as Numeric

    If !GEBDBSetTenant(cEmp)
        oApp:Notify("Empresa indisponivel.", "error")
        Return
    EndIf
    GBAUDINIC()
    GEBMONINIC()
    If !GEBEXPCONTEXTO(cEmp, cFil, cUsu)
        oApp:Notify("Sessao recusada.", "error")
        Return
    EndIf

    // Resultado de relatorio/consulta (o que antes abria FWMBrowse).
    oRes := PoPage():New(oApp, "Resultado")
    oRes:AddAction("Voltar", {|| oApp:Navigate(aNav[1])})
    oResT := PoTable():New(oRes)
    GEBTUIBRWAPP({|cAlias, cTit| oRes:Set("title", cTit), TUICarrega(oResT, cAlias, Nil), oApp:Navigate(oRes), .T.})

    // So existe um PoMenu por aplicacao: no relogin (apos "Sair") reusa o
    // objeto esvaziando os itens em vez de criar outro.
    oMenu := TUIMenuRef(oApp, .T.)
    oIni := PoPage():New(oApp, "Inicio")
    TUIMenuItem(oApp, oMenu, "Inicio", "an an-house", oIni, aNav)
    aMods := TUIModulos(cEmp, cFil, cUsu)
    aForms := TUIFormularios(cEmp, cFil)
    For nI := 1 To Len(aMods)
        If TUIPode(cUsu, aMods[nI][3])
            If Len(aMods[nI]) >= 5
                oPg := Eval(aMods[nI][5], oApp)   // pagina propria (modulo com tela custom)
            Else
                oPg := TUIModPg(oApp, aMods[nI], aForms, cUsu)
            EndIf
            aAdd(aAtalhos, {aMods[nI][1], aMods[nI][2], oPg})
            TUIMenuItem(oApp, oMenu, aMods[nI][1], aMods[nI][2], oPg, aNav)
        EndIf
    Next nI
    oPg := PoPage():New(oApp, "Rastreabilidade")
    TUIRastreio(oApp, oPg)
    TUIMenuItem(oApp, oMenu, "Rastreabilidade", "an an-path", oPg, aNav)
    oPg := PoPage():New(oApp, "Minha senha")
    TUIMenuItem(oApp, oMenu, "Minha senha", "an an-key", oPg, aNav)
    TUISenhaForm(oApp, oPg, cUsu)
    oMenu:AddItem("Sair", "an an-sign-out", {|| TUISair(oApp, oMenu)})
    TUIInicio(oApp, oIni, cEmp, cFil, cUsu, aAtalhos, aNav)
    aNav[1] := oIni
    oApp:Notify("Bem-vindo, " + cUsu + " (" + cEmp + ").", "success")
    oApp:Navigate(oIni)
Return

// Item de menu que lembra a pagina (Voltar do Resultado). Funcao propria para
// o bloco capturar a pagina certa, nao a variavel do laco.
Static Function TUIMenuItem(oApp, oMenu, cRot, cIcone, oPg, aNav)
    oMenu:AddItem(cRot, cIcone, {|| aNav[1] := oPg, oApp:Navigate(oPg)})
Return

/*/{Protheus.doc} TUIMenuRef
    Um PoMenu por aplicacao. No relogin reusa o existente (itens zerados).
    @type function
    @since 27/11/2026
/*/
Static Function TUIMenuRef(oApp, lReset)
    If s_oTUIMenu == Nil
        s_oTUIMenu := PoMenu():New(oApp)
    ElseIf lReset
        // ClearItems (nao Set("items",{})): esvazia itens e handlers sem
        // trocar o tipo interno da lista -- Set() quebraria o proximo AddItem.
        s_oTUIMenu:ClearItems()
    EndIf
Return s_oTUIMenu

/*/{Protheus.doc} TUISair
    "Sair" do menu lateral. oApp:Close() encerrava a sessao e deixava a
    aba em branco (o browser nao recarrega): aqui o menu e esvaziado e a
    navegacao volta para uma tela de acesso nova.
    @type function
    @since 27/11/2026
/*/
Static Function TUISair(oApp, oMenu)
    Local oPg := PoPage():New(oApp, "GEBAN - Entrar")
    oMenu:ClearItems()
    TUILogin(oApp, oPg)
    oApp:Navigate(oPg)
Return

Static Function TUISenhaForm(oApp, oPg, cUsu)
    Local oW   := PoWidget():New(oPg, "Trocar minha senha")
    Local oS1  := PoPassword():New(oW, "Nova senha")
    Local oS2  := PoPassword():New(oW, "Confirme a nova senha")
    Local oBtn := PoButton():New(oW, "Trocar senha")

    oW:SetCols(4)
    oBtn:Set("kind", "primary")
    oBtn:OnClick({|| TUISenhaGrava(oApp, cUsu, BOSTR(oS1:GetValue()), BOSTR(oS2:GetValue()), Nil)})
Return

// Permissao do modulo: "ADMIN" = Nucleo (admin da empresa ou super).
Static Function TUIPode(cUsu, cMenu)
    If cMenu == "ADMIN"
        Return GEBSECPODE(cUsu, "", .F.)
    EndIf
Return GEBTUIMODOK(cUsu, cMenu, .F.)

/*/{Protheus.doc} TUIModulos
    Modulos do menu: {rotulo, icone, permissao, tabelas {{alias, titulo}},
    telas {{titulo, bloco da tela, opcoes que nao viram botao}}}. As opcoes
    puladas sao as de grade (viram tabela), as que abrem outra tela (viram
    aba propria) e o "< Voltar".
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIModulos(cEmp, cFil, cUsu)
Return { ;
    {"Fiscal", "an an-receipt", "FISCAL", {{"GF1", "Produtos"}, {"GF3", "Notas"}, {"GSN2", "Apuracoes do Simples"}, {"GSN3", "Atividades do Simples"}}}, ;
    {"Financeiro", "an an-wallet", "FINANCEIRO", {{"GFN1", "Contas"}}}, ;
    {"Derrama", "an an-bank", "DERRAMA", {{"GD1", "Guias"}}}, ;
    {"Estoque", "an an-package", "ESTOQUE", {{"GV1", "Saldos"}, {"GV2", "Vendas"}}}, ;
    {"Contabil", "an an-calculator", "CONTABIL", {{"GC1", "Plano de contas"}, {"GC2", "Lancamentos"}}}, ;
    {"Compras", "an an-shopping-cart", "COMPRAS", {{"GCP1", "Fornecedores"}, {"GCP3", "Pedidos"}}}, ;
    {"Faturamento", "an an-file-text", "FATURAMENTO", {{"GFT1", "Clientes"}, {"GFT2", "Precos"}, {"GFT3", "Pedidos de venda"}, {"GSK1", "Regras Sarney"}, ;
        {"GSK3", "Historico Sarney"}, {"GCK1", "Wallets crypto"}, {"GCK2", "Pagamentos crypto"}}}, ;
    {"Nucleo", "an an-gear", "ADMIN", {{"GE1", "Empresas"}, {"GEU1", "Unidades"}, {"GEF1", "Filiais"}, {"GE2", "Usuarios"}}} ;
    }

/*/{Protheus.doc} TUIModPg
    Pagina do modulo, de cima para baixo: tabelas em abas (PoTable ao vivo;
    clicar numa linha preenche os campos ligados dos formularios), os
    formularios em abas por grupo. Toda operacao rele as tabelas.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIModPg(oApp, aMod, aForms, cUsu)
    Local oPg    := PoPage():New(oApp, aMod[1])
    Local oTabs  := Nil
    Local aTabs  := {} as Array
    Local aLinks := {} as Array
    Local aGrp   := {} as Array
    Local oFTabs := Nil
    Local cGrp   := "" as Character
    Local nG     := 0 as Numeric
    Local bRel   := Nil
    Local oT     := Nil
    Local nI     := 0 as Numeric

    bRel := {|| TUIRecarrega(aTabs)}
    If Len(aMod[4]) > 0
        oTabs := PoTabs():New(oPg)
        For nI := 1 To Len(aMod[4])
            oT := PoTable():New(PoTab():New(oTabs, aMod[4][nI][2]))
            aAdd(aTabs, {oT, aMod[4][nI][1], {}})
            TUISelecao(oT, aTabs[nI][3], aLinks)
        Next nI
    EndIf
    // Formularios em abas por grupo (Operacoes, Banco, Relatorios), pela ordem de aparicao.
    For nI := 1 To Len(aForms)
        If aForms[nI][1] == aMod[1]
            cGrp := TUIGrupo(aForms[nI][4])
            nG := aScan(aGrp, {|x| x[1] == cGrp})
            If nG == 0
                If oFTabs == Nil
                    oFTabs := PoTabs():New(oPg)
                EndIf
                aAdd(aGrp, {cGrp, PoTab():New(oFTabs, cGrp)})
                nG := Len(aGrp)
            EndIf
            TUIForm(oApp, aGrp[nG][2], aForms[nI], cUsu, aLinks, bRel)
        EndIf
    Next nI
    oPg:AddAction("Atualizar", bRel)
    TUIRecarrega(aTabs)
Return oPg

Static Function TUIRecarrega(aTabs)
    Local nI := 0 as Numeric

    For nI := 1 To Len(aTabs)
        TUICarrega(aTabs[nI][1], aTabs[nI][2], aTabs[nI][3])
    Next nI
Return

// Linha clicada: copia as colunas ligadas para os campos dos formularios.
Static Function TUISelecao(oTab, aCol, aLinks)
    oTab:OnSelect({|o, aLin| TUIPreenche(aLin, aCol, aLinks)})
Return

Static Function TUIPreenche(aLin, aCol, aLinks)
    Local nI := 0 as Numeric
    Local nP := 0 as Numeric

    If ValType(aLin) != "A"
        Return
    EndIf
    For nI := 1 To Len(aLinks)
        nP := aScan(aCol, aLinks[nI][2])
        If nP > 0 .And. nP <= Len(aLin)
            aLinks[nI][1]:SetValue(aLin[nP])
        EndIf
    Next nI
Return

/*/{Protheus.doc} TUIFormularios
    Operacoes principais como formulario de uma tela so':
    {modulo, tela, opcao substituida, titulo, campos, bloco, status de
    sucesso, mensagem}. Campo: {rotulo, "C" | "N" | {opcoes}, padrao,
    coluna ligada (a linha clicada na tabela preenche)}. Os blocos chamam
    as mesmas funcoes de negocio da tela antiga e da API.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIFormularios(cEmp, cFil)
    Local aF := TUIFormBase() as Array

    aEval(TUIFormDfe(cEmp, cFil), {|x| aAdd(aF, x)})
    aEval(TUIFormNuc(cEmp), {|x| aAdd(aF, x)})
Return aF

Static Function TUIFormBase()
    Local cComp := Left(DToS(Date()), 6) as Character
    Local cHoje := BOHOJE() as Character
    Local aRP   := {{"Receber", "R"}, {"Pagar", "P"}} as Array
    Local aFlx  := {"FINANCEIRO", "FLUXO"} as Array
    Local aBco  := {"FINANCEIRO", "BANCO"} as Array
    Local aEst  := {"ESTOQUE", "ESTOQ"} as Array
    Local aCtb  := {"CONTABIL", "LANCTO"} as Array
    Local cIni  := Left(cHoje, 6) + "01" as Character
    Local cFech := BOPARM("EST_FECHADO", "") as Character
    Local aSN   := {{"Nao", "N"}, {"Sim", "S"}} as Array
    Local aPed  := {"COMPRAS", "PEDID"} as Array
    Local aApu  := {"FISCAL", "APURA"} as Array
    Local aFat  := {"FATURAMENTO", "FATUR"} as Array
    Local aAnexo := {{"Anexo I", "I"}, {"Anexo II", "II"}, {"Anexo III", "III"}, {"Anexo IV", "IV"}, {"Anexo V", "V"}, {"Fator R (III ou V)", "FR"}} as Array
Return { ;
    {"Fiscal", 0, 0, "Novo produto", {{"Codigo", "C", ""}, {"NCM", "C", ""}, {"Descricao", "C", ""}}, {|u, a| GEBRESTPRDLSC(u, a)}, "201", "Produto criado."}, ;
    {"Fiscal", 0, 0, "Emitir nota", {{"Chave", "C", ""}, {"Produto", "C", "", "GF1_COD"}, {"Quantidade", "N", 1}, {"Preco", "N", 0}}, {|u, a| GEBRESTNOTPOST(u, a)}, "201", "Nota emitida."}, ;
    {"Fiscal", 0, 0, "Apurar competencia", {{"Competencia (AAAAMM)", "C", cComp}}, {|u, a| GEBRESTFISAPU(u, a)}, "200", "Competencia apurada."}, ;
    {"Financeiro", 0, 0, "Nova conta", {{"Conta", "C", ""}, {"Nome", "C", ""}}, {|u, a| GEBRESTFINCON(u, a)}, "201", "Conta criada."}, ;
    {"Financeiro", 0, 0, "Titulo parcelado", {{"Tipo", aRP, "R"}, {"Documento", "C", ""}, {"Cliente/fornecedor", "C", ""}, {"Valor total", "N", 0}, ;
        {"Condicao (codigo ou dias)", "C", "0"}, {"Emissao (AAAAMMDD)", "C", cHoje}}, {|u, a| GEBFXTIT(a[1], a[2], a[3], a[4], a[5], a[6], "TELA", "")}, "BO", "", aFlx}, ;
    {"Financeiro", 0, 0, "Baixa com juros e multa", {{"Tipo", aRP, "R"}, {"Documento (com a parcela, ex.: NF1/01)", "C", ""}, {"Data (AAAAMMDD)", "C", cHoje}, ;
        {"Principal", "N", 0}, {"Juros", "N", 0}, {"Multa", "N", 0}, {"Desconto", "N", 0}, {"Conta", "C", "CAIXA"}}, ;
        {|u, a| GEBFXBAI(a[1], a[2], a[4], a[5], a[6], a[7], a[8], a[3])}, "BO", "", aFlx, ;
        {"Calcular juros e multa", {|a| TUICalcBaixa(a)}}}, ;
    {"Financeiro", 0, 0, "Transferencia entre contas", {{"Conta de origem", "C", "", "GFN1_CONTA"}, {"Conta de destino", "C", ""}, {"Valor", "N", 0}, ;
        {"Data (AAAAMMDD)", "C", cHoje}, {"Historico", "C", ""}}, {|u, a| GEBFXTRF(a[1], a[2], a[3], a[4], a[5])}, "BO", "", aFlx}, ;
    {"Financeiro", 0, 0, "Movimento avulso", {{"Conta", "C", "", "GFN1_CONTA"}, {"Tipo", {{"Saida (D)", "D"}, {"Entrada (C)", "C"}}, "D"}, {"Valor", "N", 0}, ;
        {"Historico", "C", ""}, {"Data (AAAAMMDD)", "C", cHoje}, {"Conta contabil (vazio = padrao)", "C", ""}, {"Centro de custo ou rateio", "C", ""}}, ;
        {|u, a| GEBFXMOV(a[1], a[2], a[3], a[4], a[5], a[6], a[7])}, "BO", "", aFlx}, ;
    {"Financeiro", 0, 0, "Despesa a pagar", {{"Documento", "C", ""}, {"Fornecedor", "C", ""}, {"Valor", "N", 0}, {"Condicao (codigo ou dias)", "C", "0"}, ;
        {"Emissao (AAAAMMDD)", "C", cHoje}, {"Conta de despesa (vazio = 4.02.006)", "C", ""}, {"Centro de custo ou rateio", "C", ""}, {"Historico", "C", ""}}, ;
        {|u, a| GEBFXDESP(a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8])}, "BO", "", aFlx}, ;
    {"Financeiro", 0, 0, "Condicao de pagamento", {{"Codigo", "C", ""}, {"Descricao", "C", ""}, {"Dias das parcelas (ex.: 30,60,90; 0 = a vista)", "C", "0"}}, ;
        {|u, a| GEBFXCOND(a[1], a[2], a[3])}, "BO", "", aFlx}, ;
    {"Financeiro", 0, 0, "Relatorio: titulos por atraso", {{"Tipo", aRP, "R"}, {"Posicao em (AAAAMMDD)", "C", cHoje}}, ;
        {|u, a| GEBFXPOSICAO(a[1], a[2])}, "REL", "", aFlx}, ;
    {"Financeiro", 0, 0, "Relatorio: extrato da conta", {{"Conta", "C", "CAIXA", "GFN1_CONTA"}, {"Inicio (AAAAMMDD)", "C", Left(cHoje, 6) + "01"}, {"Fim (AAAAMMDD)", "C", cHoje}}, ;
        {|u, a| GEBFXEXTRATO(a[1], a[2], a[3])}, "REL", "", aFlx}, ;
    {"Financeiro", 0, 0, "Relatorio: fluxo de caixa projetado", {{"Inicio (AAAAMMDD)", "C", cHoje}, {"Dias", "N", 30}}, ;
        {|u, a| GEBFXFLUXO(a[1], a[2])}, "REL", "", aFlx}, ;
    {"Financeiro", 0, 0, "Banco: dados de cobranca da conta", {{"Conta financeira", "C", "BANCO", "GFN1_CONTA"}, ;
        {"Banco", {{"001 Banco do Brasil", "001"}, {"033 Santander", "033"}, {"104 Caixa", "104"}, {"237 Bradesco", "237"}, {"341 Itau", "341"}, {"756 Sicoob", "756"}}, "237"}, ;
        {"Agencia/cooperativa (4 digitos)", "C", ""}, {"DV da agencia", "C", ""}, {"Conta corrente", "C", ""}, {"DV da conta", "C", ""}, ;
        {"Carteira (Santander: 101/104)", "C", ""}, {"Codigo do beneficiario/convenio no banco", "C", ""}, {"Beneficiario (razao social)", "C", ""}, ;
        {"CNPJ", "C", ""}, {"Leiaute CNAB 240 ou 400 (vazio = padrao do banco)", "C", ""}, {"Modalidade (Sicoob; vazio = 01)", "C", ""}}, ;
        {|u, a| GEBBCOCFG(a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12])}, "BO", "", aBco}, ;
    {"Financeiro", 0, 0, "Banco: gerar boleto do titulo", {{"Titulo a receber (documento com a parcela)", "C", ""}, {"Conta de cobranca", "C", "BANCO"}}, ;
        {|u, a| TUIBoleto(a)}, "BO", "", aBco}, ;
    {"Financeiro", 0, 0, "Banco: gerar remessa CNAB", {{"Conta de cobranca", "C", "BANCO"}, {"Gravar em (caminho no servidor)", "C", "/tmp/remessa_BANCO.rem"}}, ;
        {|u, a| GEBBCOREM(a[1], a[2])}, "BO", "", aBco}, ;
    {"Financeiro", 0, 0, "Banco: ler retorno CNAB (baixa)", {{"Conta", "C", "BANCO"}, {"Arquivo (caminho no servidor)", "C", ""}}, ;
        {|u, a| TUIArquivo(a[2], {|c| GEBBCORET(a[1], c)})}, "BO", "", aBco}, ;
    {"Financeiro", 0, 0, "Banco: importar extrato OFX", {{"Conta", "C", "BANCO"}, {"Arquivo (caminho no servidor)", "C", ""}}, ;
        {|u, a| TUIArquivo(a[2], {|c| GEBBCOOFX(a[1], c)})}, "BO", "", aBco}, ;
    {"Financeiro", 0, 0, "Banco: conciliar automatico", {{"Conta", "C", "BANCO"}}, {|u, a| GEBBCOCONC(a[1])}, "BO", "", aBco}, ;
    {"Financeiro", 0, 0, "Banco: conciliar na mao", {{"Conta", "C", "BANCO"}, {"FITID da linha do extrato", "C", ""}, {"Movimento (numero do relatorio; 0 desfaz)", "N", 0}}, ;
        {|u, a| GEBBCOCONCMAN(a[1], a[2], a[3])}, "BO", "", aBco}, ;
    {"Financeiro", 0, 0, "Banco: lancar linha do extrato (tarifa)", {{"Conta", "C", "BANCO"}, {"FITID da linha do extrato", "C", ""}, {"Conta contabil (vazio = padrao)", "C", ""}, ;
        {"Centro de custo (vazio = nenhum)", "C", ""}}, {|u, a| GEBBCOLANCA(a[1], a[2], a[3], a[4])}, "BO", "", aBco}, ;
    {"Financeiro", 0, 0, "Relatorio: conciliacao bancaria", {{"Conta", "C", "BANCO"}, {"Inicio (AAAAMMDD)", "C", cIni}, {"Fim (AAAAMMDD)", "C", cHoje}}, ;
        {|u, a| GEBBCOREL(a[1], a[2], a[3])}, "REL", "", aBco}, ;
    {"Estoque", 0, 0, "Saldo e custo medio", {{"Produto", "C", "", "GV1_PROD"}, {"Armazem (vazio = todos)", "C", ""}}, {|u, a| TUISaldo(a)}, "BO", "", aEst}, ;
    {"Estoque", 0, 0, "Controle de lote/serie/endereco", {{"Produto", "C", "", "GV1_PROD"}, {"Rastro", {{"Nenhum", "N"}, {"Lote", "L"}, {"Serie", "S"}}, "N"}, ;
        {"Controla endereco", aSN, "N"}}, {|u, a| GEBESTCTL(a[1], a[2], a[3])}, "BO", "", aEst}, ;
    {"Estoque", 0, 0, "Cadastrar endereco", {{"Armazem", "C", "01"}, {"Endereco (ex.: A-01-03)", "C", ""}, {"Descricao", "C", ""}}, ;
        {|u, a| GEBESTENDER(a[1], a[2], a[3])}, "BO", "", aEst}, ;
    {"Estoque", 0, 0, "Mudar lote de endereco", {{"Produto", "C", "", "GV1_PROD"}, {"Armazem", "C", "01"}, {"Lote/serie (vazio se nao controla)", "C", ""}, ;
        {"Endereco de origem", "C", ""}, {"Endereco de destino", "C", ""}, {"Quantidade", "N", 0}}, ;
        {|u, a| GEBESTENDTRF(a[1], a[2], a[3], a[4], a[5], a[6], BOHOJE())}, "BO", "", aEst}, ;
    {"Estoque", 0, 0, "Fechar mes", {{"Competencia (AAAAMM)", "C", BOMESADD(Left(cHoje, 6), -1)}}, {|u, a| GEBESTFECHA(a[1])}, "BO", "", aEst}, ;
    {"Estoque", 0, 0, "Reabrir ultimo mes fechado", {{"Competencia (AAAAMM)", "C", cFech}}, {|u, a| GEBESTREABRE(a[1])}, "BO", "", aEst}, ;
    {"Estoque", 0, 0, "Relatorio: kardex", {{"Produto", "C", "", "GV1_PROD"}, {"Armazem (vazio = todos)", "C", ""}, {"Inicio (AAAAMMDD)", "C", cIni}, {"Fim (AAAAMMDD)", "C", cHoje}}, ;
        {|u, a| GEBESTKARDEX(a[1], a[2], a[3], a[4])}, "REL", "", aEst}, ;
    {"Estoque", 0, 0, "Relatorio: posicao valorizada", {{"Armazem (vazio = todos)", "C", ""}}, {|u, a| GEBESTPOS(a[1])}, "REL", "", aEst}, ;
    {"Estoque", 0, 0, "Relatorio: saldo por lote/endereco", {{"Produto (vazio = todos)", "C", "", "GV1_PROD"}, {"Armazem (vazio = todos)", "C", ""}}, ;
        {|u, a| GEBESTLOTES(a[1], a[2], BOHOJE())}, "REL", "", aEst}, ;
    {"Estoque", 0, 0, "Relatorio: lotes a vencer", {{"Vencendo em ate (dias)", "N", 30}}, {|u, a| GEBESTVENCER(a[1], BOHOJE())}, "REL", "", aEst}, ;
    {"Estoque", 0, 0, "Relatorio: fechamento do mes", {{"Competencia (AAAAMM)", "C", cFech}}, {|u, a| GEBESTFECHREL(a[1])}, "REL", "", aEst}, ;
    {"Contabil", 0, 0, "Centro de custo", {{"Codigo do centro", "C", ""}, {"Descricao", "C", ""}, {"Bloqueado", aSN, "N"}}, ;
        {|u, a| GEBCTXCC(a[1], a[2], a[3])}, "BO", "", aCtb}, ;
    {"Contabil", 0, 0, "Corrigir lancamentos antigos (estorno e lancamento certo)", {}, {|u, a| GEBCTXCORRIGE()}, "REL", "", {"CONTABIL", "DIR"}}, ;
    {"Contabil", 0, 0, "Relatorio: razao da conta", {{"Conta (ex.: 1.01.001)", "C", "", "GC1_CONTA"}, {"Inicio (AAAAMMDD)", "C", cIni}, {"Fim (AAAAMMDD)", "C", cHoje}}, ;
        {|u, a| GEBCTXRAZAO(a[1], a[2], a[3])}, "REL", "", aCtb}, ;
    {"Contabil", 0, 0, "Relatorio: balancete do periodo", {{"Inicio (AAAAMMDD)", "C", cIni}, {"Fim (AAAAMMDD)", "C", cHoje}, {"Centro de custo (vazio = todos)", "C", ""}}, ;
        {|u, a| GEBCTXBALAN(a[1], a[2], a[3])}, "REL", "", aCtb}, ;
    {"Contabil", 0, 0, "Relatorio: DRE do periodo", {{"Inicio (AAAAMMDD)", "C", cIni}, {"Fim (AAAAMMDD)", "C", cHoje}, {"Centro de custo (vazio = todos)", "C", ""}}, ;
        {|u, a| GEBCTXDRE(a[1], a[2], a[3])}, "REL", "", aCtb}, ;
    {"Contabil", 0, 0, "Relatorio: resultado por centro de custo", {{"Inicio (AAAAMMDD)", "C", cIni}, {"Fim (AAAAMMDD)", "C", cHoje}}, ;
        {|u, a| GEBCTXCCRES(a[1], a[2])}, "REL", "", aCtb}, ;
    {"Compras", 0, 0, "Gerar pedidos da solicitacao (menor preco)", {{"Solicitacao", "C", ""}, {"Condicao de pagamento", "C", ""}, {"Armazem de entrega", "C", "01"}, ;
        {"Data (AAAAMMDD)", "C", cHoje}}, {|u, a| GEBCPXGERA(a[1], a[2], a[3], a[4])}, "BO", "", aPed}, ;
    {"Compras", 0, 0, "Aprovar ou rejeitar pedido (alcada)", {{"Pedido", "C", "", "GCP3_NUM"}, {"Decisao", {{"Aprovar", "S"}, {"Rejeitar", "N"}}, "S"}}, ;
        {|u, a| GEBCPXAPR(a[1], u, a[2] == "S")}, "BO", "", {"COMPRAS", "APROVA"}}, ;
    {"Compras", 0, 0, "Regra de retencao (ISS, IRRF, INSS, PIS, COFINS, CSLL)", {{"Codigo da retencao", "C", ""}, ;
        {"Tributo", {"ISS", "IRRF", "INSS", "PIS", "COFINS", "CSLL"}, "ISS"}, {"Aliquota %", "N", 0}, {"Descricao", "C", ""}}, ;
        {|u, a| GEBRETCAD(a[1], a[2], a[3], a[4])}, "BO", "", aApu}, ;
    {"Compras", 0, 0, "NF-e: buscar na SEFAZ", {}, {|u, a| GEBDFEDISTBUSCA()}, "BO", "", aPed}, ;
    {"Compras", 0, 0, "NF-e: manifestar", {{"Chave da NF-e recebida", "C", ""}, ;
        {"Evento", {{"Ciencia", "CIENCIA"}, {"Confirmacao", "CONFIRMACAO"}, {"Desconhecimento", "DESCONHECIMENTO"}, {"Nao realizada", "NAO_REALIZADA"}}, "CIENCIA"}, ;
        {"Justificativa (so' nao realizada; minimo 15 letras)", "C", ""}}, {|u, a| TUIManif(a)}, "BO", "", aPed}, ;
    {"Compras", 0, 0, "NF-e: produto do fornecedor = produto do GEBAN", {{"Fornecedor (codigo no GEBAN)", "C", "", "GCP1_COD"}, {"Codigo do produto na nota", "C", ""}, ;
        {"Produto no GEBAN", "C", ""}, {"Fator (unidades do GEBAN por unidade da nota)", "N", 1}}, {|u, a| GEBDFEDEPARA(a[1], a[2], a[3], a[4])}, "BO", "", aPed}, ;
    {"Compras", 0, 0, "NF-e: importar como entrada", {{"Chave da NF-e recebida", "C", ""}, {"Pedido de compra (vazio = gera da nota)", "C", "", "GCP3_NUM"}, ;
        {"Data (AAAAMMDD)", "C", cHoje}}, {|u, a| GEBDFEIMPORTA(a[1], a[2], a[3])}, "BO", "", aPed}, ;
    {"Compras", 0, 0, "Relatorio: pedidos em aberto", {}, {|u, a| GEBCPXABERTOS()}, "REL", "", aPed}, ;
    {"Compras", 0, 0, "Relatorio: compras por fornecedor", {{"Inicio (AAAAMMDD)", "C", cIni}, {"Fim (AAAAMMDD)", "C", cHoje}}, ;
        {|u, a| GEBCPXPORFORN(a[1], a[2])}, "REL", "", aPed}, ;
    {"Compras", 0, 0, "Relatorio: solicitacoes pendentes", {}, {|u, a| GEBCPXSCPEND()}, "REL", "", aPed}, ;
    {"Compras", 0, 0, "Relatorio: retencoes do mes", {{"Competencia (AAAAMM)", "C", cComp}}, {|u, a| GEBRETREL(a[1])}, "REL", "", aApu}, ;
    {"Compras", 0, 0, "Relatorio: NF-e recebidas", {{"Situacao", {{"Todas", ""}, {"Autorizada", "AUTORIZADA"}, {"Cancelada", "CANCELADA"}}, ""}}, ;
        {|u, a| GEBDFERECEBIDAS(a[1])}, "REL", "", aPed}, ;
    {"Faturamento", 0, 0, "Cliente (novo ou alterar)", {{"Codigo", "C", "", "GFT1_COD"}, {"Nome", "C", "", "GFT1_NOME"}, {"CNPJ/CPF", "C", "", "GFT1_DOC"}, ;
        {"UF", "C", "", "GFT1_UF"}, {"Limite de credito (0 = sem limite)", "N", 0}, {"Condicao padrao", "C", "", "GFT1_COND"}, {"Tabela de preco (vazio = PADRAO)", "C", "", "GFT1_TABELA"}}, ;
        {|u, a| GEBFATCLI(a[1], a[2], a[3], a[4], a[5], a[6], a[7])}, "BO", "", aFat}, ;
    {"Faturamento", 0, 0, "Preco na tabela", {{"Tabela (vazio = PADRAO)", "C", ""}, {"Produto", "C", ""}, {"Preco", "N", 0}}, ;
        {|u, a| GEBFATPRC(a[1], a[2], a[3])}, "BO", "", aFat}, ;
    {"Faturamento", 0, 0, "Sarney: regra de reajuste programado de precos", {{"Codigo", "C", ""}, {"Descricao", "C", ""}, {"Percentual geral %", "N", 0}, ;
        {"Total de aplicacoes", "N", 1}, {"Horarios HHMM separados por espaco (ex.: 0800 1200 1800)", "C", "0800"}, {"Ativo", aSN, "S"}}, ;
        {|u, a| GESSARCFG(a[1], a[2], a[3], a[4], a[5], a[6])}, "BO", "", aFat}, ;
    {"Faturamento", 0, 0, "Sarney: % proprio do produto na regra (0 remove)", {{"Regra (codigo)", "C", ""}, {"Produto", "C", ""}, {"Percentual %", "N", 0}}, ;
        {|u, a| GESSARPROD(a[1], a[2], a[3])}, "BO", "", aFat}, ;
    {"Faturamento", 0, 0, "Crypto: wallet (recebimento em moeda digital)", {{"Moeda", {"BTC", "ETH", "XMR", "USDC", "USDT"}, "BTC"}, ;
        {"Endereco da wallet", "C", ""}, {"Ativo", aSN, "S"}}, {|u, a| GEBCRYWAL(a[1], a[2], a[3])}, "BO", "", aFat}, ;
    {"Faturamento", 0, 0, "Liberar pedido (credito/estoque)", {{"Pedido", "C", ""}, {"Forcar mesmo bloqueado", aSN, "N"}}, ;
        {|u, a| TUILibera(u, a)}, "BO", "", aFat}, ;
    {"Faturamento", 0, 0, "Cancelar pedido", {{"Pedido", "C", ""}}, {|u, a| GEBFATCAN(a[1])}, "BO", "", aFat}, ;
    {"Faturamento", 0, 0, "Relatorio: faturamento e margem", {{"Inicio (AAAAMMDD)", "C", cIni}, {"Fim (AAAAMMDD)", "C", cHoje}, ;
        {"Agrupar por", {{"Cliente", "CLIENTE"}, {"Produto", "PRODUTO"}}, "CLIENTE"}}, {|u, a| GEBFATREL(a[1], a[2], a[3])}, "REL", "", aFat}, ;
    {"Faturamento", 0, 0, "Relatorio: carteira de pedidos", {}, {|u, a| GEBFATCARTEIRA()}, "REL", "", aFat}, ;
    {"Faturamento", 0, 0, "Relatorio: curva ABC", {{"Inicio (AAAAMMDD)", "C", cIni}, {"Fim (AAAAMMDD)", "C", cHoje}}, {|u, a| GEBFATABC(a[1], a[2])}, "REL", "", aFat}, ;
    {"Fiscal", 0, 0, "Lancar credito", {{"Competencia (AAAAMM)", "C", cComp}, {"Origem", "C", ""}, {"Valor", "N", 0}, {"Tipo", "C", ""}}, ;
        {|u, a| TUIFisCredito(a)}, "BO", "", {"FISCAL", "APURA"}}, ;
    {"Fiscal", 0, 0, "Aliquota da NCM (IBS/CBS)", {{"NCM", "C", ""}, {"IBS %", "N", 0}, {"CBS %", "N", 0}, ;
        {"Vigencia inicio (AAAAMMDD)", "C", DToS(Date())}, {"Vigencia fim (AAAAMMDD)", "C", "20991231"}}, ;
        {|u, a| TUIRestBO(GEBRESTALISC(u, {a[1], cValToChar(a[2]), cValToChar(a[3]), a[4], a[5]}))}, "BO", "", {"FISCAL", "PRODUT"}}, ;
    {"Fiscal", 0, 0, "Simples: configurar anexo padrao", {{"Anexo", aAnexo, Upper(AllTrim(GEBCFG("SN_ANEXO")))}, ;
        {"Inicio de atividade (AAAAMM; vazio se tem mais de 12 meses)", "C", AllTrim(GEBCFG("SN_INICIO"))}}, {|u, a| GEBSNCFG(a[1], a[2])}, "BO", "", aApu}, ;
    {"Fiscal", 0, 0, "Simples: atividade (codigo e anexo)", {{"Codigo da atividade (ate 10 caracteres)", "C", ""}, {"Descricao", "C", ""}, {"Anexo", aAnexo, "III"}}, ;
        {|u, a| GEBSNATV(a[1], a[2], a[3])}, "BO", "", aApu}, ;
    {"Fiscal", 0, 0, "Simples: produto (atividade, ST, monofasico)", {{"Produto", "C", "", "GF1_COD"}, {"Atividade (vazio = anexo padrao)", "C", ""}, ;
        {"ICMS por substituicao tributaria", aSN, "N"}, {"PIS/COFINS monofasico", aSN, "N"}}, {|u, a| GEBSNPRD(a[1], a[2], a[3], a[4])}, "BO", "", aApu}, ;
    {"Fiscal", 0, 0, "Simples: nota de exportacao", {{"Chave da nota", "C", "", "GF3_CHAVE"}, {"Exportacao", {{"Sim", "S"}, {"Nao", "N"}}, "S"}}, ;
        {|u, a| GEBSNEXP(a[1], a[2])}, "BO", "", aApu}, ;
    {"Fiscal", 0, 0, "Simples: folha e receita externa do mes", {{"Competencia (AAAAMM)", "C", cComp}, ;
        {"Folha do mes (salarios + pro-labore + encargos)", "N", 0}, {"Receita do mes fora do GEBAN", "N", 0}, {"Atividade da receita (vazio = anexo padrao)", "C", ""}}, ;
        {|u, a| GEBSNFOL(a[1], a[2], a[3], a[4])}, "BO", "", aApu}, ;
    {"Fiscal", 0, 0, "Simples: feriado municipal/estadual", {{"Data do feriado (AAAAMMDD)", "C", ""}, {"Descricao", "C", ""}}, ;
        {|u, a| GEBSNFER(a[1], a[2])}, "BO", "", aApu}, ;
    {"Fiscal", 0, 0, "Simples: apurar mes (DAS)", {{"Competencia (AAAAMM)", "C", cComp}}, {|u, a| TUISNApura(a[1])}, "BO", "", aApu}, ;
    {"Fiscal", 0, 0, "Relatorio: extrato da apuracao do Simples", {{"Competencia (AAAAMM)", "C", cComp}}, {|u, a| GEBSNEXTRATO(a[1])}, "REL", "", aApu}, ;
    {"Fiscal", 0, 0, "Relatorio: acompanhamento anual do Simples", {{"Ano (AAAA)", "C", Left(DToS(Date()), 4)}}, {|u, a| GEBSNANUAL(a[1])}, "REL", "", aApu}, ;
    {"Estoque", 0, 0, "Movimento com custo (entrada/saida)", {{"Produto", "C", "", "GV1_PROD"}, {"Armazem", "C", "01"}, ;
        {"Tipo", {{"Entrada", "E"}, {"Saida", "S"}}, "E"}, {"Quantidade", "N", 0}, {"Custo unitario (entrada)", "N", 0}, {"Documento", "C", ""}, ;
        {"Data (AAAAMMDD)", "C", cHoje}, {"Lote/series separadas por ; (vazio se nao controla)", "C", ""}, {"Validade (AAAAMMDD)", "C", ""}, ;
        {"Endereco (vazio se nao controla)", "C", ""}}, ;
        {|u, a| GEBESTMOV(a[1], a[2], a[3], a[4], a[5], "TELA", a[6], a[7], GEBESTDET(a[8], a[9], a[10], a[4]))}, "BO", "", aEst}, ;
    {"Estoque", 0, 0, "Inventario (contagem)", {{"Produto", "C", "", "GV1_PROD"}, {"Armazem", "C", "01"}, {"Quantidade contada", "N", 0}, ;
        {"Custo se o produto nao tem custo medio", "N", 0}, {"Documento", "C", ""}, {"Data (AAAAMMDD)", "C", cHoje}, ;
        {"Lote/series separadas por ; (vazio se nao controla)", "C", ""}, {"Validade (AAAAMMDD)", "C", ""}, {"Endereco (vazio se nao controla)", "C", ""}}, ;
        {|u, a| TUIInventario(a)}, "BO", "", aEst}, ;
    {"Estoque", 0, 0, "Transferencia entre armazens", {{"Produto", "C", "", "GV1_PROD"}, {"Armazem de origem", "C", "01"}, {"Armazem de destino", "C", ""}, ;
        {"Quantidade", "N", 0}, {"Documento", "C", ""}, {"Data (AAAAMMDD)", "C", cHoje}, {"Lote/series separadas por ; (vazio se nao controla)", "C", ""}, ;
        {"Validade (AAAAMMDD)", "C", ""}, {"Endereco de origem (vazio se nao controla)", "C", ""}, {"Endereco de destino (vazio = o mesmo)", "C", ""}}, ;
        {|u, a| GEBESTTRF(a[1], a[2], a[3], a[4], a[5], a[6], GEBESTDET(a[7], a[8], a[9], a[4]), a[10])}, "BO", "", aEst}, ;
    {"Contabil", 0, 0, "Rateio entre centros de custo", {{"Codigo do rateio", "C", ""}}, {|u, a, it| GEBCTXRAT(a[1], it)}, "BO", "", aCtb, Nil, ;
        {{"Centro de custo", "C", ""}, {"Percentual", "N", 0}}}, ;
    {"Compras", 0, 0, "Solicitacao de compra", {}, {|u, a, it| GEBCPXSC("", it, u)}, "BO", "", aPed, Nil, ;
        {{"Produto", "C", ""}, {"Quantidade", "N", 0}, {"Necessidade (AAAAMMDD; vazio = hoje)", "C", ""}}}, ;
    {"Compras", 0, 0, "Pedido de compra com itens", {{"Fornecedor", "C", "", "GCP1_COD"}, {"Condicao de pagamento", "C", ""}, {"Armazem de entrega", "C", "01"}}, ;
        {|u, a, it| GEBCPXPED("", a[1], it, a[2], a[3], BOHOJE())}, "BO", "", aPed, Nil, ;
        {{"Produto", "C", ""}, {"Quantidade", "N", 0}, {"Preco", "N", 0}}}, ;
    {"Compras", 0, 0, "Documento de entrada", {{"Nota fiscal", "C", ""}, {"Pedido", "C", "", "GCP3_NUM"}, {"Frete", "N", 0}, {"Data (AAAAMMDD)", "C", cHoje}, ;
        {"Retencoes (codigos separados por virgula)", "C", ""}, {"Chave da NF-e do fornecedor (44 digitos)", "C", ""}}, ;
        {|u, a, it| GEBCPXENT(a[1], a[2], it, a[3], a[4], a[5], a[6])}, "BO", "", aPed, Nil, ;
        {{"Produto recebido (sem itens = todo o pendente)", "C", ""}, {"Quantidade", "N", 0}, {"Preco (0 = do pedido)", "N", 0}, ;
         {"Lote/series", "C", ""}, {"Validade (AAAAMMDD)", "C", ""}, {"Endereco", "C", ""}}}, ;
    {"Compras", 0, 0, "Devolucao de compra", {{"Nota fiscal de entrada", "C", ""}, {"Fornecedor", "C", "", "GCP1_COD"}, {"Data (AAAAMMDD)", "C", cHoje}, ;
        {"Chave da NF-e do fornecedor (vazio = a da entrada)", "C", ""}}, ;
        {|u, a, it| GEBCPXDEV(a[1], a[2], it, a[3], a[4])}, "BO", "", aPed, Nil, ;
        {{"Produto devolvido", "C", ""}, {"Quantidade", "N", 0}}}, ;
    {"Faturamento", 0, 0, "Pedido de venda", {{"Cliente", "C", "", "GFT1_COD"}, {"Condicao (vazio = do cliente)", "C", ""}, {"Desconto % no pedido", "N", 0}, ;
        {"Armazem", "C", "01"}, {"Centro de custo (vazio = nenhum)", "C", ""}, {"Regime (DIFAL extraoficial)", {"FISCAL", "COMPROVANTE"}, "FISCAL"}}, ;
        {|u, a, it| GEBFATPED("", a[1], it, a[2], a[3], a[4], BOHOJE(), a[5], a[6])}, "BO", "", aFat, Nil, ;
        {{"Produto", "C", ""}, {"Quantidade", "N", 0}, {"Preco (0 = tabela)", "N", 0}}}, ;
    {"Faturamento", 0, 0, "Faturar pedido (documento de saida)", {{"Pedido", "C", ""}, {"Data (AAAAMMDD)", "C", cHoje}}, ;
        {|u, a, it| GEBFATFAT(a[1], it, a[2], "")}, "BO", "", aFat, Nil, ;
        {{"Produto a faturar (sem itens = todo o saldo)", "C", ""}, {"Quantidade", "N", 0}}}, ;
    {"Faturamento", 0, 0, "Devolucao de venda", {{"Nota", "C", ""}, {"Data (AAAAMMDD)", "C", cHoje}, ;
        {"Chave da NF-e de devolucao do cliente (so' contribuinte; vazio = o GEBAN emite)", "C", ""}}, ;
        {|u, a, it| GEBFATDEV(a[1], it, a[2], a[3])}, "BO", "", aFat, Nil, ;
        {{"Produto devolvido", "C", ""}, {"Quantidade", "N", 0}}}, ;
    {"Financeiro", 0, 0, "Baixar titulo", {{"Tipo", {"PAGAR", "RECEBER"}, "RECEBER"}, {"Documento", "C", ""}, {"Valor", "N", 0}}, {|u, a| GEBRESTFINBAI(u, a)}, "200", "Titulo baixado."}, ;
    {"Derrama", 0, 0, "Gerar guia", {{"Competencia (AAAAMM)", "C", cComp}}, {|u, a| GEBRESTDERGER(u, a)}, "201", "Guia gerada."}, ;
    {"Derrama", 0, 0, "Baixar guia", {{"Guia", "C", "", "GD1_GUIA"}}, {|u, a| GEBRESTDERBAI(u, a)}, "200", "Guia baixada."}, ;
    {"Derrama", 0, 0, "Parcelar guia", {{"Guia", "C", "", "GD1_GUIA"}, {"Parcelas", "N", 2}}, {|u, a| GEBRESTDERPAR(u, a)}, "200", "Guia parcelada."}, ;
    {"Derrama", 0, 0, "Calcular juros", {{"Guia", "C", "", "GD1_GUIA"}, {"Dias de atraso", "N", 30}}, {|u, a| GEBRESTDERJUR(u, a)}, "200", "Juros calculados."}, ;
    {"Derrama", 0, 0, "Protestar guia", {{"Guia", "C", "", "GD1_GUIA"}}, {|u, a| GEBRESTDERPRO(u, a)}, "200", "Guia protestada."}, ;
    {"Estoque", 0, 0, "Vender", {{"Venda", "C", ""}, {"Produto", "C", "", "GV1_PROD"}, {"Quantidade", "N", 1}, {"Preco", "N", 0}}, {|u, a| GEBRESTESTVEN(u, a)}, "201", "Venda registrada."}, ;
    {"Estoque", 0, 0, "Vender fiado", {{"Cliente", "C", ""}, {"Valor", "N", 0}}, {|u, a| GEBRESTESTFIA(u, a)}, "201", "Fiado registrado."}, ;
    {"Estoque", 0, 0, "Juros do fiado", {{"Cliente", "C", ""}, {"Dias", "N", 30}}, {|u, a| GEBRESTESTFIJ(u, a)}, "200", "Juros calculados."}, ;
    {"Contabil", 0, 0, "Lancamento", {{"Conta a debito", "C", "", "GC1_CONTA"}, {"Conta a credito", "C", ""}, {"Valor", "N", 0}}, {|u, a| GEBRESTCTBDIR(u, a)}, "201", "Lancamento gravado."}, ;
    {"Compras", 0, 0, "Cotacao de fornecedor", {{"Fornecedor", "C", "", "GCP1_COD"}, {"Produto", "C", ""}, {"Preco", "N", 0}}, ;
        {|u, a| TUICotacao(a)}, "BO", "", aPed}, ;
    {"Compras", 0, 0, "Menor preco cotado", {{"Produto", "C", ""}}, {|u, a| TUIMenorPreco(a[1])}, "BO", "", aPed}, ;
    {"Compras", 0, 0, "Novo fornecedor", {{"Codigo", "C", ""}, {"Nome", "C", ""}}, {|u, a| GEBRESTCOMFOR(u, a)}, "201", "Fornecedor criado."}, ;
    {"Compras", 0, 0, "Abrir pedido", {{"Pedido", "C", ""}, {"Fornecedor", "C", "", "GCP1_COD"}}, {|u, a| GEBRESTCOMPED(u, a)}, "201", "Pedido aberto."}, ;
    {"Compras", 0, 0, "Adicionar item", {{"Pedido", "C", "", "GCP3_NUM"}, {"Produto", "C", ""}, {"Quantidade", "N", 1}, {"Preco", "N", 0}}, {|u, a| GEBRESTCOMIT(u, a)}, "201", "Item adicionado."}, ;
    {"Compras", 0, 0, "Dar entrada", {{"Nota fiscal", "C", ""}, {"Pedido", "C", "", "GCP3_NUM"}}, {|u, a| GEBRESTCOMENT(u, a)}, "201", "Entrada registrada."} ;
    }

// Inventario: o lote/endereco vale para a diferenca entre contado e saldo.
Static Function TUIInventario(a)
    Local aSld := GEBESTSLD(a[1], a[2]) as Array
Return GEBESTAJU(a[1], a[2], a[3], a[4], a[5], a[6], GEBESTDET(a[7], a[8], a[9], Abs(a[3] - aSld[1])))

/*/{Protheus.doc} TUIMunicipio
    Codigo IBGE do municipio a partir do codigo (7 digitos) ou do nome na UF.
    Nome ambiguo e' recusado com as opcoes. {lOk, codigo ou mensagem}.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIMunicipio(cUF, cTxt)
    Local aM   := {} as Array
    Local cOps := "" as Character
    Local nI   := 0 as Numeric

    cTxt := AllTrim(cTxt)
    If Len(cTxt) == 7 .And. StrZero(Val(cTxt), 7) == cTxt
        Return {.T., cTxt}
    EndIf
    If Empty(cTxt) .Or. Empty(cUF)
        Return {.F., "informe a UF e o municipio"}
    EndIf
    aM := GEBDFEMUNBUSCA(cTxt, Upper(cUF))
    If Len(aM) == 1
        Return {.T., aM[1][1]}
    EndIf
    If Len(aM) == 0
        Return {.F., "nenhum municipio de " + Upper(cUF) + " com '" + cTxt + "'"}
    EndIf
    For nI := 1 To Min(Len(aM), 5)
        If nI > 1
            cOps += "; "
        EndIf
        cOps += aM[nI][2] + " (" + aM[nI][1] + ")"
    Next nI
Return {.F., "municipio ambiguo, use o codigo IBGE: " + cOps}

// Cotacao: GEBCMCOT devolve .T./.F. (fornecedor/produto inexistente ou preco invalido).
Static Function TUICotacao(a)
    If GEBCMCOT(a[1], a[2], a[3])
        Return {.T., "cotacao de " + a[2] + " gravada: " + TUIMoeda(a[3])}
    EndIf
Return {.F., "fornecedor ou produto inexistente, ou preco invalido"}

Static Function TUIMenorPreco(cProd)
    Local nMel := GEBCMMEL(cProd) as Numeric

    If nMel <= 0
        Return {.F., "sem cotacao para " + cProd}
    EndIf
Return {.T., "menor preco cotado de " + cProd + ": " + TUIMoeda(nMel)}

// Credito fiscal: GEBFCRE devolve o registro ("" = recusado).
Static Function TUIFisCredito(a)
    Local cReg := GEBFCRE(a[1], a[2], a[3], a[4]) as Character

    If Empty(cReg)
        Return {.F., "credito recusado"}
    EndIf
Return {.T., "credito " + cReg}

// Resposta REST {cStatus, cJson} como {lOk, cMsg} (2xx = ok).
Static Function TUIRestBO(aRes)
    If Left(cValToChar(aRes[1]), 1) == "2"
        Return {.T., "gravado"}
    EndIf
Return {.F., GEBTUIMOTIVO(aRes)}

// Apuracao do Simples com o resumo (anexo, faixa, RBT12, aliquota efetiva, DAS).
Static Function TUISNApura(cComp)
    Local aR   := GEBSNAPU(cComp) as Array
    Local cMsg := "" as Character

    If !aR[1]
        Return aR
    EndIf
    cMsg := "Anexo " + aR[3][1] + ", faixa " + cValToChar(aR[3][3]) + " | RBT12 " + TUIMoeda(aR[3][2]) + ;
        " | aliquota efetiva " + AllTrim(Str(aR[3][4], 20, 4)) + "% | DAS " + TUIMoeda(aR[3][5]) + ;
        " vence " + Right(aR[3][6], 2) + "/" + SubStr(aR[3][6], 5, 2) + "/" + Left(aR[3][6], 4)
    If !Empty(aR[3][7])
        cMsg += " | ATENCAO: " + aR[3][7]
    EndIf
Return {.T., cMsg}

/*/{Protheus.doc} TUIFormDfe
    Formularios de Fiscal > Documentos eletronicos (NF-e, NFC-e, NFS-e, EFD).
    Os padroes vem da configuracao atual (lida ao entrar). Campo de municipio
    aceita nome ou codigo IBGE (TUIMunicipio).
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIFormDfe(cEmp, cFil)
    Local oE    := GEBDFEEMITLE()
    Local aDfe  := {"FISCAL", "DFE"} as Array
    Local aSN   := {{"Nao", "N"}, {"Sim", "S"}} as Array
    Local cHoje := BOHOJE() as Character
    Local cUrl  := BOPARM("GEBAN_URL", "https://SEU-DOMINIO") as Character
    Local aEnd  := {{"Logradouro", "C", ""}, {"Numero", "C", ""}, {"Complemento", "C", ""}, {"Bairro", "C", ""}, {"UF", "C", ""}, ;
                    {"Municipio (nome ou codigo IBGE)", "C", ""}, {"CEP", "C", ""}, {"Telefone", "C", ""}, {"E-mail", "C", ""}} as Array
    Local aPart := {} as Array

    aPart := {{"Tipo", {{"Cliente", "C"}, {"Fornecedor", "F"}}, "C"}, {"Codigo do cliente/fornecedor", "C", ""}, {"CPF ou CNPJ", "C", ""}, ;
        {"Contribuinte", {{"1 contribuinte (com IE)", "1"}, {"2 isento", "2"}, {"9 nao contribuinte", "9"}}, "1"}, ;
        {"Inscricao estadual (vazio se nao contribuinte)", "C", ""}, {"Nome/razao social (vazio = o do cadastro)", "C", ""}}
    aEval(aEnd, {|x| aAdd(aPart, x)})
Return { ;
    {"Fiscal", 0, 0, "DF-e: o que falta para emitir (roteiro)", {{"Testar a comunicacao com a SEFAZ agora", aSN, "N"}}, ;
        {|u, a| GEBDFEROTEIRO(a[1] == "S"), {.T., ""}}, "REL", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: emitente (CNPJ, IE, regime, endereco)", { ;
        {"CNPJ", "C", TBOJ(oE, "CNPJ")}, {"Inscricao estadual", "C", TBOJ(oE, "IE")}, {"Razao social", "C", TBOJ(oE, "XNOME")}, ;
        {"Nome fantasia", "C", TBOJ(oE, "XFANT")}, {"Regime", {{"1 Simples", "1"}, {"4 MEI", "4"}, {"2 Simples com excesso", "2"}, {"3 normal", "3"}}, TBOJ(oE, "CRT")}, ;
        {"Inscricao municipal (vazio = nao tem)", "C", TBOJ(oE, "IM")}, {"CNAE (vazio = nao informa)", "C", TBOJ(oE, "CNAE")}, ;
        {"Logradouro", "C", TBOJ(oE, "XLGR")}, {"Numero", "C", TBOJ(oE, "NRO")}, {"Complemento", "C", TBOJ(oE, "XCPL")}, {"Bairro", "C", TBOJ(oE, "XBAIRRO")}, ;
        {"UF", "C", TBOJ(oE, "UF")}, {"Municipio (nome ou codigo IBGE)", "C", TBOJ(oE, "CMUN")}, {"CEP", "C", TBOJ(oE, "CEP")}, ;
        {"Telefone", "C", TBOJ(oE, "FONE")}, {"E-mail", "C", TBOJ(oE, "EMAIL")}}, ;
        {|u, a| TUIDfeJson({|o| GEBDFEEMIT(o)}, {"CNPJ", "IE", "RAZAO", "FANTASIA", "CRT", "IM", "CNAE", "LOGRADOURO", "NUMERO", "COMPLEMENTO", ;
            "BAIRRO", "UF", "MUNICIPIO", "CEP", "FONE", "EMAIL"}, a)}, "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: certificado digital A1", {}, {|u, a| TUICertificado(cUrl)}, "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: configuracao (ambiente, NFC-e, serie, CSC, padroes)", { ;
        {"Ambiente", {{"2 homologacao", "2"}, {"1 producao", "1"}}, BOPARM("DFE_AMBIENTE", "2")}, ;
        {"NFC-e na frente de loja", aSN, BOPARM("DFE_NFCE", "N")}, {"Serie da NFC-e", "C", BOPARM("DFE_SERIE_65", "1")}, ;
        {"NF-e no faturamento e nas devolucoes", aSN, BOPARM("DFE_NFE", "N")}, {"Serie da NF-e", "C", BOPARM("DFE_SERIE_55", "1")}, ;
        {"Forma de pagamento da NF-e de venda (15 boleto, 99 outros...)", "C", BOPARM("DFE_NFE_TPAG", "15")}, ;
        {"NFS-e (servicos, padrao nacional)", aSN, BOPARM("DFE_NFSE", "N")}, {"Serie da DPS", "C", BOPARM("DFE_SERIE_NFSE", "1")}, ;
        {"Proximo numero da NFC-e (vazio = segue a numeracao)", "C", ""}, {"CFOP padrao", "C", BOPARM("DFE_CFOP", "5102")}, ;
        {"CSOSN padrao (Simples)", "C", BOPARM("DFE_CSOSN", "102")}, {"Unidade padrao", "C", BOPARM("DFE_UNIDADE", "UN")}, ;
        {"ID do CSC (so' QR Code versao 2)", "C", BOPARM("DFE_CSC_ID", "")}, {"Codigo CSC (vazio = mantem o atual)", "P", ""}, ;
        {"Responsavel tecnico: CNPJ (vazio = nao informa)", "C", BOPARM("DFE_RT_CNPJ", "")}, {"Responsavel tecnico: contato", "C", BOPARM("DFE_RT_CONTATO", "")}, ;
        {"Responsavel tecnico: e-mail", "C", BOPARM("DFE_RT_EMAIL", "")}, {"Responsavel tecnico: telefone", "C", BOPARM("DFE_RT_FONE", "")}}, ;
        {|u, a| TUIDfeConfig(a)}, "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: perfil fiscal de produto", {{"Produto", "C", "", "GF1_COD"}, {"Unidade (vazio = padrao)", "C", ""}, ;
        {"GTIN/EAN (vazio = do codigo de barras da loja)", "C", ""}, {"CFOP (vazio = padrao)", "C", ""}, {"CSOSN (Simples; vazio = padrao)", "C", ""}, ;
        {"CST do ICMS (regime normal; vazio = padrao)", "C", ""}, {"Aliquota do ICMS % (regime normal)", "N", 0}, {"CEST (vazio = nao tem)", "C", ""}, ;
        {"Origem 0 a 8 (vazio = padrao)", "C", ""}, {"CST do PIS (vazio = padrao)", "C", ""}, {"CST da COFINS (vazio = padrao)", "C", ""}}, ;
        {|u, a| TUIDfeJson({|o| GEBDFEPRODFIS(o)}, {"PRODUTO", "UNIDADE", "GTIN", "CFOP", "CSOSN", "CST", "ALIQ_ICMS", "CEST", "ORIGEM", "PIS_CST", "COFINS_CST"}, a)}, ;
        "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: status do servico da SEFAZ", {}, {|u, a| GEBDFESTATSVC("65")}, "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: transmitir NFC-e em contingencia", {}, {|u, a| GEBDFETRANSMITE()}, "BO", "", {"LOJA", "CAIXA"}}, ;
    {"Fiscal", 0, 0, "DF-e: consultar documento na SEFAZ", {{"Chave de acesso", "C", ""}}, {|u, a| GEBDFECONSULTAR(a[1], .T.)}, "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: cancelar documento", {{"Chave de acesso", "C", ""}, {"Justificativa (minimo 15 letras)", "C", ""}}, ;
        {|u, a| GEBDFECANCELA(a[1], a[2])}, "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: inutilizar faixa de numeros", {{"Modelo", {{"65 NFC-e", "65"}, {"55 NF-e", "55"}}, "65"}, ;
        {"Serie", "N", Val(BOPARM("DFE_SERIE_65", "1"))}, {"Numero inicial", "N", 0}, {"Numero final", "N", 0}, {"Justificativa (minimo 15 letras)", "C", ""}}, ;
        {|u, a| GEBDFEINUTILIZA(a[1], a[2], a[3], a[4], a[5])}, "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: inutilizar numeros das notas rejeitadas", {{"Justificativa (minimo 15 letras)", "C", "Numero rejeitado pela SEFAZ e nao utilizado"}}, ;
        {|u, a| GEBDFEINUTPEND(a[1])}, "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: cadastro fiscal de cliente ou fornecedor (NF-e)", aPart, ;
        {|u, a| TUIDfeJson({|o| GEBDFEPART(o)}, {"TIPO", "CODIGO", "DOC", "CONTRIBUINTE", "IE", "NOME", "LOGRADOURO", "NUMERO", "COMPLEMENTO", ;
            "BAIRRO", "UF", "MUNICIPIO", "CEP", "FONE", "EMAIL"}, a)}, "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: carta de correcao (NF-e)", {{"Chave de acesso da NF-e", "C", ""}, ;
        {"Correcao (15 a 1000 letras; nao corrige valores, impostos, quantidades, datas nem as partes)", "C", ""}}, ;
        {|u, a| GEBDFECCE(a[1], a[2])}, "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: resolver NF-e/NFS-e sem resposta da SEFAZ", {}, ;
        {|u, a| {.T., "NF-e: " + BOSTR(GEBDFERESOLVE()[2]) + " | NFS-e: " + BOSTR(GEBDFENFSERESOLVE()[2])}}, "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: DANFE/DANFSe de um documento (link)", {{"Chave de acesso", "C", ""}}, ;
        {|u, a| {.T., "Abra no navegador: " + cUrl + "/api/dfe/danfe?empresa=" + cEmp + "&chave=" + GEBDFEDIG(a[1]) + "&token=" + GEBSECTOKEN(u, cEmp, cFil, "danfe")}}, ;
        "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: servico fiscal (NFS-e)", {{"Codigo do servico", "C", ""}, {"Descricao", "C", ""}, ;
        {"Codigo de tributacao nacional (6 digitos, ex.: 010101)", "C", ""}, {"Codigo de tributacao municipal (3 digitos; vazio = nao tem)", "C", ""}, ;
        {"NBS (9 digitos; vazio = nao informa)", "C", ""}, {"Aliquota do ISS % (so' quando o tomador retem)", "N", 0}}, ;
        {|u, a| TUIDfeJson({|o| GEBDFESERV(o)}, {"CODIGO", "DESCRICAO", "TRIB_NACIONAL", "TRIB_MUNICIPAL", "NBS", "ALIQ_ISS"}, a)}, "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: faturar servico (NFS-e)", {{"Cliente", "C", "", "GFT1_COD"}, {"Servico", "C", ""}, {"Valor", "N", 0}, ;
        {"Descricao complementar", "C", ""}, {"Condicao de pagamento (vazio = a vista)", "C", ""}, {"Data (AAAAMMDD)", "C", cHoje}, ;
        {"ISS retido pelo tomador", aSN, "N"}, {"Desconto", "N", 0}}, ;
        {|u, a| GEBFATSERV(a[1], a[2], a[3], a[4], a[5], a[6], a[7] == "S", a[8])}, "BO", "", {"FATURAMENTO", "FATUR"}}, ;
    {"Fiscal", 0, 0, "DF-e: cancelar NFS-e", {{"Chave da NFS-e (50 digitos)", "C", ""}, ;
        {"Motivo", {{"1 erro na emissao", "1"}, {"2 servico nao prestado", "2"}, {"9 outros", "9"}}, "1"}, {"Justificativa (minimo 15 letras)", "C", ""}}, ;
        {|u, a| GEBDFENFSECANC(a[1], a[2], a[3])}, "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: SPED Fiscal (EFD ICMS/IPI) da competencia", {{"Competencia (AAAAMM)", "C", Left(BOMESADD(Left(cHoje, 6), -1), 6)}, ;
        {"Finalidade", {{"0 original", "0"}, {"1 substituto", "1"}}, "0"}}, ;
        {|u, a| TUIEfd(GEBDFEEFD(a[1], a[2]), cUrl)}, "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "DF-e: configuracao da EFD (contabilista, receitas, vencimento)", { ;
        {"Perfil de apresentacao (A, B ou C, conforme a UF)", {{"A", "A"}, {"B", "B"}, {"C", "C"}}, BOPARM("DFE_EFD_PERFIL", "A")}, ;
        {"Atividade", {{"0 industrial ou equiparado", "0"}, {"1 outros", "1"}}, BOPARM("DFE_EFD_ATIV", "1")}, ;
        {"Codigo de receita do ICMS proprio (UF)", "C", BOPARM("DFE_EFD_COD_REC", "")}, {"Codigo de receita do ICMS ST", "C", BOPARM("DFE_EFD_COD_REC_ST", "")}, ;
        {"Codigo de receita do DIFAL", "C", BOPARM("DFE_EFD_COD_REC_DIFAL", "")}, {"Codigo de receita do FCP", "C", BOPARM("DFE_EFD_COD_REC_FCP", "")}, ;
        {"Dia do vencimento do ICMS no mes seguinte", "C", BOPARM("DFE_EFD_DIA_VENC", "20")}, ;
        {"Saldo credor de ICMS antes do 1o arquivo (0 se nao ha)", "C", BOPARM("DFE_EFD_SLD_CRED_INI", "0")}, ;
        {"Contabilista: nome", "C", BOPARM("DFE_EFD_CONT_NOME", "")}, {"Contabilista: CPF", "C", BOPARM("DFE_EFD_CONT_CPF", "")}, ;
        {"Contabilista: CRC", "C", BOPARM("DFE_EFD_CONT_CRC", "")}, {"Escritorio de contabilidade: CNPJ (vazio = nao tem)", "C", BOPARM("DFE_EFD_CONT_CNPJ", "")}, ;
        {"Contabilista: e-mail", "C", BOPARM("DFE_EFD_CONT_EMAIL", "")}, {"Contabilista: telefone", "C", BOPARM("DFE_EFD_CONT_FONE", "")}, ;
        {"Contabilista: CEP", "C", BOPARM("DFE_EFD_CONT_CEP", "")}, {"Contabilista: logradouro", "C", BOPARM("DFE_EFD_CONT_END", "")}, ;
        {"Contabilista: numero", "C", BOPARM("DFE_EFD_CONT_NUM", "")}, {"Contabilista: bairro", "C", BOPARM("DFE_EFD_CONT_BAIRRO", "")}, ;
        {"Contabilista: UF", "C", ""}, {"Contabilista: municipio (nome ou codigo IBGE)", "C", BOPARM("DFE_EFD_CONT_MUN", "")}}, ;
        {|u, a| TUIDfeJson({|o| GEBDFECONFIG(o)}, {"EFD_PERFIL", "EFD_ATIVIDADE", "EFD_COD_REC", "EFD_COD_REC_ST", "EFD_COD_REC_DIFAL", "EFD_COD_REC_FCP", ;
            "EFD_DIA_VENC", "EFD_SALDO_CREDOR_INICIAL", "CONT_NOME", "CONT_CPF", "CONT_CRC", "CONT_CNPJ", "CONT_EMAIL", "CONT_FONE", "CONT_CEP", ;
            "CONT_END", "CONT_NUM", "CONT_BAIRRO", "CONT_UF", "CONT_MUNICIPIO"}, a)}, "BO", "", aDfe}, ;
    {"Fiscal", 0, 0, "Relatorio: documentos eletronicos", {{"Inicio (AAAAMMDD)", "C", Left(cHoje, 6) + "01"}, {"Fim (AAAAMMDD)", "C", cHoje}, ;
        {"Situacao (vazio = todas)", "C", ""}}, {|u, a| TUIDfeDocs(a)}, "REL", "", aDfe} }

/*/{Protheus.doc} TUIDfeJson
    Monta o JsonObject {chave: valor} na ordem dos campos e chama o bloco.
    MUNICIPIO (e CONT_MUNICIPIO) com nome vira codigo IBGE pela UF do
    mesmo formulario; CONT_UF so' serve para isso e nao e' enviado.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIDfeJson(bFaz, aChaves, a)
    Local o  := JsonObject():New()
    Local aM := {} as Array
    Local nI := 0 as Numeric
    Local nU := 0 as Numeric

    For nI := 1 To Len(aChaves)
        If ValType(a[nI]) == "C"
            o[aChaves[nI]] := AllTrim(a[nI])
        Else
            o[aChaves[nI]] := a[nI]
        EndIf
    Next nI
    For nI := 1 To Len(aChaves)
        If aChaves[nI] == "MUNICIPIO" .Or. aChaves[nI] == "CONT_MUNICIPIO"
            If aChaves[nI] == "MUNICIPIO"
                nU := aScan(aChaves, "UF")
            Else
                nU := aScan(aChaves, "CONT_UF")
            EndIf
            If !Empty(o[aChaves[nI]])
                aM := TUIMunicipio(o[aChaves[nU]], o[aChaves[nI]])
                If !aM[1]
                    Return aM
                EndIf
                o[aChaves[nI]] := aM[2]
            EndIf
        EndIf
    Next nI
    If aScan(aChaves, "UF") > 0
        o["UF"] := Upper(o["UF"])
    EndIf
    o:DelName("CONT_UF")
Return Eval(bFaz, o)

// Configuracao do DF-e: o CSC em branco mantem o gravado.
Static Function TUIDfeConfig(a)
    If Empty(a[14])
        a[14] := BOPARM("DFE_CSC", "")
    EndIf
Return TUIDfeJson({|o| GEBDFECONFIG(o)}, {"AMBIENTE", "NFCE", "SERIE_NFCE", "NFE", "SERIE_NFE", "NFE_TPAG", "NFSE", "SERIE_NFSE", "PROXIMO_NFCE", ;
    "CFOP", "CSOSN", "UNIDADE", "CSC_ID", "CSC", "RT_CNPJ", "RT_CONTATO", "RT_EMAIL", "RT_FONE"}, a)

Static Function TUICertificado(cUrl)
    Local aR   := GEBDFECERTLE() as Array
    Local cMsg := "Nenhum certificado instalado." as Character

    If Len(aR) > 0
        cMsg := "Instalado: " + aR[1] + " (CNPJ " + aR[2] + "), valido ate " + Right(aR[3], 2) + "/" + SubStr(aR[3], 5, 2) + "/" + Left(aR[3], 4) + "."
    EndIf
Return {.T., cMsg + " Para enviar o .pfx abra " + cUrl + "/api/dfe/configurar (mesma empresa, usuario e senha)."}

Static Function TUIEfd(aR, cUrl)
    If aR[1]
        Return {.T., aR[2] + ". Baixe o arquivo em " + cUrl + "/api/dfe/configurar (secao SPED Fiscal) e valide no PVA."}
    EndIf
Return aR

Static Function TUIDfeDocs(a)
    Local aR := GEBDFEDOCS(a[1], a[2], a[3]) as Array

    If aR[1]
        BOMIG()
    EndIf
Return aR

/*/{Protheus.doc} TUIFormNuc
    Formularios do Nucleo (administracao): empresas, unidades, filiais,
    usuarios, permissoes, ciclo do usuario e agendamentos. As regras de quem
    pode (super/ADMIN) ficam nas funcoes de negocio chamadas.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIFormNuc(cEmp)
    Local aAreas := GEBTUIAREAS() as Array
    Local aRot   := GEBSCHROTINAS() as Array
    Local aOpA   := {} as Array
    Local aOpR   := {} as Array
    Local cRot1  := "" as Character
    Local nI     := 0 as Numeric

    If Len(aRot) > 0
        cRot1 := aRot[1][1]
    EndIf
    For nI := 1 To Len(aAreas)
        aAdd(aOpA, {aAreas[nI][3], cValToChar(nI)})
    Next nI
    For nI := 1 To Len(aRot)
        aAdd(aOpR, {aRot[nI][1] + " - " + aRot[nI][2], aRot[nI][1]})
    Next nI
Return { ;
    {"Nucleo", 0, 0, "Nova empresa", {{"Codigo", "C", ""}, {"Nome", "C", ""}}, {|u, a| TUIRestBO(GEBRESTEMPLSC(u, {a[1], a[2]}))}, "BO", "", Nil}, ;
    {"Nucleo", 0, 0, "Nova unidade", {{"Codigo UU (2 digitos)", "C", ""}, {"Nome", "C", ""}}, {|u, a| TUIRestBO(GEBRESTUNILSC(u, {a[1], a[2]}))}, "BO", "", Nil}, ;
    {"Nucleo", 0, 0, "Nova filial", {{"Codigo EEUUFF", "C", ""}, {"Nome", "C", ""}}, {|u, a| TUIRestBO(GEBRESTFILSC(u, {a[1], a[2]}))}, "BO", "", Nil}, ;
    {"Nucleo", 0, 0, "Novo usuario", {{"Codigo (letras, numeros e _)", "C", ""}, {"Nome", "C", ""}, {"Perfil", "C", "USUARIO"}, ;
        {"Senha (min 8, maiuscula, minuscula, numero e simbolo)", "P", ""}, {"Confirme a senha", "P", ""}, {"Empresa", "C", cEmp}, {"Filial (vazio = matriz)", "C", ""}}, ;
        {|u, a| TUINucUsuario(u, a)}, "BO", "", Nil}, ;
    {"Nucleo", 0, 0, "Vincular usuario a empresa", {{"Usuario", "C", "", "GE2_COD"}, {"Empresa", "C", cEmp}, {"Filial (vazio = matriz)", "C", ""}}, ;
        {|u, a| TUIRestBO(GEBRESTVINCSC(u, {a[1], a[2], a[3]}))}, "BO", "", Nil}, ;
    {"Nucleo", 0, 0, "Alterar usuario (senha, nome, perfil)", {{"Usuario (vazio = voce)", "C", "", "GE2_COD"}, {"Nova senha (vazio = mantem)", "P", ""}, ;
        {"Confirme a senha", "P", ""}, {"Nome (vazio = mantem)", "C", ""}, {"Perfil (vazio = mantem)", "C", ""}}, ;
        {|u, a| TUINucAltera(u, a)}, "BO", "", Nil}, ;
    {"Nucleo", 0, 0, "Permissao de perfil", {{"Perfil (ex.: USUARIO, OPERADOR)", "C", ""}, {"Area", aOpA, "1"}, ;
        {"Acao", {{"Conceder", "S"}, {"Revogar", "N"}}, "S"}, {"Escopo", {{"Esta empresa", "E"}, {"Todas as empresas (so' super)", "*"}}, "E"}}, ;
        {|u, a| TUINucPerm(u, a, aAreas, cEmp)}, "BO", "", Nil}, ;
    {"Nucleo", 0, 0, "Ciclo do usuario", {{"Usuario", "C", "", "GE2_COD"}, {"Acao", {{"Bloquear", "1"}, {"Desbloquear", "2"}, {"Definir validade", "3"}, ;
        {"Eliminar acessos", "4"}, {"Excluir", "5"}, {"Forcar troca de senha", "6"}, {"Conta de servico: ignorar troca periodica", "7"}, ;
        {"Conta de servico: voltar a trocar", "8"}}, "1"}, {"Validade (AAAAMMDD; vazio = sem validade)", "C", ""}}, ;
        {|u, a| TUINucCiclo(u, a)}, "BO", "", Nil}, ;
    {"Nucleo", 0, 0, "Agendar rotina", {{"Rotina", aOpR, cRot1}, {"Horario HHMM", "C", "0230"}, ;
        {"Dia (D = diario, M01..M28 = dia do mes)", "C", "D"}}, {|u, a| GEBSCHAGENDA(u, a[1], AllTrim(a[2]), Upper(AllTrim(a[3])), "S")}, "BO", "", Nil}, ;
    {"Nucleo", 0, 0, "Desativar agendamento", {{"Rotina", aOpR, cRot1}}, {|u, a| GEBSCHDESATIVA(u, a[1])}, "BO", "", Nil}, ;
    {"Nucleo", 0, 0, "Relatorio: permissoes do perfil", {{"Perfil", "C", ""}, {"Escopo", {{"Esta empresa", "E"}, {"Todas as empresas", "*"}}, "E"}}, ;
        {|u, a| TUINucPermRel(a, cEmp)}, "REL", "", Nil}, ;
    {"Nucleo", 0, 0, "Relatorio: agendamentos", {}, {|u, a| TUINucAgendaRel()}, "REL", "", Nil} }

Static Function TUINucUsuario(u, a)
    If !(a[4] == a[5])
        Return {.F., "senhas diferentes"}
    EndIf
Return TUIRestBO(GEBRESTURLSC(u, {a[1], a[2], a[3], a[4], a[6], a[7]}))

Static Function TUINucAltera(u, a)
    Local aR := {} as Array

    If !(a[2] == a[3])
        Return {.F., "senhas diferentes"}
    EndIf
    aR := GEBTUITROCASENHA(u, a[1], a[2], a[4], a[5])
    If aR[1]
        Return {.T., "usuario atualizado"}
    EndIf
Return {.F., TUIMotivoUsu(BOSTR(aR[2]))}

Static Function TUIMotivoUsu(cCod)
    If cCod == "nada_a_alterar"
        Return "nada a alterar"
    EndIf
    If cCod == "somente_super"
        Return "somente o super altera a conta super"
    EndIf
    If cCod == "usuario_inexistente"
        Return "usuario inexistente"
    EndIf
Return cCod

Static Function TUINucEsc(cEsc, cEmp)
    If cEsc == "*"
        Return "*"
    EndIf
Return Lower(AllTrim(cEmp))

Static Function TUINucPerm(u, a, aAreas, cEmp)
    Local nA := Val(a[2]) as Numeric
    Local aR := {} as Array

    If Empty(a[1])
        Return {.F., "informe o perfil"}
    EndIf
    aR := GEBTUIPERMSETEMP(u, TUINucEsc(a[4], cEmp), a[1], aAreas[nA][1], aAreas[nA][2], a[3] == "S")
    If !aR[1]
        Return aR
    EndIf
    If a[3] == "S"
        Return {.T., aAreas[nA][3] + " concedido a " + Upper(a[1])}
    EndIf
Return {.T., aAreas[nA][3] + " revogado de " + Upper(a[1])}

Static Function TUINucCiclo(u, a)
    Local cAlvo := AllTrim(a[1]) as Character
    Local aR    := {} as Array

    If Empty(cAlvo)
        Return {.F., "informe o usuario"}
    EndIf
    Do Case
    Case a[2] == "1"
        aR := GEBSECBLOQUEIA(u, cAlvo, .T.)
    Case a[2] == "2"
        aR := GEBSECBLOQUEIA(u, cAlvo, .F.)
    Case a[2] == "3"
        aR := GEBSECVALIDADE(u, cAlvo, AllTrim(a[3]))
    Case a[2] == "4"
        aR := GEBSECELIMINAACESSOS(u, cAlvo)
    Case a[2] == "5"
        aR := GEBSECEXCLUI(u, cAlvo)
    Case a[2] == "6"
        aR := GEBSECFORCATROCA(u, cAlvo, .T.)
    OtherWise
        aR := GEBSECIGNORAEXP(u, cAlvo, a[2] == "7")
    EndCase
    If aR[1]
        Return {.T., "feito: " + cAlvo}
    EndIf
Return {.F., BOSTR(aR[2])}

Static Function TUINucPermRel(a, cEmp)
    Local aL   := {} as Array
    Local aRel := {{"Menu", "Item", "Situacao", "Origem"}} as Array
    Local nI   := 0 as Numeric

    If Empty(a[1])
        Return {.F., "informe o perfil"}
    EndIf
    aL := GEBSECRBACLISTEMP(Upper(AllTrim(a[1])), TUINucEsc(a[2], cEmp))
    For nI := 1 To Len(aL)
        If aL[nI][3]
            aAdd(aRel, {BOSTR(aL[nI][1]), BOSTR(aL[nI][2]), "permitido", BOSTR(aL[nI][4])})
        Else
            aAdd(aRel, {BOSTR(aL[nI][1]), BOSTR(aL[nI][2]), "negado", BOSTR(aL[nI][4])})
        EndIf
    Next nI
    BOREL(aRel)
Return {.T., ""}

Static Function TUINucAgendaRel()
    Local aJ   := TCSqlQuery("SELECT SCH_ROTINA, SCH_HORA, SCH_DIA, SCH_ATIVO, SCH_ULTEXEC, SCH_STATUS FROM SCH_JOB WHERE D_E_L_E_T_ = ' ' ORDER BY SCH_ROTINA") as Array
    Local aRel := {{"Rotina", "Horario", "Dia", "Ativo", "Ultima execucao", "Situacao"}} as Array
    Local nI   := 0 as Numeric

    For nI := 1 To Len(aJ)
        aAdd(aRel, {BOSTR(aJ[nI]:SCH_ROTINA), BOSTR(aJ[nI]:SCH_HORA), BOSTR(aJ[nI]:SCH_DIA), BOSTR(aJ[nI]:SCH_ATIVO), BOSTR(aJ[nI]:SCH_ULTEXEC), BOSTR(aJ[nI]:SCH_STATUS)})
    Next nI
    BOREL(aRel)
Return {.T., ""}

// Grupo (aba) do formulario pelo prefixo do titulo.
Static Function TUIGrupo(cTit)
    If Left(cTit, 10) == "Relatorio:"
        Return "Relatorios"
    EndIf
    If Left(cTit, 6) == "Banco:"
        Return "Banco"
    EndIf
    If Left(cTit, 8) == "Simples:"
        Return "Simples Nacional"
    EndIf
    If Left(cTit, 5) == "DF-e:"
        Return "Documentos eletronicos"
    EndIf
    If Left(cTit, 5) == "NF-e:"
        Return "NF-e de fornecedores"
    EndIf
    If Left(cTit, 7) == "Sarney:"
        Return "Sarney"
    EndIf
    If Left(cTit, 7) == "Crypto:"
        Return "Crypto"
    EndIf
Return "Operacoes"

// Saldo e custo medio (antes um MsgInfo).
Static Function TUISaldo(a)
    Local aR := GEBESTSLD(a[1], a[2]) as Array
Return {.T., "Produto " + a[1] + ": quantidade " + BONUM(aR[1], 4) + ", custo medio " + BONUM(aR[2], 4) + ", valor " + BONUM(aR[3], 2)}

// Manifestacao: a justificativa so' vale para NAO_REALIZADA.
Static Function TUIManif(a)
    If a[2] == "NAO_REALIZADA"
        Return GEBDFEMANIF(a[1], a[2], a[3])
    EndIf
Return GEBDFEMANIF(a[1], a[2], "")

// Liberacao forcada exige a permissao FATURAMENTO/LIBERA.
Static Function TUILibera(u, a)
    If a[2] == "S"
        If !GEBSECRBAC(u, "FATURAMENTO", "LIBERA")
            Return {.F., "sem permissao FATURAMENTO/LIBERA para forcar"}
        EndIf
    EndIf
Return GEBFATLIB(a[1], a[2] == "S")

// Boleto: devolve a linha digitavel na mensagem.
Static Function TUIBoleto(a)
    Local aR := GEBBCOBOL(a[1], a[2]) as Array

    If !aR[1]
        Return aR
    EndIf
Return {.T., "Linha digitavel: " + aR[3][1] + " | nosso numero " + aR[3][3] + " | vencimento " + aR[3][4]}

// Arquivo do servidor (CNAB/OFX) lido e entregue ao bloco.
Static Function TUIArquivo(cArq, bProc)
    Local cTxt := MemoRead(cArq) as Character

    If BOSTR(cTxt) == ""
        Return {.F., "arquivo vazio ou nao encontrado: " + cArq}
    EndIf
Return Eval(bProc, cTxt)

// Calcular da baixa: saldo, juros e multa do titulo na data (preenche os campos 4 a 6).
Static Function TUICalcBaixa(aVal)
    Local aC := GEBFXCALC(aVal[1], aVal[2], aVal[3]) as Array

    If !aC[1]
        Return {.F., aC[2], {}}
    EndIf
Return {.T., "", {{4, aC[3][1]}, {5, aC[3][3]}, {6, aC[3][4]}}}

/*/{Protheus.doc} TUIForm
    Desenha um formulario (PoWidget com os campos e o botao) e liga as
    colunas da tabela aos campos.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIForm(oApp, oPg, aF, cUsu, aLinks, bDepois)
    Local oW     := PoWidget():New(oPg, aF[4])
    Local aCps   := {} as Array
    Local aIt    := Nil
    Local oB     := Nil
    Local nI     := 0 as Numeric
    Local lItens := .F. as Logical

    If Len(aF) >= 11
        lItens := (aF[11] != Nil)
    EndIf
    If lItens
        oW:SetCols(12)
    Else
        oW:SetCols(4)
    EndIf
    For nI := 1 To Len(aF[5])
        aAdd(aCps, TUICampo(oW, aF[5][nI], aLinks, lItens))
    Next nI
    If lItens
        aIt := TUIFormItens(oApp, oW, aF[11])
    EndIf
    oB := PoButton():New(oW, "Confirmar", {|| TUIExecuta(oApp, aF, aCps, cUsu, bDepois, aIt)})
    oB:Set("kind", "primary")
    If Len(aF) >= 10
        If aF[10] != Nil
            oB := PoButton():New(oW, aF[10][1], {|| TUICalcula(oApp, aF[10][2], aCps)})
            oB:Set("kind", "secondary")
        EndIf
    EndIf
Return

/*/{Protheus.doc} TUICampo
    Um campo do formulario: {rotulo, "C" | "N" | "P" (senha) | {opcoes}, padrao,
    coluna ligada}. Devolve {objeto, tipo}.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUICampo(oPai, aC, aLinks, lLargo)
    Local oC := Nil

    If ValType(aC[2]) == "A"
        oC := PoSelect():New(oPai, aC[1], aC[2], aC[3])
    ElseIf aC[2] == "N"
        oC := PoNumber():New(oPai, aC[1], aC[3])
    ElseIf aC[2] == "P"
        oC := PoPassword():New(oPai, aC[1])
    Else
        oC := PoInput():New(oPai, aC[1])
        If !Empty(aC[3])
            oC:SetValue(aC[3])
        EndIf
    EndIf
    If lLargo
        oC:SetCols(3)
    EndIf
    If Len(aC) >= 4
        aAdd(aLinks, {oC, aC[4]})
    EndIf
Return {oC, aC[2]}

/*/{Protheus.doc} TUIFormItens
    Grade de itens do formulario (cabecalho + itens): campos do item, botao
    de incluir, tabela e remocao. Devolve {itens, tabela, campos, selecionado}.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIFormItens(oApp, oW, aSpec)
    Local aIt  := {{}, Nil, {}, 0} as Array
    Local aCol := {{"n", "#"}} as Array
    Local oB   := Nil
    Local nI   := 0 as Numeric

    PoDivider():New(oW, "Itens")
    For nI := 1 To Len(aSpec)
        aAdd(aIt[3], TUICampo(oW, aSpec[nI], {}, .T.))
        aAdd(aCol, {"c" + cValToChar(nI), aSpec[nI][1]})
    Next nI
    oB := PoButton():New(oW, "Incluir item", {|| TUIItemInclui(oApp, aIt)})
    oB:Set("kind", "secondary")
    oB:Set("icon", "an an-plus")
    oB:SetCols(3)
    aIt[2] := PoTable():New(oW)
    aIt[2]:SetColumns(aCol)
    aIt[2]:OnSelect({|o, aLin| aIt[4] := Val(BOSTR(aLin[1]))})
    oB := PoButton():New(oW, "Remover item selecionado", {|| TUIItemRemove(oApp, aIt)})
    oB:Set("kind", "tertiary")
    oB:Set("icon", "an an-trash")
    oB:SetCols(4)
Return aIt

Static Function TUIItemInclui(oApp, aIt)
    Local aVal := TUIValores(aIt[3]) as Array
    Local nI   := 0 as Numeric

    If Empty(BOSTR(aVal[1]))
        oApp:Notify("Preencha o item antes de incluir.", "warning")
        Return
    EndIf
    aAdd(aIt[1], aVal)
    For nI := 1 To Len(aIt[3])
        If ValType(aIt[3][nI][2]) == "C"
            If aIt[3][nI][2] == "N"
                aIt[3][nI][1]:SetValue(0)
                Loop
            EndIf
            aIt[3][nI][1]:SetValue("")
        EndIf
    Next nI
    TUIItemMostra(aIt)
Return

Static Function TUIItemRemove(oApp, aIt)
    If aIt[4] < 1 .Or. aIt[4] > Len(aIt[1])
        oApp:Notify("Selecione um item na tabela.", "warning")
        Return
    EndIf
    aDel(aIt[1], aIt[4])
    aSize(aIt[1], Len(aIt[1]) - 1)
    aIt[4] := 0
    TUIItemMostra(aIt)
Return

Static Function TUIItemMostra(aIt)
    Local aLin := {} as Array
    Local aRow := {} as Array
    Local nI   := 0 as Numeric
    Local nJ   := 0 as Numeric

    For nI := 1 To Len(aIt[1])
        aRow := {cValToChar(nI)}
        For nJ := 1 To Len(aIt[1][nI])
            If ValType(aIt[1][nI][nJ]) == "N"
                aAdd(aRow, TUIQtd(aIt[1][nI][nJ]))
            Else
                aAdd(aRow, BOSTR(aIt[1][nI][nJ]))
            EndIf
        Next nJ
        aAdd(aLin, aRow)
    Next nI
    aIt[2]:SetItems(aLin)
Return

// Quantidade no formato brasileiro sem zeros inuteis: 1, 2,5, 0,375 ("1.000" se lia "mil").
Static Function TUIQtd(nQtd)
    Local cQ := AllTrim(Str(nQtd, 18, 3)) as Character

    Do While "." $ cQ .And. Right(cQ, 1) == "0"
        cQ := Left(cQ, Len(cQ) - 1)
    EndDo
    If Right(cQ, 1) == "."
        cQ := Left(cQ, Len(cQ) - 1)
    EndIf
Return StrTran(cQ, ".", ",")

// Botao auxiliar do formulario: o bloco devolve {lOk, cMsg, {{nCampo, xValor}...}}.
Static Function TUICalcula(oApp, bCalc, aCps)
    Local aR := Eval(bCalc, TUIValores(aCps)) as Array
    Local nI := 0 as Numeric

    If !aR[1]
        oApp:Notify(BOSTR(aR[2]), "error")
        Return
    EndIf
    For nI := 1 To Len(aR[3])
        aCps[aR[3][nI][1]][1]:SetValue(aR[3][nI][2])
    Next nI
Return

Static Function TUIExecuta(oApp, aF, aCps, cUsu, bDepois, aIt)
    Local aRes := {} as Array
    Local lOk  := .F. as Logical
    Local cMsg := "" as Character

    If Len(aF) >= 9
        If aF[9] != Nil
            If !GEBSECRBAC(cUsu, aF[9][1], aF[9][2])
                oApp:Notify("Sem permissao para " + aF[9][1] + "/" + aF[9][2] + ". Peca ao administrador.", "error")
                Return
            EndIf
        EndIf
    EndIf
    If aIt == Nil
        aRes := Eval(aF[6], cUsu, TUIValores(aCps))
    Else
        aRes := Eval(aF[6], cUsu, TUIValores(aCps), aIt[1])
    EndIf
    If aF[7] == "BO" .Or. aF[7] == "REL"
        lOk := aRes[1]
        cMsg := BOSTR(aRes[2])
    Else
        lOk := (aRes[1] == aF[7])
        cMsg := aF[8]
        If !lOk
            cMsg := GEBTUIMOTIVO(aRes)
        EndIf
    EndIf
    If !lOk
        oApp:Notify(aF[4] + " recusado: " + cMsg, "error")
        Return
    EndIf
    If aF[7] == "REL"
        GEBTUIBRW("GBR1", aF[4])
        Return
    EndIf
    oApp:Notify(cMsg, "success")
    If aIt != Nil
        aSize(aIt[1], 0)
        TUIItemMostra(aIt)
    EndIf
    Eval(bDepois)
Return

// Valores dos campos na ordem: "N" vira numero, o resto texto aparado.
Static Function TUIValores(aCps)
    Local aVal := {} as Array
    Local nI   := 0 as Numeric

    For nI := 1 To Len(aCps)
        // Ifs aninhados: o .And. do AdvPP avalia os dois lados (o tipo pode ser array).
        If ValType(aCps[nI][2]) == "C"
            If aCps[nI][2] == "N"
                aAdd(aVal, BOVAL(aCps[nI][1]:GetValue()))
                Loop
            EndIf
        EndIf
        aAdd(aVal, AllTrim(BOSTR(aCps[nI][1]:GetValue())))
    Next nI
Return aVal

/*/{Protheus.doc} TUICarrega
    Le uma tabela da empresa para um PoTable (ate 500 linhas, mais recentes
    primeiro; filtra a filial da sessao quando a tabela tem filial). GBR1
    (relatorio) usa a primeira linha como cabecalho.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUICarrega(oTab, cAlias, aColOut)
    Local aCol  := {} as Array
    Local aCols := {} as Array
    Local aLin  := {} as Array
    Local aHit  := {} as Array
    Local aRow  := {} as Array
    Local cSel  := "" as Character
    Local cWhr  := " WHERE D_E_L_E_T_ = ' '" as Character
    Local cCol  := "" as Character
    Local nI    := 0 as Numeric
    Local nJ    := 0 as Numeric

    If aColOut != Nil
        aSize(aColOut, 0)
    EndIf
    If !GEBDBTableExists(cAlias)
        oTab:SetColumns({{"aviso", "Aviso"}})
        oTab:SetItems({{"Tabela " + cAlias + " ainda nao existe nesta empresa."}})
        Return
    EndIf
    If cAlias == "GBR1"
        Return TUIRelatorio(oTab)
    EndIf
    // ponytail: a primeira tabela com esse nome no search_path; GE1/GE2 so' existem em public
    aHit := TCSqlQuery("SELECT column_name AS C FROM information_schema.columns WHERE table_name = " + GEBDBQuote(Lower(cAlias)) + ;
        " AND table_schema = (SELECT table_schema FROM information_schema.tables WHERE table_name = " + GEBDBQuote(Lower(cAlias)) + ;
        " AND table_schema = ANY (current_schemas(false)) ORDER BY array_position(current_schemas(false), table_schema::name) LIMIT 1)" + ;
        " ORDER BY ordinal_position")
    For nI := 1 To Len(aHit)
        cCol := Upper(AllTrim(BOSTR(aHit[nI]:C)))
        If cCol == Upper(cAlias) + "_FILIAL"
            If !(cAlias == "GE1" .Or. cAlias == "GE2")
                cWhr += " AND " + cCol + " = " + GEBDBQuote(FWxFilial(cAlias))
            EndIf
        ElseIf !(cCol == "R_E_C_N_O_" .Or. cCol == "D_E_L_E_T_") .And. !TUISigilo(cAlias, cCol)
            aAdd(aCol, cCol)
            aAdd(aCols, {Lower(cCol), TUIRotulo(SubStr(cCol, At("_", cCol) + 1))})
            If aColOut != Nil
                aAdd(aColOut, cCol)
            EndIf
            If !Empty(cSel)
                cSel += ", "
            EndIf
            cSel += cCol
        EndIf
    Next nI
    oTab:SetColumns(aCols)
    If Empty(cSel)
        oTab:SetItems({})
        Return
    EndIf
    aHit := TCSqlQuery("SELECT " + cSel + " FROM " + cAlias + cWhr + " ORDER BY R_E_C_N_O_ DESC LIMIT 500")
    For nI := 1 To Len(aHit)
        aRow := {}
        For nJ := 1 To Len(aCol)
            aAdd(aRow, AllTrim(BOSTR(aHit[nI][aCol[nJ]])))
        Next nJ
        aAdd(aLin, aRow)
    Next nI
    oTab:SetItems(aLin)
Return

// Coluna que a grade nunca mostra: credencial (salt, hash, senha, token) e as
// colunas SEC_* antigas da GE2 (as credenciais ficam na GE2_SEC).
Static Function TUISigilo(cAlias, cCol)
    If cAlias == "GE2" .And. Left(cCol, 4) == "SEC_"
        Return .T.
    EndIf
Return "SALT" $ cCol .Or. "HASH" $ cCol .Or. "SENHA" $ cCol .Or. "TOKEN" $ cCol

Static Function TUIRelatorio(oTab)
    Local aHit  := TCSqlQuery("SELECT GBR1_C1 AS C1, GBR1_C2 AS C2, GBR1_C3 AS C3, GBR1_C4 AS C4, GBR1_C5 AS C5, GBR1_C6 AS C6, GBR1_C7 AS C7, GBR1_C8 AS C8" + ;
        " FROM GBR1 WHERE D_E_L_E_T_ = ' ' AND GBR1_FILIAL = " + GEBDBQuote(FWxFilial("GBR1")) + ;
        " AND GBR1_SESSAO = " + GEBDBQuote(BOSESSAO()) + " ORDER BY GBR1_ORDEM") as Array
    Local aCols := {} as Array
    Local aLin  := {} as Array
    Local aRow  := {} as Array
    Local nI    := 0 as Numeric
    Local nJ    := 0 as Numeric

    If Len(aHit) == 0
        oTab:SetColumns({{"aviso", "Aviso"}})
        oTab:SetItems({{"Relatorio vazio."}})
        Return
    EndIf
    For nJ := 1 To 8
        If !Empty(BOSTR(aHit[1]["C" + cValToChar(nJ)]))
            aAdd(aCols, {"c" + cValToChar(nJ), TUIRotulo(StrTran(AllTrim(BOSTR(aHit[1]["C" + cValToChar(nJ)])), "_", " "))})
        EndIf
    Next nJ
    For nI := 2 To Len(aHit)
        aRow := {}
        For nJ := 1 To Len(aCols)
            aAdd(aRow, AllTrim(BOSTR(aHit[nI][Upper(aCols[nJ][1])])))
        Next nJ
        aAdd(aLin, aRow)
    Next nI
    oTab:SetColumns(aCols)
    oTab:SetItems(aLin)
Return

/*/{Protheus.doc} TUIRotulo
    Rotulo legivel de coluna ("GD1_COMP" -> sufixo "COMP" -> "Competencia").
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIRotulo(cSuf)
    Local aMapa := {{"COD", "Codigo"}, {"DESC", "Descricao"}, {"NOME", "Nome"}, {"CONTA", "Conta"}, {"SALDO", "Saldo"}, ;
        {"VALOR", "Valor"}, {"TOTAL", "Total"}, {"STATUS", "Situacao"}, {"COMP", "Competencia"}, {"GUIA", "Guia"}, ;
        {"PROD", "Produto"}, {"QTD", "Quantidade"}, {"MIN", "Minimo"}, {"EMIS", "Emissao"}, {"FORN", "Fornecedor"}, ;
        {"NUM", "Numero"}, {"DOC", "Documento"}, {"VENC", "Vencimento"}, {"COND", "Condicao"}, {"PRECO", "Preco"}, ;
        {"DATA", "Data"}, {"HORA", "Hora"}, {"USUARIO", "Usuario"}, {"PERFIL", "Perfil"}, {"EMPRESA", "Empresa"}} as Array
    Local nP := aScan(aMapa, {|x| x[1] == Upper(AllTrim(cSuf))}) as Numeric

    If nP > 0
        Return aMapa[nP][2]
    EndIf
    If Upper(cSuf) == cSuf .And. Len(cSuf) <= 4
        Return cSuf
    EndIf
Return Upper(Left(cSuf, 1)) + Lower(SubStr(cSuf, 2))

// Valor em reais no formato brasileiro (R$ 1.234.567,50).
Static Function TUIMoeda(nVal)
Return "R$ " + AllTrim(Transform(nVal, "@E 999,999,999,999.99"))

/*/{Protheus.doc} TUIInicio
    Pagina inicial: sessao, indicadores do dia (saldo em contas, titulos e
    guias em aberto, estoque abaixo do minimo), grafico de saldo por conta e
    atalhos para os modulos. "Atualizar" rele tudo.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIInicio(oApp, oPg, cEmp, cFil, cUsu, aAtalhos, aNav)
    Local oSem := Nil
    Local oWs   := PoWidget():New(oPg, "Sessao")
    Local aKpi  := {} as Array
    Local oWg   := Nil
    Local oCh   := Nil
    Local nI    := 0 as Numeric

    oWs:SetCols(12)
    TUIInfo(oWs, "Empresa", cEmp, 3)
    If Empty(cFil)
        TUIInfo(oWs, "Filial", "Matriz", 3)
    Else
        TUIInfo(oWs, "Filial", cFil, 3)
    EndIf
    TUIInfo(oWs, "Usuario", cUsu, 3)
    TUIInfo(oWs, "Data", DToC(Date()), 3)
    aAdd(aKpi, TUIKpi(oPg, "Saldo em contas"))
    aAdd(aKpi, TUIKpi(oPg, "Titulos em aberto"))
    aAdd(aKpi, TUIKpi(oPg, "Guias da Derrama"))
    aAdd(aKpi, TUIKpi(oPg, "Estoque abaixo do minimo"))
    oWg := PoWidget():New(oPg, "Saldo por conta")
    oWg:SetCols(12)
    oCh := PoChart():New(oWg, "Saldo por conta", "bar")
    oSem := PoInfo():New(oWg, "", "Nenhuma conta cadastrada. Crie em Financeiro > Nova conta.")
    If Len(aAtalhos) > 0
        PoDivider():New(oPg, "Acesso rapido")
        For nI := 1 To Len(aAtalhos)
            TUIAtalho(oApp, oPg, aAtalhos[nI], aNav)
        Next nI
    EndIf
    TUIIndicadores(aKpi, oCh, oSem)
    oPg:AddAction("Atualizar", {|| TUIIndicadores(aKpi, oCh, oSem)})
Return

// Coluna explicativa (7 de 12) ao lado do formulario das paginas de entrada.
Static Function TUIAjuda(oPg, cTitulo, aLinhas)
    Local oW := PoWidget():New(oPg, cTitulo)

    oW:SetCols(7)
    aEval(aLinhas, {|x| PoInfo():New(oW, x[1], x[2])})
Return oW

Static Function TUIInfo(oPai, cRot, cVal, nCols)
    Local oI := PoInfo():New(oPai, cRot, cVal)

    oI:SetCols(nCols)
Return oI

Static Function TUIKpi(oPg, cTitulo)
    Local oW := PoWidget():New(oPg, cTitulo)
    Local oV := PoInfo():New(oW, "", "-")
    Local oD := PoInfo():New(oW, "", "")

    oW:SetCols(3)
Return {oV, oD}

Static Function TUIAtalho(oApp, oPg, aAt, aNav)
    Local oB := PoButton():New(oPg, aAt[1], {|| aNav[1] := aAt[3], oApp:Navigate(aAt[3])})

    oB:Set("icon", aAt[2])
    oB:Set("kind", "secondary")
    oB:SetCols(2)
Return

/*/{Protheus.doc} TUIIndicadores
    Le os indicadores da empresa (cada tabela so' se existir).
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIIndicadores(aKpi, oCh, oSem)
    Local aHit := {} as Array
    Local aCat := {} as Array
    Local aVal := {} as Array
    Local cHoje := DToS(Date()) as Character
    Local nI   := 0 as Numeric

    If GEBDBTableExists("GFN1")
        aHit := TCSqlQuery("SELECT GFN1_CONTA AS C, GFN1_NOME AS N, GFN1_SALDO AS S FROM GFN1 WHERE D_E_L_E_T_ = ' ' AND GFN1_FILIAL = " + ;
            GEBDBQuote(FWxFilial("GFN1")) + " ORDER BY GFN1_SALDO DESC LIMIT 12")
        For nI := 1 To Len(aHit)
            aAdd(aCat, AllTrim(BOSTR(aHit[nI]:C)))
            aAdd(aVal, BOVAL(aHit[nI]:S))
        Next nI
        aHit := TCSqlQuery("SELECT COALESCE(SUM(GFN1_SALDO), 0) AS T, COUNT(*) AS Q FROM GFN1 WHERE D_E_L_E_T_ = ' ' AND GFN1_FILIAL = " + GEBDBQuote(FWxFilial("GFN1")))
        TUIKpiSet(aKpi[1], TUIMoeda(BOVAL(aHit[1]:T)), BOSTR(BOVAL(aHit[1]:Q)) + " conta(s)")
    EndIf
    oCh:SetCategories(aCat)
    oCh:SetSeries({{"Saldo", aVal}})
    oCh:SetVisible(Len(aCat) > 0)
    oSem:SetVisible(Len(aCat) == 0)
    If GEBDBTableExists("GFN3")
        aHit := TCSqlQuery("SELECT COUNT(*) AS Q, COALESCE(SUM(GFN3_SALDO), 0) AS T, COALESCE(SUM(CASE WHEN GFN3_VENC < " + GEBDBQuote(cHoje) + ;
            " THEN 1 ELSE 0 END), 0) AS V FROM GFN3 WHERE D_E_L_E_T_ = ' ' AND GFN3_SALDO > 0 AND GFN3_FILIAL = " + GEBDBQuote(FWxFilial("GFN3")))
        TUIKpiSet(aKpi[2], BOSTR(BOVAL(aHit[1]:Q)) + " titulo(s)", TUIMoeda(BOVAL(aHit[1]:T)) + "; " + BOSTR(BOVAL(aHit[1]:V)) + " vencido(s)")
    EndIf
    If GEBDBTableExists("GD1")
        aHit := TCSqlQuery("SELECT COUNT(*) AS Q, COALESCE(SUM(GD1_TOTAL), 0) AS T, COALESCE(SUM(CASE WHEN GD1_STATUS = 'VENCIDA' THEN 1 ELSE 0 END), 0) AS V" + ;
            " FROM GD1 WHERE D_E_L_E_T_ = ' ' AND GD1_STATUS IN ('ABERTA', 'VENCIDA') AND GD1_FILIAL = " + GEBDBQuote(FWxFilial("GD1")))
        TUIKpiSet(aKpi[3], BOSTR(BOVAL(aHit[1]:Q)) + " em aberto", TUIMoeda(BOVAL(aHit[1]:T)) + "; " + BOSTR(BOVAL(aHit[1]:V)) + " vencida(s)")
    EndIf
    If GEBDBTableExists("GV1")
        aHit := TCSqlQuery("SELECT COUNT(*) AS Q FROM GV1 WHERE D_E_L_E_T_ = ' ' AND GV1_SALDO < GV1_MIN AND GV1_FILIAL = " + GEBDBQuote(FWxFilial("GV1")))
        TUIKpiSet(aKpi[4], BOSTR(BOVAL(aHit[1]:Q)) + " produto(s)", "saldo menor que o minimo")
    EndIf
Return

Static Function TUIKpiSet(aK, cVal, cDet)
    aK[1]:SetValue(cVal)
    aK[2]:SetValue(cDet)
Return

/*/{Protheus.doc} TUIRastreio
    Rastreabilidade ponta a ponta (GEBEXP_TRAK): compra, venda, nota ou guia,
    mostrada como arvore de etapas.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function TUIRastreio(oApp, oPg)
    Local oW   := PoWidget():New(oPg, "Rastrear documento")
    Local oTip := PoSelect():New(oW, "Origem", {{"Pedido de compra", "C"}, {"Venda", "V"}, {"Nota fiscal (chave)", "N"}, {"Guia da Derrama", "D"}}, "C")
    Local oDoc := PoInput():New(oW, "Documento")
    Local oB   := PoButton():New(oW, "Rastrear")
    Local oWa  := PoWidget():New(oPg, "Caminho do documento")
    Local oArv := PoTree():New(oWa)

    oW:SetCols(4)
    oWa:SetCols(8)
    oB:Set("kind", "primary")
    oB:Set("icon", "an an-path")
    oB:OnClick({|| TUIRastreia(oApp, oArv, BOSTR(oTip:GetValue()), AllTrim(BOSTR(oDoc:GetValue())))})
Return

Static Function TUIRastreia(oApp, oArv, cTipo, cDoc)
    Local aRet   := {} as Array
    Local aNomes := {} as Array
    Local aItens := {} as Array
    Local aFilho := {} as Array
    Local nI     := 0 as Numeric
    Local nJ     := 0 as Numeric

    If Empty(cDoc)
        oApp:Notify("Informe o documento.", "warning")
        Return
    EndIf
    If cTipo == "C"
        aRet := GEBTRAKCOMPRA(cDoc)
        aNomes := {"Pedido", "Itens", "Entrada", "Estoque", "Contas a pagar", "Lancamentos"}
    ElseIf cTipo == "V"
        aRet := GEBTRAKVENDA(cDoc)
        aNomes := {"Venda", "Itens", "Estoque", "Contas a receber", "Lancamentos"}
    ElseIf cTipo == "N"
        aRet := GEBTRAKNOTAFISCAL(cDoc)
        aNomes := {"Nota", "Itens", "Calculo", "Contas a receber", "Apuracao", "Guia"}
    Else
        aRet := GEBTRAKDERRAMA(cDoc)
        aNomes := {"Apuracao", "Guia", "Parcelas", "Cobranca", "Contas a pagar", "Baixa", "Lancamentos"}
    EndIf
    For nI := 1 To Min(Len(aRet), Len(aNomes))
        aFilho := {}
        If ValType(aRet[nI]) == "A"
            For nJ := 1 To Len(aRet[nI])
                aAdd(aFilho, {TUILinha(aRet[nI][nJ]), cValToChar(nI) + "." + cValToChar(nJ)})
            Next nJ
        EndIf
        aAdd(aItens, {aNomes[nI] + " (" + cValToChar(Len(aFilho)) + ")", cValToChar(nI), aFilho})
    Next nI
    oArv:SetItems(aItens)
Return

// Registro de uma etapa como texto ("a | b | c").
Static Function TUILinha(xReg)
    Local cOut := "" as Character
    Local nI   := 0 as Numeric

    If ValType(xReg) != "A"
        Return AllTrim(BOSTR(xReg))
    EndIf
    For nI := 1 To Len(xReg)
        If nI > 1
            cOut += " | "
        EndIf
        cOut += AllTrim(BOSTR(xReg[nI]))
    Next nI
Return cOut

/*/{Protheus.doc} GEBTUIBRWAPP
    Desvia GEBTUIBRW para um bloco {|cAlias, cTitulo| ...} (Nil = FWMBrowse).
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
User Function GEBTUIBRWAPP(bBloco)
    bTUIBrw := bBloco
Return .T.

/*/{Protheus.doc} GEBTUIEMPRESAS
    Lista empresas do catalogo para o menu (pares {cod, nome}).
    @type Helper
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBTUIEMPRESAS(cUsu)
    Local aArea := GetArea()
    Local aOut := {}
    Local aHit := {}
    Local nI := 0
    If cUsu == Nil
        cUsu := ""
    EndIf
    // Super ve todas. Os demais veem so' as empresas vinculadas em GE2_EMP
    // (antes a lista expunha o nome de empresas sem vinculo).
    If GEBSECISSUPER(cUsu)
        aHit := TCSqlQuery("SELECT GE1_COD, GE1_NOME FROM public.GE1 WHERE D_E_L_E_T_ = ' ' ORDER BY GE1_COD")
    Else
        aHit := TCSqlQuery("SELECT GE1_COD, GE1_NOME FROM public.GE1 WHERE D_E_L_E_T_ = ' ' AND LOWER(GE1_COD) IN (SELECT LOWER(GE2_EMP_EMPRESA) FROM public.GE2_EMP WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cUsu) + " AND D_E_L_E_T_ = ' ') ORDER BY GE1_COD")
    EndIf
    For nI := 1 To Len(aHit)
        AAdd(aOut, {cValToChar(aHit[nI]:GE1_COD), cValToChar(aHit[nI]:GE1_NOME)})
    Next nI
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aOut

/*/{Protheus.doc} GEBTUIFILIAL
    Filiais do usuario na empresa, {{rotulo, codigo}} ("" = matriz). Super
    entra na matriz sem gravar vinculo.
    @type Consulta
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBTUIFILIAL(cUsu, cEmp)
    Local aVinc := {}
    Local aReg  := {}
    Local aOut  := {}
    Local cFil  := ""
    Local cNome := ""
    Local nI    := 0
    Local nJ    := 0

    If GEBSECISSUPER(cUsu)
        Return {{"Matriz", ""}}
    EndIf
    If !GEBDBSchemaValido(cEmp)
        Return {}
    EndIf
    aVinc := TCSqlQuery("SELECT DISTINCT GE2_EMP_FILIAL FROM public.GE2_EMP WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cUsu) + " AND GE2_EMP_EMPRESA = " + GEBDBQuote(Lower(cEmp)) + " AND D_E_L_E_T_ = ' '")
    // GEF1 e' do tenant e a sessao ainda nao trocou de empresa: schema explicito (cEmp validado acima).
    If Len(aVinc) > 1
        aReg := TCSqlQuery("SELECT GEF1_COD, GEF1_NOME FROM emp_" + Lower(AllTrim(cEmp)) + ".GEF1 WHERE D_E_L_E_T_ = ' '")
    EndIf
    For nI := 1 To Len(aVinc)
        cFil := Upper(AllTrim(BOSTR(aVinc[nI]:GE2_EMP_FILIAL)))
        cNome := "Matriz"
        If !Empty(cFil)
            cNome := cFil
        EndIf
        For nJ := 1 To Len(aReg)
            If Upper(AllTrim(BOSTR(aReg[nJ]:GEF1_COD))) == cFil
                cNome := BOSTR(aReg[nJ]:GEF1_NOME)
                Exit
            EndIf
        Next nJ
        aAdd(aOut, {cFil + " - " + cNome, cFil})
    Next nI
Return aOut

/*/{Protheus.doc} GEBTUIBRW
    Abre browse FWMBrowse da tabela (padrao GesCon).
    @type Helper
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBTUIBRW(cAlias, cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil
    If bTUIBrw != Nil
        Return Eval(bTUIBrw, cAlias, cTitle)
    EndIf
    If !GEBDBTableExists(cAlias)
        ConOut("GEBTUIBRW: tabela " + cAlias + " fora do search_path")
        MsgStop("Tabela " + cAlias + " indisponivel.", "GEBAN")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    DbSelectArea(cAlias)
    oBrowse := FWMBrowse():New()
    // Catalogo (empresas, unidades, filiais, usuarios): grade so' de consulta.
    // Incluir/alterar passa pelas acoes do menu Nucleo, que validam senha,
    // vinculo e escopo -- a grade gravava direto na tabela (CAT-010).
    If cAlias == "GE1" .Or. cAlias == "GEU1" .Or. cAlias == "GEF1" .Or. cAlias == "GE2"
        oBrowse:SetMenuDef("")
    EndIf
    oBrowse:SetAlias(cAlias)
    oBrowse:SetDescription(cTitle)
    oBrowse:Activate()
    DbCloseArea()
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

/*/{Protheus.doc} GEBTUITROCASENHA
    Troca senha e/ou propriedades (nome, perfil) de um usuario.
    Logica pura (sem chamadas FW ou Msg) para ser testavel em modo blind;
    o menu Nucleo so coleta os prompts e exibe o retorno.
    cAlvo vazio/Nil = o proprio cUsuLog; cSenha vazia/Nil = mantem;
    cNome/cPerfil vazio/Nil = mantem. Nunca remove vinculos.
    @type Helper Nucleo
    @author Peder Munksgaard
    @since 26/09/2026
    @param cUsuLog Chamador ja autenticado (confianca do menu)
    @param cAlvo Alvo ("" = proprio)
    @param cSenha Nova senha ("" = mantem)
    @param cNome Novo nome ("" = mantem)
    @param cPerfil Novo perfil ("" = mantem)
    @return {lOk, cMsg} (cMsg: usuario_atualizado, nada_a_alterar,
    somente_super, usuario_inexistente, senha_recusada[: motivo],
    troca_recusada, nome_recusado, perfil_recusado)
/*/
User Function GEBTUITROCASENHA(cUsuLog, cAlvo, cSenha, cNome, cPerfil)
    Local aArea := GetArea()
    Local lOk := .T.
    Local cMsg := "usuario_atualizado"
    Local aUsr := {}
    Local aPol := {}
    Local cAtuNome := ""
    Local cAtuPerfil := ""
    Local cAlvoL := ""
    Local cSenhaL := ""
    Local cNomeL := ""
    Local cPerfilL := ""
    If cUsuLog == Nil
        cUsuLog := ""
    EndIf
    If cAlvo == Nil
        cAlvoL := AllTrim(cValToChar(cUsuLog))
    Else
        If Empty(cAlvo)
            cAlvoL := AllTrim(cValToChar(cUsuLog))
        Else
            cAlvoL := AllTrim(cValToChar(cAlvo))
        EndIf
    EndIf
    If cSenha == Nil
        cSenhaL := ""
    Else
        cSenhaL := cSenha
    EndIf
    If !GEBDBSchemaValido(cAlvoL)
        lOk := .F.
        cMsg := "usuario_inexistente"
    EndIf
    If lOk
        If GEBSECISSUPER(cAlvoL)
            If !GEBSECISSUPER(cUsuLog)
                lOk := .F.
                cMsg := "somente_super"
            EndIf
        EndIf
    EndIf
    If lOk
        aUsr := TCSqlQuery("SELECT GE2_NOME, GE2_PERFIL FROM public.GE2 WHERE GE2_COD = " + GEBDBQuote(cAlvoL) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
        If Len(aUsr) == 0
            lOk := .F.
            cMsg := "usuario_inexistente"
        Else
            cAtuNome := cValToChar(aUsr[1]:GE2_NOME)
            // Perfil e' por empresa: le o vinculo da empresa da sessao.
            aPf := TCSqlQuery("SELECT UPPER(TRIM(GE2_EMP_PERFIL)) AS PERF FROM public.GE2_EMP WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cAlvoL) + " AND LOWER(TRIM(GE2_EMP_EMPRESA)) = " + GEBDBQuote(GEBDBTenantAtual()) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
            // Sem vinculo nesta empresa: so' bloqueia se houver troca de perfil (abaixo).
            lSemVinc := (Len(aPf) == 0)
            If !lSemVinc
                cAtuPerfil := AllTrim(cValToChar(aPf[1]:PERF))
            EndIf
        EndIf
    EndIf
    If lOk
        If cNome == Nil
            cNomeL := cAtuNome
        Else
            If Empty(cNome)
                cNomeL := cAtuNome
            Else
                cNomeL := cValToChar(cNome)
            EndIf
        EndIf
        If cPerfil == Nil
            cPerfilL := cAtuPerfil
        Else
            If Empty(cPerfil)
                cPerfilL := cAtuPerfil
            Else
                cPerfilL := cValToChar(cPerfil)
            EndIf
        EndIf
        If Empty(cSenhaL)
            If AllTrim(cNomeL) == AllTrim(cAtuNome)
                If Upper(AllTrim(cPerfilL)) == Upper(AllTrim(cAtuPerfil))
                    lOk := .F.
                    cMsg := "nada_a_alterar"
                EndIf
            EndIf
        EndIf
    EndIf
    // Autorizacao (antes de gravar qualquer coisa): mexer em OUTRO usuario
    // exige a regra unica GEBSECPODE (ADMIN da empresa, alvo so' dela);
    // mudar perfil -- inclusive o proprio -- so' o super ou um ADMIN sobre
    // terceiro da propria empresa (ninguem se promove sozinho).
    If lOk .And. Lower(cAlvoL) != Lower(AllTrim(cValToChar(cUsuLog)))
        If !GEBSECPODE(cUsuLog, cAlvoL, .T.)
            lOk := .F.
            cMsg := "sem_permissao: so ADMIN da empresa altera outro usuario dela"
        EndIf
    EndIf
    If lOk .And. Upper(AllTrim(cPerfilL)) != Upper(AllTrim(cAtuPerfil)) .And. !GEBSECISSUPER(cUsuLog)
        If Lower(cAlvoL) == Lower(AllTrim(cValToChar(cUsuLog)))
            lOk := .F.
            cMsg := "sem_permissao: ninguem altera o proprio perfil"
        EndIf
    EndIf
    If lOk
        If !Empty(cSenhaL)
            aPol := GEBSECPOL_VERIFICA(cSenhaL)
            If Len(aPol) >= 1
                If !aPol[1]
                    lOk := .F.
                    cMsg := "senha_recusada"
                    If Len(aPol) >= 2
                        cMsg := "senha_recusada: " + cValToChar(aPol[2])
                    EndIf
                EndIf
            Else
                lOk := .F.
                cMsg := "senha_recusada"
            EndIf
        EndIf
    EndIf
    If lOk
        If !Empty(cSenhaL)
            lOk := GEBSECCRIAUSU(cAlvoL, cSenhaL, {}, Nil, Nil, GEBSECISSUPER(cUsuLog))
            If !lOk
                cMsg := "troca_recusada"
            ElseIf Lower(cAlvoL) != Lower(AllTrim(cValToChar(cUsuLog)))
                GEBSECDERRUBA(cAlvoL) // senha trocada por outra pessoa: derruba as sessoes dele
            EndIf
        EndIf
    EndIf
    If lOk
        If AllTrim(cNomeL) != AllTrim(cAtuNome)
            If Empty(cNomeL)
                lOk := .F.
                cMsg := "nome_recusado"
            Else
                lOk := TCSqlExec("UPDATE public.GE2 SET GE2_NOME = '" + StrTran(AllTrim(cNomeL), "'", "''") + "' WHERE GE2_COD = " + GEBDBQuote(cAlvoL) + " AND D_E_L_E_T_ = ' '")
                If !lOk
                    cMsg := "nome_recusado"
                EndIf
            EndIf
        EndIf
    EndIf
    If lOk .And. lSemVinc .And. Upper(AllTrim(cPerfilL)) != Upper(AllTrim(cAtuPerfil))
        lOk := .F.
        cMsg := "usuario_sem_vinculo"
    EndIf
    If lOk
        If Upper(AllTrim(cPerfilL)) != Upper(AllTrim(cAtuPerfil))
            If Empty(cPerfilL)
                lOk := .F.
                cMsg := "perfil_recusado"
            Else
                If !GEBDBSchemaValido(cPerfilL)
                    lOk := .F.
                    cMsg := "perfil_recusado"
                Else
                    lOk := TCSqlExec("UPDATE public.GE2_EMP SET GE2_EMP_PERFIL = " + GEBDBQuote(Upper(AllTrim(cPerfilL))) + " WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cAlvoL) + " AND LOWER(TRIM(GE2_EMP_EMPRESA)) = " + GEBDBQuote(GEBDBTenantAtual()) + " AND D_E_L_E_T_ = ' '")
                    If !lOk
                        cMsg := "perfil_recusado"
                    EndIf
                EndIf
            EndIf
        EndIf
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {lOk, cMsg}

/*/{Protheus.doc} GEBTUIMOTIVO
    Extrai o primeiro motivo de erro do JSON devolvido pelos GEBREST*
    ({cStatus, cBody}) para mostrar ao usuario o porque da recusa, em vez
    de uma mensagem generica.
    @type Helper UI
    @author Peder Munksgaard
    @since 02/10/2026
    @param aRes Retorno {cStatus, cBody} de um GEBREST*
    @return cMotivo Primeiro item de "erros", ou "HTTP <status>"
/*/
Static Function GEBTUIMOTIVO(aRes)
    Local cBody := ""
    Local cMot := ""
    Local nPos := 0

    If ValType(aRes) != "A"
        Return "sem resposta"
    EndIf
    If Len(aRes) < 2
        Return "sem resposta"
    EndIf
    cBody := cValToChar(aRes[2])
    nPos := At('"erros":["', cBody)
    If nPos > 0
        cMot := SubStr(cBody, nPos + 10)
        nPos := At('"', cMot)
        If nPos > 1
            cMot := Left(cMot, nPos - 1)
        Else
            cMot := ""
        EndIf
    EndIf
    If cMot == ""
        cMot := "HTTP " + cValToChar(aRes[1])
    EndIf
Return cMot

// ===== PERMISSOES POR PERFIL (SEC_PERM) =====

// Areas que a tela e a API controlam: {menu, item, descricao}. Mesmo mapa
// de GEBRESTRBAC (src/GEBREST.prw).
Static Function GEBTUIAREAS()
Return {{"FISCAL", "PRODUT", "Fiscal - produtos"}, {"FISCAL", "NOTAS", "Fiscal - notas"}, ;
    {"FISCAL", "APURA", "Fiscal - apuracao, credito, aliquota"}, {"FINANCEIRO", "FLUXO", "Financeiro"}, ;
    {"DERRAMA", "GUIAS", "Derrama"}, {"ESTOQUE", "ESTOQ", "Estoque, vendas e fiado"}, ;
    {"CONTABIL", "LANCTO", "Contabil"}, {"COMPRAS", "PEDID", "Compras"}, ;
    {"SEGURANCA", "USUARI", "Usuarios (API)"}, {"CONFIG", "EMPRES", "Empresas e unidades (API)"}, ;
    {"MONITOR", "MONITR", "Monitor de sessoes (API)"}, {"RELATORIOS", "GERENC", "Relatorio gerencial (API)"}, ;
    {"COMPRAS", "APROVA", "Compras - aprovacao de alcada"}, {"FATURAMENTO", "FATUR", "Faturamento"}, ;
    {"FATURAMENTO", "LIBERA", "Faturamento - liberacao forcada"}, {"LOJA", "CAIXA", "Frente de loja"}, ;
    {"LOJA", "ORCAM", "Frente de loja - orcamento"}, {"LOJA", "GEREN", "Frente de loja - cadastros e gerencial"}, ;
    {"LOJA", "DESCONTO", "Frente de loja - libera desconto acima do limite"}, ;
    {"FINANCEIRO", "BANCO", "Financeiro - boleto, CNAB e conciliacao"}, ;
    {"FISCAL", "DFE", "Fiscal - documentos eletronicos: emitente, certificado, cancelamento, inutilizacao"}}

// Item do Fiscal para cada opcao do menu Fiscal (1..7).
/*/{Protheus.doc} GEBTUIMODOK
    .T. se o usuario pode entrar no modulo (tem permissao em ao menos um item
    dele). ADMIN e super: tudo (regra padrao de GEBSECRBAC). lAvisa mostra o
    motivo na tela quando nega.
    @type Funcao de seguranca
    @author Peder Munksgaard
    @since 03/10/2026
/*/
User Function GEBTUIMODOK(cUsu, cMenu, lAvisa)
    Local aAreas := GEBTUIAREAS()
    Local nI := 0
    For nI := 1 To Len(aAreas)
        If aAreas[nI][1] == cMenu .And. GEBSECRBAC(cUsu, cMenu, aAreas[nI][2])
            Return .T.
        EndIf
    Next nI
    If lAvisa != Nil .And. lAvisa
        MsgStop("Sem permissao para " + cMenu + ". Peca ao super: Nucleo > Permissoes.", "GEBAN")
    EndIf
Return .F.

/*/{Protheus.doc} GEBTUIPERMSETEMP
    Concede (lPermite .T.) ou revoga (.F.) uma area para um perfil, numa empresa.
    Super: qualquer empresa ("*" = todas). ADMIN da empresa da sessao: so' a propria empresa.
    @type Funcao de seguranca
    @param cUsuLog   Quem pede
    @param cEmpresa  Empresa alvo ("*" = todas as empresas; so' o super)
    @return {lOk, cMsg}
/*/
User Function GEBTUIPERMSETEMP(cUsuLog, cEmpresa, cPerfil, cMenu, cItem, lPermite)
    Local cPerf   := Upper(AllTrim(cValToChar(cPerfil)))
    Local cEmpS   := ""
    Local cEmpT   := Lower(AllTrim(cValToChar(GEBDBTenantAtual())))
    Local aAreas  := GEBTUIAREAS()
    Local lArea   := .F.
    Local nI      := 0

    If cEmpresa == Nil
        cEmpS := ""
    Else
        cEmpS := Lower(AllTrim(cValToChar(cEmpresa)))
    EndIf
    If !GEBSECISSUPER(cUsuLog)
        If !GEBSECPODE(cUsuLog, "", .F.)
            Return {.F., "so o ADMIN da empresa ou o super alteram permissoes"}
        EndIf
        If cEmpS != cEmpT
            Return {.F., "o ADMIN so altera permissoes da propria empresa"}
        EndIf
    EndIf
    If cEmpS == ""
        Return {.F., "empresa nao informada"}
    EndIf
    If cPerf == "" .Or. !GEBDBSchemaValido(Lower(cPerf))
        Return {.F., "perfil invalido: use letras, numeros e _"}
    EndIf
    If cPerf == "ADMIN"
        Return {.F., "o perfil ADMIN tem todas as permissoes e nao e editavel"}
    EndIf
    For nI := 1 To Len(aAreas)
        If aAreas[nI][1] == cMenu .And. aAreas[nI][2] == cItem
            lArea := .T.
        EndIf
    Next nI
    If !lArea
        Return {.F., "area inexistente: " + cValToChar(cMenu) + "/" + cValToChar(cItem)}
    EndIf
    If !GEBSECRBACADDEMP(cPerf, cEmpS, cMenu, cItem, lPermite)
        Return {.F., "falha ao gravar a permissao"}
    EndIf
Return {.T., "ok"}

/*/{Protheus.doc} GEBTUIPERMSET
    Concede ou revoga uma area para um perfil em TODAS as empresas. So' o super.
    Mantido por compatibilidade; a tela usa GEBTUIPERMSETEMP.
    @type Funcao de seguranca
    @return {lOk, cMsg}
/*/
User Function GEBTUIPERMSET(cUsuLog, cPerfil, cMenu, cItem, lPermite)
    If !GEBSECISSUPER(cUsuLog)
        Return {.F., "so o super altera permissoes para todas as empresas"}
    EndIf
Return GEBTUIPERMSETEMP(cUsuLog, "*", cPerfil, cMenu, cItem, lPermite)

