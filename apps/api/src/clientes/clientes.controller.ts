import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Put,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard.js';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { UsuarioAtual } from '../auth/usuario-atual.decorator.js';
import { ClientesService } from './clientes.service.js';

@Controller('clientes')
@UseGuards(AuthGuard)
export class ClientesController {
  constructor(private readonly clientes: ClientesService) {}

  @Get('me')
  meuPerfil(@UsuarioAtual() user: AuthenticatedUser) {
    return this.clientes.meuPerfil(user);
  }

  @Put('me')
  salvarMeuPerfil(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.clientes.salvarMeuPerfil(user, body);
  }

  @Get('me/enderecos')
  listarEnderecos(@UsuarioAtual() user: AuthenticatedUser) {
    return this.clientes.listarEnderecos(user);
  }

  @Post('me/enderecos')
  criarEndereco(
    @UsuarioAtual() user: AuthenticatedUser,
    @Body() body: unknown,
  ) {
    return this.clientes.criarEndereco(user, body);
  }

  @Patch('me/enderecos/:id')
  atualizarEndereco(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: unknown,
  ) {
    return this.clientes.atualizarEndereco(user, parseId(id), body);
  }

  @Delete('me/enderecos/:id')
  removerEndereco(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.clientes.removerEndereco(user, parseId(id));
  }

  @Get('me/favoritos')
  listarFavoritos(
    @UsuarioAtual() user: AuthenticatedUser,
    @Query() query: Record<string, unknown>,
  ) {
    return this.clientes.listarFavoritosPagina(
      user,
      query.pagina,
      query.limite,
    );
  }

  @Get('me/favoritos/:profissionalId')
  consultarFavorito(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('profissionalId') profissionalId: string,
  ) {
    return this.clientes.consultarFavorito(user, parseId(profissionalId));
  }

  @Post('me/favoritos/:profissionalId')
  adicionarFavorito(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('profissionalId') profissionalId: string,
  ) {
    return this.clientes.adicionarFavorito(user, parseId(profissionalId));
  }

  @Delete('me/favoritos/:profissionalId')
  removerFavorito(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('profissionalId') profissionalId: string,
  ) {
    return this.clientes.removerFavorito(user, parseId(profissionalId));
  }
}

function parseId(value: string): number {
  if (!/^[1-9]\d{0,9}$/.test(value)) {
    return 0;
  }

  return Number(value);
}
