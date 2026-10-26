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

@Entity({ name: 'usuario_senha_resets' })
@Index('uq_usuario_senha_resets_token_hash', ['tokenHash'], { unique: true })
@Index('idx_usuario_senha_resets_usuario_criado', ['usuarioId', 'criadoEm'])
export class UsuarioSenhaResetEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'usuario_id', type: 'int', unsigned: true })
  usuarioId!: number;

  @ManyToOne(() => UsuarioEntity, { nullable: false })
  @JoinColumn({ name: 'usuario_id' })
  usuario!: UsuarioEntity;

  @Column({ name: 'token_hash', type: 'varchar', length: 64 })
  tokenHash!: string;

  @Column({ name: 'expira_em', type: 'timestamp' })
  expiraEm!: Date;

  @Column({ name: 'usado_em', type: 'timestamp', nullable: true })
  usadoEm!: Date | null;

  @Column({ type: 'smallint', unsigned: true, default: 0 })
  tentativas!: number;

  @Column({ name: 'bloqueado_em', type: 'timestamp', nullable: true })
  bloqueadoEm!: Date | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;
}
