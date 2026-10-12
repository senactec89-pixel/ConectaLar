# Parte 5 — formulários e ações

Data: 12/10/2026. Base: `04c0984`, conferida com `git pull origin main`.

- Botões de contorno, texto e ícone usam área mínima de 48 px no tema. Ações primárias mantêm 52 px e os raios definidos na parte 1.
- Mensagens auxiliares e de validação compartilham tamanho e altura de linha. O tema permite até quatro linhas auxiliares e oito linhas de validação, evitando o corte das mensagens existentes com texto ampliado.
- Login, cadastro, recuperação, Meus dados, Segurança, cadastro profissional e documentos usam os mesmos recuos e intervalos de formulário.
- Os SnackBars compartilham apresentação flutuante e cantos do tema; seus textos e chamadas continuam os mesmos.
- Durante o login, os campos e o envio por teclado acompanham o bloqueio do botão já existente. Após erro, os dados permanecem preenchidos e os controles voltam a permitir nova tentativa.
- O seletor de tipo documental apresenta rótulos curtos, mantendo os nomes completos na leitura acessível e no menu. Valores enviados, seleção nativa de arquivos, Base64, tipos permitidos e limite de 5 MB foram preservados.

## Verificação

- `AppColors` e as cores literais das sete telas foram comparados com a base e preservados integralmente.
- Os métodos anteriores à construção da interface foram comparados com a base, preservando os envios, validações, serviços e rotas.
- `dart format`, `git diff --check` e `flutter analyze`: aprovados, sem problemas.
- Três testes novos verificam validação completa com fonte 200% e teclado, envio único de login e recuperação dos dados após erro, além do seletor documental nas larguras 360, 390 e 412 px.
- `flutter test --no-pub --concurrency=2 --reporter expanded`: 97 testes aprovados em 2 min 45 s, saída 0.

As capturas do resultado conjunto das partes 5 e 6 serão registradas na parte 6. Os testes usam transporte controlado; não substituem a homologação em aparelho real.
