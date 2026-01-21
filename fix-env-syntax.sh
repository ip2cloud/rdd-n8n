#!/bin/bash

###################################
# Script para Corrigir Sintaxe do .env
# Identifica e corrige problemas comuns
###################################

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${YELLOW}→ $1${NC}"; }

echo "╔══════════════════════════════════════════╗"
echo "║   DIAGNÓSTICO DO ARQUIVO .env            ║"
echo "╚══════════════════════════════════════════╝"
echo ""

if [[ ! -f ".env" ]]; then
    print_error "Arquivo .env não encontrado!"
    exit 1
fi

# Fazer backup
BACKUP=".env.backup.$(date +%Y%m%d_%H%M%S)"
cp .env "$BACKUP"
print_success "Backup criado: $BACKUP"
echo ""

# Verificar linha 33
print_info "Verificando linha 33 do .env:"
echo ""
sed -n '33p' .env
echo ""

# Verificar sintaxe do arquivo todo
print_info "Verificando sintaxe completa:"
echo ""

# Tentar carregar com bash -n (syntax check)
if bash -n .env 2>&1 | grep -q "syntax error"; then
    print_error "Erros de sintaxe encontrados:"
    bash -n .env 2>&1
    echo ""
fi

# Verificar linhas problemáticas
print_info "Procurando por problemas comuns:"
echo ""

# Linhas com aspas não fechadas
if grep -n "[^=]*=[^\"]*\"[^\"]*$" .env | grep -v "^#"; then
    echo ""
    print_error "↑ Linhas com aspas não fechadas encontradas"
else
    print_success "Sem aspas não fechadas"
fi

echo ""

# Linhas com caracteres especiais sem aspas
if grep -n "=[^\"']*[\$\`\!\&\*\(\)\[\]\{\}\;\<\>\?]" .env | grep -v "^#" | grep -v "HASH" | grep -v "PASSWORD"; then
    echo ""
    print_error "↑ Linhas com caracteres especiais sem aspas"
else
    print_success "Caracteres especiais OK"
fi

echo ""

# Verificar linha vazia ou incompleta
if grep -n "^[A-Z_]*=$" .env; then
    echo ""
    print_error "↑ Variáveis vazias ou incompletas"
else
    print_success "Sem variáveis vazias"
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   TESTES DE CARGA                        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Testar carregar cada variável individualmente
print_info "Testando carregar variáveis (linha por linha):"
echo ""

LINE_NUM=0
while IFS= read -r line; do
    LINE_NUM=$((LINE_NUM + 1))

    # Pular linhas vazias e comentários
    if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi

    # Tentar avaliar a linha
    if ! eval "export $line" 2>/dev/null; then
        print_error "Linha $LINE_NUM FALHOU: $line"
    fi
done < .env

print_success "Teste de carga concluído"
echo ""

echo "╔══════════════════════════════════════════╗"
echo "║   RECOMENDAÇÕES                          ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "1. Verifique a linha 33 acima"
echo "2. Se houver erro, edite manualmente:"
echo "   nano .env"
echo ""
echo "3. Problemas comuns:"
echo "   - Aspas não fechadas: VAR=\"valor"
echo "   - Caracteres especiais sem aspas: VAR=\$senha"
echo "   - Linha incompleta: VAR="
echo ""
echo "4. Depois de corrigir, teste:"
echo "   source .env && echo OK"
echo ""
print_info "Backup salvo em: $BACKUP"
