#include "totvs.ch"

/*/{Protheus.doc} GEBEXP_REL_NUC
    Relatorios do nucleo multi-empresa GEB_EXPANSAO.
    Desenho multi-tenant (Fase 2): nao existe mais coluna EMPRESA em
    nenhuma tabela. Catalogo (schema public): GE1 (empresas), GE2
    (usuarios), GE2_EMP (vinculo usuario<->empresa). Dados por empresa
    (schema emp_<cod>): GE3, GE4, GEH, GF1, GCP1, GV3, GFN1, etc.
    Funcoes:
    - GEBRELEMPRESAS(): array {EMPRESA, NOME, NUSUARIOS, NREGRE} -- uma
      linha por empresa ativa em public.GE1 (todas, sem filtro pela
      empresa logada); NUSUARIOS vem de UMA agregacao em public.GE2_EMP
      (x public.GE2); NREGRE = linhas ativas de emp_<cod>.GE3.
    - GEBRELUSUARIOS(cEmpresa): array {COD, NOME, PERFIL} -- usuarios
      ativos de public.GE2 vinculados a cEmpresa em public.GE2_EMP.
    - GEBRELAUDITORIA(cEmpresa, cInicio, cFim): array
      {DATA, HORA, USUARIO, FUNCAO, IP} lido de emp_<cod>.GEH (historico
      de acesso), ordenado do mais recente para o mais antigo.
    - GEBRELMENTOR(cEmpresa): array {evento, modo} lido de GE4 do tenant
      corrente (search_path) -- inalterada aqui.
    - GEBRELCADASTROS(cEmpresa): array {{nProdutos, nFornecedores,
      nClientes, nContas}} contando emp_<cod>.GF1/GCP1/GV3/GFN1.
    cEmpresa vazio/Nil: usa o tenant corrente (current_schema() no
    formato emp_<cod>); se nao houver tenant selecionado, retorna {}.
    Leitura por-tenant usa nome de tabela qualificado pelo schema
    (emp_<cod>.TABELA) apos GEBDBSchemaExists() -- NAO troca search_path
    e NAO usa workarea: nenhum GetArea()/RestArea() atravessa troca de
    tenant (RESTAREA neste runtime re-seleciona a alias sob o search_path
    ativo no momento; DBCLOSEAREA e' no-op) e o search_path do chamador
    nunca e' alterado. Por isso estas funcoes tambem nao fazem
    GetArea()/RestArea(): nao abrem workarea nenhuma, e um RestArea() de
    uma alias herdada do chamador poderia re-consultar essa alias no
    schema errado.
    @type Modulo de relatorios
    @author Peder Munksgaard
    @since 23/09/2026
/*/
User Function GEBRELEMPRESAS()
    Local aRet := {}
    Local aEmp := {}
    Local aUsu := {}
    Local aCnt := {}
    Local oRow := Nil
    Local cCod := ""
    Local nUsu := 0
    Local nReg := 0
    Local nIdx := 0
    Local nPos := 0

    // 1. Todas as empresas ativas do catalogo (GE1 nao tem coluna
    // EMPRESA -- ela E' a lista de empresas; o antigo filtro pela empresa
    // logada era resquicio do desenho pre-multi-tenant).
    aEmp := TCSqlQuery("SELECT GE1_COD, GE1_NOME FROM public.GE1 WHERE D_E_L_E_T_ = ' ' ORDER BY GE1_COD")

    // 2. Usuarios por empresa: UMA agregacao no catalogo (GE2_EMP x GE2),
    // mesmo criterio de GEBRELUSUARIOS() (usuario ativo em GE2 na mesma
    // filial do vinculo).
    aUsu := TCSqlQuery("SELECT LOWER(E.GE2_EMP_EMPRESA) AS EMPCOD, COUNT(DISTINCT E.GE2_EMP_USUARIO) AS NCNT " + ;
        "FROM public.GE2_EMP E JOIN public.GE2 U ON U.GE2_COD = E.GE2_EMP_USUARIO " + ;
        "AND U.GE2_FILIAL = E.GE2_EMP_FILIAL AND U.D_E_L_E_T_ = ' ' " + ;
        "WHERE E.D_E_L_E_T_ = ' ' GROUP BY LOWER(E.GE2_EMP_EMPRESA)")

    For nIdx := 1 To Len(aEmp)
        oRow := aEmp[nIdx]
        cCod := AllTrim(cValToChar(oRow:GE1_COD))

        nUsu := 0
        For nPos := 1 To Len(aUsu)
            If AllTrim(cValToChar(aUsu[nPos]:EMPCOD)) == Lower(cCod)
                nUsu := Val(cValToChar(aUsu[nPos]:NCNT))
                Exit
            EndIf
        Next nPos

        // 3. GE3 e' por-tenant: conta direto em emp_<cod>.GE3 (sem trocar
        // search_path). Codigo fora do formato/sem schema -> 0, sem SQL.
        nReg := 0
        aCnt := RNContaTenant(cCod, "GE3")
        If Len(aCnt) > 0
            nReg := aCnt[1]
        EndIf

        AAdd(aRet, {cCod, AllTrim(cValToChar(oRow:GE1_NOME)), nUsu, nReg})
    Next nIdx
