import { MigrationInterface, QueryRunner } from 'typeorm';

export class EnderecoAtendimentoEAuditoriaAmpliada1760113000000
  implements MigrationInterface
{
  name = 'EnderecoAtendimentoEAuditoriaAmpliada1760113000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    // MariaDB commits DDL even when a later statement in this migration fails.
    // Check each object so a retry can finish a partially-applied migration.
    let solicitacoes = await tableOrFail(queryRunner, 'solicitacoes');
    if (!solicitacoes.columns.some((column) => column.name === 'endereco_id')) {
      await queryRunner.query(`
        ALTER TABLE solicitacoes
          ADD endereco_id INT UNSIGNED NULL AFTER categoria_id
      `);
      solicitacoes = await tableOrFail(queryRunner, 'solicitacoes');
    }
    if (!solicitacoes.indices.some((index) => index.name === 'idx_solicitacoes_endereco')) {
      await queryRunner.query(`
        ALTER TABLE solicitacoes
          ADD INDEX idx_solicitacoes_endereco (endereco_id)
      `);
      solicitacoes = await tableOrFail(queryRunner, 'solicitacoes');
    }
    if (!solicitacoes.foreignKeys.some((key) => key.name === 'fk_solicitacoes_endereco')) {
      await queryRunner.query(`
        ALTER TABLE solicitacoes
          ADD CONSTRAINT fk_solicitacoes_endereco
            FOREIGN KEY (endereco_id) REFERENCES cliente_enderecos(id)
            ON DELETE RESTRICT
      `);
    }

    await dropCheckConstraint(queryRunner, 'admin_auditoria', 'chk_admin_auditoria_acao');

    await queryRunner.query(`
      ALTER TABLE admin_auditoria
        ADD CONSTRAINT chk_admin_auditoria_acao
          CHECK (
            acao IN (
              'usuario_ativado',
              'usuario_desativado',
              'administrador_criado',
              'categoria_criada',
              'categoria_atualizada',
              'documento_analisado',
              'denuncia_moderada',
              'avaliacao_moderada'
            )
          )
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await dropCheckConstraint(queryRunner, 'admin_auditoria', 'chk_admin_auditoria_acao');

    await queryRunner.query(`
      ALTER TABLE admin_auditoria
        ADD CONSTRAINT chk_admin_auditoria_acao
          CHECK (
            acao IN (
              'usuario_ativado',
              'usuario_desativado',
              'administrador_criado'
            )
          )
    `);

    await queryRunner.query(`
      ALTER TABLE solicitacoes
        DROP FOREIGN KEY fk_solicitacoes_endereco
    `);
    await queryRunner.query(`
      ALTER TABLE solicitacoes
        DROP INDEX idx_solicitacoes_endereco,
        DROP COLUMN endereco_id
    `);
  }
}

async function tableOrFail(queryRunner: QueryRunner, tableName: string) {
  const table = await queryRunner.getTable(tableName);
  if (table === undefined) throw new Error(`Missing table: ${tableName}`);
  return table;
}

async function dropCheckConstraint(
  queryRunner: QueryRunner,
  tableName: string,
  constraintName: string,
): Promise<void> {
  const rows = (await queryRunner.query('SELECT VERSION() AS version')) as Array<{
    version: string;
  }>;
  const version = rows[0]?.version?.toLowerCase() ?? '';
  const operation = version.includes('mariadb') ? 'DROP CONSTRAINT' : 'DROP CHECK';
  await queryRunner.query(
    `ALTER TABLE ${tableName} ${operation} ${constraintName}`,
  );
}
