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

export type EstadoRevisaoHabilitacao =
  | 'aguardando_segundo_revisor'
  | 'concluida'
  | 'divergente'
  | 'cancelada';
export type AcaoRevisaoHabilitacao = 'iniciar_analise' | 'reabrir';
export type MotivoRevisaoHabilitacao =
  | 'revisao_cadastral'
  | 'suspeita_fraude'
  | 'solicitacao_titular';

@Entity({ name: 'profissional_habilitacao_revisoes' })
@Index('idx_habilitacao_revisao_profissional_estado', ['profissionalId', 'estado', 'id'])
@Index('idx_habilitacao_revisao_estado_criado', ['estado', 'criadoEm'])
export class ProfissionalHabilitacaoRevisaoEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'profissional_id', type: 'int', unsigned: true })
  profissionalId!: number;

  @ManyToOne(() => ProfissionalPerfilEntity, { nullable: false })
  @JoinColumn({ name: 'profissional_id' })
  profissional!: ProfissionalPerfilEntity;

  @Column({ name: 'estado_inicial', type: 'varchar', length: 24 })
  estadoInicial!: string;

  @Column({ name: 'assinatura_dossie', type: 'char', length: 64 })
  assinaturaDossie!: string;

  @Column({ name: 'acao_primeiro_voto', type: 'varchar', length: 32 })
  acaoPrimeiroVoto!: AcaoRevisaoHabilitacao;

  @Column({ name: 'motivo_primeiro_voto', type: 'varchar', length: 32 })
  motivoPrimeiroVoto!: MotivoRevisaoHabilitacao;

  @Column({ name: 'primeiro_revisor_id', type: 'int', unsigned: true })
  primeiroRevisorId!: number;

  @ManyToOne(() => UsuarioEntity, { nullable: false })
  @JoinColumn({ name: 'primeiro_revisor_id' })
  primeiroRevisor!: UsuarioEntity;

  @Column({ name: 'primeiro_voto_em', type: 'datetime', precision: 3 })
  primeiroVotoEm!: Date;

  @Column({ name: 'acao_segundo_voto', type: 'varchar', length: 32, nullable: true })
  acaoSegundoVoto!: AcaoRevisaoHabilitacao | null;

  @Column({ name: 'motivo_segundo_voto', type: 'varchar', length: 32, nullable: true })
  motivoSegundoVoto!: MotivoRevisaoHabilitacao | null;

  @Column({ name: 'segundo_revisor_id', type: 'int', unsigned: true, nullable: true })
  segundoRevisorId!: number | null;

  @ManyToOne(() => UsuarioEntity, { nullable: true })
  @JoinColumn({ name: 'segundo_revisor_id' })
  segundoRevisor!: UsuarioEntity | null;

  @Column({ name: 'segundo_voto_em', type: 'datetime', precision: 3, nullable: true })
  segundoVotoEm!: Date | null;

  @Column({ type: 'varchar', length: 32, default: 'aguardando_segundo_revisor' })
  estado!: EstadoRevisaoHabilitacao;

  @Column({ name: 'resolvida_em', type: 'datetime', precision: 3, nullable: true })
  resolvidaEm!: Date | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp', precision: 6 })
  criadoEm!: Date;
}
