import { Body, Controller, Delete, Get, Param, Post, Put, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard.js';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { UsuarioAtual } from '../auth/usuario-atual.decorator.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { DisponibilidadeService } from './disponibilidade.service.js';

@Controller()
export class DisponibilidadeController {
  constructor(private readonly disponibilidade: DisponibilidadeService) {}

  @Get('profissionais/me/disponibilidade')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  minha(@UsuarioAtual() user: AuthenticatedUser) {
    return this.disponibilidade.minha(user);
  }

  @Put('profissionais/me/disponibilidade')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  salvarMinha(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.disponibilidade.salvarMinha(user, body);
  }

  @Get('profissionais/me/bloqueios')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  meusBloqueios(@UsuarioAtual() user: AuthenticatedUser) {
    return this.disponibilidade.meusBloqueios(user);
  }

  @Post('profissionais/me/bloqueios')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  criarBloqueio(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.disponibilidade.criarBloqueio(user, body);
  }

  @Delete('profissionais/me/bloqueios/:id')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  removerBloqueio(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.disponibilidade.removerBloqueio(user, parseId(id));
  }

  // Rotas literais devem preceder :id; "me" não é um ID de perfil público.
  @Get('profissionais/:id/disponibilidade')
  listarPublica(@Param('id') id: string) {
    return this.disponibilidade.listarPublica(parseId(id));
  }
}

function parseId(value: string): number {
  if (!/^[1-9]\d{0,9}$/.test(value)) {
    return 0;
  }

  return Number(value);
}
