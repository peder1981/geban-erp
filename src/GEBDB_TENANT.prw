#include "totvs.ch"
#include "GEBDB_CORE.prw"
#include "GENUC_MIG.prw"
#include "GEBEXP_MIG.prw"
#include "GEBDER_MIG.prw"
#include "GEBV_MIG.prw"
#include "GEBCOM_MIG.prw"
#include "GEBPERIF_MIG.prw"
#include "GEBCTB_MIG.prw"
#include "GEBFIN_MIG.prw"
#include "GEBFIS_MIG.prw"
#include "GEBFIL_MIG.prw"
#include "GEBUNI_MIG.prw"

/*/{Protheus.doc} GEBDB_TENANT
    Conexao Postgres e provisionamento multi-tenant (schema por empresa).
    Schema "public" = catalogo global (GE1, GE2, seguranca) -- existe
    antes de saber qual empresa esta logando. Schema "emp_<cod>" =
    dados da empresa (GE3-GE5, GEH, GEI, e modulos de negocio).
    @type Modulo de infraestrutura de dados
    @author Peder Munksgaard
    @since 23/09/2026
/*/

User Function GEBDBConecta()
    Local cHost := GetEnv("GEBAN_PG_HOST")
    Local cPort := GetEnv("GEBAN_PG_PORT")
    Local cDb   := GetEnv("GEBAN_PG_DB")
    Local cUser := GetEnv("GEBAN_PG_USER")
    Local cPass := GetEnv("GEBAN_PG_PASSWORD")
    Local oConn := Nil

    If cHost == Nil .Or. cHost == ""
        ConOut("GEBDBConecta: GEBAN_PG_HOST nao definido")
        Return .F.
    EndIf

    oConn := DbConnection():New("POSTGRES", cHost, Val(cPort), cDb, cUser, cPass)
    If !oConn:Connect()
        ConOut("GEBDBConecta: FALHA - " + oConn:GetError())
        Return .F.
    EndIf

    DBSetDriver("TOPCONN")
    ConOut("GEBDBConecta: conectado em " + cHost + ":" + cPort + "/" + cDb)
Return .T.

User Function GEBDBSchemaValido(cCod)
    Local cC := ""
    If cCod == Nil .Or. AllTrim(cCod) == ""
        Return .F.
    EndIf
    cC := Lower(AllTrim(cCod))
Return (cC == StrTran(StrTran(StrTran(cC, "-", ""), " ", ""), ";", "")) .And. ;
    Len(cC) <= 30 .And. IsAlphaNumUnder(cC)

Static Function IsAlphaNumUnder(cTxt)
    Local nI := 0
    Local cCh := ""
    For nI := 1 To Len(cTxt)
        cCh := SubStr(cTxt, nI, 1)
        If !(cCh >= "a" .And. cCh <= "z") .And. !(cCh >= "0" .And. cCh <= "9") .And. cCh != "_"
            Return .F.
        EndIf
    Next nI
Return .T.

// GEBDBSchemaExists(cCod) -> .T./.F. -- o schema emp_<cod> realmente
// existe no Postgres? GEBDBSchemaValido() so valida o FORMATO do
// codigo; SET search_path aceita um schema inexistente sem erro
// (Postgres cai silenciosamente para o proximo schema do search_path),
// entao GEBDBSetTenant() precisa desta checagem antes de trocar.
User Function GEBDBSchemaExists(cCod)
    Local aChk := {}
    If !GEBDBSchemaValido(cCod)
        Return .F.
    EndIf
    aChk := TCSqlQuery("SELECT nspname FROM pg_namespace WHERE nspname = 'emp_" + Lower(AllTrim(cCod)) + "'")
Return (Len(aChk) > 0)

// GEBDBTenantAtual() -> codigo da empresa da sessao (schema corrente
// emp_<cod>), ou "" fora de uma empresa (catalogo/public).
User Function GEBDBTenantAtual()
    Local aRow := TCSqlQuery("SELECT current_schema()::text AS SCH")
    Local cSch := ""
    If Len(aRow) > 0
        cSch := Lower(AllTrim(cValToChar(aRow[1]:SCH)))
    EndIf
    If Left(cSch, 4) != "emp_"
        Return ""
    EndIf
