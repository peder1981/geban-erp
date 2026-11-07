#include "totvs.ch"
#include "GEBDB_CORE.prw"
#include "GEBAUD.prw"

/*/{Protheus.doc} GEBFIN_BAI
    Baixa financeira GEBAN (Task 3 GEB_FIN).
    Mapeamento 1:1 com a interface do plano (chamada sem prefixo U_):
    U_GEBFNBAI -> GEBFNBAI. O prefixo U_ nao e usado na chamada
    porque o runtime AdvPP so resolve U_ em StartJob/FindFunction;
    chamada direta U_X() da "unknown function".
    GEBFNBAI(cTipo, cDoc, nValor) baixa titulo a receber (cTipo
    REC/RECEBER em GFN2) ou a pagar (cTipo PAG/PAGAR em GFN3):
    o valor e' limitado ao saldo (pago a maior quita) e a baixa e'
    feita pelo financeiro (GEBFXBAI) na conta CAIXA (criada se faltar):
    historico em GFX3, movimento em GFN4, saldo em GFN1 e contabilizacao
    pela conta do titulo (FIN_REC/FIN_PAG). SALDO zerado muda STATUS
    para RECEBIDA ou PAGA e sincroniza a origem (guia da Derrama, fiado). Baixa de pagar passa antes pela guia do mentor
    GEBMNT("PAG_IMPULSIVO") (travado retorna .F. sem tocar o
    banco). Retorna .F. se tipo invalido, doc vazio, valor menor
    ou igual a zero, tabela ausente ou titulo inexistente.
    Notas AdvPP (balisador): log via ConOut; If Nil em vez de
    Default; GetArea/RestArea guardados; leitura via workarea;
    guarda via TCSqlQuery em pg_tables; escrita nova via
    DbAppend mais RecLock ponto T e update via RecLock ponto F
    mais MsUnlock; FWxFilial retorna 6 espacos sem env; sem
    SELECT estrela, sem concat SQL, sem cFilial, sem IIF; so
    User/Static.
    @type Modulo de baixa
    @author Peder Munksgaard
    @since 23/09/2026
    @param cTipo REC/RECEBER (receber) ou PAG/PAGAR (pagar)
    @param cDoc Documento do titulo em GFN2/GFN3
    @param nValor Valor da baixa (parcial ou total)
    @return .T. se baixou, .F. se recusou
/*/
User Function GEBFNBAI(cTipo, cDoc, nValor)
    Local aHit := {}
    Local aR := {}
    Local cNorm := ""
    Local cT := ""
    Local cTab := ""
    Local nEf := 0

    If cTipo == Nil
        cTipo := ""
    EndIf
    If cDoc == Nil
        cDoc := ""
    EndIf
    If nValor == Nil
        nValor := 0
    EndIf

    cNorm := Upper(AllTrim(cTipo))
    If cNorm == "PAG" .OR. cNorm == "PAGAR"
        cT := "P"
        cTab := "GFN3"
    ElseIf cNorm == "REC" .OR. cNorm == "RECEBER"
        cT := "R"
        cTab := "GFN2"
    Else
        Return .F.
    EndIf
    If cDoc == ""
        Return .F.
    EndIf
    If nValor <= 0
        Return .F.
    EndIf
    If cT == "P" .And. !GEBMNT("PAG_IMPULSIVO")
        ConOut("BAI bloqueada " + cDoc)
        Return .F.
    EndIf
    If !GEBDBTableExistsHere(cTab)
        Return .F.
    EndIf
    aHit := TCSqlQuery("SELECT " + cTab + "_SALDO AS S FROM " + cTab + " WHERE " + cTab + "_FILIAL = " + GEBDBQuote(FWxFilial(cTab)) + ;
        " AND " + cTab + "_DOC = " + GEBDBQuote(cDoc) + " AND " + cTab + "_STATUS = 'ABERTO' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return .F.
    EndIf
    nEf := Min(nValor, Round(BOVAL(aHit[1]:S), 2))
    If nEf <= 0
        Return .F.
    EndIf
    GEBFNCON("CAIXA", "CAIXA")
    aR := GEBFXBAI(cT, cDoc, nEf, 0, 0, 0, "CAIXA", BOHOJE())
    If !aR[1]
        ConOut("BAI recusada " + cDoc + " " + aR[2])
        Return .F.
    EndIf
    GBAUDLOG(cTab, "ALT", cDoc, "USER", "01", "      ")
    ConOut("BAI " + cNorm + " " + cDoc + " " + cValToChar(nEf))
Return .T.
