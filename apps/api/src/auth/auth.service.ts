import { randomInt, createHash, timingSafeEqual } from 'node:crypto';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { AuthenticatedUser } from './authenticated-user.js';
import { UsuarioEmailVerificacaoEntity } from '../database/entities/usuario-email-verificacao.entity.js';
import { UsuarioSenhaResetEntity } from '../database/entities/usuario-senha-reset.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { UsuarioTipo, usuarioTiposPublicos } from '../domain/usuario-tipo.js';
import { MailService } from './mail.service.js';
import { MfaService } from './mfa.service.js';
import { PasswordService } from './password.service.js';
import { TokenService } from './token.service.js';

interface CadastroRequest {
  nome: string;
  email: string;
  senha: string;
  tipo: UsuarioTipo;
  telefone?: string | null;
  telefoneNormalizado?: string | null;
}

interface LoginRequest {
  email: string;
  senha: string;
}

interface RecuperacaoSenhaRequest {
  email: string;
}

interface ConfirmarRecuperacaoSenhaRequest {
  email: string;
  token: string;
  novaSenha: string;
}

interface ConfirmarEmailRequest {
  codigo: string;
}

interface AlterarSenhaRequest {
  senhaAtual: string;
  novaSenha: string;
}

interface MfaLoginRequest {
  mfaToken: string;
  codigo: string;
}

interface MfaCodigoRequest {
  codigo: string;
}

interface MfaDesativarRequest {
  senhaAtual: string;
  codigo: string;
}

