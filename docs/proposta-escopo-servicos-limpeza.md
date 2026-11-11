# Serviço piloto: limpeza — proposta de escopo

**Estado em 10/11/2026:** rascunho para a equipe definir o catálogo. Nenhum item desta página vira promessa ao cliente, preço obrigatório ou regra da API antes de aprovação. O colega responsável pelo catálogo deve revisar inclusões, exclusões e opções com profissionais e com a equipe de atendimento.

## O que o cliente precisa entender antes de pedir

Cada serviço publicado deve mostrar, em linguagem simples:

1. **Nome específico** e resumo de uma frase.
2. **Inclui:** tarefas que fazem parte da oferta padrão.
3. **Não inclui:** tarefas que exigem outro serviço, material, condição ou negociação.
4. **Opcionais:** tarefas que podem ser solicitadas separadamente; indicar se o profissional as oferece.
5. **Condições:** área aproximada, ambientes, acesso ao imóvel, materiais/equipamentos, duração estimada e restrições de segurança.
6. **Mudanças:** como cliente e profissional registram e aceitam alteração de escopo, valor ou horário antes da execução.

Não transformar o catálogo em cobrança interna. Valores finais continuam combinados fora do app; qualquer proposta registrada deve ser visível às partes e preservar o histórico do que foi combinado.

## Primeira ficha para validação: limpeza residencial comum

As linhas seguintes são **exemplos para discussão**, não uma lista aprovada. O responsável pelo catálogo deve revisar termos, limites, materiais e condições antes da publicação.

| Campo | Conteúdo proposto para discussão |
| --- | --- |
| Resultado esperado | Limpeza de manutenção de ambientes residenciais acessíveis, nas condições informadas no pedido |
| Inclusões candidatas | Pisos acessíveis, superfícies externas de móveis, banheiro e bancada/pia da cozinha, respeitando materiais e limites definidos na ficha final |
| Exclusões candidatas | Limpeza pós-obra, remoção de mofo ou produto perigoso, fachada/altura, desmontagem de móveis, interior de eletrodomésticos e descarte especial |
| Opcionais candidatos | Interior de armários vazios, janelas acessíveis, geladeira, forno e área externa de baixa complexidade |
| Informações a pedir | Número de ambientes, tamanho aproximado, presença de animais, condições de acesso, materiais disponíveis e observações relevantes |
| Limites pendentes | Quem fornece produtos e equipamentos, altura permitida, estado de sujeira, tempo mínimo e fotos necessárias sem expor pessoas ou bens desnecessariamente |

**Não publicar a ficha acima como serviço final.** Uma exclusão pode exigir tratamento diferente conforme o serviço e a capacitação; riscos de saúde e trabalho em altura precisam de critérios próprios.

## Estrutura de dados e apresentação a aprovar

O modelo atual de `profissional_servicos` guarda nome, categoria, preço inicial, duração, intervalo e estado ativo; não guarda inclusões, exclusões ou opcionais. A solicitação copia nome, duração, endereço e outros campos, mas não uma versão completa do escopo da oferta. Antes de alterar API ou Flutter, definir:

- Um **catálogo de tipos de serviço** com código estável, nome claro e versão da ficha; profissionais indicam quais tipos oferecem e podem informar condições próprias dentro de limites aprovados.
- Como guardar a **versão apresentada ao cliente** no momento do pedido, para uma edição posterior da oferta não mudar retroativamente o combinado.
- Quais opcionais são só informação no pedido e quais exigem uma proposta separada e aceite explícito.
- Como mostrar a ficha no perfil, no formulário de pedido e no detalhe do atendimento, inclusive texto ampliado e conexão instável.
- Como administradores revisam mudanças e evitam nomes duplicados ou promessas incompatíveis com a ficha oficial.

## Empresa e executor no mesmo fluxo

As decisões já registradas em `docs/proposta-politica-habilitacao-profissional.md` e `docs/proposta-contrato-habilitacao-profissional.md` continuam válidas como diretriz: cada executor de empresa deve ser identificado e verificado; a empresa o indica antes de aceitar; substituição exige verificação e aviso ao cliente. A ficha de serviço não autoriza alguém a executar nem dá acesso ao endereço. O backend precisa validar vínculo, habilitação e participação no pedido.

## Critérios de aprovação da ficha

- Cliente consegue distinguir o que está incluído, excluído e opcional antes de enviar o pedido.
- Profissional sabe o que aceitou e pode propor mudança sem alterar silenciosamente o pedido original.
- Histórico conserva a versão apresentada e a autoria das mudanças.
- Texto evita garantias absolutas de segurança, qualidade ou disponibilidade.
- Equipe revisou as condições operacionais, de privacidade e de segurança do serviço específico.
