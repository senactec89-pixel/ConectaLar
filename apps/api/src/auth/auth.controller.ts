import { Body, Controller, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from './auth.guard.js';
import { AuthenticatedUser } from './authenticated-user.js';
import { AuthService } from './auth.service.js';
import { UsuarioAtual } from './usuario-atual.decorator.js';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('cadastro')
  cadastro(@Body() body: unknown) {
    return this.authService.cadastro(body);
  }

  @Post('login')
  login(@Body() body: unknown) {
    return this.authService.login(body);
  }

  @Post('senha/recuperacao')
  solicitarRecuperacaoSenha(@Body() body: unknown) {
    return this.authService.solicitarRecuperacaoSenha(body);
  }

  @Post('senha/recuperacao/confirmar')
  confirmarRecuperacaoSenha(@Body() body: unknown) {
    return this.authService.confirmarRecuperacaoSenha(body);
  }

  @Patch('senha')
  @UseGuards(AuthGuard)
  alterarSenha(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.authService.alterarSenha(user, body);
  }

  @Post('logout')
  @UseGuards(AuthGuard)
  logout(@UsuarioAtual() user: AuthenticatedUser) {
    return this.authService.logout(user);
  }
}
