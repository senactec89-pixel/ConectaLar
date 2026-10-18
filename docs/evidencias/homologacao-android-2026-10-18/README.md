# Homologação Android com API de teste — 18/10/2026

## Ambiente

- Aparelho: Samsung SM A035M, Android 13 (API 33), painel físico 720 × 1600 e densidade configurada em 280 dpi (aproximadamente 411 px lógicos).
- App Flutter debug `br.com.conectalar.app`, apontado para API local de teste, com modo demonstração desativado.
- API ligada a um MySQL temporário e isolado para homologação. Os perfis, pedidos, documentos e demais registros usados nesta execução são fictícios.
- Para conferir a responsividade, usei temporariamente tamanhos de exibição equivalentes a 360, 390 e 412 px lógicos no mesmo aparelho. Restaurei o tamanho físico de 720 × 1600 e a escala de fonte original de 0,8 ao terminar.

## Fluxos conferidos

- **Cliente:** login pela API, Home e Busca com categorias e profissionais reais do banco de teste, perfil e consulta a uma solicitação de teste.
- **Profissional:** login, lista de solicitações, aceite de um pedido de teste e consulta do atendimento na agenda. O cartão exibiu duração de 120 minutos e o endereço liberado após o aceite.
- **Empresa:** login, perfil e verificação documental. O seletor nativo abriu; um JPEG fictício de 823 bytes foi escolhido e enviado. O app exibiu o documento com estado “Em análise”.
- **Administração:** login, painel e fila documental. A prévia do JPEG enviado pela empresa abriu no app admin. Uma referência de documento que já estava no seed não tinha arquivo correspondente no armazenamento isolado e apresentou uma mensagem de falha; o documento recém-enviado abriu normalmente.
- **Indisponibilidade e recuperação:** parei temporariamente a API acessível pelo celular. A lista administrativa passou para um estado de erro com “Tentar novamente”. Depois de reiniciar a API, o botão recarregou a lista.
- **Larguras e texto:** nas larguras simuladas, os filtros documentais ocuparam duas linhas em 360 e 390 px e uma linha em 412 px. Os cartões permaneceram acessíveis por rolagem. A 360 px e escala de fonte 130%, a tela continuou rolável e não observei cortes por overflow; também não encontrei registro de `RenderFlex overflow` no logcat.
- **Teclado:** os campos de e-mail e senha abriram o teclado Android durante os logins e permitiram concluir a autenticação. A digitação foi automatizada por ADB; não considerei isso uma avaliação completa de digitação ou autofill.

## Capturas

- Layout documental: [360 px](admin-documentos-360.png), [390 px](admin-documentos-390.png), [412 px](admin-documentos-412.png) e [360 px com fonte a 130% e rolagem](admin-documentos-360-texto-ampliado.png).
- [Empresa após enviar o documento fictício](empresa-documento-enviado.png) e [prévia do documento no admin](admin-previa-documento.png).
- [API indisponível](admin-api-indisponivel.png) e [lista após recuperar a API e tentar novamente](admin-api-recuperada.png).

## Ainda pendente

- TalkBack e leitor de tela não foram avaliados. Não alterei os serviços de acessibilidade configurados no aparelho.
- Não completei manualmente a verificação do limite de 5 MB. O envio físico confirmado foi de um JPEG pequeno; os limites também têm cobertura automatizada do projeto.
- A perda de rede foi simulada parando a API de teste enquanto o Wi-Fi permanecia ligado; não desliguei Wi-Fi/dados móveis.
- As larguras 360 e 390 foram simuladas por override de exibição no SM A035M, não em aparelhos físicos distintos.
- A falha da referência antiga no seed indica ausência do arquivo correspondente no armazenamento de teste. Não alterei código do backend nem os registros originais do seed. O MySQL temporário foi parado e o arquivo local criado pelo envio de teste foi removido.

Esta execução comprova os fluxos descritos acima no ambiente isolado; não substitui homologação de release nem validação humana de acessibilidade.
