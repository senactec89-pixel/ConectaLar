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
import {
  paginationMetadata,
  parsePaginationQuery,
} from '../common/pagination.js';
import { MensagemAtendimentoEntity } from '../database/entities/mensagem-atendimento.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { expirarPedidoSemResposta } from '../solicitacoes/pedido-prazo.js';
import { calcularExpiracaoNegociacao, expirarNegociacaoInativa } from '../solicitacoes/negociacao-prazo.js';
import { NotificacaoTipo } from '../domain/notificacao-tipo.js';
import { SolicitacaoStatus } from '../domain/solicitacao-status.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { NotificacoesService } from '../notificacoes/notificacoes.service.js';

@Injectable()
export class MensagensService {
  constructor(
    @InjectRepository(MensagemAtendimentoEntity)
    private readonly mensagens: Repository<MensagemAtendimentoEntity>,
    @InjectRepository(SolicitacaoEntity)
    private readonly solicitacoes: Repository<SolicitacaoEntity>,
    private readonly notificacoes: NotificacoesService,
  ) {}

  async listar(
    user: AuthenticatedUser,
    solicitacaoId: number,
    query: Record<string, unknown> = {},
  ) {
    const solicitacao = await this.carregarSolicitacao(solicitacaoId);
    assertParticipante(user, solicitacao);
    const pagination = parsePaginationQuery(query);

    const [mensagens, total] = await this.mensagens.findAndCount({
      where: { solicitacaoId },
      relations: { autor: true },
      order: { criadoEm: 'DESC', id: 'DESC' },
      skip: pagination.skip,
      take: pagination.limite,
    });

    return {
      paginacao: paginationMetadata(pagination, total),
      mensagens: mensagens.reverse().map(mensagemResponse),
    };
  }

