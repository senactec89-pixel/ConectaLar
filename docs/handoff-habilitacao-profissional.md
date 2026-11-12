# Handoff: habilitacao manual de profissionais

Este documento orienta a conversa entre os dois responsaveis e o trabalho do Codex. Ele nao e uma politica aprovada, parecer juridico, autorizacao para coletar documentos reais ou ordem para liberar contratacoes. Preencher as decisoes pendentes antes de implementar qualquer caminho que possa habilitar um profissional.

## Objetivo

Definir e construir, em etapas, um processo proporcional para avaliar profissionais que podem entrar na residencia de clientes. O admin pode liberar manualmente qualquer perfil somente no ambiente local para testar o fluxo; isso nao habilita atendimento real. Qualquer habilitacao real continua bloqueada ate que as regras tenham sido aprovadas e homologadas.

Uma imagem legivel, uma selfie, um telefone confirmado ou um documento aprovado isoladamente nao provam identidade, qualificacao, ausencia de antecedentes nem seguranca. Nao mostrar selos ou textos que deem essa impressao.

## Estado atual confirmado no codigo

- A acao administrativa `aprovar` continua recusada com `409 HABILITACAO_DEPENDENCIAS_PENDENTES` para habilitacao real.
- Para testar o ciclo local, `start-local.cmd` ativa `HABILITACAO_MANUAL_LOCAL`; administrador com MFA pode selecionar `Liberar somente para teste local` para um perfil da base local. A decisao e auditada, nao aceita em producao e nao libera atendimentos reais.
- Fora dessa excecao explicitamente local, a API bloqueia solicitacoes e aceites com `409 PROFISSIONAL_HABILITACAO_PENDENTE`.
- Existe revisao documental administrativa e um fluxo separado de confirmacao manual por WhatsApp, ambos sem liberar atendimentos.
- O fluxo de WhatsApp comprova somente acesso ao numero/conta naquele momento; nao e prova de identidade.
- O upload documental atual aceita tipos existentes, mas nao implementa selfie/foto de rosto nem comparacao facial. Nao inventar um tipo de documento para contornar a validacao.
- O armazenamento de documentos usa referencias privadas local/R2; os detalhes de scanner, acesso administrativo, exclusao e backups devem ser confirmados no codigo antes de ampliar o fluxo.

## O que os dois responsaveis precisam decidir

Registrem as respostas em uma decisao datada, com quem aprovou. Se uma resposta depender de advogado, privacidade ou fornecedor, mantenham-na como bloqueada ate receber essa validacao.

| Decisao | Pergunta que precisa de resposta | Nao presumir |
| --- | --- | --- |
| Escopo inicial | Em qual cidade/regiao, categorias e volume maximo seria feito um piloto supervisionado? | Cobertura nacional ou disponibilidade geral |
| Pessoa que atende | Profissional individual, empresa ou ambos? Para empresa, cada pessoa que entrara na casa sera cadastrada e revisada individualmente? | Que validar o representante valida toda a equipe |
| Identidade | Quais documentos sao estritamente necessarios, como tratar divergencia de nome e qual alternativa existe para documento inacessivel? | Que uma foto legivel prova autenticidade |
| Foto/selfie | A foto e realmente necessaria? Qual finalidade, base legal, aviso, acesso, prazo, exclusao e alternativa serao aprovados? | Que parede clara, selfie ou comparacao visual e prova de vida/biometria confiavel |
| Telefone | O processo manual de WhatsApp continuara? Que fato exatamente confirma, como tratar numero alterado e como comunicar seus limites? | Que telefone confirmado confirma identidade ou titularidade civil |
| Qualificacao | Para cada categoria, quais licencas/certificados sao legalmente exigidos, quem pode emiti-los e como conferir validade? | Certificado universal para todas as categorias |
| Antecedentes | Serao consultados? Em quais fontes legais, categorias, finalidade e criterio proporcional? Como tratar homonimos, dados desatualizados e contestacao? | Busca informal na internet, processo como condenacao ou reprova automatica |
| Resultado adverso/inconclusivo | Quais estados, justificativas comunicaveis, correcao, recurso e segunda revisao serao oferecidos? | Rejeicao definitiva sem explicacao e contestacao |
| Retencao | Por quanto tempo cada classe de dado e guardada? Ha prazo diferente para selfie, identidade, qualificacao, auditoria e backups? | Aplicar 72h a todo documento sem decisao; 72h de revisao nao significa automaticamente 72h de retencao |
| Operacao | Quem revisa, quem substitui, quando e como se escala incidente, e qual prazo de analise sera prometido? | Que um SLA de 72h esteja cumprido sem equipe/cobertura para isso |
| Liberacao | Quais evidencias e aprovacoes sao obrigatorias para liberar, suspender, expirar e revogar a habilitacao? | Que um administrador possa liberar por um botao sem pre-condicoes verificadas |

