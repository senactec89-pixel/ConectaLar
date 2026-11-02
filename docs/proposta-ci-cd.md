# Proposta de CI para Flutter e API

O workflow executável está em `.github/workflows/ci.yml`. Ele valida Flutter, API e o target SDK do APK de depuração em pushes e pull requests para `main`. Não executa migrations nem faz deploy.

## Cobertura atual

O job Flutter usa Flutter 3.47.7, roda análise e testes, compila APK debug e verifica no manifesto do artefato que `targetSdkVersion` é 36. O job API usa Node 22, instala pelo lockfile, roda typecheck e a suíte automatizada.

## Critérios antes de ativar

- O teste de integração com MySQL real ainda precisa ser adicionado como job com serviço MySQL descartável e variáveis efêmeras.
- A assinatura release continua fora do CI até haver secrets de assinatura configurados com proteção apropriada.
- A primeira execução no GitHub Actions deve ser acompanhada para confirmar a compatibilidade da imagem Android e do apkanalyzer.
- Confirmar periodicamente versões de Flutter, Node e MySQL usadas no pipeline.
- Guardar credenciais como secrets do GitHub, não em YAML.
- Restringir permissões do token de workflow ao mínimo.
- Não fazer deploy automático até haver ambientes, migrações, backup e revisão de release definidos.
- Revisar o workflow em pull request e manter etapas de Flutter e API independentes.

Validação local em 31/10/2026: `flutter analyze` sem avisos, 302 testes Flutter aprovados, `npm run typecheck` sem erros e 112 testes automatizados da API aprovados. O APK debug gerado foi inspecionado e declara target SDK 36. Esses resultados locais não substituem a primeira execução do GitHub Actions; o workflow ainda precisa rodar após push ou pull request para `main`.

Manter as contagens como referência informativa, sem codificá-las como expectativas rígidas no pipeline.
