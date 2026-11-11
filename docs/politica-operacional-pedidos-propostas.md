# Prazos e ocorrências de atendimento — especificação para decisão

**Estado em 10/11/2026:** o usuário confirmou os prazos e parte dos efeitos abaixo. Esta especificação separa as diretrizes aprovadas das decisões necessárias antes de automatizar encerramentos. Ela não altera estados, agenda nem permissões da API. Referências: P07, P08, P09, P12 e P14 em `.agents/skills/conectalar/references/decisoes-pendentes.md`; RB07–RB13 em `.agents/skills/conectalar/references/regras-de-negocio.md`; `docs/decisoes.md` (P06).

## Prazos comunicados pela equipe

| Situação | Prazo informado | Marco inicial proposto para validar | Consequência ainda por decidir |
| --- | --- | --- | --- |
| Profissional responde a novo pedido | 48 horas; **cancelamento automático se não houver resposta** | Registro do pedido no servidor (`criadoEm`) | Definir resposta qualificadora, aviso prévio, motivo e transição atômica |
| Cliente responde a cada proposta recebida | 48 horas por proposta; **sem cancelar atendimento já aceito** | Registro de cada proposta no servidor (`criadoEm`) | Quais propostas entram na regra e como expiram |
| Negociação sem atividade | 96 horas; **somente antes do aceite** | Última atividade qualificada e registrada no servidor | O que conta como atividade e a precedência frente ao prazo de 48 horas |

**Não há hoje rotina de expiração desses prazos no módulo de solicitações.** Orçamento e reagendamento são registros separados, com seus próprios estados; não são novos estados formais do pedido. Uma proposta de reagendamento não reserva o novo horário. O pedido começa em `aguardando_resposta`; só o aceite válido cria `aceita_agendada`.

## Decisões necessárias antes da automação

1. **Pedido sem resposta:** ao completar 48 horas, cancelar automaticamente usando um estado formal existente. Definir resposta qualificadora, motivo legível, ator de sistema, notificações e possibilidade de novo pedido.
2. **Proposta:** confirmar se o prazo de 48 horas vale para orçamento e reagendamento e como tratar proposta iniciada pelo cliente. Ao vencer, definir como a proposta deixa de aceitar resposta; o atendimento já aceito permanece válido.
3. **Inatividade:** vale somente antes do aceite. Especificar se contam mensagens, respostas formais, proposta nova, leitura de mensagem ou ação administrativa. **No fluxo atual, um pedido sempre pendente e cancelado após 48 horas nunca alcança 96 horas.** A equipe precisa indicar qual resposta formal mantém a negociação pendente após as 48 horas, ou reconhecer que a regra de 96 horas não terá efeito até o fluxo mudar.
4. **Relógio:** registrar instantes em UTC no servidor e exibir em `America/Sao_Paulo`; definir comportamento para criação perto do horário do serviço, indisponibilidade do agendador, execução repetida e aviso antecipado. Ação feita antes do prazo não pode ser invalidada por uma rotina atrasada; a transição precisa ser atômica.
5. **Comunicação:** confirmar destinatários e texto para aviso de prazo, vencimento e nova proposta. Não incluir endereço completo nem motivo privado em notificação enviada fora da área autenticada.

## Cancelamento, agenda e exceções

- **Diretriz confirmada:** aplicar a antecedência mínima de **24 horas** para cancelamento pelo cliente de atendimento aceito, conforme RB12. A API atual permite cancelar até o início; exceções de segurança, doença e força maior ainda precisam de caminho definido antes de mudar API ou mensagem do Flutter. Não presumir multa ou pagamento interno.
- **Pedido ainda pendente:** somente o cliente pode cancelá-lo atualmente. Esse pedido não reserva agenda, conforme P06.
- **Atendimento aceito:** o cancelamento antes do início muda o estado para `cancelada` e registra motivo. Definir efeito de cada exceção, incluindo segurança, doença, força maior, problema de endereço e impossibilidade do executor. A agenda deve considerar o estado resultante e não manter bloqueio após um cancelamento efetivo; preservar trilha de quem tomou a decisão.
- **Horário e orçamento:** mudanças do combinado devem passar por proposta e resposta explícitas. O horário original permanece o válido até o reagendamento aceito; o novo horário só pode ser confirmado após nova verificação de disponibilidade e conflito. Guardar versão anterior, autoria, data e motivo.
- **Depois do início:** há rotas de não comparecimento e contestação da conclusão; definir prazo de relato, evidências permitidas, aviso à outra parte, revisão humana e resultado. Não tratar denúncia como prova automática nem liberar dados privados por causa dela.

## Incidentes distintos

| Tipo | Exemplos | Fluxo a especificar |
| --- | --- | --- |
| Ocorrência do serviço | Não comparecimento, dano alegado, desacordo sobre escopo ou executor | Registro contextual ao pedido, comunicação às partes, contestação, moderação e preservação mínima de evidências |
| Incidente de segurança de dados | Acesso indevido a endereço/documento, exposição de arquivo ou perda de dados | Contenção, investigação, responsáveis, comunicação e registro conforme política de privacidade revisada |

## Critérios para iniciar código

- Fechar resposta qualificadora para as 48 horas, uso efetivo das 96 horas, propostas abrangidas, exceções ao cancelamento e mensagens de aviso. O prazo de 24 horas para o cliente já foi escolhido.
- Registrar transições permitidas usando somente os estados formais existentes: `aguardando_resposta`, `aceita_agendada`, `recusada`, `cancelada` e `conclusao_confirmada`.
- Especificar resposta da API para `venceEm`, `expirou`, motivo e horário de origem; o Flutter apenas apresenta o prazo e desabilita ações conforme a resposta, sem ser a autoridade sobre expiração.
- Conferir concorrência, idempotência, fuso, notificações e agenda antes de ativar uma rotina automática em dados reais.
