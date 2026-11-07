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
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBDFE
    NFC-e real de ponta a ponta contra o emulador da SEFAZ
    (tests/emuladores/sefaz_emulador.py, HTTPS em 127.0.0.1:18766; a suite
    exporta ADVPP_HTTP_INSECURE porque o certificado do emulador e' proprio).
    Certificados de teste gerados com o openssl (e-CNPJ 12345678000195 e um
    de outro CNPJ). Cenario:
    - roteiro vazio => FALTA; emitente (CNPJ, IE de SP, municipio IBGE),
      certificado (senha errada, outro CNPJ, ok), configuracao e perfil.
    - venda autorizada (100) com CPF: protocolo, livro GF3, DANFE com QR;
      venda com desconto: vNF, vDesc e troco no XML.
    - NCM 99999999: SEFAZ rejeita (778) => venda nao gravada, estoque igual,
      numero "a inutilizar"; NCM local invalida: recusa sem gastar numero.
    - sem comunicacao => contingencia offline (QR assinado), cancelamento
      recusado ate transmitir; transmissao autoriza.
    - SEFAZ lenta (autorizou mas a resposta nao chegou) => contingencia com o
      mesmo numero => 539 na transmissao => adota a chave original.
    - cancelamento (135) e prazo vencido; inutilizacao dos pendentes (102) e
      faixa com numero usado (241); consulta (100/101); NFC-e desligada volta
      a emissao interna.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 19/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBDFE()
    Local lOk := .T.
    Local aR := {}
    Local aD := {}
    Local aServ := {"NfeAutorizacao", "NfeStatusServico", "NfeConsultaProtocolo", "RecepcaoEvento", "NfeInutilizacao"}
    Local o := Nil
    Local cDir := "/tmp/geban-tdfe-" + StrZero(Randomize(1, 999999), 6)
    Local cSes := ""
    Local cCh1 := ""
    Local cCup1 := ""
    Local cChC := ""
    Local cCupC := ""
    Local cChO := ""
    Local cCupL := ""
    Local cCupD := ""
    Local cChD := ""
    Local oC := Nil
    Local cX := ""
    Local nGLJ3 := 0
    Local nI := 0

    If !GEBDBConecta()
        ConOut("T_GEBDFE FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    If AllTrim(BOSTR(GetEnv("ADVPP_HTTP_INSECURE"))) == ""
        ConOut("  aviso: rode pela suite (o runner de testes), que sobe o emulador e exporta ADVPP_HTTP_INSECURE")
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdfe CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebdfe")
    TCSqlExec("SET search_path TO test_gebdfe")
    lOk := Chk(lOk, "mig", GENMIG() .And. TCSecMIG() .And. GEBFMIG() .And. GEBLOJMIG() .And. GEBDFECADMIG())
    GEBFNCON("BANCO", "Banco")
    TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'P1', '08039000', 'Banana prata'), " + ;
        "(' ', '      ', 'P2', '99999999', 'Produto NCM inexistente'), (' ', '      ', 'P3', '1234', 'Produto NCM curta')")
    TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', '08039000', 10, 5, '20200101', '20991231')")
    GEBFATPRC("", "P1", 10)
    GEBFATPRC("", "P2", 20)
    GEBFATPRC("", "P3", 5)
    GEBESTMOV("P1", "", "E", 100, 4, "COMPRA", "X", "20261001")
    GEBESTMOV("P2", "", "E", 50, 12, "COMPRA", "X", "20261001")
    GEBESTMOV("P3", "", "E", 10, 1, "COMPRA", "X", "20261001")
    BOSETPARM("DFE_CERT_DIR", cDir + "/cert")
    For nI := 1 To Len(aServ)
        BOSETPARM("DFE_URL_" + Upper(aServ[nI]), "https://127.0.0.1:18766/sefaz")
    Next nI
    BOSETPARM("DFE_TIMEOUT", "10")
    // Serie de NF-e propria deste teste (o emulador e' compartilhado com T_GEBDFE_NFE, mesmo CNPJ).
    BOSETPARM("DFE_SERIE_55", "7")

    // Certificados de teste (e-CNPJ do emitente e de outra empresa).
    ProcRun("mkdir", {"-p", cDir}, {|c| c})
    Openssl({"req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", cDir + "/k.pem", "-out", cDir + "/c.pem", "-days", "60", "-subj", ;
        "/C=BR/O=ICP-Brasil/CN=EMPRESA TESTE LTDA:12345678000195"})
    Openssl({"pkcs12", "-export", "-inkey", cDir + "/k.pem", "-in", cDir + "/c.pem", "-out", cDir + "/emp.pfx", "-passout", "pass:Senha123"})
    Openssl({"req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", cDir + "/k2.pem", "-out", cDir + "/c2.pem", "-days", "60", "-subj", ;
        "/C=BR/O=ICP-Brasil/CN=OUTRA EMPRESA SA:11222333000181"})
    Openssl({"pkcs12", "-export", "-inkey", cDir + "/k2.pem", "-in", cDir + "/c2.pem", "-out", cDir + "/outra.pfx", "-passout", "pass:Senha123"})

    // Roteiro sem nada.
    aR := GEBDFEROTEIRO(.F.)
    lOk := Chk(lOk, "roteiro vazio", !aR[1] .And. Item(aR[2], "1.") == "FALTA" .And. Item(aR[2], "2.") == "FALTA")
    lOk := Chk(lOk, "venda sem emitente", !GEBDFENFCE("X", {{"P1", 1, 10, 0}}, {{"01", 10}}, "")[1])

    // Emitente.
    o := Emit()
    o["CNPJ"] := "12345678000194"
    lOk := Chk(lOk, "cnpj invalido", !GEBDFEEMIT(o)[1])
    o := Emit()
    o["IE"] := "110042490115"
    lOk := Chk(lOk, "ie invalida", "inscricao_estadual" $ GEBDFEEMIT(o)[2])
    o := Emit()
    o["MUNICIPIO"] := "3304557"
    lOk := Chk(lOk, "municipio de outra uf", "municipio" $ GEBDFEEMIT(o)[2])
    aR := GEBDFEEMIT(Emit())
    lOk := Chk(lOk, "emitente", aR[1] .And. GEBDFEEMITLE()["XMUN"] == "SAO PAULO" .And. GEBDFEEMITLE()["CNPJ"] == "12345678000195")
    lOk := Chk(lOk, "busca municipio", Len(GEBDFEMUNBUSCA("campinas", "SP")) >= 1 .And. GEBDFEMUNNOME("3509502") == "CAMPINAS")

    // Certificado.
    lOk := Chk(lOk, "certificado senha errada", "senha" $ GEBDFECERT(Encode64(MemoRead(cDir + "/emp.pfx")), "errada")[2])
    lOk := Chk(lOk, "certificado de outro cnpj", "outro_cnpj" $ GEBDFECERT(Encode64(MemoRead(cDir + "/outra.pfx")), "Senha123")[2])
    aR := GEBDFECERT(Encode64(MemoRead(cDir + "/emp.pfx")), "Senha123")
    lOk := Chk(lOk, "certificado instalado", aR[1] .And. GEBDFECERTLE()[2] == "12345678000195" .And. File(GEBDFECERTLE()[5]) .And. ;
        GEBDFECERTLE()[1] == "EMPRESA TESTE LTDA")
    If !aR[1]
        ConOut("    " + aR[2])
    EndIf

    // Configuracao e perfil fiscal.
    o := JsonObject():New()
    o["AMBIENTE"] := "3"
    lOk := Chk(lOk, "ambiente invalido", !GEBDFECONFIG(o)[1])
    o := JsonObject():New()
    o["AMBIENTE"] := "2"
    o["NFCE"] := "s"
    o["SERIE_NFCE"] := "1"
    o["MENSAGEM"] := "Volte sempre"
    lOk := Chk(lOk, "configuracao", GEBDFECONFIG(o)[1] .And. BOPARM("DFE_NFCE", "") == "S")
    o := JsonObject():New()
    o["PRODUTO"] := "P1"
    o["CSOSN"] := "201"
    lOk := Chk(lOk, "csosn com ST recusado", !GEBDFEPRODFIS(o)[1])
    o["CSOSN"] := "102"
    o["GTIN"] := "7891234567895"
    o["CFOP"] := "5102"
    lOk := Chk(lOk, "perfil fiscal", GEBDFEPRODFIS(o)[1])
    o["PRODUTO"] := "PX"
    lOk := Chk(lOk, "perfil de produto inexistente", !GEBDFEPRODFIS(o)[1])

    // Status, roteiro com teste (P3 sem NCM de 8 digitos ainda falta).
    aR := GEBDFESTATSVC("65")
    lOk := Chk(lOk, "status sefaz 107", aR[1] .And. "107" $ aR[2])
    If !aR[1]
        ConOut("    " + aR[2])
    EndIf
    aR := GEBDFEROTEIRO(.T.)
    lOk := Chk(lOk, "roteiro falta ncm", !aR[1] .And. Item(aR[2], "7.") == "FALTA" .And. Item(aR[2], "12.") == "OK")

    // Tabela IBPT (Lei 12.741): 08039000 com 4,2% federal nacional e 18% estadual.
    lOk := Chk(lOk, "ibpt arquivo errado", !GEBDFEIBPTIMP("qualquer coisa" + Chr(10) + "1;2", "SP")[1])
    aR := GEBDFEIBPTIMP("codigo;ex;tipo;descricao;nacionalfederal;importadosfederal;estadual;municipal;vigenciainicio;vigenciafim;chave;versao;fonte" + ;
        Chr(13) + Chr(10) + "08039000;;0;Bananas frescas;4.20;6.50;18.00;0.00;01/10/2026;31/12/2026;ABC123;26.2.A;IBPT/empresometro.com.br" + Chr(10) + ;
        "01012100;;0;Cavalos;4.20;6.50;18.00;0.00;01/10/2026;31/12/2026;ABC123;26.2.A;IBPT" + Chr(10) + "0101;;1;Servico;1;1;1;1;01/10/2026;31/12/2026;X;26.2.A;IBPT", "SP")
    lOk := Chk(lOk, "ibpt importado", aR[1] .And. aR[3] == 2)

    // Caixa e venda autorizada (CPF na nota).
    GEBLOJCX("01", "Caixa 1", "", "")
    cSes := GEBLOJABRE("01", "maria", 100, BOHOJE())[3]
    aR := GEBLOJVEN(cSes, {{"P1", 2}}, {{"DINHEIRO", 50}}, "", 0, "", "529.982.247-25")
    lOk := Chk(lOk, "venda autorizada", aR[1] .And. Len(aR[3]) >= 5 .And. aR[3][5] == "AUTORIZADA" .And. Len(aR[3][4]) == 44)
    If !aR[1]
        ConOut("    " + aR[2])
        Return Fim(.F., cDir)
    EndIf
    cCup1 := aR[3][1]
    cCh1 := aR[3][4]
    aD := GEBDFEDOC(cCh1)
    lOk := Chk(lOk, "documento autorizado", aD[1] == "AUTORIZADA" .And. Len(aD[2]) == 15 .And. "<nfeProc" $ aD[3] .And. "<protNFe" $ aD[3] .And. ;
        "?p=" + cCh1 + "|3|2" $ aD[12])
    lOk := Chk(lOk, "livro gf3 autorizada", BOCOL(TCSqlQuery("SELECT GF3_STATUS AS S FROM GF3 WHERE GF3_CHAVE = " + GEBDBQuote(cCh1))[1]:S) == "AUTORIZADA")
    lOk := Chk(lOk, "cupom aponta a chave", BOCOL(TCSqlQuery("SELECT GLJ3_NOTA AS N FROM GLJ3 WHERE GLJ3_CUPOM = " + GEBDBQuote(cCup1))[1]:N) == cCh1)
    aR := GEBDFEDANFE(cCh1)
    lOk := Chk(lOk, "danfe html", aR[1] .And. "<svg" $ aR[3] .And. "HOMOLOGACAO" $ aR[3] .And. "529.982.247-25" $ aR[3] .And. "Protocolo" $ aR[3])
    aR := GEBLOJCUPOM(cCup1)
    lOk := Chk(lOk, "segunda via com nfc-e", aR[1])
    cX := aD[3]
    lOk := Chk(lOk, "xml cpf e gtin", "<CPF>52998224725</CPF>" $ cX .And. "<cEAN>7891234567895</cEAN>" $ cX .And. "<infCpl>Documento " + cCup1 + " Volte sempre. Trib aprox R$ 0,84 Federal, R$ 3,60 Estadual, R$ 0,00 Municipal. Fonte: IBPT 26.2.A</infCpl>" $ cX .And. ;
        "<vTotTrib>4.44</vTotTrib>" $ cX)

    // Venda com desconto: vNF 29,00, vDesc 1,00, troco 1,00.
    aR := GEBLOJVEN(cSes, {{"P1", 3}}, {{"DINHEIRO", 30}}, "", 1)
    lOk := Chk(lOk, "venda com desconto", aR[1] .And. aR[3][5] == "AUTORIZADA")
    If aR[1]
        cCupD := aR[3][1]
        cChD := aR[3][4]
        cX := GEBDFEDOC(aR[3][4])[3]
        lOk := Chk(lOk, "totais no xml", "<vNF>29.00</vNF>" $ cX .And. "<vDesc>1.00</vDesc>" $ cX .And. "<vTroco>1.00</vTroco>" $ cX .And. ;
            "<vProd>30.00</vProd>" $ cX)
    EndIf

    // SEFAZ rejeita (NCM 99999999): venda nao gravada, estoque igual, numero a inutilizar.
    nGLJ3 := BOVAL(TCSqlQuery("SELECT COUNT(*) AS N FROM GLJ3")[1]:N)
    aR := GEBLOJVEN(cSes, {{"P2", 1}}, {{"DINHEIRO", 20}}, "", 0)
    lOk := Chk(lOk, "rejeicao da sefaz", !aR[1] .And. "778" $ aR[2])
    lOk := Chk(lOk, "venda rejeitada nao gravada", BOVAL(TCSqlQuery("SELECT COUNT(*) AS N FROM GLJ3")[1]:N) == nGLJ3 .And. GEBESTSLD("P2", "01")[1] == 50)
    lOk := Chk(lOk, "numero a inutilizar", Len(GEBDFEPENDINUT()) == 1)
    // NCM local invalida: recusa antes da SEFAZ e sem gastar numero.
    aR := GEBLOJVEN(cSes, {{"P3", 1}}, {{"DINHEIRO", 5}}, "", 0)
    lOk := Chk(lOk, "ncm local invalida", !aR[1] .And. "ncm_invalida" $ aR[2] .And. Len(GEBDFEPENDINUT()) == 1)

    // Sem comunicacao => contingencia offline.
    BOSETPARM("DFE_URL_NFEAUTORIZACAO", "https://127.0.0.1:1/sefaz")
    aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"PIX", 10}}, "", 0)
    lOk := Chk(lOk, "venda em contingencia", aR[1] .And. aR[3][5] == "CONTINGENCIA")
    If !aR[1]
        ConOut("    " + aR[2])
    EndIf
    If aR[1]
        cCupC := aR[3][1]
        cChC := aR[3][4]
        aD := GEBDFEDOC(cChC)
        lOk := Chk(lOk, "contingencia tpEmis 9 e qr assinado", SubStr(cChC, 35, 1) == "9" .And. "<tpEmis>9</tpEmis>" $ aD[3] .And. ;
            Len(StrTokArr(SubStr(aD[12], At("?p=", aD[12]) + 3), "|")) == 8)
        lOk := Chk(lOk, "livro gf3 contingencia", BOCOL(TCSqlQuery("SELECT GF3_STATUS AS S FROM GF3 WHERE GF3_CHAVE = " + GEBDBQuote(cChC))[1]:S) == "CONTINGENCIA")
        lOk := Chk(lOk, "danfe contingencia", "CONTINGENCIA" $ GEBDFEDANFE(cChC)[3])
        lOk := Chk(lOk, "cancelar contingencia recusado", "contingencia" $ GEBLOJCAN(cCupC, "Cliente desistiu da compra")[2])
        lOk := Chk(lOk, "roteiro mostra contingencia", Item(GEBDFEROTEIRO(.F.)[2], "9.") == "ATENCAO")
    EndIf
    BOSETPARM("DFE_URL_NFEAUTORIZACAO", "https://127.0.0.1:18766/sefaz")
    aR := GEBDFETRANSMITE()
    lOk := Chk(lOk, "transmite contingencia", aR[1] .And. aR[3][1] == 1)
    lOk := Chk(lOk, "contingencia autorizada", GEBDFEDOC(cChC)[1] == "AUTORIZADA" .And. ;
        BOCOL(TCSqlQuery("SELECT GF3_STATUS AS S FROM GF3 WHERE GF3_CHAVE = " + GEBDBQuote(cChC))[1]:S) == "AUTORIZADA")

    // SEFAZ lenta: autoriza mas a resposta nao chega => contingencia => 539 => adota a original.
    BOSETPARM("DFE_INFCPL", "DEMORA")
    BOSETPARM("DFE_TIMEOUT", "2")
    aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 0)
    lOk := Chk(lOk, "venda com sefaz lenta vira contingencia", aR[1] .And. aR[3][5] == "CONTINGENCIA")
    BOSETPARM("DFE_INFCPL", "Volte sempre")
    BOSETPARM("DFE_TIMEOUT", "10")
    If aR[1]
        cCupL := aR[3][1]
        cChO := GEBDFEDOC(aR[3][4])[10]
        aD := GEBDFETRANSMITE()
        lOk := Chk(lOk, "539 adota a chave original", aD[1] .And. aD[3][1] == 1 .And. GEBDFEDOC(aR[3][4])[1] == "SUBSTITUIDA" .And. ;
            GEBDFEDOC(cChO)[1] == "AUTORIZADA")
        lOk := Chk(lOk, "livro e cupom com a chave original", BOCOL(TCSqlQuery("SELECT GLJ3_NOTA AS N FROM GLJ3 WHERE GLJ3_CUPOM = " + ;
            GEBDBQuote(cCupL))[1]:N) == cChO .And. BOCOL(TCSqlQuery("SELECT GF3_STATUS AS S FROM GF3 WHERE GF3_CHAVE = " + GEBDBQuote(cChO))[1]:S) == "AUTORIZADA")
    EndIf

    // Cancelamento: prazo vencido e cancelamento valido pelo caixa.
    BOSETPARM("DFE_CANC_MIN", "-1")
    lOk := Chk(lOk, "cancelamento fora do prazo", "prazo" $ GEBDFECANCELA(cCh1, "Cliente desistiu da compra")[2])
    BOSETPARM("DFE_CANC_MIN", "30")
    aR := GEBLOJCAN(cCup1, "Cliente desistiu da compra no caixa")
    lOk := Chk(lOk, "cancelamento", aR[1] .And. "NFC-e cancelada" $ aR[2] .And. GEBDFEDOC(cCh1)[1] == "CANCELADA")
    If !aR[1]
        ConOut("    " + aR[2])
    EndIf
    lOk := Chk(lOk, "evento gravado", BOCOL(TCSqlQuery("SELECT GDF6_CSTAT AS C FROM GDF6 WHERE GDF6_CHAVE = " + GEBDBQuote(cCh1) + " AND GDF6_TIPO = 'CANC'")[1]:C) == "135")
    lOk := Chk(lOk, "consulta cancelada 101", Left(GEBDFECONSULTAR(cCh1, .T.)[2], 3) == "101")
    lOk := Chk(lOk, "consulta autorizada 100", Left(GEBDFECONSULTAR(cChC, .T.)[2], 3) == "100")

    // Devolucao de cupom com NFC-e: NF-e de entrada (finalidade 4) referenciando a NFC-e.
    aR := GEBLOJDEV(cSes, cCupD, {{"P1", 1}}, "VALE", "Defeito")
    lOk := Chk(lOk, "devolucao nfce sem consumidor", !aR[1] .And. "devolucao_de_nfce" $ aR[2])
    oC := JsonObject():New()
    oC["DOC"] := "111.444.777-35"
    oC["NOME"] := "Consumidor da Loja"
    oC["LOGRADOURO"] := "Rua B"
    oC["NUMERO"] := "5"
    oC["BAIRRO"] := "Centro"
    oC["UF"] := "SP"
    oC["MUNICIPIO"] := "3550308"
    oC["CEP"] := "01001000"
    aR := GEBLOJDEV(cSes, cCupD, {{"P1", 1}}, "VALE", "Defeito", oC)
    lOk := Chk(lOk, "devolucao nfce com nf-e de entrada", aR[1] .And. Len(aR[3]) >= 5 .And. Len(aR[3][5]) == 44)
    If !aR[1]
        ConOut("    " + aR[2])
    Else
        cX := GEBDFEDOC(aR[3][5])[3]
        lOk := Chk(lOk, "xml devolucao nfce", "<refNFe>" + cChD + "</refNFe>" $ cX .And. "<tpNF>0</tpNF>" $ cX .And. "<finNFe>4</finNFe>" $ cX .And. ;
            "<CPF>11144477735</CPF>" $ cX .And. "<mod>55</mod>" $ cX)
    EndIf
    oC := JsonObject():New()
    oC["DOC"] := "11144477735"
    aR := GEBLOJDEV(cSes, cCupD, {{"P1", 1}}, "VALE", "Defeito", oC)
    lOk := Chk(lOk, "segunda devolucao com consumidor ja cadastrado", aR[1])

    // Inutilizacao: faixa com numero usado (241) e os pendentes (102).
    lOk := Chk(lOk, "inutilizar numero usado", "241" $ GEBDFEINUTILIZA("65", 1, 1, 1, "Teste de faixa com numero usado")[2])
    aR := GEBDFEINUTPEND("Numero rejeitado pela SEFAZ e nao utilizado")
    lOk := Chk(lOk, "inutiliza pendentes", aR[1] .And. aR[3] == 1 .And. Len(GEBDFEPENDINUT()) == 0)
    lOk := Chk(lOk, "relatorio de documentos", GEBDFEDOCS(BODTADD(BOHOJE(), -1), BODTADD(BOHOJE(), 1), "")[3] >= 6)

    // NFC-e desligada: volta a emissao interna.
    BOSETPARM("DFE_NFCE", "N")
    aR := GEBLOJVEN(cSes, {{"P1", 1}}, {{"DINHEIRO", 10}}, "", 0)
    lOk := Chk(lOk, "nfce desligada", aR[1] .And. aR[3][5] == "" .And. Left(aR[3][4], 3) == "NFC")

    Return Fim(lOk, cDir)

