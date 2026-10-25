import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, Brackets, EntityManager, In, Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { AvaliacaoEntity } from '../database/entities/avaliacao.entity.js';
import { AvaliacaoModeracaoStatus } from '../domain/avaliacao-moderacao-status.js';
import { CategoriaEntity } from '../database/entities/categoria.entity.js';
import { ClienteEnderecoEntity } from '../database/entities/cliente-endereco.entity.js';
import { ProfissionalDisponibilidadeEntity } from '../database/entities/profissional-disponibilidade.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { ProfissionalServicoEntity } from '../database/entities/profissional-servico.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { SolicitacaoStatus } from '../domain/solicitacao-status.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { LocalizacaoService } from '../localizacao/localizacao.service.js';
import { fotoPerfilUrl } from '../usuarios/foto-perfil.storage.js';
import { podeAtender } from '../verificacao/habilitacao-profissional.js';
import { diaAnterior, duracaoLegadaMinutos, fusoAgenda, intervalosLivres, minutosHorario } from '../domain/agendamento.js';

interface ProfissionalServicoInput {
  readonly id?: number | null;
  readonly nome: string;
  readonly categoriaId?: number | null;
  readonly precoInicial?: number | null;
  readonly ativo?: boolean;
  readonly duracaoMinutos: number;
  readonly intervaloMinutos: number;
}

interface UpsertPerfilInput {
  readonly descricao: string;
  readonly bairro: string;
  readonly cep: string | null;
  readonly cidade: string | null;
  readonly uf: string | null;
  readonly raioAtendimentoKm: number;
  readonly precoInicial?: number | null;
  readonly servicos: readonly ProfissionalServicoInput[];
}

@Injectable()
export class ProfissionaisService {
  constructor(
    @InjectRepository(AvaliacaoEntity)
    private readonly avaliacoes: Repository<AvaliacaoEntity>,
    @InjectRepository(CategoriaEntity)
    private readonly categorias: Repository<CategoriaEntity>,
    @InjectRepository(ProfissionalDisponibilidadeEntity)
    private readonly disponibilidades: Repository<ProfissionalDisponibilidadeEntity>,
    @InjectRepository(ProfissionalPerfilEntity)
    private readonly perfis: Repository<ProfissionalPerfilEntity>,
    @InjectRepository(ProfissionalServicoEntity)
    private readonly servicos: Repository<ProfissionalServicoEntity>,
    @InjectRepository(SolicitacaoEntity)
    private readonly solicitacoes: Repository<SolicitacaoEntity>,
    @InjectRepository(UsuarioEntity)
    private readonly usuarios: Repository<UsuarioEntity>,
    private readonly localizacao: LocalizacaoService,
  ) {}

  async listar(query: Record<string, unknown>) {
    return this.listarComFiltros(query);
  }

  async buscar(body: unknown) {
    return this.listarComFiltros(objectBody(body), true);
  }

