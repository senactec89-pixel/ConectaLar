import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import {
  paginationMetadata,
  parsePaginationQuery,
} from '../common/pagination.js';
import { NotificacaoEntity } from '../database/entities/notificacao.entity.js';
import { NotificacaoTipo } from '../domain/notificacao-tipo.js';

export interface CriarNotificacaoInput {
  readonly usuarioId: number;
  readonly tipo: NotificacaoTipo;
  readonly titulo: string;
  readonly mensagem: string;
  readonly recursoTipo?: string | null;
  readonly recursoId?: number | null;
}

@Injectable()
export class NotificacoesService {
  constructor(
    @InjectRepository(NotificacaoEntity)
    private readonly notificacoes: Repository<NotificacaoEntity>,
  ) {}

  async listarMinhas(user: AuthenticatedUser, query: Record<string, unknown>) {
    const pagination = parsePaginationQuery(query);
    const somenteNaoLidas = query.lida === 'false' || query.naoLidas === 'true';
    const where = somenteNaoLidas
      ? { usuarioId: user.id, lida: false }
      : { usuarioId: user.id };

    const [notificacoes, total] = await this.notificacoes.findAndCount({
      where,
      order: { criadoEm: 'DESC', id: 'DESC' },
      skip: pagination.skip,
      take: pagination.limite,
    });

    return {
      paginacao: paginationMetadata(pagination, total),
      notificacoes: notificacoes.map(notificacaoResponse),
    };
  }

  async resumoMinhas(user: AuthenticatedUser) {
    const naoLidas = await this.notificacoes.count({
      where: { usuarioId: user.id, lida: false },
    });

    return { naoLidas };
  }

  async marcarComoLida(user: AuthenticatedUser, id: number) {
    const notificacao = await this.notificacoes.findOne({ where: { id } });
    if (notificacao === null) {
      throw new NotFoundException({
        code: 'NOTIFICACAO_NAO_ENCONTRADA',
        message: 'Notificacao nao encontrada.',
      });
    }
    if (notificacao.usuarioId !== user.id) {
      throw forbidden();
    }

    notificacao.lida = true;
    notificacao.lidaEm = new Date();
    const saved = await this.notificacoes.save(notificacao);
    return { notificacao: notificacaoResponse(saved) };
  }

  async marcarTodasComoLidas(user: AuthenticatedUser) {
    await this.notificacoes.update(
      { usuarioId: user.id, lida: false },
      { lida: true, lidaEm: new Date() },
    );

    return { ok: true };
  }

  async criar(input: CriarNotificacaoInput) {
    if (input.titulo.trim().length === 0 || input.mensagem.trim().length === 0) {
      return null;
    }

    return this.notificacoes.save(
      this.notificacoes.create({
        usuarioId: input.usuarioId,
        tipo: input.tipo,
        titulo: input.titulo.trim().slice(0, 120),
        mensagem: input.mensagem.trim().slice(0, 240),
        recursoTipo: input.recursoTipo ?? null,
        recursoId: input.recursoId ?? null,
        lida: false,
      }),
    );
  }
}

function notificacaoResponse(notificacao: NotificacaoEntity) {
  return {
    id: notificacao.id,
    tipo: notificacao.tipo,
    titulo: notificacao.titulo,
    mensagem: notificacao.mensagem,
    recursoTipo: notificacao.recursoTipo,
    recursoId: notificacao.recursoId,
    lida: notificacao.lida,
    lidaEm: notificacao.lidaEm?.toISOString() ?? null,
    criadoEm: notificacao.criadoEm.toISOString(),
  };
}

function forbidden(): ForbiddenException {
  return new ForbiddenException({
    code: 'ACESSO_NEGADO',
    message: 'Usuario sem permissao para este recurso.',
  });
}
