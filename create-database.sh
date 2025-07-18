#!/bin/bash

###################################
# Script para Criar Banco n8n Manualmente
# Use apenas se o banco não foi criado automaticamente
###################################

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para imprimir com cor
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${YELLOW}→ $1${NC}"; }

echo "╔══════════════════════════════════════════╗"
echo "║       CRIAÇÃO DO BANCO N8N               ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verificar se arquivo .env existe
if [[ ! -f ".env" ]]; then
    print_error "Arquivo .env não encontrado. Execute ./install-simple.sh primeiro"
    exit 1
fi

# Carregar variáveis
source .env

print_info "Configurações carregadas:"
echo "DATABASE: $DATABASE"
echo "POSTGRES_PASSWORD: $POSTGRES_PASSWORD"
echo ""

# Verificar se PostgreSQL está rodando
if ! docker service ls | grep -q postgres_postgres; then
    print_error "PostgreSQL não está rodando. Execute a instalação primeiro."
    exit 1
fi

print_info "PostgreSQL está rodando. Aguardando container ficar pronto..."
sleep 5

# Obter o container ID do PostgreSQL
CONTAINER_ID=$(docker ps --filter "label=com.docker.swarm.service.name=postgres_postgres" --format "{{.ID}}" | head -n1)

if [[ -z "$CONTAINER_ID" ]]; then
    print_error "Container PostgreSQL não encontrado"
    exit 1
fi

print_info "Container PostgreSQL encontrado: $CONTAINER_ID"

# Criar banco se não existir
print_info "Verificando se banco '$DATABASE' existe..."

# Verificar se banco existe
DB_EXISTS=$(docker exec "$CONTAINER_ID" psql -U postgres -lqt | cut -d \| -f 1 | grep -w "$DATABASE" | wc -l)

if [[ "$DB_EXISTS" -eq 0 ]]; then
    print_info "Criando banco '$DATABASE'..."
    docker exec "$CONTAINER_ID" psql -U postgres -c "CREATE DATABASE $DATABASE;"
    print_success "Banco '$DATABASE' criado com sucesso!"
else
    print_success "Banco '$DATABASE' já existe"
fi

# Verificar novamente
print_info "Verificando bancos disponíveis:"
docker exec "$CONTAINER_ID" psql -U postgres -c "\l"

echo ""
print_success "Processo concluído!"
print_info "Agora você pode redeployar o n8n se necessário"