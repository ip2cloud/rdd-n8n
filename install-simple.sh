#!/bin/bash

###################################
# Script de Instalação Simplificado
# Docker Swarm + PostgreSQL + Redis + n8n
###################################

set -e

# Função que SEMPRE executa no final
show_final_info() {
    local domain="$1"
    local server_ip="$2" 
    local admin_email="$3"
    local admin_password="$4"
    local pgadmin_password="$5"
    local traefik_password="$6"
    local db_password="$7"
    
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║           INFORMAÇÕES FINAIS             ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "🌐 URLs DOS SERVIÇOS:"
    echo "   n8n Editor: https://fluxos.$domain"
    echo "   n8n Webhook: https://webhook.$domain" 
    echo "   pgAdmin: http://$server_ip:4040"
    echo "   Portainer: https://$server_ip:9443"
    echo "   Traefik: https://traefik.$domain"
    echo ""
    echo "🔑 CREDENCIAIS:"
    echo "   n8n: $admin_email / $admin_password"
    echo "   pgAdmin: $admin_email / $pgadmin_password"
    echo "   Traefik: admin / $traefik_password"
    echo "   PostgreSQL: postgres / $db_password"
    echo ""
    echo "🚨 URGENTE: PORTAINER (10 MINUTOS!)"
    echo "   https://$server_ip:9443"
    echo ""
    echo "📋 PRÓXIMOS PASSOS:"
    echo "1. Acesse Portainer: https://$server_ip:9443" 
    echo "2. Configure DNS: fluxos.$domain → $server_ip"
    echo "3. Configure DNS: webhook.$domain → $server_ip"
    echo "4. Acesse n8n: https://fluxos.$domain"
    echo ""
    print_error "📸 SALVE ESTE PRINT EM LOCAL SEGURO!"
    echo ""
}

# Trap para executar sempre, mesmo se der erro
trap 'show_final_info "$DOMAIN" "$SERVER_IP" "$INITIAL_ADMIN_EMAIL" "$INITIAL_ADMIN_PASSWORD" "$PGADMIN_ADMIN_PASSWORD" "$TRAEFIK_ADMIN_PASSWORD" "$DB_PASSWORD"' EXIT

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
echo "║           Versão FINAL v4                ║"
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

echo ""
print_info "🔐 Segurança das Credenciais"
echo ""

