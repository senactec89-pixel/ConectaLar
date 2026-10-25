import assert from 'node:assert/strict';
import { test } from 'node:test';
import { CategoriasService } from '../dist/categorias/categorias.service.js';

test('category mutation is not committed when its audit event cannot be saved', async () => {
  const committedCategories = [];
  const stagedCategories = [];
  const categoriaRepository = {
    manager: {
      async transaction(operation) {
        stagedCategories.length = 0;
        const result = await operation({
          getRepository(entity) {
            if (entity.name === 'AdminAuditoriaEntity') {
              return {
                create: (value) => value,
                async save() { throw new Error('audit unavailable'); },
              };
            }
            return {
              create: (value) => value,
              async save(value) {
                const created = { ...value, id: 31 };
                stagedCategories.push(created);
                return created;
              },
            };
          },
        });
        committedCategories.push(...stagedCategories);
        return result;
      },
    },
  };
  const service = new CategoriasService(categoriaRepository);

  await assert.rejects(
    service.criar(
      { id: 8, tipo: 'administrador' },
      { nome: 'Hidraulica', icone: 'plumbing' },
    ),
    /audit unavailable/,
  );
  assert.equal(committedCategories.length, 0);
});
