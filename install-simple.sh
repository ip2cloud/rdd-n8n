#!/bin/bash

###################################
# Script de Instalação Simplificado
# Docker Swarm + PostgreSQL + Redis + n8n
###################################

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para imprimir com cor
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; exit 1; }
print_info() { echo -e "${YELLOW}→ $1${NC}"; }

# Banner
clear
echo "╔══════════════════════════════════════════╗"
echo "║     INSTALAÇÃO AUTOMÁTICA DO N8N         ║"
echo "║     Docker + PostgreSQL + Redis          ║"
echo "╔══════════════════════════════════════════╝"
echo ""

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
   print_error "Execute como root: sudo ./install-simple.sh"
fi

# Verificar sistema
if [[ ! -f /etc/debian_version ]]; then
    print_error "Sistema não suportado. Use Debian/Ubuntu."
fi

# Obter IP do servidor
SERVER_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
if [[ -z "$SERVER_IP" ]]; then
    read -p "Digite o IP deste servidor: " SERVER_IP
fi

# Coletar informações mínimas
echo ""
print_info "Configuração rápida (pressione ENTER para usar valores padrão)"
echo ""

read -p "Email do administrador do n8n: " INITIAL_ADMIN_EMAIL
while [[ -z "$INITIAL_ADMIN_EMAIL" ]]; do
    print_error "Email do administrador é obrigatório!"
    read -p "Email do administrador do n8n: " INITIAL_ADMIN_EMAIL
done

read -p "Domínio principal (ex: exemplo.com): " DOMAIN
while [[ -z "$DOMAIN" ]]; do
    print_error "Domínio é obrigatório!"
    read -p "Domínio principal (ex: exemplo.com): " DOMAIN
done

read -p "Nome do banco de dados [n8n]: " DATABASE
DATABASE=${DATABASE:-n8n}

read -p "Senha do PostgreSQL [auto-gerar]: " DB_PASSWORD
if [[ -z "$DB_PASSWORD" ]]; then
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-16)
    print_info "Senha gerada: $DB_PASSWORD"
fi

# Gerar senha inicial para o admin do n8n
INITIAL_ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/")
print_info "Senha admin n8n gerada: $INITIAL_ADMIN_PASSWORD"

# Gerar encryption key
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# Começar instalação
echo ""
print_info "Iniciando instalação..."
echo ""

# 1. Atualizar sistema
print_info "Atualizando sistema..."
apt-get update -qq >/dev/null 2>&1
apt-get install -y curl wget nano htop >/dev/null 2>&1
print_success "Sistema atualizado"

# 2. Instalar Docker
if ! command -v docker >/dev/null 2>&1; then
    print_info "Instalando Docker..."
    curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
    systemctl enable docker >/dev/null 2>&1
    systemctl start docker >/dev/null 2>&1
    print_success "Docker instalado"
else
    print_success "Docker já instalado"
fi

# 3. Inicializar Swarm
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    print_info "Inicializando Docker Swarm..."
    docker swarm init --advertise-addr=$SERVER_IP >/dev/null 2>&1
    print_success "Swarm inicializado"
else
    print_success "Swarm já ativo"
fi

# 4. Criar redes
print_info "Criando redes..."
docker network create --driver=overlay network_swarm_public >/dev/null 2>&1 || true
docker network create --driver=overlay network_swarm_databases >/dev/null 2>&1 || true
print_success "Redes criadas"

# 5. Criar volumes
print_info "Criando volumes..."
docker volume create postgres_data >/dev/null 2>&1 || true
docker volume create redis_data >/dev/null 2>&1 || true
docker volume create traefik_certs >/dev/null 2>&1 || true
docker volume create portainer_data >/dev/null 2>&1 || true
print_success "Volumes criados"

# 6. Criar arquivo .env
print_info "Salvando configurações..."
cat > .env << EOF
# Configurações do n8n
DOMAIN=$DOMAIN
DATABASE=$DATABASE
DATABASE_PASSWORD=$DB_PASSWORD
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
POSTGRES_PASSWORD=$DB_PASSWORD
INITIAL_ADMIN_EMAIL=$INITIAL_ADMIN_EMAIL
INITIAL_ADMIN_PASSWORD=$INITIAL_ADMIN_PASSWORD

# URLs finais
EDITOR_URL=https://fluxos.$DOMAIN
WEBHOOK_URL=https://webhook.$DOMAIN
EOF
print_success "Configurações salvas em .env"

# 7. Deploy Portainer
print_info "Instalando Portainer..."
docker pull portainer/portainer-ce:sts >/dev/null 2>&1
docker stack deploy -c portainer/portainer.yaml portainer >/dev/null 2>&1
sleep 5
print_success "Portainer instalado"

# 8. Deploy Traefik
print_info "Instalando Traefik..."
export DOMAIN
docker stack deploy -c traefik/traefik.yaml traefik >/dev/null 2>&1
sleep 5
print_success "Traefik instalado"

