import mysql from 'mysql2/promise';
import { opcoesPropostas as suggestions, normalizarNomeServico as normalize } from './catalogo-opcoes-propostas.mjs';

const config = {
  host: process.env.DB_HOST ?? '127.0.0.1',
  port: Number(process.env.DB_PORT ?? 3307),
  user: process.env.DB_USER ?? 'conectalar_app',
  password: process.env.DB_PASSWORD ?? 'ConectaLarDev123!',
  database: process.env.DB_NAME ?? 'conectalar_dev',
  multipleStatements: false,
};

if (config.host !== '127.0.0.1' || config.port !== 3307 || config.database !== 'conectalar_dev') {
  throw new Error('This test seed only runs against 127.0.0.1:3307/conectalar_dev.');
}

const connection = await mysql.createConnection(config);
try {
  await connection.beginTransaction();
  const [admins] = await connection.execute(
    "SELECT id FROM usuarios WHERE tipo = 'administrador' AND ativo = 1 ORDER BY id LIMIT 1",
  );
  if (admins.length === 0) throw new Error('No active local administrator exists for audit logging.');
  const adminId = admins[0].id;
  const [services] = await connection.execute(
    `SELECT sc.id, sc.nome, sc.categoria_id, cat.nome AS categoria_nome
     FROM servicos_catalogo sc JOIN categorias cat ON cat.id = sc.categoria_id
     WHERE sc.ativo = 1 AND cat.ativo = 1 ORDER BY sc.id`,
  );

  const missing = services.filter((service) => !suggestions.has(normalize(service.nome)));
  if (missing.length > 0) {
    throw new Error(`No local test suggestions defined for: ${missing.map((item) => item.nome).join(', ')}`);
  }

  let insertedOrActivated = 0;
  for (const service of services) {
    const options = suggestions.get(normalize(service.nome));
    for (const name of options) {
      const [result] = await connection.execute(
        `INSERT INTO servico_catalogo_opcoes (servico_catalogo_id, nome, ativo)
         VALUES (?, ?, 1)
         ON DUPLICATE KEY UPDATE ativo = 1`,
        [service.id, name],
      );
      insertedOrActivated += result.affectedRows;
    }
    await connection.execute(
      `INSERT INTO admin_auditoria (ator_id, acao, alvo_tipo, alvo_id, detalhe)
       VALUES (?, 'servico_catalogo_atualizado', 'servico_catalogo', ?, ?)`,
      [adminId, service.id, JSON.stringify({ operacao: 'seed_teste_local_opcoes_ativas', opcoes: options })],
    );
  }
  await connection.commit();
  console.log(JSON.stringify({ status: 'ok', database: `${config.host}:${config.port}/${config.database}`, services: services.length, suggestionsPerService: 5, insertedOrActivated }));
} catch (error) {
  await connection.rollback();
  throw error;
} finally {
  await connection.end();
}
