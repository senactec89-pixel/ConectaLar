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
import { SolicitacaoEntity } from './solicitacao.entity.js';
import { UsuarioEntity } from './usuario.entity.js';

export enum SolicitacaoPropostaStatus {
  Pendente = 'pendente',
  Aceita = 'aceita',
  Recusada = 'recusada',
  Expirada = 'expirada',
  Substituida = 'substituida',
}

@Entity({ name: 'solicitacao_propostas' })
@Index('idx_solicitacao_propostas_pedido', ['solicitacaoId', 'criadoEm'])
@Index('idx_solicitacao_propostas_vencimento', ['status', 'venceEm'])
export class SolicitacaoPropostaEntity {
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

  @Column({ name: 'data_proposta', type: 'date', nullable: true })
  dataProposta!: string | null;

  @Column({ name: 'horario_proposto', type: 'varchar', length: 5, nullable: true })
  horarioProposto!: string | null;

  @Column({ name: 'escopo_proposto', type: 'varchar', length: 600, nullable: true })
  escopoProposto!: string | null;

  @Column({ type: 'varchar', length: 16 })
  status!: SolicitacaoPropostaStatus;

  @Column({ name: 'vence_em', type: 'datetime', precision: 3 })
  venceEm!: Date;

  @Column({ name: 'respondido_em', type: 'datetime', precision: 3, nullable: true })
  respondidoEm!: Date | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamp' })
  atualizadoEm!: Date;
}
