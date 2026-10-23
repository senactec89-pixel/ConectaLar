import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { ProfissionalIdentidadeVerificacaoEntity } from '../database/entities/profissional-identidade-verificacao.entity.js';
import { AdminAuditoriaAcao } from '../domain/admin-auditoria-acao.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { habilitacaoProfissional } from './habilitacao-profissional.js';
import { IdZapSignProvider } from './id-zapsign.provider.js';

@Injectable()
export class HabilitacaoService {
  constructor(
    @InjectRepository(ProfissionalPerfilEntity) private readonly perfis: Repository<ProfissionalPerfilEntity>,
    @InjectRepository(UsuarioEntity) private readonly usuarios: Repository<UsuarioEntity>,
    @InjectRepository(ProfissionalIdentidadeVerificacaoEntity) private readonly identidades: Repository<ProfissionalIdentidadeVerificacaoEntity> | undefined = undefined,
    private readonly identidade: IdZapSignProvider = new IdZapSignProvider(),
  ) {}

  async minha(user: AuthenticatedUser) {
    this.exigirProfissional(user);
    const perfil = await this.perfis.findOne({ where: { usuarioId: user.id }, relations: { usuario: true } });
    const identidade = perfil ? await this.identidades?.findOne({
      where: { usuarioId: user.id }, order: { criadoEm: 'DESC' },
    }) : null;
    return { habilitacao: habilitacaoProfissional(perfil, etapaIdentidade(identidade?.estado)) };
  }

