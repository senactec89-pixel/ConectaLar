# ConectaLar API foundation

This is the new NestJS API workspace. The existing PHP backend remains legacy code and is not called by this foundation. The first MySQL-backed module is authentication, enabled only when the required database and token environment variables are present.

## Runtime configuration

Use Node.js 22.13 or newer in the 22.x line, or 24.15 or newer. Install dependencies from this directory, then run `npm run typecheck`, `npm run build`, `npm test`, and `npm start`. The API reads environment variables from the process and does not load a `.env` file. Supply deployment values through the local shell or a secret manager.

| Variable | Default | Validation |
| --- | --- | --- |
| `NODE_ENV` | `development` | `development`, `test`, or `production` |
| `HOST` | `127.0.0.1` | IP address or DNS hostname |
| `PORT` | `3000` | Integer from 1 through 65535 |
| `DB_HOST` | none | Required to enable MySQL-backed routes |
| `DB_PORT` | `3306` | Integer from 1 through 65535 |
| `DB_USER` | none | Required to enable MySQL-backed routes |
| `DB_PASSWORD` | empty string | Allowed empty only for local development |
| `DB_NAME` | none | Required to enable MySQL-backed routes |
| `AUTH_TOKEN_SECRET` | none | Required to enable auth routes; minimum 32 characters |
| `RATE_LIMIT_WINDOW_MS` | `60000` | Positive integer window, in milliseconds |
| `RATE_LIMIT_MAX` | `120` | Positive integer max requests per client/window |

The health check is `GET /health` and returns only `{ "status": "ok" }`. It does not report dependency, database, version, or environment details.

The OpenAPI contract in `openapi.yaml` covers the routes currently implemented by the API, including client profiles and addresses, professional availability and agenda, service requests, chat, reviews, reports, notifications, document moderation, administrative users, history, terms, and audit. It describes the current HTTP contract; it does not claim that every route has passed an integration or production test. MySQL-backed routes are mounted only when MySQL and `AUTH_TOKEN_SECRET` are configured before process startup.

## Logging and errors

Request bodies and headers are not logged. The global exception filter returns a generic response and emits only a structured event, HTTP status, and broad exception type; it omits exception messages, stacks, URLs, and request data. Add request logging only with an explicit redaction and retention policy.

The API uses allow-list CORS, basic security headers, a local in-memory request rate limiter, generic error responses, and structured startup/error logs that do not include request bodies or authorization headers. It currently has local private document storage for verification uploads, but no public file serving, external storage provider, payment, or push notification module. The app module imports TypeORM and the business modules only when runtime configuration is complete, so the health endpoint remains independent of MySQL.

## Database foundation

The approved persistence stack is `@nestjs/typeorm` 12.0.2, TypeORM 1.1.2, and `mysql2` 3.24.5. `src/database/data-source.ts` is the explicit TypeORM CLI data source. It requires `DB_HOST`, `DB_USER`, and `DB_NAME`; `DB_PORT` defaults to 3306 and `DB_PASSWORD` defaults to an empty string for local development. It reads process environment variables only and does not load `.env` files.

Schema synchronization and automatic migrations are disabled (`synchronize: false`, `migrationsRun: false`). The migrations create the `usuarios`, `usuario_senha_resets`, `admin_auditoria`, `termo_aceites`, `profissionais`, `profissional_servicos`, `profissional_disponibilidades`, `profissional_documentos_verificacao`, `denuncias`, `categorias`, `solicitacoes`, `mensagens_atendimento`, `avaliacoes`, `notificacoes`, `cliente_perfis`, `cliente_enderecos`, and `favoritos_profissionais` tables needed for the current RF001/RF028 groundwork. Do not point a migration command at the legacy database.

The `.env.example` values are placeholders, not usable credentials. Supply local test database values only in the current PowerShell session or an ignored local file after a local MySQL database has been set up.

For the local portable MySQL setup used during development:

```powershell
$env:DB_HOST='127.0.0.1'
$env:DB_PORT='3307'
$env:DB_USER='root'
Remove-Item Env:DB_PASSWORD -ErrorAction SilentlyContinue
$env:DB_NAME='conectalar_dev'
$env:AUTH_TOKEN_SECRET='local-dev-secret-change-before-production-123456'
npm run db:migration:run
npm start
```

Authentication routes:

