# Plano de privacidade para habilitacao profissional

**Status:** material de trabalho para os dois responsaveis e revisao juridica.
Nao e parecer, aviso final, declaracao de conformidade ou autorizacao para
receber documentos reais. Nao coletar identidade, certificados ou fotos reais
ate os gates da secao 7 serem atendidos.

**Texto recebido para avaliacao:** as propostas sobre finalidades, fornecedores,
direitos e incidentes foram organizadas na secao 8. Elas nao substituem revisao
profissional nem alteram a politica de habilitacao ou o bloqueio de pedidos.

**Decisao conjunta em 2026-11-05:** os responsaveis aprovaram os principios de
minimizacao descritos na secao 1. A aprovacao e somente dessa diretriz; nao fecha
bases legais, prazos, texto final do aviso, fornecedores ou autorizacao para
coletar documentos reais.

**Encaminhamentos de produto em 2026-11-05 (nao sao aprovacao juridica nem
autorizacao de coleta):** seguir com evidencia pertinente a cada tarefa e com a
auditoria minima da secao 3; exigir confirmacao do telefone por WhatsApp para o
perfil receber solicitacoes, sem impedir a criacao da conta; adotar Cloudflare R2
como destino planejado dos arquivos privados. O desejo de avaliar CPF/nome,
antecedentes e fontes publicas foi registrado, mas a recomendacao para a primeira
fase e nao fazer pesquisas de antecedentes ou buscas abertas e nao usar CPF como
prova de identidade. Qualquer consulta adicional depende de analise juridica,
necessidade por tarefa, aviso, contestacao e controles tecnicos.

## 1. Principios aprovados pelos responsaveis

Em 2026-11-05, os dois responsaveis aprovaram como principios de produto:

- coletar somente o minimo necessario para uma finalidade especifica;
- vincular evidencia a tarefa e aceitar somente criterio relacionado ao servico;
- nao pedir comprovante de endereco, selfie/biometria ou antecedentes por padrao;
- nao pesquisar antecedentes informalmente;
- restringir documentos a revisores autorizados, nao mostrar arquivos a clientes e
  permitir correcao, reenvio e contestacao;
- nao dizer que triagem manual prova autenticidade, identidade, qualificacao
  completa ou seguranca;
- nao liberar contratacoes com base em uma unica verificacao.

Isso e uma direcao prudente, mas nao fecha a base legal, os prazos ou a operacao.
Consentimento, quando usado, nao substitui a hipotese legal adequada nem corrige
coleta excessiva ou aviso incompleto.

## 2. Inventario e bases legais candidatas

As hipoteses abaixo sao pontos para avaliacao, nao conclusoes. A escolha deve ser
feita para cada finalidade concreta, registrada pelo controlador e revisada por
advogado com acesso ao modelo de negocio, contratos, telas e fornecedores. Nao
marcar varias bases como alternativas genericas para usar depois.

