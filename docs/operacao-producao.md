# Operacao e seguranca da API

Este documento registra a base operacional atual do backend ConectaLar. Ele nao substitui revisao juridica, contrato de infraestrutura ou politica final de retencao.

## Controles ja implementados

- Erros HTTP usam resposta generica e nao retornam stack trace, SQL, headers, corpo da requisicao ou token.
- CORS em producao depende de `CORS_ALLOWED_ORIGINS`; em desenvolvimento, origens locais sao permitidas.
- Cabecalhos de seguranca basicos sao aplicados em todas as respostas: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` e `Permissions-Policy`.
- Rate limit global e limites mais estritos para rotas de autenticacao usam `RATE_LIMIT_WINDOW_MS` e `RATE_LIMIT_MAX`, com contadores em memoria por processo.
- `TRUST_PROXY_HOPS` define quantos proxies o Express pode confiar para resolver o IP. O padrao e `0`; nao aumente sem confirmar a cadeia real da hospedagem.
- Tokens sao invalidados quando a senha muda ou quando o usuario faz logout.
- Acoes administrativas sensiveis sao registradas em `admin_auditoria`.
- Endereco completo do cliente fica protegido por regra de autorizacao no backend.
- Upload de documento de verificacao aceita somente PDF, JPEG ou PNG ate 5 MB e grava em armazenamento local privado, sem URL publica.

## Backup e restauracao

Para producao, o banco MySQL deve ter backup automatico diario, backup antes de migracoes e teste periodico de restauracao. O procedimento minimo recomendado:

1. Gerar dump criptografado antes de cada deploy com migracao.
2. Guardar backups fora da maquina da API.
3. Testar restauracao em ambiente separado antes de considerar o backup confiavel.
4. Documentar responsavel, data, horario, tamanho do arquivo e resultado do teste.

## Monitoramento

Os logs atuais sao estruturados e minimizam dados pessoais. Em producao, conectar stdout/stderr a uma plataforma de observabilidade com alerta para:

- falha de inicializacao da API;
- aumento de erros 401, 403, 429 e 5xx;
- falhas de migracao;
- queda ou lentidao do MySQL;
- crescimento anormal da tabela de auditoria, notificacoes ou mensagens.

## Limites pendentes

Codigos de recuperacao e verificacao agora possuem quotas persistidas no MySQL por conta (ate tres emissoes numa janela fixa de uma hora iniciada no primeiro envio, intervalo minimo de um minuto) e ate cinco tentativas por codigo; a migracao `1760135000000-LimitesPersistentesCodigosAuth` precisa ser aplicada antes de publicar esta versao. O rate limit por IP continua em memoria e nao coordena multiplas instancias. Antes do lancamento publico, configurar protecao distribuida na borda e homologar o IP real recebido pela API. Upload binario local nao substitui storage gerenciado, antivirus, politica de retencao documental e fluxo de download seguro. Pipeline de deploy e teste de carga completo seguem como pendencias de producao.
