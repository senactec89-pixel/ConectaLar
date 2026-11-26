# ConectaLar

O **ConectaLar** é um aplicativo em desenvolvimento para aproximar clientes de profissionais e empresas que oferecem serviços residenciais. A plataforma reúne busca de serviços, perfis, solicitações de atendimento, comunicação entre as partes e ferramentas de administração.

> **Estágio do projeto:** o núcleo está implementado para desenvolvimento e demonstração. A beta técnica é local e usa dados fictícios. O atendimento a clientes e prestadores reais ainda não foi liberado; a publicação depende de decisões de segurança, homologação e preparação da infraestrutura.

## Como funciona

1. O cliente consulta categorias e ofertas e visualiza o perfil do prestador.
2. Escolhe uma oferta, endereço e horário e envia uma solicitação.
3. O profissional analisa e responde. O pedido só se torna agendado após um aceite válido registrado pela API.
4. As partes podem acompanhar o atendimento, conversar no contexto do pedido e, conforme as regras implementadas, registrar conclusão, avaliação ou ocorrência.
5. Administradores gerenciam usuários, catálogo e processos de análise e moderação.

Enviar uma solicitação **não confirma o agendamento**. O ConectaLar não processa pagamentos: preço de referência, orçamento e pagamento final são tratados diretamente entre as partes. A análise documental e eventual selo não garantem qualidade ou segurança do serviço.

## Papéis do sistema

- **Cliente:** busca profissionais, gerencia endereços e acompanha solicitações.
- **Profissional:** administra perfil, ofertas, disponibilidade e respostas aos pedidos.
- **Empresa:** possui perfil de prestador; cadastro e habilitação individual de cada executor ainda são uma lacuna registrada.
- **Administrador:** gerencia catálogo e moderação, com controles administrativos como MFA e auditoria.

## Arquitetura

| Componente | Tecnologia | Localização |
|---|---|---|
| Aplicativo multiplataforma | Flutter e Dart | `lib/` |
| API REST | NestJS, TypeScript e Node.js | `apps/api/` |
| Banco de dados | MySQL via TypeORM e migrations explícitas | Configuração em `apps/api/` |
| Contrato HTTP | OpenAPI | `apps/api/openapi.yaml` |
| Testes | Flutter e Node.js | `test/` e `apps/api/test/` |

O repositório também contém `backend/` e `database/conectalar.sql` como legado histórico. O app atual usa a API em `apps/api`; não importe o SQL legado no banco dessa API. As migrations são executadas explicitamente.

## Executar localmente

Leia primeiro o [guia de ambiente local](docs/ambiente-local.md), que explica como configurar MySQL, migrations, dados de demonstração e API. Depois, na raiz do repositório:

```sh
flutter pub get
flutter run --dart-define=CONECTALAR_API_BASE_URL=http://127.0.0.1:3012
```

No emulador Android, a API local normalmente é acessada por `http://10.0.2.2:3012`. Em aparelho físico, use o endereço de rede da máquina que executa a API. Endereços locais são apenas para desenvolvimento; builds distribuídos precisam apontar para uma API HTTPS aprovada.

Para abrir a prévia visual sem API, em Linux:

```sh
flutter run -d linux \
  --dart-define=CONECTALAR_DEMO=true \
  --dart-define=CONECTALAR_DEMO_ROLE=cliente
```

O papel da demonstração pode ser `cliente`, `profissional`, `empresa` ou `administrador`. Essa prévia usa dados fictícios e não grava operações no servidor. A beta integrada de fluxos também é restrita a ambiente local e dados descartáveis; não a use com dados reais ou produção.

## Verificações de desenvolvimento

Na raiz do projeto:

```sh
flutter analyze --no-pub
flutter test --no-pub
```

Na pasta `apps/api`:

```sh
npm ci
npm run typecheck
npm test
```

Testes de integração podem exigir MySQL descartável. Diagnósticos de fluxo criam dados e devem ser executados somente em banco local de desenvolvimento ou teste. Consulte os guias antes de rodá-los.

## Estado, segurança e lançamento

O código inclui autenticação, autorização na API, sessões seguras no app, proteção de endereços, auditoria administrativa e recursos de privacidade. A presença de código ou testes não significa que todos os controles foram homologados em ambiente de produção.

Antes de qualquer lançamento ainda é necessário, entre outros itens, aprovar a política de habilitação de profissionais e executores de empresas, concluir revisão de privacidade, homologar migrations e fluxos em ambiente isolado, configurar hospedagem HTTPS, banco, armazenamento privado e scanner de arquivos, testar integrações com credenciais reais, preparar backup e monitoramento e gerar/testar um build Android assinado. A habilitação atual mantém novos atendimentos reais bloqueados.

Consulte [progresso](docs/progresso.md), [pendências](docs/pendencias.md), [habilitação profissional](docs/habilitacao-profissional.md), [operação de produção](docs/operacao-producao.md) e [preparação Android](docs/preparacao-android-release.md) para o estado detalhado e os critérios pendentes.

## Documentação

- [Ambiente local](docs/ambiente-local.md)
- [Ficha técnica](docs/ficha-tecnica-conectalar-2026-11-12.md)
- [Progresso e validações registradas](docs/progresso.md)
- [Pendências de produto e operação](docs/pendencias.md)
- [Requisitos e rastreabilidade](docs/rastreabilidade.md)
- [Segurança](docs/seguranca.md)
- [Inventário de dados e fornecedores](docs/inventario-dados-e-fornecedores.md)
- [Homologação beta local](docs/homologacao-beta-local.md)
- [Checklists de homologação](docs/checklist-homologacao-cliente.md), [profissional](docs/checklist-homologacao-profissional.md) e [administração](docs/checklist-homologacao-admin.md)
- [Preparação Android para release](docs/preparacao-android-release.md)
- [Login Google](docs/login-google.md) e [GPS/mapa](docs/gps-mapa-distancia.md)
- [Proposta de CI/CD](docs/proposta-ci-cd.md)
