# Fluxo completo de atendimento - proposta de trabalho

**Status:** direcoes operacionais abaixo aprovadas pelos dois responsaveis em
conversa. Este registro nao e parecer juridico, checklist tecnico homologado,
contrato definitivo nem autorizacao para coletar documentos reais ou realizar
atendimentos. Catalogo, procedimentos de habilitacao e controles ainda dependem
das revisoes indicadas; partes do fluxo podem nao existir no aplicativo.

**Bloqueio atual:** a API deve continuar recusando novas solicitacoes e aceites
enquanto a politica de habilitacao nao estiver aprovada e homologada. Fazer
desenvolvimento e testes apenas em ambiente isolado, com dados ficticios. Nao
aplicar migrations no banco do aplicativo nem contornar o bloqueio por conta de
qualquer etapa deste documento.

**Pagamento no app:** cobranca, retencao e liberacao de valores pelo aplicativo
ficam para etapa futura. Nesta fase, o resumo pode registrar valor, metodo e
condicao de pagamento que cliente e profissional combinaram diretamente, como
informacao declarada pelas partes. O app nao recebe, verifica, retem, garante ou
reembolsa esse pagamento; nao mostrar um pagamento como confirmado sem uma
integracao que o comprove. Multas, compensacoes e reembolsos nao serao
automatizados nesta fase.

## Divisao do trabalho

- **Fluxo do atendimento:** os dois responsaveis definem o percurso do pedido a
  conclusao, com apoio do assistente para organizar regras, estados, excecoes e
  requisitos tecnicos.
- **Catalogo e operacao:** o amigo revisa a lista de servicos, inclusoes,
  exclusoes e opcoes selecionaveis, comecando por limpeza residencial.
- **Empresas e equipes:** os dois responsaveis definem cadastro, habilitacao de
  cada integrante, substituicoes e comunicacao ao cliente.
- **Privacidade e juridico:** os dois responsaveis preparam o inventario e
  encaminham finalidades, acessos, retencao, avisos, contestacao e termos para
  revisao profissional antes de dados reais.

## Direcoes aprovadas pelos responsaveis

- O cliente inicia o pedido escolhendo o servico e as tarefas desejadas, e pode
  escrever uma observacao adicional. O pedido inicial nao e o acordo final.
- A primeira resposta do profissional serve para aceitar a conversa e negociar;
  nao confirma por si so o atendimento nem bloqueia o horario na agenda.
- Se o profissional nao responder ao pedido inicial em 48 horas, contadas da
  criacao e disponibilizacao do pedido, o pedido expira. Depois
  da primeira resposta, a negociacao sem proposta pendente expira apos 96 horas
  sem nova mensagem de qualquer lado. Cada nova mensagem reinicia esse prazo.
- Enquanto conversam, o horario continua disponivel para outros clientes.
- O profissional prepara uma proposta-resumo com o combinado. O cliente pode
  aceitar ou recusar; se recusar, volta ao chat para negociar e o profissional
  pode enviar uma nova versao. Cada nova versao inicia outro prazo de 48 horas;
  se o horario do servico chegar antes, a proposta expira nesse momento.
- O cliente nao edita uma proposta enviada. A confirmacao deve se referir a
  versao exata que ele viu. A confirmacao final precisa verificar novamente a
  disponibilidade do horario.
- A proposta deve apresentar servico e tarefas, preco, data e horario, local,
  cliente, equipe prevista e materiais. Pode registrar a condicao de pagamento
  combinada pelas partes como declaracao, sem afirmar que o pagamento foi
  realizado ou verificado. O resumo e um registro do acordo no app, nao uma nota
  fiscal.
- A negociacao pode ser encerrada por qualquer lado, com motivo registrado. A
  lista de motivos e a comunicacao ainda precisam ser fechadas. Se ninguem
  enviar nova mensagem por 96 horas, a negociacao expira; uma nova mensagem de
  qualquer lado reinicia a contagem.
