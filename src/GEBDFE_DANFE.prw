#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBDFE_XML.prw"
#include "GEBDFE_QR.prw"
#include "GEBDFE.prw"
#include "GEBDFE_DANFE55.prw"

/*/{Protheus.doc} GEBDFE_DANFE
    DANFE NFC-e (cupom de 80 mm em HTML para imprimir pelo navegador) a
    partir do XML do documento (GDF5): emitente, itens, totais, pagamentos e
    troco, consumidor, chave de acesso em grupos de 4, protocolo, avisos de
    contingencia e de homologacao e o QR Code em SVG (GEBQRSVG, sem
    internet). GEBDFEDANFETXT devolve as mesmas informacoes em linhas de
    texto (segunda via na tela).
    @type Relatorio fiscal
    @author Peder Munksgaard
    @since 19/10/2026
/*/

// Todas as ocorrencias do elemento cTag.
Static Function DANBlocos(cXml, cTag)
    Local aR := {}
    Local cB := ""
    Local nP := 0
    Do While .T.
        cB := GEBDFEBLOCO(cXml, cTag)
        If cB == ""
            Exit
        EndIf
        aAdd(aR, cB)
        nP := At(cB, cXml)
        cXml := SubStr(cXml, nP + Len(cB))
    EndDo
Return aR

// 1234.5 -> "1.234,50" (o Transform do AdvPP nao trata "@E").
Static Function DANMoeda(cVal)
    Local cN := AllTrim(Str(Round(BOVAL(cVal), 2), 20, 2))
    Local cInt := Left(cN, Len(cN) - 3)
    Local cR := ""
    Local cSinal := ""
    If Left(cInt, 1) == "-"
        cSinal := "-"
        cInt := SubStr(cInt, 2)
    EndIf
    Do While Len(cInt) > 3
        cR := "." + Right(cInt, 3) + cR
        cInt := Left(cInt, Len(cInt) - 3)
    EndDo
Return cSinal + cInt + cR + "," + Right(cN, 2)

// CPF 999.999.999-99 ou CNPJ 99.999.999/9999-99 (o Transform do AdvPP nao trata "@R").
Static Function DANDoc(cD)
    If Len(cD) == 11
        Return Left(cD, 3) + "." + SubStr(cD, 4, 3) + "." + SubStr(cD, 7, 3) + "-" + Right(cD, 2)
    EndIf
    If Len(cD) == 14
        Return Left(cD, 2) + "." + SubStr(cD, 3, 3) + "." + SubStr(cD, 6, 3) + "/" + SubStr(cD, 9, 4) + "-" + Right(cD, 2)
    EndIf
Return cD

Static Function DANChave(cCh)
    Local cR := ""
    Local nI := 0
    For nI := 1 To 44 Step 4
        cR += SubStr(cCh, nI, 4) + " "
    Next nI
Return AllTrim(cR)

Static Function DANPag(cTp)
    Local aP := {{"01", "Dinheiro"}, {"02", "Cheque"}, {"03", "Cartao de credito"}, {"04", "Cartao de debito"}, {"05", "Credito loja"}, ;
        {"10", "Vale alimentacao"}, {"11", "Vale refeicao"}, {"12", "Vale presente"}, {"13", "Vale combustivel"}, {"15", "Boleto"}, ;
        {"16", "Deposito"}, {"17", "PIX"}, {"18", "Transferencia"}, {"90", "Sem pagamento"}, {"99", "Outros"}}
    Local nP := AScan(aP, {|x| x[1] == cTp})
    If nP == 0
        Return cTp
    EndIf
Return aP[nP][2]

Static Function DANDh(cDh)
    If Len(cDh) < 19
        Return cDh
    EndIf
Return SubStr(cDh, 9, 2) + "/" + SubStr(cDh, 6, 2) + "/" + Left(cDh, 4) + " " + SubStr(cDh, 12, 8)

