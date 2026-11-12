import assert from 'node:assert/strict';
import { DocumentoStorageService } from '../dist/verificacao/documento-storage.service.js';
import { MalwareScannerService } from '../dist/verificacao/malware-scanner.service.js';

const accountId = required('R2_PILOT_ACCOUNT_ID');
const bucket = required('R2_PILOT_BUCKET');
const accessKeyId = required('R2_PILOT_ACCESS_KEY_ID');
const secretAccessKey = required('R2_PILOT_SECRET_ACCESS_KEY');
const confirmation = required('R2_PILOT_CONFIRM_BUCKET');

if (!/^[a-f0-9]{32}$/iu.test(accountId)) {
  throw new Error('R2 pilot Account ID must contain 32 hexadecimal characters.');
}
if (confirmation !== bucket) {
  throw new Error('R2_PILOT_CONFIRM_BUCKET must exactly match R2_PILOT_BUCKET.');
}
if (!/^conectalar-(piloto|pilot|homologacao|teste)-[a-z0-9](?:[a-z0-9-]{0,46}[a-z0-9])?$/u.test(bucket)) {
  throw new Error('Use a dedicated bucket named conectalar-piloto-<identificador>.');
}

const endpoint = process.env.R2_PILOT_ENDPOINT?.trim() ||
  `https://${accountId}.r2.cloudflarestorage.com`;
const endpointUrl = new URL(endpoint);
const loopbackHosts = new Set(['127.0.0.1', 'localhost', '[::1]']);
if (
  endpointUrl.username || endpointUrl.password || endpointUrl.search || endpointUrl.hash ||
  (endpointUrl.protocol !== 'https:' && !loopbackHosts.has(endpointUrl.hostname))
) {
  throw new Error('R2 pilot endpoint must use HTTPS (HTTP is allowed only on loopback).');
}

const config = {
  NODE_ENV: 'test',
  FILE_STORAGE_DRIVER: 'r2',
  MALWARE_SCAN_MODE: 'required',
  R2_ACCOUNT_ID: accountId,
  R2_BUCKET: bucket,
  R2_ACCESS_KEY_ID: accessKeyId,
  R2_SECRET_ACCESS_KEY: secretAccessKey,
  R2_REGION: process.env.R2_PILOT_REGION?.trim() || 'auto',
  R2_ENDPOINT: endpoint,
  CLAMAV_HOST: process.env.R2_PILOT_CLAMAV_HOST?.trim() || '127.0.0.1',
  CLAMAV_PORT: process.env.R2_PILOT_CLAMAV_PORT?.trim() || '3310',
  CLAMAV_TIMEOUT_MS: process.env.R2_PILOT_CLAMAV_TIMEOUT_MS?.trim() || '10000',
};
const previous = Object.fromEntries(
  Object.keys(config).map((key) => [key, process.env[key]]),
);
for (const [key, value] of Object.entries(config)) process.env[key] = value;

const scanner = new MalwareScannerService();
const storage = new DocumentoStorageService();
const syntheticPdf = Buffer.from(
  '%PDF-1.4\n% ConectaLar synthetic integration fixture; no personal data.\n%%EOF\n',
  'ascii',
);
const eicar = Buffer.from(
  String.raw`X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*`,
  'ascii',
);
let reference;
let stage = 'ClamAV clean-file scan';

try {
  const cleanScan = await scanner.scanBuffer(syntheticPdf);
  assert.equal(cleanScan.scannerAvailable, true, 'ClamAV must be reachable.');
  assert.equal(cleanScan.clean, true, 'Synthetic clean fixture should pass ClamAV.');

  stage = 'ClamAV EICAR detection';
  const infectedScan = await scanner.scanBuffer(eicar);
  assert.equal(infectedScan.scannerAvailable, true, 'ClamAV must be reachable.');
  assert.equal(infectedScan.clean, false, 'ClamAV must detect the EICAR test signature.');

  stage = 'R2 upload';
  reference = await storage.salvar(0, syntheticPdf, 'application/pdf');
  assert.match(reference, /^r2:\/\/documentos-verificacao\/0\/[0-9a-f-]+\.pdf$/u);

  stage = 'R2 download and content comparison';
  const stored = await storage.carregar(0, reference, 'conectalar-piloto-sintetico.pdf');
  assert.deepEqual(stored.bytes, syntheticPdf, 'R2 bytes differ from the synthetic upload.');
  assert.equal(stored.mimeType, 'application/pdf');

  stage = 'R2 cleanup';
  await storage.remover(reference);
  reference = undefined;

  console.log('Combined R2 + ClamAV pilot passed.');
  console.log('ClamAV: clean fixture accepted; EICAR test signature detected.');
  console.log('R2: synthetic clean fixture PUT, GET, byte comparison, and DELETE passed.');
  console.log(`Pilot bucket: ${bucket}`);
} catch (error) {
  const detail = safeErrorDetail(error);
  console.error(
    `Combined pilot failed during ${stage}${detail ? ` (${detail})` : ''}. Check the relevant service and pilot configuration.`,
  );
  process.exitCode = 1;
} finally {
  if (reference !== undefined) {
    try {
      await storage.remover(reference);
      console.warn('Cleanup was attempted for the unique synthetic R2 object.');
    } catch {
      console.error(`Cleanup failed; remove this synthetic object manually: ${reference}`);
      process.exitCode = 1;
    }
  }
  for (const [key, value] of Object.entries(previous)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
}

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

function safeErrorDetail(error) {
  if (typeof error !== 'object' || error === null) return '';
  const labels = [];
  const code = error.Code ?? error.code ?? error.name;
  if (typeof code === 'string' && /^[A-Za-z0-9_.-]{1,80}$/u.test(code)) {
    labels.push(code);
  }
  const status = error.$metadata?.httpStatusCode;
  if (Number.isInteger(status) && status >= 100 && status <= 599) {
    labels.push(`HTTP ${status}`);
  }
  return labels.join(', ');
}
