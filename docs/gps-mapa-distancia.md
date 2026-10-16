# GPS, mapa e busca por distancia

O ConectaLar pode usar a localizacao atual sob acao explicita do usuario para
ordenar e filtrar profissionais. Nao existe rastreamento em segundo plano. A
coordenada fica somente na memoria da tela, e enviada no corpo de um `POST` e
nao e gravada no perfil do cliente.

O servidor aplica duas regras ao mesmo tempo:

- o profissional deve estar dentro da distancia escolhida pelo cliente;
- o cliente deve estar dentro do raio de atendimento cadastrado pelo
  profissional.

Perfis sem coordenadas nao aparecem na busca por distancia. No mapa publico, a
API arredonda as coordenadas do profissional para aproximadamente duas casas
decimais, evitando expor o ponto exato cadastrado.

## Configurar o Android

1. No Google Cloud, habilite `Maps SDK for Android`.
2. Crie uma chave exclusiva para o aplicativo Android.
3. Restrinja a chave ao pacote `br.com.conectalar.app` e aos SHA-1 usados em
   debug e release.
4. Restrinja a API permitida a `Maps SDK for Android`.
5. No PowerShell usado para gerar o APK, defina a chave apenas para a sessao:

```powershell
$env:GOOGLE_MAPS_ANDROID_API_KEY='SUA_CHAVE_ANDROID'
```

6. Gere ou execute o app habilitando o mapa:

```powershell
flutter run --dart-define=CONECTALAR_GOOGLE_MAPS_ENABLED=true --dart-define=CONECTALAR_API_BASE_URL=http://IP_DO_SERVIDOR:3012
```

Para um APK de teste:

```powershell
flutter build apk --debug --dart-define=CONECTALAR_GOOGLE_MAPS_ENABLED=true --dart-define=CONECTALAR_API_BASE_URL=http://IP_DO_SERVIDOR:3012
```

Sem a chave ou sem o `dart-define`, a busca por distancia continua funcionando
em lista, mas o botao de mapa nao e exibido. Nao grave a chave real no Git.

## Geocodificacao no servidor

A chave Android nao deve ser reutilizada pela API. Crie uma chave separada,
restrita ao IP publico do servidor e somente a `Geocoding API`, e configure:

```env
GOOGLE_MAPS_SERVER_API_KEY=SUA_CHAVE_DE_SERVIDOR
```

Essa chave transforma CEP/regiao em coordenadas ao salvar enderecos e perfis.
Sem ela, ViaCEP continua preenchendo os campos textuais, mas novos cadastros
podem ficar indisponiveis no mapa e na busca por distancia.

## Permissoes e privacidade

- Android solicita localizacao aproximada ou precisa somente ao tocar em
  `Usar minha localizacao`.
- iOS e Web podem usar a busca por distancia; no Web o navegador exige HTTPS
  fora de `localhost`.
- A versao atual habilita o mapa Google apenas no Android. A configuracao
  nativa da chave iOS continua pendente de um ambiente macOS.
- O app nao solicita permissao de localizacao em segundo plano.
- O endpoint recomendado para GPS e `POST /profissionais/busca`, evitando
  coordenadas em URLs e logs comuns de proxy.

## Teste manual

1. Abra Buscar e toque em `Usar minha localizacao`.
2. Aceite a permissao e confirme que os resultados exibem distancia.
3. Troque entre 5, 10, 25 e 50 km e confira a atualizacao da lista.
4. Abra o mapa e toque em um marcador profissional.
5. Negue a permissao, tente novamente e confira a mensagem.
6. Marque a permissao como negada permanentemente e confira o atalho para as
   configuracoes do aplicativo.
7. Desative a localizacao do aparelho e confira o atalho correspondente.
8. Remova a localizacao e confirme que a busca manual por bairro/cidade volta.
