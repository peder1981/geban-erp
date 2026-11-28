#include "totvs.ch"
#include "../../src/GEBDB_CORE.prw"
#include "../../src/GEBDB_TENANT.prw"
#include "../../src/GEBPERIF_MIG.prw"
#include "../../src/GENUC_MIG.prw"
#include "../../src/GENUC_MNT.prw"
#include "../../src/GEBEXP_MIG.prw"
#include "../../src/GEBSEC_MIG.prw"
#include "../../src/GEBAUD.prw"
#include "../../src/GEBFIS_MIG.prw"
#include "../../src/GEBFIN_MIG.prw"
#include "../../src/GEBCTB_MIG.prw"
#include "../../src/GEBV_MIG.prw"
#include "../../src/GEBV_EST.prw"
#include "../../src/GEBBOLIB.prw"
#include "../../src/GEBCTX.prw"
#include "../../src/GEBEST.prw"
#include "../../src/GEBFNX.prw"
#include "../../src/GEBFAT.prw"
#include "../../src/GEBTEF.prw"
#include "../../src/GEBLOJ.prw"
#include "../../src/GEBLOJ_CAD.prw"
#include "../../src/GEBLOJ_OPE.prw"
#include "../../src/GEBSEC_POL.prw"
#include "../../src/GEBSEC_LOGIN.prw"
#include "../../src/GEBSEC_RBA.prw"
#include "../../src/GEBFIS_CAD.prw"
#include "../../src/GEBFIS_EMI.prw"
#include "../../src/GEBFIS_APU.prw"
#include "../../src/GEBFIN_CON.prw"
#include "../../src/GEBFIN_BAI.prw"
#include "../../src/GEBDER_MIG.prw"
#include "../../src/GEBDER_GUI.prw"
#include "../../src/GEBDER_BAI.prw"
#include "../../src/GEBDER_COB.prw"
#include "../../src/GEBCOM_MIG.prw"
#include "../../src/GEBCPX.prw"
#include "../../src/GEBDFE.prw"
#include "../../src/GEBDFE_NFE.prw"
#include "../../src/GEBRET.prw"
#include "../../src/GEBSN.prw"
#include "../../src/GEBCRY.prw"
#include "../../src/GESSAR.prw"
#include "../../src/GEBFIL_MIG.prw"
#include "../../src/GEBUNI_MIG.prw"
#include "../../src/GEBCOM_FOR.prw"
#include "../../src/GEBBCO.prw"
#include "../../src/GEBDFE_CAD.prw"
#include "../../src/GEBDFE_DIST.prw"
#include "../../src/GEBDFE_EFD.prw"
#include "../../src/GEBDFE_NFSE.prw"
#include "../../src/GEBDER_FIN.prw"
#include "../../src/GEBSCH.prw"

/*/{Protheus.doc} SEED_FULL
    Carga persistente da demonstracao, exclusivamente geban_test/emp_99.
    Nao executa testes de massa, cleanup ou movimentos operacionais.
    Restricao do demo: os blocos SN/CTB/DER e EFD trabalham na competencia
    corrente (AAAAMM de hoje). Reexecutar o seed em outro mes abre uma
    competencia nova e exige ajuste/novo seed — e' intencionalmente
    "same-month".
    @type Seed de demonstracao
    @author Peder Munksgaard
    @since 2026-10-03
    @return .T. se migracoes, cadastros e verificacoes passarem
/*/
User Function SEED_FULL()
    Local lOk := .T.
    If GetEnv("GEBAN_PG_DB") != "geban_test"
        ConOut("SEED_FULL FAIL (use GEBAN_PG_DB=geban_test)")
        Return .F.
    EndIf
    If !GEBDBConecta()
        ConOut("SEED_FULL FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    // Provisiona o destino antes do search_path: schema ausente cairia em public.
    If !GEBDBProvisionaCatalogo()
        ConOut("SEED_FULL FAIL (catalogo)")
        Return .F.
    EndIf
    If !GEBDBProvisionaEmpresa("99", "Empresa Demo Completa")
        ConOut("SEED_FULL FAIL (empresa 99)")
        Return .F.
    EndIf
    If !GEBDBSetTenant("99")
        ConOut("SEED_FULL FAIL (tenant 99)")
        Return .F.
    EndIf
    lOk := SF_MIG()
    If !lOk
        ConOut("SEED_FULL FAIL (migracoes)")
        Return .F.
    EndIf
    lOk := SF_PAR() .And. lOk
    lOk := SF_NUC() .And. lOk
    lOk := SF_CAD() .And. lOk
    lOk := SF_FIS() .And. lOk
    lOk := SF_FIN() .And. lOk
    lOk := SF_COM() .And. lOk
    lOk := SF_LOJ() .And. lOk
    lOk := SF_PDV() .And. lOk
    lOk := SF_SN() .And. lOk
    lOk := SF_DER() .And. lOk
    lOk := SF_CTB() .And. lOk
    ConOut("SEED_FULL " + IIf(lOk, "PASS", "FAIL"))
Return lOk

Static Function SF_MIG()
    Local lOk := .T.
    lOk := GENMIG() .And. lOk
    lOk := GEBFMIG() .And. lOk
    lOk := GEBFNMIG() .And. lOk
    lOk := GEBCMIG() .And. lOk
    lOk := GEBDMIG() .And. lOk
    lOk := GEBVMIG() .And. lOk
    lOk := GEBCMMIG() .And. lOk
    lOk := GEBPERIFMIG() .And. lOk
    lOk := GEFFILMIG() .And. lOk
    lOk := GEUNIMIG() .And. lOk
    lOk := BOMIG() .And. lOk
    lOk := GEBCTXMIG() .And. lOk
    lOk := GEBESTMIG() .And. lOk
    lOk := GEBFXMIG() .And. lOk
    lOk := GEBFATMIG() .And. lOk
    lOk := GEBTEFMIG() .And. lOk
    lOk := GEBLOJMIG() .And. lOk
    lOk := GEBLOJCADMIG() .And. lOk
    lOk := GEBCPXMIG() .And. lOk
    lOk := GEBBCOMIG() .And. lOk
    lOk := GEBDFECADMIG() .And. lOk
    lOk := GEBDFENFEMIG() .And. lOk
    lOk := GEBDFEDISTMIG() .And. lOk
    lOk := GEBDFEEFDMIG() .And. lOk
    lOk := GEBDFENFSEMIG() .And. lOk
    lOk := GEBDERFMIG() .And. lOk
    lOk := GEBRETMIG() .And. lOk
    lOk := GEBSNMIG() .And. lOk
    lOk := GEBCRYMIG() .And. lOk
    lOk := GESSARMIG() .And. lOk
    lOk := GEBSCHMIG() .And. lOk
Return lOk

Static Function SF_PAR()
    Local lOk := .T.
    Local nI := 0
    Local aServ := {"NFEAUTORIZACAO", "NFERETAUTORIZACAO", "NFESTATUSSERVICO", "NFECONSULTAPROTOCOLO", ;
        "RECEPCAOEVENTO", "NFEINUTILIZACAO", "NFEDISTRIBUICAODFE"}
    // FIN_BANCO_URL fica reservado para a integracao bancaria do demo.
    // GEBBCO atual usa arquivos CNAB/OFX; nao le URL de banco.
    lOk := SF_SET("FIN_BANCO_URL", "http://127.0.0.1:18767") .And. lOk
    // O emulador :18765 fala Cielo e-Commerce, nao o protocolo HTTP generico.
    lOk := SF_SET("LOJ_TEF_PROVEDOR", "CIELO") .And. lOk
    lOk := SF_SET("LOJ_CIELO_URL", "http://127.0.0.1:18765") .And. lOk
    lOk := SF_SET("LOJ_CIELO_MERCHANTID", "demo-local") .And. lOk
    lOk := SF_SET("LOJ_CIELO_MERCHANTKEY", "demo-local") .And. lOk
    lOk := SF_SET("LOJ_CIELO_CARTAO", "4024007153763191") .And. lOk
    lOk := SF_SET("LOJ_CIELO_BANDEIRA", "Visa") .And. lOk
    lOk := SF_SET("DFE_AMBIENTE", "2") .And. lOk
    For nI := 1 To Len(aServ)
        lOk := SF_SET("DFE_URL_" + aServ[nI], "https://127.0.0.1:18766/sefaz") .And. lOk
    Next
    lOk := SF_SET("DFE_URL_SEFIN", "https://127.0.0.1:18766/SefinNacional") .And. lOk
    lOk := SF_SET("DFE_URL_ADN", "https://127.0.0.1:18766") .And. lOk
    lOk := SF_SET("DFE_URL_NFECONSULTAQR", "https://127.0.0.1:18766/qrcode") .And. lOk
    lOk := SF_SET("DFE_URL_URLCHAVE", "https://127.0.0.1:18766/consulta") .And. lOk
Return lOk

Static Function SF_NUC()
    Local lOk := .T.
    Local nI := 0
    Local cCod := ""
    Local aFil := {{"990101", "DEM Matriz"}, {"990102", "DEM Loja Centro"}, {"990103", "DEM Deposito"}}
    Local aUsu := {{"DEM_ADMIN", "Administrador Demo", "ADMIN", ""}, ;
        {"DEM_GESTOR", "Gestor Demo", "DEM_GESTOR", "990101"}, ;
        {"DEM_CAIXA1", "Caixa Centro", "DEM_CAIXA", "990102"}, ;
        {"DEM_CAIXA2", "Caixa Matriz", "DEM_CAIXA", "990101"}, ;
        {"DEM_FISCAL", "Analista Fiscal", "DEM_FISCAL", "990101"}, ;
        {"DEM_FIN", "Analista Financeiro", "DEM_FIN", "990101"}, ;
        {"DEM_COMPRAS", "Comprador Demo", "DEM_COMPRAS", "990103"}, ;
        {"DEM_CTB", "Contador Demo", "DEM_CTB", ""}}
    Local aPerm := {{"DEM_GESTOR", "NUCLEO", "1"}, {"DEM_CAIXA", "LOJA", "1"}, ;
        {"DEM_FISCAL", "FISCAL", "1"}, {"DEM_FIN", "FINANCEIRO", "1"}, ;
        {"DEM_COMPRAS", "COMPRAS", "1"}, {"DEM_CTB", "CONTABIL", "1"}}
    For nI := 1 To Len(aFil)
        cCod := aFil[nI][1]
        lOk := TCSqlExec("INSERT INTO GEF1 (D_E_L_E_T_, GEF1_FILIAL, GEF1_COD, GEF1_NOME, GEF1_UNI) " + ;
            "SELECT ' ', " + GEBDBQuote(cCod) + ", " + GEBDBQuote(cCod) + ", " + GEBDBQuote(aFil[nI][2]) + ", '01' " + ;
            "WHERE NOT EXISTS (SELECT 1 FROM GEF1 WHERE GEF1_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' ')") .And. lOk
    Next
    For nI := 1 To Len(aUsu)
        cCod := aUsu[nI][1]
        // Nao redefine salt/senha nem cria historico a cada reexecucao.
        If !SF_HAS("public.GE2_EMP", "GE2_EMP_USUARIO", cCod, " AND GE2_EMP_EMPRESA = '99'") .Or. ;
                !SF_HAS("public.GE2_SEC", "SEC_USUARIO", cCod, " AND SEC_HASH <> ''")
            lOk := GEBSECCRIAUSU(cCod, "Demo#2026", {"99"}, aUsu[nI][2], aUsu[nI][3], .F., aUsu[nI][4]) .And. lOk
        EndIf
    Next
    For nI := 1 To Len(aPerm)
        lOk := GEBSECRBACADDEMP(aPerm[nI][1], "99", aPerm[nI][2], aPerm[nI][3], .T.) .And. lOk
    Next
    For nI := 1 To Len(aPerm)
        // Cada perfil especializado precisa conseguir acessar seu modulo.
        // DEM_CAIXA corresponde aos usuarios 3 e 4; demais pares abaixo.
        lOk := SF_CNT("SEC_PERM", "SEC_PERM_PERFIL = " + GEBDBQuote(aPerm[nI][1]) + ;
            " AND SEC_PERM_EMPRESA = '99' AND SEC_PERM_MENU = " + GEBDBQuote(aPerm[nI][2]) + ;
            " AND SEC_PERM_ITEM = " + GEBDBQuote(aPerm[nI][3]) + " AND SEC_PERM_PERMITE = 'T'", 1) .And. lOk
    Next
    lOk := SF_CNT("public.GE2", "LEFT(GE2_COD, 4) = 'DEM_'", 8) .And. lOk
    lOk := SF_CNT("public.GE2_SEC", "LEFT(SEC_USUARIO, 4) = 'DEM_' AND SEC_HASH <> ''", 8) .And. lOk
    lOk := SF_CNT("GEF1", "GEF1_COD IN ('990101','990102','990103')", 3) .And. lOk
    lOk := SF_CNT("public.GE2_EMP", "LEFT(GE2_EMP_USUARIO, 4) = 'DEM_' AND GE2_EMP_EMPRESA = '99'", 8) .And. lOk
    ConOut("SEED_FULL nucleo " + IIf(lOk, "OK", "FAIL"))
Return lOk

Static Function SF_CAD()
    Local lOk := .T.
    Local nI := 0
    Local nJ := 0
    Local cCod := ""
    Local cNcm := ""
    Local cFil := ""
    Local cFilQ := ""
    Local aR := {}
    // 12 familias x 5 apresentacoes = 60 produtos, precos variados.
    Local aProd := {{"Arroz", "10063021", 24.90}, {"Feijao", "07133399", 8.90}, ;
        {"Cafe", "09012100", 18.50}, {"Acucar", "17019900", 4.90}, ;
        {"Macarrao", "19021900", 5.50}, {"Farinha", "11010010", 6.90}, ;
        {"Leite", "04012010", 5.90}, {"Biscoito", "19053100", 4.50}, ;
        {"Sabonete", "34011190", 3.90}, {"Detergente", "34025000", 2.90}, ;
        {"Papel higienico", "48181000", 12.90}, {"Agua mineral", "22011000", 2.50}}
    Local aUF := {"SP", "RJ", "MG", "PR", "SC", "RS", "BA", "GO"}
    Local aConta := {{"DEM-1", "Ativo", "S"}, {"DEM-1.01", "Disponibilidades", "S"}, ;
        {"DEM-1.01.01", "Caixa", "A"}, {"DEM-1.01.02", "Bancos", "A"}, ;
        {"DEM-1.02", "Clientes", "A"}, {"DEM-1.03", "Estoques", "A"}, ;
        {"DEM-2", "Passivo", "S"}, {"DEM-2.01", "Fornecedores", "A"}, ;
        {"DEM-2.02", "Tributos a recolher", "A"}, {"DEM-3", "Receitas", "S"}, ;
        {"DEM-3.01", "Vendas", "R"}, {"DEM-4", "Custos e despesas", "S"}, ;
        {"DEM-4.01", "Custo mercadorias", "A"}, {"DEM-4.02", "Despesas administrativas", "A"}}
    Local aCC := {"Administracao", "Vendas Matriz", "Loja Centro", "Deposito", "Financeiro", "Fiscal"}
    cFil := FWxFilial("GF1")
    cFilQ := GEBDBQuote(cFil)
    For nI := 1 To Len(aProd)
        cNcm := aProd[nI][2]
        lOk := TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) " + ;
            "SELECT ' ', " + cFilQ + ", " + GEBDBQuote(cNcm) + ", 0.1, 0.9, '20200101', '20991231' " + ;
            "WHERE NOT EXISTS (SELECT 1 FROM GF2 WHERE GF2_FILIAL = " + cFilQ + " AND GF2_NCM = " + GEBDBQuote(cNcm) + " AND D_E_L_E_T_ = ' ')") .And. lOk
        For nJ := 1 To 5
            cCod := "DEM-P" + StrZero((nI - 1) * 5 + nJ, 2)
            lOk := TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) " + ;
                "SELECT ' ', " + cFilQ + ", " + GEBDBQuote(cCod) + ", " + GEBDBQuote(cNcm) + ", " + ;
                GEBDBQuote(aProd[nI][1] + " tipo " + StrZero(nJ, 1)) + ;
                " WHERE NOT EXISTS (SELECT 1 FROM GF1 WHERE GF1_FILIAL = " + cFilQ + " AND GF1_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' ')") .And. lOk
            If !SF_HAS("GFT2", "GFT2_PROD", cCod, " AND GFT2_FILIAL = " + cFilQ + " AND GFT2_TAB = 'PADRAO'")
                aR := GEBFATPRC("", cCod, aProd[nI][3] + nJ - 1)
                lOk := aR[1] .And. lOk
            EndIf
        Next
    Next
    For nI := 1 To 40
        cCod := "DEM-C" + StrZero(nI, 3)
        If !SF_HAS("GFT1", "GFT1_COD", cCod, " AND GFT1_FILIAL = " + cFilQ)
            aR := GEBFATCLI(cCod, "Cliente Demo " + StrZero(nI, 3), "", aUF[((nI - 1) % Len(aUF)) + 1], 1000 + nI * 250, "", "")
            lOk := aR[1] .And. lOk
        EndIf
    Next
    For nI := 1 To 15
        cCod := "DEM-F" + StrZero(nI, 3)
        lOk := GEBCMFOR(cCod, "Fornecedor Demo " + StrZero(nI, 3)) .And. lOk
    Next
    // Nao existe rotina de cadastro de conta: mesmo INSERT usado pela migracao GC1.
    For nI := 1 To Len(aConta)
        lOk := TCSqlExec("INSERT INTO GC1 (D_E_L_E_T_, GC1_FILIAL, GC1_CONTA, GC1_NOME, GC1_TIPO) " + ;
            "SELECT ' ', " + cFilQ + ", " + GEBDBQuote(aConta[nI][1]) + ", " + GEBDBQuote(aConta[nI][2]) + ", " + GEBDBQuote(aConta[nI][3]) + ;
            " WHERE NOT EXISTS (SELECT 1 FROM GC1 WHERE GC1_FILIAL = " + cFilQ + " AND GC1_CONTA = " + GEBDBQuote(aConta[nI][1]) + " AND D_E_L_E_T_ = ' ')") .And. lOk
    Next
    For nI := 1 To Len(aCC)
        cCod := "DEM-CC" + StrZero(nI, 2)
        If !SF_HAS("GCC1", "GCC1_COD", cCod, " AND GCC1_FILIAL = " + cFilQ)
            aR := GEBCTXCC(cCod, aCC[nI], "N")
            lOk := aR[1] .And. lOk
        EndIf
    Next
    lOk := SF_CNT("GF1", "LEFT(GF1_COD, 5) = 'DEM-P'", 60) .And. lOk
    lOk := SF_CNT("GFT2", "LEFT(GFT2_PROD, 5) = 'DEM-P' AND GFT2_TAB = 'PADRAO'", 60) .And. lOk
    lOk := SF_CNT("GFT1", "LEFT(GFT1_COD, 5) = 'DEM-C'", 40) .And. lOk
    lOk := SF_CNT("GCP1", "LEFT(GCP1_COD, 5) = 'DEM-F'", 15) .And. lOk
    lOk := SF_CNT("GC1", "LEFT(GC1_CONTA, 4) = 'DEM-'", Len(aConta)) .And. lOk
    lOk := SF_CNT("GCC1", "LEFT(GCC1_COD, 6) = 'DEM-CC'", Len(aCC)) .And. lOk
    ConOut("SEED_FULL cadastros " + IIf(lOk, "OK", "FAIL"))
