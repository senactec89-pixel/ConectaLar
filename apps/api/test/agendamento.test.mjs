import assert from 'node:assert/strict';
import test from 'node:test';
import { intervalosLivres, parseDuracao, periodosSobrepostos } from '../dist/domain/agendamento.js';
import { horarioDisponivel } from '../dist/disponibilidade/disponibilidade.service.js';

const periodo = (horarioServico, duracaoMinutos, dataServico = '2027-10-18') => ({
  dataServico, horarioServico, duracaoMinutos,
});

test('different starts overlap, while adjacent appointments and different days do not', () => {
  assert.equal(periodosSobrepostos(periodo('10:00', 120), periodo('10:30', 60)), true);
  assert.equal(periodosSobrepostos(periodo('10:30', 30), periodo('10:00', 120)), true);
  assert.equal(periodosSobrepostos(periodo('10:00', 120), periodo('12:00', 60)), false);
  assert.equal(periodosSobrepostos(periodo('10:00', 120), periodo('10:00', 120, '2027-10-19')), false);
  // Previously accepted legacy appointments can cross midnight after migration.
  assert.equal(periodosSobrepostos(periodo('23:30', 120), periodo('00:30', 60, '2027-10-19')), true);
});

test('the entire appointment must fit in one active weekly availability interval', () => {
  const semana = [{ ativo: true, diaSemana: 1, horaInicio: '08:00', horaFim: '12:00' }];
  assert.equal(horarioDisponivel(semana, '2027-10-18', '10:00', 120), true);
  assert.equal(horarioDisponivel(semana, '2027-10-18', '10:30', 120), false);
  assert.equal(horarioDisponivel(semana, '2027-10-19', '10:00', 120), false);
  assert.equal(horarioDisponivel([{ ...semana[0], ativo: false }], '2027-10-18', '10:00', 120), false);
});

test('public free windows exclude occupied time and handle a legacy previous-day appointment', () => {
  const semana = [{ ativo: true, diaSemana: 1, horaInicio: '00:00', horaFim: '18:00' }];
  assert.deepEqual(intervalosLivres('2027-10-18', semana, [
    periodo('23:30', 120, '2027-10-17'), periodo('10:00', 120), periodo('11:30', 120),
  ]), [{ horaInicio: '01:30', horaFim: '10:00' }, { horaInicio: '13:30', horaFim: '18:00' }]);
});

test('duration requires an explicit positive whole number within one day', () => {
  for (const invalid of [undefined, null, 0, -1, 1.5, '120', 1441]) {
    assert.throws(() => parseDuracao(invalid));
  }
  assert.equal(parseDuracao(120), 120);
});
