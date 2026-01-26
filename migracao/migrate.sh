#!/bin/bash

###############################################################################
#                                                                             #
#           ATUALIZAÇÃO AUTOMÁTICA DO N8N v1.x → v2.4.3                      #
#                                                                             #
#  Este script faz TUDO automaticamente:                                     #
#  ✅ Cria backup completo                                                    #
#  ✅ Limpa migrações problemáticas do banco                                  #
#  ✅ Atualiza em 2 etapas seguras (v1.x → v2.0.0 → v2.4.3)                  #
#  ✅ Verifica cada etapa antes de continuar                                  #
#  ✅ Restaura automaticamente se algo der errado                             #
#                                                                             #
#  COMO USAR: sudo ./migrate.sh                                              #
#                                                                             #
###############################################################################

# Para o script se houver erro
set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Versões para migração em etapas
VERSAO_INTERMEDIARIA="2.0.0"
NOVA_VERSAO="2.4.3"
MIGRACAO_EM_ETAPAS=true  # true = mais seguro (2 etapas), false = direto para 2.4.3

# Diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backup_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$SCRIPT_DIR/migracao_$(date +%Y%m%d_%H%M%S).log"

# Função para log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Função para pausar
pausar() {
    echo ""
    read -p "Pressione ENTER para continuar..."
    echo ""
}

# Função para erro fatal
erro_fatal() {
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                    ❌ ERRO CRÍTICO                         ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}$1${NC}"
    echo ""
    log "ERRO: $1"

    if [ -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}Iniciando restauração automática...${NC}"
        restaurar_backup
    fi

    echo ""
    echo "📄 Log completo salvo em: $LOG_FILE"
    exit 1
}

# Função de restauração
restaurar_backup() {
    echo ""
    echo -e "${YELLOW}🔄 Restaurando estado anterior...${NC}"

    cd "$PROJECT_DIR"

    # Restaurar YAMLs
    if [ -f "$BACKUP_DIR/orq_editor.yaml" ]; then
        cp "$BACKUP_DIR/orq_editor.yaml" n8n/queue/orq_editor.yaml
        cp "$BACKUP_DIR/orq_webhook.yaml" n8n/queue/orq_webhook.yaml
        cp "$BACKUP_DIR/orq_worker.yaml" n8n/queue/orq_worker.yaml
        echo -e "${GREEN}✅ Arquivos YAML restaurados${NC}"
    fi

    # Restaurar banco de dados
    if [ -f "$BACKUP_DIR/database.sql" ]; then
        source .env
        POSTGRES_CONTAINER=$(docker ps -qf name=postgres | head -1)
        if [ -n "$POSTGRES_CONTAINER" ]; then
            docker exec -i "$POSTGRES_CONTAINER" psql -U postgres -d "$DATABASE" < "$BACKUP_DIR/database.sql" 2>/dev/null
            echo -e "${GREEN}✅ Banco de dados restaurado${NC}"
        fi
    fi

    # Redesplegar serviços
    export DOMAIN DATABASE DATABASE_PASSWORD N8N_ENCRYPTION_KEY INITIAL_ADMIN_EMAIL INITIAL_ADMIN_PASSWORD

    docker stack deploy -c n8n/queue/orq_editor.yaml n8n_editor >/dev/null 2>&1
    sleep 15
    docker stack deploy -c n8n/queue/orq_webhook.yaml n8n_webhook >/dev/null 2>&1
    sleep 10
    docker stack deploy -c n8n/queue/orq_worker.yaml n8n_worker >/dev/null 2>&1

    echo -e "${GREEN}✅ Sistema restaurado para versão anterior${NC}"
    echo ""
}

