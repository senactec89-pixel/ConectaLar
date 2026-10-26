import assert from 'node:assert/strict';
import {
  createHmac,
  randomBytes,
  randomInt,
  randomUUID,
  scrypt,
} from 'node:crypto';
import { promisify } from 'node:util';
import test from 'node:test';
import mysql from 'mysql2/promise';

const enabled = process.env.CONECTALAR_MYSQL_TEST === '1';

test(
  'MySQL real: fluxo principal e listas administrativas com MFA, filtros e paginacao',
  { skip: !enabled },
  async () => {
    const host = required('CONECTALAR_TEST_DB_HOST');
    assert.ok(
      ['127.0.0.1', 'localhost', '::1'].includes(host),
      'O banco de teste deve estar em loopback; bancos remotos nunca sao aceitos.',
    );
    const port = Number(process.env.CONECTALAR_TEST_DB_PORT ?? '3307');
    assert.ok(Number.isInteger(port) && port > 0 && port <= 65_535);
    const user = required('CONECTALAR_TEST_DB_USER');
    const password = process.env.CONECTALAR_TEST_DB_PASSWORD ?? '';
    const database = `conectalar_it_${randomBytes(8).toString('hex')}`;
    const adminConnection = await mysql.createConnection({
      host,
      port,
      user,
      password,
      connectTimeout: 3_000,
    });

    const envKeys = [
      'NODE_ENV',
      'HOST',
      'PORT',
      'DB_HOST',
      'DB_PORT',
      'DB_USER',
      'DB_PASSWORD',
      'DB_NAME',
      'AUTH_TOKEN_SECRET',
      'MFA_SECRET_ENCRYPTION_KEY',
      'EXPOSE_EMAIL_VERIFICATION_CODE',
      'SMTP_HOST',
      'RATE_LIMIT_MAX',
    ];
    const previousEnv = new Map(envKeys.map((key) => [key, process.env[key]]));
    let databaseCreated = false;
    let migrationDataSource;
    let app;

    try {
      await adminConnection.query(
        `CREATE DATABASE \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
      );
      databaseCreated = true;

      process.env.NODE_ENV = 'test';
      process.env.HOST = '127.0.0.1';
      process.env.PORT = '3000';
      process.env.DB_HOST = host;
      process.env.DB_PORT = String(port);
      process.env.DB_USER = user;
      process.env.DB_PASSWORD = password;
      process.env.DB_NAME = database;
      process.env.AUTH_TOKEN_SECRET = randomBytes(48).toString('base64url');
      process.env.MFA_SECRET_ENCRYPTION_KEY = randomBytes(32).toString('hex');
      process.env.EXPOSE_EMAIL_VERIFICATION_CODE = 'true';
      process.env.SMTP_HOST = '';
      process.env.RATE_LIMIT_MAX = '1000';

      const dataSourceModule = await import('../../dist/database/data-source.js');
      const dataSource = dataSourceModule.default.default ?? dataSourceModule.default;
      migrationDataSource = dataSource;
      await migrationDataSource.initialize();
      await migrationDataSource.runMigrations();

      const { createApp } = await import('../../dist/app.factory.js');
      app = await createApp();
      await app.listen(0, '127.0.0.1');
      const address = app.getHttpServer().address();
      assert.ok(address && typeof address === 'object');
      const baseUrl = `http://127.0.0.1:${address.port}`;

      async function request(method, path, token, body, expectedStatus) {
        const response = await fetch(`${baseUrl}/${path}`, {
          method,
          headers: {
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
            ...(body ? { 'Content-Type': 'application/json' } : {}),
          },
          ...(body ? { body: JSON.stringify(body) } : {}),
        });
        const data = await response.json();
        assert.equal(
          response.status,
          expectedStatus,
          `${method} ${path} returned ${response.status}: ${JSON.stringify(data)}`,
        );
        return data;
      }

      async function register(tipo, email, telefone) {
        const cadastro = await request(
          'POST',
          'auth/cadastro',
          null,
          {
            nome: `Teste de integracao ${tipo}`,
            email,
            senha: 'ConectaLarTeste123!',
            tipo,
            aceitouTermos: true,
            versaoTermos: '2026-10-24.v5',
            ...(telefone ? { telefone } : {}),
          },
          201,
        );
        assert.equal(cadastro.emailVerificationRequired, true);
        assert.match(cadastro.devCode ?? '', /^\d{6}$/);
        await request(
          'POST',
          'auth/email/verificacao/confirmar',
          cadastro.token.accessToken,
          { codigo: cadastro.devCode },
          201,
        );
        return cadastro.token.accessToken;
      }

      const suffix = randomUUID().replaceAll('-', '').slice(0, 12);
      const customerEmail = `cliente.${suffix}@example.invalid`;
      const customerPhone = `119${randomInt(10_000_000, 100_000_000)}`;
      const customerToken = await register(
        'cliente',
        customerEmail,
        customerPhone,
      );
      const professionalEmail = `profissional.${suffix}@example.invalid`;
      const professionalToken = await register('profissional', professionalEmail);

      await request('GET', 'clientes/me', null, undefined, 401);
      await request(
        'POST',
        'auth/cadastro',
        null,
        {
          nome: 'Conta duplicada',
          email: customerEmail,
          senha: 'ConectaLarTeste123!',
          tipo: 'cliente',
          aceitouTermos: true,
          versaoTermos: '2026-10-24.v5',
        },
        409,
      );
      await request(
        'POST',
        'auth/cadastro',
        null,
        {
          nome: 'Telefone duplicado',
          email: `duplicado.${suffix}@example.invalid`,
          senha: 'ConectaLarTeste123!',
          tipo: 'cliente',
          telefone: `+55 ${customerPhone.slice(0, 2)} 9${customerPhone.slice(3)}`,
          aceitouTermos: true,
          versaoTermos: '2026-10-24.v5',
        },
        409,
      );

      const perfilCliente = await request(
        'PUT',
        'clientes/me',
        customerToken,
        {
          nome: 'Cliente Integracao',
          bairroPrincipal: 'Centro',
          cidade: 'Sao Paulo',
          uf: 'SP',
        },
        200,
      );
      assert.equal(perfilCliente.cliente.nome, 'Cliente Integracao');

      const endereco = await request(
        'POST',
        'clientes/me/enderecos',
        customerToken,
        {
          apelido: 'Endereco de teste',
          logradouro: 'Rua de Integracao',
          numero: '42',
          bairro: 'Centro',
          cidade: 'Sao Paulo',
          uf: 'SP',
          principal: true,
        },
        201,
      );
      const enderecos = await request(
        'GET',
        'clientes/me/enderecos',
        customerToken,
        undefined,
        200,
      );
      assert.ok(enderecos.enderecos.some((item) => item.id === endereco.endereco.id));

      const categorias = (await request('GET', 'categorias', null, undefined, 200))
        .categorias;
      assert.ok(categorias.length > 0, 'As migrations devem carregar categorias base.');
      const profissional = await request(
        'PUT',
        'profissionais/me',
        professionalToken,
        {
          descricao: 'Perfil profissional ficticio para integracao.',
          bairro: 'Centro',
          cidade: 'Sao Paulo',
          uf: 'SP',
          servicos: [
            {
              nome: 'Servico de teste',
              categoriaId: categorias[0].id,
              duracaoMinutos: 60,
              precoInicial: 100,
            },
            {
              nome: 'Outro servico de teste',
              categoriaId: categorias[0].id,
              duracaoMinutos: 90,
              precoInicial: 140,
            },
          ],
        },
        200,
      );
      const profissionalId = profissional.profissional.id;
      const segundoToken = await register(
        'profissional',
        `profissional.segundo.${suffix}@example.invalid`,
      );
      const segundoPerfil = await request(
        'PUT',
        'profissionais/me',
        segundoToken,
        {
          descricao: 'Segundo perfil ficticio para validar paginacao.',
          bairro: 'Centro',
          cidade: 'Sao Paulo',
          uf: 'SP',
          servicos: [
            {
              nome: 'Segundo servico de teste',
              categoriaId: categorias[0].id,
              duracaoMinutos: 60,
              precoInicial: 120,
            },
          ],
        },
        200,
      );
      const segundoProfissionalId = segundoPerfil.profissional.id;
      await migrationDataSource.query(
        'UPDATE profissionais SET latitude = ?, longitude = ? WHERE id = ?',
        ['-23.5500000', '-46.6300000', profissionalId],
      );
      await migrationDataSource.query(
        'UPDATE profissionais SET latitude = ?, longitude = ? WHERE id = ?',
        ['-23.5600000', '-46.6300000', segundoProfissionalId],
      );

      const buscaPagina1 = await request(
        'GET',
        'profissionais?bairro=Centro&pagina=1&limite=1',
        null,
        undefined,
        200,
      );
      const buscaPagina2 = await request(
        'GET',
        'profissionais?bairro=Centro&pagina=2&limite=1',
        null,
        undefined,
        200,
      );
      assert.equal(buscaPagina1.paginacao.total, 2);
      assert.equal(buscaPagina1.paginacao.temMais, true);
      assert.equal(buscaPagina2.paginacao.temMais, false);
      assert.notEqual(
        buscaPagina1.profissionais[0].id,
        buscaPagina2.profissionais[0].id,
      );
      const buscaCategoria = await request(
        'GET',
        `profissionais?categoriaId=${categorias[0].id}&pagina=1&limite=10`,
        null,
        undefined,
        200,
      );
      const profissionalFiltrado = buscaCategoria.profissionais.find(
        (item) => item.id === profissionalId,
      );
      assert.equal(profissionalFiltrado.servicos.length, 2);
      const buscaDistancia = await request(
        'POST',
        'profissionais/busca',
        null,
        {
          latitude: -23.55,
          longitude: -46.63,
          raioKm: 5,
          pagina: 1,
          limite: 10,
        },
        201,
      );
      assert.equal(buscaDistancia.paginacao.total, 2);
      assert.equal(buscaDistancia.profissionais[0].id, profissionalId);
      assert.equal(buscaDistancia.profissionais[1].id, segundoProfissionalId);
      assert.ok(buscaDistancia.profissionais[1].distanciaKm > 1);

      await request(
        'POST',
        `clientes/me/favoritos/${profissionalId}`,
        customerToken,
        undefined,
        201,
      );
      await request(
        'POST',
        `clientes/me/favoritos/${segundoProfissionalId}`,
        customerToken,
        undefined,
        201,
      );
      const favoritoDireto = await request(
        'GET',
        `clientes/me/favoritos/${profissionalId}`,
        customerToken,
        undefined,
        200,
      );
      assert.equal(favoritoDireto.favorito, true);
      const favoritosPagina1 = await request(
        'GET',
        'clientes/me/favoritos?pagina=1&limite=1',
        customerToken,
        undefined,
        200,
      );
      const favoritosPagina2 = await request(
        'GET',
        'clientes/me/favoritos?pagina=2&limite=1',
        customerToken,
        undefined,
        200,
      );
      assert.equal(favoritosPagina1.paginacao.total, 2);
      assert.equal(favoritosPagina1.paginacao.temMais, true);
      assert.equal(favoritosPagina2.paginacao.temMais, false);
      assert.notEqual(
        favoritosPagina1.favoritos[0].profissional.id,
        favoritosPagina2.favoritos[0].profissional.id,
      );

      await request(
        'PUT',
        'profissionais/me/disponibilidade',
        professionalToken,
        {
          disponibilidades: Array.from({ length: 7 }, (_, diaSemana) => ({
            diaSemana,
            horaInicio: '08:00',
            horaFim: '18:00',
          })),
        },
        200,
      );

      const requisicao = await request(
        'POST',
        'solicitacoes',
        customerToken,
        {
          profissionalId,
          servicoId: profissional.profissional.servicos[0].id,
          enderecoId: endereco.endereco.id,
          descricao: 'Solicitacao ficticia para validar bloqueio de habilitacao.',
          bairroAtendimento: 'Centro',
          dataServico: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000)
            .toISOString()
            .slice(0, 10),
          horarioServico: '10:00',
        },
        409,
      );
      assert.equal(requisicao.statusCode, 409);
      assert.equal(requisicao.message, 'Request could not be processed');
      assert.equal(Object.hasOwn(requisicao, 'code'), false);

      const customerRows = await migrationDataSource.query(
        'SELECT email_verificado FROM usuarios WHERE email = ?',
        [customerEmail],
      );
      assert.equal(Number(customerRows[0].email_verificado), 1);
      const addressRows = await migrationDataSource.query(
        'SELECT COUNT(*) AS total FROM cliente_enderecos WHERE usuario_id = ? AND ativo = 1',
        [(await request('GET', 'clientes/me', customerToken, undefined, 200)).cliente.id],
      );
      assert.equal(Number(addressRows[0].total), 1);
      const requestRows = await migrationDataSource.query(
        'SELECT COUNT(*) AS total FROM solicitacoes',
      );
      assert.equal(Number(requestRows[0].total), 0);

      await verifyAdministrativeLists({
        request,
        migrationDataSource,
        customerEmail,
        customerToken,
        professionalEmail,
        professionalId: profissionalId,
        suffix,
      });
    } finally {
      try {
        if (app) await app.close();
      } finally {
        try {
          if (migrationDataSource?.isInitialized) {
            await migrationDataSource.destroy();
          }
        } finally {
          try {
            if (databaseCreated) {
              await adminConnection.query(
                `DROP DATABASE IF EXISTS \`${database}\``,
              );
            }
          } finally {
            try {
              await adminConnection.end();
            } finally {
              for (const key of envKeys) {
                const value = previousEnv.get(key);
                if (value === undefined) delete process.env[key];
                else process.env[key] = value;
              }
            }
          }
        }
      }
    }
  },
);

