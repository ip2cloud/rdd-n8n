#!/bin/bash

# Script para deploy via API do Portainer

# Configurações
PORTAINER_URL="https://$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1):9443"
ENDPOINT_ID="1"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${YELLOW}→ $1${NC}"; }

echo "╔══════════════════════════════════════════╗"
echo "║       DEPLOY VIA API PORTAINER           ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verificar se .env existe
if [[ ! -f ".env" ]]; then
    print_error "Arquivo .env não encontrado. Execute ./install-simple.sh primeiro"
    exit 1
fi

# Carregar variáveis do .env
source .env

# Verificar se Traefik precisa ser redeployado com novas credenciais
print_info "Verificando Traefik..."
if docker service ls | grep -q traefik_traefik; then
    print_info "Atualizando Traefik com credenciais corretas..."
    export DOMAIN TRAEFIK_ADMIN_HASH
    docker stack deploy -c traefik/traefik.yaml traefik >/dev/null 2>&1
    sleep 5
    print_success "Traefik atualizado"
fi

# Solicitar credenciais do Portainer
read -p "Usuário do Portainer [admin]: " PORTAINER_USER
PORTAINER_USER=${PORTAINER_USER:-admin}

read -s -p "Senha do Portainer: " PORTAINER_PASS
echo ""

# Fazer login e obter token
print_info "Fazendo login no Portainer..."
JWT_TOKEN=$(curl -s -k -X POST "${PORTAINER_URL}/api/auth" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"${PORTAINER_USER}\",
    \"password\": \"${PORTAINER_PASS}\"
  }" | jq -r '.jwt' 2>/dev/null)

if [[ "$JWT_TOKEN" == "null" ]] || [[ -z "$JWT_TOKEN" ]]; then
    print_error "Falha no login. Verifique as credenciais."
    exit 1
fi

print_success "Login realizado com sucesso"

# Função para deploy de stack
deploy_stack() {
    local stack_name="$1"
    local yaml_file="$2"
    local env_vars="$3"
    
    print_info "Deployando stack: $stack_name"
    
    # Ler e escapar o conteúdo YAML
    local yaml_content=$(cat "$yaml_file" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    
    # Fazer deploy
    local response=$(curl -s -k -X POST "${PORTAINER_URL}/api/stacks?type=1&method=string&endpointId=${ENDPOINT_ID}" \
      -H "Authorization: Bearer ${JWT_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"${stack_name}\",
        \"stackFileContent\": \"${yaml_content}\",
        \"env\": ${env_vars}
      }")
    
    if echo "$response" | jq -e '.Id' >/dev/null 2>&1; then
        print_success "Stack $stack_name deployado com sucesso"
    else
        print_error "Falha ao deployar $stack_name"
        echo "Response: $response"
    fi
    
    sleep 2
}

# Deploy PostgreSQL
print_info "=== DEPLOY POSTGRESQL ==="
deploy_stack "postgres" "postgres16/postgres.yaml" "[
  {\"name\": \"POSTGRES_PASSWORD\", \"value\": \"${POSTGRES_PASSWORD}\"}
]"

# Deploy Redis
print_info "=== DEPLOY REDIS ==="
deploy_stack "redis" "redis/redis.yaml" "[]"

# Deploy n8n Editor
print_info "=== DEPLOY N8N EDITOR ==="
deploy_stack "n8n_editor" "n8n/queue/orq_editor.yaml" "[
  {\"name\": \"DOMAIN\", \"value\": \"${DOMAIN}\"},
  {\"name\": \"DATABASE\", \"value\": \"${DATABASE}\"},
  {\"name\": \"DATABASE_PASSWORD\", \"value\": \"${DATABASE_PASSWORD}\"},
  {\"name\": \"N8N_ENCRYPTION_KEY\", \"value\": \"${N8N_ENCRYPTION_KEY}\"},
  {\"name\": \"INITIAL_ADMIN_EMAIL\", \"value\": \"${INITIAL_ADMIN_EMAIL}\"},
  {\"name\": \"INITIAL_ADMIN_PASSWORD\", \"value\": \"${INITIAL_ADMIN_PASSWORD}\"}
]"

# Deploy n8n Webhook
print_info "=== DEPLOY N8N WEBHOOK ==="
deploy_stack "n8n_webhook" "n8n/queue/orq_webhook.yaml" "[
  {\"name\": \"DOMAIN\", \"value\": \"${DOMAIN}\"},
  {\"name\": \"DATABASE\", \"value\": \"${DATABASE}\"},
  {\"name\": \"DATABASE_PASSWORD\", \"value\": \"${DATABASE_PASSWORD}\"},
  {\"name\": \"N8N_ENCRYPTION_KEY\", \"value\": \"${N8N_ENCRYPTION_KEY}\"}
]"

# Deploy n8n Worker
print_info "=== DEPLOY N8N WORKER ==="
deploy_stack "n8n_worker" "n8n/queue/orq_worker.yaml" "[
  {\"name\": \"DOMAIN\", \"value\": \"${DOMAIN}\"},
  {\"name\": \"DATABASE\", \"value\": \"${DATABASE}\"},
  {\"name\": \"DATABASE_PASSWORD\", \"value\": \"${DATABASE_PASSWORD}\"},
  {\"name\": \"N8N_ENCRYPTION_KEY\", \"value\": \"${N8N_ENCRYPTION_KEY}\"}
]"

echo ""
print_success "Deploy completo via API!"
print_info "Acesse o Portainer para verificar: ${PORTAINER_URL}"