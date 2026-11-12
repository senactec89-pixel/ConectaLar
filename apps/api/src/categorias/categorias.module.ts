import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { CategoriaEntity } from '../database/entities/categoria.entity.js';
import { ServicoCatalogoEntity } from '../database/entities/servico-catalogo.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { CategoriasController } from './categorias.controller.js';
import { CategoriasService } from './categorias.service.js';
import { ServicosCatalogoController, ServicosCatalogoPublicoController } from './servicos-catalogo.controller.js';
import { ServicosCatalogoService } from './servicos-catalogo.service.js';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([
      AdminAuditoriaEntity,
      CategoriaEntity,
      ServicoCatalogoEntity,
      UsuarioEntity,
    ]),
  ],
  controllers: [CategoriasController, ServicosCatalogoController, ServicosCatalogoPublicoController],
  providers: [CategoriasService, ServicosCatalogoService],
})
export class CategoriasModule {}
