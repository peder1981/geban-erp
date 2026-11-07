#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBCTX.prw"
#include "../src/GEBEST.prw"
#include "../src/GEBFNX.prw"
#include "../src/GEBFAT.prw"
#include "../src/GEBBCO.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBCOM_MIG.prw"
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
#include "../src/GEBSEC_LOGIN.prw"
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

/*/{Protheus.doc} T_GEBBCO
    Teste de boleto, CNAB 400 e conciliacao OFX (GEBBCO). Valores do boleto
    conferidos com uma implementacao independente (Python) das regras
    FEBRABAN/Bradesco:
    - modulo 10 "123" = 0, "0019373700" = 4; modulo 11 "123" = 6.
    - fator 22/02/2025 = 1000, 21/02/2025 = 9999, 20/11/2026 = 1636.
    - DV nosso numero carteira 09: 00000000001 = 1; 00000000002 = P.
    - boleto de 135,00 em 20/11/2026, agencia 1234, conta 0012345:
      barras 23797163600000135001234090000000000100123450,
      linha 23791.23405 90000.000001 01001.234507 7 16360000013500.
    - retorno: liquidacao de 136,50 (juros 1,50) baixa o titulo; OFX com 3
      linhas concilia 2 sozinho e a tarifa e' lancada pelo extrato.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 18/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBBCO()
    Local lOk := .T.
    Local aR := {}
    Local aL := {}
    Local cRet := ""
    Local cOfx := ""
    Local nRN := 0
    Local cBar := ""
    Local cNNs := ""
    Local aB := {}
    Local nI := 0

    // Calculos puros
    lOk := Chk(lOk, "mod10", GEBBCOMOD10("123") == "0" .And. GEBBCOMOD10("0019373700") == "4")
    lOk := Chk(lOk, "mod11", GEBBCOMOD11("123") == "6")
    lOk := Chk(lOk, "fator", GEBBCOFATOR("20250222") == "1000" .And. GEBBCOFATOR("20250221") == "9999" .And. GEBBCOFATOR("20261120") == "1636")
    lOk := Chk(lOk, "nndv", GEBBCONNDV("09", "00000000001") == "1" .And. GEBBCONNDV("09", "00000000002") == "P")

    If !GEBDBConecta()
        ConOut("T_GEBBCO FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebbco CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebbco")
    TCSqlExec("SET search_path TO test_gebbco")
    lOk := Chk(lOk, "mig", GENMIG() .And. GEBFMIG() .And. GEBFATMIG() .And. GEBBCOMIG())
    GEBFNCON("BANCO", "Banco")
    GEBFATCLI("C1", "Cliente Um", "123.456.789-01", "SP", 0, "", "")

    // Boleto
    lOk := Chk(lOk, "cfg banco invalido", !GEBBCOCFG("BANCO", "001", "1234", "5", "12345", "6", "09", "", "", "")[1])
    lOk := Chk(lOk, "cfg conta inexistente", !GEBBCOCFG("NADA", "237", "1234", "5", "12345", "6", "09", "", "", "")[1])
    lOk := Chk(lOk, "cfg", GEBBCOCFG("BANCO", "237", "1234", "5", "12345", "6", "09", "4567", "GEBAN LTDA", "12345678000199")[1])
    GEBFXTIT("R", "NFB1", "C1", 135, "0", "20261120", "TESTE", "")
    lOk := Chk(lOk, "boleto sem cobranca", !GEBBCOBOL("NFB1", "CAIXA")[1])
    lOk := Chk(lOk, "boleto titulo inexistente", !GEBBCOBOL("NADA", "BANCO")[1])
    aR := GEBBCOBOL("NFB1", "BANCO")
    lOk := Chk(lOk, "boleto barras", aR[1] .And. aR[3][2] == "23797163600000135001234090000000000100123450")
    lOk := Chk(lOk, "boleto linha", aR[1] .And. aR[3][1] == "23791.23405 90000.000001 01001.234507 7 16360000013500")
    lOk := Chk(lOk, "boleto nn", aR[1] .And. aR[3][3] == "09/00000000001-1")
    lOk := Chk(lOk, "boleto repetido", GEBBCOBOL("NFB1", "BANCO")[2] == "boleto ja gerado")
    aR := GEBBCOHTML("NFB1")
    lOk := Chk(lOk, "html", aR[1] .And. "23791.23405" $ aR[3] .And. "<span" $ aR[3])

    // Remessa CNAB 400
    aR := GEBBCOREM("BANCO", "")
    aL := StrTokArr(StrTran(Left(aR[3][3], Len(aR[3][3]) - 2), Chr(13), ""), Chr(10))
    lOk := Chk(lOk, "remessa", aR[1] .And. aR[3][2] == 1 .And. Len(aL) == 3)
    lOk := Chk(lOk, "remessa 400", Len(aL) == 3 .And. Len(aL[1]) == 400 .And. Len(aL[2]) == 400 .And. Len(aL[3]) == 400)
    lOk := Chk(lOk, "remessa header", Len(aL) == 3 .And. Left(aL[1], 26) == "01REMESSA01COBRANCA       " .And. SubStr(aL[1], 77, 3) == "237")
    lOk := Chk(lOk, "remessa detalhe", Len(aL) == 3 .And. SubStr(aL[2], 71, 12) == "000000000011" .And. SubStr(aL[2], 109, 2) == "01" .And. ;
        SubStr(aL[2], 121, 6) == "201126" .And. SubStr(aL[2], 127, 13) == "0000000013500" .And. SubStr(aL[2], 221, 14) == "00012345678901")
    lOk := Chk(lOk, "remessa sequencia", Len(aL) == 3 .And. Right(aL[3], 6) == "000003" .And. Left(aL[3], 1) == "9")
    lOk := Chk(lOk, "remessa vazia", !GEBBCOREM("BANCO", "")[1])

    // Retorno CNAB 400
    cRet := RetLin("00000000001", "02", "181026", 0, 0) + Chr(13) + Chr(10) + RetLin("00000000001", "06", "211126", 136.5, 1.5) + Chr(13) + Chr(10) + ;
        RetLin("00000009999", "06", "211126", 10, 0)
    aR := GEBBCORET("BANCO", cRet)
    lOk := Chk(lOk, "retorno", aR[1] .And. Len(aR[3]) == 3 .And. "sem baixa" $ aR[3][1][4] .And. "baixado 136.50" $ aR[3][2][4] .And. "desconhecido" $ aR[3][3][4])
    lOk := Chk(lOk, "titulo recebido", BOCOL(TCSqlQuery("SELECT GFN2_STATUS AS S FROM GFN2 WHERE GFN2_DOC = 'NFB1'")[1]:S) == "RECEBIDA")
    lOk := Chk(lOk, "retorno repetido", "ja liquidado" $ GEBBCORET("BANCO", cRet)[3][2][4])

    // OFX e conciliacao
    GEBFXMOV("BANCO", "D", 50, "Pagamento fornecedor", "20261121", "")
    cOfx := "OFXHEADER:100" + Chr(10) + "<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><BANKTRANLIST>" + Chr(10) + ;
        "<STMTTRN><TRNTYPE>CREDIT<DTPOSTED>20261122120000[-3:BRT]<TRNAMT>136.50<FITID>A1<MEMO>LIQ COBRANCA</STMTTRN>" + Chr(10) + ;
        "<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20261121<TRNAMT>-50.00<FITID>A2<MEMO>PIX ENVIADO</STMTTRN>" + Chr(10) + ;
        "<STMTTRN>" + Chr(10) + "<TRNTYPE>DEBIT" + Chr(10) + "<DTPOSTED>20261122" + Chr(10) + "<TRNAMT>-12,90" + Chr(10) + "<FITID>A3" + Chr(10) + "<MEMO>TARIFA" + Chr(10) + "</STMTTRN>" + Chr(10) + ;
        "</BANKTRANLIST></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>"
    aR := GEBBCOOFX("BANCO", cOfx)
    lOk := Chk(lOk, "ofx", aR[1] .And. aR[3][1] == 3 .And. aR[3][3] == 2)
    lOk := Chk(lOk, "ofx repetido", GEBBCOOFX("BANCO", cOfx)[3][2] == 3)
    lOk := Chk(lOk, "ofx invalido", !GEBBCOOFX("BANCO", "nada aqui")[1])
    aR := GEBBCOREL("BANCO", "20261101", "20261130")
    lOk := Chk(lOk, "rel pendente", aR[1] .And. Chave(aR[3][2], "pendente_banco") == -12.9 .And. Chave(aR[3][2], "pendente_sistema") == 0)
    lOk := Chk(lOk, "lanca tarifa", GEBBCOLANCA("BANCO", "A3", "4.02.006", "")[1])
    lOk := Chk(lOk, "lanca de novo", !GEBBCOLANCA("BANCO", "A3", "", "")[1])
    aR := GEBBCOREL("BANCO", "20261101", "20261130")
    lOk := Chk(lOk, "rel conciliado", aR[1] .And. Chave(aR[3][2], "pendente_banco") == 0 .And. Chave(aR[3][2], "pendente_sistema") == 0 .And. ;
        Chave(aR[3][2], "total_banco") == 73.6 .And. Chave(aR[3][2], "total_sistema") == 73.6)
    nRN := BOVAL(TCSqlQuery("SELECT R_E_C_N_O_ AS RN FROM GFX4 WHERE GFX4_CONTA = 'BANCO' AND GFX4_VALOR = 50")[1]:RN)
    lOk := Chk(lOk, "desfaz", GEBBCOCONCMAN("BANCO", "A2", 0)[1])
    lOk := Chk(lOk, "conc manual", GEBBCOCONCMAN("BANCO", "A2", nRN)[1])
    lOk := Chk(lOk, "conc manual repetida", !GEBBCOCONCMAN("BANCO", "A1", nRN)[1])

    // Campo livre dos demais bancos (exemplos dos manuais de Itau, Santander e Caixa;
    // BB e Sicoob conferidos com a biblioteca brcobranca).
    aL := GEBBCOLIVRE("341", "0057", "12345", "110", "", "", "12345678")
    cBar := GEBBCOBARRAS("341", "1667", 123.45, aL[1])
    lOk := Chk(lOk, "itau manual", cBar == "34196166700000123451101234567880057123457000" .And. ;
        GEBBCOLINHA(cBar) == "34191.10121 34567.880058 71234.570001 6 16670000012345" .And. aL[2] == "110/12345678-8")
    lOk := Chk(lOk, "itau carteira excecao", GEBBCOLIVRE("341", "0057", "12345", "126", "", "", "12345678")[3] == GEBBCOMOD10("12612345678"))
    aL := GEBBCOLIVRE("033", "", "", "101", "0282033", "", "566612457800")
    lOk := Chk(lOk, "santander manual", GEBBCOBARRAS("033", "2046", 273.71, aL[1]) == "03398204600000273719028203356661245780020101" .And. aL[3] == "2")
    aL := GEBBCOLIVRE("104", "", "", "", "005507", "", "222333777777777")
    lOk := Chk(lOk, "caixa manual", GEBBCOBARRAS("104", "3242", 321.12, aL[1]) == "10494324200000321120055077222133347777777771" .And. aL[2] == "14222333777777777")
    aL := GEBBCOLIVRE("001", "", "", "17", "1234567", "", "0000000001")
    lOk := Chk(lOk, "bb convenio 7", GEBBCOBARRAS("001", "1636", 100, aL[1]) == "00191163600000100000000001234567000000000117")
    aL := GEBBCOLIVRE("756", "4321", "", "1", "1234567", "01", "0000001")
    cBar := GEBBCOBARRAS("756", "1636", 100, aL[1])
    lOk := Chk(lOk, "sicoob", cBar == "75691163600000100001432101123456700000010001" .And. GEBBCOLINHA(cBar) == "75691.43212 01123.456707 00000.100016 1 16360000010000")

    // Cadastro de cobranca: validacoes
    GEBFNCON("BANCOST", "Santander")
    GEBFNCON("BANCOIT", "Itau")
    lOk := Chk(lOk, "cfg banco desconhecido", !GEBBCOCFG("BANCOST", "999", "1234", "", "1", "", "1", "1", "", "", "", "")[1])
    lOk := Chk(lOk, "cfg 400 santander", !GEBBCOCFG("BANCOST", "033", "1234", "", "13000123", "4", "101", "0282033", "", "", "400", "")[1])
    lOk := Chk(lOk, "cfg santander sem codigo", !GEBBCOCFG("BANCOST", "033", "1234", "", "13000123", "4", "101", "", "", "", "240", "")[1])
    lOk := Chk(lOk, "cfg santander", GEBBCOCFG("BANCOST", "033", "1234", "", "13000123", "4", "101", "0282033", "GEBAN LTDA", "12345678000199", "", "")[1])
    lOk := Chk(lOk, "cfg itau", GEBBCOCFG("BANCOIT", "341", "0057", "", "12345", "", "109", "", "GEBAN LTDA", "12345678000199", "", "")[1])

    // CNAB 240 FEBRABAN (Santander)
    GEBFXTIT("R", "NFS1", "C1", 135, "0", "20261120", "TESTE", "")
    aR := GEBBCOBOL("NFS1", "BANCOST")
    lOk := Chk(lOk, "boleto santander", aR[1] .And. Left(aR[3][2], 3) == "033" .And. SubStr(aR[3][2], 20, 8) == "90282033")
    cNNs := BOCOL(TCSqlQuery("SELECT GBC2_NN AS N FROM GBC2 WHERE GBC2_DOC = 'NFS1'")[1]:N) + BOCOL(TCSqlQuery("SELECT GBC2_NNDV AS D FROM GBC2 WHERE GBC2_DOC = 'NFS1'")[1]:D)
    aR := GEBBCOREM("BANCOST", "")
    aL := StrTokArr(StrTran(Left(aR[3][3], Len(aR[3][3]) - 2), Chr(13), ""), Chr(10))
    lOk := Chk(lOk, "rem240 registros", aR[1] .And. Len(aL) == 6 .And. Len(aL[1]) == 240 .And. Len(aL[2]) == 240 .And. Len(aL[3]) == 240 .And. ;
        Len(aL[4]) == 240 .And. Len(aL[5]) == 240 .And. Len(aL[6]) == 240)
    lOk := Chk(lOk, "rem240 header", Len(aL) == 6 .And. Left(aL[1], 8) == "03300000" .And. SubStr(aL[1], 19, 14) == "12345678000199" .And. SubStr(aL[1], 143, 1) == "1")
    lOk := Chk(lOk, "rem240 lote", Len(aL) == 6 .And. SubStr(aL[2], 8, 4) == "1R01")
    lOk := Chk(lOk, "rem240 P", Len(aL) == 6 .And. SubStr(aL[3], 14, 1) == "P" .And. AllTrim(SubStr(aL[3], 38, 20)) == cNNs .And. ;
        SubStr(aL[3], 78, 8) == "20112026" .And. SubStr(aL[3], 86, 15) == "000000000013500")
    lOk := Chk(lOk, "rem240 Q", Len(aL) == 6 .And. SubStr(aL[4], 14, 1) == "Q" .And. SubStr(aL[4], 19, 15) == "000012345678901")
    lOk := Chk(lOk, "rem240 trailers", Len(aL) == 6 .And. SubStr(aL[5], 18, 6) == "000004" .And. SubStr(aL[5], 24, 6) == "000001" .And. ;
        SubStr(aL[6], 18, 12) == "000001000006")
    cRet := Lin240("033", "T", "06", cNNs, 0, 0, "") + Chr(13) + Chr(10) + Lin240("033", "U", "06", "", 136.5, 1.5, "21112026") + Chr(13) + Chr(10)
    aR := GEBBCORET("BANCOST", cRet)
    lOk := Chk(lOk, "ret240", aR[1] .And. Len(aR[3]) == 1 .And. "baixado 136.50" $ aR[3][1][4])
    lOk := Chk(lOk, "ret240 titulo", BOCOL(TCSqlQuery("SELECT GFN2_STATUS AS S FROM GFN2 WHERE GFN2_DOC = 'NFS1'")[1]:S) == "RECEBIDA")

    // CNAB 240 nos demais bancos: boleto -> remessa -> retorno com o nosso numero da propria remessa -> baixa
    aB := {{"BCO001", "001", "1234", "123456", "7", "17", "1234567", ""}, {"BCO104", "104", "1234", "123456", "", "1", "005507", ""}, ;
        {"BCO237", "237", "1234", "1234567", "0", "09", "", ""}, {"BCO341", "341", "0057", "12345", "", "109", "", ""}, ;
        {"BCO756", "756", "4321", "123456", "", "1", "1234567", "01"}}
    For nI := 1 To Len(aB)
        GEBFNCON(aB[nI][1], "Banco " + aB[nI][2])
        lOk := Chk(lOk, "cfg240 " + aB[nI][2], GEBBCOCFG(aB[nI][1], aB[nI][2], aB[nI][3], "", aB[nI][4], aB[nI][5], aB[nI][6], aB[nI][7], ;
            "GEBAN LTDA", "12345678000199", "240", aB[nI][8])[1])
        GEBFXTIT("R", "N240" + aB[nI][2], "C1", 100, "0", "20261120", "TESTE", "")
        aR := GEBBCOBOL("N240" + aB[nI][2], aB[nI][1])
        lOk := Chk(lOk, "boleto240 " + aB[nI][2], aR[1] .And. Left(aR[3][2], 3) == aB[nI][2] .And. Len(aR[3][2]) == 44)
        aR := GEBBCOREM(aB[nI][1], "")
        aL := {}
        If aR[1]
            aL := StrTokArr(StrTran(Left(aR[3][3], Len(aR[3][3]) - 2), Chr(13), ""), Chr(10))
        EndIf
        lOk := Chk(lOk, "rem240 " + aB[nI][2], Len(aL) == 6 .And. Left(aL[1], 8) == aB[nI][2] + "00000" .And. SubStr(aL[3], 14, 1) == "P" .And. ;
            Len(aL[3]) == 240 .And. Len(aL[6]) == 240)
        If Len(aL) == 6
            cRet := Lin240(aB[nI][2], "T", "06", AllTrim(SubStr(aL[3], 38, 20)), 0, 0, "") + Chr(13) + Chr(10) + ;
                Lin240(aB[nI][2], "U", "06", "", 100, 0, "21112026") + Chr(13) + Chr(10)
            aR := GEBBCORET(aB[nI][1], cRet)
            lOk := Chk(lOk, "ret240 " + aB[nI][2], aR[1] .And. Len(aR[3]) == 1 .And. "baixado 100.00" $ aR[3][1][4])
        EndIf
    Next nI

    // CNAB 400 Itau
    GEBFXTIT("R", "NFI1", "C1", 100, "0", "20261120", "TESTE", "")
    GEBFXTIT("R", "NFI2", "C1", 50, "0", "20261120", "TESTE", "")
    aR := GEBBCOBOL("NFI1", "BANCOIT")
    lOk := Chk(lOk, "boleto itau", aR[1] .And. aR[3][3] == "109/00000001-" + GEBBCOMOD10("00571234510900000001"))
    GEBBCOBOL("NFI2", "BANCOIT")
    aR := GEBBCOREM("BANCOIT", "")
    aL := StrTokArr(StrTran(Left(aR[3][3], Len(aR[3][3]) - 2), Chr(13), ""), Chr(10))
    lOk := Chk(lOk, "rem400 itau", aR[1] .And. Len(aL) == 4 .And. Len(aL[1]) == 400 .And. Len(aL[2]) == 400 .And. Len(aL[4]) == 400)
    lOk := Chk(lOk, "rem400 itau header", Len(aL) == 4 .And. Left(aL[1], 26) == "01REMESSA01COBRANCA       " .And. SubStr(aL[1], 27, 11) == "00570012345" .And. SubStr(aL[1], 77, 3) == "341")
    lOk := Chk(lOk, "rem400 itau detalhe", Len(aL) == 4 .And. SubStr(aL[2], 63, 8) == "00000001" .And. SubStr(aL[2], 84, 3) == "109" .And. ;
        SubStr(aL[2], 109, 2) == "01" .And. SubStr(aL[2], 127, 13) == "0000000010000" .And. SubStr(aL[2], 140, 3) == "341")
    cRet := Lin400I("00000001", "06", "211126", 100, 0) + Chr(13) + Chr(10) + Lin400I("00000002", "15", "211126", 50, 0)
    aR := GEBBCORET("BANCOIT", cRet)
    lOk := Chk(lOk, "ret400 itau", aR[1] .And. Len(aR[3]) == 2 .And. "baixado 100.00" $ aR[3][1][4] .And. "sem baixa" $ aR[3][2][4])

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebbco CASCADE")
    If lOk
        ConOut("T_GEBBCO PASS")
    Else
        ConOut("T_GEBBCO FAIL")
    EndIf
Return lOk

// Segmento T ou U do retorno CNAB 240 (FEBRABAN 10.3).
Static Function Lin240(cBanco, cSeg, cMov, cNN, nPago, nJuros, cData8)
    Local cL := cBanco + "0001" + "3" + "00001" + cSeg + " " + cMov
    If cSeg == "T"
        cL := cL + Replicate("0", 20) + Left(cNN + Space(20), 20)
    Else
        cL := cL + StrZero(Round(nJuros * 100, 0), 15) + Replicate("0", 15) + Replicate("0", 15) + Replicate("0", 15) + StrZero(Round(nPago * 100, 0), 15)
        cL := cL + Replicate("0", 137 - Len(cL)) + cData8
    EndIf
Return cL + Space(240 - Len(cL))

// Detalhe do retorno CNAB 400 Itau: NN 63-70, ocorrencia 109-110, data 111-116, valor 254-266, juros 267-279.
Static Function Lin400I(cNN, cOc, cData6, nPago, nJuros)
    Local cL := "1" + Replicate("0", 61) + cNN
    cL := cL + Space(107 - Len(cL)) + "I" + cOc + cData6
    cL := cL + Replicate("0", 253 - Len(cL)) + StrZero(Round(nPago * 100, 0), 13) + StrZero(Round(nJuros * 100, 0), 13)
Return cL + Space(400 - Len(cL))

// Linha de detalhe do retorno CNAB 400 Bradesco (posicoes de GEBBCORET).
Static Function RetLin(cNN, cOc, cData6, nPago, nJuros)
    Local cL := "1" + Replicate("0", 69)
    cL := cL + cNN + "0" + Space(26) + cOc + cData6
    cL := cL + Replicate("0", 240 - Len(cL)) + Replicate("0", 13)
    cL := cL + StrZero(Round(nPago * 100, 0), 13) + StrZero(Round(nJuros * 100, 0), 13)
Return cL + Space(400 - Len(cL))

Static Function Chave(aP, cK)
    Local nI := 0
    For nI := 1 To Len(aP)
        If aP[nI][1] == cK
            Return aP[nI][2]
        EndIf
    Next nI
Return Nil

Static Function Chk(lOk, cNome, lCond)
    If !lCond
        ConOut("  FAIL: " + cNome)
        Return .F.
    EndIf
Return lOk
