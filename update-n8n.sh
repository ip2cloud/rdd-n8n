#!/bin/bash

###################################
# Script para Atualizar n8n
# Seleciona versão e atualiza todos os orq_
###################################

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; exit 1; }
print_info() { echo -e "${YELLOW}→ $1${NC}"; }
print_version() { echo -e "${BLUE}🔖 $1${NC}"; }

echo "╔══════════════════════════════════════════╗"
echo "║         ATUALIZAÇÃO DO N8N               ║"
echo "║     Seleção de Versão Automática         ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verificar se .env existe
if [[ ! -f ".env" ]]; then
    print_error "Arquivo .env não encontrado. Execute ./install-simple.sh primeiro"
fi

# Verificar se Docker está rodando
if ! docker info >/dev/null 2>&1; then
    print_error "Docker não está rodando ou não há permissão de acesso"
fi

# Verificar se curl está instalado
if ! command -v curl >/dev/null 2>&1; then
    print_error "curl não está instalado. Execute: apt install curl"
fi

# Verificar se jq está disponível (opcional, mas útil)
if ! command -v jq >/dev/null 2>&1; then
    print_info "⚠️  jq não instalado. Usando parsing básico (pode ser menos confiável)"
fi

# Carregar variáveis
source .env
print_info "Configurações carregadas do .env"

# Função para buscar versões disponíveis do n8n
get_n8n_versions() {
    print_info "🔍 Buscando versões disponíveis do n8n no Docker Hub..."
    
    # Buscar tags do Docker Hub usando API
    local response=$(curl -s "https://registry.hub.docker.com/v2/repositories/n8nio/n8n/tags/?page_size=50" 2>/dev/null)
    
    if [[ -z "$response" ]]; then
        print_error "Falha ao conectar com Docker Hub. Verifique sua conexão."
    fi
    
    # Extrair apenas versões numéricas (formato X.Y.Z)
    local versions=$(echo "$response" | grep -o '"name":"[0-9]\+\.[0-9]\+\.[0-9]\+"' | sed 's/"name":"//g' | sed 's/"//g' | sort -V -r | head -20)
    
    if [[ -z "$versions" ]]; then
        print_error "Não foi possível obter lista de versões. Usando versões padrão."
        versions="1.100.1
1.99.0
1.98.0
1.97.0
1.96.0
latest"
    fi
    
    echo "$versions"
}

# Função para exibir versão atual
show_current_version() {
    print_info "📋 Verificando versão atual do n8n..."
    
    local current_version=""
    if docker service ls | grep -q n8n_editor; then
        # Extrair versão da imagem do serviço
        current_version=$(docker service inspect n8n_editor_n8n_editor_ip2 --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null | sed 's/.*://g')
        if [[ -z "$current_version" ]]; then
            # Tentar com nome alternativo
            current_version=$(docker service ls --format "table {{.Name}}\t{{.Image}}" | grep n8n_editor | awk '{print $2}' | sed 's/.*://g')
        fi
        if [[ -n "$current_version" ]]; then
            print_success "Versão atual: n8nio/n8n:$current_version"
        else
            print_info "Não foi possível detectar a versão atual"
        fi
    else
        print_info "Serviços n8n não encontrados"
    fi
}

# Função para validar se a imagem existe
validate_image() {
    local version="$1"
    print_info "🔍 Validando imagem n8nio/n8n:$version..."
    
    if docker manifest inspect "n8nio/n8n:$version" >/dev/null 2>&1; then
        print_success "Imagem n8nio/n8n:$version encontrada"
        return 0
    else
        print_error "Imagem n8nio/n8n:$version não encontrada no Docker Hub"
        return 1
    fi
}

# Função para atualizar arquivo YAML
update_yaml_version() {
    local file="$1"
    local new_version="$2"
    
    if [[ -f "$file" ]]; then
        # Backup do arquivo original
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Substituir versão na linha da imagem
        sed -i "s|image: n8nio/n8n:.*|image: n8nio/n8n:$new_version|g" "$file"
        print_success "Arquivo $file atualizado para versão $new_version"
    else
        print_error "Arquivo $file não encontrado"
    fi
}

