import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { registrarAuditoriaAdmin } from '../common/admin-auditoria.js';
import { optionalEnumFilter, optionalSearchTerm } from '../common/admin-list-query.js';
import { paginationMetadata, parsePaginationQuery } from '../common/pagination.js';
import { AvaliacaoEntity } from '../database/entities/avaliacao.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { AdminAuditoriaAcao } from '../domain/admin-auditoria-acao.js';
import { AvaliacaoModeracaoStatus } from '../domain/avaliacao-moderacao-status.js';
import { NotificacaoTipo } from '../domain/notificacao-tipo.js';
import { SolicitacaoStatus } from '../domain/solicitacao-status.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { NotificacoesService } from '../notificacoes/notificacoes.service.js';

@Injectable()
export class AvaliacoesService {
  constructor(
    @InjectRepository(AvaliacaoEntity)
    private readonly avaliacoes: Repository<AvaliacaoEntity>,
    @InjectRepository(SolicitacaoEntity)
    private readonly solicitacoes: Repository<SolicitacaoEntity>,
    private readonly notificacoes: NotificacoesService,
  ) {}

  async listarDaSolicitacao(user: AuthenticatedUser, solicitacaoId: number) {
    const solicitacao = await this.carregarSolicitacao(solicitacaoId);
    assertParticipante(user, solicitacao);

    const avaliacoes = await this.avaliacoes.find({
      where: { solicitacaoId },
      relations: { avaliador: true, avaliado: true },
      order: { criadoEm: 'ASC' },
    });

    return { avaliacoes: avaliacoes.map(avaliacaoResponse) };
  }

  async avaliarProfissional(
    user: AuthenticatedUser,
    solicitacaoId: number,
    body: unknown,
  ) {
    const solicitacao = await this.carregarSolicitacao(solicitacaoId);
    assertClienteParticipante(user, solicitacao);
    return this.criarAvaliacao(
      solicitacao,
      user.id,
      solicitacao.profissional.usuarioId,
      body,
    );
  }

  async avaliarCliente(
    user: AuthenticatedUser,
    solicitacaoId: number,
    body: unknown,
  ) {
    const solicitacao = await this.carregarSolicitacao(solicitacaoId);
    assertProfissionalParticipante(user, solicitacao);
    return this.criarAvaliacao(solicitacao, user.id, solicitacao.clienteId, body);
  }

  async listarModeracao(query: Record<string, unknown>) {
    const status = query.status === 'todas'
      ? null
      : query.status === undefined || query.status === ''
      ? AvaliacaoModeracaoStatus.Pendente
      : optionalEnumFilter(query, 'status', Object.values(AvaliacaoModeracaoStatus));
    const termo = optionalSearchTerm(query);
    const pagination = parsePaginationQuery(query, { defaultLimit: 20, maxLimit: 100 });
    const builder = this.avaliacoes
      .createQueryBuilder('avaliacao')
      .leftJoinAndSelect('avaliacao.avaliador', 'avaliador')
      .leftJoinAndSelect('avaliacao.avaliado', 'avaliado')
      .leftJoinAndSelect('avaliacao.solicitacao', 'solicitacao')
      .orderBy('avaliacao.criadoEm', 'DESC')
      .addOrderBy('avaliacao.id', 'DESC')
      .skip(pagination.skip)
      .take(pagination.limite);
    if (status !== null) {
      builder.andWhere('avaliacao.moderacaoStatus = :status', { status });
    }
    if (termo !== null) {
      builder.andWhere(
        '(avaliacao.comentario LIKE :termo OR avaliador.nome LIKE :termo OR avaliado.nome LIKE :termo)',
        { termo: `%${termo}%` },
      );
    }
    const [avaliacoes, total] = await builder.getManyAndCount();
    return {
      paginacao: paginationMetadata(pagination, total),
      avaliacoes: avaliacoes.map(avaliacaoResponse),
    };
  }

