# Atualizacao de seguranca e catalogo - 11/10/2026

Esta nota complementa `docs/progresso.md` e `docs/pendencias.md` depois do commit `8fc1884`.

## Alteracoes implementadas

- Cadastro e edicao de perfil passam a validar telefone com DDD e impedir reutilizacao do mesmo numero normalizado em contas diferentes.
- Erro de senha atual invalida nao encerra mais uma sessao autenticada valida no Flutter.
- Categorias administrativas aceitam icones controlados pela API e exibem o icone escolhido na Home/listas.
- Solicitar atendimento separa erro de rede ao carregar enderecos do estado realmente vazio.
- Chat de atendimento encerrado exibe orientacao de conversa encerrada em vez do campo de envio.
- Solicitacao com oferta de preco "a combinar" preserva o preco nulo da oferta escolhida, sem herdar automaticamente o preco do perfil.

## Mantido por seguranca

- Login continua com mensagem generica de credenciais invalidas. Nao foi criada validacao publica de existencia de e-mail antes do login, para evitar enumeracao de contas.
- Icone de categoria e controlado por uma lista fechada. Upload livre de imagens para icones de catalogo continua fora do escopo por enquanto.
- Google login nao foi implementado sem Client IDs reais, politica de OAuth e validacao backend do token.

## Validacoes executadas

- `npm run typecheck`
- `npm test`
- `flutter analyze`
- `flutter test`
- `flutter test test\admin_visual_test.dart test\frontend_preview_test.dart test\senha_atual_sessao_test.dart`
- `git diff --check`