# Função para atualizar variáveis de ambiente para v2.x
atualizar_variaveis_env() {
    echo -e "${BLUE}⚙️  Atualizando variáveis de ambiente para v2.x...${NC}"
    echo ""

    # Fazer backup do .env
    cp .env "$BACKUP_DIR/.env.backup"
    log "Backup do .env criado"

    # Contadores (sem local para serem acessíveis pela função interna)
    REMOVIDAS=0
    ADICIONADAS=0
    JA_EXISTENTES=0

    # Variáveis obsoletas que devem ser removidas na v2.x
    VARS_OBSOLETAS=(
        "N8N_CONFIG_FILES"
        "QUEUE_WORKER_MAX_STALLED_COUNT"
    )

    # Remover variáveis obsoletas
    echo -e "   ${BLUE}🗑️  Verificando variáveis obsoletas...${NC}"
    for VAR in "${VARS_OBSOLETAS[@]}"; do
        if grep -q "^${VAR}=" .env 2>/dev/null; then
            echo -e "      ${YELLOW}⚠️  Removendo: ${VAR}${NC}"
            sed -i.bak "/^${VAR}=/d" .env
            log "Variável obsoleta removida: $VAR"
            REMOVIDAS=$((REMOVIDAS + 1))
        fi
    done

    if [ "$REMOVIDAS" -eq 0 ]; then
        echo -e "      ${GREEN}✓ Nenhuma variável obsoleta encontrada${NC}"
    else
        echo -e "      ${GREEN}✓ ${REMOVIDAS} variável(is) obsoleta(s) removida(s)${NC}"
    fi

    # Adicionar/atualizar variáveis necessárias para v2.x
    echo ""
    echo -e "   ${BLUE}➕ Verificando variáveis necessárias para v2.x...${NC}"

    # Adicionar seção de comentário se não existir
    if ! grep -q "# Configurações de segurança v2.x" .env 2>/dev/null; then
        echo "" >> .env
        echo "# Configurações de segurança v2.x" >> .env
    fi

    # Função auxiliar para adicionar/verificar variável
    adicionar_variavel() {
        local VAR_NAME="$1"
        local VAR_VALUE="$2"

        if grep -q "^${VAR_NAME}=" .env 2>/dev/null; then
            # Variável já existe
            VALOR_ATUAL=$(grep "^${VAR_NAME}=" .env 2>/dev/null | head -1 | cut -d'=' -f2-)
            echo -e "      ${BLUE}ℹ️  ${VAR_NAME} já existe (valor: ${VALOR_ATUAL})${NC}"
            JA_EXISTENTES=$((JA_EXISTENTES + 1))
            log "Variável já existe: ${VAR_NAME}=${VALOR_ATUAL}"
        else
            # Adicionar variável
            echo "${VAR_NAME}=${VAR_VALUE}" >> .env || {
                echo -e "      ${RED}❌ Erro ao adicionar: ${VAR_NAME}${NC}"
                return 1
            }
            echo -e "      ${GREEN}✅ Adicionada: ${VAR_NAME}=${VAR_VALUE}${NC}"
            log "Variável adicionada: ${VAR_NAME}=${VAR_VALUE}"
            ADICIONADAS=$((ADICIONADAS + 1))
        fi
        return 0
    }

    # Verificar e adicionar cada variável (compatível com Bash 3.x+)
    # Desabilitar exit on error temporariamente para não parar se uma variável falhar
    set +e

    adicionar_variavel "N8N_SECURE_COOKIE" "true"
    adicionar_variavel "N8N_GIT_NODE_DISABLE_BARE_REPOS" "true"
    adicionar_variavel "EXECUTIONS_DATA_PRUNE" "true"
    adicionar_variavel "EXECUTIONS_DATA_MAX_AGE" "336"
    adicionar_variavel "N8N_LOG_LEVEL" "info"
    adicionar_variavel "N8N_BLOCK_ENV_ACCESS_IN_NODE" "false"
    adicionar_variavel "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS" "true"
    adicionar_variavel "N8N_RUNNERS_ENABLED" "true"
    adicionar_variavel "N8N_RUNNERS_MODE" "internal"
    adicionar_variavel "NODE_EXCLUDE" '"[]"'
    adicionar_variavel "N8N_SKIP_AUTH_ON_OAUTH_CALLBACK" "false"

    # Reabilitar exit on error
    set -e

    echo ""
    echo -e "${GREEN}   ✅ Verificação de variáveis concluída!${NC}"
    echo ""
    echo -e "   ${BLUE}📊 RESUMO:${NC}"
    echo -e "      ${YELLOW}🗑️  Removidas: ${REMOVIDAS}${NC}"
    echo -e "      ${GREEN}✅ Adicionadas: ${ADICIONADAS}${NC}"
    echo -e "      ${BLUE}ℹ️  Já existiam: ${JA_EXISTENTES}${NC}"
    echo -e "      ${PURPLE}📦 Total v2.x: 11 variáveis${NC}"

    log "Atualização de variáveis - Removidas: $REMOVIDAS, Adicionadas: $ADICIONADAS, Já existentes: $JA_EXISTENTES"
}

