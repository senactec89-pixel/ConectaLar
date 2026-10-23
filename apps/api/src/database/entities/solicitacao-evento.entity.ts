import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { SolicitacaoStatus } from '../../domain/solicitacao-status.js';
import { SolicitacaoEntity } from './solicitacao.entity.js';
import { UsuarioEntity } from './usuario.entity.js';

@Entity({ name: 'solicitacao_eventos' })
@Index('idx_solicitacao_eventos_solicitacao', ['solicitacaoId', 'criadoEm'])
export class SolicitacaoEventoEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'solicitacao_id', type: 'int', unsigned: true })
  solicitacaoId!: number;

  @ManyToOne(() => SolicitacaoEntity, { nullable: false, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'solicitacao_id' })
  solicitacao!: SolicitacaoEntity;

  @Column({ name: 'ator_id', type: 'int', unsigned: true, nullable: true })
  atorId!: number | null;

  @ManyToOne(() => UsuarioEntity, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'ator_id' })
  ator!: UsuarioEntity | null;

  @Column({ type: 'varchar', length: 48 })
  tipo!: string;

  @Column({ name: 'status_anterior', type: 'varchar', length: 32, nullable: true })
  statusAnterior!: SolicitacaoStatus | null;

  @Column({ name: 'status_novo', type: 'varchar', length: 32 })
  statusNovo!: SolicitacaoStatus;

  @Column({ type: 'varchar', length: 600, nullable: true })
  motivo!: string | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;
}
