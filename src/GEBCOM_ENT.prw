#include "totvs.ch"
#include "GEBDB_CORE.prw"
#include "GEBAUD.prw"

/*{Protheus.doc} GEBCOM_ENT
    Entrada de compra GEBAN (Task 4 GEB_COM).
    Mapeamento 1:1 com a interface do plano (chamada sem prefixo U_):
    U_GEBCMENT -> GEBCMENT.
    O prefixo U_ nao e usado na chamada porque o runtime AdvPP so
    resolve U_ em StartJob/FindFunction; chamada direta U_X() da
    "unknown function".
    GEBCMENT(cNF, cPed) recebe todo o pendente do pedido pelo documento
    de entrada do backoffice (GEBCPXENT): estoque a custo de entrada
    (kardex, custo medio), titulo a pagar pela condicao do pedido (a
    vista se nao tiver), contabilizacao COMPRA_ESTOQUE, credito de
    IBS/CBS, GCP3 RECEBIDO e GCP5 RECEBIDA. Antes passa pela guia do
    mentor GEBMNT("PAG_IMPULSIVO"). Retorna .F. sem tocar o banco se NF
    ou pedido vazio, tabela GCP3/GCP4/GCP5 ausente, pedido inexistente
    ou ja RECEBIDO, pedido sem itens, NF duplicada ou mentor travado.
    Notas AdvPP (balisador): log via ConOut; If Nil em vez de
    Default; GetArea/RestArea guardados; leitura via workarea;
    guarda via TCSqlQuery em pg_tables; escrita nova via
    DbAppend mais RecLock ponto T e update via RecLock ponto F;
    FWxFilial retorna 6 espacos sem env; sem SELECT estrela, sem
    concat SQL, sem cFilial, sem IIF; so User/Static.
    @type Modulo de entrada
    @author Peder Munksgaard
    @since 23/09/2026
    @param cNF Numero da nota de entrada em GCP5/GFN3 (GEBCMENT)
    @param cPed Numero do pedido em GCP3/GCP4 (GEBCMENT)
    @return .T. se entrou, .F. se recusou
/*/
User Function GEBCMENT(cNF, cPed)
    Local aHit := {}
    Local aR := {}

    If cNF == Nil
        cNF := ""
    EndIf
    If cPed == Nil
        cPed := ""
    EndIf
    If cNF == "" .Or. cPed == ""
        Return .F.
    EndIf
    If !GEBDBTableExistsHere("GCP3") .Or. !GEBDBTableExistsHere("GCP4") .Or. !GEBDBTableExistsHere("GCP5")
        Return .F.
    EndIf
    aHit := TCSqlQuery("SELECT GCP3_STATUS AS S FROM GCP3 WHERE GCP3_FILIAL = " + GEBDBQuote(FWxFilial("GCP3")) + " AND GCP3_NUM = " + ;
        GEBDBQuote(cPed) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        ConOut("ENT sem pedido " + cPed)
        Return .F.
    EndIf
    If AllTrim(BOCOL(aHit[1]:S)) == "RECEBIDO"
        ConOut("ENT ja recebida " + cPed)
        Return .F.
    EndIf
    If Len(TCSqlQuery("SELECT GCP5_NF FROM GCP5 WHERE GCP5_FILIAL = " + GEBDBQuote(FWxFilial("GCP5")) + " AND GCP5_NF = " + ;
            GEBDBQuote(cNF) + " AND D_E_L_E_T_ = ' '")) > 0
        ConOut("ENT duplicada " + cNF)
        Return .F.
    EndIf
    aHit := TCSqlQuery("SELECT COALESCE(SUM(GCP4_QTD * GCP4_PRECO), 0) AS T FROM GCP4 WHERE GCP4_FILIAL = " + GEBDBQuote(FWxFilial("GCP4")) + ;
        " AND GCP4_PED = " + GEBDBQuote(cPed) + " AND D_E_L_E_T_ = ' '")
    If BOVAL(aHit[1]:T) <= 0
        ConOut("ENT sem itens " + cPed)
        Return .F.
    EndIf
    If !GEBMNT("PAG_IMPULSIVO")
        ConOut("ENT pag recusou " + cNF)
        Return .F.
    EndIf

    aR := GEBCPXENT(cNF, cPed, {}, 0, BOHOJE(), {})
    If !aR[1]
        ConOut("ENT recusada " + cNF + " " + aR[2])
        Return .F.
    EndIf

    // Audit: log entrada GCP3/GCP4/GCP5.
    GBAUDLOG("GCP3", "ALT", cPed, "USER", "01", "      ")
    GBAUDLOG("GCP4", "INS", cPed, "USER", "01", "      ")
    GBAUDLOG("GCP5", "INS", cNF, "USER", "01", "      ")

    ConOut("ENT RECEBIDA " + cNF + " " + cValToChar(aR[3][1]))
Return .T.
