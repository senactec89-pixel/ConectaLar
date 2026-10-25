import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { AvaliacaoEntity } from '../database/entities/avaliacao.entity.js';
import { CategoriaEntity } from '../database/entities/categoria.entity.js';
import { DenunciaEntity } from '../database/entities/denuncia.entity.js';
import { ProfissionalDocumentoVerificacaoEntity } from '../database/entities/profissional-documento-verificacao.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { AvaliacaoModeracaoStatus } from '../domain/avaliacao-moderacao-status.js';
import { DenunciaStatus } from '../domain/denuncia-status.js';
import { DocumentoVerificacaoStatus } from '../domain/documento-verificacao-status.js';
import { SolicitacaoStatus } from '../domain/solicitacao-status.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { optionalEnumFilter, optionalSearchTerm } from '../common/admin-list-query.js';
import { paginationMetadata, parsePaginationQuery } from '../common/pagination.js';
import { AdminAuditoriaAcao } from '../domain/admin-auditoria-acao.js';

@Injectable()
export class AdminPainelService {
  constructor(
    @InjectRepository(AdminAuditoriaEntity)
    private readonly auditoria: Repository<AdminAuditoriaEntity>,
    @InjectRepository(AvaliacaoEntity)
    private readonly avaliacoes: Repository<AvaliacaoEntity>,
    @InjectRepository(CategoriaEntity)
    private readonly categorias: Repository<CategoriaEntity>,
    @InjectRepository(DenunciaEntity)
    private readonly denuncias: Repository<DenunciaEntity>,
    @InjectRepository(ProfissionalDocumentoVerificacaoEntity)
    private readonly documentos: Repository<ProfissionalDocumentoVerificacaoEntity>,
    @InjectRepository(ProfissionalPerfilEntity)
    private readonly profissionais: Repository<ProfissionalPerfilEntity>,
    @InjectRepository(SolicitacaoEntity)
    private readonly solicitacoes: Repository<SolicitacaoEntity>,
    @InjectRepository(UsuarioEntity)
    private readonly usuarios: Repository<UsuarioEntity>,
  ) {}

  async resumo() {
    const [
      usuariosAtivos,
      clientes,
      profissionais,
      empresas,
      administradores,
      perfisProfissionais,
      documentosPendentes,
      denunciasAbertas,
      avaliacoesPendentes,
      categoriasAtivas,
      solicitacoesAguardando,
      solicitacoesAgendadas,
      solicitacoesEmRevisao,
      solicitacoesConcluidas,
    ] = await Promise.all([
      this.usuarios.count({ where: { ativo: true } }),
      this.usuarios.count({
        where: { tipo: UsuarioTipo.Cliente, ativo: true },
      }),
      this.usuarios.count({
        where: { tipo: UsuarioTipo.Profissional, ativo: true },
      }),
      this.usuarios.count({
        where: { tipo: UsuarioTipo.Empresa, ativo: true },
      }),
      this.usuarios.count({
        where: { tipo: UsuarioTipo.Administrador, ativo: true },
      }),
      this.profissionais.count({ where: { ativo: true } }),
      this.documentos.count({
        where: { status: DocumentoVerificacaoStatus.Pendente },
      }),
      this.denuncias.count({
        where: { status: In([DenunciaStatus.Pendente, DenunciaStatus.EmAnalise]) },
      }),
      this.avaliacoes.count({
        where: { moderacaoStatus: AvaliacaoModeracaoStatus.Pendente },
      }),
      this.categorias.count({ where: { ativo: true } }),
      this.solicitacoes.count({
        where: { status: SolicitacaoStatus.AguardandoResposta },
      }),
      this.solicitacoes.count({
        where: { status: SolicitacaoStatus.AceitaAgendada },
      }),
      this.solicitacoes.count({
        where: {
          status: In([
            SolicitacaoStatus.ConclusaoContestada,
            SolicitacaoStatus.NaoComparecimentoInformado,
          ]),
        },
      }),
      this.solicitacoes.count({
        where: { status: SolicitacaoStatus.ConclusaoConfirmada },
      }),
    ]);

    return {
      usuarios: {
        ativos: usuariosAtivos,
        clientes,
        profissionais,
        empresas,
        administradores,
      },
      profissionais: {
        perfisAtivos: perfisProfissionais,
      },
      moderacao: {
        documentosPendentes,
        denunciasAbertas,
        avaliacoesPendentes,
      },
      catalogo: {
        categoriasAtivas,
      },
      atendimentos: {
        aguardandoResposta: solicitacoesAguardando,
        aceitaAgendada: solicitacoesAgendadas,
        emRevisao: solicitacoesEmRevisao,
        conclusaoConfirmada: solicitacoesConcluidas,
      },
    };
  }

  async listarAuditoria(query: Record<string, unknown>) {
    const acao = optionalEnumFilter(query, 'acao', Object.values(AdminAuditoriaAcao));
    const alvoTipo = optionalEnumFilter(query, 'alvoTipo', [
      'usuario', 'categoria', 'documento', 'denuncia', 'avaliacao', 'profissional',
    ] as const);
    const termo = optionalSearchTerm(query);
    const atorId = optionalPositiveId(query.atorId);
    const pagination = parsePaginationQuery(query, { defaultLimit: 20, maxLimit: 100 });
    const builder = this.auditoria
      .createQueryBuilder('evento')
      .leftJoinAndSelect('evento.ator', 'ator')
      .orderBy('evento.criadoEm', 'DESC')
      .addOrderBy('evento.id', 'DESC')
      .skip(pagination.skip)
      .take(pagination.limite);
    if (acao !== null) builder.andWhere('evento.acao = :acao', { acao });
    if (alvoTipo !== null) builder.andWhere('evento.alvoTipo = :alvoTipo', { alvoTipo });
    if (atorId !== null) builder.andWhere('evento.atorId = :atorId', { atorId });
    if (termo !== null) {
      builder.andWhere(
        '(ator.nome LIKE :termo OR ator.email LIKE :termo OR evento.acao LIKE :termo OR evento.alvoTipo LIKE :termo)',
        { termo: `%${termo}%` },
      );
    }
    const [eventos, total] = await builder.getManyAndCount();

    return {
      paginacao: paginationMetadata(pagination, total),
      eventos: eventos.map((evento) => ({
        id: evento.id,
        ator: {
          id: evento.ator.id,
          nome: evento.ator.nome,
          tipo: evento.ator.tipo,
        },
        acao: evento.acao,
        alvoTipo: evento.alvoTipo,
        alvoId: evento.alvoId,
        detalhe: evento.detalhe,
        criadoEm: evento.criadoEm.toISOString(),
      })),
    };
  }
}

function optionalPositiveId(value: unknown): number | null {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string' || !/^[1-9]\d{0,9}$/.test(value)) {
    throw new BadRequestException({ code: 'FILTRO_INVALIDO', message: 'Filtro invalido.' });
  }
  return Number(value);
}
