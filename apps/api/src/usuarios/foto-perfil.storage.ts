import { randomUUID } from 'node:crypto';
import { mkdir, stat, unlink, writeFile } from 'node:fs/promises';
import { extname, join, resolve, sep } from 'node:path';
import { BadRequestException, NotFoundException } from '@nestjs/common';

export interface FotoPerfilArquivo {
  readonly caminho: string;
  readonly mimeType: string;
}

const maxFotoPerfilBytes = 2 * 1024 * 1024;
const pastaFotosPerfilRelativa = join('storage', 'fotos-perfil');

export function fotoPerfilUrl(
  usuario: { readonly id: number; readonly fotoPerfil: string | null },
): string | null {
  return usuario.fotoPerfil === null ? null : `/usuarios/${usuario.id}/foto`;
}

export async function salvarFotoPerfil(
  usuarioId: number,
  body: unknown,
): Promise<string> {
  const input = parseFotoPerfil(body);
  const conteudo = Buffer.from(input.arquivoBase64, 'base64');
  if (
    conteudo.length === 0 ||
    conteudo.length > maxFotoPerfilBytes ||
    conteudo.toString('base64').replace(/=+$/u, '') !==
      input.arquivoBase64.replace(/\s/g, '').replace(/=+$/u, '')
  ) {
    throw badRequest('FOTO_PERFIL_INVALIDA');
  }

  if (!assinaturaCompativelComMime(conteudo, input.mimeType)) {
    throw badRequest('ASSINATURA_FOTO_INVALIDA');
  }

  const extensao = extensaoMime(input.mimeType);
  if (extensao === null) throw badRequest('TIPO_FOTO_INVALIDO');

  const pastaRelativa = join(pastaFotosPerfilRelativa, String(usuarioId));
  const nomeArquivo = `${randomUUID()}${extensao}`;
  const pastaAbsoluta = resolve(process.cwd(), pastaRelativa);
  await mkdir(pastaAbsoluta, { recursive: true });
  await writeFile(join(pastaAbsoluta, nomeArquivo), conteudo, { flag: 'wx' });
  return join(pastaRelativa, nomeArquivo).replace(/\\/g, '/');
}

export async function carregarFotoPerfil(
  referencia: string | null,
): Promise<FotoPerfilArquivo> {
  if (referencia === null) throw fotoNaoEncontrada();

  const caminho = caminhoAbsolutoSeguro(referencia);
  if (caminho === null) throw fotoNaoEncontrada();

  const extensao = extname(caminho).toLowerCase();
  const mimeType = mimeExtensao(extensao);
  if (mimeType === null) throw fotoNaoEncontrada();

  try {
    const arquivo = await stat(caminho);
    if (!arquivo.isFile()) throw fotoNaoEncontrada();
  } catch {
    throw fotoNaoEncontrada();
  }

  return { caminho, mimeType };
}

export async function removerFotoPerfilArquivo(
  referencia: string | null,
): Promise<void> {
  if (referencia === null) return;
  const caminho = caminhoAbsolutoSeguro(referencia);
  if (caminho === null) return;
  try {
    await unlink(caminho);
  } catch {
    // A remoção do arquivo antigo não pode impedir a atualização do perfil.
  }
}

function parseFotoPerfil(body: unknown) {
  const value = objectBody(body);
  const arquivoBase64 = stringField(value, 'arquivoBase64').replace(/\s/g, '');
  const mimeType = stringField(value, 'mimeType').trim().toLowerCase();
  const nomeArquivo = optionalText(value.nomeArquivo, 180);

  if (arquivoBase64.length > Math.ceil((maxFotoPerfilBytes * 4) / 3) + 8) {
    throw badRequest('FOTO_PERFIL_MUITO_GRANDE');
  }
  if (extensaoMime(mimeType) === null) {
    throw badRequest('TIPO_FOTO_INVALIDO');
  }
  if (!nomeArquivoCompativelComMime(nomeArquivo, mimeType)) {
    throw badRequest('NOME_FOTO_INVALIDO');
  }

  return { arquivoBase64, mimeType };
}

function caminhoAbsolutoSeguro(referencia: string): string | null {
  const root = resolve(process.cwd(), pastaFotosPerfilRelativa);
  const caminho = resolve(process.cwd(), referencia);
  if (caminho !== root && !caminho.startsWith(`${root}${sep}`)) return null;
  return caminho;
}

function objectBody(body: unknown): Record<string, unknown> {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw badRequest('CORPO_INVALIDO');
  }
  return body as Record<string, unknown>;
}

function stringField(value: Record<string, unknown>, key: string): string {
  const field = value[key];
  if (typeof field !== 'string' || field.trim().length === 0) {
    throw badRequest('CAMPO_OBRIGATORIO');
  }
  return field;
}

function optionalText(value: unknown, max: number): string | null {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string') throw badRequest('CAMPO_INVALIDO');
  const text = value.trim();
  if (text.length === 0) return null;
  if (text.length > max) throw badRequest('CAMPO_INVALIDO');
  return text;
}

function extensaoMime(value: string): string | null {
  if (value === 'image/jpeg') return '.jpg';
  if (value === 'image/png') return '.png';
  if (value === 'image/webp') return '.webp';
  return null;
}

function mimeExtensao(value: string): string | null {
  if (value === '.jpg' || value === '.jpeg') return 'image/jpeg';
  if (value === '.png') return 'image/png';
  if (value === '.webp') return 'image/webp';
  return null;
}

function nomeArquivoCompativelComMime(
  nomeArquivo: string | null,
  mimeType: string,
): boolean {
  if (nomeArquivo === null) return true;
  const nome = nomeArquivo.toLowerCase();
  if (/[\\/]/.test(nome)) return false;
  if (mimeType === 'image/jpeg') {
    return nome.endsWith('.jpg') || nome.endsWith('.jpeg');
  }
  if (mimeType === 'image/png') return nome.endsWith('.png');
  if (mimeType === 'image/webp') return nome.endsWith('.webp');
  return false;
}

function assinaturaCompativelComMime(conteudo: Buffer, mimeType: string): boolean {
  if (mimeType === 'image/png') {
    return conteudo
      .subarray(0, 8)
      .equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  }
  if (mimeType === 'image/jpeg') {
    return (
      conteudo.length >= 4 &&
      conteudo[0] === 0xff &&
      conteudo[1] === 0xd8 &&
      conteudo[2] === 0xff
    );
  }
  if (mimeType === 'image/webp') {
    return (
      conteudo.length >= 12 &&
      conteudo.subarray(0, 4).equals(Buffer.from('RIFF')) &&
      conteudo.subarray(8, 12).equals(Buffer.from('WEBP'))
    );
  }
  return false;
}

function fotoNaoEncontrada(): NotFoundException {
  return new NotFoundException({
    code: 'FOTO_PERFIL_NAO_ENCONTRADA',
    message: 'Foto de perfil nao encontrada.',
  });
}

function badRequest(code: string): BadRequestException {
  return new BadRequestException({
    code,
    message: 'Dados invalidos.',
  });
}
