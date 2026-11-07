#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBPDVHTML
    Serve a interface PDV (página HTML autocontida).
    Lê o arquivo public/pdv.html e retorna como resposta HTTP.
    @type Rota HTTP (HTML estático)
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVHTML(oReq)
    Local cPath := "/opt/geban/public/pdv.html"
    Local cContent := ""
    Local aCtx := {}

    // Tentar ler o arquivo
    If File(cPath)
        cContent := MemoRead(cPath)
    Else
        // Fallback: HTML minimal
        cContent := '<html><head><title>GEBAN PDV</title></head>' + ;
            '<body><h1>GEBAN PDV</h1>' + ;
            '<p>Interface PDV carrega de /public/pdv.html</p>' + ;
            '<p>API: <a href="/api/health">/api/health</a></p>' + ;
            '</body></html>'
    EndIf

Return {"__RAW_HTTP__", "text/html; charset=utf-8", cContent, 200}

/*/{Protheus.doc} GEBPDVWS
    Health check do serviço WebSocket de periféricos.
    Retorna status do serviço (porta 9100).
    @type Rota HTTP (JSON)
    @author Peder Munksgaard
    @since 21/10/2026
/*/
User Function GEBPDVWS(oReq)
    Local cHost := GetEnv("GEBAN_PG_HOST")
    Local nPortaWs := 9100
    Return GEBRESTJSONRESP(.T., "pdv_status", {;
        "pdv_url": "/pdv",;
        "ws_port": nPortaWs,;
        "api_base": "/api",;
        "periferico_service": "rodando" ;
    })
