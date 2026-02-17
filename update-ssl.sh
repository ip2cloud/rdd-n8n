#!/bin/bash

###################################
# Script para Atualizar SSL/TLS
# Adiciona Let's Encrypt ao Traefik
###################################

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; exit 1; }
print_info() { echo -e "${YELLOW}→ $1${NC}"; }

echo "╔══════════════════════════════════════════╗"
echo "║       ATUALIZAÇÃO SSL/TLS LET'S ENCRYPT  ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verificar se .env existe
if [[ ! -f ".env" ]]; then
    print_error "Arquivo .env não encontrado. Execute ./install-simple.sh primeiro"
fi

# Carregar variáveis
source .env

print_info "Carregando configurações do .env..."
print_success "Domínio: $DOMAIN"

# Redeployar Traefik com configuração SSL
print_info "Atualizando Traefik com Let's Encrypt..."
export DOMAIN TRAEFIK_ADMIN_HASH
docker stack deploy -c traefik/traefik.yaml traefik
sleep 10
print_success "Traefik atualizado"

# Redeployar n8n Editor
print_info "Atualizando n8n Editor com SSL..."
export DOMAIN DATABASE DATABASE_PASSWORD N8N_ENCRYPTION_KEY INITIAL_ADMIN_EMAIL INITIAL_ADMIN_PASSWORD
docker stack deploy -c n8n/queue/orq_editor.yaml n8n_editor
sleep 5
print_success "n8n Editor atualizado"

# Redeployar n8n Webhook  
print_info "Atualizando n8n Webhook com SSL..."
docker stack deploy -c n8n/queue/orq_webhook.yaml n8n_webhook
sleep 5
print_success "n8n Webhook atualizado"

echo ""
print_success "Atualização SSL concluída!"
echo ""
echo "🔐 CERTIFICADOS LET'S ENCRYPT:"
echo "   • Aguarde ~2 minutos para emissão"
echo "   • Verifique em: https://fluxos.$DOMAIN"
echo "   • Verifique em: https://webhook.$DOMAIN"
echo "   • Verifique em: https://traefik.$DOMAIN"
echo ""
print_info "Monitorar logs: docker service logs traefik_traefik"
echo ""
echo "✅ Let's Encrypt configurado com sucesso!"