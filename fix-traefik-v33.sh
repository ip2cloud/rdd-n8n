#!/bin/bash

###################################
# Script para Corrigir Traefik com v3.3
# Resolve erro de API Docker version
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
echo "║   CORREÇÃO DO TRAEFIK v3.3               ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
   print_error "Execute como root: sudo ./fix-traefik-v33.sh"
fi

# Verificar se .env existe
if [[ ! -f ".env" ]]; then
    print_error "Arquivo .env não encontrado!"
fi

# Ler variáveis do .env com grep
DOMAIN=$(grep -E "^DOMAIN=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
TRAEFIK_ADMIN_HASH=$(grep -E "^TRAEFIK_ADMIN_HASH=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")

if [[ -z "$DOMAIN" ]]; then
    print_error "DOMAIN não encontrado no .env"
fi

echo "🔧 Corrigindo Traefik com versão v3.3..."
echo "📍 Domínio: $DOMAIN"
echo ""

# 1. Remover stack do Traefik
print_info "Removendo stack antiga do Traefik..."
docker stack rm traefik 2>/dev/null || true
sleep 10

# 2. Limpar TODAS as imagens do Traefik
print_info "Removendo TODAS as imagens do Traefik..."
docker image rm $(docker images traefik -q) -f 2>/dev/null || true
docker image prune -af --filter "label=org.opencontainers.image.title=Traefik" 2>/dev/null || true
docker system prune -f

print_success "Imagens antigas removidas!"

# 3. Tentar baixar v3.3
print_info "Tentando baixar Traefik v3.3..."
if docker pull traefik:v3.3 2>/dev/null; then
    TRAEFIK_IMAGE="traefik:v3.3"
    print_success "Traefik v3.3 baixado com sucesso!"
else
    print_info "v3.3 não disponível, tentando 'latest'..."
    if docker pull traefik:latest; then
        TRAEFIK_IMAGE="traefik:latest"
        print_success "Traefik latest baixado com sucesso!"
    else
        print_error "Falha ao baixar imagem do Traefik!"
    fi
fi

# Verificar versão baixada
print_info "Versão baixada:"
docker run --rm $TRAEFIK_IMAGE version

echo ""

# 4. Atualizar traefik.yaml se necessário
if [[ "$TRAEFIK_IMAGE" == "traefik:latest" ]]; then
    print_info "Atualizando traefik.yaml para usar 'latest'..."
    sed -i.bak 's|image: traefik:.*|image: traefik:latest|' traefik/traefik.yaml
fi

# 5. Exportar variáveis necessárias
export DOMAIN="$DOMAIN"
export TRAEFIK_ADMIN_HASH="$TRAEFIK_ADMIN_HASH"

# 6. Fazer deploy do Traefik
print_info "Fazendo deploy do Traefik..."
docker stack deploy -c traefik/traefik.yaml traefik --resolve-image always

print_success "Deploy iniciado!"
echo ""

# 7. Aguardar serviço subir
print_info "Aguardando Traefik inicializar (30 segundos)..."
sleep 30

# 8. Verificar imagem rodando
print_info "Verificando imagem em execução:"
docker service inspect traefik_traefik --format='{{.Spec.TaskTemplate.ContainerSpec.Image}}' | head -1

echo ""

# 9. Verificar status
print_info "Verificando status do Traefik..."
docker service ps traefik_traefik --no-trunc

echo ""

# 10. Verificar logs
print_info "Últimas 50 linhas do log:"
echo ""
docker service logs traefik_traefik --tail 50

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║      CORREÇÃO CONCLUÍDA!                 ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "🔍 Verificações:"
echo "   1. Versão do Traefik deve ser v3.3.x ou superior"
echo "   2. NÃO deve haver erro 'client version 1.24' nos logs"
echo "   3. Deve mostrar 'Configuration loaded from flags'"
echo ""
echo "🌐 Teste os acessos:"
echo "   - https://traefik.$DOMAIN (Dashboard do Traefik)"
echo "   - https://fluxos.$DOMAIN (n8n Editor)"
echo "   - https://webhook.$DOMAIN (n8n Webhook)"
echo ""
echo "📋 Comandos úteis:"
echo "   docker service logs traefik_traefik -f     # Ver logs em tempo real"
echo "   docker service ps traefik_traefik          # Ver status"
echo ""
print_success "✅ Traefik atualizado para $TRAEFIK_IMAGE"
