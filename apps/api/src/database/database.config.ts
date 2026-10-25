import { join } from 'node:path';
import type { DataSourceOptions } from 'typeorm';
import { AdminAuditoriaEntity } from './entities/admin-auditoria.entity.js';
import { AvaliacaoEntity } from './entities/avaliacao.entity.js';
import { CategoriaEntity } from './entities/categoria.entity.js';
import { ClienteEnderecoEntity } from './entities/cliente-endereco.entity.js';
import { ClientePerfilEntity } from './entities/cliente-perfil.entity.js';
import { DenunciaEntity } from './entities/denuncia.entity.js';
import { AdminConviteEntity } from './entities/admin-convite.entity.js';
import { EmailOutboxEntity } from './entities/email-outbox.entity.js';
import { FavoritoProfissionalEntity } from './entities/favorito-profissional.entity.js';
import { MensagemAtendimentoEntity } from './entities/mensagem-atendimento.entity.js';
import { NotificacaoEntity } from './entities/notificacao.entity.js';
import { ProfissionalDocumentoVerificacaoEntity } from './entities/profissional-documento-verificacao.entity.js';
import { ProfissionalDisponibilidadeEntity } from './entities/profissional-disponibilidade.entity.js';
import { ProfissionalBloqueioEntity } from './entities/profissional-bloqueio.entity.js';
import { ProfissionalPerfilEntity } from './entities/profissional-perfil.entity.js';
import { ProfissionalServicoEntity } from './entities/profissional-servico.entity.js';
import { PrivacidadeSolicitacaoEntity } from './entities/privacidade-solicitacao.entity.js';
import { SolicitacaoEntity } from './entities/solicitacao.entity.js';
import { SolicitacaoEventoEntity } from './entities/solicitacao-evento.entity.js';
import { SolicitacaoReagendamentoEntity } from './entities/solicitacao-reagendamento.entity.js';
import { SolicitacaoOrcamentoEntity } from './entities/solicitacao-orcamento.entity.js';
import { TermoAceiteEntity } from './entities/termo-aceite.entity.js';
import { UsuarioEmailVerificacaoEntity } from './entities/usuario-email-verificacao.entity.js';
import { UsuarioSenhaResetEntity } from './entities/usuario-senha-reset.entity.js';
import { UsuarioEntity } from './entities/usuario.entity.js';
import { ProfissionalIdentidadeVerificacaoEntity } from './entities/profissional-identidade-verificacao.entity.js';
import { ProfissionalTelefoneVerificacaoEntity } from './entities/profissional-telefone-verificacao.entity.js';

export {
  isAuthRuntimeConfigured,
  isDatabaseRuntimeConfigured,
} from '../config/runtime.js';

function requiredDatabaseValue(name: string): string {
  const value = process.env[name];
  if (name === 'DB_PASSWORD') {
    return value ?? '';
  }

  if (value === undefined || value.trim() === '') {
    throw new Error('Database configuration is incomplete.');
  }

  return value;
}

function databasePort(): number {
  const value = process.env.DB_PORT ?? '3306';
  if (!/^[1-9]\d{0,4}$/.test(value)) {
    throw new Error('Database configuration is invalid.');
  }

  const port = Number(value);
  if (!Number.isSafeInteger(port) || port > 65_535) {
    throw new Error('Database configuration is invalid.');
  }

  return port;
}

export function databaseRuntimeOptions(): DataSourceOptions {
  return {
    type: 'mysql',
    host: requiredDatabaseValue('DB_HOST'),
    port: databasePort(),
    username: requiredDatabaseValue('DB_USER'),
    password: requiredDatabaseValue('DB_PASSWORD'),
    database: requiredDatabaseValue('DB_NAME'),
    charset: 'utf8mb4',
    timezone: 'Z',
    // DATE é uma data civil, sem fuso. Evita deslocar o atendimento para o dia
    // anterior quando o servidor roda em America/Sao_Paulo.
    dateStrings: ['DATE'],
    synchronize: false,
    migrationsRun: false,
    migrationsTableName: 'typeorm_migrations',
    logging: false,
    entities: [
      UsuarioEntity,
      ProfissionalPerfilEntity,
      ProfissionalServicoEntity,
      CategoriaEntity,
      SolicitacaoEntity,
      SolicitacaoEventoEntity,
      MensagemAtendimentoEntity,
      AvaliacaoEntity,
      ClientePerfilEntity,
      ClienteEnderecoEntity,
      FavoritoProfissionalEntity,
      ProfissionalDisponibilidadeEntity,
      ProfissionalBloqueioEntity,
      NotificacaoEntity,
      ProfissionalDocumentoVerificacaoEntity,
      DenunciaEntity,
      AdminConviteEntity,
      EmailOutboxEntity,
      AdminAuditoriaEntity,
      TermoAceiteEntity,
      UsuarioSenhaResetEntity,
      UsuarioEmailVerificacaoEntity,
      ProfissionalIdentidadeVerificacaoEntity,
      ProfissionalTelefoneVerificacaoEntity,
      PrivacidadeSolicitacaoEntity,
      SolicitacaoReagendamentoEntity,
      SolicitacaoOrcamentoEntity,
    ],
  };
}

export function databaseCliOptions(): DataSourceOptions {
  return {
    ...databaseRuntimeOptions(),
    entities: [join(__dirname, 'entities', '*.entity.js')],
    migrations: [join(__dirname, 'migrations', '*.js')],
  };
}
