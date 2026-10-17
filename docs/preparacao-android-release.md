# Preparação Android para release

Este checklist acompanha o estado atual dos arquivos Android.

## Estado encontrado

- Rótulo exibido: ConectaLar.
- Namespace e applicationId: `br.com.conectalar.app`; definido antes da criação das credenciais OAuth e da publicação.
- Versão em pubspec.yaml: 1.0.0+1; o Gradle usa esses valores para versionName/versionCode.
- Assinatura release: Gradle lê `android/key.properties`; builds release são bloqueados se os quatro campos da assinatura não estiverem configurados. Não há chave privada no repositório.
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
- [ ] Configurar URL HTTPS de produção sem IP local, segredo ou token em dart-define versionado.
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

Exemplo para criar a chave (execute em ambiente seguro e substitua os valores):

```sh
keytool -genkeypair -v -keystore android/conectalar-release.jks -alias conectalar -keyalg RSA -keysize 2048 -validity 10000
```

Este checklist não declara o aplicativo pronto para publicar. A chave e a versão de distribuição ainda dependem de decisão e custódia da equipe.
