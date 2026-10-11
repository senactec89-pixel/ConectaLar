import { randomBytes, scrypt } from 'node:crypto';
import { promisify } from 'node:util';
import mysql from 'mysql2/promise';

const scryptAsync = promisify(scrypt);
const keyLength = 64;
const demoPassword = process.env.DEMO_PASSWORD ?? 'ConectaLarDemo123!';

const config = {
  host: process.env.DB_HOST ?? '127.0.0.1',
  port: Number(process.env.DB_PORT ?? 3307),
  user: process.env.DB_USER ?? 'conectalar_app',
  password: process.env.DB_PASSWORD ?? '',
  database: process.env.DB_NAME ?? 'conectalar_dev',
  multipleStatements: false,
};

const users = {
  cliente: {
    nome: 'Mariana Alves Demo',
    email: 'cliente.demo@conectalar.local',
    telefone: '31990000001',
    tipo: 'cliente',
  },
  profissional: {
    nome: 'Carlos Silva Demo',
    email: 'profissional.demo@conectalar.local',
    telefone: '31990000002',
    tipo: 'profissional',
  },
  admin: {
    nome: 'Admin ConectaLar Demo',
    email: 'admin.demo@conectalar.local',
    telefone: '31990000003',
    tipo: 'administrador',
  },
};

const categories = [
  'Eletrica',
  'Hidraulica',
  'Pintura',
  'Limpeza',
  'Manutencao',
  'Ar-condicionado',
  'Reformas',
  'Outros',
];

async function main() {
  const db = await mysql.createConnection(config);
  try {
    await db.beginTransaction();
    await seedCategories(db);
    const ids = {
      cliente: await upsertUser(db, users.cliente),
      profissionalUsuario: await upsertUser(db, users.profissional),
      admin: await upsertUser(db, users.admin),
    };
    ids.profissional = await upsertProfessional(db, ids.profissionalUsuario);
    await resetDemoData(db, ids);
    ids.enderecoCliente = await seedClientProfile(db, ids.cliente);
    await seedProfessionalChildren(db, ids.profissional, ids.profissionalUsuario);
    const solicitacoes = await seedRequests(db, ids);
    await seedMessages(db, ids, solicitacoes);
    await seedReviews(db, ids, solicitacoes);
    await seedReports(db, ids, solicitacoes);
    await seedDocuments(db, ids);
    await seedNotifications(db, ids, solicitacoes);
    await db.commit();

    console.log('Seed demo concluido.');
    console.log(`Senha de todos os usuarios demo: ${demoPassword}`);
    console.log(`Cliente: ${users.cliente.email}`);
    console.log(`Profissional: ${users.profissional.email}`);
    console.log(`Admin: ${users.admin.email}`);
  } catch (error) {
    await db.rollback();
    console.error('Seed demo falhou.');
    console.error(error);
    process.exitCode = 1;
  } finally {
    await db.end();
  }
}

async function hashPassword(password) {
  const salt = randomBytes(16);
  const derivedKey = await scryptAsync(password, salt, keyLength);
  return `scrypt$${salt.toString('base64url')}$${derivedKey.toString('base64url')}`;
}

async function seedCategories(db) {
  for (const nome of categories) {
    await db.execute(
      `INSERT INTO categorias (nome, ativo)
       VALUES (?, 1)
       ON DUPLICATE KEY UPDATE ativo = VALUES(ativo)`,
      [nome],
    );
  }
}

async function upsertUser(db, user) {
  const senhaHash = await hashPassword(demoPassword);
  await db.execute(
    `INSERT INTO usuarios (nome, email, telefone, tipo, senha_hash, ativo)
     VALUES (?, ?, ?, ?, ?, 1)
     ON DUPLICATE KEY UPDATE
       nome = VALUES(nome),
       telefone = VALUES(telefone),
       tipo = VALUES(tipo),
       senha_hash = VALUES(senha_hash),
       ativo = 1,
       token_version = token_version + 1`,
    [user.nome, user.email, user.telefone, user.tipo, senhaHash],
  );
  return singleValue(db, 'SELECT id FROM usuarios WHERE email = ?', [user.email]);
}

