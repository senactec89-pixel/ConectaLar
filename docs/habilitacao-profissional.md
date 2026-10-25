# Habilitacao profissional: preparacao de seguranca

Estado em 25/10/2026: a API e a interface Flutter para posse de telefone por codigo
WhatsApp estao implementadas e testadas com MySQL isolado e respostas simuladas. O
recurso permanece desativado: `ID_ZAPSIGN_PHONE_ENABLED=false`; nenhum codigo real foi
enviado nem credito consumido. O aviso exibido no app ainda precisa de aprovacao juridica
antes de uma homologacao com fornecedor. Antecedentes seguem pendentes de politica.
Nenhuma confirmacao de telefone ou aprovacao documental libera atendimentos.

## Impacto da atualizacao

- `verificado` continua significando apenas analise documental. Nao e autorizacao
  para entrar na residencia, qualificacao tecnica ou garantia de seguranca.
- Novas solicitacoes e aceites retornam 409 `PROFISSIONAL_HABILITACAO_PENDENTE`,
  inclusive para profissionais antigos com documento aprovado e para empresas.
- Enderecos completos de pedidos antigos ficam ocultos ao profissional nas rotas
  de consulta/listagem de pedidos e agenda. O cliente titular e o administrador
  preservam o acesso permitido anteriormente. Mensagens ja trocadas nao sao apagadas:
  o controle nao remove enderecos anteriormente compartilhados em texto ou capturas.
- Cadastro, documentos permitidos, edicao de perfil e consulta de historico continuam
  disponiveis. O catalogo pode mostrar perfis, mas informa `podeReceberSolicitacoes=false`,
  `atendimentoStatus=em_verificacao` e uma mensagem publica generica. O app apresenta
  o aviso "Em verificacao - pedidos indisponiveis" sem expor o motivo privado.
- O aplicativo mostra as pendencias em Documentos e verificacao. O admin tem a tela
  Habilitacoes profissionais com paginacao, MFA obrigatorio e registro de decisoes.
- Suspender, reabrir e iniciar analise nunca aprovam. Pedir revisao nao remove suspensao.
  A solicitacao e idempotente enquanto nao for tratada pelo administrador.
- Nao aplicar esta versao esperando que a demo anterior continue criando atendimentos.
  O bloqueio e deliberado enquanto as dependencias de seguranca nao forem concluidas.

## Banco e implantacao

A migration `1760123000000-HabilitacaoProfissional` adiciona estado e data de pedido
de revisao em `profissionais`, indice e CHECK de estados, alem de ampliar as acoes
permitidas na auditoria. Todos os perfis existentes comecam pendentes. Nenhuma conta
e excluida e nenhum documento e promovido para identidade confirmada.

A migration `1760134000000-ProfissionalTelefoneZapSign` foi aplicada com sucesso em um
MySQL 8.4.9 descartavel junto com a sequencia completa de migrations. O teste verificou
a tabela e a invalidacao do registro, e confirmou que rollback nao apaga historico.
O banco de desenvolvimento e o banco Hostinger nao foram usados. Durante o teste,
tambem foi corrigida a migration de agenda que tentava recriar `duracao_minutos` ja
criada pela migration anterior; agora ela preserva essa coluna e adiciona somente o
intervalo de deslocamento.

1. Revisar o impacto, fazer backup e homologar em banco descartavel.
2. Parar a API antiga durante a implantacao coordenada.
3. Carregar as variaveis do ambiente correto e executar `npm run db:migration:run`.
4. Executar `npm run typecheck` e `npm test`, reiniciar a API e distribuir o app atualizado.
5. Conferir pendencias e bloqueios com contas de cliente, profissional e admin com MFA.

A migration nao deve ser aplicada automaticamente no banco de uso diario durante
o desenvolvimento. O rollback recusa remover a estrutura quando ha auditorias novas,
para nao apagar o historico ou deixar registros fora da constraint antiga. Nao
reverter para a API antiga como forma de contornar os bloqueios.

## Integracao de identidade em preparacao

A integracao externa esta preparada, mas nao ativada: nao configurar a chave em
producao nem iniciar consultas pagas antes da revisao de privacidade, da interface e
da homologacao controlada. A conta e a chave ID ZapSign existem. A API de WhatsApp foi
implementada com flag independente, inicialmente desligada. A revisao manual nao deve
simular resultado de fornecedor nem conceder habilitacao automaticamente.

