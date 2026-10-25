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

@Entity({ name: 'email_outbox' })
@Index('idx_email_outbox_pendente', ['enviadoEm', 'canceladoEm', 'proximaTentativaEm'])
@Index('idx_email_outbox_usuario', ['usuarioId', 'criadoEm'])
export class EmailOutboxEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'usuario_id', type: 'int', unsigned: true })
  usuarioId!: number;

  @ManyToOne(() => UsuarioEntity, { nullable: false })
  @JoinColumn({ name: 'usuario_id' })
  usuario!: UsuarioEntity;

  @Column({ type: 'varchar', length: 40 })
  tipo!: 'verificacao_email' | 'convite_admin';

  @Column({ name: 'payload_criptografado', type: 'varchar', length: 255 })
  payloadCriptografado!: string;

  @Column({ type: 'smallint', unsigned: true, default: 0 })
  tentativas!: number;

  @Column({ name: 'proxima_tentativa_em', type: 'datetime' })
  proximaTentativaEm!: Date;

  @Column({ name: 'processando_em', type: 'datetime', nullable: true })
  processandoEm!: Date | null;

  @Column({ name: 'expira_em', type: 'datetime' })
  expiraEm!: Date;

  @Column({ name: 'enviado_em', type: 'datetime', nullable: true })
  enviadoEm!: Date | null;

  @Column({ name: 'cancelado_em', type: 'datetime', nullable: true })
  canceladoEm!: Date | null;

  @Column({ name: 'ultimo_erro', type: 'varchar', length: 64, nullable: true })
  ultimoErro!: string | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamp' })
  atualizadoEm!: Date;
}