async function upsertProfessional(db, usuarioId) {
  await db.execute(
    `INSERT INTO profissionais
       (usuario_id, descricao, bairro, preco_inicial, verificado, ativo)
     VALUES
       (?, 'Eletricista residencial com foco em reparos, instalacoes e manutencao preventiva.', 'Jardim das Flores', 80.00, 1, 1)
     ON DUPLICATE KEY UPDATE
       descricao = VALUES(descricao),
       bairro = VALUES(bairro),
       preco_inicial = VALUES(preco_inicial),
       verificado = VALUES(verificado),
       ativo = VALUES(ativo)`,
    [usuarioId],
  );
  return singleValue(db, 'SELECT id FROM profissionais WHERE usuario_id = ?', [
    usuarioId,
  ]);
}

async function resetDemoData(db, ids) {
  const [solicitacoes] = await db.execute(
    `SELECT id FROM solicitacoes
     WHERE cliente_id = ? OR profissional_id = ?`,
    [ids.cliente, ids.profissional],
  );
  const solicitacaoIds = solicitacoes.map((item) => item.id);
  if (solicitacaoIds.length > 0) {
    const placeholders = solicitacaoIds.map(() => '?').join(', ');
    await db.execute(
      `DELETE FROM denuncias WHERE solicitacao_id IN (${placeholders})`,
      solicitacaoIds,
    );
    await db.execute(
      `DELETE FROM avaliacoes WHERE solicitacao_id IN (${placeholders})`,
      solicitacaoIds,
    );
    await db.execute(
      `DELETE FROM mensagens_atendimento WHERE solicitacao_id IN (${placeholders})`,
      solicitacaoIds,
    );
    await db.execute(
      `DELETE FROM notificacoes WHERE recurso_tipo = 'solicitacao' AND recurso_id IN (${placeholders})`,
      solicitacaoIds,
    );
    await db.execute(
      `DELETE FROM solicitacoes WHERE id IN (${placeholders})`,
      solicitacaoIds,
    );
  }

  await db.execute('DELETE FROM profissional_documentos_verificacao WHERE profissional_id = ?', [
    ids.profissional,
  ]);
  await db.execute('DELETE FROM profissional_disponibilidades WHERE profissional_id = ?', [
    ids.profissional,
  ]);
  await db.execute('DELETE FROM profissional_servicos WHERE profissional_id = ?', [
    ids.profissional,
  ]);
  await db.execute(
    'DELETE FROM notificacoes WHERE usuario_id IN (?, ?, ?) AND recurso_tipo IS NULL',
    [ids.cliente, ids.profissionalUsuario, ids.admin],
  );
}

async function seedClientProfile(db, clienteId) {
  await db.execute(
    `INSERT INTO cliente_perfis
       (usuario_id, bairro_principal, cidade, uf, observacoes)
     VALUES
       (?, 'Jardim das Flores', 'Belo Horizonte', 'MG', 'Perfil demo para testes locais.')
     ON DUPLICATE KEY UPDATE
       bairro_principal = VALUES(bairro_principal),
       cidade = VALUES(cidade),
       uf = VALUES(uf),
       observacoes = VALUES(observacoes)`,
    [clienteId],
  );
  await db.execute('DELETE FROM cliente_enderecos WHERE usuario_id = ?', [clienteId]);
  await db.execute(
    `INSERT INTO cliente_enderecos
       (usuario_id, apelido, cep, logradouro, numero, complemento, bairro, cidade, uf, principal, ativo)
     VALUES
       (?, 'Casa demo', '30140-000', 'Rua Demo Protegida', '123', 'Apto 301', 'Jardim das Flores', 'Belo Horizonte', 'MG', 1, 1)`,
    [clienteId],
  );
  const [enderecos] = await db.execute(
    'SELECT id FROM cliente_enderecos WHERE usuario_id = ? AND principal = 1 LIMIT 1',
    [clienteId],
  );
  return enderecos[0].id;
}

