import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { PasswordService } from '../auth/password.service.js';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { AdminAuditoriaAcao } from '../domain/admin-auditoria-acao.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';

interface CriarAdministradorInput {
  readonly nome: string;
  readonly email: string;
  readonly senha: string;
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
    @InjectRepository(AdminAuditoriaEntity)
    private readonly auditoria: Repository<AdminAuditoriaEntity>,
    @InjectRepository(UsuarioEntity)
    private readonly usuarios: Repository<UsuarioEntity>,
    private readonly passwordService: PasswordService,
  ) {}

  async listar(query: Record<string, unknown>) {
    const tipo = optionalTipo(query.tipo);
    const ativo = optionalBooleanQuery(query.ativo);
    const termo = optionalText(query.termo, 120);

    const builder = this.usuarios
      .createQueryBuilder('usuario')
      .orderBy('usuario.criadoEm', 'DESC')
      .take(100);

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

    const usuarios = await builder.getMany();
    return { usuarios: usuarios.map(usuarioResponse) };
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

    const usuario = this.usuarios.create({
      nome: input.nome,
      email,
      telefone: input.telefone,
      telefoneNormalizado: input.telefoneNormalizado,
      tipo: UsuarioTipo.Administrador,
      senhaHash: await this.passwordService.hash(input.senha),
      ativo: true,
    });

    let saved: UsuarioEntity;
    try {
      saved = await this.usuarios.save(usuario);
    } catch (error) {
      if (isDuplicateError(error)) {
        throw new ConflictException({
          code: 'CONTA_NAO_CRIADA',
          message: 'Nao foi possivel criar a conta com estes dados.',
        });
      }
      throw error;
    }
    await this.registrarAuditoria({
      atorId: user.id,
      acao: AdminAuditoriaAcao.AdministradorCriado,
      alvoId: saved.id,
      detalhe: 'Conta administrativa criada por administrador autenticado.',
    });

    return { usuario: usuarioResponse(saved) };
  }

  async atualizarStatus(
    user: AuthenticatedUser,
    id: number,
    body: unknown,
  ) {
    const input = parseAtualizarStatus(body);
    const usuario = await this.usuarios.findOne({ where: { id } });
    if (usuario === null) {
      throw new NotFoundException({
        code: 'USUARIO_NAO_ENCONTRADO',
        message: 'Usuario nao encontrado.',
      });
    }

    if (usuario.id === user.id && !input.ativo) {
      throw badRequest('ADMIN_NAO_PODE_DESATIVAR_PROPRIA_CONTA');
    }

    if (
      usuario.tipo === UsuarioTipo.Administrador &&
      usuario.ativo &&
      !input.ativo
    ) {
      const adminsAtivos = await this.usuarios.count({
        where: { tipo: UsuarioTipo.Administrador, ativo: true },
      });
      if (adminsAtivos <= 1) {
        throw badRequest('ULTIMO_ADMIN_ATIVO');
      }
    }

    usuario.ativo = input.ativo;
    const saved = await this.usuarios.save(usuario);
    await this.registrarAuditoria({
      atorId: user.id,
      acao: input.ativo
        ? AdminAuditoriaAcao.UsuarioAtivado
        : AdminAuditoriaAcao.UsuarioDesativado,
      alvoId: saved.id,
      detalhe: input.motivo,
    });

    return { usuario: usuarioResponse(saved) };
  }

  private async registrarAuditoria(input: {
    readonly atorId: number;
    readonly acao: AdminAuditoriaAcao;
    readonly alvoId: number;
    readonly detalhe: string | null;
  }) {
    await this.auditoria.save(
      this.auditoria.create({
        atorId: input.atorId,
        acao: input.acao,
        alvoTipo: 'usuario',
        alvoId: input.alvoId,
        detalhe: input.detalhe,
      }),
    );
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
  const senha = textField(value, 'senha', 8, 128);
  const telefone = optionalText(value.telefone, 32);
  const telefoneNormalizado = normalizarTelefoneOpcional(telefone);

  if (!emailValido(email)) {
    throw badRequest('EMAIL_INVALIDO');
  }

  return { nome, email, senha, telefone, telefoneNormalizado };
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
