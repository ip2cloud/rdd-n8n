#!/bin/bash

###################################
# Script de Atualização do Stirling-PDF
# Atualiza a versão do Stirling-PDF
###################################

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Funções
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; exit 1; }
print_info() { echo -e "${YELLOW}→ $1${NC}"; }

# Banner
clear
echo "╔══════════════════════════════════════════╗"
echo "║   ATUALIZAÇÃO DO STIRLING-PDF            ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
   print_error "Execute como root: sudo ./update-stirling.sh"
fi

# Verificar se arquivo existe
if [[ ! -f "stirling/stirling.yaml" ]]; then
    print_error "Arquivo stirling/stirling.yaml não encontrado!"
fi

# Verificar se .env existe
if [[ ! -f ".env" ]]; then
    print_error "Arquivo .env não encontrado! Execute install-simple.sh primeiro."
fi

# Carregar variáveis do .env
source .env

echo "🔍 Buscando versões disponíveis do Stirling-PDF..."
echo ""

# Buscar tags do Docker Hub via API
TAGS=$(curl -s "https://registry.hub.docker.com/v2/repositories/frooodle/s-pdf/tags?page_size=20" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | grep -E "^v|^[0-9]|latest" | sort -Vr)

if [[ -z "$TAGS" ]]; then
    print_error "Não foi possível buscar as versões disponíveis"
fi

# Mostrar versões disponíveis
echo "📦 Versões disponíveis (últimas 20):"
echo ""
echo "$TAGS" | nl -w2 -s'. '
echo ""

# Pegar versão atual
CURRENT_VERSION=$(grep "image: frooodle/s-pdf:" stirling/stirling.yaml | awk -F':' '{print $3}')
print_info "Versão atual instalada: $CURRENT_VERSION"
echo ""

# Perguntar versão desejada
read -p "Digite o número da versão desejada (ou digite manualmente, ex: latest): " VERSION_INPUT

# Se for número, pegar da lista
if [[ "$VERSION_INPUT" =~ ^[0-9]+$ ]]; then
    VERSION=$(echo "$TAGS" | sed -n "${VERSION_INPUT}p")
    if [[ -z "$VERSION" ]]; then
        print_error "Número inválido!"
    fi
else
    VERSION="$VERSION_INPUT"
fi

# Validar versão
if [[ -z "$VERSION" ]]; then
    print_error "Versão inválida!"
fi

print_info "Versão selecionada: $VERSION"
echo ""

# Confirmar atualização
read -p "Confirma atualização para $VERSION? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    print_error "Atualização cancelada pelo usuário"
fi

echo ""
print_info "Iniciando atualização..."
echo ""

# Criar backup do arquivo atual
BACKUP_FILE="stirling/stirling.yaml.bak.$(date +%Y%m%d_%H%M%S)"
cp stirling/stirling.yaml "$BACKUP_FILE"
print_success "Backup criado: $BACKUP_FILE"

# Atualizar versão no YAML
sed -i.tmp "s|image: frooodle/s-pdf:.*|image: frooodle/s-pdf:$VERSION|g" stirling/stirling.yaml
rm -f stirling/stirling.yaml.tmp
print_success "Arquivo atualizado para versão $VERSION"

# Validar se a imagem existe no Docker Hub
print_info "Validando imagem no Docker Hub..."
if docker pull frooodle/s-pdf:$VERSION >/dev/null 2>&1; then
    print_success "Imagem validada e baixada"
else
    print_error "Imagem não encontrada no Docker Hub! Restaurando backup..."
    mv "$BACKUP_FILE" stirling/stirling.yaml
    exit 1
fi

# Exportar variáveis necessárias
export DOMAIN="$DOMAIN"
export STIRLING_ADMIN_USERNAME="$STIRLING_ADMIN_USERNAME"
export STIRLING_ADMIN_PASSWORD="$STIRLING_ADMIN_PASSWORD"

# Redeploy do Stirling-PDF
print_info "Fazendo redeploy do Stirling-PDF..."
docker stack deploy -c stirling/stirling.yaml stirling --resolve-image always

print_success "Redeploy iniciado!"
echo ""

print_info "Aguardando 10 segundos para o serviço reiniciar..."
sleep 10

# Verificar status do serviço
print_info "Verificando status do serviço..."
if docker service ls | grep -q "stirling_stirling-pdf"; then
    docker service ps stirling_stirling-pdf --no-trunc | head -5
    echo ""
    print_success "Serviço atualizado com sucesso!"
else
    print_error "Serviço não encontrado. Verifique os logs."
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║      ATUALIZAÇÃO CONCLUÍDA!              ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "📊 Informações:"
echo "   Versão anterior: $CURRENT_VERSION"
echo "   Versão nova: $VERSION"
echo "   Backup: $BACKUP_FILE"
echo ""
echo "🌐 Acesse: https://stir.$DOMAIN"
echo "   Usuário: $STIRLING_ADMIN_USERNAME"
echo "   Senha: $STIRLING_ADMIN_PASSWORD"
echo ""
echo "📋 Comandos úteis:"
echo "   docker service logs stirling_stirling-pdf        # Ver logs"
echo "   docker service ps stirling_stirling-pdf          # Ver status"
echo "   docker service update --force stirling_stirling-pdf  # Forçar restart"
echo ""
print_success "✅ Stirling-PDF atualizado para $VERSION"
