import assert from 'node:assert/strict';
import test from 'node:test';
import { DenunciasService } from '../dist/denuncias/denuncias.service.js';

function denuncia() {
  const agora = new Date('2026-10-23T12:00:00Z');
  return {
    id: 4,
    solicitacaoId: 10,
    denuncianteId: 30,
    denunciadoId: 20,
    denunciado: { id: 20, nome: 'Profissional', tipo: 'profissional' },
    solicitacao: {
      id: 10,
      nomeServico: 'Reparo eletrico',
      dataServico: '2026-10-25',
      categoria: { id: 2, nome: 'Eletrica' },
      profissional: {
        usuario: { id: 20, nome: 'Profissional', tipo: 'profissional' },
      },
    },
    motivo: 'Conduta inadequada',
    descricao: 'Relato detalhado para a equipe administrativa analisar.',
    status: 'pendente',
    decisao: null,
    analisadoPorId: null,
    analisadoEm: null,
    criadoEm: agora,
    atualizadoEm: agora,
  };
}

test('historico consulta apenas denuncias enviadas pelo usuario', async () => {
  let opcoes;
  const item = denuncia();
  const service = new DenunciasService(
    {},
    {
      async find(value) { opcoes = value; return [item]; },
    },
    {},
    {},
  );

  const response = await service.listarMinhas({ id: 30, tipo: 'cliente' });
  assert.deepEqual(opcoes.where, { denuncianteId: 30 });
  assert.equal(opcoes.take, 50);
  assert.equal(response.denuncias[0].denunciado.nome, 'Profissional');
  assert.deepEqual(response.denuncias[0].atendimento, {
    id: 10,
    nomeServico: 'Reparo eletrico',
    dataServico: '2026-10-25',
    profissional: 'Profissional',
  });
});

test('decisao administrativa notifica denunciante sem desfazer moderacao', async () => {
  const item = denuncia();
  const auditorias = [];
  const notificacoes = [];
  const service = new DenunciasService(
    {
      create(value) { return value; },
      async save(value) { auditorias.push(value); return value; },
    },
    {
      async findOne() { return item; },
      async save(value) { return value; },
    },
    {},
    {
      async criar(value) { notificacoes.push(value); },
    },
  );

  const response = await service.moderar(
    { id: 99, tipo: 'administrador' },
    4,
    { status: 'resolvida', decisao: 'Medidas administrativas registradas.' },
  );
  assert.equal(response.denuncia.status, 'resolvida');
  assert.equal(auditorias.length, 1);
  assert.equal(notificacoes.length, 1);
  assert.equal(notificacoes[0].usuarioId, 30);
  assert.equal(notificacoes[0].recursoId, 10);
});
