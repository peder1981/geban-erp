#include "totvs.ch"
#include "GEBDB_CORE.prw"
#include "GEBDB_TENANT.prw"

/*/{Protheus.doc} GEBEXP_CTX
    Contexto de sessao multi-empresa para GEB_EXPANSAO (Task 2).
    Funcoes:
    - GEBEXPCONTEXTO(cEmpresa, cFilial, cUsuario): valida usuario em GE2
      (FILIAL+COD+EMPRESA), grava entrada em GEH (historico acesso),
      armazena contexto em tabela GEX. Retorna .T. se sucesso, .F. se
      usuario inexistente na empresa.
    - GEBEXPIST(): retorna .T. se houver sessao ativa em GEX.
    - GEBEXPCONTEXTO(): retorna array {empresa, filial, usuario}.
    - GEBEXPCLEAR(): encerra sessao, limpa linha de GEX.
    Tabela GEX criada sob demanda (sem EMPRESA; contexto temporario).
    Notas AdvPP (balisador, ver task-1-report.md):
    - ConOut p/ log (FWLogMsg inexistente no runtime).
    - TCSqlQuery so funciona p/ existencia (Len > 0); valores sao Nil.
      Por isso a validacao de usuario usa COUNT(*) via TCSqlQuery
      (verifica existencia da linha, nao valor do campo).
    - Workarea (DbSelectArea/DbGoTop/While !Eof/DbSkip) funciona
      para colunas existentes no CREATE, mas campos adicionados por
      ALTER TABLE (EMPRESA) retornam Nil no workarea. Uso workarea
      SO para GEX (criada pelo proprio modulo, sem ALTER posterior).
    - GetArea/RestArea guardados (GetArea retorna "" sem workarea
      aberta; RestArea("") aborta).
    - If Nil em vez de Default (Default sobrescreve incondicionalmente
      no AdvPP). Sem IIF (CA4000). Sem cFilial.
    @type Modulo de contexto de sessao
    @author Peder Munksgaard
    @since 23/09/2026
    @param cEmpresaCodigo da empresa (CHAR(02))
    @param cFilialCodigo da filial (CHAR(06))
    @param cUsuarioCodigo do usuario em GE2
    @return .T. se sessao iniciada, .F. se usuario nao existe na empresa
/*/
User Function GEBEXPCONTEXTO(cEmpresa, cFilial, cUsuario)
    Local aArea := GetArea()
    Local lOk := .F.
    Local cData := ""
    Local cHora := ""
    Local aHit := {}
    Local cSql := ""

    // Default de parametros (If Nil em vez de Default -- AdvPP bug).
    If cEmpresa == Nil
        cEmpresa := ""
    EndIf
    If cFilial == Nil
        cFilial := ""
    EndIf
    If cUsuario == Nil
        cUsuario := ""
    EndIf

    // Defesa em profundidade: cEmpresa/cUsuario (e cFilial) sao
    // concatenados direto no SQL abaixo -- o FORMATO e' validado AQUI,
    // independente do chamador (GEBAN() ja valida, outros podem nao
    // validar). cEmpresa/cUsuario: GEBDBSchemaValido (alfanumerico +
    // underscore, ate 30 chars). cFilial: vazia/so espacos (filial
    // padrao FWxFilial) ou o mesmo formato. Falha de formato cai no
    // mesmo retorno .F. (silencioso) de "usuario sem vinculo" -- sem SQL
    // nenhum. GEBEXPCONTEXTO() sem argumentos (chamadores legados que
    // esperavam o array de contexto) continua devolvendo .F. como antes.
    If !GEBDBSchemaValido(cEmpresa)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If !GEBDBSchemaValido(cUsuario)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If AllTrim(cFilial) != ""
        If !GEBDBSchemaValido(cFilial)
            If Len(aArea) > 0
                RestArea(aArea)
            EndIf
            Return .F.
        EndIf
    EndIf
    cEmpresa := AllTrim(cEmpresa)
    cUsuario := AllTrim(cUsuario)

    // Valida se o usuario existe em GE2 (catalogo, identidade unica --
    // sem filtro por filial: a filial da sessao e' imposta pelo vinculo
    // GE2_EMP triplo logo abaixo, que e' a guarda real) E tem vinculo
    // com a empresa em GE2_EMP -- GE2.EMPRESA foi aposentada no redesign
    // multi-tenant (Fase 1); GE2_EMP e' o vinculo many-to-many real.
    cSql := "SELECT GE2_COD FROM GE2 WHERE GE2_COD = " + GEBDBQuote(cUsuario) + " AND D_E_L_E_T_ = ' '"
    aHit := TCSqlQuery(cSql)
    If Len(aHit) > 0
        cSql := "SELECT GE2_EMP_USUARIO FROM GE2_EMP WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cUsuario) + " AND GE2_EMP_EMPRESA = " + GEBDBQuote(Lower(AllTrim(cEmpresa))) + " AND TRIM(BOTH ' ' FROM GE2_EMP_FILIAL) = TRIM(BOTH ' ' FROM " + GEBDBQuote(cFilial) + ") AND D_E_L_E_T_ = ' '"
        aHit := TCSqlQuery(cSql)
        If Len(aHit) > 0
            lOk := .T.
        EndIf
    EndIf

    // Super (mesma regra de GEBSECISSUPER, inline: este fonte nao depende de GEBSEC_LOGIN).
    If !lOk
        If Upper(AllTrim(cUsuario)) == "SUPER"
            lOk := .T.
        EndIf
    EndIf

    If lOk
        // Grava historico em GEH.
        cData := DToS(Date())
        cHora := Time()
        TCSqlExec("INSERT INTO GEH (D_E_L_E_T_, GEH_DATA, GEH_HORA, GEH_USUARIO, GEH_EMPRESA, GEH_FUNCAO, GEH_IP) VALUES (' ', " + GEBDBQuote(cData) + ", " + GEBDBQuote(cHora) + ", " + GEBDBQuote(cUsuario) + ", " + GEBDBQuote(cEmpresa) + ", 'GEBEXPCONTEXTO', 'local')")

        // Armazena contexto em GEX.
        GEXPCREATE()
        TCSqlExec("DELETE FROM GEX WHERE D_E_L_E_T_ = ' '")
        TCSqlExec("INSERT INTO GEX (D_E_L_E_T_, GEX_EMPRESA, GEX_FILIAL, GEX_USUARIO) VALUES (' ', " + GEBDBQuote(cEmpresa) + ", " + GEBDBQuote(cFilial) + ", " + GEBDBQuote(cUsuario) + ")")
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