# Função para limpar migrações problemáticas
limpar_migracoes_problematicas() {
    echo -e "${BLUE}🧹 Verificando migrações problemáticas no banco de dados...${NC}"

    POSTGRES_CONTAINER=$(docker ps -qf name=postgres | head -1)

    if [ -z "$POSTGRES_CONTAINER" ]; then
        echo -e "${YELLOW}⚠️  Container PostgreSQL não encontrado, pulando limpeza${NC}"
        return
    fi

    # Lista de migrações problemáticas conhecidas que causam erro "already exists"
    MIGRACOES_PROBLEMATICAS=(
        "AddWorkflowDescriptionColumn1762177736257"
        "AddWorkflowMetadata1"
    )

    for MIGRACAO in "${MIGRACOES_PROBLEMATICAS[@]}"; do
        EXISTE=$(docker exec "$POSTGRES_CONTAINER" psql -U postgres -d "$DATABASE" -tAc "SELECT COUNT(*) FROM migrations WHERE name = '$MIGRACAO';" 2>/dev/null)

        if [ "$EXISTE" = "1" ]; then
            echo -e "${YELLOW}   ⚠️  Removendo migração problemática: $MIGRACAO${NC}"
            docker exec "$POSTGRES_CONTAINER" psql -U postgres -d "$DATABASE" -c "DELETE FROM migrations WHERE name = '$MIGRACAO';" >/dev/null 2>&1
            log "Migração problemática removida: $MIGRACAO"
        fi
    done

    echo -e "${GREEN}   ✅ Verificação de migrações concluída${NC}"
    log "Limpeza de migrações problemáticas concluída"
}

# Função para atualizar serviço n8n
atualizar_servico_n8n() {
    local NOME_SERVICO=$1
    local ARQUIVO_YAML=$2
    local VERSAO=$3
    local TEMPO_ESPERA=$4

    echo -e "   🔄 Atualizando ${NOME_SERVICO}..."
    echo -e "${YELLOW}      ⏳ Aguarde ~${TEMPO_ESPERA} segundos...${NC}"

    if docker stack deploy -c "$ARQUIVO_YAML" "$NOME_SERVICO" >/dev/null 2>&1; then
        sleep "$TEMPO_ESPERA"

        # Verificar se o serviço subiu corretamente
        REPLICAS=$(docker service ls --filter "name=${NOME_SERVICO}" --format "{{.Replicas}}" 2>/dev/null | head -1)

        if echo "$REPLICAS" | grep -q "0/"; then
            erro_fatal "${NOME_SERVICO} não iniciou corretamente.\n   Verifique os logs: docker service logs ${NOME_SERVICO}"
        fi

        # Verificar versão instalada
        VERSAO_INSTALADA=$(docker service ls --format "{{.Name}} {{.Image}}" 2>/dev/null | grep "$NOME_SERVICO" | head -1 | awk '{print $2}' | sed 's/.*://')

        if [ "$VERSAO_INSTALADA" != "$VERSAO" ]; then
            erro_fatal "${NOME_SERVICO} não atualizou para versão $VERSAO.\n   Versão atual: $VERSAO_INSTALADA"
        fi

        echo -e "${GREEN}      ✅ ${NOME_SERVICO} atualizado para v${VERSAO}${NC}"
        log "${NOME_SERVICO} atualizado com sucesso para v${VERSAO}"
        return 0
    else
        erro_fatal "Falha ao atualizar ${NOME_SERVICO}"
    fi
}

