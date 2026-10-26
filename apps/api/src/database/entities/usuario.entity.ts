import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { UsuarioTipo } from '../../domain/usuario-tipo.js';

@Entity({ name: 'usuarios' })
@Index('uq_usuarios_telefone_normalizado', ['telefoneNormalizado'], {
  unique: true,
})
@Index('uq_usuarios_google_sub', ['googleSub'], { unique: true })
@Index('idx_usuarios_tipo_ativo', ['tipo', 'ativo'])
export class UsuarioEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ type: 'varchar', length: 140 })
  nome!: string;

  @Column({ type: 'varchar', length: 180, unique: true })
  email!: string;

  @Column({ name: 'email_verificado', type: 'boolean', default: false })
  emailVerificado!: boolean;

  @Column({
    name: 'google_sub',
    type: 'varchar',
    length: 255,
    nullable: true,
  })
  googleSub!: string | null;

  @Column({ type: 'varchar', length: 32, nullable: true })
  telefone!: string | null;

  @Column({
    name: 'telefone_normalizado',
    type: 'varchar',
    length: 16,
    nullable: true,
  })
  telefoneNormalizado!: string | null;

  @Column({
    name: 'foto_perfil',
    type: 'varchar',
    length: 180,
    nullable: true,
  })
  fotoPerfil!: string | null;

  @Column({ type: 'varchar', length: 24 })
  tipo!: UsuarioTipo;

  @Column({ name: 'senha_hash', type: 'varchar', length: 255, select: false })
  senhaHash!: string;

  @Column({ type: 'boolean', default: true })
  ativo!: boolean;

  @Column({ name: 'token_version', type: 'int', unsigned: true, default: 0 })
  tokenVersion!: number;

  @Column({ name: 'mfa_ativo', type: 'boolean', default: false })
  mfaAtivo!: boolean;

  @Column({ name: 'mfa_falhas', type: 'smallint', unsigned: true, default: 0 })
  mfaFalhas!: number;

  @Column({ name: 'mfa_bloqueado_ate', type: 'datetime', nullable: true })
  mfaBloqueadoAte!: Date | null;

  @Column({ name: 'senha_reset_solicitacoes', type: 'smallint', unsigned: true, default: 0 })
  senhaResetSolicitacoes!: number;

  @Column({ name: 'senha_reset_janela_inicio', type: 'datetime', nullable: true })
  senhaResetJanelaInicio!: Date | null;

  @Column({ name: 'senha_reset_ultima_solicitacao', type: 'datetime', nullable: true })
  senhaResetUltimaSolicitacao!: Date | null;

  @Column({ name: 'email_verificacao_solicitacoes', type: 'smallint', unsigned: true, default: 0 })
  emailVerificacaoSolicitacoes!: number;

  @Column({ name: 'email_verificacao_janela_inicio', type: 'datetime', nullable: true })
  emailVerificacaoJanelaInicio!: Date | null;

  @Column({ name: 'email_verificacao_ultima_solicitacao', type: 'datetime', nullable: true })
  emailVerificacaoUltimaSolicitacao!: Date | null;

  @Column({
    name: 'mfa_secret_encrypted',
    type: 'varchar',
    length: 512,
    nullable: true,
    select: false,
  })
  mfaSecretEncrypted!: string | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamp' })
  atualizadoEm!: Date;
}
