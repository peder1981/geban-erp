#include "totvs.ch"

/*/{Protheus.doc} GEBDFE_IE
    Validacao da Inscricao Estadual pelos digitos verificadores de cada UF
    (regras do SINTEGRA). GEBDFEIEOK(cIE, cUF): pontos, tracos, barras e
    espacos sao ignorados; "ISENTO" e' aceito so quando lIsento = .T.
    (destinatario). Conferida contra a implementacao de referencia
    gammasoft/ie em tests/local/T_GEBDFE_IE.sh (milhares de numeros por UF).
    @type Biblioteca
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBDFEIEOK(cIE, cUF, lIsento)
    Local cV := ""
    Local cC := ""
    Local nI := 0
    cUF := Upper(AllTrim(BOSTR(cUF)))
    cIE := Upper(AllTrim(BOSTR(cIE)))
    If cIE == "ISENTO"
        Return lIsento == .T.
    EndIf
    For nI := 1 To Len(cIE)
        cC := SubStr(cIE, nI, 1)
        If !(cC $ ".-/ ")
            cV += cC
        EndIf
    Next nI
    If cV == ""
        Return .F.
    EndIf
    If !(cUF == "SP" .And. Left(cV, 1) == "P") .And. !IEDigitos(cV)
        Return .F.
    EndIf
    If cUF == "AC"
        Return IEAC(cV)
    ElseIf cUF == "AL"
        Return IEAL(cV)
    ElseIf cUF == "AP"
        Return IEAP(cV)
    ElseIf cUF == "AM" .Or. cUF == "SE" .Or. cUF == "PB"
        Return Len(cV) == 9 .And. IETrivial(cV, Left(cV, 8))
    ElseIf cUF == "BA"
        Return IEBA(cV)
    ElseIf cUF == "CE"
        Return Len(cV) == 9 .And. Left(cV, 2) == "06" .And. IETrivial(cV, Left(cV, 8))
    ElseIf cUF == "DF"
        Return IEDuplo(cV, 13, "07")
    ElseIf cUF == "ES" .Or. cUF == "PI" .Or. cUF == "SC"
        Return Len(cV) == 9 .And. IETrivial(cV, Left(cV, 8))
    ElseIf cUF == "GO"
        Return IEGO(cV)
    ElseIf cUF == "MA"
        Return Len(cV) == 9 .And. Left(cV, 2) == "12" .And. IETrivial(cV, Left(cV, 8))
    ElseIf cUF == "MG"
        Return IEMG(cV)
    ElseIf cUF == "MS"
        Return Len(cV) == 9 .And. Left(cV, 2) == "28" .And. IETrivial(cV, Left(cV, 8))
    ElseIf cUF == "MT"
        Return IEMT(cV)
    ElseIf cUF == "PA"
        Return Len(cV) == 9 .And. Left(cV, 2) == "15" .And. IETrivial(cV, Left(cV, 8))
    ElseIf cUF == "PE"
        Return IEPE(cV)
    ElseIf cUF == "PR"
        Return IEPR(cV)
    ElseIf cUF == "RJ"
        Return Len(cV) == 8 .And. cV == Left(cV, 7) + cValToChar(IEDv11(IEMod(Left(cV, 7), {2, 3, 4, 5, 6, 7}, 11)))
    ElseIf cUF == "RN"
        Return IERN(cV)
    ElseIf cUF == "RO"
        Return IERO(cV)
    ElseIf cUF == "RR"
        Return Len(cV) == 9 .And. Left(cV, 2) == "24" .And. cV == Left(cV, 8) + cValToChar(IEMod(Left(cV, 8), {8, 7, 6, 5, 4, 3, 2, 1}, 9))
    ElseIf cUF == "RS"
        Return Len(cV) == 10 .And. IETrivial(cV, Left(cV, 9))
    ElseIf cUF == "SP"
        Return IESP(cV)
    ElseIf cUF == "TO"
        Return IETO(cV)
    EndIf
Return .F.

Static Function IEDigitos(c)
    Local nI := 0
    For nI := 1 To Len(c)
        If !(SubStr(c, nI, 1) $ "0123456789")
            Return .F.
        EndIf
    Next nI
Return .T.

Static Function IESerie(nDe, nAte)
    Local aR := {}
    Local nI := 0
    For nI := nDe To nAte
        aAdd(aR, nI)
    Next nI
Return aR

// Soma ponderada da direita para a esquerda (multiplicadores ciclicos) mod nDiv.
Static Function IEMod(cVal, aMult, nDiv)
    Local nSoma := 0
    Local nP := 1
    Local nI := 0
    If aMult == Nil
        aMult := IESerie(2, 9)
    EndIf
    If nDiv == Nil
        nDiv := 11
    EndIf
    For nI := Len(cVal) To 1 Step -1
        If nP > Len(aMult)
            nP := 1
        EndIf
        nSoma += aMult[nP] * Val(SubStr(cVal, nI, 1))
        nP++
    Next nI
Return nSoma % nDiv

// Resto < 2 => 0; senao 11 - resto.
Static Function IEDv11(nResto)
    If nResto < 2
        Return 0
    EndIf
Return 11 - nResto

Static Function IETrivial(cV, cBase)
Return cV == cBase + cValToChar(IEDv11(IEMod(cBase)))

// Dois digitos modulo 11 sobre os primeiros nTam-2 (AC, DF).
Static Function IEDuplo(cV, nTam, cIni)
    Local cBase := ""
    Local nD1 := 0
    Local nD2 := 0
    If !(Len(cV) == nTam)
        Return .F.
    EndIf
    cBase := Left(cV, nTam - 2)
    nD1 := IEDv11(IEMod(cBase))
    nD2 := IEDv11(IEMod(cBase + cValToChar(nD1)))
Return cV == cBase + cValToChar(nD1) + cValToChar(nD2)

Static Function IEAC(cV)
    If !(Len(cV) == 13) .Or. !(Left(cV, 2) == "01")
        Return .F.
    EndIf
Return IEDuplo(cV, 13, "01")

Static Function IEAL(cV)
    Local cBase := Left(cV, 8)
    Local nR := 0
    If !(Len(cV) == 9) .Or. !(Left(cV, 2) == "24")
        Return .F.
    EndIf
    nR := IEMod(cBase) * 10
    nR := nR - Int(nR / 11) * 11
    If nR == 10
        nR := 0
    EndIf
Return cV == cBase + cValToChar(nR)

Static Function IEAP(cV)
    Local cBase := Left(cV, 8)
    Local nB := 0
    Local nP := 0
    Local nD := 0
    Local nR := 0
    Local nDig := 0
    If !(Len(cV) == 9) .Or. !(Left(cV, 2) == "03")
        Return .F.
    EndIf
    nB := Val(cBase)
    If nB >= 3000001 .And. nB <= 3017000
        nP := 5
        nD := 0
    ElseIf nB >= 3017001 .And. nB <= 3019022
        nP := 9
        nD := 1
    EndIf
    // A referencia soma p como texto antes da base ("5" + "03...") e pondera 2..9,1.
    nR := IEMod(cValToChar(nP) + cBase, {2, 3, 4, 5, 6, 7, 8, 9, 1}, 11)
    If nR == 1
        nDig := 0
    ElseIf nR == 0
        nDig := nD
    Else
        nDig := 11 - nR
    EndIf
Return cV == cBase + cValToChar(nDig)

Static Function IEBA(cV)
    Local cBase := ""
    Local cCmp := ""
    Local aM2 := IESerie(2, 7)
    Local aM1 := IESerie(2, 8)
    Local nR := 0
    Local nD1 := 0
    Local nD2 := 0
    If !(Len(cV) == 8 .Or. Len(cV) == 9)
        Return .F.
    EndIf
    cBase := Left(cV, Len(cV) - 2)
    cCmp := Left(cV, 1)
    If Len(cV) == 9
        aAdd(aM2, 8)
        aAdd(aM1, 9)
        cCmp := SubStr(cV, 2, 1)
    EndIf
    If cCmp $ "0123458"
        nR := IEMod(cBase, aM2, 10)
        If nR == 0
            nD2 := 0
        Else
            nD2 := 10 - nR
        EndIf
        nR := IEMod(cBase + cValToChar(nD2), aM1, 10)
        If nR == 0
            nD1 := 0
        Else
            nD1 := 10 - nR
        EndIf
    Else
        nD2 := IEDv11(IEMod(cBase, aM2, 11))
        nD1 := IEDv11(IEMod(cBase + cValToChar(nD2), aM1, 11))
    EndIf
Return cV == cBase + cValToChar(nD1) + cValToChar(nD2)

Static Function IEGO(cV)
    Local cBase := Left(cV, 8)
    Local nR := 0
    Local nD := 0
    Local nB := 0
    If !(Len(cV) == 9) .Or. !(Left(cV, 2) $ "10|11|15")
        Return .F.
    EndIf
    If cBase == "11094402"
        Return Right(cV, 1) == "0" .Or. Right(cV, 1) == "1"
    EndIf
    nR := IEMod(cBase)
    nB := Val(cBase)
    If nR == 0
        nD := 0
    ElseIf nR == 1
        If nB >= 10103105 .And. nB <= 10119997
            nD := 1
        Else
            nD := 0
        EndIf
    Else
        nD := 11 - nR
    EndIf
Return cV == cBase + cValToChar(nD)

Static Function IEMG(cV)
    Local cBase := Left(cV, 11)
    Local cZero := ""
    Local cProd := ""
    Local nSoma := 0
    Local nP := 0
    Local nI := 0
    Local nD1 := 0
    Local nD2 := 0
    If !(Len(cV) == 13)
        Return .F.
    EndIf
    // Insere 0 depois do municipio; multiplica por 2,1 da direita e soma os algarismos.
    cZero := Left(cV, 3) + "0" + SubStr(cV, 4, 8)
    nP := 1
    For nI := Len(cZero) To 1 Step -1
        If nP == 1
            cProd := cValToChar(2 * Val(SubStr(cZero, nI, 1))) + cProd
            nP := 2
        Else
            cProd := cValToChar(1 * Val(SubStr(cZero, nI, 1))) + cProd
            nP := 1
        EndIf
    Next nI
    For nI := 1 To Len(cProd)
        nSoma += Val(SubStr(cProd, nI, 1))
    Next nI
    nD1 := (Int(nSoma / 10) + 1) * 10 - nSoma
    If nD1 == 10
        nD1 := 0
    EndIf
    nD2 := IEDv11(IEMod(cBase + cValToChar(nD1), IESerie(2, 11), 11))
Return cV == cBase + cValToChar(nD1) + cValToChar(nD2)

Static Function IEMT(cV)
    If Len(cV) == 11
        Return IETrivial(cV, Left(cV, 10))
    EndIf
    If Len(cV) == 9
        Return IETrivial(cV, Left(cV, 8))
    EndIf
Return .F.

Static Function IEPE(cV)
    Local cBase := Left(cV, Len(cV) - 2)
    Local nR := 0
    Local nD1 := 0
    Local nD2 := 0
    If Len(cV) < 3
        Return .F.
    EndIf
    nR := IEMod(cBase)
    nD1 := 11 - nR
    If nD1 >= 10
        nD1 := 0
    EndIf
    nR := IEMod(cBase + cValToChar(nD1))
    nD2 := 11 - nR
    If nD2 >= 10
        nD2 := 0
    EndIf
Return cV == cBase + cValToChar(nD1) + cValToChar(nD2)

Static Function IEPR(cV)
    Local cBase := Left(cV, 8)
    Local nR := 0
    Local nD1 := 0
    Local nD2 := 0
    If !(Len(cV) == 10)
        Return .F.
    EndIf
    nR := IEMod(cBase, IESerie(2, 7), 11)
    nD1 := 11 - nR
    If nD1 >= 10
        nD1 := 0
    EndIf
    nR := IEMod(cBase + cValToChar(nD1), IESerie(2, 7), 11)
    nD2 := 11 - nR
    If nD2 >= 10
        nD2 := 0
    EndIf
Return cV == cBase + cValToChar(nD1) + cValToChar(nD2)

Static Function IERN(cV)
    Local cBase := ""
    Local aM := IESerie(2, 9)
    Local nR := 0
    If !(Len(cV) == 9 .Or. Len(cV) == 10) .Or. !(Left(cV, 2) == "20")
        Return .F.
    EndIf
    cBase := Left(cV, Len(cV) - 1)
    If Len(cV) == 10
        aAdd(aM, 10)
    EndIf
    nR := (IEMod(cBase, aM, 11) * 10) % 11
    If nR == 10
        nR := 0
    EndIf
Return cV == cBase + cValToChar(nR)

Static Function IERO(cV)
    Local cBase := ""
    Local nR := 0
    Local nD := 0
    If Len(cV) == 9
        cBase := SubStr(cV, 4, 5)
        Return cV == Left(cV, 3) + cBase + cValToChar(IEDv11(IEMod(cBase)))
    EndIf
    If Len(cV) == 14
        cBase := Left(cV, 13)
        nR := IEMod(cBase)
        If nR <= 1
            nD := 1
        Else
            nD := 11 - nR
        EndIf
        Return cV == cBase + cValToChar(nD)
    EndIf
Return .F.

// Ultimo algarismo do resto (resto 10 => "0").
Static Function IEUlt(nR)
Return Right(cValToChar(nR), 1)

Static Function IESP(cV)
    Local cBase := ""
    Local cB2 := ""
    Local cD1 := ""
    Local cD2 := ""
    If Left(cV, 1) == "P"
        If !(Len(cV) == 13) .Or. !IEDigitos(SubStr(cV, 2))
            Return .F.
        EndIf
        cBase := SubStr(cV, 2, 8)
        cB2 := SubStr(cV, 11, 3)
        Return cV == "P" + cBase + IEUlt(IEMod(cBase, {10, 8, 7, 6, 5, 4, 3, 1}, 11)) + cB2
    EndIf
    If !(Len(cV) == 12)
        Return .F.
    EndIf
    cBase := Left(cV, 8)
    cB2 := SubStr(cV, 10, 2)
    cD1 := IEUlt(IEMod(cBase, {10, 8, 7, 6, 5, 4, 3, 1}, 11))
    cD2 := IEUlt(IEMod(cBase + cD1 + cB2, IESerie(2, 10), 11))
Return cV == cBase + cD1 + cB2 + cD2

Static Function IETO(cV)
    Local cBase := ""
    If Len(cV) == 11
        If !(SubStr(cV, 3, 2) $ "01|02|03|99")
            Return .F.
        EndIf
        cBase := Left(cV, 2) + SubStr(cV, 5, 6)
    ElseIf Len(cV) == 9
        cBase := Left(cV, 8)
    Else
        Return .F.
    EndIf
Return cV == Left(cV, Len(cV) - 1) + cValToChar(IEDv11(IEMod(cBase)))
