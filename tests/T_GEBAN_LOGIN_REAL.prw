#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBMON.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBEXP_CTX.prw"
#include "../src/GEBEXP_REL_BIZ.prw"
#include "../src/GEBEXP_REL_NUC.prw"
#include "../src/GEBEXP_WEB.prw"
#include "../src/GEBGUI_MAIN.prw"
#include "../src/GEBAN.prw"

/*/{Protheus.doc} T_GEBAN_LOGIN_REAL
    Prova que GEBAN() com credenciais reais faz login de ponta a ponta
    contra Postgres real (Task 5, fecha o ciclo das Tasks 1-4): autentica
    em nivel de catalogo (GEBSECLOGIN, Argon2id real), valida vinculo
    usuario-empresa (GE2_EMP), confirma schema provisionado
    (GEBDBSchemaExists), seleciona o tenant (GEBDBSetTenant) e so entao
    registra a sessao (GEBEXPCONTEXTO).
    Arquivo separado de T_GEBAN_SMOKE.prw porque o smoke test so cobre o
    caminho sem credenciais (menu terminal); este cobre o caminho de
    login real que so passou a funcionar de ponta a ponta nesta task.
    GEBAN() retorna .T. tanto no login real quanto no fallback de menu
    terminal (credenciais invalidas) -- por isso o teste nao confia so
    no retorno: tambem verifica GEBEXPIST() == .T. apos a chamada, que
    so acontece quando GEBEXPCONTEXTO() de fato rodou (caminho real).
    Empresa descartavel "zzloginreal" (schema emp_zzloginreal), usuario
    de teste T_LOGINREAL em GE2/GE2_SEC/GE2_EMP (catalogo, schema
    public -- GEBDBProvisionaCatalogo() forca search_path para public).
    Caso negativo adicional (Task 2, plano fase2-gaps, 2026-09-25):
    terceira empresa real "zzwrongfil" com linha GE2_EMP ligando
    (T_LOGINREAL, zzwrongfil) mas com GE2_EMP_FILIAL = "999999",
    diferente da filial que GEBAN() realmente usa no gate de vinculo
    (FWxFilial("GE1")) -- prova que o filtro por GE2_EMP_FILIAL (recem
    adicionado) rejeita um vinculo que so' bate USUARIO+EMPRESA. Antes
    dessa correcao o filtro antigo aceitaria essa linha e autenticaria
    indevidamente.
    Caso negativo adicional (fix round 1, achado CRITICAL do reviewer;
    CORRIGIDO no fix round 2 -- ver nota abaixo): um segundo codigo de
    empresa "zznomemb" -- desta vez PROVISIONADO DE VERDADE via
    GEBDBProvisionaEmpresa() (schema emp_zznomemb existe de fato) mas SEM
    linha GE2_EMP vinculando T_LOGINREAL a ele -- prova que GEBAN(cEmpresa,
    cUsuario, cSenha) com senha REAL, empresa REALMENTE provisionada, mas
    sem vinculo GE2_EMP nao cria sessao, fechando o caminho que permitia
    entrar em outra empresa via GEBAN() sem checar GE2_EMP (o teste
    anterior so chamava GEBSECLOGIN() direto, que nunca exercitava essa
    checagem).
    NOTA DE CORRECAO (fix round 2): a versao do fix round 1 deste teste
    deixava "zznomemb" SEM provisionar, o que tornava o caso negativo
    incapaz de distinguir "o gate GE2_EMP rejeitou corretamente" de "o
    gate GE2_EMP foi apagado/quebrado silenciosamente" -- porque
    GEBDBSchemaExists("zznomemb"), o passo IMEDIATAMENTE POSTERIOR ao
    gate de vinculo em GEBAN(), ja rejeitaria a empresa nao-provisionada
    independentemente do que o gate de vinculo tivesse feito. A asserção
    original (GEBDBTableExistsHere("GEX")) tambem checava o schema
    ERRADO: no momento em que ela rodava, o search_path ja tinha voltado
    para "public" (a tentativa de login nunca chegou a selecionar o
    tenant), e GEX so existe dentro do schema emp_<cod> de uma empresa
    -- nunca em "public" -- entao o `If` em que essa asserção estava
    nunca sequer avaliava verdadeiro, e a checagem era silenciosamente
    pulada. Corrigido: agora "zznomemb" E' provisionado de verdade (o
    schema emp_zznomemb EXISTE), entao GEBDBSchemaExists("zznomemb")
    retornaria .T. -- o gate GE2_EMP DENTRO DE GEBAN() e' o unico que
    barra ANTES de GEBDBSetTenant()/GBAUDINIC()/GEBMONINIC() rodarem.
    ACHADO EMPIRICO ADICIONAL (descoberto verificando o teste
    empiricamente, como pedido pelo reviewer -- comentar o gate de
    GEBAN() e confirmar que o teste falha): GEBEXPCONTEXTO()
    (src/GEBEXP_CTX.prw) faz sua PROPRIA checagem independente de
    GE2_EMP antes de gravar em GEX -- defesa em profundidade real. Isso
    significa que checar so' a ausencia de GEX nao provaria que o gate
    de GEBAN() especificamente funciona (o teste passaria mesmo com
    esse gate inteiramente removido, porque GEBEXPCONTEXTO() bloquearia
    de qualquer forma). Por isso a asserção principal verifica a
    AUSENCIA de GEI_AUDIT (criada por GBAUDINIC(), que roda logo apos o
    gate de GEBAN() e MUITO antes de GEBEXPCONTEXTO() ser sequer
    chamado) em emp_zznomemb, com qualificador de schema EXPLICITO
    (pg_tables WHERE schemaname = 'emp_zznomemb') -- essa tabela so
    aparece se GEBDBSetTenant(cCod2) rodou, que por sua vez so roda se o
    gate GE2_EMP de GEBAN() deixar passar. GEX continua checada tambem
    (segunda camada, prova a invariante fim-a-fim). Verificado
    empiricamente: gate de GEBAN() comentado -> GEI_AUDIT apareceu em
    emp_zznomemb -> teste FALHOU (corretamente; GEX continuou ausente
    por causa da checagem redundante em GEBEXPCONTEXTO()); gate
    restaurado -> teste PASSOU (ver relatorio da task, secao "Fix Round
    2").
    IMPORTANTE sobre GEBEXPIST() e sobre a ORDEM dos casos: o reviewer
    original sugeriu verificar GEBEXPIST() == .F. apos a chamada
    negativa. Descoberto durante o desenvolvimento do fix round 1 (dois
    problemas reais de runtime AdvPP/TOPCONN, ambos alheios a esta
    correcao, fora de escopo, nao investigados a fundo):
    (1) chamar GEBAN() pela segunda vez no mesmo processo DEPOIS de uma
    chamada bem-sucedida que renderizou o dashboard GEBEXP_WEB (o qual
    abre/fecha a workarea GCP1) disparou um erro tardio e' nao
    relacionado ("table GCP1 not found") logo no inicio da segunda
    chamada -- por isso o caso negativo roda ANTES do login real
    bem-sucedido neste teste, nao depois;
    (2) GEBEXPIST() usa workarea (DbSelectArea) sobre a tabela GEX, e
    essa camada demonstrou (empiricamente, reproduzido) manter estado
    indevido entre chamadas quando a mesma alias "GEX" e' reaberta
    contra schemas DIFERENTES dentro do mesmo processo -- por isso a
    asserção do caso negativo verifica a MESMA invariante que
    GEBEXPIST() checa (linha ativa em GEX, D_E_L_E_T_ = ' ') via SQL
    direto (TCSqlQuery) em vez de abrir a workarea; o caso positivo
    (login real) continua usando GEBEXPIST() normalmente, como sugerido
    pelo reviewer, ja que e' a UNICA vez que essa workarea e' aberta
    neste processo.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 2026-09-24
    @return .T. se login real + sessao ativa forem confirmados, .F. caso
            contrario
/*/
User Function T_GEBAN_LOGIN_REAL()
    Local lOk := .T.
    Local lTmp := .F.
    Local cCod := "zzloginreal"
    Local cNome := "Empresa Teste Login Real"
    Local cCod2 := "zznomemb"
    Local cNome2 := "Empresa Teste Sem Vinculo"
    Local cCod3 := "zzwrongfil"
    Local cNome3 := "Empresa Teste Filial Errada"
    Local cFil := ""
    Local cUsu := "T_LOGINREAL"
    Local cSenha := "senhaReal123"
    Local cSalt := "SALTREAL01"
    Local cHash := ""

    If !GEBDBConecta()
        ConOut("T_GEBAN_LOGIN_REAL: FALHA GEBDBConecta")
        Return .F.
    EndIf

    TCSqlExec("SET search_path TO public")
    // Catalogo antes da limpeza: num banco vazio o DELETE abaixo numa
    // tabela inexistente derruba o programa (erro de TCSqlExec e' fatal).
    GEBDBProvisionaCatalogo()
    TCSqlExec("SET search_path TO public")

    // Limpeza de execucao anterior (idempotencia). cCod2 ("zznomemb")
    // AGORA e' provisionado de verdade (fix round 2 -- ver doc-comment
    // acima) -- tambem precisa ter seu schema dropado na limpeza, igual
    // cCod.
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod + " CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod2 + " CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod3 + " CASCADE")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod + "'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod2 + "'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod3 + "'")

    // Catalogo (GE1/GE2/seguranca) em schema public.
    If !GEBDBProvisionaCatalogo()
        lOk := .F.
        ConOut("T_GEBAN_LOGIN_REAL: FALHA GEBDBProvisionaCatalogo")
    EndIf

    // Provisiona a SEGUNDA empresa real primeiro (schema emp_zznomemb
    // EXISTE de verdade ao final desta chamada) -- fix round 2: sem
    // isso, GEBDBSchemaExists("zznomemb") dentro de GEBAN() rejeitaria a
    // empresa antes mesmo do gate de vinculo GE2_EMP ser exercitado,
    // tornando o caso negativo abaixo incapaz de provar que o gate
    // GE2_EMP especificamente e' o que bloqueia (ver doc-comment).
    // Nenhuma linha GE2_EMP e' criada para (cUsu, cCod2) -- essa
    // ausencia e' o proprio cenario negativo.
    If lOk .AND. !GEBDBProvisionaEmpresa(cCod2, cNome2)
        lOk := .F.
        ConOut("T_GEBAN_LOGIN_REAL: FALHA GEBDBProvisionaEmpresa(" + cCod2 + ")")
    EndIf
    TCSqlExec("SET search_path TO public")

    // Terceira empresa real (schema emp_zzwrongfil EXISTE de verdade):
    // prova especificamente que GE2_EMP_FILIAL agora entra no filtro do
    // gate de vinculo (Task 2, plano fase2-gaps). Diferente de cCod2
    // (SEM nenhuma linha GE2_EMP), para cCod3 a linha GE2_EMP VAI
    // existir mais abaixo, ligando (cUsu, cCod3) -- so' que com
    // GE2_EMP_FILIAL diferente da filial que GEBAN() realmente usa
    // (FWxFilial("GE1")). Filtro antigo (so USUARIO+EMPRESA) teria
    // aceitado essa linha; o filtro novo deve rejeitar.
    If lOk .AND. !GEBDBProvisionaEmpresa(cCod3, cNome3)
        lOk := .F.
        ConOut("T_GEBAN_LOGIN_REAL: FALHA GEBDBProvisionaEmpresa(" + cCod3 + ")")
    EndIf
    TCSqlExec("SET search_path TO public")

    // Provisiona empresa real (schema emp_zzloginreal) -- cria as
    // tabelas de negocio e registra a empresa em GE1 (public).
    If lOk .AND. !GEBDBProvisionaEmpresa(cCod, cNome)
        lOk := .F.
        ConOut("T_GEBAN_LOGIN_REAL: FALHA GEBDBProvisionaEmpresa")
    EndIf

    // GEBDBProvisionaEmpresa() deixa search_path em emp_<cod>,public;
    // volta para public para semear as tabelas de catalogo diretamente.
    TCSqlExec("SET search_path TO public")

    If lOk
        cFil := FWxFilial("GE2")
        cHash := HashSenha(cSenha, cSalt)

        TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '" + cFil + "', '" + cUsu + "', 'Usuario Login Real', 'ADMIN')")
        TCSqlExec("INSERT INTO GE2_SEC (D_E_L_E_T_, SEC_FILIAL, SEC_USUARIO, SEC_SALT, SEC_HASH, SEC_FAILCNT, SEC_LOCKED, SEC_LASTLOGIN, SEC_PWDLAST) VALUES (' ', '" + cFil + "', '" + cUsu + "', '" + cSalt + "', '" + cHash + "', 0, '00000000', '00000000', '" + DToS(Date()) + "')")
        TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA) VALUES (' ', '" + cFil + "', '" + cUsu + "', '" + cCod + "')")

        // Vinculo GE2_EMP para cCod3, deliberadamente com FILIAL
        // DIFERENTE ("999999") da filial que GEBAN() realmente usa na
        // query de vinculo (FWxFilial("GE1"), sempre "" neste processo
        // de teste -- nenhum RpcSetEnv foi chamado). Antes da correcao
        // desta task, esta linha teria casado no filtro (so
        // USUARIO+EMPRESA) e GEBAN(cCod3, cUsu, cSenha) teria autenticado
        // indevidamente.
        TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA) VALUES (' ', '999999', '" + cUsu + "', '" + cCod3 + "')")
    EndIf

    // === ASSERT (roda ANTES do login real -- ver nota no doc-comment
    // sobre a ordem): usuario autenticado (senha real), empresa
    // REALMENTE provisionada (schema emp_zznomemb existe), mas SEM
    // vinculo GE2_EMP com a empresa alvo NAO consegue sessao via
    // GEBAN() === (achado CRITICAL do reviewer original: antes da
    // correcao do fix round 1, um cUsu malicioso conseguia forjar a
    // clausula SQL da query GE2_EMP e entrar em qualquer empresa; a
    // correcao valida o FORMATO de cUsu -- GEBDBSchemaValido -- antes
    // de tudo. Fix round 2: como cCod2 agora E' provisionado de
    // verdade, este caso prova especificamente o GATE DE VINCULO
    // GE2_EMP -- e nao a checagem de schema, que teria rejeitado de
    // qualquer forma se a empresa nao existisse).
    If lOk
        lTmp := GEBAN(cCod2, cUsu, cSenha)
        If !lTmp
            lOk := .F.
            ConOut("FAIL: GEBAN(" + cCod2 + "," + cUsu + ",<senha>) retornou .F. (esperado .T., fallback menu terminal)")
        EndIf
    EndIf

    // Verifica que o gate de vinculo GE2_EMP em GEBAN() especificamente
    // barrou a chamada -- NAO checa apenas GEX (ver nota abaixo sobre
    // achado empirico de defesa em profundidade).
    // Qualificador de schema EXPLICITO em toda query (pg_tables WHERE
    // schemaname = 'emp_zznomemb'), independente do search_path atual
    // do processo -- diferente da versao anterior deste teste, que
    // usava GEBDBTableExistsHere() (relativo ao search_path atual) e
    // por isso nunca checava o schema certo.
    // ACHADO EMPIRICO (fix round 2, durante a verificacao pedida pelo
    // reviewer -- comentar o gate e confirmar que o teste falha):
    // GEBEXPCONTEXTO() (src/GEBEXP_CTX.prw:61) tambem faz sua PROPRIA
    // checagem independente de GE2_EMP antes de gravar em GEX. Isso
    // significa que checar so' a AUSENCIA de GEX nao prova que o gate de
    // GEBAN() especificamente e' o que bloqueia -- o teste passaria
    // mesmo com o gate de GEBAN() completamente removido, porque
    // GEBEXPCONTEXTO() bloquearia de qualquer forma (defesa em
    // profundidade real, confirmada rodando o teste com o gate de
    // GEBAN() comentado: GEX nunca chegou a existir em emp_zznomemb,
    // mas GEI_AUDIT e SEC_MON SIM foram criadas la, porque
    // GBAUDINIC()/GEBMONINIC() rodam ANTES de GEBEXPCONTEXTO() em
    // GEBAN() e nao dependem dele). Por isso a asserção real deste teste
    // e' a AUSENCIA de GEI_AUDIT (criada por GBAUDINIC(), a primeira
    // coisa que roda DEPOIS do gate GE2_EMP de GEBAN() e ANTES de
    // GEBEXPCONTEXTO() ser sequer chamado) -- essa tabela so aparece em
    // emp_zznomemb se GEBDBSetTenant(cCod2) rodou, que por sua vez so
    // roda se o gate GE2_EMP de GEBAN() deixar passar. Confirmado
    // empiricamente: gate de GEBAN() comentado -> GEI_AUDIT apareceu em
    // emp_zznomemb -> este assert FALHOU (corretamente); gate
    // restaurado -> GEI_AUDIT ausente -> PASS (ver relatorio da task,
    // secao "Fix Round 2"). GEX continua checada tambem, como segunda
    // camada (prova a invariante fim-a-fim: nenhuma sessao de negocio
    // foi de fato aberta).
    If lOk
        If Len(TCSqlQuery("SELECT tablename FROM pg_tables WHERE schemaname = 'emp_" + cCod2 + "' AND tablename = 'gei_audit'")) > 0
            lOk := .F.
            ConOut("FAIL: tabela GEI_AUDIT existe em emp_" + cCod2 + " apos GEBAN(" + cCod2 + ",...) sem vinculo GE2_EMP -- GEBDBSetTenant/GBAUDINIC rodaram indevidamente (gate GE2_EMP de GEBAN() nao bloqueou)")
        EndIf
    EndIf
    If lOk
        If Len(TCSqlQuery("SELECT tablename FROM pg_tables WHERE schemaname = 'emp_" + cCod2 + "' AND tablename = 'gex'")) > 0
            lOk := .F.
            ConOut("FAIL: tabela GEX existe em emp_" + cCod2 + " apos GEBAN(" + cCod2 + ",...) sem vinculo GE2_EMP -- sessao foi criada indevidamente")
        EndIf
    EndIf

    // === ASSERT (Task 2, plano fase2-gaps): usuario autenticado (senha
    // real), empresa REALMENTE provisionada (schema emp_zzwrongfil
    // existe), e COM linha GE2_EMP ligando (cUsu, cCod3) -- mas com
    // GE2_EMP_FILIAL diferente da filial que GEBAN() usa na query de
    // vinculo. Prova que o filtro por filial especificamente bloqueia
    // (nao so' a ausencia de linha, caso ja coberto por cCod2 acima).
    // Mesma logica de asserção do caso cCod2: AUSENCIA de GEI_AUDIT em
    // emp_zzwrongfil, com qualificador de schema explicito.
    If lOk
        lTmp := GEBAN(cCod3, cUsu, cSenha)
        If !lTmp
            lOk := .F.
            ConOut("FAIL: GEBAN(" + cCod3 + "," + cUsu + ",<senha>) retornou .F. (esperado .T., fallback menu terminal)")
        EndIf
    EndIf
    If lOk
        If Len(TCSqlQuery("SELECT tablename FROM pg_tables WHERE schemaname = 'emp_" + cCod3 + "' AND tablename = 'gei_audit'")) > 0
            lOk := .F.
            ConOut("FAIL: tabela GEI_AUDIT existe em emp_" + cCod3 + " apos GEBAN(" + cCod3 + ",...) com GE2_EMP_FILIAL divergente -- gate de vinculo nao filtrou por filial")
        EndIf
    EndIf
    If lOk
        If Len(TCSqlQuery("SELECT tablename FROM pg_tables WHERE schemaname = 'emp_" + cCod3 + "' AND tablename = 'gex'")) > 0
            lOk := .F.
            ConOut("FAIL: tabela GEX existe em emp_" + cCod3 + " apos GEBAN(" + cCod3 + ",...) com GE2_EMP_FILIAL divergente -- sessao foi criada indevidamente")
        EndIf
    EndIf

    // === ASSERT: login real com credenciais validas ===
    If lOk
        lTmp := GEBAN(cCod, cUsu, cSenha)
        If !lTmp
            lOk := .F.
            ConOut("FAIL: GEBAN(" + cCod + "," + cUsu + ",<senha>) retornou .F.")
        EndIf
    EndIf

    // Distingue login real de fallback "menu terminal": GEBAN() retorna
    // .T. nos dois casos, mas GEBEXPIST() so' fica .T. quando
    // GEBEXPCONTEXTO() de fato rodou (caminho de login real). Primeira
    // (e unica) vez que a workarea GEX e' aberta neste processo --
    // seguro quanto ao bug de cache cross-schema descrito no
    // doc-comment.
    // If aninhado, NAO "lOk .AND. !GEBEXPIST()": .AND. em AdvPL/Clipper
    // NAO e' curto-circuito (avalia os dois lados sempre) -- se lOk ja
    // estiver .F. neste ponto (ex.: um FAIL anterior), GEBEXPIST()
    // ainda assim seria chamada e tentaria abrir a workarea GEX antes
    // dela ter sido criada por qualquer chamada de GEBAN() bem-sucedida,
    // quebrando com "Error: table GEX not found" (confirmado
    // empiricamente durante a verificacao do fix round 2, com o gate
    // GE2_EMP de GEBAN() comentado -- o FAIL anterior deixava lOk .F. e
    // esta linha crashava o teste em vez de so reportar FAIL).
    If lOk
        If !GEBEXPIST()
            lOk := .F.
            ConOut("FAIL: GEBEXPIST() retornou .F. apos GEBAN() com credenciais validas -- login real nao ocorreu (caiu no fallback)")
        EndIf
    EndIf

    // === ASSERT: senha errada NAO autentica (GEBSECLOGIN direto, sem
    // passar por GEBAN()/GEBGUIMAIN() -- o menu terminal interativo
    // (ConIn()) nao e' seguro de exercitar num run nao-interativo).
    // Mantem search_path como GEBAN() deixou (emp_<cod>,public):
    // GE2/GE2_SEC sao resolvidos via o "public" no fallback do
    // search_path, GEBSECLOGIN() nao depende do tenant selecionado. ===
    If GEBSECLOGIN(cUsu, "senhaErrada", "local") == "OK"
        lOk := .F.
        ConOut("FAIL: GEBSECLOGIN aceitou senha errada para " + cUsu)
    EndIf

    // === CLEANUP ===
    // GEBEXPCLEAR() primeiro, ainda com emp_<cod> no search_path (GEX
    // vive no schema da empresa); so depois volta para public.
    GEBEXPCLEAR()
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod + "'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod2 + "'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod3 + "'")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod + " CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod2 + " CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod3 + " CASCADE")

    If lOk
        ConOut("T_GEBAN_LOGIN_REAL PASS")
    Else
        ConOut("T_GEBAN_LOGIN_REAL FAIL")
    EndIf
Return lOk
