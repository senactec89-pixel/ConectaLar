# Inventário de dados e fornecedores — rascunho para revisão

**Estado:** levantamento técnico do código em 10/11/2026. Não é política de privacidade aprovada nem autorização para usar dados reais de habilitação. Finalidade específica, base legal, prazo de guarda, descarte e contratos devem ser conferidos pela equipe responsável e por revisão jurídica antes da operação com dados reais.

Referências técnicas: `apps/api/src/database/entities/`, `apps/api/src/privacidade/`, `apps/api/src/verificacao/`, `apps/api/src/localizacao/`, `docs/lgpd-direitos-titular.md` e `docs/seguranca.md`. Modelo de registro e checklist da ANPD: <https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/guia-orientativo-sobre-seguranca-da-informacao-para-agentes-de-tratamento-de-pequeno-porte>.

## Registro inicial das operações

Este quadro descreve o que o sistema trata hoje. A coluna de acesso é o **acesso pretendido pelo fluxo**, não uma certificação de todas as permissões implementadas. Confirmar cada rota e consulta em testes de autorização antes da entrada em produção. Para cada linha, preencher posteriormente fundamento jurídico, responsável, prazo, destino após o prazo e tratamento em backups.

| Dados ou registros | Uso no produto | Acesso a conferir | Guarda e descarte |
| --- | --- | --- | --- |
| Nome, e-mail, telefone, tipo de conta e identificador Google | Cadastro, autenticação e comunicação da conta | Titular e administradores com permissão; identificador Google restrito | **Pendente:** política por campo e histórico mínimo após exclusão |
| Hash de senha, tokens/sessões, códigos de verificação e MFA | Controle de acesso, recuperação e confirmação | Serviço de autenticação e titular somente nas operações apropriadas; segredos nunca em exportação pública | **Pendente:** expiração, revogação, logs e descarte de registros antigos |
| Perfil, foto e dados públicos do profissional ou empresa | Apresentação e busca de serviços | Público apenas para campos aprovados; edição pelo titular | **Pendente:** remoção de cópias, cache e imagens após desativação |
| Endereços do cliente e coordenadas de localização | Cadastro, localização e atendimento | Cliente; endereço completo ao participante autorizado somente após aceite válido | **Pendente:** retenção do snapshot do pedido e revogação de acesso após encerramento |
| Oferta, categoria, duração, disponibilidade e localização do profissional | Catálogo, busca e agenda | Público para oferta aprovada; titular para edição; equipe autorizada para moderação | **Pendente:** histórico de ofertas e versões do combinado |
| Pedido, descrição, data, horário, endereço em snapshot, orçamento, reagendamento e eventos | Negociação, agendamento, histórico e resolução de conflito | Participantes e administração autorizada; endereço limitado por estado e habilitação | **Pendente:** dados mínimos de histórico, acesso após cancelamento e descarte |
| Mensagens do atendimento | Conversa contextual entre participantes | Participantes autorizados e acesso administrativo somente com finalidade definida | **Pendente:** prazo, moderação, anexos e exclusão |
| Avaliações, favoritos e notificações | Experiência do cliente, reputação e avisos | Titular e destinatários previstos; avaliação pública apenas nos campos aprovados | **Pendente:** prazo e efeito da exclusão da conta |
| Denúncias, motivos e evidências | Atendimento e moderação de incidentes do serviço | Relatores envolvidos conforme fluxo e administração autorizada; não publicar motivo privado | **Pendente:** prazo, contestação, acesso do denunciado e descarte |
| Documentos profissionais, metadados e arquivos privados | Análise documental e habilitação | Titular e revisores administrativos autorizados; sem URL pública | **Pendente:** validade, cópias, backups, retenção e prova de descarte |
| Identidade, prova de vida, telefone e resultados de verificações | Habilitação individual e revisão humana | Titular na extensão permitida, revisores autorizados e fornecedor contratado | **Pendente:** necessidade, minimização, retenção, contestação e tratamento de dados sensíveis |
| Decisões de administradores, convites, MFA e auditoria | Moderação, rastreabilidade e controle de acesso | Administração com permissão específica; acesso ao dossiê restrito | **Pendente:** prazo por tipo de evento e preservação mínima necessária |
| Aceites de termos e solicitações de privacidade | Comprovação de aceite, exportação e exclusão | Titular nas operações próprias; administração autorizada conforme finalidade | **Pendente:** prazo e resposta a pedidos não resolvidos pelo autoatendimento |

## Fornecedores e fluxos externos a confirmar

Não presumir que toda integração configurável esteja ativa no ambiente de produção. Registrar contrato, papel de cada parte, localização do tratamento, medidas de segurança, suboperadores, prazo de eliminação e canal de incidente antes do uso real.

| Integração identificada no código | Dados potencialmente enviados ou armazenados | Verificação pendente |
| --- | --- | --- |
| Provedor de hospedagem da API e MySQL | Dados persistidos e backups | Ambiente real, contrato, acesso, criptografia e restauração |
| Armazenamento local privado ou Cloudflare R2 | Arquivos de documentos e metadados de armazenamento | Qual opção será usada, região, contrato, bucket privado, backup e descarte |
| ZapSign para identidade e telefone | Dados necessários à verificação e resultado retornado | Contrato, finalidade, dados exatos, validade, retenção e canal de contestação |
| Google Login | Identificador da conta, e-mail e nome retornados na autenticação | Configuração efetiva, avisos e contrato/termos aplicáveis |
| Google Geocoding/Maps | Endereço usado na busca de coordenadas, quando configurado | Minimização do endereço enviado, chave, condições de uso e avisos |
| Servidor de e-mail SMTP | Endereço de e-mail e conteúdo de mensagens transacionais | Provedor real, contrato, logs, retenção e entregabilidade |

## Direitos, avisos e incidentes

- **Já existe tecnicamente:** exportação autenticada em JSON, exclusão com autenticação e anonimização, descritas em `docs/lgpd-direitos-titular.md`. Isso não resolve todos os pedidos humanos, casos excepcionais ou prazos de resposta.
- **Definir e revisar:** texto de aviso para cliente, profissional, executor de empresa e administrador; canal de atendimento humano; procedimento de correção e contestação; responsável pela resposta; registro da decisão e comunicação ao titular.
- **Separar fluxos:** incidente de atendimento (ausência, dano, alteração do combinado) e incidente de segurança de dados (acesso indevido, perda ou exposição) exigem responsáveis e respostas diferentes. Para segurança, documentar detecção, contenção, avaliação, comunicação e evidências, sujeitos a revisão especializada.
- **Antes de liberar atendimentos:** revisar especialmente o acesso ao endereço, a verificação individual de executores, a dupla revisão administrativa e o tratamento dos dados de habilitação. O bloqueio atual não deve ser removido por este inventário.

## Próximos passos de validação

1. Confirmar com a equipe quais fornecedores serão usados em produção e preencher o registro por operação com os campos do modelo da ANPD.
2. Revisar necessidade, fundamento jurídico e prazo de cada categoria de dado, inclusive cópias, logs e backups.
3. Validar permissões da API e mensagens da interface por papel; registrar evidência dos testes.
4. Submeter termos, avisos, contratos, prazos e procedimento de incidentes à revisão jurídica e de privacidade antes de usar dados reais.
