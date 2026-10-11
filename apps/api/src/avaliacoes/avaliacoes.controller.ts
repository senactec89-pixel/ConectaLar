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
import { AvaliacoesService } from './avaliacoes.service.js';

@Controller()
@UseGuards(AuthGuard)
export class AvaliacoesController {
  constructor(private readonly avaliacoes: AvaliacoesService) {}

  @Get('solicitacoes/:solicitacaoId/avaliacoes')
  listarDaSolicitacao(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('solicitacaoId') solicitacaoId: string,
  ) {
    return this.avaliacoes.listarDaSolicitacao(user, parseId(solicitacaoId));
  }

  @Post('solicitacoes/:solicitacaoId/avaliacoes/profissional')
  avaliarProfissional(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('solicitacaoId') solicitacaoId: string,
    @Body() body: unknown,
  ) {
    return this.avaliacoes.avaliarProfissional(
      user,
      parseId(solicitacaoId),
      body,
    );
  }

  @Post('solicitacoes/:solicitacaoId/avaliacoes/cliente')
  avaliarCliente(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('solicitacaoId') solicitacaoId: string,
    @Body() body: unknown,
  ) {
    return this.avaliacoes.avaliarCliente(user, parseId(solicitacaoId), body);
  }

  @Get('avaliacoes/moderacao')
  @UseGuards(RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  listarModeracao() {
    return this.avaliacoes.listarModeracao();
  }

  @Patch('avaliacoes/:id/moderacao')
  @UseGuards(RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  moderar(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: unknown,
  ) {
    return this.avaliacoes.moderar(user, parseId(id), body);
  }
}

function parseId(value: string): number {
  if (!/^[1-9]\d{0,9}$/.test(value)) {
    return 0;
  }

  return Number(value);
}
