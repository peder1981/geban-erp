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
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCOM_FOR.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBCTX.prw"
#include "../src/GEBEST.prw"
#include "../src/GEBFNX.prw"
#include "../src/GEBCPX.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
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
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBDFE_EFD
    EFD ICMS/IPI com banco: coleta das notas proprias (GDF5), inutilizacoes
    (GDF6) e entradas de terceiros (GDF8 + GCQ4 + GDFE + de-para GDFF);
    recusas (Simples, contabilista, contingencia pendente, codigo de
    receita), apuracao, arquivo guardado (GDFG) e saldo credor levado para
    a competencia seguinte.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 19/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBDFE_EFD()
    Local lOk := .T.
    Local aR := {}
    Local oC := Nil
    Local cX := ""
    Local cCh := ""
    Local cArq := ""

    If !GEBDBConecta()
        ConOut("T_GEBDFE_EFD FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdfeefd CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebdfeefd")
    TCSqlExec("SET search_path TO test_gebdfeefd")
    lOk := Chk(lOk, "mig", GENMIG() .And. GEBFMIG() .And. GEBCPXMIG() .And. GEBDFEDISTMIG() .And. GEBDFEEFDMIG())
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'P1', '08039000', 'Banana unidade')")
    lOk := Chk(lOk, "emitente simples", GEBDFEEMIT(Emit("1"))[1])
    lOk := Chk(lOk, "simples recusado", "regime_normal" $ GEBDFEEFD("202609", "0")[2])
    lOk := Chk(lOk, "emitente regime normal", GEBDFEEMIT(Emit("3"))[1])
    lOk := Chk(lOk, "sem contabilista", "contabilista_incompleto" $ GEBDFEEFD("202609", "0")[2])
    lOk := Chk(lOk, "competencia invalida", "competencia_invalida" $ GEBDFEEFD("202613", "0")[2])
    oC := JsonObject():New()
    oC["CONT_CPF"] := "111.444.777-36"
    lOk := Chk(lOk, "cpf do contabilista invalido", "cpf_do_contabilista" $ GEBDFECONFIG(oC)[2])
    oC["CONT_NOME"] := "Maria Contadora"
    oC["CONT_CPF"] := "111.444.777-35"
    oC["CONT_CRC"] := "1SP123456"
    oC["CONT_EMAIL"] := "contab@exemplo.com.br"
    oC["CONT_MUNICIPIO"] := "3550308"
    oC["EFD_PERFIL"] := "b"
    lOk := Chk(lOk, "configuracao da efd", GEBDFECONFIG(oC)[1] .And. BOPARM("DFE_EFD_CONT_CRC", "") == "1SP123456")

    // Notas proprias: autorizada, cancelada, rejeitada (fora) e inutilizadas 4-5.
    aR := GEBDFEMONTA(NFe(1, "11222333000181", "RJ", "3304557", 12, 1000))
    Grava(aR[3][2], 1, "AUTORIZADA", aR[3][1], "20260910")
    aR := GEBDFEMONTA(NFe(2, "11222333000181", "RJ", "3304557", 12, 50))
    Grava(aR[3][2], 2, "CANCELADA", aR[3][1], "20260911")
    aR := GEBDFEMONTA(NFe(3, "11222333000181", "RJ", "3304557", 12, 70))
    Grava(aR[3][2], 3, "REJEITADA", aR[3][1], "20260911")
    TCSqlExec("INSERT INTO GDF6 (D_E_L_E_T_, GDF6_FILIAL, GDF6_CHAVE, GDF6_TIPO, GDF6_SEQ, GDF6_CSTAT, GDF6_MOTIVO, GDF6_PROT, GDF6_DH, GDF6_JUST, " + ;
        "GDF6_XML, GDF6_MOD, GDF6_SERIE, GDF6_NINI, GDF6_NFIM) VALUES (' ', '      ', '', 'INUT', 1, '102', 'Homologado', '1', '2026-09-12T10:00:00-03:00', " + ;
        "'quebra de sequencia', '', '55', 1, 4, 5)")
    // Entrada de terceiro: 2 caixas de 12 (ICMS 18% de 600 = 108 de credito).
    oC := NFe(77, "11222333000181", "SP", "3550308", 18, 600)
    oC["EMIT"]["CNPJ"] := "11444777000161"
    oC["IDDEST"] := "1"
    oC["ITENS"][1]["CPROD"] := "FORN-CX"
    oC["ITENS"][1]["UCOM"] := "CX"
    oC["ITENS"][1]["QCOM"] := 2
    oC["ITENS"][1]["CFOP"] := "5102"
    aR := GEBDFEMONTA(oC)
    cCh := aR[3][2]
    TCSqlExec("INSERT INTO GDFE (D_E_L_E_T_, GDFE_FILIAL, GDFE_CHAVE, GDFE_NSU, GDFE_CNPJ, GDFE_NOME, GDFE_IE, GDFE_DHEMI, GDFE_VNF, GDFE_SIT, GDFE_MANIF, " + ;
        "GDFE_XML, GDFE_IMPORT) VALUES (' ', '      ', " + GEBDBQuote(cCh) + ", '1', '11444777000161', 'Fornecedor', '', '2026-09-14', 600, 'AUTORIZADA', " + ;
        "'CIENCIA', " + GEBDBQuote(aR[3][1]) + ", '77')")
    TCSqlExec("INSERT INTO GDF8 (D_E_L_E_T_, GDF8_FILIAL, GDF8_TIPO, GDF8_DOC, GDF8_PART, GDF8_CHAVE) VALUES (' ', '      ', 'ENT', '77', 'F77000161', " + ;
        GEBDBQuote(cCh) + ")")
    TCSqlExec("INSERT INTO GCQ4 (D_E_L_E_T_, GCQ4_FILIAL, GCQ4_NF, GCQ4_FORN, GCQ4_PED, GCQ4_DATA, GCQ4_VALMERC, GCQ4_FRETE, GCQ4_TOTAL) VALUES " + ;
        "(' ', '      ', '77', 'F77000161', 'PN1', '20260915', 600, 0, 600), (' ', '      ', '88', 'F77000161', 'PN2', '20260916', 10, 0, 10)")
    lOk := Chk(lOk, "sem de-para", "itens_sem_de_para" $ GEBDFEEFD("202609", "0")[2])
    TCSqlExec("INSERT INTO GDFF (D_E_L_E_T_, GDFF_FILIAL, GDFF_FORN, GDFF_CPROD, GDFF_PROD, GDFF_FATOR) VALUES (' ', '      ', 'F77000161', 'FORN-CX', 'P1', 12)")

    TCSqlExec("INSERT INTO GDF5 (D_E_L_E_T_, GDF5_FILIAL, GDF5_CHAVE, GDF5_MOD, GDF5_SERIE, GDF5_NNF, GDF5_TPEMIS, GDF5_TPAMB, GDF5_STATUS, GDF5_CSTAT, " + ;
        "GDF5_MOTIVO, GDF5_PROT, GDF5_DHEMI, GDF5_DHAUT, GDF5_ORIGEM, GDF5_DOC, GDF5_VNF, GDF5_XML, GDF5_QR, GDF5_URLCH, GDF5_DEST, GDF5_CHORIG, GDF5_DATA, " + ;
        "GDF5_XMLORIG) VALUES (' ', '      ', 'CONT1', '65', 1, 9, '9', '2', 'CONTINGENCIA', '', '', '', '', '', 'LOJA', '', 0, '', '', '', '', '', '20260920', '')")
    lOk := Chk(lOk, "contingencia pendente", "documentos_pendentes" $ GEBDFEEFD("202609", "0")[2])
    TCSqlExec("UPDATE GDF5 SET D_E_L_E_T_ = '*' WHERE GDF5_CHAVE = 'CONT1'")
    lOk := Chk(lOk, "sem codigo de receita", "codigo_de_receita" $ GEBDFEEFD("202609", "0")[2])
    BOSETPARM("DFE_EFD_COD_REC", "046-2")

    aR := GEBDFEEFD("202609", "0")
    lOk := Chk(lOk, "gerou", aR[1])
    ConOut("    " + aR[2])
    If aR[1]
        lOk := Chk(lOk, "apuracao 120 - 108", aR[4][1] == 120 .And. aR[4][2] == 108 .And. aR[4][3] == 12 .And. aR[4][4] == 0)
        lOk := Chk(lOk, "documentos (1 + cancelada + 2 inutilizadas + entrada)", aR[4][5] == 5)
        lOk := Chk(lOk, "aviso de entrada sem chave", "1_entrada(s)_sem_chave" $ aR[2])
    EndIf
    cArq := GEBDFEEFDLE("202609")
    lOk := Chk(lOk, "arquivo guardado", Left(cArq, 10) == "|0000|020|" .And. Right(cArq, 2) == Chr(13) + Chr(10))
    lOk := Chk(lOk, "perfil em maiuscula", "|SP|110042490114|3550308|||B|1|" $ cArq)
    lOk := Chk(lOk, "cancelada e inutilizadas", "|C100|1|0||55|02|1|2|" $ cArq .And. "|C100|1|0||55|05|1|4||" $ cArq .And. "|C100|1|0||55|05|1|5||" $ cArq)
    lOk := Chk(lOk, "rejeitada fora", !("|55|00|1|3|" $ cArq))
    lOk := Chk(lOk, "entrada com item do GEBAN", "|C170|1|P1|" $ cArq .And. "|0200|P1|Banana unidade|" $ cArq .And. "|0220|CX|12,000000||" $ cArq)
    lOk := Chk(lOk, "E116", "|E116|000|12,00|20102026|046-2|||||092026|" $ cArq)
    lOk := Chk(lOk, "nao gerada", GEBDFEEFDLE("202501") == "")

    // Saldo credor: 500 antes do 1o arquivo -> 488 levado para 10/2026.
    BOSETPARM("DFE_EFD_SLD_CRED_INI", "500")
    aR := GEBDFEEFD("202609", "1")
    lOk := Chk(lOk, "substituto com saldo credor", aR[1] .And. aR[4][3] == 0 .And. aR[4][4] == 488 .And. "|0000|020|1|" $ GEBDFEEFDLE("202609"))
    aR := GEBDFEEFD("202610", "0")
    lOk := Chk(lOk, "competencia seguinte", aR[1] .And. aR[4][4] == 488)
    lOk := Chk(lOk, "saldo anterior no E110", "|E110|0,00|0,00|0,00|0,00|0,00|0,00|0,00|0,00|488,00|0,00|0,00|0,00|488,00|0,00|" $ GEBDFEEFDLE("202610"))
