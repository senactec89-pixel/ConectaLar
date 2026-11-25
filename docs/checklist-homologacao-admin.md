# Homologação manual — administração

Use uma conta administrativa de teste e banco descartável. Execute decisões apenas sobre registros fictícios; confirme o ator, o alvo e a auditoria de cada operação.

**Contexto:** siga `homologacao-beta-local.md` e use apenas contas/dados ficticios neste checklist. A verificacao por codigo de telefone fica desligada. A aprovacao real, quando a migration estiver aplicada, requer documento aprovado, tarefa elegivel revisada por dois admins e duas revisoes distintas do perfil com MFA; nao teste essa acao com contas reais durante homologacao. Nao use SQL para contornar o fluxo, nem marque caixas por teste automatizado. Este checklist nao representa aprovacao juridica ou decisao de lancamento.

## Acesso e painel

- [ ] Convidar um administrador de teste e confirmar que nenhum token de convite aparece na resposta da API.
- [ ] Aceitar o convite uma vez; repetir o mesmo token e confirmar rejeicao.
- [ ] Confirmar que senha forte, aceite da versao atual dos termos e MFA sao obrigatorios antes do painel.
- [ ] Testar convite expirado, alterado e enviado ao e-mail errado sem revelar se outra conta existe.
- [ ] Confirmar que uma conta administrativa sem MFA recebe `403 MFA_ADMIN_OBRIGATORIO` em rotas protegidas.
- [ ] Confirmar que cinco codigos TOTP errados bloqueiam tentativas por 15 minutos, inclusive depois de reiniciar a API.
- [ ] Entrar com administrador habilitado e confirmar que senha + TOTP sao exigidos.
- [ ] Confirmar que o usuario nao pode desativar MFA por interface ou API.
- [ ] Confirmar que uma conta sem papel admin recebe acesso restrito.
- [ ] Conferir indicadores e acessos do painel em aparelho.
- [ ] Sair e confirmar que páginas autenticadas retornam ao login.

## Usuários e categorias

- [ ] Buscar/listar usuários e abrir detalhes.
- [ ] Ativar/desativar uma conta de teste conforme permissões.
- [ ] Confirmar que não é possível desativar a própria última conta administrativa ativa.
- [ ] Listar categorias, criar uma categoria de teste, editar e desativar.
- [ ] Confirmar que categoria inativa não aparece como opção pública para novas ofertas/solicitações.

## Documentos e verificação

- [ ] Listar documentos pendentes e filtrar por pendente, aprovado, rejeitado e todos.
- [ ] Abrir/inspecionar o conteúdo do arquivo em fluxo autorizado. Se a API não oferecer acesso seguro ao conteúdo, registrar como bloqueio e não aprovar somente pela referência/nome.
- [ ] Aprovar um documento de teste.
- [ ] Rejeitar outro com justificativa.
- [ ] Conferir status na área profissional e selo no perfil público.
- [ ] Confirmar que aprovar um documento isoladamente atualiza apenas o estado documental/selo e não libera solicitações.
- [ ] Em registros ficticios, confirmar que a primeira aprovacao do perfil nao habilita pedidos e a segunda, feita por outro admin com MFA, conclui a habilitacao.
- [ ] Confirmar que o mesmo administrador nao consegue registrar as duas decisoes do perfil nem as duas revisoes de uma tarefa.
- [ ] Confirmar que perfil sem e-mail confirmado, documento aprovado ou oferta ativa aprovada do piloto permanece bloqueado.
- [ ] Confirmar que um profissional habilitado nao pode receber solicitacao por tarefa fora do piloto ou sem duas revisoes registradas.
- [ ] Confirmar que nenhuma tela exige codigo de telefone e que os endpoints de inicio/confirmacao ficam indisponiveis com `CONECTALAR_PHONE_VERIFICATION_ENABLED=false`.
- [ ] Confirmar que a interface não apresenta profissional pendente como apto a receber pedidos.
- [ ] Conferir se a auditoria registra ator, ação, alvo e data sem incluir conteúdo sensível.

## Denúncias, avaliações e auditoria

- [ ] Localizar denúncia criada por conta de teste; analisar e registrar decisão/justificativa.
- [ ] Conferir que denúncia não aplica punição automática sem ação explícita.
- [ ] Conferir avaliações pendentes e moderar uma avaliação de teste.
- [ ] Conferir resultado público e trilha de auditoria.
- [ ] Consultar auditoria e validar autor, tipo de ação, entidade alvo e horário.
- [ ] Confirmar resumo legível antes de abrir os detalhes técnicos e fechar a expansão novamente.
- [ ] Verificar após atualização da tela que decisão, aceite/recusa, expiração e cancelamento de pedidos de teste mantêm seus históricos nos módulos apropriados.
- [ ] Confirmar que justificativas, relatos, CPF, telefone, e-mail, documento e tokens fictícios não aparecem no detalhe da auditoria, inclusive em registros antigos.
- [ ] Conferir respostas para estados vazios, erro/retry, salvamento e falha de rede.

## Resultado

- [ ] Acesso restrito validado.
- [ ] Cada decisão aparece no estado esperado e na auditoria.
- [ ] Capturas e falhas anexadas sem conteúdo de documentos ou dados pessoais.
