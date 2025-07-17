#!/bin/bash

###################################
#
# Primeiro vamos mudar o hostname da máquina para que ela seja devidamente
# identificada pelo Cluster do Docker Swarm
#
###################################

# Insira o hostname usando este comando:
hostnamectl set-hostname mgt01htz

# precisamos alterar esse arquivo tambem
nano /etc/hosts

###################################
# Agora precisamos alterar o /etc/hosts para adicionar o novo nome, tornando persistente
#
# 127.0.0.1    manager1
#
###################################

###################################
# Agora vamos reiniciar o sistema para efetivar as alterações do hostname

reboot

###################################
# Para exibir o nome do host
#
###################################

hostnamectl