# 9. Deploy automático das aplicações
read -p "Deseja instalar automaticamente PostgreSQL + Redis + n8n? (Y/n): " AUTO_DEPLOY
if [[ ! "$AUTO_DEPLOY" =~ ^[Nn]$ ]]; then
    print_info "Deployando aplicações automaticamente..."
    
    # Deploy PostgreSQL
    print_info "Instalando PostgreSQL..."
    export POSTGRES_PASSWORD=$DB_PASSWORD
    docker stack deploy -c postgres16/postgres.yaml postgres >/dev/null 2>&1
    sleep 10
    print_success "PostgreSQL instalado"
    
    # Deploy Redis
    print_info "Instalando Redis..."
    docker stack deploy -c redis/redis.yaml redis >/dev/null 2>&1
    sleep 5
    print_success "Redis instalado"
    
    # Deploy n8n
    print_info "Instalando n8n (modo queue)..."
    export DOMAIN DATABASE DATABASE_PASSWORD N8N_ENCRYPTION_KEY INITIAL_ADMIN_EMAIL INITIAL_ADMIN_PASSWORD
    docker stack deploy -c n8n/queue/orq_editor.yaml n8n_editor >/dev/null 2>&1
    docker stack deploy -c n8n/queue/orq_webhook.yaml n8n_webhook >/dev/null 2>&1
    docker stack deploy -c n8n/queue/orq_worker.yaml n8n_worker >/dev/null 2>&1
    print_success "n8n instalado"
    
    AUTO_DEPLOYED=true
else
    AUTO_DEPLOYED=false
fi

# 9. Instalar ctop (opcional)
if ! command -v docker-ctop >/dev/null 2>&1; then
    print_info "Instalando ctop..."
    curl -fsSL https://azlux.fr/repo.gpg.key | gpg --dearmor -o /usr/share/keyrings/azlux-archive-keyring.gpg >/dev/null 2>&1
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/azlux-archive-keyring.gpg] http://packages.azlux.fr/debian $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/azlux.list >/dev/null
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y docker-ctop >/dev/null 2>&1
    print_success "ctop instalado"
fi

# Resultado final
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         INSTALAÇÃO CONCLUÍDA!            ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "📌 INFORMAÇÕES IMPORTANTES:"
echo ""
echo "🎛️ Portainer (Gerenciador Docker):"
echo "   URL: https://$SERVER_IP:9443"
echo "   ⚠️  Acesso inicial: Defina senha de admin na primeira vez!"
echo ""

if [[ "$AUTO_DEPLOYED" == "true" ]]; then
    echo "✅ APLICAÇÕES INSTALADAS AUTOMATICAMENTE:"
    echo "   PostgreSQL + Redis + n8n (modo queue)"
    echo ""
    echo "🌐 URLs do n8n:"
    echo "   Editor: https://fluxos.$DOMAIN"
    echo "   Webhook: https://webhook.$DOMAIN"
    echo ""
    echo "🔑 Credenciais do n8n:"
    echo "   Email: $INITIAL_ADMIN_EMAIL"
    echo "   Senha: $INITIAL_ADMIN_PASSWORD"
    echo ""
    echo "🚀 PRÓXIMOS PASSOS:"
    echo ""
    echo "1️⃣ CONFIGURE O DNS:"
    echo "   fluxos.$DOMAIN → $SERVER_IP"
    echo "   webhook.$DOMAIN → $SERVER_IP"
    echo ""
    echo "2️⃣ AGUARDE ~2 MINUTOS e acesse:"
    echo "   https://fluxos.$DOMAIN"
    echo ""
    echo "3️⃣ MONITORE NO PORTAINER:"
    echo "   https://$SERVER_IP:9443"
    echo "   Verifique se todos os serviços estão rodando"
else
    echo "🔧 DEPLOY MANUAL NECESSÁRIO:"
    echo "   Use: ./deploy-api.sh (após configurar Portainer)"
    echo ""
    echo "🌐 URLs futuras do n8n:"
    echo "   Editor: https://fluxos.$DOMAIN"
    echo "   Webhook: https://webhook.$DOMAIN"
    echo ""
    echo "🚀 PRÓXIMOS PASSOS:"
    echo ""
    echo "1️⃣ ACESSE O PORTAINER:"
    echo "   https://$SERVER_IP:9443"
    echo "   - Crie a senha do admin"
    echo "   - Conecte ao ambiente local"
    echo ""
    echo "2️⃣ CONFIGURE O DNS:"
    echo "   fluxos.$DOMAIN → $SERVER_IP"
    echo "   webhook.$DOMAIN → $SERVER_IP"
    echo ""
    echo "3️⃣ DEPLOY VIA API:"
    echo "   ./deploy-api.sh"
    echo "   (Script automatizado para deploy via API do Portainer)"
fi

echo ""
echo "🔑 Todas as credenciais estão salvas em: .env"
echo "   PostgreSQL: postgres / $DB_PASSWORD"
echo "   Banco: $DATABASE"
echo ""
echo "📊 Comandos úteis:"
echo "   docker stack ls              # Ver stacks"
echo "   docker service ls            # Ver serviços"
echo "   docker-ctop                  # Monitor"
echo "   docker service logs <nome>   # Ver logs"
echo "   ./debug.sh                   # Diagnóstico completo"
echo ""
echo "✅ Instalação concluída em $(date)"