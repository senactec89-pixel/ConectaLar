import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { AvaliacaoEntity } from '../database/entities/avaliacao.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { NotificacoesModule } from '../notificacoes/notificacoes.module.js';
import { AvaliacoesController } from './avaliacoes.controller.js';
import { AvaliacoesService } from './avaliacoes.service.js';

@Module({
  imports: [
    AuthModule,
    NotificacoesModule,
    TypeOrmModule.forFeature([
      AdminAuditoriaEntity,
      AvaliacaoEntity,
      SolicitacaoEntity,
    ]),
  ],
  controllers: [AvaliacoesController],
  providers: [AvaliacoesService],
})
export class AvaliacoesModule {}
