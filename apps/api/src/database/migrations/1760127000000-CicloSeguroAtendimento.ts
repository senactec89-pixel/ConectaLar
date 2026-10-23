import { MigrationInterface, QueryRunner } from 'typeorm';

export class CicloSeguroAtendimento1760127000000 implements MigrationInterface {
  name = 'CicloSeguroAtendimento1760127000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE solicitacoes
      ADD conclusao_contestacao_motivo VARCHAR(600) NULL AFTER cancelamento_motivo,
      ADD nao_comparecimento_motivo VARCHAR(600) NULL AFTER conclusao_contestacao_motivo,
      ADD nao_comparecimento_por_id INT UNSIGNED NULL AFTER nao_comparecimento_motivo`);
    await queryRunner.query(`CREATE TABLE solicitacao_eventos (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      solicitacao_id INT UNSIGNED NOT NULL,
      ator_id INT UNSIGNED NULL,
      tipo VARCHAR(48) NOT NULL,
      status_anterior VARCHAR(32) NULL,
      status_novo VARCHAR(32) NOT NULL,
      motivo VARCHAR(600) NULL,
      criado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
      INDEX idx_solicitacao_eventos_solicitacao (solicitacao_id, criado_em),
      INDEX idx_solicitacao_eventos_ator (ator_id),
      CONSTRAINT fk_solicitacao_eventos_solicitacao FOREIGN KEY (solicitacao_id)
        REFERENCES solicitacoes(id) ON DELETE CASCADE,
      CONSTRAINT fk_solicitacao_eventos_ator FOREIGN KEY (ator_id)
        REFERENCES usuarios(id) ON DELETE SET NULL,
      PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
    await queryRunner.query(`INSERT INTO solicitacao_eventos
      (solicitacao_id, ator_id, tipo, status_anterior, status_novo, motivo, criado_em)
      SELECT id, NULL, 'estado_importado', NULL, status, NULL, criado_em
      FROM solicitacoes`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE solicitacao_eventos');
    await queryRunner.query(`ALTER TABLE solicitacoes
      DROP COLUMN nao_comparecimento_por_id,
      DROP COLUMN nao_comparecimento_motivo,
      DROP COLUMN conclusao_contestacao_motivo`);
  }
}
