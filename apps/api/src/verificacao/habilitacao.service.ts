import { BadRequestException, ConflictException, ForbiddenException, HttpException, HttpStatus, Injectable, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { registrarAuditoriaAdmin } from '../common/admin-auditoria.js';
import { optionalSearchTerm } from '../common/admin-list-query.js';
import { paginationMetadata, parsePaginationQuery } from '../common/pagination.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { ProfissionalIdentidadeVerificacaoEntity } from '../database/entities/profissional-identidade-verificacao.entity.js';
import { ProfissionalTelefoneVerificacaoEntity } from '../database/entities/profissional-telefone-verificacao.entity.js';
import { ProfissionalDocumentoVerificacaoEntity } from '../database/entities/profissional-documento-verificacao.entity.js';
import {
  ProfissionalHabilitacaoRevisaoEntity,
  type AcaoRevisaoHabilitacao,
  type MotivoRevisaoHabilitacao,
} from '../database/entities/profissional-habilitacao-revisao.entity.js';
import { ProfissionalHabilitacaoImpedimentoEntity } from '../database/entities/profissional-habilitacao-impedimento.entity.js';
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
    @InjectRepository(ProfissionalTelefoneVerificacaoEntity) private readonly telefones: Repository<ProfissionalTelefoneVerificacaoEntity> | undefined = undefined,
    @InjectRepository(ProfissionalHabilitacaoRevisaoEntity) private readonly revisoes: Repository<ProfissionalHabilitacaoRevisaoEntity> | undefined = undefined,
    @InjectRepository(ProfissionalHabilitacaoImpedimentoEntity) private readonly impedimentos: Repository<ProfissionalHabilitacaoImpedimentoEntity> | undefined = undefined,
  ) {}

  async minha(user: AuthenticatedUser) {
    this.exigirProfissional(user);
    const perfil = await this.perfis.findOne({ where: { usuarioId: user.id }, relations: { usuario: true } });
    const identidade = perfil ? await this.identidades?.findOne({
      where: { usuarioId: user.id }, order: { criadoEm: 'DESC' },
    }) : null;
    const telefone = perfil ? await this.telefones?.findOne({
      where: { usuarioId: user.id }, order: { criadoEm: 'DESC' },
    }) : null;
    return { habilitacao: habilitacaoProfissional(
      perfil,
      etapaIdentidade(identidade?.estado),
      etapaTelefone(telefone, perfil?.usuario?.telefoneNormalizado, this.identidade.telefoneDisponivel),
    ) };
  }

  async iniciarTelefone(user: AuthenticatedUser, body: unknown) {
    this.exigirProfissional(user);
    const input = corpo(body, ['consentimento']);
    if (input.consentimento !== true) throw invalido();
    if (!this.identidade.telefoneDisponivel || !this.telefones) throw telefoneIndisponivel();

    const inicio = await this.telefones.manager.transaction(async (manager) => {
      const usuario = await manager.findOne(UsuarioEntity, {
        where: { id: user.id, ativo: true }, lock: { mode: 'pessimistic_write' },
      });
      if (!usuario || !usuario.telefoneNormalizado) throw telefoneAusente();
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { usuarioId: user.id, ativo: true },
      });
      if (!perfil) throw naoEncontrado();

      const repo = manager.getRepository(ProfissionalTelefoneVerificacaoEntity);
      const ultima = await repo.findOne({
        where: { usuarioId: user.id },
        order: { criadoEm: 'DESC' },
        lock: { mode: 'pessimistic_write' },
      });
      const now = new Date();
      if (ultima && ultima.telefoneVinculado !== usuario.telefoneNormalizado &&
        !['invalidada', 'expirada', 'falha'].includes(ultima.estado)) {
        ultima.estado = 'invalidada';
        ultima.resolvidaEm = now;
        ultima.tentativaEmAndamento = false;
        await repo.save(ultima);
      }
      if (ultima?.telefoneVinculado === usuario.telefoneNormalizado && ultima.estado === 'confirmada') {
        return { verificacao: ultima, iniciar: false };
      }
      if (ultima?.telefoneVinculado === usuario.telefoneNormalizado &&
        (ultima.estado === 'pendente' || ultima.estado === 'iniciando')) {
        if (ultima.estado === 'pendente' && ultima.expiraEm && ultima.expiraEm > now) {
          return { verificacao: ultima, iniciar: false };
        }
        if (ultima.estado === 'iniciando' && ultima.chaveIdempotencia) {
          return { verificacao: ultima, iniciar: true };
        }
        ultima.estado = 'expirada';
        ultima.resolvidaEm = now;
        await repo.save(ultima);
      }

      const desde = new Date(now.getTime() - 24 * 60 * 60_000);
      const recentes = await repo.createQueryBuilder('verificacao')
        .where('verificacao.usuarioId = :usuarioId', { usuarioId: user.id })
        .andWhere('verificacao.criadoEm >= :desde', { desde })
        .getCount();
      if (recentes >= 3) throw new HttpException({
        code: 'LIMITE_VERIFICACAO_TELEFONE',
        message: 'Limite diario de verificacoes atingido. Tente novamente mais tarde.',
      }, HttpStatus.TOO_MANY_REQUESTS);
      if (ultima && now.getTime() - ultima.criadoEm.getTime() < 10 * 60_000) {
        throw new ConflictException({
          code: 'AGUARDE_NOVA_VERIFICACAO_TELEFONE',
          message: 'Aguarde alguns minutos antes de solicitar outro codigo.',
        });
      }
      const verificacao = await repo.save(repo.create({
        usuarioId: user.id,
        telefoneVinculado: usuario.telefoneNormalizado,
        referencia: null,
        referenciaExterna: randomUUID(),
        chaveIdempotencia: randomUUID(),
        tentativaId: null,
        chaveIdempotenciaTentativa: null,
        tentativaEmAndamento: false,
        consentimentoEm: now,
        versaoAviso: 'conectalar-telefone-whatsapp-v1',
        estado: 'iniciando',
        tentativasRestantes: null,
        expiraEm: null,
        resolvidaEm: null,
      }));
      return { verificacao, iniciar: true };
    });

    const verificacao = inicio.verificacao;
    if (!inicio.iniciar) {
      const usuario = await this.usuarios.findOneBy({ id: user.id, ativo: true });
      return { telefone: respostaTelefone(verificacao, true, usuario?.telefoneNormalizado) };
    }
    if (!verificacao.chaveIdempotencia) throw telefoneIndisponivel();
    const criada = await this.identidade.iniciarPosseTelefone({
      telefoneE164: `+55${verificacao.telefoneVinculado}`,
      referenciaExterna: verificacao.referenciaExterna,
      chaveIdempotencia: verificacao.chaveIdempotencia,
    });
    const persistida = await this.telefones.manager.transaction(async (manager) => {
      const usuario = await manager.findOne(UsuarioEntity, {
        where: { id: user.id, ativo: true }, lock: { mode: 'pessimistic_write' },
      });
      const repo = manager.getRepository(ProfissionalTelefoneVerificacaoEntity);
      const atual = await repo.findOne({
        where: { id: verificacao.id, usuarioId: user.id }, lock: { mode: 'pessimistic_write' },
      });
      if (!usuario || !atual || usuario.telefoneNormalizado !== atual.telefoneVinculado) {
        if (atual) {
          atual.estado = 'invalidada';
          atual.resolvidaEm = new Date();
          atual.tentativaEmAndamento = false;
          await repo.save(atual);
        }
        return { invalidada: true, atual };
      }
      atual.referencia = criada.referencia;
      atual.chaveIdempotencia = null;
      atual.estado = 'pendente';
      atual.tentativasRestantes = criada.tentativasRestantes;
      atual.expiraEm = criada.expiraEm;
      await repo.save(atual);
      return { invalidada: false, atual };
    });
    if (persistida.invalidada || !persistida.atual) throw new ConflictException({
      code: 'TELEFONE_ALTERADO', message: 'O telefone mudou. Inicie uma nova confirmacao.',
    });
    const usuario = await this.usuarios.findOneBy({ id: user.id, ativo: true });
    return { telefone: respostaTelefone(persistida.atual, true, usuario?.telefoneNormalizado) };
  }

  async consultarTelefone(user: AuthenticatedUser) {
    this.exigirProfissional(user);
    if (!this.telefones) return { telefone: respostaTelefone(null, false) };
    const resultado = await this.telefones.manager.transaction(async (manager) => {
      const usuario = await manager.findOne(UsuarioEntity, {
        where: { id: user.id, ativo: true }, lock: { mode: 'pessimistic_write' },
      });
      if (!usuario) throw telefoneAusente();
      const repo = manager.getRepository(ProfissionalTelefoneVerificacaoEntity);
      const verificacao = await repo.findOne({
        where: { usuarioId: user.id }, order: { criadoEm: 'DESC' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!verificacao) return { usuario, verificacao: null };
      if (verificacao.telefoneVinculado !== usuario.telefoneNormalizado &&
        !['invalidada', 'expirada', 'falha'].includes(verificacao.estado)) {
        verificacao.estado = 'invalidada';
        verificacao.resolvidaEm = new Date();
        verificacao.tentativaEmAndamento = false;
      } else if (verificacao.estado === 'pendente' && verificacao.expiraEm && verificacao.expiraEm <= new Date()) {
        verificacao.estado = 'expirada';
        verificacao.resolvidaEm = new Date();
        verificacao.tentativaEmAndamento = false;
      } else {
        return { usuario, verificacao };
      }
      return { usuario, verificacao: await repo.save(verificacao) };
    });
    return {
      telefone: respostaTelefone(
        resultado.verificacao,
        this.identidade.telefoneDisponivel,
        resultado.usuario.telefoneNormalizado,
      ),
    };
  }

  async confirmarTelefone(user: AuthenticatedUser, body: unknown) {
    this.exigirProfissional(user);
    const input = corpo(body, ['codigo', 'tentativaId']);
    if (typeof input.codigo !== 'string' || !/^\d{1,20}$/.test(input.codigo) ||
      typeof input.tentativaId !== 'string' ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(input.tentativaId)) {
      throw invalido();
    }
    const codigo = input.codigo;
    const tentativaId = input.tentativaId as string;
    if (!this.identidade.telefoneDisponivel || !this.telefones) throw telefoneIndisponivel();

    const preparado = await this.telefones.manager.transaction(async (manager) => {
      const usuario = await manager.findOne(UsuarioEntity, {
        where: { id: user.id, ativo: true }, lock: { mode: 'pessimistic_write' },
      });
      if (!usuario?.telefoneNormalizado) throw telefoneAusente();
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { usuarioId: user.id, ativo: true },
      });
      if (!perfil) throw naoEncontrado();
      const repo = manager.getRepository(ProfissionalTelefoneVerificacaoEntity);
      const verificacao = await repo.findOne({
        where: { usuarioId: user.id }, order: { criadoEm: 'DESC' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!verificacao) throw new ConflictException({
        code: 'VERIFICACAO_TELEFONE_NAO_INICIADA',
        message: 'Solicite primeiro o codigo de confirmacao.',
      });
      if (verificacao.telefoneVinculado !== usuario.telefoneNormalizado) {
        verificacao.estado = 'invalidada';
        verificacao.resolvidaEm = new Date();
        verificacao.tentativaEmAndamento = false;
        await repo.save(verificacao);
        return { verificacao, invalidada: true, enviar: false };
      }
      if (verificacao.tentativaId === tentativaId && !verificacao.tentativaEmAndamento) {
        return { verificacao, invalidada: false, enviar: false };
      }
      if (verificacao.tentativaEmAndamento && verificacao.tentativaId !== tentativaId) {
        throw new ConflictException({ code: 'VERIFICACAO_TELEFONE_EM_ANDAMENTO', message: 'Aguarde a tentativa atual terminar.' });
      }
      if (verificacao.estado !== 'pendente' || !verificacao.referencia || !verificacao.expiraEm ||
        verificacao.expiraEm <= new Date() || verificacao.tentativasRestantes === 0) {
        if (verificacao.estado === 'pendente' && verificacao.expiraEm && verificacao.expiraEm <= new Date()) {
          verificacao.estado = 'expirada';
          verificacao.resolvidaEm = new Date();
          await repo.save(verificacao);
        }
        throw new ConflictException({
          code: 'VERIFICACAO_TELEFONE_INDISPONIVEL',
          message: 'Esta confirmacao expirou ou nao aceita mais tentativas.',
        });
      }
      const repeticao = verificacao.tentativaId === tentativaId && verificacao.tentativaEmAndamento;
      if (!repeticao) {
        verificacao.tentativaId = tentativaId;
        verificacao.chaveIdempotenciaTentativa = randomUUID();
        verificacao.tentativaEmAndamento = true;
        await repo.save(verificacao);
      }
      if (!verificacao.chaveIdempotenciaTentativa) throw telefoneIndisponivel();
      return { verificacao, invalidada: false, enviar: true };
    });

    if (preparado.invalidada) throw new ConflictException({
      code: 'TELEFONE_ALTERADO', message: 'O telefone mudou. Inicie uma nova confirmacao.',
    });
    const verificacao = preparado.verificacao;
    if (!preparado.enviar) {
      const usuario = await this.usuarios.findOneBy({ id: user.id, ativo: true });
      return { telefone: respostaTelefone(verificacao, true, usuario?.telefoneNormalizado) };
    }
    const resultado = await this.identidade.confirmarPosseTelefone({
      referencia: verificacao.referencia!,
      referenciaExterna: verificacao.referenciaExterna,
      codigo,
      chaveIdempotencia: verificacao.chaveIdempotenciaTentativa!,
    });
    return this.telefones.manager.transaction(async (manager) => {
      const usuario = await manager.findOne(UsuarioEntity, {
        where: { id: user.id, ativo: true }, lock: { mode: 'pessimistic_write' },
      });
      const repo = manager.getRepository(ProfissionalTelefoneVerificacaoEntity);
      const atual = await repo.findOne({
        where: { id: verificacao.id, usuarioId: user.id }, lock: { mode: 'pessimistic_write' },
      });
      if (!usuario || !atual || usuario.telefoneNormalizado !== atual.telefoneVinculado) {
        if (atual) {
          atual.estado = 'invalidada';
          atual.resolvidaEm = new Date();
          atual.tentativaEmAndamento = false;
          await repo.save(atual);
        }
        return { invalidada: true, verificacao: atual };
      }
      atual.estado = resultado.status;
      atual.tentativasRestantes = resultado.tentativasRestantes;
      atual.expiraEm = resultado.expiraEm ?? atual.expiraEm;
      atual.resolvidaEm = resultado.resolvidaEm;
      atual.tentativaEmAndamento = false;
      await repo.save(atual);
      return { invalidada: false, verificacao: atual, telefoneAtual: usuario.telefoneNormalizado };
    }).then((final) => {
      if (final.invalidada || !final.verificacao) {
        throw new ConflictException({ code: 'TELEFONE_ALTERADO', message: 'O telefone mudou. Inicie uma nova confirmacao.' });
      }
      return { telefone: respostaTelefone(final.verificacao, true, final.telefoneAtual) };
    });
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
    const atualizada = await this.salvarIdentidadeAtualizada(verificacao, {
      referencia: criada.referencia,
      chaveIdempotencia: null,
      estado: 'pendente',
      expiraEm: criada.expiraEm,
    });
    return { identidade: respostaIdentidade(atualizada, criada.url) };
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
      const atualizada = await this.salvarIdentidadeAtualizada(verificacao, {
        referencia: criada.referencia,
        chaveIdempotencia: null,
        estado: 'pendente',
        expiraEm: criada.expiraEm,
      });
      return { identidade: respostaIdentidade(atualizada, criada.url) };
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
      await registrarAuditoriaAdmin(manager, {
        atorId: user.id,
        acao: AdminAuditoriaAcao.HabilitacaoRevisaoSolicitada,
        alvoTipo: 'habilitacao_profissional',
        alvoId: perfil.id,
        detalhe: {
          profissionalUsuarioId: perfil.usuarioId,
          revisaoSolicitadaEm: {
            antes: null,
            depois: perfil.habilitacaoRevisaoEm.toISOString(),
          },
          efeito: 'nao_altera_estado_de_aprovacao_ou_suspensao',
        },
      });
    });
    return this.minha(user);
  }

  async listar(user: AuthenticatedUser, query: Record<string, unknown>) {
    await this.exigirAdminMfa(user);
    let pagination: ReturnType<typeof parsePaginationQuery>;
    try {
      pagination = parsePaginationQuery(query, { defaultLimit: 20, maxLimit: 100 });
    } catch {
      throw invalido();
    }
    const termo = optionalSearchTerm(query);
    const estado = optionalEstadoHabilitacao(query.estado);
    const builder = this.perfis
      .createQueryBuilder('perfil')
      .leftJoinAndSelect('perfil.usuario', 'usuario')
      .orderBy('perfil.id', 'ASC')
      .skip(pagination.skip)
      .take(pagination.limite);
    if (estado !== null) builder.andWhere('perfil.habilitacaoEstado = :estado', { estado });
    if (termo !== null) {
      builder.andWhere('(usuario.nome LIKE :termo OR usuario.email LIKE :termo)', { termo: `%${termo}%` });
    }
    const [perfis, total] = await builder.getManyAndCount();
    return {
      pagina: pagination.pagina,
      total,
      paginacao: paginationMetadata(pagination, total),
      profissionais: await Promise.all(perfis.map(async (p) => {
      const identidade = await this.identidades?.findOne({ where: { usuarioId: p.usuarioId }, order: { criadoEm: 'DESC' } });
      const telefone = await this.telefones?.findOne({ where: { usuarioId: p.usuarioId }, order: { criadoEm: 'DESC' } });
      const revisao = await this.revisoes?.findOne({
        where: { profissionalId: p.id, estado: 'aguardando_segundo_revisor' },
        order: { id: 'DESC' },
      });
      const impedimento = await this.impedimentos?.findOne({
        where: { profissionalId: p.id, administradorId: user.id },
      });
      return {
        id: p.id,
        nome: p.usuario.nome,
        revisaoAdministrativa: revisao || impedimento ? {
          id: revisao?.id ?? null,
          estado: revisao?.estado ?? 'revisor_impedido',
          jaVotou: revisao?.primeiroRevisorId === user.id,
          impedido: impedimento !== null && impedimento !== undefined,
        } : null,
        habilitacao: habilitacaoProfissional(
          p,
          etapaIdentidade(identidade?.estado),
          etapaTelefone(telefone, p.usuario.telefoneNormalizado, this.identidade.telefoneDisponivel),
        ),
      };
      })),
    };
  }

  async analisar(user: AuthenticatedUser, id: number, body: unknown) {
    await this.exigirAdminMfa(user);
    const input = corpo(body, ['acao', 'motivo', 'revisaoId', 'semConflito']);
    if (input.acao === 'aprovar') {
      throw new ConflictException({ code: 'HABILITACAO_DEPENDENCIAS_PENDENTES',
        message: 'Aprovacao indisponivel: faltam integracoes de identidade, telefone e politica de antecedentes.' });
    }
    if (typeof input.acao !== 'string' || !['suspender', 'iniciar_analise', 'reabrir', 'recusar_conflito'].includes(input.acao)) throw invalido();
    const acaoRecebida = input.acao;
    const motivoValido = acaoRecebida === 'recusar_conflito'
      ? input.motivo === 'conflito_interesse'
      : typeof input.motivo === 'string' && ['revisao_cadastral', 'suspeita_fraude', 'solicitacao_titular'].includes(input.motivo);
    if (!motivoValido) throw invalido();
    if (input.semConflito !== undefined && typeof input.semConflito !== 'boolean') throw invalido();
    if (['iniciar_analise', 'reabrir'].includes(acaoRecebida) && input.semConflito !== true) {
      throw new ConflictException({
        code: 'HABILITACAO_DECLARACAO_CONFLITO_OBRIGATORIA',
        message: 'Confirme que não possui conflito de interesse antes de votar.',
      });
    }
    if (acaoRecebida === 'recusar_conflito' && input.semConflito !== undefined) throw invalido();
    const revisaoId = input.revisaoId;
    if (revisaoId !== undefined && (!Number.isSafeInteger(revisaoId) || (revisaoId as number) < 1)) throw invalido();
    const acao = input.acao as 'suspender' | 'recusar_conflito' | AcaoRevisaoHabilitacao;
    const motivo = input.motivo as MotivoRevisaoHabilitacao | 'conflito_interesse';
    if (!this.revisoes || !this.impedimentos) throw new ConflictException({
      code: 'HABILITACAO_REVISAO_INDISPONIVEL',
      message: 'A revisão administrativa em duas etapas ainda não está disponível.',
    });
    // Resolve the owner before the transaction so its first locking read can
    // lock the user row, the shared serialization point for contact changes.
    const perfilReferencia = await this.perfis.findOne({ where: { id } });
    if (!perfilReferencia) throw naoEncontrado();
    if (perfilReferencia.usuarioId === user.id) throw new ForbiddenException();
    const resultado = await this.perfis.manager.transaction(async (manager) => {
      const titular = await manager.findOne(UsuarioEntity, {
        where: { id: perfilReferencia.usuarioId },
        lock: { mode: 'pessimistic_write' },
      });
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { id }, lock: { mode: 'pessimistic_write' },
      });
      if (!titular || !perfil || perfil.usuarioId !== perfilReferencia.usuarioId) throw naoEncontrado();
      if (perfil.usuarioId === user.id) throw new ForbiddenException();

      const admin = await manager.findOne(UsuarioEntity, {
        where: { id: user.id, ativo: true, tipo: UsuarioTipo.Administrador },
        lock: { mode: 'pessimistic_read' },
      });
      if (!admin?.mfaAtivo) {
        throw new ForbiddenException({ code: 'MFA_ADMIN_OBRIGATORIO', message: 'Ative a verificacao em duas etapas para gerenciar habilitacoes.' });
      }

      const revisoes = manager.getRepository(ProfissionalHabilitacaoRevisaoEntity);
      const impedimentos = manager.getRepository(ProfissionalHabilitacaoImpedimentoEntity);
      const aberta = await revisoes.findOne({
        where: { profissionalId: perfil.id, estado: 'aguardando_segundo_revisor' },
        order: { id: 'DESC' },
        lock: { mode: 'pessimistic_write' },
      });
      const impedimentoExistente = await impedimentos.findOne({
        where: { profissionalId: perfil.id, administradorId: user.id },
        lock: { mode: 'pessimistic_write' },
      });

      if (acao === 'recusar_conflito') {
        if (impedimentoExistente) {
          return { perfil, decisaoDupla: { estado: 'revisor_impedido', revisaoId: aberta?.id ?? null } };
        }
        if ((aberta && revisaoId !== aberta.id) || (!aberta && revisaoId !== undefined)) {
          throw new ConflictException({
            code: 'HABILITACAO_REVISAO_INDISPONIVEL',
            message: 'A revisão mudou. Atualize a lista antes de registrar o impedimento.',
          });
        }
        if (aberta) {
          aberta.estado = 'cancelada';
          aberta.resolvidaEm = new Date();
          await revisoes.save(aberta);
        }
        await impedimentos.save(impedimentos.create({
          profissionalId: perfil.id,
          administradorId: user.id,
        }));
        await registrarAuditoriaAdmin(manager, {
          atorId: user.id,
          acao: AdminAuditoriaAcao.HabilitacaoRevisorImpedido,
          alvoTipo: 'habilitacao_profissional',
          alvoId: perfil.id,
          detalhe: {
            profissionalUsuarioId: perfil.usuarioId,
            ...(aberta ? { revisaoId: aberta.id } : {}),
            motivo: 'conflito_interesse',
            resultado: 'revisor_impedido',
          },
        });
        return { perfil, decisaoDupla: { estado: 'revisor_impedido', revisaoId: aberta?.id ?? null } };
      }

      if (impedimentoExistente) throw new ForbiddenException({
        code: 'HABILITACAO_REVISOR_IMPEDIDO',
        message: 'Você declarou impedimento para revisar este perfil.',
      });
      const motivoRevisao = motivo as MotivoRevisaoHabilitacao;

      if (acao === 'suspender') {
        if (revisaoId !== undefined) throw invalido();
        if (aberta) {
          aberta.estado = 'cancelada';
          aberta.resolvidaEm = new Date();
          await revisoes.save(aberta);
          await registrarAuditoriaAdmin(manager, {
            atorId: user.id,
            acao: AdminAuditoriaAcao.HabilitacaoDecisaoDupla,
            alvoTipo: 'habilitacao_profissional',
            alvoId: perfil.id,
            detalhe: { profissionalUsuarioId: perfil.usuarioId, revisaoId: aberta.id, resultado: 'cancelada' },
          });
        }
        const estadoAnterior = perfil.habilitacaoEstado;
        const revisaoAnterior = perfil.habilitacaoRevisaoEm;
        perfil.habilitacaoEstado = 'suspenso';
        perfil.habilitacaoRevisaoEm = null;
        await manager.save(ProfissionalPerfilEntity, perfil);
        await registrarAuditoriaAdmin(manager, {
          atorId: user.id,
          acao: AdminAuditoriaAcao.HabilitacaoAnalisada,
          alvoTipo: 'habilitacao_profissional',
          alvoId: perfil.id,
          detalhe: {
            profissionalUsuarioId: perfil.usuarioId,
            estado: { antes: estadoAnterior, depois: perfil.habilitacaoEstado },
            revisaoSolicitadaEm: { antes: revisaoAnterior?.toISOString() ?? null, depois: null },
            acao: 'suspender', motivo, aprovacaoConcedida: false,
          },
        });
        return { perfil, decisaoDupla: { estado: 'suspensao_imediata', revisaoId: aberta?.id ?? null } };
      }

      if (acao === 'iniciar_analise' && perfil.habilitacaoEstado === 'suspenso') {
        throw new ConflictException({ code: 'HABILITACAO_SUSPENSA', message: 'Reabra a analise antes de continuar.' });
      }
      const assinaturaDossie = await this.assinaturaDossie(manager, perfil, titular);

      if (revisaoId === undefined) {
        if (aberta) throw new ConflictException({
          code: 'HABILITACAO_REVISAO_PENDENTE',
          message: 'Já existe uma revisão aguardando outro administrador. Atualize a lista e registre seu voto individual.',
        });
        const nova = await revisoes.save(revisoes.create({
          profissionalId: perfil.id,
          estadoInicial: perfil.habilitacaoEstado,
          assinaturaDossie,
          primeiroSemConflito: true,
          acaoPrimeiroVoto: acao,
          motivoPrimeiroVoto: motivoRevisao,
          primeiroRevisorId: user.id,
          primeiroVotoEm: new Date(),
          acaoSegundoVoto: null,
          motivoSegundoVoto: null,
          segundoRevisorId: null,
          segundoVotoEm: null,
          segundoSemConflito: null,
          estado: 'aguardando_segundo_revisor',
          resolvidaEm: null,
        }));
        await registrarAuditoriaAdmin(manager, {
          atorId: user.id,
          acao: AdminAuditoriaAcao.HabilitacaoVotoRegistrado,
          alvoTipo: 'habilitacao_profissional',
          alvoId: perfil.id,
          detalhe: {
            profissionalUsuarioId: perfil.usuarioId,
            revisaoId: nova.id,
            estado: 'aguardando_segundo_revisor',
            semConflitoConfirmado: true,
          },
        });
        return { perfil, decisaoDupla: { estado: 'aguardando_segundo_revisor', revisaoId: nova.id } };
      }

      if (!aberta || aberta.id !== (revisaoId as number)) throw new ConflictException({
        code: 'HABILITACAO_REVISAO_INDISPONIVEL', message: 'Esta revisão não está mais aguardando um segundo administrador.',
      });
      const primeiroRevisor = await manager.findOne(UsuarioEntity, {
        where: { id: aberta.primeiroRevisorId, ativo: true, tipo: UsuarioTipo.Administrador },
        lock: { mode: 'pessimistic_read' },
      });
      if (!primeiroRevisor?.mfaAtivo) {
        aberta.estado = 'cancelada';
        aberta.resolvidaEm = new Date();
        await revisoes.save(aberta);
        await registrarAuditoriaAdmin(manager, {
          atorId: user.id,
          acao: AdminAuditoriaAcao.HabilitacaoDecisaoDupla,
          alvoTipo: 'habilitacao_profissional',
          alvoId: perfil.id,
          detalhe: { profissionalUsuarioId: perfil.usuarioId, revisaoId: aberta.id, resultado: 'cancelada' },
        });
        return { perfil, decisaoDupla: { estado: 'cancelada', revisaoId: aberta.id } };
      }
      if (aberta.primeiroSemConflito !== true) {
        aberta.estado = 'cancelada';
        aberta.resolvidaEm = new Date();
        await revisoes.save(aberta);
        await registrarAuditoriaAdmin(manager, {
          atorId: user.id,
          acao: AdminAuditoriaAcao.HabilitacaoDecisaoDupla,
          alvoTipo: 'habilitacao_profissional',
          alvoId: perfil.id,
          detalhe: { profissionalUsuarioId: perfil.usuarioId, revisaoId: aberta.id, resultado: 'cancelada' },
        });
        return { perfil, decisaoDupla: { estado: 'cancelada', revisaoId: aberta.id } };
      }
      if (aberta.primeiroRevisorId === user.id) {
        if (aberta.acaoPrimeiroVoto === acao && aberta.motivoPrimeiroVoto === motivo) {
          return { perfil, decisaoDupla: { estado: 'aguardando_segundo_revisor', revisaoId: aberta.id } };
        }
        throw new ConflictException({
          code: 'HABILITACAO_REVISOR_REPETIDO', message: 'O segundo voto deve ser registrado por outro administrador.',
        });
      }
      aberta.acaoSegundoVoto = acao;
      aberta.motivoSegundoVoto = motivoRevisao;
      aberta.segundoRevisorId = user.id;
      aberta.segundoVotoEm = new Date();
      aberta.segundoSemConflito = true;
      if (aberta.estadoInicial !== perfil.habilitacaoEstado) {
        aberta.estado = 'cancelada';
        aberta.resolvidaEm = new Date();
        await revisoes.save(aberta);
        await registrarAuditoriaAdmin(manager, {
          atorId: user.id,
          acao: AdminAuditoriaAcao.HabilitacaoVotoRegistrado,
          alvoTipo: 'habilitacao_profissional',
          alvoId: perfil.id,
          detalhe: {
            profissionalUsuarioId: perfil.usuarioId,
            revisaoId: aberta.id,
            estado: 'cancelada',
            semConflitoConfirmado: true,
          },
        });
        await registrarAuditoriaAdmin(manager, {
          atorId: user.id,
          acao: AdminAuditoriaAcao.HabilitacaoDecisaoDupla,
          alvoTipo: 'habilitacao_profissional',
          alvoId: perfil.id,
          detalhe: {
            profissionalUsuarioId: perfil.usuarioId, revisaoId: aberta.id,
            primeiroRevisorId: aberta.primeiroRevisorId, segundoRevisorId: user.id,
            resultado: 'cancelada', semConflitoConfirmado: true,
          },
        });
        return { perfil, decisaoDupla: { estado: 'cancelada', revisaoId: aberta.id } };
      }
      if (aberta.assinaturaDossie !== assinaturaDossie) {
        aberta.estado = 'cancelada';
        aberta.resolvidaEm = new Date();
        await revisoes.save(aberta);
        await registrarAuditoriaAdmin(manager, {
          atorId: user.id,
          acao: AdminAuditoriaAcao.HabilitacaoVotoRegistrado,
          alvoTipo: 'habilitacao_profissional',
          alvoId: perfil.id,
          detalhe: {
            profissionalUsuarioId: perfil.usuarioId,
            revisaoId: aberta.id,
            estado: 'cancelada',
            semConflitoConfirmado: true,
          },
        });
        await registrarAuditoriaAdmin(manager, {
          atorId: user.id,
          acao: AdminAuditoriaAcao.HabilitacaoDecisaoDupla,
          alvoTipo: 'habilitacao_profissional',
          alvoId: perfil.id,
          detalhe: {
            profissionalUsuarioId: perfil.usuarioId, revisaoId: aberta.id,
            primeiroRevisorId: aberta.primeiroRevisorId, segundoRevisorId: user.id,
            acaoPrimeiroVoto: aberta.acaoPrimeiroVoto, motivoPrimeiroVoto: aberta.motivoPrimeiroVoto,
            acaoSegundoVoto: acao, motivoSegundoVoto: motivo, resultado: 'cancelada',
            semConflitoConfirmado: true,
          },
        });
        return { perfil, decisaoDupla: { estado: 'cancelada', revisaoId: aberta.id } };
      }

      aberta.resolvidaEm = new Date();
      aberta.estado = aberta.acaoPrimeiroVoto === acao
        ? 'concluida' : 'divergente';
      await revisoes.save(aberta);
      await registrarAuditoriaAdmin(manager, {
        atorId: user.id,
        acao: AdminAuditoriaAcao.HabilitacaoVotoRegistrado,
        alvoTipo: 'habilitacao_profissional',
        alvoId: perfil.id,
        detalhe: {
          profissionalUsuarioId: perfil.usuarioId,
          revisaoId: aberta.id,
          estado: aberta.estado,
          semConflitoConfirmado: true,
        },
      });
      if (aberta.estado === 'divergente') {
        await registrarAuditoriaAdmin(manager, {
          atorId: user.id,
          acao: AdminAuditoriaAcao.HabilitacaoDecisaoDupla,
          alvoTipo: 'habilitacao_profissional',
          alvoId: perfil.id,
          detalhe: {
            profissionalUsuarioId: perfil.usuarioId,
            revisaoId: aberta.id,
            primeiroRevisorId: aberta.primeiroRevisorId,
            segundoRevisorId: user.id,
            acaoPrimeiroVoto: aberta.acaoPrimeiroVoto,
            motivoPrimeiroVoto: aberta.motivoPrimeiroVoto,
            acaoSegundoVoto: acao,
            motivoSegundoVoto: motivo,
            resultado: 'divergente', semConflitoConfirmado: true,
          },
        });
        return { perfil, decisaoDupla: { estado: 'divergente', revisaoId: aberta.id } };
      }

      const estadoAnterior = perfil.habilitacaoEstado;
      const revisaoAnterior = perfil.habilitacaoRevisaoEm;
      perfil.habilitacaoEstado = acao === 'iniciar_analise' ? 'em_analise' : 'pendente';
      perfil.habilitacaoRevisaoEm = null;
      await manager.save(ProfissionalPerfilEntity, perfil);
      await registrarAuditoriaAdmin(manager, {
        atorId: user.id,
        acao: AdminAuditoriaAcao.HabilitacaoDecisaoDupla,
        alvoTipo: 'habilitacao_profissional',
        alvoId: perfil.id,
        detalhe: {
          profissionalUsuarioId: perfil.usuarioId,
          revisaoId: aberta.id,
          primeiroRevisorId: aberta.primeiroRevisorId,
          segundoRevisorId: user.id,
          estado: { antes: estadoAnterior, depois: perfil.habilitacaoEstado },
          acao,
          motivo,
          acaoPrimeiroVoto: aberta.acaoPrimeiroVoto,
          motivoPrimeiroVoto: aberta.motivoPrimeiroVoto,
          acaoSegundoVoto: acao,
          motivoSegundoVoto: motivo,
          resultado: 'concluida',
          semConflitoConfirmado: true,
          aprovacaoConcedida: false,
        },
      });
      return { perfil, decisaoDupla: { estado: 'concluida', revisaoId: aberta.id } };
    });
    const perfil = resultado.perfil;
    perfil.usuario = (await this.usuarios.findOneBy({ id: perfil.usuarioId }))!;
    const identidade = await this.identidades?.findOne({ where: { usuarioId: perfil.usuarioId }, order: { criadoEm: 'DESC' } });
    const telefone = await this.telefones?.findOne({ where: { usuarioId: perfil.usuarioId }, order: { criadoEm: 'DESC' } });
    return {
      habilitacao: habilitacaoProfissional(perfil, etapaIdentidade(identidade?.estado),
        etapaTelefone(telefone, perfil.usuario?.telefoneNormalizado, this.identidade.telefoneDisponivel)),
      decisaoDupla: resultado.decisaoDupla,
    };
  }

  private async assinaturaDossie(
    manager: import('typeorm').EntityManager,
    perfil: ProfissionalPerfilEntity,
    usuario: UsuarioEntity,
  ): Promise<string> {
    const documentos = await manager.getRepository(ProfissionalDocumentoVerificacaoEntity).find({
      where: { profissionalId: perfil.id }, order: { id: 'ASC' },
    });
    const identidade = await manager.getRepository(ProfissionalIdentidadeVerificacaoEntity).findOne({
      where: { usuarioId: perfil.usuarioId }, order: { criadoEm: 'DESC' },
    });
    const telefone = await manager.getRepository(ProfissionalTelefoneVerificacaoEntity).findOne({
      where: { usuarioId: perfil.usuarioId }, order: { criadoEm: 'DESC' },
    });
    const data = (value: Date | null | undefined) => value?.toISOString() ?? null;
    const material = {
      perfil: {
        id: perfil.id,
        atualizadoEm: data(perfil.atualizadoEm),
        ativo: perfil.ativo,
        verificado: perfil.verificado,
      },
      usuario: {
        ativo: usuario?.ativo ?? false,
        emailVerificado: usuario?.emailVerificado ?? false,
        telefoneNormalizado: usuario?.telefoneNormalizado ?? null,
      },
      documentos: documentos.map((documento) => ({
        id: documento.id,
        tipo: documento.tipoDocumento,
        status: documento.status,
        criadoEm: data(documento.criadoEm),
        analisadoEm: data(documento.analisadoEm),
        atualizadoEm: data(documento.atualizadoEm),
      })),
      identidade: identidade ? {
        id: identidade.id,
        estado: identidade.estado,
        expiraEm: data(identidade.expiraEm),
        resolvidaEm: data(identidade.resolvidaEm),
        atualizadoEm: data(identidade.atualizadoEm),
      } : null,
      telefone: telefone ? {
        id: telefone.id,
        telefoneVinculado: telefone.telefoneVinculado,
        estado: telefone.estado,
        expiraEm: data(telefone.expiraEm),
        resolvidaEm: data(telefone.resolvidaEm),
        atualizadoEm: data(telefone.atualizadoEm),
      } : null,
    };
    return createHash('sha256').update(JSON.stringify(material)).digest('hex');
  }

  private async atualizarIdentidade(verificacao: ProfissionalIdentidadeVerificacaoEntity) {
    if (!verificacao.referencia) throw identidadeIndisponivel();
    if (!this.identidades) throw identidadeIndisponivel();
    const resultado = await this.identidade.consultar(
      verificacao.referencia,
      verificacao.referenciaExterna,
    );
    const estado = resultado.status === 'pendente' && resultado.expiraEm &&
        resultado.expiraEm.getTime() <= Date.now()
      ? 'expirada'
      : resultado.status;
    const atualizada = await this.salvarIdentidadeAtualizada(verificacao, {
      estado,
      expiraEm: resultado.expiraEm ?? verificacao.expiraEm,
      resolvidaEm: resultado.resolvidaEm,
    });
    return { identidade: respostaIdentidade(atualizada, resultado.url, this.identidade.disponivel) };
  }

  private async salvarIdentidadeAtualizada(
    referencia: ProfissionalIdentidadeVerificacaoEntity,
    alteracoes: Partial<Pick<ProfissionalIdentidadeVerificacaoEntity,
      'referencia' | 'chaveIdempotencia' | 'estado' | 'expiraEm' | 'resolvidaEm'>>,
  ): Promise<ProfissionalIdentidadeVerificacaoEntity> {
    const identidades = this.identidades;
    if (!identidades) throw identidadeIndisponivel();
    return identidades.manager.transaction(async (manager) => {
      const usuario = await manager.findOne(UsuarioEntity, {
        where: { id: referencia.usuarioId, ativo: true }, lock: { mode: 'pessimistic_write' },
      });
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { usuarioId: referencia.usuarioId }, lock: { mode: 'pessimistic_write' },
      });
      if (!usuario || !perfil) throw naoEncontrado();
      const repo = manager.getRepository(ProfissionalIdentidadeVerificacaoEntity);
      const atual = await repo.findOne({
        where: { id: referencia.id, usuarioId: referencia.usuarioId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!atual || atual.referenciaExterna !== referencia.referenciaExterna ||
        atual.referencia !== referencia.referencia) {
        throw new ConflictException({
          code: 'IDENTIDADE_ALTERADA',
          message: 'A verificação de identidade mudou. Atualize o estado antes de continuar.',
        });
      }
      Object.assign(atual, alteracoes);
      return repo.save(atual);
    });
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
function etapaTelefone(
  verificacao: ProfissionalTelefoneVerificacaoEntity | null | undefined,
  telefoneAtual: string | null | undefined,
  disponivel: boolean,
): string {
  if (!telefoneAtual) return 'telefone_ausente';
  if (!verificacao) return disponivel ? 'nao_iniciada' : 'aguardando_integracao';
  if (verificacao.telefoneVinculado !== telefoneAtual && verificacao.estado !== 'invalidada') return 'invalidada';
  if (verificacao.estado === 'confirmada') return 'confirmado';
  if (verificacao.estado === 'pendente' || verificacao.estado === 'iniciando') return 'em_analise';
  if (verificacao.estado === 'expirada') return 'expirada';
  if (verificacao.estado === 'falha' || verificacao.estado === 'revisao_necessaria') return 'revisao_necessaria';
  return verificacao.estado;
}
function respostaTelefone(
  verificacao: ProfissionalTelefoneVerificacaoEntity | null,
  disponivel = true,
  telefoneAtual?: string | null,
) {
  const vinculado = verificacao?.telefoneVinculado ?? null;
  const estado = verificacao && telefoneAtual !== undefined && vinculado !== telefoneAtual &&
    verificacao.estado !== 'invalidada' ? 'invalidada' : verificacao?.estado ??
      (telefoneAtual ? 'nao_iniciada' : 'telefone_ausente');
  const telefoneParaExibir = vinculado === telefoneAtual ? vinculado : telefoneAtual ?? null;
  return {
    estado,
    disponivel,
    tentativaId: verificacao?.tentativaEmAndamento ? verificacao.tentativaId : null,
    telefoneMascarado: mascararTelefone(telefoneParaExibir),
    tentativasRestantes: estado === 'pendente' ? verificacao?.tentativasRestantes ?? null : null,
    expiraEm: verificacao?.expiraEm?.toISOString() ?? null,
    resolvidaEm: verificacao?.resolvidaEm?.toISOString() ?? null,
  };
}
function mascararTelefone(telefone: string | null): string | null {
  if (!telefone) return null;
  const digits = telefone.replace(/\D/g, '');
  if (digits.length < 4) return null;
  return `+55 (***) *****-${digits.slice(-4)}`;
}
function telefoneAusente() {
  return new ConflictException({ code: 'TELEFONE_OBRIGATORIO', message: 'Cadastre um telefone valido antes de solicitar a confirmacao.' });
}
function telefoneIndisponivel() {
  return new ServiceUnavailableException({
    code: 'VERIFICACAO_TELEFONE_INDISPONIVEL',
    message: 'A confirmacao por telefone nao esta disponivel. Seu cadastro continua pendente.',
  });
}
function identidadeIndisponivel() {
  return new ServiceUnavailableException({
    code: 'VERIFICACAO_IDENTIDADE_INDISPONIVEL',
    message: 'A verificacao de identidade esta temporariamente indisponivel. Seu cadastro permanece pendente.',
  });
}
function optionalEstadoHabilitacao(value: unknown): string | null {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value === 'string' && ['pendente', 'em_analise', 'suspenso'].includes(value)) {
    return value;
  }
  throw new BadRequestException({ code: 'FILTRO_INVALIDO', message: 'Filtro invalido.' });
}

function invalido() { return new BadRequestException({ code: 'HABILITACAO_DADOS_INVALIDOS', message: 'Dados de habilitacao invalidos.' }); }
function naoEncontrado() { return new NotFoundException({ code: 'PERFIL_PROFISSIONAL_OBRIGATORIO', message: 'Cadastre seu perfil profissional primeiro.' }); }
