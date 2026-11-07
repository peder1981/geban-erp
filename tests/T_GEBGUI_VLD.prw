#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GENUC_CAD.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBV_FIA.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCOM_FOR.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBFIN_FLX.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBCTB_DIR.prw"
#include "../src/GEBGUI_VLD.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBCTX.prw"
#include "../src/GEBEST.prw"
#include "../src/GEBFNX.prw"
#include "../src/GEBFAT.prw"
#include "../src/GEBTEF.prw"
#include "../src/GEBLOJ.prw"
#include "../src/GEBDFE_XML.prw"
#include "../src/GEBDFE_WS.prw"
#include "../src/GEBDFE_MUN.prw"
#include "../src/GEBDFE_IE.prw"
#include "../src/GEBDFE_CAD.prw"
#include "../src/GEBDFE.prw"
#include "../src/GEBDFE_QR.prw"
#include "../src/GEBDFE_DANFE.prw"
#include "../src/GEBLOJ_CAD.prw"
#include "../src/GEBLOJ_OPE.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBGUI_VLD
    Teste da camada de validacao GUI (Task 1 GEB_GUI).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP.
    Asserts: migracoes OK; todos os 13 validadores retornam
    valores esperados em cenarios VALIDO/INVALIDO/MISS;
    GEBGUIFIN_BAI valida tipo/doc/valor/saldo;
    GEBGUIFIN_FLX retorna {rec,pag,saldo};
    GEBGUIFIS_EMI valida params;
    GEBGUIFIS_GER gera guia GD;
    GEBGUICTB_DIR checa PERMITE_DIRETA;
    GEBGUICONFIG_LC/SC fazem read-only/write GE4.
    Cleanup DELETE em todas as tabelas tocadas (rerun limpo).
    TCSqlExec("PRAGMA wal_checkpoint(TRUNCATE)")
    So literais; ConOut PASS/FAIL.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBGUI_VLD()
    Local lOk    := .T.
    Local lTmp   := .F.
    Local lVal   := .F.
    Local cStr   := ""
    Local aArr   := {}
    Local cFil1  := ""
    Local cFil2  := ""
    Local cFil3  := ""
    Local cFil4  := ""
    Local cFil5  := ""
    Local cFil6  := ""
    Local cFiln  := ""
    Local cFilk  := ""
    Local cFilg  := ""
    Local nSaldo := 0

    If !GEBDBConecta()
        ConOut("T_GEBGUI_VLD: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebgui_vld CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_gvld CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebgui_vld")
    TCSqlExec("CREATE SCHEMA emp_gvld")
    TCSqlExec("SET search_path TO emp_gvld, test_gebgui_vld")
    GBAUDINIC()

    // Migracoes
    If !GENMIG()
        lOk := .F.
    EndIf
    TCSecMIG()
    If !GEBFMIG()
        lOk := .F.
    EndIf
    If !GEBVMIG()
        lOk := .F.
    EndIf
    If !GEBCMMIG()
        lOk := .F.
    EndIf
    If !GEBFNMIG()
        lOk := .F.
    EndIf
    If !GEBDMIG()
        lOk := .F.
    EndIf
    If !GEBCMIG()
        lOk := .F.
    EndIf

    // Limpeza prev
    TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO IN ('EMISSAO','APURACAO','PERMITE_DIRETA')")
    TCSqlExec("DELETE FROM GF1 WHERE GF1_COD = 'PROD-VLD'")
    TCSqlExec("DELETE FROM GCP1 WHERE GCP1_COD = 'FORN-VLD'")
    TCSqlExec("DELETE FROM GV3 WHERE GV3_CLI = 'CLI-VLD'")
    TCSqlExec("DELETE FROM GV1 WHERE GV1_PROD = 'PROD-EST'")
    TCSqlExec("DELETE FROM GFN2 WHERE GFN2_DOC IN ('REC-VLD','REC-FLX1','REC-FLX2')")
    TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC IN ('PAG-FLX1')")
    TCSqlExec("DELETE FROM GFN4 WHERE GFN4_CONTA = 'CAIXA'")
    TCSqlExec("DELETE FROM GFN1 WHERE GFN1_CONTA = 'CAIXA'")
    TCSqlExec("DELETE FROM GD1 WHERE GD1_GUIA = 'GD-VLD'")
    TCSqlExec("DELETE FROM GF5 WHERE GF5_COMP = '202601'")
    TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'TEST_CFG'")

    // ===== T1: GEBGUIPROD_CK =====
    cFil1 := FWxFilial("GF1")
    DbSelectArea("GF1")
    DbAppend()
    RecLock("GF1", .T.)
    GF1->GF1_FILIAL := cFil1
    GF1->D_E_L_E_T_ := " "
    GF1->GF1_COD    := "PROD-VLD"
    GF1->GF1_NCM    := "0000.00.00"
    GF1->GF1_DESC   := "Produto teste"
    MsUnlock()
    DbCloseArea()

    lVal := GEBGUIPROD_CK("PROD-VLD")
    If !lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIPROD_CK("INEXISTENTE")
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIPROD_CK("")
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIPROD_CK(Nil)
    If lVal
        lOk := .F.
    EndIf

    // ===== T2: GEBGUIFORN_CK =====
    cFil2 := FWxFilial("GCP1")
    DbSelectArea("GCP1")
    DbAppend()
    RecLock("GCP1", .T.)
    GCP1->GCP1_FILIAL := cFil2
    GCP1->D_E_L_E_T_  := " "
    GCP1->GCP1_COD    := "FORN-VLD"
    GCP1->GCP1_NOME   := "Fornecedor teste"
    GCP1->GCP1_CNPJ   := ""
    MsUnlock()
    DbCloseArea()

    lVal := GEBGUIFORN_CK("FORN-VLD")
    If !lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIFORN_CK("INEXISTENTE")
    If lVal
        lOk := .F.
    EndIf

    // ===== T3: GEBGUICLI_CK =====
    cFil3 := FWxFilial("GV3")
    DbSelectArea("GV3")
    DbAppend()
    RecLock("GV3", .T.)
    GV3->GV3_FILIAL := cFil3
    GV3->D_E_L_E_T_ := " "
    GV3->GV3_CLI    := "CLI-VLD"
    GV3->GV3_VALOR  := 100
    GV3->GV3_JUROS  := 0
    GV3->GV3_MULTA  := 0
    GV3->GV3_TOTAL  := 100
    GV3->GV3_STATUS := "ABERTA"
    MsUnlock()
    DbCloseArea()

    lVal := GEBGUICLI_CK("CLI-VLD")
    If !lVal
        lOk := .F.
    EndIf
    lVal := GEBGUICLI_CK("INEXISTENTE")
    If lVal
        lOk := .F.
    EndIf

    // ===== T4: GEBGUIPROD_EST =====
    cFil5 := FWxFilial("GV1")
    DbSelectArea("GV1")
    DbAppend()
    RecLock("GV1", .T.)
    GV1->GV1_FILIAL := cFil5
    GV1->D_E_L_E_T_ := " "
    GV1->GV1_PROD   := "PROD-EST"
    GV1->GV1_SALDO  := 50
    GV1->GV1_MIN    := 10
    MsUnlock()
    DbCloseArea()

    lVal := GEBGUIPROD_EST("PROD-EST", 30)
    If !lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIPROD_EST("PROD-EST", 100)
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIPROD_EST("SEMESTOQUE", 1)
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIPROD_EST("", 1)
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIPROD_EST("PROD-EST", 0)
    If lVal
        lOk := .F.
    EndIf

    // ===== T5: GEBGUIFIADO_LIM =====
    lVal := GEBGUIFIADO_LIM("CLI-VLD", 50)
    If !lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIFIADO_LIM("CLI-VLD", 1000)
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIFIADO_LIM("", 10)
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIFIADO_LIM("CLI-VLD", 0)
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIFIADO_LIM("NAOEXISTE", 10)
    If !lVal
        lOk := .F.
    EndIf

    // ===== T6: GEBGUIFIN_BAI =====
    cFiln := FWxFilial("GFN2")
    DbSelectArea("GFN2")
    DbAppend()
    RecLock("GFN2", .T.)
    GFN2->GFN2_FILIAL := cFiln
    GFN2->D_E_L_E_T_  := " "
    GFN2->GFN2_DOC    := "REC-VLD"
    GFN2->GFN2_CLI    := "CLI-VLD"
    GFN2->GFN2_VALOR  := 500
    GFN2->GFN2_SALDO  := 500
    GFN2->GFN2_VENC   := "20261231"
    GFN2->GFN2_STATUS := "ABERTO"
    MsUnlock()
    DbCloseArea()

    TCSqlExec("INSERT INTO GFN1 (D_E_L_E_T_, GFN1_FILIAL, GFN1_CONTA, GFN1_NOME, GFN1_SALDO) VALUES (' ', '      ', 'CAIXA', 'Caixa', 0)")

    lVal := GEBGUIFIN_BAI("REC", "REC-VLD", 100)
    If !lVal
        lOk := .F.
    EndIf
    // saldo agora 400; tentativa maior que saldo deve falhar
    lVal := GEBGUIFIN_BAI("REC", "REC-VLD", 600)
    If lVal
        lOk := .F.
    EndIf
    // baixa total do saldo remanescente
    lVal := GEBGUIFIN_BAI("REC", "REC-VLD", 400)
    If !lVal
        lOk := .F.
    EndIf
    // titulo ja quitado nao permite nova baixa
    lVal := GEBGUIFIN_BAI("REC", "REC-VLD", 10)
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIFIN_BAI("XXX", "REC-VLD", 10)
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIFIN_BAI("REC", "", 10)
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIFIN_BAI("REC", "REC-VLD", 0)
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIFIN_BAI("REC", "NAOREC", 10)
    If lVal
        lOk := .F.
    EndIf

    // ===== T7: GEBGUIFIN_FLX =====
    // Criar titulos fresh para fluxo
    DbSelectArea("GFN2")
    DbAppend()
    RecLock("GFN2", .T.)
    GFN2->GFN2_FILIAL := cFiln
    GFN2->D_E_L_E_T_  := " "
    GFN2->GFN2_DOC    := "REC-FLX1"
    GFN2->GFN2_CLI    := "CLI-VLD"
    GFN2->GFN2_VALOR  := 500
    GFN2->GFN2_SALDO  := 500
    GFN2->GFN2_VENC   := "20261231"
    GFN2->GFN2_STATUS := "ABERTO"
    MsUnlock()
    DbCloseArea()
    DbSelectArea("GFN2")
    DbAppend()
    RecLock("GFN2", .T.)
    GFN2->GFN2_FILIAL := cFiln
    GFN2->D_E_L_E_T_  := " "
    GFN2->GFN2_DOC    := "REC-FLX2"
    GFN2->GFN2_CLI    := "CLI-VLD"
    GFN2->GFN2_VALOR  := 200
    GFN2->GFN2_SALDO  := 200
    GFN2->GFN2_VENC   := "20261231"
    GFN2->GFN2_STATUS := "ABERTO"
    MsUnlock()
    DbCloseArea()
    cFil6 := FWxFilial("GFN3")
    DbSelectArea("GFN3")
    DbAppend()
    RecLock("GFN3", .T.)
    GFN3->GFN3_FILIAL := cFil6
    GFN3->D_E_L_E_T_  := " "
    GFN3->GFN3_DOC    := "PAG-FLX1"
    GFN3->GFN3_FORN   := "FORN-VLD"
    GFN3->GFN3_VALOR  := 300
    GFN3->GFN3_SALDO  := 300
    GFN3->GFN3_VENC   := "20261231"
    GFN3->GFN3_STATUS := "ABERTO"
    MsUnlock()
    DbCloseArea()

    aArr := GEBGUIFIN_FLX()
    If Len(aArr) != 3
        lOk := .F.
    Else
        If !(aArr[1] == 700)
            lOk := .F.
        EndIf
        If !(aArr[2] == 300)
            lOk := .F.
        EndIf
        If !(aArr[3] == 400)
            lOk := .F.
        EndIf
    EndIf

    // baixa parcial 100 em REC-FLX1 => saldo 400
    lVal := GEBGUIFIN_BAI("REC", "REC-FLX1", 100)
    If !lVal
        lOk := .F.
    EndIf
    aArr := GEBGUIFIN_FLX()
    If !(aArr[1] == 600)
        lOk := .F.
    EndIf
    If !(aArr[2] == 300)
        lOk := .F.
    EndIf
    If !(aArr[3] == 300)
        lOk := .F.
    EndIf

    // baixa total 300 em PAG-FLX1
    lVal := GEBGUIFIN_BAI("PAG", "PAG-FLX1", 300)
    If !lVal
        lOk := .F.
    EndIf
    aArr := GEBGUIFIN_FLX()
    If !(aArr[1] == 600)
        lOk := .F.
    EndIf
    If !(aArr[2] == 0)
        lOk := .F.
    EndIf
    If !(aArr[3] == 600)
        lOk := .F.
    EndIf

    // ===== T8: GEBGUIFIS_EMI =====
    cFil4 := FWxFilial("GF2")
    DbSelectArea("GF2")
    DbAppend()
    RecLock("GF2", .T.)
    GF2->GF2_FILIAL := cFil4
    GF2->D_E_L_E_T_ := " "
    GF2->GF2_NCM    := "0000.00.00"
    GF2->GF2_IBS    := 7.5
    GF2->GF2_CBS    := 0
    GF2->GF2_INI    := "20200101"
    GF2->GF2_FIM    := "20301231"
    MsUnlock()
    DbCloseArea()

    lVal := GEBGUIFIS_EMI("NF-VLD", "PROD-VLD", 2, 100)
    If !lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIFIS_EMI("", "PROD-VLD", 1, 10)
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIFIS_EMI("NF2", "", 1, 10)
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIFIS_EMI("NF3", "PROD-VLD", 0, 10)
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIFIS_EMI("NF4", "PROD-VLD", 1, 0)
    If lVal
        lOk := .F.
    EndIf

    // ===== T9: GEBGUIFIS_APU =====
    cFilg := FWxFilial("GF5")
    DbSelectArea("GF5")
    DbAppend()
    RecLock("GF5", .T.)
    GF5->GF5_FILIAL := cFilg
    GF5->D_E_L_E_T_ := " "
    GF5->GF5_COMP   := "202601"
    GF5->GF5_DEB    := 150
    GF5->GF5_CRED   := 0
    GF5->GF5_SALDO  := 150
    GF5->GF5_REGIME := "REGULAR"
    MsUnlock()
    DbCloseArea()

    lVal := GEBGUIFIS_APU("202601")
    If !lVal
        lOk := .F.
    EndIf
    lVal := GEBGUIFIS_APU("")
    If lVal
        lOk := .F.
    EndIf

    // ===== T10: GEBGUIFIS_GER =====
    // A apuracao acima refez 202601 sem notas (saldo 0, sem guia); a guia
    // precisa de imposto a pagar: volta o saldo de 150 da semente.
    TCSqlExec("UPDATE GF5 SET GF5_DEB = 150, GF5_SALDO = 150 WHERE GF5_COMP = '202601' AND D_E_L_E_T_ = ' '")
    cStr := GEBGUIFIS_GER("202601")
    If cStr == ""
        lOk := .F.
    EndIf
    cStr := GEBGUIFIS_GER("202601")
    If cStr == ""
        lOk := .F.
    EndIf
    cStr := GEBGUIFIS_GER("")
    If cStr != ""
        lOk := .F.
    EndIf
    cStr := GEBGUIFIS_GER("999999")
    If cStr != ""
        lOk := .F.
    EndIf

    // ===== T11: GEBGUICTB_DIR =====
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'PERMITE_DIRETA', 'S')")
    If !lTmp
        lOk := .F.
    EndIf
    cFilk := FWxFilial("GE2")
    DbSelectArea("GE2")
    DbAppend()
    RecLock("GE2", .T.)
    GE2->GE2_FILIAL := cFilk
    GE2->D_E_L_E_T_ := " "
    GE2->GE2_COD    := "ADMIN"
    GE2->GE2_NOME   := "Admin"
    GE2->GE2_PERFIL := "ADMIN"
    MsUnlock()
    DbCloseArea()
    // Perfil e' por empresa (GE2_EMP): ADMIN com vinculo na empresa 'gvld' (schema emp_gvld).
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'ADMIN'")
    TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA, GE2_EMP_PERFIL) VALUES (' ', '', 'ADMIN', 'gvld', 'ADMIN')")

    lVal := GEBGUICTB_DIR("ADMIN", "1.01.001", "3.01.001", 100)
    If !lVal
        lOk := .F.
    EndIf
    lVal := GEBGUICTB_DIR("ADMIN", "", "3.01.001", 100)
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUICTB_DIR("ADMIN", "1.01.001", "", 100)
    If lVal
        lOk := .F.
    EndIf
    lVal := GEBGUICTB_DIR("ADMIN", "1.01.001", "3.01.001", 0)
    If lVal
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'PERMITE_DIRETA'")
    lVal := GEBGUICTB_DIR("ADMIN", "1.01.001", "3.01.001", 100)
    If lVal
        lOk := .F.
    EndIf

    // ===== T12: GEBGUICONFIG_LC =====
    cStr := GEBGUICONFIG_LC("EMISSAO")
    cStr := GEBGUICONFIG_LC("")
    If cStr != ""
        lOk := .F.
    EndIf

    // ===== T13: GEBGUICONFIG_SC =====
    lTmp := GEBGUICONFIG_SC("TEST_CFG", "VAL1")
    If !lTmp
        lOk := .F.
    EndIf
    cStr := GEBGUICONFIG_LC("TEST_CFG")
    If cStr != "VAL1"
        lOk := .F.
    EndIf
    lTmp := GEBGUICONFIG_SC("TEST_CFG", "VAL2")
    If !lTmp
        lOk := .F.
    EndIf
    cStr := GEBGUICONFIG_LC("TEST_CFG")
    If cStr != "VAL2"
        lOk := .F.
    EndIf
    lTmp := GEBGUICONFIG_SC("", "X")
    If lTmp
        lOk := .F.
    EndIf

    // ===== CLEANUP =====
    TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO IN ('EMISSAO','APURACAO','PERMITE_DIRETA','TEST_CFG')")
    TCSqlExec("DELETE FROM GF1 WHERE GF1_COD = 'PROD-VLD'")
    TCSqlExec("DELETE FROM GF2 WHERE GF2_NCM = '0000.00.00'")
    TCSqlExec("DELETE FROM GCP1 WHERE GCP1_COD = 'FORN-VLD'")
    TCSqlExec("DELETE FROM GV3 WHERE GV3_CLI = 'CLI-VLD'")
    TCSqlExec("DELETE FROM GV1 WHERE GV1_PROD = 'PROD-EST'")
    TCSqlExec("DELETE FROM GFN2 WHERE GFN2_DOC IN ('REC-VLD','REC-FLX1','REC-FLX2')")
    TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC IN ('PAG-FLX1')")
    TCSqlExec("DELETE FROM GFN4 WHERE GFN4_CONTA = 'CAIXA'")
    TCSqlExec("DELETE FROM GFN1 WHERE GFN1_CONTA = 'CAIXA'")
    TCSqlExec("DELETE FROM GD1 WHERE GD1_GUIA = 'GD-VLD'")
    TCSqlExec("DELETE FROM GF5 WHERE GF5_COMP = '202601'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'ADMIN'")

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebgui_vld CASCADE")

    If lOk
        ConOut("T_GEBGUI_VLD PASS")
    Else
        ConOut("T_GEBGUI_VLD FAIL")
    EndIf
Return lOk
