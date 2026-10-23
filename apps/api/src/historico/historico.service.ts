import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { SelectQueryBuilder, Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { SolicitacaoStatus } from '../domain/solicitacao-status.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';

const estadosFinais = new Set<SolicitacaoStatus>([
  SolicitacaoStatus.Recusada,
  SolicitacaoStatus.Cancelada,
  SolicitacaoStatus.ConclusaoConfirmada,
]);

@Injectable()
export class HistoricoService {
  constructor(
    @InjectRepository(SolicitacaoEntity)
    private readonly solicitacoes: Repository<SolicitacaoEntity>,
  ) {}

  async meusAtendimentos(
    user: AuthenticatedUser,
    query: Record<string, unknown>,
  ) {
    const status = optionalStatus(query.status);
    const apenasFinalizados = optionalBooleanQuery(query.finalizados);
    const builder = this.baseBuilder().take(100);

    if (user.tipo === UsuarioTipo.Cliente) {
      builder.andWhere('solicitacao.cliente_id = :userId', { userId: user.id });
    } else if (
      [UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(user.tipo)
    ) {
      builder.andWhere('profissional.usuario_id = :userId', { userId: user.id });
    } else if (user.tipo === UsuarioTipo.Administrador) {
      const usuarioId = optionalId(query.usuarioId);
      if (usuarioId !== null) {
        builder.andWhere(
          '(solicitacao.cliente_id = :usuarioId OR profissional.usuario_id = :usuarioId)',
          { usuarioId },
        );
      } else {
        builder.andWhere('1 = 0');
      }
    }

    aplicarFiltros(builder, status, apenasFinalizados);
    const solicitacoes = await builder.getMany();
    return { atendimentos: solicitacoes.map(historicoResponse) };
  }

  async listarAdmin(query: Record<string, unknown>) {
    const status = optionalStatus(query.status);
    const apenasFinalizados = optionalBooleanQuery(query.finalizados);
    const usuarioId = optionalId(query.usuarioId);
    const builder = this.baseBuilder().take(200);

    if (usuarioId !== null) {
      builder.andWhere(
        '(solicitacao.cliente_id = :usuarioId OR profissional.usuario_id = :usuarioId)',
        { usuarioId },
      );
    }

    aplicarFiltros(builder, status, apenasFinalizados);
    const solicitacoes = await builder.getMany();
    return { atendimentos: solicitacoes.map(historicoAdminResponse) };
  }

  private baseBuilder(): SelectQueryBuilder<SolicitacaoEntity> {
    return this.solicitacoes
      .createQueryBuilder('solicitacao')
      .leftJoinAndSelect('solicitacao.cliente', 'cliente')
      .leftJoinAndSelect('solicitacao.profissional', 'profissional')
      .leftJoinAndSelect('profissional.usuario', 'profissionalUsuario')
      .leftJoinAndSelect('solicitacao.categoria', 'categoria')
      .orderBy('solicitacao.criadoEm', 'DESC');
  }
}

function aplicarFiltros(
  builder: SelectQueryBuilder<SolicitacaoEntity>,
  status: SolicitacaoStatus | null,
  apenasFinalizados: boolean | null,
) {
  if (status !== null) {
    builder.andWhere('solicitacao.status = :status', { status });
  }
  if (apenasFinalizados === true) {
    builder.andWhere('solicitacao.status IN (:...finais)', {
      finais: [...estadosFinais],
    });
  }
}

function historicoResponse(solicitacao: SolicitacaoEntity) {
  return {
    id: solicitacao.id,
    status: solicitacao.status,
    finalizado: estadosFinais.has(solicitacao.status),
    descricao: solicitacao.descricao,
    bairroAtendimento: solicitacao.bairroAtendimento,
    dataServico: solicitacao.dataServico,
    horarioServico: solicitacao.horarioServico,
    precoInicial: numberOrNull(solicitacao.precoInicial),
    precoFinal: numberOrNull(solicitacao.precoFinal),
    cliente: {
      id: solicitacao.cliente.id,
      nome: solicitacao.cliente.nome,
    },
    profissional: {
      id: solicitacao.profissional.id,
      usuarioId: solicitacao.profissional.usuarioId,
      nome: solicitacao.profissional.usuario.nome,
      verificado: solicitacao.profissional.verificado,
    },
    categoria:
      solicitacao.categoria === null
        ? null
        : {
            id: solicitacao.categoria.id,
            nome: solicitacao.categoria.nome,
          },
    criadoEm: solicitacao.criadoEm.toISOString(),
    atualizadoEm: solicitacao.atualizadoEm.toISOString(),
  };
}

function historicoAdminResponse(solicitacao: SolicitacaoEntity) {
  return {
    ...historicoResponse(solicitacao),
    clienteUsuarioId: solicitacao.clienteId,
  };
}

function optionalStatus(value: unknown): SolicitacaoStatus | null {
  if (value === undefined || value === null || value === '') return null;
  if (Object.values(SolicitacaoStatus).includes(value as SolicitacaoStatus)) {
    return value as SolicitacaoStatus;
  }

  throw badRequest('STATUS_INVALIDO');
}

function optionalId(value: unknown): number | null {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value === 'number' && Number.isInteger(value) && value > 0) {
    return value;
  }
  if (typeof value === 'string' && /^[1-9]\d{0,9}$/.test(value)) {
    return Number(value);
  }

  throw badRequest('ID_INVALIDO');
}

function optionalBooleanQuery(value: unknown): boolean | null {
  if (value === undefined || value === null || value === '') return null;
  if (value === 'true' || value === true) return true;
  if (value === 'false' || value === false) return false;
  throw badRequest('FILTRO_INVALIDO');
}

function numberOrNull(value: string | null | undefined): number | null {
  return value === null || value === undefined ? null : Number(value);
}

function badRequest(code: string): BadRequestException {
  return new BadRequestException({
    code,
    message: 'Dados invalidos.',
  });
}
