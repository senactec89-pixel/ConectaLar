# Segurança — estado atual e pendências

Atualizado para o código disponível em main, commit 0264eab, em 11/10/2026. Este documento registra controles técnicos observados no repositório; não é certificação de segurança ou conformidade legal.

## Controles existentes

- Senhas são armazenadas com hash scrypt.
- A API autentica com token, aplica papéis nas rotas e invalida tokens após logout ou troca de senha.
- A senha nova exige maiúscula, minúscula, número e caractere especial, além do mínimo e máximo de tamanho.
- O filtro HTTP evita retornar stack traces e mensagens internas. Erros públicos conhecidos recebem mensagens tratadas.
- CORS usa lista permitida; há cabeçalhos básicos de segurança.
- Logs HTTP não registram corpo, token ou cabeçalhos de autorização.
- O rate limit existe em memória para uma instância.
- Endereço completo é protegido na API antes das condições autorizadas.
- Upload de documentos limita o tamanho e aceita PDF, JPEG e PNG pelo contrato. Os arquivos são armazenados em diretório privado local; não há URL pública de arquivo.

## Limites que precisam ser resolvidos

- Recuperação de senha tem integração SMTP configurável por ambiente. Em produção, a API exige entrega configurada para não depender de token de desenvolvimento.
- MFA administrativo foi implementado com TOTP para contas administradoras. O segredo fica criptografado no banco e o login admin passa por desafio curto antes de emitir token de sessão.
- O rate limit em memória não coordena instâncias. A identificação por cabeçalho de proxy depende de uma configuração confiável na borda.
- A aplicação persiste a sessão Flutter com SharedPreferences; definir armazenamento seguro, expiração e política de sessões antes de publicar.
- O armazenamento local de documentos ainda não oferece antivírus, retenção aprovada ou backup gerenciado. Para produção, use storage privado gerenciado, varredura de arquivo e política formal de descarte.
- O launcher local versionado contém valores de desenvolvimento para iniciar a API. Não reutilize esses valores em ambiente compartilhado ou produção; mover segredos para configuração externa antes de publicar.
- HTTPS, origens de produção, backup/restauração, monitoramento e resposta a incidentes ainda precisam ser configurados e comprovados.
- Não há evidência de scanner dedicado de segredos executado antes da publicação.

## Regras para desenvolvimento

Use somente contas e dados fictícios nos ambientes locais. Não coloque tokens, senhas reais, documentos pessoais ou endereços reais em commits, capturas ou logs. O seed e os diagnósticos de fluxo são exclusivos de desenvolvimento/teste. Nunca execute migrations ou seed contra o banco legado ou produção sem processo próprio de revisão e backup.

Veja também [operação e segurança da API](operacao-producao.md) e [ambiente local](ambiente-local.md).
