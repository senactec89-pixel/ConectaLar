# Parte 3 — cards mais simples

Base: `d3bdf2a`. Data: 12/10/2026.

- Os serviços resumidos no card profissional usam marcadores discretos no lugar de pequenas cápsulas preenchidas. As cores do texto foram preservadas.
- Um separador na cor de borda existente organiza o rodapé com preço e ações. Foto, selo, dados, limite de três serviços e callbacks continuam iguais.
- As avaliações publicadas têm intervalo de 12 px entre cards, nota identificada por estrela, comentário com leitura contínua e data como informação auxiliar. A consulta, a moderação e o cálculo do resumo não foram modificados.
- Nenhuma cor oficial foi alterada. A remoção do fundo das etiquetas reduz as camadas decorativas.

## Verificação

- `dart format` e `git diff --check`: aprovados.
- `flutter analyze`: sem problemas.
- 36 testes aprovados (saída 0) em `profissional_card_visual_test.dart`, `favoritos_visual_test.dart`, `busca_visual_test.dart`, `fluxos_integrados_test.dart` e `acabamento_visual_test.dart`.
- A cobertura inclui dados longos, ausência de foto/nota/preço, preservação dos callbacks, texto até 200%, larguras 360/390/412 e avaliações carregadas com transporte simulado.

As capturas do conjunto das partes 2 a 4 serão registradas ao concluir a parte 4. A homologação em aparelho físico com API real continua separada destes testes.
