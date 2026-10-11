import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard.js';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { UsuarioAtual } from '../auth/usuario-atual.decorator.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { CategoriasService } from './categorias.service.js';

@Controller('categorias')
export class CategoriasController {
  constructor(private readonly categorias: CategoriasService) {}

  @Get()
  listarPublicas() {
    return this.categorias.listarPublicas();
  }

  @Get('admin')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  listarAdmin() {
    return this.categorias.listarAdmin();
  }

  @Post()
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  criar(@UsuarioAtual() user: AuthenticatedUser, @Body() body: unknown) {
    return this.categorias.criar(user, body);
  }

  @Patch(':id')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  atualizar(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: unknown,
  ) {
    return this.categorias.atualizar(user, parseId(id), body);
  }
}

function parseId(value: string): number {
  if (!/^[1-9]\d{0,9}$/.test(value)) {
    return 0;
  }

  return Number(value);
}
