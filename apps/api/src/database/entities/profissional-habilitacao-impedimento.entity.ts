import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { ProfissionalPerfilEntity } from './profissional-perfil.entity.js';
import { UsuarioEntity } from './usuario.entity.js';

@Entity({ name: 'profissional_habilitacao_impedimentos' })
@Index('uq_habilitacao_impedimento_profissional_admin', ['profissionalId', 'administradorId'], { unique: true })
@Index('idx_habilitacao_impedimento_admin', ['administradorId', 'criadoEm'])
export class ProfissionalHabilitacaoImpedimentoEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'profissional_id', type: 'int', unsigned: true })
  profissionalId!: number;

  @ManyToOne(() => ProfissionalPerfilEntity, { nullable: false })
  @JoinColumn({ name: 'profissional_id' })
  profissional!: ProfissionalPerfilEntity;

  @ManyToOne(() => UsuarioEntity, { nullable: false })
  @JoinColumn({ name: 'administrador_id' })
  administrador!: UsuarioEntity;

  @Column({ name: 'administrador_id', type: 'int', unsigned: true })
  administradorId!: number;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp', precision: 6 })
  criadoEm!: Date;
}
