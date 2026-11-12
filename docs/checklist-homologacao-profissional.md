# Homologação manual — profissional e empresa

Use aparelho Android real e ambiente de teste com API, MySQL e migrations atuais. Para empresa, use conta separada. Não use documentos ou dados pessoais reais.

**Política atual:** profissionais e empresas permanecem indisponíveis para novas solicitações. Cadastro, perfil, ofertas, disponibilidade e envio documental podem ser homologados, mas não se deve esperar receber, aceitar ou recusar novos pedidos. Documento aprovado ou telefone confirmado isoladamente não libera atendimento. Não altere banco, flags ou fixtures para contornar o bloqueio.

## Cadastro e perfil

- [ ] Ler e aceitar termos; cadastrar profissional autônomo.
- [ ] Cadastrar empresa em conta de teste.
- [ ] Testar validação de senha forte.
- [ ] Entrar, sair e entrar novamente.
- [ ] Preencher/editar perfil, região, categoria e ofertas.
- [ ] Salvar oferta com preço e oferta “a combinar”; confirmar persistência sem criar contratação.
- [ ] Confirmar que editar uma oferta existente não cria duplicata.

## Disponibilidade e agenda

- [ ] Criar, editar e remover horários semanais.
- [ ] Conferir a agenda mensal e os bloqueios/disponibilidades configurados; pedidos existentes só podem ser registros legados de teste.
- [ ] Testar horário fora da disponibilidade.
- [ ] Não aceitar pedidos novos: a API deve responder HTTP `409` sem mudança de estado; o log seguro deve registrar `PROFISSIONAL_HABILITACAO_PENDENTE`.
- [ ] Registrar como o sistema se comporta em horários sobrepostos com durações diferentes; a regra final depende de decisão de produto.

## Pedidos, endereço e chat

- [ ] Confirmar que não há ação para aceitar/recusar novos pedidos e que a indisponibilidade é explicada sem expor dados privados.
- [ ] Tentar aceitar diretamente pela API um pedido pendente de fixture isolada, se disponível; confirmar bloqueio e ausência de mudança de estado.
- [ ] Confirmar que a tentativa bloqueada não revela endereço completo nem cria acesso ao chat.
- [ ] Chat, encerramento e histórico só podem ser testados em registros legados/fixtures isoladas; não simular habilitação nem criar pedido para alcançá-los.

## Documentos e avaliações

- [ ] Abrir seletor nativo e selecionar PDF válido de até 5 MB.
- [ ] Repetir com JPEG e PNG.
- [ ] Testar arquivo inválido, arquivo acima de 5 MB e cancelar o seletor.
- [ ] Confirmar nome/tipo do arquivo e retorno de sucesso/erro.
- [ ] Conferir status pendente e atualização após decisão administrativa.
- [ ] Conferir avaliações recebidas, média e quantidade após avaliação aprovada.

## Resultado

- [ ] Fluxo autônomo concluído.
- [ ] Fluxo de empresa concluído.
- [ ] Falhas, passos, horários e capturas registrados sem expor documentos.
