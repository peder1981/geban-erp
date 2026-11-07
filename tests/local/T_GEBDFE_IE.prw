#include "totvs.ch"
#include "../../src/GEBDB_CORE.prw"
#include "../../src/GENUC_MIG.prw"
#include "../../src/GEBBOLIB.prw"
#include "../../src/GEBDFE_IE.prw"

/*/{Protheus.doc} T_GEBDFE_IE
    Teste local: le ../.out/local/ie_vetores.txt (UF|IE|esperado, gerado
    por T_GEBDFE_IE.sh com a implementacao de referencia) e confere
    GEBDFEIEOK em cada linha.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function T_GEBDFE_IE()
    Local aL := StrTokArr(MemoRead("../.out/local/ie_vetores.txt"), Chr(10))
    Local aC := {}
    Local nOk := 0
    Local nFalha := 0
    Local nI := 0
    Local lR := .F.
    For nI := 1 To Len(aL)
        aC := StrTokArr(aL[nI], "|")
        If Len(aC) == 3
            lR := GEBDFEIEOK(aC[2], aC[1])
            If lR == (aC[3] == "1")
                nOk++
            Else
                nFalha++
                If nFalha <= 30
                    ConOut("  FAIL " + aC[1] + " " + aC[2] + " esperado " + aC[3])
                EndIf
            EndIf
        EndIf
    Next nI
    // Exemplos oficiais (SINTEGRA) e o ISENTO.
    If !GEBDFEIEOK("0013000001-9", "MT") .Or. !GEBDFEIEOK("110.042.490.114", "SP") .Or. !GEBDFEIEOK("P-01100424.3/002", "SP") .Or. ;
            !GEBDFEIEOK("ISENTO", "SP", .T.) .Or. GEBDFEIEOK("ISENTO", "SP") .Or. GEBDFEIEOK("", "SP") .Or. GEBDFEIEOK("123", "XX")
        nFalha++
        ConOut("  FAIL exemplos oficiais")
    EndIf
    ConOut("  conferidos " + cValToChar(nOk) + " falhas " + cValToChar(nFalha))
    If nFalha == 0 .And. nOk > 1000
        ConOut("T_GEBDFE_IE PASS")
    Else
        ConOut("T_GEBDFE_IE FAIL")
    EndIf
Return nFalha == 0
