#include "totvs.ch"

/*/{Protheus.doc} GEBDB_CORE
    Helper central de introspeccao/criacao de tabela sobre a conexao
    Postgres ativa (via DBSetDriver("TOPCONN")). Substitui o padrao
    pg_tables/information_schema.columns duplicado em cada *_MIG.prw.
    @type Modulo de infraestrutura de dados
    @author Peder Munksgaard
    @since 23/09/2026
/*/

// GEBDBQuote(xVal) -> literal SQL entre aspas simples, com aspas internas
// dobradas. Use em TODO valor vindo de fora (HTTP, tela, parametro) que
// entre num TCSqlExec/TCSqlQuery -- dentro da funcao que monta o SQL, nao
// em quem chama.
User Function GEBDBQuote(xVal)
Return "'" + StrTran(cValToChar(xVal), "'", "''") + "'"


// GEBDBTableExists(cTabela) -> .T./.F. -- existe em QUALQUER schema do
// search_path atual? Usado como guarda de leitura ampla (ex.: GEBCFG()
// quer saber "GE4 existe em algum lugar alcancavel"), NAO para decidir
// se uma CREATE TABLE sem qualificador de schema deve rodar -- para isso
// use GEBDBTableExistsHere().
User Function GEBDBTableExists(cTabela)
    Local aChk := TCSqlQuery( ;
        "SELECT tablename FROM pg_tables WHERE schemaname = ANY(current_schemas(false)) AND tablename = '" + ;
        Lower(AllTrim(cTabela)) + "'")
Return (Len(aChk) > 0)

// GEBDBTableExistsHere(cTabela) -> .T./.F. -- existe especificamente no
// PRIMEIRO schema do search_path atual (o schema que uma CREATE TABLE
// sem qualificador de schema efetivamente alveja)? Diferente de
// GEBDBTableExists(), que busca em TODOS os schemas do search_path
// (incluindo "public" quando o search_path e' "emp_xxx, public") e por
// isso pode reportar "existe" mesmo quando a tabela nao existe no
// schema do tenant -- mascarando a necessidade de cria-la ali.
User Function GEBDBTableExistsHere(cTabela)
    Local aChk := TCSqlQuery( ;
        "SELECT tablename FROM pg_tables WHERE schemaname = (current_schemas(false))[1] AND tablename = '" + ;
        Lower(AllTrim(cTabela)) + "'")
Return (Len(aChk) > 0)

// GEBDBColumnExists(cTabela, cColuna) -> .T./.F.
User Function GEBDBColumnExists(cTabela, cColuna)
    Local aChk := TCSqlQuery( ;
        "SELECT column_name FROM information_schema.columns WHERE table_schema = ANY(current_schemas(false)) " + ;
        "AND table_name = " + GEBDBQuote(Lower(AllTrim(cTabela))) + " AND column_name = " + GEBDBQuote(Lower(AllTrim(cColuna))) + "")
Return (Len(aChk) > 0)

// GEBDBTableEnsure(cTabela, cDDL, aColsObrigatorias) -> .T./.F.
// cDDL: "CREATE TABLE ..." completo, so' usado se a tabela ainda nao existir.
// aColsObrigatorias: array de nomes de coluna que devem existir ao final;
// as que faltarem (tabela ja existente) sao adicionadas como TEXT.
User Function GEBDBTableEnsure(cTabela, cDDL, aColsObrigatorias)
    Local lOk    := .T.
    Local nIdx   := 0
    Local cCol   := ""
    Local cSql   := ""

    If !GEBDBTableExistsHere(cTabela)
        If Empty(cDDL)
            ConOut("GEBDBTableEnsure: " + cTabela + " nao existe e cDDL vazio")
            Return .F.
        EndIf
        lOk := TCSqlExec(cDDL)
        If !lOk
            ConOut("GEBDBTableEnsure: FALHA ao criar " + cTabela)
            Return .F.
        EndIf
        ConOut("GEBDBTableEnsure: " + cTabela + " criada")
    EndIf

    For nIdx := 1 To Len(aColsObrigatorias)
        cCol := AllTrim(aColsObrigatorias[nIdx])
        If !GEBDBColumnExists(cTabela, cCol)
            cSql := "ALTER TABLE " + cTabela + " ADD COLUMN " + cCol + " TEXT"
            If !TCSqlExec(cSql)
                ConOut("GEBDBTableEnsure: FALHA ao adicionar coluna " + cCol + " em " + cTabela)
                lOk := .F.
            Else
                ConOut("GEBDBTableEnsure: " + cTabela + "." + cCol + " adicionada")
            EndIf
        EndIf
    Next nIdx
Return lOk

// GEBDBMoedaFix() -> converte as colunas REAL (float de 4 bytes, ~6
// digitos: perdia centavos acima de 100 mil) do schema corrente para
// NUMERIC exato: quantidades (sufixo _QTD, GV1_SALDO, GV1_MIN) com 4
// casas, dinheiro com 2 (arredondando ao centavo o que o float gravou).
// Idempotente: sem coluna REAL, nao faz nada. Passa por float8: o cast
// direto real->numeric do Postgres arredonda a 6 digitos (12345,67 -> 12345,7).
// Migracao: rodar uma vez por empresa (ver o runbook interno), nao a cada login.
User Function GEBDBMoedaFix()
    Local aCols := TCSqlQuery("SELECT table_name AS T, column_name AS C FROM information_schema.columns WHERE table_schema = current_schema() AND data_type = 'real' ORDER BY 1, 2")
    Local nI := 0
    Local cTab := ""
    Local cCol := ""
    Local nDec := 2
    Local lOk := .T.
    For nI := 1 To Len(aCols)
        cTab := Upper(AllTrim(cValToChar(aCols[nI]:T)))
        cCol := Upper(AllTrim(cValToChar(aCols[nI]:C)))
        nDec := 2
        If Right(cCol, 4) == "_QTD" .Or. cCol == "GV1_SALDO" .Or. cCol == "GV1_MIN"
            nDec := 4
        EndIf
        If !TCSqlExec("ALTER TABLE " + cTab + " ALTER COLUMN " + cCol + " TYPE NUMERIC(18," + cValToChar(nDec) + ") USING ROUND(" + cCol + "::float8::numeric, " + cValToChar(nDec) + ")")
            lOk := .F.
        EndIf
    Next nI
Return lOk
