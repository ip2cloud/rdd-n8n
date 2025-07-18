# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **fully automated Docker Swarm deployment project** for n8n workflow automation platform. The project provides a one-click installation that sets up a complete production-ready environment with:
- Docker Swarm orchestration
- PostgreSQL 16 + Redis 7 databases  
- n8n in queue mode (editor + webhook + worker)
- Traefik reverse proxy with automatic SSL
- Portainer for container management
- Secure credential management with optional email delivery

## Installation Approach

The project uses a **fully automated approach** with optional email integration:
- **Single command**: `sudo ./install-simple.sh` installs everything
- **Optional SMTP**: Configure with `sudo ./setup-smtp.sh` for credential delivery
- **Zero manual steps**: All services deployed automatically
- **Secure by default**: No hardcoded credentials in repository

## Key Files

### Main Scripts
- `install-simple.sh` - Complete automated installer (deploys everything)
- `setup-smtp.sh` - Configure SMTP for secure credential delivery
- `deploy-api.sh` - API-based deployment alternative (if needed)

### Diagnostic & Maintenance
- `debug.sh` - Comprehensive diagnostic script
- `cleanup.sh` - Quick cleanup (remove stacks, clean system)
- `uninstall.sh` - Complete uninstallation with data removal

### Configuration Templates
- `smtp.conf.example` - SMTP configuration template
- `.gitignore` - Prevents credential files from being committed

### Service Configurations
- `traefik/traefik.yaml` - Traefik v3 reverse proxy with dynamic credentials
- `portainer/portainer.yaml` - Portainer Docker management UI
- `postgres16/postgres.yaml` - PostgreSQL 16 with dynamic password
- `redis/redis.yaml` - Redis 7 for caching and queues
- `n8n/queue/orq_editor.yaml` - n8n editor interface (v1.100.1)
- `n8n/queue/orq_webhook.yaml` - n8n webhook handler (v1.100.1)  
- `n8n/queue/orq_worker.yaml` - n8n background worker (v1.100.1)

### Documentation
- `README.md` - Complete user installation guide
- `CLAUDE.md` - This technical documentation

## Architecture

### Networks
- `network_swarm_public` - Public services (Traefik, web interfaces)
- `network_swarm_databases` - Internal database connections

### Security Features
- **Dynamic passwords**: All credentials generated automatically
- **External SMTP config**: Credentials stored in `/etc/n8n-installer/smtp.conf`
- **Secure permissions**: Config files with 600 permissions
- **SSL everywhere**: Traefik handles automatic HTTPS
- **No hardcoded secrets**: Repository safe for public git

### Service URLs
- **Portainer**: `https://SERVER_IP:9443`
- **n8n Editor**: `https://fluxos.DOMAIN`
- **n8n Webhooks**: `https://webhook.DOMAIN`
- **Traefik Dashboard**: `https://traefik.DOMAIN` (with auth)

## Environment Variables

The script generates a comprehensive `.env` file with:
```env
DOMAIN=user-domain.com
DATABASE=n8n
DATABASE_PASSWORD=generated_password
N8N_ENCRYPTION_KEY=generated_key
POSTGRES_PASSWORD=generated_password
INITIAL_ADMIN_EMAIL=user@email.com
INITIAL_ADMIN_PASSWORD=generated_password
TRAEFIK_ADMIN_PASSWORD=generated_password
TRAEFIK_ADMIN_HASH=generated_hash
EDITOR_URL=https://fluxos.user-domain.com
WEBHOOK_URL=https://webhook.user-domain.com
```

## SMTP Configuration (Optional)

### Security Model
- SMTP credentials stored externally in `/etc/n8n-installer/smtp.conf`
- Repository contains no real credentials (safe for public git)
- Configuration template provided in `smtp.conf.example`

### Setup Process
```bash
# Configure SMTP (one time per server)
sudo ./setup-smtp.sh

# Or manually:
sudo mkdir -p /etc/n8n-installer
sudo tee /etc/n8n-installer/smtp.conf > /dev/null <<EOF
SMTP_API_TOKEN=your_api_token
SMTP_API_URL=https://api.smtplw.com.br/v1/messages
EOF
sudo chmod 600 /etc/n8n-installer/smtp.conf
```

## Deployment Process

### Automatic Deployment (Default)
1. Run installer: `sudo ./install-simple.sh`
2. Answer 5-6 simple questions
3. Choose automatic deployment (default: Yes)
4. Wait ~5 minutes for complete setup
5. Access n8n at `https://fluxos.DOMAIN`

### Manual Deployment (Alternative)
1. Choose manual deployment during installation
2. Use Portainer UI or `./deploy-api.sh` script
3. All YAML files ready with variable substitution

## Common Tasks

### Check Installation Status
```bash
./debug.sh                    # Complete diagnostic
docker service ls             # List all services
docker stack ls               # List all stacks
docker service logs SERVICE   # View service logs
```

### Update Services
```bash
# Update single service
docker service update SERVICE_NAME

# Redeploy stack
docker stack deploy -c path/to/file.yaml STACK_NAME
```

### Cleanup Operations
```bash
# Quick cleanup (keep data)
./cleanup.sh

# Complete uninstall (removes data)
sudo ./uninstall.sh

# Manual cleanup
docker stack rm $(docker stack ls --format "{{.Name}}")
docker system prune -f
docker swarm leave --force
```

### Credential Management
```bash
# View all credentials
cat .env

# If you need to redeploy with correct credentials
sudo ./install-simple.sh  # Just run installer again
```

## Technical Details

### n8n Queue Mode Configuration
- **Editor**: Web interface for workflow creation
- **Webhook**: Handles incoming webhook requests
- **Worker**: Processes background jobs
- **Queue**: Redis-based job queue system
- **Database**: PostgreSQL for persistence

### Traefik Integration
- Automatic service discovery via Docker labels
- Dynamic SSL certificate generation
- Load balancing and health checks
- Password-protected dashboard

### Volume Management
- `postgres_data` - PostgreSQL database storage
- `redis_data` - Redis persistence
- `traefik_certs` - SSL certificate storage
- `portainer_data` - Portainer configuration

## Important Notes

### System Requirements
- **OS**: Debian/Ubuntu (64-bit)
- **RAM**: Minimum 2GB (recommended 4GB+)
- **CPU**: 1+ cores
- **Disk**: 10GB+ free space
- **User**: root or sudo access
- **Domain**: Valid domain with DNS control

### Security Considerations
- All passwords auto-generated and unique per installation
- SMTP credentials stored outside repository
- File permissions properly configured
- SSL/TLS enabled on all connections
- Docker Swarm provides container isolation

### Language & Localization
- Documentation and comments in Portuguese (Brazilian)
- Timezone set to America/Sao_Paulo
- UI remains in original language (English for most services)

### Git Repository Safety
- Zero hardcoded credentials in source code
- `.gitignore` prevents credential file commits
- Safe for public repositories
- Configuration templates provided