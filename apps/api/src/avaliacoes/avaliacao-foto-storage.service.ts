import { Injectable, NotFoundException } from '@nestjs/common';
import { DeleteObjectCommand, GetObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { randomUUID } from 'node:crypto';
import { dirname, join } from 'node:path';
import { readFile, stat, unlink, writeFile } from 'node:fs/promises';
import {
  ensurePrivateStorageDirectory,
  localStoragePath,
} from '../storage/local-storage';

const prefixoR2 = 'r2://';

@Injectable()
export class AvaliacaoFotoStorageService {
  novaReferencia(solicitacaoId: number): string {
    const nome = `${randomUUID()}.jpg`;
    const key = `avaliacoes/${solicitacaoId}/${nome}`;
    return storageDriver() === 'r2'
      ? `${prefixoR2}${key}`
      : join('storage', 'avaliacoes', String(solicitacaoId), nome).replace(/\\/g, '/');
  }

  async salvar(referencia: string, bytes: Buffer): Promise<void> {
    const key = referencia.startsWith(prefixoR2)
      ? referencia.slice(prefixoR2.length)
      : null;
    if (!this.referenciaValida(referencia)) throw arquivoIndisponivel();
    if (key !== null) {
      const { bucket, client } = r2Config();
      await client.send(
        new PutObjectCommand({
          Bucket: bucket,
          Key: key,
          Body: bytes,
          ContentType: 'image/jpeg',
          CacheControl: 'private, no-store',
        }),
      );
      return;
    }

    const absolute = localStoragePath(referencia, 'avaliacoes');
    if (absolute === null) throw arquivoIndisponivel();
    await ensurePrivateStorageDirectory(dirname(absolute));
    await writeFile(absolute, bytes, { flag: 'wx', mode: 0o600 });
  }

  async carregar(referencia: string): Promise<Buffer> {
    if (referencia.startsWith(prefixoR2)) {
      const key = referencia.slice(prefixoR2.length);
      if (!/^avaliacoes\/[1-9]\d{0,9}\/[0-9a-f-]{36}\.jpg$/i.test(key)) {
        throw arquivoIndisponivel();
      }
      const { bucket, client } = r2Config();
      const response = await client.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
      if (response.Body === undefined || (response.ContentLength ?? 0) > 2 * 1024 * 1024) {
        throw arquivoIndisponivel();
      }
      if (!(Symbol.asyncIterator in Object(response.Body))) {
        throw arquivoIndisponivel();
      }
      return readBoundedJpeg(
        response.Body as unknown as AsyncIterable<Uint8Array>,
      );
    }

    const absolute = localStoragePath(referencia, 'avaliacoes');
    if (absolute === null) throw arquivoIndisponivel();
    const info = await stat(absolute);
    if (!info.isFile() || info.size < 3 || info.size > 2 * 1024 * 1024) {
      throw arquivoIndisponivel();
    }
    const bytes = await readFile(absolute);
    if (!isJpeg(bytes)) throw arquivoIndisponivel();
    return bytes;
  }

  async remover(referencia: string): Promise<void> {
    if (referencia.startsWith(prefixoR2)) {
      const key = referencia.slice(prefixoR2.length);
      if (!/^avaliacoes\/[1-9]\d{0,9}\/[0-9a-f-]{36}\.jpg$/i.test(key)) return;
      const { bucket, client } = r2Config();
      await client.send(new DeleteObjectCommand({ Bucket: bucket, Key: key }));
      return;
    }

    const absolute = localStoragePath(referencia, 'avaliacoes');
    if (absolute === null) return;
    try {
      await unlink(absolute);
    } catch (error) {
      if (!isArquivoAusente(error)) throw error;
    }
  }

  private referenciaValida(referencia: string): boolean {
    if (referencia.startsWith(prefixoR2)) {
      return /^avaliacoes\/[1-9]\d{0,9}\/[0-9a-f-]{36}\.jpg$/i.test(
        referencia.slice(prefixoR2.length),
      );
    }
    return localStoragePath(referencia, 'avaliacoes') !== null;
  }
}

function storageDriver(): 'local' | 'r2' {
  const configured = process.env.FILE_STORAGE_DRIVER?.trim().toLowerCase();
  if (configured === 'r2') return 'r2';
  if (configured === 'local') return 'local';
  return process.env.NODE_ENV === 'production' ? 'r2' : 'local';
}

function r2Config() {
  const accountId = requiredEnv('R2_ACCOUNT_ID');
  const bucket = requiredEnv('R2_BUCKET');
  return {
    bucket,
    client: new S3Client({
      region: process.env.R2_REGION?.trim() || 'auto',
      endpoint: process.env.R2_ENDPOINT?.trim() || `https://${accountId}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: requiredEnv('R2_ACCESS_KEY_ID'),
        secretAccessKey: requiredEnv('R2_SECRET_ACCESS_KEY'),
      },
    }),
  };
}

function requiredEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw arquivoIndisponivel();
  return value;
}

function isArquivoAusente(error: unknown): boolean {
  return typeof error === 'object' && error !== null && 'code' in error && error.code === 'ENOENT';
}

async function readBoundedJpeg(
  body: AsyncIterable<Uint8Array>,
): Promise<Buffer> {
  const chunks: Buffer[] = [];
  let total = 0;
  for await (const chunk of body) {
    total += chunk.byteLength;
    if (total > 2 * 1024 * 1024) throw arquivoIndisponivel();
    chunks.push(Buffer.from(chunk));
  }
  const bytes = Buffer.concat(chunks, total);
  if (!isJpeg(bytes)) throw arquivoIndisponivel();
  return bytes;
}

function isJpeg(bytes: Buffer): boolean {
  return bytes.length >= 3 &&
    bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
}

function arquivoIndisponivel(): NotFoundException {
  return new NotFoundException({
    code: 'FOTO_AVALIACAO_INDISPONIVEL',
    message: 'Foto da avaliacao indisponivel.',
  });
}
