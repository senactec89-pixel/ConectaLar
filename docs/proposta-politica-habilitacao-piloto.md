# Proposta consolidada: habilitacao profissional para piloto

**Status: rascunho para decisao dos dois responsaveis.** Esta proposta nao e
parecer juridico, autorizacao para coletar dados reais, garantia de identidade
ou seguranca, nem liberacao de contratacoes. Ate a politica ser aprovada,
implementada e homologada, a API deve continuar bloqueando solicitacoes e
aceites.

**Contexto atual:** Venda Nova, Belo Horizonte/MG e as oito categorias iniciais
foram indicadas como candidatas. O ConectaLar ainda nao mapeou profissionais
reais. Candidata significa somente que a equipe pode recrutar e estudar a tarefa;
nao significa que ela esta disponivel para contratacao.

**Privacidade e coleta:** a analise detalhada de bases legais candidatas, metodo
para justificar prazos, minuta de aviso e portao para documentos reais esta em
[plano-lgpd-habilitacao-profissional.md](plano-lgpd-habilitacao-profissional.md).
Esse plano registra dois fatos tecnicos desta copia: a rota de upload ja aceita
documentos e a exportacao de dados inclui arquivos em Base64 no JSON. Nao
interpretar o rascunho desta politica como bloqueio tecnico da coleta.

Esta matriz e o complemento operacional da [proposta de politica da fase 1](proposta-politica-habilitacao-profissional.md)
e do [contrato tecnico proposto](proposta-contrato-habilitacao-profissional.md).
Os tres documentos devem ser lidos em conjunto; a atualizacao de 05/11 prevalece
sobre requisitos anteriores de prova de vida ou de criterios documentais iguais
para todas as categorias.

**Decisoes/encaminhamentos comunicados em 2026-11-05:** seguir com evidencia
pertinente por tarefa e auditoria minima; exigir telefone confirmado por WhatsApp
para receber solicitacoes, sem impedir a criacao da conta; e adotar R2 como
destino planejado para arquivos privados. Isso registra a direcao de produto,
nao aprovacao juridica, configuracao concluida, coleta real ou liberacao de
contratacoes.

**CPF, identidade e antecedentes:** embora tenha sido manifestado interesse em
avaliar CPF/nome, antecedentes e fontes publicas, a recomendacao inicial e nao
fazer buscas abertas ou verificacoes de antecedentes e nao tratar CPF como prova
de identidade. Qualquer verificacao adicional depende de necessidade por tarefa,
fonte autorizada, base legal, aviso, revisao humana, contestacao e orientacao
juridica. Detalhes e salvaguardas em
[plano-lgpd-habilitacao-profissional.md](plano-lgpd-habilitacao-profissional.md).

## 1. Regras comuns propostas

- Avaliar a pessoa que efetivamente entrara na residencia. Em empresas, cada
  integrante da equipe precisa de cadastro e avaliacao individual; a empresa nao
  pode substituir a pessoa aprovada sem nova verificacao.
- Definir tarefas e limites concretos. Categoria ampla ou campo "Outros" nao
  habilita uma oferta.
- Exigir evidencia pertinente a tarefa, nao o mesmo certificado para todos.
  Evidencia pode ser curso/certificado aplicavel, qualificacao exigida para a
  atividade ou experiencia demonstravel por meio previamente aceito. Portfolio,
  declaracao ou referencia podem demonstrar apenas o que foi apresentado; nao
  autenticam por si so autoria, qualidade ou competencia. Nao recolher dados de
  clientes anteriores sem necessidade, autorizacao e protecao adequada.
- Para atividade regulamentada ou de risco elevado, nao aceitar evidencia
  generica: definir qualificacao, escopo e forma confiavel de conferir emissor e
  validade com especialista tecnico e orientacao juridica. Sem isso, a tarefa
  fica fora do piloto.
- Conferencia manual de arquivo significa apenas avaliar legibilidade e
  consistencia aparente. Nao declarar documento autentico, identidade provada,
  antecedentes limpos ou seguranca garantida sem processo valido para cada
  afirmacao.
- O perfil pode criar conta, mas nao recebe nem aceita solicitacoes ate confirmar
  o acesso ao telefone pelo fluxo de WhatsApp. Essa confirmacao indica acesso ao
  canal naquele momento; nao comprova titularidade civil nem identidade. Trocar o
  numero invalida a confirmacao; suporte nao pode ignorar a verificacao.
