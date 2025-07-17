#!/bin/bash

# Script simplificado de limpeza

echo "=== LIMPEZA COMPLETA ==="

# Confirmar
read -p "Remover tudo? Digite SIM: " confirm
if [ "$confirm" != "SIM" ]; then
    echo "Cancelado"
    exit 1
fi

echo "Removendo stacks..."
docker stack rm traefik portainer

echo "Aguardando 15 segundos..."
sleep 15

echo "Limpando sistema..."
docker system prune -f
docker volume prune -f

echo "Desativando swarm..."
docker swarm leave --force

echo "Limpeza concluída!"
echo "Para reinstalar: sudo ./install-simple.sh"