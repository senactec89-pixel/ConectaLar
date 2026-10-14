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

@Entity({ name: 'cliente_enderecos' })
@Index('idx_cliente_enderecos_usuario', ['usuarioId'])
export class ClienteEnderecoEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'usuario_id', type: 'int', unsigned: true })
  usuarioId!: number;

  @ManyToOne(() => UsuarioEntity, { nullable: false })
  @JoinColumn({ name: 'usuario_id' })
  usuario!: UsuarioEntity;

  @Column({ type: 'varchar', length: 80 })
  apelido!: string;

  @Column({ type: 'varchar', length: 12, nullable: true })
  cep!: string | null;

  @Column({ type: 'varchar', length: 160 })
  logradouro!: string;

  @Column({ type: 'varchar', length: 24 })
  numero!: string;

  @Column({ type: 'varchar', length: 120, nullable: true })
  complemento!: string | null;

  @Column({ type: 'varchar', length: 120 })
  bairro!: string;

  @Column({ type: 'varchar', length: 120 })
  cidade!: string;

  @Column({ type: 'char', length: 2 })
  uf!: string;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  latitude!: string | null;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  longitude!: string | null;

  @Column({ name: 'precisao_geografica', type: 'varchar', length: 32, nullable: true })
  precisaoGeografica!: string | null;

  @Column({ type: 'boolean', default: false })
  principal!: boolean;

  @Column({ type: 'boolean', default: true })
  ativo!: boolean;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamp' })
  atualizadoEm!: Date;
}
