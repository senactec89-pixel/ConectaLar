import type { MigrationInterface, QueryRunner } from 'typeorm';

export class PrazosEPropostasPreAceite1760136000000 implements MigrationInterface {
  name = 'PrazosEPropostasPreAceite1760136000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    if (!(await queryRunner.hasColumn('solicitacoes', 'prazo_resposta_em'))) {
      await queryRunner.query('ALTER TABLE solicitacoes ADD COLUMN prazo_resposta_em DATETIME(3) NULL');
    }
    if (!(await queryRunner.hasColumn('solicitacoes', 'prazo_inatividade_em'))) {
      await queryRunner.query('ALTER TABLE solicitacoes ADD COLUMN prazo_inatividade_em DATETIME(3) NULL');
    }
    let table = await queryRunner.getTable('solicitacoes');
    if (!table?.indices.some((index) => index.name === 'idx_solicitacoes_prazo_resposta')) {
      await queryRunner.query('ALTER TABLE solicitacoes ADD INDEX idx_solicitacoes_prazo_resposta (status, prazo_resposta_em)');
    }
    table = await queryRunner.getTable('solicitacoes');
    if (!table?.indices.some((index) => index.name === 'idx_solicitacoes_prazo_inatividade')) {
      await queryRunner.query('ALTER TABLE solicitacoes ADD INDEX idx_solicitacoes_prazo_inatividade (status, prazo_inatividade_em)');
    }
    if (!(await queryRunner.hasTable('solicitacao_propostas'))) {
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
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const hasPropostas = await queryRunner.hasTable('solicitacao_propostas');
    if (hasPropostas) {
      const rows = await queryRunner.query(
        'SELECT COUNT(*) AS total FROM solicitacao_propostas',
      ) as Array<{ total: number | string }>;
      if (Number(rows[0]?.total) !== 0) {
        throw new Error('Rollback blocked: preserve request proposals.');
      }
    }
    const prazoColumns: string[] = [];
    for (const column of ['prazo_resposta_em', 'prazo_inatividade_em']) {
      if (await queryRunner.hasColumn('solicitacoes', column)) prazoColumns.push(column);
    }
    if (prazoColumns.length > 0) {
      const prazoRows = await queryRunner.query(
        `SELECT COUNT(*) AS total FROM solicitacoes WHERE ${prazoColumns.map((column) => `${column} IS NOT NULL`).join(' OR ')}`,
      ) as Array<{ total: number | string }>;
      if (Number(prazoRows[0]?.total) !== 0) {
        throw new Error('Rollback blocked: preserve request deadlines.');
      }
    }
    if (hasPropostas) await queryRunner.query('DROP TABLE solicitacao_propostas');
    const table = await queryRunner.getTable('solicitacoes');
    for (const index of ['idx_solicitacoes_prazo_resposta', 'idx_solicitacoes_prazo_inatividade']) {
      if (table?.indices.some((item) => item.name === index)) {
        await queryRunner.query(`ALTER TABLE solicitacoes DROP INDEX ${index}`);
      }
    }
    for (const column of prazoColumns) {
      await queryRunner.query(`ALTER TABLE solicitacoes DROP COLUMN ${column}`);
    }
  }
}
