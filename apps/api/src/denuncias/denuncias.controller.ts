import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard.js';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { UsuarioAtual } from '../auth/usuario-atual.decorator.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { DenunciasService } from './denuncias.service.js';

@Controller()
export class DenunciasController {
  constructor(private readonly denuncias: DenunciasService) {}

  @Post('solicitacoes/:solicitacaoId/denuncias')
  @UseGuards(AuthGuard)
  criar(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('solicitacaoId') solicitacaoId: string,
    @Body() body: unknown,
  ) {
    return this.denuncias.criar(user, parseId(solicitacaoId), body);
  }

  @Get('denuncias/me')
  @UseGuards(AuthGuard)
  listarMinhas(
    @UsuarioAtual() user: AuthenticatedUser,
    @Query() query: Record<string, unknown>,
  ) {
    return this.denuncias.listarMinhas(user, query);
  }

  @Get('denuncias/moderacao')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  listarModeracao(@Query() query: Record<string, unknown>) {
    return this.denuncias.listarModeracao(query);
  }

  @Patch('denuncias/:id/moderacao')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  moderar(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: unknown,
  ) {
    return this.denuncias.moderar(user, parseId(id), body);
  }
}

function parseId(value: string): number {
  if (!/^[1-9]\d{0,9}$/.test(value)) {
    return 0;
  }

  return Number(value);
}
