import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { test } from 'node:test';
import { AdminUsuariosService } from '../dist/admin-usuarios/admin-usuarios.service.js';

test('admin creation stores invitation hash transactionally and never returns token', async () => {
  const saved = [];
  let rawInviteToken;
  const createdAt = new Date('2026-01-01T00:00:00Z');
  const usuarioRepository = {
    findOne: async () => null,
    manager: {
      transaction: async (operation) => operation({
        getRepository(entity) {
          return {
            create: (value) => value,
            save: async (value) => {
              const row = { ...value };
              if (entity.name === 'UsuarioEntity') {
                Object.assign(row, {
                  id: 77,
                  criadoEm: createdAt,
                  atualizadoEm: createdAt,
                });
              }
              if (entity.name === 'EmailOutboxEntity') row.id = 90;
              saved.push({ entity: entity.name, row });
              return row;
            },
          };
        },
      }),
    },
  };
  const service = new AdminUsuariosService(
    usuarioRepository,
    { hash: async () => 'scrypt$discarded-password' },
    { configured: () => true },
    {
      criarRegistro: (usuarioId, token, expiresAt, tipo) => {
        rawInviteToken = token;
        return { usuarioId, tipo, expiresAt, payloadCriptografado: 'encrypted' };
      },
      entregarAgora: async () => true,
    },
  );

  const response = await service.criarAdministrador(
    { id: 4, tipo: 'administrador' },
    { nome: 'Admin Convidado', email: 'convidado@example.invalid' },
  );

  const invite = saved.find((item) => item.entity === 'AdminConviteEntity')?.row;
  assert.equal(saved.some((item) => item.entity === 'UsuarioEntity'), true);
  assert.equal(saved.some((item) => item.entity === 'AdminAuditoriaEntity'), true);
  assert.equal(saved.some((item) => item.entity === 'EmailOutboxEntity'), true);
  assert.equal(invite.tokenHash, createHash('sha256').update(rawInviteToken).digest('hex'));
  assert.equal(rawInviteToken.length, 43);
  assert.equal(JSON.stringify(response).includes(rawInviteToken), false);
  assert.equal(response.convite.emailEnviado, true);
  assert.equal(response.usuario.emailVerificado, undefined);
});
