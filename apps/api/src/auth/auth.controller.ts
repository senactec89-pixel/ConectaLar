import {
  Body,
  Controller,
  Delete,
  Get,
  Patch,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { AuthGuard } from './auth.guard.js';
import { AuthenticatedUser } from './authenticated-user.js';
import { AuthService } from './auth.service.js';
import { Roles } from './roles.decorator.js';
import { RolesGuard } from './roles.guard.js';
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

  @Post('google')
  loginGoogle(@Body() body: unknown) {
    return this.authService.loginGoogle(body);
  }

  @Post('login/mfa')
  confirmarLoginMfa(@Body() body: unknown) {
    return this.authService.confirmarLoginMfa(body);
  }

  @Post('senha/recuperacao')
  solicitarRecuperacaoSenha(@Body() body: unknown) {
    return this.authService.solicitarRecuperacaoSenha(body);
  }

  @Post('senha/recuperacao/confirmar')
  confirmarRecuperacaoSenha(@Body() body: unknown) {
    return this.authService.confirmarRecuperacaoSenha(body);
  }

  @Get('email/verificacao')
  @UseGuards(AuthGuard)
  statusVerificacaoEmail(@UsuarioAtual() user: AuthenticatedUser) {
    return this.authService.statusVerificacaoEmail(user);
  }

  @Post('email/verificacao/enviar')
  @UseGuards(AuthGuard)
  solicitarVerificacaoEmail(@UsuarioAtual() user: AuthenticatedUser) {
    return this.authService.solicitarVerificacaoEmail(user);
  }

  @Post('email/verificacao/confirmar')
  @UseGuards(AuthGuard)
  confirmarVerificacaoEmail(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.authService.confirmarVerificacaoEmail(user, body);
  }

  @Patch('senha')
  @UseGuards(AuthGuard)
  alterarSenha(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.authService.alterarSenha(user, body);
  }

  @Patch('me/dados')
  @UseGuards(AuthGuard)
  atualizarDadosPessoais(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.authService.atualizarDadosPessoais(user, body);
  }

  @Put('me/foto')
  @UseGuards(AuthGuard)
  atualizarFotoPerfil(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.authService.atualizarFotoPerfil(user, body);
  }

  @Delete('me/foto')
  @UseGuards(AuthGuard)
  removerFotoPerfil(@UsuarioAtual() user: AuthenticatedUser) {
    return this.authService.removerFotoPerfil(user);
  }

  @Get('mfa/admin')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  statusMfaAdmin(@UsuarioAtual() user: AuthenticatedUser) {
    return this.authService.statusMfaAdmin(user);
  }

  @Post('mfa/admin/setup')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  iniciarMfaAdmin(@UsuarioAtual() user: AuthenticatedUser) {
    return this.authService.iniciarMfaAdmin(user);
  }

  @Post('mfa/admin/confirmar')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  confirmarMfaAdmin(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.authService.confirmarMfaAdmin(user, body);
  }

  @Post('mfa/admin/desativar')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  desativarMfaAdmin(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.authService.desativarMfaAdmin(user, body);
  }

  @Post('logout')
  @UseGuards(AuthGuard)
  logout(@UsuarioAtual() user: AuthenticatedUser) {
    return this.authService.logout(user);
  }
}
