import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { SolicitacoesService } from './solicitacoes.service.js';

const intervaloMs = 60_000;

@Injectable()
export class PropostaAtendimentoCleanupService implements OnModuleInit, OnModuleDestroy {
  private timer: NodeJS.Timeout | null = null;
  private processando = false;

  constructor(private readonly solicitacoes: SolicitacoesService) {}

  onModuleInit(): void {
    void this.processarVencidas();
    this.timer = setInterval(() => void this.processarVencidas(), intervaloMs);
    this.timer.unref();
  }

  onModuleDestroy(): void {
    if (this.timer !== null) clearInterval(this.timer);
  }

  async processarVencidas(agora = new Date()): Promise<number> {
    if (this.processando) return 0;
    this.processando = true;
    try {
      return await this.solicitacoes.expirarPropostasVencidas(agora);
    } finally {
      this.processando = false;
    }
  }
}
