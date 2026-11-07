#include "totvs.ch"
#include "GEBDB_CORE.prw"
#include "GEBDB_TENANT.prw"

/*/{Protheus.doc} GEBINIC
    Inicializacao do catalogo GEBAN (schema public). Nao seleciona
    empresa -- isso e' responsabilidade de GEBAN() via GEBDBSetTenant()
    apos o login. Conecta ao Postgres e roda o bootstrap idempotente
    do catalogo (GE1/GE2 + seguranca).
    @type Funcao de inicializacao
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se o catalogo foi provisionado com sucesso, .F. caso
            contrario
/*/
User Function GEBINIC()
    Local lOk := .T.

    If !GEBDBConecta()
        ConOut("ERRO: GEBDBConecta falhou")
        Return .F.
    EndIf

    If !GEBDBProvisionaCatalogo()
        ConOut("ERRO: GEBDBProvisionaCatalogo falhou")
        Return .F.
    EndIf

    ConOut("GEBAN inicializado com sucesso")
Return lOk