  async iniciarIdentidade(user: AuthenticatedUser, body: unknown) {
    this.exigirProfissional(user);
    const input = corpo(body, ['consentimento']);
    if (!this.identidade.disponivel) throw identidadeIndisponivel();
    if (input.consentimento !== true) throw invalido();
    if (!this.identidades) throw identidadeIndisponivel();
    const verificacao = await this.identidades.manager.transaction(async (manager) => {
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { usuarioId: user.id, ativo: true }, lock: { mode: 'pessimistic_write' },
      });
      if (!perfil) throw naoEncontrado();
      const ativa = await manager.findOne(ProfissionalIdentidadeVerificacaoEntity, {
        where: [
          { usuarioId: user.id, estado: 'iniciando' },
          { usuarioId: user.id, estado: 'pendente' },
        ],
        order: { criadoEm: 'DESC' },
        lock: { mode: 'pessimistic_write' },
      });
      if (ativa) return ativa;
      const ultima = await manager.findOne(ProfissionalIdentidadeVerificacaoEntity, {
        where: { usuarioId: user.id }, order: { criadoEm: 'DESC' },
      });
      if (ultima?.estado === 'confirmada') {
        throw new ConflictException({ code: 'IDENTIDADE_JA_CONFIRMADA', message: 'Sua identidade ja foi confirmada.' });
      }
      if (ultima && Date.now() - ultima.criadoEm.getTime() < 10 * 60_000) {
        throw new ConflictException({ code: 'NOVA_VERIFICACAO_AGUARDE', message: 'Aguarde 10 minutos antes de iniciar outra verificacao.' });
      }
      return manager.save(ProfissionalIdentidadeVerificacaoEntity, manager.create(ProfissionalIdentidadeVerificacaoEntity, {
        usuarioId: user.id,
        referencia: null,
        referenciaExterna: randomUUID(),
        chaveIdempotencia: randomUUID(),
        consentimentoEm: new Date(),
        versaoAviso: 'conectalar-identidade-v1',
        estado: 'iniciando',
        expiraEm: null,
        resolvidaEm: null,
      }));
    });

    if (verificacao.referencia) return this.atualizarIdentidade(verificacao);
    if (!verificacao.chaveIdempotencia) throw identidadeIndisponivel();
    const criada = await this.identidade.iniciar({
      referenciaExterna: verificacao.referenciaExterna,
      chaveIdempotencia: verificacao.chaveIdempotencia,
    });
    verificacao.referencia = criada.referencia;
    verificacao.chaveIdempotencia = null;
    verificacao.estado = 'pendente';
    verificacao.expiraEm = criada.expiraEm;
    await this.identidades.save(verificacao);
    return { identidade: respostaIdentidade(verificacao, criada.url) };
  }

  async consultarIdentidade(user: AuthenticatedUser) {
    this.exigirProfissional(user);
    const identidades = this.identidades;
    if (!identidades) return { identidade: respostaIdentidade(null, null, false) };
    const verificacao = await identidades.findOne({
      where: { usuarioId: user.id }, order: { criadoEm: 'DESC' },
    });
    if (!verificacao) return { identidade: respostaIdentidade(null, null, this.identidade.disponivel) };
    if (!this.identidade.disponivel) {
      return { identidade: respostaIdentidade(verificacao, null, false) };
    }
    if (verificacao.estado === 'confirmada') return { identidade: respostaIdentidade(verificacao) };
    if (verificacao.estado === 'iniciando' && verificacao.chaveIdempotencia) {
      const criada = await this.identidade.iniciar({
        referenciaExterna: verificacao.referenciaExterna,
        chaveIdempotencia: verificacao.chaveIdempotencia,
      });
      verificacao.referencia = criada.referencia;
      verificacao.chaveIdempotencia = null;
      verificacao.estado = 'pendente';
      verificacao.expiraEm = criada.expiraEm;
      await identidades.save(verificacao);
      return { identidade: respostaIdentidade(verificacao, criada.url) };
    }
    if (verificacao.estado === 'pendente' && verificacao.referencia) {
      return this.atualizarIdentidade(verificacao);
    }
    return { identidade: respostaIdentidade(verificacao, null, this.identidade.disponivel) };
  }

  async solicitarRevisao(user: AuthenticatedUser, body: unknown) {
    this.exigirProfissional(user);
    corpo(body, []);
    await this.perfis.manager.transaction(async (manager) => {
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { usuarioId: user.id }, lock: { mode: 'pessimistic_write' },
      });
      if (!perfil) throw naoEncontrado();
      if (perfil.habilitacaoRevisaoEm) return;
      // An appeal must never lift a suspension or approve the applicant.
      perfil.habilitacaoRevisaoEm = new Date();
      await manager.save(ProfissionalPerfilEntity, perfil);
      await manager.save(AdminAuditoriaEntity, manager.create(AdminAuditoriaEntity, {
        atorId: user.id, acao: AdminAuditoriaAcao.HabilitacaoRevisaoSolicitada,
        alvoTipo: 'habilitacao_profissional', alvoId: perfil.id, detalhe: 'Revisao solicitada pelo titular.',
      }));
    });
    return this.minha(user);
  }

  async listar(user: AuthenticatedUser, query: Record<string, unknown>) {
    await this.exigirAdminMfa(user);
    const pagina = query.pagina ?? '1';
    if (typeof pagina !== 'string' || !/^[1-9]\d{0,4}$/.test(pagina)) throw invalido();
    const [perfis, total] = await this.perfis.findAndCount({
      relations: { usuario: true }, order: { id: 'ASC' }, take: 30, skip: (Number(pagina) - 1) * 30,
    });
    return { pagina: Number(pagina), total, profissionais: await Promise.all(perfis.map(async (p) => {
      const identidade = await this.identidades?.findOne({ where: { usuarioId: p.usuarioId }, order: { criadoEm: 'DESC' } });
      return { id: p.id, nome: p.usuario.nome, habilitacao: habilitacaoProfissional(p, etapaIdentidade(identidade?.estado)) };
    })) };
  }

  async analisar(user: AuthenticatedUser, id: number, body: unknown) {
    await this.exigirAdminMfa(user);
    const input = corpo(body, ['acao', 'motivo']);
    if (input.acao === 'aprovar') {
      throw new ConflictException({ code: 'HABILITACAO_DEPENDENCIAS_PENDENTES',
        message: 'Aprovacao indisponivel: faltam integracoes de identidade, telefone e politica de antecedentes.' });
    }
    if (typeof input.acao !== 'string' || !['suspender', 'iniciar_analise', 'reabrir'].includes(input.acao)) throw invalido();
    if (typeof input.motivo !== 'string' || !['revisao_cadastral', 'suspeita_fraude', 'solicitacao_titular'].includes(input.motivo)) throw invalido();
    const perfil = await this.perfis.manager.transaction(async (manager) => {
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { id }, lock: { mode: 'pessimistic_write' },
      });
      if (!perfil) throw naoEncontrado();
      if (perfil.usuarioId === user.id) throw new ForbiddenException();
      if (perfil.habilitacaoEstado === 'suspenso' && input.acao === 'iniciar_analise') {
        throw new ConflictException({ code: 'HABILITACAO_SUSPENSA', message: 'Reabra a analise antes de continuar.' });
      }
      perfil.habilitacaoEstado = input.acao === 'suspender' ? 'suspenso'
        : input.acao === 'iniciar_analise' ? 'em_analise' : 'pendente';
      perfil.habilitacaoRevisaoEm = null;
      await manager.save(ProfissionalPerfilEntity, perfil);
      await manager.save(AdminAuditoriaEntity, manager.create(AdminAuditoriaEntity, {
        atorId: user.id, acao: AdminAuditoriaAcao.HabilitacaoAnalisada,
        alvoTipo: 'habilitacao_profissional', alvoId: perfil.id,
        detalhe: `Acao: ${input.acao}; motivo: ${input.motivo}. Sem aprovacao para atendimento.`,
      }));
      return perfil;
    });
    perfil.usuario = (await this.usuarios.findOneBy({ id: perfil.usuarioId }))!;
    const identidade = await this.identidades?.findOne({ where: { usuarioId: perfil.usuarioId }, order: { criadoEm: 'DESC' } });
    return { habilitacao: habilitacaoProfissional(perfil, etapaIdentidade(identidade?.estado)) };
  }

  private async atualizarIdentidade(verificacao: ProfissionalIdentidadeVerificacaoEntity) {
    if (!verificacao.referencia) throw identidadeIndisponivel();
    if (!this.identidades) throw identidadeIndisponivel();
    const resultado = await this.identidade.consultar(
      verificacao.referencia,
      verificacao.referenciaExterna,
    );
    verificacao.estado = resultado.status === 'pendente' && resultado.expiraEm &&
        resultado.expiraEm.getTime() <= Date.now()
      ? 'expirada'
      : resultado.status;
    verificacao.expiraEm = resultado.expiraEm ?? verificacao.expiraEm;
    verificacao.resolvidaEm = resultado.resolvidaEm;
    await this.identidades.save(verificacao);
    return { identidade: respostaIdentidade(verificacao, resultado.url, this.identidade.disponivel) };
  }

  private exigirProfissional(user: AuthenticatedUser) {
    if (![UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(user.tipo)) throw new ForbiddenException();
  }

  private async exigirAdminMfa(user: AuthenticatedUser) {
    if (user.tipo !== UsuarioTipo.Administrador) throw new ForbiddenException();
    const admin = await this.usuarios.findOneBy({ id: user.id, ativo: true });
    if (!admin?.mfaAtivo || admin.tipo !== UsuarioTipo.Administrador) {
      throw new ForbiddenException({ code: 'MFA_ADMIN_OBRIGATORIO', message: 'Ative a verificacao em duas etapas para gerenciar habilitacoes.' });
    }
  }
}