### Acordo minimo antes de coletar dados reais

1. Aprovar aviso de privacidade, finalidade, base legal, necessidade, retencao, direitos do titular e canal de contestacao com orientacao juridica apropriada.
2. Definir a matriz de requisitos por categoria e o tratamento de profissionais de empresas.
3. Confirmar armazenamento privado, antivirus, autorizacao por papel/MFA, auditoria, exclusao e comportamento de backups.
4. Definir revisores e procedimento escrito; treinar ambos os responsaveis com casos ficticios.
5. Somente entao abrir coleta real, inicialmente sem liberar contratacoes.

## Plano de trabalho do amigo

### Fase A: decisao e contrato (sem mudar a regra de liberacao)

- Ler este handoff, `docs/habilitacao-profissional.md`, `docs/verificacao-manual-profissional.md` e o fluxo atual em `apps/api/src/verificacao/`.
- Fazer com o outro responsavel uma reuniao curta para preencher a tabela de decisoes. Marcar cada item como `decidido`, `depende de juridico/fornecedor` ou `adiado`, com responsavel e data.
- Especificar o contrato da API com os estados e campos estritamente necessarios. O contrato deve distinguir pelo menos: nao enviado, recebido, em analise, precisa de reenvio, inconclusivo, analisado e expirado. Esses estados sao uma proposta tecnica; nomes e transicoes precisam ser acordados.
- Apresentar o contrato ao responsavel pelo Flutter antes de codificar. Nao duplicar o trabalho de interface em arquivos Flutter sem combinacao.
- Manter `podeAtender=false`, a recusa da acao `aprovar` e o bloqueio 409. Fase A nao altera politica, migrations nem comportamento de contratacao.

### Fase B: backend de caso documental (somente depois do contrato e dos requisitos de privacidade)

- Criar um caso/dossie de habilitacao por profissional, com itens exigidos derivados de uma matriz versionada por categoria. Guardar estado, datas, referencia opaca do arquivo e codigos de motivo; evitar CPF/documento integral, imagem, codigo de WhatsApp ou narrativas sensiveis em auditoria/logs.
- Permitir envio autenticado somente pelo titular, para seu proprio caso, validando tipo real do arquivo, tamanho, quantidade, extensao/MIME/conteudo, limites de requisicao, antivirus e armazenamento privado. O cliente nunca escolhe referencia, dono, estado de revisao ou resultado.
- Servir visualizacao administrativa com autorizacao estrita, MFA e resposta sem URL publica/permanente. Revisar politica de cache e download; nao mandar documento por e-mail, chat ou notificacao.
- Oferecer operacoes administrativas explicitas por item: marcar revisao documental limitada, pedir reenvio com codigo de motivo, indicar inconclusivo ou encerrar conforme politica aprovada. Exigir motivo enumerado e manter possibilidade de segunda revisao/contestacao segundo a decisao.
- Fazer cada mudanca de estado e sua auditoria atomicas na mesma transacao. Auditar ator, alvo, acao, item, motivo codificado, horario e identificador de correlacao; nunca o conteudo ou segredo do arquivo.
- Implementar exclusao/expiracao idempotente: retirar referencia do caso, apagar objeto do storage e tratar falhas/retries. Definir como a politica aprovada se aplica a replicas e backups; nao afirmar exclusao completa se isso nao estiver tecnicamente garantido.
- Se aprovado coletar selfie, tratar como uma classe de dado separada e de maior risco: nao implementar reconhecimento facial, comparacao biometrica ou prova de vida propria nesta tarefa. Criar apenas o fluxo de upload/revisao e prazo exatamente conforme decisao documentada. Prazo vencido nunca aprova automaticamente; deve expirar e exigir novo envio ou encerrar conforme regra aprovada.
- Atualizar OpenAPI, migration, configuracao e docs. Migration deve ter indices/constraints necessarios, ser reversivel sem apagar auditoria/dados silenciosamente e ser testada em MySQL descartavel antes de qualquer ambiente compartilhado.

### Fase C: testes e entrega

- Testar MySQL real descartavel: migration nova e sequencia completa, constraints, concorrencia de decisoes, rollback, exclusao/idempotencia e transacao de auditoria.
- Testar autorizacao: cliente nao le nem altera dossie; profissional A nao acessa profissional B; admin sem MFA nao ve arquivo nem decide; admin autorizado so ve o escopo permitido.
- Testar upload hostil/invalido, arquivo infectado, scanner indisponivel, R2/storage indisponivel, tamanho excedido, MIME falso, repeticao de requisicao e erro parcial de upload. Falha de storage/scanner deve falhar fechada: nenhum documento vira revisavel/aprovado.
- Testar transicoes validas/invalidas, reenvio, telefone alterado, mudanca de categoria e expiracao. Nenhum desses eventos deve liberar atendimento implicitamente.
- Testar logs e respostas para ausencia de documento integral, selfie, token, codigo OTP, URL assinada ou segredo.
- Entregar PR pequeno com: contrato, decisao aprovada vinculada, migrations, testes e checklist de deploy/rollback. Indicar claramente o que nao foi testado.

