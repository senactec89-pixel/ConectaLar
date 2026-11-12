import mysql from 'mysql2/promise';

const config = {
  host: process.env.DB_HOST ?? '127.0.0.1',
  port: Number(process.env.DB_PORT ?? 3307),
  user: process.env.DB_USER ?? 'conectalar_app',
  password: process.env.DB_PASSWORD ?? 'ConectaLarDev123!',
  database: process.env.DB_NAME ?? 'conectalar_dev',
  multipleStatements: false,
};

if (config.host !== '127.0.0.1' || config.port !== 3307 || config.database !== 'conectalar_dev') {
  throw new Error('This test seed only runs against 127.0.0.1:3307/conectalar_dev.');
}

const suggestions = new Map(Object.entries({
  'diagnostico de falha eletrica': ['Tomada ou interruptor sem funcionar', 'Luminaria ou circuito com falha', 'Disjuntor desarmando'],
  'instalacao de ventilador de teto': ['Instalar ventilador em ponto existente', 'Substituir ventilador existente', 'Conferir compatibilidade do suporte existente'],
  'instalacao ou troca de luminaria': ['Instalar luminaria em ponto existente', 'Substituir luminaria existente', 'Montar luminaria fornecida pelo cliente'],
  'troca de chuveiro eletrico': ['Substituir chuveiro em ponto existente', 'Instalar chuveiro fornecido pelo cliente', 'Conferir modelo e compatibilidade antes do servico'],
  'troca de disjuntor': ['Substituir disjuntor existente', 'Avaliar disjuntor que desarma', 'Conferir identificacao do circuito'],
  'troca de interruptor': ['Substituir interruptor simples', 'Substituir conjunto com mais de uma tecla', 'Instalar interruptor fornecido pelo cliente'],
  'troca de tomada': ['Substituir tomada simples', 'Substituir conjunto de tomadas', 'Instalar tomada fornecida pelo cliente'],
  'desentupimento simples': ['Desentupir pia ou lavatorio', 'Desentupir ralo de banheiro', 'Desentupir vaso sanitario'],
  'instalacao de filtro de agua': ['Instalar filtro em torneira compativel', 'Instalar filtro em ponto existente', 'Trocar refil de filtro existente'],
  'reparo de descarga': ['Ajustar mecanismo interno da caixa', 'Substituir mecanismo fornecido pelo cliente', 'Corrigir acionamento ou vedacao aparente'],
  'reparo de vazamento aparente': ['Vazamento visivel em torneira', 'Vazamento visivel em sifao', 'Vazamento em conexao acessivel'],
  'troca de sifao': ['Trocar sifao de pia de cozinha', 'Trocar sifao de lavatorio', 'Instalar sifao fornecido pelo cliente'],
  'troca de torneira': ['Trocar torneira de cozinha', 'Trocar torneira de banheiro', 'Instalar torneira fornecida pelo cliente'],
  'desmontagem e remontagem de moveis': ['Desmontar e remontar um movel', 'Desmontar e remontar mais de um movel', 'Montagem no mesmo endereco'],
  'montagem de armario de cozinha': ['Montar modulo de piso', 'Montar conjunto de modulos de piso', 'Montar modulo fornecido pelo cliente'],
  'montagem de beliche': ['Montar beliche convencional', 'Montar beliche com gavetas', 'Montar modelo conforme manual fornecido'],
  'montagem de cadeira': ['Montar uma cadeira', 'Montar conjunto de cadeiras', 'Montar cadeira de escritorio'],
  'montagem de cama': ['Montar cama de solteiro', 'Montar cama de casal', 'Montar cama com gavetas'],
  'montagem de comoda': ['Montar comoda pequena', 'Montar comoda media', 'Montar comoda conforme manual'],
  'montagem de estante': ['Montar estante baixa autoportante', 'Montar estante modular', 'Montar estante conforme manual'],
  'montagem de guarda-roupa': ['Montar guarda-roupa de duas portas', 'Montar guarda-roupa de tres portas', 'Montar modelo conforme manual'],
  'montagem de mesa': ['Montar mesa de jantar', 'Montar mesa de escritorio', 'Montar mesa lateral ou de apoio'],
  'montagem de rack e painel': ['Montar rack autoportante', 'Montar rack de piso', 'Montar somente o rack sem fixacao na parede'],
  'aplicacao de massa corrida': ['Aplicar massa em reparo pequeno', 'Aplicar massa em uma parede', 'Preparar superficie para pintura'],
  'pintura de grades': ['Pintar grade pequena ao nivel do solo', 'Pintar portao ao nivel do solo', 'Pintar trecho localizado de grade'],
  'pintura de janelas e esquadrias': ['Pintar janela pelo lado interno', 'Pintar esquadria de madeira acessivel', 'Pintar esquadria metalica acessivel'],
  'pintura de paredes internas': ['Pintar um comodo', 'Pintar uma parede', 'Retocar parede interna'],
  'pintura de portas': ['Pintar uma porta interna', 'Pintar porta e batente', 'Retocar pintura de porta'],
  'pintura de tetos': ['Pintar teto de um comodo', 'Retocar trecho pequeno do teto', 'Pintar teto apos preparo da superficie'],
  'pintura externa terrea': ['Pintar parede externa ao nivel do solo', 'Retocar fachada acessivel do solo', 'Pintar muro baixo acessivel'],
  'retoques de pintura': ['Retocar pequena area de parede', 'Retocar marcas localizadas', 'Retocar pintura em uma porta'],
}));

function normalize(value) {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim();
}

const connection = await mysql.createConnection(config);
try {
  await connection.beginTransaction();
  const [admins] = await connection.execute(
    "SELECT id FROM usuarios WHERE tipo = 'administrador' AND ativo = 1 ORDER BY id LIMIT 1",
  );
  if (admins.length === 0) throw new Error('No active local administrator exists for audit logging.');
  const adminId = admins[0].id;
  const [services] = await connection.execute(
    `SELECT sc.id, sc.nome, sc.categoria_id, cat.nome AS categoria_nome
     FROM servicos_catalogo sc JOIN categorias cat ON cat.id = sc.categoria_id
     WHERE sc.ativo = 1 AND cat.ativo = 1 ORDER BY sc.id`,
  );

  const missing = services.filter((service) => !suggestions.has(normalize(service.nome)));
  if (missing.length > 0) {
    throw new Error(`No local test suggestions defined for: ${missing.map((item) => item.nome).join(', ')}`);
  }

  let insertedOrActivated = 0;
  for (const service of services) {
    const options = suggestions.get(normalize(service.nome));
    for (const name of options) {
      const [result] = await connection.execute(
        `INSERT INTO servico_catalogo_opcoes (servico_catalogo_id, nome, ativo)
         VALUES (?, ?, 1)
         ON DUPLICATE KEY UPDATE ativo = 1`,
        [service.id, name],
      );
      insertedOrActivated += result.affectedRows;
    }
    await connection.execute(
      `INSERT INTO admin_auditoria (ator_id, acao, alvo_tipo, alvo_id, detalhe)
       VALUES (?, 'servico_catalogo_atualizado', 'servico_catalogo', ?, ?)`,
      [adminId, service.id, JSON.stringify({ operacao: 'seed_teste_local_opcoes_ativas', opcoes: options })],
    );
  }
  await connection.commit();
  console.log(JSON.stringify({ status: 'ok', database: `${config.host}:${config.port}/${config.database}`, services: services.length, suggestionsPerService: 3, insertedOrActivated }));
} catch (error) {
  await connection.rollback();
  throw error;
} finally {
  await connection.end();
}
