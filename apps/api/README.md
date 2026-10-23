# ConectaLar API foundation

This is the active NestJS API used by the Flutter app. It includes MySQL-backed modules for authentication, clients, professionals, categories, requests, chat, reviews, documents, notifications and administration. The PHP/XAMPP descriptions in the root README and the SQL schema are historical and are not used by this API.

## Runtime configuration

Use Node.js 22.13 or newer in the 22.x line, or 24.15 or newer. Install dependencies from this directory, then run `npm run typecheck`, `npm run build`, `npm test`, and `npm start`. The API reads environment variables from the process and does not load a `.env` file. Supply deployment values through the local shell or a secret manager.

| Variable | Default | Validation |
| --- | --- | --- |
| `NODE_ENV` | `development` | `development`, `test`, or `production` |
| `HOST` | `127.0.0.1` | IP address or DNS hostname |
| `PORT` | `3000` for direct start; the Windows local launcher sets `3012` | Integer from 1 through 65535 |
| `DB_HOST` | none | Required to enable MySQL-backed routes |
| `DB_PORT` | `3306` | Integer from 1 through 65535 |
| `DB_USER` | none | Required to enable MySQL-backed routes |
| `DB_PASSWORD` | empty string | Allowed empty only for local development |
| `DB_NAME` | none | Required to enable MySQL-backed routes |
| `AUTH_TOKEN_SECRET` | none | Required to enable auth routes; minimum 32 characters |
| `MFA_SECRET_ENCRYPTION_KEY` | falls back to `AUTH_TOKEN_SECRET` outside production | Use a distinct 32+ character secret in production to encrypt administrator MFA secrets |
| `GOOGLE_WEB_CLIENT_ID` | none | OAuth Web client ID accepted as the audience for Google ID tokens |
| `GOOGLE_OAUTH_CLIENT_IDS` | falls back to `GOOGLE_WEB_CLIENT_ID` | Optional comma-separated audience allow-list for multiple trusted OAuth clients |
| `CORS_ALLOWED_ORIGINS` | none | Comma-separated exact Web origins allowed in production; non-browser Android requests have no Origin header |
| `GOOGLE_MAPS_SERVER_API_KEY` | none | Optional restricted server key for geocoding; CEP lookup and regional fallback continue without it |
| `ID_ZAPSIGN_ENABLED` | `false` | Must be explicitly `true` to start hosted identity checks; does not enable professional attendance |
| `ID_ZAPSIGN_API_KEY` | none | Server-only ID ZapSign credential; set after the privacy notice and migration are reviewed |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_FROM` | none / `587` / none | Required in production for password recovery and account verification e-mail delivery |
| `SMTP_SECURE` / `SMTP_STARTTLS` | `false` / `true` | SMTP transport security flags |
| `SMTP_USER` / `SMTP_PASSWORD` | none | Optional SMTP credentials |
| `MALWARE_SCAN_MODE` | `required` in production, `disabled` otherwise | `disabled`, `log-only`, or `required`; use `required` with ClamAV before production uploads |
| `CLAMAV_HOST` / `CLAMAV_PORT` | `127.0.0.1` / `3310` | ClamAV TCP service used by document upload scanning |
| `CLAMAV_TIMEOUT_MS` | `10000` | Positive integer timeout for ClamAV scan requests |
| `FILE_STORAGE_DRIVER` | `r2` in production, `local` otherwise | `local` or `r2`; document uploads use R2 when set to `r2` |
| `R2_ACCOUNT_ID` / `R2_BUCKET` | none | Required when `FILE_STORAGE_DRIVER=r2` |
| `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` | none | Cloudflare R2 token credentials with bucket access |
| `R2_REGION` / `R2_ENDPOINT` | `auto` / derived from account id | Optional S3-compatible R2 settings |
| `RATE_LIMIT_WINDOW_MS` | `60000` | Positive integer window, in milliseconds |
| `RATE_LIMIT_MAX` | `120` | Positive integer max requests per client/window |

`GET /health` and `GET /health/live` return only `{ "status": "ok" }` when the HTTP process responds. `GET /health/ready` returns 200 with `{ "status": "ready" }` only when database/authentication configuration is complete, TypeORM is initialized, and MySQL answers `SELECT 1`. It returns 503 with `{ "status": "not_ready" }` on failure or a two-second probe timeout. Outstanding database probes are shared to avoid filling the connection pool. Responses contain no connection details or credentials. Production startup rejects incomplete database/authentication configuration. Readiness does not validate migrations, SMTP, object storage, Google, or malware scanning; validate those separately before homologation/deployment.

`GET /localizacao/cep/{cep}` validates an eight-digit Brazilian CEP and fills address components through ViaCEP. When `GOOGLE_MAPS_SERVER_API_KEY` is configured, the API also geocodes the result. Restrict that key in Google Cloud to the VPS public IP and only the Geocoding API. Exact client coordinates and the professional's raw coordinates are not returned publicly; professional map coordinates are rounded and intended only for approximate regional display.

`POST /profissionais/busca` accepts transient coordinates in the JSON body,
orders results by distance, and filters by both the requested radius and each
professional's service radius. Use this route for device GPS so coordinates do
not appear in request URLs. The API does not persist the supplied position.

The OpenAPI contract in `openapi.yaml` covers the routes currently implemented by the API, including client profiles and addresses, professional availability and agenda, service requests, chat, reviews, reports, notifications, document moderation, administrative users, history, terms, and audit. It describes the current HTTP contract; it does not claim that every route has passed an integration or production test. MySQL-backed routes are mounted only when MySQL and `AUTH_TOKEN_SECRET` are configured before process startup.

For local troubleshooting, use `npm run diagnostico:local` after starting the API. The command checks `/health`, MySQL, pending migrations, demo logins, and the main demo endpoints. Use `npm run diagnostico:fluxo` for a deeper local end-to-end validation that creates temporary test data and exercises request creation, acceptance, chat, completion, reviews, reports, moderation, and audit. The full local workflow is documented in [`docs/ambiente-local.md`](../../docs/ambiente-local.md). The Flutter app defaults to port `3012`; direct API execution defaults to `3000`, so set `PORT` or the Flutter base URL when not using the Windows launcher.

## Logging and errors

Request bodies and headers are not logged. The global exception filter returns a generic response and emits only a structured event, HTTP status, and broad exception type; it omits exception messages, stacks, URLs, and request data. Add request logging only with an explicit redaction and retention policy.

The API uses allow-list CORS, basic security headers, a local in-memory request rate limiter, generic error responses, and structured startup/error logs that do not include request bodies or authorization headers. Verification uploads validate file type and can scan bytes through ClamAV before writing to private storage. Document storage supports local disk for development and Cloudflare R2 through its S3-compatible API for production. Documents are still served back only through the authenticated administrative API route, not by public object URLs. It currently has no payment or push notification module. The app module imports TypeORM and the business modules only when runtime configuration is complete, so the health endpoint remains independent of MySQL.

## Database foundation

The approved persistence stack is `@nestjs/typeorm` 12.0.2, TypeORM 1.1.2, and `mysql2` 3.24.5. `src/database/data-source.ts` is the explicit TypeORM CLI data source. It requires `DB_HOST`, `DB_USER`, and `DB_NAME`; `DB_PORT` defaults to 3306 and `DB_PASSWORD` defaults to an empty string for local development. It reads process environment variables only and does not load `.env` files.

Schema synchronization and automatic migrations are disabled (`synchronize: false`, `migrationsRun: false`). The migrations create the `usuarios`, `usuario_senha_resets`, `admin_auditoria`, `termo_aceites`, `profissionais`, `profissional_servicos`, `profissional_disponibilidades`, `profissional_documentos_verificacao`, `denuncias`, `categorias`, `solicitacoes`, `solicitacao_eventos`, `solicitacao_reagendamentos`, `solicitacao_orcamentos`, `mensagens_atendimento`, `avaliacoes`, `notificacoes`, `cliente_perfis`, `cliente_enderecos`, and `favoritos_profissionais` tables needed for the current RF001/RF028 groundwork. Do not point a migration command at the legacy database.

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
- `POST /auth/google`
- `POST /auth/login/mfa`
- `POST /auth/senha/recuperacao`
- `POST /auth/senha/recuperacao/confirmar`
- `GET /auth/email/verificacao` with `Authorization: Bearer <token>`
- `POST /auth/email/verificacao/enviar` with `Authorization: Bearer <token>`
- `POST /auth/email/verificacao/confirmar` with `Authorization: Bearer <token>`
- `PATCH /auth/senha` with `Authorization: Bearer <token>`
- `GET /auth/mfa/admin` with `Authorization: Bearer <token>` for `administrador`
- `POST /auth/mfa/admin/setup` with `Authorization: Bearer <token>` for `administrador`
- `POST /auth/mfa/admin/confirmar` with `Authorization: Bearer <token>` for `administrador`
- `POST /auth/mfa/admin/desativar` with `Authorization: Bearer <token>` for `administrador`
- `POST /auth/logout` with `Authorization: Bearer <token>`

Passwords are stored as `scrypt` hashes. Responses never include `senha_hash`. Password reset sends a 6-digit recovery code by e-mail, stores only a SHA-256 hash scoped to the user, expires codes after 30 minutes, invalidates prior unused reset codes, and marks codes as used after password change. Recovery requests return a generic success response so the API does not reveal whether an e-mail exists. In production, password recovery fails closed if no SMTP delivery is available. Access tokens include a token version and are invalidated when the password changes. Local development can expose `devToken` only when `EXPOSE_PASSWORD_RESET_TOKEN=true`; do not enable that flag in production.

Google authentication accepts only a Google ID token and verifies its signature, issuer, expiry and configured audience with `google-auth-library`. The API stores the stable Google subject, never trusts an e-mail or role sent by the app, requires the current terms on first registration, and keeps administrator MFA in the login path. Automatic linking by e-mail is limited to active non-administrator accounts where Google is authoritative for the address (Gmail or Google Workspace). See [`docs/login-google.md`](../../docs/login-google.md) for the required Google Cloud and build setup.

New public registrations start with `emailVerificado=false`. The API stores only a hash of the six-digit e-mail verification code, expires it after 15 minutes, invalidates previous unused codes when a new one is requested, and marks all open codes as used when the e-mail is confirmed. Existing users are marked as verified by the migration so current demo and test accounts keep working. In production, configure SMTP before enabling public registration. Local development can expose the verification `devCode` only when `EXPOSE_EMAIL_VERIFICATION_CODE=true`; do not enable that flag in production.

Administrator MFA uses TOTP. Setup returns the standard `otpauth://` URL for an authenticator app, stores the secret encrypted in `usuarios.mfa_secret_encrypted`, and requires a six-digit code before issuing an admin access token after password login. Enabling or disabling MFA invalidates previous admin sessions through `token_version`.

Administrative user routes:

- `GET /admin/usuarios` with `Authorization: Bearer <token>` for `administrador`
- `GET /admin/usuarios?tipo=cliente&ativo=true&termo=maria` with `Authorization: Bearer <token>` for `administrador`
- `GET /admin/usuarios/:id` with `Authorization: Bearer <token>` for `administrador`
- `POST /admin/usuarios/administradores` with `Authorization: Bearer <token>` for `administrador`
- `PATCH /admin/usuarios/:id/status` with `Authorization: Bearer <token>` for `administrador`

Administrative user responses never include password hashes. Public registration still cannot create administrator accounts; administrator creation is restricted to authenticated administrators and stores the password with the same `scrypt` hashing. Status changes are soft activation/deactivation only, are audited in `admin_auditoria`, cannot deactivate the current administrator's own account, and cannot deactivate the last active administrator. Invite flow, detailed permissions, and account recovery remain pending under P02/P15.

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
Administrators can choose only one of the controlled icon identifiers accepted by the API; arbitrary file upload is intentionally not supported for category icons.

Service request routes:

- `POST /solicitacoes` with `Authorization: Bearer <token>` for `cliente`
- `GET /solicitacoes/me?pagina=1&limite=20` with `Authorization: Bearer <token>` for participants or `administrador`
- `GET /solicitacoes/:id` with `Authorization: Bearer <token>` for participants or `administrador`
- `PATCH /solicitacoes/:id/aceitar` with `Authorization: Bearer <token>` for the requested `profissional` or `empresa`
- `PATCH /solicitacoes/:id/recusar` with `Authorization: Bearer <token>` for the requested `profissional` or `empresa`
- `PATCH /solicitacoes/:id/cancelar` with `Authorization: Bearer <token>` for the requesting `cliente`
- `PATCH /solicitacoes/:id/concluir` with `Authorization: Bearer <token>` for the requesting `cliente`
- `POST /solicitacoes/:id/orcamentos` with `Authorization: Bearer <token>` for the requested `profissional` or `empresa`
- `PATCH /solicitacoes/:id/orcamentos/responder` with `Authorization: Bearer <token>` for the requesting `cliente`

New requests always start as `aguardando_resposta`; they become `aceita_agendada` only after the requested provider accepts them. `POST /solicitacoes` accepts optional `enderecoId`, which must belong to the authenticated client and be active. Request responses always expose the attendance neighborhood. Full address data is returned only to the owning client, an administrator, or the requested professional/company after the request is `aceita_agendada` or `conclusao_confirmada`; otherwise the API returns `enderecoProtegido: true`.

Final-price proposals are versioned. Only the professional can propose a value and only the client can accept or refuse it. A pending proposal may be replaced without deleting history, and `precoFinal` changes only after explicit client acceptance. Payments remain outside ConectaLar.

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

- `GET /solicitacoes/:solicitacaoId/mensagens?pagina=1&limite=20` with `Authorization: Bearer <token>` for participants or `administrador`
- `POST /solicitacoes/:solicitacaoId/mensagens` with `Authorization: Bearer <token>` for the requesting `cliente` or requested `profissional`/`empresa`

Messages are linked to a service request. New messages are allowed only while the request is `aguardando_resposta` or `aceita_agendada`; final states keep the history available to authorized participants without reopening the service.

Report routes:

- `POST /solicitacoes/:solicitacaoId/denuncias` with `Authorization: Bearer <token>` for the requesting `cliente` or requested `profissional`/`empresa`
- `GET /denuncias/me?pagina=1&limite=20` with `Authorization: Bearer <token>`
- `GET /denuncias/moderacao` with `Authorization: Bearer <token>` for `administrador`
- `GET /denuncias/moderacao?status=pendente` with `Authorization: Bearer <token>` for `administrador`
- `PATCH /denuncias/:id/moderacao` with `Authorization: Bearer <token>` for `administrador`

Reports are tied to an existing service request and can target only the opposite participant. Creating a report does not change the service request status, block an account, hide a review, or apply any punishment automatically. `GET /denuncias/me` returns only reports submitted by the authenticated user, including the related attendance summary and administrative response. Administrative review records `em_analise`, `resolvida`, or `rejeitada`; final statuses require a decision note and notify the reporter. Detailed targets, categories, penalties, contestation, and retention policies remain pending under P11/P13.

Review routes:

- `GET /solicitacoes/:solicitacaoId/avaliacoes` with `Authorization: Bearer <token>` for participants or `administrador`
- `POST /solicitacoes/:solicitacaoId/avaliacoes/profissional` with `Authorization: Bearer <token>` for the requesting `cliente`
- `POST /solicitacoes/:solicitacaoId/avaliacoes/cliente` with `Authorization: Bearer <token>` for the requested `profissional` or `empresa`
- `GET /avaliacoes/moderacao` with `Authorization: Bearer <token>` for `administrador`
- `PATCH /avaliacoes/:id/moderacao` with `Authorization: Bearer <token>` for `administrador`

Reviews can be created only after `conclusao_confirmada`. Each participant can review the opposite participant once per service request. New reviews start with moderation status `pendente`.

Notification routes:

- `GET /notificacoes/me?pagina=1&limite=20` with `Authorization: Bearer <token>`
- `GET /notificacoes/me?naoLidas=true&pagina=1&limite=20` with `Authorization: Bearer <token>`
- `GET /notificacoes/me/resumo` with `Authorization: Bearer <token>`
- `PATCH /notificacoes/:id/lida` with `Authorization: Bearer <token>`
- `PATCH /notificacoes/me/lidas` with `Authorization: Bearer <token>`

