import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { ClienteEnderecoEntity } from '../database/entities/cliente-endereco.entity.js';
import { ClientePerfilEntity } from '../database/entities/cliente-perfil.entity.js';
import { FavoritoProfissionalEntity } from '../database/entities/favorito-profissional.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { LocalizacaoModule } from '../localizacao/localizacao.module.js';
import { ClientesController } from './clientes.controller.js';
import { ClientesService } from './clientes.service.js';

@Module({
  imports: [
    AuthModule,
    LocalizacaoModule,
    TypeOrmModule.forFeature([
      ClienteEnderecoEntity,
      ClientePerfilEntity,
      FavoritoProfissionalEntity,
      ProfissionalPerfilEntity,
      UsuarioEntity,
    ]),
  ],
  controllers: [ClientesController],
  providers: [ClientesService],
})
export class ClientesModule {}
