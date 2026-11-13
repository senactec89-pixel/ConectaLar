import type { MigrationInterface, QueryRunner } from 'typeorm';

export class PrazosPropostasAgendadas1760137000000 implements MigrationInterface {
  name = 'PrazosPropostasAgendadas1760137000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    for (const table of ['solicitacao_orcamentos', 'solicitacao_reagendamentos']) {
      if (!(await queryRunner.hasColumn(table, 'vence_em'))) {
        await queryRunner.query(`ALTER TABLE ${table} ADD COLUMN vence_em DATETIME(3) NULL`);
      }
      const index = table === 'solicitacao_orcamentos'
        ? 'idx_orcamentos_vencimento' : 'idx_reagendamentos_vencimento';
      const current = await queryRunner.getTable(table);
      if (!current?.indices.some((item) => item.name === index)) {
        await queryRunner.query(`ALTER TABLE ${table} ADD INDEX ${index} (status, vence_em)`);
      }
    }
    await replaceCheck(queryRunner, 'solicitacao_orcamentos', 'chk_orcamentos_status',
      "'pendente','aceito','recusado','substituido','expirado'");
    await replaceCheck(queryRunner, 'solicitacao_reagendamentos', 'chk_reagendamentos_status',
      "'pendente','aceito','recusado','cancelado','expirado'");
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    for (const table of ['solicitacao_orcamentos', 'solicitacao_reagendamentos']) {
      const hasDeadline = await queryRunner.hasColumn(table, 'vence_em');
      const rows = await queryRunner.query(
        `SELECT COUNT(*) AS total FROM ${table} WHERE status = 'expirado'${hasDeadline ? ' OR vence_em IS NOT NULL' : ''}`,
      ) as Array<{ total: number | string }>;
      if (Number(rows[0]?.total) !== 0) {
        throw new Error('Rollback blocked: preserve proposal deadlines and expiration history.');
      }
    }
    await replaceCheck(queryRunner, 'solicitacao_orcamentos', 'chk_orcamentos_status',
      "'pendente','aceito','recusado','substituido'");
    await replaceCheck(queryRunner, 'solicitacao_reagendamentos', 'chk_reagendamentos_status',
      "'pendente','aceito','recusado','cancelado'");
    for (const table of ['solicitacao_orcamentos', 'solicitacao_reagendamentos']) {
      const index = table === 'solicitacao_orcamentos'
        ? 'idx_orcamentos_vencimento' : 'idx_reagendamentos_vencimento';
      const current = await queryRunner.getTable(table);
      if (current?.indices.some((item) => item.name === index)) {
        await queryRunner.query(`ALTER TABLE ${table} DROP INDEX ${index}`);
      }
      if (await queryRunner.hasColumn(table, 'vence_em')) {
        await queryRunner.query(`ALTER TABLE ${table} DROP COLUMN vence_em`);
      }
    }
  }
}

async function replaceCheck(
  queryRunner: QueryRunner, table: string, constraint: string, values: string,
): Promise<void> {
  const existing = await queryRunner.query(
    `SELECT CONSTRAINT_NAME FROM information_schema.TABLE_CONSTRAINTS
     WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = ?
       AND CONSTRAINT_NAME = ? AND CONSTRAINT_TYPE = 'CHECK'`,
    [table, constraint],
  ) as Array<{ CONSTRAINT_NAME: string }>;
  if (existing.length > 0) {
    await queryRunner.query(`ALTER TABLE ${table} DROP CONSTRAINT ${constraint}`);
  }
  await queryRunner.query(`ALTER TABLE ${table} ADD CONSTRAINT ${constraint} CHECK (status IN (${values}))`);
}
