import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, MoreThan, Repository } from 'typeorm';
import sharp from 'sharp';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { registrarAuditoriaAdmin } from '../common/admin-auditoria.js';
import { optionalEnumFilter, optionalSearchTerm } from '../common/admin-list-query.js';
import { paginationMetadata, parsePaginationQuery } from '../common/pagination.js';
import { AvaliacaoEntity } from '../database/entities/avaliacao.entity.js';
import { AvaliacaoFotoEntity } from '../database/entities/avaliacao-foto.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { AdminAuditoriaAcao } from '../domain/admin-auditoria-acao.js';
import { AvaliacaoModeracaoStatus } from '../domain/avaliacao-moderacao-status.js';
import { NotificacaoTipo } from '../domain/notificacao-tipo.js';
import { SolicitacaoStatus } from '../domain/solicitacao-status.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { NotificacoesService } from '../notificacoes/notificacoes.service.js';
import { MalwareScannerService } from '../verificacao/malware-scanner.service.js';
import { AvaliacaoFotoStorageService } from './avaliacao-foto-storage.service.js';

const maxFotoBytes = 5 * 1024 * 1024;
const maxFotosPorAvaliacao = 3;
const validadeUploadMs = 24 * 60 * 60 * 1000;

export interface ArquivoFotoAvaliacao {
  readonly buffer: Buffer;
  readonly mimetype: string;
}

@Injectable()
export class AvaliacoesService {
  constructor(
    @InjectRepository(AvaliacaoEntity)
    private readonly avaliacoes: Repository<AvaliacaoEntity>,
    @InjectRepository(SolicitacaoEntity)
    private readonly solicitacoes: Repository<SolicitacaoEntity>,
    @InjectRepository(AvaliacaoFotoEntity)
    private readonly fotos: Repository<AvaliacaoFotoEntity>,
    private readonly notificacoes: NotificacoesService,
    private readonly fotoStorage: AvaliacaoFotoStorageService,
    private readonly malwareScanner: MalwareScannerService,
  ) {}

  async listarDaSolicitacao(user: AuthenticatedUser, solicitacaoId: number) {
    const solicitacao = await this.carregarSolicitacao(solicitacaoId);
    assertParticipante(user, solicitacao);

    const avaliacoes = await this.avaliacoes.find({
      where: { solicitacaoId },
      relations: { avaliador: true, avaliado: true, fotos: true },
      order: { criadoEm: 'ASC' },
    });

    return {
      avaliacoes: avaliacoes
        .filter((avaliacao) =>
          user.tipo === UsuarioTipo.Administrador ||
          avaliacao.avaliadorId === user.id ||
          avaliacao.moderacaoStatus === AvaliacaoModeracaoStatus.Aprovada,
        )
        .map(avaliacaoResponse),
    };
  }

  async avaliarProfissional(
    user: AuthenticatedUser,
    solicitacaoId: number,
    body: unknown,
  ) {
    const solicitacao = await this.carregarSolicitacao(solicitacaoId);
    assertClienteParticipante(user, solicitacao);
    return this.criarAvaliacao(
      solicitacao,
      user.id,
      solicitacao.profissional.usuarioId,
      body,
      true,
    );
  }

  async avaliarCliente(
    user: AuthenticatedUser,
    solicitacaoId: number,
    body: unknown,
  ) {
    const solicitacao = await this.carregarSolicitacao(solicitacaoId);
    assertProfissionalParticipante(user, solicitacao);
    return this.criarAvaliacao(
      solicitacao,
      user.id,
      solicitacao.clienteId,
      body,
      false,
    );
  }

