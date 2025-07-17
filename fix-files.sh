#!/bin/bash

echo "Corrigindo terminadores de linha para Linux..."

# Corrige todos os arquivos .sh
find . -name "*.sh" -type f -exec sed -i 's/\r$//' {} \;

# Torna executáveis
chmod +x install.sh
find ./infra -name "*.sh" -type f -exec chmod +x {} \;

echo "Arquivos corrigidos com sucesso!"
echo "Execute: ./install.sh"