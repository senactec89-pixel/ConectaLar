# Beta técnica local e homologação

Esta beta serve para testar fluxos com contas, endereços e documentos **fictícios** em MySQL descartável. Não habilita atendimento a pessoas reais. A ação administrativa de aprovação permanece bloqueada até a conclusão das políticas de identidade, telefone e antecedentes.

## Preparação do ambiente

1. Use Node 22.13+ ou 24.15+, MySQL local e as migrations atuais, incluindo `AgendaSemIntervalo1760139000000`. Aplique migrations explicitamente apenas no banco de teste. No Windows, `apps/api/start-local.cmd` aceita `NODE_HOME` apontando para uma instalação compatível; o script recusa um Node antigo.
2. Crie o banco separado `conectalar_beta_test`. Mantenha `DB_HOST` como `127.0.0.1`, `localhost` ou `::1` e `NODE_ENV=test` somente no processo de homologação. Não reutilize `conectalar_dev` nem um banco de produção.
3. Crie os perfis fictícios pelos fluxos normais. Anote os IDs numéricos dos **perfis profissionais** no banco de teste. O operador local os habilita ao iniciar a API com `CONECTALAR_BETA_LOCAL=true` e `CONECTALAR_BETA_LOCAL_PROFISSIONAL_IDS=ID1,ID2`. Reinicie a API ao alterar a lista. Não existe rota de aprovação da beta.
4. Configure as demais variáveis exigidas pela API, sem incluir senhas, tokens ou chaves nas evidências. Ao usar `start-local.cmd`, coloque os valores de beta em `apps/api/.env.local`; o arquivo local substitui os padrões do script. Para aparelho Android na mesma rede, configure `HOST` e a URL do app conforme a rede local; o banco continua em loopback.
5. Confirme em dois processos separados: com `NODE_ENV=production` ou sem a flag, `podeAtender=false` e novas solicitações retornam `409 PROFISSIONAL_HABILITACAO_PENDENTE`; no processo de teste, somente os IDs listados e ativos podem prosseguir. Perfis suspensos permanecem bloqueados.

## Roteiro integrado

- [ ] Registrar data, commit, versão do APK, modelo/Android, URL sem credenciais, versão do Node, banco de teste e IDs fictícios usados.
- [ ] Criar pedido e confirmar proteção do endereço antes do aceite.
- [ ] Enviar proposta de horário ou escopo; atualizar a tela e conferir o prazo de 48 horas.
- [ ] Aceitar uma proposta: verificar agenda, escopo confirmado, histórico, notificações e ausência de cobrança no app.
- [ ] Recusar outra proposta e expirar uma terceira: conferir estado e dados anteriores, prazo de inatividade e histórico após atualizar a tela.
- [ ] Cancelar um atendimento aceito com motivo fictício e conferir status, histórico e notificação.
- [ ] Verificar duração pronta e personalizada, dias bloqueados, horários consecutivos e conflito entre dois aceites concorrentes.
- [ ] Conferir auditoria administrativa com MFA: resumo, detalhes fechados, expansão, atualização e ausência de textos sensíveis.
- [ ] Repetir telas prioritárias em Android físico com teclado aberto, fontes ampliadas, rolagem e rede instável.
- [ ] Registrar resultado por papel nos checklists de cliente, profissional/empresa e administrador, sem marcar testes não executados.

## Critérios de não lançar

- Sem aprovação da política de habilitação, não abrir pedidos para pessoas reais.
- Sem build Android válido, migrations aplicadas no banco descartável e teste em aparelho, não distribuir a beta técnica.
- Sem validação manual de proposta, agenda, privacidade e auditoria nos três papéis, não declarar a homologação concluída.

## Estado em 12/11/2026

- API: TypeScript compilou e 136 testes automatizados passaram com Node 24.20.0.
- Flutter: 304 testes automatizados passaram; build web e APK debug foram gerados.
- `flutter analyze --no-pub`: nenhum erro ou aviso de código; 124 mensagens informativas de depreciação de `material.dart` no Flutter 3.50.
- Nenhum aparelho Android foi detectado neste ambiente. A migration nova e o fluxo completo ainda precisam de validação com MySQL descartável e aparelho real. Nenhuma caixa de homologação manual foi marcada.
