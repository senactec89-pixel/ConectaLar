import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';

const accountId = required('R2_PILOT_ACCOUNT_ID');
const bucket = required('R2_PILOT_BUCKET');
const accessKeyId = required('R2_PILOT_ACCESS_KEY_ID');
const secretAccessKey = required('R2_PILOT_SECRET_ACCESS_KEY');
const confirmation = required('R2_PILOT_CONFIRM_BUCKET');

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
const region = process.env.R2_PILOT_REGION?.trim() || 'auto';
const key = `conectalar-r2-pilot/${randomUUID()}.txt`;
const marker = Buffer.from(`ConectaLar R2 pilot ${randomUUID()}; no personal data.`);
const client = new S3Client({
  region,
  endpoint,
  credentials: { accessKeyId, secretAccessKey },
});
let putAttempted = false;

try {
  putAttempted = true;
  await client.send(new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    Body: marker,
    ContentType: 'text/plain; charset=utf-8',
  }));

  const object = await client.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
  assert.ok(object.Body, 'R2 returned no object body.');
  const downloaded = Buffer.from(await object.Body.transformToByteArray());
  assert.deepEqual(downloaded, marker, 'Downloaded object differs from the upload.');

  await client.send(new DeleteObjectCommand({ Bucket: bucket, Key: key }));
  putAttempted = false;
  console.log('R2 pilot passed: PUT, GET, content comparison, and DELETE succeeded.');
  console.log(`Pilot bucket: ${bucket}`);
} catch {
  console.error('R2 pilot failed. Check endpoint, bucket scope, and Object Read & Write permissions.');
  process.exitCode = 1;
} finally {
  if (putAttempted) {
    try {
      await client.send(new DeleteObjectCommand({ Bucket: bucket, Key: key }));
      console.warn('Cleanup DELETE was attempted for the unique pilot object.');
    } catch {
      console.error(`Cleanup failed; remove this test object manually if it exists: ${key}`);
      process.exitCode = 1;
    }
  }
  client.destroy();
}

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}
