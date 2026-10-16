import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsuarioEmailVerificacaoEntity } from '../database/entities/usuario-email-verificacao.entity.js';
import { UsuarioSenhaResetEntity } from '../database/entities/usuario-senha-reset.entity.js';
import { TermoAceiteEntity } from '../database/entities/termo-aceite.entity.js';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { AuthGuard } from './auth.guard.js';
import { AuthController } from './auth.controller.js';
import { AuthService } from './auth.service.js';
import { MailService } from './mail.service.js';
import { GoogleIdentityService } from './google-identity.service.js';
import { MfaService } from './mfa.service.js';
import { PasswordService } from './password.service.js';
import { RolesGuard } from './roles.guard.js';
import { TokenService } from './token.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      UsuarioEntity,
      UsuarioSenhaResetEntity,
      UsuarioEmailVerificacaoEntity,
      TermoAceiteEntity,
    ]),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    GoogleIdentityService,
    MailService,
    MfaService,
    PasswordService,
    TokenService,
    AuthGuard,
    RolesGuard,
  ],
  exports: [TypeOrmModule, AuthGuard, RolesGuard, TokenService, PasswordService],
})
export class AuthModule {}
