#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"

/*/{Protheus.doc} T_GEBISO
    Prova de isolamento entre empresas sob concorrencia (Fase 2 da
    revisao geral). 6 workers (StartJob) alternando 2 empresas gravam e
    leem sem qualificar schema; nenhum pode ver/gravar a empresa do outro.
    Modo A: worker conecta sozinho (padrao sessao do advplc serve).
    Modo B: worker herda a conexao do pai (padrao requisicao REST).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 02/10/2026
/*/
User Function T_GEBISO()
    Local lOk := .T.
    Local nI := 0
    Local nEspera := 0
    Local aRes := {}
    Local aCnt := {}
    Local aEmp := {"zziso1", "zziso2"}

    If !GEBDBConecta()
        ConOut("T_GEBISO FAIL")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP TABLE IF EXISTS public.GEISO_RES")
    TCSqlExec("CREATE TABLE public.GEISO_RES (W VARCHAR(10), OK VARCHAR(1), MSG VARCHAR(250))")
    For nI := 1 To 2
        TCSqlExec("DROP SCHEMA IF EXISTS emp_" + aEmp[nI] + " CASCADE")
        TCSqlExec("CREATE SCHEMA emp_" + aEmp[nI])
        TCSqlExec("CREATE TABLE emp_" + aEmp[nI] + ".GEISO (EMP VARCHAR(10), W VARCHAR(10), I INTEGER)")
    Next nI

    For nI := 1 To 3
        StartJob("GEBISOWA", "", .F., aEmp[((nI - 1) % 2) + 1], "A" + cValToChar(nI))
        StartJob("GEBISOWB", "", .F., aEmp[(nI % 2) + 1], "B" + cValToChar(nI))
    Next nI

    Do While nEspera < 400
        aRes := TCSqlQuery("SELECT COUNT(*) AS N FROM public.GEISO_RES")
        If Len(aRes) > 0 .And. Val(aRes[1]:N) >= 6
            Exit
        EndIf
        Sleep(500)
        nEspera := nEspera + 1
    EndDo

    aRes := TCSqlQuery("SELECT W, OK, MSG FROM public.GEISO_RES ORDER BY W")
    If Len(aRes) < 6
        ConOut("FAIL: so " + cValToChar(Len(aRes)) + " de 6 workers terminaram")
        lOk := .F.
    EndIf
    For nI := 1 To Len(aRes)
        If aRes[nI]:OK != "S"
            ConOut("FAIL: worker " + aRes[nI]:W + " -> " + aRes[nI]:MSG)
            lOk := .F.
        Else
            ConOut("  OK worker " + aRes[nI]:W)
        EndIf
    Next nI
    For nI := 1 To 2
        aCnt := TCSqlQuery("SELECT COUNT(*) AS N FROM emp_" + aEmp[nI] + ".GEISO WHERE EMP <> '" + aEmp[nI] + "'")
        If Len(aCnt) == 0 .Or. Val(aCnt[1]:N) != 0
            ConOut("FAIL: emp_" + aEmp[nI] + " recebeu linhas de outra empresa")
            lOk := .F.
        EndIf
        aCnt := TCSqlQuery("SELECT COUNT(*) AS N FROM emp_" + aEmp[nI] + ".GEISO")
        If Len(aCnt) == 0 .Or. Val(aCnt[1]:N) != 450
            If Len(aCnt) > 0
                ConOut("FAIL: emp_" + aEmp[nI] + " tem " + aCnt[1]:N + " linhas, esperado 450")
            Else
                ConOut("FAIL: emp_" + aEmp[nI] + " sem contagem")
            EndIf
            lOk := .F.
        EndIf
    Next nI

    For nI := 1 To 2
        TCSqlExec("DROP SCHEMA IF EXISTS emp_" + aEmp[nI] + " CASCADE")
    Next nI
    TCSqlExec("DROP TABLE IF EXISTS public.GEISO_RES")

    If lOk
        ConOut("T_GEBISO PASS")
    Else
        ConOut("T_GEBISO FAIL")
    EndIf
Return lOk

User Function GEBISOWA(cEmp, cId)
    If !GEBDBConecta()
        TCSqlExec("INSERT INTO public.GEISO_RES (W, OK, MSG) VALUES ('" + cId + "', 'N', 'conecta falhou')")
        Return .F.
    EndIf
Return GEBISOLOOP(cEmp, cId)

User Function GEBISOWB(cEmp, cId)
Return GEBISOLOOP(cEmp, cId)

Static Function GEBISOLOOP(cEmp, cId)
    Local nI := 0
    Local nErr := 0
    Local cMsg := ""
    Local aSch := {}

    TCSqlExec("SET search_path TO emp_" + cEmp)
    For nI := 1 To 150
        If !TCSqlExec("INSERT INTO GEISO (EMP, W, I) VALUES ('" + cEmp + "', '" + cId + "', " + cValToChar(nI) + ")")
            nErr := nErr + 1
            cMsg := "insert falhou na iteracao " + cValToChar(nI)
        EndIf
        aSch := TCSqlQuery("SELECT current_schema()::text AS SCH")
        If Len(aSch) == 0 .Or. AllTrim(aSch[1]:SCH) != "emp_" + cEmp
            nErr := nErr + 1
            If Len(aSch) > 0
                cMsg := "schema " + aSch[1]:SCH + " na iteracao " + cValToChar(nI)
            EndIf
        EndIf
    Next nI
    If nErr == 0
        TCSqlExec("INSERT INTO public.GEISO_RES (W, OK, MSG) VALUES ('" + cId + "', 'S', '')")
    Else
        TCSqlExec("INSERT INTO public.GEISO_RES (W, OK, MSG) VALUES ('" + cId + "', 'N', '" + cValToChar(nErr) + " erros; ultimo: " + cMsg + "')")
    EndIf
Return (nErr == 0)
