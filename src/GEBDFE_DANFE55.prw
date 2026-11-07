#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBDFE_XML.prw"
#include "GEBDFE.prw"

/*/{Protheus.doc} GEBDFE_DANFE55
    DANFE da NF-e (modelo 55) em HTML A4 retrato, a partir do XML do
    documento (GDF5): canhoto, emitente, codigo de barras Code 128 (C) da
    chave de acesso, protocolo, destinatario/remetente, fatura/duplicatas,
    calculo do imposto, transportador, produtos e dados adicionais (avisos de
    homologacao e cancelamento).
    - GEBC128(cDigitos) -> larguras das barras/espacos (Code 128 subconjunto C:
      start 105, pares 00-99, digito mod 103, stop), conferidas com o
      reportlab em tests/local/T_GEBDFE_C128.sh.
    - GEBC128SVG(cDigitos, nAltura) -> SVG.
    - GEBDFEDANFE55(cChave) -> {lOk, cMsg, cHtml}.
    @type Relatorio fiscal
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBC128(cDig)
    Local cTab := "212222;222122;222221;121223;121322;131222;122213;122312;132212;221213;221312;231212;112232;122132;122231;113222;123122;" + ;
        "123221;223211;221132;221231;213212;223112;312131;311222;321122;321221;312212;322112;322211;212123;212321;232121;111323;131123;131321;" + ;
        "112313;132113;132311;211313;231113;231311;112133;112331;132131;113123;113321;133121;313121;211331;231131;213113;213311;213131;311123;" + ;
        "311321;331121;312113;312311;332111;314111;221411;431111;111224;111422;121124;121421;141122;141221;112214;112412;122114;122411;142112;" + ;
        "142211;241211;221114;413111;241112;134111;111242;121142;121241;114212;124112;124211;411212;421112;421211;212141;214121;412121;111143;" + ;
        "111341;131141;114113;114311;411113;411311;113141;114131;311141;411131;211412;211214;211232;2331112"
    Local aPad := StrTokArr(cTab, ";")
    Local aVal := {105}
    Local cW := ""
    Local nSoma := 105
    Local nI := 0
    If Len(cDig) % 2 == 1 .Or. !(GEBDFEDIG(cDig) == cDig) .Or. Len(cDig) == 0
        Return ""
    EndIf
    For nI := 1 To Len(cDig) Step 2
        aAdd(aVal, Val(SubStr(cDig, nI, 2)))
        nSoma += Val(SubStr(cDig, nI, 2)) * (Len(aVal) - 1)
    Next nI
    aAdd(aVal, nSoma % 103)
    aAdd(aVal, 106)
    For nI := 1 To Len(aVal)
        cW += aPad[aVal[nI] + 1]
    Next nI
Return cW

User Function GEBC128SVG(cDig, nAltura)
    Local cW := GEBC128(cDig)
    Local cS := ""
    Local nX := 10
    Local nI := 0
    Local nL := 0
    Local nTot := 20
    If nAltura == Nil
        nAltura := 50
    EndIf
    For nI := 1 To Len(cW)
        nTot += Val(SubStr(cW, nI, 1))
    Next nI
    cS := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + cValToChar(nTot) + " " + cValToChar(nAltura) + '" preserveAspectRatio="none" ' + ;
        'shape-rendering="crispEdges"><rect width="100%" height="100%" fill="#fff"/><path fill="#000" d="'
    For nI := 1 To Len(cW)
        nL := Val(SubStr(cW, nI, 1))
        If nI % 2 == 1
            cS += "M" + cValToChar(nX) + " 0h" + cValToChar(nL) + "v" + cValToChar(nAltura) + "h-" + cValToChar(nL) + "z"
        EndIf
        nX += nL
    Next nI
Return cS + '"/></svg>'

Static Function D55Blocos(cXml, cTag)
    Local aR := {}
    Local cB := ""
    Do While .T.
        cB := GEBDFEBLOCO(cXml, cTag)
        If cB == ""
            Exit
        EndIf
        aAdd(aR, cB)
        cXml := SubStr(cXml, At(cB, cXml) + Len(cB))
    EndDo
Return aR

Static Function D55Moeda(cVal)
    Local cN := AllTrim(Str(Round(BOVAL(cVal), 2), 20, 2))
    Local cInt := Left(cN, Len(cN) - 3)
    Local cR := ""
    Do While Len(cInt) > 3
        cR := "." + Right(cInt, 3) + cR
        cInt := Left(cInt, Len(cInt) - 3)
    EndDo
Return cInt + cR + "," + Right(cN, 2)

Static Function D55Doc(cD)
    If Len(cD) == 11
        Return Left(cD, 3) + "." + SubStr(cD, 4, 3) + "." + SubStr(cD, 7, 3) + "-" + Right(cD, 2)
    EndIf
    If Len(cD) == 14
        Return Left(cD, 2) + "." + SubStr(cD, 3, 3) + "." + SubStr(cD, 6, 3) + "/" + SubStr(cD, 9, 4) + "-" + Right(cD, 2)
    EndIf
Return cD

Static Function D55Data(cDh)
    If Len(cDh) < 10
        Return cDh
    EndIf
Return SubStr(cDh, 9, 2) + "/" + SubStr(cDh, 6, 2) + "/" + Left(cDh, 4)

Static Function D55Cel(cRotulo, cValor, cEstilo)
    If cEstilo == Nil
        cEstilo := ""
    EndIf
Return '<td style="' + cEstilo + '"><span class="r">' + cRotulo + "</span>" + cValor + "</td>"

/*/{Protheus.doc} GEBDFEDANFE55
    DANFE A4 da NF-e.
    @type Relatorio fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, cHtml}
