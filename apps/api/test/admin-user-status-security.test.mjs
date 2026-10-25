import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AdminUsuariosService } from '../dist/admin-usuarios/admin-usuarios.service.js';

function makeService(users) {
  const audits = [];
  const locks = [];
  let transactionCount = 0;
  const usuarioRepository = {
    manager: {
      transaction: async (operation) => {
        transactionCount += 1;
        return operation({
          getRepository(entity) {
            if (entity.name === 'AdminAuditoriaEntity') {
              return {
                create: (value) => value,
                save: async (value) => audits.push(value),
              };
            }

            return {
              createQueryBuilder() {
                let condition = '';
                let parameters = {};
                const builder = {
                  where(sql, values) {
                    condition = sql;
                    parameters = values ?? {};
                    return builder;
                  },
                  orderBy() {
                    return builder;
                  },
                  setLock(mode) {
                    locks.push(mode);
                    return builder;
                  },
                  getMany: async () => condition.includes('usuario.tipo')
                    ? users.filter((user) => user.tipo === 'administrador')
                    : [],
                  getOne: async () => users.find(
                    (user) => user.id === parameters.id,
                  ) ?? null,
                };
                return builder;
              },
              save: async (user) => user,
            };
          },
        });
      },
    },
  };
  const service = new AdminUsuariosService(
    usuarioRepository,
    {},
    {},
    {},
  );
  return {
    service,
    audits,
    locks,
    transactionCount: () => transactionCount,
  };
}

function account({ id, type = 'cliente', active, tokenVersion }) {
  const now = new Date('2026-10-25T12:00:00.000Z');
  return {
    id,
    nome: `Usuario ${id}`,
    email: `usuario${id}@example.invalid`,
    telefone: null,
    tipo: type,
    ativo: active,
    tokenVersion,
    criadoEm: now,
    atualizadoEm: now,
  };
}

test('deactivation and reactivation each advance token version in a transaction', async () => {
  const target = account({ id: 8, active: true, tokenVersion: 3 });
  const { service, audits, locks, transactionCount } = makeService([target]);
  const actor = { id: 99, tipo: 'administrador' };

  const deactivated = await service.atualizarStatus(actor, target.id, {
    ativo: false,
    motivo: 'Revisao administrativa',
  });
  assert.equal(deactivated.usuario.ativo, false);
  assert.equal(target.tokenVersion, 4);

  const reactivated = await service.atualizarStatus(actor, target.id, {
    ativo: true,
  });
  assert.equal(reactivated.usuario.ativo, true);
  assert.equal(target.tokenVersion, 5);
  assert.equal(transactionCount(), 2);
  assert.deepEqual(locks, [
    'pessimistic_write',
    'pessimistic_write',
    'pessimistic_write',
    'pessimistic_write',
  ]);
  assert.equal(audits.length, 2);
  assert.deepEqual(JSON.parse(audits[0].detalhe), {
    antes: { ativo: true, tokenVersion: 3 },
    depois: { ativo: false, tokenVersion: 4 },
    motivo: 'Revisao administrativa',
  });
});

test('cannot deactivate the final active administrator', async () => {
  const lastAdmin = account({
    id: 12,
    type: 'administrador',
    active: true,
    tokenVersion: 7,
  });
  const { service, audits, locks, transactionCount } = makeService([lastAdmin]);

  await assert.rejects(
    service.atualizarStatus(
      { id: 99, tipo: 'administrador' },
      lastAdmin.id,
      { ativo: false },
    ),
    (error) => error.getResponse().code === 'ULTIMO_ADMIN_ATIVO',
  );

  assert.equal(transactionCount(), 1);
  assert.deepEqual(locks, ['pessimistic_write']);
  assert.equal(lastAdmin.ativo, true);
  assert.equal(lastAdmin.tokenVersion, 7);
  assert.equal(audits.length, 0);
});
