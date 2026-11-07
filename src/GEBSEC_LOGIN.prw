#include "totvs.ch"
#include "GEBDB_CORE.prw"
#include "GEBDB_TENANT.prw"
#include "GEBSEC_POL.prw"

/*/{Protheus.doc} GEBSEC_LOGIN
    Autenticacao de usuario GEB_SEC (Task 2 GEB_SECURITY).
    GEBSECLOGIN(cUser, cPass, cIP) valida credenciais contra GE2/GE2_SEC:
    - Verifica existencia do usuario em GE2.
    - Verifica lockout (SEC_LOCKED >= hoje).
    - Compara hash da senha via Argon2id (RFC 9106, nativo do runtime).
    - Incrementa failCount em caso de erro; bloqueia apos 5 tentativas.
    - Atualiza SEC_LASTLOGIN em caso de sucesso.
    - Grava entrada de audit em GEH.
    Retorna codigo de status:
      "OK"         -- autenticacao com sucesso.
      "USU_INEX"   -- usuario inexistente.
      "SENHA_ERR"  -- senha incorreta.
      "CONTA_BLOQ" -- conta bloqueada (lockout).
      "MAX_TENT"   -- maximo de tentativas atingido.
    Interface: U_GEBSECLOGIN -> GEBSECLOGIN(cUser, cPass, cIP).
    Notas AdvPP: ConOut p/ log; TCSqlQuery so funciona p/ existencia;
    GetArea/RestArea guardados; If Nil em vez de Default; sem SELECT *,
    sem concat SQL em leitura, so literais.
    @type Funcao de autenticacao
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUser     Codigo do usuario (GE2_COD)
    @param cPass     Senha em texto puro
    @param cIP       IP de origem (padrao "local")
    @return cStatus  Codigo de status ("OK" ou erro)
/*/
User Function GEBSECLOGIN(cUser, cPass, cIP)
    Local aArea    := GetArea()
    Local cStatus  := "USU_INEX"
    Local cFil     := ""
    Local aUser    := {}
    Local aSec     := {}
    Local cHash    := ""
    Local cStored  := ""
    Local cSalt    := ""
    Local nFail    := 0
    Local cLocked  := ""
    Local cRid     := ""
    Local cBloqU   := "N"
    Local cVenc    := "N"
    Local cForce   := "N"
    Local cExpira  := "N"
    Local cToday   := ""
    Local cData    := ""
    Local cHora    := ""
    Local cIp      := ""
    Local lAudit   := .F.

    // Default parametros.
    If cUser == Nil
        cUser := ""
    EndIf
    If cPass == Nil
        cPass := ""
    EndIf
    If cIP == Nil
        cIp := "local"
    Else
        cIp := AllTrim(cIP)
    EndIf

    cToday := DToS(Date())

    // Defesa em profundidade: cUser e' concatenado direto nas queries
    // abaixo, entao o FORMATO e' validado AQUI (alfanumerico + underscore,
    // ate 30 chars -- GEBDBSchemaValido), independente do chamador ter
    // validado antes (GEBAN() valida; outros chamadores podem nao validar).
    // Formato invalido cai no mesmo retorno generico de usuario
    // inexistente -- nao cria mensagem/codigo distinguivel.
    If !GEBDBSchemaValido(cUser)
        ConOut("GEBSECLOGIN: usuario inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return "USU_INEX"
    EndIf
    cUser := AllTrim(cUser)

    // Busca usuario em GE2.
    aUser := TCSqlQuery("SELECT GE2_FILIAL, GE2_BLOQ, CASE WHEN GE2_VALID <> '' AND GE2_VALID < to_char(current_date, 'YYYYMMDD') THEN 'S' ELSE 'N' END AS VENC FROM GE2 WHERE GE2_COD = " + GEBDBQuote(cUser) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aUser) == 0
        ConOut("GEBSECLOGIN: usuario inexistente '" + cUser + "'")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return "USU_INEX"
    EndIf

    cFil := aUser[1]:GE2_FILIAL  // Mantem 6 espacos (FWxFilial padrao)
    cBloqU := AllTrim(cValToChar(aUser[1]:GE2_BLOQ))
    cVenc  := AllTrim(cValToChar(aUser[1]:VENC))

    // Busca credenciais em GE2_SEC.
    // Credencial e' identificada pelo usuario (catalogo). Se houver mais de uma linha
    // (legado com filiais diferentes), prefere a da filial do GE2; o UPDATE usa R_E_C_N_O_.
    aSec := TCSqlQuery("SELECT R_E_C_N_O_ AS RID, SEC_IGNEXP, SEC_FORCE, CASE WHEN SEC_PWDLAST = '00000000' THEN 'N' WHEN SEC_IGNEXP = 'S' THEN 'N' WHEN to_date(SEC_PWDLAST, 'YYYYMMDD') + 90 < current_date THEN 'S' ELSE 'N' END AS EXPIRA, SEC_SALT, SEC_HASH, SEC_FAILCNT, SEC_LOCKED, CASE WHEN SEC_LOCKED > to_char(now(), 'YYYYMMDD HH24:MI:SS') THEN 'S' ELSE 'N' END AS BLOQ FROM GE2_SEC WHERE SEC_USUARIO = " + GEBDBQuote(cUser) + " AND D_E_L_E_T_ = ' ' ORDER BY (SEC_FILIAL = " + GEBDBQuote(cFil) + ") DESC LIMIT 1")
    If Len(aSec) == 0
        ConOut("GEBSECLOGIN: credenciais ausentes para usuario " + cUser)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return "USU_INEX"
    EndIf

    // TCSqlQuery devolve TODA coluna como string (inclusive INTEGER) --
    // Val() converte antes da aritmetica, senao "nFail + 1" concatena
    // ("0"+1 -> "01", "1"+1 -> "11") e a comparacao ">= 5" cai em
    // comparacao numerica de "11" -> bloqueava na 2a tentativa errada.
    // Mesmo padrao de GEBRESTRLIMIT (src/GEBREST.prw).
    cSalt   := AllTrim(cValToChar(aSec[1]:SEC_SALT))
    cStored := AllTrim(cValToChar(aSec[1]:SEC_HASH))
    nFail   := Val(cValToChar(aSec[1]:SEC_FAILCNT))
    cLocked := AllTrim(cValToChar(aSec[1]:SEC_LOCKED))
    cRid    := AllTrim(cValToChar(aSec[1]:RID))
    cForce  := AllTrim(cValToChar(aSec[1]:SEC_FORCE))
    cExpira := AllTrim(cValToChar(aSec[1]:EXPIRA))

    // Verifica lockout (comparado no banco: data+hora do bloqueio contra now()).
    If AllTrim(cValToChar(aSec[1]:BLOQ)) == "S"
        ConOut("GEBSECLOGIN: conta bloqueada ate " + cLocked + " (usuario " + cUser + ")")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return "CONTA_BLOQ"
    EndIf

    // Compara hash. Argon2id(x, "") devolve "" no runtime AdvPP, entao
    // uma linha GE2_SEC com SEC_SALT/SEC_HASH vazios faria "" == "" e
    // aceitaria QUALQUER senha (fail-open). Salt vazio, hash armazenado
    // vazio ou hash calculado vazio => credencial invalida, tratada
    // EXATAMENTE como senha errada (mesmo retorno, mesma mensagem, mesmo
    // incremento de tentativas) -- sem oraculo distinguivel.
    If cSalt == "" .Or. cStored == ""
        cHash := ""
    Else
        cHash := HashSenha(cPass, cSalt)
    EndIf
    If cHash == "" .Or. cHash != cStored
        // Falha: incrementa failCount.
        nFail := nFail + 1
        TCSqlExec("UPDATE GE2_SEC SET SEC_FAILCNT = " + cValToChar(nFail) + " WHERE R_E_C_N_O_ = " + cRid)
        If nFail >= 5
            ConOut("GEBSECLOGIN: maximo de tentativas atingido para usuario " + cUser)
            // Bloqueio TEMPORARIO (15 min, relogio do banco): o permanente
            // ('20991231') deixava qualquer um travar qualquer conta -- o
            // super inclusive -- com 5 senhas erradas, sem desbloqueio.
            TCSqlExec("UPDATE GE2_SEC SET SEC_LOCKED = to_char(now() + interval '15 minutes', 'YYYYMMDD HH24:MI:SS') WHERE R_E_C_N_O_ = " + cRid)
            If Len(aArea) > 0
                RestArea(aArea)
            EndIf
            Return "MAX_TENT"
        EndIf
        ConOut("GEBSECLOGIN: senha incorreta para usuario " + cUser + " (" + cValToChar(nFail) + "/5 tentativas)")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return "SENHA_ERR"
    EndIf

    // Senha correta. Bloqueio, validade, troca obrigatoria e expiracao so' sao
    // informados agora (nao antes da senha, para nao virar oraculo de conta).
    // O super nao e' bloqueado nem vencido por validade ou bloqueio.
    If !GEBSECISSUPER(cUser)
        If cBloqU == "S" .Or. cVenc == "S"
            ConOut("GEBSECLOGIN: conta bloqueada ou vencida (usuario " + cUser + ")")
            If Len(aArea) > 0
                RestArea(aArea)
            EndIf
            Return "USU_BLOQ"
        EndIf
    EndIf
    If cForce == "S"
        ConOut("GEBSECLOGIN: troca de senha obrigatoria (usuario " + cUser + ")")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return "TROCA_OBRIGATORIA"
    EndIf
    If cExpira == "S"
        ConOut("GEBSECLOGIN: senha expirada (usuario " + cUser + ")")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return "SENHA_EXP"
    EndIf

    // Sucesso: reseta failCount, atualiza lastLogin.
    TCSqlExec("UPDATE GE2_SEC SET SEC_FAILCNT = 0, SEC_LASTLOGIN = " + GEBDBQuote(cToday) + ", SEC_LOCKED = '00000000' WHERE R_E_C_N_O_ = " + cRid)

    // Audit em GEH -- tabela por-empresa (GEBEXPCriaAuditoria(), dentro
    // de emp_<cod>), so' existe depois que um tenant foi selecionado.
    // GEBSECLOGIN() agora roda em nivel de catalogo (autentica ANTES de
    // saber a empresa, ver GEBAN.prw), entao guarda a existencia da
    // tabela em vez de assumir que ja existe -- login continua valendo
    // mesmo sem auditoria per-empresa ainda disponivel.
    If GEBDBTableExistsHere("GEH")
        cData := SubStr(DToS(Date()), 7, 2) + "/" + SubStr(DToS(Date()), 4, 2) + "/" + SubStr(DToS(Date()), 1, 2)
        cHora := Time()
        lAudit := TCSqlExec("INSERT INTO GEH (D_E_L_E_T_, GEH_DATA, GEH_HORA, GEH_USUARIO, GEH_EMPRESA, GEH_FUNCAO, GEH_IP) VALUES (' ', " + GEBDBQuote(cData) + ", " + GEBDBQuote(cHora) + ", " + GEBDBQuote(cUser) + ", '', 'GEBSECLOGIN', " + GEBDBQuote(cIp) + ")")
    EndIf
    ConOut("GEBSECLOGIN: usuario " + cUser + " autenticado com sucesso")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return "OK"

// Hash de senha real via Argon2id (RFC 9106), nativo do runtime AdvPP.
// Argon2id() retorna bytes binarios crus -- nunca gravar direto num
// TEXT via TCSqlExec literal (bytes NUL/aspas quebram o literal).
// Hex-encode antes de armazenar; ao comparar, hex-encode o hash
// recem-calculado e compara string a string (nunca decodifica de volta
// para binario -- nao ha necessidade).
User Function HashSenha(cSenha, cSalt)
    Local cBin := Argon2id(cSenha, cSalt)
Return HexEncode(cBin)

User Function HexEncode(cBin)
    Local cHex   := ""
    Local nIdx   := 0
    Local nLen   := Len(cBin)
    Local cAlpha := "0123456789abcdef"
    Local nByte  := 0

    For nIdx := 1 To nLen
        nByte := Asc(SubStr(cBin, nIdx, 1))
        cHex := cHex + SubStr(cAlpha, (nByte / 16) + 1, 1) + SubStr(cAlpha, (nByte % 16) + 1, 1)
    Next nIdx
Return cHex

/*/{Protheus.doc} GEBSECSALT
    Gera um salt aleatorio por usuario para HashSenha(): 32 caracteres
    hexadecimais (16 bytes) derivados de UUIDRandom() -- UUID v4 gerado
    com crypto/rand pelo runtime AdvPP (pkg/vm/ambiente_native.go). So
    [0-9a-f], seguro para literal SQL. Retorna "" se o runtime nao
    conseguir gerar (chamadores DEVEM tratar "" como falha -- salt vazio
    faz Argon2id() devolver "").
    @type Funcao utilitaria de seguranca
    @author Peder Munksgaard
    @since 25/09/2026
    @return cSalt  Salt hexadecimal de 32 chars, ou "" em falha
/*/
User Function GEBSECSALT()
    Local cUuid := UUIDRandom()
    Local cSalt := ""

    If ValType(cUuid) == "C"
        cSalt := Lower(StrTran(AllTrim(cUuid), "-", ""))
    EndIf
    If Len(cSalt) != 32
        cSalt := ""
    EndIf
Return cSalt

/*/{Protheus.doc} GEBSECCRIAUSU
    Provisiona (cria ou redefine) um usuario que consegue fazer login de
    verdade: linha em GE2 (se ainda nao existir), credencial em GE2_SEC
    (salt aleatorio via GEBSECSALT() + HashSenha() Argon2id hex,
    SEC_FAILCNT = 0, sem bloqueio) e vinculos em GE2_EMP para cada
    empresa de aEmpresas (so' insere vinculo que ainda nao existe).
    Se o usuario ja existe, a credencial e' SUBSTITUIDA (nova senha, novo
    salt, contador zerado, desbloqueado) -- serve tambem para redefinir
    senha/desbloquear. GE2_NOME/GE2_PERFIL de usuario existente nao sao
    alterados.
    Tudo e' validado ANTES de qualquer escrita (tudo-ou-nada na
    validacao): cUsu, cPerfil e cada empresa passam por
    GEBDBSchemaValido(); cada empresa precisa estar provisionada
    (GEBDBSchemaExists -- schema emp_<cod> existe); cSenha nao pode ser
    vazia nem so' espacos (AllTrim); cSenha precisa passar em
    GEBSECPOL_VERIFICA() (src/GEBSEC_POL.prw, mesma politica aplicada em
    GEBRESTURLSC()/src/GEBREST.prw: min 8 chars, 1 maiuscula, 1
    minuscula, 1 digito, 1 especial, sem sequencia/repeticao 3x); cNome
    tem aspas simples duplicadas. So' literais validados chegam ao SQL.
    Roda contra as tabelas de catalogo (GE2/GE2_SEC/GE2_EMP, schema
    public) -- o search_path atual precisa enxergar public (padrao apos
    GEBDBProvisionaCatalogo()).
    Guarda super: se cUsu (case-insensitive) for "super" e lPermiteSuper
    nao for .T., a chamada e' rejeitada inteira (.F., nenhuma escrita) --
    evita reset/desbloqueio ACIDENTAL da conta administrativa por um
    chamador que nao percebeu que cUsu era super. Nao remove a
    capacidade de reset: um chamador que deliberadamente quer tocar
    super ainda pode, passando lPermiteSuper:=.T.
    @type Funcao de provisionamento de usuario
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsu          Codigo do usuario (GE2_COD), alfanumerico/_ ate 30
    @param cSenha        Senha em texto puro (nao vazia, nao so' espacos, deve passar GEBSECPOL_VERIFICA)
    @param aEmpresas     Array de codigos de empresa (GE1_COD) a vincular
    @param cNome         Nome (GE2_NOME) para usuario novo (padrao: cUsu)
    @param cPerfil       Perfil (GE2_PERFIL) para usuario novo (padrao: USUARIO)
    @param lPermiteSuper .T. autoriza explicitamente tocar a conta super (padrao .F.)
    @return lOk          .T. se tudo gravado, .F. se validacao ou SQL falhar
/*/
/*/{Protheus.doc} GEBSECPODE
    Regra unica de autorizacao para agir sobre usuarios (criar, alterar,
    trocar senha, excluir, vincular), usada pela API e pela tela.
    super: pode tudo. Demais: precisa ser ADMIN ativo, estar numa empresa
    (sessao) e o alvo -- se houver -- nao pode ser o super nem ter vinculo
    com OUTRA empresa (o perfil e a senha sao globais: mexer num usuario
    compartilhado afetaria empresas fora do alcance de quem pede).
    @type Funcao de seguranca
    @author Peder Munksgaard
    @since 02/10/2026
    @param cUsuario   Quem pede
    @param cAlvo      Usuario afetado ("" = acao sem alvo, ex.: criar)
    @param lExigeVinc .T. = alvo tem de ser vinculado a empresa da sessao
    @return .T. se pode
/*/
User Function GEBSECPODE(cUsuario, cAlvo, lExigeVinc)
    Local cEmp := GEBDBTenantAtual()
    Local cAlv := AllTrim(cValToChar(cAlvo))
    If cUsuario == Nil
        Return .F.
    EndIf
    If GEBSECISSUPER(cUsuario)
        Return .T.
    EndIf
    If cEmp == ""
        Return .F.
    EndIf
    If Len(TCSqlQuery("SELECT GE2_EMP_USUARIO FROM GE2_EMP WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cUsuario) + " AND LOWER(TRIM(GE2_EMP_EMPRESA)) = " + GEBDBQuote(cEmp) + " AND UPPER(TRIM(GE2_EMP_PERFIL)) = 'ADMIN' AND D_E_L_E_T_ = ' '")) == 0
        Return .F.
    EndIf
    If cAlv == "" .Or. cAlvo == Nil
        Return .T.
    EndIf
    If GEBSECISSUPER(cAlv)
        Return .F.
    EndIf
    If Len(TCSqlQuery("SELECT GE2_EMP_USUARIO FROM GE2_EMP WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cAlv) + " AND LOWER(TRIM(GE2_EMP_EMPRESA)) <> " + GEBDBQuote(cEmp) + " AND D_E_L_E_T_ = ' ' LIMIT 1")) > 0
        Return .F.
    EndIf
    If lExigeVinc != Nil .And. lExigeVinc
        If Len(TCSqlQuery("SELECT GE2_EMP_USUARIO FROM GE2_EMP WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cAlv) + " AND LOWER(TRIM(GE2_EMP_EMPRESA)) = " + GEBDBQuote(cEmp) + " AND D_E_L_E_T_ = ' ' LIMIT 1")) == 0
            Return .F.
        EndIf
    EndIf
Return .T.

// GEBSECDERRUBA(cUsu) -> invalida as sessoes (tokens) abertas do usuario:
// troca de senha por outra pessoa costuma responder a comprometimento.
User Function GEBSECDERRUBA(cUsu)
Return TCSqlExec("UPDATE GE2_TOK SET D_E_L_E_T_ = '*' WHERE TOK_USUARIO = " + GEBDBQuote(cUsu) + " AND D_E_L_E_T_ = ' '")

/*/{Protheus.doc} GEBSECISSUPER
    Diz se o codigo e' a conta global super (case-insensitive).
    @type Helper
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsu Codigo do usuario
    @return .T. se for super
/*/
User Function GEBSECISSUPER(cUsu)
    If cUsu == Nil
        Return .F.
    EndIf
Return (Upper(AllTrim(cValToChar(cUsu))) == "SUPER")

User Function GEBSECCRIAUSU(cUsu, cSenha, aEmpresas, cNome, cPerfil, lPermiteSuper, cFilial)
    Local aArea  := GetArea()
    Local lOk    := .T.
    Local cFil   := ""
    Local cSalt  := ""
    Local cHash  := ""
    Local cEmpC  := ""
    Local aEmps  := {}
    Local aHit   := {}
    Local nI     := 0
    Local cToday := DToS(Date())
    Local aPol   := {}
    Local cFilP  := ""

    If cSenha == Nil
        cSenha := ""
    EndIf
    If aEmpresas == Nil
        aEmpresas := {}
    EndIf
    If cPerfil == Nil
        cPerfil := "USUARIO"
    EndIf
    If ValType(lPermiteSuper) != "L"
        lPermiteSuper := .F.
    EndIf

    // 1. Validacao completa ANTES de qualquer escrita.
    If !GEBDBSchemaValido(cUsu)
        ConOut("GEBSECCRIAUSU: codigo de usuario invalido")
        lOk := .F.
    EndIf
    // Guarda ADMIN: evita reset/desbloqueio acidental da conta
    // administrativa por um chamador que nao percebeu que cUsu e' ADMIN.
    // Checagem em If separado (sem .And./.Or., que nao fazem
    // curto-circuito neste runtime).
    If lOk
        If GEBSECISSUPER(cUsu)
            If !lPermiteSuper
                ConOut("GEBSECCRIAUSU: alteracao da conta super exige lPermiteSuper:=.T. explicito")
                lOk := .F.
            EndIf
        EndIf
    EndIf
    // Obs.: .And./.Or. NAO fazem curto-circuito neste runtime (AdvPP
    // compila para OP_AND/OP_OR avaliando os dois lados) -- checagens
    // de tipo ficam em If aninhado antes de usar o valor.
    If lOk
        cUsu := AllTrim(cUsu)
        If ValType(cNome) != "C"
            cNome := cUsu
        EndIf
        If AllTrim(cNome) == ""
            cNome := cUsu
        EndIf
        cNome := AllTrim(cNome) // escapado por GEBDBQuote na montagem do SQL
        If ValType(cPerfil) != "C"
            cPerfil := "USUARIO"
        EndIf
        cPerfil := Upper(AllTrim(cPerfil))
        If !GEBDBSchemaValido(cPerfil)
            ConOut("GEBSECCRIAUSU: perfil invalido")
            lOk := .F.
        EndIf
    EndIf
    If lOk
        If ValType(cSenha) != "C"
            ConOut("GEBSECCRIAUSU: senha invalida")
            lOk := .F.
        ElseIf AllTrim(cSenha) == ""
            ConOut("GEBSECCRIAUSU: senha vazia (ou so' espacos) nao e' permitida")
            lOk := .F.
        EndIf
    EndIf
    // Politica de senha (mesma regra de GEBRESTURLSC(), src/GEBREST.prw):
    // min 8 chars, 1 maiuscula, 1 minuscula, 1 digito, 1 especial, sem
    // sequencia/repeticao 3x.
    If lOk
        If cFilial == Nil
            cFilP := ""
        Else
            cFilP := Upper(AllTrim(cValToChar(cFilial)))
        EndIf
        If cFilP != ""
            If !GEBDBSchemaValido(cFilP)
                ConOut("GEBSECCRIAUSU: filial invalida")
                lOk := .F.
            EndIf
        EndIf
    EndIf
    If lOk
        aPol := GEBSECPOL_VERIFICA(cSenha)
        If Len(aPol) >= 2
            If !(aPol[1])
                ConOut("GEBSECCRIAUSU: senha reprovada na politica (" + cValToChar(aPol[2]) + ")")
                lOk := .F.
            EndIf
        EndIf
    EndIf
    If lOk
        If ValType(aEmpresas) != "A"
            ConOut("GEBSECCRIAUSU: aEmpresas deve ser um array")
            lOk := .F.
        EndIf
    EndIf
    If lOk
        For nI := 1 To Len(aEmpresas)
            If ValType(aEmpresas[nI]) != "C"
                ConOut("GEBSECCRIAUSU: codigo de empresa invalido na posicao " + cValToChar(nI))
                lOk := .F.
                Exit
            EndIf
            If !GEBDBSchemaValido(aEmpresas[nI])
                ConOut("GEBSECCRIAUSU: codigo de empresa invalido na posicao " + cValToChar(nI))
                lOk := .F.
                Exit
            EndIf
            cEmpC := Lower(AllTrim(aEmpresas[nI]))
            If !GEBDBSchemaExists(cEmpC)
                ConOut("GEBSECCRIAUSU: empresa " + cEmpC + " nao provisionada")
                lOk := .F.
                Exit
            EndIf
            AAdd(aEmps, cEmpC)
        Next nI
    EndIf
    If lOk
        cSalt := GEBSECSALT()
        If cSalt == ""
            ConOut("GEBSECCRIAUSU: falha ao gerar salt aleatorio")
            lOk := .F.
        EndIf
    EndIf
    If lOk
        cHash := HashSenha(cSenha, cSalt)
        If cHash == ""
            ConOut("GEBSECCRIAUSU: falha ao calcular hash da senha")
            lOk := .F.
        EndIf
    EndIf

    // 2. GE2: cria se nao existir. Filial explicita (cFilial) tem
    // precedencia: e' nela que a identidade (GE2/GE2_SEC/GE2_EMP) vive.
    // Sem parametro, mantem o comportamento anterior (linha existente
    // ou FWxFilial).
    If lOk
        aHit := TCSqlQuery("SELECT GE2_FILIAL FROM GE2 WHERE GE2_COD = " + GEBDBQuote(cUsu) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
        If cFilP != ""
            cFil := cFilP
            If Len(aHit) > 0
                // GE2 e' a fonte da filial da identidade: GE2_SEC e GE2_EMP seguem a mesma
                // filial. Sem essa atualizacao, GE2 e GE2_SEC ficavam divergentes.
                If cValToChar(aHit[1]:GE2_FILIAL) != cFilP
                    ConOut("GEBSECCRIAUSU: identidade " + cUsu + " passa a viver na filial " + cFilP)
                    lOk := TCSqlExec("UPDATE GE2 SET GE2_FILIAL = " + GEBDBQuote(cFilP) + " WHERE GE2_COD = " + GEBDBQuote(cUsu) + " AND D_E_L_E_T_ = ' '")
                    If !lOk
                        ConOut("GEBSECCRIAUSU: falha ao mover GE2 para a filial " + cFilP)
                    EndIf
                EndIf
            Else
                lOk := TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', " + GEBDBQuote(cFilP) + ", " + GEBDBQuote(cUsu) + ", " + GEBDBQuote(cNome) + ", " + GEBDBQuote(cPerfil) + ")")
                If !lOk
                    ConOut("GEBSECCRIAUSU: falha ao inserir GE2 na filial " + cFilP)
                EndIf
            EndIf
        Else
            If Len(aHit) > 0
                cFil := cValToChar(aHit[1]:GE2_FILIAL)
            Else
                cFil := FWxFilial("GE2")
                lOk := TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cUsu) + ", " + GEBDBQuote(cNome) + ", " + GEBDBQuote(cPerfil) + ")")
                If !lOk
                    ConOut("GEBSECCRIAUSU: falha ao inserir GE2 para " + cUsu)
                EndIf
            EndIf
        EndIf
    EndIf

    // 3. GE2_SEC: substitui credencial existente ou cria nova.
    If lOk
        aHit := TCSqlQuery("SELECT SEC_USUARIO FROM GE2_SEC WHERE SEC_FILIAL = " + GEBDBQuote(cFil) + " AND SEC_USUARIO = " + GEBDBQuote(cUsu) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
        If Len(aHit) > 0
            lOk := TCSqlExec("UPDATE GE2_SEC SET SEC_SALT = " + GEBDBQuote(cSalt) + ", SEC_HASH = " + GEBDBQuote(cHash) + ", SEC_FAILCNT = 0, SEC_LOCKED = '00000000', SEC_FORCE = 'N', SEC_PWDLAST = " + GEBDBQuote(cToday) + " WHERE SEC_FILIAL = " + GEBDBQuote(cFil) + " AND SEC_USUARIO = " + GEBDBQuote(cUsu) + " AND D_E_L_E_T_ = ' '")
        Else
            lOk := TCSqlExec("INSERT INTO GE2_SEC (D_E_L_E_T_, SEC_FILIAL, SEC_USUARIO, SEC_SALT, SEC_HASH, SEC_FAILCNT, SEC_LOCKED, SEC_LASTLOGIN, SEC_PWDLAST) VALUES (' ', " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cUsu) + ", " + GEBDBQuote(cSalt) + ", " + GEBDBQuote(cHash) + ", 0, '00000000', '00000000', " + GEBDBQuote(cToday) + ")")
        EndIf
        If !lOk
            ConOut("GEBSECCRIAUSU: falha ao gravar GE2_SEC para " + cUsu)
        EndIf
    EndIf

    // 4. GE2_EMP: um vinculo por empresa (sem duplicar).
    If lOk
        For nI := 1 To Len(aEmps)
            aHit := TCSqlQuery("SELECT GE2_EMP_USUARIO FROM GE2_EMP WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cUsu) + " AND GE2_EMP_EMPRESA = " + GEBDBQuote(aEmps[nI]) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
            If Len(aHit) == 0
                lOk := TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA, GE2_EMP_PERFIL) VALUES (' ', " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cUsu) + ", " + GEBDBQuote(aEmps[nI]) + ", " + GEBDBQuote(cPerfil) + ")")
            Else
                lOk := TCSqlExec("UPDATE GE2_EMP SET GE2_EMP_PERFIL = " + GEBDBQuote(cPerfil) + " WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cUsu) + " AND GE2_EMP_EMPRESA = " + GEBDBQuote(aEmps[nI]) + " AND D_E_L_E_T_ = ' '")
            EndIf
            If !lOk
                ConOut("GEBSECCRIAUSU: falha ao vincular " + cUsu + " a empresa " + aEmps[nI])
                Exit
            EndIf
        Next nI
    EndIf

    If lOk
        ConOut("GEBSECCRIAUSU: usuario " + cUsu + " provisionado (" + cValToChar(Len(aEmps)) + " empresa(s))")
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk
