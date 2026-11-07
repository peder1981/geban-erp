#include "totvs.ch"

/*/{Protheus.doc} GEBDFE_QR
    Codificador de QR Code (ISO/IEC 18004) para o DANFE NFC-e: modo byte,
    correcao de erro nivel M, versoes 1 a 40, mascara escolhida pela menor
    penalidade (regras N1 a N4 da norma). Sem biblioteca externa: o DANFE
    sai com o QR em SVG mesmo sem internet.
    - GEBQRMATRIZ(cTexto[, nMascara]) -> {nVersao, aMatriz} (linhas de 0/1).
    - GEBQRSVG(cTexto[, nModulo]) -> SVG com margem de 4 modulos.
    Tabelas de blocos (nivel M) e de posicoes dos padroes de alinhamento
    conferidas com a biblioteca Python qrcode (tests/local/T_GEBDFE_QR.sh).
    @type Biblioteca
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBQRMATRIZ(cTexto, nMascara)
    Local aDados := {}
    Local aBlk := {}
    Local aCw := {}
    Local aBest := {}
    Local aM := {}
    Local nV := 0
    Local nCap := 0
    Local nBits := 0
    Local nPen := 0
    Local nMelhor := -1
    Local nK := 0
    Local nI := 0

    For nI := 1 To Len(cTexto)
        aAdd(aDados, Asc(SubStr(cTexto, nI, 1)))
    Next nI
    For nV := 1 To 40
        aBlk := QRBlocos(nV)
        nCap := QRCapacidade(aBlk)
        nBits := 4 + QRBitsQtd(nV) + 8 * Len(aDados)
        If nBits <= nCap * 8
            Exit
        EndIf
    Next nV
    If nV > 40
        Return {0, {}}
    EndIf
    aCw := QRCodewords(aDados, nV, aBlk, nCap)
    If nMascara != Nil .And. nMascara >= 0
        Return {nV, QRMonta(nV, aCw, nMascara)}
    EndIf
    For nK := 0 To 7
        aM := QRMonta(nV, aCw, nK)
        nPen := QRPenalidade(aM)
        If nMelhor < 0 .Or. nPen < nMelhor
            nMelhor := nPen
            aBest := aM
        EndIf
    Next nK
Return {nV, aBest}

/*/{Protheus.doc} GEBQRSVG
    QR Code em SVG (um retangulo por trecho escuro de cada linha).
    @type Biblioteca
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBQRSVG(cTexto, nModulo)
    Local aQ := GEBQRMATRIZ(cTexto)
    Local aM := aQ[2]
    Local cS := ""
    Local nN := Len(aM)
    Local nT := 0
    Local nR := 0
    Local nC := 0
    Local nIni := 0
    If nModulo == Nil
        nModulo := 4
    EndIf
    If nN == 0
        Return ""
    EndIf
    nT := (nN + 8) * nModulo
    cS := '<svg xmlns="http://www.w3.org/2000/svg" width="' + cValToChar(nT) + '" height="' + cValToChar(nT) + ;
        '" viewBox="0 0 ' + cValToChar(nN + 8) + " " + cValToChar(nN + 8) + '" shape-rendering="crispEdges">' + ;
        '<rect width="100%" height="100%" fill="#fff"/><path fill="#000" d="'
    For nR := 1 To nN
        nC := 1
        Do While nC <= nN
            If aM[nR][nC] == 1
                nIni := nC
                Do While nC <= nN
                    If aM[nR][nC] != 1
                        Exit
                    EndIf
                    nC++
                EndDo
                cS += "M" + cValToChar(nIni + 3) + " " + cValToChar(nR + 3) + "h" + cValToChar(nC - nIni) + "v1h-" + cValToChar(nC - nIni) + "z"
            Else
                nC++
            EndIf
        EndDo
    Next nR
Return cS + '"/></svg>'

