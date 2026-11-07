#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*{Protheus.doc} GEBCOM_FOR
    Fornecedor + cotacao + menor preco GEBAN (Task 2 GEB_COM).
    Mapeamento 1:1 com as interfaces do plano (chamadas sem prefixo U_):
    U_GEBCMFOR -> GEBCMFOR | U_GEBCMCOT -> GEBCMCOT |
    U_GEBCMMEL -> GEBCMMEL.
    O prefixo U_ nao e usado nas chamadas porque o runtime AdvPP so
    resolve U_ em StartJob/FindFunction; chamada direta U_X() da
    "unknown function".
    GEBCMFOR(cCod, cNome) cria o fornecedor em GCP1 com CNPJ vazio
    via DbAppend() + RecLock(.T.); idempotente (cod existente
    retorna .T. sem duplicar); .F. se cod/nome vazio ou GCP1 ausente.
    GEBCMCOT(cForn, cProd, nPreco) grava a cotacao em GCP2 via
    DbAppend() + RecLock(.T.); .F. se forn/prod vazio, preco menor
    ou igual a zero ou GCP2 ausente.
    GEBCMMEL(cProd) varre GCP2 na filial e retorna o menor PRECO do
    produto (0 se produto vazio, GCP2 ausente ou sem cotacao).
    Notas AdvPP (balisador): log via ConOut; If Nil em vez de
    Default; GetArea/RestArea guardados; leitura via workarea;
    guarda via TCSqlQuery em pg_tables; escrita via DbAppend
    mais RecLock ponto T; FWxFilial retorna 6 espacos sem env;
    sem SELECT estrela, sem concat SQL, sem cFilial, sem IIF;
    so User/Static.
    @type Modulo de fornecedor
    @author Peder Munksgaard
    @since 23/09/2026
    @param cCod Codigo do fornecedor em GCP1 (GEBCMFOR)
    @param cNome Nome do fornecedor em GCP1 (GEBCMFOR)
    @param cForn Fornecedor da cotacao em GCP2 (GEBCMCOT)
    @param cProd Produto da cotacao/menor preco (GEBCMCOT/GEBCMMEL)
    @param nPreco Preco da cotacao em GCP2 (GEBCMCOT)
    @return .T./menor preco se OK, .F./0 se recusar
/*/
User Function GEBCMFOR(cCod, cNome)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GCP1")
    Local lAchou := .F.

    If cCod == Nil
        cCod := ""
    EndIf
    If cNome == Nil
        cNome := ""
    EndIf
    If cCod == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If cNome == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    If !GEBDBTableExistsHere("GCP1")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GCP1")
    DbGoTop()
    While !Eof()
        If GCP1->GCP1_FILIAL == cFil .AND. GCP1->GCP1_COD == cCod .AND. GCP1->D_E_L_E_T_ == " "
            lAchou := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If lAchou
        ConOut("FOR existe " + cCod)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .T.
    EndIf

    DbSelectArea("GCP1")
    DbAppend()
    RecLock("GCP1", .T.)
    GCP1->GCP1_FILIAL := cFil
    GCP1->D_E_L_E_T_ := " "
    GCP1->GCP1_COD := cCod
    GCP1->GCP1_NOME := cNome
    GCP1->GCP1_CNPJ := ""
    MsUnlock()
    DbCloseArea()

    ConOut("FOR " + cCod)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function GEBCMCOT(cForn, cProd, nPreco)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GCP2")

    If cForn == Nil
        cForn := ""
    EndIf
    If cProd == Nil
        cProd := ""
    EndIf
    If nPreco == Nil
        nPreco := 0
    EndIf
    If cForn == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If cProd == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If nPreco <= 0
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    If !GEBDBTableExistsHere("GCP2")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GCP2")
    DbAppend()
    RecLock("GCP2", .T.)
    GCP2->GCP2_FILIAL := cFil
    GCP2->D_E_L_E_T_ := " "
    GCP2->GCP2_FORN := cForn
    GCP2->GCP2_PROD := cProd
    GCP2->GCP2_PRECO := nPreco
    MsUnlock()
    DbCloseArea()

    ConOut("COT " + cProd + " " + cValToChar(nPreco))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function GEBCMMEL(cProd)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GCP2")
    Local nMel := 0

    If cProd == Nil
        cProd := ""
    EndIf
    If cProd == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return 0
    EndIf

    If !GEBDBTableExistsHere("GCP2")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return 0
    EndIf

    DbSelectArea("GCP2")
    DbGoTop()
    While !Eof()
        If GCP2->GCP2_FILIAL == cFil .AND. GCP2->GCP2_PROD == cProd .AND. GCP2->D_E_L_E_T_ == " "
            If nMel == 0 .OR. GCP2->GCP2_PRECO < nMel
                nMel := GCP2->GCP2_PRECO
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    ConOut("MEL " + cProd + " " + cValToChar(nMel))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return nMel
