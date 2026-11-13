import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, EntityManager, In, Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import {
  paginationMetadata,
  parsePaginationQuery,
} from '../common/pagination.js';
import { CategoriaEntity } from '../database/entities/categoria.entity.js';
import { AvaliacaoEntity } from '../database/entities/avaliacao.entity.js';
import { ProfissionalServicoEntity } from '../database/entities/profissional-servico.entity.js';
import { criarSnapshotServico } from './servico-snapshot.js';
import { bloquearOfertaCatalogo } from './oferta-catalogo.js';
import { calcularExpiracaoProposta, propostaExpirada } from './proposta-prazo.js';
import { ClienteEnderecoEntity } from '../database/entities/cliente-endereco.entity.js';
import { ProfissionalDisponibilidadeEntity } from '../database/entities/profissional-disponibilidade.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { EnderecoAtendimentoSnapshot, EscopoServicoSnapshot, SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { SolicitacaoEventoEntity } from '../database/entities/solicitacao-evento.entity.js';
import { ProfissionalBloqueioEntity } from '../database/entities/profissional-bloqueio.entity.js';
import {
  ReagendamentoStatus,
  SolicitacaoReagendamentoEntity,
} from '../database/entities/solicitacao-reagendamento.entity.js';
import { SolicitacaoOrcamentoEntity } from '../database/entities/solicitacao-orcamento.entity.js';
import {
  SolicitacaoPropostaEntity,
  SolicitacaoPropostaStatus,
} from '../database/entities/solicitacao-proposta.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { horarioDisponivel } from '../disponibilidade/disponibilidade.service.js';
import { cancelamentoClienteExcepcional, diaAnterior, duracaoLegadaMinutos, fusoAgenda, horarioIniciado, periodosSobrepostos } from '../domain/agendamento.js';
import { NotificacaoTipo } from '../domain/notificacao-tipo.js';
import { OrcamentoStatus } from '../domain/orcamento-status.js';
import { SolicitacaoStatus } from '../domain/solicitacao-status.js';
import { escoposIguais, ofertasEquivalentes, snapshotEscopo } from '../domain/escopo-servico.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { NotificacoesService } from '../notificacoes/notificacoes.service.js';
import { exigirHabilitacao, habilitacaoManualLocalAtiva, podeAtender } from '../verificacao/habilitacao-profissional.js';
import { calcularExpiracaoPedido, expirarPedidoSemResposta } from './pedido-prazo.js';
import { calcularExpiracaoNegociacao, expirarNegociacaoInativa } from './negociacao-prazo.js';

interface CriarSolicitacaoInput {
  readonly profissionalId: number;
  readonly categoriaId: number | null;
  readonly servicoId: number | null;
  readonly enderecoId: number | null;
  readonly descricao: string;
  readonly bairroAtendimento: string;
  readonly dataServico: string;
  readonly horarioServico: string;
  readonly opcoesIds: number[];
  readonly escopoEsperado: EscopoServicoSnapshot | null;
}

@Injectable()
export class SolicitacoesService {
  constructor(
    @InjectRepository(AvaliacaoEntity)
    private readonly avaliacoes: Repository<AvaliacaoEntity>,
    @InjectRepository(ProfissionalServicoEntity)
    private readonly ofertas: Repository<ProfissionalServicoEntity>,
    @InjectRepository(CategoriaEntity)
    private readonly categorias: Repository<CategoriaEntity>,
    @InjectRepository(ClienteEnderecoEntity)
    private readonly enderecos: Repository<ClienteEnderecoEntity>,
    @InjectRepository(ProfissionalDisponibilidadeEntity)
    private readonly disponibilidades: Repository<ProfissionalDisponibilidadeEntity>,
    @InjectRepository(ProfissionalPerfilEntity)
    private readonly profissionais: Repository<ProfissionalPerfilEntity>,
    @InjectRepository(SolicitacaoEntity)
    private readonly solicitacoes: Repository<SolicitacaoEntity>,
    @InjectRepository(SolicitacaoReagendamentoEntity)
    private readonly reagendamentos: Repository<SolicitacaoReagendamentoEntity>,
    @InjectRepository(SolicitacaoOrcamentoEntity)
    private readonly orcamentos: Repository<SolicitacaoOrcamentoEntity>,
    @InjectRepository(ProfissionalBloqueioEntity)
    private readonly bloqueios: Repository<ProfissionalBloqueioEntity>,
    @InjectRepository(UsuarioEntity)
    private readonly usuarios: Repository<UsuarioEntity>,
    private readonly notificacoes: NotificacoesService,
    @InjectRepository(SolicitacaoPropostaEntity)
    private readonly propostas?: Repository<SolicitacaoPropostaEntity>,
  ) {}

