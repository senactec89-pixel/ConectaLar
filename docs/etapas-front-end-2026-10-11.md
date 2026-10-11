# Etapas de front-end — 11/10/2026

Execução autorizada em etapas sequenciais, com análise, verificações e commit/push ao concluir cada etapa. Base inicial: `f2acbe9`, sincronizada por `git pull origin main`. Backend, banco, migrations e OpenAPI ficam fora deste trabalho.

## Ordem

| Etapa | Trabalho | Situação |
| --- | --- | --- |
| 1 | Auditoria dos protótipos e responsividade | Enviada: `32bcfbc` |
| 2 | Prévia isolada das telas sem API | Verificada |
| 3 | Cadastro, leitura de termos e empresa | A executar |
| 4 | Chat: erro, nova tentativa e atualização | A executar |
| 5 | Notificações: envio, erros e retorno | A executar |
| 6 | Atualização de Meus serviços ao retornar | A executar |
| 7 | Encaminhamento após sessão expirada | A executar |
| 8 | Filtros administrativos de documentos | A executar |
| 9 | Textos e identidade da versão web | A executar |

## Etapa 1 — referências e auditoria

Referências disponíveis em `/home/rodrigo/Downloads`: `Prototipo 2.pdf` (8 páginas), `ConectaLar_Telas_Individuais_Cliente_Profissional.pdf` (14 páginas) e `ConectaLar_Telas_Restantes_Administrativo.pdf` (24 páginas). Foram extraídos texto e painéis de todas as páginas para inspeção; páginas profissionais, categorias e auditoria também foram ampliadas. O PDF orienta apresentação e não concede funcionalidades, permissões ou regras novas.

### Comparação com as telas implementadas

| Tela/grupo | Referência | Observação e encaminhamento |
| --- | --- | --- |
| Home | Principal p.1; C01 | Cabeçalho, casa circular, grade e cards presentes. Preservar a imagem já aprovada. O erro atual depende da conexão; melhorar diagnóstico e prévia na etapa 2. |
| Busca e resultados | Principal p.2; C02 | Busca por termo/bairro/categoria e cards presentes. Ordenação e comparação adicionais dependem do escopo vigente. |
| Favoritos | Principal p.3 | Favoritos de profissionais presentes. Favoritos de serviços não foram aprovados pelo desenho isolado. |
| Perfil público e solicitação | C03–C04 | Serviços/ofertas, preços, avaliações e formulário presentes. Endereço e ações seguem a API. |
| Meus serviços e detalhes | Principal p.4; C05 | Cards e agrupamentos pelos cinco estados presentes. Falta atualizar ao retornar; etapa 6. |
| Chat | Principal p.8; C06 | Contexto e balões presentes. Erro, retry e atualização na etapa 4; não criar proposta/reagendamento pelo desenho. |
| Perfil, endereço e segurança | Principal p.5; C07; R20–R21 | Opções disponíveis, formulários e logout presentes. Sessão expirada na etapa 7. Suporte, idioma, MFA e sessões concorrentes não são simulados como recursos reais. |
| Login, cadastro e recuperação | Principal p.6–7; R01–R02 | Formulários presentes. Falta leitura de termos, escolha de empresa e indicação coerente de etapas; etapa 3. E-mail fictício e textos na etapa 9. |
| Painel profissional | P01 | Hierarquia e resumo presentes; o app usa cards mais altos e aviso documental explícito. Não reproduzir números ou selo fictícios em uso real. |
| Pedidos recebidos e detalhes | P02–P03 | Cards, filtros, endereço protegido e ações presentes. Não criar novos estados “Em análise”. |
| Agenda e disponibilidade | P04 | Calendário e edição semanal presentes. A disponibilidade continua sendo a retornada pela API. |
| Serviços e perfil profissional | P05–P06 | Ofertas editáveis, preço inicial, região e navegação presentes. Fotos/galeria e categorias globais não viram novas operações pelo protótipo. |
| Documentos profissionais | P07 | Seletor, nome, status e motivo presentes; formato e 5 MB preservados. O seletor nativo exige conferência em aparelho. |
| Central e usuários administrativos | R16 e navegação do PDF | Painel, listagem, busca e tipo de conta presentes. Encontrados e corrigidos overflows de indicadores e seletor com texto ampliado. |
| Denúncias e avaliações administrativas | R03–R05 | Lista, análise e decisão presentes. Não incluir evidências/medidas que a API não fornece. |
| Categorias administrativas | R08–R09 | Busca, edição, criação e status presentes. Descrição, ícone persistido e total de serviços não fazem parte do contrato atual. |
| Auditoria administrativa | R19 | Registro já implementado, com ator/alvo/ação/data. Filtros por período/responsável dependem do contrato; não simular abrangência sobre registros não retornados. |
| Documentos administrativos | Fluxo documental existente | Lista e decisão presentes. Filtros por status na etapa 8; abertura do conteúdo privado depende de endpoint seguro do colega. |
| Demais propostas administrativas | R06–R07, R10–R15, R17–R18 | Não foram convertidas em novos módulos por referência visual; exigem escopo, API e permissões próprios. |

