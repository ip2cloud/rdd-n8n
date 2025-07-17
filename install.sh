#!/bin/bash

###################################
#
# Script de Instalação Automatizada
# Docker Swarm + n8n + Portainer
#
# Executa todos os passos necessários para configurar
# o ambiente Docker Swarm com n8n e Portainer
#
###################################

set -e  # Para em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERRO: $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] AVISO: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Função para verificar se é root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script deve ser executado como root (use sudo)"
        exit 1
    fi
}

# Função para verificar se é sistema Debian/Ubuntu
check_system() {
    if [[ ! -f /etc/debian_version ]]; then
        error "Este script foi desenvolvido para sistemas Debian/Ubuntu"
        exit 1
    fi
    log "Sistema Debian/Ubuntu detectado"
}

# Função para configurar hostname
setup_hostname() {
    log "=== CONFIGURANDO HOSTNAME ==="
    
    read -p "Digite o hostname desejado para esta máquina (ex: manager1): " NEW_HOSTNAME
    
    if [[ -z "$NEW_HOSTNAME" ]]; then
        error "Hostname não pode estar vazio"
        exit 1
    fi
    
    log "Configurando hostname para: $NEW_HOSTNAME"
    hostnamectl set-hostname "$NEW_HOSTNAME"
    
    # Adiciona entrada no /etc/hosts
    if ! grep -q "127.0.0.1.*$NEW_HOSTNAME" /etc/hosts; then
        echo "127.0.0.1    $NEW_HOSTNAME" >> /etc/hosts
        log "Entrada adicionada ao /etc/hosts"
    fi
    
    log "Hostname configurado com sucesso"
}

# Função para instalar Docker
install_docker() {
    log "=== INSTALANDO DOCKER ==="
    
    # Verifica se Docker já está instalado
    if command -v docker >/dev/null 2>&1; then
        warning "Docker já está instalado"
        docker --version
        return 0
    fi
    
    log "Atualizando sistema e instalando dependências..."
    apt-get update
    apt-get install -y sudo gnupg2 wget ca-certificates apt-transport-https curl gnupg nano htop
    
    log "Adicionando chave GPG do Docker..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    log "Adicionando repositório do Docker..."
    echo \
      "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    
    log "Instalando Docker..."
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log "Habilitando serviços do Docker..."
    systemctl enable docker.service
    systemctl enable containerd.service
    systemctl start docker.service
    
    log "Docker instalado com sucesso!"
    docker --version
}

# Função para configurar Docker Swarm
setup_swarm() {
    log "=== CONFIGURANDO DOCKER SWARM ==="
    
    # Verifica se já está em um swarm
    if docker info --format '{{.Swarm.LocalNodeState}}' | grep -q active; then
        warning "Este nó já faz parte de um Docker Swarm"
        return 0
    fi
    
    echo "Escolha uma opção:"
    echo "1) Inicializar um novo Swarm (Manager)"
    echo "2) Juntar-se a um Swarm existente (Worker)"
    read -p "Digite sua escolha (1 ou 2): " SWARM_CHOICE
    
    case $SWARM_CHOICE in
        1)
            read -p "Digite o IP deste servidor para anunciar o Swarm: " SWARM_IP
            if [[ -z "$SWARM_IP" ]]; then
                error "IP não pode estar vazio"
                exit 1
            fi
            
            log "Inicializando Docker Swarm..."
            docker swarm init --advertise-addr="$SWARM_IP"
            
            log "Criando redes overlay..."
            docker network create --driver=overlay network_swarm_public 2>/dev/null || warning "Rede network_swarm_public já existe"
            docker network create --driver=overlay network_swarm_databases 2>/dev/null || warning "Rede network_swarm_databases já existe"
            
            log "Para adicionar workers a este swarm, execute o comando mostrado acima em outros servidores"
            ;;
        2)
            read -p "Digite o comando 'docker swarm join' fornecido pelo manager: " SWARM_JOIN_CMD
            if [[ -z "$SWARM_JOIN_CMD" ]]; then
                error "Comando de join não pode estar vazio"
                exit 1
            fi
            
            log "Juntando-se ao Swarm..."
            $SWARM_JOIN_CMD
            ;;
        *)
            error "Opção inválida"
            exit 1
            ;;
    esac
    
    log "Docker Swarm configurado com sucesso!"
}

