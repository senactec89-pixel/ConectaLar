# Acabamento visual isolado — 11/10/2026

Referências: `Prototipo 2.pdf` e `ConectaLar_Telas_Individuais_Cliente_Profissional.pdf` disponíveis no ambiente. Auditoria aplicada à disponibilidade, endereços, busca e favoritos, respeitando a divisão de arquivos da equipe.

## Ajustes e commits

| Etapa | Problema observado e ajuste | Commit |
| --- | --- | --- |
| Identidade desktop | Nome técnico da janela substituído por ConectaLar no Linux e Windows. | `bdcab42` |
| Disponibilidade | Modal apresentava overflow horizontal de 158 px no teste em 360 px/texto 200%. Acrescentados seletor que respeita a largura, scroll, título e orientação; aviso e cards ganharam hierarquia visual. | `755813d` |
| Endereços | Texto do endereço tinha 124 px de largura em 360 px. Ações passaram para baixo do texto, com rótulos, tamanho mínimo de 48 px e quebra de linha. | `697aadb` |
| Busca | Faixa de categorias rolável aproxima a disposição do protótipo; cabeçalho de resultados permite quebra de linha com fonte ampliada. Seleção, busca e limpeza dos filtros preservadas. | `b1f13ce` |
| Favoritos | Identificação de profissionais, quantidade de salvos e coração com alvo de toque de 48×48 px e fundo vermelho claro. | `f3ccc0e` |
| Categoria ativa | Nome da categoria selecionada permanece explícito, inclusive quando recebida da Home e fora da parte visível da faixa. | `075a385` |

Os commits remotos de diagnóstico, documentação, macOS e metadados Windows foram integrados em `39b8d9a`, sem conflitos. A exclusão local de `docs/relatorio-conectalar-2026-10-11.pdf` permaneceu fora dos commits.

## Capturas

As capturas mostram o aplicativo Flutter Web em Chrome headless, navegando pela interface de demonstração. Os dados são fictícios e a faixa DEMONSTRAÇÃO permanece visível. Estas capturas registram aparência; não comprovam os fluxos com a API real.

| Tela | 360 px | 390 px | 412 px |
| --- | --- | --- | --- |
| Disponibilidade | [Captura](disponibilidade-360.png) | [Captura](disponibilidade-390.png) | [Captura](disponibilidade-412.png) |
| Modal de horário | [Captura](disponibilidade-modal-viewport-reduzido-360.png) | [Captura](disponibilidade-modal-viewport-reduzido-390.png) | [Captura](disponibilidade-modal-viewport-reduzido-412.png) |
| Endereços | [Captura](enderecos-360.png) | [Captura](enderecos-390.png) | [Captura](enderecos-412.png) |
| Busca | [Captura](busca-360.png) | [Captura](busca-390.png) | [Captura](busca-412.png) |
| Busca com categoria ativa | [Captura](busca-categoria-360.png) | [Captura](busca-categoria-390.png) | [Captura](busca-categoria-412.png) |
| Favoritos | [Captura](favoritos-360.png) | [Captura](favoritos-390.png) | [Captura](favoritos-412.png) |

Altura das capturas comuns: 844 px lógicos, escala de dispositivo 1. O modal foi registrado com campo Início focado e viewport de 484 px: isso representa espaço reduzido, não um teclado nativo real. Texto ampliado e espaço de teclado foram verificados também em testes de widgets.

Disponibilidade e modal foram capturados após seu ajuste específico; o arquivo dessa tela permaneceu igual nas etapas seguintes. As telas de cliente foram capturadas depois da integração dos commits remotos e do ajuste de categoria ativa.

## Verificações

| Cobertura visual | Verificação automatizada nas três larguras |
| --- | --- |
| Disponibilidade | Lista, modal, texto 200%, altura 640 px, espaço de teclado 300 px, acesso ao botão por toque e adição à lista local. |
| Endereços | Largura de leitura, texto 200%, ações com mínimo de 48 px e abertura do formulário com os dados existentes. |
| Busca preenchida | Texto 140%, teclado, filtro por bairro, limpeza e acesso a categoria no fim da faixa. |
| Busca vazia/categoria recebida da Home | Texto 200%, contagem, orientação e indicação da categoria ativa. |
| Favoritos preenchido | Alvo de toque, mensagem de falha ao remover e texto 140%. |
| Favoritos vazio | Quantidade e orientação com texto 200%. |

- `flutter analyze --no-pub`: aprovado, sem problemas (4,0 s).
- `flutter test --no-pub --concurrency=2`: suíte completa aprovada com 81 testes após a integração dos commits remotos. A etapa anterior passou com 80 testes.
- Compilação debug Linux: aprovada; janela aberta e título ConectaLar conferido.
- Compilação Windows: não executada neste ambiente Linux.
- Compilações debug web dos modos profissional e cliente: aprovadas. Os seis conjuntos de capturas em 360, 390 e 412 px registraram zero exceções de execução e zero erros de console. Avisos de viewport e GPU estão resumidos em `resumo-navegador.json`.

## Pendências da auditoria

O teste de lista preenchida com texto 200% revelou overflows de 30 e 29 px no selo e na linha de ações de `lib/widgets/profissional_card.dart`. Esse componente compartilhado permanece reservado até confirmar a divisão com o colega. As verificações preenchidas de Busca/Favoritos cobrem 140%; os controles, cabeçalhos e estados vazios cobrem 200% conforme a tabela. Não há confirmação de suporte a 200% para os cards preenchidos.

Na tela Meus dados, ainda há oportunidades locais: permitir múltiplas linhas no texto de apoio do e-mail (`lib/screens/perfil/editar_dados_page.dart`) e tornar seu estado de erro rolável em alturas pequenas. Esses ajustes foram registrados para uma próxima etapa; esse arquivo permaneceu igual nesta entrega.

O acabamento visual das listas administrativas autenticadas e das telas de integração deve ser retomado com a equipe depois da estabilização do fluxo com API/banco. O roteiro de homologação do colega está em `docs/homologacao-visual.md`; este registro apresenta somente as evidências destes ajustes.