Existe um adaptador de servidor para ID ZapSign. Ele cria uma verificacao hospedada
de documento com prova de vida e consulta o resultado pela API do fornecedor. O app
recebe somente a URL hospedada e o estado; a chave permanece em
`ID_ZAPSIGN_API_KEY` no servidor. O ConectaLar nao envia CPF, selfie ou imagem facial
ao proprio backend, e nao persiste os detalhes pessoais devolvidos pelo fornecedor.
O banco guarda apenas o usuario associado, identificadores da verificacao, estado,
datas de validade/resolucao e registro da versao e data do consentimento. Repeticoes
reaproveitam uma chave de idempotencia.

A API nao faz polling automatico: o profissional atualiza o estado no app, que faz
uma consulta autenticada ao backend. O backend consulta ID ZapSign apenas enquanto a
verificacao estiver pendente. A URL retornada e validada para HTTPS e o host oficial
`id.zapsign.com.br` antes de ser apresentada ao usuario.

A chave do fornecedor nao foi usada nesta homologacao e nenhuma chamada externa foi
feita. A migration de telefone foi homologada apenas no banco temporario descrito acima;
isso nao equivale a homologar o fornecedor. A prova de vida usa `ID_ZAPSIGN_ENABLED`; posse de telefone
usa separadamente `ID_ZAPSIGN_PHONE_ENABLED`; ambos exigem `ID_ZAPSIGN_API_KEY`. Mantenha
as flags desligadas e a chave fora do VPS ate aprovar o aviso/consentimento e concluir
os testes. A API registra telefone vinculado, estado, datas e versao do aviso; nao
persiste o OTP. A confirmacao so prova acesso ao canal WhatsApp naquele momento, nao
identidade nem titularidade civil do numero. Tambem nao libera atendimentos: a
habilitacao continua bloqueada enquanto antecedentes e revisao administrativa nao
estiverem resolvidos.

O fluxo usa `POST /profissionais/me/habilitacao/telefone` para solicitar o envio,
`POST /profissionais/me/habilitacao/telefone/confirmacao` para submeter codigo e
`GET /profissionais/me/habilitacao/telefone` para consultar estado. Exige consentimento
explicito, nao devolve o telefone completo, usa idempotencia nas tentativas, respeita
cooldown de 10 minutos e limita a tres iniciacoes por dia por conta. O fornecedor
permite tres tentativas de codigo e validade de 10 minutos; a API nao fixa o tamanho do
OTP. Mudanca de telefone invalida as verificacoes anteriores na mesma transacao.

## Revisao manual provisoria

Antes de qualquer piloto com pessoas reais, documentar um procedimento aprovado pela
equipe e por assessoria adequada. A revisao manual deve usar apenas documentos e dados
necessarios, acesso restrito no painel, registro de quem revisou e quando, prazo de
retencao/exclusao, canal de contestacao e alternativa para casos inconclusivos. Nao
baixar documentos para celulares ou computadores pessoais, nao enviar documentos em
chats, nao registrar codigos ou dados sensiveis em logs e nao fazer pesquisas de
antecedentes por conta propria.

A tela de moderacao documental atual e uma revisao de documentos; ela nao confirma
posse do telefone, nao equivale a verificacao biometrica, nao prova qualificacao
profissional e nao libera solicitacoes. Ate que exista fluxo manual formal, testado e
aprovado, manter pedidos e aceites bloqueados. Um piloto deve ser supervisionado e
nao deve expor clientes a atendimentos residenciais sem as salvaguardas definidas.

Antes de ativar em producao, definir e documentar:

- base legal, finalidade, aviso ao titular, retencao/exclusao, contrato de tratamento
  e avaliacao de impacto para biometria;
- revisao humana segura e alternativa acessivel para resultados inconclusivos;
- confirmacao real de telefone e nova verificacao apos alteracoes de identidade;
- empresas: verificar cada pessoa que entrara na residencia, nao apenas CNPJ ou representante;
- tratamento administrativo de casos `revisao_necessaria` sem aceitar aprovacao automatica.

O provedor nao oferece webhook para este fluxo: o app solicita atualizacao manual e a
API consulta o resultado autenticado. Nao ha aprovacao de habilitacao nesta fase. A
futura liberacao exigira completar telefone, antecedentes, analise humana, revogacao,
expiracao e validacao operacional; nao basta alterar uma constante.

