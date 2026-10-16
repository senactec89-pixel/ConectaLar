# Preparação Android para release

Este checklist acompanha o estado atual dos arquivos Android.

## Estado encontrado

- Rótulo exibido: ConectaLar.
- Namespace e applicationId: `br.com.conectalar.app`; definido antes da criação das credenciais OAuth e da publicação.
- Versão em pubspec.yaml: 1.0.0+1; o Gradle usa esses valores para versionName/versionCode.
- Assinatura release: atualmente usa a chave debug; não publicar assim.
- Ícone: configurado pelos recursos mipmap atuais. Aprovar e validar a arte final em todos os tamanhos e no ícone adaptativo antes da loja.
- O manifesto inclui permissão de Internet. Configuração final de endpoint deve usar HTTPS.

## Checklist antes de gerar o artefato

- [x] Escolher applicationId definitivo e registrar que ele não deve mudar após publicação.
- [x] Trocar namespace/applicationId e revisar identificadores Kotlin/Android associados.
- [ ] Registrar pacote e SHA-1 debug/release no Google Cloud para o login Google.
- [ ] Finalizar ícone adaptativo, ícones por densidade, splash e nome localizado.
- [ ] Definir versão de produto e incrementar versionCode a cada envio.
- [ ] Criar chave de assinatura release e armazenar arquivo/senhas fora do Git e do código.
- [ ] Remover assinatura debug da configuração release e validar acesso restrito ao segredo.
- [ ] Configurar URL HTTPS de produção sem IP local, segredo ou token em dart-define versionado.
- [ ] Revisar permissões e política de privacidade conforme os dados coletados.
- [ ] Gerar APK para distribuição controlada e AAB para Google Play, quando aplicável.
- [ ] Instalar artefato release em aparelho real e testar atualização, login, rede instável, arquivos e notificações.
- [ ] Guardar hash, versão, commit, ambiente e resultado da homologação.

Comandos de build devem ser definidos depois da configuração final do ambiente e da assinatura. Este checklist não declara o aplicativo pronto para publicar.
