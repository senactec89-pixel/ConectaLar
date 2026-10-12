# Homologação manual — cliente

Use aparelho Android real conectado à rede do servidor. A API deve apontar para um MySQL descartável de teste, com migrations atuais aplicadas. Registre data, modelo/versão do aparelho, build do app, commit, base URL sem credenciais, usuário de teste e resultado. Não use dados pessoais reais.

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

- [ ] Abrir solicitação e selecionar oferta, data, horário e endereço cadastrado.
- [ ] Confirmar que não é possível enviar sem endereço.
- [ ] Confirmar que a solicitação aparece como aguardando resposta.
- [ ] Antes do aceite, conferir que o profissional não recebe o endereço completo.
- [ ] Usar conta profissional de teste para aceitar; confirmar endereço liberado somente conforme contrato.
- [ ] Enviar e receber mensagens no chat; atualizar a conversa.
- [ ] Concluir atendimento e confirmar o estado.
- [ ] Enviar avaliação uma vez e conferir que não é possível duplicá-la.
- [ ] Registrar denúncia pelo fluxo do atendimento e conferir confirmação/aviso.
- [ ] Conferir notificação e histórico resultantes.

## Resultado

- [ ] Fluxo concluído sem erro.
- [ ] Erros/retries registrados com passo e horário.
- [ ] Capturas anexadas ao registro de homologação.
