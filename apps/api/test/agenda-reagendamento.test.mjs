import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { horarioDisponivel } from '../dist/disponibilidade/disponibilidade.service.js';
import { intervalosConflitam } from '../dist/solicitacoes/solicitacoes.service.js';

const disponibilidade = [
  {
    ativo: true,
    diaSemana: 1,
    horaInicio: '09:00',
    horaFim: '12:00',
  },
];

test('duration must fit completely inside weekly availability', () => {
  assert.equal(horarioDisponivel(disponibilidade, '2026-10-19', '10:30', 90), true);
  assert.equal(horarioDisponivel(disponibilidade, '2026-10-19', '11:00', 90), false);
});

test('overlap includes service duration and travel interval', () => {
  assert.equal(intervalosConflitam(14 * 60 + 30, 16 * 60, 14 * 60, 15 * 60 + 30), true);
  assert.equal(intervalosConflitam(15 * 60 + 30, 16 * 60, 14 * 60, 15 * 60 + 30), false);
});

test('professional blocks migration references the professionals table', async () => {
  const migration = await readFile(
    new URL(
      '../src/database/migrations/1760125000000-AgendaDuracaoBloqueiosReagendamento.ts',
      import.meta.url,
    ),
    'utf8',
  );

  assert.match(migration, /REFERENCES profissionais\(id\) ON DELETE CASCADE/);
  assert.doesNotMatch(migration, /REFERENCES profissional_perfis\(id\)/);
});