async function seedProfessionalChildren(db, profissionalId, profissionalUsuarioId) {
  const eletricaId = await categoryId(db, 'Eletrica');
  const manutencaoId = await categoryId(db, 'Manutencao');
  const arId = await categoryId(db, 'Ar-condicionado');
  const services = [
    [profissionalId, eletricaId, 'Instalacao eletrica', 80],
    [profissionalId, manutencaoId, 'Reparos e manutencao', 70],
    [profissionalId, arId, 'Instalacao de ventilador', 90],
  ];
  for (const service of services) {
    await db.execute(
      `INSERT INTO profissional_servicos
         (profissional_id, categoria_id, nome, preco_inicial, ativo)
       VALUES (?, ?, ?, ?, 1)`,
      service,
    );
  }

  for (const day of [1, 2, 3, 4, 5]) {
    await db.execute(
      `INSERT INTO profissional_disponibilidades
         (profissional_id, dia_semana, hora_inicio, hora_fim, ativo)
       VALUES (?, ?, '08:00', '18:00', 1)`,
      [profissionalId, day],
    );
  }

  await db.execute(
    `INSERT INTO notificacoes
       (usuario_id, tipo, titulo, mensagem, recurso_tipo, recurso_id, lida)
     VALUES
       (?, 'documento_aprovado', 'Selo de verificacao ativo', 'Seu perfil demo esta verificado para testes locais.', NULL, NULL, 0)`,
    [profissionalUsuarioId],
  );
}

