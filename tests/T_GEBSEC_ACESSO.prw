#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBSEC_TOKEN.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBEXP_CTX.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBEXP_REL_BIZ.prw"
#include "../src/GEBEXP_REL_NUC.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIN_FLX.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBAUD.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBREST.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GEBWEB_API.prw"
#include "../src/GEBWEB.prw"
#include "../src/GEBTUI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBCTX.prw"
#include "../src/GEBEST.prw"
#include "../src/GEBFNX.prw"
#include "../src/GEBFAT.prw"
#include "../src/GEBTEF.prw"
#include "../src/GEBLOJ.prw"
#include "../src/GEBDFE_XML.prw"
#include "../src/GEBDFE_WS.prw"
#include "../src/GEBDFE_MUN.prw"
#include "../src/GEBDFE_IE.prw"
#include "../src/GEBDFE_CAD.prw"
#include "../src/GEBDFE.prw"
#include "../src/GEBDFE_QR.prw"
#include "../src/GEBDFE_DANFE.prw"
#include "../src/GEBLOJ_CAD.prw"
#include "../src/GEBLOJ_OPE.prw"
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBSEC_ACESSO
    Matriz de acesso da API (Fase 3 da revisao geral), pela camada HTTP
    real (GEBWAPI_*): escopo do ADMIN por empresa, leitura x escrita por
    perfil, exclusao de usuario revoga vinculos/credencial/tokens, token
    perde valor quando o vinculo some, todas as rotas autenticadas negam
    sem token e o super desbloqueia conta trocando a senha.
    Empresas descartaveis zzac1/zzac2.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 02/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBSEC_ACESSO()
    Local lOk    := .T.
    Local aUsu   := {"T_ACADM1", "T_ACVIT2", "T_ACOPE1", "T_ACALVO1", "t_acnovo", "super", "T_ACADM2"}
    Local cTokVit := ""
    Local aTroca := {}
    Local cTokAdm := ""
    Local cTokOpe := ""
    Local cTokAlv := ""
    Local cTokSup := ""
    Local oMock  := Nil
    Local aRet   := {}
    Local aChk   := {}
    Local aRotas := {}
    Local nI     := 0
    Local nNeg   := 0
    Local nJ     := 0

    If !GEBDBConecta()
        ConOut("T_GEBSEC_ACESSO FAIL")
        Return .F.
    EndIf
    GEBACLIMPA(aUsu)
    If !GEBDBProvisionaCatalogo() .Or. !GEBDBProvisionaEmpresa("zzac1", "Empresa AC1") .Or. !GEBDBProvisionaEmpresa("zzac2", "Empresa AC2")
        ConOut("T_GEBSEC_ACESSO FAIL")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    DbSelectArea("GE1")
    lOk := lOk .And. GEBSECCRIAUSU("T_ACADM1", "Senha#Forte1", {"zzac1"}, "Admin AC1", "ADMIN")
    lOk := lOk .And. GEBSECCRIAUSU("T_ACVIT2", "Senha#Forte1", {"zzac2"}, "Vitima AC2", "USUARIO")
    lOk := lOk .And. GEBSECCRIAUSU("T_ACOPE1", "Senha#Forte1", {"zzac1"}, "Operador AC1", "OPERADOR")
    lOk := lOk .And. GEBSECCRIAUSU("T_ACALVO1", "Senha#Forte1", {"zzac1"}, "Alvo AC1", "USUARIO")
    lOk := lOk .And. GEBSECCRIAUSU("super", "Senha#Forte1", {"zzac1", "zzac2"}, "Super", "ADMIN", .T.)
    lOk := lOk .And. GEBSECCRIAUSU("T_ACADM2", "Senha#Forte1", {"zzac2"}, "Admin AC2", "ADMIN")
    If !lOk
        ConOut("FAIL: setup de usuarios")
        ConOut("T_GEBSEC_ACESSO FAIL")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    DbSelectArea("GE1")
    GEBSECRBACADD("OPERADOR", "SEGURANCA", "USUARI", .T.)
    cTokAdm := GEBSECTOKEN("T_ACADM1", "zzac1", "", "t")
    cTokOpe := GEBSECTOKEN("T_ACOPE1", "zzac1", "", "t")
    cTokAlv := GEBSECTOKEN("T_ACALVO1", "zzac1", "", "t")
    cTokSup := GEBSECTOKEN("super", "zzac2", "", "t")
    cTokVit := GEBSECTOKEN("T_ACVIT2", "zzac2", "", "t")

    // C1) ADMIN da zzac1 nao exclui usuario da zzac2 -- e nada e' apagado.
    aRet := GEBACCALL("DEL", cTokAdm, "zzac1", "T_ACVIT2", Nil)
    aChk := TCSqlQuery("SELECT GE2_COD FROM public.GE2 WHERE GE2_COD = 'T_ACVIT2' AND D_E_L_E_T_ = ' '")
    lOk := GEBACOK(lOk, aRet[4] == 403 .And. Len(aChk) == 1, "C1 ADMIN de outra empresa nao exclui (status " + cValToChar(aRet[4]) + ", ativo=" + cValToChar(Len(aChk)) + ")")

    // C2) perfil com permissao de VER usuarios nao cria usuario (escrita exige ADMIN).
    aRet := GEBACCALL("LST", cTokOpe, "zzac1", "", Nil)
    lOk := GEBACOK(lOk, aRet[4] == 200, "C2a OPERADOR com SEGURANCA/USUARI le a lista (status " + cValToChar(aRet[4]) + ")")
    aRet := GEBACCALL("POST", cTokOpe, "zzac1", "t_acnovo", Nil)
    aChk := TCSqlQuery("SELECT GE2_COD FROM public.GE2 WHERE LOWER(GE2_COD) = 't_acnovo' AND D_E_L_E_T_ = ' '")
    lOk := GEBACOK(lOk, aRet[4] == 403 .And. Len(aChk) == 0, "C2b OPERADOR nao cria usuario ADMIN (status " + cValToChar(aRet[4]) + ", criado=" + cValToChar(Len(aChk)) + ")")

    // C3) excluir usuario revoga vinculos, credencial e tokens.
    aRet := GEBACCALL("DEL", cTokAdm, "zzac1", "T_ACALVO1", Nil)
    lOk := GEBACOK(lOk, aRet[4] == 200, "C3a ADMIN exclui usuario da propria empresa (status " + cValToChar(aRet[4]) + ")")
    aChk := TCSqlQuery("SELECT GE2_EMP_USUARIO FROM public.GE2_EMP WHERE GE2_EMP_USUARIO = 'T_ACALVO1' AND D_E_L_E_T_ = ' '")
    lOk := GEBACOK(lOk, Len(aChk) == 0, "C3b vinculos do excluido revogados (ativos=" + cValToChar(Len(aChk)) + ")")
    aRet := GEBACCALL("LST", cTokAlv, "zzac1", "", Nil)
    lOk := GEBACOK(lOk, aRet[4] == 401, "C3c token do excluido negado (status " + cValToChar(aRet[4]) + ")")

    // C4) vinculo removido -> token antigo perde valor na hora.
    TCSqlExec("UPDATE public.GE2_EMP SET D_E_L_E_T_ = '*' WHERE GE2_EMP_USUARIO = 'T_ACOPE1'")
    aRet := GEBACCALL("LST", cTokOpe, "zzac1", "", Nil)
    lOk := GEBACOK(lOk, aRet[4] == 401, "C4 token sem vinculo negado (status " + cValToChar(aRet[4]) + ")")

    // C5) toda rota autenticada nega sem token.
    aRotas := {{|o| GEBWAPI_USRLST(o)}, {|o| GEBWAPI_USRGET(o)}, {|o| GEBWAPI_USRPOST(o)}, {|o| GEBWAPI_USRPUT(o)}, ;
        {|o| GEBWAPI_USRDEL(o)}, {|o| GEBWAPI_EMPLST(o)}, {|o| GEBWAPI_EMPLSC(o)}, {|o| GEBWAPI_PRDLST(o)}, ;
        {|o| GEBWAPI_PRDLSC(o)}, {|o| GEBWAPI_NOTLST(o)}, {|o| GEBWAPI_NOTPOST(o)}, {|o| GEBWAPI_FLXLST(o)}, ;
        {|o| GEBWAPI_CONLST(o)}, {|o| GEBWAPI_RELFISC(o)}, {|o| GEBWAPI_RELGER(o)}, {|o| GEBWAPI_MONUSU(o)}, ;
        {|o| GEBWAPI_MONDEL(o)}, {|o| GEBWAPI_DERLST(o)}, {|o| GEBWAPI_ESTLST(o)}, {|o| GEBWAPI_VENLST(o)}, ;
        {|o| GEBWAPI_CTBLST(o)}, {|o| GEBWAPI_CTCLST(o)}, {|o| GEBWAPI_COMLST(o)}, {|o| GEBWAPI_FORLST(o)}, ;
        {|o| GEBWAPI_UNILST(o)}, {|o| GEBWAPI_UNILSC(o)}, {|o| GEBWAPI_FILLST(o)}, {|o| GEBWAPI_FILSC(o)}, ;
        {|o| GEBWAPI_VINCSC(o)}, {|o| GEBWAPI_DERGER(o)}, {|o| GEBWAPI_DERBAI(o)}, {|o| GEBWAPI_DERPAR(o)}}
    For nI := 1 To Len(aRotas)
        TCSqlExec("SET search_path TO public")
        oMock := JsonObject():New()
        oMock["EMPRESA"] := "zzac1"
        oMock["COD"] := "T_ACVIT2"
        aRet := Eval(aRotas[nI], oMock)
        If Len(aRet) >= 4 .And. aRet[4] == 401
            nNeg := nNeg + 1
        Else
            ConOut("FAIL: C5 rota " + cValToChar(nI) + " sem token nao negou")
        EndIf
    Next nI
    lOk := GEBACOK(lOk, nNeg == Len(aRotas), "C5 " + cValToChar(nNeg) + "/" + cValToChar(Len(aRotas)) + " rotas autenticadas negam sem token")

    // C6) super desbloqueia conta trocando a senha.
    TCSqlExec("UPDATE public.GE2_SEC SET SEC_FAILCNT = 99, SEC_LOCKED = '20991231' WHERE SEC_USUARIO = 'T_ACVIT2'")
    aRet := GEBACCALL("PUT", cTokSup, "zzac2", "T_ACVIT2", Nil)
    lOk := GEBACOK(lOk, aRet[4] == 200, "C6a super troca a senha (status " + cValToChar(aRet[4]) + ")")
    TCSqlExec("SET search_path TO public")
    lOk := GEBACOK(lOk, GEBSECLOGIN("T_ACVIT2", "Nova#Senha9", "t") == "OK", "C6b conta desbloqueada entra com a senha nova")

    // C7) injecao no codigo da rota nao vaza dados.
    aRet := GEBACCALL("GET", cTokSup, "zzac2", "' OR '1'='1", Nil)
    lOk := GEBACOK(lOk, aRet[4] == 404, "C7 GET /usuarios/<injecao> -> 404 (status " + cValToChar(aRet[4]) + ")")

    // C8) ADMIN da zzac1 nao se vincula a zzac2 -- caminho da tela
    // (GEBTUI "Vincular usuario" chama GEBRESTVINCSC com a empresa digitada).
    GEBDBSetTenant("zzac1")
    aRet := GEBRESTVINCSC("T_ACADM1", {"T_ACADM1", "zzac2", ""})
    TCSqlExec("SET search_path TO public")
    aChk := TCSqlQuery("SELECT GE2_EMP_USUARIO FROM public.GE2_EMP WHERE GE2_EMP_USUARIO = 'T_ACADM1' AND GE2_EMP_EMPRESA = 'zzac2' AND D_E_L_E_T_ = ' '")
    If Len(aRet) < 2
        aRet := {"0", ""}
    EndIf
    aRet := {"", "", "", Val(cValToChar(aRet[1]))}
    lOk := GEBACOK(lOk, aRet[4] == 403 .And. Len(aChk) == 0, "C8 ADMIN nao se vincula a outra empresa (status " + cValToChar(aRet[4]) + ", vinculo=" + cValToChar(Len(aChk)) + ")")

    // C9) ADMIN da zzac1 nao toma a conta do ADMIN da zzac2 (vincular -> trocar senha).
    GEBDBSetTenant("zzac1")
    aRet := GEBRESTVINCSC("T_ACADM1", {"T_ACADM2", "zzac1", ""})
    lOk := GEBACOK(lOk, cValToChar(aRet[1]) == "403", "C9a ADMIN nao traz usuario de outra empresa para a sua (status " + cValToChar(aRet[1]) + ")")
    TCSqlExec("INSERT INTO public.GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA) VALUES (' ', '', 'T_ACADM2', 'zzac1')")
    aRet := GEBACCALL("PUT", cTokAdm, "zzac1", "T_ACADM2", Nil)
    lOk := GEBACOK(lOk, aRet[4] == 403, "C9b ADMIN nao troca senha de usuario que tambem e' de outra empresa (status " + cValToChar(aRet[4]) + ")")
    TCSqlExec("DELETE FROM public.GE2_EMP WHERE GE2_EMP_USUARIO = 'T_ACADM2' AND GE2_EMP_EMPRESA = 'zzac1'")

    // C10) monitor nao expoe token e nao mostra sessoes de outra empresa.
    TCSqlExec("SET search_path TO public")
    DbSelectArea("GE1")
    GEBDBSetTenant("zzac1")
    aRet := GEBRESTMONUSU("T_ACADM1")
    TCSqlExec("SET search_path TO public")
    lOk := GEBACOK(lOk, At(cTokSup, cValToChar(aRet[2])) == 0 .And. At(cTokAdm, cValToChar(aRet[2])) == 0 .And. At("zzac2", cValToChar(aRet[2])) == 0, "C10 monitor sem tokens e sem sessoes de outra empresa")

    // C11) tela: usuario comum nao troca senha de terceiro nem o proprio perfil.
    TCSqlExec("SET search_path TO public")
    DbSelectArea("GE1")
    GEBDBSetTenant("zzac2")
    aTroca := GEBTUITROCASENHA("T_ACVIT2", "T_ACADM2", "Outra#Senha8", "", "")
    lOk := GEBACOK(lOk, !aTroca[1], "C11a USUARIO nao troca senha de terceiro pela tela")
    aTroca := GEBTUITROCASENHA("T_ACVIT2", "", "", "", "ADMIN")
    TCSqlExec("SET search_path TO public")
    aChk := TCSqlQuery("SELECT GE2_PERFIL FROM public.GE2 WHERE GE2_COD = 'T_ACVIT2' AND D_E_L_E_T_ = ' '")
    lOk := GEBACOK(lOk, !aTroca[1] .And. Len(aChk) == 1 .And. AllTrim(aChk[1]:GE2_PERFIL) == "USUARIO", "C11b USUARIO nao se promove a ADMIN pela tela")

    // C12) bloqueio por senha errada e' temporario (nao 20991231).
    TCSqlExec("SET search_path TO public")
    For nI := 1 To 5
        GEBSECLOGIN("T_ACADM2", "errada", "t")
    Next nI
    aChk := TCSqlQuery("SELECT SEC_LOCKED FROM public.GE2_SEC WHERE SEC_USUARIO = 'T_ACADM2' AND D_E_L_E_T_ = ' '")
    lOk := GEBACOK(lOk, Len(aChk) == 1 .And. AllTrim(aChk[1]:SEC_LOCKED) != "20991231" .And. Len(AllTrim(aChk[1]:SEC_LOCKED)) > 8, "C12 bloqueio temporario (" + GEBACVAL(aChk) + ")")
    lOk := GEBACOK(lOk, GEBSECLOGIN("T_ACADM2", "Senha#Forte1", "t") == "CONTA_BLOQ", "C12b durante o bloqueio nem a senha certa entra")

    // C13) troca de senha derruba as sessoes abertas do alvo.
    aRet := GEBACCALL("LST", cTokVit, "zzac2", "", Nil)
    lOk := GEBACOK(lOk, aRet[4] == 401, "C13 token antigo do alvo cai apos a troca de senha do C6 (status " + cValToChar(aRet[4]) + ")")

    // C14) ADMIN so lista usuarios da propria empresa.
    aRet := GEBACCALL("LST", cTokAdm, "zzac1", "", Nil)
    lOk := GEBACOK(lOk, aRet[4] == 200 .And. At("T_ACADM1", cValToChar(aRet[3])) > 0 .And. At("T_ACVIT2", cValToChar(aRet[3])) == 0 .And. At("T_ACADM2", cValToChar(aRet[3])) == 0, "C14 lista do ADMIN sem usuarios de outra empresa")

    GEBACLIMPA(aUsu)
    If lOk
        ConOut("T_GEBSEC_ACESSO PASS")
    Else
        ConOut("T_GEBSEC_ACESSO FAIL")
    EndIf