- Antes do inicio do servico, cliente ou profissional pode cancelar o
  atendimento confirmado, informando motivo; o app registra quem pediu, quando
  e o motivo e notifica a outra parte. Depois do inicio, usar o relato de
  problema/suporte para tratar interrupcao ou incidente. Multas, compensacoes e
  reembolsos nao serao automatizados nesta fase.

**Escopo de dados desta etapa:** reutilizar as tabelas existentes de solicitacao,
propostas numeradas e opcoes snapshot. A confirmacao grava estado, preco,
data/horario/duracao acordados e auditoria; nao requer migration nova. Nao
armazenar cartao, chave Pix, comprovante, split, saldo, taxa, repasse, reembolso
ou status de pagamento. Equipe, identidade e endereco detalhado ficam fora deste
recorte ate aprovacao das regras e da revisao de privacidade.

- Se o servico ja tiver comecado e surgir um problema, usar o fluxo de relato de
  problema e suporte, em vez de cancelamento comum. O profissional deve avisar
  pelo chat assim que souber que vai atrasar. Como regra inicial, apos 15 minutos
  o cliente pode pedir atualizacao; apos 30 minutos sem contato, pode registrar
  ausencia e solicitar cancelamento. Isso nao aplica multa nem decide
  responsabilidade automaticamente.
- Se houver dano ou uma tarefa fora do combinado, interromper a parte afetada,
  avisar a outra parte e abrir um relato no app. Registrar somente informacoes
  necessarias ao atendimento do caso. O suporte inicial fica com os dois
  responsaveis; nao prometer prazo de resposta ate medir a capacidade. Nao ha
  atribuicao automatica de culpa, multa ou reembolso.
- Na chegada, o app deve mostrar a equipe prevista e permitir que o cliente
  registre a chegada ou informe uma divergencia. Isso e um registro no app, nao
  uma verificacao formal de identidade.
- Na conclusao, o profissional informa que terminou e o cliente confirma ou
  relata problema. Nao concluir automaticamente nem liberar pagamento apenas
  porque o cliente nao respondeu; o prazo e o tratamento da falta de resposta
  ainda dependem da politica operacional e financeira.
- A ideia de divulgar, opcionalmente, uma vaga cancelada com desconto para a
  regiao, sem dados do cliente anterior, fica para uma etapa posterior.

Estas direcoes registram a decisao de produto dos dois responsaveis. A
implementacao e a operacao ainda dependem de checklist tecnico, revisao de
privacidade/juridica e homologacao. A integracao de pagamento pelo app foi
adiada; o registro declaratorio de condicoes externas nao e pagamento protegido.

## Mapa geral

Preparacao de regras e catalogo -> cadastro e habilitacao -> cliente escolhe
profissional e tarefas -> profissional responde -> conversa -> proposta com
resumo -> cliente aceita ou recusa -> atendimento confirmado -> execucao ->
conclusao e possivel avaliacao. Desvios, como cancelamento ou substituicao,
precisam de regras proprias.

## 1. Antes de receber pedidos

1. Os responsaveis organizam o catalogo por categoria e servico. Montagem de
   moveis fica em Manutencao; cozinha e banheiro sao opcoes da limpeza padrao.
2. Para cada servico, definem tarefas selecionaveis, limites e informacoes
   necessarias. Um profissional experiente revisa o checklist e a assessoria
   revisa os temas juridicos e de privacidade pertinentes.
3. Servicos podem existir no catalogo sem estar disponiveis para contratacao.
   Limpeza comum, pintura interna simples e montagem delimitada sao apenas
   candidatas a avaliacao; eletrica e outras tarefas continuam fora ou adiadas
   conforme a ficha por categoria. Nao liberar tarefa por ser selecionavel.
4. Nao ha teto fixo de participantes nem limite fixo de bairros nesta proposta.
   A disponibilidade deve refletir areas atendidas e nao promete cobertura nacional.

## 2. Cadastro e habilitacao