function required(name) {
  const value = process.env[name]?.trim();
  assert.ok(value, `Defina ${name} para habilitar o teste MySQL descartavel.`);
  return value;
}

async function verifyAdministrativeLists(context) {
  const {
    request,
    migrationDataSource,
    customerEmail,
    customerToken,
    professionalEmail,
    professionalId,
    suffix,
  } = context;
  const adminEmail = `admin.${suffix}@example.invalid`;
  const adminPassword = 'IntegrationAdmin123!';
  const salt = randomBytes(16);
  const hash = await promisify(scrypt)(adminPassword, salt, 64);
  await migrationDataSource.query(
    `INSERT INTO usuarios
      (nome, email, email_verificado, tipo, senha_hash, ativo)
     VALUES (?, ?, 1, 'administrador', ?, 1)`,
    [
      `Admin de integracao ${suffix}`,
      adminEmail,
      `scrypt$${salt.toString('base64url')}$${hash.toString('base64url')}`,
    ],
  );
  const adminRows = await migrationDataSource.query(
    'SELECT id FROM usuarios WHERE email = ?',
    [adminEmail],
  );
  const adminId = Number(adminRows[0].id);
  const currentTerms = await request('GET', 'termos/atuais', null, undefined, 200);
  await migrationDataSource.query(
    `INSERT INTO termo_aceites (usuario_id, versao, canal, aceito_em)
     VALUES (?, ?, 'integracao', CURRENT_TIMESTAMP(6))`,
    [adminId, currentTerms.termos.versao],
  );

  const adminLogin = await request(
    'POST',
    'auth/login',
    null,
    { email: adminEmail, senha: adminPassword },
    201,
  );
  assert.equal(adminLogin.mfaSetupRequired, true);
  const setup = await request(
    'POST',
    'auth/admin-mfa/setup',
    null,
    { setupToken: adminLogin.mfaSetupToken },
    201,
  );
  const mfaConfirmation = await request(
    'POST',
    'auth/admin-mfa/confirmar',
    null,
    { setupToken: adminLogin.mfaSetupToken, codigo: totp(setup.secret) },
    201,
  );
  const adminToken = mfaConfirmation.token.accessToken;
  assert.ok(adminToken, 'O administrador so recebe sessao depois de concluir MFA.');

  await request('GET', 'admin/usuarios?pagina=1&limite=1', null, undefined, 401);
  await request(
    'GET',
    'admin/usuarios?pagina=1&limite=1',
    customerToken,
    undefined,
    403,
  );

  const usersPage1 = await request(
    'GET',
    'admin/usuarios?pagina=1&limite=1',
    adminToken,
    undefined,
    200,
  );
  const usersPage2 = await request(
    'GET',
    'admin/usuarios?pagina=2&limite=1',
    adminToken,
    undefined,
    200,
  );
  assert.ok(usersPage1.paginacao.total > 1);
  assert.equal(usersPage1.paginacao.temMais, true);
  assert.notEqual(usersPage1.usuarios[0].id, usersPage2.usuarios[0].id);
  const filteredUsers = await request(
    'GET',
    `admin/usuarios?tipo=cliente&termo=${encodeURIComponent(customerEmail)}`,
    adminToken,
    undefined,
    200,
  );
  assert.equal(filteredUsers.paginacao.total, 1);
  assert.equal(filteredUsers.usuarios[0].email, customerEmail);

  const habilitations = await request(
    'GET',
    `admin/profissionais/habilitacoes?estado=pendente&termo=${encodeURIComponent(suffix)}&pagina=1&limite=1`,
    adminToken,
    undefined,
    200,
  );
  assert.equal(habilitations.paginacao.total, 2);
  assert.equal(habilitations.paginacao.temMais, true);
  const habilitationsPage2 = await request(
    'GET',
    `admin/profissionais/habilitacoes?estado=pendente&termo=${encodeURIComponent(suffix)}&pagina=2&limite=1`,
    adminToken,
    undefined,
    200,
  );
  assert.equal(habilitationsPage2.paginacao.temMais, false);
  assert.notEqual(
    habilitations.profissionais[0].id,
    habilitationsPage2.profissionais[0].id,
  );

  const categoryName = `IT ${suffix}`;
  const createdCategory = await request(
    'POST',
    'categorias',
    adminToken,
    { nome: categoryName, icone: 'home_repair', ativo: false },
    201,
  );
  await request(
    'POST',
    'categorias',
    adminToken,
    { nome: `IT ativa ${suffix}`, icone: 'home_repair', ativo: true },
    201,
  );
  const categories = await request(
    'GET',
    `categorias/admin?ativo=false&termo=${encodeURIComponent(categoryName)}&pagina=1&limite=1`,
    adminToken,
    undefined,
    200,
  );
  assert.equal(categories.paginacao.total, 1);
  assert.equal(categories.categorias[0].id, createdCategory.categoria.id);
  const categoriesPage1 = await request(
    'GET',
    'categorias/admin?pagina=1&limite=1',
    adminToken,
    undefined,
    200,
  );
  assert.ok(categoriesPage1.paginacao.total > 1);
  assert.equal(categoriesPage1.paginacao.temMais, true);

  const customerRows = await migrationDataSource.query(
    'SELECT id FROM usuarios WHERE email = ?',
    [customerEmail],
  );
  const customerId = Number(customerRows[0].id);
  const secondProfessionalUserRows = await migrationDataSource.query(
    'SELECT id FROM usuarios WHERE email = ?',
    [`profissional.segundo.${suffix}@example.invalid`],
  );
  const secondProfessionalRows = await migrationDataSource.query(
    'SELECT id FROM profissionais WHERE usuario_id = ?',
    [Number(secondProfessionalUserRows[0].id)],
  );
  const secondProfessionalId = Number(secondProfessionalRows[0].id);
  const professionalUserRows = await migrationDataSource.query(
    'SELECT id FROM usuarios WHERE email = ?',
    [professionalEmail],
  );
  const professionalUserId = Number(professionalUserRows[0].id);
  const categoryRows = await migrationDataSource.query(
    'SELECT id FROM categorias ORDER BY id LIMIT 1',
  );
  const categoryId = Number(categoryRows[0].id);
  const date = new Date(Date.now() + 21 * 24 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
  await migrationDataSource.query(
    `INSERT INTO solicitacoes
      (cliente_id, profissional_id, categoria_id, descricao, bairro_atendimento,
       data_servico, horario_servico, status)
     VALUES (?, ?, ?, ?, 'Centro', ?, '10:00', 'aceita_agendada'),
            (?, ?, ?, ?, 'Centro', ?, '11:00', 'aceita_agendada')`,
    [
      customerId,
      professionalId,
      categoryId,
      `Atendimento de integracao ${suffix}`,
      date,
      customerId,
      secondProfessionalId,
      categoryId,
      `Segundo atendimento de integracao ${suffix}`,
      date,
    ],
  );
  const solicitationRows = await migrationDataSource.query(
    'SELECT id FROM solicitacoes WHERE descricao IN (?, ?) ORDER BY id',
    [
      `Atendimento de integracao ${suffix}`,
      `Segundo atendimento de integracao ${suffix}`,
    ],
  );
  assert.equal(solicitationRows.length, 2);
  const solicitationId1 = Number(solicitationRows[0].id);
  const solicitationId2 = Number(solicitationRows[1].id);
  await migrationDataSource.query(
    `INSERT INTO profissional_documentos_verificacao
      (profissional_id, enviado_por_id, tipo_documento, referencia_arquivo,
       nome_arquivo, status)
     VALUES (?, ?, 'documento_identidade', ?, ?, 'pendente'),
            (?, ?, 'documento_identidade', ?, ?, 'rejeitado')`,
    [
      professionalId,
      professionalUserId,
      `private/${suffix}/one`,
      `documento-${suffix}.pdf`,
      secondProfessionalId,
      Number(secondProfessionalUserRows[0].id),
      `private/${suffix}/two`,
      'outro-documento.pdf',
    ],
  );
  const documents = await request(
    'GET',
    `documentos-verificacao?status=pendente&tipoDocumento=documento_identidade&termo=${encodeURIComponent(`documento-${suffix}`)}&pagina=1&limite=1`,
    adminToken,
    undefined,
    200,
  );
  assert.equal(documents.paginacao.total, 1);
  assert.equal(documents.documentos[0].nomeArquivo, `documento-${suffix}.pdf`);
  const documentsPage = await request(
    'GET',
    'documentos-verificacao?pagina=1&limite=1',
    adminToken,
    undefined,
    200,
  );
  assert.equal(documentsPage.paginacao.temMais, true);
  const documentsPage2 = await request(
    'GET',
    'documentos-verificacao?pagina=2&limite=1',
    adminToken,
    undefined,
    200,
  );
  assert.equal(documentsPage2.paginacao.temMais, false);
  assert.notEqual(documentsPage.documentos[0].id, documentsPage2.documentos[0].id);

  await migrationDataSource.query(
    `INSERT INTO denuncias
      (solicitacao_id, denunciante_id, denunciado_id, motivo, descricao, status)
     VALUES (?, ?, ?, 'conduta_inadequada', ?, 'pendente'),
            (?, ?, ?, 'conduta_inadequada', ?, 'resolvida')`,
    [
      solicitationId1,
      customerId,
      professionalUserId,
      `Denuncia de integracao ${suffix}`,
      solicitationId2,
      customerId,
      Number(secondProfessionalUserRows[0].id),
      `Outra denuncia ${suffix}`,
    ],
  );
  const reports = await request(
    'GET',
    `denuncias/moderacao?status=pendente&termo=${encodeURIComponent(suffix)}&pagina=1&limite=1`,
    adminToken,
    undefined,
    200,
  );
  assert.equal(reports.paginacao.total, 1);
  assert.match(reports.denuncias[0].descricao, new RegExp(suffix));
  const reportsPage = await request(
    'GET',
    `denuncias/moderacao?termo=${encodeURIComponent(suffix)}&pagina=1&limite=1`,
    adminToken,
    undefined,
    200,
  );
  assert.equal(reportsPage.paginacao.total, 2);
  assert.equal(reportsPage.paginacao.temMais, true);

  await migrationDataSource.query(
    `INSERT INTO avaliacoes
      (solicitacao_id, avaliador_id, avaliado_id, nota, comentario, moderacao_status)
     VALUES (?, ?, ?, 5, ?, 'pendente'),
            (?, ?, ?, 4, ?, 'aprovada')`,
    [
      solicitationId1,
      customerId,
      professionalUserId,
      `Avaliacao de integracao ${suffix}`,
      solicitationId2,
      customerId,
      Number(secondProfessionalUserRows[0].id),
      `Outra avaliacao ${suffix}`,
    ],
  );
  const reviews = await request(
    'GET',
    `avaliacoes/moderacao?status=pendente&termo=${encodeURIComponent(suffix)}&pagina=1&limite=1`,
    adminToken,
    undefined,
    200,
  );
  assert.equal(reviews.paginacao.total, 1);
  assert.match(reviews.avaliacoes[0].comentario, new RegExp(suffix));
  const reviewsPage = await request(
    'GET',
    `avaliacoes/moderacao?status=todas&termo=${encodeURIComponent(suffix)}&pagina=1&limite=1`,
    adminToken,
    undefined,
    200,
  );
  assert.equal(reviewsPage.paginacao.total, 2);
  assert.equal(reviewsPage.paginacao.temMais, true);

  const audit = await request(
    'GET',
    `admin/painel/auditoria?atorId=${adminId}&alvoTipo=categoria&pagina=1&limite=1`,
    adminToken,
    undefined,
    200,
  );
  assert.equal(audit.paginacao.total, 2);
  assert.ok(audit.eventos.every((event) => event.ator.id === adminId));
  assert.equal(audit.paginacao.limite, 1);
  assert.equal(audit.paginacao.temMais, true);
  const auditPage2 = await request(
    'GET',
    `admin/painel/auditoria?atorId=${adminId}&alvoTipo=categoria&pagina=2&limite=1`,
    adminToken,
    undefined,
    200,
  );
  assert.equal(auditPage2.paginacao.temMais, false);
  assert.notEqual(audit.eventos[0].id, auditPage2.eventos[0].id);
}

function totp(secret, now = Date.now()) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  const bits = [...secret]
    .map((character) => alphabet.indexOf(character).toString(2).padStart(5, '0'))
    .join('');
  const key = Buffer.from(
    bits.match(/.{8}/g).map((byte) => Number.parseInt(byte, 2)),
  );
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(now / 30_000)));
  const digest = createHmac('sha1', key).update(counter).digest();
  const offset = digest[digest.length - 1] & 0x0f;
  const binary =
    ((digest[offset] & 0x7f) << 24) |
    (digest[offset + 1] << 16) |
    (digest[offset + 2] << 8) |
    digest[offset + 3];
  return String(binary % 1_000_000).padStart(6, '0');
}
