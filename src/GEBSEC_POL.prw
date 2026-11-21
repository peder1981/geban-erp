#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBSEC_POL
    Politicas de senha do modulo de seguranca GEB_SEC (Task 4 GEB_SECURITY).
    Funcoes:
      - GEBSECPOL_VERIFICA(cSenha) -> {lOk,cMsg} : min 8 chars, 1 upper, 1 lower,
        1 digit, 1 special, nao sequencial (abc,123), nao repete 3x.
      - GEBSECPOL_EXPIRACAO(cUsuario) -> dData : ultima TrocaSenha + 90 dias
        (configuravel via GE4 "SEG_VIGENCIA"; padrao 90).
      - GEBSECPOL_FORCA(nForca) -> .T./.F. : politica ativa via GE4 "SEG_FORCA".
      - GEBSECFORCAR(cUsuario) -> void : marca usuario para forcar redefinicao.
    Notas AdvPP: ConOut p/ log; GetArea/RestArea guardados;
    workarea p/ leitura de GE2; guarda de existencia via GEBDBTableExists;
    sem SELECT *, sem concat SQL em queries de leitura,
    so literais. AdPP: If Nil em vez de Default. Portabilidade Postgres.
    @type Modulo de politica de senha
    @author Peder Munksgaard
    @since 23/09/2026
    @param cSenha      Senha a verificar (GEBSECPOL_VERIFICA)
    @param cUsuario    Codigo do usuario em GE2 (GEBSECPOL_EXPIRACAO/GEBSECFORCAR)
    @param nForca      Nivel de forca (1-10) (GEBSECPOL_FORCA)
    @return {lOk,cMsg} (GEBSECPOL_VERIFICA), dData (GEBSECPOL_EXPIRACAO), .T./.F. (GEBSECPOL_FORCA), void (GEBSECFORCAR)
