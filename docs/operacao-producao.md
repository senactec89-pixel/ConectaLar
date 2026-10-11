# Operacao e seguranca da API

Este documento registra a base operacional atual do backend ConectaLar. Ele nao substitui revisao juridica, contrato de infraestrutura ou politica final de retencao.

## Controles ja implementados

- Erros HTTP usam resposta generica e nao retornam stack trace, SQL, headers, corpo da requisicao ou token.
- CORS em producao depende de `CORS_ALLOWED_ORIGINS`; em desenvolvimento, origens locais sao permitidas.
- Cabecalhos de seguranca basicos sao aplicados em todas as respostas: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` e `Permissions-Policy`.
- Rate limit local por cliente usa `RATE_LIMIT_WINDOW_MS` e `RATE_LIMIT_MAX`.
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

O rate limit em memoria protege o ambiente local e uma instancia simples, mas nao substitui limite distribuido quando houver mais de uma instancia. Upload binario local nao substitui storage gerenciado, antivirus, politica de retencao documental e fluxo de download seguro. MFA administrativo, pipeline de deploy e teste de carga completo seguem como pendencias de producao.
