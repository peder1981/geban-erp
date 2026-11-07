#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBDER_BAI
    Baixa da guia da Derrama pelo financeiro (GEBDERPAGA): todos os titulos
    abertos da guia sao baixados na conta informada (padrao DER_CONTA, ou
    CAIXA), o dinheiro sai da conta e a contabilizacao e' D obrigacao /
    C conta financeira. A baixa do ultimo titulo baixa a guia e as parcelas.
    @type Modulo de baixa
    @author Peder Munksgaard
    @since 23-09-2026
    @param cGuia Codigo da guia em GD1
    @param cConta Conta financeira (opcional)
    @param cData Data do pagamento AAAAMMDD (opcional; padrao hoje)
    @return .T. se pagou, .F. se nao
/*/
User Function GEBDBAI(cGuia, cConta, cData)
    Local aR := {}

    If cGuia == Nil
        cGuia := ""
    EndIf
    If cGuia == ""
        Return .F.
    EndIf
    If !GEBDBTableExistsHere("GD1")
        Return .F.
    EndIf
    aR := GEBDERPAGA(cGuia, cConta, cData)
    ConOut("BAI " + cGuia + " " + aR[2])
Return aR[1]
