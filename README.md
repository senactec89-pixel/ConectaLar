# ConectaLar

Aplicativo Flutter para conectar clientes a profissionais e empresas de serviços residenciais. O repositório contém o app, uma API REST NestJS/TypeScript e persistência MySQL com TypeORM.

## Estado atual

O núcleo funcional está disponível para demonstração e desenvolvimento local integrado. As contagens e datas atuais das verificações ficam em `docs/progresso.md`; testes automatizados não equivalem à homologação de todos os fluxos em aparelho nem à prontidão para publicação.

A API e o banco usados pelo app ficam em `apps/api`. O arquivo `database/conectalar.sql` é legado; não o importe para o banco da API NestJS. As migrations TypeORM são aplicadas explicitamente.

## Componentes

- Aplicativo: Flutter e Dart.
- API: NestJS, TypeScript e Node.js.
- Persistência: MySQL, TypeORM e migrations.
- Contrato: OpenAPI em `apps/api/openapi.yaml`.
- Testes: Flutter em `test/`; API em `apps/api/test/`.

## Executar localmente

Siga primeiro o guia de [ambiente local](docs/ambiente-local.md), que contém configuração do MySQL, migrations, seed de demonstração, API e diagnóstico.

Na raiz do projeto:

    flutter pub get

Para abrir o app apontando para API local na porta 3012:

    flutter run --dart-define=CONECTALAR_API_BASE_URL=http://127.0.0.1:3012

No emulador Android, o endereço padrão é http://10.0.2.2:3012. Em aparelho físico, configure o IP da máquina servidora na mesma rede. Não use endereços locais de desenvolvimento em uma versão publicada.

Para conferir a aparência sem API, use a prévia fictícia identificada no app como demonstração:

    flutter run -d linux --dart-define=CONECTALAR_DEMO=true --dart-define=CONECTALAR_DEMO_ROLE=cliente

O papel pode ser cliente, profissional, empresa ou administrador. Operações da prévia não são gravadas no servidor.

## Verificações

Na raiz:

    flutter analyze --no-pub
    flutter test --no-pub

Na pasta apps/api:

    npm ci
    npm run typecheck
    npm test

Os testes de integração e os diagnósticos precisam de API/MySQL locais configurados. O diagnóstico de fluxo cria dados de teste; use somente em banco descartável de desenvolvimento ou teste. Veja [checklist de homologação](docs/checklist-demo.md).

## Documentação

- [Ambiente local](docs/ambiente-local.md)
- [Progresso e pendências](docs/progresso.md)
- [Rastreabilidade](docs/rastreabilidade.md)
- [Segurança](docs/seguranca.md)
- [Pendências de produto e operação](docs/pendencias.md)
- [Homologação visual](docs/homologacao-visual.md)
- [Checklists de homologação por papel](docs/checklist-homologacao-cliente.md)
- [Preparação Android](docs/preparacao-android-release.md)
- [Login com Google](docs/login-google.md)
- [GPS, mapa e busca por distancia](docs/gps-mapa-distancia.md)
- [Proposta de CI/CD](docs/proposta-ci-cd.md)

O ConectaLar não processa pagamentos: preço é referência inicial e os valores finais são combinados diretamente entre as partes.
