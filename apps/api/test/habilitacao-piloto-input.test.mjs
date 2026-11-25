import assert from 'node:assert/strict';
import test from 'node:test';
import { ProfissionaisService } from '../dist/profissionais/profissionais.service.js';
import { CategoriaEntity } from '../dist/database/entities/categoria.entity.js';
import { ProfissionalPerfilEntity } from '../dist/database/entities/profissional-perfil.entity.js';
import { ProfissionalServicoEntity } from '../dist/database/entities/profissional-servico.entity.js';
import { ServicoCatalogoEntity } from '../dist/database/entities/servico-catalogo.entity.js';

test('API exige confirmacao explicita para declaracao de iniciante no piloto', async () => {
  const keys = ['NODE_ENV', 'CONECTALAR_HABILITACAO_PILOTO', 'CONECTALAR_STAGE', 'DB_HOST', 'DB_NAME'];
  const previous = new Map(keys.map((key) => [key, process.env[key]]));
  Object.assign(process.env, {
    NODE_ENV: 'development',
    CONECTALAR_HABILITACAO_PILOTO: 'true',
    CONECTALAR_STAGE: 'development',
    DB_HOST: '127.0.0.1',
    DB_NAME: 'conectalar_dev',
  });
  try {
    const categoria = { id: 5, ativo: true };
    const catalogo = {
      id: 9,
      categoriaId: 5,
      nome: 'Reparo simples',
      ativo: true,
      politicaPiloto: 'iniciante_ou_experiencia',
      criterioPiloto: 'Tarefa simples e de acesso seguro, sem tubulacao embutida.',
    };
    const perfil = { id: 2, usuarioId: 3, servicos: [] };
    let salvo = null;
    const manager = {
      transaction: async (run) => run(manager),
      find: async (entity) => entity === ProfissionalServicoEntity ? [] : [catalogo],
      findOne: async (entity) => {
        if (entity === ProfissionalPerfilEntity) return perfil;
        if (entity === CategoriaEntity) return categoria;
        if (entity === ServicoCatalogoEntity) return catalogo;
        return null;
      },
      create: (_entity, value) => ({ ...value }),
      save: async (_entity, value) => { salvo = value; return value; },
    };
    const service = new ProfissionaisService(
      {}, {}, {}, { findOne: async () => perfil }, { manager }, {},
      { findOne: async () => ({ id: 3, tipo: 'profissional', ativo: true }) }, {}, {},
    );
    const servicos = [{
      servicoCatalogoId: 9,
      categoriaId: 5,
      nivelExperienciaPiloto: 'iniciante',
      formacaoInformadaPiloto: 'Curso livre de limpeza, Escola Exemplo, 2025',
      intervaloMinutos: 0,
    }];
    const body = { servicos };
    const rejected = (error) => error?.getResponse?.().code === 'DECLARACAO_INICIANTE_INVALIDA';

    await assert.rejects(service.salvarMeusServicos({ id: 3 }, body), rejected);
    assert.equal(salvo, null);

    servicos[0].inicianteConfirmadoPiloto = true;
    await service.salvarMeusServicos({ id: 3 }, body);
    assert.equal(salvo.inicianteConfirmadoPiloto, true);
    assert.equal(salvo.formacaoInformadaPiloto, 'Curso livre de limpeza, Escola Exemplo, 2025');

    servicos[0].formacaoInformadaPiloto = 'x'.repeat(301);
    await assert.rejects(
      service.salvarMeusServicos({ id: 3 }, body),
      (error) => error?.getResponse?.().code === 'FORMACAO_PILOTO_INVALIDA',
    );
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});
