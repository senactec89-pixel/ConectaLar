import { MigrationInterface, QueryRunner } from 'typeorm';

export class MfaAdministrativo1760116000000 implements MigrationInterface {
  name = 'MfaAdministrativo1760116000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE usuarios
        ADD mfa_ativo BOOLEAN NOT NULL DEFAULT FALSE AFTER token_version,
        ADD mfa_secret_encrypted VARCHAR(512) NULL AFTER mfa_ativo
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE usuarios
        DROP COLUMN mfa_secret_encrypted,
        DROP COLUMN mfa_ativo
    `);
  }
}
