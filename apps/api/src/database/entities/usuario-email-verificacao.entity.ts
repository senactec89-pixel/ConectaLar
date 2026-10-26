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

@Entity({ name: 'usuario_email_verificacoes' })
@Index('idx_usuario_email_verificacoes_usuario_criado', [
  'usuarioId',
  'criadoEm',
])
export class UsuarioEmailVerificacaoEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'usuario_id', type: 'int', unsigned: true })
  usuarioId!: number;

  @ManyToOne(() => UsuarioEntity, { nullable: false })
  @JoinColumn({ name: 'usuario_id' })
  usuario!: UsuarioEntity;

  @Column({ name: 'codigo_hash', type: 'varchar', length: 64 })
  codigoHash!: string;

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
