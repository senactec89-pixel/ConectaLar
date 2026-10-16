# Progresso do ConectaLar

Atualizado em 16/10/2026 para o estado atual do `main`.

## Estado do produto

O nucleo do app Flutter e da API NestJS/MySQL esta implementado para demonstracao local integrada:

- cadastro, login por senha ou Google, confirmacao de e-mail, recuperacao de senha, troca de senha e logout;
- sessao persistida no armazenamento criptografado da plataforma, com migracao e remocao automatica do valor legado;
- exportacao autenticada dos dados pessoais em JSON e exclusao de conta com anonimizacao, invalidacao de sessoes e trilha de atendimento LGPD;
- perfis de cliente, profissional e empresa, foto de perfil, enderecos e favoritos;
- categorias, busca, ofertas, disponibilidade e agenda profissional;
- GPS sob consentimento, filtro por distancia e raio de atendimento, com mapa Android de coordenadas profissionais aproximadas;
- solicitacoes com endereco cadastrado, oferta escolhida, data, horario e os cinco estados oficiais;
- protecao do endereco completo antes das condicoes autorizadas;
- chat por solicitacao, com bloqueio visual quando a conversa esta encerrada;
- conclusao e avaliacoes dos participantes;
- upload de documentos PDF/JPEG/PNG, varredura ClamAV configuravel, storage local ou Cloudflare R2, leitura administrativa autenticada e preview de imagem/PDF no app;
- regra de selo profissional baseada em documento de identidade aprovado;
- denuncias, notificacoes internas e auditoria administrativa;
- modulos administrativos para usuarios, documentos, categorias, avaliacoes, denuncias e auditoria.

## Validacoes recentes

- API: `npm.cmd test` aprovado em 16/10/2026 com 33 testes.
- Flutter: `flutter analyze` aprovado em 16/10/2026.
- Flutter: `flutter test` aprovado em 16/10/2026 com 180 testes.
- Android debug: `flutter build apk --debug` aprovado em 16/10/2026, incluindo armazenamento seguro e compartilhamento nativo da exportacao LGPD.
- Android debug recompilado com GPS e mapa habilitados por chave ficticia somente para validacao de build; a exibicao real depende de chave Google Maps restrita.
- Integracao LGPD com MySQL local: migration, exportacao, exclusao, invalidacao do token e bloqueio do login antigo aprovados em 16/10/2026.
- Login Google: testes de contrato e widgets aprovados; builds Android e Web compilados com client ID ficticio apenas para validar o codigo. A homologacao real depende das credenciais OAuth da equipe.
- Migration `GoogleLogin1760122000000` aplicada com sucesso no MySQL local em 16/10/2026.

Essas validacoes cobrem codigo, contratos simulados e widgets. Elas nao substituem homologacao manual completa em aparelho real com API e MySQL do ambiente que sera usado.

## Ainda falta para homologar

- Percorrer os fluxos de cliente, profissional, empresa e admin em aparelho fisico com API e MySQL atualizados.
- Confirmar cadastro, verificacao de e-mail, login, endereco, busca, solicitacao, aceite/recusa, chat, conclusao, avaliacao, denuncia, documentos e moderacao.
- Testar documentos reais: PDF, JPEG, PNG, arquivo invalido, arquivo maior que 5 MB, aprovacao, rejeicao e reflexo do selo no perfil publico.
- Validar envio de e-mail em rede real e conferir spam/quarentena.
- Testar mudanca de IP/base URL antes de cada APK local.
- Reconciliar relatorios antigos que registram contagens de testes anteriores.
- Homologar em aparelho real a exportacao/compartilhamento do JSON e a exclusao de contas de cliente, profissional e empresa.
- Criar as credenciais OAuth no Google Cloud e homologar login Google no APK e no Flutter Web seguindo `docs/login-google.md`.
- Criar chaves Google Maps separadas e restritas, geocodificar os perfis e homologar GPS/mapa em aparelho Android seguindo `docs/gps-mapa-distancia.md`.

Roteiros relacionados:

- [Checklist cliente](checklist-homologacao-cliente.md)
- [Checklist profissional](checklist-homologacao-profissional.md)
- [Checklist administracao](checklist-homologacao-admin.md)

## Antes de producao

Antes de hospedar/publicar, ainda precisam ser definidos e demonstrados:

- bucket Cloudflare R2 real criado, credenciais configuradas e upload/download homologados na hospedagem;
- ClamAV instalado, atualizado e homologado no ambiente de hospedagem;
- politica juridica final de retencao e descarte por categoria de dado; o fluxo tecnico de exportacao, exclusao e anonimizacao ja existe;
- HTTPS, dominio, variaveis de ambiente e origens CORS de producao;
- rate limit distribuido, caso exista mais de uma instancia;
- backup/restauracao testados;
- monitoramento, alertas e resposta a incidentes;
- pipeline de publicacao;
- assinatura release Android e preparacao de iOS em ambiente macOS.