const resetTokenTtlMinutes = 30;
const emailVerificationTtlMinutes = 15;

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(UsuarioEmailVerificacaoEntity)
    private readonly emailVerificacoes: Repository<UsuarioEmailVerificacaoEntity>,
    @InjectRepository(UsuarioSenhaResetEntity)
    private readonly senhaResets: Repository<UsuarioSenhaResetEntity>,
    @InjectRepository(UsuarioEntity)
    private readonly usuarios: Repository<UsuarioEntity>,
    private readonly mailService: MailService,
    private readonly mfaService: MfaService,
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
    if (cadastro.telefoneNormalizado !== null) {
      const existingPhone = await this.usuarios.findOne({
        where: { telefoneNormalizado: cadastro.telefoneNormalizado },
      });
      if (existingPhone !== null) {
        throw new ConflictException({
          code: 'CONTA_NAO_CRIADA',
          message: 'Nao foi possivel criar a conta com estes dados.',
        });
      }
    }
    if (process.env.NODE_ENV === 'production' && !this.mailService.configured()) {
      throw new ServiceUnavailableException({
        code: 'EMAIL_VERIFICACAO_INDISPONIVEL',
        message: 'Servico de verificacao de e-mail indisponivel no momento.',
      });
    }

    const usuario = this.usuarios.create({
      nome: cadastro.nome.trim(),
      email,
      telefone: cadastro.telefone?.trim() || null,
      telefoneNormalizado: cadastro.telefoneNormalizado ?? null,
      tipo: cadastro.tipo,
      senhaHash: await this.passwordService.hash(cadastro.senha),
      emailVerificado: false,
      ativo: true,
    });

    try {
      const saved = await this.usuarios.save(usuario);
      const verificacao = await this.enviarCodigoVerificacaoEmail(saved);
      return {
        ...this.authResponse(saved),
        emailVerificationRequired: true,
        ...verificacao,
      };
    } catch (error) {
      if (isDuplicateError(error)) {
        throw new ConflictException({
          code: 'CONTA_NAO_CRIADA',
          message: 'Nao foi possivel criar a conta com estes dados.',
        });
      }
      throw error;
    }
  }

  async login(body: unknown) {
    const login = parseLogin(body);
    const email = normalizarEmail(login.email);
    const usuario = await this.usuarios
      .createQueryBuilder('usuario')
      .addSelect('usuario.senhaHash')
      .addSelect('usuario.mfaSecretEncrypted')
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

    if (usuario.tipo === UsuarioTipo.Administrador && usuario.mfaAtivo) {
      return {
        mfaRequired: true,
        ...this.tokenService.createMfaChallengeToken(usuario),
      };
    }

    return this.authResponse(usuario);
  }

  async confirmarLoginMfa(body: unknown) {
    const input = parseMfaLogin(body);
    const payload = this.tokenService.verifyMfaChallengeToken(input.mfaToken);
    if (payload === null) {
      throw invalidMfaCode();
    }

    const usuario = await this.usuarios
      .createQueryBuilder('usuario')
      .addSelect('usuario.mfaSecretEncrypted')
      .where('usuario.id = :id', { id: payload.sub })
      .andWhere('usuario.ativo = :ativo', { ativo: true })
      .getOne();
    if (
      usuario === null ||
      usuario.tipo !== UsuarioTipo.Administrador ||
      !usuario.mfaAtivo ||
      usuario.tokenVersion !== payload.tv ||
      usuario.mfaSecretEncrypted === null ||
      !this.verificarCodigoMfa(usuario.mfaSecretEncrypted, input.codigo)
    ) {
      throw invalidMfaCode();
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

    const codigo = criarCodigoNumerico();
    const tokenHash = hashResetCode(usuario.id, codigo);
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

    const delivered = await this.enviarEmailComFalhaControlada(() =>
      this.mailService.sendPasswordResetEmail(usuario.email, codigo),
    );
    if (!delivered && process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException({
        code: 'EMAIL_RECUPERACAO_INDISPONIVEL',
        message: 'Servico de recuperacao indisponivel no momento.',
      });
    }

    return recuperacaoSolicitadaResponse(codigo);
  }

  async statusVerificacaoEmail(user: AuthenticatedUser) {
    const usuario = await this.usuarioAtivo(user.id);
    return { emailVerificado: usuario.emailVerificado };
  }

  async solicitarVerificacaoEmail(user: AuthenticatedUser) {
    const usuario = await this.usuarioAtivo(user.id);
    if (usuario.emailVerificado) {
      return { ok: true, emailVerificado: true };
    }

    return {
      ok: true,
      emailVerificado: false,
      ...(await this.enviarCodigoVerificacaoEmail(usuario)),
    };
  }

  async confirmarVerificacaoEmail(
    user: AuthenticatedUser,
    body: unknown,
  ) {
    const input = parseConfirmarEmail(body);
    const usuario = await this.usuarioAtivo(user.id);
    if (usuario.emailVerificado) {
      return { ok: true, emailVerificado: true };
    }

    const codigoHash = hashEmailVerificationCode(usuario.id, input.codigo);
    const verificacao = await this.emailVerificacoes
      .createQueryBuilder('verificacao')
      .where('verificacao.usuarioId = :usuarioId', { usuarioId: usuario.id })
      .andWhere('verificacao.codigoHash = :codigoHash', { codigoHash })
      .andWhere('verificacao.usadoEm IS NULL')
      .orderBy('verificacao.criadoEm', 'DESC')
      .getOne();

    if (
      verificacao === null ||
      verificacao.expiraEm.getTime() <= Date.now()
    ) {
      throw invalidEmailVerificationCode();
    }

    usuario.emailVerificado = true;
    await this.usuarios.save(usuario);
    await this.emailVerificacoes.update(
      { usuarioId: usuario.id, usadoEm: IsNull() },
      { usadoEm: new Date() },
    );

    return { ok: true, emailVerificado: true };
  }

  async iniciarMfaAdmin(user: AuthenticatedUser) {
    const usuario = await this.usuarioAdminComMfa(user.id);
    if (usuario.mfaAtivo) {
      throw badRequest('MFA_JA_ATIVO');
    }
    const secret = this.mfaService.createSecret();
    usuario.mfaSecretEncrypted = this.mfaService.encryptSecret(secret);
    await this.usuarios.save(usuario);
    return {
      secret,
      otpauthUrl: this.mfaService.createOtpAuthUrl(secret, usuario.email),
    };
  }

  async confirmarMfaAdmin(user: AuthenticatedUser, body: unknown) {
    const input = parseMfaCodigo(body);
    const usuario = await this.usuarioAdminComMfa(user.id);
    if (usuario.mfaSecretEncrypted === null) {
      throw badRequest('MFA_NAO_INICIADO');
    }
    if (!this.verificarCodigoMfa(usuario.mfaSecretEncrypted, input.codigo)) {
      throw invalidMfaCode();
    }
    usuario.mfaAtivo = true;
    usuario.tokenVersion += 1;
    await this.usuarios.save(usuario);
    return { ok: true };
  }

  async desativarMfaAdmin(user: AuthenticatedUser, body: unknown) {
    const input = parseMfaDesativar(body);
    const usuario = await this.usuarios
      .createQueryBuilder('usuario')
      .addSelect('usuario.senhaHash')
      .addSelect('usuario.mfaSecretEncrypted')
      .where('usuario.id = :id', { id: user.id })
      .andWhere('usuario.ativo = :ativo', { ativo: true })
      .getOne();
    if (
      usuario === null ||
      usuario.tipo !== UsuarioTipo.Administrador ||
      !(await this.passwordService.verify(input.senhaAtual, usuario.senhaHash))
    ) {
      throw new UnauthorizedException({
        code: 'SENHA_ATUAL_INVALIDA',
        message: 'Senha atual invalida.',
      });
    }
    if (
      usuario.mfaSecretEncrypted === null ||
      !this.verificarCodigoMfa(usuario.mfaSecretEncrypted, input.codigo)
    ) {
      throw invalidMfaCode();
    }
    usuario.mfaAtivo = false;
    usuario.mfaSecretEncrypted = null;
    usuario.tokenVersion += 1;
    await this.usuarios.save(usuario);
    return { ok: true };
  }

  async statusMfaAdmin(user: AuthenticatedUser) {
    const usuario = await this.usuarios.findOne({
      where: { id: user.id, ativo: true },
    });
    return {
      mfaAtivo:
        usuario !== null &&
        usuario.tipo === UsuarioTipo.Administrador &&
        usuario.mfaAtivo,
    };
  }

  async confirmarRecuperacaoSenha(body: unknown) {
    const input = parseConfirmarRecuperacaoSenha(body);
    const email = normalizarEmail(input.email);
    const usuario = await this.usuarios
      .createQueryBuilder('usuario')
      .addSelect('usuario.senhaHash')
      .where('usuario.email = :email', { email })
      .andWhere('usuario.ativo = :ativo', { ativo: true })
      .getOne();
    if (usuario === null) {
      throw invalidResetToken();
    }

    const tokenHash = hashResetCode(usuario.id, input.token);
    const reset = await this.senhaResets.findOne({
      where: { usuarioId: usuario.id, tokenHash },
    });
    if (
      reset === null ||
      reset.usadoEm !== null ||
      reset.expiraEm.getTime() <= Date.now()
    ) {
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
        emailVerificado: usuario.emailVerificado,
        telefone: usuario.telefone,
        tipo: usuario.tipo,
      },
      token: this.tokenService.createAccessToken(usuario),
    };
  }

  private async usuarioAtivo(id: number): Promise<UsuarioEntity> {
    const usuario = await this.usuarios.findOne({
      where: { id, ativo: true },
    });
    if (usuario === null) {
      throw new UnauthorizedException({
        code: 'SESSAO_INVALIDA',
        message: 'Sua sessao expirou. Entre novamente.',
      });
    }
    return usuario;
  }

  private async enviarCodigoVerificacaoEmail(usuario: UsuarioEntity) {
    const codigo = criarCodigoNumerico();
    await this.emailVerificacoes.update(
      { usuarioId: usuario.id, usadoEm: IsNull() },
      { usadoEm: new Date() },
    );
    await this.emailVerificacoes.save(
      this.emailVerificacoes.create({
        usuarioId: usuario.id,
        codigoHash: hashEmailVerificationCode(usuario.id, codigo),
        expiraEm: new Date(
          Date.now() + emailVerificationTtlMinutes * 60 * 1000,
        ),
        usadoEm: null,
      }),
    );

    const delivered = await this.enviarEmailComFalhaControlada(() =>
      this.mailService.sendEmailVerificationCode(usuario.email, codigo),
    );
    if (!delivered && process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException({
        code: 'EMAIL_VERIFICACAO_INDISPONIVEL',
        message: 'Servico de verificacao de e-mail indisponivel no momento.',
      });
    }

    const response: { emailVerificationSent: boolean; devCode?: string } = {
      emailVerificationSent: delivered,
    };
    if (
      !delivered &&
      process.env.NODE_ENV !== 'production' &&
      process.env.EXPOSE_EMAIL_VERIFICATION_CODE === 'true'
    ) {
      response.devCode = codigo;
    }
    return response;
  }

  private async enviarEmailComFalhaControlada(
    send: () => Promise<boolean>,
  ): Promise<boolean> {
    try {
      return await send();
    } catch {
      if (process.env.NODE_ENV === 'production') {
        throw new ServiceUnavailableException({
          code: 'EMAIL_INDISPONIVEL',
          message: 'Servico de e-mail indisponivel no momento.',
        });
      }
      return false;
    }
  }

  private async usuarioAdminComMfa(id: number): Promise<UsuarioEntity> {
    const usuario = await this.usuarios
      .createQueryBuilder('usuario')
      .addSelect('usuario.mfaSecretEncrypted')
      .where('usuario.id = :id', { id })
      .andWhere('usuario.ativo = :ativo', { ativo: true })
      .getOne();
    if (usuario === null || usuario.tipo !== UsuarioTipo.Administrador) {
      throw new UnauthorizedException({
        code: 'ACESSO_NEGADO',
        message: 'Usuario sem permissao para este recurso.',
      });
    }
    return usuario;
  }

  private verificarCodigoMfa(secretEncrypted: string, codigo: string): boolean {
    const secret = this.mfaService.decryptSecret(secretEncrypted);
    return secret !== null && this.mfaService.verifyCode(secret, codigo);
  }
}

