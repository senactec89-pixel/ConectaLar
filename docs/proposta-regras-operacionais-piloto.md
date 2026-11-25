# Proposta consolidada de regras operacionais do piloto

**Versao:** minuta para revisao dos dois responsaveis e assessoria juridica  
**Data:** 21/11/2026  
**Status:** consolida diretrizes ja registradas e identifica decisoes pendentes. Nao e contrato, parecer juridico, nem confirmacao de que todos os fluxos estejam implementados ou homologados.

## Objetivo

Reunir em um so lugar como cliente, profissional individual e equipe do ConectaLar
devem lidar com pedidos, mudancas, atrasos, problemas e suporte durante o piloto.
A ideia e revisar esta proposta com o colaborador e levar as perguntas juridicas
ao advogado. Ela nao libera servicos: cada tarefa ainda depende da matriz tecnica
e da aprovacao administrativa correspondente.

## 1. Escopo operacional do piloto

- Atender somente profissionais individuais nesta rodada. Empresas, equipes e
  substituicoes ficam fora do escopo do piloto.
- Mostrar apenas as areas que o profissional realmente atende. Nao prometer
  cobertura onde nao ha profissional disponivel.
- O catalogo pode conter tarefas ainda indisponiveis. Categoria ou perfil
  publicado nao significa que todas as tarefas aceitam pedidos.
- O aplicativo organiza a solicitacao e o combinado; nao garante a identidade,
  a qualidade ou a seguranca do servico.

**Diretriz registrada:** profissionais individuais no primeiro piloto.  
**Pendente:** alinhar todos os documentos e testar que o sistema bloqueia empresas
enquanto o modo de piloto estiver ativo.

## 2. Pedido, proposta e resumo confirmado

O resumo que o cliente aceita deve identificar, de forma compreensivel:

- tarefa(s) e limites do trabalho;
- preco/valor combinado;
- data, horario e duracao;
- profissional responsavel;
- local e informacoes necessarias, conforme os controles de acesso aprovados;
- condicoes externas de pagamento, se os responsaveis decidirem exibi-las.

Enviar um pedido nao confirma o atendimento nem reserva horario. Uma proposta
so altera o combinado depois de uma resposta explicita da outra parte. O chat
ajuda na conversa, mas nao altera sozinho preco, escopo ou agendamento.

**Diretriz registrada:** mudancas depois da confirmacao exigem nova versao e
aceite explicito do cliente; a versao aceita anteriormente permanece no
historico. Mudanca de horario exige nova verificacao de disponibilidade.

**Aplicacao proposta:**

1. O profissional apresenta uma nova versao com o que mudou e o motivo.
2. O cliente aceita ou recusa essa versao.
3. Ate o aceite, vale o resumo ja confirmado. Se a mudanca tornar a tarefa
   insegura ou impossivel, o profissional interrompe a parte afetada e pede
   suporte; nao improvisa nem executa escopo adicional.
4. Se a mudanca for recusada, manter o combinado original quando ainda for
   possivel; caso contrario, usar o cancelamento com motivo. Nao alterar preco
   retroativamente.

## 3. Atraso e ausencia

**Diretriz registrada:** o profissional avisa pelo canal do pedido assim que
souber que vai atrasar. Apos 15 minutos sem a chegada esperada, o cliente pode
pedir atualizacao. Apos 30 minutos sem contato, pode registrar ausencia e pedir
ajuda/cancelamento.

**Limites propostos:**

- O registro de ausencia e um relato, nao uma conclusao automatica de culpa.
- A outra parte deve poder responder e informar o que ocorreu.
- O sistema nao aplica multa, compensacao ou reembolso automaticamente.
- Se houver novo horario, ele deve ser aceito explicitamente e validado na
  agenda; uma mensagem informal nao deve alterar o agendamento.
- Se houver risco imediato, a pessoa prioriza sair da situacao de risco e buscar
  ajuda apropriada; o suporte do aplicativo nao e servico de emergencia.

**Pendente:** definir como o sistema apresenta atrasos quando o profissional
avisa e qual fluxo usar se o cliente nao estiver no local. Os marcos de 15/30
minutos precisam ser homologados no app e na API.

