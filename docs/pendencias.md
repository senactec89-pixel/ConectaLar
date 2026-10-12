# Pendências do ConectaLar

Estado revisado para main, commit 0264eab, em 11/10/2026. O app e a API já implementam o núcleo dos fluxos de demonstração; as listas abaixo distinguem ajustes técnicos, decisões de produto e requisitos de produção.

## Correções recentes já incorporadas

- Campo de envio do chat alinhado ao contrato.
- Tela de denúncia do cliente adicionada.
- Solicitação passou a exigir endereço cadastrado.
- Validação de senha forte aplicada no Flutter e na API.
- Selo do perfil profissional corrigido para texto longo.
- Mensagem de busca vazia revisada.

## Ajustes técnicos que ainda merecem validação

- No formulário de solicitação, erro de rede ao carregar endereços pode parecer ausência de endereço; separar erro/retry do estado realmente vazio.
- A troca de senha usa resposta 401; validar que senha atual incorreta não seja confundida com sessão expirada.
- O favorito no perfil público deve refletir o estado salvo na API e permitir atualização coerente.
- Reconsultar dados do perfil público ao abrir, se necessário para evitar informação desatualizada.
- Garantir que a conversa em estado encerrado não sugira envio de mensagens que a API recusará.
- Corrigir a preservação de preço nulo da oferta “a combinar”, caso diferente do preço inicial do perfil.
- Completar a inspeção segura de documentos na moderação administrativa.
- Tornar a emissão de notificações resiliente a falhas ocorridas após a operação principal.
- Definir paginação para busca, histórico, chat e listas administrativas conforme volume esperado.

## Decisões de produto ainda abertas

- Duração, fuso, sobreposição e capacidade da agenda, inclusive empresas e múltiplos executores.
- Prazo e exceções de cancelamento.
- Política de snapshot, histórico, retenção e acesso ao endereço após encerramento/cancelamento.
- Critérios para selo quando há vários documentos, reenvio e expiração documental.
- Política de recuperação de senha, expiração de token e sessões concorrentes.
- Conta administrativa principal, convites, permissões, revogação e MFA.
- Cidades/cobertura, comparação de profissionais e escopo do catálogo.
- Abertura e continuidade do chat, anexos, canais de notificação e preferências.
- Retenção/descarte de dados pessoais, atendimento a titulares e conteúdo final dos termos.

As decisões P01–P18 e Q01–Q08 têm situação individual na documentação de requisitos. Itens classificados como proposta não devem ser tratados como aprovados. O SQL em database/conectalar.sql é legado e não deve ser migrado para a estrutura TypeORM atual.

## Preparação para produção

- Recuperação de senha com envio por contato verificado e MFA administrativo.
- Storage privado gerenciado, validação do conteúdo dos documentos, antivírus e política de retenção.
- HTTPS, configuração de proxies confiáveis e rate limit que funcione entre instâncias.
- Backup/restauração testados, monitoramento, alertas, resposta a incidentes e pipeline de publicação.
- Assinatura release Android, identificador final e ambiente macOS/conta de loja para iOS.
- Homologação completa em aparelho real com API e MySQL.

## Documentação relacionada

- [Progresso](progresso.md)
- [Rastreabilidade](rastreabilidade.md)
- [Segurança](seguranca.md)
- [Checklist do cliente](checklist-homologacao-cliente.md)
- [Checklist profissional](checklist-homologacao-profissional.md)
- [Checklist admin](checklist-homologacao-admin.md)
