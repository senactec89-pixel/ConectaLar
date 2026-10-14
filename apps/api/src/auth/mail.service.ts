import { Socket, connect as netConnect } from 'node:net';
import { TLSSocket, connect as tlsConnect } from 'node:tls';
import { Injectable } from '@nestjs/common';

interface SmtpConfig {
  readonly host: string;
  readonly port: number;
  readonly secure: boolean;
  readonly startTls: boolean;
  readonly user: string | null;
  readonly password: string | null;
  readonly from: string;
}

@Injectable()
export class MailService {
  configured(): boolean {
    return smtpConfig() !== null;
  }

  async sendPasswordResetEmail(email: string, codigo: string): Promise<boolean> {
    const config = smtpConfig();
    if (config === null) return false;

    const message = buildMessage({
      from: config.from,
      to: email,
      subject: 'Recuperacao de senha do ConectaLar',
      text:
        'Recebemos uma solicitacao para redefinir sua senha no ConectaLar.\n\n' +
        `Codigo de recuperacao: ${codigo}\n\n` +
        'Esse codigo expira em 30 minutos.\n\n' +
        'Se voce nao pediu isso, ignore este e-mail. Nunca compartilhe este codigo ou link.',
    });

    await sendSmtp(config, email, message);
    return true;
  }

  async sendEmailVerificationCode(
    email: string,
    codigo: string,
  ): Promise<boolean> {
    const config = smtpConfig();
    if (config === null) return false;

    const message = buildMessage({
      from: config.from,
      to: email,
      subject: 'Confirme seu e-mail no ConectaLar',
      text:
        'Use o codigo abaixo para confirmar seu e-mail no ConectaLar.\n\n' +
        `Codigo de confirmacao: ${codigo}\n\n` +
        'Esse codigo expira em 15 minutos. Se voce nao criou uma conta, ignore este e-mail.',
    });

    await sendSmtp(config, email, message);
    return true;
  }
}

function smtpConfig(): SmtpConfig | null {
  const host = process.env.SMTP_HOST?.trim();
  const from = process.env.SMTP_FROM?.trim();
  if (!host || !from) return null;
  const port = Number(process.env.SMTP_PORT ?? '587');
  if (!Number.isInteger(port) || port <= 0 || port > 65_535) return null;
  const user = process.env.SMTP_USER?.trim() || null;
  const password = process.env.SMTP_PASSWORD ?? null;
  return {
    host,
    port,
    secure: process.env.SMTP_SECURE === 'true',
    startTls: process.env.SMTP_STARTTLS !== 'false',
    user,
    password,
    from,
  };
}

function buildMessage(input: {
  readonly from: string;
  readonly to: string;
  readonly subject: string;
  readonly text: string;
}): string {
  return [
    `From: ${input.from}`,
    `To: ${input.to}`,
    `Subject: ${input.subject}`,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=utf-8',
    'Content-Transfer-Encoding: 8bit',
    '',
    input.text,
  ].join('\r\n');
}

async function sendSmtp(
  config: SmtpConfig,
  to: string,
  message: string,
): Promise<void> {
  const client = new SmtpClient(config);
  await client.connect();
  try {
    await client.command(`EHLO ${process.env.SMTP_EHLO_NAME ?? 'localhost'}`, 250);
    if (!config.secure && config.startTls) {
      await client.command('STARTTLS', 220);
      client.upgradeToTls();
      await client.command(`EHLO ${process.env.SMTP_EHLO_NAME ?? 'localhost'}`, 250);
    }
    if (config.user !== null && config.password !== null) {
      await client.command('AUTH LOGIN', 334);
      await client.command(Buffer.from(config.user).toString('base64'), 334);
      await client.command(Buffer.from(config.password).toString('base64'), 235);
    }
    await client.command(`MAIL FROM:<${addressOnly(config.from)}>`, 250);
    await client.command(`RCPT TO:<${addressOnly(to)}>`, 250);
    await client.command('DATA', 354);
    await client.command(`${message.replace(/\r?\n\./g, '\r\n..')}\r\n.`, 250);
    await client.command('QUIT', 221);
  } finally {
    client.close();
  }
}

class SmtpClient {
  private socket: Socket | TLSSocket | null = null;
  private buffer = '';

  constructor(private readonly config: SmtpConfig) {}

  async connect(): Promise<void> {
    this.socket = this.config.secure
      ? tlsConnect({
          host: this.config.host,
          port: this.config.port,
          servername: this.config.host,
        })
      : netConnect({ host: this.config.host, port: this.config.port });
    this.socket.setEncoding('utf8');
    this.socket.on('data', (chunk: string) => {
      this.buffer += chunk;
    });
    await onceConnected(this.socket);
    await this.readCode(220);
  }

  upgradeToTls(): void {
    const current = this.socket;
    if (current === null) throw new Error('SMTP connection is closed.');
    this.socket = tlsConnect({
      socket: current,
      servername: this.config.host,
    });
    this.socket.setEncoding('utf8');
    this.socket.on('data', (chunk: string) => {
      this.buffer += chunk;
    });
  }

  async command(command: string, expectedCode: number): Promise<void> {
    if (this.socket === null) throw new Error('SMTP connection is closed.');
    this.socket.write(`${command}\r\n`);
    await this.readCode(expectedCode);
  }

  close(): void {
    this.socket?.destroy();
    this.socket = null;
  }

  private async readCode(expectedCode: number): Promise<void> {
    const deadline = Date.now() + 10_000;
    while (Date.now() < deadline) {
      const lines = this.buffer.split(/\r\n/);
      for (let index = 0; index < lines.length; index++) {
        const line = lines[index];
        if (line === undefined || !/^\d{3}[ -]/.test(line)) continue;
        const code = Number(line.slice(0, 3));
        if (line[3] === '-') continue;
        this.buffer = lines.slice(index + 1).join('\r\n');
        if (code !== expectedCode) {
          throw new Error(`SMTP respondeu ${code}; esperado ${expectedCode}.`);
        }
        return;
      }
      await delay(25);
    }
    throw new Error('Tempo esgotado aguardando SMTP.');
  }
}

function onceConnected(socket: Socket | TLSSocket): Promise<void> {
  if (socket.connecting === false) return Promise.resolve();
  return new Promise((resolve, reject) => {
    socket.once('connect', resolve);
    socket.once('secureConnect', resolve);
    socket.once('error', reject);
  });
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function addressOnly(value: string): string {
  const match = /<([^>]+)>/.exec(value);
  return (match?.[1] ?? value).trim();
}
