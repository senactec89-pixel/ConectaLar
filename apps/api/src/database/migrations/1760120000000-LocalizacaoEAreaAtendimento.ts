import type { MigrationInterface, QueryRunner } from 'typeorm';

export class LocalizacaoEAreaAtendimento1760120000000
  implements MigrationInterface
{
  name = 'LocalizacaoEAreaAtendimento1760120000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE cliente_enderecos
        ADD COLUMN latitude DECIMAL(10, 7) NULL AFTER uf,
        ADD COLUMN longitude DECIMAL(10, 7) NULL AFTER latitude,
        ADD COLUMN precisao_geografica VARCHAR(32) NULL AFTER longitude
    `);
    await queryRunner.query(`
      ALTER TABLE profissionais
        ADD COLUMN cep VARCHAR(12) NULL AFTER bairro,
        ADD COLUMN cidade VARCHAR(120) NULL AFTER cep,
        ADD COLUMN uf CHAR(2) NULL AFTER cidade,
        ADD COLUMN latitude DECIMAL(10, 7) NULL AFTER uf,
        ADD COLUMN longitude DECIMAL(10, 7) NULL AFTER latitude,
        ADD COLUMN precisao_geografica VARCHAR(32) NULL AFTER longitude,
        ADD COLUMN raio_atendimento_km SMALLINT UNSIGNED NOT NULL DEFAULT 15 AFTER precisao_geografica,
        ADD INDEX idx_profissionais_regiao (uf, cidade),
        ADD CONSTRAINT chk_profissionais_raio_atendimento
          CHECK (raio_atendimento_km BETWEEN 1 AND 200)
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await dropCheckConstraint(queryRunner, 'profissionais', 'chk_profissionais_raio_atendimento');
    await queryRunner.query(`
      ALTER TABLE profissionais
        DROP INDEX idx_profissionais_regiao,
        DROP COLUMN raio_atendimento_km,
        DROP COLUMN precisao_geografica,
        DROP COLUMN longitude,
        DROP COLUMN latitude,
        DROP COLUMN uf,
        DROP COLUMN cidade,
        DROP COLUMN cep
    `);
    await queryRunner.query(`
      ALTER TABLE cliente_enderecos
        DROP COLUMN precisao_geografica,
        DROP COLUMN longitude,
        DROP COLUMN latitude
    `);
  }
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
  await queryRunner.query(`ALTER TABLE ${tableName} ${operation} ${constraintName}`);
}
