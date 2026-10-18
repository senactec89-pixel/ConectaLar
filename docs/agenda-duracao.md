# Agenda com duração por serviço

Decisão P06 aprovada pelo usuário em 18/10/2026, para RF011/RF012/RF014/RF015/RF018/RF030:

- O profissional informa a duração de cada oferta em minutos. O formulário e a API exigem um inteiro positivo, limitado a 1440 minutos por atendimento.
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

1. Aplicar a migration `DuracaoAtendimentos1760123000000` explicitamente no banco apropriado, usando `npm run db:migration:run`. Nesta tarefa foi usado somente um MySQL temporário e isolado.
2. Publicar API e Flutter compatíveis: versões antigas do formulário não enviam a duração de novas ofertas e recebem erro de validação.
3. Revisar atendimentos já aceitos antes da migration: atribuir 120 minutos pode revelar sobreposições históricas. Nenhum atendimento é cancelado ou reagendado automaticamente.
4. Conferir criação/edição da oferta, alteração posterior da duração, atendimento consecutivo, horários sobrepostos e dois aceites simultâneos.

Os testes de integração precisam de uma API local, banco descartável, seed administrativo e `EXPOSE_EMAIL_VERIFICATION_CODE=true` sem SMTP real. A confirmação de e-mail é realizada pelos testes; a proteção das rotas permanece ativa. Nunca habilitar a exposição de códigos em produção.