| Finalidade | Dados estritamente possiveis | Hipotese a avaliar | Decisao/salvaguarda pendente |
|---|---|---|---|
| Criar conta e operar cadastro | Identificadores de conta, contato, perfil e ofertas | Execucao de contrato/procedimentos preliminares solicitados pelo titular (art. 7, V) | Separar o necessario para abrir conta do requisito para publicar ou contratar. |
| Confirmar acesso ao telefone | Numero, estado, datas; desafio temporario | Procedimentos preliminares (art. 7, V); legitimo interesse (art. 7, IX) somente se necessario e documentado | Definir fornecedor, finalidade, prazo dos metadados e consequencia de nao fornecer. Nunca guardar OTP em texto/log. |
| Revisar documento de identidade | Imagem/documento e resultado minimo da revisao | Procedimentos preliminares (art. 7, V) ou outra hipotese comum aplicavel, a justificar | Documento nao e automaticamente necessario apenas porque a plataforma deseja verificar. Avaliar se basta reter o resultado da revisao. |
| Revisar experiencia/curso por tarefa | Certificado ou evidencia minima de experiencia | Art. 7, V; legitimo interesse (art. 7, IX) somente com finalidade, necessidade e balanceamento; obrigacao legal (art. 7, II) apenas se houver norma concreta | Citar a tarefa e a norma, quando existir. Nao exigir certificado generico nem aceitar evidencia sem relacao. |
| Registrar decisao/auditoria | Estado, revisor, horario, motivo codificado e versao do dossie | Exercicio regular de direitos (art. 7, VI) quando aplicavel; legitimo interesse com teste; obrigacao legal se identificada | Prazo proprio, acesso e correcao de dados inexatos. Metadado pseudonimizado ainda pode ser dado pessoal. |
| Selfie/identificacao biometrica | Nao coletar nesta fase | Se futuramente proposto, avaliar bases especificas do art. 11; art. 11, II, g pode ser relevante a sistemas eletronicos de identificacao/autenticacao, mas nao e permissao automatica | Necessidade, proporcionalidade, alternativa, aviso, acesso, impacto e retencao. Analise visual nao deve ser chamada de prova de vida. |
| Antecedentes criminais | Nao coletar nem pesquisar nesta fase | Sem hipotese aprovada | Revisao juridica especifica de necessidade por tarefa, fonte, exatidao, impacto, contestacao e risco de discriminacao. |
| Direitos, exportacao e exclusao | Dados da conta e historico necessario ao pedido | Obrigacoes legais e, conforme o caso, exercicio regular de direitos (art. 7, VI) | Canal, verificacao do solicitante, prazos aplicaveis, excecoes de conservacao e resposta. |

Para dado sensivel, nao usar legitimo interesse do art. 7, IX: avaliar as bases
especificas do art. 11. Um aceite generico dos termos nao deve ser usado para
cobrir todos os tratamentos. Se a coleta for condicao para o piloto, informar
isso com destaque e explicar a consequencia de nao fornecer.

### CPF, identidade, antecedentes e fontes publicas: limites da proposta

**Recomendacao para a primeira fase:** separar tres perguntas: (a) o CPF tem
formato/digitos validos; (b) qual e a situacao cadastral informada pela fonte
oficial; (c) a pessoa que abriu a conta e a titular. A primeira e apenas
matematica; a segunda nao responde a terceira. Nao integrar consulta de CPF/nome
nem declarar identidade confirmada ate assessoria juridica e de privacidade
aprovar a finalidade, a fonte, a base legal, a informacao ao titular e o metodo de
resolver divergencias. Para a seguranca do cliente, combinar controles de
produto/operacao e evidencia pertinente a tarefa; nao substituir isso por uma
busca de antecedentes ampla.

- Validar os digitos/formato do CPF so demonstra que o numero passa por uma
  verificacao matematica; nao demonstra que pertence a quem enviou o cadastro.
- A consulta oficial da Receita Federal usa dados de entrada e informa situacao
  cadastral. Mesmo uma correspondencia aparente de nome/data nao e prova de que a
  pessoa presente controla o CPF. Se considerada, fazer com conhecimento e
  participacao do titular, registrar somente o resultado minimo e nao guardar
  credenciais nem fazer consultas em bases nao autorizadas.
- A certidao da Policia Federal nao e uma afirmacao geral de que alguem "nao tem
  antecedentes": o servico informa `nada consta` conforme o escopo definido na
  propria fonte, e alerta que ocorrencias de homonimia podem exigir confirmacao.
  Uma certidao ou resultado isolado nao mede risco futuro nem prova seguranca.
- A LGPD tambem se aplica a informacoes encontradas em fontes publicas. Nao fazer
  pesquisas abertas em redes sociais, mecanismos de busca, grupos, bases vazadas
  ou agregadores para montar dossie. Se a tarefa exigir uma credencial/registro,
  considerar somente fonte oficial pertinente a essa credencial, com finalidade,
  base legal, transparencia, minimizacao e caminho para corrigir divergencias.
