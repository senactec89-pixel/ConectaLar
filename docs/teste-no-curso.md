# Teste do APK em outra rede

Use este roteiro quando trocar de Wi-Fi, por exemplo no curso.

## 1. Descobrir o IP do computador

No PowerShell:

```powershell
ipconfig
```

Use o IPv4 do adaptador Wi-Fi que estiver conectado na mesma rede do celular.
Evite IP de Radmin VPN, VirtualBox, VMware ou adaptadores sem gateway.

## 2. Ligar a API

No terminal do VS Code:

```powershell
cd C:\Users\User\Downloads\ConectaLar-main\ConectaLar-main\apps\api
npm.cmd run dev:local
```

Se for testar envio real de e-mail, configure as variaveis SMTP no mesmo
terminal antes de ligar a API. Nao coloque a senha de app do Gmail em arquivos
versionados.

No ambiente atual, o jeito mais simples e:

```powershell
cd C:\Users\User\Downloads\ConectaLar-main\ConectaLar-main\apps\api
.\scripts\configurar-email-local.ps1
npm.cmd run email:test -- seu-email-de-teste@gmail.com
npm.cmd run dev:local
```

O script cria `apps/api/.env.local`, que e carregado automaticamente pelo
`start-local.cmd` e fica fora do Git.

## 3. Gerar o APK com o IP da rede

Na raiz do projeto:

```powershell
cd C:\Users\User\Downloads\ConectaLar-main\ConectaLar-main
.\scripts\build-apk-local.ps1 -Ip SEU_IP_DO_WIFI
```

Se o PowerShell bloquear scripts, use o `.cmd`:

```bat
scripts\build-apk-local.cmd SEU_IP_DO_WIFI
```

Exemplo:

```powershell
.\scripts\build-apk-local.ps1 -Ip 192.168.15.5
```

O script copia o APK para a pasta Downloads com um nome parecido com:

```text
C:\Users\User\Downloads\ConectaLar-debug-192-168-15-5-3012.apk
```

## 4. Conferir no celular

Antes de instalar ou abrir o app, teste no navegador do celular:

```text
http://SEU_IP_DO_WIFI:3012/health
```

O esperado e:

```json
{"status":"ok"}
```

Se o navegador do celular nao abrir esse endereco, o app tambem nao vai
conseguir acessar a API. Nesse caso, confira se PC e celular estao na mesma
rede, se a API esta ligada e se o firewall do Windows liberou a porta 3012.
