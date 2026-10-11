# Checklist de demo integrada

Use esta lista para validar a demo com API e MySQL locais. Marque somente quando o fluxo for testado no ambiente integrado atual.

## Resultado em 2026-10-10

Validacao automatizada via HTTP contra API local `127.0.0.1:3016` e MySQL `conectalar_dev`:

- commit base: `4e303d0`;
- migrations: sem pendencias;
- seed demo: executado com sucesso;
- usuarios demo: `cliente.demo@conectalar.local`, `profissional.demo@conectalar.local`, `admin.demo@conectalar.local`;
- arquivos enviados pelo contrato real de upload Base64: PDF aprovado, JPEG rejeitado com justificativa e PNG mantido pendente;
- solicitacao integrada criada com id `36`, aceita pelo profissional e concluida pelo cliente;
- endereco completo ficou protegido antes do aceite e foi liberado ao profissional somente depois do aceite;
- chat retornou 2 mensagens do fluxo integrado;
- avaliacoes criadas com ids `8` e `9`;
- denuncia criada com id `7` e moderada como `resolvida`;
- auditoria retornou `documento_analisado`, `avaliacao_moderada` e `denuncia_moderada`.

Observacao: esta evidencia valida API, banco, autorizacao e contrato usado pelo app. O clique visual no seletor nativo de arquivo ainda deve ser conferido manualmente no Flutter em aparelho/navegador, porque essa acao depende da UI do sistema operacional.

## Ambiente

- [x] MySQL local iniciado com banco `conectalar_dev`.
- [x] Migrations executadas com sucesso.
- [x] Seed de demo executado com sucesso.
- [x] API iniciada em loopback.
- [ ] App Flutter apontando para a API local correta.

## Fluxo cliente/profissional

- [x] Cadastro de cliente concluido.
- [x] Cadastro de profissional concluido.
- [x] Login de cliente concluido.
- [x] Login de profissional concluido.
- [x] Cliente cadastrou endereco completo.
- [x] Cliente criou solicitacao com `enderecoId`.
- [x] Profissional viu a solicitacao antes do aceite sem endereco completo.
- [x] Profissional aceitou a solicitacao.
- [x] Profissional viu o endereco completo somente apos aceite.
- [x] Cliente/profissional trocaram mensagens no chat.
- [x] Cliente concluiu o atendimento.
- [x] Cliente avaliou o profissional.
- [x] Profissional avaliou o cliente.
- [x] Cliente ou profissional abriu denuncia vinculada ao atendimento.

## Documentos e administracao

- [x] Profissional enviou PDF real de ate 5 MB.
- [x] Profissional enviou JPEG real de ate 5 MB.
- [x] Profissional enviou PNG real de ate 5 MB.
- [x] Administrador viu os documentos pendentes.
- [x] Administrador aprovou um documento.
- [x] Administrador rejeitou um documento com justificativa.
- [x] Profissional viu o status atualizado dos documentos.
- [x] Administrador moderou denuncia.
- [x] Administrador moderou avaliacao.
- [x] Administrador conferiu evento na auditoria.

## Evidencias recomendadas

- Data/hora do teste.
- Commit testado.
- Porta da API.
- Usuario de cliente, profissional e administrador usados.
- Prints das telas principais, quando a validacao for visual.

