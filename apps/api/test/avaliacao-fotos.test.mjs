import assert from 'node:assert/strict';
import { test } from 'node:test';
import sharp from 'sharp';
import { AvaliacoesService } from '../dist/avaliacoes/avaliacoes.service.js';
import { AvaliacaoFotoCleanupService } from '../dist/avaliacoes/avaliacao-foto-cleanup.service.js';
import { OptionalAuthGuard } from '../dist/avaliacoes/avaliacoes.controller.js';

function makeService({ solicitacao, avaliacoes = [], foto, storage } = {}) {
  let uploadsPersistidos = 0;
  const service = new AvaliacoesService(
    {
      find: async () => avaliacoes,
      findOne: async () => foto ?? null,
      count: async () => uploadsPersistidos,
      manager: { transaction: async (operation) => operation({}) },
    },
    { findOne: async () => solicitacao ?? null },
    {
      findOne: async () => foto ?? null,
      count: async () => uploadsPersistidos,
      save: async (value) => ({ id: 71, ...value }),
      create: (value) => value,
      update: async () => ({ affected: 1 }),
      delete: async () => ({ affected: 1 }),
      manager: { transaction: async (operation) => operation({}) },
    },
    { criar: async () => undefined },
    storage ?? { carregar: async () => Buffer.from('jpeg'), remover: async () => undefined },
    { scanBuffer: async () => ({ clean: true }) },
  );
  return service;
}

function pendingReview(overrides = {}) {
  return {
    id: 31,
    avaliadorId: 10,
    avaliadoId: 20,
    moderacaoStatus: 'pendente',
    ...overrides,
  };
}

function solicitacao(overrides = {}) {
  return {
    id: 5,
    clienteId: 10,
    status: 'conclusao_confirmada',
    profissional: { usuarioId: 20 },
    ...overrides,
  };
}

test('foto pendente pode ser lida pelo autor e admin, mas nao pelo avaliado', async () => {
  let leituras = 0;
  const service = makeService({
    foto: { id: 71, avaliacao: pendingReview(), referenciaArquivo: 'private' },
    storage: { carregar: async () => { leituras++; return Buffer.from('jpeg'); } },
  });

  await assert.rejects(
    service.carregarFoto({ id: 20, tipo: 'profissional' }, 31, 71),
    (error) => error?.getStatus?.() === 404,
  );
  assert.equal(leituras, 0, 'nao deve sequer consultar o armazenamento privado');
  assert.equal(
    (await service.carregarFoto({ id: 10, tipo: 'cliente' }, 31, 71)).toString(),
    'jpeg',
  );
  await service.carregarFoto({ id: 99, tipo: 'administrador' }, 31, 71);
  assert.equal(leituras, 2);
});

test('somente avaliacao aprovada libera foto para outras contas', async () => {
  const service = makeService({
    foto: {
      id: 71,
      avaliacao: pendingReview({ moderacaoStatus: 'aprovada' }),
      referenciaArquivo: 'private',
    },
  });
  const result = await service.carregarFoto(
    null,
    31,
    71,
  );
  assert.equal(result.toString(), 'jpeg');
});

test('foto de avaliacao rejeitada continua privada para o avaliado', async () => {
  const service = makeService({
    foto: {
      id: 71,
      avaliacao: pendingReview({ moderacaoStatus: 'rejeitada' }),
      referenciaArquivo: 'private',
    },
  });
  await assert.rejects(
    service.carregarFoto(null, 31, 71),
    (error) => error?.getStatus?.() === 404,
  );
  await assert.rejects(
    service.carregarFoto({ id: 20, tipo: 'profissional' }, 31, 71),
    (error) => error?.getStatus?.() === 404,
  );
});

test('rota de imagem aceita visitante anonimo para aprovadas, mas valida token apresentado', async () => {
  let validacoes = 0;
  const guard = new OptionalAuthGuard({
    canActivate: async () => { validacoes++; return true; },
  });
  const context = (authorization) => ({
    switchToHttp: () => ({
      getRequest: () => ({ headers: { authorization } }),
    }),
  });

  assert.equal(await guard.canActivate(context(undefined)), true);
  assert.equal(validacoes, 0);
  assert.equal(await guard.canActivate(context('Bearer token')), true);
  assert.equal(validacoes, 1);
});

test('lista de avaliacoes oculta pendentes/rejeitadas da parte avaliada', async () => {
  const service = makeService({
    solicitacao: solicitacao(),
    avaliacoes: [
      { ...pendingReview(), avaliador: {}, avaliado: {}, fotos: [], criadoEm: new Date(), atualizadoEm: new Date() },
      { ...pendingReview({ id: 32, moderacaoStatus: 'rejeitada' }), avaliador: {}, avaliado: {}, fotos: [], criadoEm: new Date(), atualizadoEm: new Date() },
      { ...pendingReview({ id: 33, moderacaoStatus: 'aprovada' }), avaliador: {}, avaliado: {}, fotos: [], criadoEm: new Date(), atualizadoEm: new Date() },
      { ...pendingReview({ id: 34, avaliadorId: 20, avaliadoId: 10 }), avaliador: {}, avaliado: {}, fotos: [], criadoEm: new Date(), atualizadoEm: new Date() },
    ],
  });
  const result = await service.listarDaSolicitacao(
    { id: 20, tipo: 'profissional' },
    5,
  );
  assert.deepEqual(result.avaliacoes.map(({ id }) => id), [33, 34]);
});

