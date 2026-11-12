# Armazenamento privado na VPS

Este documento prepara o armazenamento local persistente para a futura VPS. A
implementacao ja permite usar um diretorio fora da pasta de publicacao tanto para
documentos de verificacao quanto para fotos de avaliacao. Nenhum servidor ou
servico externo e configurado por este documento.

## Como o codigo funciona

- `FILE_STORAGE_DRIVER=local` seleciona o disco local. Em producao, a ausencia de
  `FILE_STORAGE_LOCAL_DIR`, um caminho relativo ou um caminho dentro da pasta da
  aplicacao causa falha no upload, sem voltar silenciosamente para a pasta da release.
- `FILE_STORAGE_LOCAL_DIR` e a raiz privada de dados, nao a pasta final dos arquivos.
  Com `/var/lib/conectalar`, os arquivos ficam em `storage/documentos-verificacao`
  e `storage/avaliacoes` abaixo dessa raiz.
- As referencias salvas no banco continuam relativas, por exemplo
  `storage/documentos-verificacao/42/<uuid>.pdf`. Isso permite manter referencias
  existentes ao copiar a mesma arvore de diretorios para a VPS.
- No Linux, diretorios sao criados com permissao `0700` e arquivos com `0600`.
  O usuario do processo Node.js precisa ser dono do diretorio configurado.
- `FILE_STORAGE_DRIVER=r2` continua selecionando R2. A migracao posterior deve
  copiar e verificar os arquivos antes de alterar o driver ou remover a copia local.

## Configuracao prevista na VPS

Depois de instalar a API como um servico Linux, use variaveis equivalentes a estas
no ambiente do servico (nao no APK nem no repositorio):

```ini
NODE_ENV=production
FILE_STORAGE_DRIVER=local
FILE_STORAGE_LOCAL_DIR=/var/lib/conectalar
MALWARE_SCAN_MODE=required
CLAMAV_HOST=127.0.0.1
CLAMAV_PORT=3310
```

Antes de receber documentos reais, confirmar que:

- `/var/lib/conectalar` existe, pertence ao usuario nao-root da API e nao esta sob
  `public_html`, `hbuilds`, o diretorio da aplicacao ou uma pasta servida pelo Nginx.
- O firewall deixa publico apenas o necessario para HTTPS e acesso administrativo
  restrito. MySQL e ClamAV nao devem aceitar conexoes publicas.
- O processo Node.js nao roda como `root`; ele so precisa ler e escrever na pasta
  privada e acessar o banco e o ClamAV local.
- O antivirus esta ativo e atualizado. Se a verificacao estiver indisponivel, o
  upload deve falhar fechado, sem aprovar nem disponibilizar o arquivo.
- MFA administrativo, autorizacao por papel, auditoria de visualizacao/decisao e
  limites de upload estao ativos.
- Ha backups criptografados em local separado da VPS e foi testada a restauracao
  tanto do banco quanto dos arquivos. Snapshot da propria VPS nao substitui copia
  independente.
- Foi aprovada uma politica de retencao e exclusao dos documentos; guardar por sete
  meses nao deve ser assumido como requisito automatico.

## Homologacao antes de dados reais

1. Usar arquivos de teste sem dados pessoais para validar upload, leitura autorizada,
   rejeicao, exclusao e bloqueio de tipos/tamanhos invalidos.
2. Confirmar que um cliente e um profissional nao conseguem ler documentos alheios;
   somente administradores autorizados podem abrir a copia de revisao.
3. Testar com ClamAV disponivel e indisponivel, verificando que indisponibilidade
   nao resulte em aceite.
4. Reiniciar o servico e publicar uma nova versao; confirmar que os arquivos continuam
   presentes e acessiveis pela API.
5. Restaurar um backup em ambiente isolado e comparar contagens e hashes antes de
   considerar a rotina operacional.
6. Homologar exclusao de arquivos temporarios/incompletos e a retencao apos a decisao.

## Migracao futura para R2

A migracao precisa copiar os objetos mantendo as referencias e verificar contagem,
tamanho e SHA-256. Testar leitura pelo fluxo administrativo antes de trocar
`FILE_STORAGE_DRIVER` para `r2`. Manter a copia antiga ate validar a nova rotina de
backup e recuperacao. Nao tornar bucket ou objetos publicos durante a migracao.

## Limite atual

Este preparo nao configura a VPS, firewall, servico systemd, ClamAV, backup externo,
criptografia de backup ou politicas legais de retencao. Uploads reais so devem ser
habilitados depois de completar e registrar a homologacao acima.