- Nao rejeitar por homonimia, processo sem condenacao definitiva, noticia ou
  resultado automatico. Antecedentes continuam fora do fluxo ate advogado definir
  se existe necessidade e base legal para uma verificacao especifica por tarefa,
  quais fontes podem ser usadas, como tratar divergencia/contestacao e por quanto
  tempo guardar o resultado. A LGPD nao cria uma autorizacao geral para investigar
  candidatos.

### Proposta pratica de evidencia por tarefa

Usar uma matriz aprovada antes do cadastro real. Para cada tarefa, listar um
requisito minimo e os meios aceitaveis para demonstrar o mesmo requisito, sem
obrigar todas as pessoas a possuirem certificado generico:

1. **Atividade regulamentada ou de risco elevado:** exigir a qualificacao,
   registro ou habilitacao especifica que a avaliacao tecnica/juridica confirmar;
   conferir em fonte oficial quando houver. Sem criterio e forma de confirmacao,
   tarefa fica fora do piloto.
2. **Tarefa nao regulamentada com curso pertinente:** aceitar certificado de
   curso cujo conteudo e escopo tenham relacao clara com a tarefa. Conferir apenas
   os dados necessarios e emissor por canal confiavel, se disponivel.
3. **Experiencia informal ou pratica:** criar alternativas previamente definidas,
   como declaracao estruturada de tarefas/periodo/escopo mais portfolio sanitizado
   ou entrevista estruturada. Uma declaracao sozinha nao autentica competencia.
   Nao exigir nota fiscal/contrato com dados integrais de clientes; se uma amostra
   for indispensavel, remover nomes, CPF, telefone, endereco, rostos e metadados
   antes do envio. Nao contatar referencia sem permissao e base/finalidade
   aprovadas.
4. **Revisao:** marcar separadamente arquivo legivel, evidencia relacionada a
   tarefa, verificacao oficial do emissor (quando feita) e decisao da tarefa. Nao
   converter esses itens em selo amplo de identidade/seguranca.

Como primeira proposta, definir uma ficha para cada tarefa, preencher com
especialista quando tecnica e testar a compreensao com profissionais ficticios.
Limpeza, pintura interna e pequenas montagens podem estudar evidencia de
experiencia/curso relacionado; eletrica, gas, circuito de refrigeracao, reformas
amplas e qualquer atividade regulamentada ficam bloqueadas ate criterio
tecnico/juridico especifico. Isso e uma sugestao de escopo, nao uma decisao final.

### Requisito de WhatsApp

Encaminhamento de produto: a conta pode existir, mas o perfil nao recebe nem
aceita solicitacoes ate confirmar o acesso ao numero por WhatsApp. A confirmacao
nao prova identidade civil nem titularidade juridica do numero. O fluxo deve
explicar a consequencia antes do envio, invalidar a confirmacao quando o numero
mudar, limitar reenvios/tentativas e oferecer suporte para numero incorreto,
indisponibilidade ou falha do fornecedor. O suporte nao pode marcar o telefone
como confirmado sem uma verificacao equivalente. Antes de producao, aprovar base
legal, aviso, prazo dos metadados, custo/fornecedor e alternativa razoavel para
quem nao consegue usar WhatsApp. A conta nao deve ser excluida apenas por nao
concluir a confirmacao.

## 3. Auditoria minima proposta

Para conseguir revisar uma decisao sem copiar o dossie para logs, registrar em
trilha protegida:

- identificador interno do caso/profissional e, se aplicavel, da tarefa;
- tipo/ID interno do item analisado, nunca bytes, URL publica ou conteudo do
  documento;
- estado anterior e novo, motivo enumerado, proxima acao e versao da regra;
- ID individual do revisor, data/hora UTC e resultado da segunda revisao quando
  exigida;
