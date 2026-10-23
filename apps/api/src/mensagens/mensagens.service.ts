import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { MensagemAtendimentoEntity } from '../database/entities/mensagem-atendimento.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
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

  async listar(user: AuthenticatedUser, solicitacaoId: number) {
    const solicitacao = await this.carregarSolicitacao(solicitacaoId);
    assertParticipante(user, solicitacao);

    const mensagens = await this.mensagens.find({
      where: { solicitacaoId },
      relations: { autor: true },
      order: { criadoEm: 'ASC' },
    });

    return { mensagens: mensagens.map(mensagemResponse) };
  }

  async enviar(user: AuthenticatedUser, solicitacaoId: number, body: unknown) {
    const solicitacao = await this.carregarSolicitacao(solicitacaoId);
    assertParticipanteOperacional(user, solicitacao);
    if (
      ![
        SolicitacaoStatus.AguardandoResposta,
        SolicitacaoStatus.AceitaAgendada,
        SolicitacaoStatus.ConclusaoPendente,
        SolicitacaoStatus.ConclusaoContestada,
        SolicitacaoStatus.NaoComparecimentoInformado,
      ].includes(solicitacao.status)
    ) {
      throw badRequest('CHAT_INDISPONIVEL');
    }

    const conteudo = parseConteudo(body);
    const mensagem = await this.mensagens.save(
      this.mensagens.create({
        solicitacaoId,
        autorId: user.id,
        conteudo,
      }),
    );

    const saved = await this.mensagens.findOne({
      where: { id: mensagem.id },
      relations: { autor: true },
    });
    if (saved === null) {
      throw new Error('Saved message could not be reloaded.');
    }

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
