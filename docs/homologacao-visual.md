# Homologacao visual do ConectaLar

Este roteiro deve ser usado quando a integracao Flutter/API/MySQL estiver estavel. Ele registra verificacoes visuais sem alterar telas, servicos ou contratos da API.

## Escopo seguro durante integracao

- Registrar problemas encontrados em documentacao ou issues.
- Evitar edicoes em `lib/screens/servicos/solicitar_servico_page.dart`, `lib/screens/profissional/area_profissional_page.dart`, `lib/screens/chat/conversa_page.dart`, `lib/screens/admin/admin_pages.dart`, `lib/services/`, rotas, autenticacao e `apps/api/` enquanto houver correcao paralela de integracao.
- Combinar antes de alterar tema, widgets compartilhados, navegacao ou componentes reutilizados por varias telas.

## Ambientes de conferencia

- Largura 360 px.
- Largura 390 px.
- Largura 412 px.
- Texto do sistema em tamanho normal.
- Texto ampliado.
- Teclado aberto em formularios.
- App com API real local.
- App em modo demonstracao somente quando o objetivo for aparencia, nao contrato real.

## Checklist geral

- [ ] Nenhum texto corta, sobrepoe ou sai do botao/card/campo.
- [ ] Estados de carregamento, erro e vazio aparecem com mensagem clara.
- [ ] Botoes principais mantem area de toque confortavel.
- [ ] Cores e contraste continuam legiveis em texto pequeno.
- [ ] Campos de formulario indicam erro sem esconder o que o usuario precisa corrigir.
- [ ] Dialogos cabem na tela estreita e com texto ampliado.
- [ ] Listas vazias nao parecem falha de API.
- [ ] Navegacao de voltar/cancelar nao perde dados importantes sem aviso.

## Fluxos cliente

- [ ] Home carrega categorias e profissionais.
- [ ] Busca por categoria e termo fica legivel em telas estreitas.
- [ ] Detalhe do profissional apresenta servicos e preco sem truncar informacao essencial.
- [ ] Criacao de solicitacao mostra endereco, data, horario e descricao de forma clara.
- [ ] Meus servicos separa aguardando, aceitos, concluidos, recusados e cancelados sem criar estados formais novos.
- [ ] Chat mostra mensagens, envio, erro e lista vazia sem sobreposicao.
- [ ] Conclusao e avaliacao explicam o proximo passo.

## Fluxos profissional

- [ ] Area profissional apresenta resumo, proximos atendimentos e solicitacoes recentes.
- [ ] Agenda mostra disponibilidade e atendimentos do mes.
- [ ] Cadastro/perfil profissional mantem etapas compreensiveis.
- [ ] Gerenciamento de servicos preserva leitura de nome, categoria e preco.
- [ ] Documentos exibem tipo, arquivo selecionado, limite e status de moderacao.
- [ ] Avaliacoes recebidas diferenciam vazio, carregando e erro.

## Fluxos administrativos

- [ ] Painel administrativo apresenta indicadores sem poluicao visual.
- [ ] Usuarios exibem busca, status, ativacao/bloqueio e estados vazios.
- [ ] Documentos mostram pendentes, aprovados/rejeitados e justificativa.
- [ ] Denuncias exibem denunciante, denunciado, motivo, status e decisao.
- [ ] Avaliacoes pendentes mostram nota, comentario e acao de moderacao.
- [ ] Categorias permitem criar, editar e desativar com confirmacao clara.
- [ ] Auditoria permite leitura de acao, ator, alvo e data.

## Evidencias recomendadas

- Commit testado.
- Data e hora do teste.
- URL da API usada pelo app.
- Perfil usado no teste.
- Largura da tela.
- Captura antes/depois quando houver ajuste visual.
- Observacao se o dado veio de API real ou modo demonstracao.
