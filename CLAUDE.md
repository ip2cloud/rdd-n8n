# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker Swarm infrastructure deployment project for setting up a complete workflow automation stack including PostgreSQL, Redis, n8n (workflow automation platform), and Portainer (Docker management UI) in a production environment. The project uses shell scripts for automated setup and YAML files for Docker stack configurations.

## Common Commands

### Automated Installation
```bash
# Execute complete automated installation
sudo ./install.sh
```

### Manual Infrastructure Setup (execute in order)
```bash
# 1. Set hostname
bash /infra/1.setup-base.sh

# 2. Install Docker
bash /infra/2.setup-docker.sh

# 3. Initialize Docker Swarm (replace YOUR_IP_ADDRESS)
docker swarm init --advertise-addr=YOUR_IP_ADDRESS

# 4. Create required networks
sudo docker network create --driver=overlay network_swarm_public
sudo docker network create --driver=overlay network_swarm_databases

# 5. Install optional tools (ctop)
bash /infra/4.setup-optional.sh
```

### Manual Deployment Commands
```bash
# Create Docker volumes
docker volume create postgres_data
docker volume create redis_data
docker volume create redis_insigth_data

# Deploy PostgreSQL
docker stack deploy --prune --detach=false --resolve-image always -c /postgres16/postgres.yaml postgres

# Deploy Redis
docker stack deploy --prune --detach=false --resolve-image always -c /redis/redis.yaml redis

# Deploy RedisInsight (optional)
docker stack deploy --prune --detach=false --resolve-image always -c /redis/redisInsight.yaml redisinsight

# Deploy Portainer
docker pull portainer/portainer-ce:sts
docker stack deploy --prune --detach=false --resolve-image always -c /portainer/portainer.yaml portainer

# Deploy n8n (regular mode)
docker stack deploy --prune --detach=false --resolve-image always -c /n8n/regular/n8n-regular.yaml n8n

# Deploy n8n (queue mode - deploy all three)
docker stack deploy --prune --detach=false --resolve-image always -c /n8n/queue/orq_editor.yaml n8n_editor
docker stack deploy --prune --detach=false --resolve-image always -c /n8n/queue/orq_webhook.yaml n8n_webhook
docker stack deploy --prune --detach=false --resolve-image always -c /n8n/queue/orq_worker.yaml n8n_worker
```

### Management Commands
```bash
# View stacks and services
docker stack ls
docker stack services STACK_NAME
docker service logs SERVICE_NAME

# Update a service
docker service update SERVICE_NAME

# Remove a stack
docker stack rm STACK_NAME

# Monitor containers
docker-ctop
```

## Architecture

### Network Structure
- **network_swarm_public**: Overlay network for public-facing services (Traefik ingress, web interfaces)
- **network_swarm_databases**: Overlay network for database connections (PostgreSQL, Redis)

### Service Architecture
- **PostgreSQL 16**: Database server for n8n data persistence with persistent volume storage
- **Redis 7**: In-memory database for n8n queue management and caching
- **RedisInsight**: Optional web-based Redis management interface (port 5540)
- **Portainer**: Docker management UI deployed on manager nodes with persistent storage
- **n8n Regular Mode**: Single instance deployment with PostgreSQL backend
- **n8n Queue Mode**: Distributed deployment with:
  - Editor service (main interface)
  - Webhook service (handles incoming webhooks)
  - Worker service (executes workflows)
  - Redis for queue management
  - PostgreSQL for data persistence

### Deployment Patterns
- All services use Docker Swarm mode with explicit image resolution
- Services are deployed using `--prune` to remove unused resources
- Configuration uses environment variable substitution for sensitive data
- Persistent volumes are mounted from host paths

## Environment Variables

The automated installation script (`install.sh`) will prompt for and configure all required environment variables automatically. Variables are saved to a `.env` file and include:

### Required Variables
- `DOMAIN` - Main domain for n8n (e.g., example.com)
- `WORKFLOW` - Subdomain for workflow editor (fixed: "fluxos")
- `WEBHOOK` - Subdomain for webhook endpoints (fixed: "webhook")
- `DATABASE` - PostgreSQL database name
- `DATABASE_PASSWORD` - Database password
- `N8N_ENCRYPTION_KEY` - N8N encryption key (auto-generated if not provided)

### Database Variables
- `POSTGRES_PASSWORD` - PostgreSQL database password (auto-configured)

### Optional Variables
- `TEMPLATES_INVITE` - Email invitation template
- `N8N_SMTP_HOST` - SMTP server host
- `N8N_SMTP_PORT` - SMTP server port
- `N8N_SMTP_USER` - SMTP username
- `N8N_SMTP_PASS` - SMTP password
- `N8N_SMTP_SENDER` - Email sender address

### Using Environment Variables
```bash
# Load variables from .env file
source .env

# Deploy with variables loaded
docker stack deploy -c n8n/queue/orq_editor.yaml n8n_editor
```

## Deployment Order

The automated installation script follows this deployment order:
1. **Infrastructure setup** (hostname, Docker, Swarm)
2. **Volume creation** (postgres_data, redis_data, redis_insigth_data)
3. **Database deployment** (PostgreSQL, Redis)
4. **Management tools** (Portainer)
5. **Application deployment** (n8n)

This order ensures dependencies are available before services that need them.

## Important Notes

- All documentation and comments are in Portuguese (Brazilian)
- The project assumes Debian-based Linux systems
- PostgreSQL and Redis are deployed as Docker services within the Swarm
- SSH setup documentation is available in `/infra/5.setup-ssh.md`
- No automated tests are included as this is an infrastructure deployment project
- Database passwords are automatically generated and saved to `.env` file