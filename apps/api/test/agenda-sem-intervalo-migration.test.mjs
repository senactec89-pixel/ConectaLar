import assert from 'node:assert/strict';
import test from 'node:test';
import { AgendaSemIntervalo1760139000000 } from '../dist/database/migrations/1760139000000-AgendaSemIntervalo.js';

test('migration zera intervalo das ofertas sem reescrever pedidos antigos', async () => {
  const queries = [];
  const migration = new AgendaSemIntervalo1760139000000();
  await migration.up({ async query(sql) { queries.push(sql); } });
  assert.ok(queries.some((sql) => sql.startsWith('UPDATE profissional_servicos')));
  assert.ok(queries.some((sql) => sql.includes('ALTER TABLE solicitacoes')));
  assert.equal(queries.some((sql) => sql.startsWith('UPDATE solicitacoes')), false);
  await assert.rejects(migration.down({}), /cannot be reconstructed/);
});
