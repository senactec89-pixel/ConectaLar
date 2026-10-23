# Marca ConectaLar

A casa formada por partes conectadas e quatro janelas segue a referência visual
enviada pelo usuário em 22/10/2026. O símbolo foi reconstruído em curvas SVG;
os encaixes e as proporções foram ajustados para reprodução em tamanhos pequenos.

## Arquivos

- `conectalar_symbol.svg`: fonte vetorial editável, com fundo e espaços internos transparentes.
- `conectalar_symbol.png`: exportação transparente de 512 px para Flutter.
- `conectalar_icon_1024.png`: ícone com fundo branco, sem texto e sem cantos pré-recortados.

Cores sólidas: verde `#157A54` e verde escuro `#15553B`, já definidos no tema.
Sem degradê ou brilho. O nome **ConectaLar** nas telas é texto nativo, com
“Conecta” em verde escuro e “Lar” em verde, para permitir ampliação e leitura assistiva.
O símbolo ao lado do nome é decorativo, evitando leitura duplicada.

## Exportação

Na raiz do repositório, com Dart e Chrome instalados:

```sh
dart run tool/generate_brand_assets.dart
```

O script lê o SVG e exporta PNGs, ICO e vetores Android nos caminhos existentes.
`CHROME_EXECUTABLE` permite indicar o executável do navegador. Não requer novos
pacotes no aplicativo. Ícones de launcher recebem fundo branco; versões maskable
e adaptativa reservam margem extra para máscaras do sistema. A versão iOS é opaca.

A composição com o nome completo é usada nas telas. O ícone do dispositivo usa
somente a casa para preservar a leitura. A captura gerada por IA durante a exploração
não é usada no aplicativo: o SVG é a fonte final de produção.

As cores do tema, o identificador do aplicativo e as configurações de autenticação
continuam os mesmos. As exportações para iOS/macOS/Windows exigem conferência
nesses sistemas antes da distribuição; gerar os arquivos não equivale a homologá-los.
