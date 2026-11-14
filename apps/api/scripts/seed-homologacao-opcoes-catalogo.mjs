import mysql from 'mysql2/promise';
import { normalizarNomeServico, opcoesPropostas } from './catalogo-opcoes-propostas.mjs';

if (process.env.CONECTALAR_STAGE !== 'homologacao' ||
    process.env.DB_NAME !== 'conectalar_homologacao' ||
    process.env.SEED_HOMOLOGACAO_OPCOES !== 'SIM') {
  throw new Error('Carga bloqueada: exige homologacao, banco conectalar_homologacao e confirmacao explicita.');
}

for (const key of ['DB_HOST', 'DB_USER', 'DB_PASSWORD']) {
  if (!process.env[key]) throw new Error(`${key} obrigatorio.`);
}

const db = await mysql.createConnection({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT ?? 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  multipleStatements: false,
});

let lockAcquired = false;
try {
  const [lockRows] = await db.query(
    "SELECT GET_LOCK('conectalar_seed_opcoes_catalogo_homologacao', 10) AS acquired",
  );
  lockAcquired = Number(lockRows[0]?.acquired) === 1;
  if (!lockAcquired) throw new Error('Nao foi possivel obter o bloqueio exclusivo do seed.');

  await db.beginTransaction();
  const [admins] = await db.execute(
    "SELECT id FROM usuarios WHERE tipo = 'administrador' AND ativo = 1 ORDER BY id LIMIT 1",
  );
  if (admins.length === 0) throw new Error('Nenhum administrador ativo encontrado para auditoria.');

  const [services] = await db.execute(
    `SELECT sc.id, sc.nome, sc.ativo, sc.categoria_id, cat.ativo AS categoria_ativa
     FROM servicos_catalogo sc
     JOIN categorias cat ON cat.id = sc.categoria_id
     ORDER BY sc.id`,
  );
  const byName = new Map(services.map((service) => [normalizarNomeServico(service.nome), service]));
  const missing = [...opcoesPropostas.keys()].filter((name) => !byName.has(name));
  if (missing.length > 0) {
    throw new Error(`Catalogo incompleto; importe primeiro os servicos propostos. Ausentes: ${missing.join(', ')}`);
  }

  let opcoesCriadasOuAtivadas = 0;
  let servicosComOpcoes = 0;
  let opcoesPausadas = 0;
  for (const [name, options] of opcoesPropostas) {
    const service = byName.get(name);
    const ativo = Number(service.ativo) === 1 && Number(service.categoria_ativa) === 1;
    for (const optionName of options) {
      const [result] = await db.execute(
        `INSERT INTO servico_catalogo_opcoes (servico_catalogo_id, nome, ativo)
         VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE ativo = IF(VALUES(ativo) = 1, 1, ativo)`,
        [service.id, optionName, Number(ativo)],
      );
      opcoesCriadasOuAtivadas += result.affectedRows;
    }
    if (!ativo) opcoesPausadas += options.length;
    servicosComOpcoes += 1;
    await db.execute(
      `INSERT INTO admin_auditoria (ator_id, acao, alvo_tipo, alvo_id, detalhe)
       VALUES (?, 'servico_catalogo_atualizado', 'servico_catalogo', ?, ?)`,
      [admins[0].id, service.id, JSON.stringify({
        operacao: 'seed_homologacao_opcoes_propostas',
        quantidade: options.length,
        ativo,
        opcoes: options,
      })],
    );
  }

  await db.commit();
  console.log(JSON.stringify({
    status: 'ok',
    ambiente: 'homologacao',
    servicosComOpcoes,
    opcoesPorServico: 5,
    opcoesCriadasOuAtivadas,
    opcoesPausadas,
    servicosSemSugestoes: services.length - servicosComOpcoes,
  }, null, 2));
} catch (error) {
  try {
    await db.rollback();
  } catch {
    // The connection may not have entered a transaction.
  }
  console.error('Seed de opcoes da homologacao falhou.');
  console.error(error instanceof Error ? error.message : 'Erro inesperado.');
  process.exitCode = 1;
} finally {
  if (lockAcquired) {
    try {
      await db.query("SELECT RELEASE_LOCK('conectalar_seed_opcoes_catalogo_homologacao')");
    } catch {
      // Closing the connection also releases the advisory lock.
    }
  }
  await db.end();
}
