#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBV_EST
    Saldo e movimento de estoque GEBAN (Task 2 GEB_ESTOQ_VENDA).
    Mapeamento 1 para 1 com a interface do plano (chamada sem
    prefixo U): U_GEBVEST para GEBVEST. O prefixo U nao e usado
    na chamada porque o runtime AdvPP so resolve U em
    StartJob-FindFunction; chamada direta U_X da unknown function.
    GEBVEST(cProd, nQtd) ajusta a quantidade do produto pelo estoque
    com custo (GEBESTMOV no armazem padrao: entrada ao custo medio atual,
    saida ao custo medio), que tambem atualiza GV1 (GEBVESTGV1: produto
    novo nasce com MINIMO 10); retorna o novo saldo de GV1 (0 se produto
    vazio ou GV1 ausente). Saida acima do saldo e' recusada.
    Se o novo saldo ficar abaixo do MINIMO chama
    GEBMNT com ESTOQUE_MINIMO so como alerta (nao trava a
    movimentacao). Miss de mentor libera sem BO, trava so loga.
    Notas AdvPP (balisador): log via ConOut; If Nil em vez de
    Default; GetArea-RestArea guardados; leitura via workarea;
    guarda via TCSqlQuery em pg_tables; escrita via
    DbAppend mais RecLock ponto T e update via RecLock ponto F;
    FWxFilial retorna 6 espacos sem env; sem SELECT estrela,
    sem concat SQL, sem cFilial, sem IIF; so User-Static.
    @type Modulo de estoque
    @author Peder Munksgaard
    @since 23-09-2026
    @param cProd Codigo do produto em GV1
    @param nQtd Quantidade do movimento (positiva ou negativa)
    @return Novo saldo em GV1, 0 se bloqueado por guarda
/*/
User Function GEBVEST(cProd, nQtd)
    Local aR := {}
    Local aHit := {}
    If cProd == Nil
        cProd := ""
    EndIf
    If nQtd == Nil
        nQtd := 0
    EndIf
    If cProd == "" .Or. nQtd == 0 .Or. !GEBDBTableExistsHere("GV1")
        Return 0
    EndIf
    // Ajuste de quantidade pelo estoque com custo (kardex, custo medio atual).
    If nQtd > 0
        aR := GEBESTMOV(cProd, "", "E", nQtd, GEBESTSLD(cProd, "01")[2], "AJUSTE", "GEBVEST", BOHOJE())
    Else
        aR := GEBESTMOV(cProd, "", "S", -nQtd, 0, "AJUSTE", "GEBVEST", BOHOJE())
    EndIf
    If !aR[1]
        ConOut("EST recusado " + cProd + " " + aR[2])
    EndIf
    aHit := TCSqlQuery("SELECT GV1_SALDO AS S FROM GV1 WHERE GV1_FILIAL = " + GEBDBQuote(FWxFilial("GV1")) + " AND GV1_PROD = " + ;
        GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return 0
    EndIf
Return BOVAL(aHit[1]:S)

/*/{Protheus.doc} GEBVESTGV1
    Atualiza so' o saldo antigo GV1 (uso interno do GEBESTMOV, que mantem
    GES1/GES2 e chama esta funcao para as telas antigas). Regras de GV1:
    produto novo nasce com MINIMO 10; abaixo do minimo avisa o mentor.
    @type Modulo de estoque
    @author Peder Munksgaard
    @since 19/10/2026
    @return Novo saldo em GV1, 0 se bloqueado por guarda
/*/
User Function GEBVESTGV1(cProd, nQtd)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GV1")
    Local nSaldo := 0
    Local nMin := 10
    Local lAchou := .F.

    If cProd == Nil
        cProd := ""
    EndIf
    If nQtd == Nil
        nQtd := 0
    EndIf
    If cProd == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return 0
    EndIf

    If !GEBDBTableExistsHere("GV1")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return 0
    EndIf

    DbSelectArea("GV1")
    DbGoTop()
    While !Eof()
        If GV1->GV1_FILIAL == cFil .AND. GV1->GV1_PROD == cProd .AND. GV1->D_E_L_E_T_ == " "
            lAchou := .T.
            nSaldo := GV1->GV1_SALDO + nQtd
            nMin := GV1->GV1_MIN
            RecLock("GV1", .F.)
            GV1->GV1_SALDO := nSaldo
            MsUnlock()
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    If !lAchou
        nSaldo := nQtd
        nMin := 10
        DbSelectArea("GV1")
        DbAppend()
        RecLock("GV1", .T.)
        GV1->GV1_FILIAL := cFil
        GV1->D_E_L_E_T_ := " "
        GV1->GV1_PROD := cProd
        GV1->GV1_SALDO := nSaldo
        GV1->GV1_MIN := nMin
        MsUnlock()
        DbCloseArea()
    EndIf

    If nSaldo < nMin
        GEBMNT("ESTOQUE_MINIMO")
        ConOut("EST MINIMO " + cProd)
    Else
        ConOut("EST " + cProd)
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return nSaldo
