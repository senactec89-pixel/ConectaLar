import type { MigrationInterface, QueryRunner } from 'typeorm';

export class AdminMfaInvites1760132000000 implements MigrationInterface {
  name = 'AdminMfaInvites1760132000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE usuarios
      ADD COLUMN mfa_falhas SMALLINT UNSIGNED NOT NULL DEFAULT 0,
      ADD COLUMN mfa_bloqueado_ate DATETIME NULL`);
    await queryRunner.query(`ALTER TABLE email_outbox
      DROP CHECK chk_email_outbox_tipo,
      ADD CONSTRAINT chk_email_outbox_tipo
        CHECK (tipo IN ('verificacao_email', 'convite_admin'))`);
    await queryRunner.query(`CREATE TABLE admin_convites (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      usuario_id INT UNSIGNED NOT NULL,
      convidado_por_id INT UNSIGNED NOT NULL,
      token_hash CHAR(64) NOT NULL,
      expira_em DATETIME NOT NULL,
      aceito_em DATETIME NULL,
      cancelado_em DATETIME NULL,
      criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE INDEX uq_admin_convites_token_hash (token_hash),
      INDEX idx_admin_convites_usuario_pendente (usuario_id, aceito_em, cancelado_em),
      CONSTRAINT fk_admin_convites_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios(id) ON DELETE RESTRICT,
      CONSTRAINT fk_admin_convites_convidado_por FOREIGN KEY (convidado_por_id)
        REFERENCES usuarios(id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const rows = await queryRunner.query(
      `SELECT COUNT(*) AS total FROM email_outbox
       WHERE tipo = 'convite_admin' AND enviado_em IS NULL AND cancelado_em IS NULL`,
    ) as Array<{ total: number | string }>;
    const invites = await queryRunner.query(
      'SELECT COUNT(*) AS total FROM admin_convites',
    ) as Array<{ total: number | string }>;
    const sentInvites = await queryRunner.query(
      "SELECT COUNT(*) AS total FROM email_outbox WHERE tipo = 'convite_admin'",
    ) as Array<{ total: number | string }>;
    if (
      Number(rows[0]?.total) !== 0 || Number(invites[0]?.total) !== 0 ||
      Number(sentInvites[0]?.total) !== 0
    ) {
      throw new Error('Rollback blocked: administrator invitation records must be preserved.');
    }
    await queryRunner.query('DROP TABLE admin_convites');
    await queryRunner.query(`ALTER TABLE email_outbox
      DROP CHECK chk_email_outbox_tipo,
      ADD CONSTRAINT chk_email_outbox_tipo CHECK (tipo IN ('verificacao_email'))`);
    await queryRunner.query(`ALTER TABLE usuarios
      DROP COLUMN mfa_bloqueado_ate,
      DROP COLUMN mfa_falhas`);
  }
}
