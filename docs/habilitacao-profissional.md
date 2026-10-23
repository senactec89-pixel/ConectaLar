# Habilitacao profissional: preparacao de seguranca

Estado em 18/10/2026: preparacao implementada; NAO e verificacao real de identidade,
prova de vida, telefone ou antecedentes. O usuario confirmou que ainda nao existe
fornecedor contratado nem politica juridica aprovada. Todas essas etapas permanecem
pendentes. Nenhuma flag de ambiente ou aprovacao documental libera o atendimento.

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
  disponiveis. O catalogo pode mostrar perfis, mas informa `podeReceberSolicitacoes=false`.
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

A conta ID ZapSign foi criada e a chave foi gerada, mas ela nao foi inserida em
nenhum ambiente. A migracao `1760124000000-IdentidadeProfissionalZapSign` ainda
precisa ser aplicada em ambiente descartavel. O adaptador exige
`ID_ZAPSIGN_ENABLED=true` e `ID_ZAPSIGN_API_KEY`; mantenha a flag desligada e a
chave fora do VPS ate revisar o aviso de privacidade/consentimento biometrico e os
termos com assessoria adequada. A comprovacao da identidade por si so nao libera
atendimentos: a habilitacao continua bloqueada enquanto telefone, antecedentes e
analise administrativa nao estiverem resolvidos.

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
- API: build e typecheck aprovados; 45 testes unitarios/contratuais aprovados.
- Flutter: `flutter analyze lib test` sem apontamentos; 205 testes aprovados.
- MySQL local: conexao recusada (ECONNREFUSED). Migration NAO aplicada ao banco
  de uso diario e teste MySQL isolado ignorado por falta de ambiente habilitado.
- Nao foi gerado APK nem homologada verificacao com fornecedor real.

- Perfil antigo verificado e novo perfil: ambos continuam sem poder atender.
- POST de solicitacao e aceite via API: 409, sem gravacao ou notificacao de sucesso.
- Pedido antigo aceito/concluido: endereco oculto ao profissional, visivel ao titular.
- Agenda: nao expor endereco por um caminho alternativo.
- Inicio de identidade: 503 com corpo vazio; 400 com `aprovado`, CPF ou selfie.
- Cliente nao pode consultar/alterar habilitacao profissional ou administrativa.
- Admin sem MFA: 403 na leitura e na decisao; ativar MFA e autenticar novamente.
- Suspender e solicitar revisao duas vezes: permanece suspenso, apenas um pedido ativo.
- Reabrir: volta a pendente, nunca habilitado. Tentativa de aprovar: 409.
- Erro ao persistir auditoria: transacao nao pode confirmar alteracao do estado.
- Telas em 360, 390 e 412 px, texto ampliado, erro, vazio e nova tentativa.

Teste MySQL isolado: com DB_HOST local e credenciais de teste com permissao de
criar/apagar bancos, compilar a API e executar
`node --test test/integration/habilitacao-mysql.test.mjs` com
`CONECTALAR_MYSQL_SECURITY_TEST=1`. O teste cria um banco aleatorio exclusivo,
aplica todas as migrations e o remove no final; nao usa o banco em DB_NAME.
Valida concorrencia de pedidos de revisao, constraint da auditoria, rollback
quando a auditoria falha e protecao do historico na reversao da migration.
Sem essa flag, o teste e explicitamente ignorado, nao contado como homologacao.
O roteiro antigo `fluxos.test.mjs` ainda descreve aceites liberados e nao serve
para homologar esta fase bloqueada; sera necessario atualiza-lo quando a integracao
real permitir habilitar contas de teste de forma controlada.

Referencias para a futura politica (nao substituem revisao juridica):
- LGPD: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm
- Serpro: https://centraldeajuda.serpro.gov.br/duvidas/pt/avisos/datavalidsenatran/
- PF: https://www.gov.br/pf/pt-br/assuntos/antecedentes-criminais/antecedentes-criminais/
