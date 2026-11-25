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
import { ServicoCatalogoEntity } from './servico-catalogo.entity.js';
import { UsuarioEntity } from './usuario.entity.js';
import type { EstadoRevisaoExperienciaPiloto, NivelExperienciaPiloto } from '../../verificacao/habilitacao-piloto.js';

@Entity({ name: 'profissional_servicos' })
@Index('idx_profissional_servicos_profissional', ['profissionalId'])
@Index('idx_profissional_servicos_categoria', ['categoriaId'])
@Index('uq_oferta_profissional_catalogo', ['profissionalId', 'servicoCatalogoId'], { unique: true })
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

  @Column({ name: 'servico_catalogo_id', type: 'int', unsigned: true, nullable: true })
  servicoCatalogoId!: number | null;

  @ManyToOne(() => ServicoCatalogoEntity, { nullable: true, onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'servico_catalogo_id' })
  servicoCatalogo!: ServicoCatalogoEntity | null;

  @ManyToOne(() => ProfissionalPerfilEntity, (perfil) => perfil.servicos, {
    nullable: false,
  })
  @JoinColumn({ name: 'profissional_id' })
  profissional!: ProfissionalPerfilEntity;

  @Column({ type: 'varchar', length: 90 })
  nome!: string;

  @Column({ type: 'json', nullable: true })
  inclui!: string[] | null;

  @Column({ name: 'nao_inclui', type: 'json', nullable: true })
  naoInclui!: string[] | null;

  @Column({ type: 'json', nullable: true })
  opcionais!: string[] | null;

  @Column({
    name: 'preco_inicial',
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true,
  })
  precoInicial!: string | null;

  @Column({ name: 'duracao_minutos', type: 'smallint', unsigned: true, default: 120 })
  duracaoMinutos!: number;

  @Column({ name: 'intervalo_minutos', type: 'smallint', unsigned: true, default: 0 })
  intervaloMinutos!: number;

  @Column({ type: 'boolean', default: true })
  ativo!: boolean;

  @Column({ name: 'nivel_experiencia_piloto', type: 'varchar', length: 30, nullable: true })
  nivelExperienciaPiloto!: NivelExperienciaPiloto | null;

  @Column({ name: 'relato_experiencia_piloto', type: 'varchar', length: 500, nullable: true })
  relatoExperienciaPiloto!: string | null;

  @Column({ name: 'formacao_informada_piloto', type: 'varchar', length: 300, nullable: true })
  formacaoInformadaPiloto!: string | null;

  @Column({ name: 'frequencia_experiencia_piloto', type: 'varchar', length: 20, nullable: true })
  frequenciaExperienciaPiloto!: 'ocasional' | 'recorrente' | null;

  @Column({ name: 'iniciante_confirmado_piloto', type: 'boolean', default: false })
  inicianteConfirmadoPiloto!: boolean;

  @Column({ name: 'revisao_experiencia_estado', type: 'varchar', length: 24, default: 'pendente' })
  revisaoExperienciaEstado!: EstadoRevisaoExperienciaPiloto;

  @Column({ name: 'primeiro_revisor_id', type: 'int', unsigned: true, nullable: true })
  primeiroRevisorId!: number | null;

  @ManyToOne(() => UsuarioEntity, { nullable: true })
  @JoinColumn({ name: 'primeiro_revisor_id' })
  primeiroRevisor!: UsuarioEntity | null;

  @Column({ name: 'primeira_revisao_em', type: 'datetime', nullable: true })
  primeiraRevisaoEm!: Date | null;

  @Column({ name: 'revisor_final_id', type: 'int', unsigned: true, nullable: true })
  revisorFinalId!: number | null;

  @ManyToOne(() => UsuarioEntity, { nullable: true })
  @JoinColumn({ name: 'revisor_final_id' })
  revisorFinal!: UsuarioEntity | null;

  @Column({ name: 'revisao_final_em', type: 'datetime', nullable: true })
  revisaoFinalEm!: Date | null;

  @Column({ name: 'motivo_revisao_experiencia', type: 'varchar', length: 40, nullable: true })
  motivoRevisaoExperiencia!: string | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamp' })
  atualizadoEm!: Date;
}
