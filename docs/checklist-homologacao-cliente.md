# Homologação manual — cliente

Use aparelho Android real conectado à rede do servidor. A API deve apontar para um MySQL descartável de teste, com migrations atuais aplicadas. Registre data, modelo/versão do aparelho, build do app, commit, base URL sem credenciais, usuário de teste e resultado. Não use dados pessoais reais.

**Modo local de homologação:** o fluxo ponta a ponta pode ser testado somente com API não produtiva, banco descartável, contas sintéticas e `HABILITACAO_MANUAL_LOCAL=true`. Um administrador deve usar a ação **aprovar teste local**; não altere o banco diretamente. Nesse modo, a proposta pode ser confirmada e o horário reservado, mas nenhum pagamento é processado pelo app. Com a flag desligada ou `NODE_ENV=production`, a habilitação manual não pode liberar o profissional.

**Critério de lançamento:** esse modo serve apenas para teste interno/fechado. Não habilita contratação real nem substitui revisão de habilitação, privacidade/jurídica, segurança ou operação. Não use dados pessoais ou documentos reais.

## Preparação

- [ ] API responde em /health e os endpoints de negócio estão montados.
- [ ] MySQL está conectado e migrations atualizadas.
- [ ] App foi iniciado com a URL alcançável pelo aparelho.
- [ ] Contas e dados são exclusivos de teste.
- [ ] Registrar capturas sem tokens, e-mails pessoais, endereços completos ou documentos.

## Cadastro, login e conta

- [ ] Abrir e ler os termos antes de aceitar.
- [ ] Criar conta cliente com dados de teste e senha forte.
- [ ] Tentar senha que não atende aos critérios e confirmar validação clara.
- [ ] Sair e entrar novamente com a conta criada.
- [ ] Alterar dados e confirmar que permanecem após sair/entrar.
- [ ] Testar sessão expirada e confirmar encaminhamento ao login.

## Endereço e busca

- [ ] Criar um endereço de teste e defini-lo como principal.
- [ ] Editar e remover um endereço, confirmando o resultado na lista.
- [ ] Buscar por termo, categoria e bairro.
- [ ] Conferir estado vazio e erro de API separados.
- [ ] Abrir perfil profissional, conferir avaliação, selo, serviços, preço e favorito.
- [ ] Salvar/remover favorito e confirmar o estado ao voltar e reabrir.

## Solicitação e atendimento

- [ ] Consultar o catálogo e confirmar que profissionais indisponíveis exibem aviso e não parecem contratáveis.
- [ ] Antes da habilitação local, tentar solicitar atendimento a um profissional pendente; confirmar HTTP `409`, ausência de pedido/notificação e código `PROFISSIONAL_HABILITACAO_PENDENTE`.
- [ ] Com o profissional habilitado pelo administrador para teste local, solicitar atendimento e confirmar que pedido, chat e proposta ficam vinculados às contas sintéticas corretas.
- [ ] Conferir os campos de proposta disponíveis hoje (serviços/opções, preço, data, horário e duração); recusar e confirmar que a conversa pode continuar para uma nova proposta.
- [ ] Registrar como pendência qualquer informação ainda ausente do resumo, como materiais, condição de pagamento, equipe prevista ou endereço detalhado; não tratar conversa no chat como pagamento processado ou equipe validada.
- [ ] Confirmar uma proposta de teste e verificar que o horário fica reservado na agenda; confirmar também que o app não cobra, transfere nem registra pagamento como realizado.
- [ ] Testar recusa, cancelamento com motivo, atualização da tela e expiração nos prazos configurados, incluindo proposta sem resposta e negociação sem atividade.
- [ ] Desligar `HABILITACAO_MANUAL_LOCAL` no ambiente de teste e confirmar o bloqueio; verificar o bloqueio em `NODE_ENV=production` pelos testes automatizados, sem alterar uma produção ativa.
- [ ] Testar conclusão, avaliação e denúncia somente com dados sintéticos isolados.

## Resultado

- [ ] Fluxo local ponta a ponta testado apenas com contas e banco descartáveis; isso não aprova contratação em produção.
- [ ] Bloqueio de produção confirmado por teste automatizado/configuração, sem usar contas ou dados reais.
- [ ] Erros/retries registrados com passo e horário.
- [ ] Capturas anexadas ao registro de homologação.
