#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/_init.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBCRY.prw"

/*/{Protheus.doc} T_GEBCRY
    Pagamento crypto (src/GEBCRY.prw): lista fechada de moedas, cadastro
    de wallet (GCK1), pagamento auditado do cupom (GCK2) e cotacao
    CoinGecko. A parte de rede e' tolerada: sem internet o teste cobre os
    caminhos deterministicos e registra o salto da cotacao.
    Schema descartavel test_gebcry.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 26/11/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBCRY()
    Local lOk := .T.
    Local aR := {}
    Local aHit := {}
    Local cEnd := "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq"

    If !GEBDBConecta()
        ConOut("T_GEBCRY FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebcry CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebcry")
    TCSqlExec("SET search_path TO test_gebcry")
    lOk := Chk(GENMIG() .And. GEBCRYMIG(), "mig", lOk)
    ConOut("=== T_GEBCRY ===")

    // 1. Lista fechada: BTC, ETH, XMR, USDC, USDT.
    aR := GEBCRYMOEDAS()
    lOk := Chk(Len(aR) == 5, "moedas", lOk)
    lOk := Chk(aR[1][1] == "BTC" .And. aR[2][1] == "ETH" .And. aR[3][1] == "XMR" .And. aR[4][1] == "USDC" .And. aR[5][1] == "USDT", "moedas ids", lOk)

    // 2. Wallet: validacoes e persistencia.
    lOk := Chk(!GEBCRYWAL("DOGE", cEnd, "S")[1], "moeda invalida", lOk)
    lOk := Chk(GEBCRYWAL("BTC", cEnd, "S")[1], "wallet btc", lOk)
    aHit := TCSqlQuery("SELECT GCK1_ENDERECO AS E, GCK1_ATIVO AS A FROM GCK1 WHERE GCK1_MOEDA = 'BTC' AND D_E_L_E_T_ = ' '")
    lOk := Chk(Len(aHit) == 1 .And. BOCOL(aHit[1]:E) == cEnd .And. BOCOL(aHit[1]:A) == "S", "wallet gravada", lOk)
    // Regravar substitui (soft-delete + insert).
    lOk := Chk(GEBCRYWAL("BTC", "1A1zP1", "S")[1], "wallet regravar", lOk)
    aHit := TCSqlQuery("SELECT GCK1_ENDERECO AS E FROM GCK1 WHERE GCK1_MOEDA = 'BTC' AND D_E_L_E_T_ = ' '")
    lOk := Chk(Len(aHit) == 1 .And. BOCOL(aHit[1]:E) == "1A1zP1", "wallet substituida", lOk)
    // Endereco vazio desativa.
    lOk := Chk(GEBCRYWAL("BTC", "", "S")[1], "wallet desativar", lOk)
    aHit := TCSqlQuery("SELECT GCK1_ATIVO AS A FROM GCK1 WHERE GCK1_MOEDA = 'BTC' AND D_E_L_E_T_ = ' '")
    lOk := Chk(BOCOL(aHit[1]:A) == "N", "wallet inativa", lOk)
    lOk := Chk(GEBCRYWAL("BTC", "1A1zP1eBV4YqeZqSypBkMYbB", "S")[1], "wallet reativar", lOk)

    // 3. Listagem.
    aR := GEBCRYWALLST()
    lOk := Chk(aR[1] .And. (Len(aR[3]) >= 2), "lista wallets", lOk)

    // 4. Pagamento auditado do cupom (GCK2).
    lOk := Chk(GEBCRYPAGA("CUP1", "BTC", "1A1zP1", 100, 0.0005, 200000)[1], "paga grava", lOk)
    aR := GEBCRYPAGOS("CUP1")
    lOk := Chk(aR[1] .And. (Len(aR[3]) == 2), "pagos lista", lOk)
    If Len(aR[3]) == 2
        lOk := Chk(aR[3][1][1] == "moeda" .And. aR[3][2][1] == "BTC" .And. (aR[3][2][3] == 100) .And. (aR[3][2][4] == 0.0005), "pago linha", lOk)
    EndIf

    // 5. QR/cotacao: caminhos deterministicos de erro.
    aR := GEBCRYQRCODE("DOGE", 100)
    lOk := Chk(!aR[1], "qr moeda invalida", lOk)
    aR := GEBCRYQRCODE("BTC", 0)
    lOk := Chk(!aR[1], "qr valor zero", lOk)
    aR := GEBCRYQRCODE("XMR", 100)
    lOk := Chk(!aR[1] .And. ("wallet_nao_cadastrada" $ BOSTR(aR[2])), "qr sem wallet", lOk)

    // 6. Caminho feliz depende da rede (CoinGecko). Sem rede: registra e segue.
    aR := GEBCRYCOT("BTC")
    If Len(aR) > 0 .And. aR[1][2] > 0
        aR := GEBCRYQRCODE("BTC", 342.14)
        lOk := Chk(aR[1], "qr btc ok", lOk)
        If aR[1]
            lOk := Chk(Left(aR[3][1], 8) == "bitcoin:" .And. (aR[3][2] == "1A1zP1eBV4YqeZqSypBkMYbB") .And. (aR[3][3] > 0), "qr uri bitcoin", lOk)
        EndIf
    Else
        ConOut("  SKIP cotacao indisponivel (sem rede para CoinGecko)")
    EndIf

    TCSqlExec("SET search_path TO test_gebcry")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebcry CASCADE")

    If lOk
        ConOut("T_GEBCRY PASS")
    Else
        ConOut("T_GEBCRY FAIL")
    EndIf
Return lOk

Static Function Chk(lCond, cMsg, lOk)
    If lCond
        ConOut("  OK " + cMsg)
    Else
        ConOut("  FAIL " + cMsg)
    EndIf
Return lCond .And. lOk
