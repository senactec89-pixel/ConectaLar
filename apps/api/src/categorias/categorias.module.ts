import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { CategoriaEntity } from '../database/entities/categoria.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { CategoriasController } from './categorias.controller.js';
import { CategoriasService } from './categorias.service.js';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([
      AdminAuditoriaEntity,
      CategoriaEntity,
      UsuarioEntity,
    ]),
  ],
  controllers: [CategoriasController],
  providers: [CategoriasService],
})
export class CategoriasModule {}