  async adicionarFoto(
    user: AuthenticatedUser,
    solicitacaoId: number,
    arquivo: ArquivoFotoAvaliacao | undefined,
  ) {
    if (user.tipo !== UsuarioTipo.Cliente) throw forbidden();
    const solicitacao = await this.carregarSolicitacao(solicitacaoId);
    assertClienteParticipante(user, solicitacao);
    if (solicitacao.status !== SolicitacaoStatus.ConclusaoConfirmada) {
      throw badRequest('AVALIACAO_INDISPONIVEL');
    }
    if (
      (await this.avaliacoes.count({ where: { solicitacaoId, avaliadorId: user.id } })) > 0
    ) {
      throw new ConflictException({
        code: 'AVALIACAO_JA_REGISTRADA',
        message: 'A avaliacao ja foi enviada para este atendimento.',
      });
    }
    if (
      arquivo === undefined ||
      !Buffer.isBuffer(arquivo.buffer) ||
      arquivo.buffer.length === 0 ||
      arquivo.buffer.length > maxFotoBytes ||
      !assinaturaImagemValida(arquivo.buffer, arquivo.mimetype)
    ) {
      throw badRequest('FOTO_AVALIACAO_INVALIDA');
    }

    await this.verificarImagemMaliciosa(arquivo.buffer);
    const normalizada = await normalizarImagem(arquivo.buffer);
    await this.verificarImagemMaliciosa(normalizada);

    const referenciaArquivo = this.fotoStorage.novaReferencia(solicitacaoId);
    try {
      const foto = await this.fotos.manager.transaction(async (manager) => {
        const pedidos = manager.getRepository(SolicitacaoEntity);
        const atual = await pedidos.findOne({
          where: { id: solicitacaoId },
          lock: { mode: 'pessimistic_write' },
        });
        if (
          atual === null ||
          atual.clienteId !== user.id ||
          atual.status !== SolicitacaoStatus.ConclusaoConfirmada
        ) {
          throw forbidden();
        }
        const avaliacoes = manager.getRepository(AvaliacaoEntity);
        if (
          (await avaliacoes.count({
            where: { solicitacaoId, avaliadorId: user.id },
          })) > 0
        ) {
          throw new ConflictException({
            code: 'AVALIACAO_JA_REGISTRADA',
            message: 'A avaliacao ja foi enviada para este atendimento.',
          });
        }
        const fotos = manager.getRepository(AvaliacaoFotoEntity);
        const pendentes = await fotos.count({
          where: {
            solicitacaoId,
            enviadoPorId: user.id,
            avaliacaoId: IsNull(),
            expiraEm: MoreThan(new Date()),
          },
        });
        if (pendentes >= maxFotosPorAvaliacao) {
          throw new ConflictException({
            code: 'LIMITE_FOTOS_AVALIACAO',
            message: 'Voce pode anexar ate tres fotos por avaliacao.',
          });
        }
        const registro = await fotos.save(
          fotos.create({
            solicitacaoId,
            enviadoPorId: user.id,
            avaliacaoId: null,
            referenciaArquivo,
            mimeType: 'image/jpeg',
            tamanhoBytes: normalizada.length,
            pronto: false,
            expiraEm: new Date(Date.now() + validadeUploadMs),
          }),
        );
        return registro;
      });
      await this.fotoStorage.salvar(referenciaArquivo, normalizada);
      const ativacao = await this.fotos.update(
        { id: foto.id, avaliacaoId: IsNull() },
        { pronto: true },
      );
      if (ativacao.affected !== 1) {
        throw new ConflictException({
          code: 'FOTO_AVALIACAO_INDISPONIVEL',
          message: 'Nao foi possivel concluir o envio da foto.',
        });
      }
      return { foto: { id: foto.id, mimeType: foto.mimeType } };
    } catch (error) {
      try {
        await this.fotoStorage.remover(referenciaArquivo);
        await this.fotos.delete({ referenciaArquivo, avaliacaoId: IsNull() });
      } catch {
        await this.fotos.update(
          { referenciaArquivo, avaliacaoId: IsNull() },
          { expiraEm: new Date(Date.now() + 60_000) },
        );
      }
      throw error;
    }
  }

  async removerFotoTemporaria(
    user: AuthenticatedUser,
    solicitacaoId: number,
    fotoId: number,
  ) {
    if (user.tipo !== UsuarioTipo.Cliente) throw forbidden();
    await this.fotos.manager.transaction(async (manager) => {
      const fotos = manager.getRepository(AvaliacaoFotoEntity);
      const foto = await fotos.findOne({
        where: {
          id: fotoId,
          solicitacaoId,
          enviadoPorId: user.id,
          avaliacaoId: IsNull(),
        },
        lock: { mode: 'pessimistic_write' },
      });
      if (foto === null) throw fotoNaoEncontrada();
      await this.fotoStorage.remover(foto.referenciaArquivo);
      await fotos.delete({ id: foto.id });
    });
    return { ok: true };
  }

