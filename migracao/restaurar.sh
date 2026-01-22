#!/bin/bash

###############################################################################
#                                                                             #
#              🔄 RESTAURAR VERSÃO ANTERIOR DO N8N                           #
#                                                                             #
#  Este script restaura o backup criado durante a migração                   #
#  Use somente se a nova versão apresentar problemas                         #
#                                                                             #
#  COMO USAR: sudo ./restaurar.sh                                            #
#                                                                             #
###############################################################################

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

clear

echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║                                                            ║${NC}"
echo -e "${YELLOW}║         🔄 RESTAURAR VERSÃO ANTERIOR DO N8N               ║${NC}"
echo -e "${YELLOW}║                                                            ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Este script precisa ser executado como root${NC}"
    echo "   Execute: sudo ./restaurar.sh"
    exit 1
fi

# Procurar último backup
if [ -f "$SCRIPT_DIR/ultimo_backup.txt" ]; then
    BACKUP_DIR=$(cat "$SCRIPT_DIR/ultimo_backup.txt")
    echo -e "${BLUE}📦 Backup encontrado:${NC}"
    echo "   $BACKUP_DIR"
else
    echo -e "${YELLOW}⚠️  Arquivo de referência não encontrado${NC}"
    echo ""
    echo "Backups disponíveis:"
    echo ""
    ls -lt "$SCRIPT_DIR"/backup_* 2>/dev/null | head -5
    echo ""
    read -p "Digite o caminho completo do backup que deseja restaurar: " BACKUP_DIR
fi

# Verificar se backup existe
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}❌ Backup não encontrado: $BACKUP_DIR${NC}"
    exit 1
fi

# Verificar arquivos do backup
if [ ! -f "$BACKUP_DIR/orq_editor.yaml" ] || [ ! -f "$BACKUP_DIR/database.sql" ]; then
    echo -e "${RED}❌ Backup incompleto ou corrompido${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}⚠️  ATENÇÃO:${NC}"
echo ""
echo "  • Isso irá restaurar o n8n para a versão anterior"
echo "  • Mudanças feitas após a migração serão perdidas"
echo "  • O processo leva ~3 minutos"
echo ""
read -p "Tem certeza que deseja restaurar? Digite SIM: " CONFIRMAR

if [ "$CONFIRMAR" != "SIM" ]; then
    echo ""
    echo -e "${YELLOW}❌ Restauração cancelada${NC}"
    exit 0
fi

cd "$PROJECT_DIR" || exit 1

# Carregar variáveis
source .env

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              🔄 Iniciando Restauração                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Restaurar arquivos YAML
echo -e "${BLUE}[1/4] 📋 Restaurando arquivos de configuração...${NC}"
cp "$BACKUP_DIR/orq_editor.yaml" n8n/queue/orq_editor.yaml
cp "$BACKUP_DIR/orq_webhook.yaml" n8n/queue/orq_webhook.yaml
cp "$BACKUP_DIR/orq_worker.yaml" n8n/queue/orq_worker.yaml
echo -e "${GREEN}      ✅ Arquivos restaurados${NC}"
echo ""

# 2. Parar serviços
echo -e "${BLUE}[2/4] ⏸️  Parando serviços n8n...${NC}"
docker service scale n8n_editor_ip2=0 >/dev/null 2>&1 || true
docker service scale n8n_webhook_ip2=0 >/dev/null 2>&1 || true
docker service scale n8n_worker_ip2=0 >/dev/null 2>&1 || true
sleep 10
echo -e "${GREEN}      ✅ Serviços parados${NC}"
echo ""

# 3. Restaurar banco de dados
echo -e "${BLUE}[3/4] 💾 Restaurando banco de dados...${NC}"
echo -e "${YELLOW}      ⏳ Aguarde, isso pode levar alguns minutos...${NC}"

POSTGRES_CONTAINER=$(docker ps -qf name=postgres | head -1)

if [ -z "$POSTGRES_CONTAINER" ]; then
    echo -e "${RED}❌ Container PostgreSQL não encontrado${NC}"
    exit 1
fi

if docker exec -i "$POSTGRES_CONTAINER" psql -U postgres -d "$DATABASE" < "$BACKUP_DIR/database.sql" >/dev/null 2>&1; then
    echo -e "${GREEN}      ✅ Banco de dados restaurado${NC}"
else
    echo -e "${RED}❌ Falha ao restaurar banco de dados${NC}"
    exit 1
fi

echo ""

# 4. Reiniciar serviços
echo -e "${BLUE}[4/4] 🚀 Reiniciando serviços...${NC}"

export DOMAIN DATABASE DATABASE_PASSWORD N8N_ENCRYPTION_KEY INITIAL_ADMIN_EMAIL INITIAL_ADMIN_PASSWORD

echo "      • Editor..."
docker stack deploy -c n8n/queue/orq_editor.yaml n8n_editor >/dev/null 2>&1
sleep 30

echo "      • Webhook..."
docker stack deploy -c n8n/queue/orq_webhook.yaml n8n_webhook >/dev/null 2>&1
sleep 15

echo "      • Worker..."
docker stack deploy -c n8n/queue/orq_worker.yaml n8n_worker >/dev/null 2>&1
sleep 15

echo -e "${GREEN}      ✅ Serviços reiniciados${NC}"
echo ""

# Verificar status
echo -e "${BLUE}📊 Status dos serviços:${NC}"
echo ""
docker service ls | grep -E "NAME|n8n"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║              ✅ RESTAURAÇÃO CONCLUÍDA!                     ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ Seu n8n foi restaurado para a versão anterior${NC}"
echo ""
echo "🌐 Acesse: https://fluxos.${DOMAIN}"
echo ""
echo "⏳ Aguarde ~2 minutos para os serviços iniciarem completamente"
echo ""
