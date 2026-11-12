import type { MigrationInterface, QueryRunner } from 'typeorm';

export class OpcoesEPropostasAtendimento1760141000000 implements MigrationInterface {
  name = 'OpcoesEPropostasAtendimento1760141000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TABLE servico_catalogo_opcoes (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      servico_catalogo_id INT UNSIGNED NOT NULL,
      nome VARCHAR(120) NOT NULL,
      ativo TINYINT NOT NULL DEFAULT 0,
      criado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
      atualizado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
      PRIMARY KEY (id),
      UNIQUE INDEX uq_catalogo_opcao_nome (servico_catalogo_id, nome),
      CONSTRAINT fk_catalogo_opcao_servico FOREIGN KEY (servico_catalogo_id)
        REFERENCES servicos_catalogo(id) ON DELETE RESTRICT,
      CONSTRAINT chk_catalogo_opcao_ativo CHECK (ativo IN (0, 1))
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);

    await queryRunner.query(`CREATE TABLE solicitacao_opcoes (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      solicitacao_id INT UNSIGNED NOT NULL,
      opcao_id INT UNSIGNED NOT NULL,
      nome_snapshot VARCHAR(120) NOT NULL,
      PRIMARY KEY (id),
      UNIQUE INDEX uq_solicitacao_opcao (solicitacao_id, opcao_id),
      CONSTRAINT fk_solicitacao_opcao_solicitacao FOREIGN KEY (solicitacao_id)
        REFERENCES solicitacoes(id) ON DELETE CASCADE,
      CONSTRAINT fk_solicitacao_opcao_catalogo FOREIGN KEY (opcao_id)
        REFERENCES servico_catalogo_opcoes(id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);

    await queryRunner.query(`CREATE TABLE solicitacao_propostas_atendimento (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      solicitacao_id INT UNSIGNED NOT NULL,
      versao INT UNSIGNED NOT NULL,
      proposto_por_id INT UNSIGNED NOT NULL,
      valor DECIMAL(10,2) NOT NULL,
      data_servico DATE NOT NULL,
      horario_servico VARCHAR(5) NOT NULL,
      duracao_minutos SMALLINT UNSIGNED NOT NULL,
      status VARCHAR(24) NOT NULL DEFAULT 'pendente',
      respondido_por_id INT UNSIGNED NULL,
      respondido_em TIMESTAMP(6) NULL,
      criado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
      PRIMARY KEY (id),
      UNIQUE INDEX uq_proposta_atendimento_versao (solicitacao_id, versao),
      INDEX idx_proposta_atendimento_status (solicitacao_id, status),
      CONSTRAINT fk_proposta_atendimento_solicitacao FOREIGN KEY (solicitacao_id)
        REFERENCES solicitacoes(id) ON DELETE CASCADE,
      CONSTRAINT fk_proposta_atendimento_proponente FOREIGN KEY (proposto_por_id)
        REFERENCES usuarios(id) ON DELETE RESTRICT,
      CONSTRAINT fk_proposta_atendimento_resposta FOREIGN KEY (respondido_por_id)
        REFERENCES usuarios(id) ON DELETE RESTRICT,
      CONSTRAINT chk_proposta_atendimento_versao CHECK (versao > 0),
      CONSTRAINT chk_proposta_atendimento_valor CHECK (valor >= 0),
      CONSTRAINT chk_proposta_atendimento_duracao CHECK (duracao_minutos BETWEEN 1 AND 1440),
      CONSTRAINT chk_proposta_atendimento_status CHECK (status IN ('pendente', 'aceita', 'recusada', 'substituida')),
      CONSTRAINT chk_proposta_atendimento_resposta CHECK (
        (status IN ('aceita', 'recusada') AND respondido_por_id IS NOT NULL AND respondido_em IS NOT NULL)
        OR (status IN ('pendente', 'substituida') AND respondido_por_id IS NULL AND respondido_em IS NULL)
      )
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);

    await queryRunner.query(`CREATE TABLE proposta_atendimento_opcoes (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      proposta_id INT UNSIGNED NOT NULL,
      opcao_id INT UNSIGNED NOT NULL,
      nome_snapshot VARCHAR(120) NOT NULL,
      PRIMARY KEY (id),
      UNIQUE INDEX uq_proposta_atendimento_opcao (proposta_id, opcao_id),
      CONSTRAINT fk_proposta_opcao_proposta FOREIGN KEY (proposta_id)
        REFERENCES solicitacao_propostas_atendimento(id) ON DELETE CASCADE,
      CONSTRAINT fk_proposta_opcao_catalogo FOREIGN KEY (opcao_id)
        REFERENCES servico_catalogo_opcoes(id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    for (const table of ['proposta_atendimento_opcoes', 'solicitacao_propostas_atendimento', 'solicitacao_opcoes', 'servico_catalogo_opcoes']) {
      const rows = await queryRunner.query(`SELECT COUNT(*) AS total FROM ${table}`) as Array<{ total: number | string }>;
      if (Number(rows[0]?.total) !== 0) {
        throw new Error('Rollback blocked: preserve service options and proposal history.');
      }
    }
    await queryRunner.query('DROP TABLE proposta_atendimento_opcoes');
    await queryRunner.query('DROP TABLE solicitacao_propostas_atendimento');
    await queryRunner.query('DROP TABLE solicitacao_opcoes');
    await queryRunner.query('DROP TABLE servico_catalogo_opcoes');
  }
}
