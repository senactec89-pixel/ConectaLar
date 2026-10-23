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

export enum ReagendamentoStatus {
  Pendente = 'pendente',
  Aceito = 'aceito',
  Recusado = 'recusado',
  Cancelado = 'cancelado',
}

@Entity({ name: 'solicitacao_reagendamentos' })
@Index('idx_reagendamentos_solicitacao', ['solicitacaoId', 'criadoEm'])
export class SolicitacaoReagendamentoEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'solicitacao_id', type: 'int', unsigned: true })
  solicitacaoId!: number;

  @ManyToOne(() => SolicitacaoEntity, { nullable: false })
  @JoinColumn({ name: 'solicitacao_id' })
  solicitacao!: SolicitacaoEntity;

  @Column({ name: 'data_proposta', type: 'date' })
  dataProposta!: string;

  @Column({ name: 'horario_proposto', type: 'varchar', length: 5 })
  horarioProposto!: string;

  @Column({ type: 'varchar', length: 400 })
  motivo!: string;

  @Column({ type: 'varchar', length: 16 })
  status!: ReagendamentoStatus;

  @Column({ name: 'respondido_em', type: 'timestamp', nullable: true })
  respondidoEm!: Date | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamp' })
  atualizadoEm!: Date;
}
