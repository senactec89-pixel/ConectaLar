# Progresso do ConectaLar

## Estado de seguranca atualizado em 27/10/2026

Preparado o fluxo de habilitacao separado do selo documental, com bloqueio na API,
pendencias no app e revisao administrativa auditada com MFA. O adaptador ID ZapSign
e a tela de identidade estao implementados, mas a chave nao foi configurada e o
fluxo nao foi homologado com o fornecedor. As migrations foram validadas na cadeia
completa em MySQL descartavel local; isso nao confirma aplicacao no banco hospedado.
Telefone e antecedentes continuam pendentes e nao ha liberacao de novos
atendimentos nesta fase. A lista historica de funcionalidades abaixo nao significa
que a demo anterior de solicitacoes continue liberada. Ver [detalhes](habilitacao-profissional.md).

As referencias a demos antigas neste documento sao historicas e nao substituem os
roteiros atuais de homologacao.

## Estado do produto

### Bloqueio de contratação vigente

Novas solicitações e aceites estão bloqueados deliberadamente pela API com `409 PROFISSIONAL_HABILITACAO_PENDENTE`. O catálogo pode exibir profissionais, mas deve apresentá-los como indisponíveis para contratação. Cadastro, perfil, ofertas, disponibilidade e envio de documentos não significam habilitação. A demo integrada descrita mais abaixo é evidência histórica de uma política anterior; não representa o comportamento atual nem deve ser usada para declarar contratação homologada.

O nucleo do app Flutter e da API NestJS/MySQL esta implementado para demonstracao local integrada:

- cadastro, login por senha ou Google, confirmacao de e-mail, recuperacao de senha, troca de senha e logout;
- sessao persistida no armazenamento criptografado da plataforma, com migracao e remocao automatica do valor legado;
- exportacao autenticada dos dados pessoais em JSON e exclusao de conta com anonimizacao, invalidacao de sessoes e trilha de atendimento LGPD;
- perfis de cliente, profissional e empresa, foto de perfil, enderecos e favoritos;
- categorias, busca, ofertas, disponibilidade e agenda profissional;
- GPS sob consentimento, filtro por distancia e raio de atendimento, com mapa Android de coordenadas profissionais aproximadas;
- infraestrutura de solicitações com endereço cadastrado, oferta escolhida, data, horário e estados oficiais; criação e aceite permanecem bloqueados até concluir a política de habilitação;
- protecao do endereco completo antes das condicoes autorizadas;
- chat por solicitacao, com bloqueio visual quando a conversa esta encerrada e carregamento progressivo das mensagens anteriores;
- conclusao e avaliacoes dos participantes;
- upload de documentos PDF/JPEG/PNG, varredura ClamAV configuravel, storage local ou Cloudflare R2, leitura administrativa autenticada e preview de imagem/PDF no app;
- regra de selo profissional baseada em documento de identidade aprovado;
- denuncias, notificacoes internas e auditoria administrativa;
- modulos administrativos para usuarios, documentos, categorias, avaliacoes, denuncias e auditoria.
- pedidos, conversas, notificacoes e denuncias pessoais paginados, sem truncamento silencioso das listas.

## Validacoes recentes

### Verificacao de bloqueio, MySQL, ClamAV e storage em 27/10/2026

- Documentacao de homologacao sincronizada: solicitacoes e aceites devem falhar com
  `409 PROFISSIONAL_HABILITACAO_PENDENTE`; os resultados de uma demo antiga foram
  identificados explicitamente como historicos.
- `npm run test:integration:mysql`: 3 suites passaram em MySQL 8 local, usando bancos
  aleatorios em loopback, aplicando a cadeia de migrations e removendo os bancos ao
  final. Nenhuma base de desenvolvimento ou producao foi usada.
- ClamAV local real em `127.0.0.1:3310`: conteudo benigno aceito e assinatura EICAR
  detectada via memoria, sem gravar arquivo de teste.
- Testes de malware e storage: 6 passaram. O adaptador R2 foi exercitado com endpoint
  S3 local isolado para upload/leitura/exclusao; isso nao e homologacao contra Cloudflare.
- R2 real continua pendente: nao havia bucket/credenciais de homologacao configurados
  neste ambiente, portanto nenhum objeto foi enviado a uma conta Cloudflare.
- `npm.cmd run typecheck` passou e `npm.cmd test` passou com 124 testes em 27/10/2026.
- O procedimento e comando seguro para piloto real estao em [piloto R2](piloto-r2.md).
- A revisao manual de documentos esta especificada como proposta provisoria em
  [verificacao manual profissional](verificacao-manual-profissional.md); nao habilita atendimentos.

- API: `npm.cmd test` aprovado em 23/10/2026 com 73 testes, incluindo validacao de limites, metadados e ordenacao da paginacao.
- Flutter: `flutter analyze --no-pub` e `flutter test --no-pub` aprovados em 23/10/2026, com 240 testes.
- Android debug: `flutter build apk --debug` aprovado em 16/10/2026, incluindo armazenamento seguro e compartilhamento nativo da exportacao LGPD.
- Android debug recompilado com GPS e mapa habilitados por chave ficticia somente para validacao de build; a exibicao real depende de chave Google Maps restrita.
- Integracao LGPD com MySQL local: migration, exportacao, exclusao, invalidacao do token e bloqueio do login antigo aprovados em 16/10/2026.
- Login Google: testes de contrato e widgets aprovados; builds Android e Web compilados com client ID ficticio apenas para validar o codigo. A homologacao real depende das credenciais OAuth da equipe.
- Migration `GoogleLogin1760122000000` aplicada com sucesso no MySQL local em 16/10/2026.

Essas validacoes cobrem codigo, contratos simulados e widgets. Elas nao substituem homologacao manual completa em aparelho real com API e MySQL do ambiente que sera usado.

## Ainda falta para homologar

- Percorrer os fluxos de cliente, profissional, empresa e admin em aparelho fisico com API e MySQL atualizados.
- Confirmar cadastro, verificação de e-mail, login, endereço, busca, aviso de indisponibilidade e bloqueio de solicitação/aceite. Não homologar contratação ponta a ponta enquanto a política estiver pendente.
- Exercitar chat, conclusão, avaliação e denúncia somente com registros legados ou fixtures isoladas, sem afrouxar a proteção de novas contratações.
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
