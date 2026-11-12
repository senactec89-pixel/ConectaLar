# Homologação manual — profissional e empresa

Use aparelho Android real e ambiente de teste com API, MySQL e migrations atuais. Para empresa, use conta separada. Não use documentos ou dados pessoais reais.

**Contexto:** siga `homologacao-beta-local.md`. Pedidos e aceites no processo normal devem permanecer bloqueados. Para os passos de atendimento, libere manualmente apenas os IDs fictícios de profissional e empresa no banco descartável da beta local. Registre resultado real em aparelho, sem antecipar caixas por testes de widget.

## Cadastro e perfil

- [ ] Ler e aceitar termos; cadastrar profissional autônomo.
- [ ] Cadastrar empresa em conta de teste.
- [ ] Testar validação de senha forte.
- [ ] Entrar, sair e entrar novamente.
- [ ] Preencher/editar perfil, região, categoria e ofertas.
- [ ] Salvar oferta com preço e oferta “a combinar”; confirmar que a solicitação preserva a oferta escolhida.
- [ ] Salvar duração pronta e personalizada (1 e 1.440 minutos); validar erro para 0 e 1.441.
- [ ] Editar uma oferta antiga com duração fora das opções prontas sem perder o valor.
- [ ] Confirmar que editar uma oferta existente não cria duplicata.

## Disponibilidade e agenda

- [ ] Criar, editar e remover horários semanais.
- [ ] Conferir a agenda mensal e os pedidos agendados.
- [ ] Testar horário fora da disponibilidade.
- [ ] Tentar aceitar solicitações concorrentes para a mesma data/horário; confirmar que apenas uma operação conflitante é aceita.
- [ ] Conferir que a duração inteira cabe no período, que um bloqueio de dia remove as sugestões e que dois atendimentos consecutivos são permitidos sem intervalo novo (P06).
- [ ] Conferir que um pedido antigo com intervalo gravado mantém esse bloqueio no histórico.

## Pedidos, endereço e chat

- [ ] Receber solicitação de cliente e confirmar estado inicial.
- [ ] Antes do aceite, confirmar que o endereço completo está protegido.
- [ ] Enviar proposta formal antes do aceite; atualizar a tela e conferir o prazo de resposta de 48 horas.
- [ ] Conferir aceite, recusa e expiração da proposta em pedidos distintos, sem cobrança pelo app.
- [ ] Aceitar uma solicitação e conferir a liberação de endereço permitida.
- [ ] Recusar outra solicitação e conferir estado/motivo visual.
- [ ] Abrir chat, enviar e receber mensagens.
- [ ] Concluir o fluxo com o cliente e confirmar histórico/avaliação.
- [ ] Testar conversa de atendimento encerrado e registrar se a interface comunica que envio não está disponível.

## Documentos e avaliações

- [ ] Abrir seletor nativo e selecionar PDF válido de até 5 MB.
- [ ] Repetir com JPEG e PNG.
- [ ] Testar arquivo inválido, arquivo acima de 5 MB e cancelar o seletor.
- [ ] Confirmar nome/tipo do arquivo e retorno de sucesso/erro.
- [ ] Conferir status pendente e atualização após decisão administrativa.
- [ ] Conferir avaliações recebidas, média e quantidade após avaliação aprovada.

## Resultado

- [ ] Fluxo autônomo concluído.
- [ ] Fluxo de empresa concluído.
- [ ] Falhas, passos, horários e capturas registrados sem expor documentos.
