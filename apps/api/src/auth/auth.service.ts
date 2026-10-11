import {
  randomBytes,
  createHash,
  timingSafeEqual,
} from 'node:crypto';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { AuthenticatedUser } from './authenticated-user.js';
import { UsuarioSenhaResetEntity } from '../database/entities/usuario-senha-reset.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { UsuarioTipo, usuarioTiposPublicos } from '../domain/usuario-tipo.js';
import { PasswordService } from './password.service.js';
import { TokenService } from './token.service.js';

interface CadastroRequest {
  nome: string;
  email: string;
  senha: string;
  tipo: UsuarioTipo;
  telefone?: string | null;
}

interface LoginRequest {
  email: string;
  senha: string;
}

interface RecuperacaoSenhaRequest {
  email: string;
}

interface ConfirmarRecuperacaoSenhaRequest {
  token: string;
  novaSenha: string;
}

interface AlterarSenhaRequest {
  senhaAtual: string;
  novaSenha: string;
}

const resetTokenTtlMinutes = 30;

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(UsuarioSenhaResetEntity)
    private readonly senhaResets: Repository<UsuarioSenhaResetEntity>,
    @InjectRepository(UsuarioEntity)
    private readonly usuarios: Repository<UsuarioEntity>,
    private readonly passwordService: PasswordService,
    private readonly tokenService: TokenService,
  ) {}

  async cadastro(body: unknown) {
    const cadastro = parseCadastro(body);
    const email = normalizarEmail(cadastro.email);
    const existing = await this.usuarios.findOne({ where: { email } });
    if (existing !== null) {
      throw new ConflictException({
        code: 'CONTA_NAO_CRIADA',
        message: 'Nao foi possivel criar a conta com estes dados.',
      });
    }

    const usuario = this.usuarios.create({
      nome: cadastro.nome.trim(),
      email,
      telefone: cadastro.telefone?.trim() || null,
      tipo: cadastro.tipo,
      senhaHash: await this.passwordService.hash(cadastro.senha),
      ativo: true,
    });

    const saved = await this.usuarios.save(usuario);
    return this.authResponse(saved);
  }

  async login(body: unknown) {
    const login = parseLogin(body);
    const email = normalizarEmail(login.email);
    const usuario = await this.usuarios
      .createQueryBuilder('usuario')
      .addSelect('usuario.senhaHash')
      .where('usuario.email = :email', { email })
      .andWhere('usuario.ativo = :ativo', { ativo: true })
      .getOne();

    if (
      usuario === null ||
      !(await this.passwordService.verify(login.senha, usuario.senhaHash))
    ) {
      throw new UnauthorizedException({
        code: 'CREDENCIAIS_INVALIDAS',
        message: 'E-mail ou senha invalidos.',
      });
    }

    return this.authResponse(usuario);
  }

  async solicitarRecuperacaoSenha(body: unknown) {
    const input = parseRecuperacaoSenha(body);
    const email = normalizarEmail(input.email);
    const usuario = await this.usuarios.findOne({
      where: { email, ativo: true },
    });

    if (usuario === null) {
      return recuperacaoSolicitadaResponse(null);
    }

    const token = randomBytes(32).toString('base64url');
    const tokenHash = hashResetToken(token);
    await this.senhaResets.update(
      { usuarioId: usuario.id, usadoEm: IsNull() },
      { usadoEm: new Date() },
    );
    await this.senhaResets.save(
      this.senhaResets.create({
        usuarioId: usuario.id,
        tokenHash,
        expiraEm: new Date(Date.now() + resetTokenTtlMinutes * 60 * 1000),
        usadoEm: null,
      }),
    );

    return recuperacaoSolicitadaResponse(token);
  }

  async confirmarRecuperacaoSenha(body: unknown) {
    const input = parseConfirmarRecuperacaoSenha(body);
    const tokenHash = hashResetToken(input.token);
    const reset = await this.senhaResets.findOne({ where: { tokenHash } });
    if (
      reset === null ||
      reset.usadoEm !== null ||
      reset.expiraEm.getTime() <= Date.now()
    ) {
      throw invalidResetToken();
    }

    const usuario = await this.usuarios
      .createQueryBuilder('usuario')
      .addSelect('usuario.senhaHash')
      .where('usuario.id = :id', { id: reset.usuarioId })
      .andWhere('usuario.ativo = :ativo', { ativo: true })
      .getOne();
    if (usuario === null) {
      throw invalidResetToken();
    }

    usuario.senhaHash = await this.passwordService.hash(input.novaSenha);
    usuario.tokenVersion += 1;
    await this.usuarios.save(usuario);
    await this.senhaResets.update(
      { usuarioId: usuario.id, usadoEm: IsNull() },
      { usadoEm: new Date() },
    );

    return { ok: true };
  }

  async alterarSenha(user: AuthenticatedUser, body: unknown) {
    const input = parseAlterarSenha(body);
    const usuario = await this.usuarios
      .createQueryBuilder('usuario')
      .addSelect('usuario.senhaHash')
      .where('usuario.id = :id', { id: user.id })
      .andWhere('usuario.ativo = :ativo', { ativo: true })
      .getOne();
    if (
      usuario === null ||
      !(await this.passwordService.verify(input.senhaAtual, usuario.senhaHash))
    ) {
      throw new UnauthorizedException({
        code: 'SENHA_ATUAL_INVALIDA',
        message: 'Senha atual invalida.',
      });
    }

    if (safeEqualText(input.senhaAtual, input.novaSenha)) {
      throw badRequest('NOVA_SENHA_DEVE_SER_DIFERENTE');
    }

    usuario.senhaHash = await this.passwordService.hash(input.novaSenha);
    usuario.tokenVersion += 1;
    await this.usuarios.save(usuario);
    await this.senhaResets.update(
      { usuarioId: usuario.id, usadoEm: IsNull() },
      { usadoEm: new Date() },
    );

    return { ok: true };
  }

  async logout(user: AuthenticatedUser) {
    const usuario = await this.usuarios.findOne({
      where: { id: user.id, ativo: true },
    });
    if (usuario !== null) {
      usuario.tokenVersion += 1;
      await this.usuarios.save(usuario);
    }

    return { ok: true };
  }

  private authResponse(usuario: UsuarioEntity) {
    return {
      usuario: {
        id: usuario.id,
        nome: usuario.nome,
        email: usuario.email,
        telefone: usuario.telefone,
        tipo: usuario.tipo,
      },
      token: this.tokenService.createAccessToken(usuario),
    };
  }
}