/*/
User Function GEBSECPOL_VERIFICA(cSenha)
    Local aArea    := GetArea()
    Local lOk      := .T.
    Local cMsg     := ""
    Local cNorm    := ""
    Local nLen     := 0
    Local nUpper   := 0
    Local nLower   := 0
    Local nDigit   := 0
    Local nSpecial := 0
    Local nIdx     := 0
    Local cChar    := ""
    Local aSeq     := {}
    Local cSeq     := ""
    Local nSeqIdx  := 0
    Local cSub     := ""
    Local nRep     := 0
    Local cPrev    := ""

    // Default de parametro.
    If cSenha == Nil
        cSenha := ""
    EndIf

    cNorm := AllTrim(cSenha)
    nLen  := Len(cNorm)

    // Tamanho minimo: 8.
    If nLen < 8
        lOk   := .F.
        cMsg  := "senha muito curta (min 8)"
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {lOk, cMsg}
    EndIf

    // Contagem de categorias via presenca (At) para evitar bug do runtime
    // AdvPP que pula iteracoes do For quando o ultimo caractere e especial.
    // Usa loops sobre o alfabeto/digitos e At() para checar presenca.
    Local cAlphaNum := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    // Maiusculas
    For nIdx := 1 To 26
        cChar := Chr(64 + nIdx)
        If At(cChar, cNorm) > 0
            nUpper++
            Exit
        EndIf
    Next nIdx
    // Minusculas
    For nIdx := 1 To 26
        cChar := Chr(96 + nIdx)
        If At(cChar, cNorm) > 0
            nLower++
            Exit
        EndIf
    Next nIdx
    // Digitos
    For nIdx := 1 To 10
        cChar := Chr(47 + nIdx)
        If At(cChar, cNorm) > 0
            nDigit++
            Exit
        EndIf
    Next nIdx
    // Especiais: qualquer char fora de alfanumerico
    For nIdx := 1 To nLen
        cChar := SubStr(cNorm, nIdx, 1)
        If At(cChar, cAlphaNum) == 0
            nSpecial++
            Exit
        EndIf
    Next nIdx

    // Pelo menos 1 de cada.

    If nUpper   == 0
        lOk := .F.
        cMsg := "sem letra maiuscula"
    EndIf
    If nLower   == 0
        lOk := .F.
        cMsg := Iif(cMsg == "", "sem letra minuscula", cMsg + " + sem minuscula")
    EndIf
    If nDigit   == 0
        lOk := .F.
        cMsg := Iif(cMsg == "", "sem digito", cMsg + " + sem digito")
    EndIf
    If nSpecial == 0
        lOk := .F.
        cMsg := Iif(cMsg == "", "sem caractere especial", cMsg + " + sem especial")
    EndIf

    // Sequencias proibidas (abc, 123, xyz,cba,321,...).
    If lOk
        aSeq := {"ABC","BCD","CDE","DEF","EFG","FGH","GHI","HIJ","IJK","JKL","KLM","LMN","MNO","NOP","OPQ","PQR","QRS","RST","STU","TUV","UVW","VWX","WXY","XYZ", ;
                 "abc","bcd","cde","def","efg","fgh","ghi","hij","ijk","jkl","klm","lmn","mno","nop","opq","pqr","qrs","rst","stu","tuv","uvw","vwx","wxy","xyz", ;
                 "123","234","345","456","567","678","789","890", ;
                 "ZYX","YXW","XWV","WVU","VUT","UTS","TSR","SRQ","RQP","QPO","PON","ONM","NML","MLK","LKJ","KJI","JIH","IHG","HGF","FED","EDC","DCB","CBA", ;
                 "321","210"}
        For nSeqIdx := 1 To Len(aSeq)
            cSeq := aSeq[nSeqIdx]
            If At(cSeq, cNorm) > 0
                lOk    := .F.
                cMsg   := "sequencia proibida detectada (" + cSeq + ")"
                Exit
            EndIf
        Next nSeqIdx
    EndIf

    // Repeticao de mesmo caracter 3x seguidas.
    If lOk
        nRep := 0
        cPrev := ""
        For nIdx := 1 To nLen
            cChar := SubStr(cNorm, nIdx, 1)
            If cChar == cPrev
                nRep++
                If nRep >= 3
                    lOk    := .F.
                    cMsg   := "caractere repetido 3x (" + cChar + ")"
                    Exit
                EndIf
            Else
                nRep := 1
                cPrev := cChar
            EndIf
        Next nIdx
    EndIf

    If lOk
        cMsg := ""
    EndIf

    ConOut("GEBSECPOL_VERIFICA: len=" + cValToChar(nLen) + " ok=" + Iif(lOk, ".T.", ".F.") + " msg=" + cMsg)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {lOk, cMsg}

User Function GEBSECPOL_EXPIRACAO(cUsuario)
    Local aArea   := GetArea()
    Local cFil    := FWxFilial("GE2")
    Local cData   := DToS(Date())
    Local cUltima := "00000000"
    Local aUser   := {}
    Local cCfg    := ""
    Local nDias   := 90
    Local cResult := ""
    Local nIdx    := 0

    // Default de parametro.
    If cUsuario == Nil
        cUsuario := ""
    EndIf

    // Guarda: GE2 pode nao existir.
    If !GEBDBTableExists("GE2")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return ""
    EndIf

    // Busca ultima troca de senha em SEC_PWDLAST de GE2_SEC (workarea, pois TCSqlQuery nao retorna valores).
    DbSelectArea("GE2_SEC")
    DbGoTop()
    While !Eof()
        If GE2_SEC->SEC_FILIAL == cFil .And. GE2_SEC->SEC_USUARIO == cUsuario .And. GE2_SEC->D_E_L_E_T_ == " "
            cUltima := GE2_SEC->SEC_PWDLAST
            If cUltima == Nil
                cUltima := "00000000"
            EndIf
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    // Se nunca trocou, considera hoje como referencia.
    If cUltima == "00000000" .Or. cUltima == ""
        cUltima := cData
    EndIf

    // Le config de vigencia em GE4 ("SEG_VIGENCIA"); padrao 90 dias.
    cCfg := GEBCFG("SEG_VIGENCIA")
    If cCfg != ""
        nDias := Val(cCfg)
        If nDias <= 0
            nDias := 90
        EndIf
    EndIf

    // ponytail: BODTADD usa dia juliano (bissexto correto); data + n no AdvPP devolve numero.
    cResult := BODTADD(cUltima, nDias)

    ConOut("GEBSECPOL_EXPIRACAO: user=" + cUsuario + " ultima=" + cUltima + " dias=" + cValToChar(nDias) + " expira=" + cResult)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return cResult

User Function GEBSECPOL_FORCA(nForca)
    Local aArea  := GetArea()
    Local cCfg   := ""
    Local nQtd   := 0
    Local lOk    := .F.

    // Default de parametro.
    If nForca == Nil
        nForca := 0
    EndIf

    // Le flag SEG_FORCA em GE4.
    cCfg := GEBCFG("SEG_FORCA")
    If cCfg == "S"
        lOk := .T.
    EndIf

    ConOut("GEBSECPOL_FORCA: SEG_FORCA=" + cCfg + " nForca=" + cValToChar(nForca) + " ativo=" + Iif(lOk, ".T.", ".F."))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

User Function GEBSECFORCAR(cUsuario)
    Local aArea    := GetArea()
    Local cFil     := FWxFilial("GE2")
    Local lOk      := .F.
    Local aChk     := {}
    Local aUser    := {}
    Local cCfg     := ""
    Local lAtivo   := .F.
    Local cData    := DToS(Date())

    // Default de parametro.
    If cUsuario == Nil
        cUsuario := ""
    EndIf

    // Checa se politica de forca esta ativa via GE4.
    cCfg := GEBCFG("SEG_FORCA")
    If cCfg == "S"
        lAtivo := .T.
    EndIf

    If !lAtivo
        ConOut("GEBSECFORCAR: politica desabilitada (SEG_FORCA != S)")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    // Guarda: GE2_SEC pode nao existir.
    If !GEBDBTableExists("GE2_SEC")
        ConOut("GEBSECFORCAR: GE2_SEC inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    // Busca usuario.
    aUser := TCSqlQuery("SELECT * FROM GE2_SEC WHERE SEC_FILIAL = " + GEBDBQuote(cFil) + " AND SEC_USUARIO = " + GEBDBQuote(cUsuario) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aUser) == 0
        ConOut("GEBSECFORCAR: usuario inexistente '" + cUsuario + "'")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    // Zera SEC_PWDLAST para forcar redefinicao na proxima entrada.
    TCSqlExec("UPDATE GE2_SEC SET SEC_PWDLAST = '00000000' WHERE SEC_FILIAL = " + GEBDBQuote(cFil) + " AND SEC_USUARIO = " + GEBDBQuote(cUsuario) + "")
    lOk := .T.
    ConOut("GEBSECFORCAR: usuario=" + cUsuario + " marcado para redefinicao")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk
