import { MigrationInterface, QueryRunner } from 'typeorm';

export class SnapshotEnderecoECancelamento1760126000000 implements MigrationInterface {
  name = 'SnapshotEnderecoECancelamento1760126000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE solicitacoes
      ADD endereco_snapshot JSON NULL AFTER endereco_id,
      ADD cancelamento_motivo VARCHAR(400) NULL AFTER status`);

    // Existing appointments cannot recover an older version of an address, but
    // this preserves the currently linked value before later edits are made.
    await queryRunner.query(`UPDATE solicitacoes solicitacao
      LEFT JOIN cliente_enderecos endereco ON endereco.id = solicitacao.endereco_id
      SET solicitacao.endereco_snapshot = CASE
        WHEN endereco.id IS NULL THEN NULL
        ELSE JSON_OBJECT(
          'id', endereco.id,
          'apelido', endereco.apelido,
          'cep', endereco.cep,
          'logradouro', endereco.logradouro,
          'numero', endereco.numero,
          'complemento', endereco.complemento,
          'bairro', endereco.bairro,
          'cidade', endereco.cidade,
          'uf', endereco.uf
        )
      END
      WHERE solicitacao.endereco_id IS NOT NULL`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE solicitacoes
      DROP COLUMN cancelamento_motivo,
      DROP COLUMN endereco_snapshot`);
  }
}
