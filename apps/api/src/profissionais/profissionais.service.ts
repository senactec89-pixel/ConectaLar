import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { CategoriaEntity } from '../database/entities/categoria.entity.js';
import { ClienteEnderecoEntity } from '../database/entities/cliente-endereco.entity.js';
import { ProfissionalDisponibilidadeEntity } from '../database/entities/profissional-disponibilidade.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { ProfissionalServicoEntity } from '../database/entities/profissional-servico.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { SolicitacaoStatus } from '../domain/solicitacao-status.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';

interface ProfissionalServicoInput {
  readonly nome: string;
  readonly categoriaId?: number | null;
  readonly precoInicial?: number | null;
}

interface UpsertPerfilInput {
  readonly descricao: string;
  readonly bairro: string;
  readonly precoInicial?: number | null;
  readonly servicos: readonly ProfissionalServicoInput[];
}

interface ProfissionaisFiltros {
  readonly termo: string | null;
  readonly bairro: string | null;
  readonly categoriaId: number | null;
}

@Injectable()
export class ProfissionaisService {
  constructor(
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
  ) {}

  async listar(query: Record<string, unknown>) {
    const termo = optionalText(query.termo, 80);
    const bairro = optionalText(query.bairro, 80);
    const categoriaId = optionalId(query.categoriaId);

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
      .where('perfil.ativo = :ativo', { ativo: true })
      .andWhere('usuario.ativo = :ativo', { ativo: true })
      .andWhere('usuario.tipo IN (:...tipos)', {
        tipos: [UsuarioTipo.Profissional, UsuarioTipo.Empresa],
      })
      .orderBy('perfil.verificado', 'DESC')
      .addOrderBy('usuario.nome', 'ASC');

    const perfis = await builder.getMany();
    return {
      profissionais: perfis
        .filter((perfil) =>
          correspondeFiltros(perfil, { termo, bairro, categoriaId }),
        )
        .map(perfilPublico),
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

    return { profissional: perfilPublico(perfil) };
  }

  async meuPerfil(user: AuthenticatedUser) {
    const perfil = await this.perfis.findOne({
      where: { usuarioId: user.id },
      relations: { usuario: true, servicos: { categoria: true } },
    });

    return { profissional: perfil === null ? null : perfilPublico(perfil) };
  }

  async salvarMeuPerfil(user: AuthenticatedUser, body: unknown) {
    const input = parseUpsertPerfil(body);
    const usuario = await this.carregarUsuarioProfissional(user);
    await this.validarCategorias(input.servicos);

    let perfil = await this.perfis.findOne({ where: { usuarioId: user.id } });
    perfil ??= this.perfis.create({ usuarioId: user.id, verificado: false });
    perfil.usuario = usuario;
    perfil.descricao = input.descricao;
    perfil.bairro = input.bairro;
    perfil.precoInicial = decimalOrNull(input.precoInicial);
    perfil.ativo = true;

    const saved = await this.perfis.save(perfil);
    await this.servicos.delete({ profissionalId: saved.id });
    if (input.servicos.length > 0) {
      await this.servicos.save(
        input.servicos.map((servico) =>
          this.servicos.create({
            profissionalId: saved.id,
            categoriaId: servico.categoriaId ?? null,
            nome: servico.nome,
            precoInicial: decimalOrNull(servico.precoInicial),
            ativo: true,
          }),
        ),
      );
    }

    const reloaded = await this.perfis.findOne({
      where: { id: saved.id },
      relations: { usuario: true, servicos: { categoria: true } },
    });
    if (reloaded === null) {
      throw new Error('Saved professional profile could not be reloaded.');
    }

    return { profissional: perfilPublico(reloaded) };
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
      .sort(
        (a, b) =>
          `${a.dataServico} ${a.horarioServico}`.localeCompare(
            `${b.dataServico} ${b.horarioServico}`,
          ),
      )
      .slice(0, 5);

    return {
      profissional: perfilPublico(perfil),
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
      return { mes, disponibilidade: [], atendimentos: [] };
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
      disponibilidade: disponibilidade.map(disponibilidadeResponse),
      atendimentos: atendimentos.map(agendaAtendimentoResponse),
    };
  }

  async meusServicos(user: AuthenticatedUser) {
    const perfil = await this.carregarMeuPerfil(user);
    return {
      servicos: perfil === null ? [] : (perfil.servicos ?? []).map(servicoResponse),
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
      servicos: reloaded === null ? [] : (reloaded.servicos ?? []).map(servicoResponse),
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
    servicos: readonly ProfissionalServicoInput[],
  ) {
    await this.servicos.delete({ profissionalId });
    if (servicos.length === 0) return;

    await this.servicos.save(
      servicos.map((servico) =>
        this.servicos.create({
          profissionalId,
          categoriaId: servico.categoriaId ?? null,
          nome: servico.nome,
          precoInicial: decimalOrNull(servico.precoInicial),
          ativo: true,
        }),
      ),
    );
  }
}

function solicitacaoProfissionalResumo(solicitacao: SolicitacaoEntity) {
  return {
    id: solicitacao.id,
    status: solicitacao.status,
    descricao: solicitacao.descricao,
    bairroAtendimento: solicitacao.bairroAtendimento,
    dataServico: solicitacao.dataServico,
    horarioServico: solicitacao.horarioServico,
    precoInicial: numberOrNull(solicitacao.precoInicial),
    enderecoCompletoLiberado:
      solicitacao.status === SolicitacaoStatus.AceitaAgendada,
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

function agendaAtendimentoResponse(solicitacao: SolicitacaoEntity) {
  return {
    ...solicitacaoProfissionalResumo(solicitacao),
    enderecoCompletoLiberado: true,
    enderecoCompleto:
      solicitacao.endereco === null ? null : enderecoResponse(solicitacao.endereco),
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

  return {
    id: perfil.id,
    usuarioId: perfil.usuarioId,
    nome: perfil.usuario.nome,
    tipo: perfil.usuario.tipo,
    descricao: perfil.descricao,
    bairro: perfil.bairro,
    precoInicial: numberOrNull(perfil.precoInicial),
    verificado: perfil.verificado,
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
    ativo: servico.ativo,
  };
}

function correspondeFiltros(
  perfil: ProfissionalPerfilEntity,
  filtros: ProfissionaisFiltros,
): boolean {
  const bairro = normalizar(filtros.bairro);
  if (bairro !== null && !normalizar(perfil.bairro)?.includes(bairro)) {
    return false;
  }

  if (
    filtros.categoriaId !== null &&
    !(perfil.servicos ?? []).some(
      (servico) => servico.categoriaId === filtros.categoriaId,
    )
  ) {
    return false;
  }

  const termo = normalizar(filtros.termo);
  if (termo === null) {
    return true;
  }

  const campos = [
    perfil.usuario.nome,
    perfil.descricao,
    perfil.bairro,
    ...(perfil.servicos ?? []).map((servico) => servico.nome),
    ...(perfil.servicos ?? []).map((servico) => servico.categoria?.nome ?? ''),
  ];

  return campos.some((campo) => normalizar(campo)?.includes(termo));
}

function normalizar(value: string | null): string | null {
  if (value === null) return null;
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase();
}

function parseUpsertPerfil(body: unknown): UpsertPerfilInput {
  const value = objectBody(body);
  const descricao = textField(value, 'descricao', 20, 280);
  const bairro = textField(value, 'bairro', 2, 120);
  const precoInicial = optionalMoney(value.precoInicial);
  const servicos = parseServicos(value.servicos);

  return { descricao, bairro, precoInicial, servicos };
}

function parseServicos(value: unknown): readonly ProfissionalServicoInput[] {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > 12) {
    throw badRequest('SERVICOS_INVALIDOS');
  }

  return value.map((item) => {
    const body = objectBody(item);
    return {
      nome: textField(body, 'nome', 2, 90),
      categoriaId: optionalId(body.categoriaId),
      precoInicial: optionalMoney(body.precoInicial),
    };
  });
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
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 7) !== value) {
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
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) {
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
