import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { registrarAuditoriaAdmin } from '../common/admin-auditoria.js';
import { optionalSearchTerm } from '../common/admin-list-query.js';
import { paginationMetadata, parsePaginationQuery } from '../common/pagination.js';
import { CategoriaEntity } from '../database/entities/categoria.entity.js';
import { ServicoCatalogoEntity } from '../database/entities/servico-catalogo.entity.js';
import { AdminAuditoriaAcao } from '../domain/admin-auditoria-acao.js';

@Injectable()
export class ServicosCatalogoService {
  constructor(
    @InjectRepository(ServicoCatalogoEntity) private readonly servicos: Repository<ServicoCatalogoEntity>,
    @InjectRepository(CategoriaEntity) private readonly categorias: Repository<CategoriaEntity>,
  ) {}

  async listarOpcoes(categoriaId: number, servicoId: number, query: Record<string, unknown>, publico: boolean) {
    const categoria = await this.categorias.findOne({ where: { id: categoriaId, ...(publico ? { ativo: true } : {}) } });
    if (categoria === null) throw categoriaNaoEncontrada();
    const servico = await this.servicos.findOne({ where: { id: servicoId, categoriaId, ...(publico ? { ativo: true } : {}) } });
    if (servico === null) throw servicoNaoEncontrado();
    const ativo = publico ? true : parseAtivoQuery(query.ativo);
    const paginacao = parsePaginationQuery(query, { defaultLimit: 20, maxLimit: 100 });
    const where = `servico_catalogo_id = ?${ativo === null ? '' : ' AND ativo = ?'}`;
    const params = ativo === null ? [servicoId] : [servicoId, Number(ativo)];
    const rows = await this.servicos.manager.query(`SELECT id, servico_catalogo_id, nome, ativo FROM servico_catalogo_opcoes WHERE ${where} ORDER BY nome, id LIMIT ? OFFSET ?`, [...params, paginacao.limite, paginacao.skip]) as OpcaoRow[];
    const counts = await this.servicos.manager.query(`SELECT COUNT(*) AS total FROM servico_catalogo_opcoes WHERE ${where}`, params) as Array<{ total: number | string }>;
    return { paginacao: paginationMetadata(paginacao, Number(counts[0]?.total ?? 0)), opcoes: rows.map(opcaoResponse) };
  }

  async criarOpcao(user: AuthenticatedUser, categoriaId: number, servicoId: number, body: unknown) {
    const input = parseOpcao(body, true);
    try {
      return await this.servicos.manager.transaction(async (manager) => {
        const categoria = await manager.findOne(CategoriaEntity, { where: { id: categoriaId }, lock: { mode: 'pessimistic_write' } });
        if (categoria === null) throw categoriaNaoEncontrada();
        const servico = await manager.findOne(ServicoCatalogoEntity, { where: { id: servicoId, categoriaId }, lock: { mode: 'pessimistic_write' } });
        if (servico === null) throw servicoNaoEncontrado();
        const result = await manager.query('INSERT INTO servico_catalogo_opcoes (servico_catalogo_id, nome) VALUES (?, ?)', [servicoId, input.nome]) as { insertId: number };
        const opcao = { id: result.insertId, servicoCatalogoId: servicoId, nome: input.nome!, ativo: false };
        await registrarAuditoriaAdmin(manager, { atorId: user.id, acao: AdminAuditoriaAcao.ServicoCatalogoAtualizado,
          alvoTipo: 'servico_catalogo', alvoId: servicoId, detalhe: { operacao: 'opcao_criada', opcao } });
        return { opcao };
      });
    } catch (error) {
      if (isDuplicate(error)) throw badRequest('OPCAO_JA_EXISTE');
      throw error;
    }
  }

  async atualizarOpcao(user: AuthenticatedUser, categoriaId: number, servicoId: number, opcaoId: number, body: unknown) {
    const input = parseOpcao(body, false);
    try {
      return await this.servicos.manager.transaction(async (manager) => {
        const categoria = await manager.findOne(CategoriaEntity, { where: { id: categoriaId }, lock: { mode: 'pessimistic_write' } });
        if (categoria === null) throw categoriaNaoEncontrada();
        const servico = await manager.findOne(ServicoCatalogoEntity, { where: { id: servicoId, categoriaId }, lock: { mode: 'pessimistic_write' } });
        if (servico === null) throw servicoNaoEncontrado();
        const rows = await manager.query('SELECT id, servico_catalogo_id, nome, ativo FROM servico_catalogo_opcoes WHERE id = ? AND servico_catalogo_id = ? FOR UPDATE', [opcaoId, servicoId]) as OpcaoRow[];
        const row = rows[0];
        if (row === undefined) throw new NotFoundException({ code: 'OPCAO_NAO_ENCONTRADA', message: 'Opcao nao encontrada neste servico.' });
        if (input.ativo === true && (!categoria.ativo || !servico.ativo)) throw badRequest('SERVICO_CATALOGO_INDISPONIVEL');
        const antes = opcaoResponse(row);
        const depois = { ...antes, nome: input.nome ?? antes.nome, ativo: input.ativo ?? antes.ativo };
        await manager.query('UPDATE servico_catalogo_opcoes SET nome = ?, ativo = ? WHERE id = ?', [depois.nome, Number(depois.ativo), opcaoId]);
        await registrarAuditoriaAdmin(manager, { atorId: user.id, acao: AdminAuditoriaAcao.ServicoCatalogoAtualizado,
          alvoTipo: 'servico_catalogo', alvoId: servicoId, detalhe: { operacao: 'opcao_atualizada', antes, depois } });
        return { opcao: depois };
      });
    } catch (error) {
      if (isDuplicate(error)) throw badRequest('OPCAO_JA_EXISTE');
      throw error;
    }
  }

