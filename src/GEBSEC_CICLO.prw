#include "totvs.ch"
#include "GEBDB_CORE.prw"
#include "GEBDB_TENANT.prw"
#include "GEBSEC_LOGIN.prw"

/*/{Protheus.doc} GEBSEC_CICLO
    Ciclo de vida do usuario (referencia: TOTVS Protheus, Gestao de Usuarios):
      - Bloquear / desbloquear (GE2_BLOQ): global, so' o super.
      - Validade (GE2_VALID, AAAAMMDD): global, so' o super. Vencida = bloqueada.
      - Eliminar acessos: remove os vinculos (GE2_EMP) do usuario. O super remove de todas
        as empresas e bloqueia; o ADMIN remove so' os vinculos da propria empresa. Reversivel
        (basta vincular de novo).
      - Excluir: so' usuario que nunca acessou (SEC_LASTLOGIN = 00000000). So' o super.
      - Ignorar troca periodica (SEC_IGNEXP): conta de servico. So' o super. Nao vale para a conta super.
      - Forcar troca no proximo logon (SEC_FORCE): super ou ADMIN da empresa (usuario vinculado).
    A conta super nunca e' bloqueada, vencida, excluida ou tem a expiracao ignorada.
    Todas as funcoes devolvem {lOk, cMsg}.
    @type Modulo de seguranca
    @since 07/11/2026
/*/

// Interno: o alvo nao pode ser o super nas operacoes que o proibem.
Static Function CicloAlvoOk(cAlv)
    If !GEBDBSchemaValido(cAlv)
        Return .F.
    EndIf
Return .T.

// GEBSECBLOQUEIA(cUsuLog, cAlvo, lBloq) -> {lOk, cMsg}. Bloqueia (.T.) ou desbloqueia (.F.).
User Function GEBSECBLOQUEIA(cUsuLog, cAlvo, lBloq)
    Local cAlv := AllTrim(cValToChar(cAlvo))
    Local cVal := "N"
    Local lOk  := .F.
    If !GEBSECISSUPER(cUsuLog)
        Return {.F., "so o super bloqueia usuarios (vale para todas as empresas)"}
    EndIf
    If !CicloAlvoOk(cAlv)
        Return {.F., "usuario invalido"}
    EndIf
    If GEBSECISSUPER(cAlv)
        Return {.F., "a conta super nao pode ser bloqueada"}
    EndIf
    If lBloq == Nil
        lBloq := .F.
    EndIf
    If lBloq
        cVal := "S"
    EndIf
    lOk := TCSqlExec("UPDATE public.GE2 SET GE2_BLOQ = " + GEBDBQuote(cVal) + " WHERE GE2_COD = " + GEBDBQuote(cAlv) + " AND D_E_L_E_T_ = ' '")
    If lOk .And. lBloq
        // Derruba as sessoes abertas do usuario.
        GEBSECDERRUBA(cAlv)
    EndIf
    ConOut("GEBSECBLOQUEIA: " + cAlv + " bloqueado=" + cVal + " por " + cUsuLog)
Return {lOk, "ok"}

// GEBSECVALIDADE(cUsuLog, cAlvo, cData) -> {lOk, cMsg}. cData AAAAMMDD; "" limpa a validade.
User Function GEBSECVALIDADE(cUsuLog, cAlvo, cData)
    Local cAlv := AllTrim(cValToChar(cAlvo))
    Local cDt  := ""
    Local lOk  := .F.
    If !GEBSECISSUPER(cUsuLog)
        Return {.F., "so o super define validade (vale para todas as empresas)"}
    EndIf
    If !CicloAlvoOk(cAlv) .Or. GEBSECISSUPER(cAlv)
        Return {.F., "usuario invalido ou conta super"}
    EndIf
    If cData == Nil
        cDt := ""
    Else
        cDt := AllTrim(cValToChar(cData))
    EndIf
    If cDt != "" .And. !(Len(cDt) == 8 .And. IsDigit(cDt))
        Return {.F., "validade invalida: use AAAAMMDD ou vazio para limpar"}
    EndIf
    lOk := TCSqlExec("UPDATE public.GE2 SET GE2_VALID = " + GEBDBQuote(cDt) + " WHERE GE2_COD = " + GEBDBQuote(cAlv) + " AND D_E_L_E_T_ = ' '")
Return {lOk, "ok"}

