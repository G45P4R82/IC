import tree_sitter_python as tspython
from tree_sitter import Language, Parser
import os
import requests
import base64
import time
import pandas as pd

PY_LANGUAGE = Language(tspython.language())
parser = Parser(PY_LANGUAGE)

ML_LIBS = {'sklearn', 'scikit', 'pandas', 'numpy', 'joblib', 'xgboost', 'torch', 'tensorflow', 'keras'}
ML_CALLS = {'predict', 'predict_proba', 'load', 'InferenceSession'}
CLOUD_CALLS = {'post', 'get', 'invoke_endpoint', 'ClientSession', 'request'}
CLOUD_LIBS = {'requests', 'aiohttp', 'boto3', 'httpx'}

def get_github_token():
    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        try:
            token = os.popen("gh auth token").read().strip()
        except:
            pass
    return token

TOKEN = get_github_token()
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Accept": "application/vnd.github.v3+json"} if TOKEN else {}

def github_api_get(url):
    for _ in range(3):
        response = requests.get(url, headers=HEADERS)
        if response.status_code == 200:
            return response.json()
        elif response.status_code == 403:
            time.sleep(5)
        else:
            return None
    return None

def parse_python_file(content):
    metrics = {'fan_out': 0, 'ml_imports': 0, 'cloud_imports': 0, 'ml_calls': 0, 'cloud_calls': 0}
    if not content: return metrics
    
    try:
        tree = parser.parse(bytes(content, "utf8"))
        root_node = tree.root_node
        
        def traverse(node):
            if node.type == 'import_statement' or node.type == 'import_from_statement':
                metrics['fan_out'] += 1
                source_code = node.text.decode('utf8').lower()
                if any(lib in source_code for lib in ML_LIBS): metrics['ml_imports'] += 1
                if any(lib in source_code for lib in CLOUD_LIBS): metrics['cloud_imports'] += 1
            
            elif node.type == 'call':
                call_text = node.text.decode('utf8')
                if any(f".{c}(" in call_text or f" {c}(" in call_text for c in ML_CALLS): metrics['ml_calls'] += 1
                if any(f".{c}(" in call_text for c in CLOUD_CALLS): metrics['cloud_calls'] += 1
            
            for child in node.children: traverse(child)

        traverse(root_node)
    except Exception as e:
        pass
    return metrics

def analyze_repo(repo_full_name):
    print(f"📦 Analisando repositório: {repo_full_name}")
    repo_metrics = {'fan_out': 0, 'ml_imports': 0, 'cloud_imports': 0, 'ml_calls': 0, 'cloud_calls': 0, 'mlops': 'Nenhuma', 'ci': 'Nenhum'}
    
    workflows = github_api_get(f"https://api.github.com/repos/{repo_full_name}/contents/.github/workflows")
    if workflows and isinstance(workflows, list): repo_metrics['ci'] = "GitHub Actions"

    req = github_api_get(f"https://api.github.com/repos/{repo_full_name}/contents/requirements.txt")
    if req and 'content' in req:
        c = base64.b64decode(req['content']).decode('utf-8', errors='ignore').lower()
        if 'mlflow' in c or 'dvc' in c or 'wandb' in c: repo_metrics['mlops'] = "MLflow/DVC"

    repo_info = github_api_get(f"https://api.github.com/repos/{repo_full_name}")
    if not repo_info: return None
    
    default_branch = repo_info.get('default_branch', 'main')
    tree_data = github_api_get(f"https://api.github.com/repos/{repo_full_name}/git/trees/{default_branch}?recursive=1")
    if not tree_data or 'tree' not in tree_data: return None

    target_files = [i for i in tree_data['tree'] if i['type'] == 'blob' and i['path'].endswith('.py') and any(x in i['path'].lower() for x in ['main', 'app', 'api', 'predict', 'inference', 'model', 'server'])]

    for item in target_files[:5]:
        blob_data = github_api_get(item['url'])
        if blob_data and 'content' in blob_data:
            content = base64.b64decode(blob_data['content']).decode('utf-8', errors='ignore')
            m = parse_python_file(content)
            repo_metrics['fan_out'] += m['fan_out']
            repo_metrics['ml_imports'] += m['ml_imports']
            repo_metrics['cloud_imports'] += m['cloud_imports']
            repo_metrics['ml_calls'] += m['ml_calls']
            repo_metrics['cloud_calls'] += m['cloud_calls']
            
    nivel = "Desconhecido"
    if repo_metrics['ml_imports'] > 0 and repo_metrics['ml_calls'] > 0: nivel = "4 (Forte)"
    elif repo_metrics['ml_imports'] > 0: nivel = "3 (Médio-Forte)"
    elif repo_metrics['cloud_calls'] > 0 or repo_metrics['cloud_imports'] > 0: nivel = "1 (Fraco)"
    elif 'onnx' in repo_info.get('description', '').lower() or 'onnx' in repo_full_name.lower(): nivel = "2 (Médio-Fraco)"
    else: nivel = "Inconclusivo"

    return {
        'Repositório': repo_full_name,
        'URL': repo_info.get('html_url'),
        'Nível de Acoplamento': nivel,
        'Fan-out (Imports Totais)': repo_metrics['fan_out'],
        'Imports de ML': repo_metrics['ml_imports'],
        'Chamadas Diretas (ML)': repo_metrics['ml_calls'],
        'Dep. de Serviço (HTTP/Cloud)': repo_metrics['cloud_calls'],
        'Ferramentas Versionamento': repo_metrics['mlops'],
        'Tipo de CI': repo_metrics['ci']
    }

QUERIES = {"Embarcados": "fastapi machine-learning", "ONNX": "fastapi onnx", "Remotos": "fastapi boto3 sagemaker"}
results = []

for cat, query in QUERIES.items():
    print(f"\n🔍 Query: {cat}")
    data = github_api_get(f"https://api.github.com/search/repositories?q={query}+created:>2025-01-01&per_page=2")
    if not data or 'items' not in data: continue
    for item in data['items']:
        metrics = analyze_repo(item['full_name'])
        if metrics:
            results.append(metrics)
            print(f"   📊 {metrics['Repositório']} -> Fan-out: {metrics['Fan-out (Imports Totais)']} | ML: {metrics['Imports de ML']} | Calls: {metrics['Chamadas Diretas (ML)']} | Nível: {metrics['Nível de Acoplamento']}")
        time.sleep(1)

df = pd.DataFrame(results)
if not df.empty:
    df.to_csv("extracao_msr_treesitter.csv", index=False)
    print("\n✅ Concluído! Arquivo: extracao_msr_treesitter.csv")
