# Fase 2 — proposta de contrato para habilitação profissional

**Estado:** proposta técnica para revisão da equipe; não descreve uma API já implementada.

**Atualizado em:** 02/11/2026.

**Base de produto:** [diretrizes da fase 1](proposta-politica-habilitacao-profissional.md). Comparar com `handoff-habilitacao-profissional.md` quando o arquivo estiver disponível neste checkout.

O bloqueio atual deve permanecer: `podeAtender` continua `false` e a ação administrativa `aprovar` continua indisponível até a política de antecedentes, a retenção, o contrato, a implementação e os testes receberem as aprovações necessárias. Esta proposta não altera os estados formais das solicitações nem a capacidade já decidida de **um atendimento simultâneo por perfil**, inclusive empresa.

## O que já existe

| Recurso | Contrato atual | Reaproveitamento proposto |
| --- | --- | --- |
| Situação privada | `GET /profissionais/me/habilitacao` | Preservar; acrescentar resumo das evidências e da versão do dossiê sem devolver dados biométricos ou criminais. |
| Identidade e telefone | Rotas `/profissionais/me/habilitacao/identidade` e `/telefone` | Preservar consentimento, flags, idempotência e consulta autenticada; confirmação de telefone prova posse do canal. |
| Documentos | `GET/POST /profissionais/me/documentos`; moderação e arquivo em `/documentos-verificacao` | Reutilizar upload privado, leitura administrativa autenticada e validações de arquivo. Definir tipo e critérios de comprovante de experiência antes de alterar o catálogo documental. |
| Revisão | `POST /profissionais/me/habilitacao/revisao`; `GET /admin/profissionais/habilitacoes`; `PATCH /admin/profissionais/{id}/habilitacao` | Preservar pedido de revisão, filtros, suspensão, reabertura, MFA e auditoria. O `PATCH` atual não aprova e não representa dois pareceres. |
| Pedidos e catálogo | `POST /solicitacoes`, `PATCH /solicitacoes/{id}/aceitar`, perfil público | Continuar validando a habilitação no servidor e apresentar somente disponibilidade pública genérica. |

O [OpenAPI atual](../apps/api/openapi.yaml), o [controlador de habilitação](../apps/api/src/verificacao/habilitacao.controller.ts) e a [regra de bloqueio](../apps/api/src/verificacao/habilitacao-profissional.ts) são o ponto de partida. As rotas abaixo são **candidatas**, sujeitas à revisão do contrato antes de codificar.

## Dossiê individual e vínculo com empresa

- Um dossiê pertence a uma **pessoa executora**, vinculada a uma conta identificada. A empresa possui vínculos ativos com executores, não herda a identidade ou a habilitação deles. Convite e aceite do vínculo exigem autenticação de cada lado; desligamento revoga o vínculo.
- O dossiê referencia evidências existentes: documento aprovado, resultado de identidade, telefone confirmado e comprovante profissional (certificado, curso ou experiência comprovável). Guarda estado, validade, versão e referências privadas; não copia selfie, OTP, CPF ou detalhes criminais para uma tabela de resumo.
- Cada alteração relevante incrementa `versaoDossie`. Dois pareceres administrativos distintos devem apontar para **a mesma versão**. Alteração de evidência, vínculo, telefone ou validade torna parecer anterior insuficiente; a reavaliação é explícita.
- Um executor verificado deve estar indicado **antes do aceite** de pedido feito à empresa. A transação que registra o aceite deve conferir o estado persistido e válido da habilitação, sem chamada de rede ao fornecedor dentro da transação. A empresa continua limitada a um atendimento simultâneo por perfil, conforme P06 já aprovada.
- Troca de executor após aceite exige revalidação do substituto, atualização auditada do vínculo com o pedido e aviso ao cliente. O substituto não recebe o endereço por herdar a permissão do executor anterior.

## Estados e visibilidade propostos

Manter `pendente`, `em_analise` e `suspenso` como estados atuais da habilitação. `habilitado` é um **estado futuro proposto**, inalcançável nesta versão. Resultado `revisao_necessaria` ou `expirada` pode continuar como motivo/etapa privada; decidir sua representação final no contrato, sem criar estados novos de solicitação.

| Papel | Resposta permitida |
| --- | --- |
| Público/cliente | Disponibilidade genérica para atendimento; nenhum documento, motivo privado ou detalhe de verificação. |
| Profissional/executor titular | Etapas, validade e motivos codificados que a política permita divulgar, além de recurso/revisão. Sem dados de outro executor. |
| Empresa vinculada | Situação operacional mínima do executor para indicar/aceitar; não recebe o dossiê pessoal inteiro. |
| Admin autorizado com MFA | Dossiê necessário para a análise, arquivo privado por rota autenticada e histórico de pareceres/auditoria. |

## Operações candidatas

