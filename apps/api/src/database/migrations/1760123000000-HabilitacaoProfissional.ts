import type { MigrationInterface, QueryRunner } from 'typeorm';

export class HabilitacaoProfissional1760123000000 implements MigrationInterface {
  name = 'HabilitacaoProfissional1760123000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE profissionais
      ADD COLUMN habilitacao_estado VARCHAR(24) NOT NULL DEFAULT 'pendente',
      ADD COLUMN habilitacao_revisao_em DATETIME NULL,
      ADD INDEX idx_profissionais_habilitacao (habilitacao_estado, id),
      ADD CONSTRAINT chk_profissionais_habilitacao CHECK (habilitacao_estado IN ('pendente', 'em_analise', 'suspenso'))`);
    await dropCheckConstraint(queryRunner, 'admin_auditoria', 'chk_admin_auditoria_acao');
    await queryRunner.query(`ALTER TABLE admin_auditoria
      ADD CONSTRAINT chk_admin_auditoria_acao CHECK (acao IN (
        'usuario_ativado', 'usuario_desativado', 'administrador_criado',
        'categoria_criada', 'categoria_atualizada', 'documento_analisado',
        'denuncia_moderada', 'avaliacao_moderada',
        'habilitacao_analisada', 'habilitacao_revisao_solicitada'))`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const rows = await queryRunner.query(`SELECT COUNT(*) AS total FROM admin_auditoria
      WHERE acao IN ('habilitacao_analisada', 'habilitacao_revisao_solicitada')`) as Array<{ total: number | string }>;
    if (Number(rows[0]?.total) !== 0) {
      throw new Error('Rollback blocked: preserve the professional eligibility audit history.');
    }
    await dropCheckConstraint(queryRunner, 'admin_auditoria', 'chk_admin_auditoria_acao');
    await queryRunner.query(`ALTER TABLE admin_auditoria
      ADD CONSTRAINT chk_admin_auditoria_acao CHECK (acao IN (
        'usuario_ativado', 'usuario_desativado', 'administrador_criado',
        'categoria_criada', 'categoria_atualizada', 'documento_analisado',
        'denuncia_moderada', 'avaliacao_moderada'))`);
    await dropCheckConstraint(queryRunner, 'profissionais', 'chk_profissionais_habilitacao');
    await queryRunner.query(`ALTER TABLE profissionais
      DROP INDEX idx_profissionais_habilitacao,
      DROP COLUMN habilitacao_revisao_em,
      DROP COLUMN habilitacao_estado`);
  }
}

async function dropCheckConstraint(
  queryRunner: QueryRunner,
  tableName: string,
  constraintName: string,
): Promise<void> {
  const rows = (await queryRunner.query('SELECT VERSION() AS version')) as Array<{
    version: string;
  }>;
  const version = rows[0]?.version?.toLowerCase() ?? '';
  const operation = version.includes('mariadb') ? 'DROP CONSTRAINT' : 'DROP CHECK';
  await queryRunner.query(`ALTER TABLE ${tableName} ${operation} ${constraintName}`);
}
