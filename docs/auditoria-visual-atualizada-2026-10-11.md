# Auditoria visual atualizada — 11/10/2026

Base: `Prototipo 2.pdf` (8 páginas), `ConectaLar_Telas_Individuais_Cliente_Profissional.pdf` (14 páginas) e `ConectaLar_Telas_Restantes_Administrativo.pdf` (24 páginas). Os PDFs são referências de apresentação; operações e dados continuam condicionados ao contrato e às permissões existentes. A [auditoria anterior](etapas-front-end-2026-10-11.md) registra a comparação inicial de cada grupo com os protótipos.

## Cliente

| Tela | Referência | Conferência atual |
| --- | --- | --- |
| Home | Principal p. 1; C01 | Cabeçalho com casa circular e busca preservados. Rótulos de categorias completos, áreas de toque de 48 px e composição ampliada sem sobreposição. [Capturas](evidencias/home-responsiva-2026-10-11/README.md). |
| Busca e resultados | Principal p. 2; C02 | Cabeçalho, filtros e lista têm hierarquia próxima da referência. Card lida com texto a 200% sem perder preço, selo ou ações. [Capturas](evidencias/cards-profissionais-2026-10-11/README.md). |
| Favoritos | Principal p. 3 | Card compartilhado legível a 200%; coração mantém ação e alvo de toque. [Capturas](evidencias/cards-profissionais-2026-10-11/README.md). |
| Perfil público do profissional | C03 | Nome, descrição, avaliação e selo mantêm leitura em 360/390/412 px, inclusive a 200%. A foto só aparece quando existe no dado; o protótipo ilustra uma foto. [Capturas](evidencias/perfil-publico-2026-10-11/README.md). |
| Solicitação | C04 | Campos e resumo seguem a API, incluindo oferta/endereço retornados. O commit remoto `6753252` tratou agenda e erros. A conferência visual com dados reais continua no roteiro de homologação. |
| Meus serviços e detalhes | Principal p. 4; C05 | Filtros e cinco estados oficiais presentes; lista atualiza ao retornar dos detalhes. A apresentação com pedidos reais depende da API. |
| Chat | Principal p. 8; C06 | Mensagens, lista vazia, erro, nova tentativa, atualização e feedback de envio presentes. O chat não confirma agendamento. |
| Conta, endereços e segurança | Principal p. 5; C07 | Formulários e ações usam o tema comum. Ajuda do e-mail e erro de Meus dados agora acomodam texto ampliado e altura reduzida. [Capturas](evidencias/meus-dados-2026-10-11/README.md). |
| Login, cadastro e termos | Principal p. 6–7; R01–R02 | Campos, escolha cliente/profissional/empresa e leitura de termos presentes. Erros e estados de envio já usam feedback explícito. |

## Profissional

| Tela | Referência | Conferência atual |
| --- | --- | --- |
| Área profissional | P01 | Resumo, próximos atendimentos e solicitações recentes presentes; o selo traz ressalva documental. [Captura](evidencias/front-end-2026-10-11/profissional-390.png). |
| Pedidos recebidos e detalhe | P02–P03 | Filtros, estado do pedido, endereço protegido e ações conforme o retorno da API. Sem estados de solicitação adicionais. |
| Agenda e disponibilidade | P04 | Calendário e horários semanais presentes; modal de edição conferido em 360/390/412 px, texto a 200% e viewport reduzido. [Capturas](evidencias/acabamento-isolado-2026-10-11/README.md). |
| Serviços e perfil privado | P05–P06 | Ofertas, preço inicial, região e edição já usam componentes do tema. A suíte percorre telas preenchidas nas três larguras com texto ampliado. |
| Documentos e avaliações | P07 e fluxo de avaliações | Seletor de arquivo, limite de 5 MB, status documental, avaliações recebidas e estados de carregamento/erro/vazio presentes. Conteúdo privado depende da API. |

## Administração

| Tela | Referência | Conferência atual |
| --- | --- | --- |
| Painel | R16 | Indicadores e acessos rápidos passaram pelo ajuste anterior de overflow e pela conferência em 360/390/412 px. [Capturas](evidencias/front-end-2026-10-11/README.md). |
| Usuários | R16 e navegação administrativa | Lista, busca, tipo de conta, status e ações existentes; teste visual com sessão e HTTP simulados. |
| Documentos | Fluxo documental | Filtros pendentes/aprovados/rejeitados/todos, justificativa e decisões presentes; documentos não são expostos sem permissão. |
| Denúncias e avaliações | R03–R05 | Lista, análise, decisão e estados visuais presentes nos módulos autenticados de teste. |
| Categorias | R08–R09 | Busca, criação, edição e status presentes conforme contrato implementado. |
| Auditoria e acesso restrito | R19 | Ator, alvo, ação e data apresentados quando retornados; acesso restrito permanece explícito. |

## Verificações e limite prático

- O tema central define verde, fundos, texto, bordas e ações. Os ajustes recentes conservaram os valores das cores existentes.
- `flutter analyze --no-pub`: sem problemas. `flutter test --no-pub --concurrency=2`: 90 testes aprovados na revisão atual.
- Há testes com 360, 390 e 412 px; texto a 200% foi conferido em Home, cards de Busca/Favoritos, Meus dados, disponibilidade e perfil público. O restante das telas profissionais e administrativas preenchidas tem cobertura anterior a 140%.
- Capturas Flutter Web usam modo demonstração e texto padrão. Elas verificam composição e ausência de exceções no navegador. Não validam a API real, o teclado nativo, o seletor nativo de arquivo ou fidelidade pixel a pixel.
- O roteiro de [homologação visual](homologacao-visual.md) permanece necessário em aparelho com a API estável, principalmente para solicitação, chat, pedidos profissionais, documentos e listas administrativas autenticadas.
