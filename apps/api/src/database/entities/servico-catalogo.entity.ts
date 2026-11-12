import {
  Column, CreateDateColumn, Entity, Index, JoinColumn, ManyToOne,
  PrimaryGeneratedColumn, UpdateDateColumn,
} from 'typeorm';
import { CategoriaEntity } from './categoria.entity.js';

@Entity({ name: 'servicos_catalogo' })
@Index('uq_servicos_catalogo_categoria_nome', ['categoriaId', 'nome'], { unique: true })
export class ServicoCatalogoEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'categoria_id', type: 'int', unsigned: true })
  categoriaId!: number;

  @ManyToOne(() => CategoriaEntity, { nullable: false, onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'categoria_id' })
  categoria!: CategoriaEntity;

  @Column({ type: 'varchar', length: 90 })
  nome!: string;

  @Column({ type: 'varchar', length: 1000, nullable: true })
  descricao!: string | null;

  @Column({ type: 'varchar', length: 1000, nullable: true })
  inclusoes!: string | null;

  @Column({ type: 'varchar', length: 1000, nullable: true })
  exclusoes!: string | null;

  @Column({ type: 'boolean', default: false })
  ativo!: boolean;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamp' })
  atualizadoEm!: Date;
}
