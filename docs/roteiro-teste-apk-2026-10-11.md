# Roteiro de teste manual do APK

Data: 11/10/2026

Use este roteiro para testar o APK debug gerado para a API local.

## Preparacao

1. Ligue o MySQL local.
2. Inicie a API:

```powershell
cd C:\Users\User\Downloads\ConectaLar-main\ConectaLar-main\apps\api
$env:HOST='0.0.0.0'
$env:PORT='3012'
$env:DB_HOST='127.0.0.1'
$env:DB_PORT='3307'
$env:DB_USER='conectalar_app'
$env:DB_PASSWORD='ConectaLarDev123!'
$env:DB_NAME='conectalar_dev'
$env:AUTH_TOKEN_SECRET='local-dev-secret-change-before-production-123456'
npm.cmd start
```

3. No navegador do celular, abra:

```text
http://192.168.15.5:3012/health
```

Resultado esperado:

```json
{"status":"ok"}
```

4. Instale o APK:

```text
C:\Users\User\Downloads\ConectaLar-main\ConectaLar-main\conectalar-192-168-15-5-debug.apk
```

## Usuarios demo

```text
cliente.demo@conectalar.local
profissional.demo@conectalar.local
admin.demo@conectalar.local

Senha:
ConectaLarDemo123!
```

Se o seed demo foi executado recentemente, faca logout e login novamente.

## Fluxo cliente

- [ ] Abrir Home e confirmar categorias/profissionais.
- [ ] Entrar como cliente.
- [ ] Conferir perfil.
- [ ] Conferir enderecos.
- [ ] Criar ou selecionar endereco.
- [ ] Buscar profissional.
- [ ] Abrir perfil profissional.
- [ ] Criar solicitacao escolhendo servico, endereco, data, horario e descricao.
- [ ] Confirmar que a solicitacao aparece em Meus servicos como `aguardando_resposta`.

## Fluxo profissional

- [ ] Entrar como profissional.
- [ ] Abrir area profissional.
- [ ] Confirmar que a solicitacao aparece sem endereco completo antes do aceite.
- [ ] Abrir agenda.
- [ ] Aceitar a solicitacao.
- [ ] Confirmar que o endereco completo aparece somente depois do aceite.
- [ ] Enviar mensagem no chat.

## Fluxo cliente apos aceite

- [ ] Voltar ao cliente.
- [ ] Abrir detalhes do atendimento.
- [ ] Conferir status aceito/agendado.
- [ ] Responder mensagem no chat.
- [ ] Concluir atendimento.
- [ ] Avaliar profissional.
- [ ] Abrir denuncia vinculada ao atendimento.

## Fluxo administrativo

- [ ] Entrar como administrador.
- [ ] Abrir painel administrativo.
- [ ] Conferir usuarios.
- [ ] Conferir categorias.
- [ ] Conferir documentos.
- [ ] Conferir denuncias.
- [ ] Moderar a denuncia criada no teste.
- [ ] Conferir avaliacoes pendentes.
- [ ] Moderar a avaliacao criada no teste.
- [ ] Conferir auditoria e validar que aparecem eventos de moderacao.

## Testes de erro

- [ ] Desligar a API e confirmar que o app mostra erro recuperavel, nao tela quebrada.
- [ ] Ligar a API novamente e testar o botao de tentar novamente.
- [ ] Fazer logout e login novamente.
- [ ] Se trocar de rede, confirmar novo IP e gerar APK novo com `CONECTALAR_API_BASE_URL`.

## Evidencias

Registre:

- data/hora;
- IP usado;
- APK usado;
- usuarios usados;
- prints das principais telas;
- qualquer mensagem de erro exibida;
- logs da API quando houver falha.
