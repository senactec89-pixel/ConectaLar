import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ProfissionaisService } from '../dist/profissionais/profissionais.service.js';

function queryBuilder(result, calls = []) {
  return {
    leftJoinAndSelect() {
      return this;
    },
    leftJoin() {
      return this;
    },
    where() {
      return this;
    },
    andWhere(...args) {
      calls.push(args);
      return this;
    },
    distinct() {
      return this;
    },
    skip(value) {
      calls.push(['skip', value]);
      return this;
    },
    take(value) {
      calls.push(['take', value]);
      return this;
    },
    orderBy() {
      return this;
    },
    addOrderBy() {
      return this;
    },
    select() {
      return this;
    },
    addSelect() {
      return this;
    },
    setParameters() {
      return this;
    },
    groupBy() {
      return this;
    },
    async getManyAndCount() {
      return [result, result.length];
    },
    async getRawMany() {
      return [];
    },
  };
}

function profile(id, longitude, raioAtendimentoKm) {
  return {
    id,
    usuarioId: id + 100,
    usuario: {
      id: id + 100,
      nome: `Profissional ${id}`,
      tipo: 'profissional',
      ativo: true,
      fotoPerfil: null,
    },
    descricao: 'Atendimento residencial com experiencia comprovada.',
    bairro: 'Centro',
    cidade: 'Cidade',
    uf: 'SP',
    latitude: longitude === null ? null : '0.0000000',
    longitude: longitude === null ? null : longitude.toFixed(7),
    raioAtendimentoKm,
    precoInicial: null,
    verificado: false,
    ativo: true,
    servicos: [],
  };
}

function service(profiles = [], calls = []) {
  const avaliacoes = { createQueryBuilder: () => queryBuilder([]) };
  const perfis = { createQueryBuilder: () => queryBuilder(profiles, calls) };
  return new ProfissionaisService(
    avaliacoes,
    {},
    {},
    perfis,
    {},
    {},
    {},
    {},
  );
}

test('busca por distancia exige o par de coordenadas e um raio valido', async () => {
  await assert.rejects(
    service().buscar({ latitude: -23.5, raioKm: 10 }),
    (error) => error?.getResponse?.().code === 'COORDENADA_INVALIDA',
  );
  await assert.rejects(
    service().buscar({ raioKm: 10 }),
    (error) => error?.getResponse?.().code === 'COORDENADA_INVALIDA',
  );
  await assert.rejects(
    service().buscar({ latitude: -23.5, longitude: -46.6 }),
    (error) => error?.getResponse?.().code === 'RAIO_ATENDIMENTO_INVALIDO',
  );
});

test('busca respeita raio do cliente e area atendida pelo profissional', async () => {
  const calls = [];
  const result = await service([profile(2, 0.04, 10)], calls).buscar({
    latitude: 0,
    longitude: 0,
    raioKm: 10,
  });

  assert.deepEqual(
    result.profissionais.map((item) => item.id),
    [2],
  );
  assert.equal(result.profissionais[0].distanciaKm, 4.4);
  assert.equal(result.profissionais[0].latitudeAproximada, 0);
  assert.equal(result.profissionais[0].longitudeAproximada, 0.04);
  assert.equal(result.paginacao.total, 1);
  assert.ok(
    calls.some(
      ([clausula, parametros]) =>
        typeof clausula === 'string' &&
        clausula.includes('LEAST(:raioKm, perfil.raioAtendimentoKm)') &&
        parametros.raioKm === 10,
    ),
  );
});

test('busca valida os limites da paginacao', async () => {
  await assert.rejects(
    service().listar({ pagina: '0' }),
    (error) => error?.getResponse?.().code === 'PAGINACAO_INVALIDA',
  );
  await assert.rejects(
    service().listar({ limite: '51' }),
    (error) => error?.getResponse?.().code === 'PAGINACAO_INVALIDA',
  );
});
