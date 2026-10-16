# Pendencias do ConectaLar

Estado revisado em 16/10/2026. O app e a API ja implementam o nucleo dos fluxos de demonstracao; as pendencias abaixo separam ajustes tecnicos, decisoes de produto e preparacao para producao.

## Correcoes recentes incorporadas

- Campo de envio do chat alinhado ao contrato da API.
- Fluxo de denuncia do cliente adicionado.
- Solicitacao passou a exigir endereco cadastrado.
- Validacao de senha forte aplicada no Flutter e na API.
- Confirmacao de e-mail e recuperacao de senha por e-mail configuravel adicionadas.
- MFA administrativo por TOTP implementado.
- Foto de perfil para usuarios adicionada.
- Upload documental com validacao de tamanho, extensao e assinatura do arquivo.
- Varredura ClamAV configuravel para documentos antes da gravacao.
- Storage documental configuravel: local em desenvolvimento ou Cloudflare R2 em producao.
- Rota administrativa privada para leitura de documento.
- Preview administrativo de JPEG, PNG e PDF no app.
- Regra do selo profissional recalculada pelo conjunto de documentos: o selo depende de documento de identidade aprovado.
- Sessao Flutter movida para armazenamento criptografado da plataforma, com migracao automatica e remocao do valor legado em `SharedPreferences`.
- Exportacao LGPD em JSON e exclusao de conta com senha atual, confirmacao forte, anonimizacao e invalidacao de sessoes.

## Ajustes tecnicos ainda pendentes

- Instalar, configurar e homologar ClamAV no ambiente de hospedagem com `MALWARE_SCAN_MODE=required`.
- Criar bucket Cloudflare R2 real, configurar credenciais de producao e homologar upload/download na hospedagem.
- Migrar fotos de perfil para storage privado/gerenciado ou definir se continuarao em storage local/publico por rota da API.
- Definir e implementar politica de retencao, expiracao e descarte de documentos.
- Trocar rate limit em memoria por solucao adequada se houver multiplas instancias.
- Definir expiracao e politica de sessoes simultaneas no Flutter e na API.
- Definir paginacao para busca, historico, chat e listas administrativas conforme volume esperado.
- Revisar mensagens genericas de erro para distinguir conexao, permissao, validacao e estado vazio.
- Atualizar relatorios historicos que ainda citam contagens antigas de testes ou pendencias ja resolvidas.

## Decisoes de produto ainda abertas

- Duracao padrao de atendimento, fuso horario, sobreposicao e capacidade da agenda.
- Politica de cancelamento: prazo, excecoes, justificativa e efeitos no historico.
- Politica de snapshot, historico, retencao e acesso ao endereco apos encerramento/cancelamento.
- Conjunto documental final exigido para selo, validade documental e eventual revalidacao periodica.
- Conta administrativa principal, convites, permissoes detalhadas e revogacao.
- Cidades/cobertura de lancamento, comparacao de profissionais e escopo final do catalogo.
- Regras de continuidade do chat, anexos, canais de notificacao e preferencias.
- Processo de contestacao para moderacao de denuncias, avaliacoes e documentos.
- Revisao juridica final dos termos, politica de privacidade, prazos de retencao e canal humano para casos que nao possam ser resolvidos pelo autoatendimento.

## Preparacao para producao

- Hospedagem da API e do banco em ambiente com suporte real a Node/NestJS, MySQL, HTTPS e variaveis de ambiente.
- Storage privado gerenciado com acesso autenticado e sem URL publica direta para documentos sensiveis.
- Backup e restauracao testados.
- Monitoramento, alertas, logs operacionais e plano de resposta a incidentes.
- Scanner de segredos antes de publicar.
- Build Android release assinado.
- Ambiente macOS, conta de loja e assinatura para iOS.
- Homologacao completa em aparelho real com API hospedada.

## Documentacao relacionada

- [Progresso](progresso.md)
- [Seguranca](seguranca.md)
- [Operacao e producao](operacao-producao.md)
- [Checklist cliente](checklist-homologacao-cliente.md)
- [Checklist profissional](checklist-homologacao-profissional.md)
- [Checklist admin](checklist-homologacao-admin.md)
