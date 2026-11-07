#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBFIN_CON
    Lancamentos financeiros GEBAN (Task 2 GEB_FIN).
    Mapeamento 1:1 com as interfaces do plano (chamadas sem prefixo U_):
    U_GEBFNREC -> GEBFNREC | U_GEBFNPAG -> GEBFNPAG.
    O prefixo U_ nao e usado nas chamadas porque o runtime AdvPP so
    resolve U_ em StartJob/FindFunction; chamada direta U_X() da
    "unknown function".
    GEBFNREC(cDoc, cCli, nValor, dVenc) lanca titulo a receber pelo
    financeiro (GEBFXTIT: GFN2 + complemento GFX2) com vencimento dVenc
    (vazio = a vista) e contabiliza FIN_RECEITA (D clientes / C outras
    receitas); .F. se doc vazio, valor menor ou igual a zero ou DOC
    duplicado na filial.
    GEBFNPAG(cDoc, cForn, nValor, dVenc) lanca titulo a pagar com as
    mesmas regras e contabiliza FIN_DESPESA (D despesas gerais /
    C fornecedores); antes de tocar o banco passa pela guia do mentor
    GEBMNT("PAG_IMPULSIVO") do nucleo (travado retorna .F. sem gravar).
    dVenc aceita string YYYYMMDD ou Date (convertida via DToS com
    ValType == "D"); gravada como texto em GFN2_VENC/GFN3_VENC.
    Notas AdvPP (balisador): log via ConOut; If Nil em vez de
    Default; GetArea/RestArea guardados; leitura via workarea;
    guarda via TCSqlQuery em pg_tables; escrita via DbAppend
    mais RecLock ponto T; FWxFilial retorna 6 espacos sem env;
    sem SELECT estrela, sem concat SQL, sem cFilial, sem IIF;
    so User/Static.
    @type Modulo de lancamentos
    @author Peder Munksgaard
    @since 23/09/2026
    @param cDoc Documento do titulo em GFN2/GFN3
    @param cCli Cliente do titulo a receber (GEBFNREC)
    @param cForn Fornecedor do titulo a pagar (GEBFNPAG)
    @param nValor Valor do titulo
    @param dVenc Vencimento YYYYMMDD ou Date
    @return .T. se lancou, .F. se recusou
/*/
User Function GEBFNREC(cDoc, cCli, nValor, dVenc)
    Local aR := {}

    If cDoc == Nil
        cDoc := ""
    EndIf
    If cCli == Nil
        cCli := ""
    EndIf
    If nValor == Nil
        nValor := 0
    EndIf
    If cDoc == ""
        Return .F.
    EndIf
    If nValor <= 0
        Return .F.
    EndIf
    aR := FINTitulo("R", cDoc, cCli, nValor, dVenc, "RECEBER")
    If !aR[1]
        ConOut("REC recusado " + cDoc + " " + aR[2])
        Return .F.
    EndIf
    GEBCTXLP("FIN_RECEITA", nValor, cDoc, aR[3])
    ConOut("REC " + cDoc + " " + cValToChar(nValor))
Return .T.

User Function GEBFNPAG(cDoc, cForn, nValor, dVenc)
    Local aR := {}

    If cDoc == Nil
        cDoc := ""
    EndIf
    If cForn == Nil
        cForn := ""
    EndIf
    If nValor == Nil
        nValor := 0
    EndIf
    If cDoc == ""
        Return .F.
    EndIf
    If nValor <= 0
        Return .F.
    EndIf
    If !GEBMNT("PAG_IMPULSIVO")
        ConOut("PAG bloqueado " + cDoc)
        Return .F.
    EndIf
    aR := FINTitulo("P", cDoc, cForn, nValor, dVenc, "PAGAR")
    If !aR[1]
        ConOut("PAG recusado " + cDoc + " " + aR[2])
        Return .F.
    EndIf
    GEBCTXLP("FIN_DESPESA", nValor, cDoc, aR[3])
    ConOut("PAG " + cDoc + " " + cValToChar(nValor))
Return .T.

// Titulo de parcela unica com o vencimento pedido: emissao hoje (ou no proprio
// vencimento, se ja passou). Devolve {lOk, cMsg, cEmissao}.
Static Function FINTitulo(cTipo, cDoc, cParc, nValor, dVenc, cOrigem)
    Local cVenc := ""
    Local cEmis := BOHOJE()
    Local cCond := ""
    Local aR := {}
    If ValType(dVenc) == "D"
        cVenc := DToS(dVenc)
    ElseIf ValType(dVenc) == "C"
        cVenc := BODATA(dVenc)
    EndIf
    If !(cVenc == "")
        If cVenc < cEmis
            cEmis := cVenc
        Else
            cCond := cValToChar(BODIAS(cEmis, cVenc))
        EndIf
    EndIf
    aR := GEBFXTIT(cTipo, cDoc, cParc, nValor, cCond, cEmis, cOrigem, "")
Return {aR[1], aR[2], cEmis}