- abertura/fechamento de contestacao e resultado, sem narrativa sensivel;
- acesso ao arquivo (administrador, item, horario e resultado), sem registrar o
  conteudo transferido.

Nao registrar CPF completo, imagem, selfie, OTP, segredo, token, dados de
antecedentes ou observacao livre em log/auditoria. Definir prazo proprio para
auditoria, papeis autorizados, deteccao de acesso indevido e processo de correcao.
Encaminhamento aceito para o desenho: usar essa trilha minima. Dois revisores
podem ser aplicados a decisoes de maior impacto se a operacao conseguir cumprir;
isso nao justifica acesso indiscriminado de toda conta administrativa. Definir
papeis por funcao, contas individuais, MFA, revisao periodica de acessos e alerta
para consultas incomuns.

## 4. Metodo e prazos candidatos de retencao

A LGPD nao fixa prazo universal. Para cada dado, documentar finalidade; campo
exato; evento que inicia a contagem; quem precisa dele; evento que encerra a
necessidade; excecao legal concreta; destino em banco, storage, logs e backups; e
como provar a exclusao. Nao manter arquivo "para o caso de ser util".

Os prazos abaixo sao **candidatos operacionais**, nao prazos garantidos pela
LGPD. A janela de contestacao nao limita direitos legais do titular.

| Classe | Proposta inicial | Evento e justificativa a aprovar |
|---|---|---|
| Upload sem registro concluido | Limpeza em ate 24h, com retry/alerta ate apagar | Contar do upload. Prazo operacional para objeto orfao, nao retencao documental. Provar reconciliacao e falhas de storage. |
| Documento de identidade bruto | Apagar ate 7 dias apos decisao documental; se contestacao aberta, ate decisao final + 7 dias | A imagem pode deixar de ser necessaria apos a triagem; permitir reenvio se houver contestacao posterior. Validar necessidade real. |
| Evidencia de experiencia/curso | Enquanto tarefa estiver ativa e evidencia for necessaria/valida; iniciar encerramento quando oferta for removida ou evidencia expirar | Rever necessidade/validade. Candidato: apagar ate 7 dias depois do fim da janela de contestacao. |
| Caso inconclusivo, rejeitado ou arquivo substituido | Manter o minimo bruto necessario ate fim da janela interna candidata de 30 dias; apagar ate 7 dias depois, salvo contestacao aberta | Justificar por que o arquivo original e necessario. Alternativa: apagar antes e aceitar novo envio para contestacao. |
| Decisao/auditoria | Prazo nao fixado | Tabela separada, com evento e fundamento. Guardar ator, acao, estado, data e motivo codificado; nao copiar documento, CPF completo, selfie ou narrativa criminal. |
| Desafio WhatsApp | OTP expira no fluxo atual em 10 minutos; nao conservar apos sucesso/expiracao/limite | Confirmar em producao. Metadados de telefone, estado e datas precisam de prazo proprio. |
| Backups | Definir ciclo e limite antes de documentos reais; avaliar rotacao criptografada de ate 30 dias | Verificar fornecedor, acesso, restauracao e expiracao; apos restore, reaplicar exclusoes pendentes antes de reabrir o servico. |

Preservacao por disputa ou obrigacao legal deve indicar base concreta, campos,
responsavel, acesso restrito e data de reavaliacao. Nao transformar excecao em
retencao indefinida. Substituir os candidatos se a equipe nao demonstrar
necessidade e capacidade de cumprir os prazos.

## 5. Minuta de aviso do fluxo profissional

**Nao publicar nem exibir como aviso final.** Preencher campos, confirmar
fornecedores e obter revisao juridica.