Internal notifications are created for real backend events such as new requests, request acceptance/refusal/cancellation/conclusion, received messages, and received reviews. Notification registration is auxiliary and must not alter the service state if it fails.

The personal request, message, report, and notification lists accept `pagina` and `limite`. Limits from 1 to 50 are accepted. Responses include `paginacao` with the current page, limit, total records, total pages, and whether another page exists.

Document verification routes:

- `GET /documentos-verificacao` with `Authorization: Bearer <token>` for `administrador`
- `GET /documentos-verificacao?status=pendente` with `Authorization: Bearer <token>` for `administrador`
- `PATCH /documentos-verificacao/:id/analisar` with `Authorization: Bearer <token>` for `administrador`

Document analysis accepts only `aprovado` or `rejeitado`; rejected documents require `motivoRejeicao`. Approval activates the professional verification seal, rejection removes it, and the professional receives an internal notification. Binary uploads are stored privately in local storage for development; production still needs a managed storage provider, antivirus scanning, retention policy, and secure file retrieval flow under P10/P13.

Terms and privacy notice routes:

- `GET /termos/atuais`
- `GET /termos/aceites/me` with `Authorization: Bearer <token>`
- `POST /termos/aceites/me` with `Authorization: Bearer <token>`
- `POST /privacidade/me/exportacao` with current password and `Authorization: Bearer <token>`
- `POST /privacidade/me/exclusao` with current password, `confirmacao: "EXCLUIR"`, and `Authorization: Bearer <token>`

The current terms are written in plain language and include privacy/LGPD explanations, protected address handling, external payment, verification seal limits, user responsibilities, and version changes. Acceptance stores only the authenticated user, accepted version, channel, and timestamp; it does not store raw IP address or user-agent data. Data export requires reauthentication and omits authentication secrets. Account deletion anonymizes records that must preserve referential integrity, removes private files, and invalidates all sessions. Final legal review and category-specific retention periods remain pending under P13/P18.

Apply migration `PrivacidadeLgpd1760121000000` before using these routes. Administrators cannot self-delete through the public flow, and accounts with open service requests must cancel or finish them first.

## Atualização dos fluxos em 11/10/2026

Aplicar `npm run db:migration:run` antes de iniciar esta versão: a migration `OfertaDaSolicitacao1760114000000` adiciona o vínculo e o nome da oferta escolhida ao pedido. `servicoId` é opcional para compatibilidade; quando enviado, a API deriva categoria e preço da oferta ativa. As ofertas são editadas preservando IDs e os itens omitidos são desativados.

Novas consultas de avaliações aprovadas:

- `GET /profissionais/:id/avaliacoes` (público, perfil ativo).
- `GET /profissionais/me/avaliacoes` (profissional/empresa autenticado).

Ambas retornam `resumo` com `notaMedia`/`quantidadeAvaliacoes` e as 50 avaliações aprovadas mais recentes, sem identificadores de clientes/pedidos. Listas/detalhes de solicitação incluem `avaliado` do ator atual, mesmo para avaliação pendente.

Aceites usam transação e bloqueio do perfil/pedido para impedir sobreposição de atendimentos, inclusive com inícios diferentes e aceites simultâneos. Conflitos retornam 409. Cada oferta exige `duracaoMinutos` (inteiro entre 1 e 1440); a solicitação preserva a duração vigente na criação. A migration `DuracaoAtendimentos1760123000000` atribui 120 minutos aos registros antigos. A duração inteira precisa caber em um período semanal do mesmo dia. Fuso: `America/Sao_Paulo`; sem intervalo adicional e capacidade de um atendimento por vez, inclusive empresas. `GET /profissionais/{id}/horarios?data=YYYY-MM-DD&servicoId=ID` retorna somente períodos livres que comportam o serviço, sem dados de clientes ou pedidos. Equipes/múltiplos executores e serviços que atravessem a madrugada permanecem fora do fluxo atual. Datas `DATE` não são convertidas por fuso. A agenda retorna `enderecoAtendimento` e mantém o alias `enderecoCompleto`.

Procedimento de teste com banco descartável, modo demo explícito no Flutter e limites: [registro dos ajustes](../../docs/ajustes-fluxos-2026-10-11.md).
