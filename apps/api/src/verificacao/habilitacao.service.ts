import { BadRequestException, ConflictException, ForbiddenException, HttpException, HttpStatus, Injectable, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { createHmac, randomInt, randomUUID, timingSafeEqual } from 'node:crypto';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { registrarAuditoriaAdmin } from '../common/admin-auditoria.js';
import { optionalSearchTerm } from '../common/admin-list-query.js';
import { paginationMetadata, parsePaginationQuery } from '../common/pagination.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { ProfissionalIdentidadeVerificacaoEntity } from '../database/entities/profissional-identidade-verificacao.entity.js';
import { ProfissionalTelefoneVerificacaoEntity } from '../database/entities/profissional-telefone-verificacao.entity.js';
import { ProfissionalDocumentoVerificacaoEntity } from '../database/entities/profissional-documento-verificacao.entity.js';
import { AdminAuditoriaAcao } from '../domain/admin-auditoria-acao.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { habilitacaoManualLocalAtiva, habilitacaoProfissional } from './habilitacao-profissional.js';
import { IdZapSignProvider } from './id-zapsign.provider.js';

@Injectable()
export class HabilitacaoService {
  constructor(
    @InjectRepository(ProfissionalPerfilEntity) private readonly perfis: Repository<ProfissionalPerfilEntity>,
    @InjectRepository(UsuarioEntity) private readonly usuarios: Repository<UsuarioEntity>,
    @InjectRepository(ProfissionalIdentidadeVerificacaoEntity) private readonly identidades: Repository<ProfissionalIdentidadeVerificacaoEntity> | undefined = undefined,
    private readonly identidade: IdZapSignProvider = new IdZapSignProvider(),
    @InjectRepository(ProfissionalTelefoneVerificacaoEntity) private readonly telefones: Repository<ProfissionalTelefoneVerificacaoEntity> | undefined = undefined,
    @InjectRepository(ProfissionalDocumentoVerificacaoEntity) private readonly documentos: Repository<ProfissionalDocumentoVerificacaoEntity> | undefined = undefined,
  ) {}

  async minha(user: AuthenticatedUser) {
    this.exigirProfissional(user);
    const perfil = await this.perfis.findOne({ where: { usuarioId: user.id }, relations: { usuario: true } });
    const identidade = perfil ? await this.identidades?.findOne({
      where: { usuarioId: user.id }, order: { criadoEm: 'DESC' },
    }) : null;
    const telefone = perfil ? await this.telefones?.findOne({
      where: { usuarioId: user.id }, order: { criadoEm: 'DESC' },
    }) : null;
    return { habilitacao: habilitacaoProfissional(
      perfil,
      etapaIdentidade(identidade?.estado),
      etapaTelefone(telefone, perfil?.usuario?.telefoneNormalizado, telefoneConfigurado()),
    ) };
  }

  async iniciarTelefone(user: AuthenticatedUser, body: unknown) {
    this.exigirProfissional(user);
    const input = corpo(body, ['consentimento']);
    if (input.consentimento !== true) throw invalido();
    if (!this.identidade.telefoneDisponivel || !this.telefones) throw telefoneIndisponivel();

    const inicio = await this.telefones.manager.transaction(async (manager) => {
      const usuario = await manager.findOne(UsuarioEntity, {
        where: { id: user.id, ativo: true }, lock: { mode: 'pessimistic_write' },
      });
      if (!usuario || !usuario.telefoneNormalizado) throw telefoneAusente();
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { usuarioId: user.id, ativo: true },
      });
      if (!perfil) throw naoEncontrado();

      const repo = manager.getRepository(ProfissionalTelefoneVerificacaoEntity);
      const ultima = await repo.findOne({
        where: { usuarioId: user.id },
        order: { criadoEm: 'DESC' },
        lock: { mode: 'pessimistic_write' },
      });
      const now = new Date();
      if (ultima && ultima.telefoneVinculado !== usuario.telefoneNormalizado &&
        !['invalidada', 'expirada', 'falha'].includes(ultima.estado)) {
        ultima.estado = 'invalidada';
        ultima.resolvidaEm = now;
        ultima.tentativaEmAndamento = false;
        await repo.save(ultima);
      }
      if (ultima?.telefoneVinculado === usuario.telefoneNormalizado && ultima.estado === 'confirmada') {
        return { verificacao: ultima, iniciar: false };
      }
      if (ultima?.telefoneVinculado === usuario.telefoneNormalizado &&
        (ultima.estado === 'pendente' || ultima.estado === 'iniciando')) {
        if (ultima.estado === 'pendente' && ultima.expiraEm && ultima.expiraEm > now) {
          return { verificacao: ultima, iniciar: false };
        }
        if (ultima.estado === 'iniciando' && ultima.chaveIdempotencia) {
          return { verificacao: ultima, iniciar: true };
        }
        ultima.estado = 'expirada';
        ultima.resolvidaEm = now;
        await repo.save(ultima);
      }

      const desde = new Date(now.getTime() - 24 * 60 * 60_000);
      const recentes = await repo.createQueryBuilder('verificacao')
        .where('verificacao.usuarioId = :usuarioId', { usuarioId: user.id })
        .andWhere('verificacao.criadoEm >= :desde', { desde })
        .getCount();
      if (recentes >= 3) throw new HttpException({
        code: 'LIMITE_VERIFICACAO_TELEFONE',
        message: 'Limite diario de verificacoes atingido. Tente novamente mais tarde.',
      }, HttpStatus.TOO_MANY_REQUESTS);
      if (ultima && now.getTime() - ultima.criadoEm.getTime() < 10 * 60_000) {
        throw new ConflictException({
          code: 'AGUARDE_NOVA_VERIFICACAO_TELEFONE',
          message: 'Aguarde alguns minutos antes de solicitar outro codigo.',
        });
      }
      const verificacao = await repo.save(repo.create({
        usuarioId: user.id,
        telefoneVinculado: usuario.telefoneNormalizado,
        referencia: null,
        referenciaExterna: randomUUID(),
        chaveIdempotencia: randomUUID(),
        tentativaId: null,
        chaveIdempotenciaTentativa: null,
        tentativaEmAndamento: false,
        consentimentoEm: now,
        versaoAviso: 'conectalar-telefone-whatsapp-v1',
        estado: 'iniciando',
        tentativasRestantes: null,
        expiraEm: null,
        resolvidaEm: null,
      }));
      return { verificacao, iniciar: true };
    });

    const verificacao = inicio.verificacao;
    if (!inicio.iniciar) {
      const usuario = await this.usuarios.findOneBy({ id: user.id, ativo: true });
      return { telefone: respostaTelefone(verificacao, true, usuario?.telefoneNormalizado) };
    }
    if (!verificacao.chaveIdempotencia) throw telefoneIndisponivel();
    const criada = await this.identidade.iniciarPosseTelefone({
      telefoneE164: `+55${verificacao.telefoneVinculado}`,
      referenciaExterna: verificacao.referenciaExterna,
      chaveIdempotencia: verificacao.chaveIdempotencia,
    });
    const persistida = await this.telefones.manager.transaction(async (manager) => {
      const usuario = await manager.findOne(UsuarioEntity, {
        where: { id: user.id, ativo: true }, lock: { mode: 'pessimistic_write' },
      });
      const repo = manager.getRepository(ProfissionalTelefoneVerificacaoEntity);
      const atual = await repo.findOne({
        where: { id: verificacao.id, usuarioId: user.id }, lock: { mode: 'pessimistic_write' },
      });
      if (!usuario || !atual || usuario.telefoneNormalizado !== atual.telefoneVinculado) {
        if (atual) {
          atual.estado = 'invalidada';
          atual.resolvidaEm = new Date();
          atual.tentativaEmAndamento = false;
          await repo.save(atual);
        }
        return { invalidada: true, atual };
      }
      atual.referencia = criada.referencia;
      atual.chaveIdempotencia = null;
      atual.estado = 'pendente';
      atual.tentativasRestantes = criada.tentativasRestantes;
      atual.expiraEm = criada.expiraEm;
      await repo.save(atual);
      return { invalidada: false, atual };
    });
    if (persistida.invalidada || !persistida.atual) throw new ConflictException({
      code: 'TELEFONE_ALTERADO', message: 'O telefone mudou. Inicie uma nova confirmacao.',
    });
    const usuario = await this.usuarios.findOneBy({ id: user.id, ativo: true });
    return { telefone: respostaTelefone(persistida.atual, true, usuario?.telefoneNormalizado) };
  }

  async iniciarTelefoneManual(user: AuthenticatedUser, body: unknown) {
    this.exigirProfissional(user);
    const input = corpo(body, ['consentimento']);
    if (input.consentimento !== true) throw invalido();
    const numeroOficial = numeroWhatsAppManual();
    if (!numeroOficial || !this.telefones || !segredoCodigoConfigurado()) {
      throw telefoneManualIndisponivel();
    }

    const criado = await this.telefones.manager.transaction(async (manager) => {
      const usuario = await manager.findOne(UsuarioEntity, {
        where: { id: user.id, ativo: true }, lock: { mode: 'pessimistic_write' },
      });
      if (!usuario?.telefoneNormalizado) throw telefoneAusente();
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { usuarioId: user.id, ativo: true },
      });
      if (!perfil) throw naoEncontrado();

      const repo = manager.getRepository(ProfissionalTelefoneVerificacaoEntity);
      const ultima = await repo.findOne({
        where: { usuarioId: user.id }, order: { criadoEm: 'DESC' },
        lock: { mode: 'pessimistic_write' },
      });
      const now = new Date();
      if (ultima && ultima.telefoneVinculado !== usuario.telefoneNormalizado &&
        !['invalidada', 'expirada', 'falha'].includes(ultima.estado)) {
        ultima.estado = 'invalidada';
        ultima.codigoHash = null;
        ultima.resolvidaEm = now;
        await repo.save(ultima);
      }
      if (ultima?.telefoneVinculado === usuario.telefoneNormalizado && ultima.estado === 'confirmada') {
        return { verificacao: ultima, codigo: null, jaConfirmado: true };
      }
      if (ultima?.telefoneVinculado === usuario.telefoneNormalizado &&
        ultima.metodo === 'whatsapp_manual' && ultima.estado === 'pendente' &&
        ultima.expiraEm && ultima.expiraEm > now) {
        return { verificacao: ultima, codigo: null, jaConfirmado: false };
      }
      if (ultima?.telefoneVinculado === usuario.telefoneNormalizado &&
        ultima.estado === 'pendente' && ultima.expiraEm && ultima.expiraEm > now) {
        throw new ConflictException({
          code: 'OUTRA_VERIFICACAO_TELEFONE_PENDENTE',
          message: 'Ja existe outra confirmacao de telefone pendente. Aguarde ou conclua a atual.',
        });
      }
      if (ultima?.estado === 'pendente' || ultima?.estado === 'iniciando') {
        ultima.estado = 'expirada';
        ultima.codigoHash = null;
        ultima.resolvidaEm = now;
        await repo.save(ultima);
      }

      const desde = new Date(now.getTime() - 24 * 60 * 60_000);
      const recentes = await repo.createQueryBuilder('verificacao')
        .where('verificacao.usuarioId = :usuarioId', { usuarioId: user.id })
        .andWhere('verificacao.criadoEm >= :desde', { desde })
        .getCount();
      if (recentes >= 3) throw limiteTelefone();
      if (ultima && now.getTime() - ultima.criadoEm.getTime() < 10 * 60_000) {
        throw new ConflictException({
          code: 'AGUARDE_NOVA_VERIFICACAO_TELEFONE',
          message: 'Aguarde alguns minutos antes de solicitar outro desafio.',
        });
      }

      const codigo = randomInt(0, 100_000_000).toString().padStart(8, '0');
      const referenciaExterna = randomUUID();
      const expiraEm = new Date(now.getTime() + 10 * 60_000);
      const verificacao = await repo.save(repo.create({
        usuarioId: user.id,
        telefoneVinculado: usuario.telefoneNormalizado,
        metodo: 'whatsapp_manual',
        codigoHash: hashDesafioTelefone(referenciaExterna, codigo),
        referencia: null,
        referenciaExterna,
        chaveIdempotencia: null,
        tentativaId: null,
        chaveIdempotenciaTentativa: null,
        tentativaEmAndamento: false,
        consentimentoEm: now,
        versaoAviso: 'conectalar-telefone-manual-v1',
        estado: 'pendente',
        tentativasRestantes: 5,
        expiraEm,
        resolvidaEm: null,
      }));
      return { verificacao, codigo, jaConfirmado: false };
    });

    const usuario = await this.usuarios.findOneBy({ id: user.id, ativo: true });
    const telefone = respostaTelefone(criado.verificacao, true, usuario?.telefoneNormalizado);
    telefone.metodo = criado.verificacao.metodo;
    telefone.whatsAppManualDisponivel = true;
    telefone.numeroWhatsAppManual = numeroOficial;
    if (criado.codigo) {
      telefone.codigo = criado.codigo;
      telefone.linkWhatsApp = linkWhatsApp(numeroOficial);
      telefone.codigoExibidoUmaVez = true;
    } else {
      telefone.codigoExibidoUmaVez = false;
      telefone.jaConfirmado = criado.jaConfirmado;
    }
    return { telefone };
  }

  async confirmarTelefoneManual(user: AuthenticatedUser, id: number, body: unknown) {
    await this.exigirAdminMfa(user);
    if (!numeroWhatsAppManual()) throw telefoneManualIndisponivel();
    const input = corpo(body, ['codigo', 'telefoneRemetente']);
    if (typeof input.codigo !== 'string' || !/^\d{8}$/.test(input.codigo) ||
      typeof input.telefoneRemetente !== 'string') throw invalido();
    const codigo = input.codigo as string;
    const telefoneRemetente = normalizarTelefoneRemetente(input.telefoneRemetente);
    if (!telefoneRemetente || !this.telefones) throw invalido();

    const resultado = await this.telefones.manager.transaction(async (manager) => {
      const admin = await manager.findOne(UsuarioEntity, {
        where: { id: user.id, ativo: true }, lock: { mode: 'pessimistic_write' },
      });
      if (!admin?.mfaAtivo || admin.tipo !== UsuarioTipo.Administrador) {
        throw new ForbiddenException({ code: 'MFA_ADMIN_OBRIGATORIO', message: 'Ative a verificacao em duas etapas para gerenciar habilitacoes.' });
      }
      const perfilInicial = await manager.findOne(ProfissionalPerfilEntity, { where: { id } });
      if (!perfilInicial || perfilInicial.usuarioId === user.id) throw naoEncontrado();
      // Keep lock order aligned with challenge creation: user, profile, verification.
      const usuario = await manager.findOne(UsuarioEntity, {
        where: { id: perfilInicial.usuarioId, ativo: true }, lock: { mode: 'pessimistic_write' },
      });
      if (!usuario?.telefoneNormalizado) throw telefoneAusente();
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { id }, lock: { mode: 'pessimistic_write' },
      });
      if (!perfil || perfil.usuarioId !== perfilInicial.usuarioId) throw naoEncontrado();
      const repo = manager.getRepository(ProfissionalTelefoneVerificacaoEntity);
      const verificacao = await repo.findOne({
        where: { usuarioId: perfil.usuarioId }, order: { criadoEm: 'DESC' },
        lock: { mode: 'pessimistic_write' },
      });
      const now = new Date();
      if (verificacao?.metodo === 'whatsapp_manual' && verificacao.estado === 'pendente' &&
        verificacao.expiraEm && verificacao.expiraEm <= now) {
        verificacao.estado = 'expirada';
        verificacao.codigoHash = null;
        verificacao.resolvidaEm = now;
        await repo.save(verificacao);
        return { invalido: false, esgotado: false, expirado: true };
      }
      if (!verificacao || verificacao.metodo !== 'whatsapp_manual' ||
        verificacao.estado !== 'pendente' || !verificacao.codigoHash ||
        !verificacao.expiraEm || verificacao.tentativasRestantes === null ||
        verificacao.tentativasRestantes < 1) {
        throw desafioTelefoneIndisponivel();
      }
      if (verificacao.telefoneVinculado !== usuario.telefoneNormalizado) {
        verificacao.estado = 'invalidada';
        verificacao.codigoHash = null;
        verificacao.resolvidaEm = now;
        await repo.save(verificacao);
        return { invalido: true, esgotado: false, expirado: false };
      }

      const codigoCorreto = compararHashDesafio(
        verificacao.referenciaExterna,
        codigo,
        verificacao.codigoHash,
      );
      const remetenteCorreto = telefoneRemetente === usuario.telefoneNormalizado;
      if (!codigoCorreto || !remetenteCorreto) {
        verificacao.tentativasRestantes -= 1;
        const esgotado = verificacao.tentativasRestantes === 0;
        if (esgotado) {
          verificacao.estado = 'falha';
          verificacao.codigoHash = null;
          verificacao.resolvidaEm = now;
        }
        await repo.save(verificacao);
        return { invalido: true, esgotado, expirado: false };
      }

      verificacao.estado = 'confirmada';
      verificacao.codigoHash = null;
      verificacao.tentativasRestantes = null;
      verificacao.resolvidaEm = now;
      await repo.save(verificacao);
      await registrarAuditoriaAdmin(manager, {
        atorId: user.id,
        acao: AdminAuditoriaAcao.TelefoneManualConfirmado,
        alvoTipo: 'profissional_telefone_verificacao',
        alvoId: verificacao.id,
        detalhe: {
          profissionalUsuarioId: perfil.usuarioId,
          metodo: 'whatsapp_manual',
          telefoneMascarado: mascararTelefone(usuario.telefoneNormalizado),
          estado: { antes: 'pendente', depois: 'confirmada' },
          confirmadoEm: now.toISOString(),
          telefoneRemetenteConferido: true,
          efeito: 'confirma_acesso_ao_whatsapp; nao_confirma_identidade_ou_habilitacao',
        },
      });
      return { invalido: false, esgotado: false, expirado: false, verificacao, telefoneAtual: usuario.telefoneNormalizado };
    });

    if (resultado.expirado) {
      throw new ConflictException({
        code: 'DESAFIO_TELEFONE_EXPIRADO',
        message: 'O desafio expirou. O profissional pode solicitar outro.',
      });
    }
    if (resultado.invalido) {
      throw new ConflictException({
        code: resultado.esgotado ? 'DESAFIO_TELEFONE_BLOQUEADO' : 'DESAFIO_TELEFONE_NAO_CONFIRMADO',
        message: resultado.esgotado
          ? 'Desafio bloqueado apos tentativas invalidas. O profissional deve solicitar outro.'
          : 'Nao foi possivel confirmar o desafio e o remetente. Confira os dados e tente novamente.',
      });
    }
    const telefone = respostaTelefone(resultado.verificacao!, true, resultado.telefoneAtual);
    telefone.metodo = 'whatsapp_manual';
    return { telefone };
  }

  async consultarTelefone(user: AuthenticatedUser) {
    this.exigirProfissional(user);
    if (!this.telefones) return { telefone: respostaTelefone(null, false) };
    const usuario = await this.usuarios.findOneBy({ id: user.id, ativo: true });
    if (!usuario) throw telefoneAusente();
    const verificacao = await this.telefones.findOne({
      where: { usuarioId: user.id }, order: { criadoEm: 'DESC' },
    });
    if (!verificacao) {
      const telefone = respostaTelefone(null, telefoneConfigurado(), usuario.telefoneNormalizado);
      telefone.whatsAppManualDisponivel = Boolean(numeroWhatsAppManual() && segredoCodigoConfigurado());
      telefone.numeroWhatsAppManual = numeroWhatsAppManual();
      return { telefone };
    }
    if (verificacao.telefoneVinculado !== usuario.telefoneNormalizado &&
      !['invalidada', 'expirada', 'falha'].includes(verificacao.estado)) {
      verificacao.estado = 'invalidada';
      verificacao.codigoHash = null;
      verificacao.resolvidaEm = new Date();
      verificacao.tentativaEmAndamento = false;
      await this.telefones.save(verificacao);
    }
    if (verificacao.estado === 'pendente' && verificacao.expiraEm && verificacao.expiraEm <= new Date()) {
      verificacao.estado = 'expirada';
      verificacao.codigoHash = null;
      verificacao.resolvidaEm = new Date();
      verificacao.tentativaEmAndamento = false;
      await this.telefones.save(verificacao);
    }
    const disponivel = telefoneConfigurado();
    const telefone = respostaTelefone(verificacao, disponivel, usuario.telefoneNormalizado);
    telefone.metodo = verificacao.metodo;
    telefone.whatsAppManualDisponivel = Boolean(numeroWhatsAppManual() && segredoCodigoConfigurado());
    telefone.numeroWhatsAppManual = numeroWhatsAppManual();
    return { telefone };
  }

  async confirmarTelefone(user: AuthenticatedUser, body: unknown) {
    this.exigirProfissional(user);
    const input = corpo(body, ['codigo', 'tentativaId']);
    if (typeof input.codigo !== 'string' || !/^\d{1,20}$/.test(input.codigo) ||
      typeof input.tentativaId !== 'string' ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(input.tentativaId)) {
      throw invalido();
    }
    const codigo = input.codigo;
    const tentativaId = input.tentativaId as string;
    if (!this.identidade.telefoneDisponivel || !this.telefones) throw telefoneIndisponivel();

    const preparado = await this.telefones.manager.transaction(async (manager) => {
      const usuario = await manager.findOne(UsuarioEntity, {
        where: { id: user.id, ativo: true }, lock: { mode: 'pessimistic_write' },
      });
      if (!usuario?.telefoneNormalizado) throw telefoneAusente();
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { usuarioId: user.id, ativo: true },
      });
      if (!perfil) throw naoEncontrado();
      const repo = manager.getRepository(ProfissionalTelefoneVerificacaoEntity);
      const verificacao = await repo.findOne({
        where: { usuarioId: user.id }, order: { criadoEm: 'DESC' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!verificacao) throw new ConflictException({
        code: 'VERIFICACAO_TELEFONE_NAO_INICIADA',
        message: 'Solicite primeiro o codigo de confirmacao.',
      });
      if (verificacao.telefoneVinculado !== usuario.telefoneNormalizado) {
        verificacao.estado = 'invalidada';
        verificacao.resolvidaEm = new Date();
        verificacao.tentativaEmAndamento = false;
        await repo.save(verificacao);
        return { verificacao, invalidada: true, enviar: false };
      }
      if (verificacao.tentativaId === tentativaId && !verificacao.tentativaEmAndamento) {
        return { verificacao, invalidada: false, enviar: false };
      }
      if (verificacao.tentativaEmAndamento && verificacao.tentativaId !== tentativaId) {
        throw new ConflictException({ code: 'VERIFICACAO_TELEFONE_EM_ANDAMENTO', message: 'Aguarde a tentativa atual terminar.' });
      }
      if (verificacao.estado !== 'pendente' || !verificacao.referencia || !verificacao.expiraEm ||
        verificacao.expiraEm <= new Date() || verificacao.tentativasRestantes === 0) {
        if (verificacao.estado === 'pendente' && verificacao.expiraEm && verificacao.expiraEm <= new Date()) {
          verificacao.estado = 'expirada';
          verificacao.resolvidaEm = new Date();
          await repo.save(verificacao);
        }
        throw new ConflictException({
          code: 'VERIFICACAO_TELEFONE_INDISPONIVEL',
          message: 'Esta confirmacao expirou ou nao aceita mais tentativas.',
        });
      }
      const repeticao = verificacao.tentativaId === tentativaId && verificacao.tentativaEmAndamento;
      if (!repeticao) {
        verificacao.tentativaId = tentativaId;
        verificacao.chaveIdempotenciaTentativa = randomUUID();
        verificacao.tentativaEmAndamento = true;
        await repo.save(verificacao);
      }
      if (!verificacao.chaveIdempotenciaTentativa) throw telefoneIndisponivel();
      return { verificacao, invalidada: false, enviar: true };
    });

    if (preparado.invalidada) throw new ConflictException({
      code: 'TELEFONE_ALTERADO', message: 'O telefone mudou. Inicie uma nova confirmacao.',
    });
    const verificacao = preparado.verificacao;
    if (!preparado.enviar) {
      const usuario = await this.usuarios.findOneBy({ id: user.id, ativo: true });
      return { telefone: respostaTelefone(verificacao, true, usuario?.telefoneNormalizado) };
    }
    const resultado = await this.identidade.confirmarPosseTelefone({
      referencia: verificacao.referencia!,
      referenciaExterna: verificacao.referenciaExterna,
      codigo,
      chaveIdempotencia: verificacao.chaveIdempotenciaTentativa!,
    });
    return this.telefones.manager.transaction(async (manager) => {
      const usuario = await manager.findOne(UsuarioEntity, {
        where: { id: user.id, ativo: true }, lock: { mode: 'pessimistic_write' },
      });
      const repo = manager.getRepository(ProfissionalTelefoneVerificacaoEntity);
      const atual = await repo.findOne({
        where: { id: verificacao.id, usuarioId: user.id }, lock: { mode: 'pessimistic_write' },
      });
      if (!usuario || !atual || usuario.telefoneNormalizado !== atual.telefoneVinculado) {
        if (atual) {
          atual.estado = 'invalidada';
          atual.resolvidaEm = new Date();
          atual.tentativaEmAndamento = false;
          await repo.save(atual);
        }
        return { invalidada: true, verificacao: atual };
      }
      atual.estado = resultado.status;
      atual.tentativasRestantes = resultado.tentativasRestantes;
      atual.expiraEm = resultado.expiraEm ?? atual.expiraEm;
      atual.resolvidaEm = resultado.resolvidaEm;
      atual.tentativaEmAndamento = false;
      await repo.save(atual);
      return { invalidada: false, verificacao: atual, telefoneAtual: usuario.telefoneNormalizado };
    }).then((final) => {
      if (final.invalidada || !final.verificacao) {
        throw new ConflictException({ code: 'TELEFONE_ALTERADO', message: 'O telefone mudou. Inicie uma nova confirmacao.' });
      }
      return { telefone: respostaTelefone(final.verificacao, true, final.telefoneAtual) };
    });
  }

  async iniciarIdentidade(user: AuthenticatedUser, body: unknown) {
    this.exigirProfissional(user);
    const input = corpo(body, ['consentimento']);
    if (!this.identidade.disponivel) throw identidadeIndisponivel();
    if (input.consentimento !== true) throw invalido();
    if (!this.identidades) throw identidadeIndisponivel();
    const verificacao = await this.identidades.manager.transaction(async (manager) => {
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { usuarioId: user.id, ativo: true }, lock: { mode: 'pessimistic_write' },
      });
      if (!perfil) throw naoEncontrado();
      const ativa = await manager.findOne(ProfissionalIdentidadeVerificacaoEntity, {
        where: [
          { usuarioId: user.id, estado: 'iniciando' },
          { usuarioId: user.id, estado: 'pendente' },
        ],
        order: { criadoEm: 'DESC' },
        lock: { mode: 'pessimistic_write' },
      });
      if (ativa) return ativa;
      const ultima = await manager.findOne(ProfissionalIdentidadeVerificacaoEntity, {
        where: { usuarioId: user.id }, order: { criadoEm: 'DESC' },
      });
      if (ultima?.estado === 'confirmada') {
        throw new ConflictException({ code: 'IDENTIDADE_JA_CONFIRMADA', message: 'Sua identidade ja foi confirmada.' });
      }
      if (ultima && Date.now() - ultima.criadoEm.getTime() < 10 * 60_000) {
        throw new ConflictException({ code: 'NOVA_VERIFICACAO_AGUARDE', message: 'Aguarde 10 minutos antes de iniciar outra verificacao.' });
      }
      return manager.save(ProfissionalIdentidadeVerificacaoEntity, manager.create(ProfissionalIdentidadeVerificacaoEntity, {
        usuarioId: user.id,
        referencia: null,
        referenciaExterna: randomUUID(),
        chaveIdempotencia: randomUUID(),
        consentimentoEm: new Date(),
        versaoAviso: 'conectalar-identidade-v1',
        estado: 'iniciando',
        expiraEm: null,
        resolvidaEm: null,
      }));
    });

    if (verificacao.referencia) return this.atualizarIdentidade(verificacao);
    if (!verificacao.chaveIdempotencia) throw identidadeIndisponivel();
    const criada = await this.identidade.iniciar({
      referenciaExterna: verificacao.referenciaExterna,
      chaveIdempotencia: verificacao.chaveIdempotencia,
    });
    verificacao.referencia = criada.referencia;
    verificacao.chaveIdempotencia = null;
    verificacao.estado = 'pendente';
    verificacao.expiraEm = criada.expiraEm;
    await this.identidades.save(verificacao);
    return { identidade: respostaIdentidade(verificacao, criada.url) };
  }

  async consultarIdentidade(user: AuthenticatedUser) {
    this.exigirProfissional(user);
    const identidades = this.identidades;
    if (!identidades) return { identidade: respostaIdentidade(null, null, false) };
    const verificacao = await identidades.findOne({
      where: { usuarioId: user.id }, order: { criadoEm: 'DESC' },
    });
    if (!verificacao) return { identidade: respostaIdentidade(null, null, this.identidade.disponivel) };
    if (!this.identidade.disponivel) {
      return { identidade: respostaIdentidade(verificacao, null, false) };
    }
    if (verificacao.estado === 'confirmada') return { identidade: respostaIdentidade(verificacao) };
    if (verificacao.estado === 'iniciando' && verificacao.chaveIdempotencia) {
      const criada = await this.identidade.iniciar({
        referenciaExterna: verificacao.referenciaExterna,
        chaveIdempotencia: verificacao.chaveIdempotencia,
      });
      verificacao.referencia = criada.referencia;
      verificacao.chaveIdempotencia = null;
      verificacao.estado = 'pendente';
      verificacao.expiraEm = criada.expiraEm;
      await identidades.save(verificacao);
      return { identidade: respostaIdentidade(verificacao, criada.url) };
    }
    if (verificacao.estado === 'pendente' && verificacao.referencia) {
      return this.atualizarIdentidade(verificacao);
    }
    return { identidade: respostaIdentidade(verificacao, null, this.identidade.disponivel) };
  }

  async solicitarRevisao(user: AuthenticatedUser, body: unknown) {
    this.exigirProfissional(user);
    corpo(body, []);
    await this.perfis.manager.transaction(async (manager) => {
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { usuarioId: user.id }, lock: { mode: 'pessimistic_write' },
      });
      if (!perfil) throw naoEncontrado();
      if (perfil.habilitacaoRevisaoEm) return;
      // An appeal must never lift a suspension or approve the applicant.
      perfil.habilitacaoRevisaoEm = new Date();
      await manager.save(ProfissionalPerfilEntity, perfil);
      await registrarAuditoriaAdmin(manager, {
        atorId: user.id,
        acao: AdminAuditoriaAcao.HabilitacaoRevisaoSolicitada,
        alvoTipo: 'habilitacao_profissional',
        alvoId: perfil.id,
        detalhe: {
          profissionalUsuarioId: perfil.usuarioId,
          revisaoSolicitadaEm: {
            antes: null,
            depois: perfil.habilitacaoRevisaoEm.toISOString(),
          },
          efeito: 'nao_altera_estado_de_aprovacao_ou_suspensao',
        },
      });
    });
    return this.minha(user);
  }

  async listar(user: AuthenticatedUser, query: Record<string, unknown>) {
    await this.exigirAdminMfa(user);
    let pagination: ReturnType<typeof parsePaginationQuery>;
    try {
      pagination = parsePaginationQuery(query, { defaultLimit: 20, maxLimit: 100 });
    } catch {
      throw invalido();
    }
    const termo = optionalSearchTerm(query);
    const estado = optionalEstadoHabilitacao(query.estado);
    const builder = this.perfis
      .createQueryBuilder('perfil')
      .leftJoinAndSelect('perfil.usuario', 'usuario')
      .orderBy('perfil.id', 'ASC')
      .skip(pagination.skip)
      .take(pagination.limite);
    if (estado !== null) builder.andWhere('perfil.habilitacaoEstado = :estado', { estado });
    if (termo !== null) {
      builder.andWhere('(usuario.nome LIKE :termo OR usuario.email LIKE :termo)', { termo: `%${termo}%` });
    }
    const [perfis, total] = await builder.getManyAndCount();
    return {
      pagina: pagination.pagina,
      total,
      paginacao: paginationMetadata(pagination, total),
      profissionais: await Promise.all(perfis.map(async (p) => {
      const identidade = await this.identidades?.findOne({ where: { usuarioId: p.usuarioId }, order: { criadoEm: 'DESC' } });
      const telefone = await this.telefones?.findOne({ where: { usuarioId: p.usuarioId }, order: { criadoEm: 'DESC' } });
      return {
        id: p.id,
        nome: p.usuario.nome,
        habilitacao: habilitacaoProfissional(
          p,
          etapaIdentidade(identidade?.estado),
          etapaTelefone(telefone, p.usuario.telefoneNormalizado, telefoneConfigurado()),
        ),
        telefoneVerificacao: telefone ? {
          metodo: telefone.metodo,
          estado: etapaTelefone(telefone, p.usuario.telefoneNormalizado, telefoneConfigurado()),
          expiraEm: telefone.expiraEm?.toISOString() ?? null,
          tentativasRestantes: telefone.metodo === 'whatsapp_manual' && telefone.estado === 'pendente'
            ? telefone.tentativasRestantes : null,
          telefoneMascarado: mascararTelefone(telefone.telefoneVinculado),
        } : null,
      };
      })),
    };
  }

  async dossie(user: AuthenticatedUser, id: number, query: Record<string, unknown>) {
    await this.exigirAdminMfa(user);
    if (!Number.isSafeInteger(id) || id < 1) throw invalido();
    const pagination = parsePaginationQuery(query, { defaultLimit: 20, maxLimit: 50 });
    const perfil = await this.perfis.findOne({
      where: { id }, relations: { usuario: true, servicos: { categoria: true } },
    });
    if (!perfil) throw naoEncontrado();
    const [identidade, telefone, resultadoDocumentos] = await Promise.all([
      this.identidades?.findOne({ where: { usuarioId: perfil.usuarioId }, order: { criadoEm: 'DESC' } }),
      this.telefones?.findOne({ where: { usuarioId: perfil.usuarioId }, order: { criadoEm: 'DESC' } }),
      this.documentos?.findAndCount({
        where: { profissionalId: id }, order: { criadoEm: 'DESC', id: 'DESC' },
        skip: pagination.skip, take: pagination.limite,
      }),
    ]);
    const [documentos, total] = resultadoDocumentos ?? [[], 0];
    return {
      profissional: {
        id: perfil.id,
        nome: perfil.usuario.nome,
        ativo: perfil.ativo,
        cidade: perfil.cidade,
        uf: perfil.uf,
        habilitacao: habilitacaoProfissional(
          perfil,
          etapaIdentidade(identidade?.estado),
          etapaTelefone(telefone, perfil.usuario.telefoneNormalizado, telefoneConfigurado()),
        ),
        telefoneVerificacao: telefone ? {
          metodo: telefone.metodo,
          estado: etapaTelefone(telefone, perfil.usuario.telefoneNormalizado, telefoneConfigurado()),
          telefoneMascarado: mascararTelefone(telefone.telefoneVinculado),
        } : null,
        ofertas: (perfil.servicos ?? []).map((servico) => ({
          id: servico.id, nome: servico.nome, ativo: servico.ativo,
          categoria: servico.categoria?.nome ?? null,
        })).sort((a, b) => a.id - b.id),
      },
      documentos: documentos.map((documento) => ({
        id: documento.id,
        tipoDocumento: documento.tipoDocumento,
        status: documento.status,
        motivoRejeicao: documento.motivoRejeicao,
        criadoEm: documento.criadoEm,
        analisadoEm: documento.analisadoEm,
      })),
      paginacao: paginationMetadata(pagination, total),
    };
  }

  async analisar(user: AuthenticatedUser, id: number, body: unknown) {
    await this.exigirAdminMfa(user);
    const input = corpo(body, ['acao', 'motivo']);
    if (input.acao === 'aprovar_teste_local' && !habilitacaoManualLocalAtiva()) {
      throw new ConflictException({ code: 'HABILITACAO_TESTE_LOCAL_INDISPONIVEL',
        message: 'A habilitacao manual de teste esta desativada neste ambiente.' });
    }
    if (input.acao === 'aprovar') {
      throw new ConflictException({ code: 'HABILITACAO_DEPENDENCIAS_PENDENTES',
        message: 'Aprovacao indisponivel: faltam integracoes de identidade, telefone e politica de antecedentes.' });
    }
    if (typeof input.acao !== 'string' || !['suspender', 'iniciar_analise', 'reabrir', 'aprovar_teste_local'].includes(input.acao)) throw invalido();
    if (typeof input.motivo !== 'string' || !['revisao_cadastral', 'suspeita_fraude', 'solicitacao_titular', 'teste_fluxo_local'].includes(input.motivo)) throw invalido();
    if (input.acao === 'aprovar_teste_local' && input.motivo !== 'teste_fluxo_local') throw invalido();
    const perfil = await this.perfis.manager.transaction(async (manager) => {
      const perfil = await manager.findOne(ProfissionalPerfilEntity, {
        where: { id }, lock: { mode: 'pessimistic_write' },
      });
      if (!perfil) throw naoEncontrado();
      if (perfil.usuarioId === user.id) throw new ForbiddenException();
      if (input.acao === 'aprovar_teste_local' && !habilitacaoManualLocalAtiva()) {
        throw new ConflictException({ code: 'HABILITACAO_TESTE_LOCAL_INDISPONIVEL',
          message: 'A habilitacao manual de teste esta desativada neste ambiente.' });
      }
      if (perfil.habilitacaoEstado === 'suspenso' && input.acao === 'iniciar_analise') {
        throw new ConflictException({ code: 'HABILITACAO_SUSPENSA', message: 'Reabra a analise antes de continuar.' });
      }
      const estadoAnterior = perfil.habilitacaoEstado;
      const revisaoAnterior = perfil.habilitacaoRevisaoEm;
      perfil.habilitacaoEstado = input.acao === 'aprovar_teste_local' ? 'teste_local_aprovado'
        : input.acao === 'suspender' ? 'suspenso'
        : input.acao === 'iniciar_analise' ? 'em_analise' : 'pendente';
      perfil.habilitacaoRevisaoEm = null;
      await manager.save(ProfissionalPerfilEntity, perfil);
      await registrarAuditoriaAdmin(manager, {
        atorId: user.id,
        acao: AdminAuditoriaAcao.HabilitacaoAnalisada,
        alvoTipo: 'habilitacao_profissional',
        alvoId: perfil.id,
        detalhe: {
          profissionalUsuarioId: perfil.usuarioId,
          estado: { antes: estadoAnterior, depois: perfil.habilitacaoEstado },
          revisaoSolicitadaEm: {
            antes: revisaoAnterior?.toISOString() ?? null,
            depois: null,
          },
          acao: input.acao,
          motivo: input.motivo,
          aprovacaoConcedida: input.acao === 'aprovar_teste_local',
          somenteTesteLocal: input.acao === 'aprovar_teste_local',
        },
      });
      return perfil;
    });
    perfil.usuario = (await this.usuarios.findOneBy({ id: perfil.usuarioId }))!;
    const identidade = await this.identidades?.findOne({ where: { usuarioId: perfil.usuarioId }, order: { criadoEm: 'DESC' } });
    const telefone = await this.telefones?.findOne({ where: { usuarioId: perfil.usuarioId }, order: { criadoEm: 'DESC' } });
    return { habilitacao: habilitacaoProfissional(perfil, etapaIdentidade(identidade?.estado),
      etapaTelefone(telefone, perfil.usuario?.telefoneNormalizado, telefoneConfigurado())) };
  }

  private async atualizarIdentidade(verificacao: ProfissionalIdentidadeVerificacaoEntity) {
    if (!verificacao.referencia) throw identidadeIndisponivel();
    if (!this.identidades) throw identidadeIndisponivel();
    const resultado = await this.identidade.consultar(
      verificacao.referencia,
      verificacao.referenciaExterna,
    );
    verificacao.estado = resultado.status === 'pendente' && resultado.expiraEm &&
        resultado.expiraEm.getTime() <= Date.now()
      ? 'expirada'
      : resultado.status;
    verificacao.expiraEm = resultado.expiraEm ?? verificacao.expiraEm;
    verificacao.resolvidaEm = resultado.resolvidaEm;
    await this.identidades.save(verificacao);
    return { identidade: respostaIdentidade(verificacao, resultado.url, this.identidade.disponivel) };
  }

  private exigirProfissional(user: AuthenticatedUser) {
    if (![UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(user.tipo)) throw new ForbiddenException();
  }

  private async exigirAdminMfa(user: AuthenticatedUser) {
    if (user.tipo !== UsuarioTipo.Administrador) throw new ForbiddenException();
    const admin = await this.usuarios.findOneBy({ id: user.id, ativo: true });
    if (!admin?.mfaAtivo || admin.tipo !== UsuarioTipo.Administrador) {
      throw new ForbiddenException({ code: 'MFA_ADMIN_OBRIGATORIO', message: 'Ative a verificacao em duas etapas para gerenciar habilitacoes.' });
    }
  }
}

