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
import { CategoriaEntity } from '../database/entities/categoria.entity.js';
import { AvaliacaoEntity } from '../database/entities/avaliacao.entity.js';
import { ProfissionalServicoEntity } from '../database/entities/profissional-servico.entity.js';
import { ClienteEnderecoEntity } from '../database/entities/cliente-endereco.entity.js';
import { ProfissionalDisponibilidadeEntity } from '../database/entities/profissional-disponibilidade.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { EnderecoAtendimentoSnapshot, SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { SolicitacaoEventoEntity } from '../database/entities/solicitacao-evento.entity.js';
import { ProfissionalBloqueioEntity } from '../database/entities/profissional-bloqueio.entity.js';
import {
  ReagendamentoStatus,
  SolicitacaoReagendamentoEntity,
} from '../database/entities/solicitacao-reagendamento.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { horarioDisponivel } from '../disponibilidade/disponibilidade.service.js';
import { diaAnterior, duracaoLegadaMinutos, fusoAgenda, periodosSobrepostos } from '../domain/agendamento.js';
import { NotificacaoTipo } from '../domain/notificacao-tipo.js';
import { SolicitacaoStatus } from '../domain/solicitacao-status.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { NotificacoesService } from '../notificacoes/notificacoes.service.js';
import { exigirHabilitacao, podeAtender } from '../verificacao/habilitacao-profissional.js';

interface CriarSolicitacaoInput {
  readonly profissionalId: number;
  readonly categoriaId: number | null;
  readonly servicoId: number | null;
  readonly enderecoId: number | null;
  readonly descricao: string;
  readonly bairroAtendimento: string;
  readonly dataServico: string;
  readonly horarioServico: string;
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
    @InjectRepository(ProfissionalBloqueioEntity)
    private readonly bloqueios: Repository<ProfissionalBloqueioEntity>,
    @InjectRepository(UsuarioEntity)
    private readonly usuarios: Repository<UsuarioEntity>,
    private readonly notificacoes: NotificacoesService,
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

    const oferta =
      input.servicoId === null
        ? null
        : await this.ofertas.findOne({
            where: {
              id: input.servicoId,
              profissionalId: profissional.id,
              ativo: true,
            },
          });
    if (input.servicoId !== null && oferta === null) {
      throw badRequest('OFERTA_INDISPONIVEL');
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
      oferta?.intervaloMinutos ?? 30,
    );

    const solicitacao = this.solicitacoes.create({
      clienteId: cliente.id,
      profissionalId: profissional.id,
      categoriaId,
      servicoId: oferta?.id ?? null,
      nomeServico: oferta?.nome ?? null,
      enderecoId: input.enderecoId,
      enderecoSnapshot,
      descricao: input.descricao,
      bairroAtendimento: input.bairroAtendimento,
      dataServico: input.dataServico,
      horarioServico: input.horarioServico,
      duracaoMinutos,
      intervaloMinutos: oferta?.intervaloMinutos ?? 30,
      precoInicial: oferta === null ? profissional.precoInicial : oferta.precoInicial,
      status: SolicitacaoStatus.AguardandoResposta,
    });