  async carregarFoto(
    user: AuthenticatedUser | null,
    avaliacaoId: number,
    fotoId: number,
  ) {
    const foto = await this.fotos.findOne({
      where: { id: fotoId, avaliacaoId },
      relations: { avaliacao: true },
    });
    if (foto === null || foto.avaliacao === null) throw fotoNaoEncontrada();
    const avaliacao = foto.avaliacao;
    const podeVer =
      avaliacao.moderacaoStatus === AvaliacaoModeracaoStatus.Aprovada ||
      (user !== null &&
        (avaliacao.avaliadorId === user.id ||
          user.tipo === UsuarioTipo.Administrador));
    if (!podeVer) throw fotoNaoEncontrada();
    return this.fotoStorage.carregar(foto.referenciaArquivo);
  }

  async listarModeracao(query: Record<string, unknown>) {
    const status = query.status === 'todas'
      ? null
      : query.status === undefined || query.status === ''
      ? AvaliacaoModeracaoStatus.Pendente
      : optionalEnumFilter(query, 'status', Object.values(AvaliacaoModeracaoStatus));
    const termo = optionalSearchTerm(query);
    const pagination = parsePaginationQuery(query, { defaultLimit: 20, maxLimit: 100 });
    const builder = this.avaliacoes
      .createQueryBuilder('avaliacao')
      .leftJoinAndSelect('avaliacao.avaliador', 'avaliador')
      .leftJoinAndSelect('avaliacao.avaliado', 'avaliado')
      .leftJoinAndSelect('avaliacao.solicitacao', 'solicitacao')
      .leftJoinAndSelect('avaliacao.fotos', 'foto')
      .orderBy('avaliacao.criadoEm', 'DESC')
      .addOrderBy('avaliacao.id', 'DESC')
      .skip(pagination.skip)
      .take(pagination.limite);
    if (status !== null) {
      builder.andWhere('avaliacao.moderacaoStatus = :status', { status });
    }
    if (termo !== null) {
      builder.andWhere(
        '(avaliacao.comentario LIKE :termo OR avaliador.nome LIKE :termo OR avaliado.nome LIKE :termo)',
        { termo: `%${termo}%` },
      );
    }
    const [avaliacoes, total] = await builder.getManyAndCount();
    return {
      paginacao: paginationMetadata(pagination, total),
      avaliacoes: avaliacoes.map(avaliacaoResponse),
    };
  }

