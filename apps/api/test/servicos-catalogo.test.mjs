import 'reflect-metadata';
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ServicosCatalogoService } from '../dist/categorias/servicos-catalogo.service.js';
import { ServicosCatalogoController } from '../dist/categorias/servicos-catalogo.controller.js';
import { rolesMetadataKey } from '../dist/auth/roles.decorator.js';
import { GUARDS_METADATA } from '@nestjs/common/constants.js';

const admin = { id: 12, tipo: 'administrador' };

function setup() {
  const state = { categorias: [{ id: 1, ativo: true }, { id: 2, ativo: false }], servicos: [], auditorias: [], falharAuditoria: false };
  const categorias = { async findOne({ where }) { return state.categorias.find((item) => item.id === where.id) ?? null; } };
  const servicos = {
    manager: {
      async transaction(operation) {
        const items = structuredClone(state.servicos);
        const audits = [];
        const repository = {
          create: (value) => value,
          async findOne({ where }) { return items.find((item) => item.id === where.id && item.categoriaId === where.categoriaId) ?? null; },
          async save(value) {
            if (items.some((item) => item.id !== value.id && item.categoriaId === value.categoriaId && item.nome.toLowerCase() === value.nome.toLowerCase())) {
              throw Object.assign(new Error('duplicate'), { code: 'ER_DUP_ENTRY' });
            }
            if (!value.id) { value.id = items.length + 1; items.push(value); }
            return value;
          },
        };
        const result = await operation({
          getRepository(entity) {
            if (entity.name === 'CategoriaEntity') return categorias;
            if (entity.name === 'ServicoCatalogoEntity') return repository;
            if (entity.name === 'AdminAuditoriaEntity') return {
              create: (value) => value,
              async save(value) { if (state.falharAuditoria) throw new Error('auditoria indisponivel'); audits.push(value); },
            };
            throw new Error(`unexpected repository ${entity.name}`);
          },
        });
        state.servicos = items;
        state.auditorias.push(...audits);
        return result;
      },
    },
  };
  return { state, service: new ServicosCatalogoService(servicos, categorias) };
}

function errorCode(code) {
  return (error) => error.getResponse?.().code === code;
}

test('administrador cria pausado e pode editar, ativar e pausar com auditoria', async () => {
  const { state, service } = setup();
  const created = (await service.criar(admin, 1, { nome: '  Montagem de cadeira  ', descricao: 'Seguir o manual' })).servico;
  assert.equal(created.nome, 'Montagem de cadeira');
  assert.equal(created.ativo, false);
  assert.equal(created.categoriaId, 1);
  const updated = (await service.atualizar(admin, 1, created.id, { ativo: true, nome: 'Montagem de mesa' })).servico;
  assert.equal(updated.ativo, true);
  assert.equal(updated.nome, 'Montagem de mesa');
  assert.equal((await service.atualizar(admin, 1, created.id, { ativo: false, descricao: null })).servico.descricao, null);
  assert.deepEqual(state.auditorias.map((item) => item.acao), ['servico_catalogo_criado', 'servico_catalogo_atualizado', 'servico_catalogo_atualizado']);
  const audit = JSON.parse(state.auditorias[1].detalhe);
  assert.deepEqual(audit.antes, { ativo: false });
  assert.deepEqual(audit.depois, { ativo: true });
});

test('valida categoria, duplicidade, campos e pertencimento', async () => {
  const { service } = setup();
  await assert.rejects(service.criar(admin, 99, { nome: 'Teste' }), errorCode('CATEGORIA_NAO_ENCONTRADA'));
  await assert.rejects(service.criar(admin, 2, { nome: 'Teste', ativo: true }), errorCode('CATEGORIA_INATIVA'));
  const item = (await service.criar(admin, 1, { nome: 'Teste' })).servico;
  await assert.rejects(service.criar(admin, 1, { nome: 'teste' }), errorCode('SERVICO_CATALOGO_JA_EXISTE'));
  await assert.rejects(service.atualizar(admin, 2, item.id, { nome: 'Outro' }), errorCode('SERVICO_CATALOGO_NAO_ENCONTRADO'));
  await assert.rejects(service.atualizar(admin, 1, item.id, { categoriaId: 2 }), errorCode('CAMPO_INVALIDO'));
  await assert.rejects(service.criar(admin, 1, { nome: ' ' }), errorCode('CAMPO_INVALIDO'));
  await assert.rejects(service.atualizar(admin, 1, item.id, {}), errorCode('SERVICO_CATALOGO_INVALIDO'));
});

test('falha de auditoria nao confirma criacao nem edicao', async () => {
  const { state, service } = setup();
  const item = (await service.criar(admin, 1, { nome: 'Inicial' })).servico;
  state.falharAuditoria = true;
  await assert.rejects(service.criar(admin, 1, { nome: 'Novo' }), /auditoria indisponivel/);
  await assert.rejects(service.atualizar(admin, 1, item.id, { nome: 'Alterado' }), /auditoria indisponivel/);
  assert.equal(state.servicos.length, 1);
  assert.equal(state.servicos[0].nome, 'Inicial');
});

test('listagem administrativa limita categoria, filtro e paginacao', async () => {
  const calls = [];
  const builder = {
    where(sql, params) { calls.push([sql, params]); return this; },
    andWhere(sql, params) { calls.push([sql, params]); return this; },
    orderBy() { return this; }, addOrderBy() { return this; },
    skip(value) { calls.push(['skip', value]); return this; },
    take(value) { calls.push(['take', value]); return this; },
    async getManyAndCount() { return [[{ id: 3, categoriaId: 1, nome: 'Cadeira', descricao: null, inclusoes: null, exclusoes: null, ativo: false }], 1]; },
  };
  const service = new ServicosCatalogoService(
    { createQueryBuilder: () => builder },
    { async findOne({ where }) { return where.id === 1 ? { id: 1 } : null; } },
  );
  const result = await service.listar(1, { ativo: 'false', termo: 'Cad', pagina: '2', limite: '5' });
  assert.equal(result.servicos[0].nome, 'Cadeira');
  assert.equal(result.paginacao.pagina, 2);
  assert.ok(calls.some(([sql, params]) => sql.includes('categoriaId') && params.categoriaId === 1));
  assert.ok(calls.some(([sql, params]) => sql.includes('ativo') && params.ativo === false));
  assert.ok(calls.some(([sql, params]) => sql.includes('LIKE') && params.termo === '%Cad%'));
  assert.ok(calls.some(([key, value]) => key === 'skip' && value === 5));
  await assert.rejects(service.listar(99, {}), errorCode('CATEGORIA_NAO_ENCONTRADA'));
  await assert.rejects(service.listar(1, { ativo: 'talvez' }), errorCode('FILTRO_INVALIDO'));
});

test('rotas do catalogo administrativo exigem guardas e papel de administrador', () => {
  assert.deepEqual(Reflect.getMetadata(rolesMetadataKey, ServicosCatalogoController), ['administrador']);
  assert.deepEqual(Reflect.getMetadata(GUARDS_METADATA, ServicosCatalogoController).map((guard) => guard.name), ['AuthGuard', 'RolesGuard']);
});