**Cliente:** cria conta, conforme o fluxo e os avisos aprovados. O uso do
endereco e a hora de mostra-lo ao profissional dependem dos controles de acesso
aprovados, sem expor endereco completo apenas por iniciar uma conversa.

**Profissional individual:** cria conta, informa servicos e area atendida. A
direcao proposta e avaliar evidencia pertinente a cada tarefa: experiencia
estruturada ou curso relacionado podem ser alternativas para algumas atividades,
conforme criterio tecnico aprovado. Nao exigir carteira de trabalho ou curso
generico automaticamente. Declaracao e documento, por si so, nao garantem
competencia, identidade ou seguranca. Tarefas tecnicas podem exigir criterios
especificos que ainda precisam de avaliacao.

**Empresa e equipe:** aceitar profissionais individuais e empresas. A empresa
tem um responsavel; cada pessoa executora deve ter cadastro individual vinculado
a empresa, sem compartilhamento de contas. Toda pessoa que possa entrar na
residencia, inclusive ajudantes, deve ser informada na proposta e passar pelo
processo de identidade e habilitacao definido para sua funcao. Metodos, dados e
verificacoes continuam sujeitos a avaliacao tecnica e de privacidade.
Substituicao exige informar a nova pessoa, verificar os requisitos aplicaveis e
obter aceite do cliente antes do atendimento. Se o cliente nao aceitar, a
empresa pode propor outra pessoa ou cancelar; nao aplicar penalidade automatica
enquanto a politica correspondente nao estiver definida.

**Revisao:** inicialmente um responsavel faz a primeira analise e o outro a
segunda; quem fez a primeira nao encerra sozinho a decisao. Se um estiver
ausente, o caso aguarda disponibilidade ou vai a substituto previamente
designado; nao prometer prazo ate medir a capacidade. Permitir correcao ou
reenvio com motivo claro e instrucao objetiva. Contestacao vai ao outro
responsavel. Enquanto a revisao necessaria estiver pendente, a pessoa nao fica
habilitada para a tarefa. Telefone confirmado demonstra apenas acesso ao canal;
nao comprova identidade. Analise documental, sozinha, nao habilita o profissional.

## 3. Cliente inicia o pedido

1. Cliente escolhe categoria, servico e profissional ou empresa disponivel.
2. Para o fluxo proposto, seleciona **pelo menos uma tarefa** antes de enviar.
   Escopo-base de limpeza aprovado pelos responsaveis para revisao do catalogo:
   varrer e passar pano, tirar poeira de superficies acessiveis, lavar a louca
   existente, limpar banheiro e arrumar superficialmente os quartos. O cliente
   escolhe ambientes e pode escrever observacao. Isso nao inclui organizacao de
   pertences. O amigo responsavel pelo catalogo e o profissional experiente
   ainda devem revisar opcoes, limites e criterios de interrupcao antes de
   cadastrar ou oferecer a tarefa.
3. Informa os demais dados necessarios e a preferencia de data/horario, conforme
   as regras que forem aprovadas. O preco inicial, se houver, nao e por si so o
   preco final combinado.
4. Envia o pedido. A lista inicial informa o que precisa; ainda nao e acordo final.

Como exclusoes iniciais da limpeza residencial padrao, manter limpeza pesada,
mover moveis grandes, janelas em altura, mofo extenso, pragas, residuos
perigosos e limpeza pos-obra. Piscina e outras limpezas especializadas devem ser
servicos separados. Nao incluir tarefas nao aprovadas como texto livre para
contornar os limites do catalogo. O amigo responsavel pelo catalogo e o
profissional experiente ainda devem validar esta lista. A criacao de pedido
permanece bloqueada na API.

## 4. Primeira resposta e conversa

1. O profissional ou representante da empresa recebe o pedido.
2. Pode responder para iniciar a negociacao, sem que essa primeira resposta
   signifique que o atendimento ja esta confirmado.
3. Cliente e profissional conversam pelo chat sobre tarefas, preco, data,
   horario e equipe, respeitando os limites da tarefa.
