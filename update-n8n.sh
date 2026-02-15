#!/bin/bash

###################################
# Script para Atualizar n8n
# Seleciona versão e atualiza todos os orq_
###################################

echo "╔══════════════════════════════════════════╗"
echo "║         ATUALIZAÇÃO DO N8N               ║"
echo "║     Seleção de Versão Automática         ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verificar se .env existe
if [ ! -f ".env" ]; then
    echo "❌ Arquivo .env não encontrado"
    echo "Execute ./install-simple.sh primeiro"
    exit 1
fi

# Verificar se Docker está rodando
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker não está rodando ou sem permissão"
    exit 1
fi

# Carregar variáveis
source .env
echo "✅ Configurações carregadas do .env"
echo "📋 Domínio: $DOMAIN"
echo ""

# Função para buscar versões disponíveis
get_n8n_versions() {
    echo "🔍 Buscando versões do n8n no Docker Hub..."
    
    # Tentar buscar via API do Docker Hub (múltiplas páginas para garantir versões 2.x)
    local all_versions=""
    local page=1
    local max_pages=5

    while [[ $page -le $max_pages ]]; do
        local response=$(curl -s "https://registry.hub.docker.com/v2/repositories/n8nio/n8n/tags/?page_size=100&page=$page" 2>/dev/null)

        if [[ -z "$response" ]]; then
            break
        fi

        local page_versions=$(echo "$response" | grep -o '"name":"[0-9]\+\.[0-9]\+\.[0-9]\+"' | sed 's/"name":"//g' | sed 's/"//g')

        if [[ -z "$page_versions" ]]; then
            break
        fi

        all_versions="$all_versions
$page_versions"

        # Verificar se há próxima página
        echo "$response" | grep -q '"next":null' && break
        ((page++))
    done

    if [[ -n "$all_versions" ]]; then
        # Filtrar apenas versões 2.x+ e ordenar
        local filtered=$(echo "$all_versions" | grep -E '^[2-9]\.' | sort -V -r | head -15)

        if [[ -n "$filtered" ]]; then
            echo "$filtered"
            return
        fi
    fi

    # Fallback: versões fixas se API falhar
    echo "2.6.4
2.6.3
2.6.2
2.6.1
2.6.0
2.5.0
2.4.3
2.4.2
2.4.1
2.4.0"
}

# Mostrar versão atual
show_current_version() {
    echo "📋 Verificando versão atual do n8n..."
    
    local current_version=""
    if docker service ls | grep -q n8n_editor; then
        current_version=$(docker service ls --format "{{.Name}} {{.Image}}" | grep n8n_editor | head -1 | awk '{print $2}' | sed 's/.*://')
        
        if [[ -n "$current_version" ]]; then
            echo "✅ Versão atual: n8nio/n8n:$current_version"
        else
            echo "ℹ️  Não foi possível detectar a versão atual"
        fi
    else
        echo "ℹ️  Serviços n8n não encontrados"
    fi
    echo ""
}

# Validar se a imagem existe
validate_image() {
    local version="$1"
    echo "🔍 Validando imagem n8nio/n8n:$version..."
    
    if docker manifest inspect "n8nio/n8n:$version" >/dev/null 2>&1; then
        echo "✅ Imagem n8nio/n8n:$version encontrada"
        return 0
    else
        echo "❌ Imagem n8nio/n8n:$version não encontrada no Docker Hub"
        return 1
    fi
}

# Atualizar arquivo YAML
update_yaml_version() {
    local file="$1"
    local new_version="$2"
    
    if [[ -f "$file" ]]; then
        # Backup do arquivo original
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Substituir versão na linha da imagem
        sed -i "s|image: n8nio/n8n:.*|image: n8nio/n8n:$new_version|g" "$file"
        echo "✅ $file atualizado para versão $new_version"
    else
        echo "❌ Arquivo $file não encontrado"
        return 1
    fi
}

