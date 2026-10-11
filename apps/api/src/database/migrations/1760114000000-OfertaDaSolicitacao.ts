import { MigrationInterface, QueryRunner } from 'typeorm';

export class OfertaDaSolicitacao1760114000000 implements MigrationInterface {
  name = 'OfertaDaSolicitacao1760114000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE solicitacoes
      ADD servico_id INT UNSIGNED NULL,
      ADD nome_servico VARCHAR(90) NULL,
      ADD INDEX idx_solicitacoes_servico (servico_id),
      ADD INDEX idx_solicitacoes_agenda (profissional_id, data_servico, horario_servico, status),
      ADD CONSTRAINT fk_solicitacoes_servico FOREIGN KEY (servico_id)
        REFERENCES profissional_servicos(id) ON DELETE SET NULL`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE solicitacoes
      DROP FOREIGN KEY fk_solicitacoes_servico,
      DROP INDEX idx_solicitacoes_servico,
      DROP INDEX idx_solicitacoes_agenda,
      DROP COLUMN servico_id,
      DROP COLUMN nome_servico`);
  }
}
