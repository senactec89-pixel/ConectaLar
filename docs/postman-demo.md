# ConectaLar - seed demo e Postman

Este roteiro prepara dados locais para testar os fluxos principais da API no Postman. Use apenas em ambiente local/desenvolvimento.

**Política atual:** novas solicitações e aceites estão deliberadamente bloqueados enquanto a habilitação profissional não for concluída. A coleção espera HTTP `409` no passo de aceite. Os pedidos que o seed grava diretamente no banco são fixtures históricas para leitura/moderação de módulos, não demonstram que novas contratações podem ser abertas. Não use o seed nem SQL para contornar a regra.

## Dados criados

O comando de seed cria ou atualiza:

- Cliente: `cliente.demo@conectalar.local`
- Profissional: `profissional.demo@conectalar.local`
- Admin: `admin.demo@conectalar.local`
- Senha comum: `ConectaLarDemo123!`
- Categorias base
- Perfil profissional verificado
- Servicos/ofertas do profissional
- Disponibilidade de segunda a sexta
- Perfil e endereco do cliente
- Solicitacoes em estados formais diferentes
- Mensagens, avaliacao pendente, denuncia pendente, documentos de verificacao e notificacoes

O endereco completo demo fica em `cliente_enderecos`, mas os endpoints de painel/listagem nao devem expor esse valor antes de autorizacao valida.

## Como preparar

No terminal integrado do VS Code, na pasta `apps/api`:

```powershell
npm.cmd run db:migration:run
npm.cmd run db:seed:demo
npm.cmd run dev:local
```

Se a API ja estiver rodando em outro terminal, rode apenas migrations/seed e reinicie a API se necessario.

## Como usar no Postman

1. Importe a colecao:
   `apps/api/postman/ConectaLar Demo.postman_collection.json`
2. Confira a variavel `baseUrl`.
   Valor local padrao: `http://127.0.0.1:3012`
3. Execute em ordem:
   - `00 Health`
   - `01 Login cliente`
   - `02 Login profissional`
   - `03 Login admin`
   - demais requests da colecao

Os logins salvam automaticamente os tokens nas variaveis da colecao.

## O que a colecao valida

- API local respondendo.
- Login dos tres papeis demo.
- Painel profissional.
- Servicos/ofertas do profissional.
- Solicitacoes do cliente.
- Bloqueio de aceite de um pedido pendente com HTTP `409`.
- Painel administrativo.
- Listagem administrativa de usuarios.
- Bloqueios de permissao:
  - cliente nao acessa painel admin.
  - cliente nao acessa painel profissional privado.

## Observacao importante

O seed e repetivel, mas recria os dados vinculados aos usuarios demo. Nao use esses e-mails em dados reais.
