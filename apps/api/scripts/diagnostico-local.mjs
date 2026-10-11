import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import mysql from 'mysql2/promise';

const baseUrl = (process.env.CONECTALAR_API_BASE_URL ?? 'http://127.0.0.1:3012')
  .replace(/\/+$/, '');
const dbConfig = {
  host: process.env.DB_HOST ?? '127.0.0.1',
  port: Number(process.env.DB_PORT ?? 3307),
  user: process.env.DB_USER ?? 'conectalar_app',
  password: process.env.DB_PASSWORD ?? 'ConectaLarDev123!',
  database: process.env.DB_NAME ?? 'conectalar_dev',
};

const demoPassword = process.env.DEMO_PASSWORD ?? 'ConectaLarDemo123!';
const demoUsers = {
  cliente: 'cliente.demo@conectalar.local',
  profissional: 'profissional.demo@conectalar.local',
  admin: 'admin.demo@conectalar.local',
};

const results = [];

async function main() {
  await checkApiHealth();
  await checkDatabase();
  await checkDemoLoginsAndEndpoints();
  printSummary();
  if (results.some((item) => item.status === 'fail')) {
    process.exitCode = 1;
  }
}

async function checkApiHealth() {
  try {
    const response = await fetchJson('GET', 'health');
    pass('API /health', `online em ${baseUrl} (${response.status})`);
  } catch (error) {
    fail('API /health', error.message);
  }
}

async function checkDatabase() {
  let db;
  try {
    db = await mysql.createConnection(dbConfig);
    await db.ping();
    pass('MySQL', `${dbConfig.user}@${dbConfig.host}:${dbConfig.port}/${dbConfig.database}`);

    const [rows] = await db.execute(
      'SELECT name FROM typeorm_migrations ORDER BY timestamp',
    );
    const applied = new Set(rows.map((row) => row.name));
    const expected = await migrationNamesFromSource();
    const pending = expected.filter((name) => !applied.has(name));
    if (pending.length === 0) {
      pass('Migrations', `${applied.size} aplicadas, nenhuma pendente`);
    } else {
      fail('Migrations', `pendentes: ${pending.join(', ')}`);
    }
  } catch (error) {
    fail('MySQL/Migrations', error.message);
  } finally {
    await db?.end();
  }
}

async function migrationNamesFromSource() {
  const dir = join(process.cwd(), 'src', 'database', 'migrations');
  const files = (await readdir(dir)).filter((file) => file.endsWith('.ts'));
  const names = [];
  for (const file of files) {
    const content = await readFile(join(dir, file), 'utf8');
    const match = content.match(/export\s+class\s+(\w+)\s+implements\s+MigrationInterface/);
    if (match) names.push(match[1]);
  }
  return names.sort();
}

async function checkDemoLoginsAndEndpoints() {
  const tokens = {};
  for (const [role, email] of Object.entries(demoUsers)) {
    try {
      const data = await fetchJson('POST', 'auth/login', undefined, {
        email,
        senha: demoPassword,
      });
      tokens[role] = data.token.accessToken;
      pass(`Login ${role}`, email);
    } catch (error) {
      fail(`Login ${role}`, error.message);
    }
  }

  await checkEndpoint('Categorias publicas', 'GET', 'categorias');
  await checkEndpoint('Profissionais publicos', 'GET', 'profissionais');
  if (tokens.cliente) {
    await checkEndpoint(
      'Enderecos do cliente demo',
      'GET',
      'clientes/me/enderecos',
      tokens.cliente,
    );
  }
  if (tokens.profissional) {
    await checkEndpoint(
      'Painel profissional demo',
      'GET',
      'profissionais/me/painel',
      tokens.profissional,
    );
    await checkEndpoint(
      'Agenda profissional demo',
      'GET',
      `profissionais/me/agenda?mes=${new Date().toISOString().slice(0, 7)}`,
      tokens.profissional,
    );
  }
  if (tokens.admin) {
    await checkEndpoint(
      'Denuncias admin demo',
      'GET',
      'denuncias/moderacao',
      tokens.admin,
    );
    await checkEndpoint(
      'Avaliacoes admin demo',
      'GET',
      'avaliacoes/moderacao',
      tokens.admin,
    );
  }
}

async function checkEndpoint(label, method, path, token) {
  try {
    await fetchJson(method, path, token);
    pass(label, `${method} /${path}`);
  } catch (error) {
    fail(label, error.message);
  }
}

async function fetchJson(method, path, token, body) {
  const response = await fetch(`${baseUrl}/${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (!response.ok) {
    const message = typeof data.message === 'string' ? data.message : text;
    throw new Error(`${response.status} ${message}`);
  }
  return data;
}

function pass(name, detail) {
  results.push({ status: 'pass', name, detail });
}

function fail(name, detail) {
  results.push({ status: 'fail', name, detail });
}

function printSummary() {
  console.log('\nDiagnostico local ConectaLar\n');
  for (const item of results) {
    const marker = item.status === 'pass' ? '[OK]' : '[FALHA]';
    console.log(`${marker} ${item.name}: ${item.detail}`);
  }
  const failures = results.filter((item) => item.status === 'fail').length;
  console.log(`\nResultado: ${results.length - failures}/${results.length} verificacoes OK.`);
}

main().catch((error) => {
  console.error('Diagnostico falhou antes de concluir.');
  console.error(error);
  process.exitCode = 1;
});
