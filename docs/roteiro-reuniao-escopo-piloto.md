# Roteiro de reuniao: escopo do piloto de profissionais

**Situacao em 2026-11-04:** roteiro aprovado como metodo de trabalho. As oito
categorias iniciais foram indicadas como candidatas (P), nao como servicos
liberados. Tarefas, exclusoes e requisitos documentais permanecem pendentes de
decisao conjunta. O usuario concordou que a evidencia de experiencia/curso seja
pertinente a cada tarefa, em vez de exigir o mesmo certificado para todas; falta
confirmacao do outro responsavel e definicao dos comprovantes aceitos.

**Atualizacao em 2026-11-05:** os dois responsaveis concordaram com os principios
de minimizacao. Isso nao aprova bases legais, prazos de retencao, aviso final nem
coleta de documentos reais.

**Encaminhamentos de produto em 2026-11-05:** seguir com evidencia por tarefa e
auditoria minima; exigir confirmacao WhatsApp para o profissional receber
solicitacoes, sem impedir a criacao da conta; planejar Cloudflare R2 para arquivos
privados. CPF/nome, antecedentes e pesquisas publicas nao estao aprovados como
procedimentos: a recomendacao inicial e nao fazer buscas abertas nem tratar CPF
como prova de identidade. Revisao juridica, configuracao e homologacao continuam
pendentes; a API deve manter as contratacoes bloqueadas.

**Preferencias para analise, ainda sem aprovacao juridica:** verificar CPF/nome,
antecedentes e fontes publicas; tornar a confirmacao WhatsApp requisito para
receber solicitacoes, sem impedir a criacao da conta; guardar arquivos em R2 com
acesso administrativo restrito. Usar o plano LGPD para delimitar essas propostas,
definir evidencia por tarefa e auditoria minima. Nao fazer pesquisas informais
nem receber documentos reais antes dos gates.

**Material consolidado para a reuniao:**
[proposta-politica-habilitacao-piloto.md](proposta-politica-habilitacao-piloto.md)
apresenta uma matriz inicial de tarefas, evidencias, retencao e contestacao. Os
prazos ali sao candidatos para discussao, nao politica aprovada ou autorizacao
para coleta. Para revisar bases legais, minuta do aviso e o portao tecnico de
documentos reais, consultar tambem
[plano-lgpd-habilitacao-profissional.md](plano-lgpd-habilitacao-profissional.md).

**Uso:** preencher durante a conversa dos responsaveis. Este roteiro registra
decisoes de produto em rascunho; nao e parecer juridico, autorizacao para coletar
documentos reais ou liberacao de contratacoes.

**Data:** __________  **Participantes:** ______________________________

## 1. Objetivo e limites

- Regiao candidata: Venda Nova, Belo Horizonte/MG. Bairros/limites exatos:
  _________________________________________________________________
- O ConectaLar ainda nao tem profissionais reais mapeados. Buscar interessados
  em todas as categorias e uma atividade de recrutamento, nao significa que todas
  entrarao no piloto.
- A tabela abaixo usa as oito categorias iniciais semeadas pela API. O
  administrador pode alterar o catalogo; conferir os nomes ativos no ambiente
  usado antes de registrar uma decisao definitiva.
- O piloto, se futuramente aprovado, sera limitado em regiao, tarefas, volume e
  periodo. O que voces querem aprender/validar primeiro?
  _________________________________________________________________
- Ate a politica completa e a homologacao serem aprovadas, a API continua
  bloqueando solicitacoes e aceites.

## 2. Decisao para cada categoria

Escolham um estado:

- **P** = candidata ao piloto; ainda precisa de tarefas exatas e dos outros gates.
- **R** = recrutar interessados, mas nao oferecer no primeiro piloto.
- **T** = depende de avaliacao tecnica/juridica antes de decidir.
- **F** = fora do escopo por enquanto.

| Categoria inicial | Estado P/R/T/F | Tarefas exatas que poderiam entrar | O que fica explicitamente fora | Responsavel / pendencia |
|---|---|---|---|---|
| Limpeza | P | Pendente | Pendente | Definir tarefas e criterios |
| Pintura | P | Pendente | Pendente | Definir tarefas e criterios |
| Manutencao | P | Pendente | Pendente | Definir tarefas e criterios |
| Hidraulica | P | Pendente | Pendente | Definir tarefas e criterios |
| Eletrica | P | Pendente | Pendente | Definir tarefas e criterios |
| Ar-condicionado | P | Pendente | Pendente | Definir tarefas e criterios |
| Reformas | P | Pendente | Pendente | Definir tarefas e criterios |
| Outros | P | Pendente | Pendente | Delimitar servicos antes de qualquer oferta |

O estado **P** registra apenas interesse. Antes de incluir uma tarefa real,
descreva seu escopo e riscos; se isso nao for possivel, reclassifique a categoria
como **T** ou **R**. Nao presuma que uma tarefa esta incluida apenas por pertencer
a uma categoria.

**Diretriz preliminar de comprovacao:** para cada tarefa ofertada, considerar uma
evidencia de experiencia, curso ou certificado pertinente ao servico. Uma
evidencia generica ou sem relacao com a tarefa nao basta. Tarefas tecnicas ou
regulamentadas podem exigir comprovacao especifica adicional. Definir formatos
aceitos, revisao, validade e alternativa para experiencia informal antes de
implementar; esta diretriz aguarda confirmacao do outro responsavel e validacao
tecnica/juridica aplicavel.

## 3. Pessoa que executa o servico

- O piloto considera profissionais individuais, empresas ou ambos?
  _________________________________________________________________
- Se uma empresa enviar equipe, cada pessoa que podera entrar na residencia sera
  cadastrada e avaliada individualmente? Como impedir substituicao por pessoa nao
  avaliada?
  _________________________________________________________________
- Limite inicial de profissionais/atendimentos, se um piloto vier a ser aprovado:
  _________________________________________________________________

## 4. Dados e documentos: decidir necessidade, nao coletar agora

Para cada categoria marcada **P**, preencher:

| Categoria/tarefa | Qual decisao ou risco exige este dado/documento? | Minimo necessario | Como seria revisado? | O que a revisao nao provaria? | Validacao pendente |
|---|---|---|---|---|---|
| __________________ | __________________ | __________________ | __________________ | __________________ | __________________ |
| __________________ | __________________ | __________________ | __________________ | __________________ | __________________ |
| __________________ | __________________ | __________________ | __________________ | __________________ | __________________ |

Perguntas para cada documento proposto:

1. Sem esse dado, qual decisao concreta nao pode ser tomada?
2. Existe alternativa menos invasiva? Evitar comprovante de endereco por padrao.
3. Quem tera acesso, por qual sistema, por quanto tempo e como sera excluido?
4. A equipe tem um meio oficial e confiavel de verificar emissor/validade, ou so
   consegue avaliar legibilidade e consistencia aparente?
5. Como o profissional corrige divergencia, reenvia ou contesta?

Nao decidir nesta reuniao uma coleta de selfie/biometria ou antecedentes sem
orientacao juridica e de privacidade. Nao fazer pesquisa informal de antecedentes.
Telefone confirmado por WhatsApp comprova somente acesso ao canal naquele
momento; nao e prova de identidade.

### Identidade, foto e antecedentes: decisoes separadas

- Qual metodo de identidade esta sendo considerado? __________________________
- Se a equipe cogita comparar manualmente foto e documento, qual seria a
  finalidade, a alternativa para quem nao puder usar esse metodo, quem faria a
  revisao e como seriam tratados erros e contestacoes? ________________________
- Antes de qualquer coleta de foto, definir com orientacao juridica e de
  privacidade necessidade, base legal, aviso, acesso, retencao, exclusao e
  tratamento de backups. Uma comparacao visual nao equivale a prova de vida.
- Antecedentes continuam pendentes: qual decisao juridica e operacional falta?
  ___________________________________________________________________________
- A politica operacional existente na copia de integracao mantem identidade/
  prova de vida pendentes ate haver fluxo aprovado e homologado. Qualquer metodo
  manual futuro exige revisar essa politica; a analise documental atual nao a
  substitui.

## 5. Operacao e atendimento

- Quem revisaria casos e quem seria substituto? ______________________________
- Quantos casos por semana a equipe consegue revisar de verdade? ______________
- Qual prazo consegue cumprir sem prometer antes de testar? ___________________
- O que fazer com caso ilegivel, divergente, inconclusivo ou contestado?
  _________________________________________________________________
- Como receber e tratar incidente, reclamacao, dano, cancelamento ou suspeita de
  pessoa diferente da cadastrada? ___________________________________________

## 6. Resultado da reuniao

### Decidido em rascunho

- Regiao/bairros: __________________________________________________
- Categorias/tarefas candidatas: ____________________________________
- Categorias para recrutamento, mas fora do piloto inicial: ____________
- Categorias bloqueadas por avaliacao tecnica/juridica: _______________

### Em aberto: responsavel e proxima acao

| Pendencia | Responsavel | Proximo passo | Data para revisar |
|---|---|---|---|
| __________________________ | __________ | __________________________ | __________ |
| __________________________ | __________ | __________________________ | __________ |
| __________________________ | __________ | __________________________ | __________ |

### Gate antes de qualquer atendimento real

Marcar somente quando houver evidencias, nao apenas intencao:

- [ ] Politica de habilitacao aprovada pelos responsaveis.
- [ ] Requisitos por tarefa definidos e revisao tecnica/juridica obtida onde
      necessaria.
- [ ] Aviso de privacidade, finalidade, acesso, retencao, exclusao e contestacao
      revisados antes de dados reais.
- [ ] Armazenamento privado, scanner, autorizacao/MFA, auditoria e procedimento de
      incidente homologados.
- [ ] Fluxos testados com dados ficticios; falhas de storage/scanner bloqueiam a
      aprovacao.
- [ ] Equipe, capacidade, limites e suporte do piloto definidos.
- [ ] Mudanca de regra de contratacao aprovada separadamente e testada; ate la,
      API segue bloqueando pedidos e aceites.
