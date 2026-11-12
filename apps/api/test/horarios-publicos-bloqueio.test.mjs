import assert from 'node:assert/strict';
import test from 'node:test';
import { ProfissionaisService } from '../dist/profissionais/profissionais.service.js';

test('horarios publicos nao sugerem dia bloqueado para o profissional', async () => {
  let bloqueado = true;
  const query = {
    where() { return this; }, andWhere() { return this; },
    async getOne() { return bloqueado ? { id: 1 } : null; },
  };
  const service = new ProfissionaisService(
    {}, {}, { async find() { return [{ ativo: true, diaSemana: 1,
      horaInicio: '08:00', horaFim: '12:00' }]; } },
    {}, { async findOne() { return { duracaoMinutos: 60 }; } },
    { async find() { return []; } }, {}, {},
    { createQueryBuilder() { return query; } },
  );
  service.obter = async () => ({});
  const queryArgs = { data: '2027-10-18', servicoId: 7 };
  assert.deepEqual((await service.horariosLivres(2, queryArgs)).intervalos, []);
  bloqueado = false;
  assert.deepEqual((await service.horariosLivres(2, queryArgs)).intervalos, [
    { horaInicio: '08:00', horaFim: '12:00' },
  ]);
});