  async criar(user: AuthenticatedUser, body: unknown) {
    const input = parseCriarSolicitacao(body);
    assertAgendamentoFuturo(input.dataServico, input.horarioServico);
    const cliente = await this.usuarios.findOne({
      where: { id: user.id, tipo: UsuarioTipo.Cliente, ativo: true },
    });
    if (cliente === null) {
      throw forbidden();
    }

    const profissional = await this.profissionais.findOne({
      where: { id: input.profissionalId, ativo: true },
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

    exigirHabilitacao(profissional);
    if (input.opcoesIds.length === 0) throw badRequest('OPCOES_OBRIGATORIAS');

    const oferta =
      input.servicoId === null
        ? null
        : await this.ofertas.findOne({
            where: {
              id: input.servicoId,
              profissionalId: profissional.id,
              ativo: true,
            },
            relations: { categoria: true, servicoCatalogo: true },
          });
    if (oferta === null || oferta.servicoCatalogoId == null ||
      !oferta.servicoCatalogo?.ativo || !oferta.categoria?.ativo ||
      oferta.servicoCatalogo.categoriaId !== oferta.categoriaId ||
      (input.categoriaId !== null && input.categoriaId !== oferta.categoriaId)) {
      throw badRequest('OFERTA_INDISPONIVEL');
    }
    if (input.escopoEsperado !== null && (oferta === null ||
      !escoposIguais(input.escopoEsperado, snapshotEscopo(oferta)!))) {
      throw ofertaAlterada();
    }
    const categoriaId =
      oferta === null ? input.categoriaId : oferta.categoriaId;
    if (categoriaId !== null) {
      const categoria = await this.categorias.findOne({
        where: { id: categoriaId, ativo: true },
      });
      if (categoria === null) {
        throw badRequest('CATEGORIA_INVALIDA');
      }
    }

    let enderecoSnapshot: EnderecoAtendimentoSnapshot | null = null;
    if (input.enderecoId !== null) {
      const endereco = await this.enderecos.findOne({
        where: { id: input.enderecoId, usuarioId: cliente.id, ativo: true },
      });
      if (endereco === null) {
        throw badRequest('ENDERECO_INVALIDO');
      }
      enderecoSnapshot = snapshotEndereco(endereco);
    }

    const duracaoMinutos = oferta?.duracaoMinutos ?? duracaoLegadaMinutos;
    await this.validarDisponibilidade(
      profissional.id,
      input.dataServico,
      input.horarioServico,
      duracaoMinutos,
      0,
    );

    const servicoSnapshot = criarSnapshotServico(oferta);
    const solicitacao = this.solicitacoes.create({
      clienteId: cliente.id,
      profissionalId: profissional.id,
      categoriaId,
      servicoId: oferta?.id ?? null,
      nomeServico: servicoSnapshot?.nomeServico ?? oferta?.nome ?? null,
      servicoSnapshot,
      escopoServicoSnapshot: snapshotEscopo(oferta),
      enderecoId: input.enderecoId,
      enderecoSnapshot,
      descricao: input.descricao,
      bairroAtendimento: input.bairroAtendimento,
      dataServico: input.dataServico,
      horarioServico: input.horarioServico,
      duracaoMinutos,
      intervaloMinutos: 0,
      precoInicial: oferta === null ? profissional.precoInicial : oferta.precoInicial,
      precoFinal: null,
      status: SolicitacaoStatus.AguardandoResposta,
      prazoRespostaEm: calcularExpiracaoPedido(new Date()),
      prazoInatividadeEm: null,
    });

    const saved = await this.solicitacoes.manager.transaction(async (manager) => {
      const perfilAtual = await manager.findOne(ProfissionalPerfilEntity, {
        where: { id: profissional.id }, lock: { mode: 'pessimistic_write' },
      });
      exigirHabilitacao(perfilAtual);
      if (perfilAtual === null || !perfilAtual.ativo) throw badRequest('PROFISSIONAL_INDISPONIVEL');
      const ofertaAtual = await bloquearOfertaCatalogo(manager, profissional.id, oferta.id);
      if (!ofertasEquivalentes(oferta, ofertaAtual)) throw ofertaAlterada();
      const opcoes = await carregarOpcoesAtivas(manager, ofertaAtual.servicoCatalogoId!, input.opcoesIds);
      if (ofertaAtual.duracaoMinutos !== duracaoMinutos) throw badRequest('OFERTA_ATUALIZADA');
      const snapshotAtual = criarSnapshotServico(ofertaAtual);
      solicitacao.categoriaId = ofertaAtual.categoriaId;
      solicitacao.nomeServico = snapshotAtual?.nomeServico ?? null;
      solicitacao.servicoSnapshot = snapshotAtual;
      solicitacao.escopoServicoSnapshot = snapshotEscopo(ofertaAtual);
      solicitacao.precoInicial = ofertaAtual.precoInicial;
      const criada = await manager.save(SolicitacaoEntity, solicitacao);
      for (const opcao of opcoes) {
        await manager.query('INSERT INTO solicitacao_opcoes (solicitacao_id, opcao_id, nome_snapshot) VALUES (?, ?, ?)', [criada.id, opcao.id, opcao.nome]);
      }
      await manager.save(
        SolicitacaoEventoEntity,
        manager.create(SolicitacaoEventoEntity, {
          solicitacaoId: criada.id,
          atorId: user.id,
          tipo: 'solicitacao_criada',
          statusAnterior: null,
          statusNovo: criada.status,
          motivo: null,
        }),
      );
      return criada;
    });
    const reloaded = await this.carregar(saved.id);
    await this.notificarSeguro({
      usuarioId: profissional.usuarioId,
      tipo: NotificacaoTipo.SolicitacaoCriada,
      titulo: 'Nova solicitacao recebida',
      mensagem: 'Voce recebeu uma nova solicitacao de atendimento.',
      recursoTipo: 'solicitacao',
      recursoId: saved.id,
    });
    return this.responder(reloaded, user);
  }

  async minhas(user: AuthenticatedUser, query: Record<string, unknown> = {}) {
    const pagination = parsePaginationQuery(query);
    const builder = this.solicitacoes
      .createQueryBuilder('solicitacao')
      .leftJoinAndSelect('solicitacao.cliente', 'cliente')
      .leftJoinAndSelect('solicitacao.profissional', 'profissional')
      .leftJoinAndSelect('profissional.usuario', 'profissionalUsuario')
      .leftJoinAndSelect('solicitacao.categoria', 'categoria')
      .leftJoinAndSelect('solicitacao.endereco', 'endereco')
      .orderBy('solicitacao.criadoEm', 'DESC')
      .addOrderBy('solicitacao.id', 'DESC')
      .skip(pagination.skip)
      .take(pagination.limite);

    if (user.tipo === UsuarioTipo.Cliente) {
      builder.where('solicitacao.cliente_id = :userId', { userId: user.id });
    } else if (
      [UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(user.tipo)
    ) {
      builder.where('profissional.usuario_id = :userId', { userId: user.id });
    } else if (user.tipo !== UsuarioTipo.Administrador) {
      throw forbidden();
    }

    const [solicitacoes, total] = await builder.getManyAndCount();
    const avaliadas =
      solicitacoes.length === 0
        ? []
        : await this.avaliacoes.find({
            where: {
              solicitacaoId: In(solicitacoes.map((s) => s.id)),
              avaliadorId: user.id,
            },
            select: { solicitacaoId: true },
          });
    const idsAvaliados = new Set(avaliadas.map((a) => a.solicitacaoId));
    const idsNegociacaoIniciada = solicitacoes.length === 0
      ? new Set<number>()
      : new Set<number>((await this.solicitacoes.manager.query(
          `SELECT DISTINCT solicitacao_id FROM solicitacao_eventos
           WHERE tipo = 'negociacao_iniciada' AND solicitacao_id IN (${solicitacoes.map(() => '?').join(',')})`,
          solicitacoes.map((item) => item.id),
        ) as Array<{ solicitacao_id: number }>).map((item) => Number(item.solicitacao_id)));
    return {
      paginacao: paginationMetadata(pagination, total),
      solicitacoes: solicitacoes.map((solicitacao) => ({
        ...solicitacaoResponse(
          solicitacao,
          user,
          idsAvaliados.has(solicitacao.id),
        ),
        negociacaoIniciada: idsNegociacaoIniciada.has(solicitacao.id),
      })),
    };
  }

  async obter(user: AuthenticatedUser, id: number) {
    const solicitacao = await this.carregar(id);
    assertParticipante(user, solicitacao);
    return this.responder(solicitacao, user);
  }

  async opcoes(user: AuthenticatedUser, id: number) {
    const solicitacao = await this.carregar(id);
    assertParticipante(user, solicitacao);
    const rows = await this.solicitacoes.manager.query(
      'SELECT opcao_id AS id, nome_snapshot AS nome FROM solicitacao_opcoes WHERE solicitacao_id = ? ORDER BY id', [id],
    ) as Array<{ id: number; nome: string }>;
    return { opcoes: rows };
  }

  async iniciarNegociacao(user: AuthenticatedUser, id: number) {
    const solicitacao = await this.carregar(id);
    assertProfissionalParticipante(user, solicitacao);
    const resultado = await this.solicitacoes.manager.transaction('READ COMMITTED', async (manager) => {
      const perfil = await manager.findOne(ProfissionalPerfilEntity, { where: { id: solicitacao.profissionalId }, lock: { mode: 'pessimistic_write' } });
      const atual = await manager.findOne(SolicitacaoEntity, { where: { id }, lock: { mode: 'pessimistic_write' } });
      if (perfil === null || !perfil.ativo) throw badRequest('PROFISSIONAL_INDISPONIVEL');
      if (perfil.usuarioId !== user.id) throw forbidden();
      if (atual === null || atual.status !== SolicitacaoStatus.AguardandoResposta) throw conflitoNegociacao();
      const opcoes = await manager.query('SELECT id FROM solicitacao_opcoes WHERE solicitacao_id = ? LIMIT 1', [id]) as unknown[];
      if (opcoes.length === 0) throw conflitoNegociacao();
      if (await expirarPedidoSemResposta(manager, atual)) return 'expirada' as const;
      if (await expirarNegociacaoInativa(manager, atual)) return 'expirada' as const;
      const iniciada = await manager.findOne(SolicitacaoEventoEntity, { where: { solicitacaoId: id, tipo: 'negociacao_iniciada' } });
      if (iniciada !== null) return 'ja_iniciada' as const;
      exigirHabilitacao(perfil);
      atual.prazoInatividadeEm = calcularExpiracaoNegociacao(new Date());
      await manager.save(SolicitacaoEntity, atual);
      await manager.save(SolicitacaoEventoEntity, manager.create(SolicitacaoEventoEntity, {
        solicitacaoId: id, atorId: user.id, tipo: 'negociacao_iniciada',
        statusAnterior: atual.status, statusNovo: atual.status, motivo: null,
      }));
      return 'iniciada' as const;
    });
    if (resultado === 'expirada') throw conflitoPedidoExpirado();
    if (resultado === 'iniciada') {
      await this.notificarSeguro({ usuarioId: solicitacao.clienteId, tipo: NotificacaoTipo.NegociacaoIniciada,
        titulo: 'Negociacao iniciada', mensagem: 'O profissional respondeu ao pedido e pode conversar com voce.',
        recursoTipo: 'solicitacao', recursoId: id });
    }
    return { ...(await this.responder(await this.carregar(id), user)), negociacaoIniciada: true };
  }

  async listarPropostasAtendimento(user: AuthenticatedUser, id: number, query: Record<string, unknown> = {}) {
    const solicitacao = await this.carregar(id);
    assertParticipante(user, solicitacao);
    const paginacao = parsePaginationQuery(query, { defaultLimit: 20, maxLimit: 100 });
    await this.solicitacoes.manager.transaction('READ COMMITTED', async (manager) => {
      const atual = await manager.findOne(SolicitacaoEntity, { where: { id }, lock: { mode: 'pessimistic_write' } });
      if (atual?.status === SolicitacaoStatus.AguardandoResposta) {
        await this.expirarPropostasPendentes(manager, atual);
      }
    });
    const rows = await this.solicitacoes.manager.query(`SELECT id, versao, proposto_por_id, valor, data_servico,
      horario_servico, duracao_minutos, status, respondido_por_id, respondido_em, criado_em, expira_em
      FROM solicitacao_propostas_atendimento WHERE solicitacao_id = ? ORDER BY versao DESC LIMIT ? OFFSET ?`,
    [id, paginacao.limite, paginacao.skip]) as PropostaAtendimentoRow[];
    const counts = await this.solicitacoes.manager.query('SELECT COUNT(*) total FROM solicitacao_propostas_atendimento WHERE solicitacao_id = ?', [id]) as Array<{ total: number | string }>;
    const itens = rows.length === 0 ? [] : await this.solicitacoes.manager.query(
      `SELECT proposta_id, opcao_id, nome_snapshot FROM proposta_atendimento_opcoes WHERE proposta_id IN (${rows.map(() => '?').join(',')}) ORDER BY id`,
      rows.map((row) => row.id),
    ) as PropostaOpcaoRow[];
    return { paginacao: paginationMetadata(paginacao, Number(counts[0]?.total ?? 0)),
      propostas: rows.map((row) => propostaAtendimentoResponse(row, itens.filter((item) => item.proposta_id === row.id))) };
  }

  async proporAtendimento(user: AuthenticatedUser, id: number, body: unknown) {
    const input = parsePropostaAtendimento(body);
    assertAgendamentoFuturo(input.dataServico, input.horarioServico);
    const solicitacao = await this.carregar(id);
    assertProfissionalParticipante(user, solicitacao);
    const propostaId = await this.solicitacoes.manager.transaction('READ COMMITTED', async (manager) => {
      const perfil = await manager.findOne(ProfissionalPerfilEntity, { where: { id: solicitacao.profissionalId }, lock: { mode: 'pessimistic_write' } });
      const atual = await manager.findOne(SolicitacaoEntity, { where: { id }, lock: { mode: 'pessimistic_write' } });
      if (perfil === null || !perfil.ativo || perfil.habilitacaoEstado === 'suspenso' || atual === null || atual.status !== SolicitacaoStatus.AguardandoResposta) throw conflitoNegociacao();
      if (perfil.usuarioId !== user.id) throw forbidden();
      const evento = await manager.findOne(SolicitacaoEventoEntity, { where: { solicitacaoId: id, tipo: 'negociacao_iniciada' } });
      if (evento === null || atual.servicoId === null) throw conflitoNegociacao();
      if (await expirarNegociacaoInativa(manager, atual)) return 'expirada' as const;
      const oferta = await bloquearOfertaCatalogo(manager, atual.profissionalId, atual.servicoId);
      const opcoes = await carregarOpcoesAtivas(manager, oferta.servicoCatalogoId!, input.opcoesIds);
      await this.expirarPropostasPendentes(manager, atual);
      await manager.query("UPDATE solicitacao_propostas_atendimento SET status='substituida' WHERE solicitacao_id=? AND status='pendente'", [id]);
      const versions = await manager.query('SELECT COALESCE(MAX(versao), 0) AS versao FROM solicitacao_propostas_atendimento WHERE solicitacao_id=?', [id]) as Array<{ versao: number | string }>;
      const versao = Number(versions[0]?.versao ?? 0) + 1;
      const expiraEm = calcularExpiracaoProposta(new Date(), input.dataServico, input.horarioServico);
      const result = await manager.query(`INSERT INTO solicitacao_propostas_atendimento
        (solicitacao_id, versao, proposto_por_id, valor, data_servico, horario_servico, duracao_minutos, expira_em)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, versao, user.id, input.valor, input.dataServico, input.horarioServico, input.duracaoMinutos, expiraEm]) as { insertId: number };
      for (const opcao of opcoes) {
        await manager.query('INSERT INTO proposta_atendimento_opcoes (proposta_id, opcao_id, nome_snapshot) VALUES (?, ?, ?)', [result.insertId, opcao.id, opcao.nome]);
      }
      atual.prazoInatividadeEm = calcularExpiracaoNegociacao(new Date());
      await manager.save(SolicitacaoEntity, atual);
      await manager.save(SolicitacaoEventoEntity, manager.create(SolicitacaoEventoEntity, {
        solicitacaoId: id, atorId: user.id, tipo: 'proposta_atendimento_enviada',
        statusAnterior: atual.status, statusNovo: atual.status, motivo: null,
      }));
      return result.insertId as number;
    });
    if (propostaId === 'expirada') throw conflitoNegociacaoExpirada();
    await this.notificarSeguro({ usuarioId: solicitacao.clienteId, tipo: NotificacaoTipo.PropostaAtendimentoEnviada,
      titulo: 'Proposta para analisar', mensagem: 'O profissional enviou uma proposta para voce conferir.',
      recursoTipo: 'solicitacao', recursoId: id });
    return { propostaId };
  }

  async responderPropostaAtendimento(user: AuthenticatedUser, id: number, propostaId: number, body: unknown) {
    const value = objectBody(body);
    if (Object.keys(value).length !== 1 || typeof value.aceitar !== 'boolean') throw badRequest('RESPOSTA_INVALIDA');
    const solicitacao = await this.carregar(id);
    assertClienteParticipante(user, solicitacao);
    const expirada = await this.solicitacoes.manager.transaction('READ COMMITTED', async (manager) => {
      const perfil = await manager.findOne(ProfissionalPerfilEntity, { where: { id: solicitacao.profissionalId }, lock: { mode: 'pessimistic_write' } });
      const atual = await manager.findOne(SolicitacaoEntity, { where: { id }, lock: { mode: 'pessimistic_write' } });
      if (atual === null || atual.status !== SolicitacaoStatus.AguardandoResposta) throw conflitoNegociacao();
      if (atual.clienteId !== user.id) throw forbidden();
      await this.expirarPropostasPendentes(manager, atual);
    const rows = await manager.query(`SELECT p.id, p.status, p.valor, p.data_servico, p.horario_servico, p.duracao_minutos FROM solicitacao_propostas_atendimento p
        WHERE p.id=? AND p.solicitacao_id=? AND p.versao=(SELECT MAX(ultima.versao) FROM solicitacao_propostas_atendimento ultima WHERE ultima.solicitacao_id=?) FOR UPDATE`,
      [propostaId, id, id]) as Array<{
        id: number; status: string; valor: string; data_servico: string;
        horario_servico: string; duracao_minutos: number;
      }>;
      if (rows[0]?.status === 'expirada') return true;
      if (rows[0]?.status !== 'pendente') throw new ConflictException({ code: 'PROPOSTA_DESATUALIZADA', message: 'A proposta nao esta mais disponivel.' });
      if (value.aceitar) {
        if (!habilitacaoManualLocalAtiva()) {
          throw new ConflictException({ code: 'CONFIRMACAO_ATENDIMENTO_PENDENTE', message: 'A confirmacao de atendimento ainda nao esta disponivel.' });
        }
        exigirHabilitacao(perfil);
        if (perfil === null || !perfil.ativo) throw new ConflictException({ code: 'PROFISSIONAL_INDISPONIVEL' });
        assertAgendamentoFuturo(rows[0].data_servico, rows[0].horario_servico);
        await this.validarAgendaComManager(
          manager, perfil.id, rows[0].data_servico, rows[0].horario_servico,
          rows[0].duracao_minutos, 0, atual.id,
        );
        await manager.query("UPDATE solicitacao_propostas_atendimento SET status='aceita', respondido_por_id=?, respondido_em=CURRENT_TIMESTAMP(6) WHERE id=? AND status='pendente'", [user.id, propostaId]);
        atual.dataServico = rows[0].data_servico;
        atual.horarioServico = rows[0].horario_servico;
        atual.duracaoMinutos = rows[0].duracao_minutos;
        atual.precoFinal = String(rows[0].valor);
        atual.status = SolicitacaoStatus.AceitaAgendada;
        atual.prazoInatividadeEm = null;
        await manager.save(SolicitacaoEntity, atual);
        await manager.save(SolicitacaoEventoEntity, manager.create(SolicitacaoEventoEntity, {
          solicitacaoId: id, atorId: user.id, tipo: 'proposta_atendimento_aceita',
          statusAnterior: SolicitacaoStatus.AguardandoResposta,
          statusNovo: SolicitacaoStatus.AceitaAgendada, motivo: null,
        }));
        return false;
      }
      await manager.query("UPDATE solicitacao_propostas_atendimento SET status='recusada', respondido_por_id=?, respondido_em=CURRENT_TIMESTAMP(6) WHERE id=?", [user.id, propostaId]);
      atual.prazoInatividadeEm = calcularExpiracaoNegociacao(new Date());
      await manager.save(SolicitacaoEntity, atual);
      await manager.save(SolicitacaoEventoEntity, manager.create(SolicitacaoEventoEntity, {
        solicitacaoId: id, atorId: user.id, tipo: 'proposta_atendimento_recusada',
        statusAnterior: atual.status, statusNovo: atual.status, motivo: null,
      }));
      return false;
    });
    if (expirada) throw new ConflictException({ code: 'PROPOSTA_EXPIRADA', message: 'O prazo para responder esta proposta terminou.' });
    const atualizada = await this.carregar(id);
    const aceita = atualizada.status === SolicitacaoStatus.AceitaAgendada;
    await this.notificarSeguro({ usuarioId: solicitacao.profissional.usuarioId,
      tipo: aceita ? NotificacaoTipo.SolicitacaoAceita : NotificacaoTipo.PropostaAtendimentoRecusada,
      titulo: aceita ? 'Atendimento confirmado' : 'Proposta recusada',
      mensagem: aceita ? 'O cliente confirmou a proposta. O horario foi reservado.' : 'O cliente recusou a proposta. Voces podem conversar novamente.',
      recursoTipo: 'solicitacao', recursoId: id });
    return { propostaId, status: aceita ? 'aceita' : 'recusada', solicitacao: atualizada };
  }

  async expirarPropostasVencidas(agora = new Date(), limite = 100): Promise<number> {
    const candidatas = await this.solicitacoes.manager.query(`SELECT DISTINCT solicitacao_id
      FROM solicitacao_propostas_atendimento
      WHERE status='pendente' AND (expira_em IS NULL OR expira_em <= ?)
      ORDER BY solicitacao_id ASC LIMIT ?`, [agora, limite]) as Array<{ solicitacao_id: number }>;
    let expiradas = 0;

    for (const candidata of candidatas) {
      expiradas += await this.solicitacoes.manager.transaction('READ COMMITTED', async (manager) => {
        const solicitacao = await manager.findOne(SolicitacaoEntity, {
          where: { id: candidata.solicitacao_id },
          lock: { mode: 'pessimistic_write' },
        });
        if (solicitacao === null || solicitacao.status !== SolicitacaoStatus.AguardandoResposta) return 0;
        return this.expirarPropostasPendentes(manager, solicitacao, agora);
      });
    }

    return expiradas;
  }

  async expirarPedidosSemResposta(agora = new Date(), limite = 100): Promise<number> {
    const candidatas = await this.solicitacoes.manager.query(`SELECT pedido.id
      FROM solicitacoes pedido
      WHERE pedido.status='aguardando_resposta'
        AND (pedido.prazo_resposta_em IS NULL OR pedido.prazo_resposta_em <= ?)
        AND NOT EXISTS (
          SELECT 1 FROM solicitacao_eventos evento
          WHERE evento.solicitacao_id=pedido.id AND evento.tipo='negociacao_iniciada'
        )
        AND NOT EXISTS (
          SELECT 1 FROM mensagens_atendimento mensagem
          INNER JOIN profissionais profissional ON profissional.usuario_id=mensagem.autor_id
          WHERE mensagem.solicitacao_id=pedido.id AND profissional.id=pedido.profissional_id
        )
      ORDER BY COALESCE(pedido.prazo_resposta_em, pedido.criado_em), pedido.id
      LIMIT ?`, [agora, limite]) as Array<{ id: number }>;
    let expirados = 0;

    for (const candidata of candidatas) {
      expirados += await this.solicitacoes.manager.transaction('READ COMMITTED', async (manager) => {
        const solicitacao = await manager.findOne(SolicitacaoEntity, {
          where: { id: candidata.id },
          lock: { mode: 'pessimistic_write' },
        });
        if (solicitacao === null || solicitacao.status !== SolicitacaoStatus.AguardandoResposta) return 0;
        return Number(await expirarPedidoSemResposta(manager, solicitacao, agora));
      });
    }

    return expirados;
  }

  async expirarNegociacoesInativas(agora = new Date(), limite = 100): Promise<number> {
    const candidatas = await this.solicitacoes.manager.query(`SELECT pedido.id
      FROM solicitacoes pedido
      WHERE pedido.status='aguardando_resposta'
        AND pedido.prazo_inatividade_em IS NOT NULL
        AND pedido.prazo_inatividade_em <= ?
        AND NOT EXISTS (SELECT 1 FROM solicitacao_propostas_atendimento proposta
          WHERE proposta.solicitacao_id=pedido.id AND proposta.status='pendente')
      ORDER BY pedido.prazo_inatividade_em, pedido.id
      LIMIT ?`, [agora, limite]) as Array<{ id: number }>;
    let expiradas = 0;

    for (const candidata of candidatas) {
      expiradas += await this.solicitacoes.manager.transaction('READ COMMITTED', async (manager) => {
        const solicitacao = await manager.findOne(SolicitacaoEntity, {
          where: { id: candidata.id },
          lock: { mode: 'pessimistic_write' },
        });
        if (solicitacao === null) return 0;
        return Number(await expirarNegociacaoInativa(manager, solicitacao, agora));
      });
    }
    return expiradas;
  }

  private async expirarPropostasPendentes(
    manager: EntityManager,
    solicitacao: SolicitacaoEntity,
    agora = new Date(),
  ): Promise<number> {
    const rows = await manager.query(`SELECT id, criado_em, data_servico, horario_servico, expira_em
      FROM solicitacao_propostas_atendimento WHERE solicitacao_id=? AND status='pendente' ORDER BY id FOR UPDATE`,
    [solicitacao.id]) as Array<{ id: number; criado_em: Date; data_servico: string; horario_servico: string; expira_em: Date | null }>;
    let expiradas = 0;
    for (const proposta of rows) {
      const calculada = calcularExpiracaoProposta(proposta.criado_em, proposta.data_servico, proposta.horario_servico);
      const expiraEm = proposta.expira_em === null
        ? calculada
        : new Date(Math.min(proposta.expira_em.getTime(), calculada.getTime()));
      if (propostaExpirada(expiraEm, agora)) {
        await manager.query("UPDATE solicitacao_propostas_atendimento SET status='expirada', expira_em=? WHERE id=? AND status='pendente'", [expiraEm, proposta.id]);
        await manager.save(SolicitacaoEventoEntity, manager.create(SolicitacaoEventoEntity, {
          solicitacaoId: solicitacao.id, atorId: null, tipo: 'proposta_atendimento_expirada',
          statusAnterior: solicitacao.status, statusNovo: solicitacao.status, motivo: null,
        }));
        expiradas++;
      } else if (proposta.expira_em === null) {
        await manager.query(`UPDATE solicitacao_propostas_atendimento SET expira_em=? WHERE id=? AND status='pendente'`, [expiraEm, proposta.id]);
      }
    }
    if (expiradas > 0) {
      solicitacao.prazoInatividadeEm = calcularExpiracaoNegociacao(agora);
      await manager.save(SolicitacaoEntity, solicitacao);
    }
    return expiradas;
  }

  async aceitar(user: AuthenticatedUser, id: number) {
    const solicitacao = await this.carregar(id);
    assertProfissionalParticipante(user, solicitacao);
    const response = await this.transicionar(
      solicitacao,
      SolicitacaoStatus.AguardandoResposta,
      SolicitacaoStatus.AceitaAgendada,
      user,
      'solicitacao_aceita',
    );
    await this.notificarSeguro({
      usuarioId: solicitacao.clienteId,
      tipo: NotificacaoTipo.SolicitacaoAceita,
      titulo: 'Solicitacao aceita',
      mensagem: 'O profissional aceitou sua solicitacao.',
      recursoTipo: 'solicitacao',
      recursoId: solicitacao.id,
    });
    return response;
  }

  async recusar(user: AuthenticatedUser, id: number) {
    const solicitacao = await this.carregar(id);
    assertProfissionalParticipante(user, solicitacao);
    const response = await this.transicionar(
      solicitacao,
      SolicitacaoStatus.AguardandoResposta,
      SolicitacaoStatus.Recusada,
      user,
      'solicitacao_recusada',
    );
    await this.notificarSeguro({
      usuarioId: solicitacao.clienteId,
      tipo: NotificacaoTipo.SolicitacaoRecusada,
      titulo: 'Solicitacao recusada',
      mensagem: 'O profissional recusou sua solicitacao.',
      recursoTipo: 'solicitacao',
      recursoId: solicitacao.id,
    });
    return response;
  }

  async encerrarNegociacao(user: AuthenticatedUser, id: number, body: unknown) {
    const motivo = textField(objectBody(body), 'motivo', 10, 600);
    const solicitacao = await this.carregar(id);
    assertParticipante(user, solicitacao);
    if (user.tipo === UsuarioTipo.Administrador) throw forbidden();
    const response = await this.transicionar(
      solicitacao,
      SolicitacaoStatus.AguardandoResposta,
      SolicitacaoStatus.Recusada,
      user,
      'negociacao_encerrada',
      motivo,
      undefined,
      true,
    );
    const destinatarioId = user.id === solicitacao.clienteId
      ? solicitacao.profissional.usuarioId
      : solicitacao.clienteId;
    await this.notificarSeguro({
      usuarioId: destinatarioId,
      tipo: NotificacaoTipo.SolicitacaoRecusada,
      titulo: 'Negociacao encerrada',
      mensagem: 'A outra parte encerrou a negociacao do atendimento.',
      recursoTipo: 'solicitacao',
      recursoId: solicitacao.id,
    });
    return response;
  }

  async proporAntesAceite(user: AuthenticatedUser, id: number, body: unknown) {
    const input = parsePropostaAntesAceite(body);
    const solicitacao = await this.carregar(id);
    assertProfissionalParticipante(user, solicitacao);
    await this.solicitacoes.manager.transaction('READ COMMITTED', async (manager) => {
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { id: solicitacao.profissionalId },
        lock: { mode: 'pessimistic_write' },
      });
      const atual = await manager.findOne(SolicitacaoEntity, {
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      const agora = new Date();
      if (atual === null || atual.status !== SolicitacaoStatus.AguardandoResposta) {
        throw new ConflictException({ code: 'TRANSICAO_INVALIDA' });
      }
      if (prazoPedidoEncerrado(atual, agora)) {
        throw new ConflictException({ code: 'PRAZO_PEDIDO_ENCERRADO' });
      }
      exigirHabilitacao(perfil);
      const data = input.dataServico ?? atual.dataServico;
      const horario = input.horarioServico ?? atual.horarioServico;
      assertAgendamentoFuturo(data, horario);
      const pendentes = await manager.find(SolicitacaoPropostaEntity, {
        where: { solicitacaoId: id, status: SolicitacaoPropostaStatus.Pendente },
      });
      for (const anterior of pendentes) {
        anterior.status = SolicitacaoPropostaStatus.Substituida;
        await manager.save(SolicitacaoPropostaEntity, anterior);
      }
      await manager.save(SolicitacaoPropostaEntity, manager.create(SolicitacaoPropostaEntity, {
        solicitacaoId: id,
        propostoPorId: user.id,
        dataProposta: input.dataServico,
        horarioProposto: input.horarioServico,
        escopoProposto: input.escopo,
        status: SolicitacaoPropostaStatus.Pendente,
        venceEm: new Date(agora.getTime() + 48 * 60 * 60 * 1000),
        respondidoEm: null,
      }));
      atual.prazoRespostaEm = null;
      atual.prazoInatividadeEm = new Date(agora.getTime() + 96 * 60 * 60 * 1000);
      await manager.save(SolicitacaoEntity, atual);
      await manager.save(SolicitacaoEventoEntity, manager.create(SolicitacaoEventoEntity, {
        solicitacaoId: id,
        atorId: user.id,
        tipo: 'proposta_pre_aceite_criada',
        statusAnterior: atual.status,
        statusNovo: atual.status,
        // Guarda o texto original antes de qualquer aceite que altere o escopo.
        motivo: input.escopo === null ? null : atual.descricao,
      }));
    });
    await this.notificarSeguro({
      usuarioId: solicitacao.clienteId,
      tipo: NotificacaoTipo.PropostaPreAceite,
      titulo: 'Nova proposta para seu pedido',
      mensagem: 'O profissional enviou uma proposta. Responda em até 48 horas.',
      recursoTipo: 'solicitacao',
      recursoId: id,
    });
    return this.responder(await this.carregar(id), user);
  }

  async responderPropostaAntesAceite(
    user: AuthenticatedUser,
    id: number,
    propostaId: number,
    body: unknown,
  ) {
    const aceitar = parseRespostaPropostaAntesAceite(body);
    const solicitacao = await this.carregar(id);
    assertClienteParticipante(user, solicitacao);
    await this.solicitacoes.manager.transaction('READ COMMITTED', async (manager) => {
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { id: solicitacao.profissionalId },
        lock: { mode: 'pessimistic_write' },
      });
      const atual = await manager.findOne(SolicitacaoEntity, {
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      const proposta = await manager.findOne(SolicitacaoPropostaEntity, {
        where: { id: propostaId, solicitacaoId: id },
        lock: { mode: 'pessimistic_write' },
      });
      const agora = new Date();
      if (atual === null || atual.status !== SolicitacaoStatus.AguardandoResposta ||
          proposta === null || proposta.status !== SolicitacaoPropostaStatus.Pendente) {
        throw new ConflictException({ code: 'PROPOSTA_INDISPONIVEL' });
      }
      if (prazoPedidoEncerrado(atual, agora) || proposta.venceEm <= agora) {
        throw new ConflictException({ code: 'PROPOSTA_EXPIRADA' });
      }
      if (aceitar) {
        exigirHabilitacao(perfil);
        if (perfil === null || !perfil.ativo) throw badRequest('PROFISSIONAL_INDISPONIVEL');
        const data = proposta.dataProposta ?? atual.dataServico;
        const horario = proposta.horarioProposto ?? atual.horarioServico;
        assertAgendamentoFuturo(data, horario);
        await this.validarAgendaComManager(
          manager, perfil.id, data, horario, atual.duracaoMinutos,
          atual.intervaloMinutos, atual.id,
        );
        atual.dataServico = data;
        atual.horarioServico = horario;
        if (proposta.escopoProposto !== null) atual.descricao = proposta.escopoProposto;
        atual.status = SolicitacaoStatus.AceitaAgendada;
        atual.prazoInatividadeEm = null;
      } else {
        atual.prazoInatividadeEm = new Date(agora.getTime() + 96 * 60 * 60 * 1000);
      }
      proposta.status = aceitar
        ? SolicitacaoPropostaStatus.Aceita
        : SolicitacaoPropostaStatus.Recusada;
      proposta.respondidoEm = agora;
      await manager.save(SolicitacaoPropostaEntity, proposta);
      await manager.save(SolicitacaoEntity, atual);
      await manager.save(SolicitacaoEventoEntity, manager.create(SolicitacaoEventoEntity, {
        solicitacaoId: id,
        atorId: user.id,
        tipo: aceitar ? 'proposta_pre_aceite_aceita' : 'proposta_pre_aceite_recusada',
        statusAnterior: SolicitacaoStatus.AguardandoResposta,
        statusNovo: atual.status,
        motivo: null,
      }));
    });
    await this.notificarSeguro({
      usuarioId: solicitacao.profissional.usuarioId,
      tipo: NotificacaoTipo.PropostaPreAceiteRespondida,
      titulo: aceitar ? 'Proposta aceita' : 'Proposta recusada',
      mensagem: aceitar
        ? 'O cliente aceitou sua proposta; o atendimento foi agendado.'
        : 'O cliente recusou sua proposta. Você pode enviar outra enquanto o pedido estiver aberto.',
      recursoTipo: 'solicitacao',
      recursoId: id,
    });
    return this.responder(await this.carregar(id), user);
  }

  async cancelar(user: AuthenticatedUser, id: number, body: unknown) {
    const motivo = textField(objectBody(body), 'motivo', 10, 400);
    const solicitacao = await this.carregar(id);
    assertParticipante(user, solicitacao);
    if (user.tipo === UsuarioTipo.Administrador) throw forbidden();
    if (
      solicitacao.status === SolicitacaoStatus.AguardandoResposta &&
      user.id !== solicitacao.clienteId
    ) {
      throw forbidden();
    }
    if (
      solicitacao.status === SolicitacaoStatus.AceitaAgendada &&
      agendamentoJaIniciou(solicitacao)
    ) {
      throw new ConflictException({
        code: 'CANCELAMENTO_APOS_INICIO',
        message:
          'O atendimento ja iniciou. Registre um nao comparecimento ou use a ajuda e seguranca.',
      });
    }
    await this.transicionar(
      solicitacao,
      [SolicitacaoStatus.AguardandoResposta, SolicitacaoStatus.AceitaAgendada],
      SolicitacaoStatus.Cancelada,
      user,
      (atual) => {
        if (atual.status === SolicitacaoStatus.AceitaAgendada && agendamentoJaIniciou(atual)) {
          throw new ConflictException({ code: 'CANCELAMENTO_APOS_INICIO' });
        }
        return atual.status === SolicitacaoStatus.AceitaAgendada &&
          user.id === atual.clienteId &&
          cancelamentoClienteExcepcional(atual.dataServico, atual.horarioServico)
          ? 'cancelamento_cliente_excepcional' : 'solicitacao_cancelada';
      },
      motivo,
      (atual) => {
        atual.cancelamentoMotivo = motivo;
      },
    );
    const canceladoPeloCliente = user.id === solicitacao.clienteId;
    await this.notificarSeguro({
      usuarioId: canceladoPeloCliente
        ? solicitacao.profissional.usuarioId
        : solicitacao.clienteId,
      tipo: NotificacaoTipo.SolicitacaoCancelada,
      titulo: 'Solicitacao cancelada',
      mensagem: canceladoPeloCliente
        ? 'O cliente cancelou uma solicitacao de atendimento.'
        : 'O profissional cancelou um atendimento agendado.',
      recursoTipo: 'solicitacao',
      recursoId: solicitacao.id,
    });
    return this.responder(await this.carregar(id), user);
  }

  async concluir(user: AuthenticatedUser, id: number) {
    const solicitacao = await this.carregar(id);
    assertProfissionalParticipante(user, solicitacao);
    exigirAgendamentoIniciado(solicitacao);
    const response = await this.transicionar(
      solicitacao,
      SolicitacaoStatus.AceitaAgendada,
      SolicitacaoStatus.ConclusaoPendente,
      user,
      'servico_marcado_realizado',
    );
    await this.notificarSeguro({
      usuarioId: solicitacao.clienteId,
      tipo: NotificacaoTipo.ConclusaoPendente,
      titulo: 'Confirme a conclusao',
      mensagem: 'O profissional informou que o atendimento foi realizado.',
      recursoTipo: 'solicitacao',
      recursoId: solicitacao.id,
    });
    return response;
  }

  async confirmarConclusao(user: AuthenticatedUser, id: number) {
    const solicitacao = await this.carregar(id);
    assertClienteParticipante(user, solicitacao);
    const response = await this.transicionar(
      solicitacao,
      [SolicitacaoStatus.ConclusaoPendente, SolicitacaoStatus.ConclusaoContestada],
      SolicitacaoStatus.ConclusaoConfirmada,
      user,
      'conclusao_confirmada',
    );
    await this.notificarSeguro({
      usuarioId: solicitacao.profissional.usuarioId,
      tipo: NotificacaoTipo.SolicitacaoConcluida,
      titulo: 'Servico concluido',
      mensagem: 'O cliente confirmou a conclusao do atendimento.',
      recursoTipo: 'solicitacao',
      recursoId: solicitacao.id,
    });
    return response;
  }

  async contestarConclusao(user: AuthenticatedUser, id: number, body: unknown) {
    const motivo = textField(objectBody(body), 'motivo', 20, 600);
    const solicitacao = await this.carregar(id);
    assertClienteParticipante(user, solicitacao);
    const response = await this.transicionar(
      solicitacao,
      SolicitacaoStatus.ConclusaoPendente,
      SolicitacaoStatus.ConclusaoContestada,
      user,
      'conclusao_contestada',
      motivo,
      (atual) => {
        atual.conclusaoContestacaoMotivo = motivo;
      },
    );
    await this.notificarSeguro({
      usuarioId: solicitacao.profissional.usuarioId,
      tipo: NotificacaoTipo.ConclusaoContestada,
      titulo: 'Conclusao contestada',
      mensagem: 'O cliente informou que o atendimento precisa ser revisto.',
      recursoTipo: 'solicitacao',
      recursoId: solicitacao.id,
    });
    return response;
  }

  async informarNaoComparecimento(
    user: AuthenticatedUser,
    id: number,
    body: unknown,
  ) {
    const motivo = textField(objectBody(body), 'motivo', 20, 600);
    const solicitacao = await this.carregar(id);
    assertParticipante(user, solicitacao);
    if (user.tipo === UsuarioTipo.Administrador) throw forbidden();
    exigirAgendamentoIniciado(solicitacao);
    const destinatarioId =
      user.id === solicitacao.clienteId
        ? solicitacao.profissional.usuarioId
        : solicitacao.clienteId;
    const response = await this.transicionar(
      solicitacao,
      SolicitacaoStatus.AceitaAgendada,
      SolicitacaoStatus.NaoComparecimentoInformado,
      user,
      'nao_comparecimento_informado',
      motivo,
      (atual) => {
        atual.naoComparecimentoMotivo = motivo;
        atual.naoComparecimentoPorId = user.id;
      },
    );
    await this.notificarSeguro({
      usuarioId: destinatarioId,
      tipo: NotificacaoTipo.NaoComparecimento,
      titulo: 'Nao comparecimento informado',
      mensagem: 'A outra parte registrou um nao comparecimento no atendimento.',
      recursoTipo: 'solicitacao',
      recursoId: solicitacao.id,
    });
    return response;
  }

  async contestarNaoComparecimento(
    user: AuthenticatedUser,
    id: number,
    body: unknown,
  ) {
    const motivo = textField(objectBody(body), 'motivo', 20, 600);
    const solicitacao = await this.carregar(id);
    assertParticipante(user, solicitacao);
    if (
      user.tipo === UsuarioTipo.Administrador ||
      solicitacao.naoComparecimentoPorId === user.id
    ) {
      throw forbidden();
    }
    const response = await this.transicionar(
      solicitacao,
      SolicitacaoStatus.NaoComparecimentoInformado,
      SolicitacaoStatus.ConclusaoContestada,
      user,
      'nao_comparecimento_contestado',
      motivo,
      (atual) => {
        atual.conclusaoContestacaoMotivo = motivo;
      },
    );
    const destinatarioId = solicitacao.naoComparecimentoPorId;
    if (destinatarioId !== null) {
      await this.notificarSeguro({
        usuarioId: destinatarioId,
        tipo: NotificacaoTipo.ConclusaoContestada,
        titulo: 'Ocorrencia contestada',
        mensagem: 'A outra parte contestou o nao comparecimento informado.',
        recursoTipo: 'solicitacao',
        recursoId: solicitacao.id,
      });
    }
    return response;
  }

  async proporReagendamento(
    user: AuthenticatedUser,
    id: number,
    body: unknown,
  ) {
    const input = parseReagendamento(body);
    assertAgendamentoFuturo(input.dataServico, input.horarioServico);
    const solicitacao = await this.carregar(id);
    assertParticipante(user, solicitacao);
    if (user.tipo === UsuarioTipo.Administrador) throw forbidden();
    if (solicitacao.status !== SolicitacaoStatus.AceitaAgendada) {
      throw new ConflictException({
        code: 'REAGENDAMENTO_INDISPONIVEL',
        message: 'Somente atendimentos aceitos podem ser reagendados.',
      });
    }
    if (agendamentoJaIniciou(solicitacao)) {
      throw new ConflictException({
        code: 'REAGENDAMENTO_APOS_INICIO',
        message:
          'O atendimento ja iniciou. Use o fluxo de conclusao ou registre uma ocorrencia.',
      });
    }
    await this.solicitacoes.manager.transaction(
      'READ COMMITTED',
      async (manager) => {
        const atual = await manager.findOne(SolicitacaoEntity, {
          where: { id },
          lock: { mode: 'pessimistic_write' },
        });
        if (
          atual === null ||
          atual.status !== SolicitacaoStatus.AceitaAgendada ||
          agendamentoJaIniciou(atual)
        ) {
          throw new ConflictException({
            code: 'REAGENDAMENTO_INDISPONIVEL',
            message: 'Este atendimento nao pode mais ser reagendado.',
          });
        }
        await this.validarAgendaComManager(
          manager,
          atual.profissionalId,
          input.dataServico,
          input.horarioServico,
          atual.duracaoMinutos,
          atual.intervaloMinutos,
          atual.id,
        );
        await manager.update(
          SolicitacaoReagendamentoEntity,
          { solicitacaoId: id, status: ReagendamentoStatus.Pendente },
          { status: ReagendamentoStatus.Cancelado, respondidoEm: new Date() },
        );
        await manager.save(
          SolicitacaoReagendamentoEntity,
          manager.create(SolicitacaoReagendamentoEntity, {
            solicitacaoId: id,
            propostoPorId: user.id,
            dataProposta: input.dataServico,
            horarioProposto: input.horarioServico,
            motivo: input.motivo,
            status: ReagendamentoStatus.Pendente,
            respondidoEm: null,
            venceEm: user.id === atual.clienteId
              ? null : new Date(Date.now() + 48 * 60 * 60 * 1000),
          }),
        );
        await manager.save(
          SolicitacaoEventoEntity,
          manager.create(SolicitacaoEventoEntity, {
            solicitacaoId: id,
            atorId: user.id,
            tipo: 'reagendamento_proposto',
            statusAnterior: atual.status,
            statusNovo: atual.status,
            motivo: input.motivo,
          }),
        );
      },
    );
    const propostoPeloCliente = user.id === solicitacao.clienteId;
    await this.notificarSeguro({
      usuarioId: propostoPeloCliente
        ? solicitacao.profissional.usuarioId
        : solicitacao.clienteId,
      tipo: NotificacaoTipo.ReagendamentoProposto,
      titulo: 'Nova proposta de reagendamento',
      mensagem: propostoPeloCliente
        ? 'O cliente sugeriu uma nova data para o atendimento.'
        : 'O profissional sugeriu uma nova data para o atendimento.',
      recursoTipo: 'solicitacao',
      recursoId: id,
    });
    return this.responder(await this.carregar(id), user);
  }

  async responderReagendamento(
    user: AuthenticatedUser,
    id: number,
    body: unknown,
  ) {
    const aceitar = parseRespostaReagendamento(body);
    const solicitacao = await this.carregar(id);
    assertParticipante(user, solicitacao);
    if (user.tipo === UsuarioTipo.Administrador) throw forbidden();
    let proponenteId: number | null = null;
    await this.solicitacoes.manager.transaction('READ COMMITTED', async (manager) => {
      const atual = await manager.findOne(SolicitacaoEntity, {
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      const proposta = await manager.findOne(SolicitacaoReagendamentoEntity, {
        where: { solicitacaoId: id, status: ReagendamentoStatus.Pendente },
        order: { criadoEm: 'DESC' },
        lock: { mode: 'pessimistic_write' },
      });
      if (atual === null || proposta === null || atual.status !== SolicitacaoStatus.AceitaAgendada) {
        throw new ConflictException({
          code: 'REAGENDAMENTO_INDISPONIVEL',
          message: 'Esta proposta não está mais disponível.',
        });
      }
      proponenteId =
        proposta.propostoPorId ?? solicitacao.profissional.usuarioId;
      if (proponenteId === user.id) {
        throw new ForbiddenException({
          code: 'REAGENDAMENTO_RESPOSTA_PROPRIA',
          message: 'A proposta deve ser respondida pela outra parte.',
        });
      }
      if (proposta.venceEm != null && proposta.venceEm <= new Date()) {
        throw new ConflictException({ code: 'PROPOSTA_EXPIRADA' });
      }
      if (aceitar) {
        if (agendamentoJaIniciou(atual)) {
          throw new ConflictException({ code: 'REAGENDAMENTO_APOS_INICIO' });
        }
        assertAgendamentoFuturo(proposta.dataProposta, proposta.horarioProposto);
        await this.validarAgendaComManager(
          manager,
          atual.profissionalId,
          proposta.dataProposta,
          proposta.horarioProposto,
          atual.duracaoMinutos,
          atual.intervaloMinutos,
          atual.id,
        );
        atual.dataServico = proposta.dataProposta;
        atual.horarioServico = proposta.horarioProposto;
        await manager.save(SolicitacaoEntity, atual);
      }
      proposta.status = aceitar ? ReagendamentoStatus.Aceito : ReagendamentoStatus.Recusado;
      proposta.respondidoEm = new Date();
      await manager.save(SolicitacaoReagendamentoEntity, proposta);
      await manager.save(
        SolicitacaoEventoEntity,
        manager.create(SolicitacaoEventoEntity, {
          solicitacaoId: id,
          atorId: user.id,
          tipo: aceitar ? 'reagendamento_aceito' : 'reagendamento_recusado',
          statusAnterior: atual.status,
          statusNovo: atual.status,
          motivo: null,
        }),
      );
    });
    if (proponenteId !== null) {
      await this.notificarSeguro({
        usuarioId: proponenteId,
        tipo: NotificacaoTipo.ReagendamentoRespondido,
        titulo: aceitar ? 'Reagendamento confirmado' : 'Reagendamento recusado',
        mensagem: aceitar
          ? 'A outra parte confirmou a nova data do atendimento.'
          : 'A outra parte recusou a proposta. Converse para combinar outra opcao.',
        recursoTipo: 'solicitacao',
        recursoId: id,
      });
    }
    return this.responder(await this.carregar(id), user);
  }

  async proporOrcamento(
    user: AuthenticatedUser,
    id: number,
    body: unknown,
  ) {
    const input = parseOrcamento(body);
    const solicitacao = await this.carregar(id);
    assertProfissionalParticipante(user, solicitacao);
    if (
      solicitacao.status !== SolicitacaoStatus.AceitaAgendada ||
      agendamentoJaIniciou(solicitacao)
    ) {
      throw new ConflictException({
        code: 'ORCAMENTO_INDISPONIVEL',
        message:
          'O orcamento so pode ser enviado antes do inicio de um atendimento aceito.',
      });
    }

    await this.solicitacoes.manager.transaction(
      'READ COMMITTED',
      async (manager) => {
        const atual = await manager.findOne(SolicitacaoEntity, {
          where: { id },
          lock: { mode: 'pessimistic_write' },
        });
        if (
          atual === null ||
          atual.status !== SolicitacaoStatus.AceitaAgendada ||
          agendamentoJaIniciou(atual)
        ) {
          throw new ConflictException({
            code: 'ORCAMENTO_INDISPONIVEL',
            message: 'Este atendimento nao aceita mais um novo orcamento.',
          });
        }

        await manager.update(
          SolicitacaoOrcamentoEntity,
          { solicitacaoId: id, status: OrcamentoStatus.Pendente },
          { status: OrcamentoStatus.Substituido, respondidoEm: new Date() },
        );
        await manager.save(
          SolicitacaoOrcamentoEntity,
          manager.create(SolicitacaoOrcamentoEntity, {
            solicitacaoId: id,
            propostoPorId: user.id,
            valor: input.valor,
            descricao: input.descricao,
            status: OrcamentoStatus.Pendente,
            respondidoEm: null,
            venceEm: new Date(Date.now() + 48 * 60 * 60 * 1000),
          }),
        );
        await manager.save(
          SolicitacaoEventoEntity,
          manager.create(SolicitacaoEventoEntity, {
            solicitacaoId: id,
            atorId: user.id,
            tipo: 'orcamento_proposto',
            statusAnterior: atual.status,
            statusNovo: atual.status,
            motivo: input.descricao,
          }),
        );
      },
    );

    await this.notificarSeguro({
      usuarioId: solicitacao.clienteId,
      tipo: NotificacaoTipo.OrcamentoProposto,
      titulo: 'Novo orcamento para analisar',
      mensagem:
        'O profissional enviou o valor final proposto para o atendimento.',
      recursoTipo: 'solicitacao',
      recursoId: id,
    });
    return this.responder(await this.carregar(id), user);
  }

  async responderOrcamento(
    user: AuthenticatedUser,
    id: number,
    body: unknown,
  ) {
    const aceitar = parseRespostaOrcamento(body);
    const solicitacao = await this.carregar(id);
    assertClienteParticipante(user, solicitacao);
    await this.solicitacoes.manager.transaction(
      'READ COMMITTED',
      async (manager) => {
        const atual = await manager.findOne(SolicitacaoEntity, {
          where: { id },
          lock: { mode: 'pessimistic_write' },
        });
        const orcamento = await manager.findOne(SolicitacaoOrcamentoEntity, {
          where: { solicitacaoId: id, status: OrcamentoStatus.Pendente },
          order: { criadoEm: 'DESC' },
          lock: { mode: 'pessimistic_write' },
        });
        if (
          atual === null ||
          orcamento === null ||
          atual.status !== SolicitacaoStatus.AceitaAgendada ||
          agendamentoJaIniciou(atual)
        ) {
          throw new ConflictException({
            code: 'ORCAMENTO_INDISPONIVEL',
            message: 'Este orcamento nao esta mais disponivel para resposta.',
          });
        }

        if (orcamento.venceEm != null && orcamento.venceEm <= new Date()) {
          throw new ConflictException({ code: 'PROPOSTA_EXPIRADA' });
        }

        if (aceitar) {
          await manager.update(
            SolicitacaoOrcamentoEntity,
            { solicitacaoId: id, status: OrcamentoStatus.Aceito },
            { status: OrcamentoStatus.Substituido },
          );
          atual.precoFinal = orcamento.valor;
          await manager.save(SolicitacaoEntity, atual);
        }
        orcamento.status = aceitar
          ? OrcamentoStatus.Aceito
          : OrcamentoStatus.Recusado;
        orcamento.respondidoEm = new Date();
        await manager.save(SolicitacaoOrcamentoEntity, orcamento);
        await manager.save(
          SolicitacaoEventoEntity,
          manager.create(SolicitacaoEventoEntity, {
            solicitacaoId: id,
            atorId: user.id,
            tipo: aceitar ? 'orcamento_aceito' : 'orcamento_recusado',
            statusAnterior: atual.status,
            statusNovo: atual.status,
            motivo: null,
          }),
        );
      },
    );

    await this.notificarSeguro({
      usuarioId: solicitacao.profissional.usuarioId,
      tipo: NotificacaoTipo.OrcamentoRespondido,
      titulo: aceitar ? 'Orcamento aceito' : 'Orcamento recusado',
      mensagem: aceitar
        ? 'O cliente aceitou o valor final proposto.'
        : 'O cliente recusou o orcamento. Converse antes de enviar uma revisao.',
      recursoTipo: 'solicitacao',
      recursoId: id,
    });
    return this.responder(await this.carregar(id), user);
  }

  private async transicionar(
    solicitacao: SolicitacaoEntity,
    origem: SolicitacaoStatus | readonly SolicitacaoStatus[],
    destino: SolicitacaoStatus,
    user: AuthenticatedUser,
    eventoTipo: string | ((solicitacao: SolicitacaoEntity) => string),
    motivo: string | null = null,
    atualizar?: (solicitacao: SolicitacaoEntity) => void,
    encerrarNegociacao = false,
  ) {
    const expirou = await this.solicitacoes.manager.transaction(
      'READ COMMITTED',
      async (manager) => {
        // Todas as transições adquirem os locks na mesma ordem. O perfil serializa
        // aceites de pedidos distintos; o pedido protege a sua própria transição.
        const perfil = await manager.findOne(ProfissionalPerfilEntity, {
          where: { id: solicitacao.profissionalId },
          lock: { mode: 'pessimistic_write' },
        });
        const atual = await manager.findOne(SolicitacaoEntity, {
          where: { id: solicitacao.id },
          lock: { mode: 'pessimistic_write' },
        });
        const permitidos = Array.isArray(origem) ? origem : [origem];
        if (atual === null || !permitidos.includes(atual.status)) {
          throw new ConflictException({
            code: 'TRANSICAO_INVALIDA',
            message: 'A solicitação já foi atualizada.',
          });
        }
        if (await expirarPedidoSemResposta(manager, atual)) return 'pedido' as const;
        if (await expirarNegociacaoInativa(manager, atual)) return 'negociacao' as const;
        if (destino === SolicitacaoStatus.Recusada) {
          const negociacao = await manager.findOne(SolicitacaoEventoEntity, {
            where: { solicitacaoId: atual.id, tipo: 'negociacao_iniciada' },
          });
          if (encerrarNegociacao !== (negociacao !== null)) {
            throw new ConflictException({
              code: negociacao === null ? 'NEGOCIACAO_NAO_INICIADA' : 'NEGOCIACAO_EXIGE_ENCERRAMENTO',
              message: negociacao === null
                ? 'A negociacao ainda nao foi iniciada.'
                : 'Use a acao de encerrar negociacao e informe o motivo.',
            });
          }
        }
        if (destino === SolicitacaoStatus.AceitaAgendada) {
          exigirHabilitacao(perfil);
          if (perfil === null || !perfil.ativo)
            throw badRequest('PROFISSIONAL_INDISPONIVEL');
          const opcoes = await manager.query('SELECT id FROM solicitacao_opcoes WHERE solicitacao_id = ? LIMIT 1', [atual.id]) as unknown[];
          if (opcoes.length > 0) throw new ConflictException({ code: 'USE_PROPOSTA_ATENDIMENTO', message: 'Este pedido deve ser negociado e confirmado por proposta.' });
          assertAgendamentoFuturo(atual.dataServico, atual.horarioServico);
          const disponibilidade = await manager.find(
            ProfissionalDisponibilidadeEntity,
            {
              where: { profissionalId: perfil.id, ativo: true },
            },
          );
          await this.validarAgendaComManager(
            manager,
            perfil.id,
            atual.dataServico,
            atual.horarioServico,
            atual.duracaoMinutos,
            atual.intervaloMinutos,
            atual.id,
            disponibilidade,
          );
        }
        const statusAnterior = atual.status;
        const tipoEvento = typeof eventoTipo === 'function' ? eventoTipo(atual) : eventoTipo;
        atual.status = destino;
        if (statusAnterior === SolicitacaoStatus.AguardandoResposta &&
            destino !== SolicitacaoStatus.AguardandoResposta) {
          atual.prazoRespostaEm = null;
          atual.prazoInatividadeEm = null;
          if (this.propostas !== undefined) {
            const pendentes = await manager.find(SolicitacaoPropostaEntity, {
              where: { solicitacaoId: atual.id, status: SolicitacaoPropostaStatus.Pendente },
            });
            for (const proposta of pendentes) {
              proposta.status = SolicitacaoPropostaStatus.Substituida;
              await manager.save(SolicitacaoPropostaEntity, proposta);
            }
          }
          await manager.query(
            `UPDATE solicitacao_propostas_atendimento
             SET status = 'substituida'
             WHERE solicitacao_id = ? AND status = 'pendente'`,
            [atual.id],
          );
        }
        atualizar?.(atual);
        await manager.save(SolicitacaoEntity, atual);
        await manager.save(
          SolicitacaoEventoEntity,
          manager.create(SolicitacaoEventoEntity, {
            solicitacaoId: atual.id,
            atorId: user.id,
            tipo: tipoEvento,
            statusAnterior,
            statusNovo: destino,
            motivo,
          }),
        );
        return null;
      },
    );
    if (expirou === 'pedido') throw conflitoPedidoExpirado();
    if (expirou === 'negociacao') throw conflitoNegociacaoExpirada();
    return this.responder(await this.carregar(solicitacao.id), user);
  }

  private async responder(
    solicitacao: SolicitacaoEntity,
    user: AuthenticatedUser,
  ) {
    const avaliado =
      solicitacao.status === SolicitacaoStatus.ConclusaoConfirmada &&
      (await this.avaliacoes.count({
        where: { solicitacaoId: solicitacao.id, avaliadorId: user.id },
      })) > 0;
    const reagendamentos = await this.reagendamentos.find({
      where: { solicitacaoId: solicitacao.id },
      order: { criadoEm: 'DESC' },
    });
    const orcamentos = await this.orcamentos.find({
      where: { solicitacaoId: solicitacao.id },
      order: { criadoEm: 'DESC' },
    });
    const propostas = await this.propostas?.find({
      where: { solicitacaoId: solicitacao.id },
      order: { criadoEm: 'DESC', id: 'DESC' },
    }) ?? [];
    const eventos = await this.solicitacoes.manager.getRepository(SolicitacaoEventoEntity).find({
      where: { solicitacaoId: solicitacao.id },
      relations: { ator: true },
      order: { criadoEm: 'DESC' },
      take: 100,
    });
    const negociacaoIniciada = eventos.some((evento) => evento.tipo === 'negociacao_iniciada') ||
      (await this.solicitacoes.manager.getRepository(SolicitacaoEventoEntity).find({
        where: { solicitacaoId: solicitacao.id, tipo: 'negociacao_iniciada' }, take: 1,
      })).some((evento) => evento.tipo === 'negociacao_iniciada');
    return {
      solicitacao: {
        ...solicitacaoResponse(solicitacao, user, avaliado),
        reagendamento: reagendamentos[0] === undefined
          ? null
          : reagendamentoResponse(reagendamentos[0]),
        reagendamentos: reagendamentos.map(reagendamentoResponse),
        orcamento:
          orcamentos[0] === undefined
            ? null
            : orcamentoResponse(orcamentos[0]),
        orcamentos: orcamentos.map(orcamentoResponse),
        propostaPreAceite: propostas[0] === undefined
          ? null
          : propostaPreAceiteResponse(propostas[0]),
        propostasPreAceite: propostas.map(propostaPreAceiteResponse),
        eventos: eventos.map(eventoResponse),
        negociacaoIniciada,
      },
    };
  }

  private async carregar(id: number): Promise<SolicitacaoEntity> {
    const solicitacao = await this.solicitacoes.findOne({
      where: { id },
      relations: {
        cliente: true,
        profissional: { usuario: true },
        categoria: true,
        endereco: true,
      },
    });
    if (solicitacao === null) {
      throw new NotFoundException({
        code: 'SOLICITACAO_NAO_ENCONTRADA',
        message: 'Solicitacao nao encontrada.',
      });
    }

    return solicitacao;
  }

  private async validarDisponibilidade(
    profissionalId: number,
    dataServico: string,
    horarioServico: string,
    duracaoMinutos: number,
    intervaloMinutos: number,
    ignorarSolicitacaoId?: number,
  ): Promise<void> {
    const disponibilidades = await this.disponibilidades.find({
      where: { profissionalId, ativo: true },
    });
    if (disponibilidades.length === 0) {
      throw badRequest('DISPONIBILIDADE_NAO_CADASTRADA');
    }
    if (!horarioDisponivel(disponibilidades, dataServico, horarioServico, duracaoMinutos)) {
      throw badRequest('HORARIO_INDISPONIVEL');
    }
    await this.validarAgendaComManager(
      this.solicitacoes.manager,
      profissionalId,
      dataServico,
      horarioServico,
      duracaoMinutos,
      intervaloMinutos,
      ignorarSolicitacaoId,
      disponibilidades,
    );
  }

  private async validarAgendaComManager(
    manager: EntityManager,
    profissionalId: number,
    dataServico: string,
    horarioServico: string,
    duracaoMinutos: number,
    intervaloMinutos: number,
    ignorarSolicitacaoId?: number,
    disponibilidadesCarregadas?: readonly ProfissionalDisponibilidadeEntity[],
  ) {
    const disponibilidades = disponibilidadesCarregadas ?? await manager.find(
      ProfissionalDisponibilidadeEntity,
      { where: { profissionalId, ativo: true } },
    );
    if (!horarioDisponivel(disponibilidades, dataServico, horarioServico, duracaoMinutos)) {
      throw new ConflictException({
        code: 'HORARIO_INDISPONIVEL',
        message: 'O atendimento não cabe no período disponível.',
      });
    }
    const bloqueio = await manager
      .createQueryBuilder(ProfissionalBloqueioEntity, 'bloqueio')
      .where('bloqueio.profissional_id = :profissionalId', { profissionalId })
      .andWhere(':dataServico BETWEEN bloqueio.data_inicio AND bloqueio.data_fim', { dataServico })
      .getOne();
    if (bloqueio !== null) {
      throw new ConflictException({
        code: 'DATA_BLOQUEADA',
        message: 'O profissional bloqueou esta data na agenda.',
      });
    }
    const ocupados = await manager.find(SolicitacaoEntity, {
      where: {
        profissionalId,
        dataServico,
        status: SolicitacaoStatus.AceitaAgendada,
      },
    });
    const inicio = minutos(horarioServico);
    const fim = inicio + duracaoMinutos + intervaloMinutos;
    const conflita = ocupados.some((item) => {
      if (item.id === ignorarSolicitacaoId) return false;
      const inicioExistente = minutos(item.horarioServico);
      const fimExistente = inicioExistente + item.duracaoMinutos + item.intervaloMinutos;
      return intervalosConflitam(inicio, fim, inicioExistente, fimExistente);
    });
    if (conflita) {
      throw new ConflictException({
        code: 'HORARIO_OCUPADO',
        message: 'Este horário se sobrepõe a outro atendimento ou intervalo.',
      });
    }
  }

  private async notificarSeguro(
    input: Parameters<NotificacoesService['criar']>[0],
  ) {
    try {
      await this.notificacoes.criar(input);
    } catch {
      // Notificacoes nao podem alterar o estado do atendimento.
    }
  }
}

function solicitacaoResponse(
  solicitacao: SolicitacaoEntity,
  user?: AuthenticatedUser,
  avaliado = false,
) {
  const enderecoLiberado = enderecoCompletoLiberado(solicitacao, user);
  return {
    id: solicitacao.id,
    servicoId: solicitacao.servicoId,
    nomeServico: solicitacao.nomeServico,
    servicoSnapshot: solicitacao.servicoSnapshot ?? null,
    escopoServicoSnapshot: solicitacao.escopoServicoSnapshot ?? null,
    avaliado,
    status: solicitacao.status,
    prazoRespostaEm: solicitacao.prazoRespostaEm?.toISOString() ?? null,
    prazoInatividadeEm: solicitacao.prazoInatividadeEm?.toISOString() ?? null,
    expiraEm: solicitacao.prazoRespostaEm?.toISOString() ?? null,
    negociacaoExpiraEm: solicitacao.prazoInatividadeEm?.toISOString() ?? null,
    descricao: solicitacao.descricao,
    bairroAtendimento: solicitacao.bairroAtendimento,
    enderecoId: solicitacao.enderecoId,
    enderecoProtegido: solicitacao.enderecoId !== null && !enderecoLiberado,
    enderecoCompletoLiberado: enderecoLiberado,
    enderecoAtendimento:
      enderecoLiberado && enderecoAtual(solicitacao) !== null
        ? enderecoAtual(solicitacao)
        : null,
    dataServico: solicitacao.dataServico,
    horarioServico: solicitacao.horarioServico,
    duracaoMinutos: solicitacao.duracaoMinutos,
    intervaloMinutos: solicitacao.intervaloMinutos,
    fusoHorario: fusoAgenda,
    precoInicial: numberOrNull(solicitacao.precoInicial),
    precoFinal: numberOrNull(solicitacao.precoFinal),
    cancelamentoMotivo:
      user !== undefined && podeVerMotivoCancelamento(solicitacao, user)
        ? solicitacao.cancelamentoMotivo
        : null,
    conclusaoContestacaoMotivo: solicitacao.conclusaoContestacaoMotivo,
    naoComparecimentoMotivo: solicitacao.naoComparecimentoMotivo,
    naoComparecimentoPorId: solicitacao.naoComparecimentoPorId,
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
      solicitacao.servicoSnapshot?.nomeCategoria != null
        ? { id: solicitacao.servicoSnapshot.categoriaId, nome: solicitacao.servicoSnapshot.nomeCategoria }
        : solicitacao.categoria === null
        ? null
        : {
            id: solicitacao.categoria.id,
            nome: solicitacao.categoria.nome,
          },
    criadoEm: solicitacao.criadoEm.toISOString(),
    atualizadoEm: solicitacao.atualizadoEm.toISOString(),
  };
}

function enderecoCompletoLiberado(
  solicitacao: SolicitacaoEntity,
  user?: AuthenticatedUser,
): boolean {
  if (solicitacao.enderecoId === null || user === undefined) return false;
  if (user.tipo === UsuarioTipo.Administrador) return true;
  if (user.tipo === UsuarioTipo.Cliente && solicitacao.clienteId === user.id) {
    return true;
  }
  if (
    [UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(user.tipo) &&
    solicitacao.profissional.usuarioId === user.id
  ) {
    if (!podeAtender(solicitacao.profissional)) return false;
    return [
      SolicitacaoStatus.AceitaAgendada,
      SolicitacaoStatus.ConclusaoPendente,
      SolicitacaoStatus.ConclusaoContestada,
      SolicitacaoStatus.NaoComparecimentoInformado,
      SolicitacaoStatus.ConclusaoConfirmada,
    ].includes(solicitacao.status);
  }

  return false;
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

function assertClienteParticipante(
  user: AuthenticatedUser,
  solicitacao: SolicitacaoEntity,
): void {
  if (user.tipo === UsuarioTipo.Cliente && solicitacao.clienteId === user.id) {
    return;
  }

  throw forbidden();
}

function parseCriarSolicitacao(body: unknown): CriarSolicitacaoInput {
  const value = objectBody(body);

  return {
    profissionalId: requiredId(value.profissionalId),
    categoriaId: optionalId(value.categoriaId),
    servicoId: optionalId(value.servicoId),
    enderecoId: optionalId(value.enderecoId),
    descricao: textField(value, 'descricao', 10, 600),
    bairroAtendimento: textField(value, 'bairroAtendimento', 2, 120),
    dataServico: dateField(value.dataServico),
    horarioServico: timeField(value.horarioServico),
    opcoesIds: parseOpcoesIds(value.opcoesIds, false),
    escopoEsperado: parseEscopoEsperado(value.escopoEsperado),
  };
}

function parseEscopoEsperado(value: unknown): EscopoServicoSnapshot | null {
  if (value === undefined || value === null) return null;
  const body = objectBody(value);
  function lista(campo: string): string[] {
    const items = body[campo];
    if (!Array.isArray(items) || items.length > 10 ||
      items.some((item) => typeof item !== 'string' || item.trim().length === 0 || item.length > 160)) {
      throw badRequest('ESCOPO_INVALIDO');
    }
    return items as string[];
  }
  return { inclui: lista('inclui'), naoInclui: lista('naoInclui'), opcionais: lista('opcionais') };
}

function ofertaAlterada(): ConflictException {
  return new ConflictException({ code: 'OFERTA_ALTERADA' });
}

function parseReagendamento(body: unknown) {
  const value = objectBody(body);
  return {
    dataServico: dateField(value.dataServico),
    horarioServico: timeField(value.horarioServico),
    motivo: textField(value, 'motivo', 10, 400),
  };
}

function parseRespostaReagendamento(body: unknown): boolean {
  const value = objectBody(body);
  if (typeof value.aceitar !== 'boolean') throw badRequest('RESPOSTA_INVALIDA');
  return value.aceitar;
}

function parseOrcamento(body: unknown) {
  const value = objectBody(body);
  const raw = value.valor;
  const texto =
    typeof raw === 'number'
      ? raw.toString()
      : typeof raw === 'string'
        ? raw.trim().replace(',', '.')
        : '';
  if (!/^\d{1,8}(\.\d{1,2})?$/.test(texto)) {
    throw badRequest('VALOR_ORCAMENTO_INVALIDO');
  }
  const numero = Number(texto);
  if (!Number.isFinite(numero) || numero <= 0 || numero > 99_999_999.99) {
    throw badRequest('VALOR_ORCAMENTO_INVALIDO');
  }
  return {
    valor: numero.toFixed(2),
    descricao: textField(value, 'descricao', 10, 600),
  };
}

function parseRespostaOrcamento(body: unknown): boolean {
  const value = objectBody(body);
  if (typeof value.aceitar !== 'boolean') {
    throw badRequest('RESPOSTA_ORCAMENTO_INVALIDA');
  }
  return value.aceitar;
}

function parsePropostaAntesAceite(body: unknown) {
  const value = objectBody(body);
  const temData = value.dataServico !== undefined && value.dataServico !== null;
  const temHorario = value.horarioServico !== undefined && value.horarioServico !== null;
  if (temData !== temHorario) throw badRequest('PROPOSTA_HORARIO_INCOMPLETO');
  if (value.escopo != null && typeof value.escopo !== 'string') {
    throw badRequest('PROPOSTA_ESCOPO_INVALIDO');
  }
  const escopo = typeof value.escopo === 'string' ? value.escopo.trim() : '';
  if (escopo !== '' && (escopo.length < 10 || escopo.length > 600)) {
    throw badRequest('PROPOSTA_ESCOPO_INVALIDO');
  }
  if (!temData && escopo === '') throw badRequest('PROPOSTA_VAZIA');
  return {
    dataServico: temData ? dateField(value.dataServico) : null,
    horarioServico: temHorario ? timeField(value.horarioServico) : null,
    escopo: escopo === '' ? null : escopo,
  };
}

function parseRespostaPropostaAntesAceite(body: unknown): boolean {
  const value = objectBody(body);
  if (typeof value.aceitar !== 'boolean') throw badRequest('RESPOSTA_PROPOSTA_INVALIDA');
  return value.aceitar;
}

function prazoPedidoEncerrado(solicitacao: SolicitacaoEntity, agora: Date): boolean {
  const prazo = solicitacao.prazoInatividadeEm ?? solicitacao.prazoRespostaEm;
  return (prazo != null && prazo <= agora) ||
    (solicitacao.prazoRespostaEm != null &&
      horarioIniciado(solicitacao.dataServico, solicitacao.horarioServico, agora));
}

function propostaPreAceiteResponse(item: SolicitacaoPropostaEntity) {
  return {
    id: item.id,
    propostoPorId: item.propostoPorId,
    dataServico: item.dataProposta,
    horarioServico: item.horarioProposto,
    escopo: item.escopoProposto,
    status: item.status,
    venceEm: item.venceEm.toISOString(),
    respondidoEm: item.respondidoEm?.toISOString() ?? null,
    criadoEm: item.criadoEm.toISOString(),
  };
}

interface PropostaAtendimentoRow {
  id: number; versao: number; proposto_por_id: number; valor: string;
  data_servico: string; horario_servico: string; duracao_minutos: number;
  status: string; respondido_por_id: number | null; respondido_em: Date | null;
  criado_em: Date; expira_em: Date | null;
}
interface PropostaOpcaoRow { proposta_id: number; opcao_id: number; nome_snapshot: string }

function propostaAtendimentoResponse(row: PropostaAtendimentoRow, itens: PropostaOpcaoRow[]) {
  const expiraEmCalculada = calcularExpiracaoProposta(row.criado_em, row.data_servico, row.horario_servico);
  const expiraEm = row.expira_em === null
    ? expiraEmCalculada
    : new Date(Math.min(row.expira_em.getTime(), expiraEmCalculada.getTime()));
  return {
    id: row.id, versao: row.versao, propostoPorId: row.proposto_por_id,
    valor: numberOrNull(row.valor), dataServico: row.data_servico, horarioServico: row.horario_servico,
    duracaoMinutos: row.duracao_minutos, status: row.status, respondidoPorId: row.respondido_por_id,
    respondidoEm: row.respondido_em?.toISOString() ?? null, criadoEm: row.criado_em.toISOString(),
    expiraEm: expiraEm.toISOString(),
    opcoes: itens.map((item) => ({ id: item.opcao_id, nome: item.nome_snapshot })),
  };
}

function parsePropostaAtendimento(body: unknown) {
  const value = objectBody(body);
  if (Object.keys(value).some((key) => !['opcoesIds', 'valor', 'dataServico', 'horarioServico', 'duracaoMinutos'].includes(key))) throw badRequest('CAMPO_INVALIDO');
  const raw = typeof value.valor === 'number' ? String(value.valor) : typeof value.valor === 'string' ? value.valor.trim().replace(',', '.') : '';
  if (!/^\d{1,8}(\.\d{1,2})?$/.test(raw) || Number(raw) <= 0 || Number(raw) > 99_999_999.99) throw badRequest('VALOR_ORCAMENTO_INVALIDO');
  if (typeof value.duracaoMinutos !== 'number' || !Number.isInteger(value.duracaoMinutos) || value.duracaoMinutos < 1 || value.duracaoMinutos > 1440) throw badRequest('DURACAO_INVALIDA');
  return { opcoesIds: parseOpcoesIds(value.opcoesIds, true), valor: Number(raw).toFixed(2),
    dataServico: dateField(value.dataServico), horarioServico: timeField(value.horarioServico), duracaoMinutos: value.duracaoMinutos };
}

function conflitoNegociacao(): ConflictException {
  return new ConflictException({ code: 'NEGOCIACAO_INDISPONIVEL', message: 'Este pedido nao aceita esta acao de negociacao.' });
}

function conflitoNegociacaoExpirada(): ConflictException {
  return new ConflictException({
    code: 'NEGOCIACAO_EXPIRADA',
    message: 'A negociação foi encerrada após 96 horas sem atividade.',
  });
}

function reagendamentoResponse(item: SolicitacaoReagendamentoEntity) {
  return {
    id: item.id,
    propostoPorId: item.propostoPorId,
    dataServico: item.dataProposta,
    horarioServico: item.horarioProposto,
    motivo: item.motivo,
    status: item.status,
    venceEm: item.venceEm?.toISOString() ?? null,
    respondidoEm: item.respondidoEm?.toISOString() ?? null,
    criadoEm: item.criadoEm.toISOString(),
  };
}

function orcamentoResponse(item: SolicitacaoOrcamentoEntity) {
  return {
    id: item.id,
    propostoPorId: item.propostoPorId,
    valor: numberOrNull(item.valor),
    descricao: item.descricao,
    status: item.status,
    venceEm: item.venceEm?.toISOString() ?? null,
    respondidoEm: item.respondidoEm?.toISOString() ?? null,
    criadoEm: item.criadoEm.toISOString(),
  };
}

function eventoResponse(item: SolicitacaoEventoEntity) {
  return {
    id: item.id,
    tipo: item.tipo,
    statusAnterior: item.statusAnterior,
    statusNovo: item.statusNovo,
    motivo: item.motivo,
    ator:
      item.ator === null
        ? null
        : { id: item.ator.id, nome: item.ator.nome, tipo: item.ator.tipo },
    criadoEm: item.criadoEm.toISOString(),
  };
}

function minutos(horario: string): number {
  const [hora = '0', minuto = '0'] = horario.split(':');
  return Number(hora) * 60 + Number(minuto);
}

export function intervalosConflitam(
  inicioA: number,
  fimA: number,
  inicioB: number,
  fimB: number,
): boolean {
  return inicioA < fimB && inicioB < fimA;
}

function objectBody(body: unknown): Record<string, unknown> {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw badRequest('CORPO_INVALIDO');
  }

  return body as Record<string, unknown>;
}

interface OpcaoAtiva { id: number; nome: string }

function parseOpcoesIds(value: unknown, obrigatorio: boolean): number[] {
  if (value === undefined && !obrigatorio) return [];
  if (!Array.isArray(value) || value.length < 1 || value.length > 30) throw badRequest('OPCOES_INVALIDAS');
  const ids = value.map((item) => requiredId(item));
  if (ids.some((id) => id > 4_294_967_295) || new Set(ids).size !== ids.length) throw badRequest('OPCOES_INVALIDAS');
  return ids.sort((a, b) => a - b);
}

async function carregarOpcoesAtivas(manager: EntityManager, servicoId: number, ids: readonly number[]): Promise<OpcaoAtiva[]> {
  if (ids.length === 0) throw badRequest('OPCOES_OBRIGATORIAS');
  const rows = await manager.query(
    `SELECT id, nome FROM servico_catalogo_opcoes WHERE servico_catalogo_id = ? AND ativo = 1 AND id IN (${ids.map(() => '?').join(',')}) ORDER BY id FOR UPDATE`,
    [servicoId, ...ids],
  ) as OpcaoAtiva[];
  if (rows.length !== ids.length) throw badRequest('OPCOES_INDISPONIVEIS');
  return rows;
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

function requiredId(value: unknown): number {
  const id = optionalId(value);
  if (id === null) {
    throw badRequest('ID_INVALIDO');
  }

  return id;
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

function dateField(value: unknown): string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw badRequest('DATA_INVALIDA');
  }

  const date = new Date(`${value}T00:00:00.000Z`);
  if (
    Number.isNaN(date.getTime()) ||
    date.toISOString().slice(0, 10) !== value
  ) {
    throw badRequest('DATA_INVALIDA');
  }

  return value;
}

function assertAgendamentoFuturo(
  dataServico: string,
  horarioServico: string,
): void {
  const agora = new Intl.DateTimeFormat('en-CA', {
    timeZone: fusoAgenda,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  })
    .formatToParts(new Date())
    .reduce<Record<string, string>>((partes, parte) => {
      partes[parte.type] = parte.value;
      return partes;
    }, {});
  const hoje = `${agora.year}-${agora.month}-${agora.day}`;
  const horarioAtual = `${agora.hour}:${agora.minute}`;
  if (
    dataServico < hoje ||
    (dataServico === hoje && horarioServico <= horarioAtual)
  ) {
    throw new BadRequestException({
      code: 'HORARIO_PASSADO',
      message: 'Escolha uma data e horario futuros para o atendimento.',
    });
  }
}

function agendamentoJaIniciou(solicitacao: SolicitacaoEntity): boolean {
  const agora = civilAgora();
  const dataHorario = `${solicitacao.dataServico}T${solicitacao.horarioServico}`;
  return dataHorario <= `${agora.data}T${agora.horario}`;
}

function exigirAgendamentoIniciado(solicitacao: SolicitacaoEntity): void {
  if (!agendamentoJaIniciou(solicitacao)) {
    throw new ConflictException({
      code: 'ATENDIMENTO_NAO_INICIADO',
      message: 'Esta acao fica disponivel a partir do horario do atendimento.',
    });
  }
}

function civilAgora(): { data: string; horario: string } {
  const partes = new Intl.DateTimeFormat('en-CA', {
    timeZone: fusoAgenda,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  })
    .formatToParts(new Date())
    .reduce<Record<string, string>>((resultado, parte) => {
      resultado[parte.type] = parte.value;
      return resultado;
    }, {});
  return {
    data: `${partes.year}-${partes.month}-${partes.day}`,
    horario: `${partes.hour}:${partes.minute}`,
  };
}

function snapshotEndereco(
  endereco: ClienteEnderecoEntity,
): EnderecoAtendimentoSnapshot {
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

function enderecoAtual(
  solicitacao: SolicitacaoEntity,
): EnderecoAtendimentoSnapshot | ReturnType<typeof enderecoResponse> | null {
  if (solicitacao.enderecoSnapshot != null)
    return solicitacao.enderecoSnapshot;
  return solicitacao.endereco === null
    ? null
    : enderecoResponse(solicitacao.endereco);
}

function podeVerMotivoCancelamento(
  solicitacao: SolicitacaoEntity,
  user: AuthenticatedUser,
): boolean {
  return (
    user.tipo === UsuarioTipo.Administrador ||
    solicitacao.clienteId === user.id ||
    solicitacao.profissional.usuarioId === user.id
  );
}

function timeField(value: unknown): string {
  if (typeof value !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) {
    throw badRequest('HORARIO_INVALIDO');
  }

  return value;
}

function numberOrNull(value: string | null | undefined): number | null {
  return value === null || value === undefined ? null : Number(value);
}

function forbidden(): ForbiddenException {
  return new ForbiddenException({
    code: 'ACESSO_NEGADO',
    message: 'Usuario sem permissao para este recurso.',
  });
}

function conflitoPedidoExpirado(): ConflictException {
  return new ConflictException({
    code: 'SOLICITACAO_EXPIRADA',
    message: 'O prazo para responder a esta solicitacao terminou.',
  });
}

function badRequest(code: string): BadRequestException {
  return new BadRequestException({
    code,
    message: 'Dados invalidos.',
  });
}
