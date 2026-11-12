# Ficha de analise por categoria - rascunho de trabalho

**Status:** proposta para discussao dos responsaveis. Nao e politica aprovada,
parecer juridico, autorizacao para coletar documentos reais nem liberacao de
contratacoes. A API deve continuar recusando solicitacoes e aceites enquanto a
politica completa nao for aprovada e homologada.

## Resumo das decisoes atuais

**Andamento tecnico:** a copia local da API ja possui catalogo, administracao e
vinculo de novas ofertas ao servico escolhido. As telas de administracao,
ofertas e busca estao integradas ao catalogo na copia local. As migrations foram
testadas em banco descartavel, mas ainda nao foram aplicadas ao banco do
aplicativo. A lista de 37 servicos esta preparada para teste, pausada. Isso nao
libera contratacoes.

- A estrutura do app continua **categoria > servico**. As categorias nao serao
  removidas; o administrador podera gerenciar categorias e seus servicos.
- Os servicos listados pelos responsaveis sao o catalogo pretendido. A etiqueta
  "fora do piloto" nesta ficha quer dizer **nao aceitar pedidos por enquanto**,
  nao apagar a tarefa do catalogo nem desistir dela.
- Montagem de moveis fica dentro de **Manutencao**, nao como categoria propria.
- Cozinha e banheiro ficam como partes/opcoes da **Limpeza residencial padrao**,
  nao como categorias separadas.
- Os dois responsaveis aprovaram um escopo-base de limpeza para revisao do
  catalogo: varrer e passar pano, tirar poeira de superficies acessiveis, lavar
  a louca existente, limpar banheiro e arrumar superficialmente os quartos. O
  cliente escolheria os ambientes e poderia acrescentar observacao. Limpeza
  pesada, mover moveis grandes, janelas em altura, mofo extenso, pragas, residuos
  perigosos e pos-obra ficam fora da tarefa padrao; piscina e servicos
  especializados ficam separados. O amigo responsavel pelo catalogo e o
  profissional experiente ainda precisam validar opcoes, limites e criterios de
  interrupcao. Esta direcao nao libera oferta nem contratacao.
- Nao havera teto de participantes nem limite fixo de bairros nesta proposta. O
  app deve mostrar disponibilidade conforme profissionais e areas que eles
  realmente atendem; isso nao e uma promessa de cobertura nacional.
- A lista de cuidados tecnicos do profissional experiente e a revisao de
  privacidade com materiais da ANPD ainda serao feitas. Nenhuma delas esta
  concluida por este documento.

**Proximas acoes, sem juridiquês:** (1) receber a lista de cuidados do profissional
experiente; (2) preencher o checklist/registro da ANPD com os dados que o app
pretende usar, para que servem, quem acessa e por quanto tempo; (3) depois dessas
duas revisoes, fechar as regras e implementar/testar o catalogo com dados
ficticios. Enquanto isso, nao coletar documentos reais nem liberar contratacoes.

**Proposta consolidada:** ver
[proposta-politica-habilitacao-piloto.md](proposta-politica-habilitacao-piloto.md),
que reune tarefas candidatas, criterios de evidencia, estados, retencao e
contestacao. Este arquivo continua sendo a ficha de analise detalhada por
categoria; nao transformar exemplos em requisitos sem decisao dos dois
responsaveis.

**Cobertura:** sem teto de participantes nem limite fixo de bairros definido
nesta proposta. A disponibilidade deve refletir as areas efetivamente atendidas
pelos profissionais cadastrados; nao anunciar cobertura nacional sem operacao
real nessas localidades.

**Objetivo:** decidir, para cada servico especifico, se ele cabe num piloto
supervisionado, qual informacao e estritamente necessaria e qual conclusao uma
revisao manual pode ou nao sustentar. Os nomes de categoria refletem o catalogo
inicial semeado pela migration. O administrador pode criar, editar e desativar
categorias, entao o catalogo de cada banco deve ser conferido antes de aplicar a
matriz. Os escopos sao exemplos para debate, nao compromissos de atendimento.

## Regras comuns propostas

- Primeiro definir a tarefa concreta. Uma categoria ampla nao significa que todo
  servico nela esteja aceito.
