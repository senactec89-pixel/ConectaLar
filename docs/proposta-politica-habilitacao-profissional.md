# Fase 1 — decisões para habilitação profissional

**Estado:** rascunho para discussão; nenhuma decisão abaixo autoriza liberar atendimentos.

**Atualizado em:** 02/11/2026.

## Atualizacao posterior — 05/11/2026

Esta atualizacao registra a direcao de produto mais recente e prevalece sobre
qualquer diretriz de 02/11 que seja conflitante. Nao e aprovacao juridica,
autorizacao para coleta real nem liberacao de atendimentos.

- **Evidencias (D1/D2):** usar evidencia pertinente a cada tarefa, em vez de um
  requisito documental identico para todas as categorias. A matriz de tarefas,
  alternativas para experiencia informal e limites esta em
  [proposta-politica-habilitacao-piloto.md](proposta-politica-habilitacao-piloto.md).
- **Identidade:** prova de vida, selfie/biometria e comparacao facial nao estao
  aprovadas para a fase inicial. Validar formato ou situacao de CPF nao prova que
  a pessoa cadastrada e seu titular. Metodo de identidade e eventual consulta de
  CPF/nome dependem de necessidade, fonte, base legal, aviso, contestacao e
  revisao especializada antes de qualquer coleta real.
- **Antecedentes (D4):** nao fazer buscas abertas nem verificacoes de antecedentes
  na fase inicial. Permanecem fora do fluxo ate decisao juridica especifica por
  tarefa; resultados nao podem reprovar automaticamente.
- **Telefone:** a conta pode ser criada, mas o perfil nao recebe nem aceita
  solicitacoes ate confirmar acesso ao numero por WhatsApp. A confirmacao nao
  prova identidade civil; mudanca do numero invalida a confirmacao.
- **Auditoria:** seguir a trilha minima de decisao e acesso descrita em
  [plano-lgpd-habilitacao-profissional.md](plano-lgpd-habilitacao-profissional.md),
  sem copiar documentos, OTP, CPF completo ou dados de antecedentes para logs.
- **Armazenamento:** Cloudflare R2 foi escolhido como destino planejado para
  arquivos privados, mas configuracao, contratos, localizacao/transferencia,
  controles e homologacao ainda estao pendentes. Nao enviar documentos reais.
- **Retencao (D7):** continua pendente de justificativa por finalidade e revisao;
  prazos candidatos nao sao aprovacao.

Enquanto os gates juridicos, operacionais e tecnicos nao forem cumpridos, `podeAtender`
deve permanecer `false`, e pedidos/aceites devem continuar bloqueados.

**Escopo:** profissionais individuais e empresas no ConectaLar. Referências: [habilitação atual](habilitacao-profissional.md), [decisões registradas](decisoes.md), [segurança](seguranca.md) e P10/P11/P12/P13/P15 em `.agents/skills/conectalar/references/decisoes-pendentes.md`.

Este documento prepara a fase de política do briefing de habilitação. A equipe também mantém a análise consolidada em [handoff-habilitacao-profissional.md](handoff-habilitacao-profissional.md); usar os dois documentos em conjunto e aplicar a atualização posterior acima quando houver divergência. As escolhas registradas em 02/11/2026 são históricas onde a atualização de 05/11 as substitui. **Não é contrato de API nem autorização jurídica.**

## Ponto de partida confirmado

- A API retorna `podeAtender: false` para todos os perfis; novas solicitações e aceites são bloqueados. O endereço completo não é liberado ao profissional por um pedido antigo enquanto a habilitação estiver pendente.
- Os estados atuais da habilitação são `pendente`, `em_analise` e `suspenso`. A ação administrativa `aprovar` é recusada. Análise documental e selo não equivalem a habilitação.
- Há rotas de consulta, telefone, identidade e revisão; leitura administrativa de documentos é autenticada e a moderação da habilitação exige MFA. A integração real de identidade/telefone e a política de antecedentes não foram homologadas para liberar atendimento.
- O modelo de empresa ainda não representa cada executor nem sua autorização para receber o endereço do cliente. O bloqueio atual também se aplica às empresas.

## Decisões a registrar antes do contrato da API

Cada decisão precisa de responsável, data, versão, critérios aprovados e impacto nos requisitos indicados. Onde houver análise jurídica ou de privacidade pendente, manter o resultado **bloqueado**; não substituir essa análise por uma suposição técnica.

