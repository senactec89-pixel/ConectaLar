import { MigrationInterface, QueryRunner } from 'typeorm';

export class AvaliacaoFotos1760136000000 implements MigrationInterface {
  name = 'AvaliacaoFotos1760136000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE avaliacao_fotos (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        solicitacao_id INT UNSIGNED NOT NULL,
        enviado_por_id INT UNSIGNED NOT NULL,
        avaliacao_id INT UNSIGNED NULL,
        referencia_arquivo VARCHAR(240) NOT NULL,
        mime_type VARCHAR(40) NOT NULL,
        tamanho_bytes INT UNSIGNED NOT NULL,
        pronto TINYINT(1) NOT NULL DEFAULT 0,
        expira_em TIMESTAMP NULL,
        criado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        UNIQUE INDEX uq_avaliacao_fotos_referencia (referencia_arquivo),
        INDEX idx_avaliacao_fotos_expiracao (avaliacao_id, expira_em),
        INDEX idx_avaliacao_fotos_autor_pedido (enviado_por_id, solicitacao_id),
        CONSTRAINT chk_avaliacao_fotos_mime CHECK (mime_type = 'image/jpeg'),
        CONSTRAINT fk_avaliacao_fotos_solicitacao
          FOREIGN KEY (solicitacao_id) REFERENCES solicitacoes(id)
          ON DELETE RESTRICT,
        CONSTRAINT fk_avaliacao_fotos_autor
          FOREIGN KEY (enviado_por_id) REFERENCES usuarios(id)
          ON DELETE RESTRICT,
        CONSTRAINT fk_avaliacao_fotos_avaliacao
          FOREIGN KEY (avaliacao_id) REFERENCES avaliacoes(id)
          ON DELETE CASCADE,
        PRIMARY KEY (id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE avaliacao_fotos');
  }
}
