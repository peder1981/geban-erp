#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBSEC_POL.prw"
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
#include "../src/GEBEXP_REL_NUC.prw"

/*/{Protheus.doc} T_GeExp_REL_NUC
    Teste dos relatorios do nucleo multi-empresa (GEBEXP_REL_NUC) sobre
    o desenho multi-tenant real (Fase 2): duas empresas REAIS
    provisionadas via GEBDBProvisionaEmpresa() (schemas emp_zzrn1 e
    emp_zzrn2), usuarios criados so' via GEBSECCRIAUSU() (catalogo
    GE2/GE2_SEC/GE2_EMP), e dados por-tenant semeados dentro de cada
    schema com quantidades DIFERENTES por empresa, de modo que qualquer
    vazamento entre empresas (somar as duas, ou trocar uma pela outra)
    quebre um assert exato:
      zzrn1: 4 usuarios (T_RN1A/B/C + T_RNX compartilhado), GE3=3 (+1
             deletado), GF1=2 (+1 deletado), GCP1=1, GV3=3, GFN1=1,
             GEH=4 (3 em set/2026 + 1 em out/2026) (+1 deletado), GE4=2
      zzrn2: 2 usuarios (T_RN2A + T_RNX) + 1 vinculo deletado de T_RN1A,
             GE3=1, GF1=5, GCP1=0, GV3=1, GFN1=2, GEH=1, GE4=1
    Cobre tambem: cEmpresa vazio usa o tenant corrente; relatorio de
    OUTRA empresa com o search_path apontando para a primeira nao muda o
    search_path nem mistura dados; entradas com injecao/empresa nao
    provisionada devolvem {} sem SQL.
    Cleanup: DROP SCHEMA ... CASCADE por empresa + remocao dos usuarios
    de teste e das linhas GE1 no catalogo.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GeExp_REL_NUC()
    Local lOk := .T.
    Local cE1 := "zzrn1"
    Local cE2 := "zzrn2"
    Local cSenha := "Senha#Forte1"
    Local aUsuTodos := {"T_RN1A", "T_RN1B", "T_RN1C", "T_RN2A", "T_RNX"}
    Local aRel := {}
    Local aLin := {}
    Local aHit := {}
    Local cFil := ""
    Local nI := 0
    Local lAchou1 := .F.
    Local lAchou2 := .F.

    If !GEBDBConecta()
        ConOut("T_GeExp_REL_NUC: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")

    // Pre-cleanup (rerun limpo).
    Limpa(cE1, cE2, aUsuTodos)

    // ---- Setup: catalogo + 2 empresas reais ----
    If !GEBDBProvisionaCatalogo()
        ConOut("FAIL GEBDBProvisionaCatalogo")
        lOk := .F.
    EndIf
    If lOk
        If !GEBDBProvisionaEmpresa(cE1, "Empresa RelNuc Um")
            ConOut("FAIL GEBDBProvisionaEmpresa(" + cE1 + ")")
            lOk := .F.
        EndIf
    EndIf
    If lOk
        If !GEBDBProvisionaEmpresa(cE2, "Empresa RelNuc Dois")
            ConOut("FAIL GEBDBProvisionaEmpresa(" + cE2 + ")")
            lOk := .F.
        EndIf
    EndIf
    TCSqlExec("SET search_path TO public")

    // Usuarios (catalogo) so' via GEBSECCRIAUSU().
    If lOk
        lOk := Chk(GEBSECCRIAUSU("T_RN1A", cSenha, {cE1}, "Rel Nuc 1A", "USUARIO"), "CRIAUSU T_RN1A") .And. lOk
        lOk := Chk(GEBSECCRIAUSU("T_RN1B", cSenha, {cE1}, "Rel Nuc 1B", "CAIXA"), "CRIAUSU T_RN1B") .And. lOk
        lOk := Chk(GEBSECCRIAUSU("T_RN1C", cSenha, {cE1}, "Rel Nuc 1C", "USUARIO"), "CRIAUSU T_RN1C") .And. lOk
        lOk := Chk(GEBSECCRIAUSU("T_RN2A", cSenha, {cE2}, "Rel Nuc 2A", "GERENTE"), "CRIAUSU T_RN2A") .And. lOk
        lOk := Chk(GEBSECCRIAUSU("T_RNX", cSenha, {cE1, cE2}, "Rel Nuc X", "USUARIO"), "CRIAUSU T_RNX") .And. lOk
    EndIf
    // Vinculo DELETADO de T_RN1A com zzrn2: nao pode contar para zzrn2.
    If lOk
        aHit := TCSqlQuery("SELECT GE2_FILIAL FROM public.GE2 WHERE GE2_COD = 'T_RN1A' AND D_E_L_E_T_ = ' '")
        If Len(aHit) > 0
            cFil := cValToChar(aHit[1]:GE2_FILIAL)
        EndIf
        lOk := Chk(TCSqlExec("INSERT INTO public.GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA) VALUES ('*', '" + cFil + "', 'T_RN1A', '" + cE2 + "')"), "seed GE2_EMP deletado") .And. lOk
    EndIf

    // Dados por-tenant (quantidades distintas por empresa).
    If lOk
        lOk := Chk(SemeiaE1(cE1), "seed " + cE1) .And. lOk
        lOk := Chk(SemeiaE2(cE2), "seed " + cE2) .And. lOk
    EndIf
    TCSqlExec("SET search_path TO public")

    // ---- 1. GEBRELEMPRESAS ----
    If lOk
        aRel := GEBRELEMPRESAS()
        For nI := 1 To Len(aRel)
            aLin := aRel[nI]
            If aLin[1] == cE1
                lAchou1 := .T.
                lOk := Chk(aLin[2] == "Empresa RelNuc Um", "EMPRESAS " + cE1 + " nome=" + cValToChar(aLin[2])) .And. lOk
                lOk := Chk(aLin[3] == 4, "EMPRESAS " + cE1 + " NUSUARIOS=" + cValToChar(aLin[3]) + " (esperado 4)") .And. lOk
                lOk := Chk(aLin[4] == 3, "EMPRESAS " + cE1 + " NREGRE=" + cValToChar(aLin[4]) + " (esperado 3)") .And. lOk
            EndIf
            If aLin[1] == cE2
                lAchou2 := .T.
                lOk := Chk(aLin[2] == "Empresa RelNuc Dois", "EMPRESAS " + cE2 + " nome=" + cValToChar(aLin[2])) .And. lOk
                lOk := Chk(aLin[3] == 2, "EMPRESAS " + cE2 + " NUSUARIOS=" + cValToChar(aLin[3]) + " (esperado 2)") .And. lOk
                lOk := Chk(aLin[4] == 1, "EMPRESAS " + cE2 + " NREGRE=" + cValToChar(aLin[4]) + " (esperado 1)") .And. lOk
            EndIf
        Next nI
        lOk := Chk(lAchou1, "EMPRESAS lista " + cE1) .And. lOk
        lOk := Chk(lAchou2, "EMPRESAS lista " + cE2) .And. lOk
        ConOut("  info GEBRELEMPRESAS: " + cValToChar(Len(aRel)) + " empresas no catalogo")
    EndIf

    // ---- 2. GEBRELUSUARIOS ----
    If lOk
        aRel := GEBRELUSUARIOS(cE1)
        lOk := Chk(Len(aRel) == 4, "USUARIOS " + cE1 + " qtd=" + cValToChar(Len(aRel)) + " (esperado 4)") .And. lOk
        lOk := Chk(ListaCods(aRel) == "T_RN1A,T_RN1B,T_RN1C,T_RNX", "USUARIOS " + cE1 + " cods=" + ListaCods(aRel)) .And. lOk
        If Len(aRel) >= 2
            lOk := Chk(aRel[2][2] == "Rel Nuc 1B", "USUARIOS " + cE1 + " nome[2]=" + cValToChar(aRel[2][2])) .And. lOk
            lOk := Chk(aRel[2][3] == "CAIXA", "USUARIOS " + cE1 + " perfil[2]=" + cValToChar(aRel[2][3])) .And. lOk
        EndIf
        aRel := GEBRELUSUARIOS(cE2)
        lOk := Chk(Len(aRel) == 2, "USUARIOS " + cE2 + " qtd=" + cValToChar(Len(aRel)) + " (esperado 2)") .And. lOk
        lOk := Chk(ListaCods(aRel) == "T_RN2A,T_RNX", "USUARIOS " + cE2 + " cods=" + ListaCods(aRel)) .And. lOk
        // Caixa do codigo nao importa (GE2_EMP grava minusculo).
        aRel := GEBRELUSUARIOS(Upper(cE2))
        lOk := Chk(Len(aRel) == 2, "USUARIOS " + Upper(cE2) + " qtd=" + cValToChar(Len(aRel))) .And. lOk
        // Injecao: {} sem SQL.
        aRel := GEBRELUSUARIOS("zzrn1' OR '1'='1")
        lOk := Chk(Len(aRel) == 0, "USUARIOS injecao qtd=" + cValToChar(Len(aRel))) .And. lOk
    EndIf

    // ---- 3. GEBRELAUDITORIA ----
    If lOk
        aRel := GEBRELAUDITORIA(cE1, "20260901", "20260930")
        lOk := Chk(Len(aRel) == 3, "AUDITORIA " + cE1 + " set/2026 qtd=" + cValToChar(Len(aRel)) + " (esperado 3)") .And. lOk
        If Len(aRel) >= 3
            // Conteudo real (nao mais placeholders vazios), mais recente
            // primeiro; linha com GEH_EMPRESA='' (como GEBSECLOGIN grava)
            // incluida.
            lOk := Chk(aRel[1][1] == "20260920", "AUDITORIA " + cE1 + " [1] DATA=" + cValToChar(aRel[1][1])) .And. lOk
            lOk := Chk(aRel[1][2] == "14:00:00", "AUDITORIA " + cE1 + " [1] HORA=" + cValToChar(aRel[1][2])) .And. lOk
            lOk := Chk(aRel[1][3] == "T_RN1B", "AUDITORIA " + cE1 + " [1] USUARIO=" + cValToChar(aRel[1][3])) .And. lOk
            lOk := Chk(aRel[1][4] == "GEBSECLOGIN", "AUDITORIA " + cE1 + " [1] FUNCAO=" + cValToChar(aRel[1][4])) .And. lOk
            lOk := Chk(aRel[1][5] == "10.0.0.9", "AUDITORIA " + cE1 + " [1] IP=" + cValToChar(aRel[1][5])) .And. lOk
            lOk := Chk(aRel[3][1] == "20260905", "AUDITORIA " + cE1 + " [3] DATA=" + cValToChar(aRel[3][1])) .And. lOk
        EndIf
        aRel := GEBRELAUDITORIA(cE1)
        lOk := Chk(Len(aRel) == 4, "AUDITORIA " + cE1 + " sem periodo qtd=" + cValToChar(Len(aRel)) + " (esperado 4)") .And. lOk
        aRel := GEBRELAUDITORIA(cE2, "20260901", "20260930")
        lOk := Chk(Len(aRel) == 1, "AUDITORIA " + cE2 + " qtd=" + cValToChar(Len(aRel)) + " (esperado 1)") .And. lOk
        If Len(aRel) >= 1
            lOk := Chk(aRel[1][3] == "T_RN2A", "AUDITORIA " + cE2 + " [1] USUARIO=" + cValToChar(aRel[1][3])) .And. lOk
        EndIf
        aRel := GEBRELAUDITORIA(cE1, "2026'--", "")
        lOk := Chk(Len(aRel) == 0, "AUDITORIA data invalida qtd=" + cValToChar(Len(aRel))) .And. lOk
    EndIf

    // ---- 5. GEBRELCADASTROS ----
    If lOk
        aRel := GEBRELCADASTROS(cE1)
        lOk := Chk(CadStr(aRel) == "2/1/3/1", "CADASTROS " + cE1 + " = " + CadStr(aRel) + " (esperado 2/1/3/1)") .And. lOk
        aRel := GEBRELCADASTROS(cE2)
        lOk := Chk(CadStr(aRel) == "5/0/1/2", "CADASTROS " + cE2 + " = " + CadStr(aRel) + " (esperado 5/0/1/2)") .And. lOk
        aRel := GEBRELCADASTROS("zznaoexiste")
        lOk := Chk(Len(aRel) == 0, "CADASTROS empresa nao provisionada qtd=" + cValToChar(Len(aRel))) .And. lOk
        aRel := GEBRELCADASTROS("x; DROP SCHEMA emp_zzrn1")
        lOk := Chk(Len(aRel) == 0, "CADASTROS injecao qtd=" + cValToChar(Len(aRel))) .And. lOk
        // Em public (sem tenant) e sem cEmpresa: nada a reportar.
        aRel := GEBRELCADASTROS("")
        lOk := Chk(Len(aRel) == 0, "CADASTROS vazio em public qtd=" + cValToChar(Len(aRel))) .And. lOk
    EndIf

    // ---- Tenant corrente como padrao + nao altera search_path ----
    If lOk
        lOk := Chk(GEBDBSetTenant(cE2), "SetTenant " + cE2) .And. lOk
        aRel := GEBRELCADASTROS("")
        lOk := Chk(CadStr(aRel) == "5/0/1/2", "CADASTROS padrao (tenant " + cE2 + ") = " + CadStr(aRel)) .And. lOk
        aRel := GEBRELUSUARIOS()
        lOk := Chk(ListaCods(aRel) == "T_RN2A,T_RNX", "USUARIOS padrao (tenant " + cE2 + ") = " + ListaCods(aRel)) .And. lOk
        // Relatorio de OUTRA empresa com o search_path em zzrn2.
        aRel := GEBRELCADASTROS(cE1)
        lOk := Chk(CadStr(aRel) == "2/1/3/1", "CADASTROS " + cE1 + " sob search_path " + cE2 + " = " + CadStr(aRel)) .And. lOk
        aRel := GEBRELAUDITORIA(cE1)
        lOk := Chk(Len(aRel) == 4, "AUDITORIA " + cE1 + " sob search_path " + cE2 + " qtd=" + cValToChar(Len(aRel))) .And. lOk
        aRel := GEBRELEMPRESAS()
        aHit := TCSqlQuery("SELECT current_schema() AS SCH")
        If Len(aHit) > 0
            lOk := Chk(cValToChar(aHit[1]:SCH) == "emp_" + cE2, "search_path preservado: current_schema=" + cValToChar(aHit[1]:SCH)) .And. lOk
        Else
            lOk := Chk(.F., "search_path preservado: current_schema sem retorno") .And. lOk
        EndIf
    EndIf

    // ---- 4. GEBRELMENTOR (inalterada; le GE4 do tenant corrente) ----
    // Por ultimo: usa workarea (GE4 vira a alias corrente), e GE4 existe
    // nos dois tenants, entao trocar entre eles aqui e' seguro.
    If lOk
        lOk := Chk(GEBDBSetTenant(cE1), "SetTenant " + cE1) .And. lOk
        aRel := GEBRELMENTOR(cE1)
        lOk := Chk(Len(aRel) == 2, "MENTOR " + cE1 + " qtd=" + cValToChar(Len(aRel)) + " (esperado 2)") .And. lOk
        lOk := Chk(GEBDBSetTenant(cE2), "SetTenant " + cE2) .And. lOk
        aRel := GEBRELMENTOR(cE2)
        lOk := Chk(Len(aRel) == 1, "MENTOR " + cE2 + " qtd=" + cValToChar(Len(aRel)) + " (esperado 1)") .And. lOk
    EndIf

    // Cleanup (so' TCSqlExec -- nenhum RestArea depois do DROP SCHEMA).
    TCSqlExec("SET search_path TO public")
    Limpa(cE1, cE2, aUsuTodos)

    If lOk
        ConOut("T_GeExp_REL_NUC PASS")
    Else
        ConOut("T_GeExp_REL_NUC FAIL")
    EndIf
Return lOk

Static Function Chk(lCond, cMsg)
    If lCond
        ConOut("  OK   " + cMsg)
    Else
        ConOut("  FAIL " + cMsg)
    EndIf
Return lCond

Static Function ListaCods(aRel)
    Local cRet := ""
    Local nI := 0
    For nI := 1 To Len(aRel)
        If nI > 1
            cRet += ","
        EndIf
        cRet += cValToChar(aRel[nI][1])
    Next nI
Return cRet

Static Function CadStr(aRel)
    If Len(aRel) == 0
        Return "{}"
    EndIf
    If Len(aRel[1]) < 4
        Return "incompleto"
    EndIf
Return cValToChar(aRel[1][1]) + "/" + cValToChar(aRel[1][2]) + "/" + cValToChar(aRel[1][3]) + "/" + cValToChar(aRel[1][4])

Static Function Limpa(cE1, cE2, aUsu)
    Local nI := 0
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cE1 + " CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cE2 + " CASCADE")
    TCSqlExec("DELETE FROM public.GE1 WHERE GE1_COD IN ('" + cE1 + "', '" + cE2 + "')")
    For nI := 1 To Len(aUsu)
        TCSqlExec("DELETE FROM public.GE2_EMP WHERE GE2_EMP_USUARIO = '" + aUsu[nI] + "'")
        TCSqlExec("DELETE FROM public.GE2_SEC WHERE SEC_USUARIO = '" + aUsu[nI] + "'")
        TCSqlExec("DELETE FROM public.GE2 WHERE GE2_COD = '" + aUsu[nI] + "'")
    Next nI
Return

// Semeia emp_<cE1>: GE3=3(+1 del), GF1=2(+1 del), GCP1=1, GV3=3, GFN1=1,
// GEH=4 ativas (+1 del), GE4=2. Nomes qualificados pelo schema.
Static Function SemeiaE1(cE)
    Local lOk := .T.
    Local cS := "emp_" + cE + "."
    lOk := TCSqlExec("INSERT INTO " + cS + "GE3 (D_E_L_E_T_, GE3_FILIAL, GE3_COD, GE3_USUAR, GE3_EVENT, GE3_MOTIV, GE3_DATA) VALUES " + ;
        "(' ', ' ', '000001', 'T_RN1A', 'EV1', 'M1', '20260910'), " + ;
        "(' ', ' ', '000002', 'T_RN1B', 'EV2', 'M2', '20260911'), " + ;
        "(' ', ' ', '000003', 'T_RN1C', 'EV3', 'M3', '20260912'), " + ;
        "('*', ' ', '000004', 'T_RN1C', 'EV4', 'M4', '20260913')") .And. lOk
    lOk := TCSqlExec("INSERT INTO " + cS + "GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES " + ;
        "(' ', ' ', 'P1', '0001', 'Prod 1'), (' ', ' ', 'P2', '0002', 'Prod 2'), ('*', ' ', 'P3', '0003', 'Prod 3')") .And. lOk
    lOk := TCSqlExec("INSERT INTO " + cS + "GCP1 (D_E_L_E_T_, GCP1_FILIAL, GCP1_COD, GCP1_NOME, GCP1_CNPJ) VALUES " + ;
        "(' ', ' ', 'F1', 'Forn 1', '11111111000111')") .And. lOk
    lOk := TCSqlExec("INSERT INTO " + cS + "GV3 (D_E_L_E_T_, GV3_FILIAL, GV3_CLI, GV3_VALOR, GV3_JUROS, GV3_MULTA, GV3_TOTAL, GV3_STATUS) VALUES " + ;
        "(' ', ' ', 'C1', 10, 0, 0, 10, 'ABERTO'), (' ', ' ', 'C2', 20, 0, 0, 20, 'ABERTO'), (' ', ' ', 'C3', 30, 0, 0, 30, 'ABERTO')") .And. lOk
    lOk := TCSqlExec("INSERT INTO " + cS + "GFN1 (D_E_L_E_T_, GFN1_FILIAL, GFN1_CONTA, GFN1_NOME, GFN1_SALDO) VALUES " + ;
        "(' ', ' ', 'CX1', 'Caixa 1', 100)") .And. lOk
    lOk := TCSqlExec("INSERT INTO " + cS + "GEH (D_E_L_E_T_, GEH_DATA, GEH_HORA, GEH_USUARIO, GEH_EMPRESA, GEH_FUNCAO, GEH_IP) VALUES " + ;
        "(' ', '20260905', '08:00:00', 'T_RN1A', '" + cE + "', 'GEBEXPCONTEXTO', 'local'), " + ;
        "(' ', '20260915', '09:30:00', 'T_RN1C', '" + cE + "', 'GEBEXPCONTEXTO', 'local'), " + ;
        "(' ', '20260920', '14:00:00', 'T_RN1B', '', 'GEBSECLOGIN', '10.0.0.9'), " + ;
        "(' ', '20261005', '10:00:00', 'T_RN1A', '" + cE + "', 'GEBEXPCONTEXTO', 'local'), " + ;
        "('*', '20260918', '11:00:00', 'T_RN1A', '" + cE + "', 'GEBEXPCONTEXTO', 'local')") .And. lOk
    lOk := TCSqlExec("INSERT INTO " + cS + "GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES " + ;
        "(' ', ' ', 'PAG_IMPULSIVO', 'ALERTA'), (' ', ' ', 'VENDA_FIADO', 'BLOQUEIO')") .And. lOk
Return lOk

// Semeia emp_<cE2>: GE3=1, GF1=5, GCP1=0, GV3=1, GFN1=2, GEH=1, GE4=1.
Static Function SemeiaE2(cE)
    Local lOk := .T.
    Local cS := "emp_" + cE + "."
    lOk := TCSqlExec("INSERT INTO " + cS + "GE3 (D_E_L_E_T_, GE3_FILIAL, GE3_COD, GE3_USUAR, GE3_EVENT, GE3_MOTIV, GE3_DATA) VALUES " + ;
        "(' ', ' ', '000001', 'T_RN2A', 'EV1', 'M1', '20260910')") .And. lOk
    lOk := TCSqlExec("INSERT INTO " + cS + "GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES " + ;
        "(' ', ' ', 'Q1', '0001', 'Prod 1'), (' ', ' ', 'Q2', '0002', 'Prod 2'), (' ', ' ', 'Q3', '0003', 'Prod 3'), " + ;
        "(' ', ' ', 'Q4', '0004', 'Prod 4'), (' ', ' ', 'Q5', '0005', 'Prod 5')") .And. lOk
    lOk := TCSqlExec("INSERT INTO " + cS + "GV3 (D_E_L_E_T_, GV3_FILIAL, GV3_CLI, GV3_VALOR, GV3_JUROS, GV3_MULTA, GV3_TOTAL, GV3_STATUS) VALUES " + ;
        "(' ', ' ', 'D1', 50, 0, 0, 50, 'ABERTO')") .And. lOk
    lOk := TCSqlExec("INSERT INTO " + cS + "GFN1 (D_E_L_E_T_, GFN1_FILIAL, GFN1_CONTA, GFN1_NOME, GFN1_SALDO) VALUES " + ;
        "(' ', ' ', 'CX1', 'Caixa 1', 100), (' ', ' ', 'BC1', 'Banco 1', 200)") .And. lOk
    lOk := TCSqlExec("INSERT INTO " + cS + "GEH (D_E_L_E_T_, GEH_DATA, GEH_HORA, GEH_USUARIO, GEH_EMPRESA, GEH_FUNCAO, GEH_IP) VALUES " + ;
        "(' ', '20260912', '16:00:00', 'T_RN2A', '" + cE + "', 'GEBEXPCONTEXTO', 'local')") .And. lOk
    lOk := TCSqlExec("INSERT INTO " + cS + "GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES " + ;
        "(' ', ' ', 'PAG_IMPULSIVO', 'ALERTA')") .And. lOk
Return lOk