4. Se o profissional nao responder em 48 horas contadas da entrega do pedido,
   o pedido inicial expira. O profissional informa um motivo ao recusar; a lista
   de motivos ainda precisa ser definida.
5. Qualquer lado pode encerrar a negociacao com motivo registrado. Se nao houver
   proposta aguardando resposta e nenhum dos lados enviar mensagem por 96 horas,
   a negociacao expira. Cada nova mensagem reinicia o prazo. O sistema deve
   avisar os participantes antes de encerrar; o momento e o canal do aviso ainda
   precisam ser definidos.

**Diferenca do codigo atual:** o status atual de aceite do profissional leva a
`aceita_agendada`, e o chat ja funciona em alguns estados de pedido, inclusive
aguardando resposta. Para o desenho novo, revisar estados, agenda, notificacoes,
chat e compatibilidade; nao presumir que o aceite atual signifique apenas
interesse em conversar.

## 5. Proposta e segunda confirmacao

1. O profissional prepara e envia uma proposta com o resumo do combinado.
2. O resumo proposto deve permitir conferir servico e tarefas, preco, data e
   horario, local, pessoa que contratou e equipe prevista. Quantidade e nomes da
   equipe dependem do cadastro e da politica de identidade e privacidade aprovados.
   Mostrar endereco completo apenas aos papeis e no momento autorizados.
3. Enviar a proposta representa a oferta do profissional; nao exigir um segundo
   clique dele para confirmar a mesma versao, conforme direcao discutida.
4. O cliente confere e aceita ou recusa. Ele nao edita a proposta: se recusar,
   os dois voltam a conversar e o profissional pode enviar nova proposta.
5. Ao aceitar, a confirmacao deve estar vinculada exatamente a versao exibida.
   Uma nova versao nao pode usar automaticamente a confirmacao anterior.

O resumo e um registro do combinado dentro do aplicativo; nao e nota fiscal.
A direcao discutida e dar ao cliente 48 horas para responder a cada versao,
com expiracao antecipada quando o horario do servico chegar primeiro. Uma nova
versao reinicia o prazo. Confirmar notificacoes, fuso e comportamento quando o
horario ja estiver indisponivel.

## 6. Agenda e alteracoes depois da confirmacao

- A confirmacao pelo cliente deve verificar se a proposta continua valida e se
  o horario ainda esta disponivel; tratar respostas simultaneas sem confirmar
  duas vezes o mesmo horario.
- A direcao discutida e nao reservar o horario enquanto houver negociacao. O
  aceite final do cliente deve validar disponibilidade atomicamente; se outra
  solicitacao ja ocupou o horario, nao confirmar e orientar as partes a negociar
  nova data.
- Alteracoes em tarefas, preco, data, horario ou equipe depois da confirmacao
  exigem nova versao da proposta e aceite explicito do cliente. A proposta
  aceita anteriormente nao e editada; permanece como registro ate que a nova
  versao seja aceita ou o atendimento seja cancelado. Mudanca de horario exige
  nova verificacao de disponibilidade. Registrar historico e quem aceitou cada
  versao.
- Substituicao exige informar a nova pessoa, verificar os criterios aplicaveis
  e obter aceite do cliente antes da visita. Se recusada, a empresa pode propor
  outra pessoa ou cancelar, sem penalidade automatica nesta fase.
- Qualquer lado pode cancelar antes do inicio, com motivo registrado e aviso a
  outra parte. Depois do inicio, problemas e interrupcoes seguem o fluxo de
  suporte. Multas, compensacoes e reembolsos nao serao automatizados nesta fase.
  A divulgacao opcional de horario com desconto apos cancelamento e futura e
  nao pode revelar informacoes do cliente anterior.

## 7. Chegada, execucao e conclusao

1. Antes da visita, cliente pode consultar quem esta previsto no atendimento,
   conforme os controles aprovados. O app permite registrar chegada ou informar
   divergencia; isso nao e uma verificacao formal de identidade.
