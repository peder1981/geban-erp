#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIS_MIG.prw"

User Function T_GeExp_MIG()
    Local lOk := .T.

    If !GEBDBConecta()
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS emp_testexp CASCADE")

    // GEBDBProvisionaEmpresa() grava em public.GE1 (catalogo) -- garante
    // que o catalogo ja' esteja provisionado antes, como aconteceria em
    // producao (catalogo provisionado uma vez, empresas depois).
    TCSqlExec("SET search_path TO public")
    If !GENMIGCatalogo()
        Return .F.
    EndIf

    If !GEBDBProvisionaEmpresa("testexp", "Empresa Teste Expansao")
        Return .F.
    EndIf

    If !GEBEXPCriaAuditoria()
        lOk := .F.
    EndIf
    If !GEBDBTableExists("GEH") .Or. !GEBDBTableExists("GEI")
        lOk := .F.
    EndIf

    // I2 -- prova que GEBDBProvisionaEmpresa() realmente cria GE3/GE4/GE5
    // dentro do schema do tenant (emp_testexp), nao apenas em "public".
    If !GEBDBTableExists("GE3") .Or. !GEBDBTableExists("GE4") .Or. !GEBDBTableExists("GE5")
        ConOut("FALHA: GE3/GE4/GE5 nao encontradas apos GEBDBProvisionaEmpresa()")
        lOk := .F.
    EndIf

    // I4 -- prova que GEBDBProvisionaEmpresa() tambem cria as tabelas dos
    // 6 modulos de negocio (Tasks 1-6 deste plano), uma tabela de cada.
    If !GEBDBTableExists("GD1") .Or. !GEBDBTableExists("GV1") .Or. !GEBDBTableExists("GCP1") .Or. ;
        !GEBDBTableExists("GC1") .Or. !GEBDBTableExists("GFN1") .Or. !GEBDBTableExists("GF1")
        ConOut("FALHA: GD1/GV1/GCP1/GC1/GFN1/GF1 nao encontradas apos GEBDBProvisionaEmpresa()")
        lOk := .F.
    EndIf

    // I3 -- prova que GEBDBProvisionaEmpresa() registra a empresa em GE1
    // (catalogo, schema public), nao so' cria o schema do tenant.
    If Len(TCSqlQuery("SELECT GE1_COD FROM public.GE1 WHERE GE1_COD = 'testexp' AND D_E_L_E_T_ = ' '")) == 0
        ConOut("FALHA: GE1 nao contem registro para 'testexp' apos GEBDBProvisionaEmpresa()")
        lOk := .F.
    EndIf

    // Limpeza: GE1 vive em "public" (catalogo real, nao descartavel como
    // o schema do tenant) -- remove o registro de teste para nao deixar
    // lixo acumulando entre execucoes.
    TCSqlExec("DELETE FROM public.GE1 WHERE GE1_COD = 'testexp'")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_testexp CASCADE")
    If lOk
        ConOut("T_GeExp_MIG: PASS")
    Else
        ConOut("T_GeExp_MIG: FAIL")
    EndIf
Return lOk
