import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { AvaliacaoEntity } from '../database/entities/avaliacao.entity.js';
import { CategoriaEntity } from '../database/entities/categoria.entity.js';
import { ProfissionalDisponibilidadeEntity } from '../database/entities/profissional-disponibilidade.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { ProfissionalServicoEntity } from '../database/entities/profissional-servico.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { LocalizacaoModule } from '../localizacao/localizacao.module.js';
import { ProfissionaisController } from './profissionais.controller.js';
import { ProfissionaisService } from './profissionais.service.js';

@Module({
  imports: [
    AuthModule,
    LocalizacaoModule,
    TypeOrmModule.forFeature([
      CategoriaEntity,
      AvaliacaoEntity,
      ProfissionalDisponibilidadeEntity,
      ProfissionalPerfilEntity,
      ProfissionalServicoEntity,
      SolicitacaoEntity,
      UsuarioEntity,
    ]),
  ],
  controllers: [ProfissionaisController],
  providers: [ProfissionaisService],
})
export class ProfissionaisModule {}