  async listarPublicos(categoriaId: number, query: Record<string, unknown>) {
    if (!(await this.categorias.findOne({ where: { id: categoriaId, ativo: true } }))) throw categoriaNaoEncontrada();
    const paginacao = parsePaginationQuery(query, { defaultLimit: 20, maxLimit: 100 });
    const [servicos, total] = await this.servicos.findAndCount({
      where: { categoriaId, ativo: true }, order: { nome: 'ASC', id: 'ASC' },
      skip: paginacao.skip, take: paginacao.limite,
    });
    return { paginacao: paginationMetadata(paginacao, total), servicos: servicos.map(response) };
  }

  async listar(categoriaId: number, query: Record<string, unknown>) {
    if (!(await this.categorias.findOne({ where: { id: categoriaId } }))) throw categoriaNaoEncontrada();
    const ativo = parseAtivoQuery(query.ativo);
    const termo = optionalSearchTerm(query, 'termo', 90);
    const paginacao = parsePaginationQuery(query, { defaultLimit: 20, maxLimit: 100 });
    const builder = this.servicos.createQueryBuilder('servico')
      .where('servico.categoriaId = :categoriaId', { categoriaId })
      .orderBy('servico.nome', 'ASC').addOrderBy('servico.id', 'ASC')
      .skip(paginacao.skip).take(paginacao.limite);
    if (ativo !== null) builder.andWhere('servico.ativo = :ativo', { ativo });
    if (termo !== null) builder.andWhere('servico.nome LIKE :termo', { termo: `%${termo}%` });
    const [servicos, total] = await builder.getManyAndCount();
    return { paginacao: paginationMetadata(paginacao, total), servicos: servicos.map(response) };
  }

  async criar(user: AuthenticatedUser, categoriaId: number, body: unknown) {
    const input = parseInput(body, true);
    try {
      const saved = await this.servicos.manager.transaction(async (manager) => {
        const categoria = await manager.getRepository(CategoriaEntity).findOne({
          where: { id: categoriaId }, lock: { mode: 'pessimistic_write' },
        });
        if (categoria === null) throw categoriaNaoEncontrada();
        if (input.ativo === true && !categoria.ativo) throw badRequest('CATEGORIA_INATIVA');
        const repo = manager.getRepository(ServicoCatalogoEntity);
        const servico = await repo.save(repo.create({
          categoriaId, nome: input.nome!, descricao: input.descricao ?? null,
          inclusoes: input.inclusoes ?? null, exclusoes: input.exclusoes ?? null,
          ativo: input.ativo ?? false,
        }));
        await registrarAuditoriaAdmin(manager, {
          atorId: user.id, acao: AdminAuditoriaAcao.ServicoCatalogoCriado,
          alvoTipo: 'servico_catalogo', alvoId: servico.id, detalhe: { depois: response(servico) },
        });
        return servico;
      });
      return { servico: response(saved) };
    } catch (error) {
      if (isDuplicate(error)) throw badRequest('SERVICO_CATALOGO_JA_EXISTE');
      throw error;
    }
  }

