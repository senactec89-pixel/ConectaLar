import { Controller, Get, Param, Res } from '@nestjs/common';
import { UsuariosService } from './usuarios.service.js';

interface HeaderResponse {
  setHeader(name: string, value: string): void;
}

@Controller('usuarios')
export class UsuariosController {
  constructor(private readonly usuariosService: UsuariosService) {}

  @Get(':id/foto')
  async fotoPerfil(
    @Param('id') id: string,
    @Res({ passthrough: true }) response: HeaderResponse,
  ) {
    const usuarioId = Number(id);
    if (!Number.isInteger(usuarioId) || usuarioId <= 0) {
      return this.usuariosService.fotoPerfil(0);
    }
    const result = await this.usuariosService.fotoPerfil(usuarioId);
    response.setHeader('Content-Type', result.mimeType);
    response.setHeader('Cache-Control', 'private, max-age=300');
    return result.file;
  }
}
