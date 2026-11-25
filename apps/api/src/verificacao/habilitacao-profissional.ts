import { ConflictException, ServiceUnavailableException } from '@nestjs/common';
import type { ProfissionalPerfilEntity } from '../database/entities/profissional-perfil.entity.js';
import { habilitacaoPilotoRestrita } from './habilitacao-piloto.js';

export type EstadoHabilitacao = 'pendente' | 'em_analise' | 'suspenso' | 'aprovado' | 'teste_local_aprovado';

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
  _telefoneStatus?: string | null,
) {
  const habilitacaoDeTesteAtiva = habilitacaoManualTesteAtiva();
  const estado = perfil?.habilitacaoEstado === 'teste_local_aprovado' && habilitacaoDeTesteAtiva
    ? 'teste_local_aprovado'
    : perfil?.habilitacaoEstado === 'suspenso' ? 'suspenso'
    : perfil?.habilitacaoEstado === 'aprovado' && aprovacaoManualValida(perfil) ? 'aprovado'
    : perfil?.habilitacaoEstado === 'em_analise' ? 'em_analise' : 'pendente';
  const profissionalIndividualNoPiloto = !habilitacaoPilotoRestrita() || perfil?.usuario?.tipo === 'profissional';
  const testeLocalElegivel = habilitacaoDeTesteAtiva && perfil !== null && profissionalIndividualNoPiloto;
  const betaLocal = betaLocalAutorizada(perfil) && estado !== 'suspenso' && profissionalIndividualNoPiloto;
  const podeAtender =
    (estado === 'teste_local_aprovado' && testeLocalElegivel && perfil?.ativo !== false) ||
    (estado === 'aprovado' && perfil?.ativo === true && perfil.verificado === true &&
      perfil.usuario?.ativo === true && perfil.usuario.emailVerificado === true && perfil.usuario.tipo === 'profissional' &&
      profissionalIndividualNoPiloto && aprovacaoManualValida(perfil)) ||
    betaLocal;
  return {
    estado,
    podeAtender,
    aguardandoSegundoRevisor: estado === 'em_analise' && perfil?.habilitacaoPrimeiroRevisorId != null,
    primeiroRevisorId: perfil?.habilitacaoPrimeiroRevisorId ?? null,
    primeiraRevisaoEm: perfil?.habilitacaoPrimeiraRevisaoEm?.toISOString() ?? null,
    revisorFinalId: perfil?.habilitacaoRevisorFinalId ?? null,
    aprovadoEm: perfil?.habilitacaoAprovadoEm?.toISOString() ?? null,
    testeLocalElegivel,
    politicaPilotoAtiva: habilitacaoPilotoRestrita(),
    documentoAnalisado: perfil?.verificado === true,
    etapas: [
      { codigo: 'perfil', status: perfil ? 'cadastrado' : 'pendente' },
      { codigo: 'email', status: perfil?.usuario?.emailVerificado === true ? 'confirmado' : 'pendente' },
      { codigo: 'documentos', status: perfil?.verificado === true ? 'analisado' : 'pendente' },
      { codigo: 'telefone', status: 'nao_exigido_no_piloto' },
      { codigo: 'identidade', status: identidadeStatus ?? 'nao_verificada_no_piloto' },
      { codigo: 'antecedentes', status: 'nao_verificados_no_piloto' },
      { codigo: 'aprovacao', status: estado },
    ],
    mensagem: podeAtender
      ? estado === 'aprovado'
        ? 'Habilitacao manual concluida apos analise documental e das ofertas. Nao inclui verificacao automatica de telefone ou antecedentes e nao garante a qualidade do servico.'
        : estado === 'teste_local_aprovado' && testeLocalElegivel
          ? process.env.NODE_ENV === 'production'
            ? 'Habilitacao exclusiva de homologacao. Nao libera atendimentos reais.'
            : 'Habilitacao temporaria no ambiente local. Nao libera atendimento real.'
          : betaLocal
            ? 'Beta local de testes: atendimentos simulados liberados para este perfil. Nao use dados reais.'
            : 'Habilitacao pendente de revisao manual.'
      : estado === 'suspenso'
      ? 'Habilitacao suspensa. Solicite revisao pela plataforma.'
      : estado === 'em_analise' && perfil?.habilitacaoPrimeiroRevisorId != null
        ? 'Primeira revisao concluida. A habilitacao aguarda a decisao de outro administrador.'
        : 'Atendimentos bloqueados ate a revisao manual do documento e das ofertas por administradores distintos.',
    revisaoSolicitadaEm: perfil?.habilitacaoRevisaoEm?.toISOString() ?? null,
  };
}

function aprovacaoManualValida(perfil: ProfissionalPerfilEntity | null): boolean {
  return perfil?.habilitacaoPrimeiroRevisorId != null && perfil.habilitacaoPrimeiraRevisaoEm != null &&
    perfil.habilitacaoRevisorFinalId != null && perfil.habilitacaoAprovadoEm != null &&
    perfil.habilitacaoPrimeiroRevisorId !== perfil.habilitacaoRevisorFinalId;
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