# Função para instalar ferramentas opcionais
install_optional_tools() {
    log "=== INSTALANDO FERRAMENTAS OPCIONAIS ==="
    
    read -p "Deseja instalar ctop (monitor de containers)? (y/N): " INSTALL_CTOP
    
    if [[ "$INSTALL_CTOP" =~ ^[Yy]$ ]]; then
        log "Instalando ctop..."
        
        apt-get install -y ca-certificates curl gnupg lsb-release
        curl -fsSL https://azlux.fr/repo.gpg.key | gpg --dearmor -o /usr/share/keyrings/azlux-archive-keyring.gpg
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/azlux-archive-keyring.gpg] http://packages.azlux.fr/debian \
          $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/azlux.list > /dev/null
        apt-get update
        apt-get install -y docker-ctop
        
        log "ctop instalado com sucesso! Execute 'docker-ctop' para monitorar containers"
    fi
}

# Função para criar volumes necessários
create_volumes() {
    log "=== CRIANDO VOLUMES DOCKER ==="
    
    # Volumes para PostgreSQL
    if ! docker volume ls | grep -q postgres_data; then
        log "Criando volume postgres_data..."
        docker volume create postgres_data
    else
        info "Volume postgres_data já existe"
    fi
    
    # Volumes para Redis
    if ! docker volume ls | grep -q redis_data; then
        log "Criando volume redis_data..."
        docker volume create redis_data
    else
        info "Volume redis_data já existe"
    fi
    
    # Volume para RedisInsight
    if ! docker volume ls | grep -q redis_insigth_data; then
        log "Criando volume redis_insigth_data..."
        docker volume create redis_insigth_data
    else
        info "Volume redis_insigth_data já existe"
    fi
    
    log "Volumes criados com sucesso!"
}

# Função para deploy do PostgreSQL
deploy_postgresql() {
    log "=== DEPLOY DO POSTGRESQL ==="
    
    read -p "Deseja fazer deploy do PostgreSQL? (Y/n): " DEPLOY_POSTGRES
    
    if [[ ! "$DEPLOY_POSTGRES" =~ ^[Nn]$ ]]; then
        if [[ ! -f "./postgres16/postgres.yaml" ]]; then
            error "Arquivo postgres.yaml não encontrado em ./postgres16/"
            return 1
        fi
        
        # Configura senha do PostgreSQL se não foi definida
        if [[ -z "$POSTGRES_PASSWORD" ]]; then
            read -s -p "Digite a senha para o PostgreSQL (deixe vazio para usar padrão): " POSTGRES_PASSWORD
            echo
            if [[ -z "$POSTGRES_PASSWORD" ]]; then
                POSTGRES_PASSWORD="lWTgxiVOht0K80mQpdY5pYA"
                warning "Usando senha padrão do PostgreSQL"
            fi
            export POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
            
            # Adiciona ao .env se existir
            if [[ -f ".env" ]]; then
                echo "" >> .env
                echo "# Configurações PostgreSQL" >> .env
                echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> .env
            fi
        fi
        
        log "Fazendo deploy do PostgreSQL..."
        docker stack deploy --prune --detach=false --resolve-image always -c ./postgres16/postgres.yaml postgres
        
        log "PostgreSQL deployado com sucesso!"
        info "Senha do PostgreSQL: (salva no .env)"
        
        # Aguarda o PostgreSQL ficar pronto
        log "Aguardando PostgreSQL ficar disponível..."
        sleep 10
    else
        log "Pulando deploy do PostgreSQL"
    fi
}

