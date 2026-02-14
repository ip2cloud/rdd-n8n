#!/bin/bash

###################################
# Rollback do Upgrade n8n v2
# Restaura automaticamente para a versao anterior
###################################

YAML_EDITOR="n8n/queue/orq_editor.yaml"
YAML_WEBHOOK="n8n/queue/orq_webhook.yaml"
YAML_WORKER="n8n/queue/orq_worker.yaml"

echo "╔══════════════════════════════════════════╗"
echo "║     ROLLBACK N8N v2 → VERSÃO ANTERIOR    ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verificar se .env existe
if [ ! -f ".env" ]; then
    echo "❌ Arquivo .env nao encontrado"
    exit 1
fi

# Verificar se Docker esta rodando
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker nao esta rodando ou sem permissao"
    exit 1
fi

# Encontrar o backup mais recente
LATEST_BACKUP=$(ls -t ${YAML_EDITOR}.backup.* 2>/dev/null | head -1)

if [[ -z "$LATEST_BACKUP" ]]; then
    echo "❌ Nenhum backup encontrado"
    echo "   Nao e possivel fazer rollback sem backups"
    exit 1
fi

# Extrair timestamp do backup
TIMESTAMP=$(echo "$LATEST_BACKUP" | sed "s|${YAML_EDITOR}.backup.||")

# Verificar se todos os backups existem
MISSING=false
for backup_file in "${YAML_EDITOR}.backup.${TIMESTAMP}" "${YAML_WEBHOOK}.backup.${TIMESTAMP}" "${YAML_WORKER}.backup.${TIMESTAMP}" ".env.backup.${TIMESTAMP}"; do
    if [[ ! -f "$backup_file" ]]; then
        echo "❌ Backup nao encontrado: $backup_file"
        MISSING=true
    fi
done

if $MISSING; then
    echo "   Nao e possivel fazer rollback com backups incompletos"
    exit 1
fi

# Detectar versao do backup
BACKUP_VERSION=$(grep -o 'image: n8nio/n8n:[^ ]*' "${YAML_EDITOR}.backup.${TIMESTAMP}" | head -1 | sed 's/image: n8nio\/n8n://')
CURRENT_VERSION=$(grep -o 'image: n8nio/n8n:[^ ]*' "$YAML_EDITOR" | head -1 | sed 's/image: n8nio\/n8n://')

echo "📋 Backup encontrado: ${TIMESTAMP}"
echo "   Versao atual:    ${CURRENT_VERSION:-desconhecida}"
echo "   Versao do backup: ${BACKUP_VERSION:-desconhecida}"
echo ""

read -p "Deseja restaurar para a versao ${BACKUP_VERSION}? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "❌ Rollback cancelado"
    exit 0
fi

echo ""

########################################
# 1. Remover servicos atuais
########################################

echo "🗑️  Removendo servicos n8n atuais..."
docker stack rm n8n_editor n8n_webhook n8n_worker 2>/dev/null
echo "   ⏳ Aguardando servicos pararem..."
sleep 15
echo "   ✅ Servicos removidos"
echo ""

########################################
# 2. Restaurar arquivos de backup
########################################

echo "📋 Restaurando arquivos de backup..."

cp "${YAML_EDITOR}.backup.${TIMESTAMP}" "$YAML_EDITOR"
echo "   ✅ orq_editor.yaml restaurado"

cp "${YAML_WEBHOOK}.backup.${TIMESTAMP}" "$YAML_WEBHOOK"
echo "   ✅ orq_webhook.yaml restaurado"

cp "${YAML_WORKER}.backup.${TIMESTAMP}" "$YAML_WORKER"
echo "   ✅ orq_worker.yaml restaurado"

cp ".env.backup.${TIMESTAMP}" ".env"
echo "   ✅ .env restaurado"

echo ""

########################################
# 3. Redeploy com versao anterior
########################################

echo "🚀 Reinstalando n8n ${BACKUP_VERSION}..."
echo ""

source .env
export DOMAIN DATABASE DATABASE_PASSWORD N8N_ENCRYPTION_KEY INITIAL_ADMIN_EMAIL INITIAL_ADMIN_PASSWORD

echo "   → [1/3] Deployando n8n Editor..."
docker stack deploy -c "$YAML_EDITOR" n8n_editor
echo "   ⏳ Aguardando 30s..."
sleep 30
echo "   ✅ Editor deployado"
echo ""

echo "   → [2/3] Deployando n8n Webhook..."
docker stack deploy -c "$YAML_WEBHOOK" n8n_webhook
echo "   ⏳ Aguardando 15s..."
sleep 15
echo "   ✅ Webhook deployado"
echo ""

echo "   → [3/3] Deployando n8n Worker..."
docker stack deploy -c "$YAML_WORKER" n8n_worker
echo "   ⏳ Aguardando 15s..."
sleep 15
echo "   ✅ Worker deployado"
echo ""

########################################
# 4. Verificar servicos
########################################

echo "🏥 Verificando servicos..."
echo ""

sleep 10

for service_name in n8n_editor n8n_webhook n8n_worker; do
    REPLICAS=$(docker service ls --format "{{.Name}} {{.Replicas}}" 2>/dev/null | grep "$service_name" | head -1 | awk '{print $2}')
    if [[ "$REPLICAS" == "1/1" ]]; then
        echo "   ✅ $service_name: $REPLICAS"
    else
        echo "   ⏳ $service_name: ${REPLICAS:-aguardando...}"
    fi
done

echo ""

########################################
# 5. Restaurar banco (opcional)
########################################

LATEST_SQL=$(ls -t backups/n8n_backup_*.sql 2>/dev/null | head -1)

if [[ -n "$LATEST_SQL" ]]; then
    echo "📦 Backup do banco disponivel: $LATEST_SQL"
    read -p "   Deseja restaurar o banco de dados tambem? (y/N): " RESTORE_DB

    if [[ "$RESTORE_DB" =~ ^[Yy]$ ]]; then
        POSTGRES_CONTAINER=$(docker ps --filter "name=postgres" --format "{{.ID}}" | head -1)
        if [[ -n "$POSTGRES_CONTAINER" ]]; then
            echo "   🗄️  Restaurando banco de dados..."
            docker exec -i "$POSTGRES_CONTAINER" psql -U postgres < "$LATEST_SQL" >/dev/null 2>&1
            echo "   ✅ Banco restaurado"
        else
            echo "   ❌ Container PostgreSQL nao encontrado"
        fi
    fi
    echo ""
fi

########################################
# Final
########################################

echo "╔══════════════════════════════════════════╗"
echo "║     ROLLBACK CONCLUÍDO!                  ║"
echo "║     Versao restaurada: ${BACKUP_VERSION}"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "🌐 Acesse o n8n: https://fluxos.${DOMAIN}"
echo ""
echo "⏰ Aguarde ~2 minutos para os servicos inicializarem"
echo ""
