# Ajustes dos seis fluxos — 11/10/2026

Escopo solicitado: separar demonstração, ações por papel, configurações de conta, agenda concorrente, avaliações e cadastro/ofertas. Base sincronizada: `35be08f` em `senactec89-pixel/ConectaLar`. A API foi ajustada onde estes fluxos exigem persistência e autorização.

## Implementado

- Home/busca consultam a API e mostram erro com nova tentativa se ela falhar. Não inserem profissionais fictícios. Rotas privadas pedem login e verificam o tipo de conta.
- Dados locais fictícios na navegação sem sessão exigem `--dart-define=CONECTALAR_DEMO=true`, com identificação da versão de demonstração. Contas autenticadas continuam consultando a API. Testes anteriores ativam o modo fictício explicitamente.
- Detalhes mostram aceitar/recusar para o profissional participante e cancelar/concluir para o cliente participante, conforme o estado permitido. A API continua autorizando cada ação.
- Profissional/admin consultam dados da sessão nas configurações, sem chamar `clientes/me`. Há caminhos para segurança, notificações e logout real. Os dados da conta são consultados sem inventar um endpoint de edição para estes papéis; a edição do perfil profissional continua em sua tela própria.
- Agenda lê `enderecoAtendimento` e aceita o alias anterior `enderecoCompleto`, mostrando somente o endereço liberado pela API.
- Transições usam transação e bloqueio do perfil/pedido em ordem consistente. O aceite revalida disponibilidade e impede dois atendimentos `aceita_agendada` na mesma data e horário, inclusive simultâneos. Botões ficam desabilitados durante envio; conflito informa o motivo e atualiza o pedido.
- Disponibilidade é publicada em transação, sem misturar atualizações simultâneas. A rota literal `/profissionais/me/disponibilidade` precede o parâmetro público `:id`, corrigindo o carregamento da própria agenda.
- Datas MySQL `DATE` permanecem strings `YYYY-MM-DD`, sem deslocamento pelo fuso do processo; timestamps continuam datas com fuso.
- Profissional pode avaliar o cliente após conclusão. Cada participante recebe o indicador individual `avaliado`, inclusive durante moderação. Avaliações aprovadas aparecem no perfil público e na área profissional. Média/quantidade consideram todas as aprovadas; a lista retorna as 50 mais recentes sem identificadores de clientes/pedidos.
- Edição de dados profissionais e região usa o mesmo formulário validado e recarrega o perfil após salvar. O formulário preenche os dados atuais e mantém as ofertas. Preço opcional segue como número ou `null`, com validação Flutter/API e limite de `DECIMAL(10,2)`.
- Preços de solicitações preservam centavos e `null` segue como valor a combinar, sem virar zero.
- Recargas de listas usam callbacks síncronos de estado, corrigindo a falha de atualização após salvar ou tentar novamente.
- Cadastro novo segue de “Salvar e continuar” para serviços. Categorias são escolhidas pelo nome. Ofertas mantêm o ID durante edição; itens omitidos são desativados e preservados no histórico.
- Cliente envia o ID da oferta escolhida. A API valida titularidade/atividade e registra ID, nome e preço no pedido, derivando a categoria da oferta. Alterar a oferta não muda o nome registrado no pedido. Pedidos anteriores continuam compatíveis, com campos novos nulos.

## Atualizar o ambiente da equipe

Antes de iniciar a API atualizada, com as variáveis do banco de desenvolvimento configuradas:

```bash
cd apps/api
npm ci
npm run db:migration:run
npm run build
npm start
```

A migration `OfertaDaSolicitacao1760114000000` adiciona vínculo/nome da oferta e índices de agenda. Foi aplicada somente no banco descartável desta tarefa; o banco de cada desenvolvedor precisa recebê-la. O SQL legado não foi alterado.

Uso real local (ajustar host/porta ao dispositivo):

```bash
flutter run --dart-define=CONECTALAR_API_BASE_URL=http://127.0.0.1:3012
```

