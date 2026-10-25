import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { AdminAuditoriaAcao } from '../../domain/admin-auditoria-acao.js';
import { UsuarioEntity } from './usuario.entity.js';

@Entity({ name: 'admin_auditoria' })
@Index('idx_admin_auditoria_ator_criado', ['atorId', 'criadoEm'])
@Index('idx_admin_auditoria_alvo', ['alvoTipo', 'alvoId'])
export class AdminAuditoriaEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'ator_id', type: 'int', unsigned: true })
  atorId!: number;

  @ManyToOne(() => UsuarioEntity, { nullable: false })
  @JoinColumn({ name: 'ator_id' })
  ator!: UsuarioEntity;

  @Column({ type: 'varchar', length: 60 })
  acao!: AdminAuditoriaAcao;

  @Column({ name: 'alvo_tipo', type: 'varchar', length: 60 })
  alvoTipo!: string;

  @Column({ name: 'alvo_id', type: 'int', unsigned: true })
  alvoId!: number;

  @Column({ type: 'text', nullable: true })
  detalhe!: string | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;
}
