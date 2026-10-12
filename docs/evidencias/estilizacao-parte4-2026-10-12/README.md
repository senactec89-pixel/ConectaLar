# Parte 4 — Busca e perfil profissional

Data: 12/10/2026. Base: `ca894e7`. O trabalho começou após `git pull origin main`; as partes 2 e 3 foram verificadas e enviadas antes desta etapa.

Referências visuais: página 2 de `Prototipo 2.pdf` (Busca) e C03 de `ConectaLar_Telas_Individuais_Cliente_Profissional.pdf` (perfil público). Os protótipos orientam a composição; as permissões e os dados continuam definidos pela integração existente.

## Ajustes

- Busca: campos e categorias alinhados à margem de conteúdo, com uma camada decorativa a menos e mais espaço para resultados. Título da seção e metadados usam a hierarquia do tema.
- Perfil: cabeçalho prioriza nome, bairro, foto e indicadores; apresentação, serviços e atendimento têm seções próprias. As avaliações usam seus cards diretamente, sem outro card externo.
- Atalhos Sobre, Serviços e Avaliações permitem rolar até a seção, com área de toque mínima de 48 px e suporte a texto ampliado. São controles locais de navegação, sem nova rota.
- Serviços oferecidos aparecem como linhas legíveis, usando os nomes e preços das ofertas já recebidas. Quando a oferta não tem preço, o app informa consulta; não replica o preço mínimo geral em cada serviço.
- Foto indisponível ou com erro mostra a inicial do nome. A apresentação e os serviços sem dados recebem mensagens claras.
- O aviso de solicitação pendente de aceite e o pagamento combinado entre as partes permanecem no bloco Atendimento. A barra de solicitação usa a borda existente no lugar da sombra.

## Preservação

- `AppColors` foi comparado com a parte 1 (`0e8571d`) e mantém exatamente os mesmos valores. Os ajustes usam a paleta existente.
- Os métodos de busca/filtros e normalização, o callback de favoritos e as condições de acesso do perfil foram comparados com a base e preservados.
- Solicitar atendimento continua passando o objeto profissional original, incluindo suas ofertas, para a mesma rota. Os atalhos não refazem a consulta de avaliações.
- Somente telas Flutter, testes e documentação foram alterados. Não houve edição de backend, banco, serviços, modelos ou contratos.

## Cobertura adicionada

- Navegação pelas três seções em 360, 390 e 412 px com texto 200%, sem consultas adicionais de avaliações.
- Preservação dos argumentos da solicitação e dos preços próprios das ofertas.
- Ausência de foto válida e de preço por serviço sem inventar valores.
- Ações do perfil preservadas para profissional e administrador.
- O teste da Busca passou a retornar aos filtros pela rolagem antes de acessar a faixa de categorias, acompanhando o novo layout e a montagem sob demanda da lista.

As capturas desta etapa incluem o resultado das [partes 2](../../estilizacao-parte2-2026-10-12.md) e [3](../../estilizacao-parte3-2026-10-12.md).

## Verificação automatizada

- `dart format` e `git diff --check`: aprovados.
- `flutter analyze`: sem problemas.
- Testes específicos de Busca e perfil: 10 aprovados.
- `flutter test --no-pub --concurrency=2 --reporter expanded`: 94 testes aprovados em 2 min 30 s, saída 0.
- A cobertura inclui texto até 200%, conteúdo longo, três larguras móveis e espaço de teclado simulado nos cenários da Busca. Usa dados controlados e não equivale a homologação com aparelho físico e API real.

## Capturas conferidas

Dezoito imagens em Chrome headless, com altura de 844 px e texto em escala normal. Foram inspecionados cards, filtros, indicadores, serviços, avaliações e a barra de solicitação nas três larguras. A faixa DEMONSTRAÇÃO identifica os dados fictícios.

| Tela/estado | 360 px | 390 px | 412 px |
| --- | --- | --- | --- |
| Busca preenchida | [Captura](busca-360.png) | [Captura](busca-390.png) | [Captura](busca-412.png) |
| Categoria selecionada | [Captura](busca-categoria-360.png) | [Captura](busca-categoria-390.png) | [Captura](busca-categoria-412.png) |
| Busca vazia | [Captura](busca-vazia-360.png) | [Captura](busca-vazia-390.png) | [Captura](busca-vazia-412.png) |
| Favoritos | [Captura](favoritos-360.png) | [Captura](favoritos-390.png) | [Captura](favoritos-412.png) |
| Perfil e serviços | [Captura](perfil-publico-360.png) | [Captura](perfil-publico-390.png) | [Captura](perfil-publico-412.png) |
| Perfil após o atalho Avaliações | [Captura](perfil-publico-avaliacoes-360.png) | [Captura](perfil-publico-avaliacoes-390.png) | [Captura](perfil-publico-avaliacoes-412.png) |

As seis execuções concluídas registraram zero exceções e zero erros de console. Os avisos de viewport e GPU do navegador estão no [resumo](resumo-navegador.json). A captura de avaliações foi repetida após interrupção do processo de captura; a execução final terminou normalmente e gerou as três imagens.

Compilação da prévia aprovada:

```bash
flutter build web --debug --no-pub --no-wasm-dry-run --dart-define=CONECTALAR_DEMO=true --output=/tmp/conectalar-estilo-parte4-web
```

As imagens não simulam teclado nativo nem ampliação de texto; esses cenários foram cobertos pelos testes Flutter indicados acima.
