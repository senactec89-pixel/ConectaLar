import assert from 'node:assert/strict';
import test from 'node:test';
import { detalheAuditoriaSeguro, registrarAuditoriaAdmin } from '../dist/common/admin-auditoria.js';
import { AdminPainelService } from '../dist/admin-painel/admin-painel.service.js';

test('auditoria grava apenas campos estruturados e omite texto sensivel', async () => {
  const salvos = [];
  const manager = { getRepository: () => ({
    create: (value) => value,
    save: async (value) => { salvos.push(value); },
  }) };
  await registrarAuditoriaAdmin(manager, {
    atorId: 1, acao: 'denuncia_moderada', alvoTipo: 'denuncia', alvoId: 3,
    detalhe: { solicitacaoId: 8, status: { antes: 'pendente', depois: 'resolvida' },
      decisao: 'CPF 123.456.789-00', motivoDenuncia: 'email@exemplo.com' },
  });
  assert.deepEqual(JSON.parse(salvos[0].detalhe), {
    solicitacaoId: 8, status: { antes: 'pendente', depois: 'resolvida' },
  });
});

test('consulta filtra inclusive registros legados com texto livre', async () => {
  const legado = { id: 3, ator: { id: 1, nome: 'Admin', tipo: 'administrador' },
    acao: 'denuncia_moderada', alvoTipo: 'denuncia', alvoId: 4,
    detalhe: JSON.stringify({ status: { antes: 'pendente', depois: 'resolvida' },
      decisao: 'Telefone 11999999999' }), criadoEm: new Date('2026-11-12T10:00:00Z') };
  const builder = {
    leftJoinAndSelect() { return this; }, orderBy() { return this; },
    addOrderBy() { return this; }, skip() { return this; }, take() { return this; },
    async getManyAndCount() { return [[legado], 1]; },
  };
  const service = new AdminPainelService({ createQueryBuilder: () => builder },
    {}, {}, {}, {}, {}, {}, {});
  const result = await service.listarAuditoria({});
  assert.equal(result.eventos.length, 1);
  assert.deepEqual(JSON.parse(result.eventos[0].detalhe), {
    status: { antes: 'pendente', depois: 'resolvida' },
  });
  assert.equal(detalheAuditoriaSeguro('texto livre: cpf 123'), '{}');
});
