# Ocorrências e mudanças no atendimento — roteiro operacional

**Estado:** descrição dos caminhos já disponíveis e das decisões ainda pendentes, em 10/11/2026. Este roteiro não autoriza sanção automática nem substitui análise humana. Usar com `docs/politica-operacional-pedidos-propostas.md`.

## Caminhos existentes

| Situação | Ação já disponível | Efeito atual | Ponto a fechar |
| --- | --- | --- | --- |
| Uma parte precisa cancelar | Cancelamento com motivo; no pedido pendente, só cliente; no aceito, as partes podem agir antes do início | Pedido passa a `cancelada`, com motivo e aviso à outra parte | Antecedência padrão de 24 h para cliente, exceções, quem revisa e efeito em horários futuros |
| Horário precisa mudar | Proposta de reagendamento e resposta explícita | Horário do pedido muda apenas após aceite da proposta e conferência de agenda | Prazo de 48 h da proposta, aviso de expiração e como tratar proposta próxima ao início |
| Valor ou trabalho combinado muda | Orçamento proposto e resposta do cliente | Valor final muda após aceite; propostas anteriores ficam no histórico | Como registrar alteração do escopo incluído/opcional e preservar sua versão |
| Profissional marca serviço realizado | Confirmação ou contestação pelo cliente | Atendimento pode ficar aguardando confirmação, ser contestado ou concluído | Prazos e revisão de contestação |
| Uma parte não comparece | Registro de não comparecimento e contestação da outra parte | Ocorrência e motivo ficam vinculados ao pedido | Evidências proporcionais, prazo e decisão humana |
| Há relato de conduta ou segurança | Denúncia ligada ao pedido, inclusive antes do cancelamento | Administração recebe caso de moderação | Categorias, medidas provisórias, direito de resposta e recurso |

## Procedimento proposto para a equipe

1. **Registrar o fato:** vincular a ocorrência ao pedido, autor, instante, tipo e relato mínimo necessário. Não pedir documento sensível ou foto de terceiro sem finalidade definida.
2. **Preservar o combinado:** manter oferta, data, horário, duração, proposta e aceite anteriores no histórico. Mensagem de chat sozinha não muda agendamento, preço ou escopo.
3. **Avisar sem expor dados:** comunicar à outra parte a existência da ocorrência e a próxima ação. Endereço completo, verificação do executor e motivo privado ficam protegidos pelas permissões da API.
4. **Permitir contestação:** registrar resposta da outra parte e encaminhar casos inconclusivos para revisão humana; denúncia ou ausência alegada não prova automaticamente culpa.
5. **Resolver e auditar:** registrar decisão, responsável, momento, justificativa permitida e avisos enviados. Preservar apenas evidências necessárias pelo prazo aprovado na política de privacidade.

## Antes de automatizar

- Definir quais fatos exigem revisão imediata, suspensão de novos pedidos, reagendamento ou cancelamento; uma ocorrência em atendimento já aceito não deve produzir cancelamento automático sem política aprovada.
- Definir como pedidos aceitos em revisão continuam aparecendo na agenda e quem pode acessar o endereço durante essa revisão.
- Definir prazo de resposta e rota de suporte humano, inclusive quando a outra parte não responde ou a rede falha.
- Separar incidente **do serviço** de incidente **de segurança de dados**. O segundo segue o procedimento de privacidade e segurança, com avaliação técnica e jurídica própria.
