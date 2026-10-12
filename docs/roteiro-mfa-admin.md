# Roteiro MFA administrativo

Use apenas conta e banco de teste. O MFA administrativo usa TOTP, o mesmo padrão de Google Authenticator, Microsoft Authenticator, 1Password e apps compatíveis.

## Diagnóstico automático

Com API e MySQL locais ligados:

```powershell
cd C:\Users\User\Downloads\ConectaLar-main\ConectaLar-main\apps\api
npm.cmd run diagnostico:mfa
```

O diagnóstico:

1. entra com `admin.demo@conectalar.local`;
2. inicia MFA;
3. confirma o código TOTP gerado pelo próprio script;
4. valida que o próximo login exige MFA;
5. confirma que código errado recebe `401`;
6. confirma que código certo emite token;
7. desativa o MFA no fim, para não bloquear os testes manuais do APK.

## Teste manual com app autenticador

1. Faça login como admin e copie o token.
2. Chame `POST /auth/mfa/admin/setup` com `Authorization: Bearer <token>`.
3. Copie o `otpauthUrl` ou o `secret` retornado.
4. Cadastre no app autenticador.
5. Chame `POST /auth/mfa/admin/confirmar` com o código de 6 dígitos.
6. Faça login novamente. A resposta deve trazer `mfaRequired: true` e `mfaToken`.
7. Chame `POST /auth/login/mfa` com `mfaToken` e o código atual.
8. Ao terminar o teste, chame `POST /auth/mfa/admin/desativar` com senha atual e código, se quiser voltar ao login sem MFA.

Nunca use segredo MFA, token, senha real ou captura de QR Code em commit, documentação pública ou conversa compartilhada.
