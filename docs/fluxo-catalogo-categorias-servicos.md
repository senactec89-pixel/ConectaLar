# Fluxo proposto: categorias e servicos

**Status:** proposta tecnica para validacao dos responsaveis. Ainda nao altera o
app, a API ou o banco e nao aprova tarefas para contratacao. A regra atual de
bloqueio de contratacoes permanece intacta.

## Objetivo

Manter a navegacao por categoria e, dentro de cada categoria, oferecer uma lista
administravel de servicos padronizados. O administrador podera criar e editar
categorias e servicos, alem de retira-los da oferta futura sem apagar historico.

Exemplo:

```text
Limpeza residencial                 categoria
  Limpeza residencial padrao        servico do catalogo
  Limpeza de vidros internos        servico do catalogo

Oferta da profissional Ana:
  Limpeza residencial padrao        preco, duracao, ativa/pausada
```

## Conceitos que precisam ficar separados

1. **Categoria:** agrupador de navegacao, como Limpeza residencial ou Pintura.
2. **Servico do catalogo:** definicao mantida pelo ConectaLar, vinculada a uma
   categoria. Tem nome, descricao, escopo, inclusoes/exclusoes e estado de
   publicacao.
3. **Oferta do profissional:** adesao de um profissional a um servico do
   catalogo, com preco, duracao estimada e estado proprio. Pausar uma oferta nao
   remove o servico para outros profissionais.
4. **Solicitacao:** pedido do cliente para uma oferta. Deve guardar um snapshot
   do nome da categoria, nome/escopo do servico e condicoes relevantes no momento
   do pedido, para que futuras edicoes do catalogo nao reescrevam o combinado.

O nome livre atual da oferta nao deve continuar sendo a identificacao principal
de um servico novo. A oferta deve referenciar um `servico_catalogo_id`; um campo
de observacoes pode detalhar o caso, sem transformar texto livre em nova tarefa.

## Fluxos de uso

### Cliente

1. Escolhe uma categoria ativa.
2. Ve somente os servicos publicados daquela categoria que estao disponiveis na
   regiao atendida.
3. Escolhe o servico e ve seu escopo, inclusoes, exclusoes e orientacoes.
4. Ve profissionais com oferta ativa daquele servico e perfil elegivel.
5. Envia a solicitacao vinculada a oferta e ao servico do catalogo.

Se nao houver servico disponivel, mostrar estado vazio e nao oferecer uma caixa
generica que permita contratar algo fora do catalogo.

### Profissional

1. Abre o catalogo de servicos que pode oferecer.
2. Escolhe uma categoria e um ou mais servicos publicados.
3. Informa os dados permitidos da oferta, como preco inicial e duracao; nao pode
   alterar o nome, a categoria nem os limites definidos pela plataforma.
4. Ativa ou pausa sua propria oferta.

A API valida que o servico esta publicado e pertence a categoria selecionada.
Uma oferta ativa nao significa que o profissional esta habilitado para receber
solicitacoes; a verificacao de habilitacao continua sendo um bloqueio separado.

### Administrador

1. Na tela de catalogo, cria ou seleciona uma categoria.
2. Dentro dela, adiciona servicos com nome, descricao, inclusoes, exclusoes e
   estado inicial de rascunho.
3. Edita textos sem mudar o significado da tarefa. Uma mudanca de escopo cria
   nova versao ou novo servico, em vez de alterar silenciosamente o que clientes
   ja contrataram.
4. Publica, pausa ou arquiva categoria/servico. A publicacao exige os campos
   obrigatorios e registro de quem aprovou; para tarefas de maior risco, exigir
   segunda revisao administrativa antes de publicar.

## Remover, renomear e preservar historico

- **Remover** significa arquivar/desativar para novas ofertas e solicitacoes; nao
  apagar fisicamente registros usados por profissionais ou solicitacoes.
- Ao desativar uma categoria, seus servicos deixam de aceitar novas ofertas e
  solicitacoes. Ofertas e pedidos antigos permanecem consultaveis.
- Ao desativar um servico, bloquear novas ofertas e pedidos para ele. Solicitacoes
  ja criadas preservam o snapshot e seguem os estados normais do atendimento.
- Renomear mantendo o mesmo significado pode preservar o ID; pedidos anteriores
  continuam exibindo o nome salvo no snapshot.
