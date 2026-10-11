# Pendências do ConectaLar

Estas pendências foram preservadas para não transformar propostas documentais em regras aprovadas. Nenhuma delas bloqueia a fundação técnica da Etapa 1.

## Fontes localizadas e status documental

Os materiais abaixo estão em `Downloads` e foram localizados em 9 de outubro de 2026:

- `ConectaLar_Requisitos_Funcionais_v3_Revisado.docx`;
- `ConectaLar_Requisitos_Nao_Funcionais_e_Regras_de_Negocio_Revisado.docx`;
- `ConectaLar_Telas_Restantes_Administrativo.pdf`;
- `Prototipo.pdf`;
- `ConectaLar.zip`.

Os dois DOCX foram lidos para preparar o início da Etapa 2. Eles classificam RF001–RF030 como preservados e RF031–RF042 como propostas; RNF001–RNF026 e RB01–RB18 são preservados, enquanto complementos têm situação própria. P01–P18 e Q01–Q08 seguem para validação. O conteúdo desses documentos é fonte de requisitos, mas recomendações identificadas como propostas não são aprovações do usuário.

Os PDFs ainda precisam de inspeção visual antes de implementar telas administrativas. Protótipos e imagens orientam apresentação, não substituem requisitos funcionais nem regras de negócio. O stack PHP/XAMPP mencionado nos DOCX é histórico e não prevalece sobre o prompt mestre atual.

## Políticas a decidir nas etapas correspondentes

- Cidades, cobertura territorial e regras de atendimento por região.
- Exceções e prevalência das condições do prestador diante da referência documental de cancelamento em 24 horas.
- Momento de visibilidade do endereço completo já tem regra operacional no contrato atual: cliente, administrador e profissional vinculado podem ver o endereço completo após aceite do atendimento. Ainda falta decidir política de snapshot, histórico, retenção e acesso após cancelamento/encerramento.
- Duração e capacidade de atendimento de profissionais/empresas.
- Momento de abertura do chat, anexos, avaliações e reenvio de mensagens.
- Retenção, descarte e solicitações de titulares para dados pessoais.
- Permissões, justificativa e auditoria de decisões administrativas e denúncias.
- Decisões P01–P18 listadas na seção 8 do DOCX funcional permanecem a validar; propostas não devem ser incluídas como regra aprovada.
- Metas Q01–Q08 do DOCX de qualidade são propostas, sem valores aprovados para alegações ou testes de homologação.
- Identificadores expostos pela API, convenção de data/hora e paginação precisam de proposta e registro antes de fechar os contratos de negócio.

### Gate explícito para o modelo e as migrations da Etapa 2

Todos os itens abaixo seguem **a validar**. A descrição completa e as recomendações originais permanecem no DOCX funcional v3; esta lista serve para mostrar o que cada decisão desbloqueia.

| Decisão | Tema para validar | Efeito direto no modelo/contrato |
| --- | --- | --- |
| P01 | Campos, visibilidade e identificador da conta/perfil | Colunas de conta, normalização, unicidade e IDs públicos |
| P02 | Sessões, recuperação e revogação | Tabelas/expiração de sessão e desafios de recuperação |
| P03 | Taxonomia, ofertas e preço | Categoria, serviço, oferta, preço e constraints de duplicidade |
| P04 | Endereços e acesso ao local | Endereço salvo, snapshot por pedido e autorização após atendimento |
| P05 | Cobertura e localidades de lançamento | Catálogo territorial e cobertura de prestador |
| P06 | Duração, fuso, disponibilidade e concorrência | Tipos temporais, capacidade, bloqueios e índices de agenda |
| P07 | Campos do pedido, recusa e ausência de resposta | Colunas de solicitação, limites e transições |
| P08 | Cancelamento e exceções | Transições, prazos e registros de cancelamento |
| P09 | Momento e recursos do chat | Conversa, mensagem, encerramento, anexos e leitura |
| P10 | Documentos e critérios de verificação | Tipos, estados, metadados e renovação de documentos |
| P11 | Denúncias, moderação e permissões administrativas | Alvos, medidas autorizadas, papéis e auditoria |
| P12 | Empresa, integrantes e capacidade | Organização, vínculos, executor e atribuição de pedidos |
| P13 | Retenção, encerramento e solicitações de titulares | Prazos, descarte, anonimização e snapshots históricos |
| P14 | Canais, conteúdo e preferências de notificações | Avisos internos, push, destinatários e tentativas |
| P15 | Papéis e ciclo de vida da conta | Relações de papéis, suspensão, troca e encerramento |
| P16 | Visitantes, comparação, filtros e elementos adicionais | Visibilidade pública, limites e ordenação de busca |
| P17 | Conclusão e política de avaliação | Elegibilidade, escala, unicidade, edição e moderação |
| P18 | Avisos legais, versão e manifestação | Versões de documentos e registro de aceite quando aplicável |

