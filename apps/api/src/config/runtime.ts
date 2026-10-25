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
  const baseConfigured =
    isDatabaseRuntimeConfigured(environment) &&
    (environment.AUTH_TOKEN_SECRET?.trim().length ?? 0) >= 32;
  if (!baseConfigured) return false;
  if (environment.NODE_ENV !== 'production') return true;

  const authKey = environment.AUTH_TOKEN_SECRET?.trim();
  const mfaKey = environment.MFA_SECRET_ENCRYPTION_KEY?.trim();
  const outboxKey = environment.EMAIL_OUTBOX_ENCRYPTION_KEY?.trim();
  const secrets = [authKey, mfaKey, outboxKey];
  const secretsValid = secrets.every((secret) => (secret?.length ?? 0) >= 32) &&
    new Set(secrets).size === secrets.length;
  const smtpConfigured = Boolean(
    environment.SMTP_HOST?.trim() &&
      environment.SMTP_FROM?.trim() &&
      environment.SMTP_USER?.trim() &&
      environment.SMTP_PASSWORD?.trim(),
  );
  return secretsValid && smtpConfigured;
}
