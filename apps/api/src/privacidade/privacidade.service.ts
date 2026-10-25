import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { DataSource, In, Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { PasswordService } from '../auth/password.service.js';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { AvaliacaoEntity } from '../database/entities/avaliacao.entity.js';
import { ClienteEnderecoEntity } from '../database/entities/cliente-endereco.entity.js';
import { ClientePerfilEntity } from '../database/entities/cliente-perfil.entity.js';
import { DenunciaEntity } from '../database/entities/denuncia.entity.js';
import { FavoritoProfissionalEntity } from '../database/entities/favorito-profissional.entity.js';
import { MensagemAtendimentoEntity } from '../database/entities/mensagem-atendimento.entity.js';
import { NotificacaoEntity } from '../database/entities/notificacao.entity.js';
import {
  PrivacidadeSolicitacaoEntity,
  PrivacidadeSolicitacaoStatus,
  PrivacidadeSolicitacaoTipo,
} from '../database/entities/privacidade-solicitacao.entity.js';
import { ProfissionalDisponibilidadeEntity } from '../database/entities/profissional-disponibilidade.entity.js';
import { ProfissionalDocumentoVerificacaoEntity } from '../database/entities/profissional-documento-verificacao.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { ProfissionalServicoEntity } from '../database/entities/profissional-servico.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { SolicitacaoOrcamentoEntity } from '../database/entities/solicitacao-orcamento.entity.js';
import { TermoAceiteEntity } from '../database/entities/termo-aceite.entity.js';
import { UsuarioEmailVerificacaoEntity } from '../database/entities/usuario-email-verificacao.entity.js';
import { UsuarioSenhaResetEntity } from '../database/entities/usuario-senha-reset.entity.js';
import { ProfissionalTelefoneVerificacaoEntity } from '../database/entities/profissional-telefone-verificacao.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { SolicitacaoStatus } from '../domain/solicitacao-status.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import {
  carregarFotoPerfil,
  removerFotoPerfilArquivo,
} from '../usuarios/foto-perfil.storage.js';
import { DocumentoStorageService } from '../verificacao/documento-storage.service.js';

interface CredencialInput {
  readonly senhaAtual: string;
}

interface ExclusaoInput extends CredencialInput {
  readonly confirmacao: string;
}

@Injectable()
export class PrivacidadeService {
  private readonly logger = new Logger(PrivacidadeService.name);

  constructor(
    private readonly dataSource: DataSource,
    private readonly passwordService: PasswordService,
    private readonly documentoStorage: DocumentoStorageService,
    @InjectRepository(PrivacidadeSolicitacaoEntity)
    private readonly solicitacoesPrivacidade: Repository<PrivacidadeSolicitacaoEntity>,
  ) {}

  async exportarDados(user: AuthenticatedUser, body: unknown) {
    const input = parseCredencial(body);
    const usuario = await this.carregarUsuarioComSenha(user.id);
    await this.validarSenha(usuario, input.senhaAtual);

    const solicitacao = await this.solicitacoesPrivacidade.save(
      this.solicitacoesPrivacidade.create({
        usuarioId: usuario.id,
        tipo: PrivacidadeSolicitacaoTipo.Exportacao,
        status: PrivacidadeSolicitacaoStatus.Processando,
        concluidaEm: null,
      }),
    );

    try {
      const dados = await this.montarExportacao(usuario);
      solicitacao.status = PrivacidadeSolicitacaoStatus.Concluida;
      solicitacao.concluidaEm = new Date();
      await this.solicitacoesPrivacidade.save(solicitacao);
      return {
        nomeArquivo: `conectalar-dados-${usuario.id}-${dataArquivo(new Date())}.json`,
        mimeType: 'application/json',
        dados,
      };
    } catch (error) {
      solicitacao.status = PrivacidadeSolicitacaoStatus.Falhou;
      await this.solicitacoesPrivacidade.save(solicitacao);
      throw error;
    }
  }

  async excluirConta(user: AuthenticatedUser, body: unknown) {
    const input = parseExclusao(body);
    const arquivosDocumentos: string[] = [];
    let fotoPerfil: string | null = null;

    await this.dataSource.transaction('READ COMMITTED', async (manager) => {
      const usuario = await manager
        .createQueryBuilder(UsuarioEntity, 'usuario')
        .addSelect('usuario.senhaHash')
        .where('usuario.id = :id', { id: user.id })
        .andWhere('usuario.ativo = true')
        .setLock('pessimistic_write')
        .getOne();
      if (usuario === null) throw naoAutenticado();
      await this.validarSenha(usuario, input.senhaAtual);
      if (usuario.tipo === UsuarioTipo.Administrador) {
        throw new ForbiddenException({
          code: 'EXCLUSAO_ADMIN_NAO_PERMITIDA',
          message:
            'Contas administrativas devem ser desativadas por outro administrador.',
        });
      }

      const profissional = await manager.findOne(ProfissionalPerfilEntity, {
        where: { usuarioId: usuario.id },
      });
      const atendimentosAtivos = await manager
        .createQueryBuilder(SolicitacaoEntity, 'solicitacao')
        .where('solicitacao.status IN (:...status)', {
          status: [
            SolicitacaoStatus.AguardandoResposta,
            SolicitacaoStatus.AceitaAgendada,
            SolicitacaoStatus.ConclusaoPendente,
            SolicitacaoStatus.ConclusaoContestada,
            SolicitacaoStatus.NaoComparecimentoInformado,
          ],
        })
        .andWhere(
          profissional === null
            ? 'solicitacao.cliente_id = :usuarioId'
            : '(solicitacao.cliente_id = :usuarioId OR solicitacao.profissional_id = :profissionalId)',
          { usuarioId: usuario.id, profissionalId: profissional?.id },
        )
        .getCount();
      if (atendimentosAtivos > 0) {
        throw new ConflictException({
          code: 'ATENDIMENTOS_ATIVOS',
          message:
            'Cancele ou conclua os atendimentos em aberto antes de excluir a conta.',
        });
      }

      const registro = manager.create(PrivacidadeSolicitacaoEntity, {
        usuarioId: usuario.id,
        tipo: PrivacidadeSolicitacaoTipo.Exclusao,
        status: PrivacidadeSolicitacaoStatus.Processando,
        concluidaEm: null,
      });
      await manager.save(PrivacidadeSolicitacaoEntity, registro);

      fotoPerfil = usuario.fotoPerfil;
      if (profissional !== null) {
        const documentos = await manager.find(
          ProfissionalDocumentoVerificacaoEntity,
          { where: { profissionalId: profissional.id } },
        );
        arquivosDocumentos.push(
          ...documentos.map((documento) => documento.referenciaArquivo),
        );
        const documentoIds = documentos.map((documento) => documento.id);
        if (documentoIds.length > 0) {
          await manager.update(
            AdminAuditoriaEntity,
            {
              alvoTipo: 'documento_verificacao',
              alvoId: In(documentoIds),
            },
            { detalhe: null },
          );
        }
        await manager.delete(ProfissionalDocumentoVerificacaoEntity, {
          profissionalId: profissional.id,
        });
        await manager.delete(ProfissionalDisponibilidadeEntity, {
          profissionalId: profissional.id,
        });
        await manager.delete(FavoritoProfissionalEntity, {
          profissionalId: profissional.id,
        });
        await manager.update(
          ProfissionalServicoEntity,
          { profissionalId: profissional.id },
          {
            nome: 'Servico removido',
            precoInicial: null,
            categoriaId: null,
            ativo: false,
          },
        );
        await manager.update(
          ProfissionalPerfilEntity,
          { id: profissional.id },
          {
            descricao: 'Perfil excluido pelo titular.',
            bairro: 'Nao informado',
            cep: null,
            cidade: null,
            uf: null,
            latitude: null,
            longitude: null,
            precisaoGeografica: null,
            precoInicial: null,
            verificado: false,
            ativo: false,
          },
        );
      }

      await manager.update(
        ClientePerfilEntity,
        { usuarioId: usuario.id },
        {
          bairroPrincipal: null,
          cidade: null,
          uf: null,
          observacoes: null,
        },
      );
      await manager.update(
        ClienteEnderecoEntity,
        { usuarioId: usuario.id },
        {
          apelido: 'Endereco removido',
          cep: null,
          logradouro: 'Dado removido',
          numero: 'S/N',
          complemento: null,
          bairro: 'Nao informado',
          cidade: 'Nao informado',
          uf: 'NA',
          latitude: null,
          longitude: null,
          precisaoGeografica: null,
          principal: false,
          ativo: false,
        },
      );
      await manager.update(
        SolicitacaoEntity,
        { clienteId: usuario.id },
        { descricao: 'Conteudo removido pelo titular.', bairroAtendimento: 'Nao informado' },
      );
      await manager.update(
        MensagemAtendimentoEntity,
        { autorId: usuario.id },
        { conteudo: 'Mensagem removida pelo titular.' },
      );
      await manager.update(
        AvaliacaoEntity,
        { avaliadorId: usuario.id },
        { comentario: null },
      );
      await manager.update(
        AvaliacaoEntity,
        { avaliadoId: usuario.id },
        { comentario: null },
      );
      await manager.update(
        DenunciaEntity,
        { denuncianteId: usuario.id },
        {
          motivo: 'Conteudo removido',
          descricao: 'Conteudo removido pelo titular.',
        },
      );
      await manager.update(
        DenunciaEntity,
        { denunciadoId: usuario.id },
        { decisao: 'Detalhes removidos apos exclusao de conta.' },
      );
      await manager.update(
        AdminAuditoriaEntity,
        { alvoTipo: 'usuario', alvoId: usuario.id },
        { detalhe: null },
      );
      await manager.delete(FavoritoProfissionalEntity, {
        clienteId: usuario.id,
      });
      await manager.delete(NotificacaoEntity, { usuarioId: usuario.id });
      await manager.delete(UsuarioSenhaResetEntity, { usuarioId: usuario.id });
      await manager.delete(UsuarioEmailVerificacaoEntity, {
        usuarioId: usuario.id,
      });
      await manager.delete(ProfissionalTelefoneVerificacaoEntity, {
        usuarioId: usuario.id,
      });

      await manager.update(
        UsuarioEntity,
        { id: usuario.id },
        {
          nome: 'Usuario excluido',
          email: emailAnonimo(usuario.id),
          emailVerificado: false,
          googleSub: null,
          telefone: null,
          telefoneNormalizado: null,
          fotoPerfil: null,
          senhaHash: await this.passwordService.hash(randomUUID()),
          ativo: false,
          tokenVersion: usuario.tokenVersion + 1,
          mfaAtivo: false,
          mfaSecretEncrypted: null,
        },
      );
      registro.status = PrivacidadeSolicitacaoStatus.Concluida;
      registro.concluidaEm = new Date();
      await manager.save(PrivacidadeSolicitacaoEntity, registro);
    });

    await removerArquivosPrivados(
      fotoPerfil,
      arquivosDocumentos,
      this.documentoStorage,
      this.logger,
    );
    return {
      ok: true,
      contaExcluida: true,
      message:
        'Conta excluida e dados pessoais removidos. Registros minimos podem ser mantidos de forma anonimizada para seguranca e obrigacoes legais.',
    };
  }

  private async carregarUsuarioComSenha(id: number): Promise<UsuarioEntity> {
    const usuario = await this.dataSource
      .getRepository(UsuarioEntity)
      .createQueryBuilder('usuario')
      .addSelect('usuario.senhaHash')
      .where('usuario.id = :id', { id })
      .andWhere('usuario.ativo = true')
      .getOne();
    if (usuario === null) throw naoAutenticado();
    return usuario;
  }

  private async validarSenha(
    usuario: UsuarioEntity,
    senhaAtual: string,
  ): Promise<void> {
    if (!(await this.passwordService.verify(senhaAtual, usuario.senhaHash))) {
      throw new UnauthorizedException({
        code: 'SENHA_ATUAL_INVALIDA',
        message: 'Senha atual incorreta.',
      });
    }
  }

  private async montarExportacao(usuario: UsuarioEntity) {
    const manager = this.dataSource.manager;
    const [cliente, enderecos, profissional, notificacoes, favoritos, termos, verificacoesTelefone] =
      await Promise.all([
        manager.findOne(ClientePerfilEntity, {
          where: { usuarioId: usuario.id },
        }),
        manager.find(ClienteEnderecoEntity, {
          where: { usuarioId: usuario.id },
          order: { id: 'ASC' },
        }),
        manager.findOne(ProfissionalPerfilEntity, {
          where: { usuarioId: usuario.id },
        }),
        manager.find(NotificacaoEntity, {
          where: { usuarioId: usuario.id },
          order: { criadoEm: 'DESC' },
        }),
        manager.find(FavoritoProfissionalEntity, {
          where: { clienteId: usuario.id },
          order: { criadoEm: 'DESC' },
        }),
        manager.find(TermoAceiteEntity, {
          where: { usuarioId: usuario.id },
          order: { aceitoEm: 'DESC' },
        }),
        manager.find(ProfissionalTelefoneVerificacaoEntity, {
          where: { usuarioId: usuario.id },
          order: { criadoEm: 'DESC' },
        }),
      ]);

    const [servicos, disponibilidades, documentos] = profissional === null
      ? [[], [], []] as const
      : await Promise.all([
          manager.find(ProfissionalServicoEntity, {
            where: { profissionalId: profissional.id },
            order: { id: 'ASC' },
          }),
          manager.find(ProfissionalDisponibilidadeEntity, {
            where: { profissionalId: profissional.id },
            order: { diaSemana: 'ASC', horaInicio: 'ASC' },
          }),
          manager.find(ProfissionalDocumentoVerificacaoEntity, {
            where: { profissionalId: profissional.id },
            order: { criadoEm: 'DESC' },
          }),
        ]);

    const solicitacoesBuilder = manager
      .createQueryBuilder(SolicitacaoEntity, 'solicitacao')
      .where('solicitacao.cliente_id = :usuarioId', {
        usuarioId: usuario.id,
      });
    if (profissional !== null) {
      solicitacoesBuilder.orWhere(
        'solicitacao.profissional_id = :profissionalId',
        { profissionalId: profissional.id },
      );
    }
    const solicitacoes = await solicitacoesBuilder
      .orderBy('solicitacao.criado_em', 'DESC')
      .getMany();
    const solicitacaoIds = solicitacoes.map((item) => item.id);

    const [mensagens, avaliacoes, denuncias, orcamentos, historicoPrivacidade] =
      await Promise.all([
        solicitacaoIds.length === 0
          ? []
          : manager.find(MensagemAtendimentoEntity, {
              where: { solicitacaoId: In(solicitacaoIds), autorId: usuario.id },
              order: { criadoEm: 'ASC' },
            }),
        manager
          .createQueryBuilder(AvaliacaoEntity, 'avaliacao')
          .where('avaliacao.avaliador_id = :usuarioId', {
            usuarioId: usuario.id,
          })
          .orWhere('avaliacao.avaliado_id = :usuarioId', {
            usuarioId: usuario.id,
          })
          .orderBy('avaliacao.criado_em', 'DESC')
          .getMany(),
        manager
          .createQueryBuilder(DenunciaEntity, 'denuncia')
          .where('denuncia.denunciante_id = :usuarioId', {
            usuarioId: usuario.id,
          })
          .orWhere('denuncia.denunciado_id = :usuarioId', {
            usuarioId: usuario.id,
          })
          .orderBy('denuncia.criado_em', 'DESC')
          .getMany(),
        solicitacaoIds.length === 0
          ? []
          : manager.find(SolicitacaoOrcamentoEntity, {
              where: { solicitacaoId: In(solicitacaoIds) },
              order: { criadoEm: 'ASC' },
            }),
        manager.find(PrivacidadeSolicitacaoEntity, {
          where: { usuarioId: usuario.id },
          order: { criadoEm: 'DESC' },
        }),
      ]);

    return {
      formato: 'ConectaLar LGPD v1',
      geradoEm: new Date().toISOString(),
      aviso:
        'Este arquivo contem dados pessoais. Guarde-o em local seguro. Senhas, tokens e segredos de autenticacao nunca sao exportados.',
      conta: {
        id: usuario.id,
        nome: usuario.nome,
        email: usuario.email,
        emailVerificado: usuario.emailVerificado,
        autenticacaoGoogle: {
          vinculada: usuario.googleSub !== null,
          identificador: usuario.googleSub,
        },
        telefone: usuario.telefone,
        tipo: usuario.tipo,
        ativo: usuario.ativo,
        criadoEm: iso(usuario.criadoEm),
        atualizadoEm: iso(usuario.atualizadoEm),
        foto: await exportarFoto(usuario.fotoPerfil),
      },
      perfilCliente: cliente === null ? null : semRelacoes(cliente),
      enderecos: enderecos.map(semRelacoes),
      perfilProfissional:
        profissional === null
          ? null
          : {
              ...semRelacoes(profissional),
              servicos: servicos.map(semRelacoes),
              disponibilidades: disponibilidades.map(semRelacoes),
              documentos: await Promise.all(
                documentos.map((documento) =>
                  this.exportarDocumento(documento),
                ),
              ),
            },
      solicitacoes: solicitacoes.map((item) => ({
        ...semRelacoes(item),
        papelDoTitular:
          item.clienteId === usuario.id ? 'cliente' : 'profissional',
        enderecoId: item.clienteId === usuario.id ? item.enderecoId : null,
      })),
      mensagensEnviadas: mensagens.map(semRelacoes),
      orcamentosDeAtendimentos: orcamentos.map(semRelacoes),
      avaliacoes: avaliacoes.map((item) => ({
        ...semRelacoes(item),
        relacao:
          item.avaliadorId === usuario.id ? 'enviada' : 'recebida',
        avaliadorId: item.avaliadorId === usuario.id ? usuario.id : null,
        avaliadoId: item.avaliadoId === usuario.id ? usuario.id : null,
      })),
      denuncias: denuncias.map((item) => ({
        ...semRelacoes(item),
        relacao:
          item.denuncianteId === usuario.id ? 'enviada' : 'recebida',
        denuncianteId:
          item.denuncianteId === usuario.id ? usuario.id : null,
        denunciadoId: item.denunciadoId === usuario.id ? usuario.id : null,
        analisadoPorId: null,
      })),
      notificacoes: notificacoes.map(semRelacoes),
      favoritos: favoritos.map(semRelacoes),
      aceitesDeTermos: termos.map(semRelacoes),
      verificacoesTelefone: verificacoesTelefone.map((item) => ({
        telefoneVinculado: `+55${item.telefoneVinculado}`,
        estado: item.estado,
        consentimentoEm: iso(item.consentimentoEm),
        versaoAviso: item.versaoAviso,
        tentativasRestantes: item.tentativasRestantes,
        expiraEm: iso(item.expiraEm),
        resolvidaEm: iso(item.resolvidaEm),
        criadoEm: iso(item.criadoEm),
      })),
      solicitacoesDePrivacidade: historicoPrivacidade.map(semRelacoes),
    };
  }

  private async exportarDocumento(
    documento: ProfissionalDocumentoVerificacaoEntity,
  ) {
    try {
      const arquivo = await this.documentoStorage.carregar(
        documento.id,
        documento.referenciaArquivo,
        documento.nomeArquivo,
      );
      return {
        ...semRelacoes(documento),
        referenciaArquivo: undefined,
        analisadoPorId: null,
        arquivo: {
          nome: arquivo.nomeSeguro,
          mimeType: arquivo.mimeType,
          conteudoBase64: arquivo.bytes.toString('base64'),
        },
      };
    } catch {
      return {
        ...semRelacoes(documento),
        referenciaArquivo: undefined,
        analisadoPorId: null,
        arquivo: null,
        avisoArquivo: 'Arquivo indisponivel no momento da exportacao.',
      };
    }
  }
}

function parseCredencial(body: unknown): CredencialInput {
  const value = objectBody(body);
  return { senhaAtual: senhaAtual(value.senhaAtual) };
}

function parseExclusao(body: unknown): ExclusaoInput {
  const value = objectBody(body);
  const confirmacao =
    typeof value.confirmacao === 'string' ? value.confirmacao.trim() : '';
  if (confirmacao !== 'EXCLUIR') {
    throw new BadRequestException({
      code: 'CONFIRMACAO_EXCLUSAO_INVALIDA',
      message: 'Digite EXCLUIR para confirmar a exclusao permanente.',
    });
  }
  return { senhaAtual: senhaAtual(value.senhaAtual), confirmacao };
}

function objectBody(body: unknown): Record<string, unknown> {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw dadosInvalidos();
  }
  return body as Record<string, unknown>;
}