    const saved = await this.solicitacoes.manager.transaction(async (manager) => {
      const criada = await manager.save(SolicitacaoEntity, solicitacao);
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

  async minhas(user: AuthenticatedUser) {
    const builder = this.solicitacoes
      .createQueryBuilder('solicitacao')
      .leftJoinAndSelect('solicitacao.cliente', 'cliente')
      .leftJoinAndSelect('solicitacao.profissional', 'profissional')
      .leftJoinAndSelect('profissional.usuario', 'profissionalUsuario')
      .leftJoinAndSelect('solicitacao.categoria', 'categoria')
      .leftJoinAndSelect('solicitacao.endereco', 'endereco')
      .orderBy('solicitacao.criadoEm', 'DESC');

    if (user.tipo === UsuarioTipo.Cliente) {
      builder.where('solicitacao.cliente_id = :userId', { userId: user.id });
    } else if (
      [UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(user.tipo)
    ) {
      builder.where('profissional.usuario_id = :userId', { userId: user.id });
    } else if (user.tipo !== UsuarioTipo.Administrador) {
      throw forbidden();
    }

    const solicitacoes = await builder.getMany();
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
    return {
      solicitacoes: solicitacoes.map((solicitacao) =>
        solicitacaoResponse(
          solicitacao,
          user,
          idsAvaliados.has(solicitacao.id),
        ),
      ),
    };
  }

  async obter(user: AuthenticatedUser, id: number) {
    const solicitacao = await this.carregar(id);
    assertParticipante(user, solicitacao);
    return this.responder(solicitacao, user);
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
      'solicitacao_cancelada',
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
    assertProfissionalParticipante(user, solicitacao);
    if (solicitacao.status !== SolicitacaoStatus.AceitaAgendada) {
      throw new ConflictException({
        code: 'REAGENDAMENTO_INDISPONIVEL',
        message: 'Somente atendimentos aceitos podem ser reagendados.',
      });
    }
    await this.validarDisponibilidade(
      solicitacao.profissionalId,
      input.dataServico,
      input.horarioServico,
      solicitacao.duracaoMinutos,
      solicitacao.intervaloMinutos,
      solicitacao.id,
    );
    await this.reagendamentos.update(
      { solicitacaoId: id, status: ReagendamentoStatus.Pendente },
      { status: ReagendamentoStatus.Cancelado, respondidoEm: new Date() },
    );
    await this.reagendamentos.save(
      this.reagendamentos.create({
        solicitacaoId: id,
        dataProposta: input.dataServico,
        horarioProposto: input.horarioServico,
        motivo: input.motivo,
        status: ReagendamentoStatus.Pendente,
        respondidoEm: null,
      }),
    );
    await this.notificarSeguro({
      usuarioId: solicitacao.clienteId,
      tipo: NotificacaoTipo.ReagendamentoProposto,
      titulo: 'Nova proposta de reagendamento',
      mensagem: 'O profissional propôs uma nova data para o atendimento.',
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
    assertClienteParticipante(user, solicitacao);
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
      if (aceitar) {
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
    });
    await this.notificarSeguro({
      usuarioId: solicitacao.profissional.usuarioId,
      tipo: NotificacaoTipo.ReagendamentoRespondido,
      titulo: aceitar ? 'Reagendamento confirmado' : 'Reagendamento recusado',
      mensagem: aceitar
        ? 'O cliente confirmou a nova data do atendimento.'
        : 'O cliente recusou a proposta. Converse para combinar outra opção.',
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
    eventoTipo: string,
    motivo: string | null = null,
    atualizar?: (solicitacao: SolicitacaoEntity) => void,
  ) {
    await this.solicitacoes.manager.transaction(
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
        if (destino === SolicitacaoStatus.AceitaAgendada) {
          exigirHabilitacao(perfil);
          if (perfil === null || !perfil.ativo)
            throw badRequest('PROFISSIONAL_INDISPONIVEL');
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
        atual.status = destino;
        atualizar?.(atual);
        await manager.save(SolicitacaoEntity, atual);
        await manager.save(
          SolicitacaoEventoEntity,
          manager.create(SolicitacaoEventoEntity, {
            solicitacaoId: atual.id,
            atorId: user.id,
            tipo: eventoTipo,
            statusAnterior,
            statusNovo: destino,
            motivo,
          }),
        );
      },
    );
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
    const eventos = await this.solicitacoes.manager.getRepository(SolicitacaoEventoEntity).find({
      where: { solicitacaoId: solicitacao.id },
      relations: { ator: true },
      order: { criadoEm: 'DESC' },
      take: 100,
    });
    return {
      solicitacao: {
        ...solicitacaoResponse(solicitacao, user, avaliado),
        reagendamento: reagendamentos[0] === undefined
          ? null
          : reagendamentoResponse(reagendamentos[0]),
        reagendamentos: reagendamentos.map(reagendamentoResponse),
        eventos: eventos.map(eventoResponse),
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
    avaliado,
    status: solicitacao.status,
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
  };
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

function reagendamentoResponse(item: SolicitacaoReagendamentoEntity) {
  return {
    id: item.id,
    dataServico: item.dataProposta,
    horarioServico: item.horarioProposto,
    motivo: item.motivo,
    status: item.status,
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

function numberOrNull(value: string | null): number | null {
  return value === null ? null : Number(value);
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
