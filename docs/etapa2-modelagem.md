# Etapa 2 — Auditoria e rascunho do modelo

**Status:** rascunho. Esta auditoria inicia a etapa sem tratar recomendações dos DOCX como decisões aprovadas. A Etapa 1 foi validada com instalação reproduzida pelo lockfile, typecheck, build, dois testes automatizados e smoke test HTTP local.

## Autoridade e situação das fontes

- O prompt mestre atual define Node.js/TypeScript/NestJS, MySQL Community e FCM somente para push. As referências PHP/XAMPP encontradas nos DOCX são históricas e não mudam essa stack.
- O documento funcional classifica RF001–RF030 como preservados e RF031–RF042 como propostas; suas decisões P01–P18 seguem a validar.
- O documento de qualidade classifica RNF001–RNF026 e RB01–RB18 como preservados; RNF027–RNF030, RB19–RB30 e Q01–Q08 têm situações próprias e não devem ser promovidos em bloco.
- Os PDFs foram localizados em Downloads, mas ainda precisam de inspeção visual antes de implementar administração ou fluxos que dependam deles.
- O prompt atual proíbe pagamento dentro do aplicativo; não modelar cobrança, comissão, seguro ou liquidação financeira.

## Inventário do SQL legado

`database/conectalar.sql` contém nove tabelas históricas: `usuarios`, `profissionais`, `categorias`, `profissional_categorias`, `solicitacoes`, `avaliacoes`, `favoritos`, `mensagens` e `documentos_verificacao`. O arquivo PHP correspondente é legado e não será executado nem migrado automaticamente.

Diferenças e riscos a resolver no modelo novo:

- `usuarios.email` único fixa o e-mail como identificador; P01 deixa a identificação e os campos obrigatórios a validar.
- `profissionais.preco_inicial` não representa preço inicial por oferta/serviço; taxonomia, catálogo e preço dependem de P03.
- Localização em texto livre não resolve município/bairro, cobertura ou cidades de lançamento; P05 permanece pendente.
- `solicitacoes` guarda endereço diretamente junto ao atendimento. O acesso precisa respeitar a confirmação, P04 e retenção P13.
- O `ENUM` legado de status não substitui automaticamente os cinco estados documentados nem define transições/cancelamento de P08.
- O modelo da agenda segue P06 aprovada: horário civil em `America/Sao_Paulo`, duração configurável de 1 a 1.440 minutos e sobreposição por duração; capacidade por equipes permanece em P12.
- A tabela de mensagens não decide início/encerramento, anexos, leitura ou reenvio do chat; depende de P09.
- `arquivo_url`/`foto_url` não definem armazenamento privado, autorização ou retenção de documentos e imagens; P10/P13 e a arquitetura aprovada de arquivos precisam guiar o desenho.
- Empresas, integrantes, permissões e capacidade não aparecem como modelo próprio; dependem de P12/P15.

## Mapa preliminar de domínios e decisões

| Domínio candidato | Requisitos de origem | Decisões que afetam as tabelas/relacionamentos |
| --- | --- | --- |
| Contas, perfis e sessões | RF001–RF004, RF025 | P01, P02, P15 |
| Categorias, serviços e ofertas | RF005–RF009, RF027 | P03, P16 |
| Cobertura e endereços | RF004, RF007, RF011–RF013 | P04, P05 |
| Disponibilidade e atendimentos | RF011–RF019, RF030 | P06, P07, P08 |
| Conversas e avisos | RF016, RF028, RF035, RF036, RF042 | P09, P14, P18 |
| Verificação, denúncias e administração | RF020–RF027, RF037 | P10, P11, P18 |
| Empresas e integrantes | RF040 | P12, P15 |
| Retenção, conta e histórico | RF010, RF029, RF038, RF039 | P13, P15 |
| Conclusão e avaliações | RF019–RF021 | P17 |

Este mapa não é um esquema de banco aprovado. Não inclui RF031–RF042 nem metas Q01–Q08 como escopo efetivo.

## Modelo relacional candidato

O catálogo abaixo transforma o mapa de domínios em unidades persistentes para revisão. Ele é conceitual: nomes, cardinalidades e restrições condicionais precisam ser confirmados nas decisões indicadas. Ainda não há entidade TypeORM, schema executável nem migration.