## Contrato de API a propor (nao e contrato aprovado)

O amigo deve desenhar e discutir os endpoints/campos antes de implementa-los. Preferir recursos do dossie e itens, em vez de um endpoint generico que permita o cliente definir resultado.

Possiveis operacoes:

- Profissional: consultar seu resumo e itens pendentes; enviar/substituir um item permitido; consultar estado de processamento e motivo de reenvio.
- Administrador: listar casos paginados/filtros; abrir dossie autorizado; visualizar um arquivo por endpoint autenticado e auditado; registrar decisao por item; pedir reenvio; registrar revisao adicional; consultar historico sem revelar segredo.
- Sistema: expirar/remover itens conforme politica, com job seguro, idempotente e observavel.

Para cada endpoint documentar autenticacao, papel, MFA, propriedade do recurso, validacao de entrada, resposta, erros, rate limit, auditoria, idempotencia e politica de logs. Nunca aceitar do app `aprovado=true`, decisao final, papel administrativo, `profissionalId` arbitrario ou chave/caminho de storage.

## O que fica com o outro responsavel

- Co-decidir e aprovar por escrito a politica e as questoes pendentes acima; obter revisao juridica/privacidade para dados e verificacoes que exigirem.
- Validar no Flutter o fluxo profissional: o que falta, estados reais, acao de corrigir/re-enviar e explicacao honesta do que foi ou nao confirmado.
- Validar no painel admin um dossie por profissional, checklist por categoria, itens faltantes, estado, prazo, motivo e acoes claras; evitar transformar o dossie em chat ou campo livre para dados sensiveis.
- Definir o procedimento operacional e responsaveis. O roteiro de revisao manual/PDF deve vir depois da politica, para nao ensinar uma pratica que ainda nao foi aprovada.
- So depois de aprovacao formal, planejar separadamente a futura mudanca de habilitacao e um piloto limitado. Esta tarefa de dossie nao deve liberar pedidos.

## Criterios de pronto para esta etapa

- [ ] Decisoes da tabela preenchidas ou explicitamente marcadas como bloqueadas/adiadas.
- [ ] Contrato API revisado pelos dois responsaveis e pelo responsavel Flutter.
- [ ] Dossie e fluxo administrativo definidos sem canal paralelo de compartilhamento de documentos.
- [ ] Politica de dados, retencao, exclusao, acesso, scanner e backups validada antes de dados reais.
- [ ] Testes de autorizacao, MFA, transacao/auditoria, uploads maliciosos, falhas fechadas e expiracao aprovados.
- [ ] API ainda recusa contratacoes; nenhuma aprovacao documental/telefone/selfie altera `podeAtender`.
- [ ] Nao foram usados documentos reais nos testes.

## Prompt para o Codex do amigo

```text
Leia primeiro docs/handoff-habilitacao-profissional.md, docs/habilitacao-profissional.md e docs/verificacao-manual-profissional.md. Nao altere arquivos ainda. Inspecione o estado atual do backend e devolva: (1) divergencias entre o codigo e o handoff; (2) contrato de API proposto, com estados/transicoes, autorizacao/MFA, auditoria, storage, retencao e erros; (3) migrations necessarias; (4) testes de seguranca e MySQL descartavel; (5) lista de decisoes de produto/juridicas que bloqueiam cada parte. Preserve o bloqueio de contratacoes: nao mude podeAtender, nao permita a acao aprovar e nao trate telefone, foto, documento ou antecedentes isolados como prova conclusiva. Nao use documentos reais, nao exponha segredos e nao faca pesquisas informais de antecedentes. Espere o contrato e a politica serem aprovados pelos dois responsaveis antes de implementar qualquer caminho de liberacao.
```

## Limites e referencias

Revisao manual de legibilidade/consistencia nao autentica documento. Uma foto de rosto pode envolver dado biometrico sensivel se usada para identificacao; nao implementar reconhecimento facial ou liveness sem finalidade, base legal, necessidade, salvaguardas e orientacao especializada aprovadas. Nao fazer buscas informais de antecedentes, guardar certidoes ou reprovar automaticamente por resultado isolado.

Referencias para revisao especializada, nao como substituto de parecer: [LGPD](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm), [direitos dos titulares - ANPD](https://www.gov.br/anpd/pt-br/assuntos/titular-de-dados-1/direito-dos-titulares), [guia de legitimo interesse - ANPD](https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/guia_orientativo_hipoteses_legais_tratamento_de_dados_pessoais_legitimo_interesse).
