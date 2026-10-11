import { MigrationInterface, QueryRunner } from 'typeorm';

export class EnderecoAtendimentoEAuditoriaAmpliada1760113000000
  implements MigrationInterface
{
  name = 'EnderecoAtendimentoEAuditoriaAmpliada1760113000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE solicitacoes
        ADD endereco_id INT UNSIGNED NULL AFTER categoria_id,
        ADD INDEX idx_solicitacoes_endereco (endereco_id),
        ADD CONSTRAINT fk_solicitacoes_endereco
          FOREIGN KEY (endereco_id) REFERENCES cliente_enderecos(id)
          ON DELETE RESTRICT
    `);

    await queryRunner.query(`
      ALTER TABLE admin_auditoria
        DROP CHECK chk_admin_auditoria_acao
    `);

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
    await queryRunner.query(`
      ALTER TABLE admin_auditoria
        DROP CHECK chk_admin_auditoria_acao
    `);

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