### Correções e verificações da primeira etapa

- Nova suíte `test/admin_visual_test.dart` abre os sete módulos administrativos com sessão e HTTP simulados exclusivamente no teste. A cobertura anterior mostrava principalmente o estado restrito/sem dados.
- Conferência de conteúdo em 360, 390 e 412 pixels, com escala de texto 1,4 e busca com teclado de 300 pixels.
- A primeira execução encontrou overflow de 10 pixels nos indicadores e de 25 pixels no seletor de tipo. Os indicadores passaram a ter altura natural e uma coluna com texto ampliado; o seletor ocupa a largura disponível.
- Nova suíte: 8 testes aprovados após a correção.
- `flutter analyze --no-pub`: sem problemas. `flutter test --no-pub`: 39 testes aprovados (31 existentes + 8 administrativos).
- Capturas anteriores de área profissional e avaliações foram confrontadas com as referências. A inspeção de código/testes não substitui homologação manual de cada fluxo em aparelho, nem certifica fidelidade pixel a pixel.

As próximas etapas mantêm dados de prévia explicitamente fictícios e não alteram autorizações do uso real.

## Etapa 2 — prévia isolada

- `CONECTALAR_DEMO=true` inicializa uma conta fictícia somente em memória. A sessão real não é lida, sobrescrita ou apagada, inclusive no logout da prévia.
- `CONECTALAR_DEMO_ROLE` seleciona `cliente`, `profissional`, `empresa` ou `administrador`. O cliente local não tem transporte de rede; somente consultas e login/logout fictícios são atendidos. Operações de salvar, aceitar, moderar ou enviar mostram aviso de que a prévia não salva dados.
- A faixa “DEMONSTRAÇÃO” identifica a versão. Acesso administrativo e papéis do uso real continuam verificando a sessão/API.
- Configurações de execução disponíveis no VS Code em `.vscode/launch.json`.
- URL padrão corrigida para desktop/web/iOS (`127.0.0.1:3012`); Android mantém o alias do emulador (`10.0.2.2:3012`). A definição explícita de URL prevalece. A API padrão sem o script Windows pode usar outra porta, como 3000; nesse caso informar a URL completa.
- Home diferencia conexão indisponível, timeout e erro genérico, com nova tentativa e scroll no estado de erro.
- A prévia preenchida revelou um botão “Aceitar” com largura infinita dentro de uma linha de pedido profissional. A largura agora é limitada pelo espaço da linha.
- Verificação: quatro papéis abriram em 390 px sem API; sessão real preservada ao iniciar e sair; uso real ainda restaura a sessão; URL explícita testada separadamente; erro/retry da Home coberto. `flutter analyze --no-pub`: sem problemas. Suíte completa: 44 testes aprovados.

Exemplo para trabalhar no Linux sem API:

```bash
flutter run -d linux --dart-define=CONECTALAR_DEMO=true --dart-define=CONECTALAR_DEMO_ROLE=administrador
```

Trocar o papel por `cliente`, `profissional` ou `empresa`. É uma prévia visual de leitura; não comprova fluxos de negócio integrados. Depois de mudar `dart-define`, reiniciar a execução completa, pois hot reload não troca essas definições.
