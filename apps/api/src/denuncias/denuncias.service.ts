import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { DenunciaEntity } from '../database/entities/denuncia.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { AdminAuditoriaAcao } from '../domain/admin-auditoria-acao.js';
import { DenunciaStatus } from '../domain/denuncia-status.js';
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
    @InjectRepository(AdminAuditoriaEntity)
    private readonly auditoria: Repository<AdminAuditoriaEntity>,
    @InjectRepository(DenunciaEntity)
    private readonly denuncias: Repository<DenunciaEntity>,
    @InjectRepository(SolicitacaoEntity)
    private readonly solicitacoes: Repository<SolicitacaoEntity>,
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

    return { denuncia: denunciaResponse(denuncia) };
  }

  async listarMinhas(user: AuthenticatedUser) {
    const denuncias = await this.denuncias.find({
      where: { denuncianteId: user.id },
      order: { criadoEm: 'DESC' },
      take: 50,
    });

    return { denuncias: denuncias.map(denunciaResponse) };
  }

  async listarModeracao(query: Record<string, unknown>) {
    const status = optionalStatus(query.status);
    const denuncias = await this.denuncias.find({
      where: status === null ? {} : { status },
      relations: {
        solicitacao: true,
        denunciante: true,
        denunciado: true,
        analisadoPor: true,
      },
      order: { criadoEm: 'DESC' },
      take: 100,
    });

    return { denuncias: denuncias.map(denunciaAdminResponse) };
  }

  async moderar(user: AuthenticatedUser, id: number, body: unknown) {
    const input = parseModerarDenuncia(body);
    const denuncia = await this.denuncias.findOne({
      where: { id },
      relations: {
        solicitacao: true,
        denunciante: true,
        denunciado: true,
        analisadoPor: true,
      },
    });
    if (denuncia === null) {
      throw new NotFoundException({
        code: 'DENUNCIA_NAO_ENCONTRADA',
        message: 'Denuncia nao encontrada.',
      });
    }

    denuncia.status = input.status;
    denuncia.decisao = input.decisao;
    denuncia.analisadoPorId = user.id;
    denuncia.analisadoEm = new Date();

    const saved = await this.denuncias.save(denuncia);
    await this.registrarAuditoria(
      user.id,
      saved.id,
      `Status: ${saved.status}`,
    );
    saved.solicitacao = denuncia.solicitacao;
    saved.denunciante = denuncia.denunciante;
    saved.denunciado = denuncia.denunciado;
    return { denuncia: denunciaAdminResponse(saved) };
  }

  private async registrarAuditoria(
    atorId: number,
    alvoId: number,
    detalhe: string,
  ) {
    await this.auditoria.save(
      this.auditoria.create({
        atorId,
        acao: AdminAuditoriaAcao.DenunciaModerada,
        alvoTipo: 'denuncia',
        alvoId,
        detalhe,
      }),
    );
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
    motivo: denuncia.motivo,
    descricao: denuncia.descricao,
    status: denuncia.status,
    decisao: denuncia.decisao,
    analisadoEm: denuncia.analisadoEm?.toISOString() ?? null,
    criadoEm: denuncia.criadoEm.toISOString(),
    atualizadoEm: denuncia.atualizadoEm.toISOString(),
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
