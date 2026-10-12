# ConectaLar — relatório do dia e análise do projeto

**Data:** 11 de outubro de 2026. Horários em America/Sao_Paulo, UTC−3.<br>
**Repositório:** [senactec89-pixel/ConectaLar](https://github.com/senactec89-pixel/ConectaLar), branch `main`.<br>
**Versão analisada:** `6b66896ccc9af709f0fecd522246040844909ef8`.<br>
**Abrangência:** trabalho registrado no Git até a coleta deste relatório; aplicativo Flutter, API NestJS, persistência, testes, documentos e configuração de entrega.

> **Nota de atualização:** este relatório técnico foi fechado no commit 6b66896. O main avançou para 0264eab, recebeu correções no fluxo do cliente e a equipe informa 90 testes Flutter aprovados. Use este arquivo como registro histórico; para o estado corrente consulte [progresso](progresso.md), [rastreabilidade](rastreabilidade.md) e os checklists de homologação. Não considere os achados específicos de código como revalidados após 6b66896 sem nova inspeção.

## 1. Resumo

O ConectaLar já tem um núcleo funcional para demonstração e desenvolvimento integrado: contas, busca, perfis, ofertas, disponibilidade, solicitações, chat, avaliações, documentos, denúncias, notificações e administração. A revisão de hoje melhorou o front-end, separou a prévia fictícia do uso real e ampliou a cobertura automatizada.

**Foram encontrados 12 commits de trabalho hoje:** três dos ajustes iniciais de fluxos e nove das etapas sequenciais de front-end. Todos constam no histórico de `origin/main`. O relatório é uma entrega documental adicional a esses 12 commits.

Última validação Flutter registrada hoje: **análise sem problemas e 73 testes aprovados**. Há evidência anterior de hoje de **9 testes da API e 10 cenários de integração com MySQL aprovados**. Esses números correspondem a execuções distintas, descritas na seção 4.

O projeto ainda precisa de homologação do app com servidor real em aparelho, complementação de algumas funcionalidades e preparação de segurança/operação para publicação. A existência de telas, endpoints e testes aprovados não comprova homologação completa nem prontidão para produção.

Para a parte de front-end, as próximas correções mais úteis são:

1. Distinguir erro de senha atual de expiração de sessão.
2. Mostrar falhas e nova tentativa nas consultas de endereços/disponibilidade da solicitação.
3. Conferir o seletor nativo e os fluxos reais em aparelho.
4. Fechar funcionalidades de comparação e caminhos administrativos após definir os detalhes de escopo/permissões.

## 2. Como a análise foi feita

- Conferência do estado local e execução de `git pull --ff-only origin main`: repositório já atualizado. A árvore estava limpa na versão analisada.
- Leitura do histórico e dos arquivos modificados hoje, dos registros de validação e das evidências de telas.
- Inspeção das rotas, serviços e telas Flutter, dos controllers/serviços da API, entidades, migrations, testes e configurações de plataforma.
- Comparação estática de métodos/caminhos dos controllers com o OpenAPI.
- Confronto com os requisitos e decisões registrados na skill ConectaLar e em `docs/`.

Esta atividade produziu documentação. As constatações novas abaixo são de inspeção de código; suas consequências ainda precisam de reprodução e testes específicos. As suítes Flutter/API não foram executadas novamente para gerar este relatório. Os resultados citados são das verificações realizadas anteriormente hoje e registradas no projeto.

Os protótipos orientam a apresentação. Funcionalidades adicionais desenhadas neles e requisitos classificados como propostas dependem de aprovação de escopo. Trabalho não enviado ao Git por outros integrantes da equipe não pode ser contabilizado a partir deste ambiente.

## 3. Tudo que foi registrado hoje

### 3.1. Commits, em ordem cronológica

| Hora | Commit | Área | Entrega |
| --- | --- | --- | --- |
| 00:44 | [`af57231`](https://github.com/senactec89-pixel/ConectaLar/commit/af57231) | API e banco de teste | Proteção de aceites concorrentes, preservação da oferta escolhida, avaliações, datas civis e contrato correspondente. |
| 00:50 | [`df45b8d`](https://github.com/senactec89-pixel/ConectaLar/commit/df45b8d) | Flutter | Permissões por participante, conta profissional/admin, avaliações recebidas, cadastro/edição e integração da oferta no pedido. |
| 00:56 | [`f2acbe9`](https://github.com/senactec89-pixel/ConectaLar/commit/f2acbe9) | Evidências | Registro dos testes, decisões, limites de agenda e capturas dos fluxos. |
| 13:13 | [`32bcfbc`](https://github.com/senactec89-pixel/ConectaLar/commit/32bcfbc) | Front-end — etapa 1 | Auditoria dos protótipos e correção de overflow administrativo. |
| 13:26 | [`1420819`](https://github.com/senactec89-pixel/ConectaLar/commit/1420819) | Front-end — etapa 2 | Prévia isolada de cliente, profissional, empresa e admin; configuração de conexão e erro da Home. |
| 13:39 | [`f5ddfc2`](https://github.com/senactec89-pixel/ConectaLar/commit/f5ddfc2) | Front-end — etapa 3 | Termos antes do aceite, cadastro de empresa e recuperação de cadastro parcialmente concluído. |
| 13:44 | [`1cf1246`](https://github.com/senactec89-pixel/ConectaLar/commit/1cf1246) | Front-end — etapa 4 | Chat com erro, nova tentativa, atualização e preservação do texto após falha. |
| 13:48 | [`67a9ee8`](https://github.com/senactec89-pixel/ConectaLar/commit/67a9ee8) | Front-end — etapa 5 | Notificações com proteção durante envio, tratamento de falhas e recarga no retorno. |
| 13:51 | [`5cf520a`](https://github.com/senactec89-pixel/ConectaLar/commit/5cf520a) | Front-end — etapa 6 | Meus serviços atualizado ao retornar dos detalhes, preservando o filtro. |
| 13:56 | [`f12b8ac`](https://github.com/senactec89-pixel/ConectaLar/commit/f12b8ac) | Front-end — etapa 7 | Encaminhamento ao login e limpeza local após expiração de sessão. |
| 14:00 | [`b386db3`](https://github.com/senactec89-pixel/ConectaLar/commit/b386db3) | Front-end — etapa 8 | Filtros de documentos administrativos por status. |
| 14:25 | [`6b66896`](https://github.com/senactec89-pixel/ConectaLar/commit/6b66896) | Front-end — etapa 9 | Textos, identidade web, estados com scroll, fonte de ícones e nove capturas mobile. |

Os commits `4229ac8`, `c2cad44`, `ec40db5` e `35be08f` pertencem a **10/10/2026** no fuso considerado. São antecedentes do trabalho e não entram na contagem do dia 11.

### 3.2. Ajustes dos seis fluxos, no início do dia

- **Uso real e demonstração:** Home e busca passaram a apresentar erro quando a API falha, sem inserir profissionais fictícios como substituição silenciosa. Rotas privadas verificam sessão e papel.
- **Permissões nas solicitações:** aceitar/recusar aparecem para o profissional participante; cancelar/concluir para o cliente participante, conforme o estado. A autorização permanece na API.
- **Conta profissional/admin:** configurações usam os dados da sessão e os caminhos existentes de segurança/notificações/logout, evitando consultar um endpoint exclusivo de cliente.
- **Agenda:** endereço lido pelos campos atuais do contrato. Transações e bloqueios no servidor protegem transições e aceites no mesmo dia/horário inicial. Atualizações simultâneas de disponibilidade não misturam intervalos.
- **Avaliações:** profissional avalia cliente após conclusão; indicador individual identifica avaliação já enviada. Perfil público e área profissional exibem avaliações aprovadas, média e quantidade.
- **Cadastro e ofertas:** edição preenchida com os dados existentes, validação de preço, categorias pelo nome, continuação para serviços e preservação dos IDs das ofertas. O pedido registra oferta, nome e preço; edição posterior da oferta preserva o nome registrado no atendimento.
- **Persistência/contrato:** correção do tratamento de datas MySQL `DATE`, migration de vínculo/nome de oferta e índices de agenda, atualização do OpenAPI e testes de concorrência.

A migration foi aplicada em bancos temporários de teste. Cada ambiente integrado da equipe ainda precisa conferir e aplicar as migrations pendentes no seu próprio banco de desenvolvimento. Registro completo: [ajustes dos fluxos](ajustes-fluxos-2026-10-11.md).

### 3.3. Nove etapas sequenciais de front-end

| Etapa | O que mudou | Resultado da verificação ao concluir |
| --- | --- | --- |
| 1 — Visual | Leitura dos três PDFs, auditoria por grupo de telas e testes administrativos com dados. Indicadores passaram a usar altura natural; seletor de tipo passou a ocupar a largura disponível. | Análise limpa; 39 testes. Corrigidos overflows encontrados de 10 e 25 px. |
| 2 — Prévia | Cliente HTTP local sem transporte de rede, quatro papéis, sessão somente em memória e faixa DEMONSTRAÇÃO. A sessão real fica preservada. URL padrão adequada ao sistema e mensagens de conexão/timeout na Home. Corrigida largura do botão Aceitar. | Análise limpa; 44 testes. Quatro papéis abertos sem API; URL explícita verificada separadamente. |
| 3 — Cadastro | Tela pública de termos com versão/seções/retry; leitura anterior ao aceite; escolha de empresa. Se a conta já foi criada e o aceite falha, Concluir cadastro repete somente o restante. | Análise limpa; 47 testes. |
| 4 — Chat | Atualizar conversa, gesto de atualização, erro com Tentar novamente, indicação de operação e bloqueio de ações simultâneas. Falha de envio preserva a mensagem digitada. | Análise limpa; 50 testes. |
| 5 — Notificações | Falhas ao marcar uma/todas como lidas mostram aviso. Lista preservada, ações bloqueadas durante envio e recarga após voltar dos detalhes/documentos. | Análise limpa; 53 testes. |
| 6 — Meus serviços | Navegação aguardada e consulta renovada no retorno, sem perder o filtro escolhido. | Análise limpa; 55 testes. |
| 7 — Sessão | Tratamento global de 401 autenticado, limpeza da persistência e login sem voltar à pilha privada. Guardas para respostas antigas e simultâneas; 403 preserva sessão. | Análise limpa; 59 testes. Há uma interação adicional com troca de senha a revisar, descrita em F01. |
| 8 — Admin/documentos | Pendentes, Aprovados, Rejeitados e Todos usando o parâmetro existente. Filtro visível no erro/carregamento, retry mantendo seleção e detalhes com status/motivo. | Análise limpa; 61 testes. |
| 9 — Acabamento | Login sem e-mail fictício; textos padronizados; nome, descrição, idioma e cores web. Scroll em erro/vazio. Inclusão da fonte CupertinoIcons e capturas de três áreas nas três larguras. | Análise limpa; 73 testes após a dependência; builds web de prévia concluídos. |

As nove etapas acrescentaram **42 testes** à base de 31. Cada etapa foi verificada e enviada antes da seguinte. O intervalo `f2acbe9..6b66896` não modifica `apps/api`, `backend` ou `database`; a mudança de backend de hoje pertence ao trabalho inicial `af57231`.

### 3.4. Telas e componentes trabalhados

- Home e busca; acesso, cadastro, termos e recuperação de senha.
- Perfil/configurações, dados e endereços do cliente.
- Área profissional, pedidos, agenda, disponibilidade, cadastro/edição, serviços, perfil e avaliações recebidas.
- Solicitar serviço, detalhes e Meus serviços.
- Chat/conversa e notificações.
- Central administrativa, usuários, documentos, denúncias, avaliações, categorias e auditoria.
- Proteção de rotas, serviços de sessão/API, estados visuais reutilizáveis e metadados web.

Nem toda tela recebeu uma reconstrução de layout: parte do trabalho foi de integração, textos, estados e comportamento no retorno. O seletor nativo já existia antes dos commits de hoje e foi preservado/revisado. A imagem da casa e a altura do cabeçalho aprovado foram preservadas nas nove etapas.

## 4. Verificações e evidências

| Verificação | Resultado registrado | Alcance |
| --- | --- | --- |
| `flutter analyze --no-pub` ao final | Sem problemas. | Análise estática do Flutter na entrega `6b66896`. |
| `flutter test --no-pub` ao final | 73 testes aprovados. | Widgets/serviços com sessões e HTTP simulados; inclui navegação, papéis, estados, concorrência de ações da UI e responsividade. |
| API `npm run typecheck` e `npm test`, no início do dia | Aprovados; 9 testes padrão. | Saúde/configuração, hash/token e verificações de contrato/código; parte da suíte inspeciona texto compilado, não exercita banco. |
| API `npm run test:integration`, no início do dia | 10 cenários aprovados; relatório Node inclui também o grupo, totalizando 11 resultados. | HTTP real e MySQL descartável: ofertas, endereço/permissões, aceites concorrentes, disponibilidade, avaliações/moderação e logout. |
| Migrations, no início do dia | 15 aplicadas; última revertida e reaplicada em outro banco descartável. | Evidência de teste local; não comprova atualização de todos os bancos da equipe. |
| Compilações web | Build web inicial dos fluxos e prévias de cliente/profissional/admin concluídos. | A falta da fonte Cupertino foi corrigida; os testes Flutter foram repetidos depois. |
| Capturas finais | 9 imagens: Home, profissional e admin em 360/390/412 px. | Flutter Web no Chrome, altura 844, DPR 1, dados fictícios e texto padrão. |
| Texto ampliado e teclado | Cobertos por testes de widgets em 360/390/412 px, escala 1,4; estados comuns também em 1,6 e altura reduzida. | Não equivale a certificação de todos os aparelhos, orientação horizontal ou leitor de tela. |
| Logs das capturas | Sem erros/exceções do app registrados. | Há avisos de desempenho WebGL e viewport do ambiente de captura. |

No roteiro anterior de 10/10 há validação HTTP de upload real, chat, denúncias e administração com MySQL. Esse registro é separado dos testes de hoje e do clique manual no app.

**Limites:** não há homologação recente de todos os cliques do Flutter contra a API real em aparelho. O seletor nativo do sistema operacional continua exigindo conferência manual. A suíte de integração da API é ignorada se suas três variáveis de ambiente não estiverem configuradas; um comando sem cenários executados não comprova integração.

Fontes: [fluxos do dia](ajustes-fluxos-2026-10-11.md), [etapas Flutter](etapas-front-end-2026-10-11.md), [checklist integrado anterior](checklist-demo.md) e [teste de integração](../apps/api/test/integration/fluxos.test.mjs).

### Capturas para consulta

| Área | 360 px | 390 px | 412 px |
| --- | --- | --- | --- |
| Home | [Imagem](evidencias/front-end-2026-10-11/home-360.png) | [Imagem](evidencias/front-end-2026-10-11/home-390.png) | [Imagem](evidencias/front-end-2026-10-11/home-412.png) |
| Profissional | [Imagem](evidencias/front-end-2026-10-11/profissional-360.png) | [Imagem](evidencias/front-end-2026-10-11/profissional-390.png) | [Imagem](evidencias/front-end-2026-10-11/profissional-412.png) |
| Admin | [Imagem](evidencias/front-end-2026-10-11/admin-360.png) | [Imagem](evidencias/front-end-2026-10-11/admin-390.png) | [Imagem](evidencias/front-end-2026-10-11/admin-412.png) |

Método de captura, reprodução e limites: [README das evidências](evidencias/front-end-2026-10-11/README.md). Há mais cinco capturas dos fluxos iniciais em [evidências de integração](evidencias/fluxos-2026-10-11/).

## 5. Arquitetura e estado atual

O caminho atual é **Flutter → API REST NestJS/TypeScript → MySQL, com TypeORM**. O PHP em `backend/` e o SQL legado são históricos; não representam a API usada pelos serviços atuais do aplicativo.

| Componente | Inventário encontrado | Observação |
| --- | --- | --- |
| Flutter | 26 arquivos de tela e 34 rotas registradas. | Um arquivo pode conter várias telas, como os módulos profissional e admin. |
| API | 16 controllers e 71 operações HTTP. | Negócio depende de configuração de banco e autenticação antes da inicialização. |
| OpenAPI | 71 operações HTTP. | Métodos/caminhos coincidem com os controllers na comparação estática. Isso não valida todos os schemas/respostas/permissões. |
| Persistência | 17 entidades e 15 migrations. | `synchronize: false` e `migrationsRun: false`; migrations explícitas. |
| Testes Flutter | 11 arquivos `*test.dart`. | Última execução documentada: 73 testes. |
| Testes API | 5 arquivos `*test.mjs`, incluindo integração. | Suíte padrão e suíte com MySQL têm requisitos e alcances diferentes. |
| Preparação de demonstração | Seed e coleção Postman versionados. | [Guia Postman](postman-demo.md) e [coleção](../apps/api/postman/ConectaLar%20Demo.postman_collection.json). |
| Prévia visual | Quatro papéis, identificação de demonstração, sessão em memória e cliente local. | Consultas fictícias; a prévia não comprova gravações no servidor. |

### Situação funcional por domínio

“Implementado” nesta tabela significa que há código/rota correspondente. A homologação permanece limitada às evidências da seção 4.

| Área e requisitos | Situação atual | O que ainda precisa fechar |
| --- | --- | --- |
| Conta/acesso — RF001–RF002 | Cadastro de cliente/autônomo/empresa, login por e-mail, logout, senha e reação a 401 implementados. | Recuperação com envio real, distinção do 401 na troca de senha, política de sessões e login por telefone decidido parcialmente. |
| Cliente/favoritos — RF003, RF010 | Dados do cliente, endereços e favoritos de profissionais implementados. | Homologação das alterações e indicação visual persistente do favorito no perfil público. |
| Prestador/ofertas — RF004–RF005 | Perfil, região, ofertas, preços, edição e cadastro de empresa implementados. | Empresa atua como prestador único; equipe, executores e capacidade dependem de P12. |
| Categorias — RF006 | Criar, editar e ativar/desativar na API e no Flutter admin. | Detalhes adicionais de taxonomia/ícone/descrição dependem de definição e contrato. |
| Busca/perfil — RF007–RF008 | Consulta por termo, categoria e bairro, perfil público e avaliações aprovadas. | Escala da busca, atualização dos dados do perfil e cobertura territorial final. |
| Comparação — RF009 | Não foi localizado fluxo dedicado de comparar perfis no Flutter. | Definir critérios de P16 e implementar comparação. O requisito base é preservado. |
| Disponibilidade/agendamento — RF011, RF015 | Intervalos semanais, agenda mensal e aceite válido gerando `aceita_agendada`. | Duração, sobreposição e capacidade empresarial pendentes de P06/P12. |
| Solicitações — RF012–RF014, RF018–RF019, RF030 | Criar, consultar, aceitar, recusar, cancelar e concluir; cinco estados oficiais e bloqueios de concorrência. | Prazo de cancelamento, repetição de criação após resultado incerto e histórico das transições. |
| Endereço protegido — RF017 | API oculta do profissional antes do aceite; dono/admin têm acesso autorizado. Profissional vinculado acessa em aceito/concluído. | Snapshot, alterações posteriores, retenção e acesso após encerramento/cancelamento. |
| Chat — RF016 | Mensagens por solicitação, vínculo de participantes, envio/consulta e atualização manual no Flutter. | UX em atendimento encerrado, paginação e política de continuidade. Tempo real/anexos não entram automaticamente no escopo. |
| Avaliações — RF020–RF021, RF026 | Avaliação dos dois participantes após conclusão, unicidade, moderação e média/lista aprovadas do prestador. | Administração consulta somente pendentes; reconsulta de decisões anteriores depende de complemento do contrato. |
| Documentos/selo — RF022–RF023 | Seleção nativa PDF/JPEG/PNG até 5 MB, Base64, storage privado local, status e aprovação/rejeição. | Abertura segura do conteúdo pelo admin, política de selo com vários documentos e preparação do storage. |
| Denúncias — RF024 | Registro vinculado ao atendimento, listagem e decisão administrativa com auditoria. | Homologar contestação/medidas e permissões conforme P11; denúncia não pune automaticamente. |
| Usuários/admin — RF025 | Listar/detalhar contas, mudar status e auditar; API cria administradores. | Flutter não oferece criação de administrador; MFA e política da conta principal ainda pendentes. |
| Catálogo — RF027 | Categorias globais e ofertas do prestador disponíveis. | Não há módulo independente de catálogo global de serviços; fechar P03 e a abrangência do requisito. |
| Notificações — RF028 | Eventos internos persistidos, consulta, resumo e marcação de leitura. | Tratamento resiliente de falhas na criação de avisos; canais/preferências dependem de P14. |
| Histórico — RF029 | API de histórico e filtro Histórico em Meus serviços. | Admin não tem tela dedicada ao endpoint de histórico; paginação e trilha de mudanças precisam definição. |
| Termos/privacidade | Tela pública, versão, consulta/aceite e registro no banco. | Conteúdo final, contato de suporte/privacidade e política de retenção/publicação. |

## 6. Pendências de front-end

### F01 — Alta: senha incorreta pode encerrar uma sessão válida

**Evidência:** [ApiService, linha 93](../lib/services/api_service.dart#L93) trata como expiração qualquer 401 autenticado, exceto login/cadastro/logout. A API retorna 401 quando a senha atual informada está errada em [AuthService, linha 178](../apps/api/src/auth/auth.service.ts#L178). A troca de senha usa esse caminho em [SegurancaPage, linha 36](../lib/screens/perfil/seguranca_page.dart#L36).

**Consequência indicada pelo código:** errar a senha atual pode limpar a sessão e levar ao login com aviso de expiração. O token pode continuar válido no servidor. É um caso adicional não coberto pelas quatro regressões de expiração de hoje.

**Encaminhamento:** distinguir falha da senha e token inválido, preservando o encaminhamento no segundo caso. Como o filtro atual não devolve um código público específico para esse erro, alinhar com o colega uma resposta distinguível ou uma revalidação usando contrato existente. Não ignorar indiscriminadamente todos os 401 da troca de senha.

**Conclusão da etapa futura:** senha errada mantém a sessão e mostra erro apropriado; token expirado continua levando ao login; senha alterada exige nova entrada.

### F02 — Alta: falhas de endereço/disponibilidade são ocultadas

**Evidência:** [SolicitarServicoPage, linha 63](../lib/screens/servicos/solicitar_servico_page.dart#L63) e linha 90 capturam qualquer erro de consulta e retornam lista vazia. Os builders escondem as seções quando não há itens.

**Efeito:** falha de rede fica visualmente igual a ausência de endereços/horários. O formulário pode continuar sem que o usuário perceba que dados não carregaram.

**Encaminhamento somente Flutter:** estados de carregamento, erro/retry e vazio separados nessas seções, preservando os valores já escolhidos e a validação final da API. Homologar timeout, falha parcial e retorno de login.

### F03 — Alta: homologar em aparelho e concluir a revisão visual

- Conferir os fluxos reais de cliente, autônomo, empresa e admin com o servidor/banco da equipe atualizado.
- Abrir o seletor nativo, cancelar seleção e enviar PDF/JPEG/PNG; conferir arquivo acima de 5 MB, inválido e vazio.
- Conferir os diálogos de moderação/salvamento, teclado, textos longos, fonte ampliada, foco, leitor de tela e orientação prevista.
- Complementar as capturas das demais telas/listas administrativas: as nove imagens finais cobrem Home e dois painéis, não todos os estados de todas as telas.

### F04 — Média: completar funcionalidades e caminhos já identificados

| Item | Evidência/limite | Dependência |
| --- | --- | --- |
| Comparar profissionais | Não há rota/tela dedicada em [rotas Flutter](../lib/app/routes.dart). | P16 define critérios; RF009 permanece no escopo base. |
| Criar administrador | API tem `POST /admin/usuarios/administradores`; [AdminService](../lib/services/admin_service.dart) e painel não implementam criação. | Política de conta principal/permissões e MFA, P15. |
| Histórico administrativo | Endpoint `GET /admin/historico/atendimentos` existe; não há módulo correspondente no Flutter admin. | Confirmar abrangência da tela e paginação. |
| Favorito no perfil público | [PerfilProfissionalPage, linha 92](../lib/screens/profissional/perfil_profissional_page.dart#L92) calcula o ícone de favorito pelo mock apenas na demo; uso real salva, mas não reflete a marcação existente no ícone. | Consulta de favoritos já disponível; mudança pode ficar no Flutter. |
| Perfil público atualizado | A tela recebe o objeto da lista pela navegação; não faz uma consulta dedicada ao perfil na abertura. | Reconsultar o endpoint existente; preservar erro/retry e permissões. |
| Chat encerrado | [ConversaPage, linha 192](../lib/screens/chat/conversa_page.dart#L192) habilita envio conforme ocupação; a API aceita mensagem só em aguardando/aceito. | Desabilitar envio/orientar a leitura nos demais estados, conforme contrato atual. |
| Textos ao usuário | Filtro genérico da API retorna vários erros em inglês; alguns campos preservam termos técnicos. | Flutter pode mapear avisos conhecidos; mensagens/códigos públicos exigem coordenação. |

### F05 — Antes da publicação: sessão e identidade das plataformas

- O token de uso real é persistido em JSON via `SharedPreferences`, em [AuthService](../lib/services/auth_service.dart). Definir armazenamento/expiração conforme cada plataforma e a política de sessões; não há mecanismo de armazenamento seguro dedicado no código atual.
- Android ainda usa `com.example.conectarlar_app` e a configuração release assina com a chave debug em [build.gradle.kts](../android/app/build.gradle.kts).
- Ícone Android continua com a marca padrão Flutter. Títulos Linux/Windows e identificação macOS ainda usam o nome técnico do template.
- Identificadores, ícones finais, assinatura e configuração HTTPS precisam de uma etapa de publicação própria. O HTTP local do Android está permitido no manifesto de debug.
- iOS depende do ambiente macOS, assinatura e aparelho registrados como pendentes; builds web não comprovam funcionamento iOS.

## 7. Pontos do backend para encaminhar ao colega

Esta seção é análise. As alterações de implementação dos próximos passos de front-end continuam separadas do trabalho de backend.

| ID/prioridade | Achado com evidência | Trabalho recomendado |
| --- | --- | --- |
| B01 — Alta | **Admin não consegue examinar o arquivo:** [controller de verificação](../apps/api/src/verificacao/verificacao.controller.ts) tem envio/listagem/análise, sem endpoint para obter o conteúdo. O diálogo Flutter mostra nome/referência e botões de decisão. | Acesso autenticado e restrito ao conteúdo, com registro de acesso; depois integrar visualização no Flutter. Aprovação de status sozinha não fecha a análise documental real. |
| B02 — Alta | **Selo com múltiplos documentos:** [VerificacaoService, linha 142](../apps/api/src/verificacao/verificacao.service.ts#L142) define `verificado` pelo resultado do documento recém-analisado, sem considerar o conjunto. | Definir P10 e testar combinações de documento aprovado/rejeitado/pendente, reenvio e decisões simultâneas. O resultado pode depender da ordem da última análise. |
| B03 — Alta | **Cancelamento sem antecedência:** [SolicitacoesService, linha 240](../apps/api/src/solicitacoes/solicitacoes.service.ts#L240) verifica participante e estados, sem validar a antecedência de 24 horas documentada em RB12. | Alinhar regra vigente e exceções P08; testar limites de data/fuso. A proteção deve estar na API, com mensagem correspondente no Flutter. |
| B04 — Alta | **Recuperação sem entrega real:** [AuthService, linha 108](../apps/api/src/auth/auth.service.ts#L108) gera/grava prova; não envia e-mail/SMS. `devToken` só é devolvido com configuração explícita fora de produção. | Integrar canal verificado e testar entrega, validade, abuso e resposta sem revelar existência de conta. |
| B05 — Alta | **Prova de recuperação não é consumida atomicamente:** [AuthService, linha 137](../apps/api/src/auth/auth.service.ts#L137) consulta prova, grava senha e só depois marca provas como usadas, sem transação/bloqueio. | Testar e corrigir duas confirmações simultâneas e falha entre gravações. Risco de concorrência indicado pelo código, ainda não reproduzido nesta análise. |
| B06 — Alta para publicar | **MFA administrativo ausente:** autenticação usa e-mail/senha/token; não há desafio, cadastro nem validação MFA. | Implementar conforme decisão de contas administrativas individuais; integrar tela após contrato e testes. |
| B07 — Alta para publicar | **Tipo real de arquivo não verificado:** [VerificacaoService, linha 234](../apps/api/src/verificacao/verificacao.service.ts#L234) valida Base64/tamanho e MIME informado, sem assinatura/conteúdo ou antivírus. Ainda aceita referência manual pelo contrato. | Validar conteúdo, definir tratamento do caminho legado de referência e preparar storage privado, retenção, backup e acesso restrito. |
| B08 — Alta para publicar | **Identificação do rate limit confia em header recebido:** [app.factory.ts, linha 95](../apps/api/src/app.factory.ts#L95) usa diretamente `x-forwarded-for`. | Definir proxies confiáveis e remover/sobrescrever cabeçalhos na borda. Sem isso, a proteção depende de infraestrutura que não está demonstrada no repositório. |
| B09 — Média/alta | **Auditoria e decisão em gravações separadas:** documentos, categorias, usuários e avaliações gravam a mudança antes da auditoria. Em categorias, qualquer falha posterior vira mensagem de categoria existente. | Garantir atomicidade ou mecanismo durável para decisão/auditoria. Testar falha intermediária e retorno coerente ao usuário. |
| B10 — Média | **Paginação incompleta:** busca carrega perfis e filtra em memória; solicitações/chat carregam listas inteiras. Auditoria limita aos 100 mais recentes; documentos admin a 100, notificações a 50. | Definir contrato de paginação/ordenação, levar filtros para consulta e integrar carregamento progressivo no Flutter. |
| B11 — Dependente de P06/P12 | **Conflito de agenda por horário inicial:** há bloqueio concorrente real, mas ele compara mesma data/hora inicial. | Definir duração, intervalo, fuso, capacidade/executor antes de expandir bloqueios. Não declarar ausência de proteção: a proteção atual já existe. |
| B12 — Dependente de P04/P13 | **Endereço é referência mutável:** pedido mantém `enderecoId` e consulta a entidade atual, sem snapshot. Profissional pode acessar endereço também em conclusão confirmada. | Definir histórico, alterações após pedido, retenção e acesso posterior; preservar a proteção já aplicada antes do aceite. |
| B13 — Dependente de P02/P15 | **Logout invalida tokens da conta:** incremento de `tokenVersion` invalida todas as sessões com a versão anterior, não só um dispositivo. Criação admin não distingue conta principal. | Definir sessões simultâneas, revogação por dispositivo e permissões da conta principal; testar revogação e reativação de conta. |
| B14 — Média | **Avisos podem ser perdidos:** helpers de solicitação/chat/documentos ignoram falha de criação de notificação; não há fila/reenvio persistente. | Garantir recuperação de avisos sem alterar a transição já gravada; definir canais e preferências P14. |
| B15 — Média/dependente de política | **Rastreabilidade de atendimentos limitada:** entidade guarda estado e timestamps atuais; auditoria existente é administrativa, sem uma tabela dedicada de todas as transições do pedido. | Fechar abrangência de RF030/RNF014/RB17 e registrar ator, instante e mudança quando exigido. |
| B16 — Alta | **Oferta com preço a combinar:** [SolicitacoesService, linha 134](../apps/api/src/solicitacoes/solicitacoes.service.ts#L134) usa `oferta?.precoInicial ?? profissional.precoInicial`. Quando a oferta escolhida tem preço nulo e o perfil tem preço, o pedido recebe o preço do perfil. | Preservar o nulo da oferta escolhida; testar oferta sem preço em perfil com preço e conferir o valor exibido no Flutter. Caso adicional identificado no código, sem reprodução nova nesta análise. |

Pontos que **já existem** e não devem voltar à lista como ausentes: logout real, endpoint de agenda, upload Base64, filtro documental por status, categorias administrativas, auditoria administrativa, avaliações dos participantes, média aprovada e endereço autorizado.

## 8. Operação e publicação do projeto inteiro

| Área | Código/base existente | O que falta comprovar ou preparar |
| --- | --- | --- |
| Segurança HTTP | CORS por lista, headers, rate limit em memória e filtro seguro de erros. | HTTPS público, origens finais, proxies confiáveis, limites por abuso e eventual distribuição entre instâncias. |
| Prontidão | `/health` responde estado genérico; módulos de negócio são condicionais à configuração de banco/token. | Verificação de prontidão do banco/rotas. Saúde HTTP positiva pode existir sem rotas de negócio montadas. |
| Logs/monitoramento | Eventos estruturados sem corpo/header/token nas mensagens atuais. | Coleta, métricas, alertas, retenção e acompanhamento operacional. |
| Backup/restauração | Procedimento recomendado em [operação](operacao-producao.md). | Agendamento, armazenamento separado, responsáveis e evidência de restauração; incluir documentos. |
| CI/CD | Scripts locais de build, testes, migrations e seed. | Não foi localizada configuração versionada de pipeline/deploy; documentar ambiente e execução automática. Não foi auditada infraestrutura externa ao Git. |
| Homologação | Testes Flutter, API e alguns fluxos HTTP com MySQL. | Matriz completa de cenários reais no app, dados/controladores múltiplos, testes negativos e resultados reprodutíveis no ambiente final. |
| Desempenho | Estrutura e índices básicos; nenhum ensaio de carga registrado nesta revisão. | Metas aprovadas, medição de latência/carga, volume de chat/histórico e armazenamento. |
| Privacidade/operação | Avisos, autorizações e aceite de termos implementados. | Retenção/descarte, atendimento a titulares, canal de privacidade/suporte e conteúdo final revisado. Não há comprovação de conformidade integral apenas pelo código. |
| Publicação mobile | Projetos Android/iOS e demais plataformas presentes. | IDs finais, assinatura, artefatos release, dispositivos, contas das lojas e ambiente macOS para iOS. |

## 9. Documentação que precisa ser reconciliada

| Documento | Divergência atual |
| --- | --- |
| [README principal](../README.md) | Ainda orienta PHP/XAMPP, endpoints 501 e funcionalidades por implementar; há caracteres NUL no trecho final. Contradiz a API NestJS e os serviços atuais. |
| [Rastreabilidade](rastreabilidade.md) | Descreve negócio como não implementado e OpenAPI só com health. A matriz precisa apontar código, contratos e testes atuais; RF027 aparece classificado de forma inconsistente com o requisito base preservado. |
| [Segurança](seguranca.md) | Declara ausência de conexão de banco/integração como estado da fundação; precisa deixar explícita a data/fase histórica e os controles atuais. |
| [Progresso](progresso.md) | Última atualização 10/10, com 17 testes Flutter e 8 API. Não contempla as entregas e os resultados de hoje. |
| [Decisões](decisoes.md) e [pendências](pendencias.md) | Misturam registros da fundação com limites atuais; parte dos gates de modelagem/migrations e da inspeção dos PDFs já ficou para trás. Preservar histórico e indicar situação atual. |
| [README API](../apps/api/README.md) | O corpo registra vários módulos reais, mas a introdução ainda apresenta autenticação como primeiro módulo. A porta padrão 3000 precisa ser conciliada com o launcher e o default Flutter 3012. |

O código atual e as evidências datadas prevaleceram para avaliar implementação. Documentos antigos não foram usados para concluir que os módulos presentes no código estão ausentes.

## 10. Home: explicação prática da dependência do ambiente

No uso real, a Home consulta categorias e profissionais com `Future.wait`, em [AppServices](../lib/services/service_registry.dart). Se uma consulta falha, a tela mostra o estado de erro e permite tentar novamente. As mensagens ficaram mais claras hoje.

Verificações necessárias para abrir com dados reais:

1. API acessível no host/porta usados pelo dispositivo.
2. Banco/token configurados antes de iniciar a API, para montar as rotas de negócio.
3. Migrations do banco da equipe atualizadas.
4. URL Flutter correspondente ao servidor. Default desktop/web/iOS: `127.0.0.1:3012`; emulador Android: `10.0.2.2:3012`. API isolada usa 3000 por padrão; aparelho físico precisa de um host alcançável pela rede ou HTTPS.

Exemplo local, substituindo a porta pelo valor real:

```bash
flutter run --dart-define=CONECTALAR_API_BASE_URL=http://127.0.0.1:3012
```

Para trabalhar visualmente sem servidor no Linux:

```bash
flutter run -d linux --dart-define=CONECTALAR_DEMO=true --dart-define=CONECTALAR_DEMO_ROLE=cliente
```

Os papéis também podem ser `profissional`, `empresa` ou `administrador`. A prévia abre telas com dados locais identificados como fictícios. Trocar `dart-define` exige reiniciar a execução completa. A API real indisponível continuará produzindo erro no modo real; isso não é evidência isolada de falha de layout.

## 11. Sequência recomendada a partir de agora

| Ordem | Responsável | Etapa | Critério para concluir |
| --- | --- | --- | --- |
| 1 | Front-end + alinhamento API | F01: interação entre senha errada e 401. | Senha incorreta, token expirado e troca bem-sucedida com efeitos distintos e regressões específicas. |
| 2 | Front-end | F02: falhas parciais na solicitação. | Endereços e horários com carregamento/erro/retry/vazio claros, sem perder seleção. |
| 3 | Front-end | Favorito, reconsulta de perfil e chat encerrado. | Estado real consistente, uso dos endpoints existentes e mensagens adequadas. |
| 4 | Equipe | Homologação em aparelho, incluindo arquivo nativo. | Roteiro completo de cliente/autônomo/empresa/admin com resultados e capturas do ambiente real. |
| 5 | Produto + front-end/API | Comparação, catálogo, criação admin e histórico administrativo. | Escopo/permissões definidos; implementar apenas operações autorizadas pelo contrato. |
| 6 | Backend | Documentos, selo, cancelamento, recuperação e atomicidade. | Políticas definidas e testes negativos/concorrentes aprovados com banco. |
| 7 | Equipe | Atualizar documentação de entrada/rastreabilidade. | Um procedimento coerente para iniciar app/API/banco, referências datadas e resultados atuais. |
| 8 | Backend/infra + front-end de publicação | Preparação de produção. | MFA, HTTPS, storage, backup/restauração, monitoramento, pipeline, assinatura e homologação definidos e demonstrados. |

Para preservar a organização solicitada pelo usuário: uma etapa por vez, atualização do repositório antes de editar, verificação da etapa, revisão do diff e commit/push correspondente. As implementações de backend devem ficar com o responsável dessa área, com contratos combinados antes da integração Flutter.

## 12. Decisões ainda necessárias

- Duração/fuso e capacidade dos atendimentos, inclusive empresas/executores — P06/P12.
- Antecedência e exceções de cancelamento — P08.
- Documentos necessários, conjunto para obter/manter selo e reenvio — P10.
- Snapshot e acesso/retenção de endereço, documentos, chat e histórico — P04/P13.
- Conta administrativa principal, concessão/revogação de acesso, MFA e sessões — P02/P15.
- Cobertura territorial, comparação e catálogo final — P03/P05/P16.
- Canais/preferências de avisos e textos finais de publicação — P14/P18.

Google, mapas, pagamentos internos, anexos no chat, suporte/idiomas, push e funcionalidades administrativas adicionais desenhadas nos PDFs não se tornam obrigatórias pelo desenho isolado. Pagamentos internos permanecem fora do escopo aprovado; valores finais são combinados entre as partes. O chat não confirma agendamento, os cinco estados oficiais permanecem e o selo não é garantia absoluta.

**Avaliação final:** as nove etapas solicitadas de front-end foram entregues e verificadas, e o núcleo do produto já tem implementação substancial. Para concluir a demonstração integrada, a prioridade é homologar o Flutter com a API real e corrigir os casos adicionais encontrados. Para publicar o projeto inteiro, ainda é necessário fechar funcionalidades/políticas e demonstrar os controles operacionais indicados neste relatório. Não há base suficiente para atribuir um percentual de conclusão ou declarar o projeto inteiro pronto.

**Versão para leitura e impressão:** [PDF deste relatório](relatorio-conectalar-2026-10-11.pdf). O Markdown é a fonte editável; o PDF corresponde ao mesmo conteúdo, com links para os arquivos da versão analisada no GitHub.
