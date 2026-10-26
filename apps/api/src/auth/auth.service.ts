import { randomInt, createHash, createHmac, timingSafeEqual } from 'node:crypto';
import {
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { AuthenticatedUser } from './authenticated-user.js';
import { UsuarioEmailVerificacaoEntity } from '../database/entities/usuario-email-verificacao.entity.js';
import { EmailOutboxEntity } from '../database/entities/email-outbox.entity.js';
import { AdminConviteEntity } from '../database/entities/admin-convite.entity.js';
import { UsuarioSenhaResetEntity } from '../database/entities/usuario-senha-reset.entity.js';
import { TermoAceiteEntity } from '../database/entities/termo-aceite.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { UsuarioTipo, usuarioTiposPublicos } from '../domain/usuario-tipo.js';
import { termoAtual } from '../termos/termos.service.js';
import {
  fotoPerfilUrl,
  removerFotoPerfilArquivo,
  salvarFotoPerfil,
} from '../usuarios/foto-perfil.storage.js';
import { MailService } from './mail.service.js';
import { EmailOutboxService } from './email-outbox.service.js';
import { GoogleIdentityService } from './google-identity.service.js';
import { MfaService } from './mfa.service.js';
import { PasswordService } from './password.service.js';
import { TokenService } from './token.service.js';
import { invalidarVerificacoesTelefone } from '../verificacao/telefone-verificacao.util.js';

interface CadastroRequest {
  nome: string;
  email: string;
  senha: string;
  tipo: UsuarioTipo;
  telefone?: string | null;
  telefoneNormalizado?: string | null;
  aceitouTermos: boolean;
  versaoTermos: string;
}

interface LoginRequest {
  email: string;
  senha: string;
}

interface GoogleLoginRequest {
  idToken: string;
  tipo: UsuarioTipo | null;
  aceitouTermos: boolean;
  versaoTermos: string | null;
  senha: string | null;
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

interface MfaSetupRequest {
  setupToken: string;
  codigo?: string;
}

interface AceitarConviteAdminRequest {
  token: string;
  senha: string;
  aceitouTermos: boolean;
  versaoTermos: string;
}

const resetTokenTtlMinutes = 30;
const emailVerificationTtlMinutes = 15;
const codeIssueWindowMs = 60 * 60 * 1000;
const codeIssueCooldownMs = 60 * 1000;
const maxCodeIssuesPerWindow = 3;
const maxCodeAttempts = 5;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @InjectRepository(UsuarioEmailVerificacaoEntity)
    private readonly emailVerificacoes: Repository<UsuarioEmailVerificacaoEntity>,
    @InjectRepository(UsuarioSenhaResetEntity)
    private readonly senhaResets: Repository<UsuarioSenhaResetEntity>,
    @InjectRepository(UsuarioEntity)
    private readonly usuarios: Repository<UsuarioEntity>,
    @InjectRepository(TermoAceiteEntity)
    private readonly termoAceites: Repository<TermoAceiteEntity>,
    @InjectRepository(AdminConviteEntity)
    private readonly convitesAdmin: Repository<AdminConviteEntity>,
    private readonly googleIdentity: GoogleIdentityService,
    private readonly mailService: MailService,
    private readonly emailOutbox: EmailOutboxService,
    private readonly mfaService: MfaService,
    private readonly passwordService: PasswordService,
    private readonly tokenService: TokenService,
  ) {}

  async cadastro(body: unknown) {
    const cadastro = parseCadastro(body);
    if (!cadastro.aceitouTermos) {
      throw badRequest('ACEITE_TERMOS_OBRIGATORIO');
    }
    if (cadastro.versaoTermos !== termoAtual.versao) {
      throw badRequest('VERSAO_TERMO_INVALIDA');
    }
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

    const senhaHash = await this.passwordService.hash(cadastro.senha);
    const codigo = criarCodigoNumerico();
    const agora = new Date();
    const expiraEm = new Date(Date.now() + emailVerificationTtlMinutes * 60 * 1000);

    try {
      const created = await this.usuarios.manager.transaction(async (manager) => {
        const usuarios = manager.getRepository(UsuarioEntity);
        const saved = await usuarios.save(
          usuarios.create({
            nome: cadastro.nome.trim(),
            email,
            googleSub: null,
            telefone: cadastro.telefone?.trim() || null,
            telefoneNormalizado: cadastro.telefoneNormalizado ?? null,
            tipo: cadastro.tipo,
            senhaHash,
            emailVerificado: false,
            ativo: true,
            emailVerificacaoSolicitacoes: 1,
            emailVerificacaoJanelaInicio: agora,
            emailVerificacaoUltimaSolicitacao: agora,
          }),
        );
        await manager.getRepository(TermoAceiteEntity).save(
          manager.getRepository(TermoAceiteEntity).create({
            usuarioId: saved.id,
            versao: termoAtual.versao,
            canal: 'cadastro',
            aceitoEm: new Date(),
          }),
        );
        await manager.getRepository(UsuarioEmailVerificacaoEntity).save(
          manager.getRepository(UsuarioEmailVerificacaoEntity).create({
            usuarioId: saved.id,
            codigoHash: hashEmailVerificationCode(saved.id, codigo),
            expiraEm,
            usadoEm: null,
          }),
        );
        const outbox = await manager.getRepository(EmailOutboxEntity).save(
          this.emailOutbox.criarRegistro(saved.id, codigo, expiraEm),
        );
        return { saved, outboxId: outbox.id };
      });
      const delivered = await this.emailOutbox.entregarAgora(created.outboxId);
      return {
        ...(await this.authResponse(created.saved)),
        emailVerificationRequired: true,
        ...emailVerificationResponse(delivered, codigo),
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

    return this.loginResponse(usuario);
  }

  async loginGoogle(body: unknown) {
    const input = parseGoogleLogin(body);
    const identity = await this.googleIdentity.verify(input.idToken);

    const linked = await this.usuarios.findOne({
      where: { googleSub: identity.subject },
    });
    if (linked !== null) {
      if (!linked.ativo) throw googleLoginUnavailable();
      return this.loginResponse(linked, { contaCriada: false });
    }

    const sameEmail = await this.usuarios.findOne({
      where: { email: identity.email },
    });
    if (sameEmail !== null) {
      if (
        !sameEmail.ativo ||
        sameEmail.tipo === UsuarioTipo.Administrador ||
        !identity.emailAuthoritative
      ) {
        throw googleLinkRequiresPassword();
      }
      sameEmail.googleSub = identity.subject;
      sameEmail.emailVerificado = true;
      try {
        const saved = await this.usuarios.save(sameEmail);
        return this.loginResponse(saved, {
          contaCriada: false,
          contaVinculada: true,
        });
      } catch (error) {
        if (isDuplicateError(error)) throw googleLoginUnavailable();
        throw error;
      }
    }

    if (input.tipo === null) {
      return {
        cadastroNecessario: true,
        perfilGoogle: { nome: identity.name, email: identity.email },
      };
    }
    if (!input.aceitouTermos) {
      throw badRequest('ACEITE_TERMOS_OBRIGATORIO');
    }
    if (input.versaoTermos !== termoAtual.versao) {
      throw badRequest('VERSAO_TERMO_INVALIDA');
    }

    if (input.senha === null) throw badRequest('SENHA_INVALIDA');
    const senhaHash = await this.passwordService.hash(input.senha);
    try {
      const saved = await this.usuarios.manager.transaction(async (manager) => {
        const usuarios = manager.getRepository(UsuarioEntity);
        const usuario = await usuarios.save(
          usuarios.create({
            nome: identity.name,
            email: identity.email,
            emailVerificado: true,
            googleSub: identity.subject,
            telefone: null,
            telefoneNormalizado: null,
            fotoPerfil: null,
            tipo: input.tipo!,
            senhaHash,
            ativo: true,
          }),
        );
        await manager.getRepository(TermoAceiteEntity).save(
          manager.getRepository(TermoAceiteEntity).create({
            usuarioId: usuario.id,
            versao: termoAtual.versao,
            canal: 'google',
            aceitoEm: new Date(),
          }),
        );
        return usuario;
      });
      return this.loginResponse(saved, { contaCriada: true });
    } catch (error) {
      if (isDuplicateError(error)) throw googleLoginUnavailable();
      throw error;
    }
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
      usuario.mfaSecretEncrypted === null
    ) {
      throw invalidMfaCode();
    }

    this.exigirMfaDesbloqueado(usuario.mfaBloqueadoAte);
    if (!this.verificarCodigoMfa(usuario.mfaSecretEncrypted, input.codigo)) {
      await this.registrarFalhaMfa(usuario.id);
      throw invalidMfaCode();
    }
    await this.limparFalhasMfa(usuario.id);

    return this.authResponse(usuario);
  }

  async iniciarConfiguracaoMfaAdmin(body: unknown) {
    const input = parseMfaSetup(body, false);
    const usuario = await this.usuarioAdminDoSetup(input.setupToken);
    const secret = this.mfaService.createSecret();
    usuario.mfaSecretEncrypted = this.mfaService.encryptSecret(secret);
    await this.usuarios.save(usuario);
    return {
      secret,
      otpauthUrl: this.mfaService.createOtpAuthUrl(secret, usuario.email),
    };
  }

  async confirmarConfiguracaoMfaAdmin(body: unknown) {
    const input = parseMfaSetup(body, true);
    const usuario = await this.usuarioAdminDoSetup(input.setupToken);
    this.exigirMfaDesbloqueado(usuario.mfaBloqueadoAte);
    if (
      usuario.mfaSecretEncrypted === null ||
      !this.verificarCodigoMfa(usuario.mfaSecretEncrypted, input.codigo!)
    ) {
      await this.registrarFalhaMfa(usuario.id);
      throw invalidMfaCode();
    }

    const atualizacao = await this.usuarios.update(
      {
        id: usuario.id,
        ativo: true,
        tipo: UsuarioTipo.Administrador,
        mfaAtivo: false,
        tokenVersion: usuario.tokenVersion,
      },
      { mfaAtivo: true, tokenVersion: usuario.tokenVersion + 1 },
    );
    if (atualizacao.affected !== 1) throw invalidMfaCode();
    await this.limparFalhasMfa(usuario.id);
    const ativado = await this.usuarios.findOne({
      where: { id: usuario.id, ativo: true },
    });
    if (ativado === null || !ativado.mfaAtivo) throw invalidMfaCode();
    return this.authResponse(ativado);
  }

  async aceitarConviteAdmin(body: unknown) {
    const input = parseAceitarConviteAdmin(body);
    if (!input.aceitouTermos) throw badRequest('ACEITE_TERMOS_OBRIGATORIO');
    if (input.versaoTermos !== termoAtual.versao) {
      throw badRequest('VERSAO_TERMO_INVALIDA');
    }
    const tokenHash = hashAdminInviteToken(input.token);
    const convitePrevalidado = await this.convitesAdmin.findOne({ where: { tokenHash } });
    if (
      convitePrevalidado === null || convitePrevalidado.aceitoEm !== null ||
      convitePrevalidado.canceladoEm !== null || convitePrevalidado.expiraEm.getTime() <= Date.now()
    ) {
      throw invalidAdminInvite();
    }
    const senhaHash = await this.passwordService.hash(input.senha);
    const aceitoEm = new Date();
    const usuarioId = await this.usuarios.manager.transaction(async (manager) => {
      const convites = manager.getRepository(AdminConviteEntity);
      const convite = await convites.findOne({
        where: { tokenHash },
        lock: { mode: 'pessimistic_write' },
      });
      if (
        convite === null || convite.aceitoEm !== null || convite.canceladoEm !== null ||
        convite.expiraEm.getTime() <= Date.now()
      ) {
        throw invalidAdminInvite();
      }
      const usuarios = manager.getRepository(UsuarioEntity);
      const usuario = await usuarios.findOne({
        where: { id: convite.usuarioId, tipo: UsuarioTipo.Administrador, ativo: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (usuario === null || usuario.emailVerificado) throw invalidAdminInvite();

      usuario.senhaHash = senhaHash;
      usuario.emailVerificado = true;
      usuario.tokenVersion += 1;
      await usuarios.save(usuario);
      convite.aceitoEm = aceitoEm;
      await convites.save(convite);
      await manager.getRepository(TermoAceiteEntity).save(
        manager.getRepository(TermoAceiteEntity).create({
          usuarioId: usuario.id,
          versao: termoAtual.versao,
          canal: 'convite_administrativo',
          aceitoEm,
        }),
      );
      return usuario.id;
    });
    await this.emailOutbox.cancelarPendentes(usuarioId);
    const usuario = await this.usuarios.findOne({ where: { id: usuarioId, ativo: true } });
    if (usuario === null) throw invalidAdminInvite();
    return {
      conviteAceito: true,
      mfaSetupRequired: true,
      ...this.tokenService.createMfaSetupChallengeToken(usuario),
    };
  }

  async solicitarRecuperacaoSenha(body: unknown) {
    const input = parseRecuperacaoSenha(body);
    const email = normalizarEmail(input.email);
    const codigo = criarCodigoNumerico();
    const issue = await this.usuarios.manager.transaction(async (manager) => {
      const usuario = await manager.findOne(UsuarioEntity, {
        where: { email, ativo: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (usuario === null || !reservarQuotaCodigo(usuario, 'senha', new Date())) {
        return null;
      }
      await manager.save(UsuarioEntity, usuario);
      await manager.getRepository(UsuarioSenhaResetEntity).update(
        { usuarioId: usuario.id, usadoEm: IsNull() },
        { usadoEm: new Date() },
      );
      const expiraEm = new Date(Date.now() + resetTokenTtlMinutes * 60 * 1000);
      const tokenHash = hashResetCode(usuario.id, codigo);
      await manager.getRepository(UsuarioSenhaResetEntity).save(
        manager.getRepository(UsuarioSenhaResetEntity).create({
          usuarioId: usuario.id,
          tokenHash,
          expiraEm,
          usadoEm: null,
          tentativas: 0,
          bloqueadoEm: null,
        }),
      );
      return { email: usuario.email };
    });

    if (issue === null) {
      return recuperacaoSolicitadaResponse(null);
    }

    try {
      await this.mailService.sendPasswordResetEmail(issue.email, codigo);
    } catch {
      // Keep the response indistinguishable from unknown-account and throttled requests.
      this.logger.warn('password_reset_email_delivery_failed');
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
    const result = await this.agendarCodigoVerificacaoEmail(usuario);
    if (result.alreadyVerified) return { ok: true, emailVerificado: true };
    return {
      ok: true,
      emailVerificado: false,
      ...result.response,
    };
  }

  async confirmarVerificacaoEmail(
    user: AuthenticatedUser,
    body: unknown,
  ) {
    const input = parseConfirmarEmail(body);
    const outcome = await this.usuarios.manager.transaction(async (manager) => {
      const usuario = await manager.findOne(UsuarioEntity, {
        where: { id: user.id, ativo: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (usuario === null) throw new UnauthorizedException();
      if (usuario.emailVerificado) return 'verified' as const;

      const verificacao = await manager
        .getRepository(UsuarioEmailVerificacaoEntity)
        .findOne({
          where: { usuarioId: usuario.id },
          order: { criadoEm: 'DESC', id: 'DESC' },
          lock: { mode: 'pessimistic_write' },
        });
      if (verificacao?.bloqueadoEm !== null && verificacao?.bloqueadoEm !== undefined) {
        return 'locked' as const;
      }
      if (
        verificacao === null || verificacao.usadoEm !== null ||
        verificacao.expiraEm.getTime() <= Date.now()
      ) {
        return 'invalid' as const;
      }

      const expectedHash = hashEmailVerificationCode(usuario.id, input.codigo);
      const currentHashMatches = safeEqualText(verificacao.codigoHash, expectedHash);
      const legacyHashMatches = safeEqualText(
        verificacao.codigoHash,
        legacyCodeHash(usuario.id, input.codigo),
      );
      if (!currentHashMatches && !legacyHashMatches) {
        verificacao.tentativas += 1;
        if (verificacao.tentativas >= maxCodeAttempts) {
          verificacao.bloqueadoEm = new Date();
          verificacao.usadoEm = verificacao.bloqueadoEm;
        }
        await manager.save(UsuarioEmailVerificacaoEntity, verificacao);
        return verificacao.bloqueadoEm === null
          ? 'invalid' as const
          : 'locked' as const;
      }

      const agora = new Date();
      usuario.emailVerificado = true;
      verificacao.usadoEm = agora;
      await manager.save(UsuarioEntity, usuario);
      await manager.save(UsuarioEmailVerificacaoEntity, verificacao);
      await manager.getRepository(UsuarioEmailVerificacaoEntity).update(
        { usuarioId: usuario.id, usadoEm: IsNull() },
        { usadoEm: agora },
      );
      await manager.getRepository(EmailOutboxEntity).update(
        { usuarioId: usuario.id, enviadoEm: IsNull(), canceladoEm: IsNull() },
        { canceladoEm: agora, processandoEm: null, payloadCriptografado: '' },
      );
      return 'verified' as const;
    });

    if (outcome === 'locked') throw codeTemporarilyBlocked();
    if (outcome === 'invalid') throw invalidEmailVerificationCode();
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
    void user;
    void body;
    throw new ConflictException({
      code: 'MFA_ADMIN_NAO_PODE_SER_DESATIVADO',
      message: 'O autenticador e obrigatorio para contas administrativas.',
    });
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
    const outcome = await this.usuarios.manager.transaction(async (manager) => {
      const usuario = await manager.findOne(UsuarioEntity, {
        where: { email, ativo: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (usuario === null) return 'invalid' as const;
      const reset = await manager
        .getRepository(UsuarioSenhaResetEntity)
        .findOne({
          where: { usuarioId: usuario.id },
          order: { criadoEm: 'DESC', id: 'DESC' },
          lock: { mode: 'pessimistic_write' },
        });
      if (reset?.bloqueadoEm !== null && reset?.bloqueadoEm !== undefined) {
        return 'locked' as const;
      }
      if (
        reset === null || reset.usadoEm !== null ||
        reset.expiraEm.getTime() <= Date.now()
      ) {
        return 'invalid' as const;
      }

      const expectedHash = hashResetCode(usuario.id, input.token);
      const currentHashMatches = safeEqualText(reset.tokenHash, expectedHash);
      const legacyHashMatches = safeEqualText(
        reset.tokenHash,
        legacyCodeHash(usuario.id, input.token),
      );
      if (!currentHashMatches && !legacyHashMatches) {
        reset.tentativas += 1;
        if (reset.tentativas >= maxCodeAttempts) {
          reset.bloqueadoEm = new Date();
          reset.usadoEm = reset.bloqueadoEm;
        }
        await manager.save(UsuarioSenhaResetEntity, reset);
        return reset.bloqueadoEm === null
          ? 'invalid' as const
          : 'locked' as const;
      }

      usuario.senhaHash = await this.passwordService.hash(input.novaSenha);
      usuario.tokenVersion += 1;
      reset.usadoEm = new Date();
      await manager.save(UsuarioEntity, usuario);
      await manager.getRepository(UsuarioSenhaResetEntity).update(
        { usuarioId: usuario.id, usadoEm: IsNull() },
        { usadoEm: reset.usadoEm },
      );
      return 'changed' as const;
    });
    if (outcome === 'locked') throw codeTemporarilyBlocked();
    if (outcome !== 'changed') throw invalidResetToken();
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

  async atualizarFotoPerfil(user: AuthenticatedUser, body: unknown) {
    const usuario = await this.usuarioAtivo(user.id);
    const fotoAnterior = usuario.fotoPerfil;
    usuario.fotoPerfil = await salvarFotoPerfil(usuario.id, body);
    const saved = await this.usuarios.save(usuario);
    await removerFotoPerfilArquivo(fotoAnterior);
    return this.authResponse(saved);
  }

  async atualizarDadosPessoais(user: AuthenticatedUser, body: unknown) {
    const input = parseDadosPessoais(body);
    const usuario = await this.usuarioAtivo(user.id);
    if (input.telefoneNormalizado !== null) {
      const existente = await this.usuarios
        .createQueryBuilder('usuario')
        .where('usuario.telefoneNormalizado = :telefoneNormalizado', {
          telefoneNormalizado: input.telefoneNormalizado,
        })
        .andWhere('usuario.id <> :id', { id: usuario.id })
        .getOne();
      if (existente !== null) {
        throw new ConflictException({
          code: 'TELEFONE_JA_CADASTRADO',
          message: 'Este telefone ja esta vinculado a outra conta.',
        });
      }
    }

    try {
      const saved = await this.usuarios.manager.transaction(async (manager) => {
        const atual = await manager.findOne(UsuarioEntity, {
          where: { id: usuario.id, ativo: true }, lock: { mode: 'pessimistic_write' },
        });
        if (!atual) throw new UnauthorizedException();
        const telefoneMudou = atual.telefoneNormalizado !== input.telefoneNormalizado;
        atual.nome = input.nome;
        atual.telefone = input.telefone;
        atual.telefoneNormalizado = input.telefoneNormalizado;
        const salvo = await manager.save(UsuarioEntity, atual);
        if (telefoneMudou) await invalidarVerificacoesTelefone(manager, atual.id);
        return salvo;
      });
      return this.authResponse(saved);
    } catch (error) {
      if (isDuplicateError(error)) {
        throw new ConflictException({
          code: 'TELEFONE_JA_CADASTRADO',
          message: 'Este telefone ja esta vinculado a outra conta.',
        });
      }
      throw error;
    }
  }

  async removerFotoPerfil(user: AuthenticatedUser) {
    const usuario = await this.usuarioAtivo(user.id);
    const fotoAnterior = usuario.fotoPerfil;
    usuario.fotoPerfil = null;
    const saved = await this.usuarios.save(usuario);
    await removerFotoPerfilArquivo(fotoAnterior);
    return this.authResponse(saved);
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

  private async authResponse(usuario: UsuarioEntity) {
    const termosAceitos = await this.termoAceites.exists({
      where: { usuarioId: usuario.id, versao: termoAtual.versao },
    });
    return {
      usuario: {
        id: usuario.id,
        nome: usuario.nome,
        email: usuario.email,
        emailVerificado: usuario.emailVerificado,
        telefone: usuario.telefone,
        tipo: usuario.tipo,
        fotoPerfilUrl: fotoPerfilUrl(usuario),
        googleVinculado: usuario.googleSub !== null,
        termosAceitos,
        versaoTermos: termoAtual.versao,
      },
      token: this.tokenService.createAccessToken(usuario),
    };
  }

  private async loginResponse(
    usuario: UsuarioEntity,
    extras: Record<string, unknown> = {},
  ) {
    if (usuario.tipo === UsuarioTipo.Administrador) {
      if (!usuario.emailVerificado) {
        return {
          ...(await this.authResponse(usuario)),
          ...extras,
          emailVerificationRequired: true,
        };
      }
      if (usuario.mfaAtivo) {
        return {
          ...extras,
          mfaRequired: true,
          ...this.tokenService.createMfaChallengeToken(usuario),
        };
      }
      return {
        ...extras,
        mfaSetupRequired: true,
        ...this.tokenService.createMfaSetupChallengeToken(usuario),
      };
    }
    return { ...(await this.authResponse(usuario)), ...extras };
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

  private async agendarCodigoVerificacaoEmail(usuario: UsuarioEntity) {
    const codigo = criarCodigoNumerico();
    const expiraEm = new Date(
      Date.now() + emailVerificationTtlMinutes * 60 * 1000,
    );
    const result = await this.usuarios.manager.transaction(async (manager) => {
      const atual = await manager.findOne(UsuarioEntity, {
        where: { id: usuario.id, ativo: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (atual === null) throw new UnauthorizedException();
      if (atual.emailVerificado) return { verified: true as const };
      if (!reservarQuotaCodigo(atual, 'email', new Date())) throw codeTemporarilyBlocked();
      await manager.save(UsuarioEntity, atual);
      await manager.getRepository(UsuarioEmailVerificacaoEntity).update(
        { usuarioId: usuario.id, usadoEm: IsNull() },
        { usadoEm: new Date() },
      );
      await manager.getRepository(EmailOutboxEntity).update(
        { usuarioId: usuario.id, enviadoEm: IsNull(), canceladoEm: IsNull() },
        { canceladoEm: new Date(), processandoEm: null },
      );
      await manager.getRepository(UsuarioEmailVerificacaoEntity).save(
        manager.getRepository(UsuarioEmailVerificacaoEntity).create({
          usuarioId: usuario.id,
          codigoHash: hashEmailVerificationCode(usuario.id, codigo),
          expiraEm,
          usadoEm: null,
          tentativas: 0,
          bloqueadoEm: null,
        }),
      );
      const outbox = await manager.getRepository(EmailOutboxEntity).save(
        this.emailOutbox.criarRegistro(usuario.id, codigo, expiraEm),
      );
      return { verified: false as const, outboxId: outbox.id };
    });
    if (result.verified) return { alreadyVerified: true as const, response: {} };
    const delivered = await this.emailOutbox.entregarAgora(result.outboxId);
    return {
      alreadyVerified: false as const,
      response: emailVerificationResponse(delivered, codigo),
    };
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

  private async usuarioAdminDoSetup(setupToken: string): Promise<UsuarioEntity> {
    const payload = this.tokenService.verifyMfaSetupChallengeToken(setupToken);
    if (payload === null) throw invalidMfaSetup();
    const usuario = await this.usuarios
      .createQueryBuilder('usuario')
      .addSelect('usuario.mfaSecretEncrypted')
      .where('usuario.id = :id', { id: payload.sub })
      .andWhere('usuario.ativo = :ativo', { ativo: true })
      .getOne();
    if (
      usuario === null || usuario.tipo !== UsuarioTipo.Administrador ||
      !usuario.emailVerificado || usuario.mfaAtivo || usuario.tokenVersion !== payload.tv
    ) {
      throw invalidMfaSetup();
    }
    return usuario;
  }

  private exigirMfaDesbloqueado(bloqueadoAte: Date | null): void {
    if (bloqueadoAte !== null && bloqueadoAte.getTime() > Date.now()) {
      throw new HttpException(
        {
          code: 'MFA_TEMPORARIAMENTE_BLOQUEADO',
          message: 'Muitas tentativas. Aguarde 15 minutos e tente novamente.',
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  private async registrarFalhaMfa(usuarioId: number): Promise<void> {
    await this.usuarios.query(
      `UPDATE usuarios
       SET mfa_falhas = LEAST(mfa_falhas + 1, 5),
           mfa_bloqueado_ate = CASE
             WHEN mfa_falhas + 1 >= 5 THEN DATE_ADD(UTC_TIMESTAMP(), INTERVAL 15 MINUTE)
             ELSE mfa_bloqueado_ate
           END
       WHERE id = ? AND tipo = ? AND ativo = 1`,
      [usuarioId, UsuarioTipo.Administrador],
    );
  }

  private async limparFalhasMfa(usuarioId: number): Promise<void> {
    const reset = await this.usuarios
      .createQueryBuilder()
      .update(UsuarioEntity)
      .set({ mfaFalhas: 0, mfaBloqueadoAte: null })
      .where('id = :id', { id: usuarioId })
      .andWhere('(mfa_bloqueado_ate IS NULL OR mfa_bloqueado_ate <= UTC_TIMESTAMP())')
      .execute();
    if (reset.affected !== 1) {
      throw new HttpException(
        {
          code: 'MFA_TEMPORARIAMENTE_BLOQUEADO',
          message: 'Muitas tentativas. Aguarde 15 minutos e tente novamente.',
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
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
  const aceitouTermos = value.aceitouTermos === true;
  const versaoTermos = stringField(value, 'versaoTermos').trim();

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
    aceitouTermos,
    versaoTermos,
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

function parseGoogleLogin(body: unknown): GoogleLoginRequest {
  const value = objectBody(body);
  const idToken = stringField(value, 'idToken').trim();
  const tipo = optionalStringField(value, 'tipo');
  const senha = optionalStringField(value, 'senha');
  const aceitouTermos = value.aceitouTermos === true;
  const versaoTermos = optionalStringField(value, 'versaoTermos')?.trim() ?? null;
  if (idToken.length > 12_000) throw badRequest('TOKEN_GOOGLE_INVALIDO');
  if (tipo !== null && !usuarioTiposPublicos.has(tipo)) {
    throw badRequest('TIPO_INVALIDO');
  }
  if (tipo !== null) {
    if (senha === null) throw badRequest('SENHA_INVALIDA');
    validarSenha(senha);
  }
  return {
    idToken,
    tipo: tipo as UsuarioTipo | null,
    aceitouTermos,
    versaoTermos,
    senha,
  };
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

function parseMfaSetup(body: unknown, requireCode: boolean): MfaSetupRequest {
  const value = objectBody(body);
  const setupToken = stringField(value, 'setupToken');
  const codigo = value.codigo === undefined ? undefined : stringField(value, 'codigo').replace(/\s/g, '');
  if (
    setupToken.length > 1200 ||
    (requireCode && (codigo === undefined || !/^\d{6}$/.test(codigo))) ||
    (!requireCode && codigo !== undefined)
  ) {
    throw invalidMfaSetup();
  }
  return { setupToken, codigo };
}

function parseAceitarConviteAdmin(body: unknown): AceitarConviteAdminRequest {
  const value = objectBody(body);
  const token = stringField(value, 'token').trim();
  const senha = stringField(value, 'senha');
  const versaoTermos = stringField(value, 'versaoTermos').trim();
  validarSenha(senha);
  if (!/^[A-Za-z0-9_-]{43}$/.test(token)) throw invalidAdminInvite();
  return {
    token,
    senha,
    aceitouTermos: value.aceitouTermos === true,
    versaoTermos,
  };
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

function parseDadosPessoais(body: unknown) {
  const value = objectBody(body);
  const nome = stringField(value, 'nome').trim();
  const telefone = optionalStringField(value, 'telefone')?.trim() || null;
  if (nome.length < 3 || nome.length > 140) {
    throw badRequest('NOME_INVALIDO');
  }
  return {
    nome,
    telefone,
    telefoneNormalizado: normalizarTelefoneOpcional(telefone),
  };
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
    senha !== senha.trim() ||
    !/[A-Z]/.test(senha) ||
    !/[a-z]/.test(senha) ||
    !/\d/.test(senha) ||
    !/[^A-Za-z0-9]/.test(senha)
  ) {
    throw badRequest('SENHA_INVALIDA');
  }
}

function hashResetCode(usuarioId: number, codigo: string): string {
  return createHmac('sha256', codeHashSecret())
    .update(`password-reset:v1:${usuarioId}:${codigo}`, 'utf8')
    .digest('hex');
}

function hashEmailVerificationCode(usuarioId: number, codigo: string): string {
  return createHmac('sha256', codeHashSecret())
    .update(`email-verification:v1:${usuarioId}:${codigo}`, 'utf8')
    .digest('hex');
}

function legacyCodeHash(usuarioId: number, codigo: string): string {
  return createHash('sha256')
    .update(`${usuarioId}:${codigo}`, 'utf8')
    .digest('hex');
}

function codeHashSecret(): string {
  const secret = process.env.AUTH_TOKEN_SECRET;
  if (secret !== undefined && secret.length >= 32) return secret;
  if (process.env.NODE_ENV !== 'production') {
    return 'conectalar-non-production-code-hash-key';
  }
  throw new Error('Authentication configuration is incomplete.');
}

export function hashAdminInviteToken(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

function invalidAdminInvite(): UnauthorizedException {
  return new UnauthorizedException({
    code: 'CONVITE_ADMIN_INVALIDO',
    message: 'O convite e invalido, expirou ou ja foi utilizado.',
  });
}

function invalidMfaSetup(): UnauthorizedException {
  return new UnauthorizedException({
    code: 'MFA_CONFIGURACAO_INVALIDA',
    message: 'A etapa de configuracao expirou. Entre novamente para continuar.',
  });
}

function criarCodigoNumerico(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, '0');
}

function reservarQuotaCodigo(
  usuario: UsuarioEntity,
  tipo: 'senha' | 'email',
  agora: Date,
): boolean {
  const email = tipo === 'email';
  const inicio = email
    ? usuario.emailVerificacaoJanelaInicio
    : usuario.senhaResetJanelaInicio;
  const ultimaSolicitacao = email
    ? usuario.emailVerificacaoUltimaSolicitacao
    : usuario.senhaResetUltimaSolicitacao;
  let solicitacoes = email
    ? usuario.emailVerificacaoSolicitacoes
    : usuario.senhaResetSolicitacoes;
  let inicioJanela = inicio;

  if (
    inicioJanela === null || inicioJanela === undefined ||
    agora.getTime() - inicioJanela.getTime() >= codeIssueWindowMs
  ) {
    solicitacoes = 0;
    inicioJanela = agora;
  }
  if (
    solicitacoes >= maxCodeIssuesPerWindow ||
    (ultimaSolicitacao !== null && ultimaSolicitacao !== undefined &&
      agora.getTime() - ultimaSolicitacao.getTime() < codeIssueCooldownMs)
  ) {
    return false;
  }

  if (email) {
    usuario.emailVerificacaoSolicitacoes = solicitacoes + 1;
    usuario.emailVerificacaoJanelaInicio = inicioJanela;
    usuario.emailVerificacaoUltimaSolicitacao = agora;
  } else {
    usuario.senhaResetSolicitacoes = solicitacoes + 1;
    usuario.senhaResetJanelaInicio = inicioJanela;
    usuario.senhaResetUltimaSolicitacao = agora;
  }
  return true;
}

function codeTemporarilyBlocked(): HttpException {
  return new HttpException(
    {
      code: 'CODIGO_TEMPORARIAMENTE_BLOQUEADO',
      message: 'Muitas tentativas ou solicitacoes. Aguarde antes de tentar novamente.',
    },
    HttpStatus.TOO_MANY_REQUESTS,
  );
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

function emailVerificationResponse(delivered: boolean, codigo: string) {
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

function googleLoginUnavailable(): UnauthorizedException {
  return new UnauthorizedException({
    code: 'LOGIN_GOOGLE_NAO_AUTORIZADO',
    message: 'Nao foi possivel entrar com esta conta Google.',
  });
}

function googleLinkRequiresPassword(): ConflictException {
  return new ConflictException({
    code: 'VINCULACAO_GOOGLE_REQUER_SENHA',
    message: 'Entre com e-mail e senha para proteger esta conta.',
  });
}

function badRequest(code: string): BadRequestException {
  return new BadRequestException({
    code,
    message: 'Dados invalidos.',
  });
}
