import type { MigrationInterface, QueryRunner } from 'typeorm';

export class OfertasServicosCatalogo1760139000000 implements MigrationInterface {
  name = 'OfertasServicosCatalogo1760139000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE profissional_servicos
      ADD COLUMN servico_catalogo_id INT UNSIGNED NULL AFTER categoria_id,
      ADD UNIQUE INDEX uq_oferta_profissional_catalogo (profissional_id, servico_catalogo_id),
      ADD CONSTRAINT fk_oferta_servico_catalogo FOREIGN KEY (servico_catalogo_id)
        REFERENCES servicos_catalogo(id) ON DELETE RESTRICT`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const rows = await queryRunner.query('SELECT COUNT(*) AS total FROM profissional_servicos WHERE servico_catalogo_id IS NOT NULL') as Array<{ total: number | string }>;
    if (Number(rows[0]?.total) !== 0) throw new Error('Rollback blocked: preserve catalog offer links.');
    await queryRunner.query(`ALTER TABLE profissional_servicos
      DROP FOREIGN KEY fk_oferta_servico_catalogo,
      DROP INDEX uq_oferta_profissional_catalogo,
      DROP COLUMN servico_catalogo_id`);
  }
}
