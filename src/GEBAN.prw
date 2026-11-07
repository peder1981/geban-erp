#include "totvs.ch"
#include "GENUC_MIG.prw"
#include "GEBDB_TENANT.prw"
#include "GEBMON.prw"
#include "GEBGUI_MAIN.prw"
#include "GEBEXP_MIG.prw"
#include "GEBSEC_MIG.prw"
#include "GEBSEC_LOGIN.prw"
#include "GEBAUD.prw"
#include "GEBEXP_CTX.prw"
#include "GEBEXP_WEB.prw"

/*/{Protheus.doc} GEBAN
    Entrada principal do ERP Bananias.
    Ordem de inicializacao:
    1. GEBDBConecta() - conexao Postgres
    2. GEBDBProvisionaCatalogo() - catalogo global (GE1-GE2, seguranca)
    3. Autenticacao e selecao de empresa -- so roda quando cEmpresa/
       cUsuario/cSenha foram todos informados; NENHUM tenant e'
       selecionado antes disto (ver nota de seguranca abaixo):
       valida formato de cUsuario (GEBDBSchemaValido) -> autentica
       (GEBSECLOGIN, nivel de catalogo) -> verifica vinculo (GE2_EMP)
       -> verifica schema provisionado (GEBDBSchemaExists) -> seleciona
       tenant (GEBDBSetTenant) -> GBAUDINIC() -> GEBMONINIC() ->
       GEBEXPCONTEXTO() registra sessao.
    4. GEBEXP_WEB() (login real) ou GEBGUIMAIN() (sem credenciais ou
       credenciais invalidas -- menu terminal, sem tenant selecionado).
    @type Entrada principal
    @author Peder Munksgaard
    @since 23/09/2026
/*/
User Function GEBAN(cEmpresa, cUsuario, cSenha, cModo)
    Local aArea := GetArea()
    Local lOk := .F.
    Local cEmp := ""
    Local cUsu := ""
    Local cSen := ""
    Local cMod := ""
    Local lTmp := .F.
    Local aChk := {}
    Local cFilChk := ""

    If cEmpresa == Nil
        cEmp := ""
    Else
        cEmp := AllTrim(cEmpresa)
    EndIf
    If cUsuario == Nil
        cUsu := ""
    Else
        cUsu := AllTrim(cUsuario)
    EndIf
    If cSenha == Nil
        cSen := ""
    Else
        cSen := AllTrim(cSenha)
    EndIf
    If cModo == Nil
        cMod := "MENU"
    Else
        cMod := Upper(AllTrim(cModo))
    EndIf

    ConOut("=== GEBAN Iniciando ===")
    
    // 1. Conexao Postgres
    If !GEBDBConecta()
        ConOut("ERRO: GEBDBConecta falhou")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    ConOut("OK: GEBDBConecta")

    // 2. Catalogo (public: GE1/GE2 + seguranca)
    If !GEBDBProvisionaCatalogo()
        ConOut("ERRO: GEBDBProvisionaCatalogo falhou")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    ConOut("OK: GEBDBProvisionaCatalogo")

    // 3. Autenticacao + selecao de empresa + contexto de sessao.
    // Seguranca: NADA de tenant/auditoria/monitor roda antes deste
    // bloco. cUsu E cEmp tem o FORMATO validado (GEBDBSchemaValido --
    // mesma checagem, alfanumerico + underscore, ate 30 chars) ANTES de
    // qualquer coisa, inclusive antes de chamar GEBSECLOGIN(): tanto
    // cUsu quanto cEmp sao concatenados direto em SQL na query GE2_EMP
    // abaixo (e cEmp tambem em GEBSECLOGIN()/GEBEXPCONTEXTO(), fora de
    // escopo desta correcao) -- sem essa validacao um valor malicioso em
    // qualquer um dos dois quebraria a clausula da query GE2_EMP e
    // permitiria autenticar como "eu mesmo" mas ser tratado como
    // vinculado a QUALQUER empresa. Falha de formato (de cUsu OU de
    // cEmp) cai no mesmo fallback generico "credenciais invalidas"
    // usado para senha errada / sem vinculo / schema inexistente -- nao
    // ha mensagem diferenciada, para nao virar oraculo de enumeracao de
    // usuario. Note que GEBDBSchemaExists()/GEBDBSetTenant() tambem
    // validam cEmp internamente (GEBDBSchemaValido), mas so' rodam
    // DEPOIS da query GE2_EMP -- validar cEmp aqui fecha o gap antes que
    // ele chegue a SQL nenhum.
    // Ordem depois do formato: GEBSECLOGIN() roda em nivel de catalogo
    // (autentica ANTES de saber/selecionar a empresa -- GEH ainda nao
    // existe nesse ponto, GEBSECLOGIN() ja tolera isso, ver
    // src/GEBSEC_LOGIN.prw). So depois de autenticado o codigo verifica
    // se o usuario pertence a empresa pedida (GE2_EMP) e se a empresa
    // foi provisionada (GEBDBSchemaExists) antes de trocar o
    // search_path -- e so' DEPOIS do search_path trocado e' que
    // GBAUDINIC()/GEBMONINIC() rodam (auditoria/monitor sao por-tenant,
    // nao fazem sentido -- nem devem ser criados -- antes de autenticar
    // e selecionar uma empresa).
    If cEmp != "" .AND. cUsu != "" .AND. cSen != ""
        If GEBDBSchemaValido(cUsu) .AND. GEBDBSchemaValido(cEmp)
            lTmp := (GEBSECLOGIN(cUsu, cSen, "local") == "OK")
        Else
            lTmp := .F.
        EndIf
        If lTmp
            // Filial usada na checagem de vinculo GE2_EMP: EXATAMENTE a
            // mesma que sera' passada a GEBEXPCONTEXTO() mais abaixo
            // (FWxFilial("GE1")) -- nao inventar outra fonte. Formato
            // validado (GEBDBSchemaValido) antes de entrar na string SQL;
            // filial vazia (sistema ainda sem RpcSetEnv/multi-filial) e'
            // o caso padrao e nao passa por validacao de formato, so' os
            // valores nao-vazios.
            cFilChk := FWxFilial("GE1")
            If AllTrim(cFilChk) != ""
                lTmp := GEBDBSchemaValido(cFilChk)
            EndIf
        EndIf
        If lTmp
            aChk := TCSqlQuery("SELECT * FROM GE2_EMP WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cUsu) + " AND GE2_EMP_EMPRESA = " + GEBDBQuote(Lower(cEmp)) + " AND GE2_EMP_FILIAL = " + GEBDBQuote(cFilChk) + " AND D_E_L_E_T_ = ' '")
            lTmp := (Len(aChk) > 0)
            If !lTmp
                If GEBSECISSUPER(cUsu)
                    lTmp := .T.
                EndIf
            EndIf
            If !lTmp
                ConOut("AVISO: usuario " + cUsu + " sem vinculo com empresa " + cEmp)
            EndIf
        EndIf
        If lTmp
            lTmp := GEBDBSchemaExists(cEmp)
            If !lTmp
                ConOut("AVISO: empresa " + cEmp + " nao provisionada")
            EndIf
        EndIf
        If lTmp
            lTmp := GEBDBSetTenant(cEmp)
        EndIf
        If lTmp
            GBAUDINIC()
            ConOut("OK: GBAUDINIC")
            GEBMONINIC()
            ConOut("OK: GEBMONINIC")
        EndIf
        If lTmp
            lTmp := GEBEXPCONTEXTO(cEmp, FWxFilial("GE1"), cUsu)
        EndIf
        If lTmp
            ConOut("OK: Sessao iniciada para " + cUsu + " em " + cEmp)
            If cMod == "CONFIG"
                GEBGUICONF_SHOW()
            Else
                GEBEXP_WEB(cEmp, cUsu)
            EndIf
            lOk := .T.
        Else
            ConOut("AVISO: credenciais invalidas - menu terminal")
            GEBGUIMAIN()
            lOk := .T.
        EndIf
    Else
        ConOut("INFO: sem credenciais - menu terminal")
        GEBGUIMAIN()
        lOk := .T.
    EndIf
    
    ConOut("=== GEBAN Finalizado ===")
    
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk
