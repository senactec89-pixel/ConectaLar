# Guia do codigo e diagnostico do ConectaLar

Este documento explica como o projeto esta organizado, o que roda na API, como o app Flutter conversa com o backend e como diagnosticar erros comuns. A ideia e que uma pessoa nova consiga abrir o projeto, entender o caminho dos dados e saber onde procurar quando algo falhar.

## 1. Visao geral

O ConectaLar tem duas partes principais:

- **Aplicativo Flutter**: fica na raiz do repositorio, dentro de `lib/`, `android/`, `assets/` e `test/`.
- **API NestJS com MySQL**: fica em `apps/api/`.

O app nao acessa o banco diretamente. O fluxo correto e:

```text
Flutter -> ApiService -> API NestJS -> TypeORM -> MySQL
```

Se uma tela mostra erro de conexao, normalmente o problema esta em um destes pontos:

- APK foi gerado com IP antigo.
- Celular nao consegue acessar `http://IP_DO_PC:3012/health`.
- API nao esta ligada.
- MySQL nao esta ligado ou esta sem migrations.
- Token/sessao do usuario expirou.
- Endpoint da API retornou erro.

## 2. Estrutura principal do Flutter

Arquivos mais importantes:

```text
lib/main.dart
lib/app/app.dart
lib/app/routes.dart
lib/utils/constants.dart
lib/services/
lib/screens/
lib/widgets/
test/
```

### `lib/main.dart`

Ponto de entrada do app. Ele inicializa os servicos e abre o `ConectaLarApp`.

Se o app nem abre, olhe primeiro:

- `lib/main.dart`
- `lib/app/app.dart`
- saida do `flutter analyze`
- saida do `flutter test`

### `lib/app/app.dart`

Define o `MaterialApp`, tema, rota inicial e comportamento quando a sessao expira.

Pontos importantes:

- Se o usuario estiver logado e com `emailVerificado=false`, a rota inicial deve ser a tela de confirmar e-mail.
- Se a sessao expirar, o app envia o usuario para login.

Quando der problema de app abrindo na tela errada, olhe aqui.

### `lib/app/routes.dart`

Mapa de todas as rotas/telas do app.

Exemplos:

- `/login`
- `/cadastro`
- `/email/verificacao`
- `/profissionais/inicio`
- `/admin`
- `/servicos`

Tambem define quais rotas precisam de sessao usando `SessionGate`.

Quando uma tela nao abre, rota nao encontrada ou acesso cai em "area restrita", olhe:

- `lib/app/routes.dart`
- `lib/widgets/session_gate.dart`

### `lib/utils/constants.dart`

Define a URL base da API:

```dart
String.fromEnvironment('CONECTALAR_API_BASE_URL')
```

Para APK em celular fisico, sempre gere com:

```powershell
flutter build apk --debug --dart-define=CONECTALAR_API_BASE_URL=http://SEU_IP:3012
```

Se usar outro nome, como `API_BASE_URL`, o app ignora e tenta usar o padrao.

### `lib/services/api_service.dart`

Centraliza as requisicoes HTTP.

Ele:

- monta a URL final;
- adiciona `Authorization: Bearer <token>`;
- envia JSON;
- trata timeout;
- transforma resposta ruim em `ApiException`;
- derruba a sessao em alguns casos de `401`.

Quando qualquer tela mostra erro de API, esse arquivo ajuda a entender a mensagem exibida.

### `lib/services/auth_service.dart`

Controla:

- login;
- cadastro;
- sessao salva no celular;
- logout;
- MFA administrativo;
- recuperacao de senha;
- confirmacao de e-mail.

Se o problema for login, usuario continuar logado, e-mail nao verificado ou troca de senha, olhe aqui.

### `lib/services/service_registry.dart`

Cria uma instancia unica dos servicos usados pelo app:

- `auth`
- `categorias`
- `profissionais`
- `servicos`
- `notificacoes`
- `mensagens`
- `admin`
- outros

Tambem carrega a Home com categorias e profissionais.

Se a Home falhar, o caminho normalmente e:

```text
HomePage -> AppServices.carregarHome() -> CategoriaService/ProfissionalService -> ApiService
```

