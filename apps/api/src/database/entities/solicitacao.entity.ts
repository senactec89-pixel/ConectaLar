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
import { SolicitacaoStatus } from '../../domain/solicitacao-status.js';
import { CategoriaEntity } from './categoria.entity.js';
import { ClienteEnderecoEntity } from './cliente-endereco.entity.js';
import { ProfissionalPerfilEntity } from './profissional-perfil.entity.js';
import { UsuarioEntity } from './usuario.entity.js';

@Entity({ name: 'solicitacoes' })
@Index('idx_solicitacoes_cliente', ['clienteId'])
@Index('idx_solicitacoes_profissional', ['profissionalId'])
@Index('idx_solicitacoes_status', ['status'])
export class SolicitacaoEntity {
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

  @Column({ name: 'categoria_id', type: 'int', unsigned: true, nullable: true })
  categoriaId!: number | null;

  @ManyToOne(() => CategoriaEntity, { nullable: true })
  @JoinColumn({ name: 'categoria_id' })
  categoria!: CategoriaEntity | null;

  @Column({ name: 'endereco_id', type: 'int', unsigned: true, nullable: true })
  enderecoId!: number | null;

  @ManyToOne(() => ClienteEnderecoEntity, { nullable: true })
  @JoinColumn({ name: 'endereco_id' })
  endereco!: ClienteEnderecoEntity | null;

  @Column({ type: 'varchar', length: 600 })
  descricao!: string;

  @Column({ name: 'bairro_atendimento', type: 'varchar', length: 120 })
  bairroAtendimento!: string;

  @Column({ name: 'data_servico', type: 'date' })
  dataServico!: string;

  @Column({ name: 'horario_servico', type: 'varchar', length: 5 })
  horarioServico!: string;

  @Column({
    name: 'preco_inicial',
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true,
  })
  precoInicial!: string | null;

  @Column({ type: 'varchar', length: 32 })
  status!: SolicitacaoStatus;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamp' })
  atualizadoEm!: Date;
}
