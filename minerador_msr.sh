#!/bin/bash

# ==============================================================================
# Agente MSR (Mining Software Repositories) - MC926B/MO630A
# Extração de métricas de acoplamento de modelos ML usando a CLI do GitHub (gh)
# ==============================================================================

# Validação de dependências
if ! command -v gh &> /dev/null; then
    echo "Erro: GitHub CLI (gh) não está instalada."
    exit 1
fi
if ! command -v jq &> /dev/null; then
    echo "Erro: jq não está instalado."
    exit 1
fi

CSV_FILE="extracao_automatizada_msr.csv"

# Inicializa o CSV com cabeçalhos
echo "Repositório,URL,Nível de Acoplamento Estimado,Fan-out (Imports Totais),Imports de ML,Chamadas Diretas (ML),Dep. de Serviço (HTTP/Cloud),Ferramentas Versionamento,Tipo de CI" > "$CSV_FILE"

# ==============================================================================
# Fase 1: Definição das Queries (Amostra Focada de 5 repositórios no total)
# ==============================================================================
declare -A QUERIES=(
    ["Modelos Embarcados (Níveis 3/4)"]="fastapi machine-learning"
    ["Agnósticos (ONNX - Nível 2)"]="fastapi onnx"
    ["Serviços Remotos (Nível 1)"]="fastapi boto3 sagemaker"
)

# Palavras-chave para as métricas via Regex/Grep
ML_LIBS="sklearn|scikit|pandas|numpy|joblib|xgboost|torch|tensorflow|keras"
ML_CALLS="\.predict\(|\.predict_proba\(|\.load\("
CLOUD_CALLS="requests\.post|requests\.get|aiohttp|boto3|httpx"

echo "🚀 Iniciando Agente MSR. Alvo: 5 repositórios de alta relevância..."

# Contador para limitar a 5 repositórios no total do script
TOTAL_ANALISADO=0
LIMITE_TOTAL=5

# ==============================================================================
# Fase 2: Mineração e Extração
# ==============================================================================
for CATEGORIA in "${!QUERIES[@]}"; do
    QUERY="${QUERIES[$CATEGORIA]}"
    
    if [ "$TOTAL_ANALISADO" -ge "$LIMITE_TOTAL" ]; then
        break
    fi

    echo "============================================================"
    echo "🔍 Executando Query: $CATEGORIA"
    echo "   $QUERY"
    
    # Busca repositórios (pegando apenas 2 por categoria para dar variedade)
    # Convertendo espaços da query para url encoding simples usando sed
    QUERY_ENC=$(echo "$QUERY" | sed 's/ /+/g')
    REPOS=$(curl -s "https://api.github.com/search/repositories?q=${QUERY_ENC}&per_page=2" -H "Authorization: Bearer $(gh auth token)" | jq -r '.items[] | .full_name')

    for REPO in $REPOS; do
        if [ "$TOTAL_ANALISADO" -ge "$LIMITE_TOTAL" ]; then
            break
        fi

        echo "------------------------------------------------------------"
        echo "📦 Analisando Repositório ($((TOTAL_ANALISADO+1))/$LIMITE_TOTAL): $REPO"
        
        # Faz uma pausa curta para não estourar os Rate Limits da API
        sleep 1

        # ---------------------------------------------------------
        # A. Busca de Arquivos Principais da API (Parsing Superficial)
        # ---------------------------------------------------------
        # Vamos tentar baixar os arquivos mais comuns de entrada FastAPI
        PY_CONTENT=""
        for FILE in "main.py" "app.py" "src/main.py" "api/main.py" "app/main.py" "app/api/endpoints/inference.py" "fastapi_skeleton/main.py" "src/api/main.py"; do
            RAW_CONTENT=$(gh api repos/"$REPO"/contents/"$FILE" -q '.content' 2>/dev/null)
            if [ -n "$RAW_CONTENT" ] && [ "$RAW_CONTENT" != "null" ]; then
                DECODED=$(echo "$RAW_CONTENT" | base64 -d 2>/dev/null)
                if [ -n "$DECODED" ]; then
                    echo "   📄 Encontrado: $FILE"
                    PY_CONTENT="$PY_CONTENT\n$DECODED"
                fi
            fi
        done

        # ---------------------------------------------------------
        # B. Extração de Métricas (Regex)
        # ---------------------------------------------------------
        # Fan-out: Contagem de imports únicos
        FAN_OUT=$(echo -e "$PY_CONTENT" | grep -E "^import |^from " | wc -l)
        
        # Imports de ML
        IMPORTS_ML=$(echo -e "$PY_CONTENT" | grep -E "^import |^from " | grep -iE "$ML_LIBS" | wc -l)
        
        # Chamadas Diretas
        CHAMADAS_DIRETAS=$(echo -e "$PY_CONTENT" | grep -oE "$ML_CALLS" | wc -l)
        
        # Dependências de Serviço (Remoto)
        DEP_SERVICO=$(echo -e "$PY_CONTENT" | grep -oE "$CLOUD_CALLS" | wc -l)

        # ---------------------------------------------------------
        # C. Análise de MLOps e Infraestrutura
        # ---------------------------------------------------------
        VERSIONAMENTO="Nenhuma"
        REQ_CONTENT=$(gh api repos/"$REPO"/contents/requirements.txt -q '.content' 2>/dev/null | base64 -d 2>/dev/null)
        if echo "$REQ_CONTENT" | grep -qiE "mlflow|dvc|wandb"; then
            VERSIONAMENTO="MLflow/DVC"
        fi

        TIPO_CI="Nenhum"
        if gh api repos/"$REPO"/contents/.github/workflows > /dev/null 2>&1; then
            TIPO_CI="GitHub Actions"
        fi

        # ---------------------------------------------------------
        # D. Heurística de Classificação (Nível de Acoplamento)
        # ---------------------------------------------------------
        NIVEL="Desconhecido"
        if [ "$IMPORTS_ML" -gt 0 ] && [ "$CHAMADAS_DIRETAS" -gt 0 ]; then
            NIVEL="4 (Forte)"
        elif [ "$IMPORTS_ML" -gt 0 ] && [ "$CHAMADAS_DIRETAS" -eq 0 ]; then
            NIVEL="3 (Médio-Forte)"
        elif echo -e "$PY_CONTENT" | grep -qiE "onnx|triton"; then
            NIVEL="2 (Médio-Fraco)"
        elif [ "$IMPORTS_ML" -eq 0 ] && [ "$DEP_SERVICO" -gt 0 ]; then
            NIVEL="1 (Fraco)"
        else
            NIVEL="Inconclusivo (Baixo volume de código analisado)"
        fi

        echo "   📊 Métricas -> Fan-out: $FAN_OUT | ML Imports: $IMPORTS_ML | ML Calls: $CHAMADAS_DIRETAS | Nível: $NIVEL"

        # ---------------------------------------------------------
        # E. Exportação para CSV
        # ---------------------------------------------------------
        URL="https://github.com/$REPO"
        echo "$REPO,$URL,$NIVEL,$FAN_OUT,$IMPORTS_ML,$CHAMADAS_DIRETAS,$DEP_SERVICO,$VERSIONAMENTO,$TIPO_CI" >> "$CSV_FILE"

        TOTAL_ANALISADO=$((TOTAL_ANALISADO + 1))
    done
done

echo "============================================================"
echo "✅ Extração concluída! Resultados salvos em: $CSV_FILE"
echo "============================================================"