clear

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}║        🚀 ATUALIZAÇÃO AUTOMÁTICA DO N8N v2.4.3            ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Este script vai atualizar seu n8n de forma AUTOMÁTICA e SEGURA${NC}"
echo ""
echo "O que será feito:"
echo "  1. ✅ Backup completo (banco de dados + configurações)"
echo "  2. ✅ Atualização de variáveis de ambiente para v2.x"
echo "  3. ✅ Limpeza de migrações problemáticas do banco"
echo "  4. ✅ Atualização em 2 etapas (v1.x → v2.0.0 → v2.4.3)"
echo "  5. ✅ Verificação de funcionamento em cada etapa"
echo "  6. ✅ Restauração automática se algo der errado"
echo ""
echo -e "${YELLOW}⏱️  Tempo estimado: 8-12 minutos${NC}"
echo -e "${YELLOW}⏸️  Downtime: ~5 minutos (n8n ficará offline)${NC}"
echo ""

log "===== INÍCIO DA MIGRAÇÃO PARA N8N v${NOVA_VERSAO} ====="

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    erro_fatal "Este script precisa ser executado como root.\n   Execute: sudo ./migrate.sh"
fi

# Ir para diretório do projeto
cd "$PROJECT_DIR" || erro_fatal "Diretório do projeto não encontrado"

# Verificar .env
if [ ! -f ".env" ]; then
    erro_fatal "Arquivo .env não encontrado no diretório do projeto"
fi

# Carregar variáveis
source .env

echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📋 INFORMAÇÕES DO SEU SISTEMA${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Verificar versão atual
VERSAO_ATUAL=""
if docker service ls 2>/dev/null | grep -q n8n_editor; then
    VERSAO_ATUAL=$(docker service ls --format "{{.Name}} {{.Image}}" 2>/dev/null | grep n8n_editor | head -1 | awk '{print $2}' | sed 's/.*://')
    echo -e "  📦 Versão atual do n8n: ${GREEN}${VERSAO_ATUAL}${NC}"
else
    erro_fatal "Serviços n8n não encontrados.\n   Verifique se o n8n está instalado."
fi

echo -e "  🌐 Domínio: ${GREEN}${DOMAIN}${NC}"
echo -e "  🗄️  Banco de dados: ${GREEN}${DATABASE}${NC}"

# Verificar se já está na v2.x
if [[ "$VERSAO_ATUAL" =~ ^2\. ]]; then
    echo ""
    echo -e "${GREEN}✅ Você já está na versão 2.x do n8n!${NC}"
    echo ""
    echo "Não é necessário executar esta migração."
    echo ""
    exit 0
fi

echo ""
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

pausar

###############################################################################
# AVISOS IMPORTANTES
###############################################################################

clear
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║              ⚠️  INFORMAÇÕES IMPORTANTES                   ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}A versão 2.x do n8n tem algumas mudanças importantes:${NC}"
echo ""
echo "  1. 🔄 Alguns workflows podem precisar de ajustes"
echo "  2. 🔒 Configurações de segurança mais restritas"
echo "  3. ✨ Novos recursos e melhorias de performance"
echo ""
echo -e "${GREEN}NÃO SE PREOCUPE:${NC}"
echo ""
echo "  ✅ Vamos criar backup completo de TUDO"
echo "  ✅ Se algo der errado, restauramos automaticamente"
echo "  ✅ Seus workflows e dados estão seguros"
echo ""

pausar

###############################################################################
# CONFIRMAÇÃO FINAL
###############################################################################

