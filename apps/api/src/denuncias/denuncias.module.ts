import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { DenunciaEntity } from '../database/entities/denuncia.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { NotificacoesModule } from '../notificacoes/notificacoes.module.js';
import { DenunciasController } from './denuncias.controller.js';
import { DenunciasService } from './denuncias.service.js';

@Module({
  imports: [
    AuthModule,
    NotificacoesModule,
    TypeOrmModule.forFeature([
      AdminAuditoriaEntity,
      DenunciaEntity,
      SolicitacaoEntity,
    ]),
  ],
  controllers: [DenunciasController],
  providers: [DenunciasService],
})
export class DenunciasModule {}