function senhaAtual(value: unknown): string {
  if (typeof value !== 'string' || value.length < 8 || value.length > 200) {
    throw dadosInvalidos();
  }
  return value;
}

function dadosInvalidos(): BadRequestException {
  return new BadRequestException({
    code: 'DADOS_INVALIDOS',
    message: 'Confira os dados informados.',
  });
}

function naoAutenticado(): UnauthorizedException {
  return new UnauthorizedException({
    code: 'NAO_AUTENTICADO',
    message: 'Autenticacao obrigatoria.',
  });
}

function emailAnonimo(usuarioId: number): string {
  const sufixo = randomUUID().replaceAll('-', '').slice(0, 16);
  return `excluido+${usuarioId}+${sufixo}@anonimo.invalid`;
}

function dataArquivo(data: Date): string {
  return data.toISOString().slice(0, 10);
}

function iso(value: Date | string | null): string | null {
  if (value === null) return null;
  return value instanceof Date ? value.toISOString() : value;
}

function semRelacoes<T extends object>(value: T): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [key, item] of Object.entries(value)) {
    if (typeof item === 'function') continue;
    if (item instanceof Date) result[key] = item.toISOString();
    else if (
      item === null ||
      ['string', 'number', 'boolean'].includes(typeof item)
    ) {
      result[key] = item;
    }
  }
  return result;
}

async function exportarFoto(referencia: string | null) {
  if (referencia === null) return null;
  try {
    const arquivo = await carregarFotoPerfil(referencia);
    return {
      mimeType: arquivo.mimeType,
      conteudoBase64: (await readFile(arquivo.caminho)).toString('base64'),
    };
  } catch {
    return { indisponivel: true };
  }
}

async function removerArquivosPrivados(
  fotoPerfil: string | null,
  documentos: readonly string[],
  storage: DocumentoStorageService,
  logger: Logger,
): Promise<void> {
  const resultados = await Promise.allSettled([
    removerFotoPerfilArquivo(fotoPerfil),
    ...documentos.map((referencia) => storage.remover(referencia)),
  ]);
  const falhas = resultados.filter((resultado) => resultado.status === 'rejected');
  if (falhas.length > 0) {
    logger.warn(
      `${falhas.length} arquivo(s) anonimizado(s) no banco aguardam limpeza do armazenamento.`,
    );
  }
}
