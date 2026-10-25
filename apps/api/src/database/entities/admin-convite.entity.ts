import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { UsuarioEntity } from './usuario.entity.js';

@Entity({ name: 'admin_convites' })
@Index('uq_admin_convites_token_hash', ['tokenHash'], { unique: true })
@Index('idx_admin_convites_usuario_pendente', ['usuarioId', 'aceitoEm', 'canceladoEm'])
export class AdminConviteEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'usuario_id', type: 'int', unsigned: true })
  usuarioId!: number;

  @ManyToOne(() => UsuarioEntity, { nullable: false })
  @JoinColumn({ name: 'usuario_id' })
  usuario!: UsuarioEntity;

  @Column({ name: 'convidado_por_id', type: 'int', unsigned: true })
  convidadoPorId!: number;

  @ManyToOne(() => UsuarioEntity, { nullable: false })
  @JoinColumn({ name: 'convidado_por_id' })
  convidadoPor!: UsuarioEntity;

  @Column({ name: 'token_hash', type: 'char', length: 64 })
  tokenHash!: string;

  @Column({ name: 'expira_em', type: 'datetime' })
  expiraEm!: Date;

  @Column({ name: 'aceito_em', type: 'datetime', nullable: true })
  aceitoEm!: Date | null;

  @Column({ name: 'cancelado_em', type: 'datetime', nullable: true })
  canceladoEm!: Date | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;
}
