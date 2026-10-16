# Login com Google

O codigo do ConectaLar suporta login Google no Android e no Flutter Web. O app
obtem um ID token e a API valida assinatura, emissor, validade e audiencia antes
de criar a sessao local. O ID do usuario ou o e-mail enviados isoladamente nunca
sao aceitos como prova de identidade.

## Identificadores usados

- Pacote Android: `br.com.conectalar.app`.
- Client ID Web: usado pelo Flutter como `GOOGLE_WEB_CLIENT_ID` e pela API como
  audiencia confiavel.
- Client ID Android: associado ao pacote e ao SHA-1 da assinatura do APK.
- Nao e necessario adicionar Firebase nem `google-services.json` para este
  fluxo, porque o client ID do servidor e informado ao plugin pelo Dart.
- O OAuth client secret nao e usado no app e nao deve ser colocado no repositorio.

## 1. Criar ou escolher o projeto Google Cloud

1. Abra `https://console.cloud.google.com/` com a conta da equipe.
2. Crie um projeto dedicado ao ConectaLar ou escolha o projeto ja usado pelos
   recursos de mapas.
3. Em Google Auth Platform, preencha nome do app, e-mail de suporte e contatos.
4. Durante desenvolvimento, mantenha o app em teste e cadastre como usuarios de
   teste as contas Google que farao a homologacao.
5. O fluxo usa apenas identidade basica (`openid`, e-mail e perfil); nao solicite
   acesso ao Drive, contatos ou outros dados.

## 2. Criar o Client ID Web

1. Em Credenciais, escolha criar `OAuth client ID` do tipo `Web application`.
2. Para teste Web local, adicione as origens autorizadas
   `http://localhost` e `http://localhost:7357`.
3. Quando houver site HTTPS, adicione exatamente a origem publicada, sem caminho.
4. Copie o valor terminado em `.apps.googleusercontent.com`. Esse e o
   `GOOGLE_WEB_CLIENT_ID`; ele nao e uma senha.

No arquivo ignorado `apps/api/.env.local`, adicione:

```env
GOOGLE_WEB_CLIENT_ID=SEU_CLIENT_ID_WEB.apps.googleusercontent.com
```

Em hospedagem, configure o mesmo valor como variavel de ambiente da API. Se
houver mais de uma audiencia intencional, use `GOOGLE_OAUTH_CLIENT_IDS` com IDs
separados por virgula e mantenha a lista minima.

Para Flutter Web em producao, inclua tambem a origem HTTPS exata em
`CORS_ALLOWED_ORIGINS` na API e nas origens JavaScript autorizadas da credencial
Web do Google.

## 3. Descobrir o SHA-1 Android

Na raiz do projeto, execute:

```powershell
cd android
.\gradlew.bat signingReport
```

No bloco `Variant: debug`, copie o `SHA1`. O APK release tera outro SHA-1; quando
a chave release definitiva for criada, cadastre tambem um Client ID Android para
essa assinatura. Nao publique usando a chave debug.

## 4. Criar o Client ID Android

1. Crie outra credencial `OAuth client ID`, agora do tipo `Android`.
2. Informe o pacote `br.com.conectalar.app`.
3. Informe o SHA-1 obtido no passo anterior.
4. Nao copie o client secret para o Flutter. A associacao pacote + SHA-1 e a
   configuracao necessaria para o cliente Android.

## 5. Aplicar a migration e iniciar a API

Depois de configurar banco e variaveis locais:

```powershell
cd apps\api
npm.cmd run db:migration:run
npm.cmd run dev:local
```

A migration `GoogleLogin1760122000000` cria o vinculo unico `google_sub`.

## 6. Executar ou gerar o app

Android conectado ou emulador:

```powershell
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=SEU_CLIENT_ID_WEB.apps.googleusercontent.com --dart-define=CONECTALAR_API_BASE_URL=http://10.0.2.2:3012
```

Para aparelho fisico, troque `10.0.2.2` pelo IPv4 do computador acessivel na
mesma rede. Para gerar APK debug:

```powershell
flutter build apk --debug --dart-define=GOOGLE_WEB_CLIENT_ID=SEU_CLIENT_ID_WEB.apps.googleusercontent.com --dart-define=CONECTALAR_API_BASE_URL=http://IP_DO_COMPUTADOR:3012
```

Flutter Web local precisa de porta fixa e origem cadastrada:

```powershell
flutter run -d chrome --web-hostname localhost --web-port 7357 --dart-define=GOOGLE_WEB_CLIENT_ID=SEU_CLIENT_ID_WEB.apps.googleusercontent.com --dart-define=CONECTALAR_API_BASE_URL=http://127.0.0.1:3012
```

## 7. Roteiro de teste

1. Entre com uma conta Google ainda ausente no ConectaLar.
2. Confirme que o app pede tipo de conta e aceite dos termos.
   O primeiro cadastro tambem define uma senha de recuperacao do ConectaLar;
   ela nao e a senha da conta Google.
3. Cancele e confira que nenhuma conta foi criada.
4. Repita, conclua como cliente e confira a Home.
5. Saia e entre novamente; o cadastro nao deve ser solicitado outra vez.
6. Repita com nova conta profissional e confirme o redirecionamento para completar
   perfil, servicos e documentos.
7. Teste uma conta local Gmail existente: o papel atual deve ser preservado.
8. Teste APK com assinatura ou pacote nao cadastrados: o login deve falhar fechado.
9. Confirme no banco que `google_sub` e unico e que nenhum ID token foi gravado.
10. Confira que administrador continua usando senha e MFA; o Google nao vincula
    automaticamente uma conta administrativa pelo e-mail.

## Diagnostico rapido

- `clientConfigurationError` ou cancelamento logo apos escolher a conta: confira
  pacote, SHA-1 e Client ID Web.
- API responde 503: faltou `GOOGLE_WEB_CLIENT_ID` ou
  `GOOGLE_OAUTH_CLIENT_IDS` no processo da API.
- API responde 401: token expirado, audiencia diferente ou credencial invalida.
- Web nao mostra o botao: confira o `--dart-define`, a origem autorizada e a porta
  fixa `7357`.
- Depois de alterar `.env.local`, reinicie a API. Depois de alterar
  `--dart-define`, gere ou execute o Flutter novamente.
