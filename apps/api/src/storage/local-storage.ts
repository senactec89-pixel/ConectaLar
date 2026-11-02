import { chmod, mkdir } from 'node:fs/promises';
import { isAbsolute, relative, resolve, sep } from 'node:path';

export type LocalStorageNamespace = 'documentos-verificacao' | 'avaliacoes';

export function localStorageRoot(): string {
  const configured = process.env.FILE_STORAGE_LOCAL_DIR?.trim();
  if (!configured) {
    if (
      process.env.NODE_ENV === 'production' &&
      process.env.FILE_STORAGE_DRIVER?.trim().toLowerCase() === 'local'
    ) {
      throw new Error(
        'FILE_STORAGE_LOCAL_DIR is required for local storage in production',
      );
    }
    return resolve(process.cwd());
  }

  if (!isAbsolute(configured)) {
    throw new Error('FILE_STORAGE_LOCAL_DIR must be an absolute path');
  }

  const root = resolve(configured);
  if (process.env.NODE_ENV === 'production') {
    const relativeToApp = relative(resolve(process.cwd()), root);
    if (
      relativeToApp === '' ||
      (relativeToApp !== '..' &&
        !relativeToApp.startsWith(`..${sep}`) &&
        !isAbsolute(relativeToApp))
    ) {
      throw new Error(
        'FILE_STORAGE_LOCAL_DIR must be outside the application directory in production',
      );
    }
  }

  return root;
}

export function localStoragePath(
  reference: string,
  namespace: LocalStorageNamespace,
): string | null {
  const match =
    /^storage\/(documentos-verificacao|avaliacoes)\/([1-9]\d{0,9})\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(?:pdf|jpg|png))$/i.exec(
      reference,
    );
  if (match === null || match[1] !== namespace) return null;
  if (
    namespace === 'avaliacoes' &&
    !match[3]!.toLowerCase().endsWith('.jpg')
  ) {
    return null;
  }

  const root = localStorageRoot();
  const namespaceRoot = resolve(root, 'storage', namespace);
  const absolute = resolve(root, reference);
  const relativeToNamespace = relative(namespaceRoot, absolute);
  if (
    relativeToNamespace === '' ||
    relativeToNamespace === '..' ||
    relativeToNamespace.startsWith(`..${sep}`) ||
    isAbsolute(relativeToNamespace)
  ) {
    return null;
  }
  return absolute;
}

export async function ensurePrivateStorageDirectory(
  directory: string,
): Promise<void> {
  const root = localStorageRoot();
  const target = resolve(directory);
  const relativeTarget = relative(root, target);
  if (
    relativeTarget === '..' ||
    relativeTarget.startsWith(`..${sep}`) ||
    isAbsolute(relativeTarget)
  ) {
    throw new Error('Local storage directory is outside its configured root');
  }

  const directories = [root];
  let current = root;
  for (const segment of relativeTarget.split(sep).filter(Boolean)) {
    current = resolve(current, segment);
    directories.push(current);
  }

  for (const path of directories) {
    await mkdir(path, { recursive: true, mode: 0o700 });
    if (process.platform !== 'win32') await chmod(path, 0o700);
  }
}
