import type { EntityManager } from 'typeorm';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { AdminAuditoriaAcao } from '../domain/admin-auditoria-acao.js';

interface RegistrarAuditoriaInput {
  readonly atorId: number;
  readonly acao: AdminAuditoriaAcao;
  readonly alvoTipo: string;
  readonly alvoId: number;
  readonly detalhe: Readonly<Record<string, unknown>>;
}

export async function registrarAuditoriaAdmin(
  manager: EntityManager,
  input: RegistrarAuditoriaInput,
): Promise<void> {
  const detalhe = detalheAuditoriaSeguro(input.detalhe);
  if (detalhe.length > 32_000) {
    throw new Error('Administrative audit detail exceeds its allowed size.');
  }

  const repository = manager.getRepository(AdminAuditoriaEntity);
  await repository.save(repository.create({ ...input, detalhe }));
}

// Apply the same allowlist on writes and reads: old rows may contain free text.
export function detalheAuditoriaSeguro(value: unknown): string {
  let raw: unknown = value;
  if (typeof raw === 'string') {
    try { raw = JSON.parse(raw); } catch { return '{}'; }
  }
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) return '{}';
  return JSON.stringify(filtrarDetalhe(raw as Record<string, unknown>));
}

const estados = new Set([
  'pendente', 'em_analise', 'suspenso', 'aprovado', 'aprovada',
  'rejeitado', 'rejeitada', 'resolvida', 'convite_pendente',
]);
const chavesId = new Set([
  'profissionalUsuarioId', 'solicitacaoId', 'denuncianteId',
  'denunciadoId', 'avaliadorId', 'avaliadoId', 'emailOutboxId',
  'profissionalId', 'tokenVersion',
]);
const chavesBooleanas = new Set([
  'ativo', 'mfaObrigatorio', 'comentarioPresente', 'aprovacaoConcedida', 'selo',
]);

function filtrarDetalhe(raw: Record<string, unknown>, pai = ''): Record<string, unknown> {
  const seguro: Record<string, unknown> = {};
  for (const [chave, valor] of Object.entries(raw)) {
    if (chave === 'antes' || chave === 'depois' ||
      ['status', 'estado', 'selo', 'revisaoSolicitadaEm'].includes(chave)) {
      if (valor && typeof valor === 'object' && !Array.isArray(valor)) {
        const nested = filtrarDetalhe(valor as Record<string, unknown>, chave);
        if (Object.keys(nested).length > 0) seguro[chave] = nested;
        continue;
      }
    }
    if (chave === 'antes' || chave === 'depois') {
      if (((pai === 'status' || pai === 'estado') &&
        typeof valor === 'string' && estados.has(valor)) ||
        (pai === 'selo' && typeof valor === 'boolean') ||
        (pai === 'revisaoSolicitadaEm' && (valor === null ||
          (typeof valor === 'string' &&
            /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(valor))))) {
        seguro[chave] = valor;
      }
      continue;
    }
    if (chavesId.has(chave) && typeof valor === 'number' &&
      Number.isSafeInteger(valor) && valor >= 0) {
      seguro[chave] = valor;
    } else if (chavesBooleanas.has(chave) && typeof valor === 'boolean') {
      seguro[chave] = valor;
    } else if (chave === 'nota' && typeof valor === 'number' && valor >= 1 && valor <= 5) {
      seguro[chave] = valor;
    } else if ((chave === 'status' || chave === 'estado') &&
      typeof valor === 'string' && estados.has(valor)) {
      seguro[chave] = valor;
    } else if ((chave === 'expiraEm' || chave === 'revisaoSolicitadaEm') &&
      typeof valor === 'string' && /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(valor)) {
      seguro[chave] = valor;
    } else if (chave === 'efeito' && valor === 'nao_altera_estado_de_aprovacao_ou_suspensao') {
      seguro[chave] = valor;
    }
  }
  return seguro;
}