### `lib/screens/`

Cada subpasta representa uma area do app:

```text
auth/           login, cadastro, termos, recuperacao, verificacao de e-mail
home/           tela inicial
busca/          busca e resultados
servicos/       solicitar atendimento, meus servicos, detalhes, denuncia
chat/           conversas
perfil/         dados do cliente, enderecos, seguranca
profissional/   area profissional, agenda, documentos, disponibilidade
admin/          painel administrativo e moderacoes
```

Quando uma tela especifica quebra, procure primeiro na subpasta correspondente.

## 3. Estrutura principal da API

A API fica em:

```text
apps/api/
```

Arquivos principais:

```text
apps/api/src/main.ts
apps/api/src/app.factory.ts
apps/api/src/app.module.ts
apps/api/src/database/
apps/api/src/auth/
apps/api/src/profissionais/
apps/api/src/solicitacoes/
apps/api/src/mensagens/
apps/api/src/avaliacoes/
apps/api/src/denuncias/
apps/api/src/verificacao/
apps/api/src/admin-painel/
apps/api/src/admin-usuarios/
apps/api/src/notificacoes/
```

### `apps/api/src/main.ts`

Entrada da API. Carrega configuracao, cria o app e escuta `HOST`/`PORT`.

Se aparecer:

```json
{"level":"error","event":"api_startup_failed","code":"STARTUP_FAILURE"}
```

verifique:

- porta `3012` ja ocupada;
- MySQL desligado;
- variaveis de banco erradas;
- build desatualizado;
- erro de modulo no TypeScript.

Comando para ver porta ocupada:

```powershell
netstat -ano | findstr :3012
```

Se ja tiver um `node.exe` na porta, a API provavelmente ja esta ligada.

### `apps/api/src/app.factory.ts`

Configura:

- CORS;
- headers basicos de seguranca;
- limitador simples de requisicoes;
- tamanho maximo do JSON;
- filtro global de erros.

Se um endpoint retorna `403` em navegador/app, pode ser CORS ou permissao. Em desenvolvimento, origens locais sao permitidas.

### `apps/api/src/app.module.ts`

Liga os modulos da API.

Importante: os modulos de negocio so sao montados se o banco e `AUTH_TOKEN_SECRET` estiverem configurados. Se essas variaveis faltarem, somente `/health` pode ficar disponivel.

Se `/health` funciona mas `/auth/login`, `/categorias` ou `/profissionais` dao `404`, olhe as variaveis:

```powershell
DB_HOST
DB_PORT
DB_USER
DB_PASSWORD
DB_NAME
AUTH_TOKEN_SECRET
```

### `apps/api/src/database/`

Contem:

- configuracao TypeORM;
- entidades;
- migrations.

Arquivos importantes:

```text
database.config.ts
data-source.ts
entities/
migrations/
```

Quando mudar o banco, precisa criar/rodar migration. Em desenvolvimento:

```powershell
cd C:\Users\User\Downloads\ConectaLar-main\ConectaLar-main\apps\api
npm.cmd run db:migration:run
```

### `apps/api/src/auth/`

Controla autenticacao e seguranca:

- cadastro;
- login;
- token JWT;
- MFA administrativo;
- recuperacao de senha;
- confirmacao de e-mail;
- envio SMTP.

Arquivos principais:

```text
auth.controller.ts
auth.service.ts
auth.guard.ts
roles.guard.ts
token.service.ts
password.service.ts
mfa.service.ts
mail.service.ts
```

Se login/cadastro/e-mail falhar, comece por `auth.service.ts`.

### Modulos de negocio da API

Resumo dos modulos:

```text
categorias/       categorias de servico
profissionais/    perfil profissional, servicos, agenda
clientes/         perfil do cliente, enderecos, favoritos
solicitacoes/     pedidos de atendimento
mensagens/        chat vinculado a solicitacao
avaliacoes/       avaliacoes e moderacao
denuncias/        denuncias e moderacao
notificacoes/     notificacoes internas
verificacao/      documentos do profissional
admin-painel/     dashboard, auditoria, moderacoes
admin-usuarios/   gestao de usuarios/admins
historico/        historico de atendimentos
termos/           termos e aceite LGPD
```