async function seedRequests(db, ids) {
  const eletricaId = await categoryId(db, 'Eletrica');
  const manutencaoId = await categoryId(db, 'Manutencao');
  const today = new Date();
  const dates = {
    tomorrow: isoDate(addDays(today, 1)),
    plusTwo: isoDate(addDays(today, 2)),
    plusFive: isoDate(addDays(today, 5)),
    minusTwo: isoDate(addDays(today, -2)),
    minusFive: isoDate(addDays(today, -5)),
  };
  const requests = [
    [
      ids.cliente,
      ids.profissional,
      eletricaId,
      ids.enderecoCliente,
      'Minha tomada nao esta funcionando e preciso de verificacao no circuito.',
      'Jardim das Flores',
      dates.tomorrow,
      '10:00',
      80,
      'aguardando_resposta',
    ],
    [
      ids.cliente,
      ids.profissional,
      eletricaId,
      ids.enderecoCliente,
      'Instalacao eletrica para novo chuveiro.',
      'Jardim das Flores',
      dates.plusTwo,
      '14:00',
      80,
      'aceita_agendada',
    ],
    [
      ids.cliente,
      ids.profissional,
      manutencaoId,
      ids.enderecoCliente,
      'Manutencao preventiva em quadro de energia residencial.',
      'Centro',
      dates.plusFive,
      '09:00',
      70,
      'aceita_agendada',
    ],
    [
      ids.cliente,
      ids.profissional,
      manutencaoId,
      ids.enderecoCliente,
      'Troca de tomada concluida para teste de historico.',
      'Jardim das Flores',
      dates.minusTwo,
      '16:00',
      70,
      'conclusao_confirmada',
    ],
    [
      ids.cliente,
      ids.profissional,
      eletricaId,
      ids.enderecoCliente,
      'Pedido recusado para validar filtros.',
      'Centro',
      dates.minusFive,
      '08:00',
      80,
      'recusada',
    ],
  ];

  const idsByStatus = {};
  for (const request of requests) {
    const [result] = await db.execute(
      `INSERT INTO solicitacoes
         (cliente_id, profissional_id, categoria_id, endereco_id, descricao, bairro_atendimento, data_servico, horario_servico, preco_inicial, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      request,
    );
    idsByStatus[request[9]] ??= result.insertId;
  }

  return idsByStatus;
}

async function seedMessages(db, ids, solicitacoes) {
  await db.execute(
    `INSERT INTO mensagens_atendimento (solicitacao_id, autor_id, conteudo)
     VALUES
       (?, ?, 'Ola, posso atender nesse horario. O endereco completo fica protegido ate o aceite valido.'),
       (?, ?, 'Perfeito, fico aguardando a confirmacao.')`,
    [
      solicitacoes.aceita_agendada,
      ids.profissionalUsuario,
      solicitacoes.aceita_agendada,
      ids.cliente,
    ],
  );
}

async function seedReviews(db, ids, solicitacoes) {
  await db.execute(
    `INSERT INTO avaliacoes
       (solicitacao_id, avaliador_id, avaliado_id, nota, comentario, moderacao_status)
     VALUES
       (?, ?, ?, 5, 'Atendimento demo concluido com boa comunicacao.', 'pendente')`,
    [solicitacoes.conclusao_confirmada, ids.cliente, ids.profissionalUsuario],
  );
}

async function seedReports(db, ids, solicitacoes) {
  await db.execute(
    `INSERT INTO denuncias
       (solicitacao_id, denunciante_id, denunciado_id, motivo, descricao, status)
     VALUES
       (?, ?, ?, 'comunicacao', 'Denuncia demo pendente para validar moderacao administrativa.', 'pendente')`,
    [solicitacoes.aceita_agendada, ids.cliente, ids.profissionalUsuario],
  );
}

async function seedDocuments(db, ids) {
  await db.execute(
    `INSERT INTO profissional_documentos_verificacao
       (profissional_id, enviado_por_id, tipo_documento, referencia_arquivo, nome_arquivo, observacao, status)
     VALUES
       (?, ?, 'documento_identificacao', 'demo/documento-identificacao.pdf', 'documento-identificacao.pdf', 'Documento demo aprovado previamente.', 'aprovado'),
       (?, ?, 'comprovante_endereco', 'demo/comprovante-endereco.pdf', 'comprovante-endereco.pdf', 'Documento demo pendente para analise administrativa.', 'pendente'),
       (?, ?, 'certificado_profissional', 'demo/certificado-eletrica.pdf', 'certificado-eletrica.pdf', 'Certificado opcional demo.', 'rejeitado')`,
    [
      ids.profissional,
      ids.profissionalUsuario,
      ids.profissional,
      ids.profissionalUsuario,
      ids.profissional,
      ids.profissionalUsuario,
    ],
  );
}

async function seedNotifications(db, ids, solicitacoes) {
  await db.execute(
    `INSERT INTO notificacoes
       (usuario_id, tipo, titulo, mensagem, recurso_tipo, recurso_id, lida)
     VALUES
       (?, 'solicitacao_criada', 'Nova solicitacao recebida', 'Voce recebeu uma solicitacao demo.', 'solicitacao', ?, 0),
       (?, 'solicitacao_aceita', 'Solicitacao aceita', 'O profissional aceitou uma solicitacao demo.', 'solicitacao', ?, 0),
       (?, 'documento_pendente', 'Documento em analise', 'Existe um documento demo aguardando analise.', NULL, NULL, 0)`,
    [
      ids.profissionalUsuario,
      solicitacoes.aguardando_resposta,
      ids.cliente,
      solicitacoes.aceita_agendada,
      ids.admin,
    ],
  );
}

async function categoryId(db, nome) {
  return singleValue(db, 'SELECT id FROM categorias WHERE nome = ?', [nome]);
}

async function singleValue(db, sql, params) {
  const [rows] = await db.execute(sql, params);
  if (rows.length === 0) {
    throw new Error(`Registro esperado nao encontrado: ${sql}`);
  }
  return rows[0].id;
}

function addDays(date, days) {
  const copy = new Date(date);
  copy.setUTCDate(copy.getUTCDate() + days);
  return copy;
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

main();