# Deploy dos serviços
deploy_services() {
    local version="$1"
    
    echo "🚀 Fazendo deploy da nova versão..."
    
    # Exportar variáveis necessárias
    export DOMAIN DATABASE DATABASE_PASSWORD N8N_ENCRYPTION_KEY INITIAL_ADMIN_EMAIL INITIAL_ADMIN_PASSWORD
    
    # Deploy n8n Editor primeiro
    echo "→ Atualizando n8n Editor..."
    docker stack deploy -c n8n/queue-v2/orq_editor.yaml n8n_editor
    sleep 30
    echo "✅ n8n Editor atualizado"

    # Deploy n8n Webhook
    echo "→ Atualizando n8n Webhook..."
    docker stack deploy -c n8n/queue-v2/orq_webhook.yaml n8n_webhook
    sleep 15
    echo "✅ n8n Webhook atualizado"

    # Deploy n8n Worker
    echo "→ Atualizando n8n Worker..."
    docker stack deploy -c n8n/queue-v2/orq_worker.yaml n8n_worker
    sleep 15
    echo "✅ n8n Worker atualizado"
}

# Função principal
main() {
    # Mostrar versão atual
    show_current_version
    
    # Perguntar se quer ver versões disponíveis
    read -p "Deseja ver as versões disponíveis no Docker Hub? (Y/n): " SHOW_VERSIONS
    if [[ ! "$SHOW_VERSIONS" =~ ^[Nn]$ ]]; then
        echo ""
        echo "🔖 Versões disponíveis do n8n:"
        echo ""
        
        local versions=$(get_n8n_versions)
        local counter=1
        
        # Criar array de versões
        declare -a version_array
        while IFS= read -r version; do
            echo "$counter) n8nio/n8n:$version"
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
                read -p "Digite a versão desejada (ex: 2.6.4): " NEW_VERSION
                break
            elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && [[ -n "${version_array[$CHOICE]}" ]]; then
                NEW_VERSION="${version_array[$CHOICE]}"
                break
            else
                echo "❌ Seleção inválida. Tente novamente."
            fi
        done
    else
        # Versão manual
        read -p "Digite a versão desejada (ex: 2.6.4): " NEW_VERSION
    fi
    
    echo ""
    echo "🎯 Versão selecionada: n8nio/n8n:$NEW_VERSION"
    
    # Validar imagem
    if ! validate_image "$NEW_VERSION"; then
        exit 1
    fi
    
    echo ""
    read -p "Confirma a atualização para n8nio/n8n:$NEW_VERSION? (Y/n): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
        echo "❌ Atualização cancelada pelo usuário"
        exit 1
    fi
    
    echo ""
    echo "🔄 Iniciando atualização para n8nio/n8n:$NEW_VERSION..."
    
    # Atualizar arquivos YAML
    update_yaml_version "n8n/queue-v2/orq_editor.yaml" "$NEW_VERSION" || exit 1
    update_yaml_version "n8n/queue-v2/orq_webhook.yaml" "$NEW_VERSION" || exit 1
    update_yaml_version "n8n/queue-v2/orq_worker.yaml" "$NEW_VERSION" || exit 1
    
    echo ""
    
    # Deploy dos serviços
    deploy_services "$NEW_VERSION"
    
    echo ""
    echo "🎉 Atualização concluída com sucesso!"
    echo ""
    echo "📋 INFORMAÇÕES:"
    echo "   • Versão: n8nio/n8n:$NEW_VERSION"
    echo "   • Backups salvos: *.backup.*"
    echo "   • URL: https://fluxos.$DOMAIN"
    echo ""
    echo "🔍 VERIFICAR STATUS:"
    echo "   docker service ls | grep n8n"
    echo "   docker service logs \$(docker service ls --format '{{.Name}}' | grep n8n_editor | head -1)"
    echo ""
    echo "⏰ Aguarde ~2 minutos para os serviços inicializarem completamente"
    echo ""
    echo "🌐 Acesse: https://fluxos.$DOMAIN"
}

# Executar função principal
main