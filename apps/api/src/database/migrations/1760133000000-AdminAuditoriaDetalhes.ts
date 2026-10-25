import type { MigrationInterface, QueryRunner } from 'typeorm';

export class AdminAuditoriaDetalhes1760133000000 implements MigrationInterface {
  name = 'AdminAuditoriaDetalhes1760133000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'ALTER TABLE admin_auditoria MODIFY detalhe TEXT NULL',
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const rows = (await queryRunner.query(
      'SELECT COUNT(*) AS total FROM admin_auditoria WHERE CHAR_LENGTH(detalhe) > 600',
    )) as Array<{ total: number | string }>;
    if (Number(rows[0]?.total) > 0) {
      throw new Error(
        'Rollback blocked: audit details exceed the previous 600-character limit.',
      );
    }
    await queryRunner.query(
      'ALTER TABLE admin_auditoria MODIFY detalhe VARCHAR(600) NULL',
    );
  }
}
