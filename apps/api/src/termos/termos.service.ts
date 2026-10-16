import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/authenticated-user.js';
import { TermoAceiteEntity } from '../database/entities/termo-aceite.entity.js';

const termoAtual = {
  versao: '2026-10-16.v2',
  titulo: 'Termos de uso e aviso de privacidade do ConectaLar',
  publicadoEm: '2026-10-16',
  resumo:
    'O ConectaLar aproxima clientes e prestadores. O pagamento e os detalhes finais do servico sao combinados fora da plataforma.',
  secoes: [
    {
      titulo: '1. O que o ConectaLar faz',
      texto:
        'Mostramos perfis de profissionais e empresas, permitimos pedidos de atendimento, mensagens ligadas ao pedido, avaliacoes, favoritos, notificacoes e recursos de verificacao e moderacao.',
    },
    {
      titulo: '2. O que o ConectaLar nao faz',
      texto:
        'Nao cobramos pagamento dentro do app, nao definimos o preco final, nao garantimos resultado do servico e nao transformamos o selo de verificacao em garantia absoluta de seguranca ou qualidade.',
    },
    {
      titulo: '3. Dados que usamos',
      texto:
        'Usamos dados necessarios para criar conta, autenticar acesso, exibir perfis, registrar pedidos, mensagens, avaliacoes, favoritos, documentos de verificacao, denuncias, notificacoes e aceites destes termos.',
    },
    {
      titulo: '4. Por que usamos seus dados',
      texto:
        'Usamos seus dados para prestar o servico, proteger contas, cumprir regras da plataforma, prevenir abuso, responder solicitacoes de suporte e manter registros exigidos por seguranca, auditoria e obrigacoes legais.',
    },
    {
      titulo: '5. Endereco e dados sensiveis',
      texto:
        'O endereco completo do cliente deve ficar protegido. Ele so pode ser mostrado ao prestador autorizado quando houver aceite/agendamento valido. Documentos de verificacao nao aparecem no perfil publico.',
    },
    {
      titulo: '6. Seus direitos pela LGPD',
      texto:
        'Na tela Seguranca, voce pode confirmar sua senha e exportar uma copia dos dados ligados a sua conta. Tambem pode excluir a conta. A exclusao remove acesso, perfil, contatos, enderecos, foto, documentos e textos pessoais enviados pelo titular. Registros minimos de atendimentos, aceites e moderacao podem permanecer anonimizados quando necessarios para seguranca, defesa de direitos, auditoria ou obrigacao legal. Atendimentos em aberto precisam ser cancelados ou concluidos antes da exclusao.',
    },
    {
      titulo: '7. Responsabilidades dos usuarios',
      texto:
        'Use informacoes verdadeiras, proteja sua senha, converse com respeito, nao envie conteudo ilegal ou ofensivo e use denuncias apenas para relatar problemas reais ligados ao atendimento.',
    },
    {
      titulo: '8. Mudancas nos termos',
      texto:
        'Quando os termos mudarem de forma relevante, uma nova versao sera publicada. O app podera pedir novo aceite antes de liberar algumas funcionalidades.',
    },
  ],
};

@Injectable()
export class TermosService {
  constructor(
    @InjectRepository(TermoAceiteEntity)
    private readonly aceites: Repository<TermoAceiteEntity>,
  ) {}

  atuais() {
    return { termos: termoAtual };
  }

  async meusAceites(user: AuthenticatedUser) {
    const aceites = await this.aceites.find({
      where: { usuarioId: user.id },
      order: { aceitoEm: 'DESC' },
      take: 20,
    });

    const aceitouVersaoAtual = aceites.some(
      (aceite) => aceite.versao === termoAtual.versao,
    );

    return {
      versaoAtual: termoAtual.versao,
      aceitouVersaoAtual,
      aceites: aceites.map(aceiteResponse),
    };
  }

  async aceitar(user: AuthenticatedUser, body: unknown) {
    const versao = parseAceite(body);
    if (versao !== termoAtual.versao) {
      throw badRequest('VERSAO_TERMO_INVALIDA');
    }

    const existing = await this.aceites.findOne({
      where: { usuarioId: user.id, versao },
    });
    if (existing !== null) {
      return { aceite: aceiteResponse(existing), jaAceito: true };
    }

    const saved = await this.aceites.save(
      this.aceites.create({
        usuarioId: user.id,
        versao,
        canal: 'api',
        aceitoEm: new Date(),
      }),
    );

    return { aceite: aceiteResponse(saved), jaAceito: false };
  }
}

function parseAceite(body: unknown): string {
  const value = objectBody(body);
  const versao = value.versao;
  if (typeof versao !== 'string' || versao.trim().length === 0) {
    throw badRequest('VERSAO_TERMO_OBRIGATORIA');
  }

  return versao.trim();
}

function aceiteResponse(aceite: TermoAceiteEntity) {
  return {
    id: aceite.id,
    versao: aceite.versao,
    canal: aceite.canal,
    aceitoEm: aceite.aceitoEm.toISOString(),
  };
}

function objectBody(body: unknown): Record<string, unknown> {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw badRequest('CORPO_INVALIDO');
  }

  return body as Record<string, unknown>;
}

function badRequest(code: string): BadRequestException {
  return new BadRequestException({
    code,
    message: 'Dados invalidos.',
  });
}
