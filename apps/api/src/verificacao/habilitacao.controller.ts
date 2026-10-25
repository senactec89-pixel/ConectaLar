import { Body, Controller, Get, Param, ParseIntPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard.js';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { UsuarioAtual } from '../auth/usuario-atual.decorator.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { HabilitacaoService } from './habilitacao.service.js';

@Controller()
@UseGuards(AuthGuard, RolesGuard)
export class HabilitacaoController {
  constructor(private readonly service: HabilitacaoService) {}

  @Get('profissionais/me/habilitacao')
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  minha(@UsuarioAtual() user: AuthenticatedUser) { return this.service.minha(user); }

  @Post('profissionais/me/habilitacao/telefone')
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  iniciarTelefone(@UsuarioAtual() user: AuthenticatedUser, @Body() body: unknown) {
    return this.service.iniciarTelefone(user, body);
  }

  @Get('profissionais/me/habilitacao/telefone')
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  consultarTelefone(@UsuarioAtual() user: AuthenticatedUser) {
    return this.service.consultarTelefone(user);
  }

  @Post('profissionais/me/habilitacao/telefone/confirmacao')
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  confirmarTelefone(@UsuarioAtual() user: AuthenticatedUser, @Body() body: unknown) {
    return this.service.confirmarTelefone(user, body);
  }

  @Post('profissionais/me/habilitacao/identidade')
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  iniciar(@UsuarioAtual() user: AuthenticatedUser, @Body() body: unknown) { return this.service.iniciarIdentidade(user, body); }

  @Get('profissionais/me/habilitacao/identidade')
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  consultarIdentidade(@UsuarioAtual() user: AuthenticatedUser) { return this.service.consultarIdentidade(user); }

  @Post('profissionais/me/habilitacao/revisao')
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  revisao(@UsuarioAtual() user: AuthenticatedUser, @Body() body: unknown) { return this.service.solicitarRevisao(user, body); }

  @Get('admin/profissionais/habilitacoes')
  @Roles(UsuarioTipo.Administrador)
  listar(@UsuarioAtual() user: AuthenticatedUser, @Query() query: Record<string, unknown>) { return this.service.listar(user, query); }

  @Patch('admin/profissionais/:id/habilitacao')
  @Roles(UsuarioTipo.Administrador)
  analisar(@UsuarioAtual() user: AuthenticatedUser, @Param('id', ParseIntPipe) id: number, @Body() body: unknown) {
    return this.service.analisar(user, id, body);
  }
}
