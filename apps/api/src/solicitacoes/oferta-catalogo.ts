import { BadRequestException } from '@nestjs/common';
import type { EntityManager } from 'typeorm';
import { CategoriaEntity } from '../database/entities/categoria.entity.js';
import { ProfissionalServicoEntity } from '../database/entities/profissional-servico.entity.js';
import { ServicoCatalogoEntity } from '../database/entities/servico-catalogo.entity.js';

export async function bloquearOfertaCatalogo(manager: EntityManager, profissionalId: number, ofertaId: number): Promise<ProfissionalServicoEntity> {
  const inicial = await manager.findOne(ProfissionalServicoEntity, { where: { id: ofertaId, profissionalId } });
  if (inicial?.categoriaId == null || inicial.servicoCatalogoId == null) throw indisponivel();
  const categoria = await manager.findOne(CategoriaEntity, { where: { id: inicial.categoriaId }, lock: { mode: 'pessimistic_write' } });
  const catalogo = await manager.findOne(ServicoCatalogoEntity, { where: { id: inicial.servicoCatalogoId }, lock: { mode: 'pessimistic_write' } });
  const oferta = await manager.findOne(ProfissionalServicoEntity, { where: { id: ofertaId, profissionalId }, lock: { mode: 'pessimistic_write' } });
  if (!categoria?.ativo || !catalogo?.ativo || !oferta?.ativo ||
      oferta.categoriaId !== categoria.id || oferta.servicoCatalogoId !== catalogo.id || catalogo.categoriaId !== categoria.id) {
    throw indisponivel();
  }
  oferta.categoria = categoria;
  oferta.servicoCatalogo = catalogo;
  return oferta;
}

function indisponivel(): BadRequestException {
  return new BadRequestException({ code: 'OFERTA_INDISPONIVEL', message: 'Oferta indisponivel.' });
}
