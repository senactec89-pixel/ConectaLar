# Preparação Android para release

Esta é uma análise documental. Nenhum arquivo Android foi modificado.

## Estado encontrado

- Rótulo exibido: ConectaLar.
- Namespace e applicationId: com.example.conectarlar_app; ainda identificador de template, precisa de um ID único e definitivo.
- Versão em pubspec.yaml: 1.0.0+1; o Gradle usa esses valores para versionName/versionCode.
- Assinatura release: atualmente usa a chave debug; não publicar assim.
- Ícone: configurado pelos recursos mipmap atuais. Aprovar e validar a arte final em todos os tamanhos e no ícone adaptativo antes da loja.
- O manifesto inclui permissão de Internet. Configuração final de endpoint deve usar HTTPS.

## Checklist antes de gerar o artefato

- [ ] Escolher applicationId definitivo, verificar disponibilidade e registrar que ele não deve mudar após publicação.
- [ ] Trocar namespace/applicationId e revisar identificadores Kotlin/Android associados.
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
