# Perfis — conferência visual de 25/10/2026

Capturas da galeria Flutter Web em **modo demonstração**, com dados fictícios. A revisão cobre o perfil do cliente, o perfil privado do profissional e o perfil público em larguras de **360, 390 e 412 pixels lógicos**, com texto em 100% e 200%.

O cabeçalho do cliente e do profissional passa a colocar o avatar acima do nome com texto ampliado, preservando palavras inteiras e a leitura do tipo de conta. Os cartões de opções compartilham hierarquia visual. O perfil profissional mostra a aba Perfil selecionada, o acesso direto à edição e a situação de atendimento separada da análise documental. O perfil público exibe cidade e UF quando informadas, além da quantidade de avaliações por extenso.

| Tela | 360 px | 390 px | 412 px |
| --- | --- | --- | --- |
| Cliente, 100% | [captura](perfil-cliente-360.png) | [captura](perfil-cliente-390.png) | [captura](perfil-cliente-412.png) |
| Cliente, 200% | [captura](perfil-cliente-200-360.png) | [captura](perfil-cliente-200-390.png) | [captura](perfil-cliente-200-412.png) |
| Profissional privado, 100% | [captura](perfil-profissional-privado-360.png) | [captura](perfil-profissional-privado-390.png) | [captura](perfil-profissional-privado-412.png) |
| Profissional privado, 200% | [captura](perfil-profissional-privado-200-360.png) | [captura](perfil-profissional-privado-200-390.png) | [captura](perfil-profissional-privado-200-412.png) |
| Profissional público, 100% | [captura](perfil-publico-360.png) | [captura](perfil-publico-390.png) | [captura](perfil-publico-412.png) |
| Profissional público, 200% | [captura](perfil-publico-200-360.png) | [captura](perfil-publico-200-390.png) | [captura](perfil-publico-200-412.png) |

As capturas de 360 px também incluem posições intermediárias e finais após rolagem. O [manifesto](capturas.json) contém as dimensões e **nenhuma exceção registrada pelo navegador**. O modo demonstração não fornece a situação de habilitação completa, por isso a prévia privada mostra “Situação de atendimento indisponível”; no aplicativo, a tela usa o dado recebido da API.

Esta conferência não substitui o teste no Android físico, com API real, teclado nativo ou leitor de tela. Nenhum aparelho Android estava conectado nesta rodada.