Return lOk

Static Function GEBACCALL(cOp, cTok, cEmp, cCod, xNil)
    Local oMock := JsonObject():New()
    Local aRet := {}
    TCSqlExec("SET search_path TO public")
    DbSelectArea("GE1")
    oMock["TOKEN"] := cTok
    oMock["EMPRESA"] := cEmp
    oMock["COD"] := cCod
    If cOp == "LST"
        aRet := GEBWAPI_USRLST(oMock)
    ElseIf cOp == "GET"
        aRet := GEBWAPI_USRGET(oMock)
    ElseIf cOp == "DEL"
        aRet := GEBWAPI_USRDEL(oMock)
    ElseIf cOp == "PUT"
        oMock["NOME"] := "Vitima AC2"
        oMock["PERFIL"] := "USUARIO"
        oMock["SENHA"] := "Nova#Senha9"
        aRet := GEBWAPI_USRPUT(oMock)
    ElseIf cOp == "POST"
        oMock["CODIGO"] := cCod
        oMock["NOME"] := "Novo"
        oMock["PERFIL"] := "ADMIN"
        oMock["SENHA"] := "Senha#Forte1"
        oMock["EMPRESAS"] := cEmp
        aRet := GEBWAPI_USRPOST(oMock)
    EndIf
    TCSqlExec("SET search_path TO public")
    If Len(aRet) < 4
        aRet := {"", "", "", 0}
    EndIf