## 4. Dano, risco ou trabalho fora do combinado

**Diretriz registrada:** interromper a parte afetada, avisar a outra parte e
registrar um relato ligado ao pedido.

**Procedimento proposto:**

1. Nao continuar uma atividade que pareca insegura, envolva tarefa nao aprovada
   ou possa ampliar um dano.
2. Registrar apenas o necessario: pedido relacionado, tipo de ocorrencia,
   momento, relato objetivo e proxima providencia. Evitar documentos e dados de
   terceiros sem necessidade definida.
3. Avisar as partes sem revelar endereco ou informacao privada alem do
   necessario.
4. Encaminhar para revisao humana. A plataforma nao decide automaticamente quem
   causou o dano nem promete indenizacao, multa ou reembolso.
5. Guardar somente evidencias necessarias, por acesso restrito e prazo definido
   na politica de privacidade.

**Pendente:** definir categorias de ocorrencia, evidencias proporcionais,
possibilidade de continuar a parte nao afetada e como tratar divergencias. Levar
esses pontos ao advogado e ao profissional experiente.

## 5. Cancelamento

**Diretriz registrada para o cliente:** antecedencia padrao de 24 horas para
cancelar atendimento aceito. Com menos de 24 horas, o cliente ainda pode
cancelar imediatamente, informando motivo; sem revisao previa e sem multa
automatica no app.

**Pedido ainda pendente:** pode ser cancelado pelo cliente e nao reserva horario.

**Atendimento aceito:** registrar autor, motivo e instante; avisar a outra parte
e liberar o horario somente quando o cancelamento tiver sido efetivado no
sistema. Se o profissional nao puder comparecer, deve avisar assim que souber e
solicitar cancelamento/apoio; nao pode enviar substituto nesta rodada.

**Pendente:** classificar excecoes (por exemplo, risco, doenca, forca maior,
endereco inacessivel ou impossibilidade do profissional), definir efeitos em
atendimentos ja iniciados e homologar o comportamento da agenda. Nao automatizar
cobrancas ou sancoes nesta fase.

## 6. Equipe e substituicao

Empresas, equipes e substituicoes nao fazem parte do piloto inicial. O pedido
confirmado e vinculado ao profissional individual apresentado ao cliente. Se
essa pessoa nao puder atender, a recomendacao e cancelar ou propor novo
agendamento com o proprio cliente, sem troca silenciosa de executor.

Uma fase futura com empresas precisara, antes de abrir pedidos:

- cadastro individual de cada pessoa executora e vinculo explicito a empresa;
- verificacao por tarefa para cada executor que possa entrar na residencia;
- informar ao cliente quem esta previsto;
- nova proposta e aceite explicito do cliente para qualquer substituicao;
- alternativa se o cliente recusar, sem substituicao automatica;
- revisao de privacidade, acesso ao endereco, permissao e auditoria.

## 7. Conclusao e avaliacao

O profissional pode registrar que concluiu o trabalho. O cliente deve receber a
oportunidade de confirmar ou relatar um problema; falta de resposta nao deve ser
apresentada como satisfacao nem como avaliacao positiva automatica.

A avaliacao do profissional pelo cliente deve ser opcional. Pode-se convidar o
cliente com perguntas curtas e neutras, sem pressionar por nota positiva. Uma
denuncia ou avaliacao negativa deve ser tratada pelo fluxo apropriado, nao como
prova automatica.

**Pendente:** definir por quanto tempo a conclusao fica aguardando o cliente,
como tratar ausencia de resposta e qual estado final usar quando houver
contestacao. Nao concluir automaticamente ate que essa regra seja aprovada e
testada.

## 8. Suporte e revisao manual

**Diretrizes registradas:** os dois responsaveis fazem o suporte inicial; nao
prometer prazo de resposta antes de medir capacidade. Na habilitacao, uma pessoa
faz a primeira revisao e a outra faz a segunda; contestacao vai ao outro
responsavel. Correcao/reenvio deve indicar motivo claro e instrucao objetiva.
Enquanto a revisao aplicavel estiver pendente, a oferta nao fica habilitada.

**Proposta para operacao:**

