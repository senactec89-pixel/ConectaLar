# Fase 1 — decisões para habilitação profissional

**Estado:** rascunho para discussão; nenhuma decisão abaixo autoriza liberar atendimentos.

**Atualizado em:** 02/11/2026.

**Escopo:** profissionais individuais e empresas no ConectaLar. Referências: [habilitação atual](habilitacao-profissional.md), [decisões registradas](decisoes.md), [segurança](seguranca.md) e P10/P11/P12/P13/P15 em `.agents/skills/conectalar/references/decisoes-pendentes.md`.

Este documento prepara a fase de política do briefing de habilitação. O arquivo `handoff-habilitacao-profissional.md` citado pela equipe ainda não está neste checkout; conferir as propostas com ele quando estiver disponível. As diretrizes D1, D2, D3, D5, D6 e D8 foram escolhidas pelo usuário em 02/11/2026, mas sua implementação e o início dos atendimentos continuam condicionados às demais decisões e à revisão adequada. **Não é contrato de API nem autorização jurídica.**

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
| **D5 — Revisão e recurso** | **Escolha do usuário:** decisão final por dois administradores distintos, ambos com MFA. Comprovação inconclusiva ou contestada mantém o atendimento bloqueado e oferece revisão humana por dois administradores distintos. | A API registra votos independentes para iniciar análise/reabrir e exige declaração explícita de ausência de conflito. Um impedimento cancela a rodada e bloqueia permanentemente esse administrador no fluxo de habilitação do perfil; extensão a análise documental, denúncias e avaliações ainda precisa ser decidida. Definir tipos de vínculo que caracterizam conflito, exceções e processo eventual de revisão do impedimento. Divergência mantém o estado. Prazos, contestação e decisão final de habilitação permanecem pendentes; `aprovar` continua bloqueada. | P10, P11, P15, RB17 |
| **D6 — Validade e revogação** | **Escolha do usuário:** quando uma verificação expirar, o telefone mudar ou um executor sair da empresa, bloquear imediatamente novos pedidos e aceites; revisar manualmente os atendimentos já aceitos. Avisar imediatamente cliente, executor/empresa e administradores, sem revelar ao cliente o motivo privado. | Definir quem conduz a revisão, prazo de resposta, canais de aviso, efeito sobre acesso ao endereço e demais eventos que exigem reanálise. Não cancelar automaticamente pedidos aceitos por esta diretriz. | P04, P10, P11, P12, P13 |
| **D7 — Retenção e descarte** | Cronograma por tipo de dado, aprovado pela equipe responsável e revisão jurídica | Finalidade, base legal, prazo, acesso, exclusão, auditoria mínima e tratamento de backup para documentos, resultados, telefone e decisões. | P13, RF022, RF038 |
| **D8 — Comunicação ao usuário** | **Escolha do usuário:** cliente vê apenas status genérico; titular vê etapas e motivos permitidos; administrador autorizado vê o dossiê. | Definir os textos e motivos permitidos em cada papel e canal. Nenhum aviso ou selo deve prometer segurança absoluta, divulgar dados privados ou revelar a outro usuário o motivo de uma suspensão. | P10, P18, RB15 |

## Pacote para revisão jurídica e de privacidade

Esta seção organiza o material para análise por profissional jurídico e responsável por privacidade. É um roteiro de perguntas, não um parecer, uma política aprovada ou uma conclusão sobre a base legal aplicável. Registrar respostas e pendências sem transformar recomendações em decisões operacionais.

### Materiais a entregar para análise

- Este documento, com as diretrizes escolhidas e as decisões ainda pendentes.
- [Inventário de dados e fornecedores](inventario-dados-e-fornecedores.md), conferido com a versão candidata do código e preenchido com os fornecedores que a equipe pretende contratar.
- [Descrição do fluxo atual de habilitação](habilitacao-profissional.md), incluindo telas, endpoints, dados enviados aos fornecedores, estados, bloqueios e permissões administrativas.
- Textos atuais de termos, avisos, consentimento e telas de verificação, identificados por arquivo, versão e data.
- Procedimento administrativo proposto para acesso a documentos, revisão, suspensão, contestação, auditoria e resposta a incidentes.
- Minuta dos contratos e documentos de privacidade dos fornecedores relevantes, quando disponíveis.

Use ambiente de teste e dados fictícios para demonstrar os fluxos. Não inclua documentos reais, senhas, tokens ou chaves no pacote de revisão.

### Perguntas para a revisão

