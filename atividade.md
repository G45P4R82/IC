# MC926B/MO630A-Engenharia de Software Experimental (1s2026)

Exploring Machine Learning Models as Components (MSR)

# Assessment 1 \- Grupo B

Nome dos Alunos:  
1\. Breno Shigeki Guimarães Nishimoto \- 220599  
2\. Juan Manoel Marinho Nascimento \- 324077

1\. Develop a study protocol with the following:

* Brief description of the **research topic**, with supporting references.  
* Study definition, including research **goal** (using the GQM template), research **questions** based on the goal, and research **method** to be conducted (controlled experiment, in silico experiment, survey, case study, action-research, ...).  
* Study **Design**, considering variables, procedures (including tasks), intended participants, materials/instruments, data collection, and analysis methods.

The study protocol **must be based on any guidelines** in this course, and any further assumptions should be described in the document.

Study Protocol  
**Proposta de Pesquisa**

Acoplamento de Modelos de ML como Componentes de Software

1. Descrição do Problema 

A descrição segue o formato: cenário ideal → realidade/desafio → consequência, focando no acoplamento de modelos ML.

| Componente | Formulação |
| :---- | :---- |
| **Statement/Cenário ideal** | O cenário ideal requer que o nível de acoplamento seja adequado aos requisitos da aplicação, permitindo independência de evolução sempre que a latência e a conectividade não exigirem o embarque direto do modelo no código-fonte. |
| **However/ Realidade** | Atualmente, a integração ocorre via artefatos serializados que impõem um acoplamento temporal e tecnológico. A aplicação fica refém da mesma stack do treino (versões de bibliotecas e linguagem), tratando o modelo como um pedaço de memória compartilhada em vez de um serviço. |
| **Thus/Consequência** | Isso gera uma fragilidade arquitetural: qualquer mudança no pipeline de dados ou na versão da biblioteca de ML exige o redeployment e a reconfiguração de todo o sistema consumidor, inviabilizando a evolução independente dos componentes. Adicionalmente, é importante destacar que, em certos cenários (e.g., restrições de latência, operação offline ou limitações de conectividade), o embarque do modelo na aplicação não é apenas uma escolha, mas uma necessidade arquitetural. Nesses casos, níveis mais elevados de acoplamento podem ser aceitáveis ou até desejáveis, caracterizando um trade-off entre desempenho e modularidade. |

**Objeto de estudo:** A implementação da integração de modelos de ML e suas propriedades estruturais (acoplamento e dependências). 

2. Objetivo do Estudo (GQM)

**Analisar:** A implementação da integração de modelos de ML e suas propriedades estruturais (acoplamento e dependências).    
**Com o propósito de:** Caracterizar.  
**Com respeito à:** Manutenibilidade do código de integração, focando no nível de acoplamento e o impacto na infraestrutura de software.    
**Do ponto de vista de:** Engenheiros de software e pesquisadores de MSR.   
**No contexto de:** Repositórios de código aberto que expõem a transição de modelos experimentais para serviços de produção.

3. Questões de Pesquisa

QUESTÕES AGORA SÃO FOCADAS NA CARACTERIZAÇÃO GERAL. A PRIMEIRA FOCADA EM CARACTERIZAÇÃO DE PADRÕES.  
**RQ1:** Quais são os padrões de integração de modelos de ML predominantes nos repositórios minerados e como eles se distribuem (ex: modelos embarcados, serviços locais, APIs remotas)?   
Rationale: Antes de medir acoplamento, precisamos de uma taxonomia do que estamos encontrando. 

CARACTERIZAÇÃO DO ACOPLAMENTO  
TEMOS QUE PEGAR METRICAS  
**RQ2:** Quais as características estruturais (métricas de dependência e imports) que definem cada um desses padrões identificados?  
Rationale: Aqui você caracteriza o acoplamento de forma isolada para cada grupo, sem necessariamente dizer que um é "melhor" ou "pior" que o outro. 

RELAÇÃO COM A INFRAESTRUTURA  
**RQ3:** Como a maturidade da infraestrutura (presença de Docker, MLOps, CI/CD) se correlaciona com a forma de integração escolhida?   
Rationale:Ajuda a entender se o acoplamento forte é fruto de "projetos simples" ou se ocorre também em projetos complexos por necessidade técnica. 

4. Hipóteses

Por se tratar de um estudo exploratório e descritivo, não são formuladas hipóteses a priori.

5. Método de Pesquisa

MSR — Mining Software Repositories

O fluxo seguirá uma abordagem incremental, priorizando a análise qualitativa inicial:

1. **Coleta Manual e Filtragem (Crucial):**  
   * Busca ativa no GitHub por projetos que possuam tanto o código de treinamento quanto o de serviço (app).  
   * Identificação de padrões de integração: pastas /models com arquivos .pkl/.h5 vs. arquivos de configuração de API/Docker para model serving (ex: FastAPI, TensorFlow Serving).  
   * Critério de exclusão: Repositórios de tutoriais, "Hello World" de ML e projetos sem uma aplicação consumidora clara.  
2. **Automação da Extração de Métricas**

1\. Coleta dos repositórios via GitHub API.

