# Seguranca - estado atual e pendencias

## Habilitacao residencial em 18/10/2026

Analise documental nao equivale a identidade validada nem habilitacao para atender.
Enquanto telefone, antecedentes e politica juridica estiverem pendentes, esta versao bloqueia
novos pedidos/aceites e acesso do profissional a enderecos completos. A revisao
administrativa exige MFA e nao permite aprovacao manual das verificacoes externas.
Consultar [limites, testes e implantacao](habilitacao-profissional.md).

Atualizado em 25/10/2026 para o codigo disponivel em `main`. Este documento registra controles tecnicos observados no repositorio; nao e certificacao de seguranca ou conformidade legal.

## Controles existentes

- Senhas sao armazenadas com hash `scrypt`.
- A API autentica com token, aplica papeis nas rotas e invalida tokens apos logout ou troca de senha.
- A senha nova exige maiuscula, minuscula, numero, caractere especial e limites de tamanho.
- Confirmacao de e-mail e recuperacao de senha usam HMAC-SHA-256 com segredo privado da API e expiracao; hashes legados ainda validos sao aceitos ate expirarem. Cada codigo aceita no maximo cinco tentativas e e invalidado ao atingir o limite.
- O MySQL guarda quotas por conta: no maximo tres emissoes numa janela fixa de uma hora iniciada no primeiro envio e intervalo minimo de um minuto para reenvio. A recuperacao de senha continua respondendo de forma generica quando a conta nao existe ou a quota impede o envio.
- Emissao, consumo, contador de tentativas e alteracao de senha/confirmacao de e-mail usam transacoes e bloqueio da linha da conta, evitando que requisicoes concorrentes reutilizem o mesmo codigo.
- MFA administrativo usa TOTP; o segredo fica criptografado no banco.
- O filtro HTTP evita retornar stack traces e mensagens internas.
- CORS usa lista permitida; ha cabecalhos basicos de seguranca.
- Logs HTTP nao registram corpo, token ou cabecalhos de autorizacao.
- Rate limit global e limites mais estritos por rota de autenticacao existem em memoria para uma instancia. O contador usa o IP resolvido pelo Express e nao confia diretamente no cabecalho `X-Forwarded-For`.
- `TRUST_PROXY_HOPS` controla quantos proxies reversos sao confiaveis; o padrao e `0`. So configure outro valor depois de confirmar a cadeia de proxy do ambiente, pois confiar saltos demais permite falsificar IPs.
- Endereco completo e protegido na API antes das condicoes autorizadas.
- Upload de documentos limita tamanho, aceita PDF/JPEG/PNG, confere assinatura/magic bytes e rejeita nome incompativel com o MIME informado.
- Upload de documentos pode executar varredura ClamAV antes de gravar o arquivo. Em `MALWARE_SCAN_MODE=required`, deteccao de ameaca ou falha do scanner bloqueia o upload.
- Documentos ficam em storage privado local ou Cloudflare R2, sem URL publica direta.
- A leitura de documentos para moderacao exige token administrativo e retorna arquivo por rota autenticada.
- O app administrativo renderiza imagens e PDFs carregados pela rota privada.
- O selo profissional e recalculado pelo conjunto de documentos e depende de documento de identidade aprovado.
- Profissionais nao conseguem aprovar o proprio selo.
- A sessao Flutter usa armazenamento criptografado da plataforma: Android Keystore no Android e Keychain no iOS. Sessoes legadas em `SharedPreferences` sao migradas e removidas na primeira leitura.
- Exportacao e exclusao de conta exigem token valido e confirmacao da senha atual.
- A exportacao omite hashes de senha, tokens, codigos e segredos MFA; o arquivo JSON e entregue pela folha nativa de compartilhamento do aparelho.
- A exclusao bloqueia contas com atendimentos ativos, nao permite autoexclusao administrativa, invalida todas as sessoes e anonimiza o historico que precisa permanecer referenciado.
- Foto e documentos privados sao removidos do storage; falhas de limpeza sao registradas sem expor o nome do arquivo ou dados do titular.

## Limites que precisam ser resolvidos

- A varredura depende de ClamAV ou servico compativel estar instalado, atualizado e acessivel no ambiente. Isso ainda precisa ser configurado e homologado na hospedagem.
- O suporte a Cloudflare R2 precisa de bucket, credenciais, politicas de acesso e backup/retencao configurados no ambiente real.
- Ainda falta aprovacao juridica dos prazos de retencao e descarte por categoria de dado. O autoatendimento tecnico de exportacao e exclusao ja esta implementado.
- O rate limit em memoria nao coordena multiplas instancias.
- Os limites por conta/codigo persistem no MySQL, mas o limitador por IP segue em memoria e nao coordena multiplas instancias. Configurar limitacao distribuida na borda antes de escalar ou abrir acesso publico amplo.
- A identificacao por proxy depende de `TRUST_PROXY_HOPS` corresponder exatamente a cadeia validada na hospedagem.
- Ainda falta definir a politica de expiracao e de sessoes simultaneas em diferentes dispositivos.
- O launcher local versionado contem valores de desenvolvimento para iniciar a API. Nao reutilize esses valores em ambiente compartilhado ou producao.
- HTTPS, origens de producao, backup/restauracao, monitoramento e resposta a incidentes ainda precisam ser configurados e comprovados.
- Nao ha evidencia de scanner dedicado de segredos executado antes da publicacao.

## Regras para desenvolvimento

Use somente contas e dados ficticios nos ambientes locais. Nao coloque tokens, senhas reais, documentos pessoais ou enderecos reais em commits, capturas ou logs.

O seed e os diagnosticos de fluxo sao exclusivos de desenvolvimento/teste. Nunca execute migrations ou seed contra banco de producao sem processo proprio de revisao, janela de manutencao e backup validado.

Veja tambem [operacao e seguranca da API](operacao-producao.md) e [ambiente local](ambiente-local.md).
