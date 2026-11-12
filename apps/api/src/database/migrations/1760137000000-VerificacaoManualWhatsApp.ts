import type { MigrationInterface, QueryRunner } from 'typeorm';

export class VerificacaoManualWhatsApp1760137000000 implements MigrationInterface {
  name = 'VerificacaoManualWhatsApp1760137000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE profissional_telefone_verificacoes
      ADD COLUMN metodo VARCHAR(24) NOT NULL DEFAULT 'id_zapsign',
      ADD COLUMN codigo_hash CHAR(64) NULL,
      ADD CONSTRAINT chk_telefone_verificacoes_metodo
        CHECK (metodo IN ('id_zapsign', 'whatsapp_manual'))`);
    await dropCheckConstraint(queryRunner, 'admin_auditoria', 'chk_admin_auditoria_acao');
    await queryRunner.query(`ALTER TABLE admin_auditoria
      ADD CONSTRAINT chk_admin_auditoria_acao CHECK (acao IN (
        'usuario_ativado', 'usuario_desativado', 'administrador_criado',
        'categoria_criada', 'categoria_atualizada', 'documento_analisado',
        'denuncia_moderada', 'avaliacao_moderada', 'habilitacao_analisada',
        'habilitacao_revisao_solicitada', 'telefone_manual_confirmado'))`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const audits = await queryRunner.query(`SELECT COUNT(*) AS total FROM admin_auditoria
      WHERE acao = 'telefone_manual_confirmado'`) as Array<{ total: number | string }>;
    const records = await queryRunner.query(`SELECT COUNT(*) AS total
      FROM profissional_telefone_verificacoes WHERE metodo = 'whatsapp_manual'`) as Array<{ total: number | string }>;
    if (Number(audits[0]?.total) !== 0 || Number(records[0]?.total) !== 0) {
      throw new Error('Rollback blocked: preserve manual phone verification history.');
    }
    await dropCheckConstraint(queryRunner, 'admin_auditoria', 'chk_admin_auditoria_acao');
    await queryRunner.query(`ALTER TABLE admin_auditoria
      ADD CONSTRAINT chk_admin_auditoria_acao CHECK (acao IN (
        'usuario_ativado', 'usuario_desativado', 'administrador_criado',
        'categoria_criada', 'categoria_atualizada', 'documento_analisado',
        'denuncia_moderada', 'avaliacao_moderada', 'habilitacao_analisada',
        'habilitacao_revisao_solicitada'))`);
    await queryRunner.query(`ALTER TABLE profissional_telefone_verificacoes
      DROP CHECK chk_telefone_verificacoes_metodo,
      DROP COLUMN codigo_hash,
      DROP COLUMN metodo`);
  }
}

async function dropCheckConstraint(
  queryRunner: QueryRunner,
  tableName: string,
  constraintName: string,
): Promise<void> {
  const rows = await queryRunner.query('SELECT VERSION() AS version') as Array<{ version: string }>;
  const operation = rows[0]?.version?.toLowerCase().includes('mariadb')
    ? 'DROP CONSTRAINT'
    : 'DROP CHECK';
  await queryRunner.query(`ALTER TABLE ${tableName} ${operation} ${constraintName}`);
}
