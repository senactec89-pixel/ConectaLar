import type { MigrationInterface, QueryRunner } from 'typeorm';

export class GoogleLogin1760122000000 implements MigrationInterface {
  name = 'GoogleLogin1760122000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE usuarios
      ADD COLUMN google_sub VARCHAR(255) NULL AFTER email_verificado,
      ADD UNIQUE INDEX uq_usuarios_google_sub (google_sub)
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE usuarios
      DROP INDEX uq_usuarios_google_sub,
      DROP COLUMN google_sub
    `);
  }
}
