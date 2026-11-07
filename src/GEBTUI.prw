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

/*/{Protheus.doc} GEBTUI
    Interface nativa AdvPL do ERP GEBAN (padrao GesCon: sem HTML).
    Roda sob `advplc serve src/GEBTUI.prw`: login (usuario/senha,
    empresa e filial via menus) e menu principal com os 7 modulos,
    cada um com browse (FWMBrowse) e acoes que chamam as mesmas
    funcoes de negocio da API REST. Nenhuma string HTML aqui.
    @type Entrada serve
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBTUI()
    Local aCtx := {}
    ConOut("GEBAN - Sistema de Gestao Empresarial")
    If !GEBDBConecta()
        MsgStop("Banco indisponivel.", "GEBAN")
        Return .F.
    EndIf
    If !GEBDBProvisionaCatalogo()
        MsgStop("Catalogo indisponivel.", "GEBAN")
        Return .F.
    EndIf
    aCtx := GEBTUILOGIN()
    If Len(aCtx) < 3
        Return .F.
    EndIf
    GEBTUIMENU(aCtx[1], aCtx[2], aCtx[3])
Return .T.

/*/{Protheus.doc} GEBTUILOGIN
    Login nativo: usuario/senha, empresa (menu) e filial (menu).
    super global entra direto com a matriz (garante o vinculo) e,
    com o catalogo vazio, cria a primeira empresa na hora (bootstrap).
    @type Login serve
    @author Peder Munksgaard
    @since 25/09/2026
    @return {cEmp, cFil, cUsu} ou {} se desistir/falhar
