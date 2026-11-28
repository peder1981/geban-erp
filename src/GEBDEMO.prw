#include "totvs.ch"

/*/{Protheus.doc} GEBDEMO
    Empresa 99 e' o ambiente de demonstracao local. No modo sob-demanda
    (opcao B) os emuladores SEFAZ/Cielo/CNAB/periferico so' sobem quando
    alguem acessa: esta funcao dispara GET /ensure no watchdog
    (tests/emuladores/demo_watchdog.py, unit geban-demo-watchdog.service,
    127.0.0.1:18768). Arquivo separado e' incluido por GEBWEB.prw (login
    web/PDV) e GEBTUI.prw (login TUI): cada runtime serve um entrypoint
    diferente e precisa ter a funcao compilada junto.
    Fire-and-forget: HttpQuote devolve Nil quando o watchdog esta' fora
    e isso NUNCA pode quebrar o login — no maximo um ConOut de
    diagnostico. Nao retorna nada ao usuario.
    @type Integracao demo
    @author Peder Munksgaard
    @since 05/12/2026
/*/
User Function GEBDEMOENSURE()
    Local cResp := Nil

    cResp := HttpQuote("http://127.0.0.1:18768/ensure", "GET", "", "", 4, {})
    If cResp == Nil .Or. BOCOL(cResp) == ""
        ConOut("GEBDEMOENSURE: watchdog :18768 sem resposta; emuladores demo podem estar frios")
    EndIf
Return
