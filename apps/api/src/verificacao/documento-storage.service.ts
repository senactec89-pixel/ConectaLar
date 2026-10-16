import { Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { mkdir, readFile, stat, unlink, writeFile } from 'node:fs/promises';
import { extname, join, resolve, sep } from 'node:path';
import {
  GetObjectCommand,
  PutObjectCommand,
  DeleteObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';

export interface DocumentoArquivo {
  readonly bytes: Buffer;
  readonly mimeType: string;
  readonly nomeSeguro: string;
}

const pastaDocumentosRelativa = join('storage', 'documentos-verificacao');
const r2Prefix = 'r2://';

@Injectable()
export class DocumentoStorageService {
  async salvar(
    profissionalId: number,
    conteudo: Buffer,
    mimeType: string,
  ): Promise<string> {
    const extensao = extensaoMime(mimeType);
    if (extensao === null) throw documentoIndisponivel();

    const key = `documentos-verificacao/${profissionalId}/${randomUUID()}${extensao}`;
    if (storageDriver() === 'r2') {
      const config = r2Config();
      await config.client.send(
        new PutObjectCommand({
          Bucket: config.bucket,
          Key: key,
          Body: conteudo,
          ContentType: mimeType,
        }),
      );
      return `${r2Prefix}${key}`;
    }

    const pastaRelativa = join(pastaDocumentosRelativa, String(profissionalId));
    const nomeArquivo = `${randomUUID()}${extensao}`;
    const pastaAbsoluta = join(process.cwd(), pastaRelativa);
    await mkdir(pastaAbsoluta, { recursive: true });
    await writeFile(join(pastaAbsoluta, nomeArquivo), conteudo, { flag: 'wx' });
    return join(pastaRelativa, nomeArquivo).replace(/\\/g, '/');
  }

  async carregar(
    id: number,
    referencia: string,
    nomeArquivo: string | null,
  ): Promise<DocumentoArquivo> {
    if (referencia.startsWith(r2Prefix)) {
      return this.carregarR2(id, referencia, nomeArquivo);
    }
    return carregarLocal(id, referencia, nomeArquivo);
  }

  async remover(referencia: string): Promise<void> {
    if (referencia.startsWith(r2Prefix)) {
      const key = referencia.slice(r2Prefix.length);
      if (!key.startsWith('documentos-verificacao/')) return;
      const config = r2Config();
      await config.client.send(
        new DeleteObjectCommand({ Bucket: config.bucket, Key: key }),
      );
      return;
    }

    const caminho = caminhoDocumentoSeguro(referencia);
    if (caminho === null) return;
    try {
      await unlink(caminho);
    } catch (error) {
      if (!isArquivoAusente(error)) throw error;
    }
  }

  private async carregarR2(
    id: number,
    referencia: string,
    nomeArquivo: string | null,
  ): Promise<DocumentoArquivo> {
    const key = referencia.slice(r2Prefix.length);
    if (!key.startsWith('documentos-verificacao/')) {
      throw documentoIndisponivel();
    }

    const config = r2Config();
    const extensao = extname(key).toLowerCase();
    const mimeType = mimeExtensao(extensao);
    if (mimeType === null) throw documentoIndisponivel();

    const response = await config.client.send(
      new GetObjectCommand({ Bucket: config.bucket, Key: key }),
    );
    const body = response.Body;
    if (body === undefined) throw documentoIndisponivel();

    const bytes = Buffer.from(await body.transformToByteArray());
    return {
      bytes,
      mimeType,
      nomeSeguro: nomeSeguroDocumento(id, nomeArquivo, key),
    };
  }
}

function carregarLocal(
  id: number,
  referencia: string,
  nomeArquivo: string | null,
): Promise<DocumentoArquivo> {
  return (async () => {
    const caminho = caminhoDocumentoSeguro(referencia);
    if (caminho === null) throw documentoIndisponivel();

    const extensao = extname(caminho).toLowerCase();
    const mimeType = mimeExtensao(extensao);
    if (mimeType === null) throw documentoIndisponivel();

    try {
      const arquivo = await stat(caminho);
      if (!arquivo.isFile()) throw documentoIndisponivel();
    } catch {
      throw documentoIndisponivel();
    }

    return {
      bytes: await readFile(caminho),
      mimeType,
      nomeSeguro: nomeSeguroDocumento(id, nomeArquivo, caminho),
    };
  })();
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
  const endpoint =
    process.env.R2_ENDPOINT?.trim() ||
    `https://${accountId}.r2.cloudflarestorage.com`;

  return {
    bucket,
    client: new S3Client({
      region: process.env.R2_REGION?.trim() || 'auto',
      endpoint,
      credentials: {
        accessKeyId: requiredEnv('R2_ACCESS_KEY_ID'),
        secretAccessKey: requiredEnv('R2_SECRET_ACCESS_KEY'),
      },
    }),
  };
}

function requiredEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw documentoIndisponivel();
  return value;
}

function caminhoDocumentoSeguro(referencia: string): string | null {
  const root = resolve(process.cwd(), pastaDocumentosRelativa);
  const caminho = resolve(process.cwd(), referencia);
  if (caminho !== root && !caminho.startsWith(`${root}${sep}`)) return null;
  return caminho;
}

function nomeSeguroDocumento(
  id: number,
  nomeArquivo: string | null,
  caminho: string,
): string {
  const extensao = extname(caminho).toLowerCase();
  const nome = nomeArquivo?.toLowerCase() ?? '';
  if (nomeArquivo !== null && !/[\\/"\r\n]/.test(nomeArquivo)) {
    if (
      (extensao === '.pdf' && nome.endsWith('.pdf')) ||
      (extensao === '.png' && nome.endsWith('.png')) ||
      (extensao === '.jpg' &&
        (nome.endsWith('.jpg') || nome.endsWith('.jpeg')))
    ) {
      return nomeArquivo;
    }
  }
  return `documento-verificacao-${id}${extensao}`;
}

function extensaoMime(value: string | null): string | null {
  if (value === 'application/pdf') return '.pdf';
  if (value === 'image/jpeg') return '.jpg';
  if (value === 'image/png') return '.png';
  return null;
}

function mimeExtensao(value: string): string | null {
  if (value === '.pdf') return 'application/pdf';
  if (value === '.jpg' || value === '.jpeg') return 'image/jpeg';
  if (value === '.png') return 'image/png';
  return null;
}

function documentoIndisponivel(): NotFoundException {
  return new NotFoundException({
    code: 'ARQUIVO_DOCUMENTO_INDISPONIVEL',
    message: 'Arquivo do documento indisponivel para visualizacao segura.',
  });
}

function isArquivoAusente(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    error.code === 'ENOENT'
  );
}