> **Analise do cadastro profissional**
>
> O controlador deste tratamento e **[nome legal / CNPJ / contato]**. Usaremos
> **[listar dados/documentos]** para **[finalidade especifica por tarefa]**, com
> fundamento em **[hipotese legal e justificativa aprovada]**. O envio de
> **[itens obrigatorios]** e necessario para **[consequencia real de nao enviar]**;
> **[itens opcionais]** sao opcionais e nao impedem **[o que continua disponivel]**.
>
> Os arquivos serao acessados somente por **[papeis autorizados]** no sistema
> **[storage/localizacao]**. **[Fornecedores/suboperadores e finalidade]** podem
> tratar dados para hospedagem, seguranca e operacao. Se houver transferencia
> internacional, informar pais, mecanismo legal e salvaguardas. Clientes nao
> recebem os documentos.
>
> A revisao humana verifica **[criterios objetivos]**. Ela nao garante
> autenticidade, identidade civil, antecedentes, qualidade futura ou seguranca da
> visita. O resultado pode ser pendente, pedido de reenvio ou inconclusivo. Voce
> pode corrigir dados, reenviar e contestar por **[canal]**. A janela interna de
> contestacao **[prazo aprovado]** nao reduz seus direitos previstos na LGPD.
>
> O arquivo sera eliminado **[prazo por tipo/evento]**; registros minimos e
> backups seguem **[prazos/regras]**. Para acessar/corrigir dados, pedir bloqueio
> ou eliminacao quando cabivel, ou perguntar sobre compartilhamentos, use
> **[canal de privacidade]**. Politica completa: **[URL]**.

O aviso precisa ser apresentado antes do envio, em linguagem clara e acessivel.
Registrar versao e data do aviso exibido. Se houver consentimento para uma
finalidade especifica, destacar separadamente; nao agrupar consentimento de
biometria, marketing e termos do servico.

## 6. Fornecedores, storage e riscos tecnicos encontrados

Encaminhamento de produto: Cloudflare R2 sera o destino planejado para documentos
privados. Isso nao significa que esteja configurado ou liberado para dados reais.
Inventariar hospedagem da API, MySQL, R2, backup, e-mail, WhatsApp e scanner:
entidade, papel (controlador/operador), localizacao, dados acessados,
suboperadores, prazo, exclusao, incidentes, suporte e contrato/instrucoes. Se
houver transferencia internacional, validar mecanismo conforme LGPD e Resolucao
CD/ANPD 19/2024 e refletir no aviso.

Na copia analisada, `POST /profissionais/me/documentos` aceita documento de
identidade, comprovante de endereco e certificados; nao encontrei nessa rota uma
flag que suspenda o recebimento. O download administrativo e autenticado, e o
`AuthGuard` exige MFA ativo para administradores. Isso restringe acesso, mas nao
define base legal, necessidade ou prazo. A operacao documentada usa storage local
privado quando R2 nao esta configurado.

A exportacao LGPD inclui arquivos de verificacao em Base64 dentro do JSON
compartilhavel do aparelho. Isso da acesso ao titular, mas pode expor documento
no compartilhamento geral do sistema. Revisar entrega separada por download
autenticado/expiravel, sem retirar o direito de acesso do titular.

Antes da coleta, provar: bucket R2 privado sem acesso publico; credenciais
limitadas ao bucket e operacoes necessarias, mantidas somente no servidor; sem
chaves no app; URLs temporarias apenas quando indispensaveis; TLS;
criptografia/gestao de chaves; contas administrativas individuais com MFA e
permissoes por funcao; log de acesso sem conteudo; scanner obrigatorio; limpeza
de uploads orfaos; exclusao verificavel tambem em backups; restauracao; resposta
a incidente; contratos/instrucoes com operadores; avaliacao de localizacao e
transferencia internacional; e autorizacao testada por perfil. Nao compartilhar
uma conta administrativa. Acesso duplo reduz erro, mas tambem aumenta pessoas
expostas; aplicar acesso sob demanda.

## 7. Portao antes de documentos reais

- [ ] Definir controlador, contato de privacidade, entidade responsavel e relacao
      entre os dois socios.
- [ ] Preencher inventario, finalidade e base legal por finalidade; obter revisao.
- [ ] Finalizar aviso com direitos, fornecedores, paises, prazos e consequencias.
- [ ] Aprovar retencao por tipo e demonstrar exclusao, retry, alerta e tratamento
      de backups em teste.
