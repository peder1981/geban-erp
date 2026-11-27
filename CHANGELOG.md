# Changelog

Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/). Versões seguem `vX.Y`.
Mudanças desde a última tag (`v0.9`) estão em **Não lançado**, agrupadas por tema.

## [Não lançado]

### Frente de caixa
- **O módulo "Frente de loja" do TUI (`GEBTUIPDV`) foi descontinuado e removido.** A frente de caixa passa a ser o PDV web (`public/pdv.html`), servido pelo GEBWEB em `/pdv`. Backend inalterado (`GEBLOJVEN`, tabelas GLJ*, rotas `/api/pdv/*`, permissões `LOJA/*`). Orçamentos, devolução, TEF/NFC-e, cadastros e relatórios de caixa seguem disponíveis via API (`/api/pdv/*` e BOs `loja/*`), sem tela própria no TUI.
- PDV web: alias `POST /api/pdv/login` (mesmo handler de `/api/login`) para publicação em bordas que bloqueiam `/api/login`; tema claro do ERP.

### Documentação
- **Manual do usuário** (`docs/08-manual-do-usuario.md` e PDF): passo a passo de todas as telas, com capturas reais anotadas (moldura numerada e balão no menu, campo ou botão a usar), a rotina executada numa empresa de demonstração e a referência dos 153 formulários dos 9 módulos.

### Interface (AdvPP 4.8.5, PO-UI)
- **Requer AdvPP 4.8.5 ou posterior** (`Nil` e `NULL` do banco como texto vazio, passagem por referência `@var`, curto-circuito, aritmética de datas).
- **Cancelar cupom** volta à frente de loja (aba Caixa); **Cotação de fornecedor** e **Menor preço cotado** ganham formulário em Compras.
- Tabelas da interface nunca mostram colunas de credencial; login e troca de senha em duas colunas; grade de itens com números no formato brasileiro.
- Documentação técnica e manual atualizados para a interface nova; telas novas no README.
- **Relatórios por sessão:** cada janela do navegador tem a sua grade de relatório; dois usuários gerando relatório ao mesmo tempo não se misturam (o Simples Nacional passou a usar a mesma grade).
- Páginas de empresa, filial e primeira empresa em duas colunas; aviso no Início quando não há contas.
- Inventário de tabelas e de funções da referência técnica gerados a partir dos fontes (`scripts/doc-tabelas.py`, `scripts/doc-funcoes.py`).
- **Pacote Windows** revalidado em Windows 10 limpo: instalador em português do Brasil, mensagem final corrigida e agendador rodando sem abrir janela.
- **Todas as operações viram formulários de tela única** nos módulos (abas por grupo: Operações, Banco, NF-e, Simples Nacional, Documentos eletrônicos, Relatórios); operações com vários itens têm grade para incluir e remover itens. Saem as telas de perguntas em sequência.
- **Frente de loja (PDV):** venda numa tela só (carrinho, preço e promoção resolvidos, vários pagamentos com troco, CPF na nota, vendedor e supervisor), caixa, orçamentos, consultas, devolução com os dados do consumidor da NFC-e, cadastros, relatórios e TEF/NFC-e.
- **Início** com indicadores e gráfico; **Rastreabilidade** em árvore.
- Código morto removido (interface antiga `GEBGUI_*`, `GEBAN.prw`, `GEBINIC` e afins).

### Licença
- Projeto licenciado sob **Apache License 2.0** (`LICENSE`).

### Acessos e segurança
- **Permissão por empresa:** a permissão de módulo deixa de valer para todas as empresas. Cada linha de permissão tem a empresa (`*` = todas, legado preservado).
- **Perfil por empresa:** o mesmo usuário pode ser ADMIN numa empresa e USUARIO em outra. O ADMIN só age sobre a própria empresa.
- **Login independente da filial:** a credencial é localizada pelo usuário. Divergência de filial deixa de derrubar o login.
- **Vínculo obrigatório:** sem vínculo com a empresa da sessão, não há acesso a nenhum módulo.
- **Lista de empresas filtrada:** o usuário vê só as empresas em que está vinculado.
- **Ciclo de vida do usuário** (referência: Gestão de Usuários do Protheus):
  - bloquear e desbloquear (só super);
  - validade do acesso, `AAAAMMDD` (só super): vencida = bloqueada;
  - eliminar acessos (super: todas as empresas; ADMIN: só a própria), reversível;
  - excluir, só usuário que nunca acessou (só super);
  - troca obrigatória no próximo logon;
  - conta de serviço que ignora a troca periódica de senha (só super).
