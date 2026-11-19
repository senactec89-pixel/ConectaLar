# Preparação Android para release

Este checklist acompanha o estado atual dos arquivos Android.

## Estado encontrado

- Rótulo exibido: ConectaLar.
- Namespace e applicationId: `br.com.conectalar.app`; definido antes da criação das credenciais OAuth e da publicação.
- Versão em pubspec.yaml: 1.0.0+1; o Gradle usa esses valores para versionName/versionCode.
- Assinatura release: Gradle lê `android/key.properties`; builds release são bloqueados se os quatro campos da assinatura não estiverem configurados. Não há chave privada no repositório.
- URL da API: o build release exige `CONECTALAR_API_BASE_URL` por `--dart-define`, com domínio público e HTTPS. A configuração local do emulador não pode ser distribuída por engano.
- Ícone: configurado pelos recursos mipmap atuais. Aprovar e validar a arte final em todos os tamanhos e no ícone adaptativo antes da loja.
- O manifesto inclui permissão de Internet. Configuração final de endpoint deve usar HTTPS.

## Checklist antes de gerar o artefato

- [x] Escolher applicationId definitivo e registrar que ele não deve mudar após publicação.
- [x] Trocar namespace/applicationId e revisar identificadores Kotlin/Android associados.
- [ ] Registrar pacote e SHA-1 debug/release no Google Cloud para o login Google.
- [ ] Finalizar ícone adaptativo, ícones por densidade, splash e nome localizado.
- [ ] Definir versão de produto e incrementar versionCode a cada envio.
- [ ] Criar chave de assinatura release e armazenar arquivo/senhas em local seguro, com backup controlado.
- [x] Remover assinatura debug da configuração release; o build exige a configuração local da chave.
- [x] Bloquear build release sem URL HTTPS pública configurada.
- [ ] Aprovar e configurar a URL HTTPS real de produção, sem IP local, segredo ou token no `dart-define`.
- [ ] Revisar permissões e política de privacidade conforme os dados coletados.
- [ ] Gerar APK para distribuição controlada e AAB para Google Play, quando aplicável.
- [ ] Instalar artefato release em aparelho real e testar atualização, login, rede instável, arquivos e notificações.
- [ ] Guardar hash, versão, commit, ambiente e resultado da homologação.

## Configurar assinatura local

1. Copie `android/key.properties.example` para `android/key.properties`.
2. Gere a chave release e guarde-a fora do Git. O caminho esperado pelo exemplo é `android/conectalar-release.jks`.
3. Preencha `storePassword`, `keyPassword`, `keyAlias` e `storeFile` no arquivo local.
4. Confira `git status --short`: `key.properties` e arquivos `.jks`/`.keystore` não devem aparecer.
5. Depois de configurar as credenciais e incrementar a versão aprovada, gere o artefato release e valide a instalação/atualização em aparelho.

Para gerar os artefatos, substitua `<dominio-aprovado>` pelo domínio público da API da equipe:

```sh
flutter build appbundle --release --dart-define=CONECTALAR_API_BASE_URL=https://<dominio-aprovado>
flutter build apk --release --dart-define=CONECTALAR_API_BASE_URL=https://<dominio-aprovado>
```

O Gradle recusa URL ausente, local, IP literal, domínio de exemplo, credenciais na URL e parâmetros de consulta. A URL é configuração do aplicativo, não um local para guardar segredos. Depois do build, instale o APK release no aparelho e teste também a atualização sobre a versão publicada anterior, mantendo o mesmo `applicationId` e a mesma chave.

Exemplo para criar a chave (execute em ambiente seguro e substitua os valores):

```sh
keytool -genkeypair -v -keystore android/conectalar-release.jks -alias conectalar -keyalg RSA -keysize 2048 -validity 10000
```

Este checklist não declara o aplicativo pronto para publicar. A chave e a versão de distribuição ainda dependem de decisão e custódia da equipe.
