#!/bin/bash

###################################
# Script para Upgrade n8n 1.x → 2.6.4
# Modo Internal (task runner como child process)
# Mantém os mesmos 3 containers (editor + webhook + worker)
###################################

TARGET_VERSION="2.6.4"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups"
YAML_EDITOR="n8n/queue/orq_editor.yaml"
YAML_WEBHOOK="n8n/queue/orq_webhook.yaml"
YAML_WORKER="n8n/queue/orq_worker.yaml"

echo "╔══════════════════════════════════════════╗"
echo "║     UPGRADE N8N 1.x → 2.6.4             ║"
echo "║     Modo Internal (Task Runner)          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

########################################
# 2.1 Pre-flight checks
########################################

echo "🔍 Verificações iniciais..."
echo ""

# Verifica .env existe
if [ ! -f ".env" ]; then
    echo "❌ Arquivo .env não encontrado"
    echo "   Execute ./install-simple.sh primeiro"
    exit 1
fi
echo "✅ Arquivo .env encontrado"

# Verifica Docker rodando
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker não está rodando ou sem permissão"
    echo "   Execute com sudo ou verifique o Docker"
    exit 1
fi
echo "✅ Docker está rodando"

# Verifica serviços n8n ativos
if ! docker service ls 2>/dev/null | grep -q n8n; then
    echo "❌ Nenhum serviço n8n encontrado no Docker Swarm"
    echo "   Verifique se o n8n está deployado"
    exit 1
fi
echo "✅ Serviços n8n encontrados"

# Detecta versão atual da imagem
CURRENT_VERSION=$(docker service ls --format "{{.Name}} {{.Image}}" 2>/dev/null | grep n8n_editor | head -1 | awk '{print $2}' | sed 's/.*://')

if [[ -z "$CURRENT_VERSION" ]]; then
    echo "⚠️  Não foi possível detectar a versão atual"
    echo "   Continuando mesmo assim..."
    CURRENT_VERSION="desconhecida"
else
    echo "✅ Versão atual detectada: $CURRENT_VERSION"
fi

# Confirma que versão atual é 1.x (rejeita se já for 2.x)
if [[ "$CURRENT_VERSION" =~ ^2\. ]]; then
    echo ""
    echo "❌ A versão atual já é 2.x ($CURRENT_VERSION)"
    echo "   Este script é apenas para upgrade de 1.x → 2.x"
    echo "   Para atualizar entre versões 2.x, use ./update-n8n.sh"
    exit 1
fi

# Verifica YAMLs existem
for yaml_file in "$YAML_EDITOR" "$YAML_WEBHOOK" "$YAML_WORKER"; do
    if [ ! -f "$yaml_file" ]; then
        echo "❌ Arquivo $yaml_file não encontrado"
        exit 1
    fi
done
echo "✅ Arquivos YAML encontrados"

# Carregar variáveis
source .env
echo "✅ Variáveis do .env carregadas"

echo ""

########################################
# 2.2 Informação ao usuário
########################################

echo "╔══════════════════════════════════════════╗"
echo "║          RESUMO DO UPGRADE               ║"
echo "╠══════════════════════════════════════════╣"
echo "║  Versão atual:  $CURRENT_VERSION"
echo "║  Versão alvo:   $TARGET_VERSION"
echo "║  Domínio:       $DOMAIN"
echo "╠══════════════════════════════════════════╣"
echo "║  BREAKING CHANGES v2.0:                  ║"
echo "║  • Task Runner: modo internal (OK)       ║"
echo "║  • Python Code Node: removido            ║"
echo "║  • MySQL/MariaDB: removidos              ║"
echo "║  • OAuth callback requer auth            ║"
echo "║  • Docker roda como user 'node'          ║"
echo "║  • Variável deprecated removida          ║"
echo "║    (OFFLOAD_MANUAL_EXECUTIONS_TO_WORKES) ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   • Um backup do PostgreSQL será criado antes do upgrade"
echo "   • Os arquivos YAML e .env serão backupeados"
echo "   • Em caso de falha, instruções de rollback serão exibidas"
echo ""

read -p "Deseja continuar com o upgrade para n8n $TARGET_VERSION? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "❌ Upgrade cancelado pelo usuário"
    exit 0
fi

echo ""

########################################
# 2.3 Backup do PostgreSQL
########################################

echo "🗄️  Iniciando backup do PostgreSQL..."

# Cria diretório de backups se necessário
mkdir -p "$BACKUP_DIR"

# Identifica container do PostgreSQL
POSTGRES_CONTAINER=$(docker ps --filter "name=postgres" --format "{{.ID}}" | head -1)

if [[ -z "$POSTGRES_CONTAINER" ]]; then
    echo "❌ Container do PostgreSQL não encontrado"
    echo "   Não é seguro continuar sem backup"
    exit 1
