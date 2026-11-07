#include "totvs.ch"
#include "../../src/GEBDB_CORE.prw"
#include "../../src/GENUC_MIG.prw"
#include "../../src/GEBBOLIB.prw"
#include "../../src/GEBDFE_XML.prw"
#include "../../src/GEBDFE_DANFE55.prw"

/*/{Protheus.doc} T_GEBDFE_C128
    Teste local: imprime as larguras Code 128 (C) de chaves de acesso para
    T_GEBDFE_C128.sh comparar com o reportlab.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function T_GEBDFE_C128()
    Local aC := {"35261012345678000195550010000000011123456789", "43150108287693000157651010000000971000001251", "00", "99887766554433221100"}
    Local nI := 0
    For nI := 1 To Len(aC)
        ConOut("C128 " + aC[nI] + " " + GEBC128(aC[nI]))
    Next nI
    ConOut("SVG " + Left(GEBC128SVG(aC[1], 40), 40))
    ConOut("IMPAR [" + GEBC128("123") + "]")
Return .T.
