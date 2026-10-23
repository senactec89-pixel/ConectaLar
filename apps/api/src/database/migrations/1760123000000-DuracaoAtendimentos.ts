import type { MigrationInterface, QueryRunner } from 'typeorm';

export class DuracaoAtendimentos1760123000000 implements MigrationInterface {
  name = 'DuracaoAtendimentos1760123000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    // Approved migration policy: existing offers and requests last 120 minutes.
    // MySQL DDL commits implicitly. Allow resuming if the process stops between
    // the two ALTERs, and reuse the existing idx_solicitacoes_agenda index.
    if (!(await queryRunner.hasColumn('profissional_servicos', 'duracao_minutos'))) {
      await queryRunner.query(`ALTER TABLE profissional_servicos
        ADD COLUMN duracao_minutos SMALLINT UNSIGNED NOT NULL DEFAULT 120,
        ADD CONSTRAINT chk_servicos_duracao CHECK (duracao_minutos BETWEEN 1 AND 1440)`);
    }
    if (!(await queryRunner.hasColumn('solicitacoes', 'duracao_minutos'))) {
      await queryRunner.query(`ALTER TABLE solicitacoes
        ADD COLUMN duracao_minutos SMALLINT UNSIGNED NOT NULL DEFAULT 120,
        ADD CONSTRAINT chk_solicitacoes_duracao CHECK (duracao_minutos BETWEEN 1 AND 1440)`);
    }
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE solicitacoes
      DROP CHECK chk_solicitacoes_duracao,
      DROP COLUMN duracao_minutos`);
    await queryRunner.query(`ALTER TABLE profissional_servicos
      DROP CHECK chk_servicos_duracao, DROP COLUMN duracao_minutos`);
  }
}
