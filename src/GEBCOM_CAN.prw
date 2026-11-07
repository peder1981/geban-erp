#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBCOM_CAN
    Cancelamento de pedido de compra (GCP3).
    O pedido deve estar em status ABERTO para ser cancelado.
    A cancelacao marca GCP3 com STATUS = 'CANCELADO' e软-delete dos
    itens em GCP4 (D_E_L_E_T_ = '*').
    @type Operacao compras
    @author Peder Munksgaard
    @since 21/10/2026
    @param cPedido Numero do pedido em GCP3
    @return {lOk, cMsg}
/*/
User Function GEBCMPEDCAN(cPedido)
    Local aArea   := GetArea()
    Local cFil3   := FWxFilial("GCP3")
    Local cFil4   := FWxFilial("GCP4")
    Local lOk     := .T.
    Local aHit    := {}
    Local cStatus := ""

    cPedido := BOCOL(cPedido)

    If cPedido == ""
        Return {.F., "pedido_vazio"}
    EndIf

    If !GEBDBTableExistsHere("GCP3")
        Return {.F., "tabela_gcp3_nao_existente"}
    EndIf

    aHit := TCSqlQuery("SELECT GCP3_STATUS FROM GCP3 " + ;
        "WHERE GCP3_FILIAL = " + GEBDBQuote(cFil3) + " " + ;
        "AND GCP3_NUM = " + GEBDBQuote(cPedido) + " " + ;
        "AND D_E_L_E_T_ = ' '")

    If Len(aHit) == 0
        Return {.F., "pedido_nao_encontrado: " + cPedido}
    EndIf

    cStatus := BOCOL(aHit[1]:GCP3_STATUS)

    If cStatus != "ABERTO"
        Return {.F., "pedido_nao_pode_ser_cancelado: status=" + cStatus}
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf

    TCSqlExec("UPDATE GCP3 SET GCP3_STATUS = 'CANCELADO' " + ;
        "WHERE GCP3_FILIAL = " + GEBDBQuote(cFil3) + " " + ;
        "AND GCP3_NUM = " + GEBDBQuote(cPedido) + " " + ;
        "AND D_E_L_E_T_ = ' '")

    If GEBDBTableExistsHere("GCP4")
        TCSqlExec("UPDATE GCP4 SET D_E_L_E_T_ = '*' " + ;
            "WHERE GCP4_FILIAL = " + GEBDBQuote(cFil4) + " " + ;
            "AND GCP4_PED = " + GEBDBQuote(cPedido) + " " + ;
            "AND D_E_L_E_T_ = ' '")
    EndIf

Return {.T., "pedido_cancelado: " + cPedido}