| Operação candidata | Entrada e saída mínimas | Autorização e efeito |
| --- | --- | --- |
| `GET /admin/profissionais/{id}/habilitacao/dossie` | Versão, referências de evidências, etapas, validade e pareceres; sem conteúdo bruto de fornecedor | Admin com MFA; acesso auditável e limitado à finalidade. |
| `POST /admin/profissionais/{id}/habilitacao/pareceres` | `versaoDossie`, `decisao` enumerada, `motivo` enumerado e chave de idempotência; retorna estado e pareceres mínimos | Admin ativo com MFA confirmado na sessão; contas distintas; sem autoanálise; transação com auditoria. Repetição não cria segundo voto. `aprovar` não ativa atendimento enquanto D4/D7 e os critérios finais estiverem bloqueados. |
| `GET /empresas/me/executores` e fluxo de convite/aceite/desvinculação | IDs opacos do vínculo, estado operacional, datas | Empresa administra vínculos; executor confirma sua participação; nenhuma consulta ao dossiê pessoal por simples vínculo. Desvincular invalida atribuições futuras. |
| `PATCH /solicitacoes/{id}/aceitar` (extensão) | Empresa informa `executorId`; profissional individual preserva fluxo atual | Na mesma transação, verificar empresa, vínculo ativo, executor habilitado, versão válida, capacidade e horário. Sem executor elegível, manter pedido pendente e endereço oculto. |
| `PATCH /solicitacoes/{id}/executor` (proposta) | ID do substituto e identificador de operação | Após aceite, revalidar o novo executor e vínculo, auditar a troca e avisar o cliente. Definir antes quem pode pedir a troca e o efeito sobre o atendimento aceito. |

O desenho final deve definir paginação, formatos exatos, erros e compatibilidade com o Flutter. Erros candidatos: `PROFISSIONAL_HABILITACAO_PENDENTE` (já existe), `EXECUTOR_NAO_HABILITADO`, `VINCULO_EXECUTOR_INVALIDO`, `DOSSIE_VERSAO_DESATUALIZADA` e `SEGUNDO_PARECER_MESMO_ADMIN`. O servidor deve responder `403` para falta de permissão/MFA e evitar revelar dossiês privados por IDs adivinhados.

## Invalidação, avisos e pedidos aceitos

- Expiração de verificação, troca de telefone ou desligamento de executor bloqueia imediatamente novos pedidos e aceites na API. Pedidos já aceitos entram em revisão humana; não são cancelados automaticamente por esta diretriz.
- A API registra avisos para cliente, executor/empresa e administradores imediatamente. A mensagem ao cliente informa apenas a indisponibilidade e o próximo passo, sem motivo privado. Entrega por push depende de um canal configurado; falha de entrega exige registro e nova tentativa, sem restaurar habilitação nem desfazer o bloqueio.
- Rever a autorização do endereço em **todos** os caminhos de leitura: detalhe, lista, agenda e mensagens/exports quando aplicável. O vínculo com o pedido e a habilitação do executor precisam ser validados no servidor.
- Caso inconclusivo ou contestado permanece bloqueado e oferece revisão humana por dois administradores distintos com MFA. Definir prazo, fila, conflitos de interesse e efeito dos pareceres divergentes antes da implementação.

## Arquivos, privacidade e auditoria

- Preservar armazenamento privado e leitura autenticada. PDF/JPEG/PNG, limite, assinatura do arquivo e varredura antimalware seguem as regras atuais; o ambiente real precisa configurar scanner e armazenamento. Nunca enviar o arquivo ou a URL permanente no perfil público.
- Registrar ator, alvo, ação, motivo codificado, versão do dossiê e instante na mesma transação da decisão. Evitar texto livre com CPF, dados criminais, biometria ou documentos em logs/auditoria. A consulta administrativa ao dossiê também deve deixar rastro proporcional.
- Exportação e exclusão da conta já existem, mas entidades futuras de dossiê, vínculo, parecer e arquivo precisam entrar no fluxo. Prazos, descarte e tratamento de backup permanecem **bloqueados por D7**; antecedentes permanecem **bloqueados por D4**. Não coletar esses dados antes da política aprovada.

## Condições para aprovar o contrato e implementar

1. Revisar esta proposta com o briefing original e resolver os critérios documentais, conflito de interesse, parecer divergente, prazos e vínculo do executor.
2. Obter decisões adequadas sobre D4 (antecedentes) e D7 (retenção) antes de qualquer caminho que produza `habilitado` ou `podeAtender: true`.
3. Atualizar OpenAPI **depois** da aprovação do contrato, versionar migrations e alinhar Flutter. Testar concorrência de dois pareceres, versão obsoleta, vínculos, aceite com executor, troca, endereço, suspensão, avisos, arquivos maliciosos, exportação e exclusão com MySQL isolado.
4. Homologar com contas de cliente, profissional, empresa e dois administradores com MFA; manter o bloqueio ativo até as verificações de segurança e privacidade serem concluídas.
