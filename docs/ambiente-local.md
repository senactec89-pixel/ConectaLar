# Ambiente local do ConectaLar

Este roteiro padroniza o ambiente de teste local para reduzir falhas de API causadas por IP incorreto, banco sem migration ou seed desatualizado.

## 1. MySQL

Confirme que o MySQL local esta ligado e acessivel na porta usada pelo projeto. No ambiente atual de desenvolvimento:

```powershell
$env:DB_HOST='127.0.0.1'
$env:DB_PORT='3307'
$env:DB_USER='conectalar_app'
$env:DB_PASSWORD='ConectaLarDev123!'
$env:DB_NAME='conectalar_dev'
```

## 2. API

No terminal do VS Code:

```powershell
cd C:\Users\User\Downloads\ConectaLar-main\ConectaLar-main\apps\api
$env:HOST='0.0.0.0'
$env:PORT='3012'
$env:DB_HOST='127.0.0.1'
$env:DB_PORT='3307'
$env:DB_USER='conectalar_app'
$env:DB_PASSWORD='ConectaLarDev123!'
$env:DB_NAME='conectalar_dev'
$env:AUTH_TOKEN_SECRET='local-dev-secret-change-before-production-123456'
npm.cmd run db:migration:run
npm.cmd run db:seed:demo
npm.cmd start
```

Em outro terminal, valide:

```powershell
Invoke-RestMethod http://127.0.0.1:3012/health
```

Resultado esperado:

```json
{"status":"ok"}
```

## 3. Diagnostico automatico

Com a API ligada, rode:

```powershell
cd C:\Users\User\Downloads\ConectaLar-main\ConectaLar-main\apps\api
$env:CONECTALAR_API_BASE_URL='http://127.0.0.1:3012'
npm.cmd run diagnostico:local
```

O diagnostico confere:

- `/health`;
- conexao com MySQL;
- migrations pendentes;
- login dos usuarios demo;
- categorias e profissionais publicos;
- endereco do cliente demo;
- painel e agenda profissional;
- denuncias e avaliacoes administrativas.

Se aparecer migration pendente, rode `npm.cmd run db:migration:run` e repita o diagnostico. Se o seed estiver desatualizado ou os logins demo falharem, rode `npm.cmd run db:seed:demo`.

## 4. Usuarios demo

```text
cliente.demo@conectalar.local
profissional.demo@conectalar.local
admin.demo@conectalar.local

Senha:
ConectaLarDemo123!
```

Depois de rodar o seed, faca logout/login novamente no app. O seed atualiza a versao dos tokens e invalida sessoes antigas.

## 5. APK para celular

Use o IPv4 real do Wi-Fi do computador, nao adaptadores virtuais. Exemplo:

```powershell
ipconfig
```

Depois gere o APK:

```powershell
flutter build apk --debug --dart-define=CONECTALAR_API_BASE_URL=http://SEU_IP_DO_WIFI:3012
```

Instale no celular:

```powershell
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

No celular, abra no navegador:

```text
http://SEU_IP_DO_WIFI:3012/health
```

Se o navegador do celular nao abrir o `/health`, o problema ainda e rede/firewall. Se o navegador abrir e o app nao, o APK provavelmente foi gerado com IP antigo ou URL incorreta.