1. **Responsabilidades e operação:** quem decide as finalidades e os meios do tratamento em cada fluxo? Quais responsabilidades precisam constar entre ConectaLar e cada fornecedor? Que canal será divulgado para titulares e para comunicações regulatórias?
2. **Identidade e prova de vida:** quais dados são enviados ao fornecedor, quais respostas são devolvidas e o que o ConectaLar efetivamente guarda? A finalidade e a necessidade estão justificadas? Quais avisos, salvaguardas, alternativas acessíveis, prazos e medidas para resultados inconclusivos devem ser adotados?
3. **Comprovantes profissionais:** que comprovantes são necessários e proporcionais às atividades oferecidas? Como tratar documentos inválidos, vencidos, divergentes, reenvio e contestação? Requisitos uniformes para todas as categorias são adequados ou há exigências próprias de certas atividades?
4. **Antecedentes (D4):** é necessário tratar esse tipo de informação para algum serviço? Quais fontes e critérios podem ser usados, como evitar erro de homonímia, que revisão humana e contestação são necessárias, e quais dados não devem ser coletados ou armazenados? Não iniciar consultas nem reprovar pessoas automaticamente enquanto essas questões estiverem abertas.
5. **Empresas e executores:** quais informações identificam cada executor e demonstram seu vínculo com a empresa? Como informar cada pessoa, registrar sua ciência, limitar o acesso ao endereço e às mensagens e revogar permissões quando houver substituição ou desligamento?
6. **Retenção e descarte (D7):** para cada categoria de dado, qual finalidade justifica a guarda, qual prazo deve ser proposto, quais registros mínimos podem ser preservados, como eliminar cópias e arquivos e como tratar backups e obrigações de preservação?
7. **Revisão administrativa:** a revisão por duas pessoas distintas com MFA atende ao fluxo proposto? Como prevenir conflito de interesse, limitar o acesso ao dossiê, registrar decisões e permitir correção ou contestação? Quais prazos e comunicações devem ser informados?
8. **Avisos e direitos:** quais textos devem ser apresentados antes de cada coleta ou compartilhamento? Como o titular solicita acesso, correção, informação, revisão ou exclusão, e como a equipe responde a casos não atendidos pelo autoatendimento?
9. **Incidentes e fornecedores:** quais obrigações contratuais, medidas de segurança, subprocessadores, locais de tratamento e procedimentos de incidente precisam ser confirmados antes da ativação?

### Registro do retorno da revisão

Preencher uma linha por documento ou fluxo revisado. Usar `pendente` quando ainda faltar análise ou evidência. A aprovação de um texto isolado não representa aprovação de toda a operação.

| Material e versão | Revisor e qualificação | Data | Resultado | Alterações/condições exigidas | Responsável e prazo | Evidência de conclusão |
| --- | --- | --- | --- | --- | --- | --- |
|  |  |  | Pendente / aprovado com condições / precisa revisão |  |  |  |

Manter junto ao registro a versão efetivamente revisada e a resposta escrita do revisor. Registrar separadamente as decisões de produto em `docs/decisoes.md`; a equipe não deve preencher conclusões jurídicas por inferência.

### Gate de segurança desta fase

- D4 e D7 continuam bloqueadas até análise e decisão documentadas pelos responsáveis.
- Integrações de identidade e telefone permanecem desligadas para uso real até revisar aviso, finalidade, dados, contratos e fluxo de contestação.
- Novas solicitações, aceites e acesso profissional ao endereço completo permanecem bloqueados enquanto a política de habilitação não estiver completa, implementada e homologada.
- Nenhuma aprovação documental, confirmação de telefone ou resultado de fornecedor deve, isoladamente, liberar atendimento.

## Registro de aprovação

| Decisão | Estado | Responsável | Data | Versão/observação |
| --- | --- | --- | --- | --- |
| D1 | Diretriz escolhida; critérios de comprovação pendentes | Usuário do projeto | 02/11/2026 | Documento, identidade com prova de vida e telefone; certificado, curso ou experiência comprovável para todos; D4 permanece pendente |
| D2 | Diretriz escolhida; critérios concretos pendentes | Usuário do projeto | 02/11/2026 | Mesmos requisitos para todas as categorias |
| D3 | Diretriz escolhida; vínculo e acesso detalhados pendentes | Usuário do projeto | 02/11/2026 | Executor verificado indicado antes do aceite; troca requer nova verificação e aviso ao cliente |
| D5 | Diretriz escolhida; fluxo parcial implementado; critérios finais pendentes | Usuário do projeto | 02/11/2026 | Dois administradores distintos com MFA; caso inconclusivo ou contestado fica bloqueado com revisão humana. O fluxo de habilitação exige autodeclaração e mantém impedimento persistente, cobre votos para iniciar análise/reabrir e não libera atendimentos. O escopo do impedimento fora dessa fila ainda precisa de decisão. |
| D6 | Diretriz escolhida; prazo e canais pendentes | Usuário do projeto | 02/11/2026 | Bloqueio imediato; revisão humana dos aceitos e aviso imediato a cliente, executor/empresa e admins, sem motivo privado ao cliente |
| D4 | Bloqueada para decisão operacional | Equipe e assessoria jurídica | — | Fontes, necessidade, proporcionalidade, homônimos, contestação e descarte ainda sem política aprovada |
| D7 | Bloqueada para decisão operacional | Equipe e assessoria jurídica | — | Prazos de retenção e descarte por tipo de dado ainda sem política aprovada |
| D8 | Diretriz escolhida; textos e motivos permitidos pendentes | Usuário do projeto | 02/11/2026 | Cliente: status genérico; titular: etapas/motivos permitidos; admin: dossiê |

## Critério para avançar à fase 2

1. A proposta de contrato pode descrever D1, D2, D3, D5, D6 e D8 com campos ainda abertos explicitamente marcados. D4 e D7 continuam bloqueadas para aprovação operacional até a análise jurídica adequada.
2. Detalhar o fluxo de cada executor de empresa e os comprovantes profissionais aceitos para todos. A API atual usa um bloqueio por perfil e não modela executores individuais. O fluxo parcial de dupla revisão cobre iniciar análise/reabrir, mas não implementa aprovação final nem substitui critérios de conflito, exceções ao impedimento, contestação ou revisão jurídica.
3. Inventariar as rotas e dados existentes antes de propor estados ou endpoints novos. Especificar transições, expiração, suspensão, contestação, autorização e auditoria sem duplicar o que já existe.
4. Não aprovar contrato definitivo nem implementar liberação de solicitações, aceites ou acesso profissional ao endereço até que critérios pendentes, análise jurídica, contrato, implementação e testes estejam concluídos.
