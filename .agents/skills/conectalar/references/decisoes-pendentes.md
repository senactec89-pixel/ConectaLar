# Decisões Pendentes

Fonte: seção 8 do documento funcional v3, documento de regras/RNFs e `docs/pendencias.md`/`docs/decisoes.md`.

Regra de leitura: recomendações não são aprovações. Cada decisão deve registrar responsável, data, valor aprovado, RFs afetados e versão. Se uma decisão afeta segurança, privacidade, arquitetura ou comportamento central, peça esclarecimento antes de assumir regra definitiva.

## P01-P18

| P | Assunto | RFs afetados | Situação documentada e impacto |
| --- | --- | --- | --- |
| P01 | Dados de cadastro e perfil | RF001, RF003, RF004, RF008 | Parcialmente decidido no projeto: login poderá usar e-mail ou telefone. Falta normalização, verificação dos contatos, obrigatoriedade, campos públicos/privados e identificador. Impacta contas, perfis, telas de cadastro, unicidade e privacidade. |
| P02 | Sessão e recuperação de acesso | RF002, RF025, RF031, RF032 | Recomendação de recuperação por contato verificado e prova de uso único foi aprovada; senha exige titularidade e logout invalida a sessão encerrada. Falta prazo, sessões simultâneas, revogação após recuperação e abuso. |
| P03 | Categorias, serviços e preços | RF005, RF006, RF007, RF008, RF009, RF027 | A validar. Define taxonomia, serviço de catálogo, oferta do prestador, preço inicial, duplicidades e efeito de alterações. Bloqueia modelo definitivo de catálogo/oferta. |
| P04 | Endereços e acesso após atendimento | RF003, RF012, RF013, RF017, RF029, RF033 | A validar. Define endereço privado por solicitação, correção, acesso pós-cancelamento/conclusão e retenção. Impacta privacidade e API. |
| P05 | Cobertura territorial e Minas Gerais | RF004, RF007, RF011, RF034 | A validar. Define cidades de lançamento, bairros, cobertura estadual ou não, fontes de locais e expansão. Não assumir cobertura de todo MG. |
| P06 | Disponibilidade, duração e concorrência | RF011, RF012, RF014, RF015, RF018, RF030 | Aprovada em 18/10/2026; ver `docs/decisoes.md` e `docs/agenda-duracao.md`. P12 continua aberta para equipes e múltiplos executores. |
| P07 | Solicitação, recusa e ausência de resposta | RF012, RF013, RF014 | A validar. Define campos do pedido, limites de texto/anexos, motivo de recusa, prazo de resposta e contato antes do aceite. Não inventar expiração automática. |
| P08 | Cancelamento e conflitos de realização | RF018, RF019, RF030 | A validar. Preserva referência de 24h, mas exceções, prevalência, cancelamento pelo prestador, no-show e conflitos precisam de política. Não presumir multa. |
| P09 | Chat e proposta de horário | RF016, RF035 | A validar. Define momento de abertura, mensagens pós-encerramento, anexos, leitura, bloqueio e reagendamento. Chat não confirma agendamento sozinho. |
| P10 | Verificação documental | RF022, RF023, RF037 | A validar. Define documentos, exigência para publicar/receber pedidos, formatos, tamanho, validade, reenvio, recurso e renovação. |
| P11 | Denúncias e administração | RF024, RF025, RF026, RF027 | A validar. Define alvos, categorias, medidas, motivos, prazos, contestação, permissões e auditoria. Não punir automaticamente por denúncia. |
| P12 | Empresas e integrantes | RF004, RF011, RF013, RF014, RF017, RF040 | A validar. Define papéis, convites, desligamento, capacidade, executor e acesso ao endereço por integrantes. |
| P13 | Retenção e solicitações de titulares | RF010, RF016, RF022, RF029, RF038 | A validar. Define prazos, documentos, mensagens, avaliações, logs, anonimização, descarte, restauração e pendências. |
| P14 | Notificações e lembretes | RF028, RF036, RF042 | A validar. Define canais, mensagens, antecedência, destinatários, preferências, reenvio, duplicidade e conteúdo sensível. |
| P15 | Papéis e ciclo da conta | RF001, RF002, RF025, RF038 | Parcialmente decidido: haverá conta administrativa principal que cria contas administrativas separadas; cada administrador terá e-mail próprio; MFA permanece obrigatório conforme prompt mestre. Falta convite, permissões iniciais, revogação e recuperação da conta principal. |
| P16 | Comparação, filtros e elementos adicionais | RF007, RF008, RF009, RF010 | A validar. Define comparação, visitantes, ordenação, filtros e elementos do protótipo como Google, serviços favoritos, distância, ranking, idioma e suporte. |
| P17 | Conclusão e avaliações | RF019, RF020, RF021, RF026 | A validar. Confirmação pelo cliente é marco proposto; escala, comentário, fotos, edição, resposta, exibição e contestação precisam aprovação. |
| P18 | Avisos e publicação | RF039, RF041 | A validar. Define termos, aviso de privacidade, momentos de apresentação, versionamento, manifestação e comunicações de preço/selo/cancelamento. |

## Questões dos Protótipos

- Protótipo principal: Google, idioma, suporte, favoritos de serviços, proposta de horário no chat, documentos específicos e etapas de cadastro são visuais/propostas; não implementar como regra definitiva sem P09/P10/P16/P18.
- Protótipo administrativo: R01-R21 pedem confirmação explícita por grupo; não assumir permissões, MFA, auditoria, medidas de moderação ou atuação administrativa sem P11/P15/P18.
- Administração deve permanecer separada do app cliente/prestador até haver decisão de arquitetura e navegação.

## Próxima Ação ao Bloquear

Quando uma P bloquear a implementação, apresente:

- Funcionalidade afetada.
- IDs RF/RNF/RB/P envolvidos.
- Opções documentadas, sem promover recomendação a decisão.
- Menor alternativa segura: adiar, criar placeholder honesto, implementar parte não bloqueada ou pedir decisão.
