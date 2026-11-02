# Politica operacional de habilitacao profissional

**Versao:** 1.0 (decisao provisoria de seguranca, 31/10/2026)
**Estado:** contratacoes reais bloqueadas. Esta politica nao e parecer juridico nem autorizacao para abrir o servico ao publico.

## Decisao vigente

O ConectaLar nao habilita profissionais para receber solicitacoes enquanto nao houver procedimento de verificacao aprovado para todas as etapas obrigatorias, ambiente de armazenamento e revisao prontos, e decisao formal dos responsaveis pelo produto. A API deve falhar fechada: cadastro, selo documental, confirmacao de telefone, URL de fornecedor ou valor enviado pelo aplicativo nunca podem, isoladamente, liberar contratacoes.

Esta e a politica operacional vigente para desenvolvimento e homologacao. Ela conclui que **nao ha liberacao para contratacoes neste momento**. Uma futura politica de lancamento precisa substituir este documento por uma decisao aprovada, nao apenas remover o bloqueio no codigo.

## Significado dos estados e evidencias

| Etapa | O que pode registrar | O que nao significa |
| --- | --- | --- |
| Conta e e-mail | Conta ativa e e-mail confirmado | Identidade civil confirmada ou qualificacao profissional |
| Telefone por WhatsApp | A pessoa conseguiu enviar o desafio a partir do numero vinculado, dentro do prazo | Titularidade civil, identidade, localizacao ou confiabilidade |
| Analise documental | Moderador analisou o tipo de documento permitido e registrou uma decisao | Autenticidade garantida, prova de vida, antecedentes limpos ou autorizacao para entrar em residencias |
| Identidade/prova de vida | Deve permanecer pendente ate existir fluxo aprovado, fornecedor contratado/configurado e homologacao de privacidade e seguranca | Resultado automatico e conclusivo sem revisao de excecoes |
| Antecedentes | Deve permanecer pendente; nao pesquisar, solicitar, armazenar ou usar certidoes para decidir nesta fase | Ausencia de risco ou garantia de seguranca |
| Habilitacao final | Ainda indisponivel. No futuro, exige todos os controles aprovados, decisao administrativa individual e auditoria | Aprovacao automatica por completar cadastro ou receber um selo |

Os estados devem ser mostrados separadamente. O selo atual deve dizer somente "Documento analisado". Nao usar "profissional seguro", "identidade verificada", "antecedentes aprovados" ou equivalentes sem uma verificacao realmente implantada e uma definicao aprovada do alcance.

## Procedimento permitido nesta fase

- Homologar somente com contas de teste e arquivos sinteticos, sem documentos reais.
- A interface pode preparar o desafio manual de WhatsApp, mas ele fica indisponivel ate configuracao deliberada do numero oficial, segredo e aviso aprovado. Nunca registrar o codigo em logs, tickets ou auditoria.
- Se houver um piloto manual futuro, ele precisa de aprovacao previa, escopo limitado, instrucao documentada, acesso nominal e restrito, registro de ator/data/decisao, canal de contestacao e armazenamento privado. Nao baixar documentos para dispositivos pessoais nem trocar documentos por chat ou e-mail.
- A analise de documento existente e apenas moderacao do arquivo recebido. Revisores nao devem consultar bases governamentais, redes sociais ou fontes de antecedentes por iniciativa propria nesta fase.
- Nao aceitar empresa como habilitada enquanto a plataforma nao conseguir identificar e avaliar individualmente cada pessoa que possa entrar na residencia.

## Requisitos para uma futura decisao de lancamento

Antes de mudar o bloqueio, os responsaveis precisam aprovar por escrito:

1. Escopo inicial: regioes, categorias de servico e se empresas/pessoas auxiliares ficam excluidas.
2. Metodo de identidade e tratamento de casos inconclusivos, incluindo revisao humana, acessibilidade, recurso e revalidacao.
3. Finalidade e base legal de cada dado; aviso ao titular; minimizacao; prazos de retencao e exclusao; papeis de controlador/operador e contratos aplicaveis. Biometria e dados sobre antecedentes exigem avaliacao especifica antes de qualquer coleta ou consulta.
4. Se e como antecedentes serao tratados, com fontes autorizadas, criterios proporcionais, tratamento de homonimos, contraditorio e revisao juridica. Ate essa decisao, o estado continua pendente e nao ha pesquisa.
5. Armazenamento privado validado, controle de acesso, auditoria, resposta a incidente, backup e teste de restauracao; scanner operacional para uploads que exijam varredura.
6. Expiracao/revalidacao, suspensao imediata, mudanca de telefone/identidade, denuncia, contestacao e tratamento de falhas do fornecedor.
7. Homologacao de ponta a ponta em ambiente nao produtivo, testes de autorizacao e concorrencia, e aprovacao de release da API e do aplicativo.

## Regra tecnica obrigatoria

- A decisao de habilitacao e exclusivamente do servidor e deve usar dados persistidos e atuais.
- O cliente Flutter nao pode enviar `podeAtender`, `verificado` ou uma decisao de aprovacao como prova.
- Criar solicitacao e aceitar solicitacao continuam recusados enquanto `podeAtender` nao for liberado por uma futura mudanca revisada e testada.
- A aprovacao administrativa continua recusada enquanto qualquer requisito estiver ausente; iniciar analise, reabrir ou confirmar telefone nao aprova habilitacao.
- Nao criar bypass por modo demo, endpoint alternativo, conta antiga, selo legado ou variavel de ambiente.
- Testes devem cobrir profissional novo/antigo, conta empresa, credenciais de cliente/profissional/admin, etapas ausentes, mudanca de telefone, aprovacao concorrente e falha de auditoria.

## Revisao e referencias

Revisar esta politica antes de qualquer piloto com pessoas reais e sempre que mudar fornecedor, dado coletado, categoria ou criterio de habilitacao. A revisao interna nao substitui aconselhamento juridico.

- LGPD, Lei 13.709/2018: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm
- Direitos dos titulares (ANPD): https://www.gov.br/anpd/pt-br/assuntos/titular-de-dados-1/direito-dos-titulares
- Relatorio de Impacto (ANPD): https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/relatorio-de-impacto-a-protecao-de-dados-pessoais-ripd
