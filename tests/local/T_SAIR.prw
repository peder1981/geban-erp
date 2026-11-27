#include "totvs.ch"
#include "../../src/GEBTUI.prw"
User Function T_SAIR()
    Local aE := {}
    Local aF := {}
    GEBDBConecta()
    GEBDBSetTenant("99")
    ConOut("login: " + cValToChar(GEBSECLOGIN("super", "Demo#2026", "tui")))
    aE := GEBTUIEMPRESAS("super")
    ConOut("emps: " + cValToChar(Len(aE)))
    aF := GEBTUIFILIAL("super", "99")
    ConOut("fils: " + cValToChar(Len(aF)))
Return