Return aRet

User Function GEBRELUSUARIOS(cEmpresa)
    Local aRet := {}
    Local aHit := {}
    Local oRow := Nil
    Local cEmp := ""
    Local nIdx := 0

    cEmp := RNEmpAlvo(cEmpresa)
    If cEmp == ""
        Return aRet
    EndIf

    // Pura consulta de catalogo: vinculo em GE2_EMP x cadastro em GE2.
    // cEmp ja validado por GEBDBSchemaValido() em RNEmpAlvo().
    aHit := TCSqlQuery("SELECT DISTINCT U.GE2_COD, U.GE2_NOME, U.GE2_PERFIL " + ;
        "FROM public.GE2_EMP E JOIN public.GE2 U ON U.GE2_COD = E.GE2_EMP_USUARIO " + ;
        "AND U.GE2_FILIAL = E.GE2_EMP_FILIAL AND U.D_E_L_E_T_ = ' ' " + ;
        "WHERE E.D_E_L_E_T_ = ' ' AND LOWER(E.GE2_EMP_EMPRESA) = " + GEBDBQuote(cEmp) + " " + ;
        "ORDER BY U.GE2_COD")
    For nIdx := 1 To Len(aHit)
        oRow := aHit[nIdx]
        AAdd(aRet, {AllTrim(cValToChar(oRow:GE2_COD)), AllTrim(cValToChar(oRow:GE2_NOME)), AllTrim(cValToChar(oRow:GE2_PERFIL))})
    Next nIdx
Return aRet

User Function GEBRELAUDITORIA(cEmpresa, cInicio, cFim)
    Local aRet := {}
    Local aHit := {}
    Local oRow := Nil
    Local cEmp := ""
    Local cSql := ""
    Local nIdx := 0

    cEmp := RNEmpAlvo(cEmpresa)
    If cEmp == ""
        Return aRet
    EndIf
    If ValType(cInicio) != "C"
        cInicio := ""
    EndIf
    If ValType(cFim) != "C"
        cFim := ""
    EndIf
    cInicio := AllTrim(cInicio)
    cFim := AllTrim(cFim)
    // Datas vao literais para o SQL: so' AAAAMMDD (8 digitos) ou vazio.
    If !RNDataValida(cInicio)
        Return aRet
    EndIf
    If !RNDataValida(cFim)
        Return aRet
    EndIf
    If !GEBDBSchemaExists(cEmp)
        Return aRet
    EndIf
    If !RNTabNoSchema(cEmp, "GEH")
        Return aRet
    EndIf

    // GEH e' por-tenant: o schema emp_<cod> ja isola a empresa. Nao
    // filtra por GEH_EMPRESA -- a coluna e' redundante e nao confiavel
    // (GEBSECLOGIN grava GEH_EMPRESA = '' pois autentica antes de saber
    // a empresa; GEBEXPCONTEXTO grava o codigo como recebido, sem
    // normalizar caixa), entao o filtro descartava auditoria legitima.
    cSql := "SELECT GEH_DATA, GEH_HORA, GEH_USUARIO, GEH_FUNCAO, GEH_IP FROM emp_" + cEmp + ".GEH WHERE D_E_L_E_T_ = ' '"
    If cInicio != ""
        cSql += " AND GEH_DATA >= " + GEBDBQuote(cInicio) + ""
    EndIf
    If cFim != ""
        cSql += " AND GEH_DATA <= " + GEBDBQuote(cFim) + ""
    EndIf
    cSql += " ORDER BY GEH_DATA DESC, GEH_HORA DESC"

    aHit := TCSqlQuery(cSql)
    For nIdx := 1 To Len(aHit)
        oRow := aHit[nIdx]
        AAdd(aRet, { ;
            AllTrim(cValToChar(oRow:GEH_DATA)), ;
            AllTrim(cValToChar(oRow:GEH_HORA)), ;
            AllTrim(cValToChar(oRow:GEH_USUARIO)), ;
            AllTrim(cValToChar(oRow:GEH_FUNCAO)), ;
            AllTrim(cValToChar(oRow:GEH_IP)) ;
        })
    Next nIdx
Return aRet

