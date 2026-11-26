import type { MigrationInterface, QueryRunner } from 'typeorm';

export class DuplaRevisaoHabilitacao1760140000000 implements MigrationInterface {
  name = 'DuplaRevisaoHabilitacao1760140000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TABLE profissional_habilitacao_revisoes (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      profissional_id INT UNSIGNED NOT NULL,
      estado_inicial VARCHAR(24) NOT NULL,
      assinatura_dossie CHAR(64) NOT NULL,
      acao_primeiro_voto VARCHAR(32) NOT NULL,
      motivo_primeiro_voto VARCHAR(32) NOT NULL,
      primeiro_revisor_id INT UNSIGNED NOT NULL,
      primeiro_voto_em DATETIME(3) NOT NULL,
      acao_segundo_voto VARCHAR(32) NULL,
      motivo_segundo_voto VARCHAR(32) NULL,
      segundo_revisor_id INT UNSIGNED NULL,
      segundo_voto_em DATETIME(3) NULL,
      estado VARCHAR(32) NOT NULL DEFAULT 'aguardando_segundo_revisor',
      resolvida_em DATETIME(3) NULL,
      criado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
      INDEX idx_habilitacao_revisao_profissional_estado (profissional_id, estado, id),
      INDEX idx_habilitacao_revisao_estado_criado (estado, criado_em),
      CONSTRAINT chk_habilitacao_revisao_estado_inicial
        CHECK (estado_inicial IN ('pendente', 'em_analise', 'suspenso')),
      CONSTRAINT chk_habilitacao_revisao_primeira_acao
        CHECK (acao_primeiro_voto IN ('iniciar_analise', 'reabrir')),
      CONSTRAINT chk_habilitacao_revisao_segunda_acao
        CHECK (acao_segundo_voto IS NULL OR acao_segundo_voto IN ('iniciar_analise', 'reabrir')),
      CONSTRAINT chk_habilitacao_revisao_primeiro_motivo
        CHECK (motivo_primeiro_voto IN ('revisao_cadastral', 'suspeita_fraude', 'solicitacao_titular')),
      CONSTRAINT chk_habilitacao_revisao_segundo_motivo
        CHECK (motivo_segundo_voto IS NULL OR motivo_segundo_voto IN ('revisao_cadastral', 'suspeita_fraude', 'solicitacao_titular')),
      CONSTRAINT chk_habilitacao_revisao_status
        CHECK (estado IN ('aguardando_segundo_revisor', 'concluida', 'divergente', 'cancelada')),
      CONSTRAINT chk_habilitacao_revisores_distintos
        CHECK (segundo_revisor_id IS NULL OR segundo_revisor_id <> primeiro_revisor_id),
      CONSTRAINT fk_habilitacao_revisao_profissional
        FOREIGN KEY (profissional_id) REFERENCES profissionais(id) ON DELETE CASCADE,
      CONSTRAINT fk_habilitacao_revisao_primeiro_revisor
        FOREIGN KEY (primeiro_revisor_id) REFERENCES usuarios(id) ON DELETE RESTRICT,
      CONSTRAINT fk_habilitacao_revisao_segundo_revisor
        FOREIGN KEY (segundo_revisor_id) REFERENCES usuarios(id) ON DELETE RESTRICT,
      PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);

    await dropCheckConstraint(queryRunner, 'admin_auditoria', 'chk_admin_auditoria_acao');
    await queryRunner.query(`ALTER TABLE admin_auditoria
      ADD CONSTRAINT chk_admin_auditoria_acao CHECK (acao IN (
        'usuario_ativado', 'usuario_desativado', 'administrador_criado',
        'categoria_criada', 'categoria_atualizada', 'documento_analisado',
        'denuncia_moderada', 'avaliacao_moderada', 'habilitacao_analisada',
        'habilitacao_revisao_solicitada', 'habilitacao_voto_registrado',
        'habilitacao_decisao_dupla'))`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const revisoes = await queryRunner.query(
      'SELECT COUNT(*) AS total FROM profissional_habilitacao_revisoes',
    ) as Array<{ total: number | string }>;
    const auditorias = await queryRunner.query(`SELECT COUNT(*) AS total FROM admin_auditoria
      WHERE acao IN ('habilitacao_voto_registrado', 'habilitacao_decisao_dupla')`) as Array<{ total: number | string }>;
    if (Number(revisoes[0]?.total) > 0 || Number(auditorias[0]?.total) > 0) {
      throw new Error('Rollback blocked: preserve the administrative double-review history.');
    }

    await dropCheckConstraint(queryRunner, 'admin_auditoria', 'chk_admin_auditoria_acao');
    await queryRunner.query(`ALTER TABLE admin_auditoria
      ADD CONSTRAINT chk_admin_auditoria_acao CHECK (acao IN (
        'usuario_ativado', 'usuario_desativado', 'administrador_criado',
        'categoria_criada', 'categoria_atualizada', 'documento_analisado',
        'denuncia_moderada', 'avaliacao_moderada', 'habilitacao_analisada',
        'habilitacao_revisao_solicitada'))`);
    await queryRunner.query('DROP TABLE profissional_habilitacao_revisoes');
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