- Nao coletar selfie, biometria, comprovante de endereco por padrao ou dados de
  antecedentes nesta proposta. Cada coleta exige necessidade, finalidade, base
  legal, aviso, controle de acesso, retencao, exclusao e alternativa analisados
  antes de qualquer dado real.
- Revisao apenas em painel autorizado, com MFA, armazenamento privado, scanner
  operacional e auditoria. Nunca compartilhar documentos por chat, e-mail,
  capturas ou dispositivos pessoais.
- R2 e o destino planejado, ainda sujeito a configuracao privada, credenciais
  restritas no servidor, contas individuais/MFA, exclusao verificavel, contrato,
  avaliacao de localizacao/transferencia e homologacao antes de documentos reais.

## 2. Tarefas candidatas e criterio de evidencia

Os exemplos abaixo sao uma base para a reuniao, nao um catalogo aprovado. A
equipe precisa preencher inclusoes, exclusoes e evidencia aceita antes de
habilitar cada tarefa.

Para um primeiro piloto pequeno, consultar o recorte conservador da
[ficha de analise por categoria](ficha-analise-categorias-piloto.md): somente
limpeza residencial interna comum, pintura interna simples e montagem de movel
pequeno autoportante sao sugeridas como candidatas, todas ainda dependentes de
checklist tecnico, operacao e aprovacao. Hidraulica e ar-condicionado ficam para
avaliacao especializada; eletrica, gas, altura, reformas amplas e `Outros` ficam
fora da primeira versao. A tabela abaixo e um backlog de tarefas para avaliar,
nao uma autorizacao para ofertar todas elas.

| Categoria | Tarefas que podem ser detalhadas | Evidencia pertinente a discutir | Fora do piloto ate avaliacao especifica |
|---|---|---|---|
| Limpeza | Limpeza de manutencao residencial; limpeza pesada com limites de produtos; limpeza de mudanca; vidros acessiveis do piso | Experiencia demonstravel em limpeza residencial ou curso especifico quando a tarefa exigir; instrucoes de produtos e limites | Altura, pragas, material biologico/perigoso, produtos de uso restrito, cuidado de pessoas |
| Pintura | Pintura interna; preparacao simples de parede; retoque; pintura de portas/interiores | Experiencia demonstravel ou curso de pintura pertinente; amostra/portfolio somente se permitido e sem dados de terceiros | Fachada/altura, trabalho estrutural, remocao de material perigoso, instalacao eletrica ou reparo de causa de umidade |
| Manutencao | Ajustes simples de portas e ferragens; fixacao de itens leves em superficies identificadas; pequenas montagens | Evidencia de experiencia na tarefa exata; instrucoes de limite de peso, superficie e ferramentas | Eletrica, hidraulica, gas, estrutura, climatizacao e qualquer tarefa tecnica nao classificada |
| Hidraulica | Troca de torneira/sifao; reparo acessivel de descarga; vazamento localizado em ponto acessivel | Experiencia especifica; para atividade regulamentada ou que exija qualificacao, comprovante especifico e verificavel | Gas/aquecedor, rede comum de edificio, tubulacao embutida/estrutural, risco de inundacao ou tarefa sem qualificacao definida |
| Eletrica | Nenhuma tarefa liberada nesta versao; primeiro decompor e obter avaliacao tecnica/juridica | A definir por tarefa, incluindo qualificacao exigivel e verificacao de emissor/validade | Instalacao, quadro, circuito energizado e qualquer intervencao ate aprovacao tecnica |
| Ar-condicionado | Limpeza externa simples/filtro apenas se o procedimento seguro for definido | Experiencia na tarefa; qualificacao especifica para instalacao, reparo ou circuito quando aplicavel | Circuito refrigerante, instalacao, reparo eletrico e manutencao interna ate regra tecnica aprovada |
| Reformas | Decompor em tarefas independentes antes de reconsiderar | Evidencia especifica por tarefa e por cada executor | Obra ampla, estrutura, equipe/subcontratados sem identificacao individual, responsabilidade tecnica indefinida |
| Outros | Nenhuma oferta generica; classificar e criar tarefa antes | Definir depois de classificar risco e escopo | Qualquer servico sem categoria, escopo e criterio previamente aprovados |

### Perguntas obrigatorias para cada tarefa

1. O que exatamente o profissional fara e o que nao fara?
2. Qual risco concreto a evidencia pretende reduzir?
3. Qual evidencia minima e suficiente, e qual alternativa existe para experiencia
   informal?