Static Function Fim(lOk, cDir)
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdfe CASCADE")
    ProcRun("rm", {"-rf", cDir}, {|c| c})
    If lOk
        ConOut("T_GEBDFE PASS")
    Else
        ConOut("T_GEBDFE FAIL")
    EndIf
Return lOk

Static Function Openssl(aArgs)
    Local aOut := {}
Return ProcRun("openssl", aArgs, {|c| aAdd(aOut, c)}, {|c| aAdd(aOut, c)})

// Situacao do item do roteiro que comeca com cPrefixo ("" se nao houver).
Static Function Item(aL, cPrefixo)
    Local nP := AScan(aL, {|x| Left(x[1], Len(cPrefixo)) == cPrefixo})
    If nP == 0
        Return ""
    EndIf
Return aL[nP][2]

Static Function Emit()
    Local o := JsonObject():New()
    o["CNPJ"] := "12.345.678/0001-95"
    o["IE"] := "110.042.490.114"
    o["RAZAO"] := "Empresa Teste Ltda"
    o["FANTASIA"] := "Loja Teste"
    o["CRT"] := "1"
    o["LOGRADOURO"] := "Rua das Bananeiras"
    o["NUMERO"] := "100"
    o["BAIRRO"] := "Centro"
    o["UF"] := "SP"
    o["MUNICIPIO"] := "3550308"
    o["CEP"] := "01001-000"
    o["FONE"] := "(11) 3333-4444"
Return o

Static Function Chk(lOk, cNome, lCond)
    If lCond
        ConOut("  OK " + cNome)
        Return lOk
    EndIf
    ConOut("  FAIL: " + cNome)
Return .F.
