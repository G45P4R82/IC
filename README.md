# 🏗️ Acoplamento de Modelos de ML como Componentes de Software (MSR)

Este repositório documenta a execução de um estudo experimental da disciplina **MC926B/MO630A - Engenharia de Software Experimental**. O objetivo é analisar a implementação e integração de modelos de Machine Learning (ML) em aplicações de software, focando no nível de **acoplamento** e nas dependências estruturais.

---

## 🔍 Metodologia de Mineração (MSR)

Para garantir a reprodutibilidade do estudo, a extração de dados foi realizada utilizando a [GitHub CLI (`gh`)](https://cli.github.com/) e a **GitHub REST API**, sem a necessidade de clonar os repositórios localmente. 

### 1. Estratégia de Busca e Seleção
Inicialmente, o protocolo previa buscas simples (ex: `"scikit-learn" AND "FastAPI"`). Durante a execução, constatamos que a API do GitHub requer parâmetros mais específicos para evitar repositórios de tutoriais. 

As seguintes *queries* foram executadas para garantir diversidade arquitetural (Amostragem Intencional):

* **Modelos Embarcados (Níveis 3 e 4):**
  ```bash
  gh api "/search/repositories?q=scikit-learn+fastapi+stars:>20&sort=stars&per_page=10"
  gh api "/search/repositories?q=fastapi+machine-learning+app+stars:>20&sort=stars&per_page=10"
  ```
* **Modelos Agnósticos (ONNX - Nível 2):**
  ```bash
  gh api "/search/repositories?q=fastapi+onnx+stars:>20&sort=stars&per_page=5"
  ```
* **Modelos Remotos/Cloud (Nível 1):**
  ```bash
  gh api "/search/repositories?q=fastapi+boto3+sagemaker+stars:>1&sort=stars&per_page=3"
  ```

### 2. Extração de Métricas (Parsing e AST Simulado)

Para cada repositório candidato, desenvolvemos um *script* automatizado que consome a API de conteúdos do GitHub (`repos/{owner}/{repo}/contents/{path}`) para ler o código-fonte e o arquivo `requirements.txt`.

O script realiza as seguintes extrações de evidências:
* **Fan-out (Imports Totais):** Contagem de `import X` e `from X import Y` nos arquivos da API (`main.py`, `app.py`).
* **Imports de ML:** Filtro específico para bibliotecas pesadas (`sklearn`, `pandas`, `numpy`, `joblib`, `torch`, `xgboost`).
* **Chamadas Diretas de ML:** Busca por invocações como `.predict()`, `.predict_proba()` e `joblib.load()`.
* **Dependência de Serviço:** Busca por clientes HTTP (`requests.get`, `aiohttp`, `boto3.invoke_endpoint`).

<details>
<summary>💻 Ver Script de Extração em Bash</summary>

```bash
# Exemplo de extração automatizada para um repositório
repo="Nneji123/Credit-Card-Fraud-Detection"

# 1. Baixar código fonte via API
pyfiles=$(gh api repos/$repo/contents/app.py -q '.content' | base64 -d)
req=$(gh api repos/$repo/contents/requirements.txt -q '.content' | base64 -d)

# 2. Calcular Métricas
fan_out=$(echo "$pyfiles" | grep -E "^import |^from " | wc -l)
ml_imports=$(echo "$pyfiles" | grep -E "^import |^from " | grep -iE "sklearn|pandas|numpy|joblib" | wc -l)
ml_calls=$(echo "$pyfiles" | grep -oE "\.predict\(|\.load\(" | wc -l)

echo "Fan-out: $fan_out | ML Imports: $ml_imports | Chamadas: $ml_calls"
```
</details>

---

## 📊 Dataset e Resultados (Amostra MSR)

Abaixo estão os dados minerados e classificados conforme a escala de acoplamento definida no protocolo. Os dados completos estão disponíveis no arquivo [`amostra_repositorios_ml.csv`](./amostra_repositorios_ml.csv).

| Repositório | Padrão Arquitetural | Nível de Acoplamento | Fan-out | Imports de ML | Chamadas Diretas | Contexto / Evidência no Código |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| [**cwallaceh/sklearn_fastapi_docker**](https://github.com/cwallaceh/sklearn_fastapi_docker) | API Local (Embarcado) | **4 (Forte)** | 8 | 2 | 1 | `ms/__init__.py:8 (joblib.load)` |
| [**zimingttkx/Network-Security-Based-On-ML**](https://github.com/zimingttkx/Network-Security-Based-On-ML) | API Local (Embarcado) | **4 (Forte)** | 31 | 3 | 2 | `app.py:42 (model.predict)` |
| [**Nneji123/Credit-Card-Fraud-Detection**](https://github.com/Nneji123/Credit-Card-Fraud-Detection) | API Local (Embarcado) | **4 (Forte)** | 6 | 2 | 3 | `app.py:4-5 (import joblib, numpy)` |
| [**eightBEC/fastapi-ml-skeleton**](https://github.com/eightBEC/fastapi-ml-skeleton) | Wrapper (Embarcado) | **3 (Médio-Forte)** | 12 | 1 | 1 | Esconde a biblioteca na pasta `sample_model` |
| [**sayakpaul/ml-deployment-k8s-fastapi**](https://github.com/sayakpaul/ml-deployment-k8s-fastapi) | Agnóstico (ONNX) | **2 (Médio-Fraco)**| 14 | 0 | 1 | Usa ONNXRuntime, sem PyTorch. `api/main.py:40` |
| [**991o2o9/smart-cardiologist**](https://github.com/991o2o9/smart-cardiologist) | Facade API (Remoto) | **1 (Fraco)** | 13 | 0 | 0 | Faz post externo. `src/services/ai_service.py:45` |
| [**CharlieSergeant/sagemaker-fastapi**](https://github.com/CharlieSergeant/sagemaker-fastapi) | Proxy AWS (Remoto) | **1 (Fraco)** | 15 | 0 | 0 | Usa `boto3` para invocar AWS SageMaker |

---

## 🎯 Conclusões Arquiteturais da Amostra

As evidências coletadas nas linhas de código dos repositórios validam o "Problema" mapeado no protocolo de pesquisa:

1. **Predominância do Acoplamento Forte:** Na maioria das APIs de ML em código aberto (Nível 4), a aplicação importa as bibliotecas matemáticas pesadas diretamente na rota (`app.py`), misturando lógica de rede com lógica de predição.
2. **O Mito do Docker e CI/CD:** A presença de ferramentas modernas de MLOps (GitHub Actions, Docker) não garante o isolamento do modelo. Projetos com `Dockerfile` continuam sofrendo de alto acoplamento temporal no código Python.
3. **Padrões de Isolamento:** Os padrões de baixo acoplamento identificados dividem-se em duas abordagens:
   * **Nível 2:** Exportação para formatos padronizados de grafo computacional (ONNX), desvinculando a API da biblioteca de treinamento.
   * **Nível 1:** Delegação completa do *runtime* do modelo para a Nuvem (ex: AWS SageMaker via `boto3`), transformando a API local em um mero *Proxy*.