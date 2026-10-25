import assert from 'node:assert/strict';
import test from 'node:test';
import {
  optionalEnumFilter,
  optionalSearchTerm,
} from '../dist/common/admin-list-query.js';

const codigo = (value) => (error) => error.getResponse?.().code === value;

test('admin list search trims empty values and enforces a bounded length', () => {
  assert.equal(optionalSearchTerm({}), null);
  assert.equal(optionalSearchTerm({ termo: '  ' }), null);
  assert.equal(optionalSearchTerm({ termo: '  Ana  ' }), 'Ana');
  assert.throws(
    () => optionalSearchTerm({ termo: 'x'.repeat(121) }),
    codigo('FILTRO_INVALIDO'),
  );
  assert.throws(() => optionalSearchTerm({ termo: ['admin'] }), codigo('FILTRO_INVALIDO'));
});

test('admin list enum filters accept only declared values', () => {
  const allowed = ['pendente', 'aprovada', 'rejeitada'];
  assert.equal(optionalEnumFilter({}, 'status', allowed), null);
  assert.equal(optionalEnumFilter({ status: 'pendente' }, 'status', allowed), 'pendente');
  assert.throws(
    () => optionalEnumFilter({ status: 'pendente OR 1=1' }, 'status', allowed),
    codigo('FILTRO_INVALIDO'),
  );
});
