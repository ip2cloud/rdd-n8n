#!/bin/bash

# Script de debug para verificar instalação

echo "=== VERIFICANDO INSTALAÇÃO ==="
echo ""

echo "1. Docker Swarm Status:"
docker info | grep -E "Swarm:|NodeID:|Is Manager:"
echo ""

echo "2. Nodes no cluster:"
docker node ls 2>/dev/null || echo "   Não é um manager node"
echo ""

echo "3. Redes criadas:"
docker network ls | grep overlay
echo ""

echo "4. Volumes criados:"
docker volume ls | grep -E "postgres_data|redis_data|traefik_certs|portainer_data"
echo ""

echo "5. Stacks deployados:"
docker stack ls
echo ""

echo "6. Serviços rodando:"
docker service ls
echo ""

echo "7. Logs do Portainer (se existir):"
docker service logs portainer_portainer 2>/dev/null | tail -10 || echo "   Portainer não encontrado"
echo ""

echo "8. Para deployar o Portainer manualmente:"
echo "   docker volume create portainer_data"
echo "   docker stack deploy -c portainer/portainer.yaml portainer"
echo ""

echo "9. Para ver logs de qualquer serviço:"
echo "   docker service logs NOME_DO_SERVICO"