# Função para deploy do Redis
deploy_redis() {
    log "=== DEPLOY DO REDIS ==="
    
    read -p "Deseja fazer deploy do Redis? (Y/n): " DEPLOY_REDIS
    
    if [[ ! "$DEPLOY_REDIS" =~ ^[Nn]$ ]]; then
        if [[ ! -f "./redis/redis.yaml" ]]; then
            error "Arquivo redis.yaml não encontrado em ./redis/"
            return 1
        fi
        
        log "Fazendo deploy do Redis..."
        docker stack deploy --prune --detach=false --resolve-image always -c ./redis/redis.yaml redis
        
        log "Redis deployado com sucesso!"
        
        # Pergunta sobre RedisInsight
        read -p "Deseja instalar RedisInsight (interface web)? (y/N): " DEPLOY_REDIS_INSIGHT
        if [[ "$DEPLOY_REDIS_INSIGHT" =~ ^[Yy]$ ]]; then
            if [[ -f "./redis/redisInsight.yaml" ]]; then
                log "Fazendo deploy do RedisInsight..."
                docker stack deploy --prune --detach=false --resolve-image always -c ./redis/redisInsight.yaml redisinsight
                log "RedisInsight deployado com sucesso!"
                info "RedisInsight disponível na porta 5540"
            else
                warning "Arquivo redisInsight.yaml não encontrado"
            fi
        fi
        
        # Aguarda o Redis ficar pronto
        log "Aguardando Redis ficar disponível..."
        sleep 5
    else
        log "Pulando deploy do Redis"
    fi
}

# Função para deploy do Portainer
deploy_portainer() {
    log "=== DEPLOY DO PORTAINER ==="
    
    read -p "Deseja fazer deploy do Portainer? (y/N): " DEPLOY_PORTAINER
    
    if [[ "$DEPLOY_PORTAINER" =~ ^[Yy]$ ]]; then
        if [[ ! -f "./portainer/portainer.yaml" ]]; then
            error "Arquivo portainer.yaml não encontrado em ./portainer/"
            return 1
        fi
        
        log "Fazendo pull da imagem do Portainer..."
        docker pull portainer/portainer-ce:sts
        
        log "Fazendo deploy do Portainer..."
        docker stack deploy --prune --detach=false --resolve-image always -c ./portainer/portainer.yaml portainer
        
        log "Portainer deployado com sucesso!"
        log "Acesse via navegador no endereço configurado no YAML"
    fi
}

# Função para configurar variáveis de ambiente do n8n
configure_n8n_environment() {
    log "=== CONFIGURANDO VARIÁVEIS DE AMBIENTE DO N8N ==="
    
    # Cria arquivo de variáveis de ambiente se não existir
    if [[ ! -f ".env" ]]; then
        log "Criando arquivo .env para variáveis de ambiente..."
        touch .env
    fi
    
    # Coleta informações do domínio
    read -p "Digite o domínio principal (ex: exemplo.com): " DOMAIN
    while [[ -z "$DOMAIN" ]]; do
        error "Domínio não pode estar vazio"
        read -p "Digite o domínio principal (ex: exemplo.com): " DOMAIN
    done
    
    # Variáveis fixas para subdomínios conforme arquivos orq_
    WORKFLOW="fluxos"
    WEBHOOK="webhook"
    
    log "Subdomínios configurados:"
    log "  - Workflow Editor: $WORKFLOW"
    log "  - Webhooks: $WEBHOOK"
    
    # Coleta informações do banco de dados
    read -p "Digite o nome do banco de dados PostgreSQL: " DATABASE
    while [[ -z "$DATABASE" ]]; do
        error "Nome do banco não pode estar vazio"
        read -p "Digite o nome do banco de dados PostgreSQL: " DATABASE
    done
    
    read -s -p "Digite a senha do banco de dados PostgreSQL: " DATABASE_PASSWORD
    echo
    while [[ -z "$DATABASE_PASSWORD" ]]; do
        error "Senha do banco não pode estar vazia"
        read -s -p "Digite a senha do banco de dados PostgreSQL: " DATABASE_PASSWORD
        echo
    done
    
    # Gera chave de criptografia se não fornecida
    read -p "Digite a chave de criptografia N8N (deixe vazio para gerar automaticamente): " N8N_ENCRYPTION_KEY
    if [[ -z "$N8N_ENCRYPTION_KEY" ]]; then
        N8N_ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
        log "Chave de criptografia gerada automaticamente"
    fi
    
    # Configura template invite (opcional)
    read -p "Digite o template de convite por email (opcional): " TEMPLATES_INVITE
    
    # Salva variáveis no arquivo .env
    log "Salvando variáveis de ambiente no arquivo .env..."
    cat > .env << EOF
# Configurações de Domínio
DOMAIN=$DOMAIN
WORKFLOW=$WORKFLOW
WEBHOOK=$WEBHOOK

# Configurações de Banco de Dados
DATABASE=$DATABASE
DATABASE_PASSWORD=$DATABASE_PASSWORD

# Configurações de Segurança
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY

# Configurações Opcionais
TEMPLATES_INVITE=$TEMPLATES_INVITE
EOF
    
    # Exporta as variáveis para o ambiente atual
    export DOMAIN="$DOMAIN"
    export WORKFLOW="$WORKFLOW"
    export WEBHOOK="$WEBHOOK"
    export DATABASE="$DATABASE"
    export DATABASE_PASSWORD="$DATABASE_PASSWORD"
    export N8N_ENCRYPTION_KEY="$N8N_ENCRYPTION_KEY"
    export TEMPLATES_INVITE="$TEMPLATES_INVITE"
    
    log "Variáveis de ambiente configuradas!"
    log "Domínio do Editor: https://${WORKFLOW}.${DOMAIN}/"
    log "Domínio do Webhook: https://${WEBHOOK}.${DOMAIN}/"
    log "Banco de Dados: $DATABASE"
    
    # Pergunta se quer salvar as configurações SMTP
    read -p "Deseja configurar SMTP personalizado? (y/N): " CONFIGURE_SMTP
    if [[ "$CONFIGURE_SMTP" =~ ^[Yy]$ ]]; then
        configure_smtp_settings
    fi
}