// Blocos do nivel M da versao: {{qtd, total, dados}, ...}.
Static Function QRBlocos(nV)
    Local cTab := "1,26,16;1,44,28;1,70,44;2,50,32;2,67,43;4,43,27;4,49,31;2,60,38,2,61,39;3,58,36,2,59,37;4,69,43,1,70,44;" + ;
        "1,80,50,4,81,51;6,58,36,2,59,37;8,59,37,1,60,38;4,64,40,5,65,41;5,65,41,5,66,42;7,73,45,3,74,46;10,74,46,1,75,47;" + ;
        "9,69,43,4,70,44;3,70,44,11,71,45;3,67,41,13,68,42;17,68,42;17,74,46;4,75,47,14,76,48;6,73,45,14,74,46;8,75,47,13,76,48;" + ;
        "19,74,46,4,75,47;22,73,45,3,74,46;3,73,45,23,74,46;21,73,45,7,74,46;19,75,47,10,76,48;2,74,46,29,75,47;10,74,46,23,75,47;" + ;
        "14,74,46,21,75,47;14,74,46,23,75,47;12,75,47,26,76,48;6,75,47,34,76,48;29,74,46,14,75,47;13,74,46,32,75,47;" + ;
        "40,75,47,7,76,48;18,75,47,31,76,48"
    Local aN := StrTokArr(StrTokArr(cTab, ";")[nV], ",")
    Local aRet := {}
    Local nI := 0
    For nI := 1 To Len(aN) Step 3
        aAdd(aRet, {Val(aN[nI]), Val(aN[nI + 1]), Val(aN[nI + 2])})
    Next nI
Return aRet

Static Function QRAlinhamento(nV)
    Local cTab := ";6,18;6,22;6,26;6,30;6,34;6,22,38;6,24,42;6,26,46;6,28,50;6,30,54;6,32,58;6,34,62;6,26,46,66;6,26,48,70;" + ;
        "6,26,50,74;6,30,54,78;6,30,56,82;6,30,58,86;6,34,62,90;6,28,50,72,94;6,26,50,74,98;6,30,54,78,102;6,28,54,80,106;" + ;
        "6,32,58,84,110;6,30,58,86,114;6,34,62,90,118;6,26,50,74,98,122;6,30,54,78,102,126;6,26,52,78,104,130;6,30,56,82,108,134;" + ;
        "6,34,60,86,112,138;6,30,58,86,114,142;6,34,62,90,118,146;6,30,54,78,102,126,150;6,24,50,76,102,128,154;" + ;
        "6,28,54,80,106,132,158;6,32,58,84,110,136,162;6,26,54,82,110,138,166;6,30,58,86,114,142,170"
    Local aP := {}
    Local aN := {}
    Local nI := 0
    // StrTokArr do AdvPP mantem o item vazio inicial: o item nV e' a versao nV.
    aN := StrTokArr(StrTokArr(cTab, ";")[nV], ",")
    If nV == 1
        Return aP
    EndIf
    For nI := 1 To Len(aN)
        aAdd(aP, Val(aN[nI]))
    Next nI
Return aP

Static Function QRCapacidade(aBlk)
    Local nCap := 0
    Local nI := 0
    For nI := 1 To Len(aBlk)
        nCap += aBlk[nI][1] * aBlk[nI][3]
    Next nI
Return nCap

Static Function QRBitsQtd(nV)
    If nV <= 9
        Return 8
    EndIf
Return 16

Static Function QRPoe(aBits, nVal, nLen)
    Local nI := 0
    For nI := nLen - 1 To 0 Step -1
        aAdd(aBits, Int(nVal / (2 ^ nI)) % 2)
    Next nI
Return Nil

// Dados (modo byte) + terminador + enchimento, divididos em blocos com o RS
// de cada bloco e intercalados (dados, depois correcao).
Static Function QRCodewords(aDados, nV, aBlk, nCap)
    Local aBits := {}
    Local aBytes := {}
    Local aDc := {}
    Local aEc := {}
    Local aOut := {}
    Local aTab := QRGalois()
    Local nI := 0
    Local nJ := 0
    Local nB := 0
    Local nOff := 0
    Local nMaxD := 0
    Local nMaxE := 0
    Local nPad := 0
    Local aUm := {}

    QRPoe(aBits, 4, 4)
    QRPoe(aBits, Len(aDados), QRBitsQtd(nV))
    For nI := 1 To Len(aDados)
        QRPoe(aBits, aDados[nI], 8)
    Next nI
    For nI := 1 To Min(nCap * 8 - Len(aBits), 4)
        aAdd(aBits, 0)
    Next nI
    Do While Len(aBits) % 8 != 0
        aAdd(aBits, 0)
    EndDo
    For nI := 1 To Len(aBits) Step 8
        nB := 0
        For nJ := 0 To 7
            nB := nB * 2 + aBits[nI + nJ]
        Next nJ
        aAdd(aBytes, nB)
    Next nI
    Do While Len(aBytes) < nCap
        If nPad % 2 == 0
            aAdd(aBytes, 236)
        Else
            aAdd(aBytes, 17)
        EndIf
        nPad++
    EndDo
    For nI := 1 To Len(aBlk)
        For nJ := 1 To aBlk[nI][1]
            aUm := {}
            For nB := 1 To aBlk[nI][3]
                aAdd(aUm, aBytes[nOff + nB])
            Next nB
            nOff += aBlk[nI][3]
            aAdd(aDc, aUm)
            aAdd(aEc, QRReedSolomon(aUm, aBlk[nI][2] - aBlk[nI][3], aTab))
            nMaxD := Max(nMaxD, Len(aUm))
            nMaxE := Max(nMaxE, aBlk[nI][2] - aBlk[nI][3])
        Next nJ
    Next nI
    For nI := 1 To nMaxD
        For nJ := 1 To Len(aDc)
            If nI <= Len(aDc[nJ])
                aAdd(aOut, aDc[nJ][nI])
            EndIf
        Next nJ
    Next nI
    For nI := 1 To nMaxE
        For nJ := 1 To Len(aEc)
            If nI <= Len(aEc[nJ])
                aAdd(aOut, aEc[nJ][nI])
            EndIf
        Next nJ
    Next nI