Return aRet

Static Function GEBACVAL(aChk)
    If Len(aChk) == 0
        Return "sem linha"
    EndIf
Return AllTrim(cValToChar(aChk[1]:SEC_LOCKED))

Static Function GEBACOK(lOk, lCond, cMsg)
    If lCond
        ConOut("  OK " + cMsg)
        Return lOk
    EndIf
    ConOut("FAIL: " + cMsg)
Return .F.

Static Function GEBACLIMPA(aUsu)
    Local nI := 0
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_zzac1 CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_zzac2 CASCADE")
    For nI := 1 To Len(aUsu)
        TCSqlExec("DELETE FROM GE2_TOK WHERE LOWER(TOK_USUARIO) = '" + Lower(aUsu[nI]) + "'")
        TCSqlExec("DELETE FROM GE2_EMP WHERE LOWER(GE2_EMP_USUARIO) = '" + Lower(aUsu[nI]) + "'")
        TCSqlExec("DELETE FROM GE2_SEC WHERE LOWER(SEC_USUARIO) = '" + Lower(aUsu[nI]) + "'")
        TCSqlExec("DELETE FROM GE2 WHERE LOWER(GE2_COD) = '" + Lower(aUsu[nI]) + "'")
    Next nI
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD IN ('zzac1', 'zzac2')")
    TCSqlExec("DELETE FROM SEC_PERM WHERE SEC_PERM_PERFIL = 'OPERADOR'")
Return .T.