function corpo(body: unknown, permitidas: string[]): Record<string, unknown> {
  if (body === undefined || body === null) return {};
  if (typeof body !== 'object' || Array.isArray(body) || Object.keys(body).some((k) => !permitidas.includes(k))) throw invalido();
  return body as Record<string, unknown>;
}
function etapaIdentidade(estado?: string | null): string | null {
  if (estado === 'confirmada') return 'confirmado';
  if (estado === 'pendente' || estado === 'iniciando') return 'em_analise';
  if (estado === 'revisao_necessaria') return 'revisao_necessaria';
  if (estado === 'expirada' || estado === 'falha') return 'pendente';
  return null;
}
function respostaIdentidade(
  verificacao: ProfissionalIdentidadeVerificacaoEntity | null,
  url: string | null = null,
  disponivel = true,
) {
  return {
    estado: verificacao?.estado ?? 'nao_iniciada',
    disponivel,
    url,
    expiraEm: verificacao?.expiraEm?.toISOString() ?? null,
    resolvidaEm: verificacao?.resolvidaEm?.toISOString() ?? null,
  };
}
function identidadeIndisponivel() {
  return new ServiceUnavailableException({
    code: 'VERIFICACAO_IDENTIDADE_INDISPONIVEL',
    message: 'A verificacao de identidade esta temporariamente indisponivel. Seu cadastro permanece pendente.',
  });
}
function invalido() { return new BadRequestException({ code: 'HABILITACAO_DADOS_INVALIDOS', message: 'Dados de habilitacao invalidos.' }); }
function naoEncontrado() { return new NotFoundException({ code: 'PERFIL_PROFISSIONAL_OBRIGATORIO', message: 'Cadastre seu perfil profissional primeiro.' }); }
