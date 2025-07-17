#!/bin/bash

###################################
# Etapa 1
#
# obter e rodar o script de inicialização no cluster
#
###################################

# Inicia o Swarm

docker swarm init --advertise-addr=178.156.174.79

docker swarm join --token SWMTKN-1-4y9yxvplgrc4jbglsg8rmk19fdi8vhzqirfraguiiksdyiiaz2-3psr7qv2uq7xpbbxnsdcuquqx 178.156.160.35:2377

docker swarm init --advertise-addr=5.161.247.90
###################################
# Etapa 2
#
# Configura a Rede do Docker Swarm
#

sudo docker network create --driver=overlay network_swarm_public
sudo docker network create --driver=overlay network_swarm_databases

