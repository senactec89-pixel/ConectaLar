import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { CategoriaEntity } from '../database/entities/categoria.entity.js';
import { AdminAuditoriaAcao } from '../domain/admin-auditoria-acao.js';

@Injectable()
export class CategoriasService {
  constructor(
    @InjectRepository(AdminAuditoriaEntity)
    private readonly auditoria: Repository<AdminAuditoriaEntity>,
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

  async listarAdmin() {
    const categorias = await this.categorias.find({
      order: { nome: 'ASC' },
    });

    return { categorias: categorias.map(categoriaResponse) };
  }

  async criar(user: AuthenticatedUser, body: unknown) {
    const input = parseCategoriaInput(body, true);
    const categoria = this.categorias.create({
      nome: input.nome,
      icone: input.icone ?? 'home_repair',
      ativo: input.ativo ?? true,
    });

    try {
      const saved = await this.categorias.save(categoria);
      await this.registrarAuditoria(
        user.id,
        AdminAuditoriaAcao.CategoriaCriada,
        saved.id,
        saved.nome,
      );
      return { categoria: categoriaResponse(saved) };
    } catch {
      throw badRequest('CATEGORIA_JA_EXISTE');
    }
  }

  async atualizar(user: AuthenticatedUser, id: number, body: unknown) {
    const input = parseCategoriaInput(body, false);
    const categoria = await this.categorias.findOne({ where: { id } });
    if (categoria === null) {
      throw new NotFoundException({
        code: 'CATEGORIA_NAO_ENCONTRADA',
        message: 'Categoria nao encontrada.',
      });
    }

    if (input.nome !== undefined) {
      categoria.nome = input.nome;
    }
    if (input.ativo !== undefined) {
      categoria.ativo = input.ativo;
    }
    if (input.icone !== undefined) {
      categoria.icone = input.icone;
    }

    try {
      const saved = await this.categorias.save(categoria);
      await this.registrarAuditoria(
        user.id,
        AdminAuditoriaAcao.CategoriaAtualizada,
        saved.id,
        saved.nome,
      );
      return { categoria: categoriaResponse(saved) };
    } catch {
      throw badRequest('CATEGORIA_JA_EXISTE');
    }
  }

  private async registrarAuditoria(
    atorId: number,
    acao: AdminAuditoriaAcao,
    alvoId: number,
    nome: string,
  ) {
    await this.auditoria.save(
      this.auditoria.create({
        atorId,
        acao,
        alvoTipo: 'categoria',
        alvoId,
        detalhe: `Categoria: ${nome}`,
      }),
    );
  }
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
