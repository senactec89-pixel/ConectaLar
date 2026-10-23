# Imagem da Home — 21/10/2026

A fotografia circular foi reposicionada acima do campo de busca e reenquadrada para destacar a fachada. O tamanho se adapta à largura da tela; o fundo e o contorno usam cores já definidas no tema. A altura do cabeçalho, a busca e os demais componentes foram preservados.

## Capturas

Prévia Flutter Web com dados fictícios, em viewport mobile. As imagens mostram a primeira área visível de cada largura.

| Largura lógica | Texto normal | Texto a 200% |
| --- | --- | --- |
| 360 px | [Captura](home-360.png) | [Captura](home-200-360.png) |
| 390 px | [Captura](home-390.png) | [Captura](home-200-390.png) |
| 412 px | [Captura](home-412.png) | [Captura](home-200-412.png) |

## Verificações

- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub test/home_visual_test.dart`: aprovado.
- Build da prévia web: concluído; a captura registrou zero exceções do navegador.
- Conferência visual: círculo inteiro acima da busca em 360, 390 e 412 px; sem sobreposição da saudação ou do campo, inclusive com texto a 200%.

Estas capturas conferem a aparência da prévia; não representam homologação em aparelho físico.
