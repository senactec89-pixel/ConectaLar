import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AdminPainelModule } from './admin-painel/admin-painel.module.js';
import { AdminUsuariosModule } from './admin-usuarios/admin-usuarios.module.js';
import { AuthModule } from './auth/auth.module.js';
import { AvaliacoesModule } from './avaliacoes/avaliacoes.module.js';
import { CategoriasModule } from './categorias/categorias.module.js';
import { ClientesModule } from './clientes/clientes.module.js';
import {
  databaseRuntimeOptions,
  isAuthRuntimeConfigured,
} from './database/database.config.js';
import { DenunciasModule } from './denuncias/denuncias.module.js';
import { DisponibilidadeModule } from './disponibilidade/disponibilidade.module.js';
import { HistoricoModule } from './historico/historico.module.js';
import { MensagensModule } from './mensagens/mensagens.module.js';
import { NotificacoesModule } from './notificacoes/notificacoes.module.js';
import { HealthController } from './health/health.controller.js';
import { ProfissionaisModule } from './profissionais/profissionais.module.js';
import { SolicitacoesModule } from './solicitacoes/solicitacoes.module.js';
import { TermosModule } from './termos/termos.module.js';
import { VerificacaoModule } from './verificacao/verificacao.module.js';

const runtimeImports = isAuthRuntimeConfigured()
  ? [
      TypeOrmModule.forRoot(databaseRuntimeOptions()),
      AuthModule,
      CategoriasModule,
      ProfissionaisModule,
      SolicitacoesModule,
      MensagensModule,
      AvaliacoesModule,
      ClientesModule,
      DisponibilidadeModule,
      NotificacoesModule,
      VerificacaoModule,
      DenunciasModule,
      AdminPainelModule,
      AdminUsuariosModule,
      HistoricoModule,
      TermosModule,
    ]
  : [];

@Module({
  imports: runtimeImports,
  controllers: [HealthController],
})
export class AppModule {}