## 4. O que esta rodando na API

Quando a API esta completa, ela expõe:

- `GET /health`
- `POST /auth/cadastro`
- `POST /auth/login`
- `POST /auth/login/mfa`
- `POST /auth/senha/recuperacao`
- `POST /auth/senha/recuperacao/confirmar`
- `GET /auth/email/verificacao`
- `POST /auth/email/verificacao/enviar`
- `POST /auth/email/verificacao/confirmar`
- `GET /categorias`
- `GET /profissionais`
- `GET /profissionais/:id`
- `GET/PUT /profissionais/me`
- `GET/PUT /profissionais/me/disponibilidade`
- `GET /profissionais/me/agenda`
- `GET/POST /profissionais/me/documentos`
- `POST/GET/PATCH /solicitacoes`
- `GET/POST /solicitacoes/:id/mensagens`
- `POST/GET /avaliacoes`
- `POST/GET /denuncias`
- `GET/PATCH /notificacoes`
- rotas administrativas em `/admin`
- rotas de documentos em `/documentos-verificacao`
- rotas de termos em `/termos`

O contrato fica em:

```text
apps/api/openapi.yaml
```

Quando tiver duvida sobre entrada/saida de uma rota, procure no OpenAPI.

## 5. Como ligar o projeto localmente

### API

No terminal:

```powershell
cd C:\Users\User\Downloads\ConectaLar-main\ConectaLar-main\apps\api
npm.cmd run dev:local
```

Esse comando usa `start-local.cmd`, que define variaveis locais, faz build e inicia a API na porta `3012`.

Saida esperada:

```json
{"level":"info","event":"api_started","host":"0.0.0.0","port":3012}
```

Teste:

```powershell
Invoke-RestMethod http://127.0.0.1:3012/health
```

### Flutter no navegador/desktop

```powershell
flutter run --dart-define=CONECTALAR_API_BASE_URL=http://127.0.0.1:3012
```

### APK para celular na mesma rede

Use o script:

```bat
scripts\build-apk-local.cmd SEU_IP_DO_WIFI
```

Exemplo:

```bat
scripts\build-apk-local.cmd 192.168.15.5
```

Antes de abrir o app, teste no navegador do celular:

```text
http://SEU_IP_DO_WIFI:3012/health
```

Se nao abrir no navegador do celular, o app tambem nao vai abrir.

## 6. E-mail, confirmacao de conta e recuperacao de senha

O envio de e-mail fica em:

```text
apps/api/src/auth/mail.service.ts
apps/api/src/auth/auth.service.ts
```

Variaveis usadas:

```powershell
SMTP_HOST
SMTP_PORT
SMTP_SECURE
SMTP_STARTTLS
SMTP_USER
SMTP_PASSWORD
SMTP_FROM
APP_PASSWORD_RESET_URL
```

Para Gmail, `SMTP_PASSWORD` precisa ser senha de app, nao a senha normal.

Nunca coloque a senha real em:

- codigo;
- README;
- `.env.example`;
- commits;
- mensagens de chat.

Se cadastro cria conta mas o e-mail nao chega, diagnostique assim:

1. Veja se a API foi ligada no mesmo terminal onde as variaveis SMTP foram configuradas.
2. Teste uma conta nova.
3. Observe se a resposta contem `emailVerificationSent:false`.
4. Veja spam/lixo eletronico.
5. Revise senha de app do Gmail.

Em desenvolvimento, se o envio falhar, a API nao deve derrubar o cadastro com `500`; ela pode retornar que o e-mail nao foi enviado.

## 7. Usuarios demo

Depois de rodar o seed, os usuarios demo sao:

```text
cliente.demo@conectalar.local
profissional.demo@conectalar.local
admin.demo@conectalar.local

Senha:
ConectaLarDemo123!
```

Para recriar/atualizar:

```powershell
cd C:\Users\User\Downloads\ConectaLar-main\ConectaLar-main\apps\api
npm.cmd run db:seed:demo
```

O seed pode invalidar sessoes antigas. Depois de rodar, faca logout/login no app.

## 8. Diagnostico por tipo de erro

### Erro: "Nao foi possivel carregar a pagina inicial"

