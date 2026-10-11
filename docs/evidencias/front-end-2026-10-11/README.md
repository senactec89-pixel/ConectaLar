# Capturas da revisão de front-end — 11/10/2026

Flutter Web executado localmente no Chrome, com viewport de 360, 390 e 412 pixels lógicos, altura de 844 pixels e DPR 1. São **prévias explicitamente fictícias**, identificadas pela faixa DEMONSTRAÇÃO. Não usam a API, não restauram a sessão real e não salvam operações.

| Tela | 360 px | 390 px | 412 px |
| --- | --- | --- | --- |
| Home | [Captura](home-360.png) | [Captura](home-390.png) | [Captura](home-412.png) |
| Área profissional | [Captura](profissional-360.png) | [Captura](profissional-390.png) | [Captura](profissional-412.png) |
| Central administrativa | [Captura](admin-360.png) | [Captura](admin-390.png) | [Captura](admin-412.png) |

As imagens foram feitas com texto padrão. A verificação de texto ampliado (1,4), conteúdo autenticado, filtros, estados de erro/vazio e teclado é documentada nos testes Flutter e no [relatório das etapas](../../etapas-front-end-2026-10-11.md).

Os arquivos `*-browser-log.json` registram eventos do navegador. Avisos de desempenho do WebGL no Chrome sem GPU física são distintos de erros/exceções do aplicativo.

Compilação reproduzível, trocando `cliente` por `profissional` ou `administrador`:

```bash
flutter build web --debug --no-pub --no-wasm-dry-run --no-web-resources-cdn --dart-define=CONECTALAR_DEMO=true --dart-define=CONECTALAR_DEMO_ROLE=cliente
```

Para executar no Linux sem API:

```bash
flutter run -d linux --dart-define=CONECTALAR_DEMO=true --dart-define=CONECTALAR_DEMO_ROLE=cliente
```

O seletor nativo de arquivos e os fluxos com a API real ainda precisam de homologação em aparelho/ambiente integrado. As capturas e os testes de widgets não substituem essa validação.
