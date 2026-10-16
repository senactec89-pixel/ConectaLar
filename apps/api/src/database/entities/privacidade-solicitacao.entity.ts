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
import { UsuarioEntity } from './usuario.entity.js';

export enum PrivacidadeSolicitacaoTipo {
  Exportacao = 'exportacao',
  Exclusao = 'exclusao',
}

export enum PrivacidadeSolicitacaoStatus {
  Processando = 'processando',
  Concluida = 'concluida',
  Falhou = 'falhou',
}

@Entity({ name: 'privacidade_solicitacoes' })
@Index('idx_privacidade_solicitacoes_usuario_criado', [
  'usuarioId',
  'criadoEm',
])
export class PrivacidadeSolicitacaoEntity {
  @PrimaryGeneratedColumn({ type: 'int', unsigned: true })
  id!: number;

  @Column({ name: 'usuario_id', type: 'int', unsigned: true })
  usuarioId!: number;

  @ManyToOne(() => UsuarioEntity, { nullable: false })
  @JoinColumn({ name: 'usuario_id' })
  usuario!: UsuarioEntity;

  @Column({ type: 'varchar', length: 24 })
  tipo!: PrivacidadeSolicitacaoTipo;

  @Column({ type: 'varchar', length: 24 })
  status!: PrivacidadeSolicitacaoStatus;

  @Column({ name: 'concluida_em', type: 'timestamp', nullable: true })
  concluidaEm!: Date | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamp' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamp' })
  atualizadoEm!: Date;
}
