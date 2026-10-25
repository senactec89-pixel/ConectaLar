import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { registrarAuditoriaAdmin } from '../common/admin-auditoria.js';
import { optionalSearchTerm } from '../common/admin-list-query.js';
import { paginationMetadata, parsePaginationQuery } from '../common/pagination.js';
import { CategoriaEntity } from '../database/entities/categoria.entity.js';
import { AdminAuditoriaAcao } from '../domain/admin-auditoria-acao.js';

@Injectable()
export class CategoriasService {
  constructor(
    @InjectRepository(CategoriaEntity)
    private readonly categorias: Repository<CategoriaEntity>,
  ) {}

  async listarPublicas() {
    const categorias = await this.categorias.find({
      where: { ativo: true },
      order: { nome: 'ASC' },
    });

    return { categorias: categorias.map(categoriaResponse) };
  }

  async listarAdmin(query: Record<string, unknown>) {
    const ativo = optionalBooleanQuery(query.ativo);
    const termo = optionalSearchTerm(query, 'termo', 80);
    const pagination = parsePaginationQuery(query, { defaultLimit: 20, maxLimit: 100 });
    const builder = this.categorias
      .createQueryBuilder('categoria')
      .orderBy('categoria.nome', 'ASC')
      .addOrderBy('categoria.id', 'ASC')
      .skip(pagination.skip)
      .take(pagination.limite);
    if (ativo !== null) builder.andWhere('categoria.ativo = :ativo', { ativo });
    if (termo !== null) builder.andWhere('categoria.nome LIKE :termo', { termo: `%${termo}%` });
    const [categorias, total] = await builder.getManyAndCount();
    return {
      paginacao: paginationMetadata(pagination, total),
      categorias: categorias.map(categoriaResponse),
    };
  }

  async criar(user: AuthenticatedUser, body: unknown) {
    const input = parseCategoriaInput(body, true);
    try {
      const saved = await this.categorias.manager.transaction(async (manager) => {
        const categorias = manager.getRepository(CategoriaEntity);
        const categoria = await categorias.save(categorias.create({
          nome: input.nome,
          icone: input.icone ?? 'home_repair',
          ativo: input.ativo ?? true,
        }));
        await registrarAuditoriaAdmin(manager, {
          atorId: user.id,
          acao: AdminAuditoriaAcao.CategoriaCriada,
          alvoTipo: 'categoria',
          alvoId: categoria.id,
          detalhe: {
            depois: {
              nome: categoria.nome,
              icone: categoria.icone,
              ativo: categoria.ativo,
            },
          },
        });
        return categoria;
      });
      return { categoria: categoriaResponse(saved) };
    } catch (error) {
      if (!isDuplicateError(error)) throw error;
      throw badRequest('CATEGORIA_JA_EXISTE');
    }
  }

  async atualizar(user: AuthenticatedUser, id: number, body: unknown) {
    const input = parseCategoriaInput(body, false);
    try {
      const saved = await this.categorias.manager.transaction(async (manager) => {
        const categorias = manager.getRepository(CategoriaEntity);
        const categoria = await categorias.findOne({
          where: { id },
          lock: { mode: 'pessimistic_write' },
        });
        if (categoria === null) {
          throw new NotFoundException({
            code: 'CATEGORIA_NAO_ENCONTRADA',
            message: 'Categoria nao encontrada.',
          });
        }

        const antes = {
          nome: categoria.nome,
          icone: categoria.icone,
          ativo: categoria.ativo,
        };
        if (input.nome !== undefined) categoria.nome = input.nome;
        if (input.ativo !== undefined) categoria.ativo = input.ativo;
        if (input.icone !== undefined) categoria.icone = input.icone;

        const atualizado = await categorias.save(categoria);
        await registrarAuditoriaAdmin(manager, {
          atorId: user.id,
          acao: AdminAuditoriaAcao.CategoriaAtualizada,
          alvoTipo: 'categoria',
          alvoId: atualizado.id,
          detalhe: {
            antes,
            depois: {
              nome: atualizado.nome,
              icone: atualizado.icone,
              ativo: atualizado.ativo,
            },
          },
        });
        return atualizado;
      });
      return { categoria: categoriaResponse(saved) };
    } catch (error) {
      if (!isDuplicateError(error)) throw error;
      throw badRequest('CATEGORIA_JA_EXISTE');
    }
  }
}

function isDuplicateError(error: unknown): boolean {
  return typeof error === 'object' && error !== null && 'code' in error &&
    (error as { readonly code?: unknown }).code === 'ER_DUP_ENTRY';
}

function categoriaResponse(categoria: CategoriaEntity) {
  return {
    id: categoria.id,
    nome: categoria.nome,
    icone: categoria.icone,
    ativo: categoria.ativo,
  };
}

function parseCategoriaInput(body: unknown, requireNome: boolean) {
  const value = objectBody(body);
  const nome =
    value.nome === undefined
      ? undefined
      : textField(value, 'nome', 2, 80);
  const ativo =
    value.ativo === undefined ? undefined : booleanField(value.ativo);
  const icone =
    value.icone === undefined ? undefined : categoriaIconeField(value.icone);

  if (requireNome && nome === undefined) {
    throw badRequest('CATEGORIA_INVALIDA');
  }
  if (
    !requireNome &&
    nome === undefined &&
    ativo === undefined &&
    icone === undefined
  ) {
    throw badRequest('CATEGORIA_INVALIDA');
  }

  return { nome, ativo, icone };
}

const categoriaIconesPermitidos = new Set([
  'home_repair',
  'electrical_services',
  'plumbing',
  'format_paint',
  'cleaning_services',
  'build',
  'ac_unit',
  'construction',
  'grass',
  'category',
]);

function categoriaIconeField(value: unknown): string {
  if (typeof value !== 'string') {
    throw badRequest('CATEGORIA_INVALIDA');
  }
  const icone = value.trim();
  if (!categoriaIconesPermitidos.has(icone)) {
    throw badRequest('CATEGORIA_INVALIDA');
  }
  return icone;
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

function booleanField(value: unknown): boolean {
  if (typeof value !== 'boolean') {
    throw badRequest('CAMPO_INVALIDO');
  }

  return value;
}

function badRequest(code: string): BadRequestException {
  return new BadRequestException({
    code,
    message: 'Dados invalidos.',
  });
}

function optionalBooleanQuery(value: unknown): boolean | null {
  if (value === undefined || value === null || value === '') return null;
  if (value === 'true' || value === true) return true;
  if (value === 'false' || value === false) return false;
  throw badRequest('FILTRO_INVALIDO');
}
