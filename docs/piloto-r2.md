# Piloto Cloudflare R2

Este roteiro testa a conexao S3 do ConectaLar com um objeto descartavel. Nao usa
documentos de profissionais, nao torna o bucket publico e nao muda o banco de dados.
O piloto nao deve ser executado contra o bucket de producao.

## Preparar no Cloudflare

1. Em **Storage & databases > R2 > Overview**, crie um bucket exclusivo, por exemplo
   `conectalar-piloto-seu-identificador`, usando a classe Standard.
2. Deixe o acesso publico desligado. O app acessa os objetos pela API autenticada.
3. Em **Manage R2 API Tokens**, crie credenciais S3 com **Object Read & Write** e
   limite o escopo somente ao bucket de piloto. Nao crie token com permissao Admin.
4. Guarde o Access Key ID e Secret Access Key em um gerenciador de senhas. O segredo
   nao pode ser recuperado depois e nao deve ser enviado por chat ou commit.
5. Anote o Account ID mostrado no painel. O endpoint S3 padrao e
   `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`.

Cloudflare informa uma franquia mensal para R2 Standard (10 GB-month, 1 milhao de
operacoes Class A e 10 milhoes Class B; egress para a internet sem cobranca na tabela
atual consultada em 27/10/2026). O uso acima da franquia e cobrado; confira a tabela
vigente e o painel de uso antes do piloto: [precos oficiais do R2](https://developers.cloudflare.com/r2/pricing/).
Para gerar credenciais S3, a documentacao pede uma assinatura R2 ativa e recomenda
escopar Object Read & Write a buckets especificos: [guia S3 oficial](https://developers.cloudflare.com/r2/get-started/s3/).

## Executar no Windows

No terminal integrado, entre em `apps/api` e defina as variaveis somente naquela
janela do PowerShell. O segredo e digitado sem eco e nao fica no historico do comando:

```powershell
$env:R2_PILOT_ACCOUNT_ID = Read-Host 'Account ID do Cloudflare'
$env:R2_PILOT_BUCKET = Read-Host 'Nome exato do bucket exclusivo de piloto'
$env:R2_PILOT_CONFIRM_BUCKET = Read-Host 'Digite novamente o nome do bucket'
$env:R2_PILOT_ACCESS_KEY_ID = Read-Host 'Access Key ID do token R2'
$secret = Read-Host 'Secret Access Key do token R2' -AsSecureString
$env:R2_PILOT_SECRET_ACCESS_KEY = [System.Net.NetworkCredential]::new('', $secret).Password

npm.cmd run r2:pilot

Remove-Item Env:R2_PILOT_ACCOUNT_ID, Env:R2_PILOT_BUCKET, Env:R2_PILOT_CONFIRM_BUCKET, `
  Env:R2_PILOT_ACCESS_KEY_ID, Env:R2_PILOT_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue
```

O script aceita somente buckets exclusivos com prefixo `conectalar-piloto-`,
`conectalar-pilot-`, `conectalar-homologacao-` ou `conectalar-teste-`, exige que o
nome seja confirmado e usa somente as variaveis `R2_PILOT_*`. Ele envia um marcador
sem dado pessoal, baixa e compara os bytes e apaga o objeto. Endpoint remoto deve usar
HTTPS; HTTP e permitido somente para loopback nos testes locais. Se a exclusao
automatica falhar, o script informa a chave exata para remocao manual no painel.

## Interpretar

- Sucesso valida credenciais, endpoint, escrita, leitura e exclusao contra o Cloudflare.
- Falha de autenticacao: confira se copiou as credenciais S3 do R2, nao um API token
  geral do Cloudflare.
- Falha de autorizacao: confira escopo e Object Read & Write para aquele bucket.
- Falha de rede: verifique a conexao do computador/servidor que executou o comando.
- Confirme no painel que o bucket continua privado e sem o objeto de teste.

Esse comando valida conectividade do computador em que foi executado. Para validar a
rede da hospedagem, rode-o somente em um terminal administrativo temporario da
hospedagem e com credencial exclusiva de piloto; nunca coloque as variaveis `R2_PILOT_*`
no APK, no Git, em logs ou no comando de build/publicacao. As variaveis `R2_*` usadas
pela API de producao devem apontar para um bucket e token separados do piloto.

## Piloto combinado R2 + ClamAV

Este segundo comando carrega os servicos reais de storage e scanner da API compilada,
mas nao inicia HTTP, nao acessa MySQL e nao cria registros de usuario/documento. Usa
somente um PDF sintético em memoria e a assinatura de teste EICAR; nenhum documento
pessoal ou malware real e utilizado. O arquivo limpo passa pelo scanner antes do
PUT/GET/DELETE no bucket. A assinatura EICAR deve ser detectada e nunca e enviada ao R2.

Pre-requisitos: ClamAV deve aceitar `INSTREAM` localmente na porta configurada (padrao
3310), dependencias e compilacao da API devem estar atualizadas, e um token de piloto
valido deve ter acesso somente ao bucket exclusivo. O teste exige `MALWARE_SCAN_MODE`
como `required` internamente e restaura as variaveis anteriores ao terminar.

Defina as mesmas variaveis seguras `R2_PILOT_*` descritas acima e execute na pasta
`apps/api`:

```powershell
npm.cmd run build
npm.cmd run r2:clamav:pilot
```

Opcionalmente, ajuste o destino do ClamAV com `R2_PILOT_CLAMAV_HOST`,
`R2_PILOT_CLAMAV_PORT` ou `R2_PILOT_CLAMAV_TIMEOUT_MS`. O comando informa apenas o
resultado, o nome do bucket e uma referencia unica de cleanup se a exclusao falhar;
nao imprime credenciais.

Limite: este piloto valida a integracao entre os servicos de scanner e storage, nao a
rota HTTP autenticada, banco, perfil profissional, autorizacao administrativa ou
interface Flutter. Esses fluxos exigem um banco local descartavel e serao homologados
separadamente antes de ativar storage em producao.
