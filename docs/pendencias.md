# Pendências do ConectaLar

**Organização atualizada em:** 25/11/2026.
**Objetivo:** acompanhar bloqueios de segurança, preparação técnica e critérios para lançamento. Os estados abaixo são um plano baseado nos registros do repositório; cada item precisa de responsável e evidência antes de ser marcado como concluído.

## Estado do lançamento

O núcleo do aplicativo Flutter e da API NestJS está implementado para desenvolvimento e demonstração. A beta técnica local usa dados fictícios. **Atendimentos com pessoas reais permanecem bloqueados** enquanto a política de habilitação profissional estiver incompleta e sem homologação. Testes registrados em documentos anteriores não comprovam, por si só, a prontidão do commit atual.

## P0 — Bloqueios de segurança, privacidade e operação

### Habilitação de profissionais e empresas

- [ ] Completar a política de habilitação: evidências, critérios de validade, reenvio, expiração, suspensão, revogação e contestação.
- [ ] Obter revisão jurídica e de privacidade para antecedentes, identidade/prova de vida, dados tratados por fornecedores e retenção/descarte. Usar o pacote em [proposta de política](proposta-politica-habilitacao-profissional.md) e o [inventário de dados e fornecedores](inventario-dados-e-fornecedores.md).
- [ ] Definir comprovantes profissionais aceitáveis e avaliar se há exigências próprias por categoria ou atividade.
- [ ] Projetar o cadastro e a habilitação de cada executor de empresa, incluindo vínculo, indicação antes do aceite e acesso individual ao endereço e às mensagens. O modelo atual não representa executores individuais.
- [ ] Completar e homologar a decisão final por dois administradores distintos com MFA, incluindo definição do que caracteriza conflito, exceções ao impedimento permanente, revisão de casos inconclusivos e contestação. Definir também se o impedimento deve cobrir análise documental, denúncias e avaliações, além do fluxo de habilitação. A API já exige autodeclaração, registra impedimento no fluxo de habilitação e mantém a aprovação final bloqueada.
- [ ] Definir prazos e procedimento para atendimento já aceito quando uma verificação expirar, telefone mudar ou executor sair da empresa.
- [ ] Aprovar avisos ao titular, canais de atendimento humano, correção de dados, contestação e procedimento de incidente.
- [ ] Manter as integrações de identidade e telefone desligadas para uso real até a revisão dos avisos, finalidade, dados, contratos e homologação controlada.
- [ ] Preservar o bloqueio de novas solicitações, aceites e acesso profissional ao endereço completo até a política completa estar aprovada, implementada e testada.

### Privacidade e governança

- [ ] Preencher finalidade, base legal a avaliar, acesso, retenção, descarte e tratamento de backups por categoria de dado, com responsáveis e revisão apropriada.
- [ ] Confirmar contratos, suboperadores, locais de tratamento, medidas de segurança e processos de incidente para cada fornecedor que será usado.
- [ ] Concluir revisão dos termos, avisos de privacidade e textos das telas antes de coletar dados reais de habilitação.
- [ ] Validar autorização no backend para endereço, documentos, mensagens, exportação, exclusão e administração; registrar resultados reproduzíveis.
- [ ] Definir procedimento e responsáveis para direitos de titulares que não sejam atendidos pelo fluxo automatizado.

## P1 — Base técnica e ambiente de homologação

### Integridade do código e do banco

- [ ] Fixar o commit e a cópia candidata a homologação; revisar as alterações locais ainda não incorporadas antes de preparar um release. No estado consultado em 25/11/2026, há alterações em `README.md`, `pubspec.lock` e dois arquivos gerados do Windows.
- [ ] Resolver a colisão de timestamp `1760123000000` entre as migrations `DuracaoAtendimentos` e `HabilitacaoProfissional`; confirmar ordenação e execução da sequência em MySQL descartável antes de qualquer banco candidato.
- [ ] Reconciliar documentação técnica antiga com o estado atual da API e revisar diferenças entre os estados formais descritos nos requisitos e os estados registrados pelo código.
- [ ] Executar typecheck, testes de API e Flutter e análise estática no commit candidato; registrar comandos, ambiente e resultados atuais.
- [ ] Aplicar a sequência atual de migrations em banco MySQL descartável e percorrer a integração API/banco, incluindo os gates de habilitação.

### Ambiente isolado e operação