  async enviar(user: AuthenticatedUser, solicitacaoId: number, body: unknown) {
    const conteudo = parseConteudo(body);
    const resultado = await this.mensagens.manager.transaction('READ COMMITTED', async (manager) => {
      const solicitacao = await manager.findOne(SolicitacaoEntity, {
        where: { id: solicitacaoId },
        lock: { mode: 'pessimistic_write' },
      });
      if (solicitacao === null) throw new NotFoundException({
        code: 'SOLICITACAO_NAO_ENCONTRADA',
        message: 'Solicitacao nao encontrada.',
      });
      const profissional = await manager.findOne(ProfissionalPerfilEntity, {
        where: { id: solicitacao.profissionalId },
      });
      if (profissional === null) throw new NotFoundException({
        code: 'PROFISSIONAL_NAO_ENCONTRADO',
        message: 'Profissional nao encontrado.',
      });
      const participante =
        (user.tipo === UsuarioTipo.Cliente && solicitacao.clienteId === user.id) ||
        ([UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(user.tipo) && profissional.usuarioId === user.id);
      if (!participante) throw forbidden();
      if (![
        SolicitacaoStatus.AguardandoResposta,
        SolicitacaoStatus.AceitaAgendada,
        SolicitacaoStatus.ConclusaoPendente,
        SolicitacaoStatus.ConclusaoContestada,
        SolicitacaoStatus.NaoComparecimentoInformado,
      ].includes(solicitacao.status)) throw badRequest('CHAT_INDISPONIVEL');

      let negociacaoIniciada = false;
      if (solicitacao.status === SolicitacaoStatus.AguardandoResposta) {
        if (await expirarPedidoSemResposta(manager, solicitacao)) {
          return { expirou: true, negociacaoExpirada: false, mensagemId: null };
        }
        const rows = await manager.query(`SELECT
          EXISTS(SELECT 1 FROM solicitacao_opcoes WHERE solicitacao_id = ?) AS fluxo_novo,
          EXISTS(SELECT 1 FROM solicitacao_eventos WHERE solicitacao_id = ? AND tipo = 'negociacao_iniciada') AS iniciada`,
        [solicitacaoId, solicitacaoId]) as Array<{ fluxo_novo: number; iniciada: number }>;
        negociacaoIniciada = Number(rows[0]?.iniciada) === 1;
        if (Number(rows[0]?.fluxo_novo) === 1 && !negociacaoIniciada) throw badRequest('CHAT_AGUARDA_PROFISSIONAL');
        if (await expirarNegociacaoInativa(manager, solicitacao)) {
          return { expirou: false, negociacaoExpirada: true, mensagemId: null };
        }
      }

      const mensagem = await manager.save(MensagemAtendimentoEntity, manager.create(MensagemAtendimentoEntity, {
        solicitacaoId,
        autorId: user.id,
        conteudo,
      }));
      if (
        solicitacao.status === SolicitacaoStatus.AguardandoResposta &&
        (negociacaoIniciada || solicitacao.prazoInatividadeEm != null || user.tipo !== UsuarioTipo.Cliente)
      ) {
        solicitacao.prazoInatividadeEm = calcularExpiracaoNegociacao(new Date());
        await manager.save(SolicitacaoEntity, solicitacao);
      }
      return { expirou: false, negociacaoExpirada: false, mensagemId: mensagem.id };
    });
    if (resultado.expirou) throw new ConflictException({
      code: 'SOLICITACAO_EXPIRADA',
      message: 'O prazo para responder a esta solicitacao terminou.',
    });
    if (resultado.negociacaoExpirada) throw new ConflictException({
      code: 'NEGOCIACAO_EXPIRADA',
      message: 'A negociacao foi encerrada apos 96 horas sem atividade.',
    });

    const saved = await this.mensagens.findOne({
      where: { id: resultado.mensagemId! },
      relations: { autor: true },
    });
    if (saved === null) {
      throw new Error('Saved message could not be reloaded.');
    }
    const solicitacao = await this.carregarSolicitacao(solicitacaoId);

    const destinatarioId =
      user.id === solicitacao.clienteId
        ? solicitacao.profissional.usuarioId
        : solicitacao.clienteId;
    await this.notificarSeguro({
      usuarioId: destinatarioId,
      tipo: NotificacaoTipo.MensagemRecebida,
      titulo: 'Nova mensagem',
      mensagem: 'Voce recebeu uma nova mensagem no atendimento.',
      recursoTipo: 'solicitacao',
      recursoId: solicitacaoId,
    });

    return { mensagem: mensagemResponse(saved) };
  }

  private async carregarSolicitacao(id: number): Promise<SolicitacaoEntity> {
    const solicitacao = await this.solicitacoes.findOne({
      where: { id },
      relations: { cliente: true, profissional: { usuario: true } },
    });
    if (solicitacao === null) {
      throw new NotFoundException({
        code: 'SOLICITACAO_NAO_ENCONTRADA',
        message: 'Solicitacao nao encontrada.',
      });
    }

    return solicitacao;
  }

  private async notificarSeguro(input: Parameters<NotificacoesService['criar']>[0]) {
    try {
      await this.notificacoes.criar(input);
    } catch {
      // Falha de notificacao nao altera entrega da mensagem.
    }
  }
}

function mensagemResponse(mensagem: MensagemAtendimentoEntity) {
  return {
    id: mensagem.id,
    solicitacaoId: mensagem.solicitacaoId,
    autor: {
      id: mensagem.autor.id,
      nome: mensagem.autor.nome,
      tipo: mensagem.autor.tipo,
    },
    conteudo: mensagem.conteudo,
    criadoEm: mensagem.criadoEm.toISOString(),
  };
}

function assertParticipante(
  user: AuthenticatedUser,
  solicitacao: SolicitacaoEntity,
): void {
  if (user.tipo === UsuarioTipo.Administrador) {
    return;
  }
  assertParticipanteOperacional(user, solicitacao);
}

function assertParticipanteOperacional(
  user: AuthenticatedUser,
  solicitacao: SolicitacaoEntity,
): void {
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

function parseConteudo(body: unknown): string {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw badRequest('CORPO_INVALIDO');
  }

  const conteudo = (body as Record<string, unknown>).conteudo;
  if (typeof conteudo !== 'string') {
    throw badRequest('MENSAGEM_INVALIDA');
  }

  const text = conteudo.trim();
  if (text.length < 1 || text.length > 1000) {
    throw badRequest('MENSAGEM_INVALIDA');
  }

  return text;
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
