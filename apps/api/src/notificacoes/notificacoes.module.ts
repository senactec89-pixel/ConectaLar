import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { NotificacaoEntity } from '../database/entities/notificacao.entity.js';
import { DispositivoPushEntity } from '../database/entities/dispositivo-push.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { NotificacoesController } from './notificacoes.controller.js';
import { NotificacoesService } from './notificacoes.service.js';
import {
  criarMessagingFcm,
  PUSH_MESSAGING,
  PushNotificacoesService,
} from './push-notificacoes.service.js';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([
      NotificacaoEntity,
      DispositivoPushEntity,
      UsuarioEntity,
    ]),
  ],
  controllers: [NotificacoesController],
  providers: [
    { provide: PUSH_MESSAGING, useFactory: criarMessagingFcm },
    PushNotificacoesService,
    NotificacoesService,
  ],
  exports: [NotificacoesService, PushNotificacoesService],
})
export class NotificacoesModule {}
