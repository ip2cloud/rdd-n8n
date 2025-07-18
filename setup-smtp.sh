#!/bin/bash

###################################
# Script para Configurar SMTP
# Configura credenciais para envio de emails
###################################

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para imprimir com cor
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${YELLOW}→ $1${NC}"; }

# Banner
clear
echo "╔══════════════════════════════════════════╗"
echo "║       CONFIGURAÇÃO SMTP DO N8N           ║"
echo "║     Sistema de Envio de Credenciais      ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
   print_error "Execute como root: sudo ./setup-smtp.sh"
   exit 1
fi

# Diretório de configuração
CONFIG_DIR="/etc/n8n-installer"
CONFIG_FILE="$CONFIG_DIR/smtp.conf"

print_info "Configurando sistema de envio de credenciais por email..."
echo ""

# Criar diretório se não existir
if [[ ! -d "$CONFIG_DIR" ]]; then
    print_info "Criando diretório de configuração..."
    mkdir -p "$CONFIG_DIR"
    print_success "Diretório criado: $CONFIG_DIR"
fi

# Solicitar credenciais
echo "🔐 CREDENCIAIS DO SMTP LW"
echo ""
read -p "Chave API do SMTP LW: " API_TOKEN

while [[ -z "$API_TOKEN" ]]; do
    print_error "Chave API é obrigatória!"
    read -p "Chave API do SMTP LW: " API_TOKEN
done

# URL padrão
API_URL="https://api.smtplw.com.br/v1/messages"
read -p "URL da API [$API_URL]: " CUSTOM_URL
if [[ -n "$CUSTOM_URL" ]]; then
    API_URL="$CUSTOM_URL"
fi

# Criar arquivo de configuração
print_info "Criando arquivo de configuração..."

cat > "$CONFIG_FILE" << EOF
# Configurações SMTP para envio de credenciais
# Gerado automaticamente em $(date)

# Chave API do SMTP LW
SMTP_API_TOKEN=$API_TOKEN

# URL da API
SMTP_API_URL=$API_URL

# Este arquivo foi criado em: $(date)
# Mantenha este arquivo seguro!
EOF

# Definir permissões seguras
chmod 600 "$CONFIG_FILE"
print_success "Arquivo criado com permissões seguras: $CONFIG_FILE"

# Testar configuração
print_info "Testando configuração..."

# Verificar se arquivo foi criado corretamente
if [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" && [[ -n "$SMTP_API_TOKEN" ]]; then
    print_success "Configuração SMTP criada com sucesso!"
    echo ""
    echo "📧 Sistema de email habilitado!"
    echo "   Arquivo: $CONFIG_FILE"
    echo "   Permissões: $(ls -la $CONFIG_FILE | awk '{print $1}')"
    echo ""
    echo "✅ Agora você pode usar o sistema de envio de credenciais"
    echo "   durante a instalação do n8n!"
else
    print_error "Erro na criação da configuração"
    exit 1
fi

echo ""
print_info "Para testar o envio, execute: ./install-simple.sh"
echo ""
print_success "Configuração concluída!"