# Verificar se SMTP está configurado
SMTP_CONFIG_FILE="/etc/n8n-installer/smtp.conf"
if [[ -f "$SMTP_CONFIG_FILE" ]]; then
    print_success "SMTP configurado - envio de email disponível"
    read -p "Deseja receber as credenciais por email? (Y/n): " SEND_EMAIL
    if [[ ! "$SEND_EMAIL" =~ ^[Nn]$ ]]; then
        read -p "Email para receber as credenciais: " CREDENTIALS_EMAIL
        while [[ -z "$CREDENTIALS_EMAIL" ]] || [[ ! "$CREDENTIALS_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
            print_error "Email inválido ou vazio!"
            read -p "Email para receber as credenciais: " CREDENTIALS_EMAIL
        done
        SEND_EMAIL_ENABLED=true
        print_info "Credenciais serão enviadas para: $CREDENTIALS_EMAIL"
    else
        SEND_EMAIL_ENABLED=false
        print_info "Credenciais serão exibidas apenas na tela"
    fi
else
    print_info "SMTP não configurado - credenciais apenas na tela"
    print_info "Para habilitar email: sudo ./setup-smtp.sh"
    SEND_EMAIL_ENABLED=false
fi

# Gerar senha inicial para o admin do n8n
INITIAL_ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/")
print_info "Senha admin n8n gerada: $INITIAL_ADMIN_PASSWORD"

# Gerar encryption key
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# Gerar senha para o Traefik dashboard
TRAEFIK_ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/")
print_info "Senha admin Traefik gerada: $TRAEFIK_ADMIN_PASSWORD"

# Gerar hash da senha para o Traefik (htpasswd format)
TRAEFIK_ADMIN_HASH=$(openssl passwd -apr1 "$TRAEFIK_ADMIN_PASSWORD")

# Gerar senha para o pgAdmin
PGADMIN_ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/")
print_info "Senha admin pgAdmin gerada: $PGADMIN_ADMIN_PASSWORD"

# Função para envio seguro de credenciais via API
send_credentials_email() {
    local email="$1"
    local domain="$2"
    local server_ip="$3"
    
    # Verificar se arquivo de configuração SMTP existe
    local smtp_config_file="/etc/n8n-installer/smtp.conf"
    if [[ ! -f "$smtp_config_file" ]]; then
        print_error "Arquivo de configuração SMTP não encontrado: $smtp_config_file"
        print_info "Crie o arquivo com as credenciais:"
        print_info "sudo mkdir -p /etc/n8n-installer"
        print_info "sudo tee /etc/n8n-installer/smtp.conf > /dev/null <<EOF"
        print_info "SMTP_API_TOKEN=sua_chave_api_aqui"
        print_info "SMTP_API_URL=https://api.smtplw.com.br/v1/messages"
        print_info "EOF"
        return 1
    fi
    
    # Carregar configurações SMTP
    source "$smtp_config_file"
    local api_token="$SMTP_API_TOKEN"
    local api_url="${SMTP_API_URL:-https://api.smtplw.com.br/v1/messages}"
    
    if [[ -z "$api_token" ]]; then
        print_error "SMTP_API_TOKEN não configurado em $smtp_config_file"
        return 1
    fi
    
    # Criar corpo do email
    local email_body="🔐 CREDENCIAIS DE ACESSO - INSTALAÇÃO n8n
======================================

Servidor: $server_ip
Domínio: $domain
Data: $(date '+%d/%m/%Y às %H:%M')

🌐 URLs DE ACESSO:
-----------------
• n8n Editor: https://fluxos.$domain
• n8n Webhook: https://webhook.$domain  
• pgAdmin: http://$server_ip:4040
• Portainer: https://$server_ip:9443
• Traefik Dashboard: https://traefik.$domain

🔑 CREDENCIAIS:
--------------
• n8n Admin:
  Email: $INITIAL_ADMIN_EMAIL
  Senha: $INITIAL_ADMIN_PASSWORD

• pgAdmin:
  Email: $INITIAL_ADMIN_EMAIL
  Senha: $PGADMIN_ADMIN_PASSWORD

• PostgreSQL:
  Usuário: postgres
  Senha: $DB_PASSWORD
  Banco: $DATABASE

• Traefik Dashboard:
  Usuário: admin
  Senha: $TRAEFIK_ADMIN_PASSWORD

⚠️ IMPORTANTE:
- Guarde estas credenciais em local seguro
- Configure o DNS dos domínios apontando para $server_ip
- Acesse o Portainer para definir senha de admin

🛡️ SEGURANÇA:
- Todas as senhas foram geradas automaticamente
- Conexões SSL/TLS ativas
- Sistema em Docker Swarm

Instalação realizada com sucesso!
Sistema n8n - $(date)"
    
    # Escapar aspas para JSON
    email_body=$(echo "$email_body" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    
    # Criar payload JSON
    local json_payload="{
        \"subject\": \"[SEGURO] Credenciais da Instalação n8n - $domain\",
        \"body\": \"$email_body\",
        \"from\": \"sistema@$domain\",
        \"to\": \"$email\",
        \"headers\": {
            \"Content-Type\": \"text/plain\"
        }
    }"
    
    # Enviar via API
    local response=$(curl -s -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -H "x-auth-token: $api_token" \
        -d "$json_payload" 2>/dev/null)
    
    if echo "$response" | grep -q "\"success\".*true\|\"status\".*200\|\"sent\""; then
        print_success "✅ Credenciais enviadas por email para: $email"
        return 0
    else
        print_error "❌ Falha no envio do email. Credenciais serão exibidas na tela."
        return 1
    fi
}

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
docker volume create pgadmin_data >/dev/null 2>&1 || true
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

# Configurações do Traefik
TRAEFIK_ADMIN_PASSWORD=$TRAEFIK_ADMIN_PASSWORD
TRAEFIK_ADMIN_HASH=$TRAEFIK_ADMIN_HASH

# Configurações do pgAdmin
PGADMIN_ADMIN_PASSWORD=$PGADMIN_ADMIN_PASSWORD

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
export DOMAIN TRAEFIK_ADMIN_HASH
docker stack deploy -c traefik/traefik.yaml traefik >/dev/null 2>&1
sleep 5
print_success "Traefik instalado"

# 9. Deploy automático das aplicações
read -p "Deseja instalar automaticamente PostgreSQL + Redis + n8n + pgAdmin? (Y/n): " AUTO_DEPLOY
if [[ ! "$AUTO_DEPLOY" =~ ^[Nn]$ ]]; then
    print_info "Deployando aplicações automaticamente..."
    
    # Exportar todas as variáveis necessárias antes dos deploys
    export DOMAIN="$DOMAIN"
    export DATABASE="$DATABASE" 
    export DATABASE_PASSWORD="$DB_PASSWORD"
    export POSTGRES_PASSWORD="$DB_PASSWORD"
    export N8N_ENCRYPTION_KEY="$N8N_ENCRYPTION_KEY"
    export INITIAL_ADMIN_EMAIL="$INITIAL_ADMIN_EMAIL"
    export INITIAL_ADMIN_PASSWORD="$INITIAL_ADMIN_PASSWORD"
    export PGADMIN_ADMIN_PASSWORD="$PGADMIN_ADMIN_PASSWORD"
    
    # Deploy PostgreSQL
    print_info "Instalando PostgreSQL..."
    docker stack deploy -c postgres16/postgres.yaml postgres >/dev/null 2>&1
    sleep 10
    print_success "PostgreSQL instalado"
    
    # Deploy Redis
    print_info "Instalando Redis..."
    docker stack deploy -c redis/redis.yaml redis >/dev/null 2>&1
    sleep 5
    print_success "Redis instalado"
    
    # Deploy n8n (com delay entre editor e demais)
    print_info "Instalando n8n Editor..."
    docker stack deploy -c n8n/queue/orq_editor.yaml n8n_editor >/dev/null 2>&1
    print_success "n8n Editor instalado"
    
    print_info "Aguardando 1 minuto para o Editor inicializar..."
    sleep 60
    
    print_info "Instalando n8n Webhook e Worker..."
    docker stack deploy -c n8n/queue/orq_webhook.yaml n8n_webhook >/dev/null 2>&1
    docker stack deploy -c n8n/queue/orq_worker.yaml n8n_worker >/dev/null 2>&1
    print_success "n8n completo instalado"
    
    # Deploy pgAdmin
    print_info "Instalando pgAdmin..."
    docker stack deploy -c pgadmin/pgadmin.yaml pgadmin >/dev/null 2>&1
    print_success "pgAdmin instalado"
    
    AUTO_DEPLOYED=true
else
    AUTO_DEPLOYED=false
fi

# 9. Instalar ctop (opcional)
if ! command -v docker-ctop >/dev/null 2>&1; then
    print_info "Instalando ctop..."
    # Remove arquivo anterior se existir
    rm -f /usr/share/keyrings/azlux-archive-keyring.gpg >/dev/null 2>&1
    rm -f /etc/apt/sources.list.d/azlux.list >/dev/null 2>&1
    # Instala com force overwrite
    curl -fsSL https://azlux.fr/repo.gpg.key | gpg --dearmor -o /usr/share/keyrings/azlux-archive-keyring.gpg >/dev/null 2>&1 || true
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/azlux-archive-keyring.gpg] http://packages.azlux.fr/debian $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/azlux.list >/dev/null
    apt-get update -qq >/dev/null 2>&1 || true
    apt-get install -y docker-ctop >/dev/null 2>&1 || true
    print_success "ctop instalado"