| Domínio | Entidades candidatas | Relações e integridade a validar | Gate |
| --- | --- | --- | --- |
| Identidade | `account`, `credential`, `session`, `recovery_challenge`, `account_role` | Conta possui perfis e credenciais conforme identificador escolhido; sessão e prova de recuperação pertencem à conta; papel vem de fluxo restrito. | P01, P02, P15 |
| Perfis | `customer_profile`, `provider_profile`, `organization`, `organization_membership` | Perfil é vinculado à conta; prestador pode ser autônomo ou organização; vínculo de integrante pode ser desativado sem apagar referências históricas. | P01, P12, P13, P15 |
| Catálogo | `category`, `catalog_service`, `provider_offer` | Categoria agrupa serviços; oferta associa prestador e serviço, guardando preço inicial próprio; categoria inativa não recebe oferta nova. | P03, P11, P13 |
| Cobertura e locais | `state`, `municipality`, `neighborhood`, `provider_coverage`, `saved_address`, `request_location_snapshot` | Cobertura pertence ao prestador; endereço privado pertence ao titular; solicitação referencia um local acordado sem depender de alterações posteriores no perfil. | P04, P05, P12, P13 |
| Agenda e atendimento | `availability_rule`, `schedule_block`, `service_request`, `request_state_event` | Pedido liga cliente, prestador/oferta e local; aceite grava estado e horário em operação consistente; estado atual usa somente os cinco estados documentados e eventos preservam transições autorizadas. | P04, P06, P07, P08, P12, P17 |
| Favoritos | `favorite_provider` | Relação cliente–prestador única por cliente; lista é privada e não duplica adições repetidas. | P13, P16 |
| Conversa e avisos | `conversation`, `message`, `notification`, `delivery_attempt` | Conversa liga-se ao atendimento e aos participantes; entrega é separada do evento de negócio; falha de push não altera estado. | P09, P13, P14 |
| Confiança e administração | `verification_case`, `private_file_reference`, `report`, `moderation_action`, `audit_event` | Aprovação documental e ações administrativas têm ator, instante, alvo e resultado; arquivos não ficam em URL pública; auditoria não guarda conteúdo privado desnecessário. | P10, P11, P13 |
| Avaliação | `review`, `review_moderation` | Avaliação liga autor, prestador e atendimento real; elegibilidade depende de conclusão confirmada; unicidade e edição aguardam regra final. | P11, P13, P17 |
| Avisos legais | `legal_document_version`, `user_acknowledgement` | Manifestação, quando exigida, referencia a versão realmente apresentada; não altera retroativamente registro anterior. | P18 |

### Chaves, constraints e índices candidatos

As restrições abaixo são pontos de projeto, não DDL aprovado:

- Todas as tabelas terão chave primária estável e chaves estrangeiras explícitas; formato binário, UUID ou outro identificador público segue em aberto até escolher a representação de identificadores.
- Unicidade do identificador de conta depende do método de cadastro aprovado em P01. A constraint deve ser aplicada sobre forma normalizada e protegida contra duas criações concorrentes.
- Oferta pode exigir unicidade por prestador e item de catálogo, mas duplicidade, variações e manutenção precisam ser decididas em P03.
- Solicitações terão índices separados para consulta do cliente e fila do prestador; colunas e ordem dependem das ordenações/filtros dos contratos e da agenda P06.
- Favoritos podem ter `UNIQUE(cliente, prestador)`; avaliações podem ter `UNIQUE(atendimento, autor)` somente se P17 confirmar esse limite.
- Mensagens podem usar índice `(conversa, criado_em, id)` para leitura ordenada. Retenção e cursor de leitura dependem de P09/P13.
- Referências históricas não serão removidas em cascata por padrão. Política de retenção, anonimização e descarte é necessária antes de escolher `CASCADE`, soft delete ou snapshot.
- Preço será persistido em tipo decimal exato ou unidade monetária inteira, nunca ponto flutuante. A escolha de formato, preço sob consulta e snapshots dependem de P03.
- Restrições de horário e sobreposição seguem P06 aprovada (duração completa no fuso `America/Sao_Paulo`, sem intervalo extra e capacidade de um atendimento por perfil). Equipes e múltiplos executores continuam dependentes de P12; não criar constraint que simule reserva para pedido pendente.

