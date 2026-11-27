#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBEXP_CTX.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBMON.prw"
#include "../src/GEBSEC_TOKEN.prw"

/*/{Protheus.doc} T_GEBMON
    Teste do modulo de monitoramento.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
/*/
User Function T_GEBMON()
    Local lOk := .T.
    Local aMet := {}
    Local aList := {}
    Local cRot := ""
    Local cTokGer := ""
    Local aTokRow := {}
    Local cExpGer := ""
    Local cHojeStr := ""
    Local cAmanhaStr := ""
    Local nOnlineGet := -1
    Local nOnline0 := 0

    If !GEBDBConecta()
        ConOut("T_GEBMON: GEBDBConecta fail")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_mon CASCADE")
    TCSqlExec("CREATE SCHEMA emp_test_mon")
    TCSqlExec("SET search_path TO emp_test_mon")

    If !GENMIG()
        ConOut("T_GEBMON: GENMIG fail")
        lOk := .F.
    EndIf
    If !TCSecMIG()
        ConOut("T_GEBMON: TCSecMIG fail")
        lOk := .F.
    EndIf
    GEXBINIT()
    GBAUDINIC()
    GEBMONINIC()

    // Baseline: GE2_TOK e' catalogo global (public) e acumula tokens de
    // outros testes; a metrica conta todos os validos, entao o assert usa
    // o delta em vez de um total absoluto.
    nOnline0 := GEBMONMETRICAS()[1]

    // GEBSECTOKEN() deve expirar em ~8h (mesmo dia ou dia seguinte), nao
    // em ~480 dias -- cobre a correcao de Date()+N em GEBSEC_TOKEN.prw.
    cTokGer := GEBSECTOKEN("usrtest", "01", "01", "127.0.0.1")
    If cTokGer == ""
        ConOut("T_GEBMON: GEBSECTOKEN nao gerou token")
        lOk := .F.
    Else
        aTokRow := TCSqlQuery("SELECT TOK_EXPIRES FROM public.GE2_TOK WHERE TOK_TOKEN = '" + cTokGer + "'")
        If Len(aTokRow) != 1
            ConOut("T_GEBMON: token gerado nao encontrado em GE2_TOK")
            lOk := .F.
        Else
            cExpGer := AllTrim(aTokRow[1]:TOK_EXPIRES)
            // Comparacao por STRING (YYYYMMDD), nunca por subtracao de
            // Date -- neste runtime AdvPP "Date - Date" tambem nao devolve
            // Numeric utilizavel (ToFloat trata DateValue como 0, entao a
            // subtracao antiga dava sempre 0, mascarando qualquer bug).
            cHojeStr := DToS(Date())
            cAmanhaStr := T_GEBMON_DiaSeguinte(cHojeStr)
            If Len(cExpGer) < 8 .Or. SubStr(cExpGer, 1, 8) < cHojeStr .Or. SubStr(cExpGer, 1, 8) > cAmanhaStr
                ConOut("T_GEBMON: TOK_EXPIRES fora da faixa esperada (hoje ou amanha): " + cExpGer + " (hoje=" + cHojeStr + ")")
                lOk := .F.
            EndIf
        EndIf
    EndIf

    // Cenario de contagem "online": um token claramente expirado (data
    // fixa no passado) nao deve contar; um claramente valido (data fixa
    // no futuro) deve contar. Datas fixas (nao Date()+/-N) porque, neste
    // runtime AdvPP, Date()+N nao devolve tipo Date (ver nota em
    // GEBSEC_TOKEN.prw); usar literais evita depender desse operador aqui.
    TCSqlExec("INSERT INTO public.GE2_TOK (D_E_L_E_T_, TOK_TOKEN, TOK_USUARIO, TOK_EMPRESA, TOK_FILIAL, TOK_IP, TOK_CREATED, TOK_EXPIRES) VALUES (' ', 'tok_expirado_tmon', 'usrexp_tmon', '01', '01', '127.0.0.1', '20200101 00:00:00', '20200102 00:00:00')")
    TCSqlExec("INSERT INTO public.GE2_TOK (D_E_L_E_T_, TOK_TOKEN, TOK_USUARIO, TOK_EMPRESA, TOK_FILIAL, TOK_IP, TOK_CREATED, TOK_EXPIRES) VALUES (' ', 'tok_valido_tmon', 'usrval_tmon', '01', '01', '127.0.0.1', '20301231 00:00:00', '20301231 23:59:59')")

    aMet := GEBMONMETRICAS()
    aList := GEBMONLISTAR()
    cRot := GEBMONROTINA("token_teste")

    // aMet[1] = nUsuariosOnline: so "tok_valido" e o gerado por GEBSECTOKEN()
    // devem contar; "tok_expirado" nao. Prova que a metrica usa a
    // expiracao real (~8h), corrigida em src/GEBSEC_TOKEN.prw -- o bug
    // original produzia TOK_EXPIRES vazio ("", Date()+N nao devolve Date
    // neste runtime), nao uma data futura.
    If Len(aMet) >= 1
        nOnlineGet := aMet[1]
    EndIf
    If nOnlineGet != nOnline0 + 2
        ConOut("T_GEBMON: nUsuariosOnline esperado " + cValToChar(nOnline0 + 2) + " (baseline+2), obtido " + cValToChar(nOnlineGet))
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM public.GE2_TOK WHERE TOK_TOKEN = " + GEBDBQuote(cTokGer))
    TCSqlExec("DELETE FROM public.GE2_TOK WHERE TOK_USUARIO IN ('usrexp_tmon', 'usrval_tmon')")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_mon CASCADE")

    If lOk
        ConOut("T_GEBMON PASS")
    Else
        ConOut("T_GEBMON FAIL")
    EndIf
Return lOk

// Dia seguinte a cData ("YYYYMMDD"), aritmetica pura em Y/M/D com "+",
// "-" e "%" -- mesma logica de GBSTokDiaSeguinte() em GEBSEC_TOKEN.prw,
// duplicada aqui por ser Static la (nao visivel a este teste). Neste
// runtime AdvPP "Date()+N"/"Date-Date" nao devolvem Numeric utilizavel.
Static Function T_GEBMON_DiaSeguinte(cData)
    Local nAno      := Val(SubStr(cData, 1, 4))
    Local nMes      := Val(SubStr(cData, 5, 2))
    Local nDia      := Val(SubStr(cData, 7, 2))
    Local nUltDia   := 31
    Local lBissexto := .F.

    lBissexto := ((nAno % 4 == 0 .And. nAno % 100 != 0) .Or. nAno % 400 == 0)

    Do Case
        Case nMes == 4 .Or. nMes == 6 .Or. nMes == 9 .Or. nMes == 11
            nUltDia := 30
        Case nMes == 2
            If lBissexto
                nUltDia := 29
            Else
                nUltDia := 28
            EndIf
        Otherwise
            nUltDia := 31
    EndCase

    nDia := nDia + 1
    If nDia > nUltDia
        nDia := 1
        nMes := nMes + 1
        If nMes > 12
            nMes := 1
            nAno := nAno + 1
        EndIf
    EndIf

Return PadL(cValToChar(nAno), 4, "0") + PadL(cValToChar(nMes), 2, "0") + PadL(cValToChar(nDia), 2, "0")
