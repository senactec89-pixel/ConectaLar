import type { MigrationInterface, QueryRunner } from 'typeorm';

export class ExpiraPedidosSemResposta1760143000000 implements MigrationInterface {
  name = 'ExpiraPedidosSemResposta1760143000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await dropCheck(queryRunner, 'chk_solicitacoes_status');
    await queryRunner.query(`ALTER TABLE solicitacoes
      ADD CONSTRAINT chk_solicitacoes_status CHECK (status IN (
        'aguardando_resposta', 'expirada', 'aceita_agendada', 'recusada',
        'cancelada', 'conclusao_pendente', 'conclusao_contestada',
        'nao_comparecimento_informado', 'conclusao_confirmada'
      ))`);

    await queryRunner.query(`UPDATE solicitacoes pedido
      SET prazo_resposta_em = DATE_ADD(pedido.criado_em, INTERVAL 48 HOUR)
      WHERE pedido.status='aguardando_resposta'
        AND pedido.prazo_resposta_em IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM solicitacao_eventos evento
          WHERE evento.solicitacao_id=pedido.id AND evento.tipo='negociacao_iniciada'
        )
        AND NOT EXISTS (
          SELECT 1 FROM mensagens_atendimento mensagem
          INNER JOIN profissionais profissional ON profissional.usuario_id=mensagem.autor_id
          WHERE mensagem.solicitacao_id=pedido.id AND profissional.id=pedido.profissional_id
        )`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const rows = await queryRunner.query(`SELECT COUNT(*) AS total
      FROM solicitacoes WHERE status='expirada'`) as Array<{ total: number | string }>;
    if (Number(rows[0]?.total ?? 0) > 0) {
      throw new Error('Rollback blocked: preserve expired request history.');
    }

    await dropCheck(queryRunner, 'chk_solicitacoes_status');
    await queryRunner.query(`ALTER TABLE solicitacoes
      ADD CONSTRAINT chk_solicitacoes_status CHECK (status IN (
        'aguardando_resposta', 'aceita_agendada', 'recusada', 'cancelada',
        'conclusao_pendente', 'conclusao_contestada',
        'nao_comparecimento_informado', 'conclusao_confirmada'
      ))`);
  }
}

async function dropCheck(queryRunner: QueryRunner, name: string): Promise<void> {
  const rows = await queryRunner.query('SELECT VERSION() AS version') as Array<{ version: string }>;
  const operation = rows[0]?.version?.toLowerCase().includes('mariadb') ? 'DROP CONSTRAINT' : 'DROP CHECK';
  await queryRunner.query(`ALTER TABLE solicitacoes ${operation} ${name}`);
}
