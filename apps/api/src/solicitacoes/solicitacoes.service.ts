import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { CategoriaEntity } from '../database/entities/categoria.entity.js';
import { AvaliacaoEntity } from '../database/entities/avaliacao.entity.js';
import { ProfissionalServicoEntity } from '../database/entities/profissional-servico.entity.js';
import { ClienteEnderecoEntity } from '../database/entities/cliente-endereco.entity.js';
import { ProfissionalDisponibilidadeEntity } from '../database/entities/profissional-disponibilidade.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { horarioDisponivel } from '../disponibilidade/disponibilidade.service.js';
import { NotificacaoTipo } from '../domain/notificacao-tipo.js';
import { SolicitacaoStatus } from '../domain/solicitacao-status.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { NotificacoesService } from '../notificacoes/notificacoes.service.js';

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
    @InjectRepository(UsuarioEntity)
    private readonly usuarios: Repository<UsuarioEntity>,
    private readonly notificacoes: NotificacoesService,
  ) {}

  async criar(user: AuthenticatedUser, body: unknown) {
    const input = parseCriarSolicitacao(body);
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

    if (input.enderecoId !== null) {
      const endereco = await this.enderecos.findOne({
        where: { id: input.enderecoId, usuarioId: cliente.id, ativo: true },
      });
      if (endereco === null) {
        throw badRequest('ENDERECO_INVALIDO');
      }
    }

    await this.validarDisponibilidade(
      profissional.id,
      input.dataServico,
      input.horarioServico,
    );

    const solicitacao = this.solicitacoes.create({
      clienteId: cliente.id,
      profissionalId: profissional.id,
      categoriaId,
      servicoId: oferta?.id ?? null,
      nomeServico: oferta?.nome ?? null,
      enderecoId: input.enderecoId,
      descricao: input.descricao,
      bairroAtendimento: input.bairroAtendimento,
      dataServico: input.dataServico,
      horarioServico: input.horarioServico,
      precoInicial: oferta === null ? profissional.precoInicial : oferta.precoInicial,
      status: SolicitacaoStatus.AguardandoResposta,
    });

    const saved = await this.solicitacoes.save(solicitacao);
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

  async cancelar(user: AuthenticatedUser, id: number) {
    const solicitacao = await this.carregar(id);
    assertClienteParticipante(user, solicitacao);
    const response = await this.transicionar(
      solicitacao,
      [SolicitacaoStatus.AguardandoResposta, SolicitacaoStatus.AceitaAgendada],
      SolicitacaoStatus.Cancelada,
      user,
    );
    await this.notificarSeguro({
      usuarioId: solicitacao.profissional.usuarioId,
      tipo: NotificacaoTipo.SolicitacaoCancelada,
      titulo: 'Solicitacao cancelada',
      mensagem: 'O cliente cancelou uma solicitacao de atendimento.',
      recursoTipo: 'solicitacao',
      recursoId: solicitacao.id,
    });
    return response;
  }

  async concluir(user: AuthenticatedUser, id: number) {
    const solicitacao = await this.carregar(id);
    assertClienteParticipante(user, solicitacao);
    const response = await this.transicionar(
      solicitacao,
      SolicitacaoStatus.AceitaAgendada,
      SolicitacaoStatus.ConclusaoConfirmada,
      user,
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

  private async transicionar(
    solicitacao: SolicitacaoEntity,
    origem: SolicitacaoStatus | readonly SolicitacaoStatus[],
    destino: SolicitacaoStatus,
    user: AuthenticatedUser,
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
          if (perfil === null || !perfil.ativo)
            throw badRequest('PROFISSIONAL_INDISPONIVEL');
          const disponibilidade = await manager.find(
            ProfissionalDisponibilidadeEntity,
            {
              where: { profissionalId: perfil.id, ativo: true },
            },
          );
          if (
            !horarioDisponivel(
              disponibilidade,
              atual.dataServico,
              atual.horarioServico,
            )
          ) {
            throw new ConflictException({
              code: 'HORARIO_INDISPONIVEL',
              message: 'Horário fora da disponibilidade.',
            });
          }
          const ocupados = await manager.count(SolicitacaoEntity, {
            where: {
              profissionalId: perfil.id,
              dataServico: atual.dataServico,
              horarioServico: atual.horarioServico,
              status: SolicitacaoStatus.AceitaAgendada,
            },
          });
          if (ocupados > 0) {
            throw new ConflictException({
              code: 'HORARIO_OCUPADO',
              message: 'Já existe atendimento neste horário.',
            });
          }
        }
        atual.status = destino;
        await manager.save(SolicitacaoEntity, atual);
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
    return { solicitacao: solicitacaoResponse(solicitacao, user, avaliado) };
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
  ): Promise<void> {
    const disponibilidades = await this.disponibilidades.find({
      where: { profissionalId, ativo: true },
    });
    if (disponibilidades.length === 0) {
      throw badRequest('DISPONIBILIDADE_NAO_CADASTRADA');
    }
    if (!horarioDisponivel(disponibilidades, dataServico, horarioServico)) {
      throw badRequest('HORARIO_INDISPONIVEL');
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
      enderecoLiberado && solicitacao.endereco !== null
        ? enderecoResponse(solicitacao.endereco)
        : null,
    dataServico: solicitacao.dataServico,
    horarioServico: solicitacao.horarioServico,
    precoInicial: numberOrNull(solicitacao.precoInicial),
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
    return [
      SolicitacaoStatus.AceitaAgendada,
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
