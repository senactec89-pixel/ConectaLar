# MFA e convite administrativo

Toda conta `administrador` precisa confirmar um autenticador TOTP antes de receber um token de acesso completo. Um token de configuracao de curta duracao nao autoriza chamadas administrativas. A API tambem bloqueia a conta por 15 minutos depois de cinco codigos MFA incorretos consecutivos; o contador fica no MySQL para valer entre reinicios.

## Fluxo de convite

1. Um administrador autenticado com MFA convida uma pessoa usando nome, e-mail e telefone opcional.
2. A API cria o usuario, o convite e o e-mail de saida na mesma transacao. O segredo do convite tem 256 bits, e somente seu hash fica na tabela `admin_convites`; a copia necessaria para envio fica criptografada na `email_outbox`.
3. O convite e enviado ao e-mail indicado, expira em 24 horas e so pode ser aceito uma vez. A API nao devolve o token ao administrador.
4. A pessoa informa o codigo recebido, cria a propria senha forte e aceita a versao atual dos termos. O uso concorrente ou repetido e bloqueado pela transacao e pelo bloqueio da linha.
5. A API emite somente um desafio de configuracao MFA de 10 minutos. A pessoa cadastra TOTP e confirma um codigo atual. So depois a API ativa MFA e emite um token de acesso.

O convite comprova acesso ao e-mail porque o token e entregue nessa caixa. Se nao chegar, o trabalhador da outbox tenta novamente; nao crie uma conta duplicada. Para revogar convites, desative a conta ou cancele o convite por procedimento administrativo controlado. Nunca solicite que a pessoa envie sua senha ou codigo TOTP.

## API

- `POST /auth/admin-convites/aceitar` recebe `{ token, senha, aceitouTermos, versaoTermos }`.
- `POST /auth/admin-mfa/setup` recebe `{ setupToken }` e devolve segredo TOTP apenas para cadastro inicial.
- `POST /auth/admin-mfa/confirmar` recebe `{ setupToken, codigo }`; devolve sessao apenas depois de validar TOTP.
- `POST /auth/login` e `POST /auth/google` devolvem desafio MFA para administradores ativos com MFA. Para administradores verificados sem MFA, devolvem somente `mfaSetupRequired` e `mfaSetupToken`.
- `POST /auth/login/mfa` troca `mfaToken` e codigo TOTP por sessao.
- `GET /auth/mfa/admin` consulta o estado da conta. A rota antiga de desativacao sempre recusa a operacao.

Contas administrativas antigas sem MFA ficam restritas: podem verificar e-mail e sair, mas nao acessam painel, perfil, sessoes ou dados administrativos. Apos confirmar e-mail, devem entrar novamente e concluir MFA. Nao se deve ativar `mfa_ativo` manualmente para contornar o fluxo.

## Preparacao e migration

Antes do deploy, confira backup recuperavel e configure `AUTH_TOKEN_SECRET`, `MFA_SECRET_ENCRYPTION_KEY`, `EMAIL_OUTBOX_ENCRYPTION_KEY` e SMTP (`SMTP_HOST`, `SMTP_FROM`, `SMTP_USER`, `SMTP_PASSWORD`). Em producao, a API nao ativa os modulos autenticados se as tres chaves nao tiverem 32 ou mais caracteres e forem distintas. Use valores aleatorios e fora do repositorio. A migration `1760132000000-AdminMfaInvites` depende da tabela `email_outbox`, criada por `1760131000000-EmailOutbox`; mantenha `RUN_MIGRATIONS_ON_BUILD=true` apenas durante o deploy controlado e confirme no historico que ambas foram aplicadas. Depois volte a variavel para `false`.

A migration adiciona `admin_convites`, permite o novo tipo de mensagem na outbox e adiciona os campos persistentes de bloqueio MFA em `usuarios`. Nao aplique manualmente o SQL se o TypeORM ja registrou a migration. Em caso de erro, pare o deploy e confira estado e backup antes de tentar novamente; nao apague tabelas de producao.

## Testes

- Convide um e-mail de teste, confirme que a resposta nao contem token, e confira entrega no e-mail.
- Tente usar codigo alterado, expirado e ja aceito; todos devem falhar sem ativar a conta.
- Aceite convite valido com senha forte e termos atuais. Confirme que convite repetido falha.
- Confirme que o desafio de configuracao nao funciona como bearer em endpoints protegidos.
- Insira cinco codigos TOTP incorretos; a API deve responder `429` e negar tentativa correta durante 15 minutos. Depois do prazo, o codigo correto deve funcionar e zerar o bloqueio.
- Confirme que conta sem MFA recebe `403 MFA_ADMIN_OBRIGATORIO` em toda rota autenticada fora de verificacao de e-mail e logout.
- Confirme que conta com MFA entra com senha + TOTP e que nao existe endpoint para desligar a obrigatoriedade.

Nunca inclua convite, senha, token, segredo TOTP ou codigo de autenticacao em logs, commits, capturas ou tickets.
