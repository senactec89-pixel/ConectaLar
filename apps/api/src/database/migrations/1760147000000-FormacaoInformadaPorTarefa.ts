import type { MigrationInterface, QueryRunner } from 'typeorm';

export class FormacaoInformadaPorTarefa1760147000000 implements MigrationInterface {
  name = 'FormacaoInformadaPorTarefa1760147000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE profissional_servicos
      ADD COLUMN formacao_informada_piloto VARCHAR(300) NULL`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const rows = await queryRunner.query(`SELECT COUNT(*) AS total
      FROM profissional_servicos WHERE formacao_informada_piloto IS NOT NULL`) as Array<{ total: number | string }>;
    if (Number(rows[0]?.total) !== 0) {
      throw new Error('Rollback blocked: preserve task-related training declarations.');
    }
    await queryRunner.query(`ALTER TABLE profissional_servicos
      DROP COLUMN formacao_informada_piloto`);
  }
}
