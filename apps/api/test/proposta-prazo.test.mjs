import assert from 'node:assert/strict';
import test from 'node:test';
import { calcularExpiracaoProposta, propostaExpirada } from '../dist/solicitacoes/proposta-prazo.js';

test('a proposta expira em 48 horas quando o atendimento e mais distante', () => {
  const criadoEm = new Date('2026-11-10T15:00:00.000Z');
  const expiraEm = calcularExpiracaoProposta(criadoEm, '2026-11-13', '10:00');

  assert.equal(expiraEm.toISOString(), '2026-11-12T15:00:00.000Z');
});

test('a proposta expira no inicio do atendimento quando ele ocorre antes de 48 horas', () => {
  const criadoEm = new Date('2026-11-10T15:00:00.000Z');
  const expiraEm = calcularExpiracaoProposta(criadoEm, '2026-11-11', '10:00');

  assert.equal(expiraEm.toISOString(), '2026-11-11T13:00:00.000Z');
});

test('o limite de expiracao e inclusivo', () => {
  const expiraEm = new Date('2026-11-12T15:00:00.000Z');

  assert.equal(propostaExpirada(expiraEm, new Date('2026-11-12T14:59:59.999Z')), false);
  assert.equal(propostaExpirada(expiraEm, expiraEm), true);
});