- Toda solicitacao de suporte deve ter protocolo/registro ligado ao pedido,
  categoria, responsavel, estado e proxima acao.
- Separar suporte de uso, mudanca de combinado, problema de atendimento,
  habilitacao de profissional e incidente de privacidade/seguranca.
- Restringir acesso aos relatos e anexos a quem precisa tratar o caso.
- Nao prometer SLA ainda; informar que o caso foi recebido e que esta em analise.
- Designar quem cobre a ausencia de cada responsavel; se nao houver substituto,
  o caso aguarda e o usuario recebe essa informacao.
- Correcao/reenvio deve dizer exatamente o que falta e nao pedir mais dados do
  que o necessario.

**Pendente:** escolher o canal oficial de suporte no app e fora dele, definir
responsavel de plantao e testar o registro de ponta a ponta.

## 9. Denuncias e suspensao de conta

Este fluxo **nao esta decidido**. Abaixo esta somente uma base para discutir com
o colaborador e o advogado, sem aplicar sancoes automaticamente.

**Proposta de salvaguardas:**

- Separar: reclamacao sobre resultado/escopo; atraso/ausencia; conduta; risco
  imediato; suspeita de fraude; e incidente de dados.
- Registrar o relato ligado ao atendimento, limitar os dados coletados e
  permitir que a outra parte apresente sua versao, sem divulgar dados privados
  do denunciante quando isso puder expor alguem.
- Uma denuncia isolada nao deve produzir automaticamente culpa, avaliacao
  negativa, multa ou bloqueio permanente.
- Se houver indicio concreto de risco imediato, considerar medida preventiva
  temporaria e proporcional, como pausar novos pedidos enquanto uma revisao
  humana ocorre. Definir quem pode toma-la, quando o segundo responsavel revisa,
  como lidar com atendimentos ja aceitos e como comunicar a medida.
- Decisao duradoura deve ter motivo registrado, revisao por pessoa diferente
  quando possivel, comunicacao clara e canal para resposta/contestacao.
- Definir criterios e prazos com o advogado antes de implementar: tipos de
  medida, evidencias, acesso aos dados, retencao, recurso, comunicacao e
  tratamento de denuncias abusivas ou inconclusivas.

**Nao implementar nem anunciar suspensao automatica** com base apenas em
palavras-chave, nota baixa ou denuncia nao analisada.

## 10. Pagamento nesta fase

**Diretriz registrada:** o app nao processa nem repassa pagamentos, nao guarda
cartao, chave Pix ou comprovante, e nao confirma que o pagamento ocorreu. O
resumo pode registrar apenas como declaracao as condicoes combinadas diretamente
pelas partes, se essa exibicao for mantida.

Nao prometer protecao, garantia, retencao, reembolso ou mediacao financeira pelo
ConectaLar. Multas, compensacoes e reembolsos automatizados ficam fora desta
fase. Texto de termos e responsabilidade deve passar pelo advogado.

## 11. O que ainda impede marcar esta etapa como fechada

1. Advogado revisar denuncias, suspensoes, contestacao, responsabilidades e
   pagamento fora do app; os itens da secao 9 continuam abertos.
2. Responsaveis escolherem canal oficial de suporte, cobertura de ausencia e
   procedimento de escalonamento, sem prometer prazo ainda.
3. Definir resposta quando cliente nao confirma nem contesta conclusao.
4. Especificar excecoes de cancelamento, atendimentos iniciados e casos de risco.
5. Homologar no app/API as regras registradas, especialmente 15/30 minutos,
   mudancas versionadas, pagamentos declaratorios e trilha de suporte.
6. Resolver separadamente privacidade/juridico e a matriz tecnica de tarefas;
   nenhum destes documentos libera servicos para contratacao.

## Fontes internas para revisao

- docs/perguntas-regras-privacidade-piloto.md: direcoes registradas pelos
  responsaveis e itens para completar.
- docs/politica-operacional-pedidos-propostas.md: prazos, expiracao, cancelamento
  e agenda.
- docs/roteiro-ocorrencias-atendimento.md: relatos, contestacao e suporte.
- docs/fluxo-atendimento-proposto.md: fluxo amplo e limites atuais.

