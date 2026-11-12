import type { MigrationInterface, QueryRunner } from 'typeorm';

export class AgendaSemIntervalo1760139000000 implements MigrationInterface {
  name = 'AgendaSemIntervalo1760139000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    // Offers are editable configuration; accepted requests retain their snapshots.
    await queryRunner.query('UPDATE profissional_servicos SET intervalo_minutos = 0');
    await queryRunner.query(`ALTER TABLE profissional_servicos
      MODIFY COLUMN intervalo_minutos SMALLINT UNSIGNED NOT NULL DEFAULT 0`);
    await queryRunner.query(`ALTER TABLE solicitacoes
      MODIFY COLUMN intervalo_minutos SMALLINT UNSIGNED NOT NULL DEFAULT 0`);
  }

  async down(_queryRunner: QueryRunner): Promise<void> {
    throw new Error('Rollback blocked: previous offer intervals cannot be reconstructed.');
  }
}
