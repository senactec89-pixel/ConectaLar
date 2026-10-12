# Entregas de front-end — 12/10/2026

Base: `main` em `c5e8a82`, após `git pull origin main`.
Escopo solicitado: oito etapas Flutter, mantendo paleta, regras e contratos existentes.

## Dependências confirmadas

O responsável confirmou nesta sessão que o colega ainda implementa as APIs de:

1. Confirmação de e-mail: faltam contrato de envio/reenvio/validação do código e resposta do cadastro/login para conta pendente.
2. Login Google: faltam contrato de troca da credencial, contas/perfis aceitos e configuração OAuth das plataformas. Tokens devem ser validados pelo servidor.
5. Conteúdo documental: falta acesso autenticado/autorizado ao arquivo, com tipo/nome do conteúdo e respostas de permissão/indisponibilidade. Referências privadas de armazenamento não são URLs para abrir diretamente.

Essas três etapas continuam pendentes de integração. Não foram criados endpoints presumidos, verificação local fictícia nem botões anunciando funções indisponíveis. Referências: RF001/RF002/RF023, RB01/RB10/RB15, P01/P02/P10/P15/P16. O pedido atual autoriza os fluxos; os contratos e credenciais devem vir da implementação do colega.

## Etapa 3 — Criar administrador

- Tela dedicada, acessível em **Admin → Contas → Criar administrador** (ícone no cabeçalho).
- Consome `POST /admin/usuarios/administradores`, mantendo a sessão do administrador que criou a conta.
- Nome, e-mail, telefone opcional, senha forte e confirmação; limites correspondem ao contrato existente.
- Envio bloqueia repetição; erros preservam os campos; sucesso retorna e atualiza a lista.
- Rotas administrativas exigem papel administrativo na interface; autorização definitiva continua na API.
- Paleta oficial preservada. Formulário conferido por widget tests em 360/390/412 px, texto 200% e teclado simulado.

Verificação: `flutter analyze --no-pub` sem problemas; 19 testes selecionados aprovados (`admin_criar_administrador_test.dart`, `admin_visual_test.dart`, `frontend_preview_test.dart`). São testes com transporte simulado, não homologação com API/MySQL ou aparelho físico.