function parseCadastro(body: unknown): CadastroRequest {
  const value = objectBody(body);
  const nome = stringField(value, 'nome');
  const email = stringField(value, 'email');
  const senha = stringField(value, 'senha');
  const tipo = stringField(value, 'tipo');
  const telefone = optionalStringField(value, 'telefone');

  if (nome.trim().length < 3 || nome.trim().length > 140) {
    throw badRequest('NOME_INVALIDO');
  }

  if (!emailValido(email)) {
    throw badRequest('EMAIL_INVALIDO');
  }

  if (senha.length < 8 || senha.length > 128) {
    throw badRequest('SENHA_INVALIDA');
  }

  if (!usuarioTiposPublicos.has(tipo)) {
    throw badRequest('TIPO_INVALIDO');
  }

  return {
    nome,
    email,
    senha,
    tipo: tipo as UsuarioTipo,
    telefone,
  };
}

function parseLogin(body: unknown): LoginRequest {
  const value = objectBody(body);
  const email = stringField(value, 'email');
  const senha = stringField(value, 'senha');

  if (!emailValido(email) || senha.length === 0) {
    throw new UnauthorizedException({
      code: 'CREDENCIAIS_INVALIDAS',
      message: 'E-mail ou senha invalidos.',
    });
  }

  return { email, senha };
}

function parseRecuperacaoSenha(body: unknown): RecuperacaoSenhaRequest {
  const value = objectBody(body);
  const email = stringField(value, 'email');
  if (!emailValido(email)) {
    throw badRequest('EMAIL_INVALIDO');
  }

  return { email };
}

function parseConfirmarRecuperacaoSenha(
  body: unknown,
): ConfirmarRecuperacaoSenhaRequest {
  const value = objectBody(body);
  const token = stringField(value, 'token');
  const novaSenha = stringField(value, 'novaSenha');
  validarSenha(novaSenha);
  if (token.length < 32 || token.length > 160) {
    throw invalidResetToken();
  }

  return { token, novaSenha };
}

function parseAlterarSenha(body: unknown): AlterarSenhaRequest {
  const value = objectBody(body);
  const senhaAtual = stringField(value, 'senhaAtual');
  const novaSenha = stringField(value, 'novaSenha');
  validarSenha(novaSenha);

  return { senhaAtual, novaSenha };
}

function objectBody(body: unknown): Record<string, unknown> {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw badRequest('CORPO_INVALIDO');
  }

  return body as Record<string, unknown>;
}

function stringField(value: Record<string, unknown>, key: string): string {
  const field = value[key];
  if (typeof field !== 'string' || field.trim().length === 0) {
    throw badRequest('CAMPO_OBRIGATORIO');
  }

  return field;
}

function optionalStringField(
  value: Record<string, unknown>,
  key: string,
): string | null {
  const field = value[key];
  if (field === undefined || field === null || field === '') {
    return null;
  }

  if (typeof field !== 'string') {
    throw badRequest('CAMPO_INVALIDO');
  }

  return field;
}

function normalizarEmail(email: string): string {
  return email.trim().toLowerCase();
}

function emailValido(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

function validarSenha(senha: string): void {
  if (senha.length < 8 || senha.length > 128) {
    throw badRequest('SENHA_INVALIDA');
  }
}

function hashResetToken(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

function recuperacaoSolicitadaResponse(token: string | null) {
  const response: { ok: true; devToken?: string } = { ok: true };
  if (
    token !== null &&
    process.env.NODE_ENV !== 'production' &&
    process.env.EXPOSE_PASSWORD_RESET_TOKEN === 'true'
  ) {
    response.devToken = token;
  }

  return response;
}

function safeEqualText(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

function invalidResetToken(): BadRequestException {
  return new BadRequestException({
    code: 'TOKEN_RECUPERACAO_INVALIDO',
    message: 'Token de recuperacao invalido ou expirado.',
  });
}

function badRequest(code: string): BadRequestException {
  return new BadRequestException({
    code,
    message: 'Dados invalidos.',
  });
}