A escolha TypeORM + `mysql2` já foi aprovada e registrada em `docs/decisoes.md`. As convenções de IDs, data/fuso e paginação continuam como propostas; o escopo e as políticas P ainda precisam ser definidos antes de gerar migrations executáveis. Nada desta tabela autoriza modificar ou migrar `database/conectalar.sql`.

### Respostas recebidas para identidade

- **P01 — parcialmente decidido:** login por e-mail ou telefone. Antes do contrato, confirmar se os dois contatos precisam ser verificados e definir normalização/campos obrigatórios e visibilidade do perfil.
- **P02 — recomendação aprovada:** recuperação por contato verificado com prova de uso único; a troca de senha exige prova de titularidade e logout invalida a sessão encerrada. Falta definir o prazo de validade e a política de sessões simultâneas.
- **P15 — parcialmente decidido:** haverá uma conta administrativa principal que cria contas administrativas separadas com seus próprios e-mails. O prompt mestre mantém MFA obrigatório e proíbe credenciais compartilhadas. Falta definir convite, permissões iniciais, revogação e recuperação da conta principal.
- **Prompt mestre confirmado:** seguir a stack e as regras do prompt, inclusive contas administrativas individuais com MFA.
- **MySQL:** o usuário vai criar a instância local. Ela deve ser exclusiva para desenvolvimento/teste e não conter os dados do SQL legado.

## Restrições de operação

### Limites dos módulos Flutter profissionais e administrativos

- As telas profissionais P01–P07 e os módulos administrativos de usuários, documentos, denúncias, avaliações e categorias usam os endpoints disponíveis em `apps/api`. O selo continua condicionado à aprovação administrativa; o cliente não realiza essa aprovação.
- A API atualiza as ofertas profissionais junto com o perfil (`PUT profissionais/me`) e recria os itens enviados como ativos. Não há endpoint para desativar uma oferta individual nem para alterar os campos públicos de perfil separadamente. A tela permite incluir/editar ofertas e apresenta-as como ativas; a desativação individual depende de uma decisão de contrato e endpoint específico.
- O endpoint administrativo de usuários não informa o estado de verificação do perfil profissional. O painel conta documentos pendentes, mas não consegue separar profissionais pendentes de verificação de profissionais sem documentos enviados.
- A API de categorias administra apenas nome e status. Cadastro de ícone/descrição, gerenciamento independente de serviços do catálogo e relatório/paginação administrativa não estão disponíveis; a interface não simula essas operações.
- A solicitação agora aceita `enderecoId` e a API retorna o endereço completo apenas para atores autorizados: cliente dono, administrador e profissional vinculado depois do aceite. Antes do aceite, o profissional recebe somente dados protegidos do local. Permanecem pendentes as regras finais de snapshot, retenção, histórico e cancelamento.
- O envio real de documentos profissionais foi implementado com seletor nativo no Flutter e upload Base64 para PDF, JPEG e PNG de até 5 MB. A API armazena o arquivo em diretório privado local de desenvolvimento e expõe o fluxo de moderação administrativa. Para produção ainda faltam armazenamento gerenciado privado, antivírus/verificação de conteúdo, política de retenção/descarte e trilha operacional de download/acesso.

- O orçamento informado é de R$ 400 no total; desenvolvimento deve começar localmente e sem custos recorrentes assumidos.
- A equipe não dispõe de Mac. Compilação e assinatura iOS dependem de ambiente macOS a escolher e aprovar antes da homologação.
- Acesso a iPhone de teste, orçamento recorrente e contas das lojas ainda precisam ser confirmados antes de publicação.
