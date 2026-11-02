import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, LessThanOrEqual, Repository } from 'typeorm';
import { AvaliacaoFotoEntity } from '../database/entities/avaliacao-foto.entity.js';
import { AvaliacaoFotoStorageService } from './avaliacao-foto-storage.service.js';

const intervaloMs = 60 * 60 * 1000;

@Injectable()
export class AvaliacaoFotoCleanupService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(AvaliacaoFotoCleanupService.name);
  private timer: NodeJS.Timeout | null = null;

  constructor(
    @InjectRepository(AvaliacaoFotoEntity)
    private readonly fotos: Repository<AvaliacaoFotoEntity>,
    private readonly storage: AvaliacaoFotoStorageService,
  ) {}

  onModuleInit(): void {
    void this.limparExpiradas();
    this.timer = setInterval(() => void this.limparExpiradas(), intervaloMs);
    this.timer.unref();
  }

  onModuleDestroy(): void {
    if (this.timer !== null) clearInterval(this.timer);
  }

  async limparExpiradas(agora = new Date()): Promise<number> {
    let candidatas: Pick<AvaliacaoFotoEntity, 'id'>[];
    try {
      candidatas = await this.fotos.find({
        select: { id: true },
        where: { avaliacaoId: IsNull(), expiraEm: LessThanOrEqual(agora) },
        order: { expiraEm: 'ASC', id: 'ASC' },
        take: 100,
      });
    } catch {
      this.logger.warn('Nao foi possivel localizar uploads expirados de avaliacao.');
      return 0;
    }
    let removidas = 0;

    for (const candidata of candidatas) {
      try {
        const removeu = await this.fotos.manager.transaction(async (manager) => {
          const repository = manager.getRepository(AvaliacaoFotoEntity);
          const foto = await repository.findOne({
            where: {
              id: candidata.id,
              avaliacaoId: IsNull(),
              expiraEm: LessThanOrEqual(agora),
            },
            lock: { mode: 'pessimistic_write' },
          });
          if (foto === null) return false;
          await this.storage.remover(foto.referenciaArquivo);
          await repository.delete({ id: foto.id });
          return true;
        });
        if (removeu) removidas++;
      } catch {
        this.logger.warn(`Nao foi possivel limpar upload de avaliacao ${candidata.id}.`);
      }
    }

    return removidas;
  }
}
