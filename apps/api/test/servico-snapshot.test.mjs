import assert from 'node:assert/strict';
import { test } from 'node:test';
import { criarSnapshotServico } from '../dist/solicitacoes/servico-snapshot.js';

test('snapshot guarda valores do catalogo no momento do pedido', () => {
  const oferta = { categoriaId: 2, categoria: { nome: 'Pintura' }, nome: 'Nome antigo da oferta', servicoCatalogoId: 7,
    servicoCatalogo: { nome: 'Pintura interna', descricao: 'Parede', inclusoes: 'Tinta', exclusoes: 'Altura' } };
  const snapshot = criarSnapshotServico(oferta);
  oferta.categoria.nome = 'Categoria nova';
  oferta.servicoCatalogo.nome = 'Nome novo';
  oferta.servicoCatalogo.exclusoes = 'Outro';
  assert.deepEqual(snapshot, { categoriaId: 2, nomeCategoria: 'Pintura', servicoCatalogoId: 7,
    nomeServico: 'Pintura interna', descricao: 'Parede', inclusoes: 'Tinta', exclusoes: 'Altura' });
  assert.equal(criarSnapshotServico(null), null);
});
