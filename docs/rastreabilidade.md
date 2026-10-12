# Rastreabilidade funcional — estado atual

Esta matriz resume o que existe no código de main em 0264eab. “Implementado” indica presença no app/API; não significa que todos os cenários tenham sido homologados em aparelho ou ambiente de produção. Requisitos classificados como proposta continuam fora do escopo até aprovação.

| Domínio | Estado no código | O que falta fechar |
| --- | --- | --- |
| Conta e acesso | Cadastro de cliente, profissional e empresa; login, logout, troca de senha e proteção de rotas. | Recuperação com entrega real, MFA administrativo, armazenamento seguro da sessão e política de sessões. |
| Perfil do cliente | Dados, endereços e favoritos disponíveis. Solicitação exige endereço cadastrado. | Homologar persistência, erros de rede e indicação de favorito já salvo no perfil público. |
| Profissional/empresa | Perfil, ofertas, preço inicial, disponibilidade, agenda, documentos e cadastro/edição. | Modelo de equipe/executores e capacidade de empresa dependem de decisão de produto. |
| Categorias e busca | Categorias, busca por termo/categoria/bairro e perfil público implementados. Mensagem de busca vazia revisada. | Comparação de profissionais ainda não tem fluxo dedicado; definir critérios, cobertura e escala. |
| Solicitações | Criar, consultar, aceitar, recusar, cancelar e concluir com os estados oficiais; endereço cadastrado e autorização são verificados. | Definir duração/sobreposição, política de cancelamento, snapshot do endereço e trilha de todas as transições. |
| Chat | Consulta e envio ligados à solicitação; campo enviado corrigido; atualização manual disponível. | Homologar em aparelho e orientar o envio quando a conversa estiver encerrada. |
| Avaliações | Avaliações dos participantes após conclusão, moderação e avaliações aprovadas no perfil. | Completar consulta administrativa de decisões anteriores se exigida; homologar com dados reais de teste. |
| Documentos e selo | Seletor PDF/JPEG/PNG até 5 MB, envio, status e decisões administrativas. | Acesso administrativo seguro ao conteúdo, verificação do tipo real de arquivo e regra do selo com vários documentos. |
| Denúncias | Cliente pode denunciar pelo app; API lista e registra moderação. | Homologar ações, permissões e trilha de auditoria conforme política final. |
| Administração | Painel, usuários, documentos, categorias, denúncias, avaliações e auditoria. | Criar administrador e histórico administrativo ainda não têm tela Flutter dedicada; definir MFA e permissões. |
| Notificações e histórico | Notificações internas persistidas e histórico de atendimentos. | Garantir recuperação quando a criação de aviso falhar; adicionar paginação e fechar retenção. |
| Termos e privacidade | Consulta e registro de aceite estão implementados. | Revisar conteúdo final, política de retenção e canal de suporte/privacidade antes da publicação. |

## Evidência disponível

A equipe informa **90 testes Flutter aprovados**. Capturas e testes visuais cobrem algumas telas em 360, 390 e 412 px; algumas áreas também foram testadas com texto ampliado. Testes de widgets não comprovam o contrato da API real.

A API possui testes e diagnósticos locais documentados, porém os resultados registrados anteriormente precisam ser repetidos após as mudanças de main em 0264eab. Para critérios manuais, use os [checklists de homologação](checklist-homologacao-cliente.md).

## Regras mantidas

- Estados de solicitação: aguardando_resposta, aceita_agendada, recusada, cancelada e conclusao_confirmada.
- Chat não confirma agendamento.
- O selo depende da análise documental e não é garantia absoluta.
- Valores finais e pagamento são combinados fora do app.
- Funcionalidades de requisitos marcados como proposta não entram automaticamente no escopo.

Para decisões e limitações detalhadas, consulte [pendências](pendencias.md) e o contrato em apps/api/openapi.yaml.