4. Quem consegue conferir emissor, validade e escopo de modo confiavel? Se
   ninguem, o resultado fica limitado/inconclusivo e a tarefa nao e liberada.
5. O que fazer em caso de divergencia, expiracao, mudanca de executor, reenvio ou
   contestacao?

## 3. Estados e decisao administrativa propostos

Separar estado do arquivo, estado da tarefa e habilitacao geral. Um arquivo
aprovado nunca libera sozinho o profissional.

- Arquivo: `nao_enviado`, `recebido`, `em_analise`, `precisa_reenvio`,
  `inconclusivo`, `analise_documental_concluida`.
- Tarefa: `nao_avaliada`, `pendente`, `incompleta`, `em_revisao`,
  `inconclusiva`, `aprovada_para_escopo_limitado`, `suspensa`, `expirada`.
- Habilitacao do perfil: permanece `bloqueada` ate todos os requisitos de
  identidade, telefone, evidencias por tarefa, politica de antecedentes,
  aprovacao administrativa, operacao e homologacao estarem resolvidos.

`analise_documental_concluida` quer dizer apenas que a triagem prevista foi
realizada. `aprovada_para_escopo_limitado` significa somente que os responsaveis
aprovaram aquela tarefa dentro dos limites registrados; nao e garantia de
qualidade, ausencia de risco ou conduta futura.

Para aprovar, proposta de dois revisores distintos com MFA, no mesmo dossie e
versao das evidencias. Se divergirem, o caso fica bloqueado e inconclusivo ate
revisao independente; nao ha aprovacao automatica. Revisor nao decide o proprio
caso nem o de pessoa relacionada.

## 4. Reenvio e contestacao

1. O revisor escolhe motivo codificado e registra nota objetiva, sem especulacao
   nem dado sensivel desnecessario. O profissional recebe no app o item afetado,
   o que precisa corrigir e como reenviar ou contestar.
2. `precisa_reenvio` e usado para falha corrigivel (por exemplo, arquivo cortado
   ou ilegivel); `inconclusivo` quando a equipe nao consegue concluir com meios
   disponiveis. Nenhum dos dois e uma acusacao ou prova de fraude.
3. Proposta de prazo para contestar: 30 dias corridos apos a notificacao. Proposta
   de permitir novo envio durante esse prazo e reabrir depois quando houver fato
   novo. Esses prazos sao operacionais candidatos, precisam ser confirmados pelos
   responsaveis e revisados juridicamente antes de virar regra.
4. Contestacao e reavaliada por dois revisores distintos do profissional,
   sempre que a equipe tiver pessoal suficiente. Se nao houver independencia ou
   evidencia suficiente, manter bloqueado e informar que a revisao nao foi
   conclusiva; nao inventar um terceiro nivel que a operacao nao consegue cumprir.
5. Nao prometer SLA antes de medir capacidade. Registrar responsavel e fila;
   publicar prazo somente depois de um ensaio operacional realista.
6. Cliente ve apenas disponibilidade/estado generico. Nunca recebe documentos,
   motivo privado ou dados de verificacao.
7. Toda decisao deve guardar ator, data, versao do dossie, estado anterior/novo,
   motivo codificado e acao seguinte. Auditoria nao deve copiar o documento nem
   texto livre sensivel.

## 5. Retencao: proposta conservadora para revisao

Nao tratar os periodos abaixo como aprovados ou juridicamente suficientes. Sao
valores de trabalho para a reuniao. A LGPD nao determina um prazo universal para
todo documento; o prazo precisa ser justificado pela finalidade, necessidade e
obrigacoes aplicaveis. Confirmar com assessoria juridica/privacidade antes de
coletar dados reais.