fi

BACKUP_FILE="${BACKUP_DIR}/n8n_backup_${TIMESTAMP}.sql"
echo "   → Container PostgreSQL: $POSTGRES_CONTAINER"
echo "   → Backup: $BACKUP_FILE"

# Executa pg_dump
docker exec "$POSTGRES_CONTAINER" pg_dump -U postgres "${DATABASE:-n8n}" > "$BACKUP_FILE" 2>/dev/null

# Verifica que o arquivo foi criado e não está vazio
if [[ ! -f "$BACKUP_FILE" ]] || [[ ! -s "$BACKUP_FILE" ]]; then
    echo "❌ Falha ao criar backup do PostgreSQL"
    echo "   O arquivo de backup está vazio ou não foi criado"
    echo "   Não é seguro continuar sem backup"
    rm -f "$BACKUP_FILE" 2>/dev/null
    exit 1
fi

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | awk '{print $1}')
echo "✅ Backup do PostgreSQL criado com sucesso ($BACKUP_SIZE)"
echo ""

########################################
# 2.4 Backup dos YAMLs e .env
########################################

echo "📋 Criando backup dos arquivos de configuração..."

# Backup dos YAMLs
for yaml_file in "$YAML_EDITOR" "$YAML_WEBHOOK" "$YAML_WORKER"; do
    cp "$yaml_file" "${yaml_file}.backup.${TIMESTAMP}"
    echo "   ✅ ${yaml_file}.backup.${TIMESTAMP}"
done

# Backup do .env
cp .env ".env.backup.${TIMESTAMP}"
echo "   ✅ .env.backup.${TIMESTAMP}"

echo ""

########################################
# 2.5 Atualizar YAMLs via sed
########################################

echo "📝 Atualizando arquivos YAML..."

for yaml_file in "$YAML_EDITOR" "$YAML_WEBHOOK" "$YAML_WORKER"; do
    # Troca imagem para nova versão
    sed -i "s|image: n8nio/n8n:.*|image: n8nio/n8n:${TARGET_VERSION}|g" "$yaml_file"

    # Remove linha deprecated (variável com typo, removida no v2)
    sed -i "/OFFLOAD_MANUAL_EXECUTIONS_TO_WORKES/d" "$yaml_file"

    echo "   ✅ $yaml_file atualizado"
done

echo ""

########################################
# 2.6 Pull da imagem
########################################

echo "🐳 Baixando imagem n8nio/n8n:${TARGET_VERSION}..."

if ! docker pull "n8nio/n8n:${TARGET_VERSION}"; then
    echo "❌ Falha ao baixar a imagem n8nio/n8n:${TARGET_VERSION}"
    echo ""
    echo "🔄 ROLLBACK: Restaure os arquivos de backup:"
    echo "   cp ${YAML_EDITOR}.backup.${TIMESTAMP} ${YAML_EDITOR}"
    echo "   cp ${YAML_WEBHOOK}.backup.${TIMESTAMP} ${YAML_WEBHOOK}"
    echo "   cp ${YAML_WORKER}.backup.${TIMESTAMP} ${YAML_WORKER}"
    echo "   cp .env.backup.${TIMESTAMP} .env"
    exit 1
fi

echo "🔍 Validando imagem..."
if docker manifest inspect "n8nio/n8n:${TARGET_VERSION}" >/dev/null 2>&1; then
    echo "✅ Imagem n8nio/n8n:${TARGET_VERSION} validada"
else
    echo "⚠️  Não foi possível validar via manifest (pode ser normal em redes restritas)"
    echo "   A imagem foi baixada com sucesso, continuando..."
fi

echo ""

########################################
# 2.7 Export de variáveis e deploy
########################################

echo "🚀 Iniciando deploy dos serviços..."
echo ""

# Exportar variáveis necessárias
export DOMAIN DATABASE DATABASE_PASSWORD N8N_ENCRYPTION_KEY INITIAL_ADMIN_EMAIL INITIAL_ADMIN_PASSWORD

# Deploy n8n Editor primeiro
echo "   → [1/3] Deployando n8n Editor..."
docker stack deploy -c "$YAML_EDITOR" n8n_editor
echo "   ⏳ Aguardando 30s para o Editor inicializar..."
sleep 30
echo "   ✅ n8n Editor deployado"
echo ""

# Deploy n8n Webhook
echo "   → [2/3] Deployando n8n Webhook..."
docker stack deploy -c "$YAML_WEBHOOK" n8n_webhook
echo "   ⏳ Aguardando 15s para o Webhook inicializar..."
sleep 15
echo "   ✅ n8n Webhook deployado"
echo ""

# Deploy n8n Worker
echo "   → [3/3] Deployando n8n Worker..."
docker stack deploy -c "$YAML_WORKER" n8n_worker
echo "   ⏳ Aguardando 15s para o Worker inicializar..."
sleep 15
echo "   ✅ n8n Worker deployado"
echo ""

