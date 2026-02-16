#!/bin/bash

###################################
# Rollback do Upgrade n8n v2
# Restaura automaticamente para a versao anterior
###################################

YAML_EDITOR="n8n/queue/orq_editor.yaml"
YAML_WEBHOOK="n8n/queue/orq_webhook.yaml"
YAML_WORKER="n8n/queue/orq_worker.yaml"
BACKUP_DIR="backups"

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

# Encontrar o backup mais recente pelo .env.backup ou SQL backup
LATEST_ENV_BACKUP=$(ls -t .env.backup.* 2>/dev/null | head -1)
LATEST_SQL_BACKUP=$(ls -t ${BACKUP_DIR}/n8n_backup_*.sql 2>/dev/null | head -1)

if [[ -z "$LATEST_ENV_BACKUP" ]] && [[ -z "$LATEST_SQL_BACKUP" ]]; then
    echo "❌ Nenhum backup encontrado"
    echo "   Nao e possivel fazer rollback sem backups"
    exit 1
fi

# Extrair timestamp do backup do .env
if [[ -n "$LATEST_ENV_BACKUP" ]]; then
    TIMESTAMP=$(echo "$LATEST_ENV_BACKUP" | sed 's|.env.backup.||')
fi

# Verificar que os YAMLs v1 existem para rollback
MISSING=false
for yaml_file in "$YAML_EDITOR" "$YAML_WEBHOOK" "$YAML_WORKER"; do
    if [[ ! -f "$yaml_file" ]]; then
        echo "❌ YAML v1 nao encontrado: $yaml_file"
        MISSING=true
    fi
done

if $MISSING; then
    echo "   Nao e possivel fazer rollback sem os YAMLs originais"
    exit 1
fi

# Detectar versao do backup (v1) a partir dos YAMLs originais
BACKUP_VERSION=$(grep -o 'image: n8nio/n8n:[^ ]*' "$YAML_EDITOR" | head -1 | sed 's/image: n8nio\/n8n://')
CURRENT_VERSION=$(docker service ls --format "{{.Name}} {{.Image}}" 2>/dev/null | grep n8n_editor | head -1 | awk '{print $2}' | sed 's/.*://')

echo "📋 Backups encontrados:"
[[ -n "$LATEST_ENV_BACKUP" ]] && echo "   .env backup:   $LATEST_ENV_BACKUP"
[[ -n "$LATEST_SQL_BACKUP" ]] && echo "   SQL backup:     $LATEST_SQL_BACKUP"
echo ""
echo "   Versao atual:     ${CURRENT_VERSION:-desconhecida}"
echo "   Versao do backup: ${BACKUP_VERSION:-desconhecida}"
echo ""

read -p "Restaurar para a versao ${BACKUP_VERSION}? (y/N): " CONFIRM
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

# Restaurar .env do backup se disponivel
if [[ -n "$LATEST_ENV_BACKUP" ]]; then
    cp "$LATEST_ENV_BACKUP" ".env"
    echo "   ✅ .env restaurado de $LATEST_ENV_BACKUP"
else
    echo "   ⚠️  Nenhum backup do .env encontrado, usando .env atual"
fi

# Os YAMLs v1 originais em n8n/queue/ permanecem intactos
# (o upgrade usa n8n/queue-v2/ sem modificar os originais)
echo "   ✅ YAMLs v1 originais intactos em n8n/queue/"

echo ""

source .env
export DOMAIN DATABASE DATABASE_PASSWORD N8N_ENCRYPTION_KEY INITIAL_ADMIN_EMAIL INITIAL_ADMIN_PASSWORD

########################################
# 3. Restaurar banco de dados
########################################

if [[ -n "$LATEST_SQL_BACKUP" ]]; then
    echo "🗄️  Restaurando banco de dados..."
    echo "   O n8n v2 altera o banco ao subir, entao a restauracao e obrigatoria."
    echo ""

    POSTGRES_CONTAINER=$(docker ps --filter "name=postgres" --format "{{.ID}}" | head -1)

    if [[ -n "$POSTGRES_CONTAINER" ]]; then
        # Dropar e recriar o banco para garantir estado limpo
        echo "   → Recriando banco ${DATABASE:-n8n}..."
        docker exec "$POSTGRES_CONTAINER" psql -U postgres -c "DROP DATABASE IF EXISTS \"${DATABASE:-n8n}\";" >/dev/null 2>&1
        docker exec "$POSTGRES_CONTAINER" psql -U postgres -c "CREATE DATABASE \"${DATABASE:-n8n}\";" >/dev/null 2>&1

        echo "   → Restaurando backup: $LATEST_SQL_BACKUP"
        docker exec -i "$POSTGRES_CONTAINER" psql -U postgres -d "${DATABASE:-n8n}" < "$LATEST_SQL_BACKUP" >/dev/null 2>&1

        if [[ $? -eq 0 ]]; then
            echo "   ✅ Banco restaurado com sucesso"
        else
            echo "   ⚠️  Restauracao com avisos (pode ser normal)"
        fi
    else
        echo "   ❌ Container PostgreSQL nao encontrado"
        echo "   O banco nao foi restaurado. O n8n pode nao funcionar corretamente."
    fi
else
    echo "⚠️  Nenhum backup SQL encontrado em backups/"
    echo "   O banco nao sera restaurado. O n8n pode nao funcionar corretamente."
fi

echo ""

########################################
# 4. Redeploy com versao anterior
########################################

echo "🚀 Reinstalando n8n ${BACKUP_VERSION}..."
echo ""

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
# 5. Verificar servicos
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