Return aOut

// {aExp, aLog} de GF(256) com o polinomio 0x11D (indices +1).
Static Function QRGalois()
    Local aExp := Array(512)
    Local aLog := Array(256)
    Local nX := 1
    Local nI := 0
    For nI := 0 To 254
        aExp[nI + 1] := nX
        aLog[nX + 1] := nI
        nX := nX * 2
        If nX >= 256
            nX := NXor(nX, 285)
        EndIf
    Next nI
    For nI := 255 To 511
        aExp[nI + 1] := aExp[nI - 254]
    Next nI
Return {aExp, aLog}

Static Function QRMulGF(nA, nB, aTab)
    If nA == 0 .Or. nB == 0
        Return 0
    EndIf
Return aTab[1][aTab[2][nA + 1] + aTab[2][nB + 1] + 1]

// Resto da divisao dos dados pelo gerador de grau nEc (correcao do bloco).
Static Function QRReedSolomon(aDc, nEc, aTab)
    Local aGen := {1}
    Local aNovo := {}
    Local aRes := Array(nEc)
    Local nFat := 0
    Local nI := 0
    Local nJ := 0
    For nI := 0 To nEc - 1
        aNovo := Array(Len(aGen) + 1)
        AFill(aNovo, 0)
        For nJ := 1 To Len(aGen)
            aNovo[nJ] := NXor(aNovo[nJ], aGen[nJ])
            aNovo[nJ + 1] := NXor(aNovo[nJ + 1], QRMulGF(aGen[nJ], aTab[1][nI + 1], aTab))
        Next nJ
        aGen := aNovo
    Next nI
    AFill(aRes, 0)
    For nI := 1 To Len(aDc)
        nFat := NXor(aDc[nI], aRes[1])
        For nJ := 1 To nEc - 1
            aRes[nJ] := aRes[nJ + 1]
        Next nJ
        aRes[nEc] := 0
        For nJ := 1 To nEc
            aRes[nJ] := NXor(aRes[nJ], QRMulGF(aGen[nJ + 1], nFat, aTab))
        Next nJ
    Next nI
Return aRes

// Matriz completa da versao com a mascara nK: -1 = livre (dados).
Static Function QRMonta(nV, aCw, nK)
    Local nN := nV * 4 + 17
    Local aM := Array(nN)
    Local aP := QRAlinhamento(nV)
    Local nR := 0
    Local nC := 0
    Local nI := 0
    Local nJ := 0
    Local nBits := 0
    Local nCol := 0
    Local nInc := -1
    Local nRow := 0
    Local nByte := 1
    Local nBit := 7
    Local nEsc := 0
    Local nX := 0

    For nR := 1 To nN
        aM[nR] := Array(nN)
        AFill(aM[nR], -1)
    Next nR
    QRLocalizador(aM, 0, 0, nN)
    QRLocalizador(aM, nN - 7, 0, nN)
    QRLocalizador(aM, 0, nN - 7, nN)
    For nI := 1 To Len(aP)
        For nJ := 1 To Len(aP)
            If aM[aP[nI] + 1][aP[nJ] + 1] == -1
                For nR := -2 To 2
                    For nC := -2 To 2
                        If nR == -2 .Or. nR == 2 .Or. nC == -2 .Or. nC == 2 .Or. (nR == 0 .And. nC == 0)
                            aM[aP[nI] + nR + 1][aP[nJ] + nC + 1] := 1
                        Else
                            aM[aP[nI] + nR + 1][aP[nJ] + nC + 1] := 0
                        EndIf
                    Next nC
                Next nR
            EndIf
        Next nJ
    Next nI
    For nR := 8 To nN - 9
        If aM[nR + 1][7] == -1
            aM[nR + 1][7] := 1 - nR % 2
        EndIf
        If aM[7][nR + 1] == -1
            aM[7][nR + 1] := 1 - nR % 2
        EndIf
    Next nR

    // Formato: nivel M (00) + mascara, BCH(15,5) ^ 0x5412.
    nBits := QRBCH(nK, 1335, 10)
    nBits := NXor(nK * 1024 + nBits, 21522)
    For nI := 0 To 14
        nX := Int(nBits / (2 ^ nI)) % 2
        If nI < 6
            aM[nI + 1][9] := nX
        ElseIf nI < 8
            aM[nI + 2][9] := nX
        Else
            aM[nN - 15 + nI + 1][9] := nX
        EndIf
        If nI < 8
            aM[9][nN - nI] := nX
        ElseIf nI < 9
            aM[9][15 - nI + 1] := nX
        Else
            aM[9][15 - nI] := nX
        EndIf
    Next nI
    aM[nN - 8 + 1][9] := 1

    // Versao (7+): BCH(18,6).
    If nV >= 7
        nBits := nV * 4096 + QRBCH(nV, 7973, 12)
        For nI := 0 To 17
            nX := Int(nBits / (2 ^ nI)) % 2
            aM[Int(nI / 3) + 1][nI % 3 + nN - 11 + 1] := nX
            aM[nI % 3 + nN - 11 + 1][Int(nI / 3) + 1] := nX
        Next nI
    EndIf

    // Dados em ziguezague, de baixo para cima, pulando a coluna 6.
    nRow := nN - 1
    For nJ := nN - 1 To 1 Step -2
        // A coluna 6 (padrao de sincronismo) desloca os pares a esquerda dela.
        nCol := nJ
        If nCol <= 6
            nCol--
        EndIf
        Do While .T.
            For nC := nCol To nCol - 1 Step -1
                If nC >= 0 .And. QRLivre(aM, nRow, nC)
                    nEsc := 0
                    If nByte <= Len(aCw)
                        nEsc := Int(aCw[nByte] / (2 ^ nBit)) % 2
                    EndIf
                    If QRMascara(nK, nRow, nC)
                        nEsc := 1 - nEsc
                    EndIf
                    aM[nRow + 1][nC + 1] := nEsc
                    nBit--
                    If nBit < 0
                        nByte++
                        nBit := 7
                    EndIf
                EndIf
            Next nC
            nRow += nInc
            If nRow < 0 .Or. nRow >= nN
                nRow -= nInc
                nInc := -nInc
                Exit
            EndIf
        EndDo
    Next nJ
Return aM

// Celula ainda sem valor (sem curto-circuito no AdvPP: nC < 0 checado aqui).
Static Function QRLivre(aM, nRow, nC)
    If nC < 0
        Return .F.
    EndIf
Return aM[nRow + 1][nC + 1] == -1

Static Function QRLocalizador(aM, nRow, nCol, nN)
    Local nR := 0
    Local nC := 0
    For nR := -1 To 7
        If nRow + nR >= 0 .And. nRow + nR < nN
            For nC := -1 To 7
                If nCol + nC >= 0 .And. nCol + nC < nN
                    If (nR >= 0 .And. nR <= 6 .And. (nC == 0 .Or. nC == 6)) .Or. (nC >= 0 .And. nC <= 6 .And. (nR == 0 .Or. nR == 6)) .Or. ;
                            (nR >= 2 .And. nR <= 4 .And. nC >= 2 .And. nC <= 4)
                        aM[nRow + nR + 1][nCol + nC + 1] := 1
                    Else
                        aM[nRow + nR + 1][nCol + nC + 1] := 0
                    EndIf
                EndIf
            Next nC
        EndIf
    Next nR
Return Nil

// Resto BCH de nDado deslocado nGrau bits pelo gerador nGen.
Static Function QRBCH(nDado, nGen, nGrau)
    Local nD := nDado * (2 ^ nGrau)
    Do While QRDigitos(nD) - QRDigitos(nGen) >= 0
        nD := NXor(nD, nGen * (2 ^ (QRDigitos(nD) - QRDigitos(nGen))))
    EndDo