fi

# Resultado final
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         INSTALAÇÃO CONCLUÍDA!            ║"
echo "║           Versão: 2025.07.17             ║"
echo "║             Versão FINAL v4              ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# # Debug: Verificar se chegou até aqui
# echo "DEBUG: Chegou ao resultado final - vars definidas:"
# echo "SERVER_IP: $SERVER_IP"
# echo "DOMAIN: $DOMAIN"
# echo "AUTO_DEPLOYED: $AUTO_DEPLOYED"
# echo ""

echo "🚨 ⚠️  ATENÇÃO MUITO IMPORTANTE! ⚠️  🚨"
echo ""
print_error "📸 TIRE UM PRINT/SCREENSHOT DESTA TELA AGORA!"
print_error "💾 SALVE AS CREDENCIAIS EM LOCAL SEGURO!"
print_error "🔐 VOCÊ PRECISARÁ DESSAS SENHAS NO FUTURO!"
echo ""

# FORÇA EXIBIÇÃO DAS INFORMAÇÕES CRÍTICAS
echo "🌐 === URLS DOS SERVIÇOS ==="
echo "   n8n Editor: https://fluxos.$DOMAIN"
echo "   n8n Webhook: https://webhook.$DOMAIN"
echo "   pgAdmin: http://$SERVER_IP:4040"
echo "   Portainer: https://$SERVER_IP:9443"
echo "   Traefik Dashboard: https://traefik.$DOMAIN"
echo ""

