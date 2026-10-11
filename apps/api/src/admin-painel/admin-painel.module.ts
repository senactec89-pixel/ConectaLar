import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { AvaliacaoEntity } from '../database/entities/avaliacao.entity.js';
import { CategoriaEntity } from '../database/entities/categoria.entity.js';
import { DenunciaEntity } from '../database/entities/denuncia.entity.js';
import { ProfissionalDocumentoVerificacaoEntity } from '../database/entities/profissional-documento-verificacao.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { AdminPainelController } from './admin-painel.controller.js';
import { AdminPainelService } from './admin-painel.service.js';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([
      AvaliacaoEntity,
      AdminAuditoriaEntity,
      CategoriaEntity,
      DenunciaEntity,
      ProfissionalDocumentoVerificacaoEntity,
      ProfissionalPerfilEntity,
      SolicitacaoEntity,
      UsuarioEntity,
    ]),
  ],
  controllers: [AdminPainelController],
  providers: [AdminPainelService],
})
export class AdminPainelModule {}
