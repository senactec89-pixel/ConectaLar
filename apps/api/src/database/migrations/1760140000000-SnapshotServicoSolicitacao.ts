import type { MigrationInterface, QueryRunner } from 'typeorm';

export class SnapshotServicoSolicitacao1760140000000 implements MigrationInterface {
  name = 'SnapshotServicoSolicitacao1760140000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('ALTER TABLE solicitacoes ADD COLUMN servico_snapshot JSON NULL AFTER nome_servico');
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const rows = await queryRunner.query('SELECT COUNT(*) AS total FROM solicitacoes WHERE servico_snapshot IS NOT NULL') as Array<{ total: number | string }>;
    if (Number(rows[0]?.total) !== 0) throw new Error('Rollback blocked: preserve service snapshots.');
    await queryRunner.query('ALTER TABLE solicitacoes DROP COLUMN servico_snapshot');
  }
}