2. Se surgir pedido fora do combinado, o profissional nao executa aquela parte
   antes de conversar com o cliente. Mudanca precisa seguir o processo aprovado;
   tarefa fora dos limites de seguranca ou nao aprovada nao vira permitida por
   acordo no chat.
3. Se houver situacao que exija interrupcao, pessoa diferente da prevista,
   incidente ou dano, usar o procedimento e canal de suporte a definir. Definir
   se o restante do atendimento pode continuar conforme o caso.
4. Proposta: o profissional informa a conclusao e o cliente confirma ou contesta,
   aproveitando o fluxo existente apos conferir compatibilidade. Avaliacoes e
   denuncias seguem regras proprias; prazos, acesso e moderacao ainda requerem
   revisao conforme a politica aprovada.

## 8. Estados para planejar

Nomes abaixo sao ilustrativos, **nao estados implementados ou contrato final**:

| Momento | Significado proposto |
|---|---|
| Pedido aguardando resposta | Cliente enviou a solicitacao; ainda nao ha acordo final. |
| Em negociacao | Profissional respondeu e as partes podem conversar. |
| Proposta aguardando cliente | Profissional enviou uma versao do resumo. |
| Proposta recusada | Cliente recusou aquela versao; pode haver nova conversa. |
| Atendimento confirmado | Cliente aceitou a versao valida e as demais verificacoes passaram. |
| Cancelado ou recusado | Encerramento conforme regras e permissoes a definir. |
| Conclusao aguardando cliente | Profissional informou conclusao; cliente ainda precisa responder. |
| Concluido ou contestado | Resultado conforme o fluxo de conclusao aprovado. |

A mudanca deve considerar pedidos historicos e os estados existentes. Nao
transformar automaticamente pedidos antigos em negociacoes ou novos acordos.

## 9. O que ja existe e o que precisa ser feito

**Na copia local:** catalogo e administracao, vinculo de novas ofertas e telas de
busca/oferta integradas; chat, proposta de preco, reagendamento e conclusao ja
possuem fluxos que devem ser analisados para reaproveitamento. As migrations do
catalogo foram testadas em banco descartavel e nao aplicadas ao banco do app.

**Preparacao do banco:** a migration `1760141000000-OpcoesEPropostasAtendimento`
cria tabelas complementares para opcoes por servico, escolhas iniciais, propostas
numeradas e opcoes das propostas. Comecam vazias; opcoes novas ficam desativadas
por padrao. Foi testada em MySQL descartavel, inclusive sobre pedido antigo, e
nao foi aplicada ao banco do aplicativo. O rollback recusa apagar dados dessas
tabelas. Nao foram semeadas opcoes de limpeza nem criados registros de equipe.

Essa estrutura nao converte solicitacoes antigas. A API valida participante,
pertinencia e versao da proposta. A confirmacao para teste local revalida
habilitacao, validade, data futura e disponibilidade na mesma transacao que aceita
a versao exata, grava o preco final e reserva o horario. A politica de acesso,
retencao e dados da equipe permanece pendente; o resumo completo ainda nao exibe
equipe ou endereco detalhado.

