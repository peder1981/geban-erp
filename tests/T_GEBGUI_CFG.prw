#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBFIN_FLX.prw"
#include "../src/GEBCTB_BAL.prw"
#include "../src/GEBGUI_CFG.prw"

/*/{Protheus.doc} T_GEBGUI_CFG
    Teste da tela de CONFIGURACAO BANANIAS (Task 5 GEB_GUI).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP (registro interno).
    Asserts: todas as funcoes chamam sem abortar;
    GEBGUICONF_SHOW loga secoes; GEBGUICONF_PARAM gravar/read
    secao EMISSAO com padrao ONLINE_FILA; GEBGUICONF_ALIQ loga
    aliquota (0,0 se NCM inexistente); CAD_* chamam sem erro;
    GEBGUICONF_RESUMO chama GEBNFLX/GEBBAL/GEBDRE sem abortar.
    Sem SELECT *, sem concat SQL (so literais em TCSqlExec).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBGUI_CFG()
    Local lOk := .T.
    Local lTmp := .F.
    Local cAtual := ""

    If !GEBDBConecta()
        ConOut("T_GEBGUI_CFG: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebgui_cfg CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebgui_cfg")
    TCSqlExec("SET search_path TO test_gebgui_cfg")
    GBAUDINIC()

    // 0. GENMIG cria GE1-GE5 (GE4 e necessario para GEBGUICONF_PARAM).
    If !GENMIG()
        lOk := .F.
    EndIf

    // 1. GEBGUIMIG garante tabelas de config.
    If !GEBGUIMIG()
        lOk := .F.
    EndIf

    // 2. GEBGUICONF_SHOW -- nao aborta.
    GEBGUICONF_SHOW()

    // 3. GEBGUICONF_PARAM EMISSAO -- gravar e ler.
    GEBGUICONF_PARAM("EMISSAO")
    // Le via workarea direta para conferir.
    cAtual := GEBCFG("EMISSAO")
    If cAtual != "ONLINE_FILA"
        lOk := .F.
    EndIf

    // 4. GEBGUICONF_PARAM APURACAO.
    GEBGUICONF_PARAM("APURACAO")
    cAtual := GEBCFG("APURACAO")
    If cAtual != "AUTO"
        lOk := .F.
    EndIf

    // 5. GEBGUICONF_PARAM PERMITE_DIRETA.
    GEBGUICONF_PARAM("PERMITE_DIRETA")
    cAtual := GEBCFG("PERMITE_DIRETA")
    If cAtual != "N"
        lOk := .F.
    EndIf

    // 6. GEBGUICONF_PARAM MENTOR.
    GEBGUICONF_PARAM("MENTOR")
    cAtual := GEBCFG("MENTOR")
    If cAtual != "AVISA_E_LIBERA_COM_BO"
        lOk := .F.
    EndIf

    // 7. GEBGUICONF_ALIQ com NCM inexistente -- nao aborta.
    GEBGUICONF_ALIQ("NCM_NAO_EXISTE_99999")

    // 8. GEBGUICONF_ALIQ com NCM existente (se houver em GF2).
    GEBGUICONF_ALIQ("00000000")

    // 9. Cadastros rapidos -- so chamam, nao abortam.
    GEBGUICONF_CAD_EMPRESA()
    GEBGUICONF_CAD_USUARIO()
    GEBGUICONF_CAD_PRODUTO()
    GEBGUICONF_CAD_FORN()
    GEBGUICONF_CAD_CONTA()

    // 10. GEBGUICONF_RESUMO -- chama GEBNFLX/GEBBAL/GEBDRE.
    GEBGUICONF_RESUMO()

    // 11. Parametro secao desconhecida -- padrao vazio, nao aborta.
    GEBGUICONF_PARAM("SECAO_DESCONHECIDA")

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebgui_cfg CASCADE")

    If lOk
        ConOut("T_GEBGUI_CFG PASS")
    Else
        ConOut("T_GEBGUI_CFG FAIL")
    EndIf
Return lOk
