import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { NotificacaoEntity } from '../database/entities/notificacao.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { NotificacoesController } from './notificacoes.controller.js';
import { NotificacoesService } from './notificacoes.service.js';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([NotificacaoEntity, UsuarioEntity]),
  ],
  controllers: [NotificacoesController],
  providers: [NotificacoesService],
  exports: [NotificacoesService],
})
export class NotificacoesModule {}
