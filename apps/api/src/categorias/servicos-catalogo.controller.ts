import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard.js';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { UsuarioAtual } from '../auth/usuario-atual.decorator.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { ServicosCatalogoService } from './servicos-catalogo.service.js';

@Controller('categorias/:categoriaId/servicos')
export class ServicosCatalogoPublicoController {
  constructor(private readonly servicos: ServicosCatalogoService) {}

  @Get()
  listar(@Param('categoriaId') categoriaId: string, @Query() query: Record<string, unknown>) {
    return this.servicos.listarPublicos(parseId(categoriaId), query);
  }

  @Get(':servicoId/opcoes')
  listarOpcoes(@Param('categoriaId') categoriaId: string, @Param('servicoId') servicoId: string, @Query() query: Record<string, unknown>) {
    return this.servicos.listarOpcoes(parseId(categoriaId), parseId(servicoId), query, true);
  }
}

@Controller('admin/catalogo/categorias/:categoriaId/servicos')
@UseGuards(AuthGuard, RolesGuard)
@Roles(UsuarioTipo.Administrador)
export class ServicosCatalogoController {
  constructor(private readonly servicos: ServicosCatalogoService) {}

  @Get()
  listar(@Param('categoriaId') categoriaId: string, @Query() query: Record<string, unknown>) {
    return this.servicos.listar(parseId(categoriaId), query);
  }

  @Post()
  criar(@UsuarioAtual() user: AuthenticatedUser, @Param('categoriaId') categoriaId: string, @Body() body: unknown) {
    return this.servicos.criar(user, parseId(categoriaId), body);
  }

  @Get(':servicoId/opcoes')
  listarOpcoes(@Param('categoriaId') categoriaId: string, @Param('servicoId') servicoId: string, @Query() query: Record<string, unknown>) {
    return this.servicos.listarOpcoes(parseId(categoriaId), parseId(servicoId), query, false);
  }

  @Post(':servicoId/opcoes')
  criarOpcao(@UsuarioAtual() user: AuthenticatedUser, @Param('categoriaId') categoriaId: string,
    @Param('servicoId') servicoId: string, @Body() body: unknown) {
    return this.servicos.criarOpcao(user, parseId(categoriaId), parseId(servicoId), body);
  }

  @Patch(':servicoId/opcoes/:opcaoId')
  atualizarOpcao(@UsuarioAtual() user: AuthenticatedUser, @Param('categoriaId') categoriaId: string,
    @Param('servicoId') servicoId: string, @Param('opcaoId') opcaoId: string, @Body() body: unknown) {
    return this.servicos.atualizarOpcao(user, parseId(categoriaId), parseId(servicoId), parseId(opcaoId), body);
  }

  @Patch(':servicoId')
  atualizar(@UsuarioAtual() user: AuthenticatedUser, @Param('categoriaId') categoriaId: string,
    @Param('servicoId') servicoId: string, @Body() body: unknown) {
    return this.servicos.atualizar(user, parseId(categoriaId), parseId(servicoId), body);
  }
}

function parseId(value: string): number {
  if (!/^[1-9]\d{0,9}$/.test(value) || Number(value) > 4_294_967_295) return 0;
  return Number(value);
}