## Antecedentes ainda pendentes

Nao sao feitas pesquisas, coletadas certidoes ou aplicadas reprovacoes criminais.
O upload so aceita os tipos documentais ja suportados; tipos como `selfie`, `biometria`
e `antecedentes_criminais` sao recusados. Isso nao classifica o conteudo de um arquivo
enviado com um tipo falso: a equipe deve evitar coletar material fora da finalidade.

Antes de ativar esta etapa, a assessoria juridica deve definir fontes, finalidade,
criterios proporcionais ao servico, homonimos, periodicidade, retencao e contestacao.
Nao interpretar qualquer processo como condenacao, nem certidao como garantia de
seguranca. A triagem cadastral atual nao constitui analise de antecedentes.

Decisoes usam motivos enumerados, sem texto livre para CPF, detalhes criminais ou
biometria em logs. A auditoria registra ator, alvo, acao, motivo e data na mesma
transacao do estado. Analise documental atualiza somente o selo, sem sobrescrever
suspensoes concorrentes da habilitacao.

## Roteiro de homologacao

Verificacoes locais desta entrega:
- API: `npm run typecheck` passou e `npm test` passou com 107 testes. O teste MySQL
  descartavel passou; o fluxo administrativo MySQL separado foi ignorado porque usa
  variaveis de habilitacao distintas.
- Flutter: analise dos arquivos alterados sem apontamentos; os tres testes novos de
  telefone passaram (recurso desligado, consentimento/fluxo e retry idempotente).
  O teste geral de widgets ainda tem duas falhas em expectativas antigas da Home;
  o teste de habilitacao existente tambem acusa overflow numa tela admin, fora deste fluxo.
- MySQL 8.4.9: sequencia completa de migrations e teste de habilitacao passaram num
  banco aleatorio local; nenhum banco de desenvolvimento, producao ou Hostinger foi alterado.
- Nao foi gerado APK nem homologada verificacao com fornecedor real.

- Perfil antigo verificado e novo perfil: ambos continuam sem poder atender.
- POST de solicitacao e aceite via API: 409, sem gravacao ou notificacao de sucesso.
- Pedido antigo aceito/concluido: endereco oculto ao profissional, visivel ao titular.
- Agenda: nao expor endereco por um caminho alternativo.
- Inicio de identidade: 503 com corpo vazio; 400 com `aprovado`, CPF ou selfie.
- Telefone: flag desligada => 503 sem chamada; consentimento ausente => 400; codigo
  invalido nao e enviado; retries usam o mesmo UUID; novo codigo usa UUID novo; limite
  do fornecedor, expiracao e telefone alterado nao podem marcar como confirmado.
- Cliente nao pode consultar/alterar habilitacao profissional ou administrativa.
- Admin sem MFA: 403 na leitura e na decisao; ativar MFA e autenticar novamente.
- Suspender e solicitar revisao duas vezes: permanece suspenso, apenas um pedido ativo.
- Reabrir: volta a pendente, nunca habilitado. Tentativa de aprovar: 409.
- Erro ao persistir auditoria: transacao nao pode confirmar alteracao do estado.
- Telas em 360, 390 e 412 px, texto ampliado, erro, vazio e nova tentativa.

Teste MySQL isolado: `npm run test:integration:mysql` inclui os testes de fluxo e
habilitacao. Para a migration de habilitacao, requer MySQL de teste em loopback,
credenciais com permissao de criar/apagar banco e `CONECTALAR_MYSQL_SECURITY_TEST=1`.
O teste cria um banco aleatorio exclusivo, aplica todas as migrations e remove esse
banco; nao usa o banco em `DB_NAME`. Valida concorrencia de revisao, auditoria, a tabela
de telefone sem coluna OTP, invalidacao do numero e protecao contra rollback com dados.
Sem as flags de cada teste, ele e explicitamente ignorado, nao contado como homologacao.
O roteiro `fluxos.test.mjs` representa a politica atual: o perfil permanece pesquisavel,
mas a solicitacao e o aceite sao bloqueados enquanto a habilitacao estiver pendente.

Referencias para a futura politica (nao substituem revisao juridica):
- LGPD: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm
- Serpro: https://centraldeajuda.serpro.gov.br/duvidas/pt/avisos/datavalidsenatran/
- PF: https://www.gov.br/pf/pt-br/assuntos/antecedentes-criminais/antecedentes-criminais/
