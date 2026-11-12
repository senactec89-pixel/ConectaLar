# Revisao manual de documentos profissionais: proposta provisoria

**Estado:** proposta para reduzir custos de fornecedor, ainda nao e aprovacao para
liberar contratacoes. O bloqueio da API deve permanecer. Este roteiro nao substitui
orientacao juridica nem comprova identidade, qualificacao, ausencia de antecedentes
ou seguranca de uma visita domiciliar.

## O que a equipe pode conferir manualmente

Com aviso de privacidade revisado e finalidade/base legal definidas, um administrador
com MFA pode fazer uma triagem limitada do documento enviado pelo profissional:

- arquivo esperado, legivel e dentro do prazo de validade aparente;
- nome exibido no documento consistente com o nome cadastrado, com procedimento para
  divergencias justificadas;
- necessidade de novo envio quando a imagem estiver cortada, ilegivel ou for de tipo
  incorreto;
- registro da decisao como `legivel`, `precisa_reenvio` ou `inconclusivo`, com motivo
  por categoria, revisor e data.

Isso e uma revisao humana de qualidade/consistencia do material, nao uma validacao de
autenticidade. Uma imagem pode ser falsa, alterada, pertencer a outra pessoa ou nao
representar quem comparecera ao domicilio. Nao exibir selo “identidade confirmada”,
“antecedentes verificados” ou promessa equivalente com base somente nessa triagem.

## Limites que permanecem

- Nao solicitar selfie, biometria, video de prova de vida nem guardar numero completo
  de documento em comentarios ou auditoria sem avaliacao juridica e de privacidade.
- Nao pedir certidao criminal nem pesquisar antecedentes por conta propria nesta fase.
  A finalidade, necessidade e tratamento desses dados precisam ser definidos antes;
  resultado isolado nao deve gerar rejeicao automatica.
- Nao baixar arquivos para computadores pessoais, enviar por WhatsApp/e-mail ou
  compartilhar capturas. Revisao somente na tela administrativa autorizada, com MFA,
  storage privado e ClamAV exigido.
- Armazenar apenas estado, categoria do motivo, revisor e data necessarios para
  auditoria. Definir prazo de retencao e processo de exclusao antes de coletar
  documentos reais para esse fim.
- Dar ao profissional uma explicacao clara, caminho para corrigir dados e revisao
  humana adicional em caso de divergencia ou contestacao.

## Antes de usar em pessoas reais

1. Revisar com profissional juridico a finalidade, base legal, aviso ao titular,
   retencao, compartilhamento, acesso e contestacao. Consentimento por si so nao deve
   ser presumido como solucao para toda categoria de dado.
2. Fazer primeiro um ensaio com documentos ficticios e bucket de homologacao.
3. Habilitar apenas a revisao de documento; manter `podeAtender=false` e a API
   bloqueando pedidos/aceites.
4. Registrar a decisao administrativa em trilha auditavel sem copiar o conteudo do
   documento para logs.
5. So discutir um piloto controlado com atendimentos depois de aprovar a politica
   completa de identidade, contato, qualificacao, antecedentes quando legalmente
   cabiveis, incidentes, cancelamento, seguro e responsabilidade.

A LGPD exige finalidade, adequacao, necessidade, transparencia e seguranca. Ela trata
biometria vinculada a pessoa como dado pessoal sensivel e limita seu tratamento a
hipoteses especificas. A definicao de processo para o ConectaLar deve ser validada por
assessoria juridica; consulte a [Lei 13.709/2018, especialmente arts. 5, 6, 9 e 11](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm)
e as [orientacoes da ANPD sobre direitos e informacao aos titulares](https://www.gov.br/anpd/pt-br/assuntos/titular-de-dados-1/direito-dos-titulares).

## Desafio manual de WhatsApp implementado (desligado por padrao)

O fluxo tecnico esta preparado, mas nao fica ativo ate a equipe controlar um numero
oficial e configurar o servidor. Nao existe envio automatico de mensagem: o app gera
um codigo de uso unico, o profissional envia a mensagem para a conta oficial e um
administrador com MFA confere o remetente e o codigo na caixa oficial. O registro so
confirma acesso ao WhatsApp naquele momento; nao confirma titularidade civil, identidade,
prova de vida, antecedentes, qualificacao ou habilitacao para atender.

Depois de comprar e ativar o chip em um WhatsApp Business controlado pela equipe, a
implantacao exige configurar no ambiente da API:

- `WHATSAPP_MANUAL_ENABLED=true`
- `WHATSAPP_MANUAL_NUMBER=55DDXXXXXXXXX` (somente digitos, com DDD e numero; nunca o
  telefone do profissional)
- `AUTH_TOKEN_SECRET` existente, forte e com pelo menos 32 bytes

O exemplo de ambiente mantem `WHATSAPP_MANUAL_ENABLED=false` e o numero vazio. Nao
ligar a flag antes de implantar a migration `1760137000000-VerificacaoManualWhatsApp`,
atualizar a API e testar em homologacao. O APK precisa estar atualizado para mostrar o
consentimento e a instrucao de envio. Proteja a conta oficial com verificacao em duas
etapas, PIN e meios de recuperacao da equipe. Nao compartilhe codigos recebidos fora do
painel administrativo.

O codigo tem oito digitos, expira em dez minutos, e so e mostrado uma vez ao titular.
O banco guarda apenas HMAC vinculado a um identificador aleatorio; ha limite persistente
de cinco tentativas por desafio, tres iniciacoes por dia e intervalo minimo de dez
minutos. Troca do telefone, expiracao, esgotamento ou confirmacao apagam o hash. A
confirmacao exige MFA, confere o telefone remetente com o numero cadastrado e grava a
mudanca junto com auditoria na mesma transacao. Confirmar telefone nao altera documento
analisado, identidade, antecedentes ou decisao final; `podeAtender` continua `false`.

Endpoints: `POST /profissionais/me/habilitacao/telefone/manual` inicia o desafio e
retorna o codigo uma vez; `GET /profissionais/me/habilitacao/telefone` consulta apenas
estado; `POST /admin/profissionais/{id}/habilitacao/telefone/confirmacao-manual`
confirma depois da conferencia humana. Respostas, URLs e auditoria nao devem incluir
o codigo em logs. Nao testar com telefone ou codigo de uma pessoa sem consentimento.
