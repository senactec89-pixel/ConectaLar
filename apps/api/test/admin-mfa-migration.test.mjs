import assert from 'node:assert/strict';
import test from 'node:test';
import { AdminMfaInvites1760132000000 } from '../dist/database/migrations/1760132000000-AdminMfaInvites.js';

test('admin MFA migration resumes safely after partial DDL and is repeatable', async () => {
  const columns = new Set(['mfa_falhas']);
  const tables = new Set();
  const statements = [];
  let hasEmailOutboxCheck = true;
  const queryRunner = {
    hasColumn: async (_table, column) => columns.has(column),
    hasTable: async (table) => tables.has(table),
    query: async (sql) => {
      statements.push(sql);
      if (sql.includes('FROM information_schema.TABLE_CONSTRAINTS')) {
        return hasEmailOutboxCheck
          ? [{ CONSTRAINT_NAME: 'chk_email_outbox_tipo' }]
          : [];
      }
      if (sql.includes('ADD COLUMN mfa_bloqueado_ate')) {
        columns.add('mfa_bloqueado_ate');
      }
      if (sql.includes('DROP CONSTRAINT chk_email_outbox_tipo')) {
        hasEmailOutboxCheck = false;
      }
      if (sql.includes('ADD CONSTRAINT chk_email_outbox_tipo')) {
        hasEmailOutboxCheck = true;
      }
      if (sql.includes('CREATE TABLE admin_convites')) {
        tables.add('admin_convites');
      }
      return [];
    },
  };

  const migration = new AdminMfaInvites1760132000000();
  await migration.up(queryRunner);
  await migration.up(queryRunner);

  assert.deepEqual([...columns].sort(), ['mfa_bloqueado_ate', 'mfa_falhas']);
  assert.equal(tables.has('admin_convites'), true);
  assert.equal(hasEmailOutboxCheck, true);
  assert.equal(
    statements.filter((sql) => sql.includes('ADD COLUMN mfa_falhas')).length,
    0,
  );
  assert.ok(
    statements.some((sql) => sql.includes('DROP CONSTRAINT chk_email_outbox_tipo')),
  );
  assert.ok(
    statements.some((sql) => sql.includes("'verificacao_email', 'convite_admin'")),
  );
});