Return lOk

/*/{Protheus.doc} SF_FIS
    Ciclo fiscal real no emulador: documentos DEM, eventos, entradas e EFD.
    Reutiliza documentos finais e recupera pendentes reenviando o mesmo XML/chave.
    @type Seed de demonstracao
    @author Peder Munksgaard
    @since 2026-10-03
    @return .T. se todas as quantidades e a EFD forem comprovadas
/*/
Static Function SF_FIS()
    Local lOk := .T.
    Local oE := JsonObject():New()
    Local oC := JsonObject():New()
    Local oP := Nil
    Local aR := {}
    Local aH := {}
    Local aCert := {}
    Local cDir := "/tmp/geban-seed-full"
    Local cCertBase := ""
    Local cSenha := StrZero(Randomize(1, 999999999), 9)
    Local cDoc := ""
    Local cCh := ""
    Local cMod := ""
    Local cComp := ""
    Local aD := {}
    Local cFilQ := GEBDBQuote(FWxFilial("GDF5"))
    Local nI := 0
    Local nMod := 0
    Local nLim := 0
    Local nNfe := 0
    Local nNfce := 0
    Local nCanc := 0
    Local nCce := 0
    Local nEnt := 0
    oE["CNPJ"] := "11222333000181"
    oE["IE"] := "110042490114"
    oE["RAZAO"] := "Mercado Demo Completo Ltda"
    oE["CRT"] := "3"
    oE["LOGRADOURO"] := "Rua A"
    oE["NUMERO"] := "1"
    oE["BAIRRO"] := "Centro"
    oE["UF"] := "SP"
    oE["MUNICIPIO"] := "3550308"
    oE["CEP"] := "01001000"
    If GEBDFEEMITLE() == Nil
        lOk := SF_FCHK("emitente", GEBDFEEMIT(oE)) .And. lOk
    EndIf
    // Serie exclusiva do DEM; nao altera as URLs ja configuradas em SF_PAR.
    oC["SERIE_NFE"] := "99"
    oC["SERIE_NFCE"] := "99"
    oC["QR_VERSAO"] := "3"
    oC["CONT_NOME"] := "Contabilidade Demo"
    oC["CONT_CPF"] := "11144477735"
    oC["CONT_CRC"] := "1SP123456"
    oC["CONT_EMAIL"] := "contab@example.com"
    oC["CONT_MUNICIPIO"] := "3550308"
    oC["EFD_PERFIL"] := "B"
    oC["EFD_COD_REC"] := "046-2"
    If SF_CFGDEMO()
        lOk := SF_FCHK("configuracao", GEBDFECONFIG(oC)) .And. lOk
    EndIf
    // Certificado em pasta persistente (~/.geban-demo/cert): /tmp some no
    // reboot e a emissao pararia. GEBDFECERTDIR() completa com tenant/filial.
    cCertBase := SF_CERTBASE()
    lOk := SF_SET("DFE_CERT_DIR", cCertBase) .And. lOk
    aCert := GEBDFECERTLE()
    // Reinstala quando nao ha certificado, quando o GDF2 aponta para fora da
    // pasta estavel (migracao do /tmp antigo), quando os arquivos sumiram
    // ou quando venceu — o pfx autoassinado e' regerado no scratch /tmp.
    If Len(aCert) == 0 .Or. !(BOCOL(aCert[4]) $ cCertBase) .Or. !(BOCOL(aCert[5]) $ cCertBase) .Or. ;
            !File(BOCOL(aCert[4])) .Or. !File(BOCOL(aCert[5])) .Or. BOCOL(aCert[3]) < BOHOJE()
        // Mesmo certificado autoassinado de teste usado por T_GEBDFE_DIST.
        If ProcRun("mkdir", {"-p", cDir}, {|c| c}) != 0
            Return .F.
        EndIf
        If ProcRun("openssl", {"req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", cDir + "/k.pem", "-out", cDir + "/c.pem", ;
                "-days", "365", "-subj", "/C=BR/O=ICP-Brasil/CN=MERCADO DEMO LTDA:11222333000181"}, {|c| c}, {|c| c}) != 0
            Return .F.
        EndIf
        If ProcRun("openssl", {"pkcs12", "-export", "-inkey", cDir + "/k.pem", "-in", cDir + "/c.pem", "-out", cDir + "/emp.pfx", ;
                "-passout", "pass:" + cSenha}, {|c| c}, {|c| c}) != 0
            Return .F.
        EndIf
        lOk := SF_FCHK("certificado", GEBDFECERT(Encode64(MemoRead(cDir + "/emp.pfx")), cSenha)) .And. lOk
    EndIf
    If !lOk
        Return .F.
    EndIf
    aR := GEBDFESTATSVC("55")
    If !SF_FCHK("conexao (certificado local: use ADVPP_HTTP_INSECURE=1 apenas no demo)", aR)
        Return .F.
    EndIf
    // Reenvia somente o mesmo XML/chave que ficou sem resposta, nunca nova emissao.
    aH := TCSqlQuery("SELECT GDF5_CHAVE AS C FROM GDF5 WHERE D_E_L_E_T_ = ' ' AND GDF5_FILIAL = " + cFilQ + ;
        " AND GDF5_MOD = '55' AND GDF5_DOC LIKE 'DEM-55-%' AND GDF5_STATUS = 'PENDENTE'")
    For nI := 1 To Len(aH)
        cCh := BOCOL(aH[nI]:C)
        aD := GEBDFEDOC(cCh)
        aR := GEBDFEENVIA("55", "SP", "2", "NfeAutorizacao", GEBDFELOTE(aD[3], StrZero(Val(BOSEQ("DFE_LOTE", 9)), 15)))
        lOk := aR[1] .And. lOk
        lOk := SF_FCHK("consulta pendente", GEBDFECONSULTAR(cCh, .T.)) .And. lOk
    Next
    aH := TCSqlQuery("SELECT GDF5_CHAVE AS C FROM GDF5 WHERE D_E_L_E_T_ = ' ' AND GDF5_FILIAL = " + cFilQ + ;
        " AND GDF5_MOD = '65' AND GDF5_DOC LIKE 'DEM-65-%' AND GDF5_STATUS = 'CONTINGENCIA'")
    If Len(aH) > 0
        lOk := SF_FCHK("transmitir contingencias", GEBDFETRANSMITE()) .And. lOk
    EndIf
    // Destinatario consumidor de SP (sem DIFAL), usando cadastro ja semeado.
    If !SF_HAS("GDF7", "GDF7_COD", "DEM-C001", " AND GDF7_TIPO = 'C' AND GDF7_FILIAL = " + cFilQ)
        oE["TIPO"] := "C"
        oE["CODIGO"] := "DEM-C001"
        oE["DOC"] := "52998224725"
        oE["CONTRIBUINTE"] := "9"
        lOk := SF_FCHK("participante", GEBDFEPART(oE)) .And. lOk
    EndIf
    For nMod := 1 To 2
        cMod := "55"
        nLim := 40
        If nMod == 2
            cMod := "65"
            nLim := 15
        EndIf
        For nI := 1 To nLim
            cDoc := "DEM-" + cMod + "-" + StrZero(nI, 3)
            aH := TCSqlQuery("SELECT GDF5_CHAVE AS C, GDF5_STATUS AS S FROM GDF5 WHERE D_E_L_E_T_ = ' ' AND GDF5_FILIAL = " + ;
                cFilQ + " AND GDF5_MOD = " + GEBDBQuote(cMod) + " AND GDF5_DOC = " + GEBDBQuote(cDoc))
            If Len(aH) == 0
                // Faixa fixa e independente da data; reexecucao nao consome numero.
                lOk := GEBDFESETNUM(cMod, 99, 990000 + nI) .And. lOk
                If nMod == 1
                    oP := JsonObject():New()
                    oP["ORIGEM"] := "DEM"
                    oP["DOC"] := cDoc
                    oP["TIPO_PART"] := "C"
                    oP["PART"] := "DEM-C001"
                    oP["ITENS"] := {{"DEM-P" + StrZero(nI, 2), 1 + nI % 3, 10 + nI, 0}}
                    oP["PARCELAS"] := {}
                    oP["REFS"] := {}
                    oP["NATOP"] := "Venda de mercadoria"
                    aR := GEBDFENFE(oP)
                Else
                    aR := GEBDFENFCE(cDoc, {{"DEM-P" + StrZero(nI, 2), 1, 10 + nI, 0}}, {{"01", 10 + nI}}, "")
                EndIf
                lOk := SF_FCHK(cDoc, aR) .And. lOk
                aH := TCSqlQuery("SELECT GDF5_CHAVE AS C, GDF5_STATUS AS S FROM GDF5 WHERE D_E_L_E_T_ = ' ' AND GDF5_FILIAL = " + ;
                    cFilQ + " AND GDF5_MOD = " + GEBDBQuote(cMod) + " AND GDF5_DOC = " + GEBDBQuote(cDoc))
            EndIf
            If Len(aH) != 1
                ConOut("SEED_FULL FIS documento ausente/duplicado " + cDoc)
                lOk := .F.
                Loop
            EndIf
            cCh := BOCOL(aH[1]:C)
            If nMod == 1 .And. nI <= 3
                If BOCOL(aH[1]:S) == "AUTORIZADA"
                    lOk := SF_FCHK("cancelamento " + cDoc, GEBDFECANCELA(cCh, "Cancelamento de demonstracao sem circulacao de mercadoria")) .And. lOk
                EndIf
                If GEBDFEDOC(cCh)[1] == "CANCELADA"
                    nCanc++
                Else
                    lOk := .F.
                EndIf
            ElseIf BOCOL(aH[1]:S) == "AUTORIZADA"
                If nMod == 1
                    nNfe++
                    If nI == 4
                        If !SF_HAS("GDF6", "GDF6_CHAVE", cCh, " AND GDF6_TIPO = 'CCE' AND GDF6_CSTAT IN ('135','136') AND GDF6_FILIAL = " + cFilQ)
                            lOk := SF_FCHK("cce", GEBDFECCE(cCh, "Corrige complemento do endereco de entrega para sala dois")) .And. lOk
                        EndIf
                        If SF_HAS("GDF6", "GDF6_CHAVE", cCh, " AND GDF6_TIPO = 'CCE' AND GDF6_CSTAT IN ('135','136') AND GDF6_FILIAL = " + cFilQ)
                            nCce++
                        EndIf
                    EndIf
                Else
                    nNfce++
                EndIf
            Else
                ConOut("SEED_FULL FIS nao reemite " + cDoc + " status=" + BOCOL(aH[1]:S))
                lOk := .F.
            EndIf
        Next
    Next
    // Nao consulta repetidamente sem novidade (SEFAZ rejeitaria com 656).
    aH := TCSqlQuery("SELECT GDFE_CHAVE AS C FROM GDFE WHERE D_E_L_E_T_ = ' ' AND GDFE_FILIAL = " + cFilQ + ;
        " AND GDFE_CNPJ = '11444777000161' AND GDFE_IMPORT <> '' AND GDFE_SIT = 'AUTORIZADA'")
    If Len(aH) < 8
        // Releitura segura dos resumos apos reinicio/ampliacao da massa do emulador.
        // DSTGrava preserva XML completo e vinculo de importacoes existentes.
        lOk := SF_SET("DFE_ULTNSU", "0") .And. lOk
        lOk := SF_FCHK("distribuicao", GEBDFEDISTBUSCA()) .And. lOk
    EndIf
    lOk := GEBCMFOR("F77000161", "Fornecedor Fiscal Demo") .And. lOk
    lOk := SF_FCHK("depara banana", SF_DEPARA("F77000161", "FORN-BAN", "DEM-P01", 12)) .And. lOk
    lOk := SF_FCHK("depara maca", SF_DEPARA("F77000161", "FORN-MAC", "DEM-P02", 1)) .And. lOk
    aH := TCSqlQuery("SELECT GDFE_CHAVE AS C, GDFE_IMPORT AS I FROM GDFE WHERE D_E_L_E_T_ = ' ' AND GDFE_FILIAL = " + ;
        cFilQ + " AND GDFE_CNPJ = '11444777000161' AND GDFE_SIT = 'AUTORIZADA' ORDER BY GDFE_CHAVE LIMIT 8")
    For nI := 1 To Len(aH)
        If BOCOL(aH[nI]:I) == ""
            cCh := BOCOL(aH[nI]:C)
            If SF_FCHK("ciencia", GEBDFEMANIF(cCh, "CIENCIA", ""))
                lOk := SF_FCHK("importacao", GEBDFEIMPORTA(cCh, "", BOHOJE())) .And. lOk
            Else
                lOk := .F.
            EndIf
        EndIf
    Next
    aH := TCSqlQuery("SELECT GDFE_CHAVE AS C FROM GDFE WHERE D_E_L_E_T_ = ' ' AND GDFE_FILIAL = " + cFilQ + ;
        " AND GDFE_CNPJ = '11444777000161' AND GDFE_SIT = 'AUTORIZADA' AND GDFE_IMPORT <> ''")
    nEnt := Len(aH)
    ConOut("SEED_FULL FIS nfe=" + cValToChar(nNfe + nCanc) + " autorizadas=" + cValToChar(nNfe) + " canceladas=" + cValToChar(nCanc) + ;
        " cce=" + cValToChar(nCce) + " nfce=" + cValToChar(nNfce) + " recebidas=" + cValToChar(nEnt) + "/8")
    If nEnt < 8
        ConOut("SEED_FULL FIS FAIL massa insuficiente: emulador deve distribuir 8 NF-e autorizadas do fornecedor; nao fabricar entradas locais")
    EndIf
    lOk := nNfe == 37 .And. nCanc == 3 .And. nCce == 1 .And. nNfce == 15 .And. nEnt == 8 .And. lOk
    // Competencia vem dos documentos semeados, nao do mes corrente da execucao.
    aH := TCSqlQuery("SELECT MAX(LEFT(GDF5_DATA, 6)) AS C FROM GDF5 WHERE D_E_L_E_T_ = ' ' AND GDF5_FILIAL = " + ;
        cFilQ + " AND GDF5_DOC LIKE 'DEM-%'")
    If Len(aH) > 0
        cComp := BOCOL(aH[1]:C)
    EndIf
    If Len(cComp) != 6
        ConOut("SEED_FULL FIS FAIL competencia dos documentos DEM nao encontrada")
        Return .F.
    EndIf
    aR := GEBDFEEFD(cComp, "0")
    lOk := SF_FCHK("efd competencia " + cComp, aR) .And. lOk
    If aR[1]
        ConOut("SEED_FULL FIS efd competencia=" + cComp + " documentos=" + cValToChar(aR[4][5]) + "/" + ;
            cValToChar(nNfe + nCanc + nNfce + nEnt) + " bytes=" + cValToChar(Len(aR[3])))
        // Chave emitida so' pode gerar um C100; quantidade tem de ser exata.
        If aR[4][5] != nNfe + nCanc + nNfce + nEnt
            ConOut("SEED_FULL FIS FAIL efd " + cComp + " divergente: " + cValToChar(aR[4][5]) + "/" + ;
                cValToChar(nNfe + nCanc + nNfce + nEnt) + " documentos")
            lOk := .F.
        EndIf
    EndIf
