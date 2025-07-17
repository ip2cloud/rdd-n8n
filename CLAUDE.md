# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a simplified Docker Swarm deployment project that sets up the infrastructure for n8n workflow automation platform. The installation is split into two phases:
1. **Base infrastructure** (automated via script): Docker, Swarm, Portainer, Traefik
2. **Application deployment** (manual via Portainer): PostgreSQL, Redis, n8n services

## Installation Approach

The project uses a two-step approach:
- **Step 1**: Run `install-simple.sh` to set up the base infrastructure
- **Step 2**: Use Portainer UI to deploy application stacks

This approach gives users more control and visibility over what's being deployed.

## Key Files

### Main Installation Script
- `install-simple.sh` - Simplified installer that sets up only the base infrastructure

### Configuration Files
- `traefik/traefik.yaml` - Traefik reverse proxy with automatic SSL
- `portainer/portainer.yaml` - Portainer Docker management UI
- `postgres16/postgres.yaml` - PostgreSQL 16 database
- `redis/redis.yaml` - Redis for caching and queues
- `n8n/queue/orq_editor.yaml` - n8n editor interface
- `n8n/queue/orq_webhook.yaml` - n8n webhook handler
- `n8n/queue/orq_worker.yaml` - n8n background worker

### Documentation
- `README.md` - User-facing installation guide
- `fix-linux.sh` - Utility to fix line endings for Linux

## Architecture

### Networks
- `network_swarm_public` - For public-facing services (Traefik, web interfaces)
- `network_swarm_databases` - For internal database connections

### Service Configuration
- All n8n services include Traefik labels for automatic routing
- Services use environment variable substitution
- Persistent volumes for data storage

### URLs
- Portainer: `https://SERVER_IP:9443`
- n8n Editor: `https://fluxos.DOMAIN`
- n8n Webhooks: `https://webhook.DOMAIN`
- Traefik Dashboard: `https://traefik.DOMAIN` (optional)

## Environment Variables

The script generates a `.env` file with:
- `DOMAIN` - Main domain
- `DATABASE` - PostgreSQL database name
- `DATABASE_PASSWORD` - Database password
- `N8N_ENCRYPTION_KEY` - n8n encryption key
- `POSTGRES_PASSWORD` - PostgreSQL root password
- `INITIAL_ADMIN_EMAIL` - n8n admin email
- `INITIAL_ADMIN_PASSWORD` - n8n admin password

## Common Tasks

### Deploy a stack via Portainer
1. Access Portainer at `https://SERVER_IP:9443`
2. Go to Stacks > Add Stack
3. Upload the YAML file
4. Add environment variables from `.env`
5. Deploy

### Check service status
```bash
docker service ls
docker stack ls
docker service logs SERVICE_NAME
```

### Update a service
```bash
docker service update SERVICE_NAME
```

### Remove everything
```bash
docker stack rm $(docker stack ls --format "{{.Name}}")
docker volume prune -f
```

## Important Notes

- The project is designed for Debian/Ubuntu systems
- All documentation and comments are in Portuguese (Brazilian)
- Services are deployed via Portainer for better visibility
- Traefik handles SSL certificates automatically
- Default admin credentials are generated during installation