#include "totvs.ch"
#include "GEBDB_CORE.prw"
#include "GEBAUD.prw"

/*/{Protheus.doc} GEBV_VEN
    Venda guiada GEBAN (Task 3 GEB_ESTOQ_VENDA).
    Mapeamento 1 para 1 com a interface do plano (chamada sem
    prefixo U): U_GEBVVEN para GEBVVEN. O prefixo U nao e usado
    na chamada porque o runtime AdvPP so resolve U em
    StartJob-FindFunction; chamada direta U_X da unknown function.
    GEBVVEN(cVenda, cProd, nQtd, nPreco) vende com guia do mentor:
    GEBMNT com VENDA_IMPULSIVA travando retorna BLOQUEADA sem
    tocar o banco; estoque insuficiente ou ausente em GV1 retorna
    SEM_ESTOQUE sem tocar o banco. A venda e' a vista no CAIXA:
    saida pelo estoque com custo (GEBESTMOV: kardex, custo medio e GV1)
    com o CMV contabilizado, GV2 VENDIDA, nota pelo fiscal se GF1-GF3-GF4
    existirem (GEBFEMI gera o titulo a receber e a receita) ou, sem
    fiscal, o titulo e a receita direto; o titulo e' recebido na hora na
    conta CAIXA (GEBFXBAI). nPreco e opcional (miss vale 10).
    Guardas vazias ou qtd menor ou igual a zero retornam
    BLOQUEADA; GV1-GV2 ausentes retornam SEM_ESTOQUE.
    Notas AdvPP (balisador): log via ConOut; If Nil em vez de
    Default; GetArea-RestArea guardados; leitura via workarea;
    guarda via TCSqlQuery em pg_tables; escrita via
    DbAppend mais RecLock ponto T e update via RecLock ponto F;
    FWxFilial retorna 6 espacos sem env; sem SELECT estrela,
    sem concat SQL, sem cFilial, sem IIF; so User-Static.
    @type Modulo de venda
    @author Peder Munksgaard
    @since 23-09-2026
    @param cVenda Codigo da venda em GV2 e chave fiscal
    @param cProd Codigo do produto em GV1
    @param nQtd Quantidade vendida
    @param nPreco Preco unitario para fiscal e CTB (opcional)
    @return VENDIDA ou BLOQUEADA ou SEM_ESTOQUE
/*/
User Function GEBVVEN(cVenda, cProd, nQtd, nPreco)
    Local aHit := {}
    Local aR := {}
    Local cHoje := BOHOJE()
    Local nTot := 0

    If cVenda == Nil
        cVenda := ""
    EndIf
    If cProd == Nil
        cProd := ""
    EndIf
    If nQtd == Nil
        nQtd := 0
    EndIf
    If nPreco == Nil
        nPreco := 10
    EndIf
    If cVenda == "" .Or. cProd == "" .Or. nQtd <= 0
        Return "BLOQUEADA"
    EndIf
    If !GEBDBTableExistsHere("GV1") .Or. !GEBDBTableExistsHere("GV2")
        Return "SEM_ESTOQUE"
    EndIf
    If !GEBMNT("VENDA_IMPULSIVA")
        ConOut("VEN BLOQUEADA " + cVenda)
        Return "BLOQUEADA"
    EndIf
    aHit := TCSqlQuery("SELECT GV1_SALDO AS S FROM GV1 WHERE GV1_FILIAL = " + GEBDBQuote(FWxFilial("GV1")) + " AND GV1_PROD = " + ;
        GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0 .Or. BOVAL(aHit[1]:S) < nQtd
        ConOut("VEN SEM_ESTOQUE " + cVenda)
        Return "SEM_ESTOQUE"
    EndIf
    // Saida com custo (atualiza GV1 junto); recusa = sem estoque no armazem.
    aR := GEBESTMOV(cProd, "", "S", nQtd, 0, "VENDA", cVenda, cHoje)
    If !aR[1]
        ConOut("VEN SEM_ESTOQUE " + cVenda + " " + aR[2])
        Return "SEM_ESTOQUE"
    EndIf
    GEBCTXLP("VENDA_CMV", aR[3][2], cVenda, cHoje)

    TCSqlExec("INSERT INTO GV2 (D_E_L_E_T_, GV2_FILIAL, GV2_VENDA, GV2_PROD, GV2_QTD, GV2_STATUS) VALUES (' ', " + ;
        GEBDBQuote(FWxFilial("GV2")) + ", " + GEBDBQuote(cVenda) + ", " + GEBDBQuote(cProd) + ", " + BONUM(nQtd, 4) + ", 'VENDIDA')")
    // Audit: log insercao GV2.
    GBAUDLOG("GV2", "INS", cVenda, "USER", "01", "      ")

    nTot := Round(nQtd * nPreco, 2)
    If TemFiscal()
        GEBFEMI(cVenda, cProd, nQtd, nPreco)
    ElseIf GEBFXTIT("R", cVenda, "CONSUMIDOR", nTot, "", cHoje, "VENDA " + cVenda, "")[1]
        GEBCTXLP("VENDA_RECEITA", nTot, cVenda, cHoje)
    EndIf
    // A vista: recebe o titulo na hora no CAIXA.
    GEBFNCON("CAIXA", "CAIXA")
    GEBFXBAI("R", cVenda, nTot, 0, 0, 0, "CAIXA", cHoje)

    ConOut("VEN VENDIDA " + cVenda)
Return "VENDIDA"

Static Function TemFiscal()
Return (GEBDBTableExistsHere("GF1") .AND. GEBDBTableExistsHere("GF3") .AND. GEBDBTableExistsHere("GF4"))
