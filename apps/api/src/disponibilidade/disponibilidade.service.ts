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
import { ProfissionalDisponibilidadeEntity } from '../database/entities/profissional-disponibilidade.entity.js';
import { ProfissionalBloqueioEntity } from '../database/entities/profissional-bloqueio.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { SolicitacaoStatus } from '../domain/solicitacao-status.js';

interface DisponibilidadeInput {
  readonly diaSemana: number;
  readonly horaInicio: string;
  readonly horaFim: string;
  readonly ativo: boolean;
}

@Injectable()
export class DisponibilidadeService {
  constructor(
    @InjectRepository(ProfissionalDisponibilidadeEntity)
    private readonly disponibilidades: Repository<ProfissionalDisponibilidadeEntity>,
    @InjectRepository(ProfissionalBloqueioEntity)
    private readonly bloqueios: Repository<ProfissionalBloqueioEntity>,
    @InjectRepository(ProfissionalPerfilEntity)
    private readonly profissionais: Repository<ProfissionalPerfilEntity>,
    @InjectRepository(SolicitacaoEntity)
    private readonly solicitacoes: Repository<SolicitacaoEntity>,
  ) {}

  async listarPublica(profissionalId: number) {
    await this.carregarProfissionalPublico(profissionalId);
    const disponibilidades = await this.disponibilidades.find({
      where: { profissionalId, ativo: true },
      order: { diaSemana: 'ASC', horaInicio: 'ASC' },
    });

    return { disponibilidades: disponibilidades.map(disponibilidadeResponse) };
  }

  async minha(user: AuthenticatedUser) {
    const profissional = await this.carregarMeuProfissional(user);
    const disponibilidades = await this.disponibilidades.find({
      where: { profissionalId: profissional.id },
      order: { diaSemana: 'ASC', horaInicio: 'ASC' },
    });

    return { disponibilidades: disponibilidades.map(disponibilidadeResponse) };
  }

  async salvarMinha(user: AuthenticatedUser, body: unknown) {
    const profissional = await this.carregarMeuProfissional(user);
    const itens = parseDisponibilidades(body);

    await this.disponibilidades.manager.transaction(async (manager) => {
      // Usa a mesma ordem de bloqueio do aceite para publicar a agenda inteira
      // de forma atômica e impedir que o aceite leia uma atualização parcial.
      await manager.findOne(ProfissionalPerfilEntity, {
        where: { id: profissional.id },
        lock: { mode: 'pessimistic_write' },
      });
      await manager.delete(ProfissionalDisponibilidadeEntity, {
        profissionalId: profissional.id,
      });
      if (itens.length > 0) {
        await manager.save(
          ProfissionalDisponibilidadeEntity,
          itens.map((item) =>
            manager.create(ProfissionalDisponibilidadeEntity, {
              profissionalId: profissional.id,
              diaSemana: item.diaSemana,
              horaInicio: item.horaInicio,
              horaFim: item.horaFim,
              ativo: item.ativo,
            }),
          ),
        );
      }
    });

    return this.minha(user);
  }

  async meusBloqueios(user: AuthenticatedUser) {
    const profissional = await this.carregarMeuProfissional(user);
    const bloqueios = await this.bloqueios.find({
      where: { profissionalId: profissional.id },
      order: { dataInicio: 'ASC', criadoEm: 'ASC' },
    });
    return { bloqueios: bloqueios.map(bloqueioResponse) };
  }

  async criarBloqueio(user: AuthenticatedUser, body: unknown) {
    const profissional = await this.carregarMeuProfissional(user);
    const input = parseBloqueio(body);
    const atendimentos = await this.solicitacoes
      .createQueryBuilder('solicitacao')
      .where('solicitacao.profissional_id = :profissionalId', {
        profissionalId: profissional.id,
      })
      .andWhere('solicitacao.status = :status', {
        status: SolicitacaoStatus.AceitaAgendada,
      })
      .andWhere('solicitacao.data_servico BETWEEN :inicio AND :fim', {
        inicio: input.dataInicio,
        fim: input.dataFim,
      })
      .getCount();
    if (atendimentos > 0) {
      throw new ConflictException({
        code: 'PERIODO_COM_ATENDIMENTOS',
        message: 'Reagende os atendimentos confirmados antes de bloquear este período.',
      });
    }
    const saved = await this.bloqueios.save(
      this.bloqueios.create({ profissionalId: profissional.id, ...input }),
    );
    return { bloqueio: bloqueioResponse(saved) };
  }

  async removerBloqueio(user: AuthenticatedUser, id: number) {
    const profissional = await this.carregarMeuProfissional(user);
    const bloqueio = await this.bloqueios.findOne({
      where: { id, profissionalId: profissional.id },
    });
    if (bloqueio === null) {
      throw new NotFoundException({
        code: 'BLOQUEIO_NAO_ENCONTRADO',
        message: 'Bloqueio de agenda nao encontrado.',
      });
    }
    await this.bloqueios.remove(bloqueio);
    return { ok: true };
  }