/*/{Protheus.doc} GEBDFEDANFE
    DANFE em HTML: NFC-e (80 mm) ou, para modelo 55, o A4 (GEBDFEDANFE55).
    @type Relatorio fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, cHtml}
/*/
User Function GEBDFEDANFE(cChave)
    Local aD := GEBDFEDOC(BOCOL(cChave))
    Local aL := {}
    Local cH := ""
    Local nI := 0
    If Len(aD) == 0
        Return {.F., "documento_inexistente", ""}
    EndIf
    If aD[5] == "55"
        Return GEBDFEDANFE55(cChave)
    EndIf
    aL := GEBDFEDANFETXT(cChave)[3]
    cH := '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' + ;
        "<title>DANFE NFC-e</title><style>body{margin:0;background:#fff;color:#000}.c{width:72mm;margin:0 auto;padding:2mm;" + ;
        "font:11px/1.35 'Courier New',monospace}.t{text-align:center}.b{font-weight:bold}.q{display:block;margin:2mm auto;width:38mm;height:38mm}" + ;
        "hr{border:0;border-top:1px dashed #000;margin:1.5mm 0}table{width:100%;border-collapse:collapse}td{vertical-align:top;padding:0}" + ;
        "td.r{text-align:right}.av{border:1px solid #000;padding:1mm;margin:1mm 0;text-align:center;font-weight:bold}" + ;
        "@media print{@page{size:80mm auto;margin:0}}</style></head><body><div class=" + '"c">'
    For nI := 1 To Len(aL)
        If aL[nI] == "---"
            cH += "<hr>"
        ElseIf Left(aL[nI], 3) == "!! "
            cH += '<div class="av">' + SubStr(aL[nI], 4) + "</div>"
        ElseIf Left(aL[nI], 3) == "== "
            cH += '<div class="t b">' + SubStr(aL[nI], 4) + "</div>"
        ElseIf Left(aL[nI], 3) == "QR "
            cH += '<div class="q">' + GEBQRSVG(SubStr(aL[nI], 4), 3) + "</div>"
        ElseIf Left(aL[nI], 3) == "|| "
            cH += "<table><tr><td>" + StrTran(SubStr(aL[nI], 4), "|", '</td><td class="r">') + "</td></tr></table>"
        Else
            cH += '<div class="t">' + aL[nI] + "</div>"
        EndIf
    Next nI
    cH := StrTran(cH, '<svg ', '<svg style="width:100%;height:100%" ')
Return {.T., "ok", cH + "</div></body></html>"}

