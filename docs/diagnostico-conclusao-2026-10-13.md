# Diagnóstico para conclusão do ConectaLar

Data: 13/10/2026. Base inicial revisada: `048abb9` (`main`); estado visual atualizado após as correções desta revisão. Esta é uma revisão de código, documentação e testes locais; não equivale à homologação em aparelho nem à certificação de segurança.

## Estado constatado

O app Flutter e a API NestJS/MySQL implementam o núcleo de cadastro, perfis, busca, ofertas, solicitações, agenda, chat, avaliações, documentos, denúncias, notificações e administração. O modo de demonstração usa dados locais; ele não comprova o comportamento da API real. O backend PHP e `database/conectalar.sql` são legados, preservados fora da API NestJS.

Parte das pendências documentadas em `docs/progresso.md`, `docs/pendencias.md` e `docs/rastreabilidade.md` foi resolvida depois do commit `0264eab` usado nesses relatórios. As rotas atuais incluem criação de administrador e histórico administrativo (`lib/app/routes.dart`); login com desafio MFA, recuperação e verificação por e-mail também têm implementação. Essas funções ainda precisam de validação integrada e políticas finais.

## Evidência obtida nesta revisão

| Verificação | Resultado | Limite |
| --- | --- | --- |
| `flutter analyze --no-pub` | Sem problemas após as correções visuais. | Análise estática não testa fluxos. |
| `flutter test --no-pub` | **146 aprovados, 0 reprovados** após as correções visuais. | Executado com Flutter 3.38.6/Dart 3.10.7 e dependências compatibilizadas localmente; não substitui integração ou aparelho. |
| `npm run typecheck` | Aprovado. | Usou o Node 18 do `PATH` para o compilador TypeScript. |
| Build TypeScript da API | Aprovado durante `npm test`. | O `npm test` não executou os testes sob Node 18 porque essa versão não interpretou o padrão `test/*.test.mjs` no Windows. |
| Testes unitários/contratuais da API | 13/13 aprovados usando Node 24.20.0 temporário: `npm exec --yes --package=node@24.20.0 -- node --test test/*.test.mjs`. | Não incluem MySQL nem os fluxos do app. |
| API + MySQL + app integrados | Não executados nesta revisão. | Não havia serviço local escutando nas portas 3012/3307. Os resultados em `docs/checklist-demo.md` são de um commit anterior. |
| Flutter Web e Android | [45 capturas Web](evidencias/estilizacao-2026-10-13/README.md) em dados fictícios; nenhum Android conectado. | O AVD `Pixel_7` existe, mas não houve homologação em aparelho físico. |

O `pubspec.yaml` e o `pubspec.lock` têm alterações locais da correção de compatibilidade de dependências feita anteriormente nesta conversa. O `git status` também mostra registradores Flutter gerados; não foram tratados como mudanças de produto nesta revisão.

## Prioridade 1: fechar os bloqueios para uma entrega demonstrável

1. **Fixar a versão suportada de Flutter e suas dependências.** O repositório chegou com `pubspec.lock` que exigia Flutter 3.44/Dart 3.12, enquanto esta máquina tem Flutter 3.38.6/Dart 3.10.7. A compatibilização local de `pubspec.yaml`/`pubspec.lock` permitiu análise limpa e 146 testes verdes, mas essas alterações ainda não foram incorporadas a um commit. Definir a versão oficial e registrar um resultado reproduzível com o mesmo lockfile.
2. **Homologar os três papéis com API e MySQL reais.** Rodar migrations em banco descartável e executar os checklists de cliente, profissional/empresa e administrador em aparelho Android real. Cobrir rede instável, endereço protegido antes do aceite, solicitações concorrentes, documentos no seletor nativo, chat, conclusão, moderação e auditoria. Os checklists em `docs/checklist-homologacao-*.md` ainda não registram execução completa.
3. **Concluir a análise segura de documentos.** O diálogo administrativo (`lib/screens/admin/admin_pages.dart`) mostra nome/referência e permite aprovar sem abrir o conteúdo. `apps/api/src/verificacao/verificacao.controller.ts` não oferece rota autenticada de leitura do arquivo. `verificacao.service.ts` escolhe a extensão pelo MIME informado pelo cliente, sem conferir os bytes, e aceita uma referência textual enviada pelo cliente. É necessário oferecer inspeção autorizada, validar o tipo real, definir retenção/armazenamento e testar acesso negado a terceiros. A regra do selo com vários documentos depende de P10.
4. **Exigir MFA na administração de forma efetiva.** `auth.service.ts` só pede o segundo fator se `mfaAtivo` já for verdadeiro; uma conta administrativa nova pode obter sessão sem MFA. Há endpoints de ativação e desafio, mas falta um fluxo de ativação no app e uma regra de obrigatoriedade que preserve uma recuperação segura da conta principal (P15).
5. **Fechar a comparação de prestadores (RF009).** A matriz de rastreabilidade registra que não há fluxo dedicado. Critérios de comparação e exibição dependem de P03/P16; após decisão, implementar app/API e teste de aceitação.

