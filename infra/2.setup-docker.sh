#!/bin/bash

###################################
#
# Vamos instalar o Docker
#
###################################

# Docker GPG key:
apt-get update
apt install -y sudo gnupg2 wget ca-certificates apt-transport-https curl gnupg nano htop
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Docker Apt sources:
 echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" |
   tee /etc/apt/sources.list.d/docker.list >/dev/null
   apt-get update

### com sudo

sudo apt-get update
sudo apt install -y sudo gnupg2 wget ca-certificates apt-transport-https curl gnupg nano htop
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg


echo \
  "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
  sudo apt-get update



sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Coloca o docker para iniciar com o sistema

sudo systemctl enable docker.service
sudo systemctl enable containerd.service
