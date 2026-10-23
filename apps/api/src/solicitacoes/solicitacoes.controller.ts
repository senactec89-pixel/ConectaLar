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
import { UsuarioAtual } from '../auth/usuario-atual.decorator.js';
import { SolicitacoesService } from './solicitacoes.service.js';

@Controller('solicitacoes')
@UseGuards(AuthGuard)
export class SolicitacoesController {
  constructor(private readonly solicitacoes: SolicitacoesService) {}

  @Post()
  criar(@UsuarioAtual() user: AuthenticatedUser, @Body() body: unknown) {
    return this.solicitacoes.criar(user, body);
  }

  @Get('me')
  minhas(@UsuarioAtual() user: AuthenticatedUser) {
    return this.solicitacoes.minhas(user);
  }

  @Get(':id')
  obter(@UsuarioAtual() user: AuthenticatedUser, @Param('id') id: string) {
    return this.solicitacoes.obter(user, parseId(id));
  }

  @Patch(':id/aceitar')
  aceitar(@UsuarioAtual() user: AuthenticatedUser, @Param('id') id: string) {
    return this.solicitacoes.aceitar(user, parseId(id));
  }

  @Patch(':id/recusar')
  recusar(@UsuarioAtual() user: AuthenticatedUser, @Param('id') id: string) {
    return this.solicitacoes.recusar(user, parseId(id));
  }

  @Patch(':id/cancelar')
  cancelar(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: unknown,
  ) {
    return this.solicitacoes.cancelar(user, parseId(id), body);
  }

  @Patch(':id/concluir')
  concluir(@UsuarioAtual() user: AuthenticatedUser, @Param('id') id: string) {
    return this.solicitacoes.concluir(user, parseId(id));
  }

  @Post(':id/reagendamento')
  proporReagendamento(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: unknown,
  ) {
    return this.solicitacoes.proporReagendamento(user, parseId(id), body);
  }

  @Patch(':id/reagendamento/responder')
  responderReagendamento(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: unknown,
  ) {
    return this.solicitacoes.responderReagendamento(user, parseId(id), body);
  }
}

function parseId(value: string): number {
  if (!/^[1-9]\d{0,9}$/.test(value)) {
    return 0;
  }

  return Number(value);
}