## Persistência selecionada e estratégia de migração

O usuário aprovou TypeORM + `mysql2`. As versões fixadas são `@nestjs/typeorm` 12.0.2, TypeORM 1.1.2 e `mysql2` 3.24.5. TypeORM 1.1.2 exige Node 22.13+ na linha 22; a faixa do projeto foi alinhada a esse requisito. O Nest documenta [TypeORM/MySQL](https://docs.nestjs.com/techniques/database); o TypeORM documenta [migrations revisáveis](https://typeorm.io/docs/migrations/setup/) com `up`/`down` e opção para desativar a sincronização automática.

Se aprovada, a estratégia será:

1. Entidades e migrations versionadas junto ao código; `synchronize: false` e `migrationsRun: false` em todos os ambientes. A primeira configuração do CLI já está em `apps/api/src/database/data-source.ts`.
2. Migrations nomeadas, revisadas e com `up`/`down` quando a reversão for segura; mudanças de dados irreversíveis terão procedimento de avanço/correção documentado.
3. Aplicação explícita por comando de migration, nunca ao iniciar a API. Nada será aplicado ao banco legado.
4. Antes de qualquer ambiente compartilhado, revisar o SQL gerado, testar em MySQL descartável compatível com produção e confirmar backup/restauração. Esta etapa ainda não seleciona versão do MySQL, não conecta ao servidor e não cria migration de produto.

## Convenções candidatas dos contratos

| Tema | Proposta para revisão | Dependência |
| --- | --- | --- |
| IDs da API | Identificadores opacos serializados como string; não tratar autenticação ou autorização como segredo do ID. Representação persistida e ID de login são decisões distintas. | P01 e contratos |
| Datas civis | `YYYY-MM-DD`, sem fuso, para uma data de calendário. | Uso por fluxo |
| Instantes | RFC 3339 em UTC (`Z`) para eventos registrados; fuso é apresentação, não muda o instante armazenado. | RNF014, P06 |
| Agenda local | Guardar/transportar `America/Sao_Paulo` junto ao horário civil; duração e sobreposição conforme `docs/agenda-duracao.md`. | P06 |
| Paginação | Cursor opaco com ordenação estável e desempate por identificador; limite máximo fica pendente de volume e metas aprovadas. | Q01/Q02 propostas; RNF009 |
| Erros | Manter resposta genérica atual para exceções internas; contratos de negócio terão códigos estáveis e validação por campo sem SQL, stack ou dados privados. | Contratos por módulo |
| Repetição | Operações críticas precisam ser idempotentes ou permitir consulta de resultado incerto, conforme RB23/RF030; definir chave/ciclo no contrato específico. | P06, P08, P17 |

Estas convenções são propostas de engenharia. Não acrescentam requisito de produto e não justificam criar rotas de negócio antes das decisões.

## Contrato já iniciado

`apps/api/openapi.yaml` registra somente `GET /health` e o envelope genérico de erro já implementado. O contrato não expõe banco, ambiente, versão ou dados de saúde de dependências.

## Convenções pendentes para contratos de negócio

Antes de fechar contratos de negócio, registrar uma decisão para:

- Identificadores públicos e internos, mantendo autorização por papel e vínculo em toda operação.
- Datas civis (`YYYY-MM-DD`) versus instantes; a agenda usa horário local em `America/Sao_Paulo` conforme P06.
- Paginação e ordenação estável para listas. Não aplicar um limite numérico proposto sem justificativa e aprovação.
- Códigos de erro, campos protegidos e critérios de exibição por ator. O envelope atual cobre apenas a fundação.

## Gate antes de migrações definitivas

Revisar P01–P18 item a item para os módulos que entrarão na entrega. Se uma regra continuar pendente, adiá-la explicitamente e retirar do esquema/contrato as estruturas que a pressupõem. Só então gerar migrações reversíveis e dados sintéticos associados às regras aprovadas.
