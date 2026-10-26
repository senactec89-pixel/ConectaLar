import type { MigrationInterface, QueryRunner } from 'typeorm';

export class LimitesPersistentesCodigosAuth1760135000000 implements MigrationInterface {
  name = 'LimitesPersistentesCodigosAuth1760135000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE usuarios
      ADD COLUMN senha_reset_solicitacoes SMALLINT UNSIGNED NOT NULL DEFAULT 0,
      ADD COLUMN senha_reset_janela_inicio DATETIME NULL,
      ADD COLUMN senha_reset_ultima_solicitacao DATETIME NULL,
      ADD COLUMN email_verificacao_solicitacoes SMALLINT UNSIGNED NOT NULL DEFAULT 0,
      ADD COLUMN email_verificacao_janela_inicio DATETIME NULL,
      ADD COLUMN email_verificacao_ultima_solicitacao DATETIME NULL`);
    await queryRunner.query(`ALTER TABLE usuario_senha_resets
      ADD COLUMN tentativas SMALLINT UNSIGNED NOT NULL DEFAULT 0,
      ADD COLUMN bloqueado_em TIMESTAMP(6) NULL`);
    await queryRunner.query(`ALTER TABLE usuario_email_verificacoes
      ADD COLUMN tentativas SMALLINT UNSIGNED NOT NULL DEFAULT 0,
      ADD COLUMN bloqueado_em TIMESTAMP(6) NULL`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE usuario_email_verificacoes
      DROP COLUMN bloqueado_em,
      DROP COLUMN tentativas`);
    await queryRunner.query(`ALTER TABLE usuario_senha_resets
      DROP COLUMN bloqueado_em,
      DROP COLUMN tentativas`);
    await queryRunner.query(`ALTER TABLE usuarios
      DROP COLUMN email_verificacao_ultima_solicitacao,
      DROP COLUMN email_verificacao_janela_inicio,
      DROP COLUMN email_verificacao_solicitacoes,
      DROP COLUMN senha_reset_ultima_solicitacao,
      DROP COLUMN senha_reset_janela_inicio,
      DROP COLUMN senha_reset_solicitacoes`);
  }
}
