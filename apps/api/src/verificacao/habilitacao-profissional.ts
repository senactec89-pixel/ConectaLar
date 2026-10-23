import { ConflictException, ServiceUnavailableException } from '@nestjs/common';
import type { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';

export type EstadoHabilitacao = 'pendente' | 'em_analise' | 'suspenso';

// A future adapter must authenticate server-to-server results and bind them to
// the account. The mobile client cannot submit a successful verification.
export interface IdentidadeProvider {
  readonly disponivel: boolean;
  iniciar(input: { referenciaExterna: string; chaveIdempotencia: string }): Promise<{
    referencia: string;
    url: string;
    expiraEm: Date | null;
  }>;
  consultar(referencia: string, referenciaExterna: string): Promise<{
    status: 'pendente' | 'revisao_necessaria' | 'confirmada' | 'expirada';
    url: string | null;
    expiraEm: Date | null;
    resolvidaEm: Date | null;
  }>;
}

export class IdentidadeNaoConfigurada implements IdentidadeProvider {
  readonly disponivel = false;

  async iniciar(_input: { referenciaExterna: string; chaveIdempotencia: string }): Promise<never> {
    throw identidadeIndisponivel();
  }

  async consultar(_referencia: string): Promise<never> {
    throw identidadeIndisponivel();
  }
}

function identidadeIndisponivel() {
  return new ServiceUnavailableException({
    code: 'VERIFICACAO_IDENTIDADE_INDISPONIVEL',
    message: 'A verificacao de identidade ainda nao esta disponivel. Seu cadastro permanece pendente.',
  });
}

export function habilitacaoProfissional(
  perfil: ProfissionalPerfilEntity | null,
  identidadeStatus?: string | null,
) {
  const estado = perfil?.habilitacaoEstado === 'suspenso' ? 'suspenso'
    : perfil?.habilitacaoEstado === 'em_analise' ? 'em_analise' : 'pendente';
  return {
    estado,
    // Identity checks alone cannot bypass the pending phone/background policy.
    podeAtender: false,
    documentoAnalisado: perfil?.verificado === true,
    etapas: [
      { codigo: 'perfil', status: perfil ? 'cadastrado' : 'pendente' },
      { codigo: 'email', status: perfil?.usuario?.emailVerificado === true ? 'confirmado' : 'pendente' },
      { codigo: 'telefone', status: 'aguardando_integracao' },
      { codigo: 'identidade', status: identidadeStatus ?? 'aguardando_integracao' },
      { codigo: 'antecedentes', status: 'aguardando_politica' },
      { codigo: 'aprovacao', status: estado },
    ],
    mensagem: estado === 'suspenso'
      ? 'Habilitacao suspensa. Solicite revisao pela plataforma.'
      : 'Atendimentos bloqueados ate a conclusao das verificacoes de seguranca. Documento aprovado nao libera atendimentos.',
    revisaoSolicitadaEm: perfil?.habilitacaoRevisaoEm?.toISOString() ?? null,
  };
}

export function podeAtender(perfil: ProfissionalPerfilEntity | null): boolean {
  return habilitacaoProfissional(perfil).podeAtender;
}

export function exigirHabilitacao(perfil: ProfissionalPerfilEntity | null): void {
  if (!podeAtender(perfil)) {
    throw new ConflictException({
      code: 'PROFISSIONAL_HABILITACAO_PENDENTE',
      message: 'Este profissional ainda nao esta habilitado para atender. Aguarde a conclusao das verificacoes de seguranca.',
    });
  }
}
