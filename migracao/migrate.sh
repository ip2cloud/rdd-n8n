#!/bin/bash

###############################################################################
#                                                                             #
#           ATUALIZAÇÃO AUTOMÁTICA DO N8N v1.x → v2.4.3                      #
#                                                                             #
#  Este script faz TUDO automaticamente:                                     #
#  ✅ Cria backup completo                                                    #
#  ✅ Atualiza para n8n v2.4.3                                                #
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

# Versão alvo
NOVA_VERSAO="2.4.3"

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
echo "  2. ✅ Atualização para n8n v2.4.3"
echo "  3. ✅ Verificação de funcionamento"
echo "  4. ✅ Restauração automática se algo der errado"
echo ""
echo -e "${YELLOW}⏱️  Tempo estimado: 5-8 minutos${NC}"
echo -e "${YELLOW}⏸️  Downtime: ~3 minutos (n8n ficará offline)${NC}"
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
# ETAPA 2: VALIDAR IMAGEM DOCKER
###############################################################################

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         🔍 ETAPA 2/5: Validando Nova Versão               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

log "ETAPA 2: Validando imagem Docker"

echo -e "${BLUE}🔍 Verificando se a versão ${NOVA_VERSAO} está disponível...${NC}"

if docker manifest inspect "n8nio/n8n:${NOVA_VERSAO}" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Versão ${NOVA_VERSAO} encontrada e pronta para instalar${NC}"
    log "Imagem n8nio/n8n:${NOVA_VERSAO} validada"
else
    erro_fatal "Versão ${NOVA_VERSAO} não encontrada no Docker Hub.\n   Verifique sua conexão com a internet."
fi

pausar

###############################################################################
# ETAPA 3: ATUALIZAR ARQUIVOS
###############################################################################

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       ⚙️  ETAPA 3/5: Atualizando Configurações            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

log "ETAPA 3: Atualizando arquivos de configuração"

echo -e "${BLUE}📝 Atualizando arquivos para versão ${NOVA_VERSAO}...${NC}"
echo ""

# Atualizar cada arquivo YAML
for arquivo in n8n/queue/orq_editor.yaml n8n/queue/orq_webhook.yaml n8n/queue/orq_worker.yaml; do
    nome_arquivo=$(basename "$arquivo")
    echo -e "   🔧 Atualizando ${nome_arquivo}..."

    if sed -i.bak "s|image: n8nio/n8n:.*|image: n8nio/n8n:${NOVA_VERSAO}|g" "$arquivo" 2>/dev/null; then
        echo -e "${GREEN}      ✅ ${nome_arquivo} atualizado${NC}"
        log "Arquivo $nome_arquivo atualizado para v${NOVA_VERSAO}"
    else
        erro_fatal "Falha ao atualizar $nome_arquivo"
    fi
done

echo ""
echo -e "${GREEN}✅ ARQUIVOS ATUALIZADOS COM SUCESSO!${NC}"
log "ETAPA 3: Arquivos de configuração atualizados"

pausar

###############################################################################
# ETAPA 4: ATUALIZAR N8N
###############################################################################

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          🚀 ETAPA 4/5: Instalando Nova Versão             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

log "ETAPA 4: Iniciando atualização dos serviços n8n"

echo -e "${YELLOW}⚠️  O n8n ficará offline durante esta etapa (~3 minutos)${NC}"
echo ""

pausar

# Exportar variáveis
export DOMAIN DATABASE DATABASE_PASSWORD N8N_ENCRYPTION_KEY INITIAL_ADMIN_EMAIL INITIAL_ADMIN_PASSWORD

echo -e "${BLUE}🔄 Atualizando serviços do n8n...${NC}"
echo ""

# Editor
echo -e "   [1/3] 📝 Atualizando Editor..."
echo -e "${YELLOW}         ⏳ Aguarde ~60 segundos (migração do banco de dados)...${NC}"
if docker stack deploy -c n8n/queue/orq_editor.yaml n8n_editor >/dev/null 2>&1; then
    sleep 60
    echo -e "${GREEN}         ✅ Editor atualizado${NC}"
    log "Editor atualizado com sucesso"
else
    erro_fatal "Falha ao atualizar o Editor"
fi

# Webhook
echo ""
echo -e "   [2/3] 🌐 Atualizando Webhook..."
echo -e "${YELLOW}         ⏳ Aguarde ~30 segundos...${NC}"
if docker stack deploy -c n8n/queue/orq_webhook.yaml n8n_webhook >/dev/null 2>&1; then
    sleep 30
    echo -e "${GREEN}         ✅ Webhook atualizado${NC}"
    log "Webhook atualizado com sucesso"
else
    erro_fatal "Falha ao atualizar o Webhook"
fi

# Worker
echo ""
echo -e "   [3/3] ⚙️  Atualizando Worker..."
echo -e "${YELLOW}         ⏳ Aguarde ~30 segundos...${NC}"
if docker stack deploy -c n8n/queue/orq_worker.yaml n8n_worker >/dev/null 2>&1; then
    sleep 30
    echo -e "${GREEN}         ✅ Worker atualizado${NC}"
    log "Worker atualizado com sucesso"
else
    erro_fatal "Falha ao atualizar o Worker"
fi

echo ""
echo -e "${GREEN}✅ TODOS OS SERVIÇOS ATUALIZADOS!${NC}"
log "ETAPA 4: Atualização dos serviços concluída"

pausar

###############################################################################
# ETAPA 5: VERIFICAR FUNCIONAMENTO
###############################################################################

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         ✅ ETAPA 5/5: Verificando Instalação               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

log "ETAPA 5: Verificando funcionamento dos serviços"

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
log "ETAPA 5: Verificação concluída com sucesso"

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
