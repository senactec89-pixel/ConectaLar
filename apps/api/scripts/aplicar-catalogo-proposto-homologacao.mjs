import mysql from 'mysql2/promise';
import { importarCatalogoProposto } from './catalogo-proposto.mjs';

if (process.env.CONECTALAR_STAGE !== 'homologacao' ||
    process.env.DB_NAME !== 'conectalar_homologacao' ||
    process.env.APLICAR_CATALOGO_PROPOSTO !== 'SIM') {
  throw new Error('Carga bloqueada: execute somente na homologacao com confirmacao explicita.');
}

const connection = await mysql.createConnection({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT ?? 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  multipleStatements: false,
});

try {
  const resultado = await importarCatalogoProposto(connection);
  console.log(JSON.stringify({ status: 'ok', ambiente: 'homologacao', ...resultado }));
} finally {
  await connection.end();
}