Provaveis causas:

- API desligada;
- APK com IP antigo;
- celular nao acessa a porta `3012`;
- `/categorias` ou `/profissionais` retornando erro.

Teste:

```powershell
Invoke-RestMethod http://127.0.0.1:3012/health
Invoke-RestMethod http://127.0.0.1:3012/categorias
Invoke-RestMethod http://127.0.0.1:3012/profissionais
```

No celular:

```text
http://SEU_IP:3012/health
```

Arquivos para olhar:

- `lib/screens/home/home_page.dart`
- `lib/services/service_registry.dart`
- `lib/services/categoria_service.dart`
- `lib/services/profissional_service.dart`
- `apps/api/src/categorias/`
- `apps/api/src/profissionais/`

### Erro: API mostra `STARTUP_FAILURE`

Verifique:

```powershell
netstat -ano | findstr :3012
```

Se ja tiver processo na porta, a API ja pode estar ligada.

Tambem rode:

```powershell
npm.cmd run typecheck
npm.cmd run build
npm.cmd run db:migration:run
```

Arquivos para olhar:

- `apps/api/src/main.ts`
- `apps/api/src/app.module.ts`
- `apps/api/src/database/database.config.ts`

### Erro: `/health` funciona, mas outras rotas dao `404`

Provavel causa: API iniciou sem banco/autenticacao configurados.

Verifique variaveis:

```powershell
DB_HOST
DB_PORT
DB_USER
DB_PASSWORD
DB_NAME
AUTH_TOKEN_SECRET
```

Arquivo para olhar:

- `apps/api/src/app.module.ts`

### Erro: login nao funciona

Verifique:

- API ligada;
- usuario existe;
- senha correta;
- seed demo atualizado;
- MFA ativo no admin.

Arquivos:

- `lib/screens/auth/login_page.dart`
- `lib/services/auth_service.dart`
- `apps/api/src/auth/auth.controller.ts`
- `apps/api/src/auth/auth.service.ts`
- `apps/api/src/auth/password.service.ts`
- `apps/api/src/auth/token.service.ts`

### Erro: admin pede codigo MFA

Isso e esperado se MFA estiver ativo.

Arquivos:

- `apps/api/src/auth/mfa.service.ts`
- `apps/api/src/auth/auth.service.ts`
- `lib/screens/auth/login_page.dart`
- `lib/screens/perfil/seguranca_page.dart`

### Erro: cadastro nao envia e-mail

Verifique:

- `SMTP_PASSWORD` foi configurado?
- E senha de app do Gmail?
- A API foi reiniciada depois de configurar?
- O terminal da API mostra erro?
- A resposta tem `emailVerificationSent:false`?

Arquivos:

- `apps/api/src/auth/mail.service.ts`
- `apps/api/src/auth/auth.service.ts`
- `lib/screens/auth/verificacao_email_page.dart`

### Erro: conta nao verificada entra na Home

Isso nao deve acontecer. Verifique:

- `lib/app/app.dart`
- `lib/services/auth_service.dart`
- resposta do login/cadastro contem `usuario.emailVerificado`.

### Erro: solicitacao nao cria

Verifique:

- usuario e cliente;
- profissional existe;
- servico/oferta existe;
- endereco do cliente existe;
- data e horario seguem a disponibilidade do profissional.

Arquivos:

- `lib/screens/servicos/solicitar_servico_page.dart`
- `lib/services/servico_service.dart`
- `apps/api/src/solicitacoes/solicitacoes.service.ts`
- `apps/api/src/disponibilidade/disponibilidade.service.ts`

### Erro: endereco nao aparece para profissional

Regra de negocio:

- antes do aceite, profissional ve so bairro/local protegido;
- depois do aceite, endereco completo e liberado.

Arquivos:

- `apps/api/src/solicitacoes/solicitacoes.service.ts`
- `lib/screens/servicos/detalhes_servico_page.dart`
- `lib/screens/profissional/area_profissional_page.dart`

### Erro: chat nao envia mensagem

Verifique:

- solicitacao existe;
- usuario participa da solicitacao;
- status permite mensagem;
- token valido.

Arquivos:

