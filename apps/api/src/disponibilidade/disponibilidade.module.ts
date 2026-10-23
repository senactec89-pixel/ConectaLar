import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { ProfissionalDisponibilidadeEntity } from '../database/entities/profissional-disponibilidade.entity.js';
import { ProfissionalBloqueioEntity } from '../database/entities/profissional-bloqueio.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { DisponibilidadeController } from './disponibilidade.controller.js';
import { DisponibilidadeService } from './disponibilidade.service.js';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([
      ProfissionalDisponibilidadeEntity,
      ProfissionalBloqueioEntity,
      ProfissionalPerfilEntity,
      SolicitacaoEntity,
    ]),
  ],
  controllers: [DisponibilidadeController],
  providers: [DisponibilidadeService],
})
export class DisponibilidadeModule {}
