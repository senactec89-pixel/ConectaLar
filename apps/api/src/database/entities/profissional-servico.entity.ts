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
import { CategoriaEntity } from './categoria.entity.js';
import { ProfissionalPerfilEntity } from './profissional-perfil.entity.js';

@Entity({ name: 'profissional_servicos' })
@Index('idx_profissional_servicos_profissional', ['profissionalId'])
@Index('idx_profissional_servicos_categoria', ['categoriaId'])
@Index('idx_prof_servicos_categoria_ativo_profissional', [
  'categoriaId',
  'ativo',
  'profissionalId',
])
export class ProfissionalServicoEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'profissional_id', type: 'int', unsigned: true })
  profissionalId!: number;

  @Column({ name: 'categoria_id', type: 'int', unsigned: true, nullable: true })
  categoriaId!: number | null;

  @ManyToOne(() => CategoriaEntity, { nullable: true })
  @JoinColumn({ name: 'categoria_id' })
  categoria!: CategoriaEntity | null;

  @ManyToOne(() => ProfissionalPerfilEntity, (perfil) => perfil.servicos, {
    nullable: false,
  })
  @JoinColumn({ name: 'profissional_id' })
  profissional!: ProfissionalPerfilEntity;

  @Column({ type: 'varchar', length: 90 })
  nome!: string;

  @Column({
    name: 'preco_inicial',
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true,
  })
  precoInicial!: string | null;

  @Column({ name: 'duracao_minutos', type: 'smallint', unsigned: true, default: 60 })
  duracaoMinutos!: number;

  @Column({ name: 'intervalo_minutos', type: 'smallint', unsigned: true, default: 30 })
  intervaloMinutos!: number;

  @Column({ type: 'boolean', default: true })
  ativo!: boolean;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamp' })
  atualizadoEm!: Date;
}
