import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard.js';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { UsuarioAtual } from '../auth/usuario-atual.decorator.js';
import { PrivacidadeService } from './privacidade.service.js';

@Controller('privacidade')
@UseGuards(AuthGuard)
export class PrivacidadeController {
  constructor(private readonly privacidadeService: PrivacidadeService) {}

  @Post('me/exportacao')
  exportarDados(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.privacidadeService.exportarDados(user, body);
  }

  @Post('me/exclusao')
  excluirConta(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.privacidadeService.excluirConta(user, body);
  }
}
