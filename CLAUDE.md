# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **fully automated Docker Swarm deployment project** for n8n workflow automation platform. The project provides a one-click installation that sets up a complete production-ready environment with:
- Docker Swarm orchestration
- PostgreSQL 16 with pgvector + Redis 7 databases
- n8n v2.4.3 in queue mode (editor + webhook + worker)
- Evolution API v2.3.6 for WhatsApp Multi-Device integration
- Traefik reverse proxy with automatic SSL
- Portainer for container management
- pgAdmin 4 for PostgreSQL administration
- Secure credential management with optional email delivery

## Installation Approach

The project uses a **fully automated approach** with optional email integration:
- **Single command**: `sudo ./install-simple.sh` installs everything
- **4-5 simple questions**: Email, domain, database name (optional), password (optional), SMTP (if configured)
- **Optional SMTP**: Configure with `sudo ./setup-smtp.sh` for credential delivery
- **Zero manual steps**: All services deployed automatically without confirmation prompts
- **Secure by default**: No hardcoded credentials in repository

## Key Files

### Main Scripts
- `install-simple.sh` - Complete automated installer (deploys everything including Evolution API)
- `update-n8n.sh` - Update n8n to any available version (interactive menu)
- `update-evolution.sh` - Update Evolution API to any available version (interactive menu)
- `update-ssl.sh` - Configure Let's Encrypt SSL certificates automatically
- `setup-smtp.sh` - Configure SMTP for secure credential delivery
- `deploy-api.sh` - API-based deployment alternative (if needed)

### Backup
- `backup.sh` - Backup do banco de dados n8n + variáveis de ambiente (manual ou automático via cron)

### Diagnostic & Maintenance
- `debug.sh` - Comprehensive diagnostic script
- `cleanup.sh` - Quick cleanup (remove stacks, clean system)
- `uninstall.sh` - Complete uninstallation with data removal (includes pgAdmin)
- `create-database.sh` - Manual n8n database creation utility (if needed)
- `create-evolution-database.sh` - Manual Evolution database creation utility (if needed)

### Configuration Templates
- `smtp.conf.example` - SMTP configuration template
- `.gitignore` - Prevents credential files from being committed

### Service Configurations
- `traefik/traefik.yaml` - Traefik v3 reverse proxy with Let's Encrypt support
- `portainer/portainer.yaml` - Portainer Docker management UI
- `postgres16/postgres.yaml` - PostgreSQL 16 with pgvector extension
- `redis/redis.yaml` - Redis 7 for caching and queues
- `n8n/queue/orq_editor.yaml` - n8n editor interface (v2.4.3)
- `n8n/queue/orq_webhook.yaml` - n8n webhook handler (v2.4.3)
- `n8n/queue/orq_worker.yaml` - n8n background worker (v2.4.3)
- `evolution/evolution.yaml` - Evolution API v2.3.6 for WhatsApp Multi-Device
- `pgadmin/pgadmin.yaml` - pgAdmin 4 web interface (direct IP:4040 access)

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
- **SSL everywhere**: Traefik handles automatic HTTPS with Let's Encrypt
- **No hardcoded secrets**: Repository safe for public git

### Service URLs
- **Portainer**: `https://SERVER_IP:9443`
- **n8n Editor**: `https://fluxos.DOMAIN`
- **n8n Webhooks**: `https://webhook.DOMAIN`
- **Evolution API**: `https://evo.DOMAIN`
- **pgAdmin**: `http://SERVER_IP:4040` (direct access, no Traefik)
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
PGADMIN_ADMIN_PASSWORD=generated_password
EVOLUTION_API_KEY=generated_key
EVOLUTION_DATABASE=bravo_evolution
EVOLUTION_URL=https://evo.user-domain.com
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

### Automatic Deployment (Always)
1. Run installer: `sudo ./install-simple.sh`
2. Answer 4-5 simple questions (email, domain, database name, password, SMTP)
3. Full stack deploys automatically (no manual intervention)
4. Wait ~5 minutes for complete setup
5. **IMPORTANT**: Access Portainer immediately (5-minute window to set admin password)
6. Access n8n at `https://fluxos.DOMAIN`
7. Access Evolution API at `https://evo.DOMAIN`

**Note**: The script automatically resets Portainer at the end to provide a fresh 5-minute window for initial setup.

## Common Tasks

### Check Installation Status
```bash
./debug.sh                    # Complete diagnostic
docker service ls             # List all services
docker stack ls               # List all stacks
docker service logs SERVICE   # View service logs
```

### Update n8n Version
```bash
# Interactive version selection
sudo ./update-n8n.sh

# Features:
# - Lists available versions from Docker Hub
# - Shows current installed version
# - Validates image before update
# - Automatic backup of configurations
# - Sequential deployment with proper delays
```

### Update Evolution API Version
```bash
# Interactive version selection
sudo ./update-evolution.sh

# Features:
# - Lists available versions from Docker Hub
# - Shows current installed version
# - Validates image before update
# - Automatic backup of configuration
# - Immediate deployment
```

### Configure SSL Certificates
```bash
# Enable Let's Encrypt
sudo ./update-ssl.sh

# What it does:
# - Configures Traefik with Let's Encrypt
# - Updates all services with certresolver
# - Automatic certificate renewal
# - Works for all configured domains
```

### Update Services Manually
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

