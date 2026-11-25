import assert from 'node:assert/strict';
import test from 'node:test';
import { HabilitacaoPilotoPorTarefa1760146000000 } from '../dist/database/migrations/1760146000000-HabilitacaoPilotoPorTarefa.js';
import { FormacaoInformadaPorTarefa1760147000000 } from '../dist/database/migrations/1760147000000-FormacaoInformadaPorTarefa.js';

function queryRunner({ providerCount = 0, policyCount = 0, version = '8.4.13' } = {}) {
  const statements = [];
  return {
    statements,
    async query(sql) {
      statements.push(sql);
      if (sql.includes('FROM profissional_servicos')) return [{ total: providerCount }];
      if (sql.includes('FROM servicos_catalogo')) return [{ total: policyCount }];
      if (sql.includes('SELECT VERSION()')) return [{ version }];
      return [];
    },
  };
}

test('migration cria campos com estados bloqueados por padrao', async () => {
  const runner = queryRunner();
  await new HabilitacaoPilotoPorTarefa1760146000000().up(runner);
  assert.equal(runner.statements.length, 2);
  assert.match(runner.statements[0], /politica_piloto VARCHAR\(32\) NOT NULL DEFAULT 'fora_piloto'/);
  assert.match(runner.statements[1], /revisao_experiencia_estado VARCHAR\(24\) NOT NULL DEFAULT 'pendente'/);
  assert.match(runner.statements[1], /iniciante_confirmado_piloto BOOLEAN NOT NULL DEFAULT FALSE/);
  assert.match(runner.statements[1], /primeiro_revisor_id/);
  assert.match(runner.statements[1], /revisor_final_id/);
});

test('rollback protege declaracoes e politicas ja registradas', async () => {
  for (const options of [{ providerCount: 1 }, { policyCount: 1 }]) {
    const runner = queryRunner(options);
    await assert.rejects(
      new HabilitacaoPilotoPorTarefa1760146000000().down(runner),
      /Rollback blocked/,
    );
    assert.equal(runner.statements.some((sql) => sql.startsWith('ALTER TABLE')), false);
  }
});

test('rollback usa sintaxe de constraints compativel com MySQL e MariaDB', async () => {
  for (const [version, operation] of [['8.4.13', 'DROP CHECK'], ['10.11.6-MariaDB', 'DROP CONSTRAINT']]) {
    const runner = queryRunner({ version });
    await new HabilitacaoPilotoPorTarefa1760146000000().down(runner);
    const drops = runner.statements.filter((sql) => sql.includes(operation));
    assert.equal(drops.length, 2);
    assert.ok(drops.every((sql) => sql.includes(operation)));
  }
});

test('migration adiciona formacao declarada opcional e protege dados no rollback', async () => {
  const runner = queryRunner();
  await new FormacaoInformadaPorTarefa1760147000000().up(runner);
  assert.match(runner.statements[0], /formacao_informada_piloto VARCHAR\(300\) NULL/);

  const populated = queryRunner({ providerCount: 1 });
  await assert.rejects(
    new FormacaoInformadaPorTarefa1760147000000().down(populated),
    /Rollback blocked/,
  );
  assert.equal(populated.statements.some((sql) => sql.startsWith('ALTER TABLE')), false);

  const empty = queryRunner();
  await new FormacaoInformadaPorTarefa1760147000000().down(empty);
  assert.match(empty.statements[1], /DROP COLUMN formacao_informada_piloto/);
});