/*/
User Function GEBDFEDANFE55(cChave)
    Local aD := GEBDFEDOC(BOCOL(cChave))
    Local aDet := {}
    Local aDup := {}
    Local cX := ""
    Local cIde := ""
    Local cE := ""
    Local cEE := ""
    Local cDe := ""
    Local cED := ""
    Local cTot := ""
    Local cP := ""
    Local cH := ""
    Local cCh := BOCOL(cChave)
    Local cChF := ""
    Local cImp := ""
    Local cSit := ""
    Local nI := 0
    If Len(aD) == 0 .Or. !(aD[5] == "55")
        Return {.F., "nfe_inexistente", ""}
    EndIf
    cX := aD[3]
    cIde := GEBDFEBLOCO(cX, "ide")
    cE := GEBDFEBLOCO(cX, "emit")
    cEE := GEBDFEBLOCO(cE, "enderEmit")
    cDe := GEBDFEBLOCO(cX, "dest")
    cED := GEBDFEBLOCO(cDe, "enderDest")
    cTot := GEBDFEBLOCO(cX, "ICMSTot")
    cP := GEBDFEBLOCO(cX, "protNFe")
    For nI := 1 To 44 Step 4
        cChF += SubStr(cCh, nI, 4) + " "
    Next nI
    cH := '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>DANFE NF-e ' + GEBDFETAG(cIde, "nNF") + "</title><style>" + ;
        "body{margin:0;background:#fff;color:#000;font:9px Arial,Helvetica,sans-serif}.p{width:200mm;margin:5mm auto}" + ;
        "table{width:100%;border-collapse:collapse;margin-top:1mm}td,th{border:1px solid #000;padding:1px 3px;vertical-align:top}" + ;
        ".r{display:block;font-size:6.5px;text-transform:uppercase}.t{font-size:7px;font-weight:bold;margin-top:2mm}" + ;
        ".g{font-size:13px;font-weight:bold}.c{text-align:center}.d{text-align:right}th{font-size:6.5px;font-weight:normal}" + ;
        ".m{position:fixed;top:40%;left:0;right:0;text-align:center;font-size:40px;color:rgba(200,0,0,.25);transform:rotate(-25deg)}" + ;
        "@media print{@page{size:A4;margin:5mm}.p{margin:0}}</style></head><body><div class=" + '"p">'
    If GEBDFETAG(cIde, "tpAmb") == "2"
        cSit := "SEM VALOR FISCAL - HOMOLOGACAO"
    EndIf
    If aD[1] == "CANCELADA"
        cSit := "NF-e CANCELADA"
    EndIf
    If !(cSit == "")
        cH += '<div class="m">' + cSit + "</div>"
    EndIf
    // Canhoto.
    cH += "<table><tr>" + D55Cel("Recebemos de " + GEBDFETAG(cE, "xNome") + " os produtos/servicos constantes da nota fiscal indicada ao lado", "&nbsp;", "width:75%") + ;
        '<td rowspan="2" class="c" style="width:25%"><span class="g">NF-e</span><br>N. ' + GEBDFETAG(cIde, "nNF") + "<br>Serie " + ;
        GEBDFETAG(cIde, "serie") + "</td></tr><tr>" + D55Cel("Data de recebimento", "&nbsp;") + "</tr><tr>" + ;
        D55Cel("Identificacao e assinatura do recebedor", "&nbsp;", "height:7mm") + "</tr></table>"
    // Emitente, DANFE e chave.
    cH += "<table><tr>" + '<td style="width:38%"><span class="g">' + GEBDFETAG(cE, "xNome") + "</span><br>" + GEBDFETAG(cEE, "xLgr") + ", " + ;
        GEBDFETAG(cEE, "nro") + " " + GEBDFETAG(cEE, "xCpl") + "<br>" + GEBDFETAG(cEE, "xBairro") + " - " + GEBDFETAG(cEE, "CEP") + "<br>" + ;
        GEBDFETAG(cEE, "xMun") + " - " + GEBDFETAG(cEE, "UF") + " Fone: " + GEBDFETAG(cEE, "fone") + "</td>" + ;
        '<td class="c" style="width:17%"><span class="g">DANFE</span><br>Documento Auxiliar da Nota Fiscal Eletronica<br><br>' + ;
        GEBDFETAG(cIde, "tpNF") + " - " + D55TipoNF(GEBDFETAG(cIde, "tpNF")) + '<br><br><span class="g">N. ' + GEBDFETAG(cIde, "nNF") + ;
        "</span><br>Serie " + GEBDFETAG(cIde, "serie") + "<br>Folha 1/1</td>" + '<td style="width:45%"><div style="height:12mm">' + ;
        GEBC128SVG(cCh, 40) + '</div><span class="r">Chave de acesso</span><b>' + AllTrim(cChF) + "</b><br>Consulta de autenticidade no portal " + ;
        "nacional da NF-e www.nfe.fazenda.gov.br/portal ou no site da Sefaz Autorizadora</td></tr></table>"
    cH += "<table><tr>" + D55Cel("Natureza da operacao", GEBDFETAG(cIde, "natOp"), "width:55%") + ;
        D55Cel("Protocolo de autorizacao de uso", GEBDFETAG(cP, "nProt") + " " + D55Data(GEBDFETAG(cP, "dhRecbto")) + " " + ;
        SubStr(GEBDFETAG(cP, "dhRecbto"), 12, 8)) + "</tr></table><table><tr>" + D55Cel("Inscricao estadual", GEBDFETAG(cE, "IE")) + ;
        D55Cel("Inscricao estadual do subst. trib.", GEBDFETAG(cE, "IEST")) + D55Cel("CNPJ", D55Doc(GEBDFETAG(cE, "CNPJ"))) + "</tr></table>"
    // Destinatario.
    cH += '<div class="t">DESTINATARIO / REMETENTE</div><table><tr>' + D55Cel("Nome / razao social", GEBDFETAG(cDe, "xNome"), "width:55%") + ;
        D55Cel("CNPJ / CPF", D55Doc(GEBDFETAG(cDe, "CNPJ") + GEBDFETAG(cDe, "CPF"))) + D55Cel("Data da emissao", D55Data(GEBDFETAG(cIde, "dhEmi"))) + ;
        "</tr><tr>" + D55Cel("Endereco", GEBDFETAG(cED, "xLgr") + ", " + GEBDFETAG(cED, "nro") + " " + GEBDFETAG(cED, "xCpl")) + ;
        D55Cel("Bairro / distrito", GEBDFETAG(cED, "xBairro")) + D55Cel("Data da saida/entrada", D55Data(GEBDFETAG(cIde, "dhSaiEnt"))) + "</tr><tr>" + ;
        D55Cel("Municipio", GEBDFETAG(cED, "xMun")) + D55Cel("UF / CEP / fone", GEBDFETAG(cED, "UF") + " / " + GEBDFETAG(cED, "CEP") + " / " + ;
        GEBDFETAG(cED, "fone")) + D55Cel("Inscricao estadual", GEBDFETAG(cDe, "IE")) + "</tr></table>"
    // Fatura / duplicatas.
    aDup := D55Blocos(cX, "dup")
    If Len(aDup) > 0
        cH += '<div class="t">FATURA / DUPLICATAS</div><table><tr>'
        For nI := 1 To Len(aDup)
            cH += D55Cel("Num. " + GEBDFETAG(aDup[nI], "nDup"), "Venc. " + D55Data(GEBDFETAG(aDup[nI], "dVenc")) + "<br>R$ " + ;
                D55Moeda(GEBDFETAG(aDup[nI], "vDup")))
        Next nI
        cH += "</tr></table>"
    EndIf
    // Calculo do imposto.
    cH += '<div class="t">CALCULO DO IMPOSTO</div><table><tr>' + D55Cel("Base de calc. do ICMS", D55Moeda(GEBDFETAG(cTot, "vBC")), "text-align:right") + ;
        D55Cel("Valor do ICMS", D55Moeda(GEBDFETAG(cTot, "vICMS")), "text-align:right") + D55Cel("Base calc. ICMS ST", D55Moeda(GEBDFETAG(cTot, "vBCST")), ;
        "text-align:right") + D55Cel("Valor do ICMS ST", D55Moeda(GEBDFETAG(cTot, "vST")), "text-align:right") + ;
        D55Cel("Valor total dos produtos", D55Moeda(GEBDFETAG(cTot, "vProd")), "text-align:right") + "</tr><tr>" + ;
        D55Cel("Valor do frete", D55Moeda(GEBDFETAG(cTot, "vFrete")), "text-align:right") + D55Cel("Valor do seguro", D55Moeda(GEBDFETAG(cTot, "vSeg")), ;
        "text-align:right") + D55Cel("Desconto", D55Moeda(GEBDFETAG(cTot, "vDesc")), "text-align:right") + ;
        D55Cel("Outras despesas", D55Moeda(GEBDFETAG(cTot, "vOutro")), "text-align:right") + ;
        D55Cel("Valor total da nota", "<b>" + D55Moeda(GEBDFETAG(cTot, "vNF")) + "</b>", "text-align:right") + "</tr></table>"
    cH += '<div class="t">TRANSPORTADOR / VOLUMES TRANSPORTADOS</div><table><tr>' + D55Cel("Modalidade do frete", ;
        D55Frete(GEBDFETAG(cX, "modFrete"))) + "</tr></table>"
    // Produtos.
    cH += '<div class="t">DADOS DOS PRODUTOS / SERVICOS</div><table><tr><th>Codigo</th><th>Descricao</th><th>NCM/SH</th><th>CST/CSOSN</th>' + ;
        "<th>CFOP</th><th>Un</th><th>Quant.</th><th>Valor unit.</th><th>Desconto</th><th>Valor total</th><th>BC ICMS</th><th>Valor ICMS</th><th>Aliq. ICMS</th></tr>"
    aDet := D55Blocos(cX, "det")
    For nI := 1 To Len(aDet)
        cImp := GEBDFEBLOCO(aDet[nI], "ICMS")
        cH += "<tr><td>" + GEBDFETAG(aDet[nI], "cProd") + "</td><td>" + GEBDFETAG(aDet[nI], "xProd") + "</td><td>" + GEBDFETAG(aDet[nI], "NCM") + ;
            "</td><td>" + GEBDFETAG(cImp, "orig") + GEBDFETAG(cImp, "CST") + GEBDFETAG(cImp, "CSOSN") + "</td><td>" + GEBDFETAG(aDet[nI], "CFOP") + ;
            "</td><td>" + GEBDFETAG(aDet[nI], "uCom") + '</td><td class="d">' + StrTran(GEBDFETAG(aDet[nI], "qCom"), ".", ",") + '</td><td class="d">' + ;
            D55Moeda(GEBDFETAG(aDet[nI], "vUnCom")) + '</td><td class="d">' + D55Moeda(GEBDFETAG(aDet[nI], "vDesc")) + '</td><td class="d">' + ;
            D55Moeda(GEBDFETAG(aDet[nI], "vProd")) + '</td><td class="d">' + D55Moeda(GEBDFETAG(cImp, "vBC")) + '</td><td class="d">' + ;
            D55Moeda(GEBDFETAG(cImp, "vICMS")) + '</td><td class="d">' + D55Moeda(GEBDFETAG(cImp, "pICMS")) + "</td></tr>"
    Next nI
    cH += "</table>"
    cH += '<div class="t">DADOS ADICIONAIS</div><table><tr>' + D55Cel("Informacoes complementares", GEBDFETAG(cX, "infCpl") + D55Refs(cX), ;
        "width:65%;height:20mm") + D55Cel("Reservado ao fisco", "&nbsp;") + "</tr></table></div></body></html>"
Return {.T., "ok", cH}

Static Function D55TipoNF(cTp)
    If cTp == "0"
        Return "ENTRADA"
    EndIf
Return "SAIDA"

Static Function D55Frete(cMod)
    Local aM := {{"0", "0 - Por conta do remetente (CIF)"}, {"1", "1 - Por conta do destinatario (FOB)"}, {"2", "2 - Por conta de terceiros"}, ;
        {"3", "3 - Transporte proprio do remetente"}, {"4", "4 - Transporte proprio do destinatario"}, {"9", "9 - Sem ocorrencia de transporte"}}
    Local nP := AScan(aM, {|x| x[1] == cMod})
    If nP == 0
        Return cMod
    EndIf
Return aM[nP][2]

// Notas referenciadas (devolucao).
Static Function D55Refs(cX)
    Local aR := D55Blocos(cX, "NFref")
    Local cR := ""
    Local nI := 0
    For nI := 1 To Len(aR)
        cR += "<br>NF-e referenciada: " + GEBDFETAG(aR[nI], "refNFe")
    Next nI
Return cR
