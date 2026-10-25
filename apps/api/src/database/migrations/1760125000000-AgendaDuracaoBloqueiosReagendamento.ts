import { MigrationInterface, QueryRunner } from 'typeorm';

export class AgendaDuracaoBloqueiosReagendamento1760125000000
  implements MigrationInterface
{
  name = 'AgendaDuracaoBloqueiosReagendamento1760125000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    for (const tabela of ['profissional_servicos', 'solicitacoes']) {
      if (!(await queryRunner.hasColumn(tabela, 'duracao_minutos'))) {
        throw new Error(`Migration prerequisite missing: ${tabela}.duracao_minutos.`);
      }
      if (!(await queryRunner.hasColumn(tabela, 'intervalo_minutos'))) {
        await queryRunner.query(`ALTER TABLE ${tabela}
          ADD intervalo_minutos SMALLINT UNSIGNED NOT NULL DEFAULT 30`);
      }
    }
    await queryRunner.query(`CREATE TABLE profissional_bloqueios (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      profissional_id INT UNSIGNED NOT NULL,
      data_inicio DATE NOT NULL,
      data_fim DATE NOT NULL,
      motivo VARCHAR(160) NOT NULL,
      criado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
      INDEX idx_profissional_bloqueios_data (profissional_id, data_inicio, data_fim),
      CONSTRAINT fk_profissional_bloqueios_profissional FOREIGN KEY (profissional_id)
        REFERENCES profissionais(id) ON DELETE CASCADE,
      CONSTRAINT chk_profissional_bloqueios_datas CHECK (data_inicio <= data_fim),
      PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
    await queryRunner.query(`CREATE TABLE solicitacao_reagendamentos (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      solicitacao_id INT UNSIGNED NOT NULL,
      data_proposta DATE NOT NULL,
      horario_proposto VARCHAR(5) NOT NULL,
      motivo VARCHAR(400) NOT NULL,
      status VARCHAR(16) NOT NULL DEFAULT 'pendente',
      respondido_em TIMESTAMP(6) NULL,
      criado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
      atualizado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
      INDEX idx_reagendamentos_solicitacao (solicitacao_id, criado_em),
      CONSTRAINT fk_reagendamentos_solicitacao FOREIGN KEY (solicitacao_id)
        REFERENCES solicitacoes(id) ON DELETE CASCADE,
      CONSTRAINT chk_reagendamentos_status CHECK (status IN ('pendente','aceito','recusado','cancelado')),
      PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE solicitacao_reagendamentos');
    await queryRunner.query('DROP TABLE profissional_bloqueios');
    if (await queryRunner.hasColumn('solicitacoes', 'intervalo_minutos')) {
      await queryRunner.query('ALTER TABLE solicitacoes DROP COLUMN intervalo_minutos');
    }
    if (await queryRunner.hasColumn('profissional_servicos', 'intervalo_minutos')) {
      await queryRunner.query('ALTER TABLE profissional_servicos DROP COLUMN intervalo_minutos');
    }
  }
}
