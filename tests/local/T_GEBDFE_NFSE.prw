#include "totvs.ch"
#include "../../src/GEBDB_CORE.prw"
#include "../../src/GENUC_MIG.prw"
#include "../../src/GEBBOLIB.prw"
#include "../../src/GEBDFE_XML.prw"
#include "../../src/GEBDFE_NFSE.prw"

/*/{Protheus.doc} T_GEBDFE_NFSE
    Teste local (sem banco) da NFS-e nacional: monta e assina a DPS (Simples
    com tomador PJ e desconto; regime normal com ISS retido e sem tomador) e
    o pedido de cancelamento, e grava em ../.out/local para o
    T_GEBDFE_NFSE.sh validar contra os XSD oficiais (v1.01) e conferir a
    assinatura.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function T_GEBDFE_NFSE()
    Local cDir := "../.out/local/"
    Local cKey := MemoRead(cDir + "key.pem")
    Local cCert := MemoRead(cDir + "cert.pem")
    Local lOk := .T.
    Local oD := Nil
    Local oE := JsonObject():New()
    Local oT := JsonObject():New()
    Local aA := {}
    Local cId := GEBDFEDPSID("3550308", "12345678000195", 1, 27)
    oE["CNPJ"] := "12345678000195"
    oE["IM"] := "1234567"
    oT["CNPJ"] := "11222333000181"
    oT["XNOME"] := "Cliente & Filhos Ltda"
    oT["CMUN"] := "3304557"
    oT["CEP"] := "20000000"
    oT["XLGR"] := "Av Brasil"
    oT["NRO"] := "1"
    oT["XBAIRRO"] := "Centro"
    oT["EMAIL"] := "fin@cliente.com.br"
    lOk := Chk(lOk, "id da dps", cId == "DPS355030821234567800019500001000000000000027" .And. Len(cId) == 45)
    oD := Dps(cId, "1", oE, oT, .F.)
    aA := GEBDFEASSINA(GEBDFEDPSXML(oD), "infDPS", "DPS", cKey, cCert)
    lOk := Chk(lOk, "dps simples", aA[1] .And. "<opSimpNac>3</opSimpNac><regApTribSN>1</regApTribSN>" $ aA[3] .And. "<vDescIncond>50.00</vDescIncond>" $ aA[3] .And. ;
        "Cliente &amp; Filhos" $ aA[3])
    MemoWrite(cDir + "dps_sn.xml", aA[3])
    oD := Dps(GEBDFEDPSID("3550308", "12345678000195", 1, 28), "3", oE, Nil, .T.)
    aA := GEBDFEASSINA(GEBDFEDPSXML(oD), "infDPS", "DPS", cKey, cCert)
    lOk := Chk(lOk, "dps regime normal iss retido", aA[1] .And. "<opSimpNac>1</opSimpNac><regEspTrib>" $ aA[3] .And. "<tpRetISSQN>2</tpRetISSQN><pAliq>5.00</pAliq>" $ aA[3] ;
        .And. "<indTotTrib>0</indTotTrib>" $ aA[3] .And. !("<toma>" $ aA[3]))
    MemoWrite(cDir + "dps_rn.xml", aA[3])
    aA := GEBDFEASSINA(GEBDFEPEDCANC("35503082123456780001950000000000000271026100000001", "2", "2026-10-19T11:00:00-03:00", "12345678000195", "1", ;
        "Servico cobrado em duplicidade"), "infPedReg", "pedRegEvento", cKey, cCert)
    lOk := Chk(lOk, "pedido de cancelamento", aA[1])
    MemoWrite(cDir + "nfse_canc.xml", aA[3])
    If lOk
        ConOut("T_GEBDFE_NFSE PASS")
    Else
        ConOut("T_GEBDFE_NFSE FAIL")
    EndIf
Return lOk

Static Function Dps(cId, cCRT, oE, oT, lRet)
    Local oD := JsonObject():New()
    oD["ID"] := cId
    oD["TPAMB"] := "2"
    oD["DHEMI"] := "2026-10-19T10:00:00-03:00"
    oD["SERIE"] := 1
    oD["NDPS"] := Val(Right(cId, 15))
    oD["DCOMPET"] := "20261019"
    oD["CLOCEMI"] := "3550308"
    oD["EMIT"] := oE
    oD["CRT"] := cCRT
    oD["REGAPSN"] := "1"
    oD["TOMA"] := oT
    oD["CLOCPREST"] := "3550308"
    oD["CTRIBNAC"] := "010101"
    oD["CNBS"] := "115013000"
    oD["XDESC"] := "Analise e desenvolvimento de sistemas - outubro/2026"
    oD["VSERV"] := 1500
    If cCRT == "1"
        oD["VDESCINC"] := 50
    EndIf
    oD["RETIDO"] := lRet
    oD["PALIQ"] := 5
    oD["PTOTTRIBSN"] := 0
Return oD

Static Function Chk(lOk, cNome, lCond)
    If lCond
        ConOut("  OK " + cNome)
        Return lOk
    EndIf
    ConOut("  FAIL: " + cNome)
Return .F.