/*/{Protheus.doc} GEBDFEDANFETXT
    Linhas do DANFE NFC-e (marcadores: "== " titulo, "!! " aviso,
    "|| a|b" linha com valor a direita, "QR " conteudo do QR, "---" linha).
    @type Relatorio fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, aLinhas}
/*/
User Function GEBDFEDANFETXT(cChave)
    Local aD := GEBDFEDOC(BOCOL(cChave))
    Local aL := {}
    Local aDet := {}
    Local aPg := {}
    Local cX := ""
    Local cE := ""
    Local cEnd := ""
    Local cTot := ""
    Local cDest := ""
    Local cP := ""
    Local cIde := ""
    Local nI := 0
    If Len(aD) == 0
        Return {.F., "documento_inexistente", {}}
    EndIf
    cX := aD[3]
    cE := GEBDFEBLOCO(cX, "emit")
    cEnd := GEBDFEBLOCO(cE, "enderEmit")
    cIde := GEBDFEBLOCO(cX, "ide")
    aAdd(aL, "== " + GEBDFETAG(cE, "xNome"))
    aAdd(aL, "CNPJ " + DANDoc(GEBDFETAG(cE, "CNPJ")) + "  IE " + GEBDFETAG(cE, "IE"))
    aAdd(aL, GEBDFETAG(cEnd, "xLgr") + ", " + GEBDFETAG(cEnd, "nro") + " - " + GEBDFETAG(cEnd, "xBairro") + " - " + GEBDFETAG(cEnd, "xMun") + "/" + ;
        GEBDFETAG(cEnd, "UF"))
    aAdd(aL, "---")
    aAdd(aL, "== DANFE NFC-e - Documento Auxiliar da Nota Fiscal de Consumidor Eletronica")
    If GEBDFETAG(cIde, "tpAmb") == "2"
        aAdd(aL, "!! EMITIDA EM AMBIENTE DE HOMOLOGACAO - SEM VALOR FISCAL")
    EndIf
    If GEBDFETAG(cIde, "tpEmis") == "9"
        aAdd(aL, "!! EMITIDA EM CONTINGENCIA - Pendente de autorizacao")
    EndIf
    aAdd(aL, "---")
    aAdd(aL, "|| Codigo Descricao Qtde Un x Vl unit|Vl total")
    aDet := DANBlocos(cX, "det")
    For nI := 1 To Len(aDet)
        aAdd(aL, "|| " + GEBDFETAG(aDet[nI], "cProd") + " " + GEBDFETAG(aDet[nI], "xProd") + " " + StrTran(GEBDFETAG(aDet[nI], "qCom"), ".", ",") + " " + ;
            GEBDFETAG(aDet[nI], "uCom") + " x " + DANMoeda(GEBDFETAG(aDet[nI], "vUnCom")) + "|" + DANMoeda(GEBDFETAG(aDet[nI], "vProd")))
    Next nI
    aAdd(aL, "---")
    cTot := GEBDFEBLOCO(cX, "ICMSTot")
    aAdd(aL, "|| Qtde. total de itens|" + cValToChar(Len(aDet)))
    aAdd(aL, "|| Valor total R$|" + DANMoeda(GEBDFETAG(cTot, "vProd")))
    If BOVAL(GEBDFETAG(cTot, "vDesc")) > 0
        aAdd(aL, "|| Descontos R$|" + DANMoeda(GEBDFETAG(cTot, "vDesc")))
    EndIf
    aAdd(aL, "|| Valor a pagar R$|" + DANMoeda(GEBDFETAG(cTot, "vNF")))
    aAdd(aL, "|| FORMA DE PAGAMENTO|VALOR PAGO R$")
    aPg := DANBlocos(cX, "detPag")
    For nI := 1 To Len(aPg)
        aAdd(aL, "|| " + DANPag(GEBDFETAG(aPg[nI], "tPag")) + "|" + DANMoeda(GEBDFETAG(aPg[nI], "vPag")))
    Next nI
    If !(GEBDFETAG(cX, "vTroco") == "")
        aAdd(aL, "|| Troco R$|" + DANMoeda(GEBDFETAG(cX, "vTroco")))
    EndIf
    aAdd(aL, "---")
    aAdd(aL, "Consulte pela Chave de Acesso em")
    aAdd(aL, aD[13])
    aAdd(aL, "== " + DANChave(BOCOL(cChave)))
    aAdd(aL, "---")
    cDest := GEBDFEBLOCO(cX, "dest")
    If cDest == ""
        aAdd(aL, "CONSUMIDOR NAO IDENTIFICADO")
    ElseIf !(GEBDFETAG(cDest, "CPF") == "")
        aAdd(aL, "CONSUMIDOR - CPF " + DANDoc(GEBDFETAG(cDest, "CPF")))
    Else
        aAdd(aL, "CONSUMIDOR - CNPJ " + DANDoc(GEBDFETAG(cDest, "CNPJ")))
    EndIf
    aAdd(aL, "---")
    aAdd(aL, "NFC-e n. " + GEBDFETAG(cIde, "nNF") + "  Serie " + GEBDFETAG(cIde, "serie") + "  " + DANDh(GEBDFETAG(cIde, "dhEmi")))
    cP := GEBDFEBLOCO(cX, "protNFe")
    If !(cP == "")
        aAdd(aL, "Protocolo de autorizacao: " + GEBDFETAG(cP, "nProt"))
        aAdd(aL, "Data de autorizacao: " + DANDh(GEBDFETAG(cP, "dhRecbto")))
    EndIf
    If aD[1] == "CANCELADA"
        aAdd(aL, "!! NFC-e CANCELADA")
    EndIf
    aAdd(aL, "QR " + aD[12])
    If !(GEBDFETAG(cX, "infCpl") == "")
        aAdd(aL, GEBDFETAG(cX, "infCpl"))
    EndIf
Return {.T., "ok", aL}
