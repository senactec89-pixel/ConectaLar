import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { randomBytes, createHash } from 'node:crypto';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { EmailOutboxService } from '../auth/email-outbox.service.js';
import { MailService } from '../auth/mail.service.js';
import { PasswordService } from '../auth/password.service.js';
import { AdminConviteEntity } from '../database/entities/admin-convite.entity.js';
import { EmailOutboxEntity } from '../database/entities/email-outbox.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { registrarAuditoriaAdmin } from '../common/admin-auditoria.js';
import { paginationMetadata, parsePaginationQuery } from '../common/pagination.js';
import { AdminAuditoriaAcao } from '../domain/admin-auditoria-acao.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';

interface CriarAdministradorInput {
  readonly nome: string;
  readonly email: string;
  readonly telefone: string | null;
  readonly telefoneNormalizado: string | null;
}

interface AtualizarStatusInput {
  readonly ativo: boolean;
  readonly motivo: string | null;
}

@Injectable()
export class AdminUsuariosService {
  constructor(
    @InjectRepository(UsuarioEntity)
    private readonly usuarios: Repository<UsuarioEntity>,
    private readonly passwordService: PasswordService,
    private readonly mail: MailService,
    private readonly emailOutbox: EmailOutboxService,
  ) {}

  async listar(query: Record<string, unknown>) {
    const pagination = parsePaginationQuery(query, { defaultLimit: 20, maxLimit: 100 });
    const tipo = optionalTipo(query.tipo);
    const ativo = optionalBooleanQuery(query.ativo);
    const termo = optionalText(query.termo, 120);

    const builder = this.usuarios
      .createQueryBuilder('usuario')
      .orderBy('usuario.criadoEm', 'DESC')
      .addOrderBy('usuario.id', 'DESC')
      .skip(pagination.skip)
      .take(pagination.limite);

    if (tipo !== null) {
      builder.andWhere('usuario.tipo = :tipo', { tipo });
    }
    if (ativo !== null) {
      builder.andWhere('usuario.ativo = :ativo', { ativo });
    }
    if (termo !== null) {
      builder.andWhere(
        '(usuario.nome LIKE :termo OR usuario.email LIKE :termo)',
        { termo: `%${termo}%` },
      );
    }

    const [usuarios, total] = await builder.getManyAndCount();
    return {
      paginacao: paginationMetadata(pagination, total),
      usuarios: usuarios.map(usuarioResponse),
    };
  }

  async obter(id: number) {
    const usuario = await this.usuarios.findOne({ where: { id } });
    if (usuario === null) {
      throw new NotFoundException({
        code: 'USUARIO_NAO_ENCONTRADO',
        message: 'Usuario nao encontrado.',
      });
    }

    return { usuario: usuarioResponse(usuario) };
  }

