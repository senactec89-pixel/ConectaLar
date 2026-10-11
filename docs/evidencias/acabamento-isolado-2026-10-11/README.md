# Acabamento visual isolado — 11/10/2026

Referências: `Prototipo 2.pdf` e `ConectaLar_Telas_Individuais_Cliente_Profissional.pdf` disponíveis no ambiente.

As capturas mostram o aplicativo Flutter Web em Chrome headless, navegando pela interface de demonstração. Os dados são fictícios e a faixa DEMONSTRAÇÃO permanece visível. Estas capturas registram aparência; não comprovam os fluxos com a API real.

## Disponibilidade

Aviso verde com hierarquia de título/texto, seção de horários, cards com ícone e ação de remoção identificada. O modal de adicionar horário ganhou título, orientação, seletor que respeita a largura e rolagem.

| 360 px | 390 px | 412 px |
| --- | --- | --- |
| [Captura](disponibilidade-360.png) | [Captura](disponibilidade-390.png) | [Captura](disponibilidade-412.png) |

Altura das capturas: 844 px lógicos, escala de dispositivo 1. O teste `test/disponibilidade_visual_test.dart` verifica as três larguras com texto a 200%, altura de 640 px e espaço de teclado de 300 px. Antes do ajuste, reproduziu overflow horizontal de 158 px; após o ajuste, passou e verificou o botão por toque e a adição do horário à lista local.

## Verificações desta etapa

- `flutter analyze --no-pub`: sem problemas.
- Teste específico de disponibilidade: passou.
- Navegador: nenhuma exceção de execução; avisos de viewport/GPU registrados no resumo.
- Base antes dos ajustes Flutter: suíte completa com 73 testes aprovados.
- Linux: compilação debug aprovada e janela aberta com título ConectaLar (`bdcab42`). A compilação Windows não foi executada neste ambiente Linux.