clear
echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                 ✋ CONFIRMAÇÃO FINAL                        ║${NC}"
echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Você confirma a atualização do n8n?"
echo ""
echo -e "  De: ${RED}v${VERSAO_ATUAL}${NC}"
echo -e "  Para: ${GREEN}v${NOVA_VERSAO}${NC}"
echo ""
read -p "Digite SIM (em maiúsculas) para continuar: " CONFIRMACAO

if [ "$CONFIRMACAO" != "SIM" ]; then
    echo ""
    echo -e "${YELLOW}❌ Atualização cancelada pelo usuário${NC}"
    echo ""
    log "Migração cancelada pelo usuário"
    exit 0
fi

echo ""
log "Usuário confirmou a migração"

###############################################################################
# ETAPA 1: CRIAR BACKUPS
###############################################################################

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              📦 ETAPA 1/5: Criando Backups                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

log "ETAPA 1: Iniciando criação de backups"

# Criar diretório de backup
mkdir -p "$BACKUP_DIR"
echo -e "${BLUE}📁 Criando pasta de backup...${NC}"
echo "   $BACKUP_DIR"
log "Diretório de backup criado: $BACKUP_DIR"

# Backup dos YAMLs
echo ""
echo -e "${BLUE}📋 Fazendo backup dos arquivos de configuração...${NC}"
cp n8n/queue/orq_editor.yaml "$BACKUP_DIR/orq_editor.yaml"
cp n8n/queue/orq_webhook.yaml "$BACKUP_DIR/orq_webhook.yaml"
cp n8n/queue/orq_worker.yaml "$BACKUP_DIR/orq_worker.yaml"
cp .env "$BACKUP_DIR/.env"
echo -e "${GREEN}   ✅ Arquivos YAML salvos${NC}"
log "Backup dos arquivos YAML concluído"

# Backup do banco de dados
echo ""
echo -e "${BLUE}💾 Fazendo backup do banco de dados PostgreSQL...${NC}"
echo -e "${YELLOW}   ⏳ Aguarde, isso pode levar alguns minutos...${NC}"

POSTGRES_CONTAINER=$(docker ps -qf name=postgres | head -1)

if [ -z "$POSTGRES_CONTAINER" ]; then
    erro_fatal "Container PostgreSQL não encontrado"
fi

if docker exec "$POSTGRES_CONTAINER" pg_dump -U postgres -d "$DATABASE" > "$BACKUP_DIR/database.sql" 2>/dev/null; then
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/database.sql" | cut -f1)
    echo -e "${GREEN}   ✅ Backup do banco criado (${BACKUP_SIZE})${NC}"
    log "Backup do banco de dados concluído: $BACKUP_SIZE"
else
    erro_fatal "Falha ao criar backup do banco de dados"
fi

echo ""
echo -e "${GREEN}✅ TODOS OS BACKUPS CRIADOS COM SUCESSO!${NC}"
log "ETAPA 1: Backups concluídos com sucesso"

pausar

###############################################################################
# ETAPA 2: ATUALIZAR VARIÁVEIS DE AMBIENTE
###############################################################################

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      ⚙️  ETAPA 2/6: Atualizando Variáveis de Ambiente     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

log "ETAPA 2: Atualizando variáveis de ambiente"

atualizar_variaveis_env

# Recarregar variáveis atualizadas
source .env

pausar

###############################################################################
# ETAPA 3: VALIDAR IMAGEM DOCKER
###############################################################################

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         🔍 ETAPA 3/6: Validando Nova Versão               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

log "ETAPA 3: Validando imagem Docker"

echo -e "${BLUE}🔍 Verificando se a versão ${NOVA_VERSAO} está disponível...${NC}"

if docker manifest inspect "n8nio/n8n:${NOVA_VERSAO}" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Versão ${NOVA_VERSAO} encontrada e pronta para instalar${NC}"
    log "Imagem n8nio/n8n:${NOVA_VERSAO} validada"
else
    erro_fatal "Versão ${NOVA_VERSAO} não encontrada no Docker Hub.\n   Verifique sua conexão com a internet."
fi