  private async carregarMeuProfissional(
    user: AuthenticatedUser,
  ): Promise<ProfissionalPerfilEntity> {
    if (![UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(user.tipo)) {
      throw forbidden();
    }

    const profissional = await this.profissionais.findOne({
      where: { usuarioId: user.id, ativo: true },
      relations: { usuario: true },
    });
    if (profissional === null || !profissional.usuario.ativo) {
      throw new NotFoundException({
        code: 'PERFIL_PROFISSIONAL_NAO_ENCONTRADO',
        message: 'Perfil profissional nao encontrado.',
      });
    }

    return profissional;
  }

  private async carregarProfissionalPublico(
    profissionalId: number,
  ): Promise<ProfissionalPerfilEntity> {
    const profissional = await this.profissionais.findOne({
      where: { id: profissionalId, ativo: true },
      relations: { usuario: true },
    });
    if (
      profissional === null ||
      !profissional.usuario.ativo ||
      ![UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(
        profissional.usuario.tipo,
      )
    ) {
      throw new NotFoundException({
        code: 'PROFISSIONAL_NAO_ENCONTRADO',
        message: 'Profissional nao encontrado.',
      });
    }

    return profissional;
  }
}

export function horarioDisponivel(
  disponibilidades: readonly ProfissionalDisponibilidadeEntity[],
  dataServico: Date | string,
  horarioServico: string,
  duracaoMinutos = 0,
): boolean {
  const diaSemana = diaSemanaUtc(dataServico);
  const inicio = minutos(horarioServico);
  const fim = inicio + duracaoMinutos;
  return disponibilidades.some(
    (item) =>
      item.ativo &&
      item.diaSemana === diaSemana &&
      minutos(item.horaInicio) <= inicio &&
      fim <= minutos(item.horaFim),
  );
}

function minutos(horario: string): number {
  const [hora = '0', minuto = '0'] = horario.split(':');
  return Number(hora) * 60 + Number(minuto);
}

function disponibilidadeResponse(item: ProfissionalDisponibilidadeEntity) {
  return {
    id: item.id,
    diaSemana: item.diaSemana,
    horaInicio: item.horaInicio,
    horaFim: item.horaFim,
    ativo: item.ativo,
  };
}

function bloqueioResponse(item: ProfissionalBloqueioEntity) {
  return {
    id: item.id,
    dataInicio: item.dataInicio,
    dataFim: item.dataFim,
    motivo: item.motivo,
    criadoEm: item.criadoEm.toISOString(),
  };
}

function parseBloqueio(body: unknown) {
  const value = objectBody(body);
  const dataInicio = dateField(value.dataInicio);
  const dataFim = dateField(value.dataFim);
  if (dataInicio > dataFim) throw badRequest('PERIODO_INVALIDO');
  const motivo = value.motivo;
  if (typeof motivo !== 'string' || motivo.trim().length < 3 || motivo.trim().length > 160) {
    throw badRequest('MOTIVO_INVALIDO');
  }
  return { dataInicio, dataFim, motivo: motivo.trim() };
}

function dateField(value: unknown): string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw badRequest('DATA_INVALIDA');
  }
  const parsed = new Date(`${value}T12:00:00.000Z`);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) {
    throw badRequest('DATA_INVALIDA');
  }
  return value;
}

function parseDisponibilidades(body: unknown): readonly DisponibilidadeInput[] {
  const value = objectBody(body);
  const itens = value.disponibilidades;
  if (!Array.isArray(itens) || itens.length > 42) {
    throw badRequest('DISPONIBILIDADE_INVALIDA');
  }

  const parsed = itens.map(parseDisponibilidade);
  validarSobreposicao(parsed);
  return parsed;
}

function parseDisponibilidade(item: unknown): DisponibilidadeInput {
  const value = objectBody(item);
  const diaSemana = value.diaSemana;
  if (
    typeof diaSemana !== 'number' ||
    !Number.isInteger(diaSemana) ||
    diaSemana < 0 ||
    diaSemana > 6
  ) {
    throw badRequest('DIA_SEMANA_INVALIDO');
  }

  const horaInicio = timeField(value.horaInicio);
  const horaFim = timeField(value.horaFim);
  if (horaInicio >= horaFim) {
    throw badRequest('INTERVALO_INVALIDO');
  }

  return {
    diaSemana,
    horaInicio,
    horaFim,
    ativo: value.ativo === undefined ? true : booleanField(value.ativo),
  };
}

function validarSobreposicao(itens: readonly DisponibilidadeInput[]): void {
  for (let dia = 0; dia <= 6; dia += 1) {
    const doDia = itens
      .filter((item) => item.ativo && item.diaSemana === dia)
      .sort((a, b) => a.horaInicio.localeCompare(b.horaInicio));
    for (let index = 1; index < doDia.length; index += 1) {
      const anterior = doDia[index - 1];
      const atual = doDia[index];
      if (
        anterior !== undefined &&
        atual !== undefined &&
        atual.horaInicio < anterior.horaFim
      ) {
        throw badRequest('DISPONIBILIDADE_SOBREPOSTA');
      }
    }
  }
}

function diaSemanaUtc(dataServico: Date | string): number {
  const dateText =
    dataServico instanceof Date
      ? dataServico.toISOString().slice(0, 10)
      : dataServico.slice(0, 10);
  return new Date(`${dateText}T12:00:00.000Z`).getUTCDay();
}

function objectBody(body: unknown): Record<string, unknown> {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw badRequest('CORPO_INVALIDO');
  }

  return body as Record<string, unknown>;
}

function timeField(value: unknown): string {
  if (typeof value !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) {
    throw badRequest('HORARIO_INVALIDO');
  }

  return value;
}

function booleanField(value: unknown): boolean {
  if (typeof value !== 'boolean') {
    throw badRequest('CAMPO_INVALIDO');
  }

  return value;
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
