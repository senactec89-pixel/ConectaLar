import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const script = fileURLToPath(new URL('../scripts/seed-profissionais-ficticios-homologacao.mjs', import.meta.url));

test('seed de profissionais ficticios recusa um banco que nao seja homologacao', () => {
  const result = spawnSync(process.execPath, [script], {
    encoding: 'utf8',
    env: {
      ...process.env,
      CONECTALAR_STAGE: 'homologacao',
      DB_NAME: 'conectalar_producao',
      SEED_HOMOLOGACAO_FICTICIOS: 'SIM',
    },
  });

  assert.equal(result.status, 1);
  assert.match(result.stderr, /Carga bloqueada/);
});

test('seed de profissionais ficticios exige senha forte antes de acessar o banco', () => {
  const result = spawnSync(process.execPath, [script], {
    encoding: 'utf8',
    env: {
      ...process.env,
      CONECTALAR_STAGE: 'homologacao',
      DB_NAME: 'conectalar_homologacao',
      SEED_HOMOLOGACAO_FICTICIOS: 'SIM',
      HOMOLOGACAO_DEMO_PASSWORD: 'fraca',
    },
  });

  assert.equal(result.status, 1);
  assert.match(result.stderr, /HOMOLOGACAO_DEMO_PASSWORD/);
});
