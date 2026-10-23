import {
  BadRequestException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { ProfissionalDocumentoVerificacaoEntity } from '../database/entities/profissional-documento-verificacao.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { AdminAuditoriaAcao } from '../domain/admin-auditoria-acao.js';
import { DocumentoVerificacaoStatus } from '../domain/documento-verificacao-status.js';
import { NotificacaoTipo } from '../domain/notificacao-tipo.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { NotificacoesService } from '../notificacoes/notificacoes.service.js';
import { DocumentoStorageService } from './documento-storage.service.js';
import { MalwareScannerService } from './malware-scanner.service.js';
import { habilitacaoProfissional } from './habilitacao-profissional.js';

interface EnviarDocumentoInput {
  readonly tipoDocumento: string;
  readonly referenciaArquivo: string | null;
  readonly arquivoBase64: string | null;
  readonly mimeType: string | null;
  readonly nomeArquivo: string | null;
  readonly observacao: string | null;
}

const maxDocumentoBytes = 5 * 1024 * 1024;
const tipoDocumentoIdentidade = 'documento_identidade';

interface AnaliseDocumentoInput {
  readonly status:
    | DocumentoVerificacaoStatus.Aprovado
    | DocumentoVerificacaoStatus.Rejeitado;
  readonly motivoRejeicao: string | null;
}

@Injectable()
export class VerificacaoService {
  constructor(
    @InjectRepository(AdminAuditoriaEntity)
    private readonly auditoria: Repository<AdminAuditoriaEntity>,
    @InjectRepository(ProfissionalDocumentoVerificacaoEntity)
    private readonly documentos: Repository<ProfissionalDocumentoVerificacaoEntity>,
    @InjectRepository(ProfissionalPerfilEntity)
    private readonly perfis: Repository<ProfissionalPerfilEntity>,
    private readonly notificacoes: NotificacoesService,
    private readonly storage: DocumentoStorageService,
    private readonly malwareScanner: MalwareScannerService,
  ) {}

  async enviarMeuDocumento(user: AuthenticatedUser, body: unknown) {
    const input = parseEnvioDocumento(body);
    const perfil = await this.perfis.findOne({
      where: { usuarioId: user.id, ativo: true },
      relations: { usuario: true },
    });

    if (
      perfil === null ||
      ![UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(
        perfil.usuario.tipo,
      )
    ) {
      throw new BadRequestException({
        code: 'PERFIL_PROFISSIONAL_OBRIGATORIO',
        message: 'Cadastre o perfil profissional antes de enviar documentos.',
      });
    }

    const referenciaArquivo = await resolverReferenciaArquivo(
      perfil.id,
      input,
      this.malwareScanner,
      this.storage,
    );
    const documento = await this.documentos.save(
      this.documentos.create({
        profissionalId: perfil.id,
        enviadoPorId: user.id,
        tipoDocumento: input.tipoDocumento,
        referenciaArquivo,
        nomeArquivo: input.nomeArquivo,
        observacao: input.observacao,
        status: DocumentoVerificacaoStatus.Pendente,
        motivoRejeicao: null,
        analisadoPorId: null,
        analisadoEm: null,
      }),
    );

    return { documento: documentoResponse(documento) };
  }

  async listarMeusDocumentos(user: AuthenticatedUser) {
    const perfil = await this.perfis.findOne({
      where: { usuarioId: user.id, ativo: true },
      relations: { usuario: true },
    });
    if (perfil === null) {
      return { documentos: [], habilitacao: habilitacaoProfissional(null) };
    }

    const documentos = await this.documentos.find({
      where: { profissionalId: perfil.id },
      order: { criadoEm: 'DESC' },
      take: 50,
    });

    return { documentos: documentos.map(documentoResponse), habilitacao: habilitacaoProfissional(perfil) };
  }

  async listarParaAnalise(query: Record<string, unknown>) {
    const status = optionalStatus(query.status);
    const documentos = await this.documentos.find({
      where: status === null ? {} : { status },
      relations: { profissional: { usuario: true }, enviadoPor: true },
      order: { criadoEm: 'DESC' },
      take: 100,
    });

    return { documentos: documentos.map(documentoAdminResponse) };
  }

  async arquivoParaAnalise(id: number) {
    const documento = await this.documentos.findOne({ where: { id } });
    if (documento === null) {
      throw new NotFoundException({
        code: 'DOCUMENTO_NAO_ENCONTRADO',
        message: 'Documento de verificacao nao encontrado.',
      });
    }

    return this.storage.carregar(
      documento.id,
      documento.referenciaArquivo,
      documento.nomeArquivo,
    );
  }

  async analisarDocumento(
    user: AuthenticatedUser,
    id: number,
    body: unknown,
  ) {
    const input = parseAnaliseDocumento(body);
    const documento = await this.documentos.findOne({
      where: { id },
      relations: { profissional: { usuario: true }, enviadoPor: true },
    });

    if (documento === null) {
      throw new NotFoundException({
        code: 'DOCUMENTO_NAO_ENCONTRADO',
        message: 'Documento de verificacao nao encontrado.',
      });
    }

    documento.status = input.status;
    documento.motivoRejeicao = input.motivoRejeicao;
    documento.analisadoPorId = user.id;
    documento.analisadoEm = new Date();
    const saved = await this.documentos.save(documento);

    documento.profissional.verificado =
      await this.profissionalTemIdentidadeAprovada(documento.profissionalId);
    // Do not overwrite a concurrent security suspension with this older
    // profile snapshot loaded for document moderation.
    await this.perfis.update(documento.profissionalId, {
      verificado: documento.profissional.verificado,
    });

    await this.registrarAuditoria(
      user.id,
      saved.id,
      `Resultado: ${saved.status}`,
    );
    await this.notificarResultadoSeguro(
      saved,
      documento.profissional.usuarioId,
      documento.profissional.verificado,
    );

    saved.profissional = documento.profissional;
    saved.enviadoPor = documento.enviadoPor;
    return { documento: documentoAdminResponse(saved) };
  }

  private async registrarAuditoria(
    atorId: number,
    alvoId: number,
    detalhe: string,
  ) {
    await this.auditoria.save(
      this.auditoria.create({
        atorId,
        acao: AdminAuditoriaAcao.DocumentoAnalisado,
        alvoTipo: 'documento_verificacao',
        alvoId,
        detalhe,
      }),
    );
  }

  private async notificarResultadoSeguro(
    documento: ProfissionalDocumentoVerificacaoEntity,
    usuarioId: number,
    seloAtivo: boolean,
  ) {
    const aprovado = documento.status === DocumentoVerificacaoStatus.Aprovado;
    const ativouSelo =
      aprovado &&
      seloAtivo &&
      documento.tipoDocumento === tipoDocumentoIdentidade;
    try {
      await this.notificacoes.criar({
        usuarioId,
        tipo: aprovado
          ? NotificacaoTipo.DocumentoAprovado
          : NotificacaoTipo.DocumentoRejeitado,
        titulo: aprovado ? 'Documento aprovado' : 'Documento precisa de ajuste',
        mensagem: aprovado
          ? ativouSelo
            ? 'Seu selo de verificacao foi ativado pela administracao. A analise documental nao libera atendimentos; a habilitacao de seguranca continua pendente.'
            : 'Seu documento foi aprovado pela administracao.'
          : 'Revise o motivo informado e envie uma nova verificacao.',
        recursoTipo: 'documento_verificacao',
        recursoId: documento.id,
      });
    } catch {
      // Falha de notificacao nao pode reverter analise documental.
    }
  }

  private async profissionalTemIdentidadeAprovada(profissionalId: number) {
    const total = await this.documentos.count({
      where: {
        profissionalId,
        tipoDocumento: tipoDocumentoIdentidade,
        status: DocumentoVerificacaoStatus.Aprovado,
      },
    });
    return total > 0;
  }
}

function parseEnvioDocumento(body: unknown): EnviarDocumentoInput {
  const value = objectBody(body);
  const tipoDocumento = textField(value, 'tipoDocumento', 3, 60);
  if (!['documento_identidade', 'comprovante_endereco', 'certificado_opcional', 'certificado_curso'].includes(tipoDocumento)) {
    throw badRequest('TIPO_DOCUMENTO_NAO_PERMITIDO');
  }
  const referenciaArquivo = optionalText(value.referenciaArquivo, 180);
  const arquivoBase64 = optionalText(value.arquivoBase64, 8_000_000);
  const mimeType = optionalText(value.mimeType, 80);

  if (referenciaArquivo !== null && /^https?:\/\//i.test(referenciaArquivo)) {
    throw badRequest('REFERENCIA_ARQUIVO_INVALIDA');
  }
  if (referenciaArquivo === null && arquivoBase64 === null) {
    throw badRequest('DOCUMENTO_OBRIGATORIO');
  }
  if (arquivoBase64 !== null && !mimePermitido(mimeType)) {
    throw badRequest('TIPO_ARQUIVO_INVALIDO');
  }
  const nomeArquivo = optionalText(value.nomeArquivo, 180);
  if (
    arquivoBase64 !== null &&
    !nomeArquivoCompativelComMime(nomeArquivo, mimeType)
  ) {
    throw badRequest('NOME_ARQUIVO_INVALIDO');
  }

  return {
    tipoDocumento,
    referenciaArquivo,
    arquivoBase64,
    mimeType,
    nomeArquivo,
    observacao: optionalText(value.observacao, 600),
  };
}

async function resolverReferenciaArquivo(
  profissionalId: number,
  input: EnviarDocumentoInput,
  malwareScanner: MalwareScannerService,
  storage: DocumentoStorageService,
): Promise<string> {
  if (input.arquivoBase64 === null) {
    if (input.referenciaArquivo === null) {
      throw badRequest('DOCUMENTO_OBRIGATORIO');
    }
    if (malwareScanner.required()) {
      throw badRequest('VARREDURA_DOCUMENTO_OBRIGATORIA');
    }
    return input.referenciaArquivo;
  }

  const conteudo = Buffer.from(input.arquivoBase64, 'base64');
  if (
    conteudo.length === 0 ||
    conteudo.length > maxDocumentoBytes ||
    conteudo.toString('base64').replace(/=+$/u, '') !==
      input.arquivoBase64.replace(/\s/g, '').replace(/=+$/u, '')
  ) {
    throw badRequest('ARQUIVO_INVALIDO');
  }
  if (!assinaturaCompativelComMime(conteudo, input.mimeType)) {
    throw badRequest('ASSINATURA_ARQUIVO_INVALIDA');
  }
  let scan;
  try {
    scan = await malwareScanner.scanBuffer(conteudo);
  } catch {
    throw new ServiceUnavailableException({
      code: 'VERIFICACAO_SEGURANCA_INDISPONIVEL',
      message: 'A verificacao de seguranca esta indisponivel.',
    });
  }
  if (!scan.clean) {
    throw badRequest('AMEACA_DOCUMENTO_DETECTADA');
  }

  if (input.mimeType === null) throw badRequest('TIPO_ARQUIVO_INVALIDO');
  return storage.salvar(profissionalId, conteudo, input.mimeType);
}

function mimePermitido(value: string | null): boolean {
  return extensaoMime(value) !== null;
}

function extensaoMime(value: string | null): string | null {
  if (value === 'application/pdf') return '.pdf';
  if (value === 'image/jpeg') return '.jpg';
  if (value === 'image/png') return '.png';
  return null;
}

function nomeArquivoCompativelComMime(
  nomeArquivo: string | null,
  mimeType: string | null,
): boolean {
  if (nomeArquivo === null) return true;
  const nome = nomeArquivo.toLowerCase();
  if (/[\\/]/.test(nome)) return false;
  if (mimeType === 'application/pdf') return nome.endsWith('.pdf');
  if (mimeType === 'image/jpeg') {
    return nome.endsWith('.jpg') || nome.endsWith('.jpeg');
  }
  if (mimeType === 'image/png') return nome.endsWith('.png');
  return false;
}

function assinaturaCompativelComMime(
  conteudo: Buffer,
  mimeType: string | null,
): boolean {
  if (mimeType === 'application/pdf') {
    return conteudo.subarray(0, 5).equals(Buffer.from('%PDF-'));
  }
  if (mimeType === 'image/png') {
    return conteudo.subarray(0, 8).equals(
      Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    );
  }
  if (mimeType === 'image/jpeg') {
    return (
      conteudo.length >= 4 &&
      conteudo[0] === 0xff &&
      conteudo[1] === 0xd8 &&
      conteudo[2] === 0xff
    );
  }
  return false;
}

function parseAnaliseDocumento(body: unknown): AnaliseDocumentoInput {
  const value = objectBody(body);
  if (
    value.status !== DocumentoVerificacaoStatus.Aprovado &&
    value.status !== DocumentoVerificacaoStatus.Rejeitado
  ) {
    throw badRequest('STATUS_ANALISE_INVALIDO');
  }

  const motivoRejeicao = optionalText(value.motivoRejeicao, 600);
  if (
    value.status === DocumentoVerificacaoStatus.Rejeitado &&
    motivoRejeicao === null
  ) {
    throw badRequest('MOTIVO_REJEICAO_OBRIGATORIO');
  }

  return {
    status: value.status,
    motivoRejeicao:
      value.status === DocumentoVerificacaoStatus.Rejeitado
        ? motivoRejeicao
        : null,
  };
}

function documentoResponse(documento: ProfissionalDocumentoVerificacaoEntity) {
  return {
    id: documento.id,
    profissionalId: documento.profissionalId,
    tipoDocumento: documento.tipoDocumento,
    referenciaArquivo: documento.referenciaArquivo,
    nomeArquivo: documento.nomeArquivo,
    observacao: documento.observacao,
    status: documento.status,
    motivoRejeicao: documento.motivoRejeicao,
    analisadoEm: documento.analisadoEm?.toISOString() ?? null,
    criadoEm: documento.criadoEm.toISOString(),
    atualizadoEm: documento.atualizadoEm.toISOString(),
  };
}

function documentoAdminResponse(
  documento: ProfissionalDocumentoVerificacaoEntity,
) {
  return {
    ...documentoResponse(documento),
    enviadoPorId: documento.enviadoPorId,
    analisadoPorId: documento.analisadoPorId,
    profissional:
      documento.profissional === undefined
        ? undefined
        : {
            id: documento.profissional.id,
            usuarioId: documento.profissional.usuarioId,
            nome: documento.profissional.usuario?.nome,
            verificado: documento.profissional.verificado,
          },
  };
}

function optionalStatus(value: unknown): DocumentoVerificacaoStatus | null {
  if (value === undefined || value === null || value === '') return null;
  if (
    value === DocumentoVerificacaoStatus.Pendente ||
    value === DocumentoVerificacaoStatus.Aprovado ||
    value === DocumentoVerificacaoStatus.Rejeitado
  ) {
    return value;
  }

  throw badRequest('STATUS_INVALIDO');
}

function objectBody(body: unknown): Record<string, unknown> {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw badRequest('CORPO_INVALIDO');
  }

  return body as Record<string, unknown>;
}

function textField(
  value: Record<string, unknown>,
  key: string,
  min: number,
  max: number,
): string {
  const field = value[key];
  if (typeof field !== 'string') {
    throw badRequest('CAMPO_INVALIDO');
  }

  const text = field.trim();
  if (text.length < min || text.length > max) {
    throw badRequest('CAMPO_INVALIDO');
  }

  return text;
}

function optionalText(value: unknown, max: number): string | null {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string') throw badRequest('CAMPO_INVALIDO');
  const text = value.trim();
  if (text.length === 0) return null;
  if (text.length > max) throw badRequest('CAMPO_INVALIDO');
  return text;
}

function badRequest(code: string): BadRequestException {
  return new BadRequestException({
    code,
    message: 'Dados invalidos.',
  });
}
