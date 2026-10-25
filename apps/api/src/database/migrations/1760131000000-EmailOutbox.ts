import type { MigrationInterface, QueryRunner } from 'typeorm';

export class EmailOutbox1760131000000 implements MigrationInterface {
  name = 'EmailOutbox1760131000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TABLE email_outbox (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      usuario_id INT UNSIGNED NOT NULL,
      tipo VARCHAR(40) NOT NULL,
      payload_criptografado VARCHAR(255) NOT NULL,
      tentativas SMALLINT UNSIGNED NOT NULL DEFAULT 0,
      proxima_tentativa_em DATETIME NOT NULL,
      processando_em DATETIME NULL,
      expira_em DATETIME NOT NULL,
      enviado_em DATETIME NULL,
      cancelado_em DATETIME NULL,
      ultimo_erro VARCHAR(64) NULL,
      criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      INDEX idx_email_outbox_pendente (enviado_em, cancelado_em, proxima_tentativa_em),
      INDEX idx_email_outbox_usuario (usuario_id, criado_em),
      CONSTRAINT chk_email_outbox_tipo CHECK (tipo IN ('verificacao_email')),
      CONSTRAINT fk_email_outbox_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios(id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const rows = await queryRunner.query(
      'SELECT COUNT(*) AS total FROM email_outbox WHERE enviado_em IS NULL AND cancelado_em IS NULL',
    ) as Array<{ total: number | string }>;
    if (Number(rows[0]?.total) !== 0) {
      throw new Error('Rollback blocked: pending e-mail deliveries must be preserved.');
    }
    await queryRunner.query('DROP TABLE email_outbox');
  }
}
