import type { MigrationInterface, QueryRunner } from 'typeorm';

export class HabilitacaoPilotoPorTarefa1760146000000 implements MigrationInterface {
  name = 'HabilitacaoPilotoPorTarefa1760146000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE servicos_catalogo
      ADD COLUMN politica_piloto VARCHAR(32) NOT NULL DEFAULT 'fora_piloto',
      ADD COLUMN criterio_piloto VARCHAR(1000) NULL,
      ADD CONSTRAINT chk_servicos_catalogo_politica_piloto CHECK (
        politica_piloto IN ('fora_piloto', 'experiencia_declarada', 'iniciante_ou_experiencia')
      )`);
    await queryRunner.query(`ALTER TABLE profissional_servicos
      ADD COLUMN nivel_experiencia_piloto VARCHAR(30) NULL,
      ADD COLUMN relato_experiencia_piloto VARCHAR(500) NULL,
      ADD COLUMN frequencia_experiencia_piloto VARCHAR(20) NULL,
      ADD COLUMN iniciante_confirmado_piloto BOOLEAN NOT NULL DEFAULT FALSE,
      ADD COLUMN revisao_experiencia_estado VARCHAR(24) NOT NULL DEFAULT 'pendente',
      ADD COLUMN primeiro_revisor_id INT UNSIGNED NULL,
      ADD COLUMN primeira_revisao_em DATETIME NULL,
      ADD COLUMN revisor_final_id INT UNSIGNED NULL,
      ADD COLUMN revisao_final_em DATETIME NULL,
      ADD COLUMN motivo_revisao_experiencia VARCHAR(40) NULL,
      ADD CONSTRAINT chk_prof_servico_nivel_experiencia CHECK (
        nivel_experiencia_piloto IS NULL OR nivel_experiencia_piloto IN ('experiencia_declarada', 'iniciante')
      ),
      ADD CONSTRAINT chk_prof_servico_frequencia CHECK (
        frequencia_experiencia_piloto IS NULL OR frequencia_experiencia_piloto IN ('ocasional', 'recorrente')
      ),
      ADD CONSTRAINT chk_prof_servico_revisao_experiencia CHECK (
        revisao_experiencia_estado IN ('pendente', 'primeira_aprovacao', 'aprovada', 'precisa_correcao', 'inconclusiva', 'suspensa')
      ),
      ADD CONSTRAINT fk_prof_servico_primeiro_revisor FOREIGN KEY (primeiro_revisor_id)
        REFERENCES usuarios(id) ON DELETE RESTRICT,
      ADD CONSTRAINT fk_prof_servico_revisor_final FOREIGN KEY (revisor_final_id)
        REFERENCES usuarios(id) ON DELETE RESTRICT`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const rows = await queryRunner.query(`SELECT COUNT(*) AS total FROM profissional_servicos
      WHERE revisao_experiencia_estado <> 'pendente' OR nivel_experiencia_piloto IS NOT NULL
      OR relato_experiencia_piloto IS NOT NULL OR frequencia_experiencia_piloto IS NOT NULL
      OR iniciante_confirmado_piloto = TRUE
      OR primeiro_revisor_id IS NOT NULL OR primeira_revisao_em IS NOT NULL
      OR revisor_final_id IS NOT NULL OR revisao_final_em IS NOT NULL
      OR motivo_revisao_experiencia IS NOT NULL`) as Array<{ total: number | string }>;
    if (Number(rows[0]?.total) !== 0) {
      throw new Error('Rollback blocked: preserve professional task review data.');
    }
    const services = await queryRunner.query(`SELECT COUNT(*) AS total FROM servicos_catalogo
      WHERE politica_piloto <> 'fora_piloto' OR criterio_piloto IS NOT NULL`) as Array<{ total: number | string }>;
    if (Number(services[0]?.total) !== 0) {
      throw new Error('Rollback blocked: preserve configured pilot task policies.');
    }
    const versionRows = await queryRunner.query('SELECT VERSION() AS version') as Array<{ version: string }>;
    const dropCheck = versionRows[0]?.version?.toLowerCase().includes('mariadb')
      ? 'DROP CONSTRAINT'
      : 'DROP CHECK';
    await queryRunner.query(`ALTER TABLE profissional_servicos
      DROP FOREIGN KEY fk_prof_servico_primeiro_revisor,
      DROP FOREIGN KEY fk_prof_servico_revisor_final,
      ${dropCheck} chk_prof_servico_nivel_experiencia,
      ${dropCheck} chk_prof_servico_frequencia,
      ${dropCheck} chk_prof_servico_revisao_experiencia,
      DROP COLUMN nivel_experiencia_piloto,
      DROP COLUMN relato_experiencia_piloto,
      DROP COLUMN frequencia_experiencia_piloto,
      DROP COLUMN iniciante_confirmado_piloto,
      DROP COLUMN revisao_experiencia_estado,
      DROP COLUMN primeiro_revisor_id,
      DROP COLUMN primeira_revisao_em,
      DROP COLUMN revisor_final_id,
      DROP COLUMN revisao_final_em,
      DROP COLUMN motivo_revisao_experiencia`);
    await queryRunner.query(`ALTER TABLE servicos_catalogo
      ${dropCheck} chk_servicos_catalogo_politica_piloto,
      DROP COLUMN politica_piloto,
      DROP COLUMN criterio_piloto`);
  }
}
