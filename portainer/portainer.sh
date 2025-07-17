#!/bin/bash

docker pull portainer/portainer-ce:sts

docker stack deploy --prune --detach=false --resolve-image always -c portainer.yaml portainer