  private async listarComFiltros(
    query: Record<string, unknown>,
    exigirRaio = false,
  ) {
    const paginacao = parseProfissionaisPaginacao(query);
    const termo = optionalText(query.termo, 80);
    const bairro = optionalText(query.bairro, 80);
    const categoriaId = optionalId(query.categoriaId);
    const cidade = optionalText(query.cidade, 120);
    const uf = optionalText(query.uf, 2)?.toUpperCase() ?? null;
    const latitude = optionalCoordinate(query.latitude, -90, 90);
    const longitude = optionalCoordinate(query.longitude, -180, 180);
    const raioKm = optionalRadius(query.raioKm);
    const temLatitude = latitude !== null;
    const temLongitude = longitude !== null;
    if (exigirRaio && raioKm === null) {
      throw badRequest('RAIO_ATENDIMENTO_INVALIDO');
    }
    if (temLatitude !== temLongitude || (raioKm !== null && !temLatitude)) {
      throw badRequest('COORDENADA_INVALIDA');
    }

    const builder = this.perfis
      .createQueryBuilder('perfil')
      .leftJoinAndSelect('perfil.usuario', 'usuario')
      .leftJoinAndSelect(
        'perfil.servicos',
        'servico',
        'servico.ativo = :ativo',
        { ativo: true },
      )
      .leftJoinAndSelect('servico.categoria', 'categoria')
      .leftJoin('perfil.servicos', 'servicoFiltro', 'servicoFiltro.ativo = :ativo', {
        ativo: true,
      })
      .leftJoin('servicoFiltro.categoria', 'categoriaFiltro')
      .where('perfil.ativo = :ativo', { ativo: true })
      .andWhere('usuario.ativo = :ativo', { ativo: true })
      .andWhere('usuario.tipo IN (:...tipos)', {
        tipos: [UsuarioTipo.Profissional, UsuarioTipo.Empresa],
      })
      .distinct(true);

    if (termo !== null) {
      const padrao = `%${termo}%`;
      builder.andWhere(
        new Brackets((filtros) =>
          filtros
            .where('usuario.nome LIKE :termo', { termo: padrao })
            .orWhere('perfil.descricao LIKE :termo')
            .orWhere('perfil.bairro LIKE :termo')
            .orWhere('servicoFiltro.nome LIKE :termo')
            .orWhere('categoriaFiltro.nome LIKE :termo'),
        ),
      );
    }
    if (categoriaId !== null) {
      builder.andWhere('servicoFiltro.categoriaId = :categoriaId', {
        categoriaId,
      });
    }
    if (latitude === null && (bairro !== null || cidade !== null || uf !== null)) {
      builder.andWhere(
        new Brackets((localizacao) => {
          if (bairro !== null) {
            localizacao.where('perfil.bairro LIKE :bairro', { bairro: `%${bairro}%` });
          }
          if (cidade !== null) {
            const condicao = uf === null
              ? 'perfil.cidade LIKE :cidade'
              : '(perfil.cidade LIKE :cidade AND perfil.uf = :uf)';
            const parametros = { cidade: `%${cidade}%`, uf };
            if (bairro !== null) localizacao.orWhere(condicao, parametros);
            else localizacao.where(condicao, parametros);
          } else if (uf !== null) {
            if (bairro !== null) localizacao.orWhere('perfil.uf = :uf', { uf });
            else localizacao.where('perfil.uf = :uf', { uf });
          }
        }),
      );
    }

    if (latitude !== null && longitude !== null) {
      const distancia = distanciaSql();
      const coordenadas = { latitude, longitude };
      builder
        .addSelect(distancia, 'distancia_km')
        .addSelect(`COALESCE(${distancia}, 1000000000)`, 'distancia_ordenacao')
        .setParameters(coordenadas);
      if (raioKm !== null) {
        builder
          .andWhere('perfil.latitude IS NOT NULL AND perfil.longitude IS NOT NULL')
          .andWhere(`${distancia} <= LEAST(:raioKm, perfil.raioAtendimentoKm)`, {
            ...coordenadas,
            raioKm,
          });
      }
      builder
        .orderBy('distancia_ordenacao', 'ASC')
        .addOrderBy('perfil.verificado', 'DESC')
        .addOrderBy('usuario.nome', 'ASC')
        .addOrderBy('perfil.id', 'ASC');
    } else {
      builder
        .orderBy('perfil.verificado', 'DESC')
        .addOrderBy('usuario.nome', 'ASC')
        .addOrderBy('perfil.id', 'ASC');
    }

    builder
      .skip((paginacao.pagina - 1) * paginacao.limite)
      .take(paginacao.limite);
    const [perfis, total] = await builder.getManyAndCount();
    const resumos = await this.resumosAvaliacoes(
      perfis.map((perfil) => perfil.usuarioId),
    );
    return {
      profissionais: perfis.map((perfil) => {
        const distanciaKm = latitude === null || longitude === null
          ? null
          : distanciaDoPerfil(perfil, latitude, longitude);
        return {
          ...perfilPublico(perfil),
          ...resumos.get(perfil.usuarioId),
          distanciaKm:
            distanciaKm === null ? null : Math.round(distanciaKm * 10) / 10,
        };
      }),
      paginacao: {
        pagina: paginacao.pagina,
        limite: paginacao.limite,
        total,
        totalPaginas: Math.max(1, Math.ceil(total / paginacao.limite)),
        temMais: paginacao.pagina * paginacao.limite < total,
      },
    };
  }