User Function GEBRELMENTOR(cEmpresa)
    Local aArea := GetArea()
    Local aRet := {}
    Local aCtx := {}
    Local cEmp := ""

    aCtx := GEBEXPCONTEXTO()
    If cEmpresa == Nil .Or. cEmpresa == ""
        If Len(aCtx) >= 3 .And. aCtx[1] != ""
            cEmp := aCtx[1]
        EndIf
    Else
        cEmp := cEmpresa
    EndIf

    // GE4 nao tem mais coluna EMPRESA (redesign multi-tenant): o schema
    // do tenant atual ja isola os eventos por empresa, entao toda linha
    // ativa de GE4 pertence a empresa selecionada -- sem filtro adicional.
    DbSelectArea("GE4")
    DbSetOrder(1)
    DbGoTop()
    While !Eof()
        If GE4->D_E_L_E_T_ == " "
            AAdd(aRet, {GE4->GE4_EVENTO, GE4->GE4_MODO})
        EndIf
        DbSkip()
    EndDo
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

User Function GEBRELCADASTROS(cEmpresa)
    Local aRet := {}
    Local aCnt := {}
    Local cEmp := ""
    Local nProd := 0
    Local nForn := 0
    Local nCli := 0
    Local nCont := 0

    cEmp := RNEmpAlvo(cEmpresa)
    If cEmp == ""
        Return aRet
    EndIf
    If !GEBDBSchemaExists(cEmp)
        Return aRet
    EndIf

    // Tabelas por-tenant: o proprio schema emp_<cod> e' o filtro.
    aCnt := RNContaTenant(cEmp, "GF1")
    If Len(aCnt) > 0
        nProd := aCnt[1]
    EndIf
    aCnt := RNContaTenant(cEmp, "GCP1")
    If Len(aCnt) > 0
        nForn := aCnt[1]
    EndIf
    aCnt := RNContaTenant(cEmp, "GV3")
    If Len(aCnt) > 0
        nCli := aCnt[1]
    EndIf
    aCnt := RNContaTenant(cEmp, "GFN1")
    If Len(aCnt) > 0
        nCont := aCnt[1]
    EndIf

    AAdd(aRet, {nProd, nForn, nCli, nCont})
Return aRet

// RNEmpAlvo(cEmpresa) -> codigo da empresa normalizado (minusculo) e com
// formato validado por GEBDBSchemaValido(), ou "" se invalido. cEmpresa
// vazio/Nil: tenant corrente (current_schema() = emp_<cod>), ou "" se o
// search_path atual nao aponta para um tenant.
Static Function RNEmpAlvo(cEmpresa)
    Local cEmp := ""
    Local aHit := {}

    If ValType(cEmpresa) == "C"
        cEmp := Lower(AllTrim(cEmpresa))
    EndIf
    If cEmp == ""
        aHit := TCSqlQuery("SELECT current_schema() AS SCH")
        If Len(aHit) > 0
            cEmp := Lower(AllTrim(cValToChar(aHit[1]:SCH)))
            If SubStr(cEmp, 1, 4) == "emp_"
                cEmp := SubStr(cEmp, 5)
            Else
                cEmp := ""
            EndIf
        EndIf
    EndIf
    If cEmp == ""
        Return ""
    EndIf
    If !GEBDBSchemaValido(cEmp)
        Return ""
    EndIf
Return cEmp

// RNTabNoSchema(cEmp, cTabela) -> .T. se emp_<cEmp>.<cTabela> existe.
// cEmp ja validado pelo chamador; cTabela e' literal interno.
Static Function RNTabNoSchema(cEmp, cTabela)
    Local aHit := TCSqlQuery("SELECT table_name FROM information_schema.tables WHERE table_schema = 'emp_" + ;
        cEmp + "' AND table_name = " + GEBDBQuote(Lower(cTabela)) + "")
Return (Len(aHit) > 0)

// RNContaTenant(cCod, cTabela) -> {nLinhasAtivas} de emp_<cCod>.<cTabela>,
// ou {} se o codigo for invalido, o schema nao existir ou a tabela nao
// existir nele. Nome qualificado pelo schema: nao toca no search_path.
Static Function RNContaTenant(cCod, cTabela)
    Local aHit := {}
    Local cEmp := ""

    If !GEBDBSchemaValido(cCod)
        Return {}
    EndIf
    cEmp := Lower(AllTrim(cCod))
    If !GEBDBSchemaExists(cEmp)
        Return {}
    EndIf
    If !RNTabNoSchema(cEmp, cTabela)
        Return {}
    EndIf
    aHit := TCSqlQuery("SELECT COUNT(*) AS NCNT FROM emp_" + cEmp + "." + cTabela + " WHERE D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {}
    EndIf
Return {Val(cValToChar(aHit[1]:NCNT))}

// RNDataValida(cData) -> .T. se vazio ou exatamente 8 digitos (AAAAMMDD).
Static Function RNDataValida(cData)
    Local nI := 0
    Local cCh := ""
    If cData == ""
        Return .T.
    EndIf
    If Len(cData) != 8
        Return .F.
    EndIf
    For nI := 1 To 8
        cCh := SubStr(cData, nI, 1)
        If cCh < "0" .Or. cCh > "9"
            Return .F.
        EndIf
    Next nI
Return .T.