/*/{Protheus.doc} GEBEXPIST
    Verifica se ha sessao de contexto ativa (linha em GEX).
    Usa workarea porque GEX e criada por este modulo (sem ALTER).
    @type Funcao de verificacao
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se sessao ativa, .F. caso contrario
/*/
User Function GEBEXPIST()
    Local aArea := GetArea()
    Local lOk := .F.

    // Workarea: verifica existencia de linha ativa em GEX.
    DbSelectArea("GEX")
    DbGoTop()
    While !Eof()
        If GEX->D_E_L_E_T_ == " "
            lOk := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

/*/{Protheus.doc} GEBEXPCONTEXT
    Retorna o contexto de sessao atual como array {empresa, filial, usuario}.
    Usa workarea (GEX criada sem ALTER TABLE).
    @type Funcao de consulta
    @author Peder Munksgaard
    @since 23/09/2026
    @return Array 3 posicoes: [1]=empresa, [2]=filial, [3]=usuario
/*/
User Function GEBEXPCONTEXT_GET()
    Local aArea := GetArea()
    Local aRet := {"", "", ""}

    // Workarea: lee linha ativa de GEX.
    DbSelectArea("GEX")
    DbGoTop()
    While !Eof()
        If GEX->D_E_L_E_T_ == " "
            aRet[1] := GEX->GEX_EMPRESA
            aRet[2] := GEX->GEX_FILIAL
            aRet[3] := GEX->GEX_USUARIO
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

/*/{Protheus.doc} GEBEXPCLEAR
    Encerra sessao: remove linha ativa de GEX.
    @type Funcao de limpeza
    @author Peder Munksgaard
    @since 23/09/2026
    @return void
/*/
User Function GEBEXPCLEAR()
    Local aArea := GetArea()

    TCSqlExec("DELETE FROM GEX WHERE D_E_L_E_T_ = ' '")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return

/*/{Protheus.doc} GEXBINIT
    Inicializa tabelas auxiliares GEH (historico) e GEX (contexto)
    se nao existirem. Chamada uma vez no setup do teste.
    @type Funcao auxiliar
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. sempre
/*/
User Function GEXBINIT()
    // Cria GEH (historico de acesso) se nao existir.
    If !GEBDBTableExistsHere("GEH")
        TCSqlExec("CREATE TABLE GEH (R_E_C_N_O_ INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, D_E_L_E_T_ TEXT DEFAULT ' ', GEH_DATA TEXT NOT NULL, GEH_HORA TEXT NOT NULL, GEH_USUARIO TEXT NOT NULL, GEH_EMPRESA TEXT NOT NULL, GEH_FUNCAO TEXT NOT NULL, GEH_IP TEXT NOT NULL)")
        TCSqlExec("CREATE INDEX IF NOT EXISTS GEH_DATA_USU ON GEH (GEH_DATA, GEH_USUARIO)")
    EndIf

    // Cria GEX (contexto de sessao) se nao existir.
    If !GEBDBTableExistsHere("GEX")
        TCSqlExec("CREATE TABLE GEX (R_E_C_N_O_ INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, D_E_L_E_T_ TEXT DEFAULT ' ', GEX_EMPRESA TEXT NOT NULL, GEX_FILIAL TEXT NOT NULL, GEX_USUARIO TEXT NOT NULL)")
    EndIf
Return .T.

/*/{Protheus.doc} GEXPCREATE
    Cria tabela GEX se nao existir (static, interna).
    @type Funcao auxiliar
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. sempre
/*/
Static Function GEXPCREATE()
    If !GEBDBTableExistsHere("GEX")
        TCSqlExec("CREATE TABLE GEX (R_E_C_N_O_ INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, D_E_L_E_T_ TEXT DEFAULT ' ', GEX_EMPRESA TEXT NOT NULL, GEX_FILIAL TEXT NOT NULL, GEX_USUARIO TEXT NOT NULL)")
    EndIf
Return .T.