- Pedir somente dados e documentos necessarios para aquela tarefa, depois de
  aprovados finalidade, base legal, aviso de privacidade, acesso, retencao,
  exclusao e canal de contestacao. Nao usar comprovante de endereco como requisito
  automatico sem justificar sua necessidade.
- O app atualmente aceita os tipos `documento_identidade`,
  `comprovante_endereco`, `certificado_opcional` e `certificado_curso`. Essa lista
  tecnica nao significa que todos sejam necessarios. Nao enviar outro conteudo sob
  um tipo incorreto; selfie e antecedentes nao fazem parte desta ficha.
- Atualmente o documento e vinculado ao profissional, mas nao a uma categoria,
  oferta ou tarefa. A associacao proposta nesta ficha ainda nao existe na API.
- Telefone confirmado por WhatsApp significa somente acesso aquele canal naquele
  momento. Nao prova identidade, titularidade civil, qualificacao ou seguranca.
- A revisao documental atual nao resolve identidade/prova de vida. Uma futura
  comparacao manual de foto e documento exige decisao e avaliacao de privacidade
  separadas; nao iniciar coleta de foto a partir desta ficha.
- A revisao humana pode registrar se o arquivo esperado esta legivel,
  aparentemente vigente e coerente com os dados declarados; se precisa de reenvio;
  ou se o caso e inconclusivo. Isso nao autentica o documento nem valida a pessoa.
- Nao fazer buscas informais na internet, nao solicitar certidao criminal nesta
  etapa e nao reprovar automaticamente por homonimia ou resultado isolado.
- Revisar somente no painel autorizado, com MFA, storage privado e scanner
  operacional. Nao baixar para dispositivos pessoais nem compartilhar por chat,
  e-mail ou captura de tela.

## Matriz inicial para discussao

### Recorte recomendado para o primeiro piloto supervisionado

Esta e uma recomendacao de produto para reduzir o risco e tornar a revisao
executavel por uma equipe pequena. Nao e parecer juridico, certificacao de
seguranca ou autorizacao para contratar. Categorias podem continuar no catalogo,
mas somente tarefas explicitamente aprovadas devem poder receber pedidos.

As tarefas enviadas pelos responsaveis continuam no catalogo pretendido. Os
rotulos abaixo falam somente de **quando uma tarefa pode aceitar pedidos**. Uma
tarefa pode existir no catalogo e permanecer indisponivel para contratacao ate
que os criterios tecnicos, operacionais e de habilitacao sejam aprovados.

| Decisao sugerida | Tarefa concreta | Evidencia inicial a avaliar | Limites obrigatorios |
|---|---|---|---|
| **Candidata, apos checklist tecnico** | Limpeza residencial comum em ambientes internos | Uma evidencia relacionada: experiencia descrita em formulario estruturado, com entrevista/checklist; ou curso pertinente. Portfolio e opcional, sanitizado e sem dados de clientes. | Sem altura/escada, pragas, material biologico, produtos perigosos/restritos, cuidado de pessoas ou trabalho fora da limpeza. |
| **Candidata, apos checklist tecnico** | Pintura interna simples, em superficie acessivel do piso | Curso pertinente ou experiencia descrita e avaliada por checklist; portfolio sanitizado pode complementar. | Sem fachada, altura, andaime, reparo estrutural, instalacao eletrica, mofo/contaminacao ou lixamento de revestimento desconhecido. |
| **Candidata, apos checklist tecnico** | Montagem de movel pequeno e autoportante, seguindo manual | Curso pertinente ou experiencia especifica descrita; checklist pratico definido por profissional experiente. | Sem furar parede/piso/teto, fixar cargas suspensas, mexer em eletrica/hidraulica, mover cargas pesadas ou improvisar fora do manual. |
| **Adiar ate avaliacao de especialista** | Troca de torneira/sifao, descarga e outros reparos hidraulicos | Especialista define tarefa permitida, qualificacao/evidencia, limites de dano e quando interromper. | Nao incluir tubulacao embutida, rede comum, aquecedor, gas ou risco de inundacao ate regra aprovada. |
| **Adiar ate avaliacao de especialista** | Limpeza/manutencao de ar-condicionado | Especialista define procedimento permitido, qualificacao e como evitar eletricidade/circuito refrigerante. | Nao incluir instalacao, reparo eletrico, abertura de circuito ou manuseio de refrigerante. |
| **Fora do primeiro piloto** | Eletrica, gas, aquecedores, intervencao estrutural, reformas amplas, trabalho em altura, pragas, materiais perigosos e categoria generica "Outros" | Nao coletar documentos para tentar liberar antes de especialista tecnico e revisao juridica definirem escopo, requisitos e verificacao. | Criar tarefa especifica e aprovar controles antes de reconsiderar. |