**API local nesta etapa:** ha rotas de consulta/administracao de opcoes e de
selecao no pedido; negociacao sem agendamento; propostas com versao, tarefas,
preco e horario; listagem, recusa pelo cliente e vencimento da proposta em 48
horas ou no inicio do atendimento, o que ocorrer primeiro. Pedido inicial sem
resposta profissional expira 48 horas apos a criacao; a resposta da API inclui
`expiraEm`, o status vira `expirada` e e gravado evento de auditoria. A primeira
resposta e a negociacao iniciada; em pedidos antigos, uma mensagem do profissional
tambem conta como resposta. A API rejeita resposta tardia mesmo antes da proxima
rodada do job. Na negociacao, cada mensagem reinicia 96 horas de inatividade;
uma proposta pendente impede o encerramento e segue o prazo proprio de 48 horas.
Ao vencer, o estado muda para `negociacao_expirada` e o evento fica auditado.
Propostas, pedidos e negociacoes vencidos sao processados por um job de fundo
que roda ao iniciar a API e depois a cada minuto, em lotes de ate 100 de cada tipo.
O job nao envia notificacao de vencimento e nao garante execucao enquanto todas
as instancias da API estiverem desligadas; ao voltar, processa os vencimentos
atrasados. A migration `1760144000000-ExpiraNegociacaoInativa` precisa ser aplicada
antes de iniciar esta versao contra o banco do aplicativo. Pedidos com opcoes
esperam a primeira resposta para enviar mensagens.
Proposta antiga nao pode ser respondida.
Negociacao e criacao de pedidos continuam bloqueadas pela habilitacao; a
confirmacao final desta rota so funciona fora de producao com
`HABILITACAO_MANUAL_LOCAL=true` e perfil explicitamente aprovado para teste local.
Em producao continua recusada. A confirmacao nao processa nem atesta pagamento.

**Telas locais preparadas:** administracao de opcoes por servico; selecao de
opcoes ativas no pedido; acesso aos itens solicitados e propostas; envio pelo
profissional; recusa ou confirmacao pelo cliente, com revisao explicita do resumo
e aviso de que pagamento nao e processado pelo app. A confirmacao real continua
bloqueada.
O primeiro aceite de pedidos com opcoes inicia negociacao, sem agendar; pedidos
antigos mantem seu fluxo. As telas dependem das migrations e da API atualizadas
em ambiente isolado e nao significam que o fluxo completo esteja homologado.

**Ainda por projetar e implementar:** homologacao completa da confirmacao local;
resumo completo com endereco e equipe; conciliacao com orcamentos/reagendamentos
antigos; alteracoes apos confirmacao; identidade, habilitacao, substituicao e
controles dependentes das decisoes; testes integrados de ponta a ponta em ambiente
isolado. Nenhuma tarefa foi cadastrada automaticamente.
Evitar duplicar os recursos existentes sem analisar o contrato e a compatibilidade.

Em cada etapa: testar banco descartavel, API, autorizacoes e estados; depois
testar as telas com dados ficticios. Ao final, testar tambem concorrencia,
indisponibilidade, pedido recusado, alteracao de proposta e que o bloqueio de
solicitacoes/aceites continua ativo. Nao coletar documentos reais nem abrir
contratacoes ate aprovacao e homologacao separadas.

## 10. Pendencias de validacao e implementacao

| Tema | Pendente / proxima acao | Quem participa |
|---|---|---|
| Opcoes de tarefas | Revisar escopo-base de limpeza, opcoes, exclusoes e criterios de interrupcao | Amigo responsavel pelo catalogo e profissional experiente |
| Identidade e habilitacao | Definir metodo, evidencia, dados e verificacao adequados por funcao | Responsaveis, especialista e assessoria |
| Contas e equipe | Implementar conta individual vinculada a empresa, permissoes e exibicao segura | Responsaveis e revisao de privacidade |
| Substituicao | Implementar nova proposta, aceite do cliente e alternativa se houver recusa | Responsaveis e revisao pertinente |
| Reserva e alteracoes | Implementar nova versao, aceite e validacao de disponibilidade | Equipe tecnica |
| Atraso, ausencia e incidentes | Implementar registro, notificacao e suporte; medir capacidade antes de definir SLA | Responsaveis e assessoria |
| Pagamento inicial | Resumo registra condicoes externas declaradas; processamento no app fica para depois | Responsaveis; revisao pertinente antes de lancamento |
| Retencao e acesso | Definir dados, bases, perfis, fornecedores, backups e prazos | Responsaveis e assessoria de privacidade |

Referencias: [ficha por categoria](ficha-analise-categorias-piloto.md),
[perguntas para as revisoes](perguntas-regras-privacidade-piloto.md),
[proposta de habilitacao](proposta-politica-habilitacao-piloto.md) e
[fluxo do catalogo](fluxo-catalogo-categorias-servicos.md).