- [ ] Revisar exportacao com arquivos Base64 e homologar alternativa segura.
- [ ] Revisar contratos/instrucoes de operadores e transferencia internacional.
- [ ] Configurar R2 em bucket privado, com credenciais restritas, contas individuais,
      MFA e teste de exclusao/recuperacao; confirmar localizacao e termos aplicaveis.
- [ ] Habilitar upload deliberadamente por ambiente. Enquanto pendente, desabilitar
      no servidor de producao; esconder botao no app nao bloqueia chamadas API.
- [ ] Homologar scanner, storage, autorizacao, MFA, auditoria, logs e incidente
      com arquivos ficticios e papeis diferentes.
- [ ] Definir revisores, treinamento, contestacao e alternativa inconclusiva.
- [ ] Confirmar que selfie/biometria e antecedentes continuam fora desta etapa.

Se qualquer item falhar, manter coleta real desativada e contratacoes bloqueadas.
O codigo atual pode aceitar documentos numa instancia implantada; confirmar a
configuracao do servidor, nao apenas o texto do aviso.

## 8. Propostas recebidas para revisao

Este registro organiza o texto apresentado por um dos responsaveis. As bases
legais, prazos de operacao, medidas e papeis abaixo sao candidatos para analise,
nao escolhas finais, revisao juridica concluida ou autorizacao de coleta. As
implementacoes e os fornecedores precisam ser conferidos no ambiente real.

### Finalidade e necessidade

Usar a tabela da secao 2 como ponto de partida e separar cada operacao e sua
finalidade. O texto recebido propoe, entre outras, avaliar conta e comunicacao;
confirmacao de acesso ao telefone; ofertas e experiencia; qualificacao por
tarefa; eventual identidade; seguranca/auditoria; e dados do atendimento. Para
cada operacao, identificar exatamente os dados, necessidade, alternativas e
hipotese legal, sem escolher uma base generica para todos os usos.

- O texto sugere experiencia estruturada como alternativa a certificado para
  algumas tarefas, sem excluir requisitos especificos que sejam confirmados na
  avaliacao tecnica e juridica. Nenhum dos meios garante competencia.
- Nao exigir comprovante de endereco automaticamente. Diferenciar endereco para
  executar um atendimento, quando necessario, de comprovante documental.
- Nao coletar selfie, biometria ou antecedentes nesta etapa. Documento de
  identidade e consultas externas dependem de decisao e procedimento aprovados.
- Adiar documentos de identidade ou outros mecanismos nao elimina o bloqueio:
  a politica atual mantem identidade/prova de vida pendentes e nao permite
  contratacoes. Sem metodo e controles aprovados e homologados, nao abrir piloto
  com atendimentos reais.
- Identificar a entidade efetivamente responsavel e os papeis dos fornecedores
  conforme as atividades e contratos reais. Nao presumir que a pessoa juridica
  ja existe ou que todos os fornecedores sao operadores.

### Aviso, acesso e fornecedores

Proposta para o aviso: explicar responsavel e contato; dados e finalidades;
bases avaliadas; itens necessarios ou opcionais; compartilhamentos e eventuais
transferencias; prazos; direitos; decisoes automatizadas, se existirem; e como
mudancas serao comunicadas. A minuta da secao 5 nao e aviso final.

Inventariar hospedagem, banco, R2, backups, WhatsApp, scanner, e-mail e demais
servicos efetivamente usados; incluir pagamentos somente se forem adotados.
Revisar papeis, acesso, subprocessadores, locais, exclusao, incidentes e
contratos. Escolher R2 nao significa que producao esteja homologada. Se houver
transferencia internacional, avaliar a operacao e o mecanismo aplicavel com a
assessoria, conforme a [Resolucao ANPD 19/2024](https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-19-de-23-de-agosto-de-2024).