### Catalogo proposto por categoria e tarefa

A lista abaixo organiza os servicos sugeridos pelos responsaveis. Os nomes podem
ser usados para planejar o catalogo, mas **nao estao aprovados para cadastro,
oferta ou contratacao**. "Candidata ao piloto" significa apenas que vale criar
um checklist e submeter a revisao; nao significa que a API possa aceitar pedidos.
Antes de publicar cada tarefa, definir inclusoes, exclusoes, evidencia pertinente,
orientacao ao cliente e criterios de interrupcao.

Legenda:

- **Candidata ao piloto:** escopo relativamente delimitavel; ainda depende de
  checklist tecnico, revisao dos responsaveis e homologacao.
- **Fase posterior:** pode ser considerada depois de avaliacao de profissional
  experiente, limites operacionais e procedimento de seguranca.
- **Fora do piloto inicial:** nao oferecer nem aceitar pedido no recorte inicial;
  reconsiderar somente com avaliacao tecnica e juridica especifica.

#### Limpeza residencial

| Servico proposto | Classificacao | Escopo e limites propostos |
|---|---|---|
| Limpeza residencial padrao | Candidata ao piloto | Limpeza geral de pisos e superficies acessiveis, moveis acessiveis, cozinha e banheiro. Sem altura, pragas, materiais biologicos/perigosos ou cuidado de pessoas. |
| Limpeza de cozinha | Opcao de escopo da limpeza padrao | Bancadas, armarios acessiveis, pia e superficies externas de eletrodomesticos. Nao inclui interior de forno/geladeira, desmontagem, reparo ou produto perigoso, salvo avaliacao separada. |
| Limpeza de banheiro | Opcao de escopo da limpeza padrao | Piso, loucas sanitarias, box acessivel e superficies comuns. Sem mofo extenso, material biologico, desentupimento ou mistura de produtos quimicos. |
| Limpeza de vidros internos | Candidata ao piloto, com limite | Somente vidros alcancaveis com os pes no chao e postura estavel. Sem escada, inclinacao para fora de janelas, sacadas ou risco de queda. |
| Limpeza residencial pos-mudanca | Fase posterior | Imovel desocupado, com sujeira comum. Definir previamente tamanho, condicao do imovel e volume; sem entulho, pragas ou residuos desconhecidos. |
| Limpeza pesada residencial | Fase posterior | A expressao e vaga e pode incluir carga fisica, produtos e residuos de maior risco. Requer lista fechada do que significa "pesada"; excluir contaminacao, pragas, material biologico e quimicos perigosos. |
| Limpeza pos-obra leve | Fase posterior | Apenas poeira e residuos leves identificados, com protecao e procedimento definidos. Sem entulho, silica/poeira de lixamento, solventes ou materiais desconhecidos; se nao der para identificar o residuo, nao executar. |
| Limpeza de areas externas terreas | Fase posterior | Varanda/quintal acessivel no nivel do solo. Sem telhado, escada, equipamento de pressao, trabalho eletrico ou superficie escorregadia sem controle. |

#### Pintura

