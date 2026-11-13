import { readFile } from 'node:fs/promises';

// Explicit test/demo import. The caller owns the isolated database connection.
export async function importarCatalogoProposto(connection) {
  const itens = JSON.parse(await readFile(new URL('./catalogo-proposto.json', import.meta.url), 'utf8'));
  const categorias = [...new Set(itens.map((item) => item.categoria))];
  await connection.beginTransaction();
  try {
    const [rows] = await connection.query('SELECT id, nome FROM categorias WHERE nome IN (?)', [categorias]);
    const ids = new Map(rows.map((row) => [row.nome, row.id]));
    if (categorias.some((nome) => !ids.has(nome))) throw new Error('Categorias do catalogo proposto nao encontradas.');
    let criados = 0;
    let enriquecidos = 0;
    for (const item of itens) {
      const [result] = await connection.execute(
        `INSERT INTO servicos_catalogo (categoria_id, nome, descricao, inclusoes, exclusoes, ativo)
           VALUES (?, ?, ?, ?, ?, 0)
         ON DUPLICATE KEY UPDATE
           descricao = IF(descricao IS NULL OR TRIM(descricao) = '', VALUES(descricao), descricao),
           inclusoes = IF(inclusoes IS NULL OR TRIM(inclusoes) = '', VALUES(inclusoes), inclusoes),
           exclusoes = IF(exclusoes IS NULL OR TRIM(exclusoes) = '', VALUES(exclusoes), exclusoes)`,
        [ids.get(item.categoria), item.nome, item.descricao, item.inclusoes, item.exclusoes],
      );
      if (result.affectedRows === 1) criados += 1;
      else if (result.affectedRows > 1) enriquecidos += 1;
    }
    await connection.commit();
    return { propostos: itens.length, criados, enriquecidos };
  } catch (error) {
    await connection.rollback();
    throw error;
  }
}