| Decisão | Diretriz registrada ou alternativas a avaliar | O que precisa ficar explícito | Referências |
| --- | --- | --- | --- |
| **D1 — Evidências exigidas** | **Escolha do usuário:** documento aprovado, identidade com prova de vida, telefone confirmado e comprovante profissional exigido de cada profissional ou executor. Para o último, podem ser avaliados certificado, curso ou experiência profissional comprovável. Antecedentes seguem pendentes em D4. | Definir documentos aceitáveis para comprovar experiência, critérios de autenticidade, validade e reenvio. Telefone prova posse do canal, não identidade civil; o selo documental não equivale a habilitação. | P10, RF022, RF023, RB15 |
| **D2 — Categorias** | **Escolha do usuário:** os mesmos requisitos de habilitação para todas as categorias. | Definir quais são esses requisitos e o efeito de mudar categoria, oferta ou qualificação. Uma exigência legal específica de atividade precisa de avaliação própria antes de qualquer liberação. | P03, P10, RF004, RF008 |
| **D3 — Empresas e equipes** | **Escolha do usuário:** incluir profissionais e empresas; cada executor deve ser identificado e verificado. A empresa indica o executor verificado **antes de aceitar** o pedido. Troca de executor exige nova verificação e aviso ao cliente. | Definir vínculo, consentimento/ciência do executor, quem recebe endereço e mensagens, responsabilidade e revogação do acesso. Nenhum executor substituto recebe endereço por herdar a autorização do anterior. CNPJ ou representante sozinho não identificam o executor. | P12, RF013, RF017, RF040 |
| **D4 — Antecedentes** | Critérios e fontes a definir pela equipe com análise jurídica | Necessidade e proporcionalidade por atividade, homônimos, resultados inconclusivos, contestação, periodicidade e dados que não devem ser coletados. Não consultar nem reprovar automaticamente antes dessa definição. | P10, P11, P13 |
| **D5 — Revisão e recurso** | **Escolha do usuário:** decisão final por dois administradores distintos, ambos com MFA. Comprovação inconclusiva ou contestada mantém o atendimento bloqueado e oferece revisão humana por dois administradores distintos. | Definir ordem, validade das duas decisões sobre o mesmo dossiê, impedimentos por conflito de interesse, motivos e prazo de resposta. A API atual exige MFA, mas ainda não implementa dupla aprovação. | P10, P11, P15, RB17 |
| **D6 — Validade e revogação** | **Escolha do usuário:** quando uma verificação expirar, o telefone mudar ou um executor sair da empresa, bloquear imediatamente novos pedidos e aceites; revisar manualmente os atendimentos já aceitos. Avisar imediatamente cliente, executor/empresa e administradores, sem revelar ao cliente o motivo privado. | Definir quem conduz a revisão, prazo de resposta, canais de aviso, efeito sobre acesso ao endereço e demais eventos que exigem reanálise. Não cancelar automaticamente pedidos aceitos por esta diretriz. | P04, P10, P11, P12, P13 |
| **D7 — Retenção e descarte** | Cronograma por tipo de dado, aprovado pela equipe responsável e revisão jurídica | Finalidade, base legal, prazo, acesso, exclusão, auditoria mínima e tratamento de backup para documentos, resultados, telefone e decisões. | P13, RF022, RF038 |
| **D8 — Comunicação ao usuário** | **Escolha do usuário:** cliente vê apenas status genérico; titular vê etapas e motivos permitidos; administrador autorizado vê o dossiê. | Definir os textos e motivos permitidos em cada papel e canal. Nenhum aviso ou selo deve prometer segurança absoluta, divulgar dados privados ou revelar a outro usuário o motivo de uma suspensão. | P10, P18, RB15 |

## Registro de aprovação

**Nota de leitura:** a tabela abaixo preserva o registro historico de 02/11/2026.
Para D1, D2 e D4, aplicar a atualizacao de 05/11 acima; o texto antigo nao deve
ser usado como requisito atual quando houver conflito.

| Decisão | Estado | Responsável | Data | Versão/observação |
| --- | --- | --- | --- | --- |
| D1 | Diretriz escolhida; critérios de comprovação pendentes | Usuário do projeto | 02/11/2026 | Documento, identidade com prova de vida e telefone; certificado, curso ou experiência comprovável para todos; D4 permanece pendente |
| D2 | Diretriz escolhida; critérios concretos pendentes | Usuário do projeto | 02/11/2026 | Mesmos requisitos para todas as categorias |
| D3 | Diretriz escolhida; vínculo e acesso detalhados pendentes | Usuário do projeto | 02/11/2026 | Executor verificado indicado antes do aceite; troca requer nova verificação e aviso ao cliente |
| D5 | Diretriz escolhida; prazos e impedimentos pendentes | Usuário do projeto | 02/11/2026 | Dois administradores distintos com MFA; caso inconclusivo ou contestado fica bloqueado com revisão humana |
| D6 | Diretriz escolhida; prazo e canais pendentes | Usuário do projeto | 02/11/2026 | Bloqueio imediato; revisão humana dos aceitos e aviso imediato a cliente, executor/empresa e admins, sem motivo privado ao cliente |
| D4 | Bloqueada para decisão operacional | Equipe e assessoria jurídica | — | Fontes, necessidade, proporcionalidade, homônimos, contestação e descarte ainda sem política aprovada |
| D7 | Bloqueada para decisão operacional | Equipe e assessoria jurídica | — | Prazos de retenção e descarte por tipo de dado ainda sem política aprovada |
| D8 | Diretriz escolhida; textos e motivos permitidos pendentes | Usuário do projeto | 02/11/2026 | Cliente: status genérico; titular: etapas/motivos permitidos; admin: dossiê |

## Critério para avançar à fase 2

1. A proposta de contrato pode descrever D1, D2, D3, D5, D6 e D8 com campos ainda abertos explicitamente marcados. D4 e D7 continuam bloqueadas para aprovação operacional até a análise jurídica adequada.
2. Detalhar o fluxo de cada executor de empresa e os comprovantes profissionais aceitos para todos. A API atual usa um bloqueio por perfil, não modela executores individuais e não possui dupla aprovação.
3. Inventariar as rotas e dados existentes antes de propor estados ou endpoints novos. Especificar transições, expiração, suspensão, contestação, autorização e auditoria sem duplicar o que já existe.
4. Não aprovar contrato definitivo nem implementar liberação de solicitações, aceites ou acesso profissional ao endereço até que critérios pendentes, análise jurídica, contrato, implementação e testes estejam concluídos.
