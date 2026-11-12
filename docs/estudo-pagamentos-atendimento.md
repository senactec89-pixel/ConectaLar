# Pagamentos para atendimento - estudo e simulacao local

**Status:** estudo inicial, nao e politica aprovada, contrato com provedor,
parecer juridico ou autorizacao para movimentar dinheiro. Os termos atuais da
API informam que pagamentos sao realizados fora do aplicativo. Nao alteramos
esses termos, nao ativamos cobrancas e nao criamos contas ou credenciais.
Solicitacoes e confirmacoes continuam bloqueadas pelas regras existentes.

## Direcao em discussao

**Decisao de sequenciamento:** a integracao de pagamento dentro do aplicativo e
o repasse condicionado ao atendimento ficam para uma etapa futura, depois que
o aplicativo e o fluxo principal de atendimento estiverem funcionando. Nesta
etapa, nao implementar cobranca, retencao ou repasse pelo app, nem anunciar
pagamento protegido. Quando o tema for retomado, os responsaveis devem confirmar
o provedor e suas tarifas, se ele permite liberar o valor somente apos a
conclusao, e as regras de cancelamento, disputa e reembolso. A possibilidade de
pagamento direto entre cliente e profissional tambem deve ser definida antes de
ser apresentada como opcao do produto.

Um dos responsaveis considera que o cliente possa pagar por um parceiro de
pagamentos e que o repasse ao profissional so ocorra depois de o profissional
informar a conclusao e o cliente confirma-la. Isso depende de confirmacao com
o outro responsavel, regras operacionais e revisao de privacidade e juridica.
Os responsaveis pensam em usar o Mercado Pago, ainda como candidato. Nao foi
verificado se o produto disponivel para o ConectaLar permite reter valores e
libera-los nessa condicao. Dividir pagamentos entre participantes (`split`) nao
comprova, por si so, que existe essa possibilidade.

A conversa tambem considerou 50% antes e 50% depois, pagamento integral antes
ou integral no dia. Nao esta decidido se todos os pagamentos devem passar pelo
aplicativo. Se somente metade for paga ao parceiro, nao presumir que a outra
metade ja foi paga ou garantida. Pagamento em dinheiro ou Pix direto entre as
partes nao pode ser identificado como confirmado pelo parceiro automaticamente.

## Sugestao de modelo inicial gratuito

Um responsavel concordou com as sugestoes gerais discutidas, mas o modelo de
pagamento ainda depende da decisao dos dois responsaveis e de confirmacao do
Mercado Pago. Minha recomendacao para um primeiro piloto e:

- Nao cobrar assinatura nem comissao do cliente ou profissional pelo ConectaLar.
- Enquanto o parceiro e o fluxo de liberacao nao estiverem confirmados, nao
  receber nem guardar dinheiro em uma conta propria do ConectaLar. As partes
  combinam Pix ou dinheiro diretamente e registram no resumo o valor, o meio e
  quando pretendem pagar. O app nao consegue confirmar esse pagamento nem
  garantir reembolso nesse modelo.
- Para reduzir o risco de adiantamento sem entrega, sugerir pagamento no dia do
  atendimento ou apos a execucao. Adiantamento ou pagamento dividido so deve ser
  combinado claramente pelas partes; o app nao deve sugerir que protege ou
  reembolsa esses valores automaticamente.
- Se futuramente o pagamento passar pelo Mercado Pago, continuar sem tarifa do
  ConectaLar e uma escolha possivel, mas nao elimina as tarifas do provedor. Os
  responsaveis terao de decidir se o custo do Mercado Pago e absorvido pela
  plataforma ou descontado do valor recebido pelo profissional, e informar isso
  antes da confirmacao.
- So anunciar pagamento protegido ou repasse apos conclusao se o Mercado Pago
  confirmar por escrito que o produto contratado permite esse fluxo para os
  meios escolhidos, inclusive Pix se oferecido, e apos definir disputas,
  cancelamentos, reembolsos e quem assume cada custo.

