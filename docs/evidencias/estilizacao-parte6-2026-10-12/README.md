# Partes 5 e 6 — formulários, estados e acessibilidade

Data: 12/10/2026. A parte 5 foi enviada no commit `35493e3`; veja o [registro dos formulários e ações](../../estilizacao-parte5-2026-10-12.md).

## Melhorias

- Formulários de login, cadastro, recuperação, Meus dados, Segurança, cadastro profissional e documentos compartilham recuos, intervalos, mensagens auxiliares e validações do tema.
- No tema, botões primários mantêm altura mínima de 52 px; botões de contorno, texto e ícone mantêm 48 px. A densidade explícita dos botões evita que o padrão compacto de desktop reduza essas dimensões.
- Carregamento mostra uma mensagem visível e um anúncio acessível único. O erro combina ícone, texto e ação “Tentar novamente”. Listas vazias seguem a mesma hierarquia e permitem ações existentes quando necessário.
- Os estados têm largura máxima de leitura e rolagem quando a altura disponível é pequena. Home e Busca reutilizam esses componentes.
- Envio e salvamento nos formulários usam indicadores consistentes e rótulos acessíveis durante a operação, conservando os bloqueios e callbacks existentes.
- Login necessário e acesso restrito têm uma apresentação comum. As verificações de sessão e papel continuam as mesmas, antes da construção do conteúdo privado.
- A faixa visual de demonstração usa “DEMO”, que cabe na área disponível. Sua descrição acessível continua explícita: “Modo demonstração. Dados fictícios.”

## Escopo preservado

A classe `AppColors` foi comparada com a base `04c0984` e permaneceu idêntica. Não foram alterados serviços, modelos, validadores, rotas, contratos, backend, banco ou migrations. As alterações de formulário preservam os valores enviados, a seleção nativa, Base64 e o limite de 5 MB dos documentos. As condições de acesso e os callbacks de nova tentativa, envio e navegação foram mantidos.

## Conferência automatizada

- `flutter analyze --no-pub`: sem problemas, saída 0.
- `flutter test --no-pub --concurrency=2 --reporter expanded`: **104 testes aprovados**, 3 min 41 s, saída 0.
- Verificação dirigida de estados e formulários após o ajuste de densidade: **10 testes aprovados**, saída 0.
- Galeria web compilada com sucesso. As sete telas/estados e a identificação demonstrativa foram confirmados pela árvore acessível antes da captura; os registros do navegador tiveram **zero erros de execução/console** nos sete cenários.
- Formulários: validação de senha legível com texto a 200% e teclado de 300 px; login bloqueado durante envio e recuperado após erro; seletor documental nas larguras 360, 390 e 412 px.
- Telas profissionais preenchidas, inclusive cadastro de empresa: 360, 390 e 412 px com texto a 200%, além de foco e teclado no cadastro.
- Sete módulos administrativos preenchidos: 360, 390 e 412 px com texto a 200%, incluindo busca com teclado.
- Estados em altura de 220 px e texto a 200%: carregamento, erro e vazio; nova tentativa acionada por toque e por Tab/Enter; diretrizes de área de toque e rótulo do Flutter.
- Sessão: login necessário mantém a rota original; uma conta cliente não constrói o conteúdo administrativo restrito.
- Densidade dos botões: alturas mínimas conferidas com tema Android e densidade compacta de Linux e Windows.

### Contraste da paleta existente

Os seis pares abaixo passaram na verificação automatizada de razão mínima 4,5:1. A verificação cobre esses pares de leitura; não certifica todos os elementos do aplicativo.

| Texto | Fundo | Razão aproximada |
| --- | --- | --- |
| Branco | Verde oficial | 5,32:1 |
| Texto principal | Branco | 12,34:1 |
| Texto auxiliar | Branco | 5,08:1 |
| Texto auxiliar | Fundo oficial | 4,82:1 |
| Verde escuro | Verde claro | 7,82:1 |
| Erro | Branco | 5,70:1 |

## Capturas da prévia

As imagens são capturas do Flutter web com viewport móvel de 844 px de altura, proporção de pixels 1 e texto padrão. São dados fictícios identificados como DEMO; não representam uma homologação da API ou do banco. Login, Segurança e Documentos são as telas reais; carregando, erro e vazio mostram os componentes reais na galeria de conferência; acesso restrito usa a verificação real de papel com uma sessão demonstrativa cliente.

| Tela ou estado | 360 px | 390 px | 412 px |
| --- | --- | --- | --- |
| Login | [Captura](login-360.png) | [Captura](login-390.png) | [Captura](login-412.png) |
| Segurança | [Captura](seguranca-360.png) | [Captura](seguranca-390.png) | [Captura](seguranca-412.png) |
| Documentos | [Captura](documentos-360.png) | [Captura](documentos-390.png) | [Captura](documentos-412.png) |
| Carregando | [Captura](carregando-360.png) | [Captura](carregando-390.png) | [Captura](carregando-412.png) |
| Erro | [Captura](erro-360.png) | [Captura](erro-390.png) | [Captura](erro-412.png) |
| Vazio | [Captura](vazio-360.png) | [Captura](vazio-390.png) | [Captura](vazio-412.png) |
| Acesso restrito | [Captura](restrito-360.png) | [Captura](restrito-390.png) | [Captura](restrito-412.png) |

O [resumo das capturas](capturas.json) registra dimensões e erros do navegador. As imagens complementam os testes de responsividade e texto ampliado. Teclado nativo, TalkBack e VoiceOver devem ser conferidos em aparelho real.

## Reprodução da galeria

O alvo separado de desenvolvimento exige a flag de demonstração e usa o transporte demonstrativo existente, sem modificar a inicialização de produção:

```sh
flutter run -d chrome --target=tool/preview_estilizacao.dart --dart-define=CONECTALAR_DEMO=true
```

Na URL da galeria, escolha `?tela=login`, `seguranca`, `documentos`, `carregando`, `erro`, `vazio` ou `restrito`. Para gerar a versão estática:

```sh
flutter build web --debug --no-pub --no-wasm-dry-run --target=tool/preview_estilizacao.dart --dart-define=CONECTALAR_DEMO=true
```
