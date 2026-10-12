# Progresso do ConectaLar

Atualizado em 11/10/2026 para main, commit 0264eab.

## Estado do produto

O núcleo do app Flutter e da API NestJS/MySQL está implementado para demonstração local integrada:

- cadastro, login, troca de senha e logout;
- perfis de cliente, profissional e empresa, endereços e favoritos;
- categorias, busca, ofertas e disponibilidade;
- solicitações com endereço cadastrado, agenda e os cinco estados oficiais;
- proteção do endereço antes do aceite;
- chat por solicitação;
- conclusão e avaliações dos participantes;
- upload e moderação de documentos;
- denúncias, notificações internas e auditoria administrativa;
- módulos de administração para usuários, documentos, categorias, avaliações e denúncias.

As correções recentes também alinharam o campo enviado pelo chat, adicionaram o fluxo de denúncia do cliente, exigiram endereço cadastrado na solicitação, aplicaram senha forte no app e na API, corrigiram o overflow do selo profissional e melhoraram a mensagem de busca vazia.

## Validações registradas

- Flutter: **90 testes aprovados**, conforme resultado mais recente informado pela equipe.
- Flutter: análise estática sem problemas no último registro disponível.
- API: existem testes unitários/contratuais, testes de integração com MySQL e scripts de diagnóstico local. Os resultados registrados anteriormente são anteriores ao commit 0264eab e devem ser repetidos antes de uma entrega.
- Capturas Flutter Web em 360, 390 e 412 px estão em docs/evidencias. São prévias com dados fictícios.

Não houve execução de testes ao atualizar este documento. Antes de usar estes resultados como evidência de release, registrar comando, data, commit, ambiente e resultado em um único lugar.

## Ainda falta para homologar

- Percorrer o fluxo cliente, profissional e admin no aparelho com API e MySQL atualizados.
- Confirmar cadastro, endereço, busca, solicitação, aceite/recusa, chat, conclusão, avaliação, denúncia, documentos e moderação.
- Conferir o seletor nativo, arquivos inválidos/maiores que 5 MB, teclado, fonte ampliada e retorno de erros.
- Distinguir falha de rede de lista vazia no carregamento de dados da solicitação.
- Reconciliar os números de testes nos relatórios antigos.

Roteiros: [cliente](checklist-homologacao-cliente.md), [profissional](checklist-homologacao-profissional.md) e [administração](checklist-homologacao-admin.md).

## Antes de produção

MFA, recuperação por contato verificado, armazenamento gerenciado de documentos, validação de conteúdo, política de retenção, HTTPS, rate limit distribuído, backup/restauração, monitoramento, pipeline e assinatura dos aplicativos precisam ser definidos e demonstrados. Veja [pendências](pendencias.md) e [preparação Android](preparacao-android-release.md).
