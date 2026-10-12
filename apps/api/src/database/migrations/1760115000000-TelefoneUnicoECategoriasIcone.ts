import { MigrationInterface, QueryRunner } from 'typeorm';

export class TelefoneUnicoECategoriasIcone1760115000000
  implements MigrationInterface
{
  name = 'TelefoneUnicoECategoriasIcone1760115000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE usuarios
        ADD telefone_normalizado VARCHAR(16) NULL AFTER telefone,
        ADD UNIQUE INDEX uq_usuarios_telefone_normalizado (telefone_normalizado)
    `);

    await queryRunner.query(`
      ALTER TABLE categorias
        ADD icone VARCHAR(40) NOT NULL DEFAULT 'home_repair' AFTER nome
    `);

    await queryRunner.query(`
      UPDATE categorias
      SET icone = CASE nome
        WHEN 'Eletrica' THEN 'electrical_services'
        WHEN 'Hidraulica' THEN 'plumbing'
        WHEN 'Pintura' THEN 'format_paint'
        WHEN 'Limpeza' THEN 'cleaning_services'
        WHEN 'Manutencao' THEN 'build'
        WHEN 'Ar-condicionado' THEN 'ac_unit'
        WHEN 'Reformas' THEN 'construction'
        ELSE 'home_repair'
      END
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE categorias
        DROP COLUMN icone
    `);
    await queryRunner.query(`
      ALTER TABLE usuarios
        DROP INDEX uq_usuarios_telefone_normalizado,
        DROP COLUMN telefone_normalizado
    `);
  }
}