# Função para configurar SMTP
configure_smtp_settings() {
    log "=== CONFIGURANDO SMTP ==="
    
    read -p "Host SMTP: " SMTP_HOST
    read -p "Porta SMTP: " SMTP_PORT
    read -p "Usuário SMTP: " SMTP_USER
    read -s -p "Senha SMTP: " SMTP_PASS
    echo
    read -p "Email do remetente: " SMTP_SENDER
    
    # Adiciona configurações SMTP ao .env
    cat >> .env << EOF

# Configurações SMTP
N8N_SMTP_HOST=$SMTP_HOST
N8N_SMTP_PORT=$SMTP_PORT
N8N_SMTP_USER=$SMTP_USER
N8N_SMTP_PASS=$SMTP_PASS
N8N_SMTP_SENDER=$SMTP_SENDER
EOF
    
    # Exporta as variáveis SMTP
    export N8N_SMTP_HOST="$SMTP_HOST"
    export N8N_SMTP_PORT="$SMTP_PORT"
    export N8N_SMTP_USER="$SMTP_USER"
    export N8N_SMTP_PASS="$SMTP_PASS"
    export N8N_SMTP_SENDER="$SMTP_SENDER"
    
    log "Configurações SMTP salvas!"
}

# Função para deploy do n8n
deploy_n8n() {
    log "=== DEPLOY DO N8N ==="
    
    echo "Escolha o modo de deploy do n8n:"
    echo "1) Modo Regular (single instance)"
    echo "2) Modo Queue (editor + webhook + worker)"
    echo "3) Pular deploy do n8n"
    read -p "Digite sua escolha (1, 2 ou 3): " N8N_CHOICE
    
    case $N8N_CHOICE in
        1)
            if [[ ! -f "./n8n/regular/n8n-regular.yaml" ]]; then
                error "Arquivo n8n-regular.yaml não encontrado em ./n8n/regular/"
                return 1
            fi
            
            # Configura variáveis de ambiente
            configure_n8n_environment
            
            log "Fazendo deploy do n8n (modo regular)..."
            docker stack deploy --prune --detach=false --resolve-image always -c ./n8n/regular/n8n-regular.yaml n8n
            log "n8n (modo regular) deployado com sucesso!"
            ;;
        2)
            if [[ ! -f "./n8n/queue/orq_editor.yaml" ]] || [[ ! -f "./n8n/queue/orq_webhook.yaml" ]] || [[ ! -f "./n8n/queue/orq_worker.yaml" ]]; then
                error "Arquivos YAML do modo queue não encontrados em ./n8n/queue/"
                return 1
            fi
            
            # Configura variáveis de ambiente
            configure_n8n_environment
            
            log "Fazendo deploy do n8n (modo queue)..."
            log "Deployando editor..."
            docker stack deploy --prune --detach=false --resolve-image always -c ./n8n/queue/orq_editor.yaml n8n_editor
            
            log "Deployando webhook..."
            docker stack deploy --prune --detach=false --resolve-image always -c ./n8n/queue/orq_webhook.yaml n8n_webhook
            
            log "Deployando worker..."
            docker stack deploy --prune --detach=false --resolve-image always -c ./n8n/queue/orq_worker.yaml n8n_worker
            
            log "n8n (modo queue) deployado com sucesso!"
            ;;
        3)
            log "Pulando deploy do n8n"
            ;;
        *)
            error "Opção inválida"
            return 1
            ;;
    esac
}

