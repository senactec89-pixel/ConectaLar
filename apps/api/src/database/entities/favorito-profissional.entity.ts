import {
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Column,
} from 'typeorm';
import { ProfissionalPerfilEntity } from './profissional-perfil.entity.js';
import { UsuarioEntity } from './usuario.entity.js';

@Entity({ name: 'favoritos_profissionais' })
@Index('uq_favoritos_cliente_profissional', ['clienteId', 'profissionalId'], {
  unique: true,
})
@Index('idx_favoritos_cliente_criado_id', ['clienteId', 'criadoEm', 'id'])
export class FavoritoProfissionalEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'cliente_id', type: 'int', unsigned: true })
  clienteId!: number;

  @ManyToOne(() => UsuarioEntity, { nullable: false })
  @JoinColumn({ name: 'cliente_id' })
  cliente!: UsuarioEntity;

  @Column({ name: 'profissional_id', type: 'int', unsigned: true })
  profissionalId!: number;

  @ManyToOne(() => ProfissionalPerfilEntity, { nullable: false })
  @JoinColumn({ name: 'profissional_id' })
  profissional!: ProfissionalPerfilEntity;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;
}
