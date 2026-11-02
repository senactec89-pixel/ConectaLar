import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { AvaliacaoEntity } from './avaliacao.entity.js';
import { SolicitacaoEntity } from './solicitacao.entity.js';
import { UsuarioEntity } from './usuario.entity.js';

@Entity({ name: 'avaliacao_fotos' })
@Index('uq_avaliacao_fotos_referencia', ['referenciaArquivo'], { unique: true })
@Index('idx_avaliacao_fotos_expiracao', ['avaliacaoId', 'expiraEm'])
@Index('idx_avaliacao_fotos_autor_pedido', ['enviadoPorId', 'solicitacaoId'])
export class AvaliacaoFotoEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'solicitacao_id', type: 'int', unsigned: true })
  solicitacaoId!: number;

  @ManyToOne(() => SolicitacaoEntity, { nullable: false, onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'solicitacao_id' })
  solicitacao!: SolicitacaoEntity;

  @Column({ name: 'enviado_por_id', type: 'int', unsigned: true })
  enviadoPorId!: number;

  @ManyToOne(() => UsuarioEntity, { nullable: false, onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'enviado_por_id' })
  enviadoPor!: UsuarioEntity;

  @Column({ name: 'avaliacao_id', type: 'int', unsigned: true, nullable: true })
  avaliacaoId!: number | null;

  @ManyToOne(() => AvaliacaoEntity, (avaliacao) => avaliacao.fotos, {
    nullable: true,
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'avaliacao_id' })
  avaliacao!: AvaliacaoEntity | null;

  @Column({ name: 'referencia_arquivo', type: 'varchar', length: 240 })
  referenciaArquivo!: string;

  @Column({ name: 'mime_type', type: 'varchar', length: 40 })
  mimeType!: string;

  @Column({ name: 'tamanho_bytes', type: 'int', unsigned: true })
  tamanhoBytes!: number;

  @Column({ type: 'boolean', default: false })
  pronto!: boolean;

  @Column({ name: 'expira_em', type: 'timestamp', nullable: true })
  expiraEm!: Date | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;
}