- **Expiração de senha** de 90 dias, aplicada no login depois da senha correta. Senhas legadas sem data não expiram.
- **Conta super** não é bloqueada, não vence, não é excluída e não perde acessos.
- Login web e GUI deixam de criar vínculo ao entrar o super.
- **Bootstrap do primeiro acesso:** instalação com catálogo vazio cria automaticamente a conta `super` (`GEBSECBOOT`, chamada por `GEBDBProvisionaCatalogo`) com senha padrão `Geban#2026` — customizável via `GEBAN_SUPER_SENHA` — e `SEC_FORCE='S'`: o primeiro login exige troca de senha. O login TUI conduz a troca na hora; a API web devolve `troca de senha obrigatoria`. Catálogo populado nunca é tocado.

### Agendador de rotinas
- Agendamentos por empresa (`SCH_JOB`) e histórico de execuções (`SCH_LOG`).
- Rotinas de uma lista fechada: coleta de DF-e por NSU (`DFE_DIST`) e apuração do Simples do mês anterior (`SN_APU`).
- Horário `HHMM` e dia diário ou dia do mês (1 a 28). Atraso: roda na próxima passada, uma vez por dia.
- Trava por empresa evita execução dupla.
- Tela **Núcleo > Agendamentos** para agendar, desativar e consultar.
- Executor `GEBSCHJOB`, disparado a cada minuto por timer systemd.

### Cadastro e hierarquia
- Filial exige unidade cadastrada, sempre.
- A lista de filiais é lida do schema da empresa escolhida (antes falhava para usuário com mais de uma filial).

### Fiscal
- Motor de documentos eletrônicos com NF-e, NFC-e, NFS-e (padrão nacional), CC-e, DANFE A4 e NFC-e.
- EFD ICMS/IPI gerada a partir dos XML guardados, com apuração, ST, DIFAL e FCP.
- Recebimento de NF-e de fornecedores por distribuição de DF-e, com manifestação do destinatário.
- Grupo IBS/CBS e tributos aproximados da Lei 12.741.

### Frente de loja
- Código de barras e balança, promoções, vendedor e comissão, CPF na nota, limite de desconto.
- Devolução de NFC-e no caixa com NF-e de entrada.

### Financeiro, contábil e operação
- Integração entre módulos: Derrama como livro único dos tributos, com título no financeiro.
- Retenções (como tomadora), correção contábil por estorno e lançamento novo.
- Backoffice para empresas do Simples Nacional: estoque com custo médio, financeiro, contábil com razão e DRE, compras e faturamento.
- Boletos e CNAB para os bancos 001, 033, 104, 237, 341 e 756; TEF Cielo.
- `o script de publicacao`: testes 100% → backup → envio → conferência → rollback automático.

### Correções
- DRE e balancete calculavam sobre competência vazia.
- Conversão de dinheiro de REAL para NUMERIC pelo caminho que preserva os centavos.
- Comentários que ainda citavam SQLite foram trocados por PostgreSQL.
- `/pdv` deixou de depender do caminho fixo `/opt/geban/public`: agora
  respeita `GEBAN_PUBLIC_DIR` e cai para `public/` relativo ao diretório
  de trabalho (necessário para a instalação Windows all-in-one).

### Empacotamento e instalação
- `deploy/`: instalador do servidor Linux (modelo central + web) com
  units systemd para interface, API, agendador e periférico.
- `packaging/windows/`: pacote all-in-one para Windows — `geban-setup.exe`
  (NSIS) com advplc.exe, launcher Go que sobe o PostgreSQL embarcado,
  interface, API e agendador; instalação por usuário, sem administrador.
- Agente de periféricos PDV para Windows documentado em
  `packaging/windows/pdv/` (build via PyInstaller, no Windows).

## [v0.10]
- Integração do PDV ao GEBWEB; correção do boot do gebweb em produção.

## [v0.9] e anteriores
Ver o histórico de tags do git (`v0.6` a `v0.9`).
