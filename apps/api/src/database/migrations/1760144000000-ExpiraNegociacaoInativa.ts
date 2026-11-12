import type { MigrationInterface, QueryRunner } from 'typeorm';

export class ExpiraNegociacaoInativa1760144000000 implements MigrationInterface {
  name = 'ExpiraNegociacaoInativa1760144000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    const rows = await queryRunner.query('SELECT CURRENT_TIMESTAMP(6) AS agora') as Array<{ agora: Date }>;
    const agora = rows[0]?.agora ?? new Date();
    await queryRunner.query(`UPDATE solicitacoes pedido
      SET prazo_inatividade_em = DATE_ADD(?, INTERVAL 96 HOUR)
      WHERE pedido.status='aguardando_resposta'
        AND pedido.prazo_inatividade_em IS NULL
        AND (
          EXISTS (SELECT 1 FROM solicitacao_eventos evento
            WHERE evento.solicitacao_id=pedido.id AND evento.tipo='negociacao_iniciada')
          OR EXISTS (SELECT 1 FROM mensagens_atendimento mensagem
            INNER JOIN profissionais profissional ON profissional.usuario_id=mensagem.autor_id
            WHERE mensagem.solicitacao_id=pedido.id AND profissional.id=pedido.profissional_id)
        )`, [agora]);

    await dropCheck(queryRunner, 'chk_solicitacoes_status');
    await queryRunner.query(`ALTER TABLE solicitacoes
      ADD CONSTRAINT chk_solicitacoes_status CHECK (status IN (
        'aguardando_resposta', 'expirada', 'negociacao_expirada',
        'aceita_agendada', 'recusada', 'cancelada', 'conclusao_pendente',
        'conclusao_contestada', 'nao_comparecimento_informado',
        'conclusao_confirmada'
      ))`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const rows = await queryRunner.query(`SELECT COUNT(*) AS total
      FROM solicitacoes WHERE status='negociacao_expirada'`) as Array<{ total: number | string }>;
    if (Number(rows[0]?.total ?? 0) > 0) {
      throw new Error('Rollback blocked: preserve expired negotiation history.');
    }

    await dropCheck(queryRunner, 'chk_solicitacoes_status');
    await queryRunner.query(`ALTER TABLE solicitacoes
      ADD CONSTRAINT chk_solicitacoes_status CHECK (status IN (
        'aguardando_resposta', 'expirada', 'aceita_agendada', 'recusada',
        'cancelada', 'conclusao_pendente', 'conclusao_contestada',
        'nao_comparecimento_informado', 'conclusao_confirmada'
      ))`);
  }
}

async function dropCheck(queryRunner: QueryRunner, name: string): Promise<void> {
  const rows = await queryRunner.query('SELECT VERSION() AS version') as Array<{ version: string }>;
  const operation = rows[0]?.version?.toLowerCase().includes('mariadb') ? 'DROP CONSTRAINT' : 'DROP CHECK';
  await queryRunner.query(`ALTER TABLE solicitacoes ${operation} ${name}`);
}
