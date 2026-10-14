# Progresso do ConectaLar

Atualizado em 14/10/2026 para o estado atual do `main`.

## Estado do produto

O nucleo do app Flutter e da API NestJS/MySQL esta implementado para demonstracao local integrada:

- cadastro, login, confirmacao de e-mail, recuperacao de senha, troca de senha e logout;
- perfis de cliente, profissional e empresa, foto de perfil, enderecos e favoritos;
- categorias, busca, ofertas, disponibilidade e agenda profissional;
- solicitacoes com endereco cadastrado, oferta escolhida, data, horario e os cinco estados oficiais;
- protecao do endereco completo antes das condicoes autorizadas;
- chat por solicitacao, com bloqueio visual quando a conversa esta encerrada;
- conclusao e avaliacoes dos participantes;
- upload de documentos PDF/JPEG/PNG, armazenamento privado local, leitura administrativa autenticada e preview de imagem/PDF no app;
- regra de selo profissional baseada em documento de identidade aprovado;
- denuncias, notificacoes internas e auditoria administrativa;
- modulos administrativos para usuarios, documentos, categorias, avaliacoes, denuncias e auditoria.

## Validacoes recentes

- API: `npm.cmd test` aprovado em 14/10/2026 com 16 testes.
- Flutter: `flutter analyze` aprovado em 14/10/2026.
- Flutter: `flutter test` aprovado em 14/10/2026 com 159 testes.
- Android debug: `flutter build apk --debug --dart-define=CONECTALAR_API_BASE_URL=http://192.168.0.3:3012` aprovado em 14/10/2026.

Essas validacoes cobrem codigo, contratos simulados e widgets. Elas nao substituem homologacao manual completa em aparelho real com API e MySQL do ambiente que sera usado.

## Ainda falta para homologar

- Percorrer os fluxos de cliente, profissional, empresa e admin em aparelho fisico com API e MySQL atualizados.
- Confirmar cadastro, verificacao de e-mail, login, endereco, busca, solicitacao, aceite/recusa, chat, conclusao, avaliacao, denuncia, documentos e moderacao.
- Testar documentos reais: PDF, JPEG, PNG, arquivo invalido, arquivo maior que 5 MB, aprovacao, rejeicao e reflexo do selo no perfil publico.
- Validar envio de e-mail em rede real e conferir spam/quarentena.
- Testar mudanca de IP/base URL antes de cada APK local.
- Reconciliar relatorios antigos que registram contagens de testes anteriores.

Roteiros relacionados:

- [Checklist cliente](checklist-homologacao-cliente.md)
- [Checklist profissional](checklist-homologacao-profissional.md)
- [Checklist administracao](checklist-homologacao-admin.md)

## Antes de producao

Antes de hospedar/publicar, ainda precisam ser definidos e demonstrados:

- storage privado gerenciado para arquivos;
- antivirus ou varredura equivalente para documentos enviados;
- politica de retencao e descarte de documentos e dados pessoais;
- HTTPS, dominio, variaveis de ambiente e origens CORS de producao;
- rate limit distribuido, caso exista mais de uma instancia;
- backup/restauracao testados;
- monitoramento, alertas e resposta a incidentes;
- pipeline de publicacao;
- assinatura release Android e preparacao de iOS em ambiente macOS.
