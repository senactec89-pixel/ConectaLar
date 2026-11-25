import { createHash } from 'node:crypto';
import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import {
  cert,
  getApps,
  initializeApp,
  type App,
} from 'firebase-admin/app';
import {
  getMessaging,
  type Messaging,
  type MulticastMessage,
} from 'firebase-admin/messaging';
import { In, Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { DispositivoPushEntity } from '../database/entities/dispositivo-push.entity.js';
import { NotificacaoEntity } from '../database/entities/notificacao.entity.js';

export const PUSH_MESSAGING = Symbol('PUSH_MESSAGING');

type PlataformaPush = 'android' | 'ios' | 'web';

@Injectable()
export class PushNotificacoesService {
  private readonly logger = new Logger(PushNotificacoesService.name);

  constructor(
    @InjectRepository(DispositivoPushEntity)
    private readonly dispositivos: Repository<DispositivoPushEntity>,
    @Inject(PUSH_MESSAGING)
    private readonly messaging: Messaging | null,
  ) {}

  async registrar(user: AuthenticatedUser, body: unknown) {
    const input = parseDispositivo(body);
    const tokenHash = hashToken(input.token);
    const existente = await this.dispositivos.findOne({ where: { tokenHash } });
    if (existente === null) {
      const total = await this.dispositivos.count({ where: { usuarioId: user.id } });
      if (total >= 10) {
        throw new ConflictException({
          code: 'LIMITE_DISPOSITIVOS_PUSH',
          message: 'Limite de dispositivos com notificacoes atingido.',
        });
      }
    }

    await this.dispositivos.upsert(
      {
        usuarioId: user.id,
        tokenHash,
        token: input.token,
        plataforma: input.plataforma,
      },
      ['tokenHash'],
    );
    return { ok: true };
  }

  async revogar(user: AuthenticatedUser, body: unknown) {
    const token = parseTokenField(body);
    await this.dispositivos.delete({
      usuarioId: user.id,
      tokenHash: hashToken(token),
    });
    return { ok: true };
  }

  async enviar(notificacao: NotificacaoEntity): Promise<void> {
    if (this.messaging === null) return;

    try {
      const dispositivos = await this.dispositivos.find({
        where: { usuarioId: notificacao.usuarioId },
        select: { id: true, token: true, tokenHash: true },
      });
      if (dispositivos.length === 0) return;

      const message: MulticastMessage = {
        tokens: dispositivos.map((item) => item.token),
        notification: {
          title: notificacao.titulo,
          body: notificacao.mensagem,
        },
        data: {
          notificationId: String(notificacao.id),
          resourceType: notificacao.recursoTipo ?? '',
          resourceId: notificacao.recursoId === null
            ? ''
            : String(notificacao.recursoId),
        },
        android: {
          priority: 'high',
          notification: { channelId: 'conectalar_updates' },
        },
        apns: { payload: { aps: { sound: 'default' } } },
      };
      const response = await this.messaging.sendEachForMulticast(message);
      const invalidHashes = response.responses.flatMap((item, index) => {
        const code = item.error?.code;
        return code === 'messaging/invalid-registration-token' ||
            code === 'messaging/registration-token-not-registered'
          ? [dispositivos[index]!.tokenHash]
          : [];
      });

      if (invalidHashes.length > 0) {
        await this.dispositivos.delete({
          usuarioId: notificacao.usuarioId,
          tokenHash: In(invalidHashes),
        });
      }
      if (response.failureCount > invalidHashes.length) {
        this.logger.warn('push_delivery_partially_failed');
      }
    } catch {
      this.logger.warn('push_delivery_failed');
    }
  }
}

export function criarMessagingFcm(): Messaging | null {
  if (process.env.FCM_ENABLED?.trim().toLowerCase() !== 'true') return null;

  const projectId = process.env.FCM_PROJECT_ID?.trim();
  const clientEmail = process.env.FCM_CLIENT_EMAIL?.trim();
  const privateKey = process.env.FCM_PRIVATE_KEY?.replace(/\\n/g, '\n').trim();
  if (!projectId || !clientEmail || !privateKey) {
    throw new Error('FCM_CONFIGURATION_INCOMPLETE');
  }

  let app: App | undefined = getApps().find(
    (candidate) => candidate.name === 'conectalar-fcm',
  );
  app ??= initializeApp(
    {
      credential: cert({ projectId, clientEmail, privateKey }),
      projectId,
    },
    'conectalar-fcm',
  );
  return getMessaging(app);
}

export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

function parseDispositivo(value: unknown): {
  token: string;
  plataforma: PlataformaPush;
} {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw invalidPushInput();
  }
  const body = value as Record<string, unknown>;
  const token = parseToken(body.token);
  const plataforma = body.plataforma;
  if (
    plataforma !== 'android' &&
    plataforma !== 'ios' &&
    plataforma !== 'web'
  ) {
    throw invalidPushInput();
  }
  return { token, plataforma };
}

function parseToken(value: unknown): string {
  if (
    typeof value !== 'string' ||
    value !== value.trim() ||
    value.length < 20 ||
    value.length > 4096 ||
    /[\s\x00-\x1f]/.test(value)
  ) {
    throw invalidPushInput();
  }
  return value;
}

function parseTokenField(value: unknown): string {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw invalidPushInput();
  }
  return parseToken((value as Record<string, unknown>).token);
}

function invalidPushInput(): BadRequestException {
  return new BadRequestException({
    code: 'DISPOSITIVO_PUSH_INVALIDO',
    message: 'Dados de notificacao do dispositivo invalidos.',
  });
}
