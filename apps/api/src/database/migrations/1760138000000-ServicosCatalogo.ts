import type { MigrationInterface, QueryRunner } from 'typeorm';

export class ServicosCatalogo1760138000000 implements MigrationInterface {
  name = 'ServicosCatalogo1760138000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TABLE servicos_catalogo (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      categoria_id INT UNSIGNED NOT NULL,
      nome VARCHAR(90) NOT NULL,
      descricao VARCHAR(1000) NULL,
      inclusoes VARCHAR(1000) NULL,
      exclusoes VARCHAR(1000) NULL,
      ativo TINYINT NOT NULL DEFAULT 0,
      criado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
      atualizado_em TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
      PRIMARY KEY (id),
      UNIQUE INDEX uq_servicos_catalogo_categoria_nome (categoria_id, nome),
      CONSTRAINT fk_servicos_catalogo_categoria FOREIGN KEY (categoria_id)
        REFERENCES categorias(id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
    await dropAuditCheck(queryRunner);
    await queryRunner.query(`ALTER TABLE admin_auditoria
      ADD CONSTRAINT chk_admin_auditoria_acao CHECK (acao IN (
        'usuario_ativado', 'usuario_desativado', 'administrador_criado',
        'categoria_criada', 'categoria_atualizada', 'documento_analisado',
        'denuncia_moderada', 'avaliacao_moderada', 'habilitacao_analisada',
        'habilitacao_revisao_solicitada', 'telefone_manual_confirmado',
        'servico_catalogo_criado', 'servico_catalogo_atualizado'))`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const servicos = await queryRunner.query('SELECT COUNT(*) AS total FROM servicos_catalogo') as Array<{ total: number | string }>;
    const auditorias = await queryRunner.query(`SELECT COUNT(*) AS total FROM admin_auditoria
      WHERE acao IN ('servico_catalogo_criado', 'servico_catalogo_atualizado')`) as Array<{ total: number | string }>;
    if (Number(servicos[0]?.total) !== 0 || Number(auditorias[0]?.total) !== 0) {
      throw new Error('Rollback blocked: preserve catalog and audit history.');
    }
    await dropAuditCheck(queryRunner);
    await queryRunner.query(`ALTER TABLE admin_auditoria
      ADD CONSTRAINT chk_admin_auditoria_acao CHECK (acao IN (
        'usuario_ativado', 'usuario_desativado', 'administrador_criado',
        'categoria_criada', 'categoria_atualizada', 'documento_analisado',
        'denuncia_moderada', 'avaliacao_moderada', 'habilitacao_analisada',
        'habilitacao_revisao_solicitada', 'telefone_manual_confirmado'))`);
    await queryRunner.query('DROP TABLE servicos_catalogo');
  }
}

async function dropAuditCheck(queryRunner: QueryRunner): Promise<void> {
  const rows = await queryRunner.query('SELECT VERSION() AS version') as Array<{ version: string }>;
  const operation = rows[0]?.version?.toLowerCase().includes('mariadb') ? 'DROP CONSTRAINT' : 'DROP CHECK';
  await queryRunner.query(`ALTER TABLE admin_auditoria ${operation} chk_admin_auditoria_acao`);
}
