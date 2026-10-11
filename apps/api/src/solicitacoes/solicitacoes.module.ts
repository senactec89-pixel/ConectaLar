import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { CategoriaEntity } from '../database/entities/categoria.entity.js';
import { AvaliacaoEntity } from '../database/entities/avaliacao.entity.js';
import { ProfissionalServicoEntity } from '../database/entities/profissional-servico.entity.js';
import { ClienteEnderecoEntity } from '../database/entities/cliente-endereco.entity.js';
import { ProfissionalDisponibilidadeEntity } from '../database/entities/profissional-disponibilidade.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { NotificacoesModule } from '../notificacoes/notificacoes.module.js';
import { SolicitacoesController } from './solicitacoes.controller.js';
import { SolicitacoesService } from './solicitacoes.service.js';

@Module({
  imports: [
    AuthModule,
    NotificacoesModule,
    TypeOrmModule.forFeature([
      CategoriaEntity,
      AvaliacaoEntity,
      ProfissionalServicoEntity,
      ClienteEnderecoEntity,
      ProfissionalDisponibilidadeEntity,
      ProfissionalPerfilEntity,
      SolicitacaoEntity,
      UsuarioEntity,
    ]),
  ],
  controllers: [SolicitacoesController],
  providers: [SolicitacoesService],
})
export class SolicitacoesModule {}
