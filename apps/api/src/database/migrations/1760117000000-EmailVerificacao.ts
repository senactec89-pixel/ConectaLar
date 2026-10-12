import { MigrationInterface, QueryRunner } from 'typeorm';

export class EmailVerificacao1760117000000 implements MigrationInterface {
  name = 'EmailVerificacao1760117000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE usuarios
        ADD email_verificado BOOLEAN NOT NULL DEFAULT FALSE AFTER email
    `);
    await queryRunner.query(`
      UPDATE usuarios SET email_verificado = TRUE
    `);
    await queryRunner.query(`
      CREATE TABLE usuario_email_verificacoes (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        usuario_id INT UNSIGNED NOT NULL,
        codigo_hash VARCHAR(64) NOT NULL,
        expira_em TIMESTAMP(6) NOT NULL,
        usado_em TIMESTAMP(6) NULL,
        criado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        INDEX idx_usuario_email_verificacoes_usuario_criado (usuario_id, criado_em),
        CONSTRAINT fk_usuario_email_verificacoes_usuario
          FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
          ON DELETE RESTRICT,
        PRIMARY KEY (id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE usuario_email_verificacoes');
    await queryRunner.query('ALTER TABLE usuarios DROP COLUMN email_verificado');
  }
}
