import test from 'node:test';
import assert from 'node:assert/strict';
import { PrivacidadeService } from '../dist/privacidade/privacidade.service.js';
import { SolicitacaoEntity } from '../dist/database/entities/solicitacao.entity.js';
import { SolicitacaoEventoEntity } from '../dist/database/entities/solicitacao-evento.entity.js';
import { SolicitacaoPropostaEntity } from '../dist/database/entities/solicitacao-proposta.entity.js';

test('exclusão de profissional remove escopo proposto e cópias no histórico', async () => {
  const updates = [];
  const usuario = { id: 101, tipo: 'profissional', ativo: true, senhaHash: 'hash', fotoPerfil: null, tokenVersion: 0 };
  const proposta = { solicitacaoId: 7, propostoPorId: 101, status: 'aceita', escopoProposto: 'Texto pessoal' };
  const manager = {
    createQueryBuilder(entity) {
      const query = {
        addSelect() { return this; }, where() { return this; }, andWhere() { return this; },
        setLock() { return this; }, async getOne() { return usuario; }, async getCount() { return 0; },
      };
      return query;
    },
    async findOne() { return { id: 10 }; },
    async find(entity) {
      if (entity === SolicitacaoPropostaEntity) return [proposta];
      return [];
    },
    async update(entity, where, values) { updates.push({ entity, where, values }); },
    async delete() {},
    create(_entity, values) { return { ...values }; },
    async save(_entity, value) { return value; },
  };
  const dataSource = { async transaction(_isolation, action) { return action(manager); } };
  const service = new PrivacidadeService(dataSource, {
    async verify() { return true; }, async hash() { return 'novo-hash'; },
  }, {}, {});
  const resultado = await service.excluirConta({ id: 101, tipo: 'profissional' }, {
    senhaAtual: 'senha-valida', confirmacao: 'EXCLUIR',
  });
  assert.equal(resultado.contaExcluida, true);
  assert.ok(updates.some((item) => item.entity === SolicitacaoPropostaEntity &&
    item.where.propostoPorId === 101 && item.values.escopoProposto === null));
  assert.ok(updates.some((item) => item.entity === SolicitacaoEntity &&
    item.values.descricao === 'Conteudo removido pelo titular.' && item.where.id));
  assert.ok(updates.some((item) => item.entity === SolicitacaoEventoEntity &&
    item.where.tipo === 'proposta_pre_aceite_criada' && item.values.motivo === null));
});

test('exportação inclui propostas dos pedidos e oculta identificador da outra parte', async () => {
  const usuario = {
    id: 30, nome: 'Cliente', email: 'cliente@example.invalid', emailVerificado: true,
    googleSub: null, telefone: null, tipo: 'cliente', ativo: true, fotoPerfil: null,
    criadoEm: new Date(), atualizadoEm: new Date(),
  };
  const manager = {
    async findOne() { return null; },
    async find(entity) {
      if (entity === SolicitacaoPropostaEntity) {
        return [{ id: 8, solicitacaoId: 7, propostoPorId: 101, escopoProposto: 'Escopo combinado' }];
      }
      return [];
    },
    createQueryBuilder(entity) {
      return {
        where() { return this; }, orWhere() { return this; }, orderBy() { return this; },
        async getMany() { return entity === SolicitacaoEntity ? [{ id: 7, clienteId: 30, enderecoId: null }] : []; },
      };
    },
  };
  const service = new PrivacidadeService({ manager }, {}, {}, {});
  const resultado = await service.montarExportacao(usuario);
  assert.equal(resultado.propostasDeAtendimentos.length, 1);
  assert.equal(resultado.propostasDeAtendimentos[0].escopoProposto, 'Escopo combinado');
  assert.equal(resultado.propostasDeAtendimentos[0].propostoPorId, null);
});
