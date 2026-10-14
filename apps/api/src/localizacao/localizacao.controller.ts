import { Controller, Get, Param } from '@nestjs/common';
import { LocalizacaoService } from './localizacao.service.js';

@Controller('localizacao')
export class LocalizacaoController {
  constructor(private readonly localizacao: LocalizacaoService) {}

  @Get('cep/:cep')
  consultarCep(@Param('cep') cep: string) {
    return this.localizacao.consultarCep(cep);
  }
}
