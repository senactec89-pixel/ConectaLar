import { MigrationInterface, QueryRunner } from 'typeorm';

export class ContrapropostaReagendamento1760128000000
  implements MigrationInterface
{
  name = 'ContrapropostaReagendamento1760128000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE solicitacao_reagendamentos
      ADD proposto_por_id INT UNSIGNED NULL AFTER solicitacao_id,
      ADD INDEX idx_reagendamentos_proponente (proposto_por_id)`);
    await queryRunner.query(`UPDATE solicitacao_reagendamentos reagendamento
      INNER JOIN solicitacoes solicitacao ON solicitacao.id = reagendamento.solicitacao_id
      INNER JOIN profissionais profissional ON profissional.id = solicitacao.profissional_id
      SET reagendamento.proposto_por_id = profissional.usuario_id
      WHERE reagendamento.proposto_por_id IS NULL`);
    await queryRunner.query(`ALTER TABLE solicitacao_reagendamentos
      ADD CONSTRAINT fk_reagendamentos_proponente FOREIGN KEY (proposto_por_id)
        REFERENCES usuarios(id) ON DELETE SET NULL`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE solicitacao_reagendamentos
      DROP FOREIGN KEY fk_reagendamentos_proponente,
      DROP INDEX idx_reagendamentos_proponente,
      DROP COLUMN proposto_por_id`);
  }
}
