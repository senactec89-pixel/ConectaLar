import { createHmac } from 'node:crypto';

const baseUrl = process.env.CONECTALAR_API_URL ?? 'http://127.0.0.1:3012';
const adminEmail =
  process.env.CONECTALAR_ADMIN_EMAIL ?? 'admin.demo@conectalar.local';
const adminSenha = process.env.CONECTALAR_ADMIN_SENHA ?? 'ConectaLarDemo123!';

const ctx = {};

try {
  await step('Login admin inicial sem MFA obrigatorio', async () => {
    const data = await request('POST', 'auth/login', null, {
      email: adminEmail,
      senha: adminSenha,
    });
    if (data.mfaRequired === true) {
      throw new Error('A conta admin ja esta com MFA ativo; desative antes do diagnostico.');
    }
    ctx.adminToken = data.token.accessToken;
    return adminEmail;
  });

  await step('Iniciar MFA administrativo', async () => {
    const data = await request('POST', 'auth/mfa/admin/setup', ctx.adminToken);
    assertString(data.secret, 'secret');
    assertString(data.otpauthUrl, 'otpauthUrl');
    ctx.secret = data.secret;
    return 'segredo TOTP gerado e URL otpauth retornada';
  });

  await step('Confirmar MFA com codigo TOTP valido', async () => {
    const codigo = totp(ctx.secret);
    await request('POST', 'auth/mfa/admin/confirmar', ctx.adminToken, {
      codigo,
    });
    return 'MFA ativado';
  });

  await step('Login admin passa a exigir MFA', async () => {
    const data = await request('POST', 'auth/login', null, {
      email: adminEmail,
      senha: adminSenha,
    });
    if (data.mfaRequired !== true) {
      throw new Error('Login admin nao exigiu MFA depois da ativacao.');
    }
    assertString(data.mfaToken, 'mfaToken');
    ctx.mfaToken = data.mfaToken;
    return 'desafio MFA recebido';
  });

  await step('Codigo MFA incorreto e recusado', async () => {
    const response = await rawRequest('POST', 'auth/login/mfa', null, {
      mfaToken: ctx.mfaToken,
      codigo: '000000',
    });
    if (response.status !== 401) {
      throw new Error(`Esperado 401 para codigo invalido; recebido ${response.status}.`);
    }
    return 'codigo invalido recusado';
  });

  await step('Codigo MFA correto libera token admin', async () => {
    const data = await request('POST', 'auth/login/mfa', null, {
      mfaToken: ctx.mfaToken,
      codigo: totp(ctx.secret),
    });
    assertString(data.token?.accessToken, 'token.accessToken');
    ctx.adminTokenComMfa = data.token.accessToken;
    return 'token admin emitido apos MFA';
  });

  await step('Status informa MFA ativo', async () => {
    const data = await request('GET', 'auth/mfa/admin', ctx.adminTokenComMfa);
    if (data.mfaAtivo !== true) {
      throw new Error('Status MFA nao retornou ativo.');
    }
    return 'ativo';
  });

  await step('Desativar MFA com senha e codigo validos', async () => {
    await request('POST', 'auth/mfa/admin/desativar', ctx.adminTokenComMfa, {
      senhaAtual: adminSenha,
      codigo: totp(ctx.secret),
    });
    return 'MFA desativado para nao interferir nos testes manuais';
  });

  await step('Login admin volta a emitir token sem desafio', async () => {
    const data = await request('POST', 'auth/login', null, {
      email: adminEmail,
      senha: adminSenha,
    });
    if (data.mfaRequired === true) {
      throw new Error('MFA continuou ativo apos desativacao.');
    }
    assertString(data.token?.accessToken, 'token.accessToken');
    return 'login normal restaurado';
  });

  console.log('\nDiagnostico MFA concluido com sucesso.');
} catch (error) {
  console.error('\nDiagnostico MFA falhou.');
  console.error(error);
  process.exitCode = 1;
}

async function step(name, fn) {
  process.stdout.write(`- ${name}... `);
  const result = await fn();
  console.log(`ok${result === undefined ? '' : ` (${result})`}`);
}

async function request(method, path, token, body) {
  const response = await rawRequest(method, path, token, body);
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${method} /${path} falhou (${response.status}): ${JSON.stringify(data)}`);
  }
  return data;
}

async function rawRequest(method, path, token, body) {
  return fetch(`${baseUrl.replace(/\/$/, '')}/${path}`, {
    method,
    headers: {
      accept: 'application/json',
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
      ...(token === null ? {} : { authorization: `Bearer ${token}` }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

function assertString(value, field) {
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Resposta sem campo ${field}.`);
  }
}

function totp(secret) {
  const counter = Math.floor(Date.now() / 1000 / 30);
  return hotp(secret, counter);
}

function hotp(secret, counter) {
  const key = decodeBase32(secret);
  const buffer = Buffer.alloc(8);
  buffer.writeBigUInt64BE(BigInt(counter));
  const hmac = createHmac('sha1', key).update(buffer).digest();
  const offset = hmac[hmac.length - 1] & 0x0f;
  const binary =
    ((hmac[offset] & 0x7f) << 24) |
    (hmac[offset + 1] << 16) |
    (hmac[offset + 2] << 8) |
    hmac[offset + 3];
  return String(binary % 1_000_000).padStart(6, '0');
}

function decodeBase32(value) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const char of value.replace(/=+$/g, '').toUpperCase()) {
    const index = alphabet.indexOf(char);
    if (index === -1) throw new Error('Segredo TOTP invalido.');
    bits += index.toString(2).padStart(5, '0');
  }
  const bytes = [];
  for (let index = 0; index + 8 <= bits.length; index += 8) {
    bytes.push(Number.parseInt(bits.slice(index, index + 8), 2));
  }
  return Buffer.from(bytes);
}