Return lOk

/*/{Protheus.doc} SF_FIN
    Ciclo financeiro do demo: contas, 120 titulos a receber DEM (30 baixados
    com juros/desconto, 20 vencidos, 70 em aberto) e CNAB 240 ponta a ponta
    contra o banco emulador em FIN_BANCO_URL (boleto -> remessa POST ->
    retorno GET -> baixa automatica). Idempotente: titulo/boleto/remessa so
    sao criados uma vez.
    @type Seed de demonstracao
    @author Peder Munksgaard
    @since 2026-10-18
    @return .T. se todas as quantidades forem comprovadas
/*/
Static Function SF_FIN()
    Local lOk := .T.
    Local aR := {}
    Local aH := {}
    Local cDoc := ""
    Local cCli := ""
    Local cUrl := ""
    Local cResp := ""
    Local cFilQ := GEBDBQuote(FWxFilial("GFN2"))
    Local dHoje := BOHOJE()
    Local nI := 0
    Local nVal := 0
    Local nSaldo := 0
    Local nJur := 0
    Local nMul := 0
    Local nDesc := 0
    Local nLiq := 0

    // Contas do demo; GEBFNCON ja recusa duplicata.
    lOk := GEBFNCON("CAIXA", "Caixa matriz") .And. lOk
    lOk := GEBFNCON("BANCO", "Banco cobranca demo") .And. lOk
    lOk := GEBFNCON("CRYPTO", "Carteira cripto demo") .And. lOk

    // 120 titulos a receber: 30 pagos com atraso, 20 vencidos, 70 em aberto.
    For nI := 1 To 120
        cDoc := "DEM-REC-" + StrZero(nI, 3)
        cCli := "DEM-C" + StrZero(((nI - 1) % 40) + 1, 3)
        nVal := 120 + nI * 3.75
        If !SF_HAS("GFN2", "GFN2_DOC", cDoc, " AND GFN2_FILIAL = " + cFilQ)
            If nI <= 30
                aR := GEBFXTIT("R", cDoc, cCli, nVal, "30", BODTADD(dHoje, -50), "SEED_FIN", "")
            ElseIf nI <= 50
                aR := GEBFXTIT("R", cDoc, cCli, nVal, "30", BODTADD(dHoje, -60), "SEED_FIN", "")
            Else
                aR := GEBFXTIT("R", cDoc, cCli, nVal, "30", dHoje, "SEED_FIN", "")
            EndIf
            If !aR[1]
                ConOut("SEED_FULL FIN " + cDoc + " " + aR[2])
                lOk := .F.
            EndIf
        EndIf
    Next
    // Baixa manual dos 30 primeiros, juros/multa/desconto variados.
    For nI := 1 To 30
        cDoc := "DEM-REC-" + StrZero(nI, 3)
        aH := TCSqlQuery("SELECT GFN2_SALDO AS S, GFN2_STATUS AS T FROM GFN2 WHERE GFN2_FILIAL = " + cFilQ + ;
            " AND GFN2_DOC = " + GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' '")
        If Len(aH) == 1 .And. BOCOL(aH[1]:T) == "ABERTO"
            nSaldo := BOVAL(aH[1]:S)
            nJur := Round(nSaldo * 0.01 * ((nI - 1) % 3 + 1), 2)
            nMul := Round(nSaldo * 0.02 * (nI % 2), 2)
            nDesc := Round(nSaldo * 0.05 * IIf((nI + 1) % 4 == 0, 1, 0), 2)
            aR := GEBFXBAI("R", cDoc, nSaldo, nJur, nMul, nDesc, "CAIXA", dHoje)
            If !aR[1]
                ConOut("SEED_FULL FIN baixa " + cDoc + " " + aR[2])
                lOk := .F.
            EndIf
        EndIf
    Next

    // CNAB 240 ponta a ponta: 5 titulos vencidos (DEM-REC-031..035).
    If !SF_HAS("GBC1", "GBC1_CONTA", "BANCO", " AND GBC1_FILIAL = " + cFilQ)
        aR := GEBBCOCFG("BANCO", "033", "1234", "", "123456", "", "101", "1234567", ;
            "MERCADO DEMO COMPLETO LTDA", "11222333000181", "240", "")
        lOk := aR[1] .And. lOk
        If !aR[1]
            ConOut("SEED_FULL FIN cfg cobranca " + aR[2])
        EndIf
    EndIf
    For nI := 31 To 35
        cDoc := "DEM-REC-" + StrZero(nI, 3)
        If !SF_HAS("GBC2", "GBC2_DOC", cDoc, " AND GBC2_FILIAL = " + cFilQ)
            aR := GEBBCOBOL(cDoc, "BANCO")
            lOk := aR[1] .And. lOk
            If !aR[1]
                ConOut("SEED_FULL FIN boleto " + cDoc + " " + aR[2])
            EndIf
        EndIf
    Next
    // Remessa so sai uma vez: boletos GERADO viram REMETIDO na geracao.
    aH := TCSqlQuery("SELECT GBC2_DOC AS D FROM GBC2 WHERE GBC2_FILIAL = " + cFilQ + ;
        " AND GBC2_CONTA = 'BANCO' AND GBC2_STATUS = 'GERADO' AND GBC2_DOC LIKE 'DEM-REC-%' AND D_E_L_E_T_ = ' '")
    If Len(aH) > 0
        aR := GEBBCOREM("BANCO", "")
        lOk := aR[1] .And. lOk
        If aR[1]
            cUrl := BOPARM("FIN_BANCO_URL", "http://127.0.0.1:18767")
            // HttpQuote e' o cliente HTTP do runtime (mesmo do TEF/SEFAZ).
            cResp := HttpQuote(cUrl + "/cnab/remessa", "POST", "", aR[3][3], 15, {"Content-Type: text/plain"})
            If cResp == Nil .Or. !('"ok": true' $ BOSTR(cResp))
                ConOut("SEED_FULL FIN remessa banco falhou: " + BOSTR(cResp))
                lOk := .F.
            EndIf
        EndIf
    EndIf
    // Recuperacao: REMETIDO (remessa ja saiu) ainda nao liquidado busca o
    // retorno mesmo que o POST tenha falhado numa execucao anterior.
    aH := TCSqlQuery("SELECT GBC2_DOC AS D FROM GBC2 WHERE GBC2_FILIAL = " + cFilQ + ;
        " AND GBC2_DOC LIKE 'DEM-REC-%' AND GBC2_STATUS = 'REMETIDO' AND D_E_L_E_T_ = ' '")
    If Len(aH) > 0
        If cUrl == ""
            cUrl := BOPARM("FIN_BANCO_URL", "http://127.0.0.1:18767")
        EndIf
        cResp := HttpQuote(cUrl + "/cnab/retorno", "GET", "", "", 15, {})
        If cResp == Nil
            ConOut("SEED_FULL FIN retorno banco sem resposta")
            lOk := .F.
        Else
            aR := GEBBCORET("BANCO", BOSTR(cResp))
            lOk := aR[1] .And. lOk
            ConOut("SEED_FULL FIN retorno: " + aR[2])
        EndIf
    EndIf
    aH := TCSqlQuery("SELECT GBC2_DOC AS D FROM GBC2 WHERE GBC2_FILIAL = " + cFilQ + ;
        " AND GBC2_DOC LIKE 'DEM-REC-%' AND GBC2_STATUS = 'LIQUIDADO' AND D_E_L_E_T_ = ' '")
    nLiq := Len(aH)
    ConOut("SEED_FULL FIN cnab liquidados=" + cValToChar(nLiq) + "/5")
    lOk := nLiq == 5 .And. lOk
    lOk := SF_CNT("GFN1", "GFN1_CONTA IN ('CAIXA','BANCO','CRYPTO')", 3) .And. lOk
    lOk := SF_CNT("GFN2", "GFN2_DOC LIKE 'DEM-REC-%'", 120) .And. lOk
    lOk := SF_CNT("GFN2", "GFN2_DOC LIKE 'DEM-REC-%' AND GFN2_STATUS = 'RECEBIDA'", 35) .And. lOk
    lOk := SF_CNT("GFN2", "GFN2_DOC LIKE 'DEM-REC-%' AND GFN2_STATUS = 'ABERTO'", 85) .And. lOk
    ConOut("SEED_FULL financeiro " + IIf(lOk, "OK", "FAIL"))
Return lOk

/*/{Protheus.doc} SF_COM
    Compras/estoque do demo: 5 solicitacoes atendidas via cotacao (SC ->
    GEBCPXGERA), 30 pedidos DEM-PED (18 recebidos com NF DEM-NF, 3 aprovados
    por alcada, 3 pendentes, 6 liberados em aberto) e saldo inicial DEM-EST.
    Idempotente: pedido, entrada e movimento so sao criados uma vez.
    @type Seed de demonstracao
    @author Peder Munksgaard
    @since 2026-10-18
    @return .T. se todas as quantidades forem comprovadas
/*/
Static Function SF_COM()
    Local lOk := .T.
    Local aR := {}
    Local aH := {}
    Local aCh := {}
    Local aIt := {}
    Local cPed := ""
    Local cNF := ""
    Local cForn := ""
    Local cProd1 := ""
    Local cProd2 := ""
    Local cChave := ""
    Local cFilQ := GEBDBQuote(FWxFilial("GCP3"))
    Local dHoje := BOHOJE()
    Local nI := 0
    Local nTot := 0

    // Alcada de compras: total acima fica PENDENTE ate GEBCPXAPR.
    lOk := SF_SET("COM_ALCADA", "800") .And. lOk

    // Saldo inicial de 3 produtos (estoque antes das compras).
    For nI := 1 To 3
        If !SF_HAS("GES2", "GES2_DOC", "DEM-EST-" + StrZero(nI, 3), " AND GES2_FILIAL = " + GEBDBQuote(FWxFilial("GES2")))
            aR := GEBESTMOV("DEM-P" + StrZero(nI, 2), "01", "E", 50 + nI * 10, 5 + nI, "SALDO_INI", ;
                "DEM-EST-" + StrZero(nI, 3), dHoje, {}, "", .F.)
            lOk := aR[1] .And. lOk
            If !aR[1]
                ConOut("SEED_FULL COM estoque " + aR[2])
            EndIf
        EndIf
    Next

    // Cotacoes minimas para a SC gerar pedido pelo menor preco.
    For nI := 1 To 5
        cProd1 := "DEM-P" + StrZero(40 + nI, 2)
        If !SF_HAS("GCP2", "GCP2_FORN", "DEM-F001", " AND GCP2_PROD = " + GEBDBQuote(cProd1) + ;
                " AND GCP2_FILIAL = " + cFilQ)
            lOk := GEBCMCOT("DEM-F001", cProd1, 4 + nI) .And. lOk
        EndIf
    Next
    // 5 solicitacoes -> pedido gerado pela cotacao (PCxxxxx, uma vez so).
    For nI := 1 To 5
        cPed := "DEM-SC-" + StrZero(nI, 2)
        If !SF_HAS("GCQ1", "GCQ1_NUM", cPed, " AND GCQ1_FILIAL = " + cFilQ)
            cProd1 := "DEM-P" + StrZero(40 + nI, 2)
            aR := GEBCPXSC(cPed, {{cProd1, 10 + nI, dHoje}}, "DEM_COMPRAS")
            lOk := aR[1] .And. lOk
            If aR[1]
                aR := GEBCPXGERA(cPed, "30", "01", dHoje)
                lOk := aR[1] .And. lOk
                If !aR[1]
                    ConOut("SEED_FULL COM gera " + cPed + " " + aR[2])
                EndIf
            EndIf
        EndIf
    Next

    // Chaves das NF-e de fornecedor importadas (vinculo de entrada).
    aCh := TCSqlQuery("SELECT GDFE_CHAVE AS C FROM GDFE WHERE GDFE_FILIAL = " + GEBDBQuote(FWxFilial("GDFE")) + ;
        " AND GDFE_IMPORT <> '' AND D_E_L_E_T_ = ' ' ORDER BY GDFE_CHAVE LIMIT 3")

    // 30 pedidos: 001..018 recebidos; 019..021 aprovados; 022..024 pendentes;
    // 025..030 liberados em aberto. Total dos itens acima da alcada nos 19..24.
    For nI := 1 To 30
        cPed := "DEM-PED-" + StrZero(nI, 3)
        cNF := "DEM-NF-" + StrZero(nI, 3)
        cForn := "DEM-F" + StrZero(((nI - 1) % 15) + 1, 3)
        cProd1 := "DEM-P" + StrZero(((nI * 2 - 1) % 60) + 1, 2)
        cProd2 := "DEM-P" + StrZero(((nI * 2) % 60) + 1, 2)
        If nI >= 16 .And. nI <= 18 .And. Len(aCh) >= nI - 15
            cForn := "F77000161"
        EndIf
        nTot := IIf(nI >= 19 .And. nI <= 24, 400, 60)
        aIt := {{cProd1, 2 + nI % 5, nTot}, {cProd2, 1 + nI % 3, 20 + nI % 10}}
        If !SF_HAS("GCP3", "GCP3_NUM", cPed, " AND GCP3_FILIAL = " + cFilQ)
            aR := GEBCPXPED(cPed, cForn, aIt, "30", "01", dHoje)
            lOk := aR[1] .And. lOk
            If !aR[1]
                ConOut("SEED_FULL COM pedido " + cPed + " " + aR[2])
                Loop
            EndIf
        EndIf
        // Aprovacao de alcada dos pedidos 019..021.
        If nI >= 19 .And. nI <= 21
            aH := TCSqlQuery("SELECT GCQ2_LIB AS L FROM GCQ2 WHERE GCQ2_FILIAL = " + cFilQ + ;
                " AND GCQ2_PED = " + GEBDBQuote(cPed) + " AND GCQ2_LIB = 'PENDENTE' AND D_E_L_E_T_ = ' '")
            If Len(aH) == 1
                aR := GEBCPXAPR(cPed, "DEM_COMPRAS", .T.)
                lOk := aR[1] .And. lOk
                If !aR[1]
                    ConOut("SEED_FULL COM aprova " + cPed + " " + aR[2])
                EndIf
            EndIf
        EndIf
        // Recebimento dos 18 primeiros com NF do fornecedor.
        If nI <= 18 .And. !SF_HAS("GCP5", "GCP5_NF", cNF, " AND GCP5_FILIAL = " + cFilQ)
            cChave := ""
            If nI >= 16 .And. Len(aCh) >= nI - 15
                cChave := BOCOL(aCh[nI - 15]:C)
            EndIf
            aR := GEBCPXENT(cNF, cPed, {}, 0, dHoje, {}, cChave)
            lOk := aR[1] .And. lOk
            If !aR[1]
                ConOut("SEED_FULL COM entrada " + cNF + " " + aR[2])
            EndIf
        EndIf
    Next

    lOk := SF_CNT("GCQ1", "GCQ1_NUM LIKE 'DEM-SC-%' AND GCQ1_STATUS = 'ATENDIDA'", 5) .And. lOk
    lOk := SF_CNT("GCP3", "GCP3_NUM LIKE 'DEM-PED-%'", 30) .And. lOk
    lOk := SF_CNT("GCP3", "GCP3_NUM LIKE 'DEM-PED-%' AND GCP3_STATUS = 'RECEBIDO'", 18) .And. lOk
    lOk := SF_CNT("GCQ2", "GCQ2_PED LIKE 'DEM-PED-%' AND GCQ2_LIB = 'PENDENTE'", 3) .And. lOk
    lOk := SF_CNT("GCQ2", "GCQ2_PED LIKE 'DEM-PED-%' AND GCQ2_APROV = 'DEM_COMPRAS'", 3) .And. lOk
    lOk := SF_CNT("GCP5", "GCP5_NF LIKE 'DEM-NF-%'", 18) .And. lOk
    lOk := SF_CNT("GFN3", "GFN3_DOC LIKE 'DEM-NF-%'", 18) .And. lOk
    lOk := SF_CNT("GES2", "GES2_DOC LIKE 'DEM-EST-%'", 3) .And. lOk
    ConOut("SEED_FULL compras " + IIf(lOk, "OK", "FAIL"))
Return lOk

/*/{Protheus.doc} SF_LOJ
    Loja/faturamento do demo: estoque de reposicao DEM-ESL (60 produtos),
    caixa 01 com sessao do dia (vendas multi-forma: dinheiro, PIX, TEF
    debito/credito no emulador Cielo, fiado, vale-troca e crypto se o
    CoinGecko responder), sangria/suprimento, devolucoes e fechamento sem
    diferenca; 50 pedidos DEM-PV liberados e faturados (nota NS) e 5
    devolucoes GEBFATDEV. Idempotente: sessao FECHADA do caixa 01 encerra o
    bloco; pedido/devolucao/movimento so sao criados uma vez.
    @type Seed de demonstracao
    @author Peder Munksgaard
    @since 2026-11-02
    @return .T. se todas as quantidades forem comprovadas
/*/
Static Function SF_LOJ()
    Local lOk := .T.
    Local lCrypto := .F.
    Local aR := {}
    Local aH := {}
    Local aIt := {}
    Local aPg := {}
    Local aDev := {}
    Local aVen := {}
    Local cSes := ""
    Local cSt := ""
    Local cProd := ""
    Local cProd2 := ""
    Local cForma := ""
    Local cPed := ""
    Local cCli := ""
    Local cCup := ""
    Local cVale := ""
    Local cNota := ""
    Local cFilQ := GEBDBQuote(FWxFilial("GLJ3"))
    Local dHoje := BOHOJE()
    Local nI := 0
    Local nJ := 0
    Local nTot := 0
    Local nVale := 0
    Local nEsp := 0
    Local nCup := 0
    Local nVen := 0
    Local nFat := 0
    Local nP1 := 0
    Local nP2 := 0

    // Parametros e carteira crypto (a venda crypto depende do CoinGecko).
    lOk := SF_SET("CRY_CONTA", "CRYPTO") .And. lOk
    lOk := SF_SET("LOJ_FIADO_DIAS", "30") .And. lOk
    If !SF_HAS("GCK1", "GCK1_MOEDA", "BTC", " AND GCK1_ATIVO = 'S' AND GCK1_FILIAL = " + GEBDBQuote(FWxFilial("GCK1")))
        lOk := GEBCRYWAL("BTC", "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa", "S")[1] .And. lOk
    EndIf

    // Reposicao de estoque: 500 de cada produto DEM-P (custo ~55% do preco).
    For nI := 1 To 60
        cProd := "DEM-P" + StrZero(nI, 2)
        If !SF_HAS("GES2", "GES2_DOC", "DEM-ESL-" + StrZero(nI, 2), " AND GES2_FILIAL = " + GEBDBQuote(FWxFilial("GES2")))
            aR := GEBESTMOV(cProd, "01", "E", 500, Max(Round(SF_PRC(cProd) * 0.55, 2), 0.5), "SALDO_INI", ;
                "DEM-ESL-" + StrZero(nI, 2), dHoje, {}, "", .F.)
            lOk := aR[1] .And. lOk
            If !aR[1]
                ConOut("SEED_FULL LOJ estoque " + cProd + " " + aR[2])
            EndIf
        EndIf
    Next

    // Caixa 01 da loja centro (conta CAIXA01, local 01, CC da loja).
    aR := GEBLOJCX("01", "DEM Caixa Loja Centro", "", "01", "DEM-CC03")
    lOk := aR[1] .And. lOk

    // Sessao: FECHADA = bloco ja executado; ABERTA sem cupons = retomada.
    aH := TCSqlQuery("SELECT GLJ2_SESSAO AS S, GLJ2_STATUS AS T FROM GLJ2 WHERE GLJ2_FILIAL = " + GEBDBQuote(FWxFilial("GLJ2")) + ;
        " AND GLJ2_CAIXA = '01' AND D_E_L_E_T_ = ' ' ORDER BY R_E_C_N_O_ DESC LIMIT 1")
    If Len(aH) > 0
        cSes := BOCOL(aH[1]:S)
        cSt := BOCOL(aH[1]:T)
    EndIf
    If cSt == "FECHADA"
        nCup := BOVAL(TCSqlQuery("SELECT COUNT(*) AS N FROM GLJ3 WHERE GLJ3_FILIAL = " + cFilQ + ;
            " AND GLJ3_SESSAO = " + GEBDBQuote(cSes) + " AND D_E_L_E_T_ = ' '")[1]:N)
        aH := TCSqlQuery("SELECT COUNT(DISTINCT GLJ5_FORMA) AS N FROM GLJ5 JOIN GLJ3 ON GLJ3_FILIAL = GLJ5_FILIAL AND GLJ3_CUPOM = GLJ5_CUPOM " + ;
            "AND GLJ3.D_E_L_E_T_ = ' ' WHERE GLJ5_FILIAL = " + GEBDBQuote(FWxFilial("GLJ5")) + " AND GLJ5.D_E_L_E_T_ = ' ' AND " + ;
            "GLJ3_SESSAO = " + GEBDBQuote(cSes) + " AND GLJ5_FORMA IN ('DINHEIRO', 'PIX', 'DEBITO', 'CREDITO', 'FIADO', 'VALE')")
        // Completa = 18+ cupons e as 6 formas obrigatorias; crypto e' opcional.
        If nCup < 18 .Or. BOVAL(aH[1]:N) < 6
            // Sessao fechada incompleta (rodada parcial): abre outra do zero.
            ConOut("SEED_FULL LOJ sessao " + cSes + " fechada incompleta (" + cValToChar(nCup) + " cupons): nova sessao")
            cSes := ""
            cSt := ""
        Else
            ConOut("SEED_FULL LOJ sessao " + cSes + " ja fechada com " + cValToChar(nCup) + " cupons")
        EndIf
    EndIf
    If !(cSt == "FECHADA")
        If cSt == "ABERTA"
            nCup := BOVAL(TCSqlQuery("SELECT COUNT(*) AS N FROM GLJ3 WHERE GLJ3_FILIAL = " + cFilQ + ;
                " AND GLJ3_SESSAO = " + GEBDBQuote(cSes) + " AND D_E_L_E_T_ = ' '")[1]:N)
            If nCup > 0
                // Sessao antiga com cupons: fecha sem diferenca e abre outra.
                ConOut("SEED_FULL LOJ sessao " + cSes + " aberta com " + cValToChar(nCup) + " cupons: fechando")
                aR := GEBLOJFECHA(cSes, GEBLOJESP(cSes))
                lOk := aR[1] .And. lOk
                If !aR[1]
                    // Caixa ainda ocupado: nao abre outra sessao por cima.
                    ConOut("SEED_FULL LOJ FAIL fechando sessao antiga " + cSes + ": " + aR[2])
                    Return .F.
                EndIf
                cSes := ""
                cSt := ""
            EndIf
        EndIf
        If cSt == ""
            aR := GEBLOJABRE("01", "DEM_CAIXA1", 200, dHoje)
            lOk := aR[1] .And. lOk
            If !aR[1]
                ConOut("SEED_FULL LOJ abre caixa " + aR[2])
                Return .F.
            EndIf
            cSes := aR[3]
        EndIf

        // 8 dinheiro + 3 PIX + 2 debito + 2 credito + 2 fiado = 15 genericas;
        // depois vale-troca (devolucao VALE), cancelamento e crypto.
        aVen := {;
            {{"DEM-P01", 2, "DEM-P05", 1}, "DINHEIRO", 0, ""}, ;
            {{"DEM-P06", 3, "", 0}, "DINHEIRO", 0, ""}, ;
            {{"DEM-P11", 2, "", 0}, "DINHEIRO", 0, ""}, ;
            {{"DEM-P16", 4, "", 0}, "DINHEIRO", 0, ""}, ;
            {{"DEM-P21", 4, "", 0}, "PIX", 0, ""}, ;
            {{"DEM-P22", 6, "", 0}, "PIX", 0, ""}, ;
            {{"DEM-P23", 2, "", 0}, "PIX", 0, ""}, ;
            {{"DEM-P33", 2, "", 0}, "DEBITO", 1, ""}, ;
            {{"DEM-P36", 2, "", 0}, "CREDITO", 1, ""}, ;
            {{"DEM-P41", 2, "", 0}, "CREDITO", 3, ""}, ;
            {{"DEM-P46", 1, "", 0}, "DEBITO", 1, ""}, ;
            {{"DEM-P51", 2, "", 0}, "FIADO", 0, "DEM-C005"}, ;
            {{"DEM-P56", 2, "", 0}, "DINHEIRO", 0, ""}, ;
            {{"DEM-P02", 5, "", 0}, "DINHEIRO", 0, ""}, ;
            {{"DEM-P03", 2, "", 0}, "FIADO", 0, "DEM-C010"}, ;
            {{"DEM-P12", 2, "", 0}, "DINHEIRO", 0, ""}, ;
            {{"DEM-P07", 2, "", 0}, "DINHEIRO", 0, ""}}
        For nI := 1 To Len(aVen)
            aIt := {{aVen[nI][1][1], aVen[nI][1][2]}}
            nTot := Round(aVen[nI][1][2] * SF_PRC(aVen[nI][1][1]), 2)
            If !(aVen[nI][1][3] == "")
                aAdd(aIt, {aVen[nI][1][3], aVen[nI][1][4]})
                nTot := Round(nTot + aVen[nI][1][4] * SF_PRC(aVen[nI][1][3]), 2)
            EndIf
            cForma := aVen[nI][2]
            If cForma == "DINHEIRO"
                aPg := {{"DINHEIRO", Round(nTot + 50, 2)}}
            ElseIf cForma == "PIX" .Or. cForma == "FIADO"
                aPg := {{cForma, nTot}}
            ElseIf cForma == "DEBITO"
                aPg := {{"DEBITO", nTot, aVen[nI][3]}}
            Else
                aPg := {{"CREDITO", nTot, aVen[nI][3]}}
            EndIf
            aR := GEBLOJVEN(cSes, aIt, aPg, aVen[nI][4], 0)
            If !aR[1]
                ConOut("SEED_FULL LOJ venda " + cValToChar(nI) + " " + aR[2])
                lOk := .F.
                Loop
            EndIf
            nVen++
            If nI == 14
                // Devolucao em dinheiro de 1 item da venda 14.
                cCup := aR[3][1]
                aR := GEBLOJDEV(cSes, cCup, {{"DEM-P02", 1}}, "DINHEIRO", "defeito")
                If !aR[1]
                    ConOut("SEED_FULL LOJ devolucao dinheiro " + aR[2])
                EndIf
                lOk := aR[1] .And. lOk
            EndIf
            If nI == 15
                // Devolucao em vale-troca de 1 item da venda 15.
                cCup := aR[3][1]
                aR := GEBLOJDEV(cSes, cCup, {{"DEM-P03", 1}}, "VALE", "trocou")
                If !aR[1]
                    ConOut("SEED_FULL LOJ devolucao vale " + aR[2])
                EndIf
                lOk := aR[1] .And. lOk
                If aR[1]
                    cVale := aR[3][4]
                    nVale := Round(BOVAL(aR[3][2]), 2)
                EndIf
            EndIf
            If nI == 16
                // Cancelamento da venda 16 (sessao ainda aberta).
                aR := GEBLOJCAN(aR[3][1], "desistencia no balcao")
                lOk := aR[1] .And. lOk
            EndIf
        Next
        // Venda com o vale-troca + complemento em dinheiro
        // (o numero do vale vai na 4a posicao do pagamento).
        If !(cVale == "")
            nTot := SF_PRC("DEM-P04")
            aPg := {{"VALE", Min(nVale, nTot), 0, cVale}, {"DINHEIRO", Round(Max(nTot - nVale, 0) + 20, 2)}}
            aR := GEBLOJVEN(cSes, {{"DEM-P04", 1}}, aPg, "", 0)
            If !aR[1]
                ConOut("SEED_FULL LOJ venda vale " + aR[2])
                lOk := .F.
            Else
                nVen++
            EndIf
        EndIf
        // Venda crypto (BTC): so se o CoinGecko responder agora.
        nTot := SF_PRC("DEM-P09")
        aR := GEBCRYQRCODE("BTC", nTot)
        If aR[1]
            aR := GEBLOJVEN(cSes, {{"DEM-P09", 1}}, {{"CRYPTO", nTot, 0, "BTC|" + aR[3][2]}}, "", 0)
            If aR[1]
                nVen++
                lCrypto := .T.
            Else
                ConOut("SEED_FULL LOJ aviso venda crypto recusada: " + aR[2])
            EndIf
        Else
            ConOut("SEED_FULL LOJ aviso cotacao crypto indisponivel (CoinGecko): venda crypto pulada")
        EndIf
        // Gaveta: suprimento e sangria antes do fechamento sem diferenca.
        lOk := GEBLOJSAN(cSes, "SUPRIMENTO", 150, "reforco de troco", "")[1] .And. lOk
        lOk := GEBLOJSAN(cSes, "SANGRIA", 400, "sangria cofre", "")[1] .And. lOk
        nEsp := GEBLOJESP(cSes)
        aR := GEBLOJFECHA(cSes, nEsp)
        lOk := aR[1] .And. lOk
        If aR[1] .And. !(aR[3][3] == 0)
            ConOut("SEED_FULL LOJ fechamento com diferenca " + cValToChar(aR[3][3]))
            lOk := .F.
        EndIf
        nCup := BOVAL(TCSqlQuery("SELECT COUNT(*) AS N FROM GLJ3 WHERE GLJ3_FILIAL = " + cFilQ + ;
            " AND GLJ3_SESSAO = " + GEBDBQuote(cSes) + " AND D_E_L_E_T_ = ' '")[1]:N)
    EndIf

    // Verificacao da sessao: 17 genericas + vale (18) + crypto.
    If !(nCup == 18 + IIf(lCrypto, 1, 0)) .And. !(cSt == "FECHADA" .And. nCup >= 18)
        ConOut("SEED_FULL LOJ FAIL cupons " + cValToChar(nCup) + " vendas " + cValToChar(nVen))
        lOk := .F.
    EndIf
    lOk := SF_CNT("GLJ3", "GLJ3_SESSAO = " + GEBDBQuote(cSes) + " AND GLJ3_STATUS = 'CANCELADO'", 1) .And. lOk
    // Uma venda de cada forma obrigatoria na sessao.
    For nI := 1 To 6
        cForma := {"DINHEIRO", "PIX", "DEBITO", "CREDITO", "FIADO", "VALE"}[nI]
        aH := TCSqlQuery("SELECT GLJ5_CUPOM AS C FROM GLJ5 JOIN GLJ3 ON GLJ3_FILIAL = GLJ5_FILIAL AND GLJ3_CUPOM = GLJ5_CUPOM " + ;
            "AND GLJ3.D_E_L_E_T_ = ' ' WHERE GLJ5_FILIAL = " + GEBDBQuote(FWxFilial("GLJ5")) + " AND GLJ5.D_E_L_E_T_ = ' ' AND " + ;
            "GLJ3_SESSAO = " + GEBDBQuote(cSes) + " AND GLJ5_FORMA = " + GEBDBQuote(cForma) + " LIMIT 1")
        If Len(aH) == 0
            ConOut("SEED_FULL LOJ FAIL forma ausente " + cForma)
            lOk := .F.
        EndIf
    Next
    lOk := SF_CNT("GLJ6", "GLJ6_SESSAO = " + GEBDBQuote(cSes), 2) .And. lOk
    // Crypto e' opcional (depende do CoinGecko), mas quando registrada tem que ter carteira.
    If BOVAL(TCSqlQuery("SELECT COUNT(*) AS N FROM GLJ5 JOIN GLJ3 ON GLJ3_FILIAL = GLJ5_FILIAL AND GLJ3_CUPOM = GLJ5_CUPOM " + ;
        "AND GLJ3.D_E_L_E_T_ = ' ' WHERE GLJ5_FILIAL = " + GEBDBQuote(FWxFilial("GLJ5")) + " AND GLJ5.D_E_L_E_T_ = ' ' AND " + ;
        "GLJ3_SESSAO = " + GEBDBQuote(cSes) + " AND GLJ5_FORMA = 'CRYPTO'")[1]:N) > 0
        lCrypto := .T.
        If !SF_HAS("GCK1", "GCK1_MOEDA", "BTC", "")
            ConOut("SEED_FULL LOJ FAIL pagamento crypto sem carteira GCK1")
            lOk := .F.
        EndIf
    EndIf

    // 50 pedidos DEM-PV (2 itens, produtos 21..60): libera e fatura.
    For nI := 1 To 50
        cPed := "DEM-PV-" + StrZero(nI, 3)
        cCli := "DEM-C" + StrZero(((nI - 1) % 40) + 1, 3)
        nP1 := 21 + ((nI - 1) % 40)
        nP2 := 21 + ((nP1 - 21) * 3 + 1) % 40
        If nP2 == nP1
            nP2 := 21 + (nP1 - 20) % 40
        EndIf
        cProd := "DEM-P" + StrZero(nP1, 2)
        cProd2 := "DEM-P" + StrZero(nP2, 2)
        If !SF_HAS("GFT3", "GFT3_NUM", cPed, " AND GFT3_FILIAL = " + GEBDBQuote(FWxFilial("GFT3")))
            aR := GEBFATPED(cPed, cCli, {{cProd, 1 + nI % 4}, {cProd2, 2 + nI % 3}}, "30", 0, "01", dHoje)
            lOk := aR[1] .And. lOk
            If !aR[1]
                ConOut("SEED_FULL LOJ pedido " + cPed + " " + aR[2])
                Loop
            EndIf
        EndIf
        aH := TCSqlQuery("SELECT GFT3_STATUS AS S FROM GFT3 WHERE GFT3_FILIAL = " + GEBDBQuote(FWxFilial("GFT3")) + ;
            " AND GFT3_NUM = " + GEBDBQuote(cPed) + " AND D_E_L_E_T_ = ' '")
        If Len(aH) == 1 .And. (BOCOL(aH[1]:S) == "ABERTO" .Or. BOCOL(aH[1]:S) == "BLOQUEADO")
            aR := GEBFATLIB(cPed)
            If aR[1] .And. aR[3] == "BLOQUEADO"
                ConOut("SEED_FULL LOJ " + cPed + " " + aR[2] + " (liberacao forcada)")
                aR := GEBFATLIB(cPed, .T.)
            EndIf
            lOk := aR[1] .And. lOk
        EndIf
        aH := TCSqlQuery("SELECT GFT3_STATUS AS S FROM GFT3 WHERE GFT3_FILIAL = " + GEBDBQuote(FWxFilial("GFT3")) + ;
            " AND GFT3_NUM = " + GEBDBQuote(cPed) + " AND D_E_L_E_T_ = ' '")
        If Len(aH) == 1 .And. BOCOL(aH[1]:S) == "LIBERADO"
            aR := GEBFATFAT(cPed, {}, dHoje, "")
            lOk := aR[1] .And. lOk
            If !aR[1]
                ConOut("SEED_FULL LOJ faturamento " + cPed + " " + aR[2])
                Loop
            EndIf
            nFat++
            If nFat <= 5
                aAdd(aDev, {aR[3][1], cProd})
            EndIf
        EndIf
    Next

    // 5 devolucoes de venda (1 item de cada uma das 5 primeiras notas).
    For nI := 1 To Len(aDev)
        cNota := aDev[nI][1]
        If !SF_HAS("GFT7", "GFT7_NOTA", cNota, " AND GFT7_FILIAL = " + GEBDBQuote(FWxFilial("GFT7")))
            aR := GEBFATDEV(cNota, {{aDev[nI][2], 1}}, dHoje)
            lOk := aR[1] .And. lOk
            If !aR[1]
                ConOut("SEED_FULL LOJ devolucao " + cNota + " " + aR[2])
            EndIf
        EndIf
    Next

    lOk := SF_CNT("GFT3", "GFT3_NUM LIKE 'DEM-PV-%' AND GFT3_STATUS = 'FATURADO'", 50) .And. lOk
    lOk := SF_CNT("GFT5", "GFT5_PED LIKE 'DEM-PV-%'", 50) .And. lOk
    // Devolucoes: 5 do faturamento + 2 da frente de loja (vale e dinheiro).
    lOk := SF_CNT("GFT7", "GFT7_NOTA IN (SELECT GFT5_NOTA FROM GFT5 WHERE GFT5_PED LIKE 'DEM-PV-%' AND D_E_L_E_T_ = ' ')", 5) .And. lOk
    lOk := SF_CNT("GFT7", "GFT7_NOTA IN (SELECT GLJ3_NOTA FROM GLJ3 WHERE GLJ3_SESSAO = " + GEBDBQuote(cSes) + " AND D_E_L_E_T_ = ' ')", 2) .And. lOk
    ConOut("SEED_FULL loja " + IIf(lOk, "OK", "FAIL") + " cupons=" + cValToChar(nCup) + ;
        " crypto=" + IIf(lCrypto, "S", "N") + " pedidos=50 devolucoes=5")
Return lOk

/*/{Protheus.doc} SF_SN
    Simples Nacional do demo: configura o regime (Anexo I, comercio),
    atividade COM ligada aos 60 produtos, folha/receita externa dos 12
    meses anteriores (RBT12 e Fator R), apura a competencia corrente
    (receita das GF3/GF4 emitidas no mes) e gera o DAS (guia DAS-AAAAMM na
    GD1 + titulo no financeiro + provisao SN_DAS). Reexecutavel: GEBSNCFG,
    ATV, PRD e FOL regravam; a apuracao refaz o mes.
    @type Seed de demonstracao
    @author Peder Munksgaard
    @since 2026-11-02
    @return .T. se apuracao, DAS e contagens forem comprovadas
/*/
Static Function SF_SN()
    Local lOk := .T.
    Local aR := {}
    Local aH := {}
    Local cComp := Left(BOHOJE(), 6)
    Local cCm := ""
    Local cProd := ""
    Local nI := 0

    // Regime SIMPLES + atividade comercio (Anexo I) nos produtos DEM-P.
    // GEBSNCFG regrava GE4: so' configura uma vez.
    If !(GEBCFG("SN_ANEXO") == "I") .Or. !(GEBREGIME() == "SIMPLES")
        aR := GEBSNCFG("I", "")
        lOk := aR[1] .And. lOk
    EndIf
    aR := GEBSNATV("COM", "Comercio varejista", "I")
    lOk := aR[1] .And. lOk
    For nI := 1 To 60
        cProd := "DEM-P" + StrZero(nI, 2)
        If !SF_HAS("GSN7", "GSN7_PROD", cProd, " AND GSN7_FILIAL = " + GEBDBQuote(FWxFilial("GSN7")))
            aR := GEBSNPRD(cProd, "COM", "N", "N")
            lOk := aR[1] .And. lOk
        EndIf
    Next

    // RBT12 e folha dos 12 meses anteriores (receita fora do GEBAN).
    For nI := 1 To 12
        cCm := SF_MESMENOS(cComp, nI)
        aR := GEBSNFOL(cCm, 12500 + nI * 500, 38000 + nI * 1200, "")
        lOk := aR[1] .And. lOk
    Next
    // Folha da competencia corrente (Fator R usa os 12 anteriores, mas o
    // registro do mes compoe a base do proximo).
    aR := GEBSNFOL(cComp, 13200, 0, "")
    lOk := aR[1] .And. lOk

    // Apuracao da competencia: receita = GF4 das notas AUTORIZADAS do mes.
    aR := GEBSNAPU(cComp)
    lOk := aR[1] .And. lOk
    If aR[1]
        ConOut("SEED_FULL SN " + cComp + " anexo " + aR[3][1] + " RBT12 " + cValToChar(aR[3][2]) + ;
            " DAS " + cValToChar(aR[3][5]) + " venc " + aR[3][6])
        If !(aR[3][5] > 0)
            ConOut("SEED_FULL SN FAIL DAS zerado (receita do mes ausente)")
            lOk := .F.
        EndIf
        aH := TCSqlQuery("SELECT GSN2_FATORR AS F FROM GSN2 WHERE GSN2_FILIAL = " + GEBDBQuote(FWxFilial("GSN2")) + ;
            " AND GSN2_COMP = " + GEBDBQuote(cComp) + " AND D_E_L_E_T_ = ' '")
        If Len(aH) == 1
            ConOut("SEED_FULL SN fator_r=" + cValToChar(BOVAL(aH[1]:F)))
        EndIf
    Else
        ConOut("SEED_FULL SN apuracao " + cComp + " " + aR[2])
    EndIf

    lOk := SF_CNT("GSN1", "GSN1_COMP <> ''", 13) .And. lOk
    lOk := SF_CNT("GSN2", "GSN2_COMP = " + GEBDBQuote(cComp), 1) .And. lOk
    lOk := SF_CNT("GSN3", "GSN3_COD = 'COM'", 1) .And. lOk
    lOk := SF_CNT("GSN7", "LEFT(GSN7_PROD, 5) = 'DEM-P'", 60) .And. lOk
    lOk := SF_CNT("GD1", "GD1_GUIA = 'DAS-" + cComp + "'", 1) .And. lOk
    lOk := SF_CNT("GFN3", "GFN3_DOC = 'DAS-" + cComp + "'", 1) .And. lOk
    ConOut("SEED_FULL simples " + IIf(lOk, "OK", "FAIL"))
Return lOk

/*/{Protheus.doc} SF_DER
    Derrama do demo: cadastro de retencoes (ISS, IRRF, INSS, PIS, COFINS,
    CSLL), retencao aplicada em 3 notas de entrada DEM-NF (abate os titulos
    do fornecedor e acumula guias RET-<TRIB>-<comp> com titulo a pagar),
    guia extra DEM-GD-ICMS vencida paga com juros, e pagamento do DAS da
    competencia. Idempotente: retencao por documento e guia so nascem uma
    vez; GEBDERPAGA reconhece guia ja baixada.
    @type Seed de demonstracao
    @author Peder Munksgaard
    @since 2026-11-02
    @return .T. se retencoes, guias e baixas forem comprovadas
/*/
Static Function SF_DER()
    Local lOk := .T.
    Local aR := {}
    Local aH := {}
    Local aT := {}
    Local aTit := {}
    Local aRegs := {{"DEM-ISS", "ISS", 5, "ISS retido servico"}, {"DEM-IRRF", "IRRF", 1.5, "IRRF retido servico"}, ;
        {"DEM-INSS", "INSS", 11, "INSS retido servico"}, {"DEM-PIS", "PIS", 0.65, "PIS retido"}, ;
        {"DEM-COF", "COFINS", 3, "COFINS retida"}, {"DEM-CSLL", "CSLL", 1, "CSLL retida"}}
    Local aCombo := {{"DEM-ISS", "DEM-IRRF"}, {"DEM-INSS", "DEM-IRRF"}, {"DEM-PIS", "DEM-COF", "DEM-CSLL"}}
    Local cComp := Left(BOHOJE(), 6)
    Local cDoc := ""
    Local cForn := ""
    Local cFilQ := GEBDBQuote(FWxFilial("GFN3"))
    Local dHoje := BOHOJE()
    Local nI := 0
    Local nJ := 0
    Local nBase := 0

    // Regras de retencao DEM (regrava a mesma linha, sem historico).
    For nI := 1 To Len(aRegs)
        aR := GEBRETCAD(aRegs[nI][1], aRegs[nI][2], aRegs[nI][3], aRegs[nI][4])
        lOk := aR[1] .And. lOk
    Next

    // Retencao sobre 3 notas de entrada com titulos a pagar abertos.
    aH := TCSqlQuery("SELECT DISTINCT LEFT(GFN3_DOC, 10) AS D FROM GFN3 WHERE GFN3_FILIAL = " + cFilQ + ;
        " AND GFN3_DOC LIKE 'DEM-NF-%' AND GFN3_STATUS = 'ABERTO' AND D_E_L_E_T_ = ' ' ORDER BY D LIMIT 3")
    For nI := 1 To Len(aH)
        cDoc := BOCOL(aH[nI]:D)
        If nI > Len(aCombo) .Or. SF_HAS("GRT2", "GRT2_DOC", cDoc, " AND GRT2_FILIAL = " + cFilQ)
            Loop
        EndIf
        aT := TCSqlQuery("SELECT GFN3_DOC AS D, GFN3_FORN AS F, GFN3_VENC AS V, GFN3_SALDO AS S FROM GFN3 WHERE GFN3_FILIAL = " + ;
            cFilQ + " AND LEFT(GFN3_DOC, 10) = " + GEBDBQuote(cDoc) + " AND GFN3_STATUS = 'ABERTO' AND D_E_L_E_T_ = ' '")
        If Len(aT) == 0
            Loop
        EndIf
        aTit := {}
        nBase := 0
        cForn := BOCOL(aT[1]:F)
        For nJ := 1 To Len(aT)
            aAdd(aTit, {BOCOL(aT[nJ]:D), BOCOL(aT[nJ]:V), BOVAL(aT[nJ]:S)})
            nBase := nBase + BOVAL(aT[nJ]:S)
        Next
        aR := GEBRETVAL(aCombo[nI])
        lOk := aR[1] .And. lOk
        If aR[1]
            aR := GEBRETAPL(cDoc, cForn, nBase, aR[3], dHoje, aTit)
            lOk := aR[1] .And. lOk
            ConOut("SEED_FULL DER retencao " + cDoc + " " + aR[2])
        EndIf
    Next

    // Guia vencida de tributo paga com juros (caminho GD1 + GFN3 + baixa).
    aR := GEBDERGUIA("DEM-GD-ICMS", "ICMS", cComp, 1450, BODTADD(dHoje, -20), "2.01.006", "FISCO")
    lOk := aR[1] .And. lOk
    If aR[1]
        aH := TCSqlQuery("SELECT GD1_JUROS AS J FROM GD1 WHERE GD1_FILIAL = " + GEBDBQuote(FWxFilial("GD1")) + ;
            " AND GD1_GUIA = 'DEM-GD-ICMS' AND GD1_STATUS = 'ABERTA' AND D_E_L_E_T_ = ' '")
        If Len(aH) == 1 .And. BOVAL(aH[1]:J) == 0
            lOk := GEBDJUR("DEM-GD-ICMS", 20) > 1450 .And. lOk
        EndIf
        aR := GEBDERPAGA("DEM-GD-ICMS", "BANCO", dHoje)
        lOk := aR[1] .And. lOk
        If !aR[1]
            ConOut("SEED_FULL DER paga DEM-GD-ICMS " + aR[2])
        EndIf
    EndIf

    // Pagamento do DAS da competencia (o titulo sai do BANCO).
    aR := GEBDERPAGA("DAS-" + cComp, "BANCO", dHoje)
    lOk := aR[1] .And. lOk
    If !aR[1]
        ConOut("SEED_FULL DER paga DAS " + aR[2])
    EndIf

    lOk := SF_CNT("GRT1", "LEFT(GRT1_COD, 4) = 'DEM-'", 6) .And. lOk
    lOk := SF_CNT("GRT2", "LEFT(GRT2_DOC, 6) = 'DEM-NF'", 7) .And. lOk
    lOk := SF_CNT("GD1", "GD1_COMP = " + GEBDBQuote(cComp) + " AND (GD1_GUIA LIKE 'RET-%' OR GD1_GUIA IN ('DAS-" + cComp + "', 'DEM-GD-ICMS'))", 8) .And. lOk
    lOk := SF_CNT("GD1", "GD1_STATUS = 'BAIXADA' AND GD1_GUIA IN ('DAS-" + cComp + "', 'DEM-GD-ICMS')", 2) .And. lOk
    ConOut("SEED_FULL derrama " + IIf(lOk, "OK", "FAIL"))
Return lOk

/*/{Protheus.doc} SF_CTB
    Fechamento contabil do demo: 3 lancamentos manuais DEM-CTB (despesas e
    receita financeira com centro de custo; os lancamentos das vendas,
    compras, financeiro e DAS ja foram gerados pelos modulos via GEBCTXLP)
    e prova do balancete (debitos = creditos) e da DRE (receita bruta > 0)
    na competencia corrente com GEBCTXBALAN/GEBCTXDRE.
    @type Seed de demonstracao
    @author Peder Munksgaard
    @since 2026-11-02
    @return .T. se os lancamentos e o fechamento forem comprovados
/*/
Static Function SF_CTB()
    Local lOk := .T.
    Local lFech := .F.
    Local aR := {}
    Local aPar := {}
    Local aLanc := {{"DEM-CTB-001", 250, "4.02.006", "1.01.002", "DEM-CC01"}, ;
        {"DEM-CTB-002", 380, "1.01.002", "3.01.002", "DEM-CC05"}, ;
        {"DEM-CTB-003", 72, "4.02.006", "1.01.002", "DEM-CC02"}}
    Local cComp := Left(BOHOJE(), 6)
    Local dHoje := BOHOJE()
    Local nI := 0
    Local nRB := 0
    Local nRes := 0
    Local nDeb := 0
    Local nCre := 0

    // Lancamentos manuais (um so; GC2_ORIGEM marca o documento).
    For nI := 1 To Len(aLanc)
        If !SF_HAS("GC2", "GC2_ORIGEM", "DEMLP:" + aLanc[nI][1], " AND GC2_FILIAL = " + GEBDBQuote(FWxFilial("GC2")))
            aR := GEBCTXLP("DEMLP", aLanc[nI][2], aLanc[nI][1], dHoje, aLanc[nI][3], aLanc[nI][4], aLanc[nI][5])
            lOk := aR[1] .And. lOk
            If !aR[1]
                ConOut("SEED_FULL CTB " + aLanc[nI][1] + " " + aR[2])
            EndIf
        EndIf
    Next

    // Despesas proporcionais ao volume do demo (250 administrativo + 72 loja).
    // Bases antigas: corrige o excesso por contrapartida, sem alterar o historico.
    // As 50 receitas/CMVs do faturamento ja sao lancadas pelo GEBFATFAT.
    For nI := 1 To Len(aLanc)
        If aLanc[nI][3] == "4.02.006"
            aPar := TCSqlQuery("SELECT GC2_VALOR AS V, GC2_DATA AS DT FROM GC2 WHERE D_E_L_E_T_ = ' ' AND GC2_FILIAL = " + ;
                GEBDBQuote(FWxFilial("GC2")) + " AND GC2_ORIGEM = " + GEBDBQuote("DEMLP:" + aLanc[nI][1]))
            If Len(aPar) == 1 .And. BOVAL(aPar[1]:V) > aLanc[nI][2]
                If !SF_HAS("GC2", "GC2_ORIGEM", "DEMAJUSTE:" + aLanc[nI][1], " AND GC2_FILIAL = " + GEBDBQuote(FWxFilial("GC2")))
                    aR := GEBCTXLP("DEMAJUSTE", Round(BOVAL(aPar[1]:V) - aLanc[nI][2], 2), aLanc[nI][1], ;
                        BOCOL(aPar[1]:DT), aLanc[nI][4], aLanc[nI][3], aLanc[nI][5])
                    lOk := aR[1] .And. lOk
                    If !aR[1]
                        ConOut("SEED_FULL CTB ajuste despesa " + aR[2])
                    EndIf
                EndIf
            EndIf
        EndIf
    Next

    // Balancete do mes: fechado exige debitos = creditos no periodo.
    aR := GEBCTXBALAN(cComp + "01", dHoje, "")
    lOk := aR[1] .And. lOk
    If aR[1]
        aPar := aR[3][2]
        For nI := 1 To Len(aPar)
            If aPar[nI][1] == "fechado" .And. aPar[nI][2] == "S"
                lFech := .T.
            EndIf
            If aPar[nI][1] == "debitos"
                nDeb := aPar[nI][2]
            EndIf
            If aPar[nI][1] == "creditos"
                nCre := aPar[nI][2]
            EndIf
        Next nI
        ConOut("SEED_FULL CTB balancete " + cComp + " debitos=" + cValToChar(nDeb) + ;
            " creditos=" + cValToChar(nCre) + " fechado=" + IIf(lFech, "S", "N"))
        If !lFech
            lOk := .F.
        EndIf
    Else
        ConOut("SEED_FULL CTB balancete " + aR[2])
    EndIf

    // DRE do mes: receita bruta e resultado positivos para a demonstracao.
    aR := GEBCTXDRE(cComp + "01", dHoje, "")
    lOk := aR[1] .And. lOk
    If aR[1]
        For nI := 1 To Len(aR[3])
            If aR[3][nI][1] == "receita_bruta"
                nRB := aR[3][nI][2]
            EndIf
            If aR[3][nI][1] == "resultado"
                nRes := aR[3][nI][2]
            EndIf
        Next nI
        ConOut("SEED_FULL CTB dre " + cComp + " receita_bruta=" + cValToChar(nRB) + " resultado=" + cValToChar(nRes))
        If !(nRB > 0) .Or. !(nRes > 0)
            ConOut("SEED_FULL CTB FAIL DRE exige receita e resultado positivos no mes")
            lOk := .F.
        EndIf
    Else
        ConOut("SEED_FULL CTB dre " + aR[2])
    EndIf

    lOk := SF_CNT("GC2", "GC2_ORIGEM LIKE 'DEMLP:DEM-CTB-%'", 3) .And. lOk
    ConOut("SEED_FULL contabil " + IIf(lOk, "OK", "FAIL"))
Return lOk

/*/{Protheus.doc} SF_PDV
    PDV pronto para demo: liga a NFC-e no caixa (GE4 DFE_NFCE=S, serie 99,
    QR v3; CSC de demonstracao preenchido so' para o QR v2), confere a
    pasta persistente do certificado (SF_CERTBASE, usada por SF_FIS),
    cadastra codigo de barras EAN-13 dos 60 produtos DEM-P (GLJ8), wallets
    BTC/USDT ativas (GCK1) e faz UMA venda regime FISCAL paga em dinheiro
    com codigo de barras — prova ponta a ponta: GEBLOJVEN -> GEBDFENFCE ->
    SEFAZ emuladora. Idempotente: barcode, wallet e a venda so' nascem
    uma vez (a NFC-e do caixa e' reconhecida por GDF5_DOC 'CP%').
    @type Seed de demonstracao
    @author Peder Munksgaard
    @since 2026-11-27
    @return .T. se parametros, cadastros e a NFC-e autorizada forem comprovados
/*/
Static Function SF_PDV()
    Local lOk := .T.
    Local aR := {}
    Local aH := {}
    Local cSes := ""
    Local cCup := ""
    Local cNota := ""
    Local cSt := ""
    Local cEan := ""
    Local cProd := ""
    Local cFilQ := GEBDBQuote(FWxFilial("GDF5"))
    Local dHoje := BOHOJE()
    Local nI := 0
    Local nTot := 0

    // GE4 e' versionado: SF_SET so' grava quando o valor muda e BOPARM ja'
    // devolve a linha ativa — o historico com valores antigos nao atrapalha.
    lOk := SF_SET("DFE_NFCE", "S") .And. lOk
    lOk := SF_SET("DFE_SERIE_65", "99") .And. lOk
    lOk := SF_SET("DFE_QR_VERSAO", "3") .And. lOk
    // CSC so' entra no QR Code v2; valores demo permitem trocar de versao
    // sem novo cadastro no portal da SEFAZ.
    lOk := SF_SET("DFE_CSC_ID", "1") .And. lOk
    lOk := SF_SET("DFE_CSC", "geban-demo-csc-nao-usar-em-producao") .And. lOk
    lOk := SF_SET("DFE_CERT_DIR", SF_CERTBASE()) .And. lOk

    // TEF Cielo: a linha ativa do GE4 tem que ser o emulador :18765 (o
    // historico versionado pode ter valores antigos; BOPARM ja' resolve).
    If !(BOPARM("LOJ_CIELO_URL", "") == "http://127.0.0.1:18765")
        ConOut("SEED_FULL PDV aviso LOJ_CIELO_URL=" + BOPARM("LOJ_CIELO_URL", "") + " vigente deveria ser http://127.0.0.1:18765")
    EndIf

    // Codigo de barras EAN-13 com digito verificado dos 60 produtos DEM-P.
    For nI := 1 To 60
        cProd := "DEM-P" + StrZero(nI, 2)
        cEan := SF_EAN13(nI)
        If !SF_HAS("GLJ8", "GLJ8_COD", cEan, " AND GLJ8_FILIAL = " + GEBDBQuote(FWxFilial("GLJ8")))
            aR := GEBLOJBAR(cEan, cProd, 1)
            lOk := aR[1] .And. lOk
            If !aR[1]
                ConOut("SEED_FULL PDV barcode " + cEan + " " + aR[2])
            EndIf
        EndIf
    Next

    // Wallets crypto ativas com enderecos de demonstracao (GEBCRYWAL sempre
    // regrava: so' chama quando a moeda nao tem wallet ativa).
    If !SF_HAS("GCK1", "GCK1_MOEDA", "BTC", " AND GCK1_ATIVO = 'S' AND GCK1_FILIAL = " + GEBDBQuote(FWxFilial("GCK1")))
        lOk := GEBCRYWAL("BTC", "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa", "S")[1] .And. lOk
    EndIf
    If !SF_HAS("GCK1", "GCK1_MOEDA", "USDT", " AND GCK1_ATIVO = 'S' AND GCK1_FILIAL = " + GEBDBQuote(FWxFilial("GCK1")))
        lOk := GEBCRYWAL("USDT", "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb", "S")[1] .And. lOk
    EndIf

    // Prova PDV: uma venda regime FISCAL paga em dinheiro com codigo de
    // barras — GEBLOJVEN resolve o EAN via GLJ8 e emite a NFC-e (DFE_NFCE=S).
    // NFC-e emitida pelo caixa tem GDF5_DOC = cupom ("CP..."); as DEM-65-*
    // do SF_FIS tambem gravam origem LOJA, entao o discriminador e' o doc.
    aH := TCSqlQuery("SELECT COUNT(*) AS N FROM GDF5 WHERE D_E_L_E_T_ = ' ' AND GDF5_FILIAL = " + cFilQ + ;
        " AND GDF5_MOD = '65' AND GDF5_DOC LIKE 'CP%'")
    If BOVAL(aH[1]:N) == 0
        aR := GEBLOJABRE("01", "DEM_CAIXA1", 200, dHoje)
        lOk := aR[1] .And. lOk
        If aR[1]
            cSes := aR[3]
            cProd := "DEM-P01"
            cEan := SF_EAN13(1)
            nTot := Round(2 * SF_PRC(cProd), 2)
            aR := GEBLOJVEN(cSes, {{cEan, 2, 0}}, {{"DINHEIRO", nTot + 20}}, "", 0, "", "", "", "", "", "FISCAL")
            If !aR[1]
                ConOut("SEED_FULL PDV venda " + aR[2])
                lOk := .F.
            Else
                cCup := aR[3][1]
                cNota := BOCOL(aR[3][4])
                cSt := BOCOL(aR[3][5])
                ConOut("SEED_FULL PDV cupom " + cCup + " total=" + cValToChar(nTot) + " regime=FISCAL status=" + cSt)
                aH := TCSqlQuery("SELECT GDF5_STATUS AS S, GDF5_PROT AS P, GDF5_QR AS Q FROM GDF5 WHERE D_E_L_E_T_ = ' ' AND " + ;
                    "GDF5_FILIAL = " + cFilQ + " AND GDF5_CHAVE = " + GEBDBQuote(cNota))
                If Len(aH) == 1 .And. BOCOL(aH[1]:S) == "CONTINGENCIA"
                    // SEFAZ fora do ar na hora: transmite as pendentes e rele.
                    GEBDFETRANSMITE()
                    aH := TCSqlQuery("SELECT GDF5_STATUS AS S, GDF5_PROT AS P, GDF5_QR AS Q FROM GDF5 WHERE D_E_L_E_T_ = ' ' AND " + ;
                        "GDF5_FILIAL = " + cFilQ + " AND GDF5_CHAVE = " + GEBDBQuote(cNota))
                EndIf
                If Len(aH) != 1 .Or. !(BOCOL(aH[1]:S) == "AUTORIZADA")
                    ConOut("SEED_FULL PDV FAIL NFC-e nao autorizada: " + cNota)
                    lOk := .F.
                Else
                    ConOut("SEED_FULL PDV NFC-e autorizada chave=" + cNota + " protocolo=" + BOCOL(aH[1]:P) + ;
                        " qr=" + IIf(BOCOL(aH[1]:Q) == "", "VAZIO", "ok"))
                EndIf
            EndIf
            aR := GEBLOJFECHA(cSes, GEBLOJESP(cSes))
            lOk := aR[1] .And. lOk
            If !aR[1]
                ConOut("SEED_FULL PDV fecha sessao " + cSes + " " + aR[2])
            EndIf
        EndIf
    Else
        ConOut("SEED_FULL PDV NFC-e de loja ja existe (" + cValToChar(BOVAL(aH[1]:N)) + "): venda PDV preservada")
    EndIf

    lOk := SF_CNT("GLJ8", "GLJ8_FILIAL = " + GEBDBQuote(FWxFilial("GLJ8")) + " AND LEFT(GLJ8_PROD, 5) = 'DEM-P'", 60) .And. lOk
    lOk := SF_CNT("GCK1", "GCK1_FILIAL = " + GEBDBQuote(FWxFilial("GCK1")) + " AND GCK1_MOEDA IN ('BTC','USDT') AND GCK1_ATIVO = 'S'", 2) .And. lOk
    ConOut("SEED_FULL pdv " + IIf(lOk, "OK", "FAIL"))
Return lOk

// Pasta persistente dos certificados do demo: ~/.geban-demo/cert
// (sobrevive a reboot; o /tmp/geban-seed-full era efemero). GEBDFECERTDIR
// completa o caminho com <tenant>/<filial> na hora de instalar/ler.
Static Function SF_CERTBASE()
    Local cHome := AllTrim(BOSTR(GetEnv("HOME")))
    If cHome == ""
        cHome := "/tmp"
    EndIf
Return cHome + "/.geban-demo/cert"

// EAN-13 do item nI do seed: "789" + sequencial de 9 digitos + digito
// verificador (modulo 10, pesos 3 e 1 — mesmo algoritmo de GEBLOJEANOK).
Static Function SF_EAN13(nI)
    Local cBase := "789" + StrZero(nI, 9)
    Local nSoma := 0
    Local nPeso := 3
    Local nJ := 0
    For nJ := Len(cBase) To 1 Step -1
        nSoma := nSoma + Val(SubStr(cBase, nJ, 1)) * nPeso
        nPeso := 4 - nPeso
    Next nJ
Return cBase + cValToChar(BOMOD(10 - BOMOD(nSoma, 10), 10))

// Preco PADRAO do produto (GFT2); 0 se ausente.
Static Function SF_PRC(cProd)
    Local aH := TCSqlQuery("SELECT GFT2_PRECO AS P FROM GFT2 WHERE GFT2_FILIAL = " + GEBDBQuote(FWxFilial("GFT2")) + ;
        " AND GFT2_PROD = " + GEBDBQuote(cProd) + " AND GFT2_TAB = 'PADRAO' AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aH) == 0
        Return 0
    EndIf
Return Round(BOVAL(aH[1]:P), 2)

// Competencia AAAAMM menos nMeses meses.
Static Function SF_MESMENOS(cComp, nMeses)
    Local nA := Val(Left(cComp, 4))
    Local nM := Val(SubStr(cComp, 5, 2)) - nMeses
    While nM <= 0
        nM := nM + 12
        nA := nA - 1
    EndDo
Return StrZero(nA, 4) + StrZero(nM, 2)

// Configuracao fiscal DEM: compara os parametros antes de versionar GE4.
Static Function SF_CFGDEMO()
    Local aCfg := {{"DFE_SERIE_55", "99"}, {"DFE_SERIE_65", "99"}, {"DFE_QR_VERSAO", "3"}, ;
        {"DFE_EFD_CONT_NOME", "Contabilidade Demo"}, {"DFE_EFD_CONT_CPF", "11144477735"}, ;
        {"DFE_EFD_CONT_CRC", "1SP123456"}, {"DFE_EFD_CONT_EMAIL", "contab@example.com"}, ;
        {"DFE_EFD_CONT_MUN", "3550308"}, {"DFE_EFD_PERFIL", "B"}, {"DFE_EFD_COD_REC", "046-2"}}
    Local nI := 0
    For nI := 1 To Len(aCfg)
        If !(BOPARM(aCfg[nI][1], "") == aCfg[nI][2])
            Return .T.
        EndIf
    Next
Return .F.

// De-para fiscal: a rotina oficial versiona mesmo o valor igual.
Static Function SF_DEPARA(cForn, cProdForn, cProd, nFator)
    Local aH := TCSqlQuery("SELECT GDFF_PROD AS P, GDFF_FATOR AS F FROM GDFF WHERE D_E_L_E_T_ = ' ' AND GDFF_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GDFF")) + " AND GDFF_FORN = " + GEBDBQuote(cForn) + " AND GDFF_CPROD = " + GEBDBQuote(cProdForn) + " LIMIT 1")
    If Len(aH) > 0 .And. BOCOL(aH[1]:P) == cProd .And. BOVAL(aH[1]:F) == nFator
        Return {.T., "de-para preservado: " + cProdForn + " -> " + cProd}
    EndIf
