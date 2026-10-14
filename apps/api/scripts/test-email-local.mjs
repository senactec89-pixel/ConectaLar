import { createRequire } from 'node:module';
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const require = createRequire(import.meta.url);

loadLocalEnv();

const to = process.argv[2]?.trim();
if (!to) {
  console.error('Uso: npm.cmd run email:test -- destinatario@example.com');
  process.exit(1);
}

const { MailService } = require('../dist/auth/mail.service.js');
const service = new MailService();

if (!service.configured()) {
  console.error('SMTP nao configurado. Rode scripts/configurar-email-local.ps1 primeiro.');
  process.exit(1);
}

try {
  await service.sendEmailVerificationCode(to, '123456');
  console.log(`E-mail de teste enviado para ${to}.`);
} catch (error) {
  console.error('Falha ao enviar e-mail de teste.');
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}

function loadLocalEnv() {
  const file = resolve(import.meta.dirname, '..', '.env.local');
  if (!existsSync(file)) return;

  const lines = readFileSync(file, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const separator = trimmed.indexOf('=');
    if (separator <= 0) continue;

    const key = trimmed.slice(0, separator).trim();
    let value = trimmed.slice(separator + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}