| Servico proposto | Classificacao | Escopo e limites propostos |
|---|---|---|
| Pintura de paredes internas | Candidata ao piloto, com checklist | Superficie interna alcancavel do piso, com tinta e ventilacao adequadas. Sem escada, mofo/infiltracao, reparo estrutural, instalacao eletrica ou remocao de revestimento desconhecido. |
| Retoques de pintura | Candidata ao piloto, com checklist | Correcao localizada em superficie acessivel e seca. Excluir descascamento causado por umidade, mofo, fissura estrutural ou causa nao identificada. |
| Pintura de portas | Fase posterior | Definir material, preparacao, ventilacao e produtos. Sem decapagem, solvente forte ou lixamento de revestimento desconhecido. |
| Pintura de janelas e esquadrias | Fase posterior | Apenas face acessivel sem se inclinar para fora ou trabalhar em altura; definir material e preparacao. Nenhuma parte externa com risco de queda. |
| Pintura de grades | Fase posterior | Somente grade acessivel ao nivel do solo, apos definir preparacao e produto. Sem corrosao extensa, altura, solventes perigosos ou lixamento de revestimento desconhecido. |
| Aplicacao de massa corrida | Fase posterior | Regularizacao superficial localizada, apos checklist de preparacao e controle de po. Sem umidade, mofo, fissura estrutural, lixamento amplo ou substrato desconhecido. |
| Pintura de tetos | Fora do piloto inicial | Trabalho sobrecabeca normalmente envolve alcance elevado e risco de queda; reconsiderar somente com metodo, equipamento e avaliacao tecnica especificos. |
| Pintura externa terrea | Fase posterior | Apenas superficie externa realmente acessivel do solo, em condicao climatica adequada. Sem escada, beiral, fachada elevada ou proximidade eletrica. |

#### Montagem de moveis (servicos dentro de Manutencao)

Os responsaveis decidiram que montagem de moveis pertence a categoria
"Manutencao". Cada tipo de montagem listado abaixo e um servico proposto.

| Servico proposto | Classificacao | Escopo e limites propostos |
|---|---|---|
| Montagem de cadeira | Candidata ao piloto | Modelo convencional, seguindo manual, sem reparo estrutural ou adaptacao improvisada. |
| Montagem de mesa | Candidata ao piloto, com limite | Mesa de porte manejavel, seguindo manual; sem carga pesada, fixacao em parede ou intervencao eletrica. |
| Montagem de cama | Candidata ao piloto, com limite | Cama convencional e estrutura simples, seguindo manual. Sem beliche, cama suspensa ou adaptacao de pecas. |
| Montagem de comoda | Candidata ao piloto, com limite | Modelo pequeno/medio e estavel, seguindo manual. Fixacao antitombamento, quando recomendada, deve ser tratada como tarefa separada e nao esta incluida sem avaliacao de parede e autorizacao do cliente. |
| Montagem de estante | Fase posterior | Somente estante baixa e autoportante pode ser avaliada; estante alta, fixacao antitombamento e ancoragem em parede ficam fora ate checklist especifico. |
| Montagem de guarda-roupa | Fase posterior | Variam dimensao, peso, estabilidade e necessidade de ancoragem/equipe. Definir limites de tamanho, numero de montadores, espaco e fixacao antes de oferecer. |
| Desmontagem e remontagem | Fase posterior | Exige avaliar estado, pecas, manual e risco de dano; sem garantia de reutilizacao de componentes desgastados e sem incluir transporte de carga pesada. |
| Montagem de rack e painel | Fase posterior para rack autoportante; painel fixado fora do piloto | O catalogo deve separar rack apoiado no piso de painel/rack suspenso. Nao incluir furacao, fixacao de carga ou passagem de cabos/eletrica no piloto. |
| Montagem de armario de cozinha | Fase posterior para modulo de piso; suspenso fora do piloto | Modulo suspenso exige ancoragem e avaliacao da parede/carga. Nao incluir ligacao hidraulica/eletrica, corte de bancada ou fixacao suspensa no recorte inicial. |
| Montagem de beliche | Fora do piloto inicial | A estabilidade e o risco de queda exigem criterio e verificacao especificos; nao tratar como cama convencional. |

#### Eletrica