- `POST /auth/cadastro`
- `POST /auth/login`
- `POST /auth/senha/recuperacao`
- `POST /auth/senha/recuperacao/confirmar`
- `PATCH /auth/senha` with `Authorization: Bearer <token>`
- `POST /auth/logout` with `Authorization: Bearer <token>`

Passwords are stored as `scrypt` hashes. Responses never include `senha_hash`. Password reset stores only a SHA-256 hash of the recovery token, expires tokens after 30 minutes, invalidates prior unused reset tokens, and marks tokens as used after password change. Recovery requests return a generic success response so the API does not reveal whether an e-mail exists. E-mail delivery is not configured yet, so production password recovery still needs a delivery provider. Access tokens include a token version and are invalidated when the password changes. Local development can expose `devToken` only when `EXPOSE_PASSWORD_RESET_TOKEN=true`; do not enable that flag in production.

Administrative user routes:

- `GET /admin/usuarios` with `Authorization: Bearer <token>` for `administrador`
- `GET /admin/usuarios?tipo=cliente&ativo=true&termo=maria` with `Authorization: Bearer <token>` for `administrador`
- `GET /admin/usuarios/:id` with `Authorization: Bearer <token>` for `administrador`
- `POST /admin/usuarios/administradores` with `Authorization: Bearer <token>` for `administrador`
- `PATCH /admin/usuarios/:id/status` with `Authorization: Bearer <token>` for `administrador`

Administrative user responses never include password hashes. Public registration still cannot create administrator accounts; administrator creation is restricted to authenticated administrators and stores the password with the same `scrypt` hashing. Status changes are soft activation/deactivation only, are audited in `admin_auditoria`, cannot deactivate the current administrator's own account, and cannot deactivate the last active administrator. Invite flow, MFA, detailed permissions, and account recovery remain pending under P02/P15.

Client routes:

- `GET /clientes/me` with `Authorization: Bearer <token>` for `cliente`
- `PUT /clientes/me` with `Authorization: Bearer <token>` for `cliente`
- `GET /clientes/me/enderecos` with `Authorization: Bearer <token>` for `cliente`
- `POST /clientes/me/enderecos` with `Authorization: Bearer <token>` for `cliente`
- `PATCH /clientes/me/enderecos/:id` with `Authorization: Bearer <token>` for `cliente`
- `DELETE /clientes/me/enderecos/:id` with `Authorization: Bearer <token>` for `cliente`
- `GET /clientes/me/favoritos` with `Authorization: Bearer <token>` for `cliente`
- `POST /clientes/me/favoritos/:profissionalId` with `Authorization: Bearer <token>` for `cliente`
- `DELETE /clientes/me/favoritos/:profissionalId` with `Authorization: Bearer <token>` for `cliente`

Client profiles and addresses are private to the authenticated client. Favorite responses include only the same public professional data exposed by the professional search.

Professional routes:

- `GET /profissionais`
- `GET /profissionais?termo=eletricista&bairro=jardim&categoriaId=1`
- `GET /profissionais/:id`
- `GET /profissionais/:id/disponibilidade`
- `GET /profissionais/me` with `Authorization: Bearer <token>` for `profissional` or `empresa`
- `GET /profissionais/me/agenda?mes=YYYY-MM` with `Authorization: Bearer <token>` for `profissional` or `empresa`
- `PUT /profissionais/me` with `Authorization: Bearer <token>` for `profissional` or `empresa`
- `GET /profissionais/me/disponibilidade` with `Authorization: Bearer <token>` for `profissional` or `empresa`
- `PUT /profissionais/me/disponibilidade` with `Authorization: Bearer <token>` for `profissional` or `empresa`
- `POST /profissionais/me/documentos` with `Authorization: Bearer <token>` for `profissional` or `empresa`
- `GET /profissionais/me/documentos` with `Authorization: Bearer <token>` for `profissional` or `empresa`
- `PATCH /profissionais/:id/verificacao` with `Authorization: Bearer <token>` for `administrador`, kept only as a compatibility route that rejects direct seal changes

Professional public responses do not expose e-mail, phone, address, documents, or password hashes. The `verificado` seal can only be changed through administrative document analysis; professionals cannot approve their own seal. Document registration stores an internal file reference only and must not expose public URLs or files in public profiles.

`POST /profissionais/me/documentos` accepts either an existing internal `referenciaArquivo` or `arquivoBase64` with `mimeType` (`application/pdf`, `image/jpeg`, or `image/png`) and `nomeArquivo`. Uploaded files are limited to 5 MB, saved under private local storage, and responses expose only the internal reference for authorized professional/admin flows.

