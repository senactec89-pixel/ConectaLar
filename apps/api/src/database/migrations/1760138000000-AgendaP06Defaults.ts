import { MigrationInterface, QueryRunner } from 'typeorm';

export class AgendaP06Defaults1760138000000 implements MigrationInterface {
  name = 'AgendaP06Defaults1760138000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    for (const table of ['profissional_servicos', 'solicitacoes']) {
      for (const column of ['duracao_minutos', 'intervalo_minutos']) {
        if (!(await queryRunner.hasColumn(table, column))) {
          throw new Error(`Migration prerequisite missing: ${table}.${column}.`);
        }
      }
    }

    await queryRunner.query(`ALTER TABLE profissional_servicos
      ALTER COLUMN duracao_minutos SET DEFAULT 120,
      ALTER COLUMN intervalo_minutos SET DEFAULT 0`);
    await queryRunner.query(`ALTER TABLE solicitacoes
      ALTER COLUMN duracao_minutos SET DEFAULT 120,
      ALTER COLUMN intervalo_minutos SET DEFAULT 0`);
    await queryRunner.query(
      `UPDATE profissional_servicos
      SET duracao_minutos = 120, intervalo_minutos = 0`,
    );
    await queryRunner.query(
      'UPDATE solicitacoes SET duracao_minutos = 120, intervalo_minutos = 0',
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    // Keep normalized row values and accepted appointment snapshots intact.
    await queryRunner.query(`ALTER TABLE profissional_servicos
      ALTER COLUMN intervalo_minutos SET DEFAULT 30`);
    await queryRunner.query(`ALTER TABLE solicitacoes
      ALTER COLUMN intervalo_minutos SET DEFAULT 30`);
  }
}
