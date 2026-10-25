import type { MigrationInterface, QueryRunner } from 'typeorm';

export class ProfissionalTelefoneZapSign1760134000000 implements MigrationInterface {
  name = 'ProfissionalTelefoneZapSign1760134000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TABLE profissional_telefone_verificacoes (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      usuario_id INT UNSIGNED NOT NULL,
      telefone_vinculado VARCHAR(16) NOT NULL,
      referencia VARCHAR(40) NULL,
      referencia_externa VARCHAR(64) NOT NULL,
      chave_idempotencia VARCHAR(36) NULL,
      tentativa_id VARCHAR(36) NULL,
      chave_idempotencia_tentativa VARCHAR(36) NULL,
      tentativa_em_andamento BOOLEAN NOT NULL DEFAULT FALSE,
      consentimento_em DATETIME NOT NULL,
      versao_aviso VARCHAR(40) NOT NULL,
      estado VARCHAR(24) NOT NULL DEFAULT 'iniciando',
      tentativas_restantes TINYINT UNSIGNED NULL,
      expira_em DATETIME NULL,
      resolvida_em DATETIME NULL,
      criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE INDEX uq_telefone_verificacoes_referencia (referencia),
      UNIQUE INDEX uq_telefone_verificacoes_idempotencia (chave_idempotencia),
      UNIQUE INDEX uq_telefone_verificacoes_externo (referencia_externa),
      INDEX idx_telefone_verificacoes_usuario_criado (usuario_id, criado_em),
      CONSTRAINT chk_telefone_verificacoes_estado CHECK (estado IN (
        'iniciando', 'pendente', 'confirmada', 'revisao_necessaria', 'expirada', 'falha', 'invalidada')),
      CONSTRAINT fk_telefone_verificacoes_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const rows = await queryRunner.query(
      'SELECT COUNT(*) AS total FROM profissional_telefone_verificacoes',
    ) as Array<{ total: number | string }>;
    if (Number(rows[0]?.total) !== 0) {
      throw new Error('Rollback blocked: preserve phone verification records.');
    }
    await queryRunner.query('DROP TABLE profissional_telefone_verificacoes');
  }
}
