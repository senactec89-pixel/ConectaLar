import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const script = fileURLToPath(new URL('../scripts/seed-homologacao-opcoes-catalogo.mjs', import.meta.url));

test('seed de opcoes recusa qualquer base diferente da homologacao', () => {
  const result = spawnSync(process.execPath, [script], {
    encoding: 'utf8',
    env: {
      ...process.env,
      CONECTALAR_STAGE: 'homologacao',
      DB_NAME: 'conectalar_producao',
      SEED_HOMOLOGACAO_OPCOES: 'SIM',
    },
  });

  assert.equal(result.status, 1);
  assert.match(result.stderr, /Carga bloqueada/);
});
