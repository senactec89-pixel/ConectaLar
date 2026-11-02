import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { AvaliacaoModeracaoStatus } from '../../domain/avaliacao-moderacao-status.js';
import { SolicitacaoEntity } from './solicitacao.entity.js';
import { UsuarioEntity } from './usuario.entity.js';
import { AvaliacaoFotoEntity } from './avaliacao-foto.entity.js';

@Entity({ name: 'avaliacoes' })
@Index('uq_avaliacoes_participantes', ['solicitacaoId', 'avaliadorId', 'avaliadoId'], {
  unique: true,
})
@Index('idx_avaliacoes_avaliado', ['avaliadoId'])
@Index('idx_avaliacoes_moderacao', ['moderacaoStatus'])
export class AvaliacaoEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'solicitacao_id', type: 'int', unsigned: true })
  solicitacaoId!: number;

  @ManyToOne(() => SolicitacaoEntity, { nullable: false })
  @JoinColumn({ name: 'solicitacao_id' })
  solicitacao!: SolicitacaoEntity;

  @Column({ name: 'avaliador_id', type: 'int', unsigned: true })
  avaliadorId!: number;

  @ManyToOne(() => UsuarioEntity, { nullable: false })
  @JoinColumn({ name: 'avaliador_id' })
  avaliador!: UsuarioEntity;

  @Column({ name: 'avaliado_id', type: 'int', unsigned: true })
  avaliadoId!: number;

  @ManyToOne(() => UsuarioEntity, { nullable: false })
  @JoinColumn({ name: 'avaliado_id' })
  avaliado!: UsuarioEntity;

  @Column({ type: 'tinyint', unsigned: true })
  nota!: number;

  @Column({ type: 'varchar', length: 600, nullable: true })
  comentario!: string | null;

  @Column({ name: 'moderacao_status', type: 'varchar', length: 24 })
  moderacaoStatus!: AvaliacaoModeracaoStatus;

  @OneToMany(() => AvaliacaoFotoEntity, (foto) => foto.avaliacao)
  fotos!: AvaliacaoFotoEntity[];

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamp' })
  atualizadoEm!: Date;
}