Return GEBDFEDEPARA(cForn, cProdForn, cProd, nFator)

Static Function SF_FCHK(cEtapa, aR)
    ConOut("SEED_FULL FIS " + cEtapa + " " + aR[2])
Return aR[1]

// BOSETPARM versiona linhas: nao gerar historico quando o valor ja e igual.
Static Function SF_SET(cChave, cValor)
    If BOPARM(cChave, "") == cValor
        Return .T.
    EndIf
Return BOSETPARM(cChave, cValor)

// Identificadores e filtros sao internos constantes, valores passam por quote.
Static Function SF_HAS(cTab, cCampo, cValor, cFiltro)
Return Len(TCSqlQuery("SELECT " + cCampo + " FROM " + cTab + " WHERE " + cCampo + " = " + GEBDBQuote(cValor) + ;
    " AND D_E_L_E_T_ = ' '" + cFiltro + " LIMIT 1")) > 0

Static Function SF_CNT(cTab, cFiltro, nEsperado)
    Local aHit := TCSqlQuery("SELECT R_E_C_N_O_ FROM " + cTab + " WHERE D_E_L_E_T_ = ' ' AND " + cFiltro)
    Local lOk := Len(aHit) == nEsperado
    ConOut("SEED_FULL " + cTab + "=" + cValToChar(Len(aHit)) + "/" + cValToChar(nEsperado))
Return lOk
