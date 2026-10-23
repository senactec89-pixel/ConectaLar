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

@Entity({ name: 'profissional_bloqueios' })
@Index('idx_profissional_bloqueios_data', ['profissionalId', 'dataInicio', 'dataFim'])
export class ProfissionalBloqueioEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'profissional_id', type: 'int', unsigned: true })
  profissionalId!: number;

  @ManyToOne(() => ProfissionalPerfilEntity, { nullable: false })
  @JoinColumn({ name: 'profissional_id' })
  profissional!: ProfissionalPerfilEntity;

  @Column({ name: 'data_inicio', type: 'date' })
  dataInicio!: string;

  @Column({ name: 'data_fim', type: 'date' })
  dataFim!: string;

  @Column({ type: 'varchar', length: 160 })
  motivo!: string;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;
}
