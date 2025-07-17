#!/bin/bash
# Script para corrigir problemas de execução no Linux

echo "Corrigindo arquivos para Linux..."

# Remove caracteres Windows (CRLF)
find . -name "*.sh" -type f -exec sed -i 's/\r$//' {} \;
find . -name "*.yaml" -type f -exec sed -i 's/\r$//' {} \;

# Torna executáveis
chmod +x install-simple.sh
chmod +x fix-linux.sh
find ./infra -name "*.sh" -type f -exec chmod +x {} \;

echo "Arquivos corrigidos!"
echo ""
echo "Agora execute:"
echo "  ./install-simple.sh"