# Progresso do ConectaLar

Atualizado em 2026-10-10, apos a integracao dos fluxos principais do app Flutter com a API NestJS/MySQL.

## Estado atual

O nucleo funcional de demo esta implementado no app e na API:

- cadastro e login de cliente, profissional e administrador;
- perfil profissional, ofertas, disponibilidade e documentos de verificacao;
- enderecos de cliente e solicitacoes com `enderecoId`;
- protecao do endereco completo antes do aceite e liberacao apenas para atores autorizados apos aceite;
- agenda/solicitacoes com estados formais `aguardando_resposta`, `aceita_agendada`, `recusada`, `cancelada` e `conclusao_confirmada`;
- chat vinculado a solicitacao e restrito aos participantes autorizados;
- conclusao de atendimento, avaliacoes e moderacao;
- denuncias, moderacao administrativa e trilha de auditoria;
- notificacoes internas;
- modulos administrativos para usuarios, documentos, denuncias, avaliacoes, categorias e auditoria;
- contrato OpenAPI atualizado para os fluxos principais.

## Evidencias recentes

- `flutter analyze --no-pub`: aprovado.
- `flutter test`: aprovado com 17 testes.
- `npm.cmd run typecheck`: aprovado.
- `npm.cmd test`: aprovado com 8 testes.
- MySQL local + API em `127.0.0.1:3016`: fluxo integrado validado com cadastro, login, upload documental, moderacao, solicitacao com endereco protegido, aceite, liberacao de endereco, chat, conclusao, avaliacoes, denuncia e auditoria.
- Commit publicado: `4e303d0 Corrige configuracao do body parser`.

Observacao: no Windows, `flutter analyze` sem `--no-pub` pode exigir Modo de Desenvolvedor por causa dos symlinks usados por plugins nativos como `file_picker`. Para analise rapida sem tentar recriar plugins, use `flutter analyze --no-pub`; para ambiente completo, habilite o Modo de Desenvolvedor do Windows.

## Checklist de demo

A validacao integrada via contrato HTTP esta registrada em `docs/checklist-demo.md`. O que ela cobriu:

- envio real de PDF, JPEG e PNG pelo fluxo profissional;
- listagem desses documentos no painel administrativo;
- aprovacao e rejeicao de documentos pelo administrador;
- retorno do status atualizado na area profissional;
- cadastro de cliente;
- cadastro de profissional;
- criacao de solicitacao com endereco;
- aceite pelo profissional;
- endereco completo liberado apos aceite;
- mensagens no chat;
- conclusao do atendimento;
- avaliacao;
- denuncia;
- moderacao administrativa;
- auditoria administrativa.

Ainda falta a conferencia visual manual no Flutter do seletor nativo de arquivo, porque o clique abre uma interface do sistema operacional e nao foi automatizado neste roteiro.

## Pendencias para producao

Estes pontos nao bloqueiam demo local, mas bloqueiam uma publicacao profissional segura:

- MFA para administradores;
- recuperacao de senha com envio real por e-mail/contato verificado;
- armazenamento privado gerenciado para documentos, com antivirus/verificacao de conteudo;
- politica aprovada de retencao, descarte e atendimento a titulares de dados;
- limite de requisicoes distribuido para ambiente com mais de uma instancia;
- monitoramento, alertas e logs operacionais;
- backup/restauracao testados;
- pipeline de build/deploy;
- testes de carga e homologacao;
- ambiente macOS, aparelho de teste e contas de loja para iOS.