Return SubStr(cSch, 5)

User Function GEBDBSetTenant(cCod)
    Local lResult := .F.
    If !GEBDBSchemaValido(cCod)
        ConOut("GEBDBSetTenant: codigo de empresa invalido: " + cValToChar(cCod))
        Return .F.
    EndIf
    If !GEBDBSchemaExists(cCod)
        ConOut("GEBDBSetTenant: empresa nao provisionada: " + cCod)
        Return .F.
    EndIf
    lResult := TCSqlExec("SET search_path TO emp_" + Lower(AllTrim(cCod)) + ", public")
    If lResult
        ConOut("GEBDBSetTenant(" + cCod + "): OK")
    Else
        ConOut("GEBDBSetTenant(" + cCod + "): FAIL")
    EndIf
Return lResult

User Function GEBDBProvisionaCatalogo()
    Local lOk := .T.
    TCSqlExec("SET search_path TO public")
    lOk := (lOk .And. GENMIGCatalogo())
    lOk := (lOk .And. TCSecMIG())
    If lOk
        ConOut("GEBDBProvisionaCatalogo: OK")
    Else
        ConOut("GEBDBProvisionaCatalogo: FAIL")
    EndIf
Return lOk

// GEBDBProvisionaEmpresa(cCod, cNome) -> .T./.F. -- cria o schema
// emp_<cod>, roda GENMIGEmpresa()/GEBEXPCriaAuditoria() dentro dele e
// registra a empresa em GE1 (catalogo, schema "public"). O INSERT em
// GE1 e' idempotente (SELECT antes de inserir) para permitir chamar
// esta funcao de novo para o mesmo cCod sem duplicar o cadastro.
User Function GEBDBProvisionaEmpresa(cCod, cNome)
    Local lOk := .T.
    Local cFil := FWxFilial("GE1")
    Local aChk := {}
    If !GEBDBSchemaValido(cCod)
        ConOut("GEBDBProvisionaEmpresa: codigo invalido: " + cValToChar(cCod))
        Return .F.
    EndIf
    If !TCSqlExec("CREATE SCHEMA IF NOT EXISTS emp_" + Lower(AllTrim(cCod)))
        Return .F.
    EndIf
    If !GEBDBSetTenant(cCod)
        Return .F.
    EndIf
    lOk := (lOk .And. GENMIGEmpresa())
    lOk := (lOk .And. GEBEXPCriaAuditoria())
    lOk := (lOk .And. GEBDMIG())
    lOk := (lOk .And. GEBVMIG())
    lOk := (lOk .And. GEBCMMIG())
    lOk := (lOk .And. GEBCMIG())
    lOk := (lOk .And. GEBPERIFMIG())
    lOk := (lOk .And. GEBFNMIG())
    lOk := (lOk .And. GEBFMIG())
    lOk := (lOk .And. GEFFILMIG())
    lOk := (lOk .And. GEUNIMIG())

    If lOk
        aChk := TCSqlQuery("SELECT GE1_COD FROM public.GE1 WHERE GE1_FILIAL = '" + cFil + ;
            "' AND GE1_COD = " + GEBDBQuote(Lower(AllTrim(cCod))) + " AND D_E_L_E_T_ = ' '")
        If Len(aChk) == 0
            lOk := (lOk .And. TCSqlExec("INSERT INTO public.GE1 (D_E_L_E_T_, GE1_FILIAL, GE1_COD, GE1_NOME) VALUES (' ', '" + ;
                cFil + "', " + GEBDBQuote(Lower(AllTrim(cCod))) + ", '" + StrTran(AllTrim(cNome), "'", "''") + "')"))
        EndIf
    EndIf

    If lOk
        ConOut("GEBDBProvisionaEmpresa(" + cCod + "): OK")
    Else
        ConOut("GEBDBProvisionaEmpresa(" + cCod + "): FAIL")
    EndIf
Return lOk
