#!/bin/bash

###################################
# Verificar Compatibilidade Docker
###################################

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${YELLOW}→ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

echo "╔══════════════════════════════════════════╗"
echo "║   DIAGNÓSTICO DOCKER                     ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verificar Docker instalado
if ! command -v docker &> /dev/null; then
    print_error "Docker não instalado!"
    exit 1
fi

print_success "Docker instalado"
echo ""

# Verificar versão do Docker
print_info "Docker Engine Version:"
docker version --format 'Client: {{.Client.Version}}\nServer: {{.Server.Version}}'
echo ""

# Verificar API version
print_info "Docker API Version:"
CLIENT_API=$(docker version --format '{{.Client.APIVersion}}')
SERVER_API=$(docker version --format '{{.Server.APIVersion}}')

echo "Client API: $CLIENT_API"
echo "Server API: $SERVER_API"
echo ""

# Verificar se é 1.44 ou superior
API_VERSION_NUM=$(echo $SERVER_API | cut -d'.' -f1-2 | tr -d '.')

if [[ $API_VERSION_NUM -ge 144 ]]; then
    print_success "API Version $SERVER_API é compatível (>= 1.44)"
else
    print_warning "API Version $SERVER_API pode ser incompatível (requer >= 1.44)"
    echo ""
    print_info "Considere atualizar o Docker Engine:"
    echo "  curl -fsSL https://get.docker.com | sh"
fi

echo ""

# Verificar Swarm ativo
print_info "Docker Swarm:"
if docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active"; then
    print_success "Swarm está ativo"
    docker info --format 'Node Role: {{.Swarm.ControlAvailable}}'
else
    print_error "Swarm não está ativo!"
fi

echo ""

# Verificar imagens do Traefik
print_info "Imagens Traefik disponíveis localmente:"
if docker images traefik --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}" | grep -v "REPOSITORY"; then
    echo ""
else
    print_warning "Nenhuma imagem Traefik encontrada"
fi

echo ""

# Verificar serviço Traefik
print_info "Serviço Traefik:"
if docker service ls --format '{{.Name}}' | grep -q "traefik_traefik"; then
    print_success "Serviço traefik_traefik encontrado"
    echo ""
    docker service inspect traefik_traefik --format 'Image: {{.Spec.TaskTemplate.ContainerSpec.Image}}' | head -1
    docker service inspect traefik_traefik --format 'Replicas: {{.Spec.Mode.Replicated.Replicas}}'
else
    print_warning "Serviço traefik_traefik não encontrado"
fi

echo ""

# Informações do sistema
print_info "Sistema:"
uname -a
echo ""

# Verificar espaço em disco
print_info "Espaço em disco:"
df -h / | tail -1

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   RECOMENDAÇÕES                          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

if [[ $API_VERSION_NUM -lt 144 ]]; then
    print_warning "Recomendação: Atualize o Docker Engine para versão >= 25.0"
    echo "  curl -fsSL https://get.docker.com | sh"
    echo ""
fi

if docker images traefik --format '{{.Tag}}' | grep -qE "^(v3.2|3.2)"; then
    print_warning "Versões antigas do Traefik detectadas"
    echo "  Execute: sudo ./fix-traefik-v33.sh"
    echo ""
fi

print_info "Para resolver o problema do Traefik, execute:"
echo "  sudo ./fix-traefik-v33.sh"
echo ""
echo "Ou comandos manuais:"
echo "  docker image rm \$(docker images traefik -q) -f"
echo "  docker pull traefik:v3.3"
echo "  docker service update --image traefik:v3.3 --force traefik_traefik"
