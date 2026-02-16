#!/bin/bash

###################################
# Script de Backup n8n
# Banco de Dados n8n + Variáveis de Ambiente
# Suporta execução manual e agendamento automático via cron
###################################

# Cores (desabilita se não for terminal interativo)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    GREEN='' RED='' YELLOW='' CYAN='' NC=''
fi

# Diretório do script (referência absoluta para funcionar no cron)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "$0")"
LOG_DIR="$SCRIPT_DIR/backups/logs"
CRON_MARKER="# n8n-backup-auto"

# Funções de output
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error()   { echo -e "${RED}✗ $1${NC}"; }
print_info()    { echo -e "${YELLOW}→ $1${NC}"; }
print_header()  { echo -e "${CYAN}$1${NC}"; }

# Função de log (grava no arquivo e exibe no terminal)
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"
}

log_success() { log "OK: $1";    print_success "$1"; }
log_error()   { log "ERRO: $1";  print_error "$1"; }
log_info()    { log "INFO: $1";  print_info "$1"; }

########################################
# Detectar modo de execução
########################################

# --auto é passado pelo cron para pular interações
AUTO_MODE=false
if [ "$1" = "--auto" ]; then
    AUTO_MODE=true
fi

########################################
# Banner
########################################

if [ "$AUTO_MODE" = false ]; then
    echo "╔══════════════════════════════════════════╗"
    echo "║           BACKUP N8N                     ║"
    echo "║   Banco de Dados + Variáveis de Ambiente ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
fi

########################################
# Verificações iniciais
########################################

cd "$SCRIPT_DIR"

if [ ! -f ".env" ]; then
    print_error "Arquivo .env não encontrado"
    echo "   Execute ./install-simple.sh primeiro"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    print_error "Docker não está rodando ou sem permissão"
    echo "   Execute com sudo ou verifique o Docker"
    exit 1
fi

if ! docker service ls 2>/dev/null | grep -q postgres; then
    print_error "Serviço PostgreSQL não encontrado no Docker Swarm"
    exit 1
fi

# Carregar variáveis
source .env

########################################
# Preparar diretórios e log
########################################

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$SCRIPT_DIR/backups/$TIMESTAMP"

mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/backup_${TIMESTAMP}.log"
touch "$LOG_FILE"

log "========================================="
log "BACKUP INICIADO"
log "Domínio: ${DOMAIN:-não definido}"
log "Banco n8n: ${DATABASE:-n8n}"
log "Modo: $([ "$AUTO_MODE" = true ] && echo 'AUTOMÁTICO (cron)' || echo 'MANUAL')"
log "========================================="

if [ "$AUTO_MODE" = false ]; then
    print_success "Configurações carregadas do .env"
    echo ""
fi

########################################
# Função: verificar status do cron
########################################

cron_exists() {
    crontab -l 2>/dev/null | grep -q "$CRON_MARKER"
}

cron_get_schedule() {
    crontab -l 2>/dev/null | grep "$CRON_MARKER" | awk '{print $1, $2, $3, $4, $5}'
}

########################################
# Função: mostrar status do backup automático
########################################

