import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Res,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { createReadStream } from 'node:fs';
import { AuthGuard } from '../auth/auth.guard.js';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { UsuarioAtual } from '../auth/usuario-atual.decorator.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { VerificacaoService } from './verificacao.service.js';

interface HeaderResponse {
  setHeader(name: string, value: string): void;
}

@Controller()
export class VerificacaoController {
  constructor(private readonly verificacao: VerificacaoService) {}

  @Post('profissionais/me/documentos')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  enviarMeuDocumento(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.verificacao.enviarMeuDocumento(user, body);
  }

  @Get('profissionais/me/documentos')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Profissional, UsuarioTipo.Empresa)
  listarMeusDocumentos(@UsuarioAtual() user: AuthenticatedUser) {
    return this.verificacao.listarMeusDocumentos(user);
  }

  @Get('documentos-verificacao')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  listarParaAnalise(@Query() query: Record<string, unknown>) {
    return this.verificacao.listarParaAnalise(query);
  }

  @Get('documentos-verificacao/:id/arquivo')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  async baixarArquivoParaAnalise(
    @Param('id') id: string,
    @Res({ passthrough: true }) response: HeaderResponse,
  ) {
    const arquivo = await this.verificacao.arquivoParaAnalise(parseId(id));
    response.setHeader('Content-Type', arquivo.mimeType);
    response.setHeader(
      'Content-Disposition',
      `inline; filename="${arquivo.nomeSeguro}"`,
    );
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    return new StreamableFile(createReadStream(arquivo.caminho));
  }

  @Patch('documentos-verificacao/:id/analisar')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  analisarDocumento(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: unknown,
  ) {
    return this.verificacao.analisarDocumento(user, parseId(id), body);
  }
}

function parseId(value: string): number {
  if (!/^[1-9]\d{0,9}$/.test(value)) {
    return 0;
  }

  return Number(value);
}
