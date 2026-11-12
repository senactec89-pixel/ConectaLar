import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { AvaliacaoEntity } from '../database/entities/avaliacao.entity.js';
import { AvaliacaoFotoEntity } from '../database/entities/avaliacao-foto.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { NotificacoesModule } from '../notificacoes/notificacoes.module.js';
import { MalwareScannerService } from '../verificacao/malware-scanner.service.js';
import { AvaliacaoFotoCleanupService } from './avaliacao-foto-cleanup.service.js';
import { AvaliacaoFotoStorageService } from './avaliacao-foto-storage.service.js';
import {
  AvaliacaoFotoPublicController,
  AvaliacoesController,
  OptionalAuthGuard,
} from './avaliacoes.controller.js';
import { AvaliacoesService } from './avaliacoes.service.js';

@Module({
  imports: [
    AuthModule,
    NotificacoesModule,
    TypeOrmModule.forFeature([
      AdminAuditoriaEntity,
      AvaliacaoEntity,
      AvaliacaoFotoEntity,
      SolicitacaoEntity,
    ]),
  ],
  controllers: [AvaliacoesController, AvaliacaoFotoPublicController],
  providers: [
    AvaliacoesService,
    AvaliacaoFotoStorageService,
    AvaliacaoFotoCleanupService,
    MalwareScannerService,
    OptionalAuthGuard,
  ],
})
export class AvaliacoesModule {}
