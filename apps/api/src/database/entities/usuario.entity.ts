import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { UsuarioTipo } from '../../domain/usuario-tipo.js';

@Entity({ name: 'usuarios' })
@Index('uq_usuarios_telefone_normalizado', ['telefoneNormalizado'], {
  unique: true,
})
export class UsuarioEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ type: 'varchar', length: 140 })
  nome!: string;

  @Column({ type: 'varchar', length: 180, unique: true })
  email!: string;

  @Column({ type: 'varchar', length: 32, nullable: true })
  telefone!: string | null;

  @Column({
    name: 'telefone_normalizado',
    type: 'varchar',
    length: 16,
    nullable: true,
  })
  telefoneNormalizado!: string | null;

  @Column({ type: 'varchar', length: 24 })
  tipo!: UsuarioTipo;

  @Column({ name: 'senha_hash', type: 'varchar', length: 255, select: false })
  senhaHash!: string;

  @Column({ type: 'boolean', default: true })
  ativo!: boolean;

  @Column({ name: 'token_version', type: 'int', unsigned: true, default: 0 })
  tokenVersion!: number;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamp' })
  atualizadoEm!: Date;
}
