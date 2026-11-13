import type { MigrationInterface, QueryRunner } from 'typeorm';

export class EscopoOfertas1760138000000 implements MigrationInterface {
  name = 'EscopoOfertas1760138000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    for (const [table, column] of campos) {
      if (!(await queryRunner.hasColumn(table, column))) {
        await queryRunner.query(`ALTER TABLE ${table} ADD COLUMN ${column} JSON NULL`);
      }
    }
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    for (const [table, column] of campos) {
      if (!(await queryRunner.hasColumn(table, column))) continue;
      const rows = await queryRunner.query(
        `SELECT COUNT(*) AS total FROM ${table} WHERE ${column} IS NOT NULL`,
      ) as Array<{ total: string | number }>;
      if (Number(rows[0]?.total) !== 0) {
        throw new Error('Rollback blocked: preserve service scope and request history.');
      }
    }
    for (const [table, column] of [...campos].reverse()) {
      if (await queryRunner.hasColumn(table, column)) {
        await queryRunner.query(`ALTER TABLE ${table} DROP COLUMN ${column}`);
      }
    }
  }
}

const campos = [
  ['profissional_servicos', 'inclui'],
  ['profissional_servicos', 'nao_inclui'],
  ['profissional_servicos', 'opcionais'],
  ['solicitacoes', 'escopo_servico_snapshot'],
] as const;
