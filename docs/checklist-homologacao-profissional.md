# Homologação manual — profissional e empresa

Use aparelho Android real e ambiente de teste com API, MySQL e migrations atuais. Para empresa, use conta separada. Não use documentos ou dados pessoais reais.

**Contexto de teste:** siga `homologacao-beta-local.md`. Use API não produtiva, banco descartável e contas sintéticas. Pedidos e aceites no processo normal devem permanecer bloqueados; habilite perfis apenas pelo fluxo administrativo de teste local, com as proteções de ambiente configuradas. Não altere o banco diretamente. Registre resultados reais em aparelho, sem antecipar caixas por testes de widget.

**Limite:** habilitação de teste não confirma identidade nem qualificação para produção. A confirmação de proposta reserva horário, sem pagamento processado no app. Produção continua bloqueada até aprovação e homologação de habilitação, privacidade/jurídico, segurança e operação.

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
- [ ] Manter o perfil pendente e confirmar que ele não recebe pedidos; depois habilitá-lo pelo painel somente para teste local.

## Disponibilidade e agenda

- [ ] Criar, editar e remover horários semanais.
- [ ] Conferir a agenda mensal e os bloqueios/disponibilidades configurados; pedidos existentes só podem ser registros legados de teste.
- [ ] Testar horário fora da disponibilidade.
- [ ] Com a habilitação local de teste, receber pedido sintético e enviar proposta com preço, data, horário, duração e opções corretos.
- [ ] Confirmar que a proposta só reserva a agenda depois da confirmação do cliente e que não há pagamento processado pelo app.
- [ ] Testar recusa pelo cliente, nova proposta, cancelamento, atualização da tela e expiração dos prazos.
- [ ] Registrar como o sistema se comporta em horários sobrepostos com durações diferentes.
- [ ] Conferir que a duração cabe no período, que um bloqueio de dia remove sugestões, que atendimentos consecutivos são permitidos sem intervalo (P06) e que pedidos antigos mantêm o intervalo histórico.

## Pedidos, endereço e chat

- [ ] Antes da habilitação local, confirmar que o perfil pendente não recebe pedidos nem acessa endereço completo/chat de um atendimento.
- [ ] Depois da habilitação local, responder ao pedido sintético, conversar e enviar proposta; confirmar que endereço e agenda só são liberados conforme o estado previsto.
- [ ] Após confirmação da proposta pelo cliente, conferir o atendimento na agenda e no histórico; conferir recusa, cancelamento e expiração.
- [ ] Confirmar que a ação de teste local não é apresentada como aprovação profissional definitiva.
- [ ] Tentar aceitar solicitações concorrentes para a mesma data/horário; confirmar que apenas uma operação conflitante é aceita.
- [ ] Confirmar que o profissional não recebe o endereço completo antes do estado previsto; testar abertura do chat e atualização após resposta/proposta.
- [ ] Testar conversa de atendimento encerrado e registrar se a interface comunica que o envio não está disponível.
- [ ] Concluir o fluxo com o cliente e confirmar histórico/avaliação.

## Documentos e avaliações

- [ ] Abrir seletor nativo e selecionar PDF válido de até 5 MB.
- [ ] Repetir com JPEG e PNG.
- [ ] Testar arquivo inválido, arquivo acima de 5 MB e cancelar o seletor.
- [ ] Confirmar nome/tipo do arquivo e retorno de sucesso/erro.
- [ ] Conferir status pendente e atualização após decisão administrativa.
- [ ] Conferir avaliações recebidas, média e quantidade após avaliação aprovada.

## Resultado

- [ ] Fluxo autônomo de teste local concluído; sem aprovação de operação real.
- [ ] Cadastro e oferta de empresa testados em conta sintética, sem considerar equipes, habilitação de integrantes ou substituições como homologadas.
- [ ] Registrar equipes e substituições como pendência operacional até definição das regras e implementação da apresentação/aceite pelo cliente.
- [ ] Falhas, passos, horários e capturas registrados sem expor documentos.
