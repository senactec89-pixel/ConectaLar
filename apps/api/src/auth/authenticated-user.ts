import { UsuarioTipo } from '../domain/usuario-tipo.js';

export interface AuthenticatedUser {
  readonly id: number;
  readonly tipo: UsuarioTipo;
}

export interface RequestWithUser {
  readonly headers: Record<string, string | string[] | undefined>;
  readonly method?: string;
  readonly originalUrl?: string;
  readonly url?: string;
  readonly path?: string;
  user?: AuthenticatedUser;
}
