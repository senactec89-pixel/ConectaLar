import assert from 'node:assert/strict';
import test from 'node:test';

import { PagamentoSimulado } from './support/pagamento-simulado.mjs';

test('integral: simulacao exige pagamento e confirmacao dos dois participantes', () => {
  const pagamento = new PagamentoSimulado(10_000);
  pagamento.receber({ eventoId: 'evento-ficticio-1', valorCentavos: 10_000 });
  assert.throws(() => pagamento.simularRepasse(), /REPASSE_INDISPONIVEL/);
  assert.throws(() => pagamento.confirmarPeloCliente(), /CONFIRMACAO_INDISPONIVEL/);
  pagamento.concluirPeloProfissional();
  assert.throws(() => pagamento.simularRepasse(), /REPASSE_INDISPONIVEL/);
  pagamento.confirmarPeloCliente();
  assert.deepEqual(pagamento.simularRepasse(), { valorCentavos: 10_000, apenasSimulacao: true });
  assert.throws(() => pagamento.simularRepasse(), /REPASSE_INDISPONIVEL/);
});

test('50 antes e 50 depois: saldo incompleto nao simula repasse integral', () => {
  const pagamento = new PagamentoSimulado(10_000);
  pagamento.receber({ eventoId: 'parcela-ficticia-1', valorCentavos: 5_000 });
  pagamento.concluirPeloProfissional();
  pagamento.confirmarPeloCliente();
  assert.throws(() => pagamento.simularRepasse(), /REPASSE_INDISPONIVEL/);
  pagamento.receber({ eventoId: 'parcela-ficticia-2', valorCentavos: 5_000 });
  assert.equal(pagamento.simularRepasse().valorCentavos, 10_000);
});

test('evento repetido nao duplica saldo; dados conflitantes sao recusados', () => {
  const pagamento = new PagamentoSimulado(10_000);
  pagamento.receber({ eventoId: 'evento-ficticio-1', valorCentavos: 5_000 });
  pagamento.receber({ eventoId: 'evento-ficticio-1', valorCentavos: 5_000 });
  assert.equal(pagamento.recebidoCentavos, 5_000);
  assert.throws(() => pagamento.receber({ eventoId: 'evento-ficticio-1', valorCentavos: 4_000 }), /EVENTO_CONFLITANTE/);
  assert.throws(() => pagamento.receber({ eventoId: 'evento-ficticio-2', valorCentavos: 6_000 }), /VALOR_INESPERADO/);
});

test('contestacao impede confirmacao e repasse simulado', () => {
  const pagamento = new PagamentoSimulado(10_000);
  pagamento.receber({ eventoId: 'evento-ficticio-1', valorCentavos: 10_000 });
  pagamento.concluirPeloProfissional();
  pagamento.contestar();
  assert.throws(() => pagamento.confirmarPeloCliente(), /CONFIRMACAO_INDISPONIVEL/);
  assert.throws(() => pagamento.simularRepasse(), /REPASSE_INDISPONIVEL/);
});

test('valores de teste usam centavos inteiros positivos e seguros', () => {
  for (const valor of [0, -1, 1.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
    assert.throws(() => new PagamentoSimulado(valor), /VALOR_INVALIDO/);
  }
  const pagamento = new PagamentoSimulado(10_000);
  assert.throws(() => pagamento.receber({ eventoId: '', valorCentavos: 5000 }), /EVENTO_INVALIDO/);
  assert.throws(() => pagamento.receber({ eventoId: 'ficticio', valorCentavos: 0.1 }), /VALOR_INVALIDO/);
});
