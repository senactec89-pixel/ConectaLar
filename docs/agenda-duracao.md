# Agenda com duração por serviço

Decisão P06 aprovada pelo usuário em 18/10/2026, para RF011/RF012/RF014/RF015/RF018/RF030:

- O profissional informa a duração de cada oferta em minutos. O formulário e a API exigem um inteiro de 1 a 1440 minutos por atendimento; uma nova oferta começa em 120 minutos.
- Serviços e solicitações existentes recebem **120 minutos**, conforme escolha explícita do usuário.
- A solicitação copia a duração da oferta ao ser criada. Editar a oferta depois não encurta nem prolonga os pedidos existentes. Para pedidos sem oferta específica, permanece a duração legada de 120 minutos.
- Horários são datas e horas civis em `America/Sao_Paulo`, sem conversão pelo fuso do servidor.
- Cada perfil aceita um atendimento por vez, inclusive empresas. Não há intervalo adicional: se um atendimento termina às 12h, outro pode começar às 12h.
- A duração inteira precisa caber em um período semanal do mesmo dia. Equipes, múltiplos executores e serviços que atravessem a madrugada continuam fora do formulário atual.
- Solicitações aguardando resposta não reservam horário. O aceite revalida disponibilidade e sobreposição, sob bloqueio do perfil e da solicitação, na mesma transação.

## Contrato

`duracaoMinutos` é obrigatório no cadastro/edição de ofertas e é retornado em ofertas, solicitações e atendimentos da agenda.

`GET /profissionais/{id}/horarios?data=YYYY-MM-DD&servicoId=ID` retorna data, fuso, duração vigente e somente janelas livres que comportem o serviço. Não retorna clientes, IDs de solicitações, endereços ou detalhes de compromissos. O Flutter usa essa consulta para as sugestões; o servidor valida novamente na criação e no aceite, inclusive para horários digitados manualmente.

## Atualização do ambiente

1. Faça backup restaurável do banco e revise os atendimentos aceitos: a normalização pode revelar sobreposições históricas.
2. Aplicar as migrations `DuracaoAtendimentos1760123000000` e `AgendaP06Defaults1760138000000` explicitamente no banco apropriado, usando `npm run db:migration:run`. A segunda migration define os padrões e normaliza ofertas e solicitações existentes para 120 minutos e intervalo zero.
3. Publicar API e Flutter compatíveis. A API ignora qualquer intervalo enviado por cliente antigo e grava zero; versões antigas do formulário podem não enviar duração ao cadastrar ofertas.
4. Conferir cadastro/edição de oferta (incluindo 1 e 1.440 minutos), cópia do snapshot à solicitação, atendimento consecutivo, horários sobrepostos e dois aceites simultâneos. Nenhum pedido será cancelado ou reagendado automaticamente pela migration.

Os testes de integração precisam de uma API local, banco descartável, seed administrativo e `EXPOSE_EMAIL_VERIFICATION_CODE=true` sem SMTP real. A confirmação de e-mail é realizada pelos testes; a proteção das rotas permanece ativa. Nunca habilitar a exposição de códigos em produção.