- `lib/screens/chat/conversa_page.dart`
- `lib/services/mensagem_service.dart`
- `apps/api/src/mensagens/mensagens.service.ts`

### Erro: avaliacao nao salva

Regra:

- avaliacao so deve acontecer apos conclusao confirmada;
- cada lado avalia o outro uma vez;
- avaliacao nova pode ficar pendente de moderacao.

Arquivos:

- `lib/services/avaliacao_service.dart`
- `apps/api/src/avaliacoes/avaliacoes.service.ts`
- `lib/screens/servicos/detalhes_servico_page.dart`

### Erro: denuncia nao aparece no admin

Verifique:

- denuncia foi criada em solicitacao valida;
- usuario e participante da solicitacao;
- admin esta autenticado;
- filtro de status no admin.

Arquivos:

- `lib/screens/servicos/denunciar_servico_page.dart`
- `lib/services/denuncia_service.dart`
- `apps/api/src/denuncias/denuncias.service.ts`
- `lib/screens/admin/admin_pages.dart`

### Erro: upload de documento falha

Regras:

- PDF, JPEG ou PNG;
- limite de 5 MB;
- documento fica privado no storage local;
- moderacao admin aprova/rejeita.

Arquivos:

- `lib/screens/profissional/documentos_verificacao_page.dart`
- `apps/api/src/verificacao/verificacao.service.ts`
- `apps/api/storage/`

## 9. Comandos de verificacao

### Flutter

```powershell
flutter analyze
flutter test
```

Teste menor quando mexer em cadastro/e-mail:

```powershell
flutter test test/cadastro_termos_test.dart
```

### API

```powershell
cd C:\Users\User\Downloads\ConectaLar-main\ConectaLar-main\apps\api
npm.cmd run typecheck
npm.cmd run build
npm.cmd test
```

### Banco

```powershell
npm.cmd run db:migration:run
```

### Diagnostico automatico

Com API ligada:

```powershell
cd C:\Users\User\Downloads\ConectaLar-main\ConectaLar-main\apps\api
$env:CONECTALAR_API_BASE_URL='http://127.0.0.1:3012'
npm.cmd run diagnostico:local
npm.cmd run diagnostico:fluxo
```

## 10. Como ler um erro sem se perder

Use esta ordem:

1. **Qual tela falhou?**
   Procure em `lib/screens/<area>/`.

2. **Qual servico Flutter a tela chama?**
   Procure em `lib/services/`.

3. **Qual endpoint da API foi chamado?**
   Veja o metodo no service Flutter e compare com `apps/api/openapi.yaml`.

4. **Qual controller recebe esse endpoint?**
   Procure em `apps/api/src/<modulo>/<modulo>.controller.ts`.

5. **Qual regra de negocio executa?**
   Procure no arquivo `.service.ts` do modulo.

6. **Qual tabela pode estar envolvida?**
   Procure em `apps/api/src/database/entities/`.

7. **Mudou banco?**
   Verifique migrations em `apps/api/src/database/migrations/`.

## 11. Checklist rapido antes de testar com celular

- API ligada em `0.0.0.0:3012`.
- MySQL ligado.
- Migrations rodadas.
- Celular e PC na mesma rede.
- Firewall liberando porta `3012`.
- Navegador do celular abre `http://IP_DO_PC:3012/health`.
- APK foi gerado com `CONECTALAR_API_BASE_URL=http://IP_DO_PC:3012`.
- Se mudou de rede, gerar APK novo.

## 12. Pendencias tecnicas importantes

Mesmo com o app funcionando localmente, ainda faltam itens para producao:

- hospedagem real da API;
- banco MySQL em servidor/cloud;
- backup e restauracao;
- e-mail transacional profissional;
- armazenamento privado gerenciado para documentos;
- monitoramento;
- logs com retencao;
- politicas LGPD de retencao/exclusao;
- build release e publicacao na Play Store;
- login com Google, se aprovado como requisito.

## 13. Regra de ouro para manutencao

Nao tente corrigir direto pela tela. Siga o caminho:

```text
Tela -> Service Flutter -> ApiService -> Controller API -> Service API -> Entity/Migration -> Banco
```

Assim fica muito mais facil descobrir onde o erro nasceu.
