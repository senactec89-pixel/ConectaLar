import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { AdminConviteEntity } from '../database/entities/admin-convite.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { AdminUsuariosController } from './admin-usuarios.controller.js';
import { AdminUsuariosService } from './admin-usuarios.service.js';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([AdminAuditoriaEntity, AdminConviteEntity, UsuarioEntity]),
  ],
  controllers: [AdminUsuariosController],
  providers: [AdminUsuariosService],
})
export class AdminUsuariosModule {}
