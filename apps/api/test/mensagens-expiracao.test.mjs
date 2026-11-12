import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MensagemAtendimentoEntity } from '../dist/database/entities/mensagem-atendimento.entity.js';
import { ProfissionalPerfilEntity } from '../dist/database/entities/profissional-perfil.entity.js';
import { SolicitacaoEntity } from '../dist/database/entities/solicitacao.entity.js';
import { SolicitacaoStatus } from '../dist/domain/solicitacao-status.js';
import { MensagensService } from '../dist/mensagens/mensagens.service.js';

function setup({ pedido, resposta = { negociacao: 0, mensagem_profissional: 0 }, fluxoNovo = 0, negociacaoIniciada = 0 }) {
  const eventos = [];
  const mensagens = [];
  const perfil = { id: pedido.profissionalId, usuarioId: 80 };
  const manager = {
    findOne: async (entity) => entity === SolicitacaoEntity ? pedido : perfil,
    query: async (sql) => {
      if (sql.includes('AS mensagem_profissional')) return [resposta];
      if (sql.includes('AS fluxo_novo')) return [{ fluxo_novo: fluxoNovo, iniciada: negociacaoIniciada }];
      if (sql.includes('AS pendente')) return [{ pendente: 0 }];
      assert.fail(`Consulta inesperada: ${sql}`);
    },
    create: (_entity, value) => value,
    save: async (entity, value) => {
      if (entity === SolicitacaoEntity) Object.assign(pedido, value);
      if (entity === MensagemAtendimentoEntity) {
        const saved = { ...value, id: 91, criadoEm: new Date(), autor: { id: 80, nome: 'Profissional', tipo: 'profissional' } };
        mensagens.push(saved);
        return saved;
      }
      if (entity.name === 'SolicitacaoEventoEntity') eventos.push(value);
      return value;
    },
  };
  const repository = {
    manager: { transaction: async (_isolation, operation) => operation(manager) },
    findOne: async () => ({
      id: pedido.id,
      clienteId: pedido.clienteId,
      profissional: { usuarioId: perfil.usuarioId },
    }),
  };
  const mensagensRepository = {
    manager: repository.manager,
    findOne: async ({ where }) => mensagens.find((item) => item.id === where.id) ?? null,
  };
  const notificadas = [];
  return {
    service: new MensagensService(mensagensRepository, repository, { criar: async (item) => notificadas.push(item) }),
    pedido,
    eventos,
    mensagens,
    notificadas,
  };
}

test('mensagem profissional antes do limite e salva sob lock e preserva o pedido', async () => {
  const state = setup({
    pedido: {
      id: 7,
      clienteId: 10,
      profissionalId: 8,
      status: SolicitacaoStatus.AguardandoResposta,
      criadoEm: new Date(),
      prazoRespostaEm: new Date(Date.now() + 60_000),
    },
  });

  const result = await state.service.enviar({ id: 80, tipo: 'profissional' }, 7, { conteudo: 'Posso conversar sobre o pedido.' });

  assert.equal(result.mensagem.autor.id, 80);
  assert.equal(state.mensagens.length, 1);
  assert.equal(state.pedido.status, SolicitacaoStatus.AguardandoResposta);
  assert.equal(state.eventos.length, 0);
  assert.equal(state.notificadas.length, 1);
});

test('mensagem enviada apos 48 horas expira o pedido e nao e gravada', async () => {
  const state = setup({
    pedido: {
      id: 7,
      clienteId: 10,
      profissionalId: 8,
      status: SolicitacaoStatus.AguardandoResposta,
      criadoEm: new Date(Date.now() - 49 * 60 * 60 * 1000),
      prazoRespostaEm: new Date(Date.now() - 60 * 60 * 1000),
    },
  });

  await assert.rejects(
    state.service.enviar({ id: 80, tipo: 'profissional' }, 7, { conteudo: 'Cheguei tarde.' }),
    (error) => error?.getStatus?.() === 409 && error?.response?.code === 'SOLICITACAO_EXPIRADA',
  );
  assert.equal(state.pedido.status, SolicitacaoStatus.Expirada);
  assert.equal(state.mensagens.length, 0);
  assert.equal(state.eventos[0]?.tipo, 'solicitacao_expirada');
  assert.equal(state.notificadas.length, 0);
});

test('mensagem posterior a 96 horas encerra a negociacao e nao e gravada', async () => {
  const state = setup({
    pedido: {
      id: 7,
      clienteId: 10,
      profissionalId: 8,
      status: SolicitacaoStatus.AguardandoResposta,
      criadoEm: new Date(),
      prazoRespostaEm: new Date(Date.now() + 60_000),
      prazoInatividadeEm: new Date(Date.now() - 1),
    },
    fluxoNovo: 1,
    negociacaoIniciada: 1,
  });

  await assert.rejects(
    state.service.enviar({ id: 10, tipo: 'cliente' }, 7, { conteudo: 'Ainda podemos combinar?' }),
    (error) => error?.getStatus?.() === 409 && error?.response?.code === 'NEGOCIACAO_EXPIRADA',
  );
  assert.equal(state.pedido.status, SolicitacaoStatus.NegociacaoExpirada);
  assert.equal(state.mensagens.length, 0);
  assert.equal(state.eventos[0]?.tipo, 'negociacao_expirada');
});

test('mensagem de qualquer participante reinicia as 96 horas', async () => {
  const state = setup({
    pedido: {
      id: 7,
      clienteId: 10,
      profissionalId: 8,
      status: SolicitacaoStatus.AguardandoResposta,
      criadoEm: new Date(),
      prazoRespostaEm: new Date(Date.now() + 60_000),
      prazoInatividadeEm: new Date(Date.now() + 60_000),
    },
    fluxoNovo: 1,
    negociacaoIniciada: 1,
  });

  await state.service.enviar({ id: 10, tipo: 'cliente' }, 7, { conteudo: 'Podemos confirmar o escopo?' });
  assert.ok(state.pedido.prazoInatividadeEm.getTime() > Date.now() + 95 * 60 * 60 * 1000);
});
