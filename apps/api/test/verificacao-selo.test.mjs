import assert from 'node:assert/strict';
import { test } from 'node:test';
import { VerificacaoService } from '../dist/verificacao/verificacao.service.js';

function criarServico(documentos) {
  const auditorias = [];
  const notificacoes = [];
  const perfisSalvos = [];
  const documentosRepo = {
    async findOne({ where }) {
      return documentos.find((documento) => documento.id === where.id) ?? null;
    },
    async save(documento) {
      return documento;
    },
    async count({ where }) {
      return documentos.filter(
        (documento) =>
          documento.profissionalId === where.profissionalId &&
          documento.tipoDocumento === where.tipoDocumento &&
          documento.status === where.status,
      ).length;
    },
  };
  const perfisRepo = {
    async update(_id, perfil) {
      perfisSalvos.push({ ...perfil });
      return perfil;
    },
  };
  const auditoriaRepo = {
    create(input) {
      return input;
    },
    async save(input) {
      auditorias.push(input);
      return input;
    },
  };
  const notificacoesService = {
    async criar(input) {
      notificacoes.push(input);
      return input;
    },
  };
  const storage = {
    async salvar() {
      return 'storage/documentos-verificacao/10/teste.pdf';
    },
    async carregar() {
      return {
        bytes: Buffer.from('%PDF- teste'),
        mimeType: 'application/pdf',
        nomeSeguro: 'teste.pdf',
      };
    },
  };
  const malwareScanner = {
    required() {
      return false;
    },
    async scanBuffer() {
      return { clean: true };
    },
  };

  return {
    service: new VerificacaoService(
      auditoriaRepo,
      documentosRepo,
      perfisRepo,
      notificacoesService,
      storage,
      malwareScanner,
    ),
    auditorias,
    notificacoes,
    perfisSalvos,
  };
}

function documento(id, tipoDocumento, status = 'pendente') {
  const agora = new Date('2026-10-14T00:00:00.000Z');
  return {
    id,
    profissionalId: 10,
    enviadoPorId: 20,
    tipoDocumento,
    referenciaArquivo: `storage/documentos-verificacao/${id}.pdf`,
    nomeArquivo: `${id}.pdf`,
    observacao: null,
    status,
    motivoRejeicao: null,
    analisadoPorId: null,
    analisadoEm: null,
    criadoEm: agora,
    atualizadoEm: agora,
    profissional: {
      id: 10,
      usuarioId: 20,
      verificado: false,
      usuario: { id: 20 },
    },
    enviadoPor: { id: 20 },
  };
}

test('selo profissional depende de identidade aprovada, nao da ultima analise', async () => {
  const documentos = [
    documento(1, 'certificado_curso'),
    documento(2, 'documento_identidade'),
    documento(3, 'certificado_curso', 'aprovado'),
  ];
  const { service, notificacoes, perfisSalvos } = criarServico(documentos);
  const admin = { id: 99, email: 'admin@conectalar.local', tipo: 'administrador' };

  await service.analisarDocumento(admin, 1, { status: 'aprovado' });
  assert.equal(perfisSalvos.at(-1).verificado, false);
  assert.match(notificacoes.at(-1).mensagem, /documento foi aprovado/i);
  assert.doesNotMatch(notificacoes.at(-1).mensagem, /selo/i);

  await service.analisarDocumento(admin, 2, { status: 'aprovado' });
  assert.equal(perfisSalvos.at(-1).verificado, true);
  assert.match(notificacoes.at(-1).mensagem, /selo de verificacao foi ativado/i);

  await service.analisarDocumento(admin, 3, {
    status: 'rejeitado',
    motivoRejeicao: 'Certificado ilegivel.',
  });
  assert.equal(perfisSalvos.at(-1).verificado, true);

  await service.analisarDocumento(admin, 2, {
    status: 'rejeitado',
    motivoRejeicao: 'Documento ilegivel.',
  });
  assert.equal(perfisSalvos.at(-1).verificado, false);
});
