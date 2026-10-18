export function isDatabaseRuntimeConfigured(
  environment: Readonly<Record<string, string | undefined>> = process.env,
): boolean {
  return Boolean(
    environment.DB_HOST?.trim() &&
      environment.DB_USER?.trim() &&
      environment.DB_NAME?.trim(),
  );
}

export function isAuthRuntimeConfigured(
  environment: Readonly<Record<string, string | undefined>> = process.env,
): boolean {
  return (
    isDatabaseRuntimeConfigured(environment) &&
    (environment.AUTH_TOKEN_SECRET?.trim().length ?? 0) >= 32
  );
}
