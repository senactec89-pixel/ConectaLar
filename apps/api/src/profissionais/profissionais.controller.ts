import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard.js';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { UsuarioAtual } from '../auth/usuario-atual.decorator.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { ProfissionaisService } from './profissionais.service.js';

@Controller('profissionais')
export class ProfissionaisController {
  constructor(private readonly profissionais: ProfissionaisService) {}

  @Get()
  listar(@Query() query: Record<string, unknown>) {
    return this.profissionais.listar(query);
  }

  @Post('busca')
  buscar(@Body() body: unknown) {
    return this.profissionais.buscar(body);
  }

  @Get('me')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  meuPerfil(@UsuarioAtual() user: AuthenticatedUser) {
    return this.profissionais.meuPerfil(user);
  }

  @Get('me/painel')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  meuPainel(@UsuarioAtual() user: AuthenticatedUser) {
    return this.profissionais.meuPainel(user);
  }

  @Get('me/agenda')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  minhaAgenda(
    @UsuarioAtual() user: AuthenticatedUser,
    @Query() query: Record<string, unknown>,
  ) {
    return this.profissionais.minhaAgenda(user, query);
  }

  @Get('me/servicos')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  meusServicos(@UsuarioAtual() user: AuthenticatedUser) {
    return this.profissionais.meusServicos(user);
  }

  @Put('me/servicos')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  salvarMeusServicos(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.profissionais.salvarMeusServicos(user, body);
  }

  @Put('me')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  salvarMeuPerfil(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.profissionais.salvarMeuPerfil(user, body);
  }

  @Get('me/avaliacoes')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  minhasAvaliacoes(@UsuarioAtual() user: AuthenticatedUser) {
    return this.profissionais.minhasAvaliacoes(user);
  }

  @Get(':id/avaliacoes')
  avaliacoesPublicas(@Param('id') id: string) {
    return this.profissionais.avaliacoesPublicas(parseId(id));
  }

  @Get(':id')
  obter(@Param('id') id: string) {
    return this.profissionais.obter(parseId(id));
  }

  @Patch(':id/verificacao')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  definirVerificacao(@Param('id') id: string, @Body() body: unknown) {
    return this.profissionais.definirVerificacao(parseId(id), body);
  }
}

function parseId(value: string): number {
  if (!/^[1-9]\d{0,9}$/.test(value)) {
    return 0;
  }

  return Number(value);
}
