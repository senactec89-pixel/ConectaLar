import type { MigrationInterface, QueryRunner } from 'typeorm';

export class HabilitacaoManualProducao1760149000000 implements MigrationInterface {
  name = 'HabilitacaoManualProducao1760149000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE profissionais
      ADD COLUMN habilitacao_primeiro_revisor_id INT UNSIGNED NULL,
      ADD COLUMN habilitacao_primeira_revisao_em DATETIME NULL,
      ADD COLUMN habilitacao_revisor_final_id INT UNSIGNED NULL,
      ADD COLUMN habilitacao_aprovado_em DATETIME NULL,
      ADD CONSTRAINT fk_prof_hab_primeiro_revisor FOREIGN KEY (habilitacao_primeiro_revisor_id)
        REFERENCES usuarios(id) ON DELETE SET NULL ON UPDATE CASCADE,
      ADD CONSTRAINT fk_prof_hab_revisor_final FOREIGN KEY (habilitacao_revisor_final_id)
        REFERENCES usuarios(id) ON DELETE SET NULL ON UPDATE CASCADE`);
    await dropCheckConstraint(queryRunner);
    await queryRunner.query(`ALTER TABLE profissionais
      ADD CONSTRAINT chk_profissionais_habilitacao CHECK (
        habilitacao_estado IN ('pendente', 'em_analise', 'suspenso', 'aprovado', 'teste_local_aprovado')
      )`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const rows = await queryRunner.query(`SELECT COUNT(*) AS total FROM profissionais
      WHERE habilitacao_estado = 'aprovado'
        OR habilitacao_primeiro_revisor_id IS NOT NULL
        OR habilitacao_revisor_final_id IS NOT NULL`) as Array<{ total: number | string }>;
    if (Number(rows[0]?.total) !== 0) {
      throw new Error('Rollback blocked: manual production approvals are still present.');
    }
    await dropCheckConstraint(queryRunner);
    await queryRunner.query(`ALTER TABLE profissionais
      ADD CONSTRAINT chk_profissionais_habilitacao CHECK (
        habilitacao_estado IN ('pendente', 'em_analise', 'suspenso', 'teste_local_aprovado')
      ),
      DROP FOREIGN KEY fk_prof_hab_primeiro_revisor,
      DROP FOREIGN KEY fk_prof_hab_revisor_final,
      DROP COLUMN habilitacao_primeiro_revisor_id,
      DROP COLUMN habilitacao_primeira_revisao_em,
      DROP COLUMN habilitacao_revisor_final_id,
      DROP COLUMN habilitacao_aprovado_em`);
  }
}

async function dropCheckConstraint(queryRunner: QueryRunner): Promise<void> {
  const rows = await queryRunner.query('SELECT VERSION() AS version') as Array<{ version: string }>;
  const operation = rows[0]?.version?.toLowerCase().includes('mariadb')
    ? 'DROP CONSTRAINT'
    : 'DROP CHECK';
  await queryRunner.query(`ALTER TABLE profissionais ${operation} chk_profissionais_habilitacao`);
}
