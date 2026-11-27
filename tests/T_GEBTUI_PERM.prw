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

/*/{Protheus.doc} T_GEBTUI_PERM
    Tela de permissoes (Nucleo > Permissoes) e checagem por modulo na tela:
    so' o super concede/revoga; concessao e revogacao valem na hora; perfil
    sem permissao fica fora do modulo; ADMIN e super entram em tudo.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 03/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBTUI_PERM()
    Local lOk := .T.
    Local aRes := {}

    If !GEBDBConecta()
        ConOut("T_GEBTUI_PERM FAIL")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    GEBPMLIMPA()
    If !GEBDBProvisionaCatalogo() .Or. !GEBDBProvisionaEmpresa("zzperm", "Empresa Perm")
        ConOut("T_GEBTUI_PERM FAIL")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    DbSelectArea("GE1")
    lOk := lOk .And. GEBSECCRIAUSU("T_PMUSU", "Senha#Forte1", {"zzperm"}, "Usuario Perm", "USUARIO")
    lOk := lOk .And. GEBSECCRIAUSU("T_PMADM", "Senha#Forte1", {"zzperm"}, "Admin Perm", "ADMIN")
    GEBDBSetTenant("zzperm")

    lOk := GEBPMOK(lOk, !GEBTUIMODOK("T_PMUSU", "FISCAL"), "P1 USUARIO sem permissao fica fora do Fiscal")
    lOk := GEBPMOK(lOk, GEBTUIMODOK("T_PMADM", "FISCAL") .And. GEBTUIMODOK("super", "CONTABIL"), "P2 ADMIN e super entram nos modulos")

    aRes := GEBTUIPERMSET("T_PMADM", "USUARIO", "FISCAL", "NOTAS", .T.)
    lOk := GEBPMOK(lOk, !aRes[1], "P3 ADMIN nao altera permissoes (so o super): " + cValToChar(aRes[2]))

    aRes := GEBTUIPERMSET("super", "USUARIO", "FISCAL", "NOTAS", .T.)
    lOk := GEBPMOK(lOk, aRes[1] .And. GEBSECRBAC("T_PMUSU", "FISCAL", "NOTAS") .And. GEBTUIMODOK("T_PMUSU", "FISCAL"), "P4 super concede FISCAL/NOTAS ao perfil USUARIO e vale na hora")
    lOk := GEBPMOK(lOk, !GEBSECRBAC("T_PMUSU", "FISCAL", "APURA"), "P5 concessao e' so do item pedido (APURA continua negado)")

    aRes := GEBTUIPERMSET("super", "USUARIO", "FISCAL", "NOTAS", .F.)
    lOk := GEBPMOK(lOk, aRes[1] .And. !GEBSECRBAC("T_PMUSU", "FISCAL", "NOTAS"), "P6 super revoga e vale na hora")

    aRes := GEBTUIPERMSET("super", "ADMIN", "FISCAL", "NOTAS", .F.)
    lOk := GEBPMOK(lOk, !aRes[1], "P7 perfil ADMIN nao e' editavel (evita trancar a administracao)")
    aRes := GEBTUIPERMSET("super", "USUARIO", "INVENTADO", "X", .T.)
    lOk := GEBPMOK(lOk, !aRes[1], "P8 area inexistente recusada")
    aRes := GEBTUIPERMSET("super", "us'r", "FISCAL", "NOTAS", .T.)
    lOk := GEBPMOK(lOk, !aRes[1], "P9 perfil invalido recusado")
    // P10-P13: tela por empresa. ADMIN altera so' a propria empresa; nunca a linha '*'.
    aRes := GEBTUIPERMSETEMP("T_PMADM", "zzperm", "USUARIO", "FISCAL", "NOTAS", .T.)
    lOk := GEBPMOK(lOk, aRes[1], "P10 ADMIN concede na propria empresa: " + cValToChar(aRes[2]))
    aRes := GEBTUIPERMSETEMP("T_PMADM", "zzperm", "USUARIO", "FISCAL", "NOTAS", .F.)
    lOk := GEBPMOK(lOk, aRes[1], "P10b ADMIN revoga na propria empresa")
    aRes := GEBTUIPERMSETEMP("T_PMADM", "outra", "USUARIO", "FISCAL", "NOTAS", .T.)
    lOk := GEBPMOK(lOk, !aRes[1], "P11 ADMIN nao altera permissoes de outra empresa")
    aRes := GEBTUIPERMSETEMP("T_PMUSU", "zzperm", "USUARIO", "FISCAL", "NOTAS", .T.)
    lOk := GEBPMOK(lOk, !aRes[1], "P12 usuario comum nao altera permissoes")
    aRes := GEBTUIPERMSETEMP("T_PMADM", "*", "USUARIO", "FISCAL", "NOTAS", .T.)
    lOk := GEBPMOK(lOk, !aRes[1], "P13 ADMIN nao altera a linha global '*'")

    GEBPMLIMPA()
    If lOk
        ConOut("T_GEBTUI_PERM PASS")
    Else
        ConOut("T_GEBTUI_PERM FAIL")
    EndIf
Return lOk

Static Function GEBPMOK(lOk, lCond, cMsg)
    If lCond
        ConOut("  OK " + cMsg)
        Return lOk
    EndIf
    ConOut("FAIL: " + cMsg)
Return .F.

Static Function GEBPMLIMPA()
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_zzperm CASCADE")
    If GEBDBTableExists("GE2")
        TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO IN ('T_PMUSU', 'T_PMADM')")
        TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO IN ('T_PMUSU', 'T_PMADM')")
        TCSqlExec("DELETE FROM GE2 WHERE GE2_COD IN ('T_PMUSU', 'T_PMADM')")
        TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = 'zzperm'")
        TCSqlExec("DELETE FROM SEC_PERM WHERE SEC_PERM_PERFIL = 'USUARIO'")
    EndIf
Return .T.