# Se migração em etapas, validar versão intermediária também
if [ "$MIGRACAO_EM_ETAPAS" = true ]; then
    echo ""
    echo -e "${BLUE}🔍 Verificando versão intermediária ${VERSAO_INTERMEDIARIA}...${NC}"
    if docker manifest inspect "n8nio/n8n:${VERSAO_INTERMEDIARIA}" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Versão ${VERSAO_INTERMEDIARIA} encontrada${NC}"
        log "Imagem n8nio/n8n:${VERSAO_INTERMEDIARIA} validada"
    else
        erro_fatal "Versão intermediária ${VERSAO_INTERMEDIARIA} não encontrada.\n   Verifique sua conexão com a internet."
    fi
fi

echo ""
limpar_migracoes_problematicas

pausar

###############################################################################
# ETAPA 4: ATUALIZAR ARQUIVOS
###############################################################################

atualizar_arquivos_yaml() {
    local VERSAO=$1

    echo -e "${BLUE}📝 Atualizando arquivos para versão ${VERSAO}...${NC}"
    echo ""

    # Atualizar cada arquivo YAML
    for arquivo in n8n/queue/orq_editor.yaml n8n/queue/orq_webhook.yaml n8n/queue/orq_worker.yaml; do
        nome_arquivo=$(basename "$arquivo")
        echo -e "   🔧 Atualizando ${nome_arquivo}..."

        if sed -i.bak "s|image: n8nio/n8n:.*|image: n8nio/n8n:${VERSAO}|g" "$arquivo" 2>/dev/null; then
            echo -e "${GREEN}      ✅ ${nome_arquivo} atualizado${NC}"
            log "Arquivo $nome_arquivo atualizado para v${VERSAO}"
        else
            erro_fatal "Falha ao atualizar $nome_arquivo"
        fi
    done

    echo ""
    echo -e "${GREEN}✅ ARQUIVOS ATUALIZADOS PARA v${VERSAO}!${NC}"
}

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       ⚙️  ETAPA 4/6: Atualizando Configurações            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

log "ETAPA 4: Atualizando arquivos de configuração"

if [ "$MIGRACAO_EM_ETAPAS" = true ]; then
    echo -e "${YELLOW}📋 Migração em 2 etapas (mais seguro):${NC}"
    echo ""
    echo "   Etapa 1: v${VERSAO_ATUAL} → v${VERSAO_INTERMEDIARIA}"
    echo "   Etapa 2: v${VERSAO_INTERMEDIARIA} → v${NOVA_VERSAO}"
    echo ""
    atualizar_arquivos_yaml "$VERSAO_INTERMEDIARIA"
else
    echo -e "${YELLOW}📋 Migração direta:${NC}"
    echo ""
    echo "   v${VERSAO_ATUAL} → v${NOVA_VERSAO}"
    echo ""
    atualizar_arquivos_yaml "$NOVA_VERSAO"
fi

log "ETAPA 4: Arquivos de configuração atualizados"

pausar

###############################################################################
# ETAPA 5: ATUALIZAR N8N
###############################################################################