function parseCadastro(body: unknown): CadastroRequest {
  const value = objectBody(body);
  const nome = stringField(value, 'nome');
  const email = stringField(value, 'email');
  const senha = stringField(value, 'senha');
  const tipo = stringField(value, 'tipo');
  const telefone = optionalStringField(value, 'telefone');
  const telefoneNormalizado = normalizarTelefoneOpcional(telefone);

  if (nome.trim().length < 3 || nome.trim().length > 140) {
    throw badRequest('NOME_INVALIDO');
  }

  if (!emailValido(email)) {
    throw badRequest('EMAIL_INVALIDO');
  }

  validarSenha(senha);

  if (!usuarioTiposPublicos.has(tipo)) {
    throw badRequest('TIPO_INVALIDO');
  }

  return {
    nome,
    email,
    senha,
    tipo: tipo as UsuarioTipo,
    telefone,
    telefoneNormalizado,
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
  const email = stringField(value, 'email');
  const token = stringField(value, 'token').replace(/\s/g, '');
  const novaSenha = stringField(value, 'novaSenha');
  validarSenha(novaSenha);
  if (!emailValido(email) || !/^\d{6}$/.test(token)) {
    throw invalidResetToken();
  }

  return { email, token, novaSenha };
}

function parseConfirmarEmail(body: unknown): ConfirmarEmailRequest {
  const value = objectBody(body);
  const codigo = stringField(value, 'codigo').replace(/\s/g, '');
  if (!/^\d{6}$/.test(codigo)) {
    throw invalidEmailVerificationCode();
  }
  return { codigo };
}

function parseMfaLogin(body: unknown): MfaLoginRequest {
  const value = objectBody(body);
  const mfaToken = stringField(value, 'mfaToken');
  const codigo = stringField(value, 'codigo').replace(/\s/g, '');
  if (mfaToken.length > 1200 || !/^\d{6}$/.test(codigo)) {
    throw invalidMfaCode();
  }
  return { mfaToken, codigo };
}

function parseMfaCodigo(body: unknown): MfaCodigoRequest {
  const value = objectBody(body);
  const codigo = stringField(value, 'codigo').replace(/\s/g, '');
  if (!/^\d{6}$/.test(codigo)) {
    throw invalidMfaCode();
  }
  return { codigo };
}

function parseMfaDesativar(body: unknown): MfaDesativarRequest {
  const value = objectBody(body);
  const senhaAtual = stringField(value, 'senhaAtual');
  const codigo = stringField(value, 'codigo').replace(/\s/g, '');
  if (!/^\d{6}$/.test(codigo)) {
    throw invalidMfaCode();
  }
  return { senhaAtual, codigo };
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

function emailValido(email: string): boolean {
  return /^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$/.test(
    email.trim(),
  );
}

function validarSenha(senha: string): void {
  if (
    senha.length < 8 ||
    senha.length > 128 ||
    !/[A-Z]/.test(senha) ||
    !/[a-z]/.test(senha) ||
    !/\d/.test(senha) ||
    !/[^A-Za-z0-9]/.test(senha)
  ) {
    throw badRequest('SENHA_INVALIDA');
  }
}

function hashResetCode(usuarioId: number, codigo: string): string {
  return createHash('sha256')
    .update(`${usuarioId}:${codigo}`, 'utf8')
    .digest('hex');
}

function hashEmailVerificationCode(usuarioId: number, codigo: string): string {
  return createHash('sha256')
    .update(`${usuarioId}:${codigo}`, 'utf8')
    .digest('hex');
}

function criarCodigoNumerico(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, '0');
}

function recuperacaoSolicitadaResponse(codigo: string | null) {
  const response: { ok: true; devToken?: string } = { ok: true };
  if (
    codigo !== null &&
    process.env.NODE_ENV !== 'production' &&
    process.env.EXPOSE_PASSWORD_RESET_TOKEN === 'true'
  ) {
    response.devToken = codigo;
  }

  return response;
}

function safeEqualText(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

function isDuplicateError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { readonly code?: unknown }).code === 'ER_DUP_ENTRY'
  );
}

function invalidResetToken(): BadRequestException {
  return new BadRequestException({
    code: 'TOKEN_RECUPERACAO_INVALIDO',
    message: 'Codigo de recuperacao invalido ou expirado.',
  });
}

function invalidMfaCode(): UnauthorizedException {
  return new UnauthorizedException({
    code: 'MFA_INVALIDO',
    message: 'Codigo de verificacao invalido ou expirado.',
  });
}

function invalidEmailVerificationCode(): BadRequestException {
  return new BadRequestException({
    code: 'CODIGO_EMAIL_INVALIDO',
    message: 'Codigo de verificacao invalido ou expirado.',
  });
}

function badRequest(code: string): BadRequestException {
  return new BadRequestException({
    code,
    message: 'Dados invalidos.',
  });
}
