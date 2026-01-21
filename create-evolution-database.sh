#!/bin/bash

###################################
# Script para Criar Banco Evolution API
# Útil se o Evolution API não conseguir conectar
###################################

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; exit 1; }
print_info() { echo -e "${YELLOW}→ $1${NC}"; }

# Banner
clear
echo "╔══════════════════════════════════════════╗"
echo "║   CRIAR BANCO DO EVOLUTION API           ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verificar se .env existe
if [[ ! -f ".env" ]]; then
    print_error "Arquivo .env não encontrado! Execute install-simple.sh primeiro."
fi

# Carregar variáveis do .env
source .env

# Verificar se variável existe
if [[ -z "$EVOLUTION_DATABASE" ]]; then
    print_error "EVOLUTION_DATABASE não definido no .env"
fi

print_info "Nome do banco: $EVOLUTION_DATABASE"
echo ""

# Buscar container do PostgreSQL
print_info "Buscando container do PostgreSQL..."
POSTGRES_CONTAINER=$(docker ps -q -f name=postgres_postgres | head -n1)

if [[ -z "$POSTGRES_CONTAINER" ]]; then
    print_error "Container do PostgreSQL não encontrado! Verifique se está rodando:"
    echo ""
    echo "  docker service ls | grep postgres"
    echo ""
    exit 1
fi

print_success "Container encontrado: $POSTGRES_CONTAINER"
echo ""

# Verificar se banco já existe
print_info "Verificando se banco já existe..."
EXISTS=$(docker exec -i $POSTGRES_CONTAINER psql -U postgres -t -c "SELECT 1 FROM pg_database WHERE datname='${EVOLUTION_DATABASE}';" 2>/dev/null | grep -q 1 && echo "yes" || echo "no")

if [[ "$EXISTS" == "yes" ]]; then
    print_success "Banco ${EVOLUTION_DATABASE} já existe!"
    echo ""
    echo "📊 Informações do banco:"
    docker exec -i $POSTGRES_CONTAINER psql -U postgres -c "\l+ ${EVOLUTION_DATABASE}"
    exit 0
fi

# Criar banco
print_info "Criando banco ${EVOLUTION_DATABASE}..."
docker exec -i $POSTGRES_CONTAINER psql -U postgres -c "CREATE DATABASE ${EVOLUTION_DATABASE};" 2>&1

if [[ $? -eq 0 ]]; then
    print_success "Banco ${EVOLUTION_DATABASE} criado com sucesso!"
    echo ""
    echo "📊 Informações do banco:"
    docker exec -i $POSTGRES_CONTAINER psql -U postgres -c "\l+ ${EVOLUTION_DATABASE}"
    echo ""
    echo "🔄 Reinicie o Evolution API para conectar:"
    echo "  docker service update --force evolution_evolution_v2"
    echo ""
else
    print_error "Falha ao criar banco! Verifique os logs do PostgreSQL."
fi