# Função para mostrar status final
show_status() {
    log "=== STATUS FINAL ==="
    
    log "Hostname atual:"
    hostnamectl
    
    log "Docker Swarm status:"
    docker node ls 2>/dev/null || info "Execute como manager para ver os nós"
    
    log "Stacks deployados:"
    docker stack ls 2>/dev/null || info "Nenhum stack encontrado"
    
    log "Redes disponíveis:"
    docker network ls | grep overlay
    
    # Mostra configurações das aplicações se existirem
    if [[ -f ".env" ]]; then
        log "=== CONFIGURAÇÕES DAS APLICAÇÕES ==="
        
        # Configurações do PostgreSQL
        if [[ ! -z "$POSTGRES_PASSWORD" ]]; then
            info "PostgreSQL instalado:"
            info "  - Host: postgres (interno do Swarm)"
            info "  - Porta: 5432"
            info "  - Usuário: postgres"
            info "  - Senha: (salva no .env)"
        fi
        
        # Configurações do Redis
        if docker stack ls | grep -q redis; then
            info "Redis instalado:"
            info "  - Host: redis (interno do Swarm)"
            info "  - Porta: 6379"
            if docker stack ls | grep -q redisinsight; then
                info "  - RedisInsight: porta 5540"
            fi
        fi
        
        # Configurações do n8n
        if [[ ! -z "$DOMAIN" ]]; then
            info "n8n instalado:"
            info "  - Editor URL: https://${WORKFLOW}.${DOMAIN}/"
            info "  - Webhook URL: https://${WEBHOOK}.${DOMAIN}/"
            info "  - Banco de Dados: $DATABASE"
        fi
        
        warning "Arquivo .env criado com as variáveis de ambiente"
        warning "IMPORTANTE: Guarde o arquivo .env em local seguro!"
    fi
    
    info "Instalação concluída!"
    info "Para monitorar containers, use: docker-ctop (se instalado)"
    info "Para ver logs de um serviço: docker service logs NOME_DO_SERVICO"
    
    if [[ -f ".env" ]]; then
        info "Para usar as variáveis de ambiente: source .env"
    fi
}

# Função principal
main() {
    log "Iniciando instalação automatizada do Docker Swarm + PostgreSQL + Redis + n8n + Portainer"
    
    check_root
    check_system
    
    setup_hostname
    install_docker
    setup_swarm
    install_optional_tools
    
    # Só faz deploy se estiver em um manager node
    if docker info --format '{{.Swarm.LocalNodeState}}' | grep -q active; then
        if docker node ls >/dev/null 2>&1; then
            log "=== INICIANDO DEPLOY DAS APLICAÇÕES ==="
            
            # 1. Criar volumes necessários
            create_volumes
            
            # 2. Deploy das bases de dados (primeiro)
            deploy_postgresql
            deploy_redis
            
            # 3. Deploy do Portainer
            deploy_portainer
            
            # 4. Deploy do n8n (por último, precisa das bases de dados)
            deploy_n8n
        else
            info "Este é um worker node. Deploy de aplicações deve ser feito no manager."
        fi
    fi
    
    show_status
    
    log "Script de instalação finalizado!"
}

# Execução
main "$@"