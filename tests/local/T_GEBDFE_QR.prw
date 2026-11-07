#include "totvs.ch"
#include "../../src/GEBDFE_QR.prw"

/*/{Protheus.doc} T_GEBDFE_QR
    Teste local (sem banco): imprime a matriz do QR Code de cada texto em
    cada mascara (e na automatica) para T_GEBDFE_QR.sh comparar com a
    biblioteca Python qrcode.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function T_GEBDFE_QR()
    Local aTxt := {"A", "https://www.homologacao.nfce.fazenda.sp.gov.br/qrcode?p=35261012345678000195650010000000011123456789|3|2", ;
        Replicate("0123456789ABCDEF", 30), Replicate("x", 800)}
    Local aQ := {}
    Local cLin := ""
    Local nT := 0
    Local nK := 0
    Local nR := 0
    Local nC := 0
    For nT := 1 To Len(aTxt)
        For nK := -1 To 7
            aQ := GEBQRMATRIZ(aTxt[nT], nK)
            ConOut("QR " + cValToChar(nT) + " " + cValToChar(nK) + " " + cValToChar(aQ[1]))
            For nR := 1 To Len(aQ[2])
                cLin := ""
                For nC := 1 To Len(aQ[2][nR])
                    cLin += cValToChar(aQ[2][nR][nC])
                Next nC
                ConOut(cLin)
            Next nR
        Next nK
    Next nT
    ConOut("SVG " + Left(GEBQRSVG("teste"), 60))
Return .T.
