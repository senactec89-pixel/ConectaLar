# Proposta de CI para Flutter e API

Este documento é uma proposta. Nenhum workflow executável foi criado. Antes de adicionar workflows reais, executar localmente flutter analyze, flutter test e npm test, como combinado.

## Workflow Flutter sugerido

Em pull requests e pushes para main:

1. Instalar versão estável do Flutter definida pela equipe.
2. Executar flutter pub get.
3. Executar flutter analyze --no-pub.
4. Executar flutter test --no-pub.
5. Publicar logs de resultado como resumo do job; não enviar dados de demonstração ou tokens como artefato.

## Workflow API sugerido

Em pull requests e pushes para main:

1. Instalar Node compatível com apps/api/package.json.
2. Executar npm ci.
3. Executar npm run typecheck.
4. Executar npm test.
5. Para teste de integração, iniciar MySQL temporário no job, fornecer variáveis descartáveis, aplicar migrations e executar npm run test:integration.
6. Não usar banco, seed, senha ou token de produção nos jobs.
7. Registrar separadamente quando integração for ignorada por falta de banco para evitar falso sinal verde.

## Critérios antes de ativar

- Rodar todos os comandos localmente e corrigir qualquer falha.
- Confirmar versões de Flutter, Node e MySQL usadas no pipeline.
- Guardar credenciais como secrets do GitHub, não em YAML.
- Restringir permissões do token de workflow ao mínimo.
- Não fazer deploy automático até haver ambientes, migrações, backup e revisão de release definidos.
- Revisar o workflow em pull request e manter etapas de Flutter e API independentes.

O resultado informado pela equipe é de 90 testes Flutter aprovados; manter esse número como referência informativa, sem codificá-lo como expectativa rígida no pipeline.
