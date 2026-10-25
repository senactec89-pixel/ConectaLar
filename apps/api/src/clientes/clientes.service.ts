import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { ClienteEnderecoEntity } from '../database/entities/cliente-endereco.entity.js';
import { ClientePerfilEntity } from '../database/entities/cliente-perfil.entity.js';
import { FavoritoProfissionalEntity } from '../database/entities/favorito-profissional.entity.js';
import { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { LocalizacaoService } from '../localizacao/localizacao.service.js';
import { fotoPerfilUrl } from '../usuarios/foto-perfil.storage.js';
import { invalidarVerificacoesTelefone } from '../verificacao/telefone-verificacao.util.js';

@Injectable()
export class ClientesService {
  constructor(
    @InjectRepository(ClientePerfilEntity)
    private readonly perfis: Repository<ClientePerfilEntity>,
    @InjectRepository(ClienteEnderecoEntity)
    private readonly enderecos: Repository<ClienteEnderecoEntity>,
    @InjectRepository(FavoritoProfissionalEntity)
    private readonly favoritos: Repository<FavoritoProfissionalEntity>,
    @InjectRepository(ProfissionalPerfilEntity)
    private readonly profissionais: Repository<ProfissionalPerfilEntity>,
    @InjectRepository(UsuarioEntity)
    private readonly usuarios: Repository<UsuarioEntity>,
    private readonly localizacao: LocalizacaoService,
  ) {}

  async meuPerfil(user: AuthenticatedUser) {
    await this.assertClienteAtivo(user);
    const perfil = await this.perfis.findOne({
      where: { usuarioId: user.id },
      relations: { usuario: true },
    });
    const usuario =
      perfil?.usuario ??
      (await this.usuarios.findOneOrFail({ where: { id: user.id } }));

    return { cliente: clienteResponse(usuario, perfil) };
  }

  async salvarMeuPerfil(user: AuthenticatedUser, body: unknown) {
    const input = parsePerfil(body);
    const usuario = await this.assertClienteAtivo(user);
    if (input.telefoneNormalizado !== null) {
      const existente = await this.usuarios
        .createQueryBuilder('usuario')
        .where('usuario.telefoneNormalizado = :telefoneNormalizado', {
          telefoneNormalizado: input.telefoneNormalizado,
        })
        .andWhere('usuario.id <> :id', { id: user.id })
        .getOne();
      if (existente !== null) {
        throw new ConflictException({
          code: 'CONTA_NAO_CRIADA',
          message: 'Nao foi possivel salvar este telefone.',
        });
      }
    }
    let usuarioAtualizado: UsuarioEntity;
    try {
      usuarioAtualizado = await this.usuarios.manager.transaction(async (manager) => {
        const atual = await manager.findOne(UsuarioEntity, {
          where: { id: user.id, ativo: true }, lock: { mode: 'pessimistic_write' },
        });
        if (!atual) throw new ForbiddenException();
        const telefoneMudou = atual.telefoneNormalizado !== input.telefoneNormalizado;
        atual.nome = input.nome;
        atual.telefone = input.telefone;
        atual.telefoneNormalizado = input.telefoneNormalizado;
        const salvo = await manager.save(UsuarioEntity, atual);
        if (telefoneMudou) await invalidarVerificacoesTelefone(manager, user.id);
        return salvo;
      });
    } catch (error) {
      if (isDuplicateError(error)) {
        throw new ConflictException({
          code: 'CONTA_NAO_CRIADA',
          message: 'Nao foi possivel salvar este telefone.',
        });
      }
      throw error;
    }

    let perfil = await this.perfis.findOne({ where: { usuarioId: user.id } });
    perfil ??= this.perfis.create({ usuarioId: user.id });
    perfil.usuario = usuarioAtualizado;
    perfil.bairroPrincipal = input.bairroPrincipal;
    perfil.cidade = input.cidade;
    perfil.uf = input.uf;
    perfil.observacoes = input.observacoes;

    const saved = await this.perfis.save(perfil);
    saved.usuario = usuarioAtualizado;
    return { cliente: clienteResponse(usuarioAtualizado, saved) };
  }

  async listarEnderecos(user: AuthenticatedUser) {
    await this.assertClienteAtivo(user);
    const enderecos = await this.enderecos.find({
      where: { usuarioId: user.id, ativo: true },
      order: { principal: 'DESC', criadoEm: 'DESC' },
    });

    return { enderecos: enderecos.map(enderecoResponse) };
  }

  async criarEndereco(user: AuthenticatedUser, body: unknown) {
    await this.assertClienteAtivo(user);
    const input = parseEndereco(body, true);
    const geo = await this.localizacao.geocodificar(input);
    if (input.principal) {
      await this.limparPrincipal(user.id);
    }

    const endereco = await this.enderecos.save(
      this.enderecos.create({
        usuarioId: user.id,
        ...input,
        latitude: decimalOuNulo(geo.latitude),
        longitude: decimalOuNulo(geo.longitude),
        precisaoGeografica: geo.precisao,
        ativo: true,
      }),
    );

    return { endereco: enderecoResponse(endereco) };
  }

  async atualizarEndereco(
    user: AuthenticatedUser,
    enderecoId: number,
    body: unknown,
  ) {
    await this.assertClienteAtivo(user);
    const input = parseEndereco(body, false);
    const endereco = await this.carregarEnderecoDoCliente(user.id, enderecoId);
    if (input.principal === true) {
      await this.limparPrincipal(user.id);
    }

    Object.assign(endereco, input);
    const geo = await this.localizacao.geocodificar(endereco);
    endereco.latitude = decimalOuNulo(geo.latitude);
    endereco.longitude = decimalOuNulo(geo.longitude);
    endereco.precisaoGeografica = geo.precisao;
    const saved = await this.enderecos.save(endereco);
    return { endereco: enderecoResponse(saved) };
  }

  async removerEndereco(user: AuthenticatedUser, enderecoId: number) {
    await this.assertClienteAtivo(user);
    const endereco = await this.carregarEnderecoDoCliente(user.id, enderecoId);
    endereco.ativo = false;
    endereco.principal = false;
    await this.enderecos.save(endereco);
    return { ok: true };
  }

  async listarFavoritos(user: AuthenticatedUser) {
    return this.listarFavoritosPagina(user, '1', '20');
  }

  async listarFavoritosPagina(
    user: AuthenticatedUser,
    paginaValue: unknown,
    limiteValue: unknown,
  ) {
    await this.assertClienteAtivo(user);
    const { pagina, limite } = parsePaginacao(paginaValue, limiteValue);
    const consulta = this.favoritos
      .createQueryBuilder('favorito')
      .innerJoinAndSelect('favorito.profissional', 'profissional')
      .innerJoinAndSelect('profissional.usuario', 'usuario')
      .leftJoinAndSelect('profissional.servicos', 'servico', 'servico.ativo = :ativo', {
        ativo: true,
      })
      .leftJoinAndSelect('servico.categoria', 'categoria')
      .where('favorito.clienteId = :clienteId', { clienteId: user.id })
      .andWhere('profissional.ativo = :ativo', { ativo: true })
      .andWhere('usuario.ativo = :ativo', { ativo: true })
      .andWhere('usuario.tipo IN (:...tipos)', {
        tipos: [UsuarioTipo.Profissional, UsuarioTipo.Empresa],
      })
      .orderBy('favorito.criadoEm', 'DESC')
      .addOrderBy('favorito.id', 'DESC')
      .skip((pagina - 1) * limite)
      .take(limite);
    const [favoritos, total] = await consulta.getManyAndCount();

    return {
      favoritos: favoritos.map(favoritoResponse),
      paginacao: {
        pagina,
        limite,
        total,
        totalPaginas: Math.max(1, Math.ceil(total / limite)),
        temMais: pagina * limite < total,
      },
    };
  }

  async consultarFavorito(user: AuthenticatedUser, profissionalId: number) {
    await this.assertClienteAtivo(user);
    const favorito = await this.favoritos.findOne({
      where: { clienteId: user.id, profissionalId },
      relations: { profissional: { usuario: true } },
    });
    const perfil = favorito?.profissional;
    return {
      favorito: Boolean(
        perfil?.ativo &&
          perfil.usuario.ativo &&
          [UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(
            perfil.usuario.tipo,
          ),
      ),
    };
  }

  async adicionarFavorito(user: AuthenticatedUser, profissionalId: number) {
    await this.assertClienteAtivo(user);
    const profissional = await this.carregarProfissionalPublico(profissionalId);

    try {
      const favorito = await this.favoritos.save(
        this.favoritos.create({
          clienteId: user.id,
          profissionalId: profissional.id,
        }),
      );
      favorito.profissional = profissional;
      return { favorito: favoritoResponse(favorito) };
    } catch (error) {
      if (isDuplicateError(error)) {
        throw new ConflictException({
          code: 'FAVORITO_JA_EXISTE',
          message: 'Profissional ja esta nos favoritos.',
        });
      }
      throw error;
    }
  }

  async removerFavorito(user: AuthenticatedUser, profissionalId: number) {
    await this.assertClienteAtivo(user);
    await this.favoritos.delete({ clienteId: user.id, profissionalId });
    return { ok: true };
  }

  private async assertClienteAtivo(
    user: AuthenticatedUser,
  ): Promise<UsuarioEntity> {
    if (user.tipo !== UsuarioTipo.Cliente) {
      throw forbidden();
    }

    const usuario = await this.usuarios.findOne({
      where: { id: user.id, tipo: UsuarioTipo.Cliente, ativo: true },
    });
    if (usuario === null) {
      throw forbidden();
    }

    return usuario;
  }

  private async carregarEnderecoDoCliente(
    usuarioId: number,
    enderecoId: number,
  ): Promise<ClienteEnderecoEntity> {
    const endereco = await this.enderecos.findOne({
      where: { id: enderecoId, usuarioId, ativo: true },
    });
    if (endereco === null) {
      throw new NotFoundException({
        code: 'ENDERECO_NAO_ENCONTRADO',
        message: 'Endereco nao encontrado.',
      });
    }

    return endereco;
  }

  private async carregarProfissionalPublico(
    profissionalId: number,
  ): Promise<ProfissionalPerfilEntity> {
    const profissional = await this.profissionais.findOne({
      where: { id: profissionalId, ativo: true },
      relations: { usuario: true, servicos: { categoria: true } },
    });
    if (
      profissional === null ||
      !profissional.usuario.ativo ||
      ![UsuarioTipo.Profissional, UsuarioTipo.Empresa].includes(
        profissional.usuario.tipo,
      )
    ) {
      throw new NotFoundException({
        code: 'PROFISSIONAL_NAO_ENCONTRADO',
        message: 'Profissional nao encontrado.',
      });
    }

    return profissional;
  }

  private async limparPrincipal(usuarioId: number) {
    await this.enderecos.update(
      { usuarioId, ativo: true },
      { principal: false },
    );
  }
}

function clienteResponse(
  usuario: UsuarioEntity,
  perfil: ClientePerfilEntity | null,
) {
  return {
    id: usuario.id,
    nome: usuario.nome,
    email: usuario.email,
    telefone: usuario.telefone,
    tipo: usuario.tipo,
    fotoPerfilUrl: fotoPerfilUrl(usuario),
    bairroPrincipal: perfil?.bairroPrincipal ?? null,
    cidade: perfil?.cidade ?? null,
    uf: perfil?.uf ?? null,
    observacoes: perfil?.observacoes ?? null,
  };
}

function enderecoResponse(endereco: ClienteEnderecoEntity) {
  return {
    id: endereco.id,
    apelido: endereco.apelido,
    cep: endereco.cep,
    logradouro: endereco.logradouro,
    numero: endereco.numero,
    complemento: endereco.complemento,
    bairro: endereco.bairro,
    cidade: endereco.cidade,
    uf: endereco.uf,
    latitude: numeroOuNulo(endereco.latitude),
    longitude: numeroOuNulo(endereco.longitude),
    principal: endereco.principal,
  };
}

function favoritoResponse(favorito: FavoritoProfissionalEntity) {
  return {
    id: favorito.id,
    criadoEm: favorito.criadoEm.toISOString(),
    profissional: profissionalPublico(favorito.profissional),
  };
}

function profissionalPublico(profissional: ProfissionalPerfilEntity) {
  return {
    id: profissional.id,
    usuarioId: profissional.usuarioId,
    nome: profissional.usuario.nome,
    tipo: profissional.usuario.tipo,
    fotoPerfilUrl: fotoPerfilUrl(profissional.usuario),
    descricao: profissional.descricao,
    bairro: profissional.bairro,
    precoInicial: numberOrNull(profissional.precoInicial),
    verificado: profissional.verificado,
    servicos: (profissional.servicos ?? [])
      .filter((servico) => servico.ativo)
      .map((servico) => ({
        id: servico.id,
        nome: servico.nome,
        categoria:
          servico.categoria === null || servico.categoria === undefined
            ? null
            : { id: servico.categoria.id, nome: servico.categoria.nome },
        precoInicial: numberOrNull(servico.precoInicial),
      })),
  };
}

function parsePerfil(body: unknown) {
  const value = objectBody(body);
  const telefone = optionalText(value.telefone, 32);
  return {
    nome: textField(value, 'nome', 3, 140),
    telefone,
    telefoneNormalizado: normalizarTelefoneOpcional(telefone),
    bairroPrincipal: optionalText(value.bairroPrincipal, 120),
    cidade: optionalText(value.cidade, 120),
    uf: optionalUf(value.uf),
    observacoes: optionalText(value.observacoes, 280),
  };
}

function parseEndereco(body: unknown, requireAll: boolean) {
  const value = objectBody(body);
  const endereco = {
    apelido:
      value.apelido === undefined && !requireAll
        ? undefined
        : textField(value, 'apelido', 2, 80),
    cep: value.cep === undefined && !requireAll ? undefined : optionalText(value.cep, 12),
    logradouro:
      value.logradouro === undefined && !requireAll
        ? undefined
        : textField(value, 'logradouro', 2, 160),
    numero:
      value.numero === undefined && !requireAll
        ? undefined
        : textField(value, 'numero', 1, 24),
    complemento:
      value.complemento === undefined && !requireAll
        ? undefined
        : optionalText(value.complemento, 120),
    bairro:
      value.bairro === undefined && !requireAll
        ? undefined
        : textField(value, 'bairro', 2, 120),
    cidade:
      value.cidade === undefined && !requireAll
        ? undefined
        : textField(value, 'cidade', 2, 120),
    uf: value.uf === undefined && !requireAll ? undefined : requiredUf(value.uf),
    principal:
      value.principal === undefined ? undefined : booleanField(value.principal),
  };

  if (!requireAll && Object.values(endereco).every((item) => item === undefined)) {
    throw badRequest('ENDERECO_INVALIDO');
  }

  return endereco;
}

function decimalOuNulo(value: number | null): string | null {
  return value === null ? null : value.toFixed(7);
}

function numeroOuNulo(value: string | null): number | null {
  return value === null ? null : Number(value);
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

function normalizarTelefoneOpcional(telefone: string | null): string | null {
  if (telefone === null) return null;
  let digits = telefone.replace(/\D/g, '');
  if (digits.startsWith('55') && (digits.length === 12 || digits.length === 13)) {
    digits = digits.slice(2);
  }
  if (digits.length !== 10 && digits.length !== 11) {
    throw badRequest('TELEFONE_INVALIDO');
  }
  return digits;
}

function optionalUf(value: unknown): string | null {
  if (value === undefined || value === null || value === '') return null;
  return requiredUf(value);
}

function requiredUf(value: unknown): string {
  if (typeof value !== 'string' || !/^[A-Za-z]{2}$/.test(value.trim())) {
    throw badRequest('UF_INVALIDA');
  }

  return value.trim().toUpperCase();
}

function booleanField(value: unknown): boolean {
  if (typeof value !== 'boolean') {
    throw badRequest('CAMPO_INVALIDO');
  }

  return value;
}

function numberOrNull(value: string | null): number | null {
  return value === null ? null : Number(value);
}

function parsePaginacao(paginaValue: unknown, limiteValue: unknown) {
  const pagina = parsePositiveInteger(paginaValue ?? '1', 10_000);
  const limite = parsePositiveInteger(limiteValue ?? '20', 50);
  if (pagina === null || limite === null) throw badRequest('PAGINACAO_INVALIDA');
  return { pagina, limite };
}

function parsePositiveInteger(value: unknown, max: number): number | null {
  const parsed = typeof value === 'number' ? value : Number(value);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > max) return null;
  return parsed;
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