function numeroWhatsAppManual(): string | null {
  if (process.env.WHATSAPP_MANUAL_ENABLED !== 'true') return null;
  const digits = (process.env.WHATSAPP_MANUAL_NUMBER ?? '').replace(/\D/g, '');
  return /^55[1-9]\d{9,10}$/.test(digits) ? digits : null;
}

function telefoneConfigurado(): boolean {
  return Boolean(numeroWhatsAppManual() && segredoCodigoConfigurado()) ||
    process.env.ID_ZAPSIGN_PHONE_ENABLED === 'true';
}

function segredoCodigoConfigurado(): boolean {
  return Buffer.byteLength(process.env.AUTH_TOKEN_SECRET ?? '', 'utf8') >= 32;
}

function linkWhatsApp(numero: string): string {
  return `https://wa.me/${numero}`;
}

function hashDesafioTelefone(referencia: string, codigo: string): string {
  const segredo = process.env.AUTH_TOKEN_SECRET;
  if (!segredo || Buffer.byteLength(segredo, 'utf8') < 32) throw telefoneManualIndisponivel();
  return createHmac('sha256', segredo)
    .update(`conectalar:whatsapp-manual:v1:${referencia}:${codigo}`)
    .digest('hex');
}

function compararHashDesafio(referencia: string, codigo: string, hashSalvo: string): boolean {
  const esperado = Buffer.from(hashDesafioTelefone(referencia, codigo), 'hex');
  const salvo = Buffer.from(hashSalvo, 'hex');
  return esperado.length === salvo.length && timingSafeEqual(esperado, salvo);
}

