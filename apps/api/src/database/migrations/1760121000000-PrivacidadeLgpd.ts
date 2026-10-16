import type { MigrationInterface, QueryRunner } from 'typeorm';

export class PrivacidadeLgpd1760121000000 implements MigrationInterface {
  name = 'PrivacidadeLgpd1760121000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE privacidade_solicitacoes (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        usuario_id INT UNSIGNED NOT NULL,
        tipo VARCHAR(24) NOT NULL,
        status VARCHAR(24) NOT NULL,
        concluida_em TIMESTAMP NULL,
        criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        INDEX idx_privacidade_solicitacoes_usuario_criado (usuario_id, criado_em),
        CONSTRAINT fk_privacidade_solicitacoes_usuario
          FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
          ON DELETE RESTRICT,
        CONSTRAINT chk_privacidade_solicitacoes_tipo
          CHECK (tipo IN ('exportacao', 'exclusao')),
        CONSTRAINT chk_privacidade_solicitacoes_status
          CHECK (status IN ('processando', 'concluida', 'falhou'))
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE privacidade_solicitacoes');
  }
}