// GEBSECELIMINAACESSOS(cUsuLog, cAlvo) -> {lOk, cMsg}.
User Function GEBSECELIMINAACESSOS(cUsuLog, cAlvo)
    Local cAlv := AllTrim(cValToChar(cAlvo))
    Local cEmp := Lower(AllTrim(cValToChar(GEBDBTenantAtual())))
    Local lOk  := .F.
    If !CicloAlvoOk(cAlv)
        Return {.F., "usuario invalido"}
    EndIf
    If GEBSECISSUPER(cAlv)
        Return {.F., "a conta super nao perde acessos"}
    EndIf
    If !GEBSECPODE(cUsuLog, cAlv, .T.)
        Return {.F., "sem permissao: o usuario precisa estar vinculado a empresa da sessao"}
    EndIf
    If GEBSECISSUPER(cUsuLog)
        // Super: remove de todas as empresas e bloqueia (conta sem acesso).
        lOk := TCSqlExec("UPDATE public.GE2_EMP SET D_E_L_E_T_ = '*' WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cAlv) + " AND D_E_L_E_T_ = ' '")
        lOk := lOk .And. TCSqlExec("UPDATE public.GE2 SET GE2_BLOQ = 'S' WHERE GE2_COD = " + GEBDBQuote(cAlv) + " AND D_E_L_E_T_ = ' '")
        GEBSECDERRUBA(cAlv)
    Else
        // ADMIN: so' os vinculos da propria empresa; sessoes dessa empresa caem.
        lOk := TCSqlExec("UPDATE public.GE2_EMP SET D_E_L_E_T_ = '*' WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cAlv) + " AND LOWER(TRIM(GE2_EMP_EMPRESA)) = " + GEBDBQuote(cEmp) + " AND D_E_L_E_T_ = ' '")
        lOk := lOk .And. TCSqlExec("UPDATE public.GE2_TOK SET D_E_L_E_T_ = '*' WHERE TOK_USUARIO = " + GEBDBQuote(cAlv) + " AND LOWER(TOK_EMPRESA) = " + GEBDBQuote(cEmp) + " AND D_E_L_E_T_ = ' '")
    EndIf
    ConOut("GEBSECELIMINAACESSOS: " + cAlv + " por " + cUsuLog + " ok=" + Iif(lOk, "S", "N"))
Return {lOk, "ok"}

// GEBSECEXCLUI(cUsuLog, cAlvo) -> {lOk, cMsg}. So' usuario que nunca acessou; so' o super.
User Function GEBSECEXCLUI(cUsuLog, cAlvo)
    Local cAlv := AllTrim(cValToChar(cAlvo))
    Local aAcc := {}
    Local lOk  := .F.
    If !GEBSECISSUPER(cUsuLog)
        Return {.F., "so o super exclui usuarios"}
    EndIf
    If !CicloAlvoOk(cAlv)
        Return {.F., "usuario invalido"}
    EndIf
    If GEBSECISSUPER(cAlv)
        Return {.F., "a conta super nao pode ser excluida"}
    EndIf
    aAcc := TCSqlQuery("SELECT SEC_USUARIO FROM public.GE2_SEC WHERE SEC_USUARIO = " + GEBDBQuote(cAlv) + " AND SEC_LASTLOGIN <> '00000000' AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aAcc) > 0
        Return {.F., "usuario ja acessou o sistema: use Eliminar acessos"}
    EndIf
    lOk := TCSqlExec("UPDATE public.GE2_EMP SET D_E_L_E_T_ = '*' WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cAlv) + " AND D_E_L_E_T_ = ' '")
    lOk := lOk .And. TCSqlExec("UPDATE public.GE2_SEC SET D_E_L_E_T_ = '*' WHERE SEC_USUARIO = " + GEBDBQuote(cAlv) + " AND D_E_L_E_T_ = ' '")
    lOk := lOk .And. TCSqlExec("UPDATE public.GE2 SET D_E_L_E_T_ = '*' WHERE GE2_COD = " + GEBDBQuote(cAlv) + " AND D_E_L_E_T_ = ' '")
    ConOut("GEBSECEXCLUI: " + cAlv + " por " + cUsuLog)
Return {lOk, "ok"}

// GEBSECIGNORAEXP(cUsuLog, cAlvo, lIgnora) -> {lOk, cMsg}. Conta de servico: nao expira por troca periodica.
User Function GEBSECIGNORAEXP(cUsuLog, cAlvo, lIgnora)
    Local cAlv := AllTrim(cValToChar(cAlvo))
    Local cVal := "N"
    Local lOk  := .F.
    If !GEBSECISSUPER(cUsuLog)
        Return {.F., "so o super ignora a troca periodica"}
    EndIf
    If !CicloAlvoOk(cAlv)
        Return {.F., "usuario invalido"}
    EndIf
    If GEBSECISSUPER(cAlv)
        Return {.F., "a conta super nao pode ignorar a troca periodica"}
    EndIf
    If lIgnora == Nil
        lIgnora := .F.
    EndIf
    If lIgnora
        cVal := "S"
    EndIf
    lOk := TCSqlExec("UPDATE public.GE2_SEC SET SEC_IGNEXP = " + GEBDBQuote(cVal) + " WHERE SEC_USUARIO = " + GEBDBQuote(cAlv) + " AND D_E_L_E_T_ = ' '")
Return {lOk, "ok"}

// GEBSECFORCATROCA(cUsuLog, cAlvo, lForca) -> {lOk, cMsg}. Troca obrigatoria no proximo logon.
User Function GEBSECFORCATROCA(cUsuLog, cAlvo, lForca)
    Local cAlv := AllTrim(cValToChar(cAlvo))
    Local cVal := "N"
    Local lOk  := .F.
    If !CicloAlvoOk(cAlv)
        Return {.F., "usuario invalido"}
    EndIf
    If !GEBSECPODE(cUsuLog, cAlv, .T.)
        Return {.F., "sem permissao: o usuario precisa estar vinculado a empresa da sessao"}
    EndIf
    If lForca == Nil
        lForca := .F.
    EndIf
    If lForca
        cVal := "S"
    EndIf
    lOk := TCSqlExec("UPDATE public.GE2_SEC SET SEC_FORCE = " + GEBDBQuote(cVal) + " WHERE SEC_USUARIO = " + GEBDBQuote(cAlv) + " AND D_E_L_E_T_ = ' '")
Return {lOk, "ok"}
