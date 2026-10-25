import {
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { MailService } from '../auth/mail.service.js';
import {
  paginationMetadata,
  parsePaginationQuery,
} from '../common/pagination.js';
import { NotificacaoEntity } from '../database/entities/notificacao.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
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
  private readonly logger = new Logger(NotificacoesService.name);

  constructor(
    @InjectRepository(NotificacaoEntity)
    private readonly notificacoes: Repository<NotificacaoEntity>,
    @InjectRepository(UsuarioEntity)
    private readonly usuarios: Repository<UsuarioEntity>,
    private readonly mail: MailService,
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

    const saved = await this.notificacoes.save(
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

    if (EMAIL_CRITICO_TIPOS.has(saved.tipo)) {
      await this.enviarEmailCritico(saved);
    }

    return saved;
  }

  private async enviarEmailCritico(notificacao: NotificacaoEntity): Promise<void> {
    try {
      const usuario = await this.usuarios.findOne({
        where: { id: notificacao.usuarioId },
        select: { id: true, email: true, emailVerificado: true, ativo: true },
      });
      if (usuario === null || !usuario.ativo || !usuario.emailVerificado) return;

      const enviado = await this.mail.sendCriticalNotificationEmail(
        usuario.email,
        notificacao.titulo,
        notificacao.mensagem,
      );
      if (!enviado) return;
    } catch {
      // Email e canal auxiliar: nao deve desfazer a operacao de negocio.
      this.logger.warn('critical_email_failed');
    }
  }
}

const EMAIL_CRITICO_TIPOS: ReadonlySet<NotificacaoTipo> = new Set([
  NotificacaoTipo.SolicitacaoCriada,
  NotificacaoTipo.SolicitacaoAceita,
  NotificacaoTipo.SolicitacaoRecusada,
  NotificacaoTipo.SolicitacaoCancelada,
  NotificacaoTipo.SolicitacaoConcluida,
  NotificacaoTipo.ConclusaoPendente,
  NotificacaoTipo.ConclusaoContestada,
  NotificacaoTipo.NaoComparecimento,
  NotificacaoTipo.DocumentoAprovado,
  NotificacaoTipo.DocumentoRejeitado,
  NotificacaoTipo.ReagendamentoProposto,
  NotificacaoTipo.ReagendamentoRespondido,
  NotificacaoTipo.OrcamentoProposto,
  NotificacaoTipo.OrcamentoRespondido,
  NotificacaoTipo.DenunciaAtualizada,
]);

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
