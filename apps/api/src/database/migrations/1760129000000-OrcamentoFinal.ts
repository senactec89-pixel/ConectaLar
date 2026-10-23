import { MigrationInterface, QueryRunner } from 'typeorm';

export class OrcamentoFinal1760129000000 implements MigrationInterface {
  name = 'OrcamentoFinal1760129000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE solicitacoes
      ADD preco_final DECIMAL(10,2) NULL AFTER preco_inicial`);
    await queryRunner.query(`CREATE TABLE solicitacao_orcamentos (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      solicitacao_id INT UNSIGNED NOT NULL,
      proposto_por_id INT UNSIGNED NOT NULL,
      valor DECIMAL(10,2) NOT NULL,
      descricao VARCHAR(600) NOT NULL,
      status VARCHAR(24) NOT NULL DEFAULT 'pendente',
      respondido_em TIMESTAMP(6) NULL,
      criado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
      atualizado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
      INDEX idx_orcamentos_solicitacao_criado (solicitacao_id, criado_em),
      INDEX idx_orcamentos_proponente (proposto_por_id),
      CONSTRAINT chk_orcamentos_valor CHECK (valor > 0),
      CONSTRAINT chk_orcamentos_status CHECK (
        status IN ('pendente', 'aceito', 'recusado', 'substituido')
      ),
      CONSTRAINT fk_orcamentos_solicitacao FOREIGN KEY (solicitacao_id)
        REFERENCES solicitacoes(id) ON DELETE CASCADE,
      CONSTRAINT fk_orcamentos_proponente FOREIGN KEY (proposto_por_id)
        REFERENCES usuarios(id),
      PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE solicitacao_orcamentos');
    await queryRunner.query(
      'ALTER TABLE solicitacoes DROP COLUMN preco_final',
    );
  }
}
