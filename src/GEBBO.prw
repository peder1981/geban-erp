#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBCTX.prw"
#include "GEBEST.prw"
#include "GEBFNX.prw"
#include "GEBCPX.prw"
#include "GEBFAT.prw"
#include "GEBLOJ.prw"
#include "GEBLOJ_OPE.prw"
#include "GEBDFE.prw"
#include "GEBDFE_DANFE.prw"
#include "GEBDFE_NFE.prw"
#include "GEBDFE_DANFE55.prw"
#include "GEBDFE_NFSE.prw"
#include "GEBDFE_DIST.prw"
#include "GEBDFE_EFD.prw"
#include "GEBBCO.prw"
#include "GEBDER_MIG.prw"
#include "GEBFIN_MIG.prw"
#include "GEBDER_FIN.prw"
#include "GEBRET.prw"
#include "GEBSEC_RBA.prw"

/*/{Protheus.doc} GEBBO
    API do backoffice: POST|GET /bo/<modulo>/<acao> (web: /api/bo/{modulo}/{acao}).
    GEBBOROTAS() e' a tabela {metodo, rota, menu, item, descricao}: a
    permissao (SEC_PERM) da rota vem dela (GEBRESTRBAC). GEBBOEXEC le os
    campos do JsonObject da requisicao pelo nome (corpo, query e caminho
    chegam juntos, em maiusculas) e chama a funcao do modulo. Listas de itens
    vem como arrays de objetos (itens, pagamentos).
    @type API
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBBOROTAS()
Return {;
    {"POST", "estoque/movimento", "ESTOQUE", "ESTOQ", "Entrada/saida com custo"}, ;
    {"POST", "estoque/inventario", "ESTOQUE", "ESTOQ", "Ajuste de inventario"}, ;
    {"POST", "estoque/transferencia", "ESTOQUE", "ESTOQ", "Transferencia entre armazens"}, ;
    {"GET", "estoque/saldo", "ESTOQUE", "ESTOQ", "Saldo e custo medio"}, ;
    {"GET", "estoque/kardex", "ESTOQUE", "ESTOQ", "Relatorio: kardex"}, ;
    {"GET", "estoque/posicao", "ESTOQUE", "ESTOQ", "Relatorio: posicao valorizada"}, ;
    {"POST", "estoque/controle", "ESTOQUE", "ESTOQ", "Controle de lote/serie/endereco do produto"}, ;
    {"POST", "estoque/endereco", "ESTOQUE", "ESTOQ", "Cadastro de endereco"}, ;
    {"POST", "estoque/mudar-endereco", "ESTOQUE", "ESTOQ", "Mudanca de endereco"}, ;
    {"GET", "estoque/lotes", "ESTOQUE", "ESTOQ", "Relatorio: saldo por lote/endereco"}, ;
    {"GET", "estoque/vencer", "ESTOQUE", "ESTOQ", "Relatorio: lotes a vencer"}, ;
    {"POST", "estoque/fechar", "ESTOQUE", "ESTOQ", "Fechamento mensal"}, ;
    {"POST", "estoque/reabrir", "ESTOQUE", "ESTOQ", "Reabertura do ultimo mes fechado"}, ;
    {"GET", "estoque/fechamento", "ESTOQUE", "ESTOQ", "Relatorio: fechamento do mes"}, ;
    {"POST", "financeiro/condicao", "FINANCEIRO", "FLUXO", "Condicao de pagamento"}, ;
    {"POST", "financeiro/titulo", "FINANCEIRO", "FLUXO", "Titulos parcelados"}, ;
    {"POST", "financeiro/baixa", "FINANCEIRO", "FLUXO", "Baixa com juros/multa/desconto"}, ;
    {"GET", "financeiro/calculo", "FINANCEIRO", "FLUXO", "Juros e multa por atraso"}, ;
    {"POST", "financeiro/transferencia", "FINANCEIRO", "FLUXO", "Transferencia entre contas"}, ;
    {"POST", "financeiro/movimento", "FINANCEIRO", "FLUXO", "Movimento avulso"}, ;
    {"GET", "financeiro/posicao", "FINANCEIRO", "FLUXO", "Relatorio: titulos por faixa de atraso"}, ;
    {"GET", "financeiro/extrato", "FINANCEIRO", "FLUXO", "Relatorio: extrato da conta"}, ;
    {"GET", "financeiro/fluxo", "FINANCEIRO", "FLUXO", "Relatorio: fluxo de caixa projetado"}, ;
    {"POST", "financeiro/despesa", "FINANCEIRO", "FLUXO", "Despesa a pagar com centro de custo"}, ;
    {"POST", "banco/cobranca", "FINANCEIRO", "BANCO", "Dados de cobranca da conta"}, ;
    {"POST", "banco/boleto", "FINANCEIRO", "BANCO", "Boleto do titulo"}, ;
    {"GET", "banco/boleto-html", "FINANCEIRO", "BANCO", "Boleto para imprimir (HTML)"}, ;
    {"POST", "banco/remessa", "FINANCEIRO", "BANCO", "Remessa CNAB 240 ou 400"}, ;
    {"POST", "banco/retorno", "FINANCEIRO", "BANCO", "Retorno CNAB 240 ou 400 (baixa)"}, ;
    {"POST", "banco/ofx", "FINANCEIRO", "BANCO", "Importacao de extrato OFX"}, ;
    {"POST", "banco/conciliar", "FINANCEIRO", "BANCO", "Conciliacao automatica"}, ;
    {"POST", "banco/conciliar-manual", "FINANCEIRO", "BANCO", "Conciliacao manual"}, ;
    {"POST", "banco/lancar-extrato", "FINANCEIRO", "BANCO", "Lanca linha do extrato (tarifa)"}, ;
    {"GET", "banco/conciliacao", "FINANCEIRO", "BANCO", "Relatorio: conciliacao"}, ;
    {"GET", "contabil/razao", "CONTABIL", "LANCTO", "Relatorio: razao"}, ;
    {"GET", "contabil/balancete", "CONTABIL", "LANCTO", "Relatorio: balancete"}, ;
    {"GET", "contabil/dre", "CONTABIL", "LANCTO", "Relatorio: DRE"}, ;
    {"POST", "contabil/centro", "CONTABIL", "LANCTO", "Centro de custo"}, ;
    {"POST", "contabil/rateio", "CONTABIL", "LANCTO", "Rateio entre centros"}, ;
    {"GET", "contabil/resultado-centro", "CONTABIL", "LANCTO", "Relatorio: resultado por centro"}, ;
    {"POST", "compras/solicitacao", "COMPRAS", "PEDID", "Solicitacao de compra"}, ;
    {"POST", "compras/gerar", "COMPRAS", "PEDID", "Pedidos da solicitacao (menor preco)"}, ;
    {"POST", "compras/pedido", "COMPRAS", "PEDID", "Pedido de compra"}, ;
    {"POST", "compras/aprovar", "COMPRAS", "APROVA", "Aprovacao de alcada"}, ;
    {"POST", "compras/entrada", "COMPRAS", "PEDID", "Documento de entrada"}, ;
    {"POST", "compras/devolucao", "COMPRAS", "PEDID", "Devolucao de compra"}, ;
    {"POST", "fiscal/retencao", "FISCAL", "APURA", "Regra de retencao (tributo e aliquota)"}, ;
    {"GET", "fiscal/retencoes", "FISCAL", "APURA", "Relatorio: retencoes da competencia"}, ;
    {"POST", "derrama/pagar", "DERRAMA", "GUIAS", "Paga a guia pelo financeiro (conta e data)"}, ;
    {"POST", "contabil/corrigir-legado", "CONTABIL", "DIR", "Corrige lancamentos antigos (estorno e lancamento certo)"}, ;
    {"GET", "compras/abertos", "COMPRAS", "PEDID", "Relatorio: pedidos em aberto"}, ;
    {"GET", "compras/por-fornecedor", "COMPRAS", "PEDID", "Relatorio: compras por fornecedor"}, ;
    {"GET", "compras/solicitacoes", "COMPRAS", "PEDID", "Relatorio: solicitacoes pendentes"}, ;
    {"POST", "faturamento/cliente", "FATURAMENTO", "FATUR", "Cliente"}, ;
    {"POST", "faturamento/preco", "FATURAMENTO", "FATUR", "Tabela de preco"}, ;
    {"POST", "faturamento/pedido", "FATURAMENTO", "FATUR", "Pedido de venda"}, ;
    {"POST", "faturamento/liberar", "FATURAMENTO", "FATUR", "Liberacao (credito e estoque)"}, ;
    {"POST", "faturamento/cancelar", "FATURAMENTO", "FATUR", "Cancelamento de pedido"}, ;
    {"POST", "faturamento/faturar", "FATURAMENTO", "FATUR", "Documento de saida"}, ;
    {"POST", "faturamento/devolucao", "FATURAMENTO", "FATUR", "Devolucao de venda"}, ;
    {"GET", "faturamento/relatorio", "FATURAMENTO", "FATUR", "Relatorio: faturamento e margem"}, ;
    {"GET", "faturamento/carteira", "FATURAMENTO", "FATUR", "Relatorio: carteira de pedidos"}, ;
    {"GET", "faturamento/abc", "FATURAMENTO", "FATUR", "Relatorio: curva ABC"}, ;
    {"POST", "loja/caixa", "LOJA", "CAIXA", "Cadastro de caixa"}, ;
    {"POST", "loja/abrir", "LOJA", "CAIXA", "Abertura de caixa"}, ;
    {"POST", "loja/venda", "LOJA", "CAIXA", "Venda (cupom)"}, ;
    {"POST", "loja/cancelar", "LOJA", "CAIXA", "Cancelamento de cupom"}, ;
    {"POST", "loja/sangria", "LOJA", "CAIXA", "Sangria/suprimento"}, ;
    {"POST", "loja/fechar", "LOJA", "CAIXA", "Fechamento de caixa"}, ;
    {"GET", "loja/resumo", "LOJA", "CAIXA", "Relatorio: resumo do caixa"}, ;
    {"GET", "loja/vendas", "LOJA", "CAIXA", "Relatorio: vendas do dia"}, ;
    {"GET", "loja/tef", "LOJA", "CAIXA", "Relatorio: transacoes TEF do dia"}, ;
    {"POST", "loja/tef-pendentes", "LOJA", "CAIXA", "Desfaz transacoes TEF pendentes"}, ;
    {"POST", "loja/tef-config", "CONFIG", "EMPRES", "Configuracao do TEF (provedor, Cielo)"}, ;
    {"POST", "loja/codigo-barras", "LOJA", "GEREN", "Codigo de barras / PLU de balanca do produto"}, ;
    {"POST", "loja/promocao", "LOJA", "GEREN", "Promocao (preco, leve N pague M, desconto por quantidade)"}, ;
    {"POST", "loja/vendedor", "LOJA", "GEREN", "Vendedor e comissao"}, ;
    {"POST", "loja/orcamento", "LOJA", "ORCAM", "Orcamento (pre-venda)"}, ;
    {"POST", "loja/orcamento-cancelar", "LOJA", "ORCAM", "Cancelamento de orcamento"}, ;
    {"GET", "loja/orcamentos", "LOJA", "ORCAM", "Relatorio: orcamentos por status"}, ;
    {"POST", "loja/orcamento-finalizar", "LOJA", "CAIXA", "Finaliza o orcamento no caixa (cupom)"}, ;
    {"POST", "loja/devolucao", "LOJA", "CAIXA", "Devolucao/troca no caixa (dinheiro ou vale-troca)"}, ;
    {"GET", "loja/cupom", "LOJA", "CAIXA", "Segunda via do cupom"}, ;
    {"GET", "loja/consulta", "LOJA", "CAIXA", "Consulta de preco e saldo"}, ;
    {"GET", "loja/vale", "LOJA", "CAIXA", "Saldo do vale-troca"}, ;
    {"GET", "loja/gerencial", "LOJA", "GEREN", "Relatorio: gerencial (dia, caixa, operador, vendedor)"}, ;
    {"GET", "loja/comissao", "LOJA", "GEREN", "Relatorio: comissao dos vendedores"}, ;
    {"GET", "loja/danfe", "LOJA", "CAIXA", "DANFE NFC-e do cupom (HTML)"}, ;
    {"POST", "dfe/emitente", "FISCAL", "DFE", "Emitente: CNPJ, IE, regime e endereco"}, ;
    {"GET", "dfe/emitente", "FISCAL", "DFE", "Emitente cadastrado"}, ;
    {"POST", "dfe/certificado", "FISCAL", "DFE", "Certificado A1 (.pfx em Base64 e senha)"}, ;
    {"POST", "dfe/configuracao", "FISCAL", "DFE", "Ambiente, NFC-e, serie, CSC, responsavel tecnico e padroes fiscais"}, ;
    {"POST", "dfe/produto", "FISCAL", "DFE", "Perfil fiscal do produto"}, ;
    {"GET", "dfe/municipios", "FISCAL", "DFE", "Busca de municipio IBGE pelo nome"}, ;
    {"GET", "dfe/roteiro", "FISCAL", "DFE", "O que falta para emitir (com teste de comunicacao)"}, ;
    {"GET", "dfe/status", "FISCAL", "DFE", "Status do servico da SEFAZ"}, ;
    {"POST", "dfe/transmitir", "LOJA", "CAIXA", "Transmite as NFC-e em contingencia"}, ;
    {"POST", "dfe/cancelar", "FISCAL", "DFE", "Cancela NF-e/NFC-e autorizada"}, ;
    {"POST", "dfe/inutilizar", "FISCAL", "DFE", "Inutiliza faixa de numeros"}, ;
    {"POST", "dfe/inutilizar-pendentes", "FISCAL", "DFE", "Inutiliza os numeros das notas rejeitadas"}, ;
    {"GET", "dfe/consultar", "FISCAL", "DFE", "Situacao do documento na SEFAZ"}, ;
    {"GET", "dfe/documentos", "FISCAL", "DFE", "Relatorio: documentos eletronicos do periodo"}, ;
    {"GET", "dfe/danfe", "FISCAL", "DFE", "DANFE (NFC-e ou NF-e) pela chave (HTML)"}, ;
    {"POST", "dfe/participante", "FISCAL", "DFE", "Cadastro fiscal do cliente (C) ou fornecedor (F) para a NF-e"}, ;
    {"POST", "dfe/carta-correcao", "FISCAL", "DFE", "Carta de correcao da NF-e"}, ;
    {"POST", "dfe/resolver", "FISCAL", "DFE", "Resolve NF-e sem resposta da SEFAZ (pendentes)"}, ;
    {"POST", "dfe/ibpt", "FISCAL", "DFE", "Importa a tabela IBPT da UF (Lei 12.741, tributos aproximados)"}, ;
    {"POST", "dfe/servico", "FISCAL", "DFE", "Servico fiscal (codigo de tributacao nacional, municipal e NBS)"}, ;
    {"POST", "faturamento/servico", "FATURAMENTO", "FATUR", "Faturamento de servico (NFS-e nacional, titulos e contabil)"}, ;
    {"POST", "dfe/nfse-cancelar", "FISCAL", "DFE", "Cancela NFS-e (motivo 1, 2 ou 9)"}, ;
    {"POST", "dfe/efd", "FISCAL", "DFE", "SPED Fiscal (EFD ICMS/IPI) da competencia: gera e guarda"}, ;
    {"POST", "compras/nfe-buscar", "COMPRAS", "PEDID", "Busca na SEFAZ as NF-e emitidas contra o CNPJ"}, ;
    {"GET", "compras/nfe-recebidas", "COMPRAS", "PEDID", "Relatorio: NF-e recebidas de fornecedores"}, ;
    {"POST", "compras/nfe-manifestar", "COMPRAS", "PEDID", "Manifestacao do destinatario"}, ;
    {"POST", "compras/de-para", "COMPRAS", "PEDID", "Produto do fornecedor = produto do GEBAN (fator)"}, ;
    {"POST", "compras/nfe-importar", "COMPRAS", "PEDID", "Importa a NF-e recebida como entrada de compra"}}

// Rota {metodo, rota, menu, item, descricao}; {} se nao existe.
User Function GEBBOROTA(cRota, cMetodo)
    Local aR := GEBBOROTAS()
    Local nI := 0
    cRota := Lower(BOCOL(cRota))
    cMetodo := Upper(BOCOL(cMetodo))
    For nI := 1 To Len(aR)
        If aR[nI][2] == cRota .And. aR[nI][1] == cMetodo
            Return aR[nI]
        EndIf
    Next nI
Return {}

/*/{Protheus.doc} GEBBOEXEC
    Executa a rota do backoffice.
    @type API
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, xDados}; cMsg "rota_inexistente" se nao ha rota
/*/
User Function GEBBOEXEC(cMetodo, cRota, o, cUsu)
    Local aRes := {}
    Local xJ := Nil
    Local xM := Nil
    cRota := Lower(BOCOL(cRota))
    If Len(GEBBOROTA(cRota, cMetodo)) == 0
        Return {.F., "rota_inexistente: " + cRota, Nil}
    EndIf
    If cRota == "estoque/movimento"
        aRes := GEBESTMOV(BOQ(o, "produto"), BOQ(o, "armazem"), BOQ(o, "tipo"), BOQN(o, "quantidade"), BOQN(o, "custo"), "API", BOQ(o, "documento"), BOQ(o, "data"), ;
            BOLotes(o))
    ElseIf cRota == "estoque/inventario"
        aRes := GEBESTAJU(BOQ(o, "produto"), BOQ(o, "armazem"), BOQN(o, "contado"), BOQN(o, "custo"), BOQ(o, "documento"), BOQ(o, "data"), BOLotes(o))
    ElseIf cRota == "estoque/transferencia"
        aRes := GEBESTTRF(BOQ(o, "produto"), BOQ(o, "origem"), BOQ(o, "destino"), BOQN(o, "quantidade"), BOQ(o, "documento"), BOQ(o, "data"), BOLotes(o), ;
            BOQ(o, "endereco_destino"))
    ElseIf cRota == "estoque/controle"
        aRes := GEBESTCTL(BOQ(o, "produto"), BOQ(o, "rastro"), BOQ(o, "endereco"))
    ElseIf cRota == "estoque/endereco"
        aRes := GEBESTENDER(BOQ(o, "armazem"), BOQ(o, "endereco"), BOQ(o, "descricao"))
    ElseIf cRota == "estoque/mudar-endereco"
        aRes := GEBESTENDTRF(BOQ(o, "produto"), BOQ(o, "armazem"), BOQ(o, "lote"), BOQ(o, "origem"), BOQ(o, "destino"), BOQN(o, "quantidade"), BOQ(o, "data"))
    ElseIf cRota == "estoque/lotes"
        aRes := GEBESTLOTES(BOQ(o, "produto"), BOQ(o, "armazem"), BOQ(o, "data"))
    ElseIf cRota == "estoque/vencer"
        aRes := GEBESTVENCER(BOQN(o, "dias"), BOQ(o, "data"))
    ElseIf cRota == "estoque/fechar"
        aRes := GEBESTFECHA(BOQ(o, "competencia"))
    ElseIf cRota == "estoque/reabrir"
        aRes := GEBESTREABRE(BOQ(o, "competencia"))
    ElseIf cRota == "estoque/fechamento"
        aRes := GEBESTFECHREL(BOQ(o, "competencia"))
    ElseIf cRota == "financeiro/despesa"
        aRes := GEBFXDESP(BOQ(o, "documento"), BOQ(o, "fornecedor"), BOQN(o, "valor"), BOQ(o, "condicao"), BOQ(o, "emissao"), BOQ(o, "conta_contabil"), ;
            BOQ(o, "centro"), BOQ(o, "historico"))
    ElseIf cRota == "banco/cobranca"
        aRes := GEBBCOCFG(BOQ(o, "conta"), BOQ(o, "banco"), BOQ(o, "agencia"), BOQ(o, "agencia_dv"), BOQ(o, "conta_corrente"), BOQ(o, "conta_dv"), ;
            BOQ(o, "carteira"), BOQ(o, "codigo_empresa"), BOQ(o, "beneficiario"), BOQ(o, "cnpj"), BOQ(o, "layout"), BOQ(o, "modalidade"))
    ElseIf cRota == "banco/boleto"
        aRes := GEBBCOBOL(BOQ(o, "documento"), BOQ(o, "conta"))
    ElseIf cRota == "banco/boleto-html"
        aRes := GEBBCOHTML(BOQ(o, "documento"))
    ElseIf cRota == "banco/remessa"
        aRes := GEBBCOREM(BOQ(o, "conta"), "")
    ElseIf cRota == "banco/retorno"
        aRes := GEBBCORET(BOQ(o, "conta"), BOSTR(o["CONTEUDO"]))
    ElseIf cRota == "banco/ofx"
        aRes := GEBBCOOFX(BOQ(o, "conta"), BOSTR(o["CONTEUDO"]))
    ElseIf cRota == "banco/conciliar"
        aRes := GEBBCOCONC(BOQ(o, "conta"))
    ElseIf cRota == "banco/conciliar-manual"
        aRes := GEBBCOCONCMAN(BOQ(o, "conta"), BOQ(o, "fitid"), BOQN(o, "movimento"))
    ElseIf cRota == "banco/lancar-extrato"
        aRes := GEBBCOLANCA(BOQ(o, "conta"), BOQ(o, "fitid"), BOQ(o, "conta_contabil"), BOQ(o, "centro"))
    ElseIf cRota == "banco/conciliacao"
        aRes := GEBBCOREL(BOQ(o, "conta"), BOQ(o, "inicio"), BOQ(o, "fim"))
    ElseIf cRota == "contabil/centro"
        aRes := GEBCTXCC(BOQ(o, "codigo"), BOQ(o, "descricao"), BOQ(o, "bloqueado"))
    ElseIf cRota == "contabil/rateio"
        aRes := GEBCTXRAT(BOQ(o, "codigo"), BOQITENS(o, "itens", {"centro", "percentual"}, {"percentual"}))
    ElseIf cRota == "contabil/resultado-centro"
        aRes := GEBCTXCCRES(BOQ(o, "inicio"), BOQ(o, "fim"))
    ElseIf cRota == "compras/devolucao"
        aRes := GEBCPXDEV(BOQ(o, "nota"), BOQ(o, "fornecedor"), BOQITENS(o, "itens", {"produto", "quantidade"}, {"quantidade"}), BOQ(o, "data"), ;
            BOQ(o, "chave"))
    ElseIf cRota == "loja/tef"
        aRes := GEBTEFREL(BOQ(o, "data"))
    ElseIf cRota == "loja/tef-pendentes"
        aRes := GEBTEFRESOLVE()
    ElseIf cRota == "loja/tef-config"
        aRes := GEBTEFCFG(BOQ(o, "provedor"), BOQ(o, "url"), BOQ(o, "merchant_id"), BOQ(o, "chave"), BOQ(o, "cartao_teste"), BOQ(o, "bandeira"))
    ElseIf cRota == "estoque/saldo"
        aRes := {.T., "saldo", GEBESTSLD(BOQ(o, "produto"), BOQ(o, "armazem"))}
    ElseIf cRota == "estoque/kardex"
        aRes := GEBESTKARDEX(BOQ(o, "produto"), BOQ(o, "armazem"), BOQ(o, "inicio"), BOQ(o, "fim"))
    ElseIf cRota == "estoque/posicao"
        aRes := GEBESTPOS(BOQ(o, "armazem"))
    ElseIf cRota == "financeiro/condicao"
        aRes := GEBFXCOND(BOQ(o, "codigo"), BOQ(o, "descricao"), BOQ(o, "dias"))
    ElseIf cRota == "financeiro/titulo"
        aRes := GEBFXTIT(BOQ(o, "tipo"), BOQ(o, "documento"), BOQ(o, "parceiro"), BOQN(o, "valor"), BOQ(o, "condicao"), BOQ(o, "emissao"), BOQ(o, "origem"), "")
    ElseIf cRota == "financeiro/baixa"
        // juros/multa ausentes = calculados por atraso.
        If !(BOQ(o, "juros") == "")
            xJ := BOQN(o, "juros")
        EndIf
        If !(BOQ(o, "multa") == "")
            xM := BOQN(o, "multa")
        EndIf
        aRes := GEBFXBAI(BOQ(o, "tipo"), BOQ(o, "documento"), BOQN(o, "principal"), xJ, xM, BOQN(o, "desconto"), BOQ(o, "conta"), BOQ(o, "data"))
    ElseIf cRota == "financeiro/calculo"
        aRes := GEBFXCALC(BOQ(o, "tipo"), BOQ(o, "documento"), BOQ(o, "data"))
    ElseIf cRota == "financeiro/transferencia"
        aRes := GEBFXTRF(BOQ(o, "origem"), BOQ(o, "destino"), BOQN(o, "valor"), BOQ(o, "data"), BOQ(o, "historico"))
    ElseIf cRota == "financeiro/movimento"
        aRes := GEBFXMOV(BOQ(o, "conta"), BOQ(o, "dc"), BOQN(o, "valor"), BOQ(o, "historico"), BOQ(o, "data"), BOQ(o, "conta_contabil"), BOQ(o, "centro"))
    ElseIf cRota == "financeiro/posicao"
        aRes := GEBFXPOSICAO(BOQ(o, "tipo"), BOQ(o, "data"))
    ElseIf cRota == "financeiro/extrato"
        aRes := GEBFXEXTRATO(BOQ(o, "conta"), BOQ(o, "inicio"), BOQ(o, "fim"))
    ElseIf cRota == "financeiro/fluxo"
        aRes := GEBFXFLUXO(BOQ(o, "inicio"), BOQN(o, "dias"))
    ElseIf cRota == "contabil/razao"
        aRes := GEBCTXRAZAO(BOQ(o, "conta"), BOQ(o, "inicio"), BOQ(o, "fim"))
    ElseIf cRota == "contabil/balancete"
        aRes := GEBCTXBALAN(BOQ(o, "inicio"), BOQ(o, "fim"), BOQ(o, "centro"))
    ElseIf cRota == "contabil/dre"
        aRes := GEBCTXDRE(BOQ(o, "inicio"), BOQ(o, "fim"), BOQ(o, "centro"))
    ElseIf cRota == "compras/solicitacao"
        aRes := GEBCPXSC(BOQ(o, "numero"), BOQITENS(o, "itens", {"produto", "quantidade", "necessidade"}, {"quantidade"}), cUsu)
    ElseIf cRota == "compras/gerar"
        aRes := GEBCPXGERA(BOQ(o, "solicitacao"), BOQ(o, "condicao"), BOQ(o, "armazem"), BOQ(o, "data"))
    ElseIf cRota == "compras/pedido"
        aRes := GEBCPXPED(BOQ(o, "numero"), BOQ(o, "fornecedor"), BOQITENS(o, "itens", {"produto", "quantidade", "preco"}, {"quantidade", "preco"}), ;
            BOQ(o, "condicao"), BOQ(o, "armazem"), BOQ(o, "data"))
    ElseIf cRota == "compras/aprovar"
        aRes := GEBCPXAPR(BOQ(o, "pedido"), cUsu, !(Upper(BOQ(o, "aprova")) == "N"))
    ElseIf cRota == "compras/entrada"
        aRes := GEBCPXENT(BOQ(o, "nota"), BOQ(o, "pedido"), BOQITENS(o, "itens", {"produto", "quantidade", "preco", "lote", "validade", "endereco"}, {"quantidade", "preco"}), ;
            BOQN(o, "frete"), BOQ(o, "data"), BOQ(o, "retencoes"), BOQ(o, "chave"))
    ElseIf cRota == "fiscal/retencao"
        aRes := GEBRETCAD(BOQ(o, "codigo"), BOQ(o, "tributo"), BOQN(o, "aliquota"), BOQ(o, "descricao"))
    ElseIf cRota == "fiscal/retencoes"
        aRes := GEBRETREL(BOQ(o, "competencia"))
    ElseIf cRota == "derrama/pagar"
        aRes := GEBDERPAGA(BOQ(o, "guia"), BOQ(o, "conta"), BOQ(o, "data"))
    ElseIf cRota == "contabil/corrigir-legado"
        aRes := GEBCTXCORRIGE()
    ElseIf cRota == "compras/abertos"
        aRes := GEBCPXABERTOS()
    ElseIf cRota == "compras/por-fornecedor"
        aRes := GEBCPXPORFORN(BOQ(o, "inicio"), BOQ(o, "fim"))
    ElseIf cRota == "compras/solicitacoes"
        aRes := GEBCPXSCPEND()
    ElseIf cRota == "faturamento/cliente"
        aRes := GEBFATCLI(BOQ(o, "codigo"), BOQ(o, "nome"), BOQ(o, "documento"), BOQ(o, "uf"), BOQN(o, "limite"), BOQ(o, "condicao"), BOQ(o, "tabela"))
    ElseIf cRota == "faturamento/preco"
        aRes := GEBFATPRC(BOQ(o, "tabela"), BOQ(o, "produto"), BOQN(o, "preco"))
    ElseIf cRota == "faturamento/pedido"
        aRes := GEBFATPED(BOQ(o, "numero"), BOQ(o, "cliente"), BOQITENS(o, "itens", {"produto", "quantidade", "preco"}, {"quantidade", "preco"}), ;
            BOQ(o, "condicao"), BOQN(o, "desconto"), BOQ(o, "armazem"), BOQ(o, "data"), BOQ(o, "centro"))
    ElseIf cRota == "faturamento/liberar"
        If Upper(BOQ(o, "forcar")) == "S" .And. !GEBSECRBAC(cUsu, "FATURAMENTO", "LIBERA")
            Return {.F., "sem_permissao: FATURAMENTO/LIBERA para forcar a liberacao", Nil}
        EndIf
        aRes := GEBFATLIB(BOQ(o, "pedido"), Upper(BOQ(o, "forcar")) == "S")
    ElseIf cRota == "faturamento/cancelar"
        aRes := GEBFATCAN(BOQ(o, "pedido"))
    ElseIf cRota == "faturamento/faturar"
        aRes := GEBFATFAT(BOQ(o, "pedido"), BOQITENS(o, "itens", {"produto", "quantidade"}, {"quantidade"}), BOQ(o, "data"), BOQ(o, "nota"))
    ElseIf cRota == "faturamento/devolucao"
        aRes := GEBFATDEV(BOQ(o, "nota"), BOQITENS(o, "itens", {"produto", "quantidade"}, {"quantidade"}), BOQ(o, "data"), BOQ(o, "chave_cliente"))
    ElseIf cRota == "faturamento/relatorio"
        aRes := GEBFATREL(BOQ(o, "inicio"), BOQ(o, "fim"), BOQ(o, "agrupar"))
    ElseIf cRota == "faturamento/carteira"
        aRes := GEBFATCARTEIRA()
    ElseIf cRota == "faturamento/abc"
        aRes := GEBFATABC(BOQ(o, "inicio"), BOQ(o, "fim"))
    ElseIf cRota == "loja/caixa"
        aRes := GEBLOJCX(BOQ(o, "codigo"), BOQ(o, "nome"), BOQ(o, "conta"), BOQ(o, "armazem"), BOQ(o, "centro"))
    ElseIf cRota == "loja/abrir"
        aRes := GEBLOJABRE(BOQ(o, "caixa"), cUsu, BOQN(o, "fundo"), BOQ(o, "data"))
    ElseIf cRota == "loja/venda"
        aRes := GEBLOJVEN(BOQ(o, "sessao"), BOQITENS(o, "itens", {"produto", "quantidade", "preco"}, {"quantidade", "preco"}), ;
            BOQITENS(o, "pagamentos", {"forma", "valor", "parcelas", "documento"}, {"valor", "parcelas"}), BOQ(o, "cliente"), BOQN(o, "desconto"), ;
            BOQ(o, "vendedor"), BOQ(o, "cpf"), BOQ(o, "supervisor"), BOSTR(o["SENHA_SUPERVISOR"]))
    ElseIf cRota == "loja/cancelar"
        aRes := GEBLOJCAN(BOQ(o, "cupom"), BOQ(o, "motivo"))
    ElseIf cRota == "loja/sangria"
        aRes := GEBLOJSAN(BOQ(o, "sessao"), BOQ(o, "tipo"), BOQN(o, "valor"), BOQ(o, "motivo"), BOQ(o, "conta"))
    ElseIf cRota == "loja/fechar"
        aRes := GEBLOJFECHA(BOQ(o, "sessao"), BOQN(o, "contado"))
    ElseIf cRota == "loja/resumo"
        aRes := GEBLOJRESUMO(BOQ(o, "sessao"))
    ElseIf cRota == "loja/vendas"
        aRes := GEBLOJVENDAS(BOQ(o, "data"), BOQ(o, "caixa"))
    ElseIf cRota == "loja/codigo-barras"
        aRes := GEBLOJBAR(BOQ(o, "codigo"), BOQ(o, "produto"), BOQN(o, "fator"))
    ElseIf cRota == "loja/promocao"
        aRes := GEBLOJPROMO(BOQ(o, "codigo"), BOQ(o, "produto"), BOQ(o, "tipo"), BOQN(o, "quantidade_minima"), BOQN(o, "valor"), BOQ(o, "inicio"), BOQ(o, "fim"))
    ElseIf cRota == "loja/vendedor"
        aRes := GEBLOJVEND(BOQ(o, "codigo"), BOQ(o, "nome"), BOQN(o, "comissao"))
    ElseIf cRota == "loja/orcamento"
        aRes := GEBLOJORC(BOQITENS(o, "itens", {"produto", "quantidade", "preco"}, {"quantidade", "preco"}), BOQ(o, "cliente"), BOQ(o, "vendedor"), ;
            BOQN(o, "desconto"), BOQ(o, "data"))
    ElseIf cRota == "loja/orcamento-cancelar"
        aRes := GEBLOJORCCAN(BOQ(o, "orcamento"))
    ElseIf cRota == "loja/orcamentos"
        aRes := GEBLOJORCS(BOQ(o, "status"))
    ElseIf cRota == "loja/orcamento-finalizar"
        aRes := GEBLOJORCFIN(BOQ(o, "sessao"), BOQ(o, "orcamento"), BOQITENS(o, "pagamentos", {"forma", "valor", "parcelas", "documento"}, {"valor", "parcelas"}), ;
            BOQ(o, "cpf"), BOQ(o, "supervisor"), BOSTR(o["SENHA_SUPERVISOR"]))
    ElseIf cRota == "loja/devolucao"
        aRes := GEBLOJDEV(BOQ(o, "sessao"), BOQ(o, "cupom"), BOQITENS(o, "itens", {"produto", "quantidade"}, {"quantidade"}), BOQ(o, "modo"), BOQ(o, "motivo"), BOConsumidor(o))
    ElseIf cRota == "loja/cupom"
        aRes := GEBLOJCUPOM(BOQ(o, "cupom"))
    ElseIf cRota == "loja/consulta"
        aRes := GEBLOJCONS(BOQ(o, "codigo"), BOQ(o, "caixa"))
    ElseIf cRota == "loja/vale"
        aRes := GEBLOJVALE(BOQ(o, "vale"))
    ElseIf cRota == "loja/gerencial"
        aRes := GEBLOJGER(BOQ(o, "inicio"), BOQ(o, "fim"), BOQ(o, "agrupar"))
    ElseIf cRota == "loja/comissao"
        aRes := GEBLOJCOMIS(BOQ(o, "inicio"), BOQ(o, "fim"))
    ElseIf cRota == "loja/danfe"
        aRes := GEBDFEDANFE(BOBuscaNota(BOQ(o, "cupom")))
    ElseIf cRota == "dfe/emitente" .And. cMetodo == "POST"
        aRes := GEBDFEEMIT(o)
    ElseIf cRota == "dfe/emitente"
        aRes := BOEmitente()
    ElseIf cRota == "dfe/certificado"
        aRes := GEBDFECERT(BOSTR(o["PFX"]), BOSTR(o["SENHA"]))
    ElseIf cRota == "dfe/configuracao"
        aRes := GEBDFECONFIG(o)
    ElseIf cRota == "dfe/produto"
        aRes := GEBDFEPRODFIS(o)
    ElseIf cRota == "dfe/municipios"
        aRes := {.T., "municipios", GEBDFEMUNBUSCA(BOQ(o, "nome"), BOQ(o, "uf"))}
    ElseIf cRota == "dfe/roteiro"
        // Relatorio: responde sempre com os itens (o que falta e' justamente o que interessa).
        aRes := GEBDFEROTEIRO(!(Upper(BOQ(o, "testar")) == "N"))
        aRes := {.T., BOTXT(aRes[1], "pronto para emitir", "faltam itens: veja a lista"), aRes[2]}
    ElseIf cRota == "dfe/status"
        aRes := GEBDFESTATSVC(BOTXT(BOQ(o, "modelo") == "", "65", BOQ(o, "modelo")))
    ElseIf cRota == "dfe/transmitir"
        aRes := GEBDFETRANSMITE()
    ElseIf cRota == "dfe/cancelar"
        aRes := GEBDFECANCELA(BOQ(o, "chave"), BOQ(o, "justificativa"))
    ElseIf cRota == "dfe/inutilizar"
        aRes := GEBDFEINUTILIZA(BOQ(o, "modelo"), BOQN(o, "serie"), BOQN(o, "inicio"), BOQN(o, "fim"), BOQ(o, "justificativa"))
    ElseIf cRota == "dfe/inutilizar-pendentes"
        aRes := GEBDFEINUTPEND(BOQ(o, "justificativa"))
    ElseIf cRota == "dfe/consultar"
        aRes := GEBDFECONSULTAR(BOQ(o, "chave"), .T.)
    ElseIf cRota == "dfe/documentos"
        aRes := GEBDFEDOCS(BOQ(o, "inicio"), BOQ(o, "fim"), BOQ(o, "status"))
    ElseIf cRota == "dfe/danfe"
        aRes := GEBDFEDANFE(BOQ(o, "chave"))
    ElseIf cRota == "dfe/participante"
        aRes := GEBDFEPART(o)
    ElseIf cRota == "dfe/carta-correcao"
        aRes := GEBDFECCE(BOQ(o, "chave"), BOQ(o, "correcao"))
    ElseIf cRota == "dfe/resolver"
        aRes := GEBDFERESOLVE()
        xJ := GEBDFENFSERESOLVE()
        aRes := {aRes[1] .And. xJ[1], "NF-e: " + aRes[2] + " | NFS-e: " + xJ[2], {aRes[3], xJ[3]}}
    ElseIf cRota == "dfe/servico"
        aRes := GEBDFESERV(o)
    ElseIf cRota == "faturamento/servico"
        aRes := GEBFATSERV(BOQ(o, "cliente"), BOQ(o, "servico"), BOQN(o, "valor"), BOQ(o, "descricao"), BOQ(o, "condicao"), BOQ(o, "data"), ;
            Upper(BOQ(o, "iss_retido")) == "S", BOQN(o, "desconto"))
    ElseIf cRota == "compras/nfe-buscar"
        aRes := GEBDFEDISTBUSCA()
    ElseIf cRota == "compras/nfe-recebidas"
        aRes := GEBDFERECEBIDAS(BOQ(o, "situacao"))
    ElseIf cRota == "compras/nfe-manifestar"
        aRes := GEBDFEMANIF(BOQ(o, "chave"), BOQ(o, "tipo"), BOQ(o, "justificativa"))
    ElseIf cRota == "compras/de-para"
        aRes := GEBDFEDEPARA(BOQ(o, "fornecedor"), BOQ(o, "codigo_fornecedor"), BOQ(o, "produto"), BOQN(o, "fator"))
    ElseIf cRota == "compras/nfe-importar"
        aRes := GEBDFEIMPORTA(BOQ(o, "chave"), BOQ(o, "pedido"), BOQ(o, "data"))
    ElseIf cRota == "dfe/nfse-cancelar"
        aRes := GEBDFENFSECANC(BOQ(o, "chave"), BOQ(o, "motivo"), BOQ(o, "justificativa"))
    ElseIf cRota == "dfe/efd"
        xJ := GEBDFEEFD(BOQ(o, "competencia"), BOQ(o, "finalidade"))
        aRes := {xJ[1], xJ[2], xJ[4]}
    ElseIf cRota == "dfe/ibpt"
        aRes := GEBDFEIBPTIMP(BOSTR(o["CONTEUDO"]), BOQ(o, "uf"))
    EndIf
    If Len(aRes) < 2
        Return {.F., "rota_sem_execucao: " + cRota, Nil}
    EndIf
    If Len(aRes) >= 3 .And. ValType(aRes[3]) == "N"
        aRes[3] := {aRes[3]}
    EndIf
    If Len(aRes) < 3
        Return {aRes[1], aRes[2], Nil}
    EndIf
Return aRes

// Lotes do corpo: "lotes" = [{lote, validade, endereco, quantidade}] -> aDet do GEBESTMOV.
Static Function BOLotes(o)
Return BOQITENS(o, "lotes", {"lote", "validade", "endereco", "quantidade"}, {"quantidade"})

// Texto conforme a condicao (sem IIF).
Static Function BOTXT(lCond, cSim, cNao)
    If lCond
        Return cSim
    EndIf
Return cNao

// Chave da NFC-e do cupom (GLJ3_NOTA).
Static Function BOBuscaNota(cCupom)
    Local aH := TCSqlQuery("SELECT GLJ3_NOTA AS N FROM GLJ3 WHERE GLJ3_FILIAL = " + GEBDBQuote(FWxFilial("GLJ3")) + " AND GLJ3_CUPOM = " + ;
        GEBDBQuote(Upper(BOCOL(cCupom))) + " AND D_E_L_E_T_ = ' '")
    If Len(aH) == 0
        Return ""
    EndIf
Return BOCOL(aH[1]:N)

// Emitente cadastrado em pares {campo, valor}.
Static Function BOEmitente()
    Local oE := GEBDFEEMITLE()
    Local aC := {"CNPJ", "IE", "IM", "CNAE", "XNOME", "XFANT", "CRT", "XLGR", "NRO", "XCPL", "XBAIRRO", "CMUN", "XMUN", "UF", "CEP", "FONE", "EMAIL"}
    Local aR := {}
    Local nI := 0
    If oE == Nil
        Return {.F., "emitente_nao_cadastrado", {}}
    EndIf
    For nI := 1 To Len(aC)
        aAdd(aR, {Lower(aC[nI]), oE[aC[nI]]})
    Next nI
Return {.T., "emitente", aR}

// Consumidor da devolucao de NFC-e (campos consumidor_*), ou Nil.
Static Function BOConsumidor(o)
    Local aC := {"DOC", "NOME", "LOGRADOURO", "NUMERO", "COMPLEMENTO", "BAIRRO", "MUNICIPIO", "UF", "CEP", "FONE", "EMAIL"}
    Local oC := Nil
    Local nI := 0
    If BOQ(o, "consumidor_doc") == ""
        Return Nil
    EndIf
    oC := JsonObject():New()
    For nI := 1 To Len(aC)
        oC[aC[nI]] := BOQ(o, "consumidor_" + Lower(aC[nI]))
    Next nI
Return oC