# Função para fazer deploy dos serviços
deploy_services() {
    local version="$1"
    
    print_info "🚀 Fazendo deploy da nova versão..."
    
    # Exportar variáveis necessárias
    export DOMAIN DATABASE DATABASE_PASSWORD N8N_ENCRYPTION_KEY INITIAL_ADMIN_EMAIL INITIAL_ADMIN_PASSWORD
    
    # Deploy n8n Editor
    print_info "Atualizando n8n Editor..."
    docker stack deploy -c n8n/queue/orq_editor.yaml n8n_editor
    sleep 30
    print_success "n8n Editor atualizado"
    
    # Deploy n8n Webhook
    print_info "Atualizando n8n Webhook..."
    docker stack deploy -c n8n/queue/orq_webhook.yaml n8n_webhook
    sleep 15
    print_success "n8n Webhook atualizado"
    
    # Deploy n8n Worker
    print_info "Atualizando n8n Worker..."
    docker stack deploy -c n8n/queue/orq_worker.yaml n8n_worker
    sleep 15
    print_success "n8n Worker atualizado"
}

# Função principal
main() {
    # Mostrar versão atual
    show_current_version
    echo ""
    
    # Perguntar se quer ver versões disponíveis
    read -p "Deseja ver as versões disponíveis no Docker Hub? (Y/n): " SHOW_VERSIONS
    if [[ ! "$SHOW_VERSIONS" =~ ^[Nn]$ ]]; then
        echo ""
        print_info "🔖 Versões disponíveis do n8n:"
        echo ""
        
        local versions=$(get_n8n_versions)
        local counter=1
        
        # Criar array de versões
        declare -a version_array
        while IFS= read -r version; do
            print_version "$counter) n8nio/n8n:$version"
            version_array[$counter]="$version"
            ((counter++))
        done <<< "$versions"
        
        echo ""
        echo "0) Digitar versão manualmente"
        echo ""
        
        # Seleção da versão
        while true; do
            read -p "Selecione a versão (número ou 0 para manual): " CHOICE
            
            if [[ "$CHOICE" == "0" ]]; then
                read -p "Digite a versão desejada (ex: 1.100.1): " NEW_VERSION
                break
            elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && [[ -n "${version_array[$CHOICE]}" ]]; then
                NEW_VERSION="${version_array[$CHOICE]}"
                break
            else
                print_error "Seleção inválida. Tente novamente."
            fi
        done
    else
        # Versão manual
        read -p "Digite a versão desejada (ex: 1.100.1): " NEW_VERSION
    fi
    
    echo ""
    print_info "Versão selecionada: n8nio/n8n:$NEW_VERSION"
    
    # Validar imagem
    if ! validate_image "$NEW_VERSION"; then
        exit 1
    fi
    
    echo ""
    read -p "Confirma a atualização para n8nio/n8n:$NEW_VERSION? (Y/n): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
        print_error "Atualização cancelada pelo usuário"
    fi
    
    echo ""
    print_info "🔄 Iniciando atualização para n8nio/n8n:$NEW_VERSION..."
    
    # Atualizar arquivos YAML
    update_yaml_version "n8n/queue/orq_editor.yaml" "$NEW_VERSION"
    update_yaml_version "n8n/queue/orq_webhook.yaml" "$NEW_VERSION" 
    update_yaml_version "n8n/queue/orq_worker.yaml" "$NEW_VERSION"
    
    echo ""
    
    # Deploy dos serviços
    deploy_services "$NEW_VERSION"
    
    echo ""
    print_success "🎉 Atualização concluída!"
    echo ""
    echo "📋 INFORMAÇÕES:"
    echo "   • Versão: n8nio/n8n:$NEW_VERSION"
    echo "   • Backups salvos: *.backup.*"
    echo "   • URL: https://fluxos.$DOMAIN"
    echo ""
    echo "🔍 VERIFICAR:"
    echo "   docker service ls | grep n8n"
    echo "   docker service logs \$(docker service ls --format '{{.Name}}' | grep n8n_editor | head -1)"
    echo ""
    print_info "⏰ Aguarde ~2 minutos para os serviços inicializarem"
}

# Executar função principal
main