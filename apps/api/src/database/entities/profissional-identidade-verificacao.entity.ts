import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { UsuarioEntity } from './usuario.entity.js';

export type EstadoVerificacaoIdentidade =
  | 'iniciando'
  | 'pendente'
  | 'confirmada'
  | 'revisao_necessaria'
  | 'expirada'
  | 'falha';

@Entity({ name: 'profissional_identidade_verificacoes' })
@Index('idx_identidade_verificacoes_usuario_criado', ['usuarioId', 'criadoEm'])
@Index('uq_identidade_verificacoes_referencia', ['referencia'], { unique: true })
@Index('uq_identidade_verificacoes_idempotencia', ['chaveIdempotencia'], { unique: true })
@Index('uq_identidade_verificacoes_externo', ['referenciaExterna'], { unique: true })
export class ProfissionalIdentidadeVerificacaoEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'usuario_id', type: 'int', unsigned: true })
  usuarioId!: number;

  @ManyToOne(() => UsuarioEntity, { nullable: false })
  @JoinColumn({ name: 'usuario_id' })
  usuario!: UsuarioEntity;

  @Column({ name: 'referencia', type: 'varchar', length: 40, nullable: true })
  referencia!: string | null;

  @Column({ name: 'referencia_externa', type: 'varchar', length: 64 })
  referenciaExterna!: string;

  @Column({ name: 'chave_idempotencia', type: 'varchar', length: 36, nullable: true })
  chaveIdempotencia!: string | null;

  @Column({ name: 'consentimento_em', type: 'datetime' })
  consentimentoEm!: Date;

  @Column({ name: 'versao_aviso', type: 'varchar', length: 40 })
  versaoAviso!: string;

  @Column({ type: 'varchar', length: 24, default: 'iniciando' })
  estado!: EstadoVerificacaoIdentidade;

  @Column({ name: 'expira_em', type: 'datetime', nullable: true })
  expiraEm!: Date | null;

  @Column({ name: 'resolvida_em', type: 'datetime', nullable: true })
  resolvidaEm!: Date | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamp' })
  atualizadoEm!: Date;
}