  async atualizar(user: AuthenticatedUser, categoriaId: number, servicoId: number, body: unknown) {
    const input = parseInput(body, false);
    try {
      const saved = await this.servicos.manager.transaction(async (manager) => {
        const categoria = await manager.getRepository(CategoriaEntity).findOne({
          where: { id: categoriaId }, lock: { mode: 'pessimistic_write' },
        });
        if (categoria === null) throw categoriaNaoEncontrada();
        const repo = manager.getRepository(ServicoCatalogoEntity);
        const servico = await repo.findOne({ where: { id: servicoId, categoriaId }, lock: { mode: 'pessimistic_write' } });
        if (servico === null) throw new NotFoundException({ code: 'SERVICO_CATALOGO_NAO_ENCONTRADO', message: 'Servico nao encontrado nesta categoria.' });
        if (input.ativo === true && !categoria.ativo) throw badRequest('CATEGORIA_INATIVA');
        const antes = response(servico);
        if (input.nome !== undefined) servico.nome = input.nome;
        if (input.descricao !== undefined) servico.descricao = input.descricao;
        if (input.inclusoes !== undefined) servico.inclusoes = input.inclusoes;
        if (input.exclusoes !== undefined) servico.exclusoes = input.exclusoes;
        if (input.ativo !== undefined) servico.ativo = input.ativo;
        const atualizado = await repo.save(servico);
        await registrarAuditoriaAdmin(manager, {
          atorId: user.id, acao: AdminAuditoriaAcao.ServicoCatalogoAtualizado,
          alvoTipo: 'servico_catalogo', alvoId: atualizado.id, detalhe: { antes, depois: response(atualizado) },
        });
        return atualizado;
      });
      return { servico: response(saved) };
    } catch (error) {
      if (isDuplicate(error)) throw badRequest('SERVICO_CATALOGO_JA_EXISTE');
      throw error;
    }
  }
}

interface OpcaoRow { id: number; servico_catalogo_id: number; nome: string; ativo: number | boolean }
function opcaoResponse(row: OpcaoRow) {
  return { id: row.id, servicoCatalogoId: row.servico_catalogo_id, nome: row.nome, ativo: Boolean(row.ativo) };
}
function parseOpcao(body: unknown, criar: boolean) {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) throw badRequest('CORPO_INVALIDO');
  const value = body as Record<string, unknown>;
  if (Object.keys(value).some((key) => !['nome', ...(criar ? [] : ['ativo'])].includes(key))) throw badRequest('CAMPO_INVALIDO');
  const nome = value.nome === undefined ? undefined : requiredText(value.nome, 2, 120);
  if (value.ativo !== undefined && typeof value.ativo !== 'boolean') throw badRequest('CAMPO_INVALIDO');
  if ((criar && nome === undefined) || (!criar && Object.keys(value).length === 0)) throw badRequest('OPCAO_INVALIDA');
  return { nome, ativo: value.ativo as boolean | undefined };
}
function servicoNaoEncontrado(): NotFoundException {
  return new NotFoundException({ code: 'SERVICO_CATALOGO_NAO_ENCONTRADO', message: 'Servico nao encontrado nesta categoria.' });
}

function response(servico: ServicoCatalogoEntity) {
  return { id: servico.id, categoriaId: servico.categoriaId, nome: servico.nome,
    descricao: servico.descricao, inclusoes: servico.inclusoes, exclusoes: servico.exclusoes, ativo: servico.ativo };
}

function parseInput(body: unknown, requireNome: boolean) {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) throw badRequest('CORPO_INVALIDO');
  const value = body as Record<string, unknown>;
  if (Object.keys(value).some((key) => !['nome', 'descricao', 'inclusoes', 'exclusoes', 'ativo'].includes(key))) throw badRequest('CAMPO_INVALIDO');
  const nome = value.nome === undefined ? undefined : requiredText(value.nome, 2, 90);
  const descricao = optionalText(value.descricao);
  const inclusoes = optionalText(value.inclusoes);
  const exclusoes = optionalText(value.exclusoes);
  if (value.ativo !== undefined && typeof value.ativo !== 'boolean') throw badRequest('CAMPO_INVALIDO');
  const ativo = value.ativo as boolean | undefined;
  if ((requireNome && nome === undefined) || (!requireNome && Object.keys(value).length === 0)) throw badRequest('SERVICO_CATALOGO_INVALIDO');
  return { nome, descricao, inclusoes, exclusoes, ativo };
}

function requiredText(value: unknown, min: number, max: number): string {
  if (typeof value !== 'string') throw badRequest('CAMPO_INVALIDO');
  const text = value.trim();
  if (text.length < min || text.length > max) throw badRequest('CAMPO_INVALIDO');
  return text;
}

function optionalText(value: unknown): string | null | undefined {
  if (value === undefined) return undefined;
  if (value === null) return null;
  return requiredText(value, 1, 1000);
}

function parseAtivoQuery(value: unknown): boolean | null {
  if (value === undefined || value === '') return null;
  if (value === 'true' || value === true) return true;
  if (value === 'false' || value === false) return false;
  throw badRequest('FILTRO_INVALIDO');
}

function isDuplicate(error: unknown): boolean {
  return typeof error === 'object' && error !== null && 'code' in error && (error as { code?: unknown }).code === 'ER_DUP_ENTRY';
}
function badRequest(code: string): BadRequestException {
  return new BadRequestException({ code, message: 'Dados invalidos.' });
}
function categoriaNaoEncontrada(): NotFoundException {
  return new NotFoundException({ code: 'CATEGORIA_NAO_ENCONTRADA', message: 'Categoria nao encontrada.' });
}
