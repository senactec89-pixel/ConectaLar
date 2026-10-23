import assert from 'node:assert/strict';
import test from 'node:test';
import {
  paginationMetadata,
  parsePaginationQuery,
} from '../dist/common/pagination.js';
import { MensagensService } from '../dist/mensagens/mensagens.service.js';
import { NotificacoesService } from '../dist/notificacoes/notificacoes.service.js';

test('paginacao valida entrada e calcula metadados', () => {
  const input = parsePaginationQuery({ pagina: '2', limite: '20' });
  assert.deepEqual(input, { pagina: 2, limite: 20, skip: 20 });
  assert.deepEqual(paginationMetadata(input, 41), {
    pagina: 2,
    limite: 20,
    total: 41,
    totalPaginas: 3,
    temMais: true,
  });

  for (const query of [
    { pagina: '0' },
    { pagina: '1 OR 1' },
    { limite: '0' },
    { limite: '51' },
    { limite: ['20'] },
  ]) {
    assert.throws(
      () => parsePaginationQuery(query),
      (error) => error?.response?.code === 'PAGINACAO_INVALIDA',
    );
  }
});

test('mensagens pagina das recentes para as antigas e responde em ordem cronologica', async () => {
  let opcoes;
  const autor = { id: 30, nome: 'Cliente', tipo: 'cliente' };
  const mensagem = (id, criadoEm) => ({
    id,
    solicitacaoId: 10,
    autor,
    conteudo: `Mensagem ${id}`,
    criadoEm: new Date(criadoEm),
  });
  const service = new MensagensService(
    {
      async findAndCount(value) {
        opcoes = value;
        return [[
          mensagem(20, '2026-10-23T12:20:00Z'),
          mensagem(19, '2026-10-23T12:19:00Z'),
        ], 41];
      },
    },
    {
      async findOne() {
        return {
          id: 10,
          clienteId: 30,
          profissional: { usuarioId: 40 },
        };
      },
    },
    {},
  );

  const response = await service.listar(
    { id: 30, tipo: 'cliente' },
    10,
    { pagina: '2', limite: '20' },
  );
  assert.equal(opcoes.skip, 20);
  assert.equal(opcoes.take, 20);
  assert.deepEqual(opcoes.order, { criadoEm: 'DESC', id: 'DESC' });
  assert.deepEqual(response.mensagens.map((item) => item.id), [19, 20]);
  assert.equal(response.paginacao.temMais, true);
});

test('notificacoes usam pagina solicitada sem truncamento silencioso', async () => {
  let opcoes;
  const service = new NotificacoesService({
    async findAndCount(value) {
      opcoes = value;
      return [[], 45];
    },
  });

  const response = await service.listarMinhas(
    { id: 30, tipo: 'cliente' },
    { pagina: '2', limite: '20', naoLidas: 'true' },
  );
  assert.deepEqual(opcoes.where, { usuarioId: 30, lida: false });
  assert.equal(opcoes.skip, 20);
  assert.equal(opcoes.take, 20);
  assert.equal(response.paginacao.totalPaginas, 3);
  assert.equal(response.paginacao.temMais, true);
});
