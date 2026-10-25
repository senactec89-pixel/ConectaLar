import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { ProfissionalDocumentoVerificacaoEntity } from '../database/entities/profissional-documento-verificacao.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { NotificacoesModule } from '../notificacoes/notificacoes.module.js';
import { DocumentoStorageService } from './documento-storage.service.js';
import { MalwareScannerService } from './malware-scanner.service.js';
import { VerificacaoController } from './verificacao.controller.js';
import { VerificacaoService } from './verificacao.service.js';
import { HabilitacaoController } from './habilitacao.controller.js';
import { HabilitacaoService } from './habilitacao.service.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { ProfissionalIdentidadeVerificacaoEntity } from '../database/entities/profissional-identidade-verificacao.entity.js';
import { ProfissionalTelefoneVerificacaoEntity } from '../database/entities/profissional-telefone-verificacao.entity.js';
import { IdZapSignProvider } from './id-zapsign.provider.js';

@Module({
  imports: [
    AuthModule,
    NotificacoesModule,
    TypeOrmModule.forFeature([
      AdminAuditoriaEntity,
      ProfissionalDocumentoVerificacaoEntity,
      ProfissionalPerfilEntity,
      UsuarioEntity,
      ProfissionalIdentidadeVerificacaoEntity,
      ProfissionalTelefoneVerificacaoEntity,
    ]),
  ],
  controllers: [VerificacaoController, HabilitacaoController],
  providers: [DocumentoStorageService, MalwareScannerService, VerificacaoService, HabilitacaoService, IdZapSignProvider],
})
export class VerificacaoModule {}
