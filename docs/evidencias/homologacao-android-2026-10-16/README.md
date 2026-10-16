# Conferência Android física — 16/10/2026

## O que foi executado

- Aparelho detectado: Samsung SM A035M, Android 13 (API 33), via depuração USB.
- SDK Android instalado no diretório do usuário e licenças aceitas. `flutter doctor -v` concluiu sem problemas.
- `flutter run` compilou e instalou o APK anterior no aparelho. O painel administrativo abriu em modo de demonstração.
- A tela do painel e o caminho **Perfil → Segurança** foram conferidos no aparelho, com largura aproximada de 412 pixels lógicos (720 pixels físicos; densidade configurada em 280 dpi). Capturas da versão anterior: [painel](admin-demo-android.png) e [Segurança antes da correção](seguranca-admin-antes-correcao.png). Os dados visíveis são fictícios. A captura de Segurança revelou que a prévia consultava o cliente fictício de MFA; o código foi corrigido e coberto por teste.
- Após os commits de Google/GPS do colega, `flutter build apk --debug` gerou um APK novo com `applicationId` `br.com.conectalar.app`. A instalação dessa versão no aparelho ainda depende de ele voltar a aparecer no ADB.
- O limite de memória do Gradle foi ajustado para permitir o build neste computador de 8 GB de RAM.

## Ainda não homologado

- A API informada (`http://127.0.0.1:3012`) não respondeu a `/health` neste computador. Em aparelho físico, `127.0.0.1` aponta para o próprio celular; para usar a API local, é necessário `adb reverse tcp:3012 tcp:3012` ou um endereço de rede acessível ao celular.
- O aparelho se desconectou do ADB após a abertura inicial. Sem API/MySQL disponíveis, não foram executados os fluxos reais de cliente, profissional e administrador.
- Teclado nativo, TalkBack, seletor de documentos, texto ampliado, perda de rede e decisões administrativas com dados de teste continuam pendentes. Nenhum desses itens deve ser tratado como aprovado.

## Próxima execução

1. Reconectar o SM A035M e confirmar `adb devices -l`.
2. Subir a API com MySQL e confirmar `GET /health` a partir do computador; configurar acesso pelo aparelho.
3. Seguir os roteiros de [cliente](../../checklist-homologacao-cliente.md), [profissional](../../checklist-homologacao-profissional.md) e [administrador](../../checklist-homologacao-admin.md), registrando evidências sem dados pessoais.