Return Fim(lOk)

Static Function Grava(cCh, nNum, cSt, cXml, cData)
Return TCSqlExec("INSERT INTO GDF5 (D_E_L_E_T_, GDF5_FILIAL, GDF5_CHAVE, GDF5_MOD, GDF5_SERIE, GDF5_NNF, GDF5_TPEMIS, GDF5_TPAMB, GDF5_STATUS, " + ;
    "GDF5_CSTAT, GDF5_MOTIVO, GDF5_PROT, GDF5_DHEMI, GDF5_DHAUT, GDF5_ORIGEM, GDF5_DOC, GDF5_VNF, GDF5_XML, GDF5_QR, GDF5_URLCH, GDF5_DEST, " + ;
    "GDF5_CHORIG, GDF5_DATA, GDF5_XMLORIG) VALUES (' ', '      ', " + GEBDBQuote(cCh) + ", '55', 1, " + cValToChar(nNum) + ", '1', '2', " + ;
    GEBDBQuote(cSt) + ", '100', '', '1', '', '', 'FAT', '', 0, " + GEBDBQuote(cXml) + ", '', '', '', '', " + GEBDBQuote(cData) + ", '')")

Static Function Fim(lOk)
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdfeefd CASCADE")
    If lOk
        ConOut("T_GEBDFE_EFD PASS")
    Else
        ConOut("T_GEBDFE_EFD FAIL")
    EndIf
