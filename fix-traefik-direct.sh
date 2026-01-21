#!/bin/bash

###################################
# Script para Corrigir Traefik
# Resolve erro de API Docker version
# (Versão que lê .env com grep)
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
echo "║   CORREÇÃO DO TRAEFIK                    ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
   print_error "Execute como root: sudo ./fix-traefik-direct.sh"
fi

# Verificar se .env existe
if [[ ! -f ".env" ]]; then
    print_error "Arquivo .env não encontrado!"
fi

# Ler variáveis do .env com grep (evita problemas de sintaxe)
DOMAIN=$(grep -E "^DOMAIN=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
TRAEFIK_ADMIN_HASH=$(grep -E "^TRAEFIK_ADMIN_HASH=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")

if [[ -z "$DOMAIN" ]]; then
    print_error "DOMAIN não encontrado no .env"
fi

echo "🔧 Corrigindo problema de API Docker version..."
echo "📍 Domínio: $DOMAIN"
echo ""

# 1. Remover stack do Traefik
print_info "Removendo stack antiga do Traefik..."
docker stack rm traefik 2>/dev/null || true
sleep 5

# 2. Limpar imagens antigas
print_info "Removendo imagens antigas do Traefik..."
docker image rm traefik:v3.6.1 2>/dev/null || true
docker image rm traefik:v3.2 2>/dev/null || true
docker image rm traefik:3.2.2 2>/dev/null || true
docker image prune -f

# 3. Baixar nova imagem explicitamente
print_info "Baixando Traefik 3.2.2 (compatível com Docker API 1.44+)..."
docker pull traefik:3.2.2

if [[ $? -ne 0 ]]; then
    print_error "Falha ao baixar imagem do Traefik!"
fi

print_success "Imagem Traefik 3.2.2 baixada com sucesso!"

# 4. Exportar variáveis necessárias
export DOMAIN="$DOMAIN"
export TRAEFIK_ADMIN_HASH="$TRAEFIK_ADMIN_HASH"

# 5. Fazer deploy do Traefik
print_info "Fazendo deploy do Traefik..."
docker stack deploy -c traefik/traefik.yaml traefik --resolve-image always

print_success "Deploy iniciado!"
echo ""

# 6. Aguardar serviço subir
print_info "Aguardando Traefik inicializar (30 segundos)..."
sleep 30

# 7. Verificar status
print_info "Verificando status do Traefik..."
docker service ps traefik_traefik --no-trunc

echo ""

# 8. Verificar logs
print_info "Últimas linhas do log (verificando erros)..."
docker service logs traefik_traefik --tail 20

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║      CORREÇÃO CONCLUÍDA!                 ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "🔍 Verificações:"
echo "   1. Não deve haver erro 'client version 1.24' nos logs acima"
echo "   2. Traefik deve estar 'Running'"
echo ""
echo "🌐 Teste os acessos:"
echo "   - https://traefik.$DOMAIN (Dashboard do Traefik)"
echo "   - https://fluxos.$DOMAIN (n8n Editor)"
echo "   - https://webhook.$DOMAIN (n8n Webhook)"
echo ""
echo "📋 Se ainda houver problemas:"
echo "   docker service logs traefik_traefik -f     # Ver logs em tempo real"
echo "   docker service ps traefik_traefik          # Ver status detalhado"
echo "   docker service update --force traefik_traefik  # Forçar restart"
echo ""
print_success "✅ Traefik corrigido para 3.2.2"