Availability uses weekly recurring slots with `diaSemana` from `0` Sunday through `6` Saturday and `horaInicio`/`horaFim` in `HH:MM`. Service requests can be created and accepted only when the requested date/time falls inside an active slot. This is a minimal rule until final duration, capacity, exception, and concurrency policies are approved.

The professional agenda returns active weekly availability and accepted appointments for the requested month only. It can include the full service address because every listed appointment is already `aceita_agendada`; pending requests continue to expose only neighborhood-level location.

Category routes:

- `GET /categorias`
- `GET /categorias/admin` with `Authorization: Bearer <token>` for `administrador`
- `POST /categorias` with `Authorization: Bearer <token>` for `administrador`
- `PATCH /categorias/:id` with `Authorization: Bearer <token>` for `administrador`

Inactive categories do not appear in public lists and cannot be used for new professional offers or new requests, but the category row remains available for historical references.

Service request routes:

- `POST /solicitacoes` with `Authorization: Bearer <token>` for `cliente`
- `GET /solicitacoes/me` with `Authorization: Bearer <token>` for participants or `administrador`
- `GET /solicitacoes/:id` with `Authorization: Bearer <token>` for participants or `administrador`
- `PATCH /solicitacoes/:id/aceitar` with `Authorization: Bearer <token>` for the requested `profissional` or `empresa`
- `PATCH /solicitacoes/:id/recusar` with `Authorization: Bearer <token>` for the requested `profissional` or `empresa`
- `PATCH /solicitacoes/:id/cancelar` with `Authorization: Bearer <token>` for the requesting `cliente`
- `PATCH /solicitacoes/:id/concluir` with `Authorization: Bearer <token>` for the requesting `cliente`

New requests always start as `aguardando_resposta`; they become `aceita_agendada` only after the requested provider accepts them. `POST /solicitacoes` accepts optional `enderecoId`, which must belong to the authenticated client and be active. Request responses always expose the attendance neighborhood. Full address data is returned only to the owning client, an administrator, or the requested professional/company after the request is `aceita_agendada` or `conclusao_confirmada`; otherwise the API returns `enderecoProtegido: true`.

Administrative dashboard and audit routes:

- `GET /admin/painel` with `Authorization: Bearer <token>` for `administrador`
- `GET /admin/painel/auditoria` with `Authorization: Bearer <token>` for `administrador`

Administrative actions that create or change administrator accounts, activate/deactivate users, create/update categories, analyze documents, moderate reports, or moderate reviews are recorded in `admin_auditoria`. Audit responses include actor summary, action, target type/id, a short non-sensitive detail, and timestamp.

History routes:

- `GET /historico/atendimentos/me` with `Authorization: Bearer <token>` for `cliente`, `profissional`, or `empresa`
- `GET /historico/atendimentos/me?finalizados=true` with `Authorization: Bearer <token>`
- `GET /historico/atendimentos/me?status=conclusao_confirmada` with `Authorization: Bearer <token>`
- `GET /admin/historico/atendimentos` with `Authorization: Bearer <token>` for `administrador`
- `GET /admin/historico/atendimentos?usuarioId=1&finalizados=true` with `Authorization: Bearer <token>` for `administrador`

History responses reuse service request data that is already authorized for the participant or administrator. They do not expose full client addresses and do not create new service states beyond the formal request statuses.

Chat routes:

- `GET /solicitacoes/:solicitacaoId/mensagens` with `Authorization: Bearer <token>` for participants or `administrador`
- `POST /solicitacoes/:solicitacaoId/mensagens` with `Authorization: Bearer <token>` for the requesting `cliente` or requested `profissional`/`empresa`

Messages are linked to a service request. New messages are allowed only while the request is `aguardando_resposta` or `aceita_agendada`; final states keep the history available to authorized participants without reopening the service.

Report routes:

- `POST /solicitacoes/:solicitacaoId/denuncias` with `Authorization: Bearer <token>` for the requesting `cliente` or requested `profissional`/`empresa`
- `GET /denuncias/me` with `Authorization: Bearer <token>`
- `GET /denuncias/moderacao` with `Authorization: Bearer <token>` for `administrador`
- `GET /denuncias/moderacao?status=pendente` with `Authorization: Bearer <token>` for `administrador`
- `PATCH /denuncias/:id/moderacao` with `Authorization: Bearer <token>` for `administrador`