  async obter(id: number) {
    const perfil = await this.perfis.findOne({
      where: { id, ativo: true },
      relations: { usuario: true, servicos: { categoria: true } },
    });
    if (
      perfil === null ||
      !perfil.usuario.ativo ||
      ![UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(
        perfil.usuario.tipo,
      )
    ) {
      throw new NotFoundException({
        code: 'PROFISSIONAL_NAO_ENCONTRADO',
        message: 'Profissional nao encontrado.',
      });
    }

    return { profissional: await this.comResumo(perfil) };
  }

  async meuPerfil(user: AuthenticatedUser) {
    const perfil = await this.perfis.findOne({
      where: { usuarioId: user.id },
      relations: { usuario: true, servicos: { categoria: true } },
    });

    if (perfil === null) return { profissional: null };
    return {
      profissional: {
        ...(await this.comResumo(perfil)),
        cep: perfil.cep,
      },
    };
  }

  async horariosLivres(id: number, query: Record<string, unknown>) {
    await this.obter(id);
    const data = query.data;
    if (typeof data !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(data) ||
      !Number.isFinite(Date.parse(`${data}T00:00:00Z`)) ||
      new Date(`${data}T00:00:00Z`).toISOString().slice(0, 10) !== data) {
      throw badRequest('DATA_INVALIDA');
    }
    const servicoId = optionalId(query.servicoId);
    const oferta = servicoId === null ? null : await this.servicos.findOne({
      where: { id: servicoId, profissionalId: id, ativo: true },
    });
    if (servicoId !== null && oferta === null) throw badRequest('OFERTA_INDISPONIVEL');
    const duracaoMinutos = oferta?.duracaoMinutos ?? duracaoLegadaMinutos;
    const [semanais, ocupados] = await Promise.all([
      this.disponibilidades.find({ where: { profissionalId: id, ativo: true } }),
      this.solicitacoes.find({ where: {
        profissionalId: id, status: SolicitacaoStatus.AceitaAgendada,
        dataServico: Between(diaAnterior(data), data),
      } }),
    ]);
    // Only free windows are public: no customer, request IDs, address, or busy
    // appointment details leave this endpoint.
    return {
      data, fusoHorario: fusoAgenda, duracaoMinutos,
      intervalos: intervalosLivres(data, semanais, ocupados).filter((item) =>
        minutosHorario(item.horaFim) - minutosHorario(item.horaInicio) >= duracaoMinutos),
    };
  }

  async salvarMeuPerfil(user: AuthenticatedUser, body: unknown) {
    const input = parseUpsertPerfil(body);
    await this.carregarUsuarioProfissional(user);
    await this.validarCategorias(input.servicos);
    const geo = await this.localizacao.geocodificar(input);

    const saved = await this.perfis.manager.transaction(async (manager) => {
      const perfil =
        (await manager.findOne(ProfissionalPerfilEntity, {
          where: { usuarioId: user.id },
          lock: { mode: 'pessimistic_write' },
        })) ??
        manager.create(ProfissionalPerfilEntity, {
          usuarioId: user.id,
          verificado: false,
        });
      perfil.descricao = input.descricao;
      perfil.bairro = input.bairro;
      perfil.cep = input.cep;
      perfil.cidade = input.cidade;
      perfil.uf = input.uf;
      perfil.latitude = decimalOrNull(geo.latitude);
      perfil.longitude = decimalOrNull(geo.longitude);
      perfil.precisaoGeografica = geo.precisao;
      perfil.raioAtendimentoKm = input.raioAtendimentoKm;
      perfil.precoInicial = decimalOrNull(input.precoInicial);
      perfil.ativo = true;
      const saved = await manager.save(ProfissionalPerfilEntity, perfil);
      await this.persistirServicos(manager, saved.id, input.servicos);
      return saved;
    });

    const reloaded = await this.perfis.findOne({
      where: { id: saved.id },
      relations: { usuario: true, servicos: { categoria: true } },
    });
    if (reloaded === null) {
      throw new Error('Saved professional profile could not be reloaded.');
    }

    return { profissional: await this.comResumo(reloaded) };
  }

  async meuPainel(user: AuthenticatedUser) {
    const perfil = await this.carregarMeuPerfil(user);
    if (perfil === null) {
      return {
        profissional: null,
        resumo: {
          solicitacoesNovas: 0,
          agendados: 0,
          concluidos: 0,
          recusadasOuCanceladas: 0,
        },
        proximosAtendimentos: [],
        solicitacoesRecentes: [],
      };
    }

    const solicitacoes = await this.solicitacoes.find({
      where: { profissionalId: perfil.id },
      relations: {
        cliente: true,
        profissional: { usuario: true },
        categoria: true,
      },
      order: { criadoEm: 'DESC' },
      take: 50,
    });
    const hoje = new Date().toISOString().slice(0, 10);
    const proximosAtendimentos = solicitacoes
      .filter(
        (solicitacao) =>
          solicitacao.status === SolicitacaoStatus.AceitaAgendada &&
          solicitacao.dataServico >= hoje,
      )
      .sort((a, b) =>
        `${a.dataServico} ${a.horarioServico}`.localeCompare(
          `${b.dataServico} ${b.horarioServico}`,
        ),
      )
      .slice(0, 5);

    return {
      profissional: await this.comResumo(perfil),
      resumo: {
        solicitacoesNovas: solicitacoes.filter(
          (item) => item.status === SolicitacaoStatus.AguardandoResposta,
        ).length,
        agendados: solicitacoes.filter(
          (item) => item.status === SolicitacaoStatus.AceitaAgendada,
        ).length,
        concluidos: solicitacoes.filter(
          (item) => item.status === SolicitacaoStatus.ConclusaoConfirmada,
        ).length,
        recusadasOuCanceladas: solicitacoes.filter((item) =>
          [SolicitacaoStatus.Recusada, SolicitacaoStatus.Cancelada].includes(
            item.status,
          ),
        ).length,
      },
      proximosAtendimentos: proximosAtendimentos.map(
        solicitacaoProfissionalResumo,
      ),
      solicitacoesRecentes: solicitacoes
        .slice(0, 8)
        .map(solicitacaoProfissionalResumo),
    };
  }

  async minhaAgenda(user: AuthenticatedUser, query: Record<string, unknown>) {
    const perfil = await this.carregarMeuPerfil(user);
    const mes = parseMes(query.mes);
    if (perfil === null) {
      return { mes, fusoHorario: fusoAgenda, disponibilidade: [], atendimentos: [] };
    }

    const [inicio, fim] = intervaloMes(mes);
    const [disponibilidade, atendimentos] = await Promise.all([
      this.disponibilidades.find({
        where: { profissionalId: perfil.id, ativo: true },
        order: { diaSemana: 'ASC', horaInicio: 'ASC' },
      }),
      this.solicitacoes
        .createQueryBuilder('solicitacao')
        .leftJoinAndSelect('solicitacao.cliente', 'cliente')
        .leftJoinAndSelect('solicitacao.categoria', 'categoria')
        .leftJoinAndSelect('solicitacao.endereco', 'endereco')
        .where('solicitacao.profissional_id = :profissionalId', {
          profissionalId: perfil.id,
        })
        .andWhere('solicitacao.status = :status', {
          status: SolicitacaoStatus.AceitaAgendada,
        })
        .andWhere('solicitacao.data_servico >= :inicio', { inicio })
        .andWhere('solicitacao.data_servico <= :fim', { fim })
        .orderBy('solicitacao.dataServico', 'ASC')
        .addOrderBy('solicitacao.horarioServico', 'ASC')
        .getMany(),
    ]);

    return {
      mes,
      fusoHorario: fusoAgenda,
      disponibilidade: disponibilidade.map(disponibilidadeResponse),
      atendimentos: atendimentos.map((item) => agendaAtendimentoResponse(item, podeAtender(perfil))),
    };
  }

  async meusServicos(user: AuthenticatedUser) {
    const perfil = await this.carregarMeuPerfil(user);
    return {
      servicos:
        perfil === null
          ? []
          : (perfil.servicos ?? []).map(servicoResponse),
    };
  }

  async salvarMeusServicos(user: AuthenticatedUser, body: unknown) {
    await this.carregarUsuarioProfissional(user);
    const input = parseServicosBody(body);
    await this.validarCategorias(input);
    const perfil = await this.carregarMeuPerfil(user);
    if (perfil === null) {
      throw new BadRequestException({
        code: 'PERFIL_PROFISSIONAL_OBRIGATORIO',
        message: 'Cadastre o perfil profissional antes de gerenciar servicos.',
      });
    }

    await this.salvarServicos(perfil.id, input);
    const reloaded = await this.carregarMeuPerfil(user);
    return {
      servicos:
        reloaded === null
          ? []
          : (reloaded.servicos ?? []).map(servicoResponse),
    };
  }

  async definirVerificacao(id: number, body: unknown) {
    void id;
    void body;
    throw new BadRequestException({
      code: 'VERIFICACAO_DOCUMENTAL_OBRIGATORIA',
      message:
        'Use a analise documental em /documentos-verificacao/:id/analisar.',
    });
  }

  private async carregarUsuarioProfissional(user: AuthenticatedUser) {
    const usuario = await this.usuarios.findOne({
      where: {
        id: user.id,
        tipo: In([UsuarioTipo.Profissional, UsuarioTipo.Empresa]),
        ativo: true,
      },
    });
    if (usuario === null) {
      throw new BadRequestException({
        code: 'USUARIO_NAO_ELEGIVEL',
        message: 'Apenas profissionais ou empresas podem publicar perfil.',
      });
    }

    return usuario;
  }

  private carregarMeuPerfil(user: AuthenticatedUser) {
    return this.perfis.findOne({
      where: { usuarioId: user.id },
      relations: { usuario: true, servicos: { categoria: true } },
      order: { servicos: { nome: 'ASC' } },
    });
  }

  private async validarCategorias(
    servicos: readonly ProfissionalServicoInput[],
  ) {
    const categoriaIds = [
      ...new Set(
        servicos
          .map((servico) => servico.categoriaId)
          .filter((id): id is number => id !== null && id !== undefined),
      ),
    ];
    if (categoriaIds.length === 0) return;

    const categoriasAtivas = await this.categorias.find({
      where: { id: In(categoriaIds), ativo: true },
    });
    if (categoriasAtivas.length !== categoriaIds.length) {
      throw badRequest('CATEGORIA_INVALIDA');
    }
  }

  private async salvarServicos(
    profissionalId: number,
    inputs: readonly ProfissionalServicoInput[],
  ) {
    await this.servicos.manager.transaction(async (manager) => {
      await manager.findOne(ProfissionalPerfilEntity, {
        where: { id: profissionalId },
        lock: { mode: 'pessimistic_write' },
      });
      await this.persistirServicos(manager, profissionalId, inputs);
    });
  }

  private async persistirServicos(
    manager: EntityManager,
    profissionalId: number,
    inputs: readonly ProfissionalServicoInput[],
  ) {
    const existentes = await manager.find(ProfissionalServicoEntity, {
      where: { profissionalId },
    });
    const usados = new Set<number>();
    for (const input of inputs) {
      let oferta =
        input.id == null
          ? existentes.find(
              (s) =>
                !usados.has(s.id) &&
                s.ativo &&
                s.nome === input.nome &&
                s.categoriaId === (input.categoriaId ?? null),
            )
          : existentes.find((s) => s.id === input.id);
      if (input.id != null && (oferta === undefined || usados.has(input.id))) {
        throw badRequest('OFERTA_INVALIDA');
      }
      oferta ??= manager.create(ProfissionalServicoEntity, { profissionalId });
      oferta.nome = input.nome;
      oferta.categoriaId = input.categoriaId ?? null;
      oferta.precoInicial = decimalOrNull(input.precoInicial);
      oferta.duracaoMinutos = input.duracaoMinutos;
      oferta.intervaloMinutos = input.intervaloMinutos;
      oferta.ativo = input.ativo ?? true;
      const saved = await manager.save(ProfissionalServicoEntity, oferta);
      usados.add(saved.id);
    }
    for (const oferta of existentes) {
      if (oferta.ativo && !usados.has(oferta.id)) {
        oferta.ativo = false;
        await manager.save(ProfissionalServicoEntity, oferta);
      }
    }
  }

  private async resumosAvaliacoes(usuarioIds: number[]) {
    const resumos = new Map<
      number,
      { notaMedia: number | null; quantidadeAvaliacoes: number }
    >(
      usuarioIds.map((id) => [
        id,
        { notaMedia: null, quantidadeAvaliacoes: 0 },
      ]),
    );
    if (usuarioIds.length === 0) return resumos;
    const rows = await this.avaliacoes
      .createQueryBuilder('avaliacao')
      .select('avaliacao.avaliadoId', 'usuarioId')
      .addSelect('AVG(avaliacao.nota)', 'notaMedia')
      .addSelect('COUNT(*)', 'quantidadeAvaliacoes')
      .where('avaliacao.avaliadoId IN (:...ids)', { ids: usuarioIds })
      .andWhere('avaliacao.moderacaoStatus = :status', {
        status: AvaliacaoModeracaoStatus.Aprovada,
      })
      .groupBy('avaliacao.avaliadoId')
      .getRawMany<{
        usuarioId: string;
        notaMedia: string;
        quantidadeAvaliacoes: string;
      }>();
    for (const row of rows)
      resumos.set(Number(row.usuarioId), {
        notaMedia: Number(row.notaMedia),
        quantidadeAvaliacoes: Number(row.quantidadeAvaliacoes),
      });
    return resumos;
  }

  private async comResumo(perfil: ProfissionalPerfilEntity) {
    const resumos = await this.resumosAvaliacoes([perfil.usuarioId]);
    return { ...perfilPublico(perfil), ...resumos.get(perfil.usuarioId) };
  }

  async avaliacoesPublicas(id: number, query: Record<string, unknown>) {
    const { profissional } = await this.obter(id);
    return this.avaliacoesDoUsuario(profissional.usuarioId, query);
  }

  async minhasAvaliacoes(
    user: AuthenticatedUser,
    query: Record<string, unknown>,
  ) {
    await this.carregarUsuarioProfissional(user);
    return this.avaliacoesDoUsuario(user.id, query);
  }

  private async avaliacoesDoUsuario(
    usuarioId: number,
    query: Record<string, unknown>,
  ) {
    const filtros = parseAvaliacoesQuery(query);
    const consulta = this.avaliacoes
      .createQueryBuilder('avaliacao')
      .where('avaliacao.avaliadoId = :usuarioId', { usuarioId })
      .andWhere('avaliacao.moderacaoStatus = :status', {
        status: AvaliacaoModeracaoStatus.Aprovada,
      });
    if (filtros.nota !== null) {
      consulta.andWhere('avaliacao.nota = :nota', { nota: filtros.nota });
    }
    if (filtros.comComentario) {
      consulta.andWhere("TRIM(COALESCE(avaliacao.comentario, '')) <> ''");
    }
    consulta
      .orderBy('avaliacao.criadoEm', 'DESC')
      .skip((filtros.pagina - 1) * filtros.limite)
      .take(filtros.limite);

    const [resumos, [avaliacoes, total]] = await Promise.all([
      this.resumosAvaliacoes([usuarioId]),
      consulta.getManyAndCount(),
    ]);
    return {
      resumo: resumos.get(usuarioId),
      paginacao: {
        pagina: filtros.pagina,
        limite: filtros.limite,
        total,
        totalPaginas: Math.max(1, Math.ceil(total / filtros.limite)),
      },
      avaliacoes: avaliacoes.map((a) => ({
        id: a.id,
        nota: a.nota,
        comentario: a.comentario,
        criadoEm: a.criadoEm.toISOString(),
      })),
    };
  }
}

function parseAvaliacoesQuery(query: Record<string, unknown>) {
  const pagina = query.pagina ?? '1';
  const limite = query.limite ?? '10';
  const nota = query.nota;
  const comComentario = query.comComentario ?? 'false';
  if (
    typeof pagina !== 'string' ||
    !/^[1-9]\d{0,4}$/.test(pagina) ||
    typeof limite !== 'string' ||
    !/^(?:[1-9]|[1-4]\d|50)$/.test(limite) ||
    (nota !== undefined &&
      (typeof nota !== 'string' || !/^[1-5]$/.test(nota))) ||
    (comComentario !== 'true' && comComentario !== 'false')
  ) {
    throw new BadRequestException({
      code: 'FILTROS_AVALIACOES_INVALIDOS',
      message: 'Filtros de avaliações inválidos.',
    });
  }
  return {
    pagina: Number(pagina),
    limite: Number(limite),
    nota: nota === undefined ? null : Number(nota),
    comComentario: comComentario === 'true',
  };
}

function solicitacaoProfissionalResumo(solicitacao: SolicitacaoEntity) {
  return {
    id: solicitacao.id,
    servicoId: solicitacao.servicoId,
    nomeServico: solicitacao.nomeServico,
    status: solicitacao.status,
    descricao: solicitacao.descricao,
    bairroAtendimento: solicitacao.bairroAtendimento,
    dataServico: solicitacao.dataServico,
    horarioServico: solicitacao.horarioServico,
    duracaoMinutos: solicitacao.duracaoMinutos,
    fusoHorario: fusoAgenda,
    precoInicial: numberOrNull(solicitacao.precoInicial),
    precoFinal: numberOrNull(solicitacao.precoFinal),
    enderecoCompletoLiberado: false,
    enderecoAtendimento: null,
    enderecoCompleto: null,
    cliente: {
      id: solicitacao.cliente.id,
      nome: solicitacao.cliente.nome,
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

function disponibilidadeResponse(item: ProfissionalDisponibilidadeEntity) {
  return {
    id: item.id,
    diaSemana: item.diaSemana,
    horaInicio: item.horaInicio,
    horaFim: item.horaFim,
    ativo: item.ativo,
  };
}

function agendaAtendimentoResponse(solicitacao: SolicitacaoEntity, autorizado: boolean) {
  return {
    ...solicitacaoProfissionalResumo(solicitacao),
    enderecoCompletoLiberado: autorizado && solicitacao.endereco != null,
    enderecoAtendimento:
      !autorizado || solicitacao.endereco == null
        ? null
        : enderecoResponse(solicitacao.endereco),
    enderecoCompleto:
      !autorizado || solicitacao.endereco == null
        ? null
        : enderecoResponse(solicitacao.endereco),
  };
}

function enderecoResponse(endereco: ClienteEnderecoEntity) {
  return {
    id: endereco.id,
    apelido: endereco.apelido,
    cep: endereco.cep,
    logradouro: endereco.logradouro,
    numero: endereco.numero,
    complemento: endereco.complemento,
    bairro: endereco.bairro,
    cidade: endereco.cidade,
    uf: endereco.uf,
  };
}

function perfilPublico(perfil: ProfissionalPerfilEntity) {
  const servicos = (perfil.servicos ?? [])
    .filter((servico) => servico.ativo)
    .map(servicoResponse);

  const disponivelParaAtendimento = podeAtender(perfil);
  return {
    id: perfil.id,
    usuarioId: perfil.usuarioId,
    nome: perfil.usuario.nome,
    tipo: perfil.usuario.tipo,
    fotoPerfilUrl: fotoPerfilUrl(perfil.usuario),
    descricao: perfil.descricao,
    bairro: perfil.bairro,
    cidade: perfil.cidade,
    uf: perfil.uf,
    raioAtendimentoKm: perfil.raioAtendimentoKm,
    latitudeAproximada: coordenadaAproximada(perfil.latitude),
    longitudeAproximada: coordenadaAproximada(perfil.longitude),
    precoInicial: numberOrNull(perfil.precoInicial),
    verificado: perfil.verificado,
    podeReceberSolicitacoes: disponivelParaAtendimento,
    atendimentoStatus: disponivelParaAtendimento
      ? 'disponivel'
      : 'em_verificacao',
    atendimentoMensagem: disponivelParaAtendimento
      ? 'Disponivel para receber solicitacoes.'
      : 'Perfil em verificacao e ainda indisponivel para novas solicitacoes.',
    servicos,
  };
}

function servicoResponse(servico: ProfissionalServicoEntity) {
  return {
    id: servico.id,
    nome: servico.nome,
    categoria:
      servico.categoria === null || servico.categoria === undefined
        ? null
        : {
            id: servico.categoria.id,
            nome: servico.categoria.nome,
          },
    categoriaId: servico.categoriaId,
    precoInicial: numberOrNull(servico.precoInicial),
    duracaoMinutos: servico.duracaoMinutos,
    intervaloMinutos: servico.intervaloMinutos,
    ativo: servico.ativo,
  };
}

function parseUpsertPerfil(body: unknown): UpsertPerfilInput {
  const value = objectBody(body);
  const descricao = textField(value, 'descricao', 20, 280);
  const bairro = textField(value, 'bairro', 2, 120);
  const precoInicial = optionalMoney(value.precoInicial);
  const servicos = parseServicos(value.servicos);
  const cep = optionalCep(value.cep);
  const cidade = optionalText(value.cidade, 120);
  const uf = optionalUf(value.uf);
  const raioAtendimentoKm = requiredRadius(value.raioAtendimentoKm);

  return {
    descricao,
    bairro,
    cep,
    cidade,
    uf,
    raioAtendimentoKm,
    precoInicial,
    servicos,
  };
}

function optionalCep(value: unknown): string | null {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string') throw badRequest('CEP_INVALIDO');
  const cep = value.replace(/\D/g, '');
  if (!/^\d{8}$/.test(cep)) throw badRequest('CEP_INVALIDO');
  return cep;
}

function optionalUf(value: unknown): string | null {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string' || !/^[A-Za-z]{2}$/.test(value.trim())) {
    throw badRequest('UF_INVALIDA');
  }
  return value.trim().toUpperCase();
}

function requiredRadius(value: unknown): number {
  if (value === undefined || value === null || value === '') return 15;
  const numero = typeof value === 'string' ? Number(value) : value;
  if (!Number.isInteger(numero) || Number(numero) < 1 || Number(numero) > 200) {
    throw badRequest('RAIO_ATENDIMENTO_INVALIDO');
  }
  return Number(numero);
}

function optionalRadius(value: unknown): number | null {
  if (value === undefined || value === null || value === '') return null;
  return requiredRadius(value);
}

function parseProfissionaisPaginacao(query: Record<string, unknown>) {
  const pagina = parsePositiveInteger(query.pagina ?? '1', 10_000);
  const limite = parsePositiveInteger(query.limite ?? '20', 50);
  if (pagina === null || limite === null) {
    throw badRequest('PAGINACAO_INVALIDA');
  }
  return { pagina, limite };
}

function parsePositiveInteger(value: unknown, max: number): number | null {
  const parsed = typeof value === 'number' ? value : Number(value);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > max) return null;
  return parsed;
}

function distanciaSql(): string {
  return '(6371 * 2 * ASIN(SQRT(LEAST(1, '
    + 'POWER(SIN(RADIANS(perfil.latitude - :latitude) / 2), 2) + '
    + 'COS(RADIANS(:latitude)) * COS(RADIANS(perfil.latitude)) * '
    + 'POWER(SIN(RADIANS(perfil.longitude - :longitude) / 2), 2)'
    + '))))';
}

function optionalCoordinate(
  value: unknown,
  minimo: number,
  maximo: number,
): number | null {
  if (value === undefined || value === null || value === '') return null;
  const numero = typeof value === 'string' ? Number(value) : value;
  if (typeof numero !== 'number' || !Number.isFinite(numero) || numero < minimo || numero > maximo) {
    throw badRequest('COORDENADA_INVALIDA');
  }
  return numero;
}

function distanciaDoPerfil(
  perfil: ProfissionalPerfilEntity,
  latitude: number,
  longitude: number,
): number | null {
  if (perfil.latitude === null || perfil.longitude === null) return null;
  const lat2 = Number(perfil.latitude);
  const lon2 = Number(perfil.longitude);
  const rad = (graus: number) => (graus * Math.PI) / 180;
  const dLat = rad(lat2 - latitude);
  const dLon = rad(lon2 - longitude);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(latitude)) * Math.cos(rad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 6_371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function coordenadaAproximada(value: string | null): number | null {
  return value === null ? null : Math.round(Number(value) * 100) / 100;
}

function parseServicos(value: unknown): readonly ProfissionalServicoInput[] {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > 12) {
    throw badRequest('SERVICOS_INVALIDOS');
  }

  return value.map((item) => {
    const body = objectBody(item);
    return {
      id: optionalId(body.id),
      nome: textField(body, 'nome', 2, 90),
      categoriaId: optionalId(body.categoriaId),
      precoInicial: optionalMoney(body.precoInicial),
      ativo: optionalBoolean(body.ativo),
      duracaoMinutos: durationField(body.duracaoMinutos, 60),
      intervaloMinutos: durationField(body.intervaloMinutos, 30, true),
    };
  });
}

function durationField(value: unknown, fallback: number, allowZero = false): number {
  if (value === undefined || value === null || value === '') return fallback;
  const parsed = typeof value === 'string' ? Number(value) : value;
  const minimum = allowZero ? 0 : 15;
  if (!Number.isInteger(parsed) || Number(parsed) < minimum || Number(parsed) > 480) {
    throw badRequest('DURACAO_INVALIDA');
  }
  return Number(parsed);
}

function optionalBoolean(value: unknown): boolean | undefined {
  if (value === undefined) return undefined;
  if (typeof value !== 'boolean') throw badRequest('CAMPO_INVALIDO');
  return value;
}

function parseServicosBody(body: unknown): readonly ProfissionalServicoInput[] {
  const value = objectBody(body);
  return parseServicos(value.servicos);
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
  if (typeof value !== 'string') throw badRequest('FILTRO_INVALIDO');
  const text = value.trim();
  if (text.length === 0) return null;
  if (text.length > max) throw badRequest('FILTRO_INVALIDO');
  return text;
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

function parseMes(value: unknown): string {
  if (value === undefined || value === null || value === '') {
    return new Date().toISOString().slice(0, 7);
  }
  if (typeof value !== 'string' || !/^\d{4}-\d{2}$/.test(value)) {
    throw badRequest('MES_INVALIDO');
  }

  const date = new Date(`${value}-01T00:00:00.000Z`);
  if (
    Number.isNaN(date.getTime()) ||
    date.toISOString().slice(0, 7) !== value
  ) {
    throw badRequest('MES_INVALIDO');
  }

  return value;
}

function intervaloMes(mes: string): readonly [string, string] {
  const inicio = `${mes}-01`;
  const [anoTexto, mesTexto] = mes.split('-');
  const ano = Number(anoTexto);
  const mesNumero = Number(mesTexto);
  const fim = new Date(Date.UTC(ano, mesNumero, 0)).toISOString().slice(0, 10);
  return [inicio, fim];
}

function optionalMoney(value: unknown): number | null {
  if (value === undefined || value === null || value === '') return null;
  if (
    typeof value !== 'number' ||
    !Number.isFinite(value) ||
    value < 0 ||
    value > 99999999.99
  ) {
    throw badRequest('PRECO_INVALIDO');
  }

  return Math.round(value * 100) / 100;
}

function decimalOrNull(value: number | null | undefined): string | null {
  return value === null || value === undefined ? null : value.toFixed(2);
}

function numberOrNull(value: string | null): number | null {
  return value === null ? null : Number(value);
}

function badRequest(code: string): BadRequestException {
  return new BadRequestException({
    code,
    message: 'Dados invalidos.',
  });
}
