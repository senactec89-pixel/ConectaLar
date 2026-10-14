import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { ProfissionalDocumentoVerificacaoEntity } from '../database/entities/profissional-documento-verificacao.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { NotificacoesModule } from '../notificacoes/notificacoes.module.js';
import { MalwareScannerService } from './malware-scanner.service.js';
import { VerificacaoController } from './verificacao.controller.js';
import { VerificacaoService } from './verificacao.service.js';

@Module({
  imports: [
    AuthModule,
    NotificacoesModule,
    TypeOrmModule.forFeature([
      AdminAuditoriaEntity,
      ProfissionalDocumentoVerificacaoEntity,
      ProfissionalPerfilEntity,
    ]),
  ],
  controllers: [VerificacaoController],
  providers: [MalwareScannerService, VerificacaoService],
})
export class VerificacaoModule {}
