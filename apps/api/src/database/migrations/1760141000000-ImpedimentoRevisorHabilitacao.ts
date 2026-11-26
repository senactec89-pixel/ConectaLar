import type { MigrationInterface, QueryRunner } from 'typeorm';

export class ImpedimentoRevisorHabilitacao1760141000000 implements MigrationInterface {
  name = 'ImpedimentoRevisorHabilitacao1760141000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE profissional_habilitacao_revisoes
      ADD COLUMN primeiro_sem_conflito TINYINT(1) NULL,
      ADD COLUMN segundo_sem_conflito TINYINT(1) NULL`);
    await queryRunner.query(`CREATE TABLE profissional_habilitacao_impedimentos (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      profissional_id INT UNSIGNED NOT NULL,
      administrador_id INT UNSIGNED NOT NULL,
      criado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
      UNIQUE INDEX uq_habilitacao_impedimento_profissional_admin (profissional_id, administrador_id),
      INDEX idx_habilitacao_impedimento_admin (administrador_id, criado_em),
      CONSTRAINT fk_habilitacao_impedimento_profissional
        FOREIGN KEY (profissional_id) REFERENCES profissionais(id) ON DELETE CASCADE,
      CONSTRAINT fk_habilitacao_impedimento_admin
        FOREIGN KEY (administrador_id) REFERENCES usuarios(id) ON DELETE RESTRICT,
      PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);

    await dropCheckConstraint(queryRunner, 'admin_auditoria', 'chk_admin_auditoria_acao');
    await queryRunner.query(`ALTER TABLE admin_auditoria
      ADD CONSTRAINT chk_admin_auditoria_acao CHECK (acao IN (
        'usuario_ativado', 'usuario_desativado', 'administrador_criado',
        'categoria_criada', 'categoria_atualizada', 'documento_analisado',
        'denuncia_moderada', 'avaliacao_moderada', 'habilitacao_analisada',
        'habilitacao_revisao_solicitada', 'habilitacao_voto_registrado',
        'habilitacao_decisao_dupla', 'habilitacao_revisor_impedido'))`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const impedimentos = await queryRunner.query(
      'SELECT COUNT(*) AS total FROM profissional_habilitacao_impedimentos',
    ) as Array<{ total: number | string }>;
    const auditorias = await queryRunner.query(`SELECT COUNT(*) AS total FROM admin_auditoria
      WHERE acao = 'habilitacao_revisor_impedido'`) as Array<{ total: number | string }>;
    const declaracoes = await queryRunner.query(`SELECT COUNT(*) AS total FROM profissional_habilitacao_revisoes
      WHERE primeiro_sem_conflito IS NOT NULL OR segundo_sem_conflito IS NOT NULL`) as Array<{ total: number | string }>;
    if (Number(impedimentos[0]?.total) > 0 || Number(auditorias[0]?.total) > 0 || Number(declaracoes[0]?.total) > 0) {
      throw new Error('Rollback blocked: preserve reviewer conflict and attestation history.');
    }

    await dropCheckConstraint(queryRunner, 'admin_auditoria', 'chk_admin_auditoria_acao');
    await queryRunner.query(`ALTER TABLE admin_auditoria
      ADD CONSTRAINT chk_admin_auditoria_acao CHECK (acao IN (
        'usuario_ativado', 'usuario_desativado', 'administrador_criado',
        'categoria_criada', 'categoria_atualizada', 'documento_analisado',
        'denuncia_moderada', 'avaliacao_moderada', 'habilitacao_analisada',
        'habilitacao_revisao_solicitada', 'habilitacao_voto_registrado',
        'habilitacao_decisao_dupla'))`);
    await queryRunner.query('DROP TABLE profissional_habilitacao_impedimentos');
    await queryRunner.query(`ALTER TABLE profissional_habilitacao_revisoes
      DROP COLUMN primeiro_sem_conflito,
      DROP COLUMN segundo_sem_conflito`);
  }
}

async function dropCheckConstraint(
  queryRunner: QueryRunner,
  tableName: string,
  constraintName: string,
): Promise<void> {
  const rows = await queryRunner.query('SELECT VERSION() AS version') as Array<{ version: string }>;
  const operation = rows[0]?.version?.toLowerCase().includes('mariadb')
    ? 'DROP CONSTRAINT' : 'DROP CHECK';
  await queryRunner.query(`ALTER TABLE ${tableName} ${operation} ${constraintName}`);
}