Return lOk

Static Function Emit(cCRT)
    Local o := JsonObject():New()
    o["CNPJ"] := "11222333000181"
    o["IE"] := "110042490114"
    o["RAZAO"] := "Mercado Apurador Ltda"
    o["CRT"] := cCRT
    o["LOGRADOURO"] := "Rua A"
    o["NUMERO"] := "1"
    o["BAIRRO"] := "Centro"
    o["UF"] := "SP"
    o["MUNICIPIO"] := "3550308"
    o["CEP"] := "01001000"
Return o

// NF-e de 1 item (2 unidades) a um destinatario contribuinte.
Static Function NFe(nNum, cCNPJ, cUF, cMun, nAliq, nPreco)
    Local oNF := JsonObject():New()
    Local oD := JsonObject():New()
    Local oI := JsonObject():New()
    Local oP := JsonObject():New()
    oD["CNPJ"] := cCNPJ
    oD["IE"] := "12345678"
    oD["XNOME"] := "Cliente"
    oD["XLGR"] := "Av Brasil"
    oD["NRO"] := "1"
    oD["XBAIRRO"] := "Jardim"
    oD["CMUN"] := cMun
    oD["XMUN"] := "CIDADE"
    oD["UF"] := cUF
    oD["CEP"] := "20000000"
    oD["INDIEDEST"] := "1"
    oI["CPROD"] := "P1"
    oI["XPROD"] := "Banana"
    oI["NCM"] := "08039000"
    oI["CFOP"] := "6102"
    oI["UCOM"] := "UN"
    oI["QCOM"] := 2
    oI["VUNCOM"] := nPreco / 2
    oI["ORIG"] := "0"
    oI["CST"] := "00"
    oI["PICMS"] := nAliq
    oI["PISCST"] := "07"
    oI["COFINSCST"] := "07"
    oP["TPAG"] := "01"
    oP["VPAG"] := nPreco
    oNF["MOD"] := "55"
    oNF["SERIE"] := 1
    oNF["NNF"] := nNum
    oNF["CNF"] := "12345678"
    oNF["TPEMIS"] := "1"
    oNF["DHEMI"] := "2026-09-10T10:00:00-03:00"
    oNF["TPAMB"] := "2"
    oNF["NATOP"] := "Venda"
    oNF["CMUNFG"] := "3550308"
    oNF["IDDEST"] := "2"
    oNF["INDFINAL"] := "0"
    oNF["INDPRES"] := "1"
    oNF["EMIT"] := GEBDFEEMITLE()
    oNF["DEST"] := oD
    oNF["ITENS"] := {oI}
    oNF["PAG"] := {oP}
Return oNF

Static Function Chk(lOk, cNome, lCond)
    If lCond
        ConOut("  OK " + cNome)
        Return lOk
    EndIf
    ConOut("  FAIL: " + cNome)
Return .F.
