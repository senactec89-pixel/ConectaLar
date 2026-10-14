import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { databaseRuntimeOptions } from '../dist/database/database.config.js';

const source = (path) =>
  readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('service requests protect full client address by role and status', async () => {
  const solicitacoes = await source(
    'dist/solicitacoes/solicitacoes.service.js',
  );

  assert.match(solicitacoes, /enderecoProtegido/);
  assert.match(solicitacoes, /enderecoCompletoLiberado/);
  assert.match(solicitacoes, /AceitaAgendada/);
  assert.match(solicitacoes, /ConclusaoConfirmada/);
  assert.match(solicitacoes, /ENDERECO_INVALIDO/);
});

test('sensitive administrative actions are auditable', async () => {
  const actions = await source('dist/domain/admin-auditoria-acao.js');
  const painel = await source('dist/admin-painel/admin-painel.controller.js');

  for (const action of [
    'categoria_criada',
    'categoria_atualizada',
    'documento_analisado',
    'denuncia_moderada',
    'avaliacao_moderada',
  ]) {
    assert.match(actions, new RegExp(action));
  }
  assert.match(painel, /auditoria/);
});

test('backend contract documents logout, agenda, protected address, and audit', async () => {
  const openapi = await readFile(
    new URL('../openapi.yaml', import.meta.url),
    'utf8',
  );

  assert.match(openapi, /\/auth\/logout:/);
  assert.match(openapi, /\/auth\/email\/verificacao:/);
  assert.match(openapi, /\/auth\/email\/verificacao\/enviar:/);
  assert.match(openapi, /\/auth\/email\/verificacao\/confirmar:/);
  assert.match(openapi, /\/auth\/me\/foto:/);
  assert.match(openapi, /\/usuarios\/\{id\}\/foto:/);
  assert.match(openapi, /\/profissionais\/me\/agenda:/);
  assert.match(openapi, /\/profissionais\/me\/documentos:/);
  assert.match(openapi, /\/documentos-verificacao\/\{id\}\/arquivo:/);
  assert.match(openapi, /\/admin\/painel\/auditoria:/);
  assert.match(openapi, /enderecoProtegido/);
  assert.match(openapi, /enderecoAtendimento/);
  assert.match(openapi, /\/profissionais\/me\/avaliacoes:/);
  assert.match(openapi, /\/profissionais\/\{id\}\/avaliacoes:/);
  assert.match(openapi, /servicoId/);
  assert.match(openapi, /nomeServico/);
  assert.match(openapi, /fotoPerfilUrl/);
});

test('civil dates remain strings while timestamps keep their timezone', () => {
  const previous = {
    DB_HOST: process.env.DB_HOST,
    DB_USER: process.env.DB_USER,
    DB_NAME: process.env.DB_NAME,
  };
  try {
    process.env.DB_HOST = '127.0.0.1';
    process.env.DB_USER = 'test';
    process.env.DB_NAME = 'conectalar_test';
    const options = databaseRuntimeOptions();
    assert.deepEqual(options.dateStrings, ['DATE']);
    assert.equal(options.timezone, 'Z');
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});

test('verification upload keeps files private and validates size and type', async () => {
  const verificacao = await source('dist/verificacao/verificacao.service.js');
  const scanner = await source('dist/verificacao/malware-scanner.service.js');

  assert.match(verificacao, /maxDocumentoBytes/);
  assert.match(verificacao, /application\/pdf/);
  assert.match(verificacao, /image\/jpeg/);
  assert.match(verificacao, /image\/png/);
  assert.match(verificacao, /assinaturaCompativelComMime/);
  assert.match(verificacao, /nomeArquivoCompativelComMime/);
  assert.match(verificacao, /ASSINATURA_ARQUIVO_INVALIDA/);
  assert.match(verificacao, /NOME_ARQUIVO_INVALIDO/);
  assert.match(verificacao, /arquivoParaAnalise/);
  assert.match(verificacao, /caminhoDocumentoSeguro/);
  assert.match(verificacao, /AMEACA_DOCUMENTO_DETECTADA/);
  assert.match(verificacao, /VARREDURA_DOCUMENTO_OBRIGATORIA/);
  assert.match(scanner, /MALWARE_SCAN_MODE/);
  assert.match(scanner, /CLAMAV_HOST/);
  assert.match(scanner, /INSTREAM/);
  assert.match(scanner, /FOUND/);
  assert.match(verificacao, /%PDF-/);
  assert.match(verificacao, /0x89,\s*0x50,\s*0x4e,\s*0x47/);
  assert.match(verificacao, /storage/);
  assert.doesNotMatch(verificacao, /http:\/\/|https:\/\//);
});

test('profile photos validate real image bytes before serving public URLs', async () => {
  const storage = await source('dist/usuarios/foto-perfil.storage.js');
  const auth = await source('dist/auth/auth.service.js');
  const usuarios = await source('dist/usuarios/usuarios.controller.js');

  assert.match(storage, /maxFotoPerfilBytes = 2 \* 1024 \* 1024/);
  assert.match(storage, /image\/jpeg/);
  assert.match(storage, /image\/png/);
  assert.match(storage, /image\/webp/);
  assert.match(storage, /assinaturaCompativelComMime/);
  assert.match(storage, /NOME_FOTO_INVALIDO/);
  assert.match(storage, /ASSINATURA_FOTO_INVALIDA/);
  assert.match(storage, /RIFF/);
  assert.match(storage, /WEBP/);
  assert.match(auth, /atualizarFotoPerfil/);
  assert.match(auth, /removerFotoPerfil/);
  assert.match(auth, /fotoPerfilUrl/);
  assert.match(usuarios, /Content-Type/);
  assert.match(usuarios, /Cache-Control/);
});

test('authentication keeps e-mail verification codes hashed and expiring', async () => {
  const auth = await source('dist/auth/auth.service.js');
  const entity = await source(
    'dist/database/entities/usuario-email-verificacao.entity.js',
  );
  const guard = await source('dist/auth/auth.guard.js');

  assert.match(auth, /hashEmailVerificationCode/);
  assert.match(auth, /emailVerificationTtlMinutes = 15/);
  assert.match(auth, /sendEmailVerificationCode/);
  assert.match(entity, /codigoHash/);
  assert.match(entity, /expiraEm/);
  assert.match(entity, /usadoEm/);
  assert.match(guard, /EMAIL_NAO_VERIFICADO/);
  assert.match(guard, /auth\/email\/verificacao/);
});

test('password recovery uses short user-scoped codes without reset links', async () => {
  const auth = await source('dist/auth/auth.service.js');
  const mail = await source('dist/auth/mail.service.js');
  const openapi = await readFile(new URL('../openapi.yaml', import.meta.url), 'utf8');

  assert.match(auth, /hashResetCode/);
  assert.match(auth, /resetTokenTtlMinutes = 30/);
  assert.match(auth, /criarCodigoNumerico/);
  assert.match(auth, /usuario\.id, input\.token/);
  assert.match(openapi, /required: \[email, token, novaSenha\]/);
  assert.doesNotMatch(mail, /passwordResetUrl/);
  assert.doesNotMatch(mail, /conectalar:\/\/recuperar-senha/);
});