- [ ] Escolher hospedagem, domínio e ambiente de homologação; manter API e MySQL separados do legado, desenvolvimento e dados reais.
- [ ] Configurar HTTPS, segredos fora do repositório, CORS, proxy confiável e limites contra abuso adequados à topologia escolhida.
- [ ] Criar e homologar armazenamento privado de documentos e fotos; instalar ClamAV e validar uploads com `MALWARE_SCAN_MODE=required`.
- [ ] Configurar SMTP e testar confirmação de e-mail e recuperação de senha em rede real.
- [ ] Configurar OAuth e chaves Google Maps restritas por plataforma/uso; homologar login e geocodificação com as credenciais candidatas.
- [ ] Implementar e provar backup e restauração em ambiente separado; configurar monitoramento, alertas, logs operacionais e resposta a incidentes.
- [ ] Validar rate limit distribuído se a implantação usar mais de uma instância.
- [ ] Definir política de sessões simultâneas e expiração de sessão.

### Homologação funcional

- [ ] Percorrer os fluxos de cliente, profissional e administrador em aparelho físico com API e MySQL de homologação.
- [ ] Homologar cadastro, verificação de e-mail, login, recuperação, endereços, busca, agenda, pedidos, aceite/recusa, chat, conclusão, avaliações, denúncias, documentos, moderação, exportação e exclusão.
- [ ] Testar permissões por papel, concorrência de agenda, rede instável, erros de integração, arquivos válidos/inválidos e telas com texto ampliado.
- [ ] Executar os checklists por papel na versão candidata e registrar evidências; não reutilizar caixas marcadas de uma versão antiga como resultado atual.

## P2 — Release e distribuição

- [ ] Aprovar identidade visual final do ícone, splash, nome e versão de produto; incrementar `versionCode` para cada envio.
- [ ] Definir custódia e backup controlado da chave Android release fora do Git.
- [ ] Configurar endpoint HTTPS de produção e credenciais OAuth release; produzir APK/AAB assinados depois da aprovação dos gates anteriores.
- [ ] Instalar e testar o artefato release em aparelho real, incluindo atualização da versão anterior, login, rede instável e arquivos.
- [ ] Registrar commit, versão, ambiente, hash do artefato e resultados de homologação.
- [ ] Preparar política pública de privacidade, ficha da loja, capturas, classificação, canal de suporte e processo de atualização.
- [ ] Decidir se haverá beta fechada e definir responsáveis pela operação do lançamento.
- [ ] Para iOS, preparar ambiente macOS, conta de loja, assinatura e homologação nativa antes de anunciar suporte/publicação.

## Recursos já registrados como implementados

Os itens abaixo constam nos registros do projeto; devem ser revalidados na versão candidata e não substituem homologação de produção:

- Autenticação por senha e Google, confirmação de e-mail, recuperação de senha e MFA administrativo.
- Perfis de cliente, profissional e empresa, ofertas, busca, disponibilidade e agenda.
- Solicitações, chat contextual, histórico, avaliações, denúncias e notificações internas.
- Proteção de endereço por autorização no backend e estados do atendimento.
- Upload de documentos com validação de formato/tamanho e scanner ClamAV configurável.
- Exportação de dados, exclusão/anonimização de conta e invalidação de sessões.
- Migrations explícitas, contrato OpenAPI e testes automatizados da API e do Flutter.

## Ordem de trabalho sugerida

1. Fechar o pacote de revisão P0 e registrar decisões e pendências com responsáveis.
2. Resolver a consistência do código/documentação e a sequência de migrations em ambiente descartável.
3. Implementar os controles de habilitação que forem aprovados, mantendo os gates de segurança.
4. Preparar ambiente isolado, fornecedores, backup, monitoramento e homologação ponta a ponta.
5. Gerar e validar builds de release somente após evidência dos gates anteriores.

## Documentação relacionada

- [Proposta de política de habilitação](proposta-politica-habilitacao-profissional.md)
- [Habilitação profissional e bloqueios atuais](habilitacao-profissional.md)
- [Inventário de dados e fornecedores](inventario-dados-e-fornecedores.md)
- [Progresso e validações registradas](progresso.md)
- [Segurança](seguranca.md)
- [Operação e produção](operacao-producao.md)
- [Homologação beta local](homologacao-beta-local.md)
- [Preparação Android](preparacao-android-release.md)
- Checklists de [cliente](checklist-homologacao-cliente.md), [profissional](checklist-homologacao-profissional.md) e [administração](checklist-homologacao-admin.md)