### Backup n8n
```bash
# Execução manual (interativo - sugere configurar cron na 1ª vez)
sudo ./backup.sh

# Execução automática (usado pelo cron)
sudo ./backup.sh --auto

# O que é salvo:
# - .env (variáveis de ambiente)
# - smtp.conf (configuração SMTP, se existir)
# - Configuração dos serviços n8n em execução (docker service inspect)
# - pg_dump do banco de dados n8n (formato custom, comprimido)

# Estrutura do backup:
# backups/
# ├── YYYYMMDD_HHMMSS/
# │   ├── env_backup.env
# │   ├── smtp.conf (se existir)
# │   ├── services/
# │   │   ├── n8n_editor.json / .txt
# │   │   ├── n8n_webhook.json / .txt
# │   │   └── n8n_worker.json / .txt
# │   ├── n8n_backup.dump
# │   └── n8n_dump.log
# └── logs/
#     └── backup_YYYYMMDD_HHMMSS.log

# Retenção: 15 backups mais recentes, 30 logs mais recentes
# Cron: configurável na 1ª execução (horário personalizável)

# Restaurar banco n8n:
# docker exec -i CONTAINER pg_restore -U postgres -d DATABASE --clean < n8n_backup.dump
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
- **Version**: v2.4.3
- **Editor**: Web interface for workflow creation
- **Webhook**: Handles incoming webhook requests
- **Worker**: Processes background jobs
- **Queue**: Redis-based job queue system
- **Database**: PostgreSQL 16 with pgvector for persistence and AI features

### Traefik Integration
- Automatic service discovery via Docker labels
- Let's Encrypt certificate generation via ACME
- TLS challenge for certificate validation
- Load balancing and health checks
- Password-protected dashboard
- Certificate resolver: `letsencrypt`

### Volume Management
- `postgres_data` - PostgreSQL database storage
- `redis_data` - Redis persistence
- `traefik_certs` - SSL certificate storage
- `portainer_data` - Portainer configuration
- `pgadmin_data` - pgAdmin 4 configuration and logs
- `evolution_v2_data` - Evolution API instances and media storage

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

### pgAdmin Specific Notes
- **Access**: Direct IP:4040 (bypasses Traefik for security)
- **Authentication**: Uses same email as n8n admin + auto-generated password
- **Security**: No SSL termination (internal network access recommended)
- **Database connection**: Automatically configured for local PostgreSQL

### Portainer Timeout Fix
- **Problem**: Portainer has 5-minute timeout for initial admin setup
- **Solution**: Script automatically resets Portainer at the end using Docker Swarm scaling (0→1)
  ```bash
  docker service scale portainer_portainer=0  # Stop service
  sleep 3
  docker service scale portainer_portainer=1  # Restart service
  ```
- **Result**: User gets fresh 5-minute window after installation completes
- **Benefit**: Can monitor installation AND have time to configure admin password
- **Why scaling**: More elegant than `--force`, ensures complete container recreation

### Backup System Notes
- **Script**: `backup.sh` - backup focado exclusivamente no n8n
- **Escopo**: banco de dados n8n (pg_dump), .env, smtp.conf, configuração dos serviços Docker
- **Configuração Docker**: capturada via `docker service inspect` (reflete o estado real em execução)
- **Agendamento**: na 1ª execução manual, sugere configurar cron automático diário
- **Cron**: executa `backup.sh --auto` (sem interação, sem cores, grava tudo em log)
- **Logs**: cada execução gera `backups/logs/backup_YYYYMMDD_HHMMSS.log`
- **Status**: execuções seguintes mostram status do cron e resultado do último backup automático
- **Retenção**: mantém 15 backups e 30 logs mais recentes (rotação automática)
- **Gerenciamento**: em execuções interativas, permite alterar horário ou remover o cron

### Update System Notes
- **update-n8n.sh**: Interactive version selector with Docker Hub integration
- **update-evolution.sh**: Interactive version selector for Evolution API updates
- **update-ssl.sh**: Automatic Let's Encrypt configuration for all services
- **Backup Strategy**: All update scripts create timestamped backups
- **Version Management**: Supports any version available on Docker Hub

### SSL/TLS Configuration
- **Certificate Provider**: Let's Encrypt via ACME protocol
- **Challenge Type**: TLS-ALPN-01 (port 443)
- **Storage**: `/certs/acme.json` in traefik_certs volume
- **Renewal**: Automatic via Traefik
- **Domains**: All configured subdomains get individual certificates (fluxos, webhook, evo, traefik)

### PostgreSQL with pgvector
- **Image**: pgvector/pgvector:pg16
- **Purpose**: Vector similarity search for AI/ML features in n8n
- **Features**:
  - Standard PostgreSQL 16 functionality
  - pgvector extension pre-installed for embedding storage
  - Supports AI agent memory and semantic search in n8n workflows
  - Compatible with all PostgreSQL tools and clients

### Evolution API Integration
- **Version**: v2.3.6 (evoapicloud/evolution-api)
- **Database**: Dedicated PostgreSQL database (`bravo_evolution`) - created during installation
- **Cache**: Redis database index 6 (shared with n8n)
- **Authentication**: API Key auto-generated during installation
- **Storage**: Dedicated volume for WhatsApp instances and media
- **Features**: WhatsApp Multi-Device, Chatwoot integration, OpenAI support
- **Documentation**: https://doc.evolution-api.com/
- **Integration**: Can be connected to n8n workflows via HTTP Request node
- **Note**: Installation script creates the database before deploying Evolution API