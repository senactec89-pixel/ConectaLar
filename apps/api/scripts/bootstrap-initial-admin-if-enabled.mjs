import { randomBytes, scrypt } from 'node:crypto';
import { promisify } from 'node:util';
import mysql from 'mysql2/promise';

const scryptAsync = promisify(scrypt);
const keyLength = 64;

if (process.env.BOOTSTRAP_INITIAL_ADMIN_ON_BUILD !== 'true') {
  console.info('Initial administrator bootstrap skipped.');
  process.exit(0);
}

const name = requiredText('INITIAL_ADMIN_NAME', 3, 140);
const email = requiredEmail('INITIAL_ADMIN_EMAIL');
const password = requiredPassword('INITIAL_ADMIN_PASSWORD');

async function main() {
  const db = await mysql.createConnection({
    host: requiredText('DB_HOST', 1, 253),
    port: positivePort(process.env.DB_PORT ?? '3306'),
    user: requiredText('DB_USER', 1, 128),
    password: process.env.DB_PASSWORD ?? '',
    database: requiredText('DB_NAME', 1, 128),
    multipleStatements: false,
  });

  try {
    await db.beginTransaction();
    const [admins] = await db.execute(
      "SELECT id FROM usuarios WHERE tipo = 'administrador' LIMIT 1",
    );
    if (admins.length > 0) {
      await db.rollback();
      console.info('Initial administrator bootstrap skipped because an administrator already exists.');
      return;
    }

    const [sameEmail] = await db.execute(
      'SELECT id FROM usuarios WHERE email = ? LIMIT 1',
      [email],
    );
    if (sameEmail.length > 0) {
      throw new Error('INITIAL_ADMIN_EMAIL_ALREADY_EXISTS');
    }

    const senhaHash = await hashPassword(password);
    const [result] = await db.execute(
      `INSERT INTO usuarios
        (nome, email, email_verificado, telefone, telefone_normalizado, tipo, senha_hash, ativo)
       VALUES (?, ?, 1, NULL, NULL, 'administrador', ?, 1)`,
      [name, email, senhaHash],
    );
    const adminId = result.insertId;

    await db.execute(
      `INSERT INTO admin_auditoria (ator_id, acao, alvo_tipo, alvo_id, detalhe)
       VALUES (?, 'administrador_criado', 'usuario', ?, ?)`,
      [
        adminId,
        adminId,
        'Conta administrativa inicial criada pelo bootstrap de implantacao.',
      ],
    );
    await db.commit();
    console.info(`Initial administrator created for ${email}.`);
  } catch (error) {
    await db.rollback();
    throw error;
  } finally {
    await db.end();
  }
}

async function hashPassword(value) {
  const salt = randomBytes(16);
  const derivedKey = await scryptAsync(value, salt, keyLength);
  return `scrypt$${salt.toString('base64url')}$${derivedKey.toString('base64url')}`;
}

function requiredText(key, min, max) {
  const value = process.env[key]?.trim();
  if (value === undefined || value.length < min || value.length > max) {
    throw new Error(`${key}_INVALID`);
  }
  return value;
}

function requiredEmail(key) {
  const value = requiredText(key, 5, 180).toLowerCase();
  if (!/^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$/.test(value)) {
    throw new Error(`${key}_INVALID`);
  }
  return value;
}

function requiredPassword(key) {
  const value = requiredText(key, 12, 128);
  if (!/[A-Z]/.test(value) || !/[a-z]/.test(value) || !/\d/.test(value) || !/[^A-Za-z0-9]/.test(value)) {
    throw new Error(`${key}_WEAK`);
  }
  return value;
}

function positivePort(value) {
  if (!/^[1-9]\d{0,4}$/.test(value)) throw new Error('DB_PORT_INVALID');
  const port = Number(value);
  if (port > 65_535) throw new Error('DB_PORT_INVALID');
  return port;
}

main().catch((error) => {
  console.error('Initial administrator bootstrap failed.');
  console.error(error instanceof Error ? error.message : 'UNKNOWN_ERROR');
  process.exit(1);
});
