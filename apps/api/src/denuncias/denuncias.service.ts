import {
  BadRequestException,
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
import { registrarAuditoriaAdmin } from '../common/admin-auditoria.js';
import { optionalSearchTerm } from '../common/admin-list-query.js';
import { DenunciaEntity } from '../database/entities/denuncia.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { AdminAuditoriaAcao } from '../domain/admin-auditoria-acao.js';
import { DenunciaStatus } from '../domain/denuncia-status.js';
import { NotificacaoTipo } from '../domain/notificacao-tipo.js';
import { NotificacoesService } from '../notificacoes/notificacoes.service.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';

interface CriarDenunciaInput {
  readonly denunciadoId: number;
  readonly motivo: string;
  readonly descricao: string;
}

interface ModerarDenunciaInput {
  readonly status:
    | DenunciaStatus.EmAnalise
    | DenunciaStatus.Resolvida
    | DenunciaStatus.Rejeitada;
  readonly decisao: string | null;
}

@Injectable()
export class DenunciasService {
  constructor(
    @InjectRepository(DenunciaEntity)
    private readonly denuncias: Repository<DenunciaEntity>,
    @InjectRepository(SolicitacaoEntity)
    private readonly solicitacoes: Repository<SolicitacaoEntity>,
    private readonly notificacoes: NotificacoesService,
  ) {}

  async criar(user: AuthenticatedUser, solicitacaoId: number, body: unknown) {
    const input = parseCriarDenuncia(body);
    const solicitacao = await this.solicitacoes.findOne({
      where: { id: solicitacaoId },
      relations: { cliente: true, profissional: { usuario: true } },
    });
    if (solicitacao === null) {
      throw new NotFoundException({
        code: 'SOLICITACAO_NAO_ENCONTRADA',
        message: 'Solicitacao nao encontrada.',
      });
    }

    validarParticipante(user, solicitacao);
    const denunciaveis = [solicitacao.clienteId, solicitacao.profissional.usuarioId];
    if (!denunciaveis.includes(input.denunciadoId)) {
      throw badRequest('DENUNCIADO_INVALIDO');
    }
    if (input.denunciadoId === user.id) {
      throw badRequest('AUTO_DENUNCIA_INVALIDA');
    }

    const denuncia = await this.denuncias.save(
      this.denuncias.create({
        solicitacaoId: solicitacao.id,
        denuncianteId: user.id,
        denunciadoId: input.denunciadoId,
        motivo: input.motivo,
        descricao: input.descricao,
        status: DenunciaStatus.Pendente,
        decisao: null,
        analisadoPorId: null,
        analisadoEm: null,
      }),
    );

    denuncia.solicitacao = solicitacao;
    denuncia.denunciado =
      input.denunciadoId === solicitacao.clienteId
        ? solicitacao.cliente
        : solicitacao.profissional.usuario;
    return { denuncia: denunciaResponse(denuncia) };
  }

  async listarMinhas(
    user: AuthenticatedUser,
    query: Record<string, unknown> = {},
  ) {
    const pagination = parsePaginationQuery(query);
    const [denuncias, total] = await this.denuncias.findAndCount({
      where: { denuncianteId: user.id },
      relations: {
        solicitacao: { categoria: true, profissional: { usuario: true } },
        denunciado: true,
      },
      order: { criadoEm: 'DESC', id: 'DESC' },
      skip: pagination.skip,
      take: pagination.limite,
    });

    return {
      paginacao: paginationMetadata(pagination, total),
      denuncias: denuncias.map(denunciaResponse),
    };
  }

  async listarModeracao(query: Record<string, unknown>) {
    const status = optionalStatus(query.status);
    const termo = optionalSearchTerm(query);
    const pagination = parsePaginationQuery(query, { defaultLimit: 20, maxLimit: 100 });
    const builder = this.denuncias
      .createQueryBuilder('denuncia')
      .leftJoinAndSelect('denuncia.solicitacao', 'solicitacao')
      .leftJoinAndSelect('denuncia.denunciante', 'denunciante')
      .leftJoinAndSelect('denuncia.denunciado', 'denunciado')
      .leftJoinAndSelect('denuncia.analisadoPor', 'analisadoPor')
      .orderBy('denuncia.criadoEm', 'DESC')
      .addOrderBy('denuncia.id', 'DESC')
      .skip(pagination.skip)
      .take(pagination.limite);
    if (status !== null) builder.andWhere('denuncia.status = :status', { status });
    if (termo !== null) {
      builder.andWhere(
        '(denuncia.motivo LIKE :termo OR denuncia.descricao LIKE :termo OR denunciante.nome LIKE :termo OR denunciante.email LIKE :termo OR denunciado.nome LIKE :termo OR denunciado.email LIKE :termo)',
        { termo: `%${termo}%` },
      );
    }
    const [denuncias, total] = await builder.getManyAndCount();
    return {
      paginacao: paginationMetadata(pagination, total),
      denuncias: denuncias.map(denunciaAdminResponse),
    };
  }

  async moderar(user: AuthenticatedUser, id: number, body: unknown) {
    const input = parseModerarDenuncia(body);
    const saved = await this.denuncias.manager.transaction(async (manager) => {
      const denuncias = manager.getRepository(DenunciaEntity);
      const denuncia = await denuncias.findOne({
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      if (denuncia === null) {
        throw new NotFoundException({
          code: 'DENUNCIA_NAO_ENCONTRADA',
          message: 'Denuncia nao encontrada.',
        });
      }

      const statusAnterior = denuncia.status;
      denuncia.status = input.status;
      denuncia.decisao = input.decisao;
      denuncia.analisadoPorId = user.id;
      denuncia.analisadoEm = new Date();

      const atualizado = await denuncias.save(denuncia);
      await registrarAuditoriaAdmin(manager, {
        atorId: user.id,
        acao: AdminAuditoriaAcao.DenunciaModerada,
        alvoTipo: 'denuncia',
        alvoId: atualizado.id,
        detalhe: {
          solicitacaoId: atualizado.solicitacaoId,
          denuncianteId: atualizado.denuncianteId,
          denunciadoId: atualizado.denunciadoId,
          motivoDenuncia: atualizado.motivo,
          status: { antes: statusAnterior, depois: atualizado.status },
          decisao: atualizado.decisao,
        },
      });
      return atualizado;
    });

    try {
      await this.notificacoes.criar({
        usuarioId: saved.denuncianteId,
        tipo: NotificacaoTipo.DenunciaAtualizada,
        titulo: 'Denuncia atualizada',
        mensagem:
          saved.status === DenunciaStatus.EmAnalise
            ? 'Sua denuncia entrou em analise.'
            : 'A analise da sua denuncia foi concluida.',
        recursoTipo: 'solicitacao',
        recursoId: saved.solicitacaoId,
      });
    } catch {
      // A notificacao nao pode desfazer a decisao administrativa.
    }
    const resultado = await this.denuncias.findOne({
      where: { id: saved.id },
      relations: {
        solicitacao: true,
        denunciante: true,
        denunciado: true,
        analisadoPor: true,
      },
    });
    if (resultado === null) {
      throw new NotFoundException({
        code: 'DENUNCIA_NAO_ENCONTRADA',
        message: 'Denuncia nao encontrada.',
      });
    }
    return { denuncia: denunciaAdminResponse(resultado) };
  }
}

function validarParticipante(user: AuthenticatedUser, solicitacao: SolicitacaoEntity) {
  if (user.tipo === UsuarioTipo.Cliente && solicitacao.clienteId === user.id) {
    return;
  }
  if (
    [UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(user.tipo) &&
    solicitacao.profissional.usuarioId === user.id
  ) {
    return;
  }

  throw new ForbiddenException({
    code: 'ACESSO_NEGADO',
    message: 'Usuario sem permissao para este recurso.',
  });
}

function parseCriarDenuncia(body: unknown): CriarDenunciaInput {
  const value = objectBody(body);
  return {
    denunciadoId: requiredId(value.denunciadoId),
    motivo: textField(value, 'motivo', 3, 80),
    descricao: textField(value, 'descricao', 20, 1000),
  };
}

function parseModerarDenuncia(body: unknown): ModerarDenunciaInput {
  const value = objectBody(body);
  if (
    value.status !== DenunciaStatus.EmAnalise &&
    value.status !== DenunciaStatus.Resolvida &&
    value.status !== DenunciaStatus.Rejeitada
  ) {
    throw badRequest('STATUS_DENUNCIA_INVALIDO');
  }

  const decisao = optionalText(value.decisao, 1000);
  if (
    [DenunciaStatus.Resolvida, DenunciaStatus.Rejeitada].includes(value.status) &&
    decisao === null
  ) {
    throw badRequest('DECISAO_OBRIGATORIA');
  }

  return {
    status: value.status,
    decisao,
  };
}

function optionalStatus(value: unknown): DenunciaStatus | null {
  if (value === undefined || value === null || value === '') return null;
  if (
    value === DenunciaStatus.Pendente ||
    value === DenunciaStatus.EmAnalise ||
    value === DenunciaStatus.Resolvida ||
    value === DenunciaStatus.Rejeitada
  ) {
    return value;
  }

  throw badRequest('STATUS_INVALIDO');
}

function denunciaResponse(denuncia: DenunciaEntity) {
  return {
    id: denuncia.id,
    solicitacaoId: denuncia.solicitacaoId,
    denuncianteId: denuncia.denuncianteId,
    denunciadoId: denuncia.denunciadoId,
    denunciado: usuarioResumo(denuncia.denunciado) ?? null,
    atendimento: atendimentoResumo(denuncia),
    motivo: denuncia.motivo,
    descricao: denuncia.descricao,
    status: denuncia.status,
    decisao: denuncia.decisao,
    analisadoEm: denuncia.analisadoEm?.toISOString() ?? null,
    criadoEm: denuncia.criadoEm.toISOString(),
    atualizadoEm: denuncia.atualizadoEm.toISOString(),
  };
}

function atendimentoResumo(denuncia: DenunciaEntity) {
  const solicitacao = denuncia.solicitacao;
  if (solicitacao === undefined) return null;
  return {
    id: solicitacao.id,
    nomeServico:
      solicitacao.nomeServico ?? solicitacao.categoria?.nome ?? 'Atendimento',
    dataServico: solicitacao.dataServico,
    profissional: solicitacao.profissional?.usuario?.nome ?? null,
  };
}

function denunciaAdminResponse(denuncia: DenunciaEntity) {
  return {
    ...denunciaResponse(denuncia),
    analisadoPorId: denuncia.analisadoPorId,
    denunciante: usuarioResumo(denuncia.denunciante),
    denunciado: usuarioResumo(denuncia.denunciado),
  };
}

function usuarioResumo(usuario: DenunciaEntity['denunciante'] | undefined) {
  if (usuario === undefined) return undefined;
  return {
    id: usuario.id,
    nome: usuario.nome,
    tipo: usuario.tipo,
  };
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

function requiredId(value: unknown): number {
  if (typeof value === 'number' && Number.isInteger(value) && value > 0) {
    return value;
  }
  if (typeof value === 'string' && /^[1-9]\d{0,9}$/.test(value)) {
    return Number(value);
  }

  throw badRequest('ID_INVALIDO');
}

function badRequest(code: string): BadRequestException {
  return new BadRequestException({
    code,
    message: 'Dados invalidos.',
  });
}
