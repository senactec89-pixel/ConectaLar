import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  ExecutionContext,
  Get,
  Injectable,
  Param,
  Patch,
  Post,
  Query,
  Req,
  Res,
  StreamableFile,
  UploadedFile,
  UseInterceptors,
  UseGuards,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { AuthGuard } from '../auth/auth.guard.js';
import { AuthenticatedUser, RequestWithUser } from '../auth/authenticated-user.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { UsuarioAtual } from '../auth/usuario-atual.decorator.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';
import { ArquivoFotoAvaliacao, AvaliacoesService } from './avaliacoes.service.js';

interface HeaderResponse {
  setHeader(name: string, value: string): void;
}

@Controller()
@UseGuards(AuthGuard)
export class AvaliacoesController {
  constructor(private readonly avaliacoes: AvaliacoesService) {}

  @Get('solicitacoes/:solicitacaoId/avaliacoes')
  listarDaSolicitacao(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('solicitacaoId') solicitacaoId: string,
  ) {
    return this.avaliacoes.listarDaSolicitacao(user, parseId(solicitacaoId));
  }

  @Post('solicitacoes/:solicitacaoId/avaliacoes/fotos')
  @UseInterceptors(
    FileInterceptor('arquivo', {
      limits: { fileSize: 5 * 1024 * 1024, files: 1, fields: 0, parts: 1 },
      fileFilter: (_request, file, callback) => {
        const permitidos = [
          'application/octet-stream',
          'image/jpeg',
          'image/png',
          'image/webp',
        ];
        if (!permitidos.includes(file.mimetype)) {
          callback(
            new BadRequestException({
              code: 'FOTO_AVALIACAO_INVALIDA',
              message: 'Envie uma imagem JPEG, PNG ou WebP de ate 5 MB.',
            }),
            false,
          );
          return;
        }
        callback(null, true);
      },
    }),
  )
  adicionarFoto(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('solicitacaoId') solicitacaoId: string,
    @UploadedFile() arquivo: ArquivoFotoAvaliacao | undefined,
  ) {
    return this.avaliacoes.adicionarFoto(
      user,
      parseId(solicitacaoId),
      arquivo,
    );
  }

  @Delete('solicitacoes/:solicitacaoId/avaliacoes/fotos/:fotoId')
  removerFotoTemporaria(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('solicitacaoId') solicitacaoId: string,
    @Param('fotoId') fotoId: string,
  ) {
    return this.avaliacoes.removerFotoTemporaria(
      user,
      parseId(solicitacaoId),
      parseId(fotoId),
    );
  }

  @Post('solicitacoes/:solicitacaoId/avaliacoes/profissional')
  avaliarProfissional(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('solicitacaoId') solicitacaoId: string,
    @Body() body: unknown,
  ) {
    return this.avaliacoes.avaliarProfissional(
      user,
      parseId(solicitacaoId),
      body,
    );
  }

  @Post('solicitacoes/:solicitacaoId/avaliacoes/cliente')
  avaliarCliente(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('solicitacaoId') solicitacaoId: string,
    @Body() body: unknown,
  ) {
    return this.avaliacoes.avaliarCliente(user, parseId(solicitacaoId), body);
  }

  @Get('avaliacoes/moderacao')
  @UseGuards(RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  listarModeracao(@Query() query: Record<string, unknown>) {
    return this.avaliacoes.listarModeracao(query);
  }

  @Patch('avaliacoes/:id/moderacao')
  @UseGuards(RolesGuard)
  @Roles(UsuarioTipo.Administrador)
  moderar(
    @UsuarioAtual() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: unknown,
  ) {
    return this.avaliacoes.moderar(user, parseId(id), body);
  }
}

@Injectable()
export class OptionalAuthGuard {
  constructor(private readonly auth: AuthGuard) {}

  canActivate(context: ExecutionContext): boolean | Promise<boolean> {
    const request = context.switchToHttp().getRequest<RequestWithUser>();
    if (request.headers.authorization === undefined) return true;
    return this.auth.canActivate(context);
  }
}

@Controller()
export class AvaliacaoFotoPublicController {
  constructor(private readonly avaliacoes: AvaliacoesService) {}

  @Get('avaliacoes/:avaliacaoId/fotos/:fotoId')
  @UseGuards(OptionalAuthGuard)
  async carregarFoto(
    @Req() request: RequestWithUser,
    @Param('avaliacaoId') avaliacaoId: string,
    @Param('fotoId') fotoId: string,
    @Res({ passthrough: true }) response: HeaderResponse,
  ) {
    const bytes = await this.avaliacoes.carregarFoto(
      request.user ?? null,
      parseId(avaliacaoId),
      parseId(fotoId),
    );
    response.setHeader('Content-Type', 'image/jpeg');
    response.setHeader('Content-Disposition', 'inline; filename="avaliacao.jpg"');
    response.setHeader('Cache-Control', 'private, no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader("Content-Security-Policy", "default-src 'none'; sandbox");
    return new StreamableFile(bytes);
  }
}

function parseId(value: string): number {
  if (!/^[1-9]\d{0,9}$/.test(value)) {
    return 0;
  }

  return Number(value);
}
