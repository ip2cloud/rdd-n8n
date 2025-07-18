#!/bin/bash

###################################
# Script de Desinstalação Completa
# Remove todos os componentes instalados
###################################

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para imprimir com cor
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Banner
clear
echo "╔══════════════════════════════════════════╗"
echo "║        DESINSTALAÇÃO COMPLETA            ║"
echo "║   Remove Docker Swarm + n8n + Portainer  ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
   print_error "Execute como root: sudo ./uninstall.sh"
   exit 1
fi

# Confirmação
print_warning "ATENÇÃO: Este script irá remover:"
echo "  - Todos os stacks Docker"
echo "  - Todos os volumes (DADOS SERÃO PERDIDOS!)"
echo "  - Todas as redes overlay"
echo "  - Docker Swarm será desativado"
echo "  - Arquivo .env será mantido como backup"
echo ""
read -p "Tem certeza que deseja continuar? (digite 'SIM' para confirmar): " CONFIRM

if [[ "$CONFIRM" != "SIM" ]]; then
    print_error "Desinstalação cancelada"
    exit 1
fi

echo ""
print_warning "Iniciando desinstalação..."
echo ""

# 1. Remover todos os stacks
print_warning "Removendo stacks..."
STACKS=$(docker stack ls --format "{{.Name}}" 2>/dev/null)
if [[ ! -z "$STACKS" ]]; then
    for stack in $STACKS; do
        echo "  Removendo stack: $stack"
        docker stack rm $stack >/dev/null 2>&1
    done
    sleep 10  # Aguarda serviços pararem
    print_success "Stacks removidos"
else
    print_success "Nenhum stack encontrado"
fi

# 2. Sair do Swarm
print_warning "Desativando Docker Swarm..."
docker swarm leave --force >/dev/null 2>&1
print_success "Docker Swarm desativado"

# 3. Parar containers órfãos
print_warning "Parando containers órfãos..."
docker container stop $(docker container ls -aq) >/dev/null 2>&1 || true
docker container rm $(docker container ls -aq) >/dev/null 2>&1 || true
print_success "Containers removidos"

# 4. Remover volumes
print_warning "Removendo volumes..."
echo "  Volume: postgres_data"
docker volume rm postgres_data >/dev/null 2>&1 || true
echo "  Volume: redis_data"
docker volume rm redis_data >/dev/null 2>&1 || true
echo "  Volume: redis_insigth_data"
docker volume rm redis_insigth_data >/dev/null 2>&1 || true
echo "  Volume: portainer_data"
docker volume rm portainer_data >/dev/null 2>&1 || true
echo "  Volume: traefik_certs"
docker volume rm traefik_certs >/dev/null 2>&1 || true
echo "  Volume: pgadmin_data"
docker volume rm pgadmin_data >/dev/null 2>&1 || true
# Remover outros volumes órfãos
docker volume prune -f >/dev/null 2>&1
print_success "Volumes removidos"

# 5. Remover redes
print_warning "Removendo redes..."
echo "  Rede: network_swarm_public"
docker network rm network_swarm_public >/dev/null 2>&1 || true
echo "  Rede: network_swarm_databases"
docker network rm network_swarm_databases >/dev/null 2>&1 || true
# Remover outras redes overlay
docker network prune -f >/dev/null 2>&1
print_success "Redes removidas"

# 6. Limpar imagens não utilizadas (opcional)
read -p "Deseja remover imagens Docker não utilizadas? (y/N): " REMOVE_IMAGES
if [[ "$REMOVE_IMAGES" =~ ^[Yy]$ ]]; then
    print_warning "Removendo imagens não utilizadas..."
    docker image prune -a -f >/dev/null 2>&1
    print_success "Imagens removidas"
fi

# 7. Backup do .env
if [[ -f ".env" ]]; then
    print_warning "Fazendo backup do arquivo .env..."
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
    print_success "Backup salvo como .env.backup.*"
fi

# 8. Limpeza final
print_warning "Limpeza final do sistema..."
docker system prune -f >/dev/null 2>&1
print_success "Sistema limpo"

# Resultado final
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       DESINSTALAÇÃO CONCLUÍDA!           ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "✅ Todos os componentes foram removidos"
echo "📁 Arquivo .env foi mantido como backup"
echo ""
echo "Para reinstalar, execute:"
echo "  sudo ./install-simple.sh"
echo ""

# Verificar status final
echo "Status do Docker:"
docker ps 2>/dev/null || print_warning "Docker pode precisar ser reiniciado"
echo ""
echo "Para verificar se tudo foi removido:"
echo "  docker stack ls"
echo "  docker volume ls"
echo "  docker network ls"