show_cron_status() {
    if cron_exists; then
        local schedule
        schedule=$(cron_get_schedule)
        print_success "Backup automático ATIVO"
        echo "   Agendamento: $schedule"

        # Mostrar último backup automático do log
        local last_auto
        last_auto=$(grep -l "AUTOMÁTICO (cron)" "$LOG_DIR"/*.log 2>/dev/null | sort | tail -1)
        if [ -n "$last_auto" ]; then
            local last_date
            last_date=$(basename "$last_auto" | sed 's/backup_//;s/\.log//')
            local formatted
            formatted=$(echo "$last_date" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
            echo "   Último backup automático: $formatted"

            # Verificar se teve erro
            if grep -q "ERRO:" "$last_auto" 2>/dev/null; then
                print_error "O último backup automático teve erros!"
                echo "   Log: $last_auto"
            else
                print_success "Último backup automático concluído sem erros"
            fi
        fi
    else
        print_info "Backup automático NÃO configurado"
    fi
    echo ""
}

########################################
# Função: configurar cron
########################################

setup_cron() {
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║     AGENDAMENTO DE BACKUP AUTOMÁTICO     ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "Escolha o horário do backup diário:"
    echo ""
    echo "  1) 02:00 (Recomendado - madrugada)"
    echo "  2) 03:00"
    echo "  3) 04:00"
    echo "  4) 06:00"
    echo "  5) Horário personalizado"
    echo ""
    read -rp "Opção [1]: " CRON_OPTION
    CRON_OPTION=${CRON_OPTION:-1}

    local CRON_HOUR CRON_MIN

    case "$CRON_OPTION" in
        1) CRON_HOUR=2;  CRON_MIN=0 ;;
        2) CRON_HOUR=3;  CRON_MIN=0 ;;
        3) CRON_HOUR=4;  CRON_MIN=0 ;;
        4) CRON_HOUR=6;  CRON_MIN=0 ;;
        5)
            read -rp "Hora (0-23): " CRON_HOUR
            read -rp "Minuto (0-59): " CRON_MIN
            # Validar
            if ! [[ "$CRON_HOUR" =~ ^[0-9]+$ ]] || [ "$CRON_HOUR" -gt 23 ]; then
                print_error "Hora inválida. Usando 02:00"
                CRON_HOUR=2; CRON_MIN=0
            fi
            if ! [[ "$CRON_MIN" =~ ^[0-9]+$ ]] || [ "$CRON_MIN" -gt 59 ]; then
                CRON_MIN=0
            fi
            ;;
        *) CRON_HOUR=2; CRON_MIN=0 ;;
    esac

    local CRON_ENTRY="$CRON_MIN $CRON_HOUR * * * $SCRIPT_PATH --auto >> $LOG_DIR/cron_output.log 2>&1 $CRON_MARKER"

    # Remover entrada antiga se existir
    local CURRENT_CRON
    CURRENT_CRON=$(crontab -l 2>/dev/null | grep -v "$CRON_MARKER" || true)

    # Adicionar nova entrada
    echo "$CURRENT_CRON
$CRON_ENTRY" | crontab -

    echo ""
    print_success "Backup automático configurado!"
    echo "   Horário: todos os dias às $(printf '%02d:%02d' $CRON_HOUR $CRON_MIN)"
    echo "   Logs em: $LOG_DIR/"
    echo ""

    log "Cron configurado: $CRON_MIN $CRON_HOUR * * *"
}

########################################
# Função: remover cron
########################################

remove_cron() {
    local CURRENT_CRON
    CURRENT_CRON=$(crontab -l 2>/dev/null | grep -v "$CRON_MARKER" || true)
    echo "$CURRENT_CRON" | crontab -
    print_success "Backup automático removido"
    log "Cron removido"
}

########################################
# Gerenciamento do cron (apenas modo interativo)
########################################

if [ "$AUTO_MODE" = false ]; then
    show_cron_status

    if ! cron_exists; then
        echo "╔══════════════════════════════════════════╗"
        echo "║  Deseja configurar backup automático?    ║"
        echo "╚══════════════════════════════════════════╝"
        echo ""
        echo "  O backup será executado diariamente via cron."
        echo "  Você pode alterar ou remover depois."
        echo ""
        read -rp "Configurar backup automático? (s/N): " SETUP_CRON

        if [[ "$SETUP_CRON" =~ ^[sS]$ ]]; then
            setup_cron
        else
            print_info "Ok, executando backup manual..."
            echo ""
        fi
    else
        echo "  1) Manter agendamento atual"
        echo "  2) Alterar horário"
        echo "  3) Remover backup automático"
        echo ""
        read -rp "Opção [1]: " CRON_ACTION
        CRON_ACTION=${CRON_ACTION:-1}

        case "$CRON_ACTION" in
            2) setup_cron ;;
            3) remove_cron; echo "" ;;
            *) echo "" ;;
        esac
    fi
fi

########################################
# Identificar container do PostgreSQL
########################################

log_info "Localizando container do PostgreSQL..."

POSTGRES_CONTAINER=$(docker ps --filter "name=postgres" --format "{{.ID}}" | head -1)

if [ -z "$POSTGRES_CONTAINER" ]; then
    log_error "Container do PostgreSQL não encontrado"
    exit 1
fi

log_success "Container PostgreSQL: $POSTGRES_CONTAINER"
if [ "$AUTO_MODE" = false ]; then echo ""; fi

########################################
# Backup das variáveis de ambiente
########################################

log_info "Fazendo backup das variáveis de ambiente..."

cp .env "$BACKUP_DIR/env_backup.env"
log_success "Arquivo .env salvo"

if [ -f "/etc/n8n-installer/smtp.conf" ]; then
    cp /etc/n8n-installer/smtp.conf "$BACKUP_DIR/smtp.conf"
    log_success "Arquivo smtp.conf salvo"
fi

# Backup da configuração dos serviços n8n em execução no Docker
log_info "Fazendo backup da configuração dos serviços n8n (Docker)..."

SERVICES_BACKUP_DIR="$BACKUP_DIR/services"
mkdir -p "$SERVICES_BACKUP_DIR"

N8N_SERVICES_FOUND=0
for service in $(docker service ls --format "{{.Name}}" 2>/dev/null | grep -i n8n); do
    docker service inspect "$service" --pretty > "$SERVICES_BACKUP_DIR/${service}.txt" 2>/dev/null
    docker service inspect "$service" > "$SERVICES_BACKUP_DIR/${service}.json" 2>/dev/null
    N8N_SERVICES_FOUND=$((N8N_SERVICES_FOUND + 1))
done

if [ "$N8N_SERVICES_FOUND" -gt 0 ]; then
    log_success "Configuração de $N8N_SERVICES_FOUND serviço(s) n8n salva"
else
    log_error "Nenhum serviço n8n encontrado no Docker Swarm"
fi
if [ "$AUTO_MODE" = false ]; then echo ""; fi

########################################
# Backup do banco de dados n8n
########################################

log_info "Fazendo backup do banco de dados: ${DATABASE:-n8n}..."

docker exec "$POSTGRES_CONTAINER" pg_dump \
    -U postgres \
    -d "${DATABASE:-n8n}" \
    --format=custom \
    --compress=9 \
    --verbose \
    2>"$BACKUP_DIR/n8n_dump.log" \
    > "$BACKUP_DIR/n8n_backup.dump"

if [ $? -eq 0 ] && [ -s "$BACKUP_DIR/n8n_backup.dump" ]; then
    N8N_SIZE=$(du -h "$BACKUP_DIR/n8n_backup.dump" | cut -f1)
    log_success "Banco n8n salvo ($N8N_SIZE)"
else
    log_error "Falha no backup do banco n8n (ver: $BACKUP_DIR/n8n_dump.log)"
fi

########################################
# Limpeza de backups antigos (manter últimos 7)
########################################

BACKUP_COUNT=$(find "$SCRIPT_DIR/backups" -maxdepth 1 -mindepth 1 -type d -not -name "logs" | wc -l)

if [ "$BACKUP_COUNT" -gt 15 ]; then
    log_info "Removendo backups antigos (mantendo os 15 mais recentes)..."
    find "$SCRIPT_DIR/backups" -maxdepth 1 -mindepth 1 -type d -not -name "logs" | sort | head -n -15 | xargs rm -rf
    log_success "Backups antigos removidos"
fi

# Limpar logs antigos (manter últimos 30)
LOG_COUNT=$(find "$LOG_DIR" -name "backup_*.log" 2>/dev/null | wc -l)

if [ "$LOG_COUNT" -gt 30 ]; then
    find "$LOG_DIR" -name "backup_*.log" | sort | head -n -30 | xargs rm -f
    log "Logs antigos removidos (mantidos os 30 mais recentes)"
fi

########################################
# Resumo final
########################################

TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

# Verificar se houve erros
ERRORS=$(grep -c "ERRO:" "$LOG_FILE" 2>/dev/null || echo "0")

log "========================================="
log "BACKUP FINALIZADO"
log "Diretório: $BACKUP_DIR"
log "Tamanho: $TOTAL_SIZE"
log "Erros: $ERRORS"
log "========================================="

if [ "$AUTO_MODE" = false ]; then
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║           BACKUP CONCLUÍDO               ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "📁 Local: $BACKUP_DIR"
    echo "📦 Tamanho total: $TOTAL_SIZE"
    echo "📋 Log: $LOG_FILE"
    echo ""
    echo "📋 Arquivos gerados:"
    echo "   • env_backup.env          - Variáveis de ambiente"
    [ -f "$BACKUP_DIR/smtp.conf" ] && \
    echo "   • smtp.conf               - Configuração SMTP"
    echo "   • services/               - Configuração dos serviços n8n (Docker)"
    echo "   • n8n_backup.dump         - Banco de dados n8n"
    echo ""

    if [ "$ERRORS" -gt 0 ]; then
        print_error "Backup concluído com $ERRORS erro(s). Verifique o log!"
    else
        print_success "Backup finalizado com sucesso!"
    fi

    echo ""
    echo "🔄 Para restaurar o banco n8n:"
    echo "   docker exec -i CONTAINER pg_restore -U postgres -d ${DATABASE:-n8n} --clean < n8n_backup.dump"
    echo ""
    echo "📊 Para ver logs de backups anteriores:"
    echo "   ls -la $LOG_DIR/"
    echo ""
fi

# Exit code baseado em erros
[ "$ERRORS" -gt 0 ] && exit 1 || exit 0