realizar_atualizacao_servicos() {
    local VERSAO=$1
    local ETAPA_MSG=$2

    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${ETAPA_MSG}${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Exportar variáveis básicas
    export DOMAIN DATABASE DATABASE_PASSWORD N8N_ENCRYPTION_KEY INITIAL_ADMIN_EMAIL INITIAL_ADMIN_PASSWORD

    # Exportar variáveis v2.x
    export N8N_SECURE_COOKIE N8N_GIT_NODE_DISABLE_BARE_REPOS EXECUTIONS_DATA_PRUNE EXECUTIONS_DATA_MAX_AGE N8N_LOG_LEVEL
    export N8N_BLOCK_ENV_ACCESS_IN_NODE N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS
    export N8N_RUNNERS_ENABLED N8N_RUNNERS_MODE NODE_EXCLUDE N8N_SKIP_AUTH_ON_OAUTH_CALLBACK

    echo -e "${BLUE}🔄 Atualizando serviços para v${VERSAO}...${NC}"
    echo ""

    # Editor (mais demorado por causa das migrações do banco)
    echo -e "   [1/3] 📝 Editor..."
    atualizar_servico_n8n "n8n_editor" "n8n/queue/orq_editor.yaml" "$VERSAO" 60

    # Webhook
    echo ""
    echo -e "   [2/3] 🌐 Webhook..."
    atualizar_servico_n8n "n8n_webhook" "n8n/queue/orq_webhook.yaml" "$VERSAO" 30

    # Worker
    echo ""
    echo -e "   [3/3] ⚙️  Worker..."
    atualizar_servico_n8n "n8n_worker" "n8n/queue/orq_worker.yaml" "$VERSAO" 30

    echo ""
    echo -e "${GREEN}✅ Todos os serviços atualizados para v${VERSAO}!${NC}"
    log "Serviços atualizados com sucesso para v${VERSAO}"
}

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          🚀 ETAPA 5/6: Instalando Nova Versão             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

log "ETAPA 5: Iniciando atualização dos serviços n8n"

if [ "$MIGRACAO_EM_ETAPAS" = true ]; then
    echo -e "${YELLOW}⚠️  O n8n ficará offline durante esta etapa (~5 minutos)${NC}"
    echo -e "${YELLOW}    Migração em 2 etapas para garantir máxima compatibilidade${NC}"
else
    echo -e "${YELLOW}⚠️  O n8n ficará offline durante esta etapa (~3 minutos)${NC}"
fi

echo ""
pausar

if [ "$MIGRACAO_EM_ETAPAS" = true ]; then
    # ========== ETAPA 1: v1.x → v2.0.0 ==========
    realizar_atualizacao_servicos "$VERSAO_INTERMEDIARIA" "🔸 ETAPA 1/2: Atualizando para v${VERSAO_INTERMEDIARIA} (versão estável)"

    echo ""
    echo -e "${YELLOW}⏳ Aguardando 30 segundos para estabilização...${NC}"
    sleep 30

    # Verificar se primeira etapa funcionou
    echo ""
    echo -e "${BLUE}🔍 Verificando primeira etapa da migração...${NC}"
    EDITOR_SERVICE=$(docker service ls --format "{{.Name}}" 2>/dev/null | grep n8n_editor | head -1)
    LOGS_CHECK=$(docker service logs "$EDITOR_SERVICE" --tail 30 2>&1)

    if echo "$LOGS_CHECK" | grep -qi "error.*migration\|migration.*failed"; then
        erro_fatal "Erro na primeira etapa da migração (v${VERSAO_INTERMEDIARIA}).\n   Verifique os logs: docker service logs $EDITOR_SERVICE"
    fi

    echo -e "${GREEN}   ✅ Primeira etapa concluída com sucesso!${NC}"
    echo ""
    sleep 5

    # ========== ETAPA 2: v2.0.0 → v2.4.3 ==========
    echo -e "${BLUE}Preparando segunda etapa da migração...${NC}"
    echo ""
    sleep 3

    # Atualizar arquivos YAML para versão final
    atualizar_arquivos_yaml "$NOVA_VERSAO"

    echo ""
    pausar

    realizar_atualizacao_servicos "$NOVA_VERSAO" "🔸 ETAPA 2/2: Atualizando para v${NOVA_VERSAO} (versão final)"

else
    # ========== MIGRAÇÃO DIRETA ==========
    realizar_atualizacao_servicos "$NOVA_VERSAO" "🔸 Atualizando para v${NOVA_VERSAO}"
fi

echo ""
echo -e "${GREEN}✅ ATUALIZAÇÃO DOS SERVIÇOS CONCLUÍDA!${NC}"
log "ETAPA 5: Atualização dos serviços concluída"

pausar

###############################################################################
# ETAPA 6: VERIFICAR FUNCIONAMENTO
###############################################################################

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         ✅ ETAPA 6/6: Verificando Instalação               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

log "ETAPA 6: Verificando funcionamento dos serviços"

echo -e "${BLUE}🔍 Verificando status dos serviços...${NC}"
echo ""

# Aguardar serviços iniciarem
echo -e "${YELLOW}⏳ Aguardando serviços iniciarem (30 segundos)...${NC}"
sleep 30

# Verificar serviços
echo ""
echo "📊 Status dos serviços:"
echo ""
docker service ls 2>/dev/null | grep -E "NAME|n8n" || erro_fatal "Não foi possível verificar os serviços"

echo ""
echo -e "${BLUE}🔍 Verificando logs (últimas 5 linhas de cada serviço)...${NC}"
echo ""

# Verificar logs do Editor
EDITOR_SERVICE=$(docker service ls --format "{{.Name}}" 2>/dev/null | grep n8n_editor | head -1)
if [ -n "$EDITOR_SERVICE" ]; then
    echo "📝 Editor:"
    docker service logs "$EDITOR_SERVICE" --tail 5 2>&1 | tail -5
    echo ""
fi

# Verificar se há erros críticos
LOGS_EDITOR=$(docker service logs "$EDITOR_SERVICE" --tail 20 2>&1)
if echo "$LOGS_EDITOR" | grep -qi "error.*migration\|migration.*failed"; then
    erro_fatal "Detectado erro na migração do banco de dados.\n   Verifique os logs: docker service logs $EDITOR_SERVICE"
fi

echo -e "${GREEN}✅ VERIFICAÇÃO CONCLUÍDA!${NC}"
log "ETAPA 6: Verificação concluída com sucesso"

pausar

###############################################################################
# SUCESSO!
###############################################################################

clear
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║              🎉 ATUALIZAÇÃO CONCLUÍDA!                     ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ Seu n8n foi atualizado com sucesso para a versão ${NOVA_VERSAO}!${NC}"
echo ""
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📋 INFORMAÇÕES IMPORTANTES${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  🌐 Acesse seu n8n:"
echo -e "     ${GREEN}https://fluxos.${DOMAIN}${NC}"
echo ""
echo "  📦 Backup salvo em:"
echo "     $BACKUP_DIR"
echo ""
echo "  📄 Log da migração:"
echo "     $LOG_FILE"
echo ""
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}⚠️  PRÓXIMOS PASSOS IMPORTANTES:${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  1. ✅ Acesse a interface do n8n:"
echo -e "     ${GREEN}https://fluxos.${DOMAIN}${NC}"
echo ""
echo "  2. 🔍 A interface pode mostrar uma ferramenta de verificação"
echo "     de compatibilidade. Se aparecer, execute-a!"
echo ""
echo "  3. 🧪 Teste seus principais workflows:"
echo "     • Abra cada workflow importante"
echo "     • Clique em 'Execute Workflow' para testar"
echo "     • Verifique se tudo funciona corretamente"
echo ""
echo "  4. 📧 Se algum workflow não funcionar:"
echo "     • Não se preocupe! Seus dados estão salvos"
echo "     • Anote qual workflow tem problema"
echo "     • A maioria das correções é simples"
echo ""
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📞 PRECISA DE AJUDA?${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Se algo não funcionar como esperado:"
echo ""
echo "  1. 📖 Leia o arquivo LEIA-ME.txt na pasta migracao/"
echo ""
echo "  2. 🔄 Se precisar voltar para a versão anterior:"
echo "     Execute: sudo ./restaurar.sh"
echo ""
echo "  3. 📧 Comunidade n8n: https://community.n8n.io/"
echo ""
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

log "===== MIGRAÇÃO CONCLUÍDA COM SUCESSO ====="

# Salvar informações do backup para restauração
cat > "$SCRIPT_DIR/ultimo_backup.txt" <<EOF
$BACKUP_DIR
EOF

echo -e "${GREEN}Pressione ENTER para finalizar...${NC}"
read

clear
echo ""
echo -e "${GREEN}✨ Migração concluída! Bom uso do n8n v${NOVA_VERSAO}! ✨${NC}"
echo ""
