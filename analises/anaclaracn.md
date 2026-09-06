# Autopsia: AWS S3 (us-east-1) (28/02/2017)

**Autor:** Ana Clara Carvalho Nascimento (@anaclaracn)  
**Fonte primaria:** https://aws.amazon.com/pt/message/41926/
**Data de acesso:** 27/08/2026

## 1. O que aconteceu
Em 28/02/2017, durante a depuração do sistema de faturamento do Amazon S3 na região us-east-1, um engenheiro executou um comando manual com um parâmetro incorreto, removendo acidentalmente mais servidores do que o planejado. Essa remoção afetou subsistemas vitais de metadados e alocação de armazenamento, forçando a reinicialização completa de ambos. A falha teve início às 09:37 PST, a detecção e diagnóstico foram imediatos, e a restauração gradual dos serviços PUT/GET/LIST finalizou às 13:54 PST, totalizando cerca de 4 horas de indisponibilidade geral.

## 2. Qual das Tres Vias falhou
A **Primeira Via - Fluxo** falhou. O foco da Primeira Via é garantir o fluxo contínuo de valor do desenvolvimento para a operação, aplicando barreiras de proteção (*guardrails*), limitação de raio de alcance (*blast radius*) e automação segura nas atividades operacionais. No caso da AWS, a ferramenta utilitária executada manualmente pelo operador permitia a remoção ilimitada e ultra-rápida de capacidade, sem nenhuma verificação automática que impedisse o desligamento de servidores abaixo da quantidade mínima necessária para manter o sistema no ar.

## 3. Quais metricas DORA teriam denunciado antes
Duas métricas de estabilidade teriam denunciado o risco da organização antes da queda:

1. **Tempo médio de restauração (MTTR):** Se medido previamente através de simulações de recuperação a frio (*disaster recovery*), o valor do MTTR para os subsistemas centrais de *index* e *placement* registraria um tempo estimado de recuperação de várias horas, bem distante do nível *Elite* (< 1h). Esse número alto revelaria que a organização não conseguia reconstruir o índice e checar a integridade dos metadados de forma ágil caso ocorresse uma falha total.
2. **Taxa de falha em mudanças:** O indicador numérico de falhas em intervenções manuais via scripts e *playbooks* em ambiente de produção denunciaria a fragilidade do processo. Medir a taxa de erros ou retrabalhos nessas manutenções rotineiras mostraria uma porcentagem de risco aceito inaceitável, indicando que a dependência de comandos manuais sem *guardrails* causaria degradação no ambiente a qualquer momento.

## 4. Qual pratica do semestre teria evitado e em que semana
A combinação da **Esteira de CI/CD (Semanas 7–8)** com a prática de **GitOps (Semana 12)**.

Se as operações no ambiente fossem gerenciadas por uma esteira de CI/CD com validações automáticas e aplicadas via GitOps (onde um `git push` é a única forma de alterar produção), o comando de manutenção não teria sido executado manualmente direto no terminal via script/playbook. A esteira conteria *guardrails* automáticos para barrar qualquer alteração que removesse capacidade acima do limite de segurança dos subsistemas, e a mudança passaria por um fluxo automatizado e auditável antes de impactar o ambiente.

## 5. A cultura do relatorio: generativa ou patologica?
O relatório reflete uma cultura **generativa (orientada a desempenho)**, conforme a tipologia de Westrum. Em momento algum o texto foca em apontar culpados, punir o operador ou atribuir o erro à falha individual do engenheiro. Em vez disso, assume a responsabilidade sistêmica, analisando como as ferramentas e arquiteturas permitiram que um erro humano levasse a um desastre de ampla escala.

Essa postura fica explicitamente demonstrada quando se diz que a ferramenta utilizada permitiu que muita capacidade fosse removida rápido demais, no seguinte trecho extraído do relatório oficial:

> "While removal of capacity is a key operational practice, in this instance, the tool used allowed too much capacity to be removed too quickly. We have modified this tool to remove capacity more slowly and added safeguards to prevent capacity from being removed when it will take any subsystem below its minimum required capacity level."

## 6. O que mais me surpreendeu no relatório
O que mais me surpreendeu foi a **ironia do próprio painel de status ter ficado fora do ar**. O *Service Health Dashboard* — justamente a ferramenta que a AWS usa para comunicar incidentes aos clientes — rodava sobre o S3 e, por isso, ficou indisponível durante a crise (das 09:37 às 11:37 PST). Ou seja, o canal oficial de comunicação da própria nuvem dependia do serviço que acabara de cair, obrigando a AWS a recorrer ao Twitter e a banners para avisar os clientes.

Esse detalhe me surpreendeu porque revela que até uma empresa com a maturidade operacional da AWS carregava um **ponto único de falha escondido** — uma dependência circular entre o serviço e o seu próprio mecanismo de status. Foi o ponto que mais me fez refletir: se nem a AWS garante que sua ferramenta de comunicação seja independente do serviço monitorado, imagine o risco silencioso de dependências não mapeadas em sistemas menores.

Além disso, me impressionou a **desproporção entre causa e efeito**: um único parâmetro digitado errado em um comando derrubou, por cerca de 4 horas, uma das regiões mais importantes da nuvem, afetando S3, EC2, EBS e Lambda. A causa foi mínima (um erro de digitação) e o impacto, gigantesco.