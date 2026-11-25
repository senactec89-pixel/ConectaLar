import { randomBytes, scrypt } from 'node:crypto';
import { promisify } from 'node:util';
import mysql from 'mysql2/promise';

const scryptAsync = promisify(scrypt);
const password = process.env.HOMOLOGACAO_DEMO_PASSWORD ?? '';

if (process.env.CONECTALAR_STAGE !== 'homologacao' ||
    process.env.DB_NAME !== 'conectalar_homologacao' ||
    process.env.SEED_HOMOLOGACAO_FICTICIOS !== 'SIM') {
  throw new Error('Carga bloqueada: exige homologacao, banco conectalar_homologacao e confirmacao explicita.');
}

if (!passwordForte(password)) {
  throw new Error('HOMOLOGACAO_DEMO_PASSWORD deve ter 12+ caracteres, maiuscula, minuscula, numero e simbolo.');
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

const reviewers = [
  { nome: 'DEMO QA Cliente 01', email: 'demo.qa.cliente.01@example.test', bairro: 'Centro' },
  { nome: 'DEMO QA Cliente 02', email: 'demo.qa.cliente.02@example.test', bairro: 'Savassi' },
];

const professionals = [
  { categoria: 'Limpeza', bairro: 'Centro', latitude: -19.92, longitude: -43.94 },
  { categoria: 'Pintura', bairro: 'Savassi', latitude: -19.94, longitude: -43.94 },
  { categoria: 'Manutencao', bairro: 'Santa Efigenia', latitude: -19.92, longitude: -43.92 },
  { categoria: 'Eletrica', bairro: 'Funcionarios', latitude: -19.94, longitude: -43.93 },
  { categoria: 'Hidraulica', bairro: 'Pampulha', latitude: -19.85, longitude: -43.97 },
  { categoria: 'Ar-condicionado', bairro: 'Ouro Preto', latitude: -19.88, longitude: -43.98 },
  { categoria: 'Reformas', bairro: 'Barreiro', latitude: -19.98, longitude: -44.02 },
  { categoria: 'Outros', bairro: 'Venda Nova', latitude: -19.81, longitude: -43.95 },
].map((professional, index) => ({
  ...professional,
  index: index + 1,
  nome: `DEMO QA Profissional ${String(index + 1).padStart(2, '0')}`,
  email: `demo.qa.profissional.${String(index + 1).padStart(2, '0')}@example.test`,
}));

let lockAcquired = false;
try {
  const [lockRows] = await db.query(
    "SELECT GET_LOCK('conectalar_seed_demo_qa_homologacao', 10) AS acquired",
  );
  lockAcquired = Number(lockRows[0]?.acquired) === 1;
  if (!lockAcquired) throw new Error('Nao foi possivel obter o bloqueio exclusivo do seed.');

  await db.beginTransaction();
  const categoryIds = await loadCategoryIds(db);
  const reviewerIds = new Map();

  for (const reviewer of reviewers) {
    const userId = await upsertUser(db, reviewer, 'cliente');
    reviewerIds.set(reviewer.email, userId);
    await db.execute(
      `INSERT INTO cliente_perfis (usuario_id, bairro_principal, cidade, uf, observacoes)
       VALUES (?, ?, 'Belo Horizonte', 'MG', 'DEMO QA - conta e dados ficticios para homologacao.')
       ON DUPLICATE KEY UPDATE bairro_principal = VALUES(bairro_principal),
         cidade = VALUES(cidade), uf = VALUES(uf),
         observacoes = VALUES(observacoes)`,
      [userId, reviewer.bairro],
    );
  }

  for (const professional of professionals) {
    const userId = await upsertUser(db, professional, 'profissional');
    const [profileResult] = await db.execute(
      `INSERT INTO profissionais
         (usuario_id, descricao, bairro, cidade, uf, latitude, longitude,
          precisao_geografica, raio_atendimento_km, preco_inicial, verificado,
          habilitacao_estado, ativo)
       VALUES (?, ?, ?, 'Belo Horizonte', 'MG', ?, ?, 'APPROXIMATE', 25, NULL, 0, 'pendente', 1)
       ON DUPLICATE KEY UPDATE descricao = VALUES(descricao), bairro = VALUES(bairro),
         cidade = VALUES(cidade), uf = VALUES(uf), latitude = VALUES(latitude),
         longitude = VALUES(longitude), precisao_geografica = VALUES(precisao_geografica),
         raio_atendimento_km = VALUES(raio_atendimento_km), preco_inicial = NULL,
         verificado = 0, habilitacao_estado = 'pendente', ativo = 1`,
      [
        userId,
        `Perfil DEMO QA ficticio para testar mapa e exibicao de ${professional.categoria}; nao representa prestador real.`,
        professional.bairro,
        professional.latitude,
        professional.longitude,
      ],
    );
    const profileId = profileResult.insertId || await getProfessionalId(db, userId);
    const categoriaId = categoryIds.get(professional.categoria);

    for (let reviewIndex = 0; reviewIndex < reviewers.length; reviewIndex += 1) {
      const reviewer = reviewers[reviewIndex];
      const reviewerId = reviewerIds.get(reviewer.email);
      const marker = `DEMO QA - atendimento sintetico ${String(professional.index).padStart(2, '0')}-${reviewIndex + 1}`;
      const requestId = await getOrCreateCompletedRequest(
        db,
        reviewerId,
        profileId,
        categoriaId,
        professional,
        marker,
      );
      await db.execute(
        `INSERT INTO avaliacoes
           (solicitacao_id, avaliador_id, avaliado_id, nota, comentario, moderacao_status)
         VALUES (?, ?, ?, ?, ?, 'aprovada')
         ON DUPLICATE KEY UPDATE nota = VALUES(nota), comentario = VALUES(comentario),
           moderacao_status = 'aprovada'`,
        [
          requestId,
          reviewerId,
          userId,
          reviewIndex === 0 ? 5 : 4,
          'DEMO QA - avaliacao ficticia para testar a interface; nao relata atendimento real.',
        ],
      );
    }
  }

  await db.commit();
  console.log(JSON.stringify({
    status: 'ok',
    ambiente: 'homologacao',
    profissionais: professionals.map(({ nome, email, categoria, bairro }) => ({ nome, email, categoria, bairro })),
    clientesAvaliadores: reviewers.map(({ nome, email }) => ({ nome, email })),
    observacao: 'Contas, coordenadas e avaliacoes sao ficticias; profissionais permanecem nao verificados e pendentes.',
  }, null, 2));
} catch (error) {
  try {
    await db.rollback();
  } catch {
    // The connection may not have entered a transaction.
  }
  console.error('Seed ficticio de homologacao falhou.');
  console.error(error instanceof Error ? error.message : 'Erro inesperado.');
  process.exitCode = 1;
} finally {
  if (lockAcquired) {
    try {
      await db.query("SELECT RELEASE_LOCK('conectalar_seed_demo_qa_homologacao')");
    } catch {
      // Closing the connection also releases the advisory lock.
    }
  }
  await db.end();
}

function passwordForte(value) {
  return value.length >= 12 && /[A-Z]/.test(value) && /[a-z]/.test(value) &&
    /[0-9]/.test(value) && /[^A-Za-z0-9]/.test(value);
}

async function hashPassword(value) {
  const salt = randomBytes(16);
  const derivedKey = await scryptAsync(value, salt, 64);
  return `scrypt$${salt.toString('base64url')}$${derivedKey.toString('base64url')}`;
}

async function upsertUser(connection, user, tipo) {
  await connection.execute(
    `INSERT INTO usuarios (nome, email, email_verificado, tipo, senha_hash, ativo)
     VALUES (?, ?, 1, ?, ?, 1)
     ON DUPLICATE KEY UPDATE nome = VALUES(nome), email_verificado = 1,
       tipo = VALUES(tipo), senha_hash = VALUES(senha_hash), ativo = 1`,
    [user.nome, user.email, tipo, await hashPassword(password)],
  );
  const [rows] = await connection.execute('SELECT id FROM usuarios WHERE email = ?', [user.email]);
  if (rows.length !== 1) throw new Error(`Conta DEMO QA nao encontrada: ${user.email}`);
  return rows[0].id;
}

async function loadCategoryIds(connection) {
  const names = professionals.map(({ categoria }) => categoria);
  const [rows] = await connection.query('SELECT id, nome FROM categorias WHERE nome IN (?)', [names]);
  const ids = new Map(rows.map((row) => [row.nome, row.id]));
  if (names.some((name) => !ids.has(name))) throw new Error('Categorias necessarias nao encontradas; aplique as migrations.');
  return ids;
}

async function getProfessionalId(connection, userId) {
  const [rows] = await connection.execute('SELECT id FROM profissionais WHERE usuario_id = ?', [userId]);
  if (rows.length !== 1) throw new Error('Perfil profissional DEMO QA nao encontrado.');
  return rows[0].id;
}

async function getOrCreateCompletedRequest(connection, clientId, professionalId, categoryId, professional, marker) {
  const description = `${marker}; ${professional.categoria}; nao representa atendimento real.`;
  const [existing] = await connection.execute(
    `SELECT id FROM solicitacoes
     WHERE cliente_id = ? AND profissional_id = ? AND descricao = ? LIMIT 1 FOR UPDATE`,
    [clientId, professionalId, description],
  );
  if (existing.length > 0) return existing[0].id;

  const [result] = await connection.execute(
    `INSERT INTO solicitacoes
       (cliente_id, profissional_id, categoria_id, descricao, bairro_atendimento,
        data_servico, horario_servico, preco_inicial, status)
     VALUES (?, ?, ?, ?, ?, ?, '10:00', NULL, 'conclusao_confirmada')`,
    [
      clientId,
      professionalId,
      categoryId,
      description,
      professional.bairro,
      new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10),
    ],
  );
  return result.insertId;
}