Demonstração com dados locais fictícios:

```bash
flutter run --dart-define=CONECTALAR_DEMO=true
```

## Validação

- Testes Flutter usam HTTP simulado e cobrem fallback desativado, identificação da demo, login obrigatório, ações por participante, avaliação do cliente, avaliação já enviada, configurações/logout, edição/continuidade do cadastro, categoria/oferta e preço.
- Responsividade: avaliações recebidas em 360/390/412 com texto ampliado, detalhes com avaliação liberada em 360 e a suíte existente de rotas/telas profissionais/admin.
- Testes HTTP reais em `apps/api/test/integration/fluxos.test.mjs` cobrem MySQL, oferta escolhida/IDs/histórico, endereço protegido/liberado, aceites concorrentes, disputa aceitar/recusar, disponibilidade atual, cancelamento, avaliações individuais/moderação/média e logout.
- Ambiente: Node 22.23.3, MySQL 8.0.46 temporário em loopback, banco exclusivo `conectalar_task_test`, 15 migrations aplicadas. Nenhum banco de produção foi usado.

Para repetir a integração, subir uma API local com banco **descartável**, migrations e seed demo. Os testes criam contas/pedidos/avaliações sem limpeza automática; não apontar para banco de trabalho. Informar as variáveis abaixo antes de `npm run test:integration`:

```text
CONECTALAR_TEST_API_URL=http://127.0.0.1:<porta-da-api-de-teste>
CONECTALAR_TEST_ADMIN_EMAIL=<administrador-do-banco-de-teste>
CONECTALAR_TEST_ADMIN_SENHA=<senha-do-banco-de-teste>
```

Sem as três variáveis, a suíte é ignorada, sem alegação de integração validada.

## Limites preservados

- P06/P12: bloqueio considera o mesmo horário inicial. Sobreposição por duração e capacidade por empresa/executor dependem de regras ainda a definir. Nenhuma duração/capacidade implícita foi criada.
- P04/P13: pedido registra nome/preço da oferta; endereço segue as permissões e referência existentes. Snapshot e retenção do endereço não foram redefinidos.
- Sem novos estados, pagamento interno, confirmação pelo chat ou garantia absoluta do selo.
- Checagem mobile no navegador não substitui homologação no aparelho nem validação manual do seletor nativo de documentos.

## Resultados registrados

- `flutter analyze`: sem problemas.
- `flutter test`: 31 testes aprovados, incluindo 13 regressões dos fluxos alterados.
- API `npm run typecheck` e `npm test`: aprovados; 9 testes da suíte padrão.
- API `npm run test:integration`: 10 cenários aprovados (11 resultados no relatório Node, que inclui o grupo).
- Migrations: as 15 aplicadas em banco descartável; a última também revertida e reaplicada em um segundo banco descartável.
- OpenAPI: YAML lido e referências internas conferidas, sem referências faltantes.
- Capturas mobile de área profissional, conta e avaliações em navegador com API/MySQL de teste. Avaliações conferidas em 360/390/412 pixels; as imagens usam contas e registros demo do banco descartável.
- Commits de implementação: `af57231` (API) e `df45b8d` (Flutter/testes).
- `flutter build web --no-wasm-dry-run`: concluído. O build informa aviso sobre a fonte Cupertino já referenciada pelo projeto; MaterialIcons foi incluída. Não houve erro de compilação.

### Capturas da versão final

- [Área profissional em 390 px](evidencias/fluxos-2026-10-11/area-profissional-390.png).
- Avaliações recebidas em [360 px](evidencias/fluxos-2026-10-11/avaliacoes-360.png), [390 px](evidencias/fluxos-2026-10-11/avaliacoes-390.png) e [412 px](evidencias/fluxos-2026-10-11/avaliacoes-412.png).
- [Configurações da conta profissional em 390 px](evidencias/fluxos-2026-10-11/conta-profissional-390.png).