  async moderar(user: AuthenticatedUser, id: number, body: unknown) {
    const status = parseModeracaoStatus(body);
    await this.avaliacoes.manager.transaction(async (manager) => {
      const avaliacoes = manager.getRepository(AvaliacaoEntity);
      const avaliacao = await avaliacoes.findOne({
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      if (avaliacao === null) {
        throw new NotFoundException({
          code: 'AVALIACAO_NAO_ENCONTRADA',
          message: 'Avaliacao nao encontrada.',
        });
      }

      const statusAnterior = avaliacao.moderacaoStatus;
      avaliacao.moderacaoStatus = status;
      await avaliacoes.save(avaliacao);
      await registrarAuditoriaAdmin(manager, {
        atorId: user.id,
        acao: AdminAuditoriaAcao.AvaliacaoModerada,
        alvoTipo: 'avaliacao',
        alvoId: avaliacao.id,
        detalhe: {
          solicitacaoId: avaliacao.solicitacaoId,
          avaliadorId: avaliacao.avaliadorId,
          avaliadoId: avaliacao.avaliadoId,
          nota: avaliacao.nota,
          comentarioPresente: avaliacao.comentario !== null,
          status: { antes: statusAnterior, depois: avaliacao.moderacaoStatus },
        },
      });
    });

    const saved = await this.avaliacoes.findOne({
      where: { id },
      relations: { avaliador: true, avaliado: true, fotos: true },
    });
    if (saved === null) {
      throw new NotFoundException({
        code: 'AVALIACAO_NAO_ENCONTRADA',
        message: 'Avaliacao nao encontrada.',
      });
    }
    return { avaliacao: avaliacaoResponse(saved) };
  }

  private async criarAvaliacao(
    solicitacao: SolicitacaoEntity,
    avaliadorId: number,
    avaliadoId: number,
    body: unknown,
    aceitarFotos: boolean,
  ) {
    if (solicitacao.status !== SolicitacaoStatus.ConclusaoConfirmada) {
      throw badRequest('AVALIACAO_INDISPONIVEL');
    }

    const input = parseAvaliacao(body);
    if (!aceitarFotos && input.fotoIds.length > 0) {
      throw badRequest('FOTOS_AVALIACAO_NAO_PERMITIDAS');
    }

    try {
      const savedId = await this.avaliacoes.manager.transaction(async (manager) => {
        const pedidos = manager.getRepository(SolicitacaoEntity);
        const atual = await pedidos.findOne({
          where: { id: solicitacao.id },
          lock: { mode: 'pessimistic_write' },
        });
        const perfilProfissional = atual === null
          ? null
          : await manager.getRepository(ProfissionalPerfilEntity).findOne({
              where: { id: atual.profissionalId },
            });
        const ehClienteAvaliandoProfissional =
          atual !== null &&
          perfilProfissional !== null &&
          avaliadorId === atual.clienteId &&
          avaliadoId === perfilProfissional.usuarioId;
        const ehProfissionalAvaliandoCliente =
          atual !== null &&
          perfilProfissional !== null &&
          perfilProfissional.usuarioId === avaliadorId &&
          avaliadoId === atual.clienteId;
        if (
          atual === null ||
          atual.status !== SolicitacaoStatus.ConclusaoConfirmada ||
          (!ehClienteAvaliandoProfissional && !ehProfissionalAvaliandoCliente) ||
          (input.fotoIds.length > 0 && !ehClienteAvaliandoProfissional)
        ) {
          throw badRequest('AVALIACAO_INDISPONIVEL');
        }

        const avaliacoes = manager.getRepository(AvaliacaoEntity);
        const criada = await avaliacoes.save(
          avaliacoes.create({
            solicitacaoId: solicitacao.id,
            avaliadorId,
            avaliadoId,
            nota: input.nota,
            comentario: input.comentario,
            moderacaoStatus: AvaliacaoModeracaoStatus.Pendente,
          }),
        );

        if (input.fotoIds.length > 0) {
          const fotos = manager.getRepository(AvaliacaoFotoEntity);
          const anexos = await fotos.find({
            where: {
              id: In(input.fotoIds),
              solicitacaoId: solicitacao.id,
              enviadoPorId: avaliadorId,
              avaliacaoId: IsNull(),
              expiraEm: MoreThan(new Date()),
            },
            lock: { mode: 'pessimistic_write' },
          });
          if (
            anexos.length !== input.fotoIds.length ||
            anexos.some((foto) => foto.mimeType !== 'image/jpeg' || !foto.pronto)
          ) {
            throw badRequest('FOTOS_AVALIACAO_INVALIDAS');
          }
          await fotos.update(
            { id: In(input.fotoIds), avaliacaoId: IsNull() },
            { avaliacaoId: criada.id, expiraEm: null },
          );
        }
        return criada.id;
      });
      const reloaded = await this.avaliacoes.findOne({
        where: { id: savedId },
        relations: { avaliador: true, avaliado: true, fotos: true },
      });
      if (reloaded === null) {
        throw new Error('Saved review could not be reloaded.');
      }
      await this.notificarSeguro({
        usuarioId: avaliadoId,
        tipo: NotificacaoTipo.AvaliacaoRecebida,
        titulo: 'Nova avaliacao recebida',
        mensagem: 'Voce recebeu uma avaliacao de um atendimento concluido.',
        recursoTipo: 'solicitacao',
        recursoId: solicitacao.id,
      });
      return { avaliacao: avaliacaoResponse(reloaded) };
    } catch (error) {
      if (isDuplicateError(error)) {
        throw new ConflictException({
          code: 'AVALIACAO_JA_REGISTRADA',
          message: 'Avaliacao ja registrada para este atendimento.',
        });
      }
      throw error;
    }
  }

  private async verificarImagemMaliciosa(bytes: Buffer): Promise<void> {
    try {
      const resultado = await this.malwareScanner.scanBuffer(bytes);
      if (!resultado.clean) throw badRequest('AMEACA_FOTO_AVALIACAO_DETECTADA');
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      throw new ServiceUnavailableException({
        code: 'VERIFICACAO_SEGURANCA_INDISPONIVEL',
        message: 'A verificacao de seguranca esta indisponivel.',
      });
    }
  }

  private async carregarSolicitacao(id: number): Promise<SolicitacaoEntity> {
    const solicitacao = await this.solicitacoes.findOne({
      where: { id },
      relations: { cliente: true, profissional: { usuario: true } },
    });
    if (solicitacao === null) {
      throw new NotFoundException({
        code: 'SOLICITACAO_NAO_ENCONTRADA',
        message: 'Solicitacao nao encontrada.',
      });
    }

    return solicitacao;
  }

  private async notificarSeguro(input: Parameters<NotificacoesService['criar']>[0]) {
    try {
      await this.notificacoes.criar(input);
    } catch {
      // Falha de notificacao nao altera registro de avaliacao.
    }
  }
}

function avaliacaoResponse(avaliacao: AvaliacaoEntity) {
  return {
    id: avaliacao.id,
    solicitacaoId: avaliacao.solicitacaoId,
    avaliador: {
      id: avaliacao.avaliador.id,
      nome: avaliacao.avaliador.nome,
      tipo: avaliacao.avaliador.tipo,
    },
    avaliado: {
      id: avaliacao.avaliado.id,
      nome: avaliacao.avaliado.nome,
      tipo: avaliacao.avaliado.tipo,
    },
    nota: avaliacao.nota,
    comentario: avaliacao.comentario,
    fotos: (avaliacao.fotos ?? []).map((foto) => ({
      id: foto.id,
      url: `avaliacoes/${avaliacao.id}/fotos/${foto.id}`,
    })),
    moderacaoStatus: avaliacao.moderacaoStatus,
    criadoEm: avaliacao.criadoEm.toISOString(),
    atualizadoEm: avaliacao.atualizadoEm.toISOString(),
  };
}

function assinaturaImagemValida(bytes: Buffer, mimetype: string): boolean {
  const tipoDeclarado =
    mimetype === 'application/octet-stream' ||
    ['image/jpeg', 'image/png', 'image/webp'].includes(mimetype);
  if (!tipoDeclarado) return false;
  const jpeg = bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const png =
    bytes.length >= 8 &&
    bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  const webp =
    bytes.length >= 12 &&
    bytes.toString('ascii', 0, 4) === 'RIFF' &&
    bytes.toString('ascii', 8, 12) === 'WEBP';
  if (mimetype === 'image/jpeg') return jpeg;
  if (mimetype === 'image/png') return png;
  if (mimetype === 'image/webp') return webp;
  return jpeg || png || webp;
}

async function normalizarImagem(bytes: Buffer): Promise<Buffer> {
  try {
    const opcoes = { limitInputPixels: 16_000_000, failOn: 'warning' as const };
    const metadata = await sharp(bytes, opcoes).metadata();
    if (
      !['jpeg', 'png', 'webp'].includes(metadata.format ?? '') ||
      (metadata.pages ?? 1) !== 1 ||
      metadata.width === undefined ||
      metadata.height === undefined ||
      metadata.width < 1 ||
      metadata.height < 1
    ) {
      throw badRequest('FOTO_AVALIACAO_INVALIDA');
    }
    const normalized = await sharp(bytes, opcoes)
      .rotate()
      .resize({ width: 1600, height: 1600, fit: 'inside', withoutEnlargement: true })
      .flatten({ background: '#ffffff' })
      .jpeg({ quality: 82, mozjpeg: true })
      .toBuffer();
    if (normalized.length === 0 || normalized.length > 2 * 1024 * 1024) {
      throw badRequest('FOTO_AVALIACAO_INVALIDA');
    }
    return normalized;
  } catch (error) {
    if (error instanceof BadRequestException) throw error;
    throw badRequest('FOTO_AVALIACAO_INVALIDA');
  }
}

function fotoNaoEncontrada(): NotFoundException {
  return new NotFoundException({
    code: 'FOTO_AVALIACAO_INDISPONIVEL',
    message: 'Foto da avaliacao indisponivel.',
  });
}

function assertParticipante(
  user: AuthenticatedUser,
  solicitacao: SolicitacaoEntity,
): void {
  if (user.tipo === UsuarioTipo.Administrador) {
    return;
  }
  if (user.tipo === UsuarioTipo.Cliente && solicitacao.clienteId === user.id) {
    return;
  }
  if (
    [UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(user.tipo) &&
    solicitacao.profissional.usuarioId === user.id
  ) {
    return;
  }

  throw forbidden();
}

function assertClienteParticipante(
  user: AuthenticatedUser,
  solicitacao: SolicitacaoEntity,
): void {
  if (user.tipo === UsuarioTipo.Cliente && solicitacao.clienteId === user.id) {
    return;
  }

  throw forbidden();
}

function assertProfissionalParticipante(
  user: AuthenticatedUser,
  solicitacao: SolicitacaoEntity,
): void {
  if (
    [UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(user.tipo) &&
    solicitacao.profissional.usuarioId === user.id
  ) {
    return;
  }

  throw forbidden();
}

function parseAvaliacao(body: unknown): {
  readonly nota: number;
  readonly comentario: string | null;
  readonly fotoIds: number[];
} {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw badRequest('CORPO_INVALIDO');
  }

  const value = body as Record<string, unknown>;
  const nota = value.nota;
  if (typeof nota !== 'number' || !Number.isInteger(nota) || nota < 1 || nota > 5) {
    throw badRequest('NOTA_INVALIDA');
  }
  const fotoIds = value.fotoIds ?? [];
  if (
    !Array.isArray(fotoIds) ||
    fotoIds.length > maxFotosPorAvaliacao ||
    fotoIds.some(
      (id) =>
        typeof id !== 'number' ||
        !Number.isSafeInteger(id) ||
        id < 1 ||
        id > 2_147_483_647,
    ) ||
    new Set(fotoIds).size !== fotoIds.length
  ) {
    throw badRequest('FOTOS_AVALIACAO_INVALIDAS');
  }

  const comentario = value.comentario;
  if (comentario === undefined || comentario === null || comentario === '') {
    return { nota, comentario: null, fotoIds };
  }
  if (typeof comentario !== 'string') {
    throw badRequest('COMENTARIO_INVALIDO');
  }

  const text = comentario.trim();
  if (text.length > 600) {
    throw badRequest('COMENTARIO_INVALIDO');
  }

  return { nota, comentario: text.length === 0 ? null : text, fotoIds };
}

function parseModeracaoStatus(body: unknown): AvaliacaoModeracaoStatus {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw badRequest('CORPO_INVALIDO');
  }

  const status = (body as Record<string, unknown>).moderacaoStatus;
  if (
    status === AvaliacaoModeracaoStatus.Aprovada ||
    status === AvaliacaoModeracaoStatus.Rejeitada ||
    status === AvaliacaoModeracaoStatus.Pendente
  ) {
    return status;
  }

  throw badRequest('MODERACAO_INVALIDA');
}

function isDuplicateError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { readonly code?: unknown }).code === 'ER_DUP_ENTRY'
  );
}

function forbidden(): ForbiddenException {
  return new ForbiddenException({
    code: 'ACESSO_NEGADO',
    message: 'Usuario sem permissao para este recurso.',
  });
}

function badRequest(code: string): BadRequestException {
  return new BadRequestException({
    code,
    message: 'Dados invalidos.',
  });
}