- Se o servico mudou de significado, criar outro registro/versao e arquivar o
  anterior. Nao reutilizar um nome antigo para uma tarefa diferente.
- Toda criacao, edicao de escopo, publicacao, pausa e arquivamento administrativo
  deve gerar auditoria atomica, com ator, data, alvo e valores anterior/novo sem
  incluir dados sensiveis desnecessarios.

## Regras de disponibilidade na API

Uma nova solicitacao somente pode prosseguir quando todas as condicoes estiverem
verdadeiras no servidor:

- categoria ativa;
- servico publicado e ativo, vinculado a essa categoria;
- oferta do profissional ativa e vinculada ao mesmo servico;
- profissional elegivel, regiao atendida e demais regras de negocio satisfeitas;
- contratacoes globalmente habilitadas por decisao explicita e homologacao.

Desativar algo no Flutter nao e controle de seguranca. A API precisa validar os
IDs e estados de novo em cada operacao, inclusive no momento da solicitacao. O
catalogo nao pode remover nem contornar o bloqueio deliberado de habilitacao.

## Modelo de dados sugerido

- Manter `categorias` como entidade existente e incluir somente campos realmente
  necessarios ao fluxo, como ordem de exibicao ou estado de ciclo de vida.
- Criar entidade/tabela de servicos do catalogo com ID estavel, `categoria_id`,
  nome, descricao, escopo, inclusoes, exclusoes, estado, versao e auditoria.
- Adicionar `servico_catalogo_id` a `profissional_servicos`, inicialmente
  nullable para uma migracao compativel; novas ofertas passam a exigir essa
  referencia.
- Manter preco, duracao e ativo em `profissional_servicos`: sao propriedades da
  oferta individual, nao do catalogo global.
- Adicionar snapshot de categoria/servico/versao em `solicitacoes` sem remover
  os campos e relacoes atuais ate concluir a migracao e validar dados historicos.
- Usar exclusao logica/arquivamento. Chaves estrangeiras nao devem apagar em
  cascata pedidos, ofertas ou registros de auditoria.

Os nomes concretos das tabelas e a estrategia de migracao serao definidos apos
inventariar ofertas existentes. Nao mapear automaticamente texto livre para uma
tarefa por semelhanca: itens ambiguos ficam pausados para revisao manual.

## Etapas de implementacao

1. Aprovar a hierarquia: categoria > servico padronizado > oferta do profissional.
2. Revisar a lista de servicos e seus escopos; marcar cada um como rascunho,
   candidato ao piloto, posterior ou fora do piloto.
3. Definir campos obrigatorios e permissoes do painel, incluindo publicacao e
   dupla revisao quando aplicavel.
4. Projetar migration aditiva e plano de compatibilidade para ofertas e pedidos
   existentes; testar rollback/restauracao em banco descartavel.
5. Implementar API e auditoria transacional; cobrir autorizacao, IDs cruzados,
   categoria/servico inativo, oferta pausada e historico/snapshots.
6. Implementar painel para categorias e servicos, com rascunho, publicacao,
   pausa, arquivamento e confirmacao mostrando o impacto em ofertas existentes.
7. Atualizar o fluxo do profissional para selecionar servicos do catalogo e o
   fluxo do cliente para escolher categoria e servico antes do profissional.
8. Migrar manualmente ofertas antigas, homologar com dados ficticios e manter
   contratacoes bloqueadas ate aprovacao separada da habilitacao.

## Decisoes pendentes dos responsaveis

- Quem pode publicar: um administrador ou dois revisores para todas/algumas
  tarefas?
- Quais campos de preco e duracao o profissional pode definir e quais limites a
  plataforma deve impor por tarefa?
- Como registrar no painel as areas atendidas por cada profissional, sem impor
  teto de participantes ou limite fixo de bairros no catalogo?

## Decisoes ja informadas pelos responsaveis

- Montagem de moveis sera um servico dentro da categoria Manutencao.
- Cozinha e banheiro serao opcoes/partes da Limpeza residencial padrao, nao
  categorias separadas.
- Nao havera teto de participantes nem limite fixo de bairros nesta proposta;
  a busca deve refletir as areas que os profissionais efetivamente atendem.
- Os servicos ja listados pelos responsaveis compoem o catalogo pretendido. O
  estado de catalogo nao libera automaticamente a tarefa para receber pedidos.

