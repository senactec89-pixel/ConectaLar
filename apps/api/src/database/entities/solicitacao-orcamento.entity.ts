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
import { OrcamentoStatus } from '../../domain/orcamento-status.js';
import { SolicitacaoEntity } from './solicitacao.entity.js';
import { UsuarioEntity } from './usuario.entity.js';

@Entity({ name: 'solicitacao_orcamentos' })
@Index('idx_orcamentos_solicitacao_criado', ['solicitacaoId', 'criadoEm'])
@Index('idx_orcamentos_proponente', ['propostoPorId'])
export class SolicitacaoOrcamentoEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'solicitacao_id', type: 'int', unsigned: true })
  solicitacaoId!: number;

  @ManyToOne(() => SolicitacaoEntity, { nullable: false, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'solicitacao_id' })
  solicitacao!: SolicitacaoEntity;

  @Column({ name: 'proposto_por_id', type: 'int', unsigned: true })
  propostoPorId!: number;

  @ManyToOne(() => UsuarioEntity, { nullable: false })
  @JoinColumn({ name: 'proposto_por_id' })
  propostoPor!: UsuarioEntity;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  valor!: string;

  @Column({ type: 'varchar', length: 600 })
  descricao!: string;

  @Column({ type: 'varchar', length: 24, default: OrcamentoStatus.Pendente })
  status!: OrcamentoStatus;

  @Column({ name: 'respondido_em', type: 'timestamp', nullable: true })
  respondidoEm!: Date | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamp' })
  atualizadoEm!: Date;
}
