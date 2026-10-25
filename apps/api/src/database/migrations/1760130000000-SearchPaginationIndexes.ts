import type { MigrationInterface, QueryRunner } from 'typeorm';

export class SearchPaginationIndexes1760130000000
  implements MigrationInterface
{
  name = 'SearchPaginationIndexes1760130000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'ALTER TABLE profissionais ADD INDEX idx_profissionais_ativo_bairro (ativo, bairro)',
    );
    await queryRunner.query(
      'ALTER TABLE profissionais ADD INDEX idx_profissionais_ativo_regiao (ativo, uf, cidade)',
    );
    await queryRunner.query(
      'ALTER TABLE profissionais ADD INDEX idx_profissionais_ativo_verificado (ativo, verificado)',
    );
    await queryRunner.query(
      'ALTER TABLE profissional_servicos ADD INDEX idx_prof_servicos_categoria_ativo_profissional (categoria_id, ativo, profissional_id)',
    );
    await queryRunner.query(
      'ALTER TABLE favoritos_profissionais ADD INDEX idx_favoritos_cliente_criado_id (cliente_id, criado_em, id)',
    );
    await queryRunner.query(
      'ALTER TABLE usuarios ADD INDEX idx_usuarios_tipo_ativo (tipo, ativo)',
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'ALTER TABLE usuarios DROP INDEX idx_usuarios_tipo_ativo',
    );
    await queryRunner.query(
      'ALTER TABLE favoritos_profissionais DROP INDEX idx_favoritos_cliente_criado_id',
    );
    await queryRunner.query(
      'ALTER TABLE profissional_servicos DROP INDEX idx_prof_servicos_categoria_ativo_profissional',
    );
    await queryRunner.query(
      'ALTER TABLE profissionais DROP INDEX idx_profissionais_ativo_verificado',
    );
    await queryRunner.query(
      'ALTER TABLE profissionais DROP INDEX idx_profissionais_ativo_regiao',
    );
    await queryRunner.query(
      'ALTER TABLE profissionais DROP INDEX idx_profissionais_ativo_bairro',
    );
  }
}
