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
import { ProfissionalServicoEntity } from './profissional-servico.entity.js';
import { UsuarioEntity } from './usuario.entity.js';

export interface EnderecoAtendimentoSnapshot {
  readonly id: number;
  readonly apelido: string;
  readonly cep: string | null;
  readonly logradouro: string;
  readonly numero: string;
  readonly complemento: string | null;
  readonly bairro: string;
  readonly cidade: string;
  readonly uf: string;
}

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

  @Column({ name: 'servico_id', type: 'int', unsigned: true, nullable: true })
  servicoId!: number | null;

  @ManyToOne(() => ProfissionalServicoEntity, {
    nullable: true,
    onDelete: 'SET NULL',
  })
  @JoinColumn({ name: 'servico_id' })
  servico!: ProfissionalServicoEntity | null;

  @Column({ name: 'nome_servico', type: 'varchar', length: 90, nullable: true })
  nomeServico!: string | null;

  @Column({ name: 'endereco_id', type: 'int', unsigned: true, nullable: true })
  enderecoId!: number | null;

  @ManyToOne(() => ClienteEnderecoEntity, { nullable: true })
  @JoinColumn({ name: 'endereco_id' })
  endereco!: ClienteEnderecoEntity | null;

  // The booking must keep the address agreed at creation time. The customer can
  // still update their address book without rewriting an existing appointment.
  @Column({ name: 'endereco_snapshot', type: 'json', nullable: true })
  enderecoSnapshot!: EnderecoAtendimentoSnapshot | null;

  @Column({ type: 'varchar', length: 600 })
  descricao!: string;

  @Column({ name: 'bairro_atendimento', type: 'varchar', length: 120 })
  bairroAtendimento!: string;

  @Column({ name: 'data_servico', type: 'date' })
  dataServico!: string;

  @Column({ name: 'horario_servico', type: 'varchar', length: 5 })
  horarioServico!: string;

  @Column({ name: 'duracao_minutos', type: 'smallint', unsigned: true, default: 60 })
  duracaoMinutos!: number;

  @Column({ name: 'intervalo_minutos', type: 'smallint', unsigned: true, default: 30 })
  intervaloMinutos!: number;
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

  @Column({
    name: 'cancelamento_motivo',
    type: 'varchar',
    length: 400,
    nullable: true,
  })
  cancelamentoMotivo!: string | null;

  @Column({
    name: 'conclusao_contestacao_motivo',
    type: 'varchar',
    length: 600,
    nullable: true,
  })
  conclusaoContestacaoMotivo!: string | null;

  @Column({
    name: 'nao_comparecimento_motivo',
    type: 'varchar',
    length: 600,
    nullable: true,
  })
  naoComparecimentoMotivo!: string | null;

  @Column({
    name: 'nao_comparecimento_por_id',
    type: 'int',
    unsigned: true,
    nullable: true,
  })
  naoComparecimentoPorId!: number | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamp' })
  atualizadoEm!: Date;
}
