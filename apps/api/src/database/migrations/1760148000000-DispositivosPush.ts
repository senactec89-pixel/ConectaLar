import type { MigrationInterface, QueryRunner } from 'typeorm';

export class DispositivosPush1760148000000 implements MigrationInterface {
  name = 'DispositivosPush1760148000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE dispositivos_push (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        usuario_id INT UNSIGNED NOT NULL,
        token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
        token TEXT NOT NULL,
        plataforma VARCHAR(12) NOT NULL,
        criado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        atualizado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
        PRIMARY KEY (id),
        UNIQUE INDEX uq_dispositivos_push_token_hash (token_hash),
        INDEX idx_dispositivos_push_usuario (usuario_id),
        CONSTRAINT fk_dispositivos_push_usuario
          FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
          ON DELETE CASCADE,
        CONSTRAINT chk_dispositivos_push_plataforma
          CHECK (plataforma IN ('android', 'ios', 'web'))
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE dispositivos_push');
  }
}