########################################
# 2.8 Health check
########################################

echo "🏥 Verificando saúde dos serviços..."
echo ""

HEALTHY=true
MAX_WAIT=60
WAIT_INTERVAL=10
ELAPSED=0

while [[ $ELAPSED -lt $MAX_WAIT ]]; do
    ALL_RUNNING=true

    for service_name in n8n_editor n8n_webhook n8n_worker; do
        REPLICAS=$(docker service ls --format "{{.Name}} {{.Replicas}}" 2>/dev/null | grep "$service_name" | head -1 | awk '{print $2}')

        if [[ "$REPLICAS" != "1/1" ]]; then
            ALL_RUNNING=false
            break
        fi
    done

    if $ALL_RUNNING; then
        break
    fi

    echo "   ⏳ Aguardando serviços ficarem prontos... (${ELAPSED}s/${MAX_WAIT}s)"
    sleep $WAIT_INTERVAL
    ELAPSED=$((ELAPSED + WAIT_INTERVAL))
done

echo ""
echo "   📋 Status dos serviços:"
for service_name in n8n_editor n8n_webhook n8n_worker; do
    REPLICAS=$(docker service ls --format "{{.Name}} {{.Replicas}}" 2>/dev/null | grep "$service_name" | head -1 | awk '{print $2}')
    if [[ "$REPLICAS" == "1/1" ]]; then
        echo "   ✅ $service_name: $REPLICAS"
    else
        echo "   ⚠️  $service_name: ${REPLICAS:-não encontrado}"
        HEALTHY=false
    fi
done

echo ""

if ! $HEALTHY; then
    echo "⚠️  ATENÇÃO: Nem todos os serviços estão com replicas 1/1"
    echo "   Isso pode ser normal se os serviços ainda estão inicializando."
    echo ""
    echo "   Verifique os logs com:"
    echo "   docker service logs \$(docker service ls --format '{{.Name}}' | grep n8n_editor)"
    echo "   docker service logs \$(docker service ls --format '{{.Name}}' | grep n8n_webhook)"
    echo "   docker service logs \$(docker service ls --format '{{.Name}}' | grep n8n_worker)"
    echo ""
fi

########################################
# 2.9 Sumário final
########################################

echo "╔══════════════════════════════════════════╗"
echo "║     UPGRADE CONCLUÍDO!                   ║"
echo "╠══════════════════════════════════════════╣"
echo "║  Versão anterior: $CURRENT_VERSION"
echo "║  Versão atual:    $TARGET_VERSION"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "🌐 ACESSO:"
echo "   • Editor:  https://fluxos.${DOMAIN}"
echo "   • Webhook: https://webhook.${DOMAIN}"
echo ""
echo "📦 BACKUPS:"
echo "   • PostgreSQL: ${BACKUP_FILE}"
echo "   • Editor:     ${YAML_EDITOR}.backup.${TIMESTAMP}"
echo "   • Webhook:    ${YAML_WEBHOOK}.backup.${TIMESTAMP}"
echo "   • Worker:     ${YAML_WORKER}.backup.${TIMESTAMP}"
echo "   • .env:       .env.backup.${TIMESTAMP}"
echo ""
echo "🔍 VERIFICAR:"
echo "   docker service ls | grep n8n"
echo "   docker service logs \$(docker service ls --format '{{.Name}}' | grep n8n_editor | head -1)"
echo ""
echo "🔄 ROLLBACK (se necessário):"
echo "   1. docker stack rm n8n_editor n8n_webhook n8n_worker"
echo "   2. cp ${YAML_EDITOR}.backup.${TIMESTAMP} ${YAML_EDITOR}"
echo "      cp ${YAML_WEBHOOK}.backup.${TIMESTAMP} ${YAML_WEBHOOK}"
echo "      cp ${YAML_WORKER}.backup.${TIMESTAMP} ${YAML_WORKER}"
echo "      cp .env.backup.${TIMESTAMP} .env"
echo "   3. source .env && export DOMAIN DATABASE DATABASE_PASSWORD N8N_ENCRYPTION_KEY INITIAL_ADMIN_EMAIL INITIAL_ADMIN_PASSWORD"
echo "   4. docker stack deploy -c ${YAML_EDITOR} n8n_editor"
echo "      docker stack deploy -c ${YAML_WEBHOOK} n8n_webhook"
echo "      docker stack deploy -c ${YAML_WORKER} n8n_worker"
echo "   5. Se banco corrompeu:"
echo "      docker exec -i \$(docker ps --filter name=postgres --format '{{.ID}}' | head -1) psql -U postgres < ${BACKUP_FILE}"
echo ""
echo "⏰ Aguarde ~2 minutos para os serviços inicializarem completamente"
echo ""
