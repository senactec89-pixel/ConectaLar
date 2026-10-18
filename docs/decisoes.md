# Decisões técnicas registradas

- A nova API será construída em Node.js, TypeScript e NestJS, conforme o prompt mestre. O PHP existente é legado e deve ser preservado.
- A API vive em `apps/api`, separada do aplicativo Flutter e do backend PHP.
- A API aceita Node.js 22.13+ na linha 22 ou 24.15+; o mínimo da linha 22 acompanha TypeORM 1.1.2. O runtime atual disponível para validação é o Node 22.23.3 instalado pelo usuário. A ferramenta não altera o PATH global.
- Em 9 de outubro de 2026, o usuário aprovou TypeORM + `mysql2` para a camada MySQL. Dependências fixadas: `@nestjs/typeorm` 12.0.2, TypeORM 1.1.2 e `mysql2` 3.24.5; ainda sem entidades, migrações ou conexão ativa.
- A configuração do TypeORM manterá `synchronize: false` e `migrationsRun: false`; migrações serão chamadas explicitamente depois que o escopo e as políticas forem aprovados.
- P01: login poderá usar e-mail ou telefone, conforme a resposta do usuário “ambos”. A normalização e a verificação dos dois contatos ainda precisam ser definidas antes do contrato de identidade.
- P02: o usuário aprovou a recomendação de recuperação por contato verificado e prova de uso único; senha exige prova de titularidade e logout invalida a sessão encerrada. Prazo de expiração e política de sessões simultâneas continuam sem valor definido.
- P15: o usuário definiu uma conta administrativa principal que pode criar contas para novos administradores. Cada administrador terá conta e e-mail próprios; MFA permanece obrigatório conforme o prompt mestre. Convites, concessão/revogação de permissões e recuperação da conta principal ainda precisam de fluxo definido.
- A porta local padrão é `3000` e o bind padrão é `127.0.0.1`. Um ambiente que precise de bind externo deverá configurar `HOST` conscientemente.
- A Etapa 1 não conecta ao MySQL e não define contratos ou módulos de negócio.
- `GET /health` e `GET /health/live` indicam apenas que o processo HTTP responde. `GET /health/ready` exige configuração de banco/autenticação, DataSource inicializado e uma consulta MySQL bem-sucedida; retorna 503 quando indisponível. Em produção, configuração de runtime incompleta impede a inicialização.
- Para a nova API, o prompt mestre atual prevalece sobre as referências técnicas antigas nos requisitos revisados: NestJS/MySQL substitui PHP/XAMPP; FCM é permitido apenas como transporte de push.
- Os documentos funcionais e de qualidade descrevem pagamento direto entre as partes, sem processamento financeiro no app. Não criar tabelas de cobrança/comissão no modelo inicial.
- Os documentos funcionais preservam RF001–RF030; RF031–RF042 são propostas. RNF027–RNF030 e Q01–Q08 também são propostas e não viram metas ou escopo implementado sem aprovação.
- Os cinco estados documentados do atendimento são: Aguardando resposta, Aceita/agendada, Recusada, Cancelada e Conclusão confirmada. Regras de transição dependentes de P08 continuam pendentes.

- Em 11/10/2026, o usuário solicitou os seis ajustes de fluxos descritos em `docs/ajustes-fluxos-2026-10-11.md`, incluindo proteção contra aceites simultâneos e persistência da oferta escolhida. O bloqueio usa a data e o horário inicial existentes; P06/P12 permanecem pendentes para duração, sobreposição e capacidade de empresa. Migrations desta tarefa foram aplicadas apenas em banco temporário de teste.
