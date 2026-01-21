#!/bin/bash

###################################
# Script de Atualização do Chatwoot
# Atualiza a versão do Chatwoot
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
echo "║   ATUALIZAÇÃO DO CHATWOOT                ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
   print_error "Execute como root: sudo ./update-chatwoot.sh"
fi

# Verificar se arquivo existe
if [[ ! -f "chatwoot/chatwoot.yaml" ]]; then
    print_error "Arquivo chatwoot/chatwoot.yaml não encontrado!"
fi

# Verificar se .env existe
if [[ ! -f ".env" ]]; then
    print_error "Arquivo .env não encontrado! Execute install-simple.sh primeiro."
fi

# Carregar variáveis do .env
source .env

echo "🔍 Buscando versões disponíveis do Chatwoot..."
echo ""

# Buscar tags do Docker Hub via API
TAGS=$(curl -s "https://registry.hub.docker.com/v2/repositories/chatwoot/chatwoot/tags?page_size=30" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | grep -E "^v[0-9]" | grep -E "\-ce$" | sort -Vr)

if [[ -z "$TAGS" ]]; then
    print_error "Não foi possível buscar as versões disponíveis"
fi

# Mostrar versões disponíveis
echo "📦 Versões disponíveis (últimas 30 CE - Community Edition):"
echo ""
echo "$TAGS" | nl -w2 -s'. '
echo ""

# Pegar versão atual
CURRENT_VERSION=$(grep "image: chatwoot/chatwoot:" chatwoot/chatwoot.yaml | head -1 | awk -F':' '{print $3}' | tr -d ' ')
print_info "Versão atual instalada: $CURRENT_VERSION"
echo ""

# Perguntar versão desejada
read -p "Digite o número da versão desejada (ou digite manualmente, ex: v4.0.2-ce): " VERSION_INPUT

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
BACKUP_FILE="chatwoot/chatwoot.yaml.bak.$(date +%Y%m%d_%H%M%S)"
cp chatwoot/chatwoot.yaml "$BACKUP_FILE"
print_success "Backup criado: $BACKUP_FILE"

# Atualizar versão no YAML (todas as 3 ocorrências: admin, api, sidekiq)
sed -i.tmp "s|image: chatwoot/chatwoot:.*|image: chatwoot/chatwoot:$VERSION|g" chatwoot/chatwoot.yaml
rm -f chatwoot/chatwoot.yaml.tmp
print_success "Arquivo atualizado para versão $VERSION"

# Validar se a imagem existe no Docker Hub
print_info "Validando imagem no Docker Hub..."
if docker pull chatwoot/chatwoot:$VERSION >/dev/null 2>&1; then
    print_success "Imagem validada e baixada"
else
    print_error "Imagem não encontrada no Docker Hub! Restaurando backup..."
    mv "$BACKUP_FILE" chatwoot/chatwoot.yaml
    exit 1
fi

# Exportar variáveis necessárias
export DOMAIN="$DOMAIN"
export POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
export CHATWOOT_SECRET_KEY_BASE="$CHATWOOT_SECRET_KEY_BASE"
export CHATWOOT_DATABASE="$CHATWOOT_DATABASE"
export CHATWOOT_FRONTEND_URL="$CHATWOOT_FRONTEND_URL"
export CHATWOOT_API_URL="$CHATWOOT_API_URL"
export CHATWOOT_STORAGE_SERVICE="$CHATWOOT_STORAGE_SERVICE"
export CHATWOOT_MAILER_SENDER_EMAIL="$CHATWOOT_MAILER_SENDER_EMAIL"
export CHATWOOT_SMTP_ADDRESS="$CHATWOOT_SMTP_ADDRESS"
export CHATWOOT_SMTP_DOMAIN="$CHATWOOT_SMTP_DOMAIN"
export CHATWOOT_SMTP_USERNAME="$CHATWOOT_SMTP_USERNAME"
export CHATWOOT_SMTP_PASSWORD="$CHATWOOT_SMTP_PASSWORD"

# Redeploy do Chatwoot
print_info "Fazendo redeploy do Chatwoot..."
docker stack deploy -c chatwoot/chatwoot.yaml chatwoot --resolve-image always

print_success "Redeploy iniciado!"
echo ""

print_info "Aguardando 15 segundos para os serviços reiniciarem..."
sleep 15

# Verificar status dos serviços
print_info "Verificando status dos serviços..."
if docker service ls | grep -q "chatwoot"; then
    docker service ls | grep chatwoot
    echo ""
    print_success "Serviços atualizados com sucesso!"
else
    print_error "Serviços não encontrados. Verifique os logs."
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
echo "🌐 Acesse:"
echo "   Admin: https://chat.$DOMAIN"
echo "   API: https://chat-api.$DOMAIN"
echo ""
echo "📋 Comandos úteis:"
echo "   docker service logs chatwoot_chatwoot_admin       # Ver logs admin"
echo "   docker service logs chatwoot_chatwoot_api         # Ver logs api"
echo "   docker service logs chatwoot_chatwoot_sidekiq     # Ver logs sidekiq"
echo "   docker service ps chatwoot_chatwoot_admin         # Ver status admin"
echo "   docker service update --force chatwoot_chatwoot_admin  # Forçar restart admin"
echo ""
echo "💡 Setup inicial (após primeira instalação):"
echo "   docker exec -it \$(docker ps -q -f name=chatwoot_admin) bundle exec rails db:chatwoot_prepare"
echo ""
print_success "✅ Chatwoot atualizado para $VERSION"
