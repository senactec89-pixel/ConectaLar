# Catalogo de servicos: contrato administrativo

Estas rotas sao implementadas na API e exigem sessao de administrador, MFA e
termos atuais, como as demais rotas administrativas. O catalogo inicia vazio.
Criar ou ativar um servico nao habilita profissionais nem libera contratacoes.
O arquivo `scripts/catalogo-proposto.json` reune 37 servicos propostos para
revisao. `importarCatalogoProposto` e uma carga explicita para teste/demo, nao
executada por migrations ou inicializacao da API; novos itens entram pausados,
sem alterar nomes, textos ou estados ja existentes.

## Categorias existentes

- `GET /categorias`: lista publica de categorias ativas.
- `GET /categorias/admin`: lista administrativa, com filtros e paginacao.
- `POST /categorias`: cria categoria; campos `nome`, `icone` e `ativo`.
- `PATCH /categorias/:id`: edita nome, icone e/ou ativo.

## Servicos por categoria

- `GET /admin/catalogo/categorias/:categoriaId/servicos`: lista administrativa;
  filtros opcionais `ativo=true|false`, `termo`, `pagina` e `limite` (ate 100).
  Resposta: `{ "paginacao": {...}, "servicos": [...] }`.
- `POST /admin/catalogo/categorias/:categoriaId/servicos`: cria servico.
- `PATCH /admin/catalogo/categorias/:categoriaId/servicos/:servicoId`: altera
  somente os campos informados; um ID pertencente a outra categoria retorna 404.

Exemplo de criacao:

```json
{
  "nome": "Montagem de cadeira",
  "descricao": "Montagem conforme o manual do fabricante.",
  "inclusoes": "Montagem de cadeira convencional.",
  "exclusoes": "Sem reparo estrutural ou adaptacoes.",
  "ativo": false
}
```

Nome obrigatorio, de 2 a 90 caracteres; textos opcionais aceitam de 1 a 1000
caracteres ou `null`. O valor de `ativo` e booleano e, se omitido ao criar,
inicia como `false`. A resposta de criacao/edicao tem a forma:

```json
{ "servico": { "id": 7, "categoriaId": 3, "nome": "Montagem de cadeira", "descricao": null, "inclusoes": null, "exclusoes": null, "ativo": false } }
```

O exemplo de resposta mostra textos opcionais nulos; se informados, retornam
os valores salvos. Para pausar ou reativar, use `PATCH` com `{ "ativo": false }`
ou `{ "ativo": true }`. Nao existe exclusao fisica nem mudanca de categoria por
esta API. Nomes nao podem repetir dentro da mesma categoria. Categoria inativa
impede ativar um servico. Criacao e edicao geram auditoria na mesma transacao.

## Ofertas dos profissionais

`GET /categorias/:categoriaId/servicos` lista os servicos ativos de uma categoria
ativa, com `pagina` e `limite`. E apenas consulta ao catalogo; disponibilidade
para contratacao depende da habilitacao e das demais regras da API.

O profissional usa `PUT /profissionais/me/servicos` para enviar a lista completa
das suas ofertas. Ofertas omitidas sao pausadas. Para criar uma oferta, informe
`servicoCatalogoId` de um servico ativo; a categoria e o nome sao determinados
pela API. `categoriaId`, se informado, deve corresponder ao catalogo.

```json
{ "servicos": [{ "servicoCatalogoId": 7, "precoInicial": 120, "duracaoMinutos": 120, "ativo": true }] }
```

`GET /profissionais/me/servicos` devolve o ID da oferta e `servicoCatalogoId`,
alem de `ativo` e `disponivelNoCatalogo`. O primeiro representa a escolha do
profissional; o segundo indica se categoria e servico continuam ativos. A oferta
fica indisponivel quando o catalogo ou a categoria e pausado, sem apagar dados.
Uma mesma pessoa possui no maximo uma oferta por servico do catalogo; salvar
novamente o mesmo servico reaproveita a oferta anterior.

Ofertas antigas sem vinculo sao preservadas e retornam `servicoCatalogoId: null`.
Podem ser atualizadas pelo proprio ID mantendo nome e categoria; novas ofertas
exigem servico do catalogo. Nao e possivel trocar o servico de uma oferta
existente: crie outra oferta e pause a antiga. Nao ha mapeamento automatico por
nome, e a integracao das telas continua sendo uma etapa separada.

## Busca e historico

`GET /profissionais?servicoCatalogoId=7` e `POST /profissionais/busca` com
`servicoCatalogoId` filtram por oferta ativa do servico e por categoria e
servico ativos. A busca por distancia tambem respeita o raio informado e a area
do profissional. O retorno mostra a oferta correspondente, mas o campo
`podeReceberSolicitacoes` continua sujeito a habilitacao.

Novos pedidos exigem uma oferta vinculada ao catalogo. A API ainda bloqueia
contratacoes pela habilitacao pendente. O `servicoSnapshot` preserva nome,
categoria e escopo no momento do pedido; pedidos antigos nao recebem valores
inventados e podem retornar snapshot nulo. As migrations foram testadas em banco
descartavel e devem ser aplicadas antes de usar esses campos em outro ambiente.