  async moderar(user: AuthenticatedUser, id: number, body: unknown) {
    const status = parseModeracaoStatus(body);
    await this.avaliacoes.manager.transaction(async (manager) => {
      const avaliacoes = manager.getRepository(AvaliacaoEntity);
      const avaliacao = await avaliacoes.findOne({
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      if (avaliacao === null) {
        throw new NotFoundException({
          code: 'AVALIACAO_NAO_ENCONTRADA',
          message: 'Avaliacao nao encontrada.',
        });
      }

      const statusAnterior = avaliacao.moderacaoStatus;
      avaliacao.moderacaoStatus = status;
      await avaliacoes.save(avaliacao);
      await registrarAuditoriaAdmin(manager, {
        atorId: user.id,
        acao: AdminAuditoriaAcao.AvaliacaoModerada,
        alvoTipo: 'avaliacao',
        alvoId: avaliacao.id,
        detalhe: {
          solicitacaoId: avaliacao.solicitacaoId,
          avaliadorId: avaliacao.avaliadorId,
          avaliadoId: avaliacao.avaliadoId,
          nota: avaliacao.nota,
          comentarioPresente: avaliacao.comentario !== null,
          status: { antes: statusAnterior, depois: avaliacao.moderacaoStatus },
        },
      });
    });

    const saved = await this.avaliacoes.findOne({
      where: { id },
      relations: { avaliador: true, avaliado: true },
    });
    if (saved === null) {
      throw new NotFoundException({
        code: 'AVALIACAO_NAO_ENCONTRADA',
        message: 'Avaliacao nao encontrada.',
      });
    }
    return { avaliacao: avaliacaoResponse(saved) };
  }

  private async criarAvaliacao(
    solicitacao: SolicitacaoEntity,
    avaliadorId: number,
    avaliadoId: number,
    body: unknown,
  ) {
    if (solicitacao.status !== SolicitacaoStatus.ConclusaoConfirmada) {
      throw badRequest('AVALIACAO_INDISPONIVEL');
    }

    const input = parseAvaliacao(body);
    const avaliacao = this.avaliacoes.create({
      solicitacaoId: solicitacao.id,
      avaliadorId,
      avaliadoId,
      nota: input.nota,
      comentario: input.comentario,
      moderacaoStatus: AvaliacaoModeracaoStatus.Pendente,
    });

    try {
      const saved = await this.avaliacoes.save(avaliacao);
      const reloaded = await this.avaliacoes.findOne({
        where: { id: saved.id },
        relations: { avaliador: true, avaliado: true },
      });
      if (reloaded === null) {
        throw new Error('Saved review could not be reloaded.');
      }
      await this.notificarSeguro({
        usuarioId: avaliadoId,
        tipo: NotificacaoTipo.AvaliacaoRecebida,
        titulo: 'Nova avaliacao recebida',
        mensagem: 'Voce recebeu uma avaliacao de um atendimento concluido.',
        recursoTipo: 'solicitacao',
        recursoId: solicitacao.id,
      });
      return { avaliacao: avaliacaoResponse(reloaded) };
    } catch (error) {
      if (isDuplicateError(error)) {
        throw new ConflictException({
          code: 'AVALIACAO_JA_REGISTRADA',
          message: 'Avaliacao ja registrada para este atendimento.',
        });
      }
      throw error;
    }
  }

  private async carregarSolicitacao(id: number): Promise<SolicitacaoEntity> {
    const solicitacao = await this.solicitacoes.findOne({
      where: { id },
      relations: { cliente: true, profissional: { usuario: true } },
    });
    if (solicitacao === null) {
      throw new NotFoundException({
        code: 'SOLICITACAO_NAO_ENCONTRADA',
        message: 'Solicitacao nao encontrada.',
      });
    }

    return solicitacao;
  }

  private async notificarSeguro(input: Parameters<NotificacoesService['criar']>[0]) {
    try {
      await this.notificacoes.criar(input);
    } catch {
      // Falha de notificacao nao altera registro de avaliacao.
    }
  }
}

function avaliacaoResponse(avaliacao: AvaliacaoEntity) {
  return {
    id: avaliacao.id,
    solicitacaoId: avaliacao.solicitacaoId,
    avaliador: {
      id: avaliacao.avaliador.id,
      nome: avaliacao.avaliador.nome,
      tipo: avaliacao.avaliador.tipo,
    },
    avaliado: {
      id: avaliacao.avaliado.id,
      nome: avaliacao.avaliado.nome,
      tipo: avaliacao.avaliado.tipo,
    },
    nota: avaliacao.nota,
    comentario: avaliacao.comentario,
    moderacaoStatus: avaliacao.moderacaoStatus,
    criadoEm: avaliacao.criadoEm.toISOString(),
    atualizadoEm: avaliacao.atualizadoEm.toISOString(),
  };
}

function assertParticipante(
  user: AuthenticatedUser,
  solicitacao: SolicitacaoEntity,
): void {
  if (user.tipo === UsuarioTipo.Administrador) {
    return;
  }
  if (user.tipo === UsuarioTipo.Cliente && solicitacao.clienteId === user.id) {
    return;
  }
  if (
    [UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(user.tipo) &&
    solicitacao.profissional.usuarioId === user.id
  ) {
    return;
  }

  throw forbidden();
}

function assertClienteParticipante(
  user: AuthenticatedUser,
  solicitacao: SolicitacaoEntity,
): void {
  if (user.tipo === UsuarioTipo.Cliente && solicitacao.clienteId === user.id) {
    return;
  }

  throw forbidden();
}

function assertProfissionalParticipante(
  user: AuthenticatedUser,
  solicitacao: SolicitacaoEntity,
): void {
  if (
    [UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(user.tipo) &&
    solicitacao.profissional.usuarioId === user.id
  ) {
    return;
  }

  throw forbidden();
}

function parseAvaliacao(body: unknown): {
  readonly nota: number;
  readonly comentario: string | null;
} {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw badRequest('CORPO_INVALIDO');
  }

  const value = body as Record<string, unknown>;
  const nota = value.nota;
  if (typeof nota !== 'number' || !Number.isInteger(nota) || nota < 1 || nota > 5) {
    throw badRequest('NOTA_INVALIDA');
  }

  const comentario = value.comentario;
  if (comentario === undefined || comentario === null || comentario === '') {
    return { nota, comentario: null };
  }
  if (typeof comentario !== 'string') {
    throw badRequest('COMENTARIO_INVALIDO');
  }

  const text = comentario.trim();
  if (text.length > 600) {
    throw badRequest('COMENTARIO_INVALIDO');
  }

  return { nota, comentario: text.length === 0 ? null : text };
}

function parseModeracaoStatus(body: unknown): AvaliacaoModeracaoStatus {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw badRequest('CORPO_INVALIDO');
  }

  const status = (body as Record<string, unknown>).moderacaoStatus;
  if (
    status === AvaliacaoModeracaoStatus.Aprovada ||
    status === AvaliacaoModeracaoStatus.Rejeitada ||
    status === AvaliacaoModeracaoStatus.Pendente
  ) {
    return status;
  }

  throw badRequest('MODERACAO_INVALIDA');
}

function isDuplicateError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { readonly code?: unknown }).code === 'ER_DUP_ENTRY'
  );
}

function forbidden(): ForbiddenException {
  return new ForbiddenException({
    code: 'ACESSO_NEGADO',
    message: 'Usuario sem permissao para este recurso.',
  });
}

function badRequest(code: string): BadRequestException {
  return new BadRequestException({
    code,
    message: 'Dados invalidos.',
  });
}
