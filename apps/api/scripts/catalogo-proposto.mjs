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
    for (const item of itens) {
      const [result] = await connection.execute(
        `INSERT INTO servicos_catalogo (categoria_id, nome, descricao, ativo)
         SELECT ?, ?, ?, 0 WHERE NOT EXISTS
           (SELECT 1 FROM servicos_catalogo WHERE categoria_id = ? AND nome = ?)`,
        [ids.get(item.categoria), item.nome, item.descricao ?? null, ids.get(item.categoria), item.nome],
      );
      criados += result.affectedRows;
    }
    await connection.commit();
    return { propostos: itens.length, criados };
  } catch (error) {
    await connection.rollback();
    throw error;
  }
}