| Dado/objeto | Prazo candidato | Regra proposta |
|---|---:|---|
| Upload incompleto ou sem registro associado | Ate 24 horas | Remover objeto; se falhar, registrar tarefa de limpeza e repetir com alerta. Nunca deixar objeto orfao indefinidamente. |
| Documento bruto de caso encerrado sem contestacao | Ate 30 dias apos decisao final notificada | Depois apagar arquivo; manter somente metadados minimos se houver finalidade aprovada. |
| Documento bruto contestado | Ate decisao final + 30 dias | Apagar depois, salvo retencao legal formalmente identificada ou preservacao necessaria para disputa concreta. |
| Evidencia de tarefa ativa | Enquanto a tarefa estiver ativa e a evidencia for necessaria/valida; mais 30 dias apos expiracao, substituicao ou retirada | Depois apagar o arquivo e manter somente o registro minimo aprovado. Revalidar antes de renovar a tarefa. |
| Selfie/biometria | Nao coletar agora | So discutir apos avaliacao separada. Nao presumir que 72h e adequado nem coletar enquanto storage, acesso, exclusao e alternativa nao estiverem homologados. |
| Codigo WhatsApp | Nao persistir em texto; nunca registrar em log | Guardar apenas estado, telefone vinculado e datas estritamente necessarias, conforme prazo a definir. |
| Metadados de auditoria | Prazo pendente de justificativa | Minimizar; nao armazenar conteudo de documento, selfie, codigo, CPF integral ou nota especulativa. Definir prazo com juridico/privacidade. |
| Backups | Retencao e ciclo pendentes de aprovacao | Backups criptografados e com acesso restrito; apos restauracao, reaplicar exclusoes pendentes antes de disponibilizar dados. Nao prometer apagamento imediato sem cobrir backups. |

Excecao de preservacao deve ser documentada, restrita ao dado necessario, com
responsavel e motivo; nao pode virar retencao indefinida por conveniencia. Antes
de anunciar qualquer prazo, provar que o sistema apaga objetos e trata falhas de
storage de forma repetivel.

## 6. Condicoes para sair do bloqueio

- Os dois responsaveis aprovam por escrito tarefas, escopo, evidencia, retencao,
  contestacao, equipe e prazos.
- Orientacao juridica/privacidade e tecnica conclui os pontos de alto risco,
  especialmente identidade, dados sensiveis, tarefas regulamentadas e qualquer
  pesquisa de antecedentes. Antecedentes permanecem fora/bloqueados ate decisao.
- API e app representam os estados acima, vinculam evidencias a tarefa, fazem
  exclusao/retry verificavel, auditoria minima e controle de acesso testado.
- Fluxos e falhas sao homologados com dados ficticios; scanner/storage indisponivel
  bloqueia a aprovacao.
- A mudanca do bloqueio de contratacao e uma decisao separada, implementada e
  testada somente depois dos gates anteriores.

## 7. Decisoes a registrar pelos dois responsaveis

| Decisao | Proposta para discutir | Estado |
|---|---|---|
| Regiao e tamanho do piloto | Venda Nova, com bairros, limite de profissionais e volume definidos | Pendente |
| Categorias e tarefas | Usar a matriz acima como ponto de partida; eletrica, reformas amplas e tarefas tecnicas sem criterio ficam fora | Pendente |
| Evidencia por tarefa | Evidencia pertinente; alternativa para experiencia informal; requisito tecnico especifico quando aplicavel | Direcao aceita nesta conversa; detalhar e validar por tarefa |
| Empresas/equipes | Avaliar individualmente cada pessoa que entrara na residencia | Pendente |
| Prazo e retencao | Revisar os valores candidatos da secao 5 com juridico/privacidade e capacidade tecnica | Pendente |
| Contestacao | Revisores independentes, sem aprovacao automatica; confirmar prazo de 30 dias candidato | Pendente |
| Antecedentes/selfie | Nao coletar nem usar para liberar nesta proposta | Pendente de decisao juridica futura |
| Confirmacao do telefone | WhatsApp e requisito para receber solicitacoes, nao para criar conta; numero alterado reinicia verificacao | Direcao de produto aceita; validar aviso, base, fornecedor e alternativa |
| Storage documental | Cloudflare R2 privado como destino planejado | Escolhido; configuracao, contratos e homologacao pendentes |
| Auditoria | Metadados minimos, sem copiar conteudo sensivel para logs | Direcao aceita; prazo e implementacao pendentes |
| Revisores e SLA | Definir capacidade real; nao prometer prazo ainda | Pendente |

## Fontes para revisao de privacidade

- [ANPD: perguntas frequentes sobre termino do tratamento e conservacao de dados](https://www.gov.br/anpd/pt-br/acesso-a-informacao/perguntas-frequentes)
- [ANPD: orientacoes sobre Relatorio de Impacto a Protecao de Dados Pessoais (RIPD)](https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/relatorio-de-impacto-a-protecao-de-dados-pessoais-ripd)
- [ANPD: guia de seguranca da informacao para agentes de tratamento de pequeno porte](https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/anonimizado___guia_orientat-_seg_da_inf_p_atpp.pdf)