/*/
User Function GEBTUILOGIN()
    Local cUsu := ""
    Local cSen := ""
    Local cEmp := ""
    Local cFil := ""
    Local nTent := 0
    Local lOk := .F.
    Local aEmps := {}
    Local aEmpCod := {}
    Local nEmp := 0
    Local aFils := {}
    Local nFil := 0
    Local cCod := ""
    Local cNome := ""
    Do While nTent < 3 .And. !lOk
        cUsu := FWGetText("Usuario:", "")
        If Empty(cUsu)
            Return {}
        EndIf
        cSen := FWGetText("Senha:", "", .T.)
        If Empty(cSen)
            Return {}
        EndIf
        If GEBSECLOGIN(AllTrim(cUsu), AllTrim(cSen), "tui") == "OK"
            lOk := .T.
        Else
            MsgStop("Credenciais invalidas.", "GEBAN")
        EndIf
        nTent := nTent + 1
    EndDo
    If !lOk
        Return {}
    EndIf
    cUsu := AllTrim(cUsu)
    aEmps := GEBTUIEMPRESAS(cUsu)
    If Len(aEmps) == 0
        If !GEBSECISSUPER(cUsu)
            MsgStop("Nenhuma empresa vinculada a este usuario. Peca ao super: Nucleo > Empresas.", "GEBAN")
            Return {}
        EndIf
        MsgInfo("Catalogo vazio: o super cria a primeira empresa agora.", "GEBAN")
        cCod := FWGetText("Codigo da empresa (2 letras ou digitos):", "")
        If Empty(cCod)
            Return {}
        EndIf
        cNome := FWGetText("Nome da empresa:", "")
        If Empty(cNome)
            Return {}
        EndIf
        If !GEBDBProvisionaEmpresa(AllTrim(cCod), AllTrim(cNome))
            MsgStop("Falha ao criar a empresa. Confira o codigo (letras, digitos e _).", "GEBAN")
            Return {}
        EndIf
        aEmps := GEBTUIEMPRESAS(cUsu)
        If Len(aEmps) == 0
            MsgStop("Nenhuma empresa cadastrada.", "GEBAN")
            Return {}
        EndIf
    EndIf
    aEmpCod := {}
    For nEmp := 1 To Len(aEmps)
        AAdd(aEmpCod, "icon:buildings|" + AllTrim(cValToChar(aEmps[nEmp][1])) + " - " + AllTrim(cValToChar(aEmps[nEmp][2])))
    Next nEmp
    nEmp := FWMenuSelect(aEmpCod, "Empresa:")
    If nEmp <= 0 .Or. nEmp > Len(aEmps)
        Return {}
    EndIf
    cEmp := AllTrim(cValToChar(aEmps[nEmp][1]))
    cFil := GEBTUIFILIAL(cUsu, cEmp)
    If cFil == Nil
        Return {}
    EndIf
    If !GEBDBSetTenant(cEmp)
        MsgStop("Empresa indisponivel.", "GEBAN")
        Return {}
    EndIf
    GBAUDINIC()
    GEBMONINIC()
    If !GEBEXPCONTEXTO(cEmp, cFil, cUsu)
        MsgStop("Sessao recusada.", "GEBAN")
        Return {}
    EndIf
    MsgInfo("Bem-vindo, " + cUsu + ".", "GEBAN")
Return {cEmp, cFil, cUsu}

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
    Escolhe a filial do usuario na empresa (menu; super entra direto).
    @type Helper
    @author Peder Munksgaard
    @since 25/09/2026
    @return Codigo da filial, "" matriz, Nil se desistir
/*/
User Function GEBTUIFILIAL(cUsu, cEmp)
    Local aArea := GetArea()
    Local aVinc := {}
    Local aDisp := {}
    Local nI := 0
    Local nJ := 0
    Local cFil := ""
    Local cNome := ""
    Local aReg := {}
    Local nOp := 0
    // Super entra em qualquer empresa sem gravar vinculo (antes criava GE2_EMP
    // como efeito colateral da leitura). Vinculo, se preciso, e' explicito.
    If GEBSECISSUPER(cUsu)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return ""
    EndIf
    aVinc := TCSqlQuery("SELECT DISTINCT GE2_EMP_FILIAL FROM public.GE2_EMP WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cUsu) + " AND GE2_EMP_EMPRESA = " + GEBDBQuote(Lower(cEmp)) + " AND D_E_L_E_T_ = ' '")
    If Len(aVinc) == 0
        MsgStop("Sem vinculo com esta empresa.", "GEBAN")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return Nil
    EndIf
    If Len(aVinc) == 1
        cFil := Upper(AllTrim(cValToChar(aVinc[1]:GE2_EMP_FILIAL)))
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return cFil
    EndIf
    // GEF1 e' do tenant: a sessao ainda nao trocou para a empresa (isso acontece depois),
    // entao a consulta usa o schema da empresa explicitamente (cEmp validado antes).
    If !GEBDBSchemaValido(cEmp)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return Nil
    EndIf
    aReg := TCSqlQuery("SELECT GEF1_COD, GEF1_NOME FROM emp_" + Lower(AllTrim(cEmp)) + ".GEF1 WHERE D_E_L_E_T_ = ' '")
    For nI := 1 To Len(aVinc)
        cFil := Upper(AllTrim(cValToChar(aVinc[nI]:GE2_EMP_FILIAL)))
        cNome := cFil
        If cFil == ""
            cNome := "Matriz"
        EndIf
        For nJ := 1 To Len(aReg)
            If Upper(AllTrim(cValToChar(aReg[nJ]:GEF1_COD))) == cFil
                cNome := cValToChar(aReg[nJ]:GEF1_NOME)
                Exit
            EndIf
        Next nJ
        AAdd(aDisp, "icon:storefront|" + cFil + " - " + cNome)
    Next nI
    nOp := FWMenuSelect(aDisp, "Filial:")
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
    If nOp <= 0 .Or. nOp > Len(aVinc)
        Return Nil
    EndIf
Return Upper(AllTrim(cValToChar(aVinc[nOp]:GE2_EMP_FILIAL)))

/*/{Protheus.doc} GEBTUIBRW
    Abre browse FWMBrowse da tabela (padrao GesCon).
    @type Helper
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBTUIBRW(cAlias, cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil
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

/*/{Protheus.doc} GEBTUIMENU
    Menu principal: 7 modulos + Sair (loop ate sair).
    @type Menu
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBTUIMENU(cEmp, cFil, cUsu)
    Local aOps := {"icon:receipt|Fiscal", "icon:wallet|Financeiro", "icon:bank|Derrama", "icon:package|Estoque", "icon:calculator|Contabil", "icon:shopping-cart|Compras", "icon:file-text|Faturamento", "icon:storefront|Frente de loja", "icon:gear|Nucleo", "icon:sign-out|< Sair"}
    Local nOp := 0
    Do While .T.
        nOp := FWMenuSelect(aOps, "GEBAN " + cEmp + ":")
        If nOp == Nil
            Exit
        EndIf
        If nOp <= 0 .Or. nOp == 10
            Exit
        EndIf
        If nOp == 1
            If GEBTUIMODOK(cUsu, "FISCAL", .T.)
                GEBTUIFISCAL(cEmp, cFil, cUsu)
            EndIf
        Else
            If nOp == 2
                If GEBTUIMODOK(cUsu, "FINANCEIRO", .T.)
                    GEBTUIFIN(cEmp, cFil, cUsu)
                EndIf
            Else
                If nOp == 3
                    If GEBTUIMODOK(cUsu, "DERRAMA", .T.)
                        GEBTUIDER(cEmp, cFil, cUsu)
                    EndIf
                Else
                    If nOp == 4
                        If GEBTUIMODOK(cUsu, "ESTOQUE", .T.)
                            GEBTUIEST(cEmp, cFil, cUsu)
                        EndIf
                    Else
                        If nOp == 5
                            If GEBTUIMODOK(cUsu, "CONTABIL", .T.)
                                GEBTUICTB(cEmp, cFil, cUsu)
                            EndIf
                        Else
                            If nOp == 6
                                If GEBTUIMODOK(cUsu, "COMPRAS", .T.)
                                    GEBTUICOM(cEmp, cFil, cUsu)
                                EndIf
                            ElseIf nOp == 7
                                If GEBTUIMODOK(cUsu, "FATURAMENTO", .T.)
                                    GEBTUIFAT(cEmp, cFil, cUsu)
                                EndIf
                            ElseIf nOp == 8
                                If GEBTUIMODOK(cUsu, "LOJA", .T.)
                                    GEBTUILOJ(cEmp, cFil, cUsu)
                                EndIf
                            Else
                                GEBTUINUC(cEmp, cFil, cUsu)
                            EndIf
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf
    EndDo
    MsgInfo("Sessao encerrada.", "GEBAN")
Return .T.

/*/{Protheus.doc} GEBTUIFISCAL
    Tela do modulo Fiscal (browse + operacoes).
    @type Tela
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBTUIFISCAL(cEmp, cFil, cUsu)
    Local aOps := {"icon:clipboard|Produtos", "icon:clipboard|Notas", "icon:plus|+ Novo produto", "icon:check-circle|Emitir nota", "icon:check-circle|Apurar competencia", "icon:check-circle|Lancar credito", "icon:plus|+ Nova aliquota (NCM)", "icon:calculator|Simples Nacional", "icon:gear|Documentos eletronicos (NF-e/NFC-e)", "icon:arrow-left|< Voltar"}
    Local nOp := 0
    Local cCod := ""
    Local cNCM := ""
    Local cDes := ""
    Local cCha := ""
    Local cProd := ""
    Local nQtd := 0
    Local nPre := 0
    Local cComp := ""
    Local cOri := ""
    Local nVal := 0
    Local cTip := ""
    Local cReg := ""
    Local aRes := {}
    Do While .T.
        nOp := FWMenuSelect(aOps, "Fiscal:")
        If nOp == Nil
            Exit
        EndIf
        If nOp <= 0 .Or. nOp == 10
            Exit
        EndIf
        If nOp == 9
            GEBTUIDFE(cEmp, cFil, cUsu)
            Loop
        EndIf
        // Permissao por acao (mesmo mapa da API): produtos, notas, apuracao.
        If !GEBTUIACAOOK(cUsu, "FISCAL", GEBTUIFISITEM(nOp))
            Loop
        EndIf
        If nOp == 1
            GEBTUIBRW("GF1", "Produtos")
        Else
            If nOp == 2
                GEBTUIBRW("GF3", "Notas")
            Else
                If nOp == 3
                    cCod := FWGetText("Codigo:", "")
                    cNCM := FWGetText("NCM:", "")
                    cDes := FWGetText("Descricao:", "")
                    aRes := GEBRESTPRDLSC(cUsu, {cCod, cNCM, cDes})
                    If aRes[1] == "201"
                        MsgInfo("Produto criado.", "Fiscal")
                    Else
                        MsgStop("Produto recusado: " + GEBTUIMOTIVO(aRes), "Fiscal")
                    EndIf
                Else
                    If nOp == 4
                        cCha := FWGetText("Chave:", "")
                        cProd := FWGetText("Produto:", "")
                        nQtd := Val(FWGetText("Quantidade:", ""))
                        nPre := Val(FWGetText("Preco:", ""))
                        aRes := GEBRESTNOTPOST(cUsu, {cCha, cProd, nQtd, nPre})
                        If aRes[1] == "201"
                            MsgInfo("Nota emitida.", "Fiscal")
                        Else
                            MsgStop("Nota recusada: " + GEBTUIMOTIVO(aRes), "Fiscal")
                        EndIf
                    Else
                        If nOp == 5
                            cComp := FWGetText("Competencia AAAAMM:", "")
                            aRes := GEBRESTFISAPU(cUsu, {cComp})
                            If aRes[1] == "200"
                                MsgInfo("Competencia apurada.", "Fiscal")
                            Else
                                MsgStop("Apuracao recusada: " + GEBTUIMOTIVO(aRes), "Fiscal")
                            EndIf
                        ElseIf nOp == 8
                            GEBTUISN(cUsu)
                        ElseIf nOp == 6
                            cComp := FWGetText("Competencia AAAAMM:", "")
                            cOri := FWGetText("Origem:", "")
                            nVal := Val(FWGetText("Valor:", ""))
                            cTip := FWGetText("Tipo:", "")
                            cReg := GEBFCRE(cComp, cOri, nVal, cTip)
                            If cReg == ""
                                MsgStop("Credito recusado.", "Fiscal")
                            Else
                                MsgInfo("Credito " + cReg + ".", "Fiscal")
                            EndIf
                        Else
                            // Sem aliquota vigente a NCM tributa a zero (docs/02, sec. 3):
                            // antes nao havia como cadastrar aliquota pela tela.
                            cCod := FWGetText("NCM:", "")
                            cOri := FWGetText("IBS % (ex.: 10):", "")
                            cTip := FWGetText("CBS % (ex.: 5):", "")
                            cComp := FWGetText("Vigencia inicio AAAAMMDD:", DToS(Date()))
                            cReg := FWGetText("Vigencia fim AAAAMMDD:", "20991231")
                            aRes := GEBRESTALISC(cUsu, {cCod, cOri, cTip, cComp, cReg})
                            If Left(cValToChar(aRes[1]), 1) == "2"
                                MsgInfo("Aliquota da NCM " + cCod + " cadastrada.", "Fiscal")
                            Else
                                MsgStop("Aliquota recusada: " + GEBTUIMOTIVO(aRes), "Fiscal")
                            EndIf
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf
    EndDo
Return .T.

/*/{Protheus.doc} GEBTUISN
    Submenu Simples Nacional (Fiscal > Simples Nacional): cadastros,
    apuracao e relatorios (extrato e anual, em grade via GSN6). Mesma
    permissao da API /fiscal/simples/* (FISCAL/APURA). Regras em GEBSN.prw.
    @type Tela
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBTUISN(cUsu)
    Local aOps := {"icon:gear|Configurar anexo padrao", "icon:plus|Atividade (codigo e anexo)", "icon:plus|Produto: atividade, ST, monofasico", ;
        "icon:plus|Nota de exportacao", "icon:plus|Folha e receita externa do mes", "icon:plus|Feriado (municipal/estadual)", ;
        "icon:check-circle|Apurar mes (DAS)", "icon:clipboard|Relatorio: extrato da apuracao", "icon:clipboard|Relatorio: acompanhamento anual", ;
        "icon:clipboard|Apuracoes", "icon:clipboard|Atividades", "icon:arrow-left|< Voltar"}
    Local nOp := 0
    Local cComp := ""
    Local cAux := ""
    Local cAux2 := ""
    Local cAux3 := ""
    Local aRes := {}
    Local aSN := {}
    Do While .T.
        nOp := FWMenuSelect(aOps, "Simples Nacional:")
        If nOp == Nil .Or. nOp <= 0 .Or. nOp == 12
            Exit
        EndIf
        aSN := {}
        If nOp == 1
            cAux := FWGetText("Anexo padrao (I, II, III, IV, V ou FR = Fator R):", Upper(AllTrim(GEBCFG("SN_ANEXO"))))
            cComp := FWGetText("Inicio de atividade AAAAMM (vazio se tem mais de 12 meses):", AllTrim(GEBCFG("SN_INICIO")))
            aSN := GEBSNCFG(cAux, cComp)
        ElseIf nOp == 2
            cAux := FWGetText("Codigo da atividade (ate 10 caracteres):", "")
            cAux2 := FWGetText("Descricao:", "")
            aSN := GEBSNATV(cAux, cAux2, FWGetText("Anexo (I, II, III, IV, V ou FR):", ""))
        ElseIf nOp == 3
            cAux := FWGetText("Produto (codigo):", "")
            cAux2 := FWGetText("Atividade (vazio = anexo padrao):", "")
            cAux3 := FWGetText("ICMS por substituicao tributaria? S/N:", "N")
            aSN := GEBSNPRD(cAux, cAux2, cAux3, FWGetText("PIS/COFINS monofasico? S/N:", "N"))
        ElseIf nOp == 4
            cAux := FWGetText("Chave da nota:", "")
            aSN := GEBSNEXP(cAux, FWGetText("Exportacao? S/N:", "S"))
        ElseIf nOp == 5
            cComp := FWGetText("Competencia AAAAMM:", "")
            cAux := FWGetText("Folha do mes (salarios + pro-labore + encargos; 0 se for so' receita de atividade):", "0")
            cAux2 := FWGetText("Receita do mes fora do GEBAN:", "0")
            aSN := GEBSNFOL(cComp, Val(cAux), Val(cAux2), FWGetText("Atividade da receita (vazio = anexo padrao):", ""))
        ElseIf nOp == 6
            cAux := FWGetText("Data do feriado AAAAMMDD:", "")
            aSN := GEBSNFER(cAux, FWGetText("Descricao:", ""))
        ElseIf nOp == 7
            cComp := FWGetText("Competencia AAAAMM:", "")
            aRes := GEBSNAPU(cComp)
            If aRes[1]
                cAux := "Anexo " + aRes[3][1] + ", faixa " + cValToChar(aRes[3][3]) + ;
                    " | RBT12: " + AllTrim(Str(aRes[3][2], 20, 2)) + ;
                    " | Aliquota efetiva: " + AllTrim(Str(aRes[3][4], 20, 4)) + "%" + ;
                    " | DAS: " + AllTrim(Str(aRes[3][5], 20, 2)) + " vence " + ;
                    Right(aRes[3][6], 2) + "/" + SubStr(aRes[3][6], 5, 2) + "/" + Left(aRes[3][6], 4) + " (contas a pagar DAS-" + cComp + ")"
                If !(aRes[3][7] == "")
                    cAux := cAux + " | ATENCAO: " + aRes[3][7]
                EndIf
                MsgInfo(cAux, "Simples Nacional")
            Else
                MsgStop("Apuracao recusada: " + aRes[2], "Simples Nacional")
            EndIf
        ElseIf nOp == 8 .Or. nOp == 9
            If nOp == 8
                aRes := GEBSNEXTRATO(FWGetText("Competencia AAAAMM:", ""))
            Else
                aRes := GEBSNANUAL(FWGetText("Ano AAAA:", Left(DToS(Date()), 4)))
            EndIf
            If aRes[1]
                GEBTUIBRW("GSN6", aOps[nOp])
            Else
                MsgStop("Relatorio recusado: " + aRes[2], "Simples Nacional")
            EndIf
        ElseIf nOp == 10
            GEBSNMIG()
            GEBTUIBRW("GSN2", "Apuracoes do Simples Nacional")
        Else
            GEBSNMIG()
            GEBTUIBRW("GSN3", "Atividades do Simples Nacional")
        EndIf
        If Len(aSN) >= 2
            If aSN[1]
                MsgInfo(aSN[2], "Simples Nacional")
            Else
                MsgStop("Recusado: " + aSN[2], "Simples Nacional")
            EndIf
        EndIf
    EndDo
Return .T.

/*/{Protheus.doc} GEBTUIFIN
    Tela do modulo Financeiro (browse + operacoes).
    @type Tela
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBTUIFIN(cEmp, cFil, cUsu)
    Local aOps := {"icon:clipboard|Contas", "icon:plus|+ Nova conta", "icon:check-circle|Baixar titulo", "icon:gear|Financeiro avancado (titulos, baixas, relatorios)", "icon:arrow-left|< Voltar"}
    Local nOp := 0
    Local aRes := {}
    Local cConta := ""
    Local cNome := ""
    Local cTipo := ""
    Local cDoc := ""
    Local nValor := 0
    Do While .T.
        nOp := FWMenuSelect(aOps, "Financeiro:")
        If nOp == Nil
            Exit
        EndIf
        If nOp <= 0 .Or. nOp == 5
            Exit
        EndIf
        If nOp == 4
            GEBTUIBOFIN(cUsu)
            Loop
        EndIf
        If nOp == 1
            GEBTUIBRW("GFN1", "Contas")
        Else
            If nOp == 2
                cConta := FWGetText("Conta:", "")
                cNome := FWGetText("Nome:", "")
                aRes := GEBRESTFINCON(cUsu, {cConta, cNome})
                If aRes[1] == "201"
                    MsgInfo("Conta criada.", "Financeiro")
                Else
                    MsgStop("Conta recusada: " + GEBTUIMOTIVO(aRes), "Financeiro")
                EndIf
            Else
                cTipo := FWGetText("Tipo PAGAR/RECEBER:", "")
                cDoc := FWGetText("Documento:", "")
                nValor := Val(FWGetText("Valor:", ""))
                aRes := GEBRESTFINBAI(cUsu, {cTipo, cDoc, nValor})
                If aRes[1] == "200"
                    MsgInfo("Titulo baixado.", "Financeiro")
                Else
                    MsgStop("Baixa recusada: " + GEBTUIMOTIVO(aRes), "Financeiro")
                EndIf
            EndIf
        EndIf
    EndDo
Return .T.

/*/{Protheus.doc} GEBTUIDER
    Tela do modulo Derrama (browse + operacoes).
    @type Tela
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBTUIDER(cEmp, cFil, cUsu)
    Local aOps := {"icon:clipboard|Guias", "icon:plus|+ Gerar guia", "icon:check-circle|Baixar guia", "icon:check-circle|Parcelar guia", "icon:chart-bar|Calcular juros", "icon:check-circle|Protestar guia", "icon:arrow-left|< Voltar"}
    Local nOp := 0
    Local aRes := {}
    Local cComp := ""
    Local cGuia := ""
    Local nParc := 0
    Local nDias := 0
    Do While .T.
        nOp := FWMenuSelect(aOps, "Derrama:")
        If nOp == Nil
            Exit
        EndIf
        If nOp <= 0 .Or. nOp == 7
            Exit
        EndIf
        If nOp == 1
            GEBTUIBRW("GD1", "Guias")
        Else
            If nOp == 2
                cComp := FWGetText("Competencia AAAAMM:", "")
                aRes := GEBRESTDERGER(cUsu, {cComp})
                If aRes[1] == "201"
                    MsgInfo("Guia gerada.", "Derrama")
                Else
                    MsgStop("Geracao recusada: " + GEBTUIMOTIVO(aRes), "Derrama")
                EndIf
            Else
                If nOp == 3
                    cGuia := FWGetText("Guia:", "")
                    aRes := GEBRESTDERBAI(cUsu, {cGuia})
                    If aRes[1] == "200"
                        MsgInfo("Guia baixada.", "Derrama")
                    Else
                        MsgStop("Baixa recusada: " + GEBTUIMOTIVO(aRes), "Derrama")
                    EndIf
                Else
                    If nOp == 4
                        cGuia := FWGetText("Guia:", "")
                        nParc := Val(FWGetText("Parcelas:", ""))
                        aRes := GEBRESTDERPAR(cUsu, {cGuia, nParc})
                        If aRes[1] == "200"
                            MsgInfo("Guia parcelada.", "Derrama")
                        Else
                            MsgStop("Parcelamento recusado: " + GEBTUIMOTIVO(aRes), "Derrama")
                        EndIf
                    Else
                        If nOp == 5
                            cGuia := FWGetText("Guia:", "")
                            nDias := Val(FWGetText("Dias:", ""))
                            aRes := GEBRESTDERJUR(cUsu, {cGuia, nDias})
                            If aRes[1] == "200"
                                MsgInfo("Juros calculados.", "Derrama")
                            Else
                                MsgStop("Calculo recusado: " + GEBTUIMOTIVO(aRes), "Derrama")
                            EndIf
                        Else
                            cGuia := FWGetText("Guia:", "")
                            aRes := GEBRESTDERPRO(cUsu, {cGuia})
                            If aRes[1] == "200"
                                MsgInfo("Guia protestada.", "Derrama")
                            Else
                                MsgStop("Protesto recusado: " + GEBTUIMOTIVO(aRes), "Derrama")
                            EndIf
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf
    EndDo
Return .T.

/*/{Protheus.doc} GEBTUIEST
    Tela do modulo Estoque (browse + operacoes).
    @type Tela
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBTUIEST(cEmp, cFil, cUsu)
    Local aOps := {"icon:clipboard|Saldos", "icon:clipboard|Vendas", "icon:check-circle|Vender", "icon:check-circle|Vender fiado", "icon:chart-bar|Juros fiado", "icon:gear|Estoque avancado (custo, inventario, kardex)", "icon:arrow-left|< Voltar"}
    Local nOp := 0
    Local aRes := {}
    Local cVenda := ""
    Local cProd := ""
    Local nQtd := 0
    Local nPre := 0
    Local cCli := ""
    Local nVal := 0
    Local nDias := 0
    Do While .T.
        nOp := FWMenuSelect(aOps, "Estoque:")
        If nOp == Nil
            Exit
        EndIf
        If nOp <= 0 .Or. nOp == 7
            Exit
        EndIf
        If nOp == 6
            GEBTUIBOEST(cUsu)
            Loop
        EndIf
        If nOp == 1
            GEBTUIBRW("GV1", "Saldos")
        Else
            If nOp == 2
                GEBTUIBRW("GV2", "Vendas")
            Else
                If nOp == 3
                    cVenda := FWGetText("Venda:", "")
                    cProd := FWGetText("Produto:", "")
                    nQtd := Val(FWGetText("Quantidade:", ""))
                    nPre := Val(FWGetText("Preco:", ""))
                    aRes := GEBRESTESTVEN(cUsu, {cVenda, cProd, nQtd, nPre})
                    If aRes[1] == "201"
                        MsgInfo("Venda registrada.", "Estoque")
                    Else
                        MsgStop("Venda recusada: " + GEBTUIMOTIVO(aRes), "Estoque")
                    EndIf
                Else
                    If nOp == 4
                        cCli := FWGetText("Cliente:", "")
                        nVal := Val(FWGetText("Valor:", ""))
                        aRes := GEBRESTESTFIA(cUsu, {cCli, nVal})
                        If aRes[1] == "201"
                            MsgInfo("Fiado registrado.", "Estoque")
                        Else
                            MsgStop("Fiado recusado: " + GEBTUIMOTIVO(aRes), "Estoque")
                        EndIf
                    Else
                        cCli := FWGetText("Cliente:", "")
                        nDias := Val(FWGetText("Dias:", ""))
                        aRes := GEBRESTESTFIJ(cUsu, {cCli, nDias})
                        If aRes[1] == "200"
                            MsgInfo("Juros calculados.", "Estoque")
                        Else
                            MsgStop("Calculo recusado: " + GEBTUIMOTIVO(aRes), "Estoque")
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf
    EndDo
Return .T.

/*/{Protheus.doc} GEBTUICTB
    Tela do modulo Contabil (browse + operacoes).
    @type Tela
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBTUICTB(cEmp, cFil, cUsu)
    Local aOps := {"icon:clipboard|Plano", "icon:clipboard|Lancamentos", "icon:check-circle|Lancar", "icon:chart-bar|Ver balancete", "icon:chart-bar|Ver DRE", "icon:gear|Contabil avancado (razao, balancete, DRE)", "icon:arrow-left|< Voltar"}
    Local nOp := 0
    Local aRes := {}
    Local cDeb := ""
    Local cCred := ""
    Local nVal := 0
    Local cComp := ""
    Do While .T.
        nOp := FWMenuSelect(aOps, "Contabil:")
        If nOp == Nil
            Exit
        EndIf
        If nOp <= 0 .Or. nOp == 7
            Exit
        EndIf
        If nOp == 6
            GEBTUIBOCTB(cUsu)
            Loop
        EndIf
        If nOp == 1
            GEBTUIBRW("GC1", "Plano de contas")
        Else
            If nOp == 2
                GEBTUIBRW("GC2", "Lancamentos")
            Else
                If nOp == 3
                    cDeb := FWGetText("Debito:", "")
                    cCred := FWGetText("Credito:", "")
                    nVal := Val(FWGetText("Valor:", ""))
                    aRes := GEBRESTCTBDIR(cUsu, {cDeb, cCred, nVal})
                    If aRes[1] == "201"
                        MsgInfo("Lancamento gravado.", "Contabil")
                    Else
                        MsgStop("Lancamento recusado: " + GEBTUIMOTIVO(aRes), "Contabil")
                    EndIf
                Else
                    cComp := FWGetText("Competencia AAAAMM:", "")
                    If nOp == 4
                        aRes := GEBRESTCTBBAL(cUsu, cComp)
                    Else
                        aRes := GEBRESTCTBDRE(cUsu, cComp)
                    EndIf
                    If aRes[1] == "200"
                        MsgInfo("Relatorio gerado.", "Contabil")
                    Else
                        MsgStop("Relatorio recusado: " + GEBTUIMOTIVO(aRes), "Contabil")
                    EndIf
                EndIf
            EndIf
        EndIf
    EndDo
Return .T.

/*/{Protheus.doc} GEBTUICOM
    Tela do modulo Compras (browse + operacoes).
    @type Tela
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBTUICOM(cEmp, cFil, cUsu)
    Local aOps := {"icon:clipboard|Fornecedores", "icon:clipboard|Pedidos", "icon:plus|+ Novo fornecedor", "icon:check-circle|Abrir pedido", "icon:check-circle|Adicionar item", "icon:check-circle|Dar entrada", "icon:gear|Compras avancado (solicitacao, alcada, entrada)", "icon:arrow-left|< Voltar"}
    Local nOp := 0
    Local aRes := {}
    Local cCod := ""
    Local cNome := ""
    Local cPed := ""
    Local cForn := ""
    Local cProd := ""
    Local nQtd := 0
    Local nPre := 0
    Local cNF := ""
    Do While .T.
        nOp := FWMenuSelect(aOps, "Compras:")
        If nOp == Nil
            Exit
        EndIf
        If nOp <= 0 .Or. nOp == 8
            Exit
        EndIf
        If nOp == 7
            GEBTUIBOCOM(cUsu)
            Loop
        EndIf
        If nOp == 1
            GEBTUIBRW("GCP1", "Fornecedores")
        Else
            If nOp == 2
                GEBTUIBRW("GCP3", "Pedidos")
            Else
                If nOp == 3
                    cCod := FWGetText("Codigo:", "")
                    cNome := FWGetText("Nome:", "")
                    aRes := GEBRESTCOMFOR(cUsu, {cCod, cNome})
                    If aRes[1] == "201"
                        MsgInfo("Fornecedor criado.", "Compras")
                    Else
                        MsgStop("Cadastro recusado: " + GEBTUIMOTIVO(aRes), "Compras")
                    EndIf
                Else
                    If nOp == 4
                        cPed := FWGetText("Pedido:", "")
                        cForn := FWGetText("Fornecedor:", "")
                        aRes := GEBRESTCOMPED(cUsu, {cPed, cForn})
                        If aRes[1] == "201"
                            MsgInfo("Pedido aberto.", "Compras")
                        Else
                            MsgStop("Pedido recusado: " + GEBTUIMOTIVO(aRes), "Compras")
                        EndIf
                    Else
                        If nOp == 5
                            cPed := FWGetText("Pedido:", "")
                            cProd := FWGetText("Produto:", "")
                            nQtd := Val(FWGetText("Quantidade:", ""))
                            nPre := Val(FWGetText("Preco:", ""))
                            aRes := GEBRESTCOMIT(cUsu, {cPed, cProd, nQtd, nPre})
                            If aRes[1] == "201"
                                MsgInfo("Item adicionado.", "Compras")
                            Else
                                MsgStop("Item recusado: " + GEBTUIMOTIVO(aRes), "Compras")
                            EndIf
                        Else
                            cNF := FWGetText("NF:", "")
                            cPed := FWGetText("Pedido:", "")
                            aRes := GEBRESTCOMENT(cUsu, {cNF, cPed})
                            If aRes[1] == "201"
                                MsgInfo("Entrada registrada.", "Compras")
                            Else
                                MsgStop("Entrada recusada: " + GEBTUIMOTIVO(aRes), "Compras")
                            EndIf
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf
    EndDo
Return .T.

/*/{Protheus.doc} GEBTUINUC
    Tela do modulo Nucleo em ordem de cascata: empresas, unidades,
    filiais, usuarios, criacoes, vinculo e troca de senha (browse + cadastros).
    @type Tela
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBTUINUC(cEmp, cFil, cUsu)
    Local aOps := {"icon:clipboard|Empresas", "icon:buildings|Unidades", "icon:clipboard|Filiais", "icon:users|Usuarios", "icon:plus|+ Nova empresa", "icon:plus|+ Nova unidade", "icon:plus|+ Nova filial", "icon:plus|+ Novo usuario", "icon:users|Vincular usuario", "icon:key|Trocar senha", "icon:lock|Permissoes (super)", "icon:user-check|Ciclo do usuario", "icon:clock|Agendamentos", "icon:arrow-left|< Voltar"}
    Local nOp := 0
    Local aRes := {}
    Local cCod := ""
    Local cNome := ""
    Local cPerfil := ""
    Local cSenha := ""
    Local cEmps := ""
    Local cFilN := ""
    Local cAlvo := ""
    Local lOk := .F.
    Local aPol := {}
    Local aUsr := {}
    Local cSen2 := ""
    Local cAtuNome := ""
    Local cAtuPerfil := ""
    Local aPf := {}
    Local lSemVinc := .F.
    // Nucleo e' administracao: so' ADMIN da empresa ou super. Os demais
    // so' trocam a propria senha.
    If !GEBSECPODE(cUsu, "", .F.)
        cSenha := FWGetText("Nucleo e' restrito a administradores. Nova senha para " + cUsu + " (vazio = voltar):", "", .T.)
        If !Empty(cSenha)
            If cSenha != FWGetText("Confirme a senha:", "", .T.)
                MsgStop("Senhas diferentes.", "Nucleo")
            Else
                aRes := GEBTUITROCASENHA(cUsu, "", cSenha, "", "")
                If aRes[1]
                    MsgInfo("Senha alterada.", "Nucleo")
                Else
                    MsgStop("Troca recusada: " + cValToChar(aRes[2]), "Nucleo")
                EndIf
            EndIf
        EndIf
        Return .T.
    EndIf
    Do While .T.
        nOp := FWMenuSelect(aOps, "Nucleo:")
        If nOp == Nil
            Exit
        EndIf
        If nOp <= 0 .Or. nOp == 14
            Exit
        EndIf
        If nOp == 11
            GEBTUIPERMS(cUsu)
            Loop
        EndIf
        If nOp == 12
            GEBTUICICLO(cUsu)
            Loop
        EndIf
        If nOp == 13
            GEBTUIAGENDA(cUsu)
            Loop
        EndIf
        If nOp == 1
            GEBTUIBRW("GE1", "Empresas")
        Else
            If nOp == 2
                GEBTUIBRW("GEU1", "Unidades")
            Else
                If nOp == 3
                    GEBTUIBRW("GEF1", "Filiais")
                Else
                    If nOp == 4
                        GEBTUIBRW("GE2", "Usuarios")
                    Else
                        If nOp == 5
                            cCod := FWGetText("Codigo:", "")
                            cNome := FWGetText("Nome:", "")
                            aRes := GEBRESTEMPLSC(cUsu, {cCod, cNome})
                            If aRes[1] == "201"
                                MsgInfo("Empresa criada.", "Nucleo")
                            Else
                                MsgStop("Criacao recusada: " + GEBTUIMOTIVO(aRes), "Nucleo")
                            EndIf
                        Else
                            If nOp == 6
                                cCod := FWGetText("Codigo UU (2 digitos):", "")
                                cNome := FWGetText("Nome:", "")
                                aRes := GEBRESTUNILSC(cUsu, {cCod, cNome})
                                If aRes[1] == "201"
                                    MsgInfo("Unidade criada.", "Nucleo")
                                Else
                                    MsgStop("Criacao recusada: " + GEBTUIMOTIVO(aRes), "Nucleo")
                                EndIf
                            Else
                                If nOp == 7
                                    cCod := FWGetText("Codigo EEUUFF:", "")
                                    cNome := FWGetText("Nome:", "")
                                    aRes := GEBRESTFILSC(cUsu, {cCod, cNome})
                                    If aRes[1] == "201"
                                        MsgInfo("Filial criada.", "Nucleo")
                                    Else
                                        MsgStop("Criacao recusada: " + GEBTUIMOTIVO(aRes), "Nucleo")
                                    EndIf
                                Else
                                    If nOp == 8
                                        cCod := FWGetText("Codigo (letras, numeros e _ ; sem ponto/espaco):", "")
                                        cNome := FWGetText("Nome:", "")
                                        cPerfil := FWGetText("Perfil:", "USUARIO")
                                        cSenha := FWGetText("Senha (min 8, maiuscula, minuscula, numero e simbolo; sem 123/abc):", "", .T.)
                                        cEmps := FWGetText("Empresas (codigo):", cEmp)
                                        cFilN := FWGetText("Filial (vazio=matriz):", "")
                                        aRes := GEBRESTURLSC(cUsu, {cCod, cNome, cPerfil, cSenha, cEmps, cFilN})
                                        If aRes[1] == "201"
                                            MsgInfo("Usuario criado.", "Nucleo")
                                        Else
                                            MsgStop("Criacao recusada: " + GEBTUIMOTIVO(aRes), "Nucleo")
                                        EndIf
                                    Else
                                        If nOp == 9
                                            cAlvo := FWGetText("Usuario:", "")
                                            cEmps := FWGetText("Empresa:", cEmp)
                                            cFilN := FWGetText("Filial (vazio=matriz):", "")
                                            aRes := GEBRESTVINCSC(cUsu, {cAlvo, cEmps, cFilN})
                                            If aRes[1] == "201"
                                                MsgInfo("Usuario vinculado.", "Nucleo")
                                            Else
                                                MsgStop("Vinculo recusado: " + GEBTUIMOTIVO(aRes), "Nucleo")
                                            EndIf
                                        Else
                                            cAlvo := FWGetText("Usuario (vazio=voce):", "")
                                            cSenha := FWGetText("Nova senha (vazio=mantem):", "", .T.)
                                            cSen2 := ""
                                            If !Empty(cSenha)
                                                cSen2 := FWGetText("Confirme a senha:", "", .T.)
                                            EndIf
                                            If !Empty(cSenha)
                                                If cSenha != cSen2
                                                    MsgStop("Senhas diferentes.", "Nucleo")
                                                    cSenha := Nil
                                                    cSen2 := Nil
                                                EndIf
                                            EndIf
                                            If cSenha != Nil
                                                cNome := FWGetText("Nome (vazio=mantem):", "")
                                                cPerfil := FWGetText("Perfil (vazio=mantem):", "")
                                                aRes := GEBTUITROCASENHA(cUsu, cAlvo, cSenha, cNome, cPerfil)
                                                If aRes[1]
                                                    MsgInfo("Usuario atualizado.", "Nucleo")
                                                Else
                                                    If cValToChar(aRes[2]) == "nada_a_alterar"
                                                        MsgInfo("Nada a alterar.", "Nucleo")
                                                    Else
                                                        If cValToChar(aRes[2]) == "somente_super"
                                                            MsgStop("Somente o super altera a conta super.", "Nucleo")
                                                        Else
                                                            If cValToChar(aRes[2]) == "usuario_inexistente"
                                                                MsgStop("Usuario inexistente.", "Nucleo")
                                                            Else
                                                                MsgStop("Operacao recusada: " + cValToChar(aRes[2]), "Nucleo")
                                                            EndIf
                                                        EndIf
                                                    EndIf
                                                EndIf
                                            EndIf
                                        EndIf
                                EndIf
                                EndIf
                            EndIf
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf
    EndDo
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
        aUsr := TCSqlQuery("SELECT GE2_NOME, GE2_PERFIL FROM GE2 WHERE GE2_COD = " + GEBDBQuote(cAlvoL) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
        If Len(aUsr) == 0
            lOk := .F.
            cMsg := "usuario_inexistente"
        Else
            cAtuNome := cValToChar(aUsr[1]:GE2_NOME)
            // Perfil e' por empresa: le o vinculo da empresa da sessao.
            aPf := TCSqlQuery("SELECT UPPER(TRIM(GE2_EMP_PERFIL)) AS PERF FROM GE2_EMP WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cAlvoL) + " AND LOWER(TRIM(GE2_EMP_EMPRESA)) = " + GEBDBQuote(GEBDBTenantAtual()) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
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
                lOk := TCSqlExec("UPDATE GE2 SET GE2_NOME = '" + StrTran(AllTrim(cNomeL), "'", "''") + "' WHERE GE2_COD = " + GEBDBQuote(cAlvoL) + " AND D_E_L_E_T_ = ' '")
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
                    lOk := TCSqlExec("UPDATE GE2_EMP SET GE2_EMP_PERFIL = " + GEBDBQuote(Upper(AllTrim(cPerfilL))) + " WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cAlvoL) + " AND LOWER(TRIM(GE2_EMP_EMPRESA)) = " + GEBDBQuote(GEBDBTenantAtual()) + " AND D_E_L_E_T_ = ' '")
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
Static Function GEBTUIFISITEM(nOp)
    If nOp == 1 .Or. nOp == 3
        Return "PRODUT"
    EndIf
    If nOp == 2 .Or. nOp == 4
        Return "NOTAS"
    EndIf
Return "APURA"

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

// GEBTUIACAOOK -> checa um item e avisa na tela quando nega.
Static Function GEBTUIACAOOK(cUsu, cMenu, cItem)
    If GEBSECRBAC(cUsu, cMenu, cItem)
        Return .T.
    EndIf
    MsgStop("Sem permissao para " + cMenu + "/" + cItem + ". Peca ao super: Nucleo > Permissoes.", "GEBAN")
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

/*/{Protheus.doc} GEBTUIPERMS
    Tela Nucleo > Permissoes. Super: escolhe a empresa ou todas. ADMIN da empresa: so' a propria.
    @type Tela
    @author Peder Munksgaard
    @since 07/11/2026
/*/
User Function GEBTUIPERMS(cUsu)
    Local aAreas  := GEBTUIAREAS()
    Local aLbl    := {}
    Local aOps    := {"icon:eye|Ver permissoes de um perfil", "icon:check-circle|Conceder area", "icon:x-circle|Revogar area", "icon:arrow-left|< Voltar"}
    Local nOp     := 0
    Local nArea   := 0
    Local nEsc    := 0
    Local cEmpT   := Lower(AllTrim(cValToChar(GEBDBTenantAtual())))
    Local cEmpS   := ""
    Local cPerfil := ""
    Local aLst    := {}
    Local cTxt    := ""
    Local aRes    := {}
    Local nI      := 0

    If !GEBSECPODE(cUsu, "", .F.)
        MsgStop("So o ADMIN da empresa ou o super alteram permissoes.", "Nucleo")
        Return .F.
    EndIf
    For nI := 1 To Len(aAreas)
        AAdd(aLbl, aAreas[nI][3])
    Next nI

    cEmpS := cEmpT
    If GEBSECISSUPER(cUsu)
        nEsc := FWMenuSelect({"icon:buildings|Esta empresa (" + cEmpT + ")", "icon:globe|Todas as empresas (*)"}, "Escopo das permissoes:")
        If nEsc == Nil .Or. nEsc <= 0
            Return .T.
        EndIf
        If nEsc == 2
            cEmpS := "*"
        EndIf
    EndIf

    Do While .T.
        nOp := FWMenuSelect(aOps, "Permissoes (" + cEmpS + "):")
        If nOp == Nil .Or. nOp <= 0 .Or. nOp == 4
            Exit
        EndIf
        cPerfil := Upper(AllTrim(cValToChar(FWGetText("Perfil (ex.: USUARIO, OPERADOR):", ""))))
        If cPerfil == ""
            Loop
        EndIf
        If nOp == 1
            aLst := GEBSECRBACLISTEMP(cPerfil, cEmpS)
            cTxt := ""
            For nI := 1 To Len(aLst)
                cTxt := cTxt + cValToChar(aLst[nI][1]) + "/" + cValToChar(aLst[nI][2]) + ": "
                If aLst[nI][3]
                    cTxt := cTxt + "permitido"
                Else
                    cTxt := cTxt + "negado"
                EndIf
                cTxt := cTxt + " (" + cValToChar(aLst[nI][4]) + ")" + Chr(10)
            Next nI
            If cTxt == ""
                cTxt := "Nenhuma permissao: o perfil nao entra em nenhum modulo nesta escolha."
            EndIf
            MsgInfo(cTxt, "Perfil " + cPerfil)
        Else
            nArea := FWMenuSelect(aLbl, "Area:")
            If nArea == Nil .Or. nArea <= 0 .Or. nArea > Len(aAreas)
                Loop
            EndIf
            aRes := GEBTUIPERMSETEMP(cUsu, cEmpS, cPerfil, aAreas[nArea][1], aAreas[nArea][2], (nOp == 2))
            If aRes[1]
                If nOp == 2
                    MsgInfo(aAreas[nArea][3] + " concedido a " + cPerfil + " em " + cEmpS + ".", "Nucleo")
                Else
                    MsgInfo(aAreas[nArea][3] + " revogado de " + cPerfil + " em " + cEmpS + ".", "Nucleo")
                EndIf
            Else
                MsgStop("Recusado: " + cValToChar(aRes[2]), "Nucleo")
            EndIf
        EndIf
    EndDo
Return .T.

/*/{Protheus.doc} GEBTUICICLO
    Nucleo > Ciclo do usuario: bloquear, validade, eliminar acessos, excluir, troca obrigatoria
    e conta de servico. Regras em src/GEBSEC_CICLO.prw (super tudo; ADMIN so' os da propria empresa).
    @type Tela
    @since 07/11/2026
/*/
Static Function GEBTUICICLO(cUsu)
    Local aOps  := {"icon:lock|Bloquear usuario (super)", "icon:unlock|Desbloquear usuario (super)", "icon:calendar|Validade do acesso (super)", "icon:user-minus|Eliminar acessos", "icon:trash|Excluir usuario que nunca acessou (super)", "icon:refresh|Forcar troca de senha no proximo logon", "icon:clock|Conta de servico: ignorar troca periodica (super)", "icon:arrow-left|< Voltar"}
    Local nOp   := 0
    Local cAlvo := ""
    Local cData := ""
    Local cLig  := ""
    Local aRes  := {}
    Do While .T.
        nOp := FWMenuSelect(aOps, "Ciclo do usuario:")
        If nOp == Nil .Or. nOp <= 0 .Or. nOp == 8
            Exit
        EndIf
        cAlvo := AllTrim(FWGetText("Usuario:", ""))
        If cAlvo == ""
            Loop
        EndIf
        If nOp == 1
            aRes := GEBSECBLOQUEIA(cUsu, cAlvo, .T.)
        ElseIf nOp == 2
            aRes := GEBSECBLOQUEIA(cUsu, cAlvo, .F.)
        ElseIf nOp == 3
            cData := AllTrim(FWGetText("Validade AAAAMMDD (vazio = sem validade):", ""))
            aRes := GEBSECVALIDADE(cUsu, cAlvo, cData)
        ElseIf nOp == 4
            aRes := GEBSECELIMINAACESSOS(cUsu, cAlvo)
        ElseIf nOp == 5
            aRes := GEBSECEXCLUI(cUsu, cAlvo)
        ElseIf nOp == 6
            aRes := GEBSECFORCATROCA(cUsu, cAlvo, .T.)
        Else
            cLig := Upper(AllTrim(FWGetText("Ignorar troca periodica? S/N:", "S")))
            aRes := GEBSECIGNORAEXP(cUsu, cAlvo, (cLig == "S"))
        EndIf
        If aRes[1]
            MsgInfo("Feito: " + cAlvo, "Nucleo")
        Else
            MsgStop("Recusado: " + cValToChar(aRes[2]), "Nucleo")
        EndIf
    EndDo
Return .T.

/*/{Protheus.doc} GEBTUIAGENDA
    Nucleo > Agendamentos: agendar, alterar, desativar e listar rotinas da empresa (src/GEBSCH.prw).
    @type Tela
    @since 07/11/2026
/*/
Static Function GEBTUIAGENDA(cUsu)
    Local aOps  := {"icon:plus|Agendar ou alterar rotina", "icon:x-circle|Desativar rotina", "icon:list|Ver agendamentos", "icon:info|Rotinas disponiveis", "icon:arrow-left|< Voltar"}
    Local nOp   := 0
    Local cRot  := ""
    Local cHora := ""
    Local cDia  := ""
    Local aL    := {}
    Local aJ    := {}
    Local cTxt  := ""
    Local aRes  := {}
    Local nI    := 0
    Do While .T.
        nOp := FWMenuSelect(aOps, "Agendamentos:")
        If nOp == Nil .Or. nOp <= 0 .Or. nOp == 5
            Exit
        EndIf
        If nOp == 1
            cRot := AllTrim(FWGetText("Rotina (DFE_DIST ou SN_APU):", ""))
            cHora := AllTrim(FWGetText("Horario HHMM (ex.: 0230):", "0230"))
            cDia := AllTrim(FWGetText("Dia: D (diario) ou M01..M28 (dia do mes):", "D"))
            aRes := GEBSCHAGENDA(cUsu, cRot, cHora, Upper(cDia), "S")
            If aRes[1]
                MsgInfo("Agendamento salvo: " + cRot + " " + cHora + " " + Upper(cDia), "Agendamentos")
            Else
                MsgStop("Recusado: " + cValToChar(aRes[2]), "Agendamentos")
            EndIf
        ElseIf nOp == 2
            cRot := AllTrim(FWGetText("Rotina a desativar:", ""))
            aRes := GEBSCHDESATIVA(cUsu, cRot)
            If !aRes[1]
                MsgStop("Recusado: " + cValToChar(aRes[2]), "Agendamentos")
            EndIf
        ElseIf nOp == 3
            aJ := TCSqlQuery("SELECT SCH_ROTINA, SCH_HORA, SCH_DIA, SCH_ATIVO, SCH_ULTEXEC, SCH_STATUS FROM SCH_JOB WHERE D_E_L_E_T_ = ' ' ORDER BY SCH_ROTINA")
            cTxt := ""
            For nI := 1 To Len(aJ)
                cTxt := cTxt + AllTrim(cValToChar(aJ[nI]:SCH_ROTINA)) + " " + AllTrim(cValToChar(aJ[nI]:SCH_HORA)) + " " + AllTrim(cValToChar(aJ[nI]:SCH_DIA)) + " ativo=" + AllTrim(cValToChar(aJ[nI]:SCH_ATIVO)) + " ultima=" + AllTrim(cValToChar(aJ[nI]:SCH_ULTEXEC)) + " " + AllTrim(cValToChar(aJ[nI]:SCH_STATUS)) + Chr(10)
            Next nI
            If cTxt == ""
                cTxt := "Nenhum agendamento nesta empresa."
            EndIf
            MsgInfo(cTxt, "Agendamentos")
        Else
            aL := GEBSCHROTINAS()
            cTxt := ""
            For nI := 1 To Len(aL)
                cTxt := cTxt + aL[nI][1] + ": " + aL[nI][2] + Chr(10)
            Next nI
            MsgInfo(cTxt, "Rotinas disponiveis")
        EndIf
    EndDo
Return .T.
