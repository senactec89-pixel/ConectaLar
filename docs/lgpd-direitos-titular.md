# Direitos do titular no ConectaLar

Atualizado em 16/10/2026. Este documento explica o comportamento tecnico atual. Ele nao substitui revisao juridica da politica de privacidade e dos prazos de retencao.

## Exportar meus dados

Na tela `Perfil > Seguranca`, o usuario escolhe **Exportar meus dados** e confirma a senha atual. A API gera um JSON versionado e o app abre o compartilhamento nativo do aparelho para que o titular escolha onde guardar o arquivo.

O arquivo inclui dados cadastrais, foto, perfil, enderecos, ofertas, disponibilidade, documentos enviados, solicitacoes, mensagens enviadas, avaliacoes, denuncias relacionadas, notificacoes, favoritos, aceites e historico de pedidos de privacidade. Documentos e foto sao representados em Base64 quando o arquivo esta disponivel.

O arquivo nunca inclui hash de senha, token de sessao, codigo de verificacao, codigo de recuperacao ou segredo MFA. Identificadores de outras pessoas sao omitidos quando nao sao necessarios para explicar o registro ao titular.

## Excluir minha conta

O usuario escolhe **Excluir minha conta**, informa a senha atual e digita `EXCLUIR`. A operacao somente continua quando nao existem atendimentos aguardando resposta ou aceitos/agendados.

A exclusao:

- desativa a conta e invalida todos os tokens;
- substitui nome e e-mail por valores anonimos e remove telefone, foto e MFA;
- remove documentos de verificacao e seus arquivos privados;
- apaga notificacoes, favoritos, codigos de verificacao e recuperacao;
- remove localizacao, disponibilidade e dados publicos do perfil;
- substitui mensagens, descricoes de pedidos, comentarios e denuncias escritos pelo titular por textos neutros;
- preserva registros minimos de atendimento, aceite, avaliacao e moderacao quando a referencia e necessaria para seguranca, auditoria, defesa de direitos ou obrigacao legal.

A conta nao pode ser reativada pelo aplicativo. O mesmo e-mail e telefone ficam livres para um novo cadastro, pois a conta antiga passa a usar identificadores anonimos.

## Excecoes e seguranca

Contas administrativas nao podem se autoexcluir. Outro administrador deve desativa-las para preservar a auditoria e evitar perda acidental do controle do sistema.

Contas ainda sem e-mail verificado podem abrir `Seguranca e privacidade da conta` na tela de confirmacao de e-mail. A senha continua obrigatoria para exportar ou excluir.

Cada solicitacao fica registrada em `privacidade_solicitacoes` com tipo, status e datas, sem armazenar a senha informada. Os logs da API nao devem registrar corpos de requisicao nem o conteudo exportado.

## Implantacao e teste

1. Execute `npm run db:migration:run` no ambiente da API.
2. Reinicie a API com as variaveis atualizadas.
3. Crie uma conta descartavel de cliente e exporte os dados.
4. Confira que o JSON nao contem senha, token ou segredos de autenticacao.
5. Crie uma solicitacao em aberto e confirme que a exclusao e bloqueada.
6. Cancele a solicitacao, exclua a conta e confirme que o app volta ao login.
7. Confirme que o token antigo e o login antigo retornam `401`.
8. Para profissional, confirme que foto, documentos, disponibilidade e perfil publico deixam de existir.
