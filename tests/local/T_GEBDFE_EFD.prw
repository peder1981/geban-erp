#include "totvs.ch"
#include "../../src/GEBDB_CORE.prw"
#include "../../src/GENUC_MIG.prw"
#include "../../src/GEBBOLIB.prw"
#include "../../src/GEBDFE_XML.prw"
#include "../../src/GEBDFE_EFD.prw"

/*/{Protheus.doc} T_GEBDFE_EFD
    Teste local (sem banco) do montador da EFD ICMS/IPI: notas montadas
    pelo motor real (NF-e interestadual, DIFAL, ST, NFC-e, cancelada,
    inutilizada e nota de fornecedor com de-para e conversao de unidade);
    confere a apuracao e grava ../.out/local/efd.txt para o script validar
    leiaute, contagens e somas.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function T_GEBDFE_EFD()
    Local lOk := .T.
    Local aDocs := {}
    Local aR := {}
    Local oP := JsonObject():New()
    Local oNF := Nil
    Local oI := Nil

    // A: venda interestadual a contribuinte (ICMS 12% de 800).
    oNF := NFe(1, Dest("11222333000181", "", "RJ", "3304557", "1"), Item("BAN01", "6102", "00", 12, 10, 80))
    aAdd(aDocs, Doc(oNF, "00"))
    // B: venda a consumidor final de outra UF (DIFAL 20% + FCP 2%).
    oNF := NFe(2, Dest("", "11144477735", "RJ", "3304557", "9"), Item("TV01", "6108", "00", 12, 1, 1000))
    oNF["INDFINAL"] := "1"
    oNF["DIFAL"] := {20, 2, .F.}
    aAdd(aDocs, Doc(oNF, "00"))
    // C: venda interna com ST (MVA 40%).
    oI := Item("CERV", "5401", "10", 18, 1, 100)
    oI["MVA"] := 40
    oI["PICMSST"] := 18
    oNF := NFe(3, Dest("11444777000161", "", "SP", "3550308", "1"), oI)
    oNF["IDDEST"] := "1"
    aAdd(aDocs, Doc(oNF, "00"))
    // D: cancelada.
    aAdd(aDocs, Doc(NFe(4, Dest("11222333000181", "", "RJ", "3304557", "1"), Item("BAN01", "6102", "00", 12, 1, 80)), "02"))
    // E: NFC-e (18% de 20).
    oNF := NFe(5, Nil, Item("PAO", "5102", "00", 18, 2, 10))
    oNF["MOD"] := "65"
    oNF["IDDEST"] := "1"
    aAdd(aDocs, Doc(oNF, "00"))
    // F: numero inutilizado da NFC-e.
    aAdd(aDocs, {"", "05", .T., "", {}, "65", "1", "6", ""})
    // G: nota do fornecedor (caixa de 12 com credito; KG isento sem credito).
    oNF := NFe(77, Dest("12345678000195", "", "SP", "3550308", "1"), Item("FORN-CX", "5102", "00", 18, 2, 60))
    oNF["ITENS"] := {oNF["ITENS"][1], Item("FORN-KG", "5102", "40", 0, 5, 4)}
    oNF["ITENS"][1]["UCOM"] := "CX"
    oNF["ITENS"][2]["UCOM"] := "KG"
    oNF["EMIT"]["CNPJ"] := "11444777000161"
    oNF["EMIT"]["XNOME"] := "Fornecedor Atacadista SA"
    oNF["IDDEST"] := "1"
    aR := GEBDFEMONTA(oNF)
    aAdd(aDocs, {aR[3][1], "00", .F., "20261015", {{"P1", 12}, {"P2", 1}}, "55", "", "", aR[3][2]})

    oP["COMP"] := "202610"
    oP["FIN"] := "0"
    oP["CODVER"] := GEBDFEEFDVER("202610")
    oP["PERFIL"] := "A"
    oP["ATIV"] := "1"
    oP["COD_REC"] := "046-2"
    oP["COD_REC_ST"] := "063-2"
    oP["COD_REC_DIFAL"] := "100102"
    oP["COD_REC_FCP"] := "100129"
    oP["DIA_VENC"] := 20
    oP["SLD_CRED_ANT"] := 10
    oP["CONT"] := {"Maria Contadora", "111.444.777-35", "1SP123456", "", "01001000", "Rua C", "5", "", "Centro", "1133334444", "", ;
        "contab@exemplo.com.br", "3550308"}
    oP["ITENS"] := {{"P1", "Banana prata unidade", "UN", "", "08039000", ""}, {"P2", "Maca kg", "KG", "7891234567895", "08081000", ""}}

    lOk := Chk(lOk, "versao do leiaute", GEBDFEEFDVER("202610") == "020" .And. GEBDFEEFDVER("202512") == "019" .And. GEBDFEEFDVER("202701") == "021")
    aR := GEBDFEEFDTXT(Emit(), oP, aDocs)
    lOk := Chk(lOk, "gerou", aR[1])
    ConOut("    " + aR[2])
    lOk := Chk(lOk, "debitos 96+120+18+3,60", Round(aR[4][1], 2) == 237.6)
    lOk := Chk(lOk, "creditos so' do item tributado", Round(aR[4][2], 2) == 21.6)
    lOk := Chk(lOk, "a recolher com saldo anterior", Round(aR[4][3], 2) == 206 .And. aR[4][4] == 0)
    lOk := Chk(lOk, "documentos", aR[4][5] == 7)
    lOk := Chk(lOk, "C100 cancelada so' identificacao", "|C100|1|0||55|02|1|4|" $ aR[3])
    lOk := Chk(lOk, "C100 inutilizada", "|C100|1|0||65|05|1|6||" $ aR[3])
    lOk := Chk(lOk, "C101 DIFAL", "|C101|20,00|80,00|0,00|" $ aR[3])
    lOk := Chk(lOk, "E250 ST na UF", "|E250|002|7,20|20112026|063-2|" $ aR[3])
    lOk := Chk(lOk, "E316 DIFAL e FCP", "|E316|000|80,00|" $ aR[3] .And. "|E316|006|20,00|" $ aR[3])
    lOk := Chk(lOk, "E116 a recolher", "|E116|000|206,00|20112026|046-2|||||102026|" $ aR[3])
    lOk := Chk(lOk, "0220 caixa com 12", "|0220|CX|12,000000||" $ aR[3])
    lOk := Chk(lOk, "C170 com cfop de entrada", "|C170|1|P1|" $ aR[3] .And. "|1102|" $ aR[3])
    MemoWrite("../.out/local/efd.txt", aR[3])

    // Saldo credor transportado.
    oP["SLD_CRED_ANT"] := 300
    aR := GEBDFEEFDTXT(Emit(), oP, aDocs)
    lOk := Chk(lOk, "saldo credor a transportar", aR[4][3] == 0 .And. Round(aR[4][4], 2) == 84)
    If lOk
        ConOut("T_GEBDFE_EFD PASS")
    Else
        ConOut("T_GEBDFE_EFD FAIL")
    EndIf
Return lOk

Static Function Doc(oNF, cSit)
    Local aR := GEBDFEMONTA(oNF)
    If !aR[1]
        ConOut("    montagem: " + aR[2])
        Return {"", cSit, .T., "", {}, oNF["MOD"], "1", cValToChar(oNF["NNF"]), ""}
    EndIf
Return {aR[3][1], cSit, .T., "", {}, oNF["MOD"], "1", cValToChar(oNF["NNF"]), aR[3][2]}

Static Function Chk(lOk, cNome, lCond)
    If lCond
        ConOut("  OK " + cNome)
        Return lOk
    EndIf
    ConOut("  FAIL: " + cNome)
Return .F.

Static Function Emit()
    Local oE := JsonObject():New()
    oE["CNPJ"] := "12345678000195"
    oE["XNOME"] := "Empresa Teste Ltda"
    oE["XFANT"] := "Loja Teste"
    oE["XLGR"] := "Rua das Bananeiras"
    oE["NRO"] := "100"
    oE["XBAIRRO"] := "Centro"
    oE["CMUN"] := "3550308"
    oE["XMUN"] := "SAO PAULO"
    oE["UF"] := "SP"
    oE["CEP"] := "01001000"
    oE["FONE"] := "1133334444"
    oE["IE"] := "123456789012"
    oE["IM"] := ""
    oE["EMAIL"] := "loja@exemplo.com.br"
    oE["CRT"] := "3"
Return oE

Static Function Dest(cCNPJ, cCPF, cUF, cMun, cIndIE)
    Local oD := JsonObject():New()
    If !(cCNPJ == "")
        oD["CNPJ"] := cCNPJ
        oD["IE"] := "12345678"
    Else
        oD["CPF"] := cCPF
    EndIf
    oD["XNOME"] := "Cliente " + cUF + " & Cia"
    oD["XLGR"] := "Av Brasil"
    oD["NRO"] := "1"
    oD["XBAIRRO"] := "Jardim"
    oD["CMUN"] := cMun
    oD["XMUN"] := "CIDADE"
    oD["UF"] := cUF
    oD["CEP"] := "20000000"
    oD["INDIEDEST"] := cIndIE
Return oD

Static Function Item(cProd, cCfop, cCst, nAliq, nQtd, nPreco)
    Local oI := JsonObject():New()
    oI["CPROD"] := cProd
    oI["CEAN"] := ""
    oI["XPROD"] := "Produto " + cProd
    oI["NCM"] := "08039000"
    oI["CFOP"] := cCfop
    oI["UCOM"] := "UN"
    oI["QCOM"] := nQtd
    oI["VUNCOM"] := nPreco
    oI["VDESC"] := 0
    oI["ORIG"] := "0"
    oI["CSOSN"] := ""
    oI["CST"] := cCst
    oI["PICMS"] := nAliq
    oI["PISCST"] := "01"
    oI["PPIS"] := 1.65
    oI["COFINSCST"] := "01"
    oI["PCOFINS"] := 7.6
Return oI

Static Function NFe(nNum, oD, oI)
    Local oNF := JsonObject():New()
    Local oP := JsonObject():New()
    oP["TPAG"] := "01"
    oP["VPAG"] := 5000
    oNF["MOD"] := "55"
    oNF["SERIE"] := 1
    oNF["NNF"] := nNum
    oNF["CNF"] := "12345678"
    oNF["TPEMIS"] := "1"
    oNF["DHEMI"] := "2026-10-10T10:15:30-03:00"
    oNF["TPAMB"] := "2"
    oNF["NATOP"] := "Venda de mercadoria"
    oNF["CMUNFG"] := "3550308"
    oNF["IDDEST"] := "2"
    oNF["INDFINAL"] := "0"
    oNF["INDPRES"] := "1"
    oNF["EMIT"] := Emit()
    If !(oD == Nil)
        oNF["DEST"] := oD
    EndIf
    oNF["ITENS"] := {oI}
    oNF["PAG"] := {oP}
Return oNF
