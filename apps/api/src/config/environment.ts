import { isIP } from 'node:net';
import { isAuthRuntimeConfigured } from './runtime.js';

export type RuntimeEnvironment = 'development' | 'test' | 'production';

export interface AppConfig {
  readonly nodeEnv: RuntimeEnvironment;
  readonly host: string;
  readonly port: number;
  readonly trustProxyHops: number;
}

export type Environment = Readonly<Record<string, string | undefined>>;

export class ConfigurationError extends Error {
  constructor(
    readonly code:
      | 'INVALID_NODE_ENV'
      | 'INVALID_HOST'
      | 'INVALID_PORT'
      | 'INVALID_TRUST_PROXY_HOPS'
      | 'INCOMPLETE_PRODUCTION_RUNTIME',
  ) {
    super(`Invalid application configuration (${code}).`);
    this.name = 'ConfigurationError';
  }
}

const runtimeEnvironments: readonly RuntimeEnvironment[] = [
  'development',
  'test',
  'production',
];

export function loadConfig(environment: Environment = process.env): AppConfig {
  const nodeEnv = environment.NODE_ENV ?? 'development';
  if (!runtimeEnvironments.includes(nodeEnv as RuntimeEnvironment)) {
    throw new ConfigurationError('INVALID_NODE_ENV');
  }

  const host = environment.HOST ?? '127.0.0.1';
  if (!isValidHost(host)) {
    throw new ConfigurationError('INVALID_HOST');
  }

  const portValue = environment.PORT ?? '3000';
  if (!/^(?:[1-9]\d{0,4})$/.test(portValue)) {
    throw new ConfigurationError('INVALID_PORT');
  }

  const port = Number(portValue);
  if (!Number.isSafeInteger(port) || port > 65_535) {
    throw new ConfigurationError('INVALID_PORT');
  }

  const trustProxyHops = parseTrustProxyHops(environment.TRUST_PROXY_HOPS);

  if (nodeEnv === 'production' && !isAuthRuntimeConfigured(environment)) {
    throw new ConfigurationError('INCOMPLETE_PRODUCTION_RUNTIME');
  }

  return { nodeEnv: nodeEnv as RuntimeEnvironment, host, port, trustProxyHops };
}

function parseTrustProxyHops(value: string | undefined): number {
  if (value === undefined || value.trim() === '') return 0;
  if (!/^\d{1,2}$/.test(value.trim())) {
    throw new ConfigurationError('INVALID_TRUST_PROXY_HOPS');
  }
  const hops = Number(value);
  if (hops > 10) throw new ConfigurationError('INVALID_TRUST_PROXY_HOPS');
  return hops;
}

function isValidHost(host: string): boolean {
  if (host.length === 0 || host.length > 253) {
    return false;
  }

  if (isIP(host) !== 0) {
    return true;
  }

  if (host.startsWith('.') || host.endsWith('.') || host.includes('..')) {
    return false;
  }

  return host.split('.').every(
    (label) =>
      label.length <= 63 &&
      /^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$/.test(label),
  );
}