echo "🔑 === CREDENCIAIS DE ACESSO ==="
echo "   n8n: $INITIAL_ADMIN_EMAIL / $INITIAL_ADMIN_PASSWORD"
echo "   pgAdmin: $INITIAL_ADMIN_EMAIL / $PGADMIN_ADMIN_PASSWORD"
echo "   Traefik: admin / $TRAEFIK_ADMIN_PASSWORD"
echo "   PostgreSQL: postgres / $DB_PASSWORD"
echo ""

echo "🚨 === URGENTE: PORTAINER ==="
echo "   URL: https://$SERVER_IP:9443"
echo "   ⏰ IMPORTANTE: Você tem apenas 10 MINUTOS para acessar!"
echo "   🚨 Após 10 min sem acesso, o Portainer bloqueia a configuração!"
echo ""

echo "📋 === PRÓXIMOS PASSOS ==="
echo "1️⃣ ACESSE O PORTAINER AGORA: https://$SERVER_IP:9443"
echo "2️⃣ CONFIGURE DNS: fluxos.$DOMAIN → $SERVER_IP"
echo "3️⃣ CONFIGURE DNS: webhook.$DOMAIN → $SERVER_IP"
echo "4️⃣ AGUARDE 2 MIN e acesse: https://fluxos.$DOMAIN"
echo ""

# Email section removida para evitar travamentos
EMAIL_SENT=false
echo "DEBUG: Email section bypassed"

# Sempre mostrar as informações importantes independente do deploy
echo "🌐 URLs DOS SERVIÇOS:"
echo "   n8n Editor: https://fluxos.$DOMAIN"
echo "   n8n Webhook: https://webhook.$DOMAIN"
echo "   pgAdmin: http://$SERVER_IP:4040"
echo "   Portainer: https://$SERVER_IP:9443"
echo "   Traefik Dashboard: https://traefik.$DOMAIN"
echo ""

echo "🔑 CREDENCIAIS DE ACESSO:"
echo "   n8n: $INITIAL_ADMIN_EMAIL / $INITIAL_ADMIN_PASSWORD"
echo "   pgAdmin: $INITIAL_ADMIN_EMAIL / $PGADMIN_ADMIN_PASSWORD"
echo "   Traefik: admin / $TRAEFIK_ADMIN_PASSWORD"
echo ""

echo "🚀 PRÓXIMOS PASSOS:"
echo ""
echo "1️⃣ ACESSE O PORTAINER AGORA (URGENTE!):"
echo "   https://$SERVER_IP:9443"
echo "   ⏰ Você tem 10 MINUTOS para definir senha!"
echo "   🚨 Após 10 min, será necessário redeployar!"
echo ""

