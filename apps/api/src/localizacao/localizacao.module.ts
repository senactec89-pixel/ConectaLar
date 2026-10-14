import { Module } from '@nestjs/common';
import { LocalizacaoController } from './localizacao.controller.js';
import { LocalizacaoService } from './localizacao.service.js';

@Module({
  controllers: [LocalizacaoController],
  providers: [LocalizacaoService],
  exports: [LocalizacaoService],
})
export class LocalizacaoModule {}
