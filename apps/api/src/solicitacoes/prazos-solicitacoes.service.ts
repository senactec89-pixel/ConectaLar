import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, LessThan, LessThanOrEqual, Not, Repository } from 'typeorm';
import { NotificacaoEntity } from '../database/entities/notificacao.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { SolicitacaoEventoEntity } from '../database/entities/solicitacao-evento.entity.js';
import {
  SolicitacaoPropostaEntity,
  SolicitacaoPropostaStatus,
} from '../database/entities/solicitacao-proposta.entity.js';
import { NotificacaoTipo } from '../domain/notificacao-tipo.js';
import { agoraCivil, horarioIniciado } from '../domain/agendamento.js';
import { SolicitacaoStatus } from '../domain/solicitacao-status.js';

@Injectable()
export class PrazosSolicitacoesService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrazosSolicitacoesService.name);
  private timer: NodeJS.Timeout | null = null;
  private executando = false;

  constructor(
    @InjectRepository(SolicitacaoEntity)
    private readonly solicitacoes: Repository<SolicitacaoEntity>,
    @InjectRepository(SolicitacaoPropostaEntity)
    private readonly propostas: Repository<SolicitacaoPropostaEntity>,
  ) {}

  onModuleInit(): void {
    // Repetições e múltiplas instâncias são seguras: cada mudança é validada
    // novamente sob lock no banco antes de gerar evento e notificação.
    this.timer = setInterval(() => {
      void this.processar().catch(() => this.logger.error('processamento_prazos_falhou'));
    }, 60_000);
    this.timer.unref();
    void this.processar().catch(() => this.logger.error('processamento_prazos_falhou'));
  }

  onModuleDestroy(): void {
    if (this.timer !== null) clearInterval(this.timer);
    this.timer = null;
  }

  async processar(): Promise<void> {
    if (this.executando) return;
    this.executando = true;
    try {
      const agora = new Date();
      const civil = agoraCivil(agora);
      const pedidos = await this.solicitacoes.find({
        where: [
          { status: SolicitacaoStatus.AguardandoResposta, prazoRespostaEm: LessThanOrEqual(agora) },
          { status: SolicitacaoStatus.AguardandoResposta, prazoInatividadeEm: LessThanOrEqual(agora) },
          { status: SolicitacaoStatus.AguardandoResposta, prazoRespostaEm: Not(IsNull()), dataServico: LessThan(civil.data) },
          { status: SolicitacaoStatus.AguardandoResposta, prazoRespostaEm: Not(IsNull()), dataServico: civil.data, horarioServico: LessThanOrEqual(civil.horario) },
        ],
        order: { id: 'ASC' },
        take: 100,
      });
      for (const pedido of pedidos) {
        try {
          await this.encerrarPedido(pedido);
        } catch {
          this.logger.error('encerramento_pedido_falhou');
        }
      }

      const propostas = await this.propostas.find({
        where: { status: SolicitacaoPropostaStatus.Pendente, venceEm: LessThanOrEqual(agora) },
        order: { id: 'ASC' },
        take: 100,
      });
      for (const proposta of propostas) {
        try {
          await this.expirarProposta(proposta);
        } catch {
          this.logger.error('expiracao_proposta_falhou');
        }
      }
    } finally {
      this.executando = false;
    }
  }

  private async encerrarPedido(candidato: SolicitacaoEntity): Promise<void> {
    await this.solicitacoes.manager.transaction('READ COMMITTED', async (manager) => {
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { id: candidato.profissionalId },
        lock: { mode: 'pessimistic_write' },
      });
      if (perfil === null) return;
      const pedido = await manager.findOne(SolicitacaoEntity, {
        where: { id: candidato.id },
        lock: { mode: 'pessimistic_write' },
      });
      if (pedido === null || pedido.status !== SolicitacaoStatus.AguardandoResposta) return;
      const prazo = pedido.prazoInatividadeEm ?? pedido.prazoRespostaEm;
      const agora = new Date();
      const horarioChegou = pedido.prazoRespostaEm !== null &&
        horarioIniciado(pedido.dataServico, pedido.horarioServico, agora);
      if (!horarioChegou && (prazo === null || prazo > agora)) return;
      const porInatividade = pedido.prazoInatividadeEm !== null;
      const motivo = horarioChegou
        ? 'O horário solicitado chegou sem resposta formal do profissional.'
        : porInatividade
          ? 'Negociação encerrada após 96 horas sem ação formal.'
          : 'Prazo de 48 horas sem resposta formal do profissional encerrado.';
      pedido.status = SolicitacaoStatus.Cancelada;
      pedido.cancelamentoMotivo = motivo;
      pedido.prazoRespostaEm = null;
      pedido.prazoInatividadeEm = null;
      await manager.save(SolicitacaoEntity, pedido);
      const pendentes = await manager.find(SolicitacaoPropostaEntity, {
        where: { solicitacaoId: pedido.id, status: SolicitacaoPropostaStatus.Pendente },
      });
      for (const proposta of pendentes) {
        proposta.status = SolicitacaoPropostaStatus.Expirada;
        await manager.save(SolicitacaoPropostaEntity, proposta);
      }
      await manager.save(SolicitacaoEventoEntity, manager.create(SolicitacaoEventoEntity, {
        solicitacaoId: pedido.id,
        atorId: null,
        tipo: horarioChegou ? 'pedido_expirado_horario' : porInatividade
          ? 'pedido_expirado_inatividade' : 'pedido_expirado_sem_resposta',
        statusAnterior: SolicitacaoStatus.AguardandoResposta,
        statusNovo: SolicitacaoStatus.Cancelada,
        motivo,
      }));
      await this.notificarNoManager(manager, pedido.clienteId, pedido.id,
        NotificacaoTipo.SolicitacaoCancelada,
        'Pedido encerrado', 'Seu pedido foi encerrado pelo prazo. Você pode criar outro pedido.');
      await this.notificarNoManager(manager, perfil.usuarioId, pedido.id,
        NotificacaoTipo.SolicitacaoCancelada,
        'Pedido encerrado', 'Um pedido foi encerrado pelo prazo de resposta.');
    });
  }

  private async expirarProposta(candidata: SolicitacaoPropostaEntity): Promise<void> {
    const pedido = await this.solicitacoes.findOne({ where: { id: candidata.solicitacaoId } });
    if (pedido === null) return;
    await this.solicitacoes.manager.transaction('READ COMMITTED', async (manager) => {
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { id: pedido.profissionalId },
        lock: { mode: 'pessimistic_write' },
      });
      if (perfil === null) return;
      const atual = await manager.findOne(SolicitacaoEntity, {
        where: { id: pedido.id },
        lock: { mode: 'pessimistic_write' },
      });
      const proposta = await manager.findOne(SolicitacaoPropostaEntity, {
        where: { id: candidata.id, solicitacaoId: pedido.id },
        lock: { mode: 'pessimistic_write' },
      });
      if (atual === null || proposta === null ||
          proposta.status !== SolicitacaoPropostaStatus.Pendente ||
          proposta.venceEm > new Date()) return;
      proposta.status = atual.status === SolicitacaoStatus.AguardandoResposta
        ? SolicitacaoPropostaStatus.Expirada
        : SolicitacaoPropostaStatus.Substituida;
      await manager.save(SolicitacaoPropostaEntity, proposta);
      if (atual.status !== SolicitacaoStatus.AguardandoResposta) return;
      await manager.save(SolicitacaoEventoEntity, manager.create(SolicitacaoEventoEntity, {
        solicitacaoId: atual.id,
        atorId: null,
        tipo: 'proposta_pre_aceite_expirada',
        statusAnterior: atual.status,
        statusNovo: atual.status,
        motivo: 'O prazo de 48 horas para responder à proposta terminou.',
      }));
      await this.notificarNoManager(manager, atual.clienteId, atual.id,
        NotificacaoTipo.PropostaPreAceiteExpirada,
        'Proposta expirada', 'O prazo para responder à proposta terminou. O pedido ainda está aberto.');
      await this.notificarNoManager(manager, perfil.usuarioId, atual.id,
        NotificacaoTipo.PropostaPreAceiteExpirada,
        'Proposta expirada', 'Sua proposta expirou sem resposta. O pedido ainda está aberto.');
    });
  }

  private async notificarNoManager(
    manager: Repository<SolicitacaoEntity>['manager'],
    usuarioId: number,
    solicitacaoId: number,
    tipo: NotificacaoTipo,
    titulo: string,
    mensagem: string,
  ): Promise<void> {
    await manager.save(NotificacaoEntity, manager.create(NotificacaoEntity, {
      usuarioId,
      tipo,
      titulo,
      mensagem,
      recursoTipo: 'solicitacao',
      recursoId: solicitacaoId,
      lida: false,
    }));
  }
}
