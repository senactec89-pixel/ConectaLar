# Prazos e ocorrências de atendimento — especificação para decisão

**Estado em 10/11/2026:** o usuário confirmou os prazos e parte dos efeitos abaixo. Esta especificação separa as diretrizes aprovadas das decisões necessárias antes de automatizar encerramentos. Ela não altera estados, agenda nem permissões da API. Referências: P07, P08, P09, P12 e P14 em `.agents/skills/conectalar/references/decisoes-pendentes.md`; RB07–RB13 em `.agents/skills/conectalar/references/regras-de-negocio.md`; `docs/decisoes.md` (P06).

## Prazos comunicados pela equipe

| Situação | Prazo informado | Marco inicial proposto para validar | Consequência ainda por decidir |
| --- | --- | --- | --- |
| Profissional responde a novo pedido | 48 horas; encerra antes se chegar o horário solicitado sem resposta | Registro do pedido no servidor (`criadoEm`) | Aviso prévio, transição atômica e execução após falhas |
| Cliente responde a cada proposta recebida | 48 horas por proposta; sem cancelar atendimento já aceito | Registro da proposta no servidor (`criadoEm`) | Expiração de propostas enviadas pelo cliente ao profissional ainda não foi definida |
| Negociação sem atividade | 96 horas; somente antes do aceite | Última proposta ou resposta formal | Avisos e recuperação após indisponibilidade do processamento |

**Implementação técnica:** há processamento de vencimento para pedidos, propostas pré-aceite, orçamentos e reagendamentos enviados pelo profissional ao cliente. Os pedidos e propostas anteriores às migrations não recebem prazos retroativos automaticamente. Uma proposta de reagendamento não reserva o novo horário. O pedido começa em `aguardando_resposta`; o aceite válido do profissional ou a aceitação pelo cliente de uma proposta formal do profissional pode produzir `aceita_agendada`.

## Decisões necessárias antes da automação

1. **Pedido sem resposta:** ao completar 48 horas, ou ao chegar o horário solicitado caso venha antes, cancelar automaticamente se o profissional não aceitou, recusou ou registrou proposta formal de horário/escopo. Proposta formal interrompe esse prazo. Histórico, motivo legível, ator de sistema e avisos devem acompanhar a transição.
2. **Proposta antes do aceite:** o profissional pode propor horário ou escopo; o cliente tem 48 horas para responder. Aceitar confirma o agendamento somente após revalidar disponibilidade, conflitos e habilitação. Se vencer, a proposta deixa de aceitar resposta, mas o pedido continua pendente até completar 96 horas desde a última ação formal.
3. **Inatividade:** vale somente antes do aceite. Propostas e respostas formais reiniciam o prazo de 96 horas; mensagens de chat e leitura não contam. Ao completar 96 horas, encerrar o pedido pendente com motivo e aviso, sem afetar atendimento já aceito.
4. **Propostas após o aceite:** orçamento e reagendamento enviados pelo profissional ao cliente vencem após 48 horas. O vencimento não cancela o atendimento nem altera o horário ou valor anterior. As regras já existentes também impedem alterações após o início do atendimento; portanto, esse limite pode ser anterior às 48 horas. O prazo para proposta enviada pelo cliente ao profissional permanece sem decisão.
5. **Relógio:** registrar instantes em UTC no servidor e exibir em `America/Sao_Paulo`; definir comportamento para criação perto do horário do serviço, indisponibilidade do agendador, execução repetida e aviso antecipado. Ação feita antes do prazo não pode ser invalidada por uma rotina atrasada; a transição precisa ser atômica.
6. **Comunicação:** confirmar destinatários e texto para aviso de prazo, vencimento e nova proposta. Não incluir endereço completo nem motivo privado em notificação enviada fora da área autenticada.

## Cancelamento, agenda e exceções

- **Diretriz confirmada:** a antecedência padrão é de **24 horas** para cancelamento pelo cliente de atendimento aceito, conforme RB12. Com menos de 24 horas, o cliente ainda pode cancelar imediatamente ao informar motivo; não há revisão prévia nem multa no app. A API exige motivo, registra a exceção no histórico e verifica novamente o início sob bloqueio na transação. O Flutter explica a regra sem bloquear a ação urgente. Essa identificação ainda precisa ser homologada com MySQL e relógios reais.
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

- Validar os prazos, a trilha de auditoria e as mensagens com MySQL e contas isoladas antes do uso real. A antecedência padrão de 24 horas e a exceção imediata com motivo já foram escolhidas.
- Preservar as transições aprovadas. As regras de referência listam cinco estados principais; a API atual também possui `conclusao_pendente`, `conclusao_contestada` e `nao_comparecimento_informado`. A equipe deve reconciliar essa diferença documental sem eliminar dados existentes.
- Especificar resposta da API para `venceEm`, `expirou`, motivo e horário de origem; o Flutter apenas apresenta o prazo e desabilita ações conforme a resposta, sem ser a autoridade sobre expiração.
- Conferir concorrência, idempotência, fuso, notificações e agenda antes de ativar uma rotina automática em dados reais.

## Implantação e limitações

- Aplicar as migrations `1760136000000` e `1760137000000` no ambiente apropriado antes de iniciar a API atualizada; elas não foram aplicadas automaticamente por este documento.
- A apresentação do escopo das ofertas também requer a migration `1760138000000`. As três devem ser homologadas com MySQL isolado e backup antes de qualquer implantação; não há evidência de aplicação em banco real nesta etapa.
- A API consulta os vencimentos em intervalos de aproximadamente um minuto e ao iniciar. Uma interrupção da API atrasa o processamento até o retorno; os endpoints recusam respostas fora do prazo mesmo que a rotina ainda não tenha atualizado o estado visual.
- Os avisos de expiração são gravados como notificações internas. Entrega por push ou e-mail não é garantida por essa rotina.
- O bloqueio de habilitação profissional continua ativo. A criação e o aceite de novos atendimentos, inclusive o aceite de proposta, dependem da conclusão da política e das verificações de segurança.