test('upload de fotos e exclusivo do cliente e do atendimento dele', async () => {
  const service = makeService({ solicitacao: solicitacao({ clienteId: 11 }) });
  const file = { buffer: Buffer.from([0xff, 0xd8, 0xff]), mimetype: 'image/jpeg' };

  await assert.rejects(
    service.adicionarFoto({ id: 20, tipo: 'profissional' }, 5, file),
    (error) => error?.getStatus?.() === 403,
  );
  await assert.rejects(
    service.adicionarFoto({ id: 10, tipo: 'cliente' }, 5, file),
    (error) => error?.getStatus?.() === 403,
  );
});

test('upload valido e escaneado, normalizado em JPEG e reservado antes do armazenamento', async () => {
  let scanned = 0;
  let stored;
  let activated = 0;
  const pedido = solicitacao();
  const repositories = new Map([
    ['SolicitacaoEntity', { findOne: async () => pedido }],
    ['AvaliacaoEntity', { count: async () => 0 }],
    ['AvaliacaoFotoEntity', {
      count: async () => 0,
      create: (value) => value,
      save: async (value) => ({ id: 71, ...value }),
    }],
  ]);
  const transaction = async (operation) => operation({
    getRepository: (entity) => repositories.get(entity.name),
  });
  const service = new AvaliacoesService(
    { count: async () => 0, manager: { transaction } },
    { findOne: async () => pedido },
    {
      count: async () => 0,
      create: (value) => value,
      save: async (value) => ({ id: 71, ...value }),
      update: async () => { activated++; return { affected: 1 }; },
      manager: { transaction },
    },
    { criar: async () => undefined },
    { novaReferencia: () => 'storage/avaliacoes/5/test.jpg', salvar: async (_ref, bytes) => { stored = bytes; }, remover: async () => undefined },
    { scanBuffer: async () => { scanned++; return { clean: true }; } },
  );
  const png = await sharp({
    create: { width: 1, height: 1, channels: 3, background: '#ffffff' },
  }).png().toBuffer();

  const result = await service.adicionarFoto(
    { id: 10, tipo: 'cliente' },
    5,
    { buffer: png, mimetype: 'image/png' },
  );

  assert.deepEqual(result, { foto: { id: 71, mimeType: 'image/jpeg' } });
  assert.equal(scanned, 2, 'arquivo original e imagem reprocessada sao escaneados');
  assert.equal(activated, 1);
  assert.equal(stored.subarray(0, 3).toString('hex'), 'ffd8ff');
});

test('somente o cliente autor pode excluir seu upload temporario', async () => {
  let removals = 0;
  let deletes = 0;
  const staged = {
    id: 71,
    solicitacaoId: 5,
    enviadoPorId: 10,
    avaliacaoId: null,
    referenciaArquivo: 'staged',
  };
  const service = new AvaliacoesService(
    {},
    {},
    {
      manager: {
        transaction: async (operation) => operation({
          getRepository: () => ({
            findOne: async ({ where }) =>
              where.enviadoPorId === staged.enviadoPorId ? staged : null,
            delete: async () => { deletes++; },
          }),
        }),
      },
    },
    {},
    { remover: async () => { removals++; } },
    {},
  );

  await assert.rejects(
    service.removerFotoTemporaria({ id: 20, tipo: 'profissional' }, 5, 71),
    (error) => error?.getStatus?.() === 403,
  );
  await assert.rejects(
    service.removerFotoTemporaria({ id: 11, tipo: 'cliente' }, 5, 71),
    (error) => error?.getStatus?.() === 404,
  );
  assert.equal(removals, 0);
  await service.removerFotoTemporaria({ id: 10, tipo: 'cliente' }, 5, 71);
  assert.equal(removals, 1);
  assert.equal(deletes, 1);
});

test('limpeza remove uploads temporarios expirados e preserva anexos', async () => {
  const rows = new Map([
    [1, { id: 1, avaliacaoId: null, expiraEm: new Date('2026-01-01'), referenciaArquivo: 'expired' }],
    [2, { id: 2, avaliacaoId: 9, expiraEm: null, referenciaArquivo: 'attached' }],
  ]);
  const removidos = [];
  const repository = {
    find: async () => [{ id: 1 }, { id: 2 }],
    manager: {
      transaction: async (operation) => operation({
        getRepository: () => ({
          findOne: async ({ where }) => {
            const row = rows.get(where.id);
            return row?.avaliacaoId === null ? row : null;
          },
          delete: async ({ id }) => rows.delete(id),
        }),
      }),
    },
  };
  const cleanup = new AvaliacaoFotoCleanupService(repository, {
    remover: async (reference) => { removidos.push(reference); },
  });

  assert.equal(await cleanup.limparExpiradas(new Date('2026-02-01')), 1);
  assert.deepEqual(removidos, ['expired']);
  assert.equal(rows.has(1), false);
  assert.equal(rows.has(2), true);
});

test('falha no storage mantem registro expirado para nova tentativa', async () => {
  const row = { id: 1, avaliacaoId: null, expiraEm: new Date('2026-01-01'), referenciaArquivo: 'expired' };
  let deleted = false;
  const cleanup = new AvaliacaoFotoCleanupService({
    find: async () => [{ id: 1 }],
    manager: {
      transaction: async (operation) => operation({
        getRepository: () => ({
          findOne: async () => row,
          delete: async () => { deleted = true; },
        }),
      }),
    },
  }, { remover: async () => { throw new Error('storage unavailable'); } });

  assert.equal(await cleanup.limparExpiradas(new Date('2026-02-01')), 0);
  assert.equal(deleted, false);
});