2\. Recuperação dos arquivos relevantes utilizando a API de conteúdos (Contents API).

3\. Identificação dos diretórios relevantes (código da aplicação vs artefatos de modelo).

4\. Parsing de arquivos Python (.py) utilizando o módulo ast.

5\. Extração de: Imports de bibliotecas, chamadas de funções e uso de frameworks de ML.

6\. Cálculo automático das métricas de acoplamento.

6. Study Design

1\. Rationale e Unidade de Análise

Análise de arquivos específicos para tirar conclusões sobre a arquitetura do projeto.

* **Unidade de Observação:** Arquivos ou módulos responsáveis pela integração do modelo.  
* **Unidade de Análise:** O repositório como um todo.

2\. Data Sources e Seleção de Repositórios

Utilizaremos o GitHub devido à sua volumetria em projetos de ML. A seleção será feita via API do GitHub utilizando strings de busca como: "scikit-learn" AND "FastAPI", "model.pkl" AND "app", e "inference API".

* **Inclusão:** Repositórios com \> 20 estrelas, com README.md em inglês ou português, código de aplicação clara e possuir licença de software livre explicitamente definida .  
* **Exclusão:** Projetos de cursos, tutoriais, repositórios sem código de serviço e forks inativos. A validação será feita por inspeção manual dos primeiros 20 resultados para refinar os filtros.

3\. Estratégia de Amostragem e Aquisição

Dado o volume massivo, utilizaremos Amostragem Intencional (Purposive Sampling). O objetivo não é a totalidade do GitHub, mas uma amostra representativa de dois extremos: projetos experimentais e projetos com foco em produção.

1. **Extração de Metadados:** Primeiro, coletamos metadados (linguagem, estrelas, dependências).  
2. **Tamanho da Amostra:** O tamanho da amostra será definido com base no retorno dos seguintes passos:  
   1. Busca por string no GitHub Search  
   2. Aplicação dos filtros de inclusão  
   3. Seleção de uma amostra sistemática  
   4. Inspeção manual de uma parcela viável

4\. Pré-processamento de Dados

Antes da análise, os dados passarão por:

* **Filtragem de Arquivos:** Artefatos binários (e.g., modelos e datasets) serão identificados e excluídos da análise estrutural, sendo considerados apenas como metadados.. O script de análise irá focar apenas no código-fonte (.py) e arquivos de configuração (Dockerfile, requirements.txt).  
* **Normalização:** Mapeamento de extensões de modelos para categorias (ex: .pkl e .joblib → Scikit-Learn).

5\. Escala de acoplamento

* **Nível 1 (Fraco):** Integração via API/Serviço externo. Nenhuma biblioteca de ML no código da aplicação.  
* **Nível 2 (Médio-Fraco):** Uso de biblioteca de inferência agnóstica   
* **Nível 3 (Médio-Forte):** Carregamento local do modelo com wrappers de isolamento.  
* **Nível 4 (Forte):** A aplicação importa bibliotecas de treinamento e o modelo é carregado no processo principal.

Regra adicional:

* Mesmo em arquiteturas baseadas em API, o acoplamento será considerado forte se:

  1\) houver dependência de bibliotecas específicas de ML para pré-processamento na aplicação

  2\) mudanças no modelo exigirem alterações no código da aplicação.

6\. Procedimento de Anotação Manual

Para classificação do acoplamento, utilizaremos dois anotadores (pesquisador e revisor):

* **Treinamento:** Ambos analisarão 3 repositórios em conjunto para alinhar o que constitui "acoplamento forte".  
* **Codificação:** Cada anotador responderá: "A aplicação importa bibliotecas de treino?", "Existe isolamento por container?", "O modelo é servido via endpoint?".  
* **Concordância:** Discrepâncias serão resolvidas por um terceiro revisor ou por consenso.

7\. Métricas e Medidas

Métricas de Acoplamento:

* **Fan-in:** Número de módulos que dependem do componente de integração.  
* **Fan-out:** Número de dependências externas do componente de integração.  
* **Imports de ML:** Quantidade de bibliotecas de ML importadas no código da aplicação.  
* **Chamadas diretas de ML:** Número de invocações a métodos de frameworks de ML.  
* **Dependência de Serviço:** Número de chamadas HTTP para serviços de inferência. 

	Métricas de Infraestrutura:

* **Ferramentas de versionamento de modelo (e.g., DVC, MLflow).**  
* **Tipo de CI (GitHub Actions)**  
* **Tipo de serving (API, batch, embarcado)** 

Relação com as Questões de Pesquisa:

* RQ1 será respondida por meio da classificação dos padrões de integração identificados.  
* RQ2 será respondida pelas métricas de acoplamento (fan-in, fan-out, imports de ML, chamadas diretas).  
* RQ3 será respondida pela correlação entre métricas de acoplamento e métricas de infraestrutura.

8\. Métodos de Análise

A análise será conduzida de forma descritiva e exploratória:

* Estatística descritiva (distribuição dos níveis de acoplamento).  
* Agrupamento dos repositórios por padrão de integração.  
* Análise de correlação entre métricas de acoplamento e infraestrutura.  
* Comparação qualitativa entre casos representativos.

