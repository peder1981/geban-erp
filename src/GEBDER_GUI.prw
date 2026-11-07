#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBDER_GUI
    Guia da Derrama do IBS/CBS a partir da apuracao GF5.
    GEBDGER(cComp) le o saldo ativo de GF5 na competencia AAAAMM e cria ou
    atualiza a guia GD<cComp> com o titulo a pagar no financeiro
    (GEBDERGUIA): vencimento no dia DER_DIA_IBSCBS (padrao 20) do mes
    seguinte em dia util, conta 2.01.004. Reapurar atualiza a guia enquanto
    nao houver pagamento; depois, a diferenca vira guia complementar.
    Empresa do Simples (GEBREGIME) recolhe o IBS/CBS no DAS: nao gera guia.
    @type Modulo de geracao
    @author Peder Munksgaard
    @since 23-09-2026
    @param cComp Competencia AAAAMM lida em GF5
    @return Codigo da guia gravada (GD mais cComp ou a complementar), ou vazio se nao gerou
/*/
User Function GEBDGER(cComp)
    Local aHit := {}
    Local aR := {}
    Local cVenc := ""

    If cComp == Nil
        cComp := ""
    EndIf
    If cComp == ""
        Return ""
    EndIf
    If !GEBDBTableExistsHere("GF5")
        Return ""
    EndIf
    If GEBREGIME() == "SIMPLES"
        ConOut("GER " + cComp + " Simples: IBS/CBS recolhido no DAS")
        Return ""
    EndIf
    aHit := TCSqlQuery("SELECT GF5_SALDO AS S FROM GF5 WHERE GF5_FILIAL = " + GEBDBQuote(FWxFilial("GF5")) + " AND GF5_COMP = " + ;
        GEBDBQuote(cComp) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return ""
    EndIf
    cVenc := GEBSNVENC(cComp, Val(BOPARM("DER_DIA_IBSCBS", "20")))
    If !BODATAOK(cVenc)
        // Competencia fora do formato AAAAMM (dados antigos): vence hoje.
        cVenc := BOHOJE()
    EndIf
    aR := GEBDERGUIA("GD" + cComp, "IBSCBS", cComp, Max(Round(BOVAL(aHit[1]:S), 2), 0), cVenc, "2.01.004", "FISCO")
    ConOut("GER " + cComp + " " + aR[2])
Return aR[3]