  async criarAdministrador(user: AuthenticatedUser, body: unknown) {
    const input = parseCriarAdministrador(body);
    const email = normalizarEmail(input.email);
    if (process.env.NODE_ENV === 'production' && !this.mail.configured()) {
      throw new ServiceUnavailableException({
        code: 'EMAIL_CONVITE_INDISPONIVEL',
        message: 'Nao foi possivel enviar o convite neste momento.',
      });
    }
    const existing = await this.usuarios.findOne({ where: { email } });
    if (existing !== null) {
      throw new ConflictException({
        code: 'CONTA_NAO_CRIADA',
        message: 'Nao foi possivel criar a conta com estes dados.',
      });
    }
    if (input.telefoneNormalizado !== null) {
      const existingPhone = await this.usuarios.findOne({
        where: { telefoneNormalizado: input.telefoneNormalizado },
      });
      if (existingPhone !== null) {
        throw new ConflictException({
          code: 'CONTA_NAO_CRIADA',
          message: 'Nao foi possivel criar a conta com estes dados.',
        });
      }
    }

    const token = randomBytes(32).toString('base64url');
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const senhaDescartavel = await this.passwordService.hash(
      randomBytes(48).toString('base64url'),
    );
    let created: { usuario: UsuarioEntity; outboxId: number };
    try {
      created = await this.usuarios.manager.transaction(async (manager) => {
        const usuarios = manager.getRepository(UsuarioEntity);
        const usuario = await usuarios.save(usuarios.create({
          nome: input.nome,
          email,
          telefone: input.telefone,
          telefoneNormalizado: input.telefoneNormalizado,
          tipo: UsuarioTipo.Administrador,
          senhaHash: senhaDescartavel,
          emailVerificado: false,
          mfaAtivo: false,
          ativo: true,
        }));
        await manager.getRepository(AdminConviteEntity).save(
          manager.getRepository(AdminConviteEntity).create({
            usuarioId: usuario.id,
            convidadoPorId: user.id,
            tokenHash: createHash('sha256').update(token, 'utf8').digest('hex'),
            expiraEm: expiresAt,
            aceitoEm: null,
            canceladoEm: null,
          }),
        );
        const outbox = await manager.getRepository(EmailOutboxEntity).save(
          this.emailOutbox.criarRegistro(
            usuario.id,
            token,
            expiresAt,
            'convite_admin',
          ),
        );
        await registrarAuditoriaAdmin(manager, {
          atorId: user.id,
          acao: AdminAuditoriaAcao.AdministradorCriado,
          alvoTipo: 'usuario',
          alvoId: usuario.id,
          detalhe: {
            estado: 'convite_pendente',
            expiraEm: expiresAt.toISOString(),
            mfaObrigatorio: true,
            emailOutboxId: outbox.id,
          },
        });
        return { usuario, outboxId: outbox.id };
      });
    } catch (error) {
      if (isDuplicateError(error)) {
        throw new ConflictException({
          code: 'CONTA_NAO_CRIADA',
          message: 'Nao foi possivel criar a conta com estes dados.',
        });
      }
      throw error;
    }
    const emailEnviado = await this.emailOutbox.entregarAgora(created.outboxId);
    return {
      usuario: usuarioResponse(created.usuario),
      convite: {
        expiraEm: expiresAt.toISOString(),
        emailEnviado,
        estado: emailEnviado ? 'enviado' : 'aguardando_envio',
      },
    };
  }

  async atualizarStatus(
    user: AuthenticatedUser,
    id: number,
    body: unknown,
  ) {
    const input = parseAtualizarStatus(body);
    const saved = await this.usuarios.manager.transaction(async (manager) => {
      const usuarios = manager.getRepository(UsuarioEntity);
      const administradores = await usuarios
        .createQueryBuilder('usuario')
        .where('usuario.tipo = :tipo', { tipo: UsuarioTipo.Administrador })
        .orderBy('usuario.id', 'ASC')
        .setLock('pessimistic_write')
        .getMany();

      let usuario = administradores.find((item) => item.id === id) ?? null;
      if (usuario === null) {
        usuario = await usuarios
          .createQueryBuilder('usuario')
          .where('usuario.id = :id', { id })
          .setLock('pessimistic_write')
          .getOne();
      }
      if (usuario === null) {
        throw new NotFoundException({
          code: 'USUARIO_NAO_ENCONTRADO',
          message: 'Usuario nao encontrado.',
        });
      }

      if (usuario.id === user.id && !input.ativo) {
        throw badRequest('ADMIN_NAO_PODE_DESATIVAR_PROPRIA_CONTA');
      }

      const ativoAnterior = usuario.ativo;
      const tokenVersionAnterior = usuario.tokenVersion;

      if (
        usuario.tipo === UsuarioTipo.Administrador &&
        usuario.ativo &&
        !input.ativo &&
        administradores.filter((item) => item.ativo).length <= 1
      ) {
        throw badRequest('ULTIMO_ADMIN_ATIVO');
      }

      if (usuario.ativo !== input.ativo) {
        usuario.ativo = input.ativo;
        usuario.tokenVersion += 1;
      }
      const atualizado = await usuarios.save(usuario);
      await registrarAuditoriaAdmin(manager, {
        atorId: user.id,
        acao: input.ativo
          ? AdminAuditoriaAcao.UsuarioAtivado
          : AdminAuditoriaAcao.UsuarioDesativado,
        alvoTipo: 'usuario',
        alvoId: atualizado.id,
        detalhe: {
          antes: { ativo: ativoAnterior, tokenVersion: tokenVersionAnterior },
          depois: { ativo: atualizado.ativo, tokenVersion: atualizado.tokenVersion },
          motivo: input.motivo,
        },
      });
      return atualizado;
    });

    return { usuario: usuarioResponse(saved) };
  }
}

