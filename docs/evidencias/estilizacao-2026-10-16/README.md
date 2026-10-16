# Conferência visual — 16/10/2026

As 108 capturas desta pasta usam a galeria Flutter Web local em **modo demonstração**, após os commits de Google/GPS do `main`. Nomes, documentos, indicadores e atendimentos são fictícios. O arquivo [capturas.json](capturas.json) registra largura, escala do texto e exceções do navegador; nenhuma exceção foi registrada.

## Telas conferidas

- 360, 390 e 412 pixels lógicos: Home, Busca, perfil público, agenda profissional, moderação documental, login, documentos profissionais, erro e lista vazia.
- 360 pixels lógicos com texto a 200%: as mesmas telas, incluindo prévia e decisão documental.
- Capturas abaixo do primeiro enquadramento mostram a rolagem do conteúdo; os diálogos documentais foram abertos na prévia.

Exemplos: [Home 390](home-390.png), [Busca 360](busca-360.png), [agenda 412](agenda-412.png), [documentos admin a 200%](admin-documentos-200-360.png), [decisão a 200%](admin-documentos-200-decisao-360.png), [login a 200%](login-200-360.png) e [erro 360](erro-360.png).

## Ajustes a partir das capturas

- Na moderação documental, o status passa para baixo do nome e do tipo do documento quando o texto está muito ampliado. Isso evita quebrar “Documento de identificação” no meio das palavras.
- A navegação inferior administrativa limita apenas a ampliação dos rótulos para manter as cinco áreas legíveis em 360 pixels; o restante da tela respeita a escala de texto escolhida.
- O campo de rejeição usa o rótulo mais curto “Justificativa”, com instrução de apoio sobre quando preenchê-lo.

## Limites

Estas capturas verificam aparência com dados locais. Teclado nativo, TalkBack, seletor de arquivos e fluxos com API/MySQL exigem [homologação Android física](../homologacao-android-2026-10-16/README.md). A galeria não substitui esses testes.
