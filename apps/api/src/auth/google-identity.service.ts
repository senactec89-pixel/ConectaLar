import {
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { OAuth2Client } from 'google-auth-library';

export interface GoogleIdentity {
  readonly subject: string;
  readonly email: string;
  readonly name: string;
  readonly emailAuthoritative: boolean;
}

@Injectable()
export class GoogleIdentityService {
  private readonly client = new OAuth2Client();

  async verify(idToken: string): Promise<GoogleIdentity> {
    const audiences = googleOAuthClientIds();
    if (audiences.length === 0) {
      throw new ServiceUnavailableException({
        code: 'LOGIN_GOOGLE_INDISPONIVEL',
        message: 'Login com Google indisponivel.',
      });
    }

    try {
      const ticket = await this.client.verifyIdToken({
        idToken,
        audience: audiences,
      });
      const payload = ticket.getPayload();
      const subject = payload?.sub?.trim() ?? '';
      const email = payload?.email?.trim().toLowerCase() ?? '';
      const name = normalizarNome(payload?.name);
      const hostedDomain = payload?.hd?.trim() ?? '';

      if (
        subject.length === 0 ||
        subject.length > 255 ||
        email.length > 180 ||
        payload?.email_verified !== true ||
        !emailValido(email)
      ) {
        throw invalidGoogleToken();
      }

      return {
        subject,
        email,
        name,
        emailAuthoritative:
          email.endsWith('@gmail.com') || hostedDomain.length > 0,
      };
    } catch (error) {
      if (
        error instanceof UnauthorizedException ||
        error instanceof ServiceUnavailableException
      ) {
        throw error;
      }
      throw invalidGoogleToken();
    }
  }
}

export function googleOAuthClientIds(
  environment: NodeJS.ProcessEnv = process.env,
): string[] {
  const configured =
    environment.GOOGLE_OAUTH_CLIENT_IDS ?? environment.GOOGLE_WEB_CLIENT_ID ?? '';
  return [...new Set(configured.split(',').map((value) => value.trim()))].filter(
    (value) => value.length > 0,
  );
}

function normalizarNome(value: string | undefined): string {
  const name = value?.replace(/\s+/g, ' ').trim() ?? '';
  if (name.length >= 3) return name.slice(0, 140);
  return 'Usuario Google';
}

function emailValido(email: string): boolean {
  return /^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$/.test(
    email,
  );
}

function invalidGoogleToken(): UnauthorizedException {
  return new UnauthorizedException({
    code: 'TOKEN_GOOGLE_INVALIDO',
    message: 'Nao foi possivel validar a conta Google.',
  });
}
