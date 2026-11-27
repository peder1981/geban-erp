#include "totvs.ch"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"

User Function TEST_INIT()
    Local lOk := .T.
    
    If !GENMIG()
        lOk := .F.
    EndIf
    If lOk .AND. !TCSecMIG()
        lOk := .F.
    EndIf
    If lOk .AND. !GEBEXPCriaAuditoria()
        lOk := .F.
    EndIf
    If lOk
        GBAUDINIC()
    EndIf
Return lOk
