import type { MigrationInterface, QueryRunner } from 'typeorm';

export class ExpiraPropostasAtendimento1760142000000 implements MigrationInterface {
  name = 'ExpiraPropostasAtendimento1760142000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE solicitacao_propostas_atendimento
      ADD COLUMN expira_em TIMESTAMP(6) NULL,
      ADD INDEX idx_proposta_atendimento_expira (status, expira_em)`);

    await dropCheck(queryRunner, 'chk_proposta_atendimento_status');
    await queryRunner.query(`ALTER TABLE solicitacao_propostas_atendimento
      ADD CONSTRAINT chk_proposta_atendimento_status CHECK (status IN ('pendente', 'aceita', 'recusada', 'substituida', 'expirada'))`);

    await dropCheck(queryRunner, 'chk_proposta_atendimento_resposta');
    await queryRunner.query(`ALTER TABLE solicitacao_propostas_atendimento
      ADD CONSTRAINT chk_proposta_atendimento_resposta CHECK (
        (status IN ('aceita', 'recusada') AND respondido_por_id IS NOT NULL AND respondido_em IS NOT NULL)
        OR (status IN ('pendente', 'substituida', 'expirada') AND respondido_por_id IS NULL AND respondido_em IS NULL)
      )`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const rows = await queryRunner.query(`SELECT COUNT(*) AS total
      FROM solicitacao_propostas_atendimento WHERE status='expirada'`) as Array<{ total: number | string }>;
    if (Number(rows[0]?.total ?? 0) > 0) {
      throw new Error('Rollback blocked: preserve expired proposal history.');
    }

    await dropCheck(queryRunner, 'chk_proposta_atendimento_resposta');
    await queryRunner.query(`ALTER TABLE solicitacao_propostas_atendimento
      ADD CONSTRAINT chk_proposta_atendimento_resposta CHECK (
        (status IN ('aceita', 'recusada') AND respondido_por_id IS NOT NULL AND respondido_em IS NOT NULL)
        OR (status IN ('pendente', 'substituida') AND respondido_por_id IS NULL AND respondido_em IS NULL)
      )`);
    await dropCheck(queryRunner, 'chk_proposta_atendimento_status');
    await queryRunner.query(`ALTER TABLE solicitacao_propostas_atendimento
      ADD CONSTRAINT chk_proposta_atendimento_status CHECK (status IN ('pendente', 'aceita', 'recusada', 'substituida')),
      DROP INDEX idx_proposta_atendimento_expira,
      DROP COLUMN expira_em`);
  }
}

async function dropCheck(queryRunner: QueryRunner, name: string): Promise<void> {
  const rows = await queryRunner.query('SELECT VERSION() AS version') as Array<{ version: string }>;
  const operation = rows[0]?.version?.toLowerCase().includes('mariadb') ? 'DROP CONSTRAINT' : 'DROP CHECK';
  await queryRunner.query(`ALTER TABLE solicitacao_propostas_atendimento ${operation} ${name}`);
}
