import { createReadStream } from 'node:fs';
import { Injectable, StreamableFile } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { carregarFotoPerfil } from './foto-perfil.storage.js';

@Injectable()
export class UsuariosService {
  constructor(
    @InjectRepository(UsuarioEntity)
    private readonly usuarios: Repository<UsuarioEntity>,
  ) {}

  async fotoPerfil(usuarioId: number) {
    const usuario = await this.usuarios.findOne({
      where: { id: usuarioId, ativo: true },
    });
    const arquivo = await carregarFotoPerfil(usuario?.fotoPerfil ?? null);
    return {
      mimeType: arquivo.mimeType,
      file: new StreamableFile(createReadStream(arquivo.caminho)),
    };
  }
}