function normalizarTelefoneRemetente(value: string): string | null {
  if (!/^[+\d().\s-]{10,24}$/.test(value)) return null;
  let digits = value.replace(/\D/g, '');
  if (digits.startsWith('55') && (digits.length === 12 || digits.length === 13)) digits = digits.slice(2);
  return digits.length === 10 || digits.length === 11 ? digits : null;
}

function limiteTelefone() {
  return new HttpException({
    code: 'LIMITE_VERIFICACAO_TELEFONE',
    message: 'Limite diario de desafios de telefone atingido. Tente novamente mais tarde.',
  }, HttpStatus.TOO_MANY_REQUESTS);
}

function telefoneManualIndisponivel() {
  return new ServiceUnavailableException({
    code: 'VERIFICACAO_MANUAL_WHATSAPP_INDISPONIVEL',
    message: 'A confirmacao manual por WhatsApp ainda nao foi configurada. Seu cadastro permanece pendente.',
  });
}

function desafioTelefoneIndisponivel() {
  return new ConflictException({
    code: 'DESAFIO_TELEFONE_INDISPONIVEL',
    message: 'Nao ha desafio manual valido aguardando confirmacao.',
  });
}

function corpo(body: unknown, permitidas: string[]): Record<string, unknown> {
  if (body === undefined || body === null) return {};
  if (typeof body !== 'object' || Array.isArray(body) || Object.keys(body).some((k) => !permitidas.includes(k))) throw invalido();
  return body as Record<string, unknown>;
}
function etapaIdentidade(estado?: string | null): string | null {
  if (estado === 'confirmada') return 'confirmado';
  if (estado === 'pendente' || estado === 'iniciando') return 'em_analise';
  if (estado === 'revisao_necessaria') return 'revisao_necessaria';
  if (estado === 'expirada' || estado === 'falha') return 'pendente';
  return null;
}
function respostaIdentidade(
  verificacao: ProfissionalIdentidadeVerificacaoEntity | null,
  url: string | null = null,
  disponivel = true,
) {
  return {
    estado: verificacao?.estado ?? 'nao_iniciada',
    disponivel,
    url,
    expiraEm: verificacao?.expiraEm?.toISOString() ?? null,
    resolvidaEm: verificacao?.resolvidaEm?.toISOString() ?? null,
  };
}
function etapaTelefone(
  verificacao: ProfissionalTelefoneVerificacaoEntity | null | undefined,
  telefoneAtual: string | null | undefined,
  disponivel: boolean,
): string {
  if (!telefoneAtual) return 'telefone_ausente';
  if (!verificacao) return disponivel ? 'nao_iniciada' : 'aguardando_integracao';
  if (verificacao.telefoneVinculado !== telefoneAtual && verificacao.estado !== 'invalidada') return 'invalidada';
  if (verificacao.estado === 'pendente' && verificacao.expiraEm && verificacao.expiraEm <= new Date()) return 'expirada';
  if (verificacao.estado === 'confirmada') return 'confirmado';
  if (verificacao.estado === 'pendente' || verificacao.estado === 'iniciando') return 'em_analise';
  if (verificacao.estado === 'expirada') return 'expirada';
  if (verificacao.estado === 'falha' || verificacao.estado === 'revisao_necessaria') return 'revisao_necessaria';
  return verificacao.estado;
}
function respostaTelefone(
  verificacao: ProfissionalTelefoneVerificacaoEntity | null,
  disponivel = true,
  telefoneAtual?: string | null,
): Record<string, unknown> {
  const vinculado = verificacao?.telefoneVinculado ?? null;
  const estado = verificacao && telefoneAtual !== undefined && vinculado !== telefoneAtual &&
    verificacao.estado !== 'invalidada' ? 'invalidada' : verificacao?.estado ??
      (telefoneAtual ? 'nao_iniciada' : 'telefone_ausente');
  const telefoneParaExibir = vinculado === telefoneAtual ? vinculado : telefoneAtual ?? null;
  return {
    estado,
    disponivel,
    tentativaId: verificacao?.tentativaEmAndamento ? verificacao.tentativaId : null,
    telefoneMascarado: mascararTelefone(telefoneParaExibir),
    tentativasRestantes: estado === 'pendente' ? verificacao?.tentativasRestantes ?? null : null,
    expiraEm: verificacao?.expiraEm?.toISOString() ?? null,
    resolvidaEm: verificacao?.resolvidaEm?.toISOString() ?? null,
  };
}
function mascararTelefone(telefone: string | null): string | null {
  if (!telefone) return null;
  const digits = telefone.replace(/\D/g, '');
  if (digits.length < 4) return null;
  return `+55 (***) *****-${digits.slice(-4)}`;
}
function telefoneAusente() {
  return new ConflictException({ code: 'TELEFONE_OBRIGATORIO', message: 'Cadastre um telefone valido antes de solicitar a confirmacao.' });
}
function telefoneIndisponivel() {
  return new ServiceUnavailableException({
    code: 'VERIFICACAO_TELEFONE_INDISPONIVEL',
    message: 'A confirmacao por telefone nao esta disponivel. Seu cadastro continua pendente.',
  });
}
function identidadeIndisponivel() {
  return new ServiceUnavailableException({
    code: 'VERIFICACAO_IDENTIDADE_INDISPONIVEL',
    message: 'A verificacao de identidade esta temporariamente indisponivel. Seu cadastro permanece pendente.',
  });
}
function optionalEstadoHabilitacao(value: unknown): string | null {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value === 'string' && ['pendente', 'em_analise', 'suspenso', 'teste_local_aprovado'].includes(value)) {
    return value;
  }
  throw new BadRequestException({ code: 'FILTRO_INVALIDO', message: 'Filtro invalido.' });
}

function invalido() { return new BadRequestException({ code: 'HABILITACAO_DADOS_INVALIDOS', message: 'Dados de habilitacao invalidos.' }); }
function naoEncontrado() { return new NotFoundException({ code: 'PERFIL_PROFISSIONAL_OBRIGATORIO', message: 'Cadastre seu perfil profissional primeiro.' }); }
