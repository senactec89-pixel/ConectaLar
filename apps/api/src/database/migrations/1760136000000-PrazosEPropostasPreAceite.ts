import type { MigrationInterface, QueryRunner } from 'typeorm';

export class PrazosEPropostasPreAceite1760136000000 implements MigrationInterface {
  name = 'PrazosEPropostasPreAceite1760136000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE solicitacoes
      ADD COLUMN prazo_resposta_em DATETIME(3) NULL,
      ADD COLUMN prazo_inatividade_em DATETIME(3) NULL,
      ADD INDEX idx_solicitacoes_prazo_resposta (status, prazo_resposta_em),
      ADD INDEX idx_solicitacoes_prazo_inatividade (status, prazo_inatividade_em)`);
    await queryRunner.query(`CREATE TABLE solicitacao_propostas (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      solicitacao_id INT UNSIGNED NOT NULL,
      proposto_por_id INT UNSIGNED NOT NULL,
      data_proposta DATE NULL,
      horario_proposto VARCHAR(5) NULL,
      escopo_proposto VARCHAR(600) NULL,
      status VARCHAR(16) NOT NULL,
      vence_em DATETIME(3) NOT NULL,
      respondido_em DATETIME(3) NULL,
      criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      INDEX idx_solicitacao_propostas_pedido (solicitacao_id, criado_em),
      INDEX idx_solicitacao_propostas_vencimento (status, vence_em),
      CONSTRAINT chk_solicitacao_propostas_status CHECK (status IN (
        'pendente', 'aceita', 'recusada', 'expirada', 'substituida')),
      CONSTRAINT fk_solicitacao_propostas_pedido FOREIGN KEY (solicitacao_id)
        REFERENCES solicitacoes(id) ON DELETE CASCADE,
      CONSTRAINT fk_solicitacao_propostas_usuario FOREIGN KEY (proposto_por_id)
        REFERENCES usuarios(id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const rows = await queryRunner.query(
      'SELECT COUNT(*) AS total FROM solicitacao_propostas',
    ) as Array<{ total: number | string }>;
    if (Number(rows[0]?.total) !== 0) {
      throw new Error('Rollback blocked: preserve request proposals.');
    }
    const prazoRows = await queryRunner.query(
      'SELECT COUNT(*) AS total FROM solicitacoes WHERE prazo_resposta_em IS NOT NULL OR prazo_inatividade_em IS NOT NULL',
    ) as Array<{ total: number | string }>;
    if (Number(prazoRows[0]?.total) !== 0) {
      throw new Error('Rollback blocked: preserve request deadlines.');
    }
    await queryRunner.query('DROP TABLE solicitacao_propostas');
    await queryRunner.query(`ALTER TABLE solicitacoes
      DROP INDEX idx_solicitacoes_prazo_resposta,
      DROP INDEX idx_solicitacoes_prazo_inatividade,
      DROP COLUMN prazo_resposta_em,
      DROP COLUMN prazo_inatividade_em`);
  }
}