Reports are tied to an existing service request and can target only the opposite participant. Creating a report does not change the service request status, block an account, hide a review, or apply any punishment automatically. Administrative review records `em_analise`, `resolvida`, or `rejeitada`; final statuses require a decision note. Detailed targets, categories, penalties, contestation, and retention policies remain pending under P11/P13.

Review routes:

- `GET /solicitacoes/:solicitacaoId/avaliacoes` with `Authorization: Bearer <token>` for participants or `administrador`
- `POST /solicitacoes/:solicitacaoId/avaliacoes/profissional` with `Authorization: Bearer <token>` for the requesting `cliente`
- `POST /solicitacoes/:solicitacaoId/avaliacoes/cliente` with `Authorization: Bearer <token>` for the requested `profissional` or `empresa`
- `GET /avaliacoes/moderacao` with `Authorization: Bearer <token>` for `administrador`
- `PATCH /avaliacoes/:id/moderacao` with `Authorization: Bearer <token>` for `administrador`

Reviews can be created only after `conclusao_confirmada`. Each participant can review the opposite participant once per service request. New reviews start with moderation status `pendente`.

Notification routes:

- `GET /notificacoes/me` with `Authorization: Bearer <token>`
- `GET /notificacoes/me?naoLidas=true` with `Authorization: Bearer <token>`
- `GET /notificacoes/me/resumo` with `Authorization: Bearer <token>`
- `PATCH /notificacoes/:id/lida` with `Authorization: Bearer <token>`
- `PATCH /notificacoes/me/lidas` with `Authorization: Bearer <token>`

Internal notifications are created for real backend events such as new requests, request acceptance/refusal/cancellation/conclusion, received messages, and received reviews. Notification registration is auxiliary and must not alter the service state if it fails.

Document verification routes:

- `GET /documentos-verificacao` with `Authorization: Bearer <token>` for `administrador`
- `GET /documentos-verificacao?status=pendente` with `Authorization: Bearer <token>` for `administrador`
- `PATCH /documentos-verificacao/:id/analisar` with `Authorization: Bearer <token>` for `administrador`

Document analysis accepts only `aprovado` or `rejeitado`; rejected documents require `motivoRejeicao`. Approval activates the professional verification seal, rejection removes it, and the professional receives an internal notification. Binary uploads are stored privately in local storage for development; production still needs a managed storage provider, antivirus scanning, retention policy, and secure file retrieval flow under P10/P13.

Terms and privacy notice routes:

- `GET /termos/atuais`
- `GET /termos/aceites/me` with `Authorization: Bearer <token>`
- `POST /termos/aceites/me` with `Authorization: Bearer <token>`

The current terms are written in plain language and include privacy/LGPD explanations, protected address handling, external payment, verification seal limits, user responsibilities, and version changes. Acceptance stores only the authenticated user, accepted version, channel, and timestamp; it does not store raw IP address or user-agent data. Retention, deletion, legal text approval, and re-consent rules remain pending under P13/P18.

## Atualização dos fluxos em 11/10/2026

Aplicar `npm run db:migration:run` antes de iniciar esta versão: a migration `OfertaDaSolicitacao1760114000000` adiciona o vínculo e o nome da oferta escolhida ao pedido. `servicoId` é opcional para compatibilidade; quando enviado, a API deriva categoria e preço da oferta ativa. As ofertas são editadas preservando IDs e os itens omitidos são desativados.

Novas consultas de avaliações aprovadas:

- `GET /profissionais/:id/avaliacoes` (público, perfil ativo).
- `GET /profissionais/me/avaliacoes` (profissional/empresa autenticado).

Ambas retornam `resumo` com `notaMedia`/`quantidadeAvaliacoes` e as 50 avaliações aprovadas mais recentes, sem identificadores de clientes/pedidos. Listas/detalhes de solicitação incluem `avaliado` do ator atual, mesmo para avaliação pendente.

Aceites usam transação e bloqueio do perfil/pedido para impedir dois atendimentos aceitos na mesma data e horário inicial. Conflitos retornam 409. Duração/capacidade empresarial continuam pendentes. Datas `DATE` não são convertidas por fuso. A agenda retorna `enderecoAtendimento` e mantém o alias `enderecoCompleto`.

Procedimento de teste com banco descartável, modo demo explícito no Flutter e limites: [registro dos ajustes](../../docs/ajustes-fluxos-2026-10-11.md).