function usuarioResponse(usuario: UsuarioEntity) {
  return {
    id: usuario.id,
    nome: usuario.nome,
    email: usuario.email,
    telefone: usuario.telefone,
    tipo: usuario.tipo,
    ativo: usuario.ativo,
    criadoEm: usuario.criadoEm.toISOString(),
    atualizadoEm: usuario.atualizadoEm.toISOString(),
  };
}

function parseCriarAdministrador(body: unknown): CriarAdministradorInput {
  const value = objectBody(body);
  const nome = textField(value, 'nome', 3, 140);
  const email = textField(value, 'email', 5, 180);
  if ('senha' in value || 'senhaHash' in value || 'emailVerificado' in value || 'mfaAtivo' in value) {
    throw badRequest('CAMPO_INVALIDO');
  }
  const telefone = optionalText(value.telefone, 32);
  const telefoneNormalizado = normalizarTelefoneOpcional(telefone);

  if (!emailValido(email)) {
    throw badRequest('EMAIL_INVALIDO');
  }

  return { nome, email, telefone, telefoneNormalizado };
}

function parseAtualizarStatus(body: unknown): AtualizarStatusInput {
  const value = objectBody(body);
  if (typeof value.ativo !== 'boolean') {
    throw badRequest('STATUS_INVALIDO');
  }

  return {
    ativo: value.ativo,
    motivo: optionalText(value.motivo, 600),
  };
}

function optionalTipo(value: unknown): UsuarioTipo | null {
  if (value === undefined || value === null || value === '') return null;
  if (Object.values(UsuarioTipo).includes(value as UsuarioTipo)) {
    return value as UsuarioTipo;
  }

  throw badRequest('TIPO_INVALIDO');
}

function optionalBooleanQuery(value: unknown): boolean | null {
  if (value === undefined || value === null || value === '') return null;
  if (value === 'true' || value === true) return true;
  if (value === 'false' || value === false) return false;
  throw badRequest('FILTRO_INVALIDO');
}

function objectBody(body: unknown): Record<string, unknown> {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw badRequest('CORPO_INVALIDO');
  }

  return body as Record<string, unknown>;
}

function textField(
  value: Record<string, unknown>,
  key: string,
  min: number,
  max: number,
): string {
  const field = value[key];
  if (typeof field !== 'string') {
    throw badRequest('CAMPO_INVALIDO');
  }

  const text = field.trim();
  if (text.length < min || text.length > max) {
    throw badRequest('CAMPO_INVALIDO');
  }

  return text;
}

function optionalText(value: unknown, max: number): string | null {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string') throw badRequest('CAMPO_INVALIDO');
  const text = value.trim();
  if (text.length === 0) return null;
  if (text.length > max) throw badRequest('CAMPO_INVALIDO');
  return text;
}

function normalizarTelefoneOpcional(telefone: string | null): string | null {
  if (telefone === null) return null;
  let digits = telefone.replace(/\D/g, '');
  if (digits.startsWith('55') && (digits.length === 12 || digits.length === 13)) {
    digits = digits.slice(2);
  }
  if (digits.length !== 10 && digits.length !== 11) {
    throw badRequest('TELEFONE_INVALIDO');
  }
  return digits;
}

function isDuplicateError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { readonly code?: unknown }).code === 'ER_DUP_ENTRY'
  );
}

function normalizarEmail(email: string): string {
  return email.trim().toLowerCase();
}

function emailValido(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

function badRequest(code: string): BadRequestException {
  return new BadRequestException({
    code,
    message: 'Dados invalidos.',
  });
}
