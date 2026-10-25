import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { TermoAceiteEntity } from '../database/entities/termo-aceite.entity.js';
import { termoAtual } from '../termos/termos.service.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { RequestWithUser } from './authenticated-user.js';
import { TokenService } from './token.service.js';

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly tokenService: TokenService,
    @InjectRepository(UsuarioEntity)
    private readonly usuarios: Repository<UsuarioEntity>,
    @InjectRepository(TermoAceiteEntity)
    private readonly termoAceites: Repository<TermoAceiteEntity>,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<RequestWithUser>();
    const token = bearerToken(request.headers.authorization);
    if (token === null) {
      throw unauthorized();
    }

    const payload = this.tokenService.verifyAccessToken(token);
    if (payload === null) {
      throw unauthorized();
    }

    const usuario = await this.usuarios.findOne({
      where: { id: payload.sub, ativo: true },
    });
    if (
      usuario === null ||
      usuario.tipo !== payload.tipo ||
      usuario.tokenVersion !== payload.tv
    ) {
      throw unauthorized();
    }

    if (
      usuario.tipo === UsuarioTipo.Administrador &&
      !usuario.mfaAtivo &&
      !permiteAdminSemMfa(request)
    ) {
      throw new ForbiddenException({
        code: 'MFA_ADMIN_OBRIGATORIO',
        message: 'Configure o autenticador para acessar recursos administrativos.',
      });
    }

    if (!usuario.emailVerificado && !permiteEmailNaoVerificado(request)) {
      throw new ForbiddenException({
        code: 'EMAIL_NAO_VERIFICADO',
        message: 'Confirme seu e-mail para continuar.',
      });
    }

    if (
      usuario.emailVerificado &&
      !permiteSemAceiteAtual(request) &&
      !(await this.termoAceites.exists({
        where: { usuarioId: usuario.id, versao: termoAtual.versao },
      }))
    ) {
      throw new ForbiddenException({
        code: 'TERMOS_NAO_ACEITOS',
        message: 'Leia e aceite a versao atual dos termos para continuar.',
        versao: termoAtual.versao,
      });
    }

    request.user = { id: usuario.id, tipo: usuario.tipo };
    return true;
  }
}

function permiteAdminSemMfa(request: RequestWithUser): boolean {
  const path = normalizarPath(request.originalUrl ?? request.url ?? request.path ?? '');
  if (request.method === 'POST' && path === '/auth/logout') return true;
  if (request.method === 'GET' && path === '/auth/email/verificacao') return true;
  if (request.method === 'POST' && path === '/auth/email/verificacao/enviar') return true;
  if (request.method === 'POST' && path === '/auth/email/verificacao/confirmar') return true;
  return false;
}

function permiteSemAceiteAtual(request: RequestWithUser): boolean {
  const path = normalizarPath(request.originalUrl ?? request.url ?? request.path ?? '');
  if (path.startsWith('/auth/')) return true;
  if (path === '/termos/aceites/me') return true;
  if (path.startsWith('/privacidade/me/')) return true;
  return false;
}

function permiteEmailNaoVerificado(request: RequestWithUser): boolean {
  const path = normalizarPath(request.originalUrl ?? request.url ?? request.path ?? '');
  if (request.method === 'POST' && path === '/auth/logout') return true;
  if (path === '/auth/email/verificacao') return true;
  if (path.startsWith('/auth/email/verificacao/')) return true;
  if (path === '/termos/aceites/me') return true;
  if (path.startsWith('/privacidade/me/')) return true;
  return false;
}

function normalizarPath(value: string): string {
  const semQuery = value.split('?')[0] ?? '';
  return semQuery.startsWith('/') ? semQuery : `/${semQuery}`;
}

function bearerToken(header: string | string[] | undefined): string | null {
  const value = Array.isArray(header) ? header[0] : header;
  if (value === undefined) return null;

  const [scheme, token] = value.split(' ');
  if (scheme !== 'Bearer' || token === undefined || token.trim() === '') {
    return null;
  }

  return token;
}

function unauthorized(): UnauthorizedException {
  return new UnauthorizedException({
    code: 'NAO_AUTENTICADO',
    message: 'Autenticacao obrigatoria.',
  });
}
