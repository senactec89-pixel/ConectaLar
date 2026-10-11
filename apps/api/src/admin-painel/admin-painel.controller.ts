import { Controller, Get, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { AdminPainelService } from './admin-painel.service.js';

@Controller('admin/painel')
@UseGuards(AuthGuard, RolesGuard)
@Roles(UsuarioTipo.Administrador)
export class AdminPainelController {
  constructor(private readonly painel: AdminPainelService) {}

  @Get()
  resumo() {
    return this.painel.resumo();
  }
}
