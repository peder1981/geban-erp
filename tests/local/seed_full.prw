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
    // Proximas etapas: SF_FIS(), SF_FIN(), SF_CTB(), SF_LOJ().
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
