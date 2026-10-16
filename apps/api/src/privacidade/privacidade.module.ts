import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { PrivacidadeSolicitacaoEntity } from '../database/entities/privacidade-solicitacao.entity.js';
import { DocumentoStorageService } from '../verificacao/documento-storage.service.js';
import { PrivacidadeController } from './privacidade.controller.js';
import { PrivacidadeService } from './privacidade.service.js';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([PrivacidadeSolicitacaoEntity]),
  ],
  controllers: [PrivacidadeController],
  providers: [PrivacidadeService, DocumentoStorageService],
})
export class PrivacidadeModule {}
