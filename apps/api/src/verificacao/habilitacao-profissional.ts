import { ConflictException, ServiceUnavailableException } from '@nestjs/common';
import type { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';

export type EstadoHabilitacao = 'pendente' | 'em_analise' | 'suspenso' | 'teste_local_aprovado';

export function habilitacaoManualTesteAtiva(): boolean {
  if (process.env.NODE_ENV !== 'production') {
    return process.env.HABILITACAO_MANUAL_LOCAL === 'true';
  }
  return process.env.CONECTALAR_STAGE === 'homologacao' &&
    process.env.HABILITACAO_MANUAL_HOMOLOGACAO === 'true' &&
    process.env.DB_NAME === 'conectalar_homologacao';
}

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
  telefoneStatus?: string | null,
) {
  const habilitacaoDeTesteAtiva = habilitacaoManualTesteAtiva();
  const estado = perfil?.habilitacaoEstado === 'teste_local_aprovado' && habilitacaoDeTesteAtiva
    ? 'teste_local_aprovado'
    : perfil?.habilitacaoEstado === 'suspenso' ? 'suspenso'
    : perfil?.habilitacaoEstado === 'em_analise' ? 'em_analise' : 'pendente';
  const testeLocalElegivel = habilitacaoDeTesteAtiva && perfil !== null;
  const betaLocal = betaLocalAutorizada(perfil) && estado !== 'suspenso';
  const podeAtender =
    (estado === 'teste_local_aprovado' && testeLocalElegivel && perfil?.ativo !== false) ||
    betaLocal;
  return {
    estado,
    podeAtender,
    testeLocalElegivel,
    documentoAnalisado: perfil?.verificado === true,
    etapas: [
      { codigo: 'perfil', status: perfil ? 'cadastrado' : 'pendente' },
      { codigo: 'email', status: perfil?.usuario?.emailVerificado === true ? 'confirmado' : 'pendente' },
      { codigo: 'documentos', status: perfil?.verificado === true ? 'analisado' : 'pendente' },
      { codigo: 'telefone', status: telefoneStatus ?? 'aguardando_integracao' },
      { codigo: 'identidade', status: identidadeStatus ?? 'aguardando_integracao' },
      { codigo: 'antecedentes', status: 'aguardando_politica' },
      { codigo: 'aprovacao', status: estado },
    ],
    mensagem: podeAtender
      ? process.env.NODE_ENV === 'production'
        ? 'Habilitacao temporaria de homologacao. Nao libera atendimento em producao.'
        : betaLocal
          ? 'Beta local de testes: atendimentos simulados liberados para este perfil. Nao use dados reais.'
        : 'Habilitacao temporaria no ambiente local. Nao libera atendimento real.'
      : estado === 'suspenso'
      ? 'Habilitacao suspensa. Solicite revisao pela plataforma.'
      : 'Atendimentos bloqueados ate a conclusao das verificacoes de seguranca. Documento aprovado nao libera atendimentos.',
    revisaoSolicitadaEm: perfil?.habilitacaoRevisaoEm?.toISOString() ?? null,
  };
}

function betaLocalAutorizada(perfil: ProfissionalPerfilEntity | null): boolean {
  if (process.env.NODE_ENV !== 'test' || process.env.CONECTALAR_BETA_LOCAL !== 'true') return false;
  if (!['127.0.0.1', 'localhost', '::1'].includes(process.env.DB_HOST ?? '')) return false;
  if (process.env.DB_NAME !== 'conectalar_beta_test') return false;
  if (!perfil?.ativo || !perfil.usuario?.ativo ||
    !['profissional', 'empresa'].includes(perfil.usuario.tipo)) return false;
  const ids = (process.env.CONECTALAR_BETA_LOCAL_PROFISSIONAL_IDS ?? '').split(',');
  return ids.some((raw) => /^[1-9]\d*$/.test(raw.trim()) && Number(raw.trim()) === perfil.id);
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
