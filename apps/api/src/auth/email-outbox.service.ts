import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnApplicationShutdown,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from 'node:crypto';
import { IsNull, LessThanOrEqual, Repository } from 'typeorm';
import { EmailOutboxEntity } from '../database/entities/email-outbox.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { MailService } from './mail.service.js';

const intervaloProcessamentoMs = 60_000;
const travaExpiraMs = 5 * 60_000;
const maxTentativas = 8;

@Injectable()
export class EmailOutboxService
  implements OnApplicationBootstrap, OnApplicationShutdown
{
  private readonly logger = new Logger(EmailOutboxService.name);
  private timer: NodeJS.Timeout | null = null;
  private processando = false;

  constructor(
    @InjectRepository(EmailOutboxEntity)
    private readonly outbox: Repository<EmailOutboxEntity>,
    @InjectRepository(UsuarioEntity)
    private readonly usuarios: Repository<UsuarioEntity>,
    private readonly mail: MailService,
  ) {}

  onApplicationBootstrap(): void {
    this.timer = setInterval(() => void this.processarPendentes(), intervaloProcessamentoMs);
    this.timer.unref();
    void this.processarPendentes();
  }

  onApplicationShutdown(): void {
    if (this.timer !== null) clearInterval(this.timer);
    this.timer = null;
  }

  criarRegistro(
    usuarioId: number,
    codigo: string,
    expiraEm: Date,
    tipo: 'verificacao_email' | 'convite_admin' = 'verificacao_email',
  ): EmailOutboxEntity {
    return this.outbox.create({
      usuarioId,
      tipo,
      payloadCriptografado: criptografarCodigoOutbox(codigo),
      tentativas: 0,
      proximaTentativaEm: new Date(),
      processandoEm: null,
      expiraEm,
      enviadoEm: null,
      canceladoEm: null,
      ultimoErro: null,
    });
  }

  async entregarAgora(id: number): Promise<boolean> {
    const claimed = await this.reivindicar(id);
    if (!claimed) return false;
    return this.entregar(id);
  }

  async cancelarPendentes(usuarioId: number): Promise<void> {
    await this.outbox.update(
      { usuarioId, enviadoEm: IsNull(), canceladoEm: IsNull() },
      {
        canceladoEm: new Date(),
        processandoEm: null,
        payloadCriptografado: '',
      },
    );
  }

  private async processarPendentes(): Promise<void> {
    if (this.processando) return;
    this.processando = true;
    try {
      const agora = new Date();
      const itens = await this.outbox.find({
        where: {
          enviadoEm: IsNull(),
          canceladoEm: IsNull(),
          proximaTentativaEm: LessThanOrEqual(agora),
        },
        order: { criadoEm: 'ASC' },
        take: 20,
      });
      for (const item of itens) {
        if (await this.reivindicar(item.id)) await this.entregar(item.id);
      }
    } catch {
      this.logger.warn('email_outbox_processing_failed');
    } finally {
      this.processando = false;
    }
  }

  private async reivindicar(id: number): Promise<boolean> {
    const agora = new Date();
    const travaExpirada = new Date(agora.getTime() - travaExpiraMs);
    const result = await this.outbox
      .createQueryBuilder()
      .update(EmailOutboxEntity)
      .set({ processandoEm: agora })
      .where('id = :id', { id })
      .andWhere('enviado_em IS NULL')
      .andWhere('cancelado_em IS NULL')
      .andWhere('proxima_tentativa_em <= :agora', { agora })
      .andWhere('(processando_em IS NULL OR processando_em < :travaExpirada)', {
        travaExpirada,
      })
      .execute();
    return result.affected === 1;
  }

  private async entregar(id: number): Promise<boolean> {
    const item = await this.outbox.findOne({ where: { id } });
    if (item === null || item.enviadoEm !== null || item.canceladoEm !== null) {
      return false;
    }
    if (item.expiraEm.getTime() <= Date.now() || item.tentativas >= maxTentativas) {
      await this.outbox.update(id, {
        canceladoEm: new Date(),
        processandoEm: null,
        payloadCriptografado: '',
        ultimoErro: 'DELIVERY_EXPIRED',
      });
      return false;
    }

    try {
      const usuario = await this.usuarios.findOne({
        where: { id: item.usuarioId, ativo: true },
      });
      if (usuario === null || usuario.emailVerificado) {
        await this.outbox.update(id, {
          canceladoEm: new Date(),
          processandoEm: null,
          payloadCriptografado: '',
        });
        return false;
      }
      const codigo = descriptografarCodigoOutbox(item.payloadCriptografado);
      const enviado = item.tipo === 'convite_admin'
        ? await this.mail.sendAdminInvitation(usuario.email, usuario.nome, codigo)
        : await this.mail.sendEmailVerificationCode(usuario.email, codigo);
      if (!enviado) throw new Error('SMTP_UNAVAILABLE');
      await this.outbox.update(id, {
        enviadoEm: new Date(),
        processandoEm: null,
        payloadCriptografado: '',
        ultimoErro: null,
      });
      return true;
    } catch {
      const tentativas = item.tentativas + 1;
      const cancelar = tentativas >= maxTentativas || item.expiraEm.getTime() <= Date.now();
      await this.outbox.update(id, {
        tentativas,
        processandoEm: null,
        proximaTentativaEm: new Date(Date.now() + atrasoTentativaMs(tentativas)),
        canceladoEm: cancelar ? new Date() : null,
        payloadCriptografado: cancelar ? '' : item.payloadCriptografado,
        ultimoErro: 'DELIVERY_FAILED',
      });
      this.logger.warn('email_outbox_delivery_failed');
      return false;
    }
  }
}

export function criptografarCodigoOutbox(codigo: string): string {
  const nonce = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', chaveOutbox(), nonce);
  const encrypted = Buffer.concat([cipher.update(codigo, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return ['v1', nonce, tag, encrypted].map((value) =>
    typeof value === 'string' ? value : value.toString('base64url')
  ).join('.');
}

export function descriptografarCodigoOutbox(payload: string): string {
  const [versao, nonce, tag, encrypted] = payload.split('.');
  if (versao !== 'v1' || !nonce || !tag || !encrypted) {
    throw new Error('EMAIL_OUTBOX_PAYLOAD_INVALID');
  }
  const decipher = createDecipheriv(
    'aes-256-gcm',
    chaveOutbox(),
    Buffer.from(nonce, 'base64url'),
  );
  decipher.setAuthTag(Buffer.from(tag, 'base64url'));
  return Buffer.concat([
    decipher.update(Buffer.from(encrypted, 'base64url')),
    decipher.final(),
  ]).toString('utf8');
}

function chaveOutbox(): Buffer {
  const production = process.env.NODE_ENV === 'production';
  const secret = production
    ? process.env.EMAIL_OUTBOX_ENCRYPTION_KEY?.trim()
    : process.env.EMAIL_OUTBOX_ENCRYPTION_KEY?.trim() ||
      process.env.MFA_SECRET_ENCRYPTION_KEY?.trim() ||
      process.env.AUTH_TOKEN_SECRET?.trim();
  if (!secret || secret.length < 32) {
    throw new Error('Email outbox encryption is not configured.');
  }
  return createHash('sha256')
    .update('conectalar-email-outbox-v1\0', 'utf8')
    .update(secret, 'utf8')
    .digest();
}

function atrasoTentativaMs(tentativas: number): number {
  return Math.min(8 * 60_000, 30_000 * 2 ** Math.max(0, tentativas - 1));
}