Direcao proposta: documentos apenas para revisores autorizados; resultados ao
profissional e papeis administrativos conforme necessidade; auditoria restrita;
separar permissoes de desenvolvimento e administracao. MFA, armazenamento
privado, acessos individuais e registro de consulta precisam ser homologados,
nao apenas descritos como existentes.

### Retencao, direitos e incidentes

- Manter em aberto os prazos concretos de cadastro, documentos, arquivos
  substituidos e logs; justificar cada prazo por finalidade e avaliar exclusao,
  anonimizacao e ciclo de backup. Os numeros da secao 4 sao apenas candidatos.
- A [ANPD informa](https://www.gov.br/anpd/pt-br/assuntos/noticias/anpd-aprova-o-regulamento-de-comunicacao-de-incidente-de-seguranca)
  a manutencao de registros de incidentes com dados pessoais por pelo menos
  cinco anos; isso nao e prazo generico para documentos ou todos os logs.
- Propor canal para pedidos de acesso, correcao, exclusao quando cabivel e
  informacoes sobre compartilhamento, com protocolo e resposta registrados.
  Um dos responsaveis concordou com correcao e reenvio; detalhes e procedimento
  de contestacao de decisao ainda precisam ser definidos com ambos e revisados.
- A [LGPD, art. 19](https://www2.camara.leg.br/legin/fed/lei/2018/lei-13709-14-agosto-2018-787077-normaatualizada-pl.html),
  distingue confirmacao/acesso simplificado imediato de declaracao completa em
  ate 15 dias. A [Resolucao ANPD 2/2022](https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-2-de-27-de-janeiro-de-2022)
  preve prazo diferenciado em casos previstos para agentes elegiveis. Nao
  presumir enquadramento ou aplicar esse prazo a todos os direitos; confirmar com
  assessoria e conferir a regra vigente em cada caso.
- Para incidentes, propor conter, preservar evidencias, avaliar dados e riscos,
  comunicar quando aplicavel, corrigir e registrar. A
  [ANPD](https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/comunicado-de-incidente-de-seguranca-cis)
  informa prazo geral de tres dias uteis para comunicacao aplicavel, com regras
  e excecoes especificas. Verificar termo inicial, eventual prazo em dobro para
  agente elegivel e obrigacoes especiais com assessoria; nao esperar para iniciar
  a resposta. Reclamacao sobre servico nao e automaticamente incidente de dados.

### Decisoes e verificacoes ainda abertas

| Tema | Proximo passo | Situacao |
|---|---|---|
| Controlador e fornecedores | Identificar entidade, atividades, contratos e transferencias reais | Pendente |
| Dados, finalidades e bases | Completar inventario e obter revisao juridica por operacao | Pendente |
| Aviso e direitos | Definir canal, protocolo, respostas e texto aplicavel | Pendente |
| Retencao e exclusao | Definir prazos por finalidade e testar arquivos, logs e backups | Pendente |
| Identidade e habilitacao | Definir e homologar metodo e controles antes de atendimento real | Pendente; pedidos bloqueados |
| Incidentes e acessos | Definir responsaveis, canais e testar scanner, MFA e resposta | Pendente |

## Referencias oficiais

- [LGPD, texto atualizado](https://www2.camara.leg.br/legin/fed/lei/2018/lei-13709-14-agosto-2018-787077-normaatualizada-pl.html)
- [ANPD: termino e conservacao](https://www.gov.br/anpd/pt-br/acesso-a-informacao/perguntas-frequentes)
- [ANPD: direitos dos titulares](https://www.gov.br/anpd/pt-br/assuntos/titular-de-dados/direito-dos-titulares)
- [ANPD: guia de seguranca para agentes pequenos](https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/anonimizado___guia_orientat-_seg_da_inf_p_atpp.pdf)
- [ANPD: transferencia internacional, Resolucao 19/2024](https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-19-de-23-de-agosto-de-2024)