Essa recomendacao mantem o uso gratuito para as duas partes, mas o modelo
direto nao oferece retencao, confirmacao automatica nem garantia de reembolso.
Se a protecao por pagamento dentro do app for requisito para o piloto, a
integracao financeira e uma dependencia de lancamento, nao algo que se possa
substituir por apenas registrar o pagamento no resumo.

## Modalidades levantadas para discutir

Um responsavel sugeriu apresentar tres modalidades ao cliente. Elas ainda nao
estao aprovadas pelos dois responsaveis, e as duas primeiras dependem de o
Mercado Pago confirmar o fluxo, as taxas e a forma de reembolso:

1. **Integral pelo app antes do atendimento.** O cliente paga o valor total na
   plataforma de pagamentos. So oferecer como pagamento condicionado a conclusao
   se o provedor confirmar que consegue manter o saldo sem libera-lo ao vendedor
   ate o evento aprovado. Se o profissional cancelar ou nao comparecer e o
   atendimento nao for remarcado, sugestao: devolver integralmente ao cliente o
   que foi efetivamente cobrado. Taxas nao recuperaveis e prazo de devolucao
   precisam ser explicados e decididos antes de prometer essa regra.
2. **30% pelo app antes e 70% na chegada.** Para que ambas as parcelas tenham
   registro e eventual reembolso pelo provedor, sugestao: cobrar as duas pelo
   checkout do parceiro, com a segunda parcela confirmada antes de iniciar o
   servico. Se os 70% forem pagos diretamente ao profissional em dinheiro ou
   Pix, essa parte fica fora do controle e da conciliacao do app. A parcela
   inicial, a ausencia e o cancelamento ainda precisam de regras proprias.
3. **Pagamento direto ao profissional.** As partes combinam Pix ou dinheiro e
   registram o meio e o momento no resumo. O ConectaLar nao confirma o pagamento,
   nao retira o valor do profissional e nao garante o reembolso. A tela deve
   identificar claramente que o pagamento ocorre fora da plataforma.

Em qualquer modalidade, sugestao: se o profissional cancelar ou nao comparecer,
oferecer remarcacao ou iniciar reembolso do valor pago pelo app; nao liberar
automaticamente dinheiro contestado. Se o cliente cancelar, o profissional
cancelar depois de iniciar o servico, houver atendimento parcial, dano ou
discordancia sobre a conclusao, o resultado financeiro permanece pendente ate
que os responsaveis definam prazos, criterios, provas, taxas e canal de revisao.
Nao chamar a modalidade de "protegida" nem prometer reembolso ate que o fluxo
esteja confirmado com o provedor, aprovado pelos responsaveis e revisado
profissionalmente.

**Recomendacao de implementacao:** desenhar as tres escolhas no resumo como
proposta de produto, mas manter a cobranca pelo app desativada ate haver resposta
formal do Mercado Pago e regras aprovadas. Se precisarem iniciar um piloto antes
disso, disponibilizar apenas pagamento direto, com aviso explicito de que o app
nao verifica nem garante a transacao. Manter o uso gratuito nao elimina as
tarifas do provedor; os responsaveis precisam decidir se a plataforma absorve
essas tarifas ou se elas sao descontadas do valor recebido pelo profissional.

## Como alinhar a decisao com os dois responsaveis

Um responsavel indicou preferencia por deixar o uso gratuito para cliente e
profissional e considerar que o ConectaLar pague as tarifas de processamento,
dependendo do valor. Isso ainda nao e compromisso financeiro nem decisao dos
dois responsaveis. Antes de implementar, fechar nesta ordem:

1. **Confirmar a oferta e os custos:** criar uma aplicacao em ambiente de teste
   e perguntar ao Mercado Pago qual tarifa vale especificamente para o produto
   Marketplace/Split escolhido, por meio de pagamento e prazo de recebimento.
   Confirmar se ha outras taxas, requisitos ou custos fixos.
2. **Confirmar o caminho do dinheiro:** perguntar em que conta o valor fica,
   quando o vendedor pode movimenta-lo, se e possivel condicionar o repasse a
   conclusao confirmada, e quem precisa ter conta vinculada. Nao presumir que
   passar pelo checkout significa que o dinheiro fica retido pelo ConectaLar.