Return nD

Static Function QRDigitos(nD)
    Local nN := 0
    Do While nD != 0
        nN++
        nD := Int(nD / 2)
    EndDo
Return nN

Static Function QRMascara(nK, nI, nJ)
    If nK == 0
        Return (nI + nJ) % 2 == 0
    ElseIf nK == 1
        Return nI % 2 == 0
    ElseIf nK == 2
        Return nJ % 3 == 0
    ElseIf nK == 3
        Return (nI + nJ) % 3 == 0
    ElseIf nK == 4
        Return (Int(nI / 2) + Int(nJ / 3)) % 2 == 0
    ElseIf nK == 5
        Return (nI * nJ) % 2 + (nI * nJ) % 3 == 0
    ElseIf nK == 6
        Return ((nI * nJ) % 2 + (nI * nJ) % 3) % 2 == 0
    EndIf
Return ((nI * nJ) % 3 + (nI + nJ) % 2) % 2 == 0

// Penalidade (N1 sequencias, N2 blocos 2x2, N3 padrao 1011101, N4 proporcao).
Static Function QRPenalidade(aM)
    Local nN := Len(aM)
    Local nP := 0
    Local nEsc := 0
    Local nR := 0
    Local nC := 0
    Local nRun := 0
    Local nPct := 0
    For nR := 1 To nN
        nRun := 1
        For nC := 2 To nN
            If aM[nR][nC] == aM[nR][nC - 1]
                nRun++
            Else
                If nRun >= 5
                    nP += nRun - 2
                EndIf
                nRun := 1
            EndIf
        Next nC
        If nRun >= 5
            nP += nRun - 2
        EndIf
        nRun := 1
        For nC := 2 To nN
            If aM[nC][nR] == aM[nC - 1][nR]
                nRun++
            Else
                If nRun >= 5
                    nP += nRun - 2
                EndIf
                nRun := 1
            EndIf
        Next nC
        If nRun >= 5
            nP += nRun - 2
        EndIf
    Next nR
    For nR := 1 To nN - 1
        For nC := 1 To nN - 1
            If aM[nR][nC] == aM[nR][nC + 1] .And. aM[nR][nC] == aM[nR + 1][nC] .And. aM[nR][nC] == aM[nR + 1][nC + 1]
                nP += 3
            EndIf
        Next nC
    Next nR
    For nR := 1 To nN
        For nC := 1 To nN - 6
            If QRPadrao(aM, nR, nC, .T.)
                nP += 40
            EndIf
            If QRPadrao(aM, nC, nR, .F.)
                nP += 40
            EndIf
        Next nC
        For nC := 1 To nN
            nEsc += aM[nR][nC]
        Next nC
    Next nR
    nPct := Int(nEsc * 100 / (nN * nN))
    nP += Int(Abs(nPct - 50) / 5) * 10
Return nP

// 1011101 com 4 claros antes ou depois, na linha (lLinha) ou coluna.
Static Function QRPadrao(aM, nR, nC, lLinha)
    Local aPad := {1, 0, 1, 1, 1, 0, 1}
    Local nN := Len(aM)
    Local nI := 0
    Local lAntes := .T.
    Local lDepois := .T.
    Local nV := 0
    For nI := 0 To 6
        nV := QRCel(aM, nR, nC, nI, lLinha)
        If nV != aPad[nI + 1]
            Return .F.
        EndIf
    Next nI
    For nI := 1 To 4
        If QRPos(nR, nC, -nI, lLinha) < 1 .Or. QRCel(aM, nR, nC, -nI, lLinha) != 0
            lAntes := .F.
        EndIf
        If QRPos(nR, nC, 6 + nI, lLinha) > nN .Or. QRCel(aM, nR, nC, 6 + nI, lLinha) != 0
            lDepois := .F.
        EndIf
    Next nI
Return lAntes .Or. lDepois

Static Function QRPos(nR, nC, nD, lLinha)
    If lLinha
        Return nC + nD
    EndIf
Return nR + nD

// Celula deslocada; fora da matriz conta como clara (a margem).
Static Function QRCel(aM, nR, nC, nD, lLinha)
    Local nN := Len(aM)
    If lLinha
        If nC + nD < 1 .Or. nC + nD > nN
            Return 0
        EndIf
        Return aM[nR][nC + nD]
    EndIf
    If nR + nD < 1 .Or. nR + nD > nN
        Return 0
    EndIf
Return aM[nR + nD][nC]