echo "DEBUG: Verificando AUTO_DEPLOYED: $AUTO_DEPLOYED"
if [[ "$AUTO_DEPLOYED" == "true" ]]; then
    echo "✅ APLICAÇÕES INSTALADAS AUTOMATICAMENTE:"
    echo "   PostgreSQL + Redis + n8n (modo queue) + pgAdmin"
    echo ""
    echo "2️⃣ CONFIGURE O DNS:"
    echo "   fluxos.$DOMAIN → $SERVER_IP"
    echo "   webhook.$DOMAIN → $SERVER_IP"
    echo "   traefik.$DOMAIN → $SERVER_IP (opcional)"
    echo ""
    echo "3️⃣ AGUARDE ~2 MINUTOS e acesse:"
    echo "   https://fluxos.$DOMAIN"
    echo ""
    echo "4️⃣ MONITORE NO PORTAINER:"
    echo "   Verifique se todos os serviços estão rodando"
    echo "   Acompanhe logs e status dos containers"
else
    echo "🔧 DEPLOY MANUAL NECESSÁRIO:"
    echo "   Use: ./deploy-api.sh (após configurar Portainer)"
    echo ""
    echo "2️⃣ CONFIGURE O DNS:"
    echo "   fluxos.$DOMAIN → $SERVER_IP"
    echo "   webhook.$DOMAIN → $SERVER_IP"
    echo "   traefik.$DOMAIN → $SERVER_IP (opcional)"
    echo ""
    echo "3️⃣ DEPLOY VIA API:"
    echo "   ./deploy-api.sh"
    echo "   (Script automatizado para deploy via API do Portainer)"
fi

echo ""
echo "🔑 ⚠️  CREDENCIAIS CRÍTICAS - SALVE ESTA INFORMAÇÃO! ⚠️"
echo "📄 Arquivo .env criado com todas as credenciais"
echo ""
echo "🗂️  RESUMO DE TODAS AS SENHAS:"
echo "   PostgreSQL: postgres / $DB_PASSWORD"
echo "   Banco: $DATABASE"
echo "   Traefik Dashboard: admin / $TRAEFIK_ADMIN_PASSWORD"
echo "   pgAdmin: $INITIAL_ADMIN_EMAIL / $PGADMIN_ADMIN_PASSWORD"
echo ""
print_error "📸 TIRE UM PRINT DESTA TELA ANTES DE CONTINUAR!"
print_error "💾 GUARDE AS SENHAS EM GERENCIADOR DE SENHAS!"

if [[ "$EMAIL_SENT" == "true" ]]; then
    echo ""
    echo "📧 Credenciais também enviadas por email para: $CREDENTIALS_EMAIL"
fi
echo ""
echo "📊 Comandos úteis:"
echo "   docker stack ls              # Ver stacks"
echo "   docker service ls            # Ver serviços"
echo "   docker-ctop                  # Monitor"
echo "   docker service logs <nome>   # Ver logs"
echo "   ./debug.sh                   # Diagnóstico completo"
echo ""
echo "🚨 LEMBRETE FINAL:"
print_error "📸 VOCÊ TIROU O PRINT DAS CREDENCIAIS?"
print_error "💾 VOCÊ SALVOU AS SENHAS EM LOCAL SEGURO?"
echo ""
echo "✅ === INSTALAÇÃO FINALIZADA ==="
echo "📅 Data: $(date)"
echo "🔧 Script versão: 2025.07.17-v3"
echo ""
echo "⏰ AGUARDE ~2 MINUTOS antes de acessar os serviços"
echo "🔄 Os containers precisam de tempo para inicializar"
echo ""
echo "🎯 RESUMO FINAL:"
echo "   • Portainer: https://$SERVER_IP:9443 (10 min para configurar!)"
echo "   • n8n: https://fluxos.$DOMAIN (após configurar DNS)"
echo "   • pgAdmin: http://$SERVER_IP:4040"
echo ""
print_error "📸 NÃO ESQUEÇA DE SALVAR ESTE PRINT!"
echo ""
echo "DEBUG: Script finalizado com sucesso! ✅"