import type { MigrationInterface, QueryRunner } from 'typeorm';

export class HabilitacaoTesteLocal1760145000000 implements MigrationInterface {
  name = 'HabilitacaoTesteLocal1760145000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await dropCheckConstraint(queryRunner);
    await queryRunner.query(`ALTER TABLE profissionais
      ADD CONSTRAINT chk_profissionais_habilitacao CHECK (
        habilitacao_estado IN ('pendente', 'em_analise', 'suspenso', 'teste_local_aprovado')
      )`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const rows = await queryRunner.query(`SELECT COUNT(*) AS total FROM profissionais
      WHERE habilitacao_estado = 'teste_local_aprovado'`) as Array<{ total: number | string }>;
    if (Number(rows[0]?.total) !== 0) {
      throw new Error('Rollback blocked: local test approvals are still present.');
    }
    await dropCheckConstraint(queryRunner);
    await queryRunner.query(`ALTER TABLE profissionais
      ADD CONSTRAINT chk_profissionais_habilitacao CHECK (
        habilitacao_estado IN ('pendente', 'em_analise', 'suspenso')
      )`);
  }
}

async function dropCheckConstraint(queryRunner: QueryRunner): Promise<void> {
  const rows = await queryRunner.query('SELECT VERSION() AS version') as Array<{ version: string }>;
  const operation = rows[0]?.version?.toLowerCase().includes('mariadb')
    ? 'DROP CONSTRAINT'
    : 'DROP CHECK';
  await queryRunner.query(`ALTER TABLE profissionais ${operation} chk_profissionais_habilitacao`);
}