Todas as tarefas abaixo ficam **fora do piloto inicial**: troca de tomada,
troca de interruptor, instalacao/troca de luminaria, troca de chuveiro eletrico,
diagnostico de falha, troca de disjuntor e instalacao de ventilador de teto.
Envolvem intervencao eletrica, circuito, quadro, potencia, suporte ou trabalho em
altura. Nao liberar com base apenas em documento enviado ou experiencia declarada.
Antes de reconsiderar cada tarefa, um profissional eletricista deve delimitar o
escopo e os controles, e a assessoria competente deve verificar requisitos
aplicaveis e como comprova-los. A NR-10 trata de seguranca em instalacoes e
servicos com eletricidade; sua aplicabilidade e os requisitos concretos devem ser
avaliados para a atividade e a relacao de trabalho, nao inferidos por esta ficha
[fonte oficial do MTE](https://www.gov.br/trabalho-e-emprego/pt-br/acesso-a-informacao/participacao-social/conselhos-e-orgaos-colegiados/comissao-tripartite-paritaria-permanente/normas-regulamentadora/normas-regulamentadoras-vigentes/norma-regulamentadora-no-10-nr-10).

#### Hidraulica

Todas as tarefas abaixo ficam **adiadas ate avaliacao de profissional
hidraulico** e definicao de limites, procedimento de interrupcao e responsabilidade
por danos. Nenhuma deve ser oferecida como "reparo simples" ate o escopo ser
validado.

| Servico proposto | Escopo e limites que precisam ser definidos |
|---|---|
| Troca de torneira | Conexoes existentes e acessiveis; definir fechamento de agua, compatibilidade e procedimento para vazamento. Sem alterar tubulacao embutida. |
| Reparo de vazamento aparente | Apenas origem visivel e acessivel, depois de avaliar urgencia e risco de inundacao. Vazamento ativo relevante deve ser encaminhado a atendimento apropriado, nao tratado como servico comum. |
| Troca de sifao | Sifao acessivel sob pia/lavatorio; definir compatibilidade, vedacao e descarte. Sem alterar tubulacao embutida. |
| Reparo de descarga | Componentes acessiveis; definir modelo e limites. Sem intervir em tubulacao embutida, caixa pressurizada ou sistema coletivo sem avaliacao. |
| Desentupimento simples | Definir metodo mecanico permitido e limite de parada. Excluir produtos causticos/perigosos, rede coletiva, equipamento de alta pressao e situacoes sem diagnostico. |
| Instalacao de filtro de agua | Ponto e equipamento compativeis, conforme fabricante; definir vedacao e teste de vazamento. Sem alteracao complexa de tubulacao. |

**Categorias ainda sem lista de tarefas nesta proposta:** manutencao generica,
ar-condicionado, reformas e outros. Nao usar esses nomes amplos como servicos
contrataveis. Primeiro decompor cada um em tarefas concretas; "Outros" deve
permanecer indisponivel ate classificacao e aprovacao da tarefa.

**Regra de evidencia:** para cada tarefa candidata, o profissional precisa
apresentar ao menos uma evidencia previamente aceita e pertinente. Para tarefas
simples, a alternativa pode ser experiencia informal estruturada (tarefas e
periodo declarados, entrevista com roteiro e, se houver, portfolio sanitizado),
ou curso relacionado. Isso documenta o que foi apresentado, mas nao prova
identidade, autenticidade, desempenho futuro ou seguranca. Se nao houver
criterio que os dois fundadores consigam aplicar de modo consistente, a tarefa
fica adiada ate um especialista definir o checklist.

**Divisao de revisao sugerida:** um fundador confere completude e aplica o
checklist; o outro faz a segunda revisao das decisoes de habilitacao. Um
profissional experiente da area ajuda a criar e validar os checklists tecnicos;
advogado/especialista de privacidade revisa finalidades, bases legais, aviso,
retencao e contestacao, nao necessariamente cada documento individual. Se houver
divergencia ou duvida tecnica, o caso fica bloqueado/inconclusivo e vai para
revisao; nao se decide por intuicao.

Antes de aceitar clientes, testar com contas e arquivos ficticios, definir como
cliente confirma quem chegou e como interromper/denunciar um servico fora do
escopo. A triagem nao substitui esses controles de atendimento.

### 1. Limpeza

**Escopo candidato:** limpeza residencial comum, com tarefas e limites descritos
antes do pedido. Deixar fora, ate avaliacao especifica, trabalho em altura,
controle de pragas, materiais perigosos, cuidado de pessoas e atividades fora de
limpeza residencial.

**O que informar/enviar:** tarefas aceitas, experiencia declarada, regiao e
disponibilidade. Documento de identidade somente se a finalidade e o processo
forem aprovados apos revisao juridica/privacidade. Certificado apenas se uma
tarefa concreta justificar requisito tecnico ou legal; nao presumir certificado
universal.

**Conferencia manual possivel:** legibilidade e consistencia aparente do arquivo;
se o escopo declarado corresponde ao servico anunciado; registrar `legivel`,
`precisa_reenvio` ou `inconclusivo` e motivo codificado.

**Nao comprova:** identidade autentica, antecedentes, confiabilidade, qualidade,
capacidade de lidar com todos os produtos ou seguranca de acesso a residencia e
pertences.

### 2. Pintura

**Escopo candidato:** pintura interna simples, com limites sobre altura,
preparacao de superficie, produtos e reparos definidos no catalogo. Deixar fora,
ate avaliacao especifica, fachada em altura, trabalho estrutural e revestimentos
industriais ou perigosos.

**O que informar/enviar:** tarefas e tecnicas oferecidas, experiencia declarada
e, se uma tarefa exigir qualificacao, a evidencia especifica definida pela equipe
apos revisao tecnica/juridica. Documento de identidade so pode ser exigido se a
finalidade e o processo forem aprovados apos revisao juridica/privacidade.

**Conferencia manual possivel:** arquivo legivel, dados aparentes coerentes,
validade visivel quando aplicavel e correspondencia entre evidencia apresentada e
servico anunciado. Um portfolio, se futuramente permitido, demonstraria apenas
trabalhos apresentados, nao autoria ou qualidade garantida.

**Nao comprova:** autenticidade de certificado ou portfolio, desempenho futuro,
capacidade para trabalho em altura, identidade de quem comparecera ou seguranca da
visita.

### 3. Manutencao

**Escopo candidato:** nao aceitar a categoria generica sozinha. Dividir a oferta
em tarefas concretas (por exemplo, pequenos ajustes ou montagem), com inclusoes e
exclusoes claras. Tarefas eletricas, hidraulicas, de gas, estruturais ou de
climatizacao seguem a ficha tecnica correspondente.

**O que informar/enviar:** tarefas individuais aceitas, limites do trabalho e
evidencias especificas apenas quando a tarefa as exigir e isso estiver aprovado.
Documento de identidade so pode ser exigido se a finalidade e o processo forem
aprovados apos revisao juridica/privacidade.

**Conferencia manual possivel:** verificar se a oferta esta suficientemente
descrita e se os documentos correspondem ao requisito definido para uma tarefa.
Se estiver ambigua, marcar inconclusiva e pedir detalhamento; nao inferir
habilitacao.

**Nao comprova:** competencia para qualquer manutencao, qualificacao em todas as
especialidades, identidade de ajudantes ou seguranca geral.

### 4. Hidraulica

**Escopo candidato:** pequenos reparos residenciais definidos tarefa por tarefa.
Deixar fora, ate definicao tecnica/juridica, gas, aquecedores, intervencoes
estruturais, redes comuns de edificio e tarefas sem criterio de qualificacao
aprovado.

**O que informar/enviar:** tarefas especificas, experiencia declarada e, quando
o requisito aplicavel estiver definido, evidencia tecnica correspondente.
Documento de identidade so pode ser exigido se a finalidade e o processo forem
aprovados apos revisao juridica/privacidade.

**Conferencia manual possivel:** legibilidade, consistencia aparente, validade
visivel e correspondencia nominal/escopo do documento. Confirmacao de emissor so
por procedimento oficial previamente definido.

**Nao comprova:** autenticidade, habilitacao legal sem consulta valida, qualidade
da execucao, inexistencia de danos ou seguranca da visita.

### 5. Eletrica

**Escopo candidato:** nao liberar servico antes de definir com profissional
tecnico competente e assessoria juridica quais tarefas podem entrar e quais
qualificacoes sao obrigatorias. Instalacoes, quadros, circuitos energizados e
intervencoes de maior risco permanecem fora ate essa definicao.

**O que informar/enviar:** tarefa exata e evidencia de qualificacao que a regra
aplicavel exigir, depois de definir como verificar emissor, validade, escopo e
eventual registro. Documento de identidade so pode ser exigido se a finalidade e
o processo forem aprovados apos revisao juridica/privacidade.

**Conferencia manual possivel:** verificar legibilidade e se os campos aparentes
correspondem ao requisito aprovado. Sem metodo confiavel junto ao emissor,
registrar somente analise documental limitada ou inconclusiva; nao marcar
qualificacao como confirmada.

**Nao comprova:** autenticidade do documento, competencia pratica, autorizacao
para qualquer instalacao, identidade de quem executara nem ausencia de risco.

### 6. Ar-condicionado

**Escopo candidato:** separar limpeza/manutencao simples de instalacao, reparo
eletrico e intervencao no circuito refrigerante. Nao incluir tarefas tecnicas mais
complexas antes de definir qualificacao, limites e procedimento de verificacao.

**O que informar/enviar:** tarefa exata, equipamentos atendidos e evidencia
tecnica somente quando exigida por criterio aprovado. Documento de identidade
so pode ser exigido se a finalidade e o processo forem aprovados apos revisao
juridica/privacidade.

**Conferencia manual possivel:** legibilidade e correspondencia aparente entre
certificado e tarefa; validade visivel quando aplicavel. Confirmar emissor apenas
por fonte oficial e procedimento aprovado.

**Nao comprova:** autenticidade, habilidade pratica, autorizacao para manusear
qualquer refrigerante, seguranca do equipamento ou da visita.

### 7. Reformas

**Escopo candidato:** manter fora do primeiro piloto enquanto for categoria
ampla. Antes de reconsiderar, decompor em tarefas especificas, avaliar cada risco
e definir responsabilidade por equipe, subcontratados, materiais e danos.

**O que informar/enviar:** nao coletar um conjunto generico para "reformas".
Primeiro selecionar uma tarefa concreta e aplicar sua matriz, incluindo regra
para cada pessoa que entraria na residencia se houver equipe.

**Conferencia manual possivel:** somente avaliar arquivo e requisito de tarefa
definida. Se escopo, equipe ou responsabilidade estiverem indefinidos, manter fora
do piloto.

**Nao comprova:** capacidade para obra completa, responsabilidade tecnica,
qualificacao de toda a equipe, seguro, qualidade ou seguranca.

### 8. Outros

**Escopo candidato:** nao permitir oferta generica no piloto. Classificar cada
servico em categoria e tarefa definidas antes de aceitar cadastro ou pedido.

**O que informar/enviar:** descricao concreta. Somente depois da classificacao se
decide quais dados ou documentos sao necessarios.

**Conferencia manual possivel:** identificar a categoria correta e encaminhar a
ficha especifica. Sem categoria/regra aprovada, marcar fora de escopo e nao coletar
documentos adicionais.

**Nao comprova:** aptidao para servicos nao classificados, qualificacao ampla ou
seguranca por estar cadastrado na plataforma.

## Registro do resultado da triagem

Para cada arquivo, a proposta e registrar somente profissional/caso e tarefa,
tipo esperado, estado, motivo codificado, revisor autorizado, data e proxima acao.
Estados candidatos: `nao_enviado`, `recebido`, `em_analise`, `precisa_reenvio`,
`inconclusivo` e `analise_documental_concluida`.

Esses estados e motivos codificados **nao estao implementados** no fluxo
documental atual. Hoje a API persiste `pendente`, `aprovado` e `rejeitado`, e
recebe motivo de rejeicao em texto livre. O desenho do contrato, da migracao e
dos cuidados de auditoria depende das decisoes e da revisao de privacidade.

### Lacunas verificadas no codigo atual

- A API local exige vinculo ao catalogo para novas ofertas e preserva as ofertas
  antigas; o app local permite escolher o servico. As migrations ainda precisam
  ser aplicadas ao banco do aplicativo em momento apropriado. Nao ha requisitos
  documentais implementados por tarefa.
- O documento pertence a um perfil profissional e tem um tipo generico; nao ha
  vinculo com categoria, oferta ou tarefa. A lista do profissional mostra apenas
  os 50 envios mais recentes. O painel admin lista arquivos individualmente com
  paginacao e filtros, sem dossie por profissional/categoria.
- Analise de documento possui somente `pendente`, `aprovado` e `rejeitado`.
  Rejeicao exige texto livre, e esse texto tambem e copiado para a auditoria.
  Definir motivos estruturados e uma forma segura de comunicacao antes de ampliar
  o processo.
- Um documento de identidade aprovado ativa o selo documental enquanto houver
  qualquer envio desse tipo aprovado. Isso nao representa uma decisao de
  habilitacao, e novas regras terao de definir revogacao, validade e reenvio.
- O envio com referencia preexistente so e recusado quando o scanner esta em modo
  `required`; confirmar a configuracao operacional antes de coletar documentos
  reais. O fluxo de exclusao de conta remove arquivos, mas ainda nao ha prazo de
  expiracao por tipo de documento nesta estrutura.
- A politica operacional presente na copia de integracao mantem identidade/prova
  de vida pendentes ate existir fluxo aprovado. Uma opcao manual com foto exigira
  revisao dessa politica e avaliacao de privacidade antes de implementacao.

`analise_documental_concluida` significa somente que a triagem documental prevista
foi realizada. Nao equivale a identidade confirmada, antecedentes verificados,
qualificacao autenticada, aprovacao final ou permissao para atender. A API continua
bloqueando solicitacoes e aceites.

## Decisoes dos responsaveis

| Tema | Decisao | Responsavel/data |
|---|---|---|
| Cobertura e participantes | Sem teto de participantes nem limite fixo de bairros; mostrar somente areas realmente atendidas | Confirmar antes de divulgar cobertura |
| Categorias e tarefas do catalogo | Lista enviada pelos responsaveis e catalogo pretendido; montagem de moveis dentro de Manutencao; cozinha/banheiro como opcoes da limpeza padrao | Escopo recebido; disponibilidade para pedidos ainda depende das revisoes e homologacao |
| Profissional individual, empresa e tratamento de equipes | Pendente | Pendente |
| Evidencia necessaria por tarefa | Uma evidencia relacionada; curso ou experiencia estruturada conforme tarefa; nao implica competencia garantida | Direcao aceita nesta conversa; checklist tecnico pendente |
| Requisitos tecnicos e verificacao oficial de emissores | Especialista define criterio para tarefas tecnicas/regulamentadas e quando fonte oficial existir | Pendente por categoria |
| Reenvio, inconclusao e contestacao | Pendente | Pendente |
| Privacidade/juridico | Principios de minimizacao discutidos; bases legais por finalidade, aviso final e prazos nao sao parecer juridico concluido | Revisao profissional pendente antes de dados reais |
| Acesso, MFA, scanner, R2, retencao e exclusao | R2 escolhido e piloto com dados sinteticos testado; producao, scanner obrigatorio, acesso, contratos, exclusao e backups ainda precisam ser homologados | Pendente; nao usar dados reais |
| Revisores, capacidade e prazo de resposta | Dois fundadores fazem triagem/segunda revisao; especialista tecnico e apoio juridico a contratar/consultar; sem SLA ate medir capacidade | Confirmar disponibilidade e procedimento |
| Suspensao, incidentes e revogacao | Pendente | Pendente |

## Fontes oficiais de referencia

- [LGPD, texto atualizado](https://www2.camara.leg.br/legin/fed/lei/2018/lei-13709-14-agosto-2018-787077-normaatualizada-pl.html)
- [ANPD: Relatorio de Impacto a Protecao de Dados Pessoais](https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/relatorio-de-impacto-a-protecao-de-dados-pessoais-ripd)
- [ANPD: guia de seguranca para agentes de tratamento de pequeno porte](https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/anonimizado___guia_orientat-_seg_da_inf_p_atpp.pdf)
- [Ministerio do Trabalho: NR-10 vigente e atualizacao com vigencia futura](https://www.gov.br/trabalho-e-emprego/pt-br/acesso-a-informacao/participacao-social/conselhos-e-orgaos-colegiados/comissao-tripartite-paritaria-permanente/normas-regulamentadora/normas-regulamentadoras-vigentes/norma-regulamentadora-no-10-nr-10)

Essas fontes orientam a avaliacao, mas nao classificam automaticamente cada
servico do ConectaLar. A aplicabilidade de normas e qualificacoes depende da
tarefa, do modo de execucao e da relacao juridica; confirmar com profissional
tecnico e assessoria juridica.

## Proxima etapa

Os dois responsaveis devem revisar o recorte recomendado acima com um profissional
experiente nas tarefas candidatas, registrar inclusoes/exclusoes e capacidade de
revisao e, em paralelo, obter revisao juridica de privacidade. So entao atualizar
o contrato da API e homologar o app/painel com dados ficticios. Nenhuma ficha,
documento ou confirmacao de telefone libera atendimento por si so.