3. **Escolher quem absorve a tarifa:** calcular o custo em valores de exemplo e
   decidir se a plataforma consegue absorve-lo sem cobrar assinatura ou
   comissao. Se nao conseguir, apresentar a alternativa aos dois responsaveis
   antes de cobrar qualquer valor dos usuarios.
4. **Fechar regras de cancelamento e devolucao:** definir resultado para
   cancelamento pelo cliente, cancelamento/falta do profissional, atendimento
   parcial, contestacao e ausencia de resposta do cliente. Distinguir devolver
   pagamento de cancelar uma cobranca ainda nao aprovada; confirmar os prazos e
   taxas efetivos do provedor.
5. **So entao desenhar o fluxo:** apos o cliente aceitar a proposta, definir
   quando a cobranca e feita, quanto tempo a vaga fica reservada aguardando
   pagamento, quando o atendimento passa a confirmado e como ficam as opcoes
   integral e 30/70. Nas duas opcoes pelo app, registrar cada parcela como uma
   transacao confirmada pelo provedor. A opcao de pagamento direto deve ficar
   identificada como externa e sem garantia de conciliacao pelo ConectaLar.

Se o custo couber no orcamento, absorver a tarifa e coerente com a intencao de
nao cobrar cliente nem profissional. Se nao couber, minha recomendacao e
reavaliar o modelo com os dois responsaveis, em vez de esconder a tarifa ou
prometer uma protecao financeira que o produto contratado nao ofereca.

## O que foi preparado

O arquivo `apps/api/test/support/pagamento-simulado.mjs` e uma ferramenta
exclusiva de teste: funciona em memoria e nao possui conexao de rede, banco,
rota, interface de usuario, credencial ou movimentacao financeira. Nenhum
codigo da API de producao chama essa simulacao.

Os exemplos ficticios testam os seguintes comportamentos conservadores:

- Valores usam centavos inteiros; eventos repetidos iguais nao duplicam saldo.
- Uma declaracao do profissional, sozinha, nao simula autorizacao de repasse.
- Uma contestacao bloqueia a confirmacao e o repasse ficticio.
- No cenario de repasse integral, valor ainda nao pago impede a simulacao do
  repasse integral, mesmo depois da confirmacao da conclusao.
- O repasse simulado nao pode ocorrer duas vezes.

Esses comportamentos sao apenas hipoteses para testes. Nao resolvem pagamentos
parciais, retencao efetiva, prazos, reembolso, saldo real, disputas ou fraudes.
Nao tratam informacoes recebidas do navegador como comprovacao de pagamento.
Executar somente os testes ficticios com:

```powershell
cd apps/api
node --test test/pagamento-simulado.test.mjs
```

## Decisoes necessarias

1. Confirmar com os responsaveis quais pagamentos serao internos: total,
   parcelas ou apenas adiantamentos, e se pagamento externo continuara opcional.
2. Pesquisar parceiro e confirmar documental e contratualmente: habilitacao de
   profissionais/empresas, meios aceitos, retencao real ate evento solicitado,
   prazo de repasse, taxas, limites, reembolso e suporte a disputas. Verificar
   se as contas e atividades de cada participante sao elegiveis.
3. Definir o que ocorre se pagamento for parcial, cliente nao confirmar,
   servico for parcial, houver dano, contestacao ou cancelamento. Nao prometer
   reembolso ou repasse automatico antes de decidir e revisar essas regras.
4. Decidir como registrar cada parcela, seu vencimento e a situacao real da
   transacao. Definir conciliacao, tratamento de erro e comunicacao as partes.
5. Obter revisao profissional de privacidade, juridica, tributaria e financeira,
   inclusive dados, responsabilidades, termos, compartilhamento e retencao.

## Candidato: Mercado Pago

Consulta a documentacao oficial em 7 de novembro de 2026:

Criar e gerenciar uma aplicacao de integracao e acessar a API sao etapas de
desenvolvimento; a documentacao oferece acesso gratuito a API. Isso nao quer
dizer que processar vendas seja gratuito. A pagina geral de Checkout consultada
em 10 de novembro de 2026 informa cobranca por venda, sem mensalidade, e exibe
como referencia 0,99% para Pix e 3,98% a 4,98% para cartao, variando conforme o
prazo de recebimento. Esses valores sao do checkout geral e **nao devem ser
assumidos como tarifa aprovada para o Split de marketplace do ConectaLar**. A
taxa aplicavel deve ser confirmada na conta, no produto Marketplace selecionado
e com o atendimento comercial antes de decidir ou divulgar precos.

- A [integracao de split 1:1](https://www.mercadopago.com.br/developers/pt/docs/split-payments/split-1-1/integration-configuration/integrate-marketplace)
  descreve divisao automatica entre vendedor e marketplace e vinculacao do
  vendedor via OAuth. Isso nao demonstra retencao ate a conclusao do servico.
- A documentacao de [reserva e captura de valores](https://www.mercadopago.com.br/developers/pt/docs/checkout-api-orders/payment-management/reserve-capture-cancel)
  descreve uma reserva de limite de cartao com captura posterior; nesse fluxo,
  a captura deve ocorrer em ate cinco dias e e do valor integral. Nao e prova
  de retencao de Pix pago ou de repasse manual apos conclusao.
- A [documentacao de notificacoes](https://www.mercadopago.com.br/developers/pt/docs/checkout-pro-preferences/payment-notifications)
  descreve avisos de pagamento e assinatura para validacao. Sua aplicacao deve
  ser confirmada para o produto e a modalidade de integracao escolhidos.

Antes de implementar um fluxo financeiro, perguntar ao Mercado Pago:

1. Qual produto permite que um marketplace de servicos receba via Pix e mantenha
   o valor sem repasse ate a confirmacao de conclusao? A liberacao pode ser
   solicitada por API? Onde o dinheiro fica e qual e o prazo maximo?
2. Esse produto aceita pagamentos em duas etapas, como 50% antes e 50% depois?
   Como funcionam repasses parciais, cancelamentos, devolucoes e disputas?
3. Quais contas, documentos, autorizacoes, taxas e prazos sao exigidos da
   plataforma e de cada profissional ou empresa? Ha ambiente de teste que cubra
   esses fluxos? Como sao tratados falhas de repasse e eventos duplicados?

Nao foi confirmada a disponibilidade de retencao de Pix ou de liberacao sob
demanda para o ConectaLar. Nao enviar credenciais ao chat nem ativar pagamentos
de producao enquanto isso e as revisoes necessarias estiverem pendentes.

Na documentacao publica consultada, Split 1:1 descreve divisao automatica entre
vendedor e marketplace com autorizacao OAuth por vendedor. Ela tambem diz que
configuracoes de data de liberacao de comissao dependem de contato com executivo
comercial de carteira assessorada. Isso nao confirma que o saldo do profissional
possa ficar retido ate o cliente confirmar um servico, nem que Pix tenha esse
comportamento. As tarifas do Mercado Pago sao descontadas antes da comissao do
marketplace; reembolsos no split podem depender de saldo disponivel na conta do
vendedor. Confirmar as condicoes da conta e do produto contratado antes de
desenhar o fluxo.

## Implementacao futura, apos as decisoes

- Projetar contrato da API e migrations sem movimentar dados ou alterar pedidos
  antigos; testar em banco descartavel antes de avaliar qualquer implantacao.
- Integrar um parceiro confirmado, com credenciais guardadas no servidor;
  nunca colocar segredos no app, no repositorio ou em conversas.
- Confirmar pagamentos e repasses consultando o parceiro e validando seus
  eventos; garantir idempotencia, reconciliacao e controle de acesso.
- Implementar a regra aprovada de conclusao, contestacao, cancelamento,
  devolucao e eventual repasse, incluindo falhas e suporte operacional.
- Fazer testes em ambiente de homologacao do parceiro, com contas e valores de
  teste, sem solicitar informacoes financeiras reais dos participantes.
- Atualizar termos, telas e comunicacoes somente apos as revisoes e aprovacoes.

Nenhuma etapa deste arquivo habilita pagamentos, solicitacoes ou atendimento real.
