import { MigrationInterface, QueryRunner } from 'typeorm';

export class FotoPerfilUsuario1760118000000 implements MigrationInterface {
  name = 'FotoPerfilUsuario1760118000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE usuarios
      ADD COLUMN foto_perfil VARCHAR(180) NULL AFTER telefone_normalizado
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('ALTER TABLE usuarios DROP COLUMN foto_perfil');
  }
}