## Prioridade 2: definir regras centrais antes de declarar o produto concluído

- **Atendimentos e agenda:** P06/P08/P12 precisam definir duração, sobreposição, capacidade de empresas, fuso, cancelamento e exceções. O código já protege um aceite concorrente para mesma data/hora inicial, mas isso não resolve intervalos ou múltiplos executores. A API cancela pelos estados permitidos; a regra de antecedência de 24 horas e exceções ainda não está fechada.
- **Dados e privacidade:** P01/P04/P13 precisam fechar identidade por telefone/e-mail, acesso ao endereço após encerramento, retenção e descarte de documentos, mensagens e registros. A verificação de e-mail existe no app, mas `AuthGuard` valida token/conta ativa e não exige `emailVerificado`; decidir e aplicar a política no servidor.
- **Catálogo, cobertura e moderação:** P03/P05/P10/P11/P17 precisam definir taxonomia, regiões de lançamento, documentos necessários, política do selo, decisões sobre denúncias/avaliações e eventual contestação. Não tratar telas de protótipo como regras aprovadas.
- **Escala e integridade:** listas da API usam limites fixos de 50/100/200 sem paginação em vários módulos. Algumas mutações administrativas gravam decisão e auditoria em operações separadas; revisar atomicidade e resposta a falhas antes de ampliar o uso.

## Prioridade 3: preparar publicação e operação

- **App:** substituir armazenamento do token em `SharedPreferences` por armazenamento apropriado para credenciais; usar endpoint HTTPS de produção; escolher `applicationId` definitivo; configurar assinatura release própria, ícones finais e ensaiar atualização em aparelho. Hoje `android/app/build.gradle.kts` ainda usa `com.example.conectarlar_app` e assinatura debug no build release.
- **API e dados:** configurar e testar SMTP real, storage privado com inspeção de arquivos, backup com restauração ensaiada, observabilidade/alertas, limite de requisições adequado ao número de instâncias e procedimento de resposta a incidentes. O armazenamento documental atual é local. A URL de produção, a retenção e os avisos/termos finais dependem de decisão.
- **Entrega contínua:** criar workflow executável para Flutter e API, incluindo MySQL descartável nos testes de integração, e alinhar versões de Flutter e Node. `docs/proposta-ci-cd.md` é apenas proposta; não há workflow `.github` no repositório.
- **Documentação:** atualizar `README.md`, progresso, segurança e rastreabilidade para o commit de entrega. Relatórios antigos ainda dizem que MFA, criação de administrador e histórico administrativo não existem, embora o código atual tenha partes dessas funções. Registrar comando, data, commit, ambiente e resultado de cada homologação.
- **iOS:** somente se fizer parte da entrega pretendida; exige ambiente macOS, assinatura e validação em dispositivo.

RF031–RF042, RNF027–RNF030 e Q01–Q08 continuam propostas ou itens condicionados. Não entram automaticamente na definição de pronto. A conclusão deve ser declarada contra um escopo aprovado, com testes verdes, decisões P essenciais registradas e homologação documentada.
