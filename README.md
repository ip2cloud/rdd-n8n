# Instalacao Automatica do n8n v2 + PostgreSQL + Redis

## Instalacao Completamente Automatica em Uma Execucao

### O que e instalado automaticamente:
- Docker Swarm + Portainer + Traefik (SSL automatico)
- PostgreSQL 16 + Redis 7
- n8n v2 completo (editor + webhook + worker) em modo queue
- pgAdmin 4 para administracao do banco
- Todas as redes, volumes e configuracoes necessarias

---

## Como Instalar

### 1. Execute o instalador

```bash
git clone <url-do-repositorio>
cd rdd-n8n
chmod +x install-simple.sh
sudo ./install-simple.sh
```

### 2. (Opcional) Configure SMTP para envio de credenciais:

```bash
sudo ./setup-smtp.sh
```

### 3. Responda 4-5 perguntas simples:

1. **Email do administrador**: seu-email@exemplo.com
2. **Dominio principal**: exemplo.com
3. **Nome do banco** [ENTER = n8n]: nome_do_banco (opcional)
4. **Senha do PostgreSQL** [ENTER = auto-gerar]: senha (opcional)
5. **Receber credenciais por email** [ENTER = Sim]: Y/n (se SMTP configurado)

> **Recomendado**: Tecle ENTER em tudo para usar os padroes

### 4. Aguarde ~5 minutos e pronto!

Tudo instalado automaticamente sem perguntas adicionais.

---

## Configure o DNS (Obrigatorio)

Aponte os dominios para o IP do seu servidor:

```
fluxos.SEU-DOMINIO.com   -> IP_DO_SERVIDOR
webhook.SEU-DOMINIO.com  -> IP_DO_SERVIDOR
traefik.SEU-DOMINIO.com  -> IP_DO_SERVIDOR (opcional)
```

**Nota**: pgAdmin nao precisa de DNS, acesso direto via IP:4040

---

## URLs de Acesso

### n8n (Automacao de Workflows)
- **Editor**: https://fluxos.SEU-DOMINIO.com
- **Webhook**: https://webhook.SEU-DOMINIO.com
- **Credenciais**: Mostradas no final da instalacao (salvas em `.env`)

### Portainer (Monitoramento Docker)
- **URL**: https://IP_DO_SERVIDOR:9443
- **Primeiro acesso**: Defina senha do admin (10 minutos apos instalacao)
- **Funcao**: Monitorar containers e servicos

### Traefik (Dashboard do Proxy)
- **URL**: https://traefik.SEU-DOMINIO.com
- **Login**: admin / senha_gerada_automaticamente
- **Funcao**: Monitoramento do proxy reverso e SSL

### pgAdmin (Administracao PostgreSQL)
- **URL**: http://IP_DO_SERVIDOR:4040
- **Login**: mesmo email da instalacao / senha_gerada_automaticamente
- **Funcao**: Interface web para administracao do PostgreSQL

---

## Tempo de Instalacao

- **Interacao**: 60-90 segundos (responder perguntas)
- **Instalacao**: ~5 minutos (automatica)
- **Aguardar servicos**: ~2 minutos adicionais

**Total**: ~8 minutos do inicio ao acesso

---

## Sistema de Envio de Credenciais

### Configuracao Segura
- **Configuracao externa**: Credenciais SMTP fora do codigo fonte
- **Arquivo protegido**: `/etc/n8n-installer/smtp.conf` com permissoes 600
- **Fallback inteligente**: Se email falhar, exibe na tela
- **Backup local**: Arquivo `.env` sempre mantido como backup

### Como configurar:

#### 1. Configure o SMTP (uma vez apenas):
```bash
sudo ./setup-smtp.sh
```

#### 2. Durante a instalacao:
- Se SMTP configurado: pergunta se quer email
- Se SMTP nao configurado: apenas credenciais na tela
- Credenciais sempre exibidas na tela tambem
- Arquivo `.env` sempre salvo localmente

### Configuracao Manual (alternativa):
```bash
sudo mkdir -p /etc/n8n-installer
sudo tee /etc/n8n-installer/smtp.conf > /dev/null <<EOF
SMTP_API_TOKEN=sua_chave_api_aqui
SMTP_API_URL=https://api.smtplw.com.br/v1/messages
EOF
sudo chmod 600 /etc/n8n-installer/smtp.conf
```

---

## Scripts Disponiveis

### Atualizacao do n8n
```bash
sudo ./update-n8n.sh
```
- Atualiza n8n para qualquer versao 2.x disponivel
- Busca versoes automaticamente no Docker Hub
- Interface interativa com selecao por menu
- Backup automatico dos arquivos YAML
- Deploy sequencial otimizado (Editor -> Webhook -> Worker)
- Validacao de imagens antes da atualizacao

### Upgrade para n8n v2 (migracao de v1)
```bash
sudo ./upgrade-n8n-v2.sh
```
- Migra instalacoes n8n 1.x para v2
- Backup automatico do banco PostgreSQL
- Migracao de YAMLs (queue -> queue-v2)
- Validacao de imagem e health checks

### Rollback do n8n v2
```bash
sudo ./rollback-n8n-v2.sh
```
- Reverte upgrade v2 em caso de falha
- Restaura YAMLs e banco PostgreSQL do backup

### Configuracao SSL/TLS
```bash
sudo ./update-ssl.sh
```
- Configura certificados Let's Encrypt automaticamente
- Atualiza Traefik com resolver SSL
- Redeploy de todos os servicos com certificados
- Certificados automaticos para todos os dominios

### Configuracao SMTP
```bash
sudo ./setup-smtp.sh
```
- Configura credenciais para envio de email
- Cria arquivo seguro `/etc/n8n-installer/smtp.conf`
- Necessario apenas uma vez por servidor

### Diagnostico e Monitoramento
```bash
./debug.sh
```
- Verifica status do Docker Swarm
- Lista nodes, redes, volumes e stacks
- Mostra logs dos servicos

### Limpeza Rapida
```bash
./cleanup.sh
```
- Remove stacks principais (traefik, portainer)
- Limpa sistema Docker
- Desativa Docker Swarm

### Desinstalacao Completa
```bash
sudo ./uninstall.sh
```
- Remove todos os stacks e servicos
- Apaga volumes (DADOS PERDIDOS!)
- Desativa Docker Swarm
- Remove redes overlay
- Mantem backup do `.env`

---

## Variaveis de Ambiente

Todas as configuracoes ficam salvas no arquivo `.env`:

```env
DOMAIN=seu-dominio.com
DATABASE=n8n
DATABASE_PASSWORD=senha_gerada_automaticamente
N8N_ENCRYPTION_KEY=chave_gerada_automaticamente
POSTGRES_PASSWORD=senha_gerada_automaticamente
INITIAL_ADMIN_EMAIL=seu@email.com
INITIAL_ADMIN_PASSWORD=senha_gerada_automaticamente
TRAEFIK_ADMIN_PASSWORD=senha_gerada_automaticamente
TRAEFIK_ADMIN_HASH=hash_gerado_automaticamente
PGADMIN_ADMIN_PASSWORD=senha_gerada_automaticamente
EDITOR_URL=https://fluxos.seu-dominio.com
WEBHOOK_URL=https://webhook.seu-dominio.com
```

---

## Comandos Uteis

```bash
# Ver status dos servicos
docker service ls

# Monitorar containers em tempo real
docker-ctop

# Ver logs de um servico especifico
docker service logs nome_do_servico

# Ver stacks instalados
docker stack ls

# Carregar variaveis do .env
source .env

# Script de diagnostico completo
./debug.sh
```

---

## Resolucao de Problemas

### Script nao executa?
```bash
# Corrigir permissoes e quebras de linha
sed -i 's/\r$//' *.sh
chmod +x *.sh
```

### Servicos nao sobem?
```bash
# Diagnostico completo
./debug.sh

# Ver logs especificos
docker service logs postgres_postgres
docker service logs n8n_editor_n8nv2_editor_ip2
```

### n8n nao acessa?
1. Verifique se o DNS esta configurado
2. Aguarde ~2 minutos para todos os servicos subirem
3. Verifique no Portainer se todos estao rodando

### Portainer nao acessa?
```bash
# Verificar se esta rodando
docker service ls | grep portainer

# Resetar timeout (10 minutos novos)
docker service scale portainer_portainer=0
sleep 3
docker service scale portainer_portainer=1

# Reinstalar se necessario
docker stack deploy -c portainer/portainer.yaml portainer
```

---

## Desinstalacao

### Limpeza Rapida (mantem dados)
```bash
./cleanup.sh
```

### Remocao Completa (apaga tudo)
```bash
sudo ./uninstall.sh
```

### Reinstalar
```bash
# Apos desinstalar, reinstale com:
sudo ./install-simple.sh
```

---

## Requisitos do Sistema

- **OS**: Debian/Ubuntu (64-bit)
- **RAM**: Minimo 2GB (recomendado 4GB+)
- **CPU**: 1 core (recomendado 2+ cores)
- **Disco**: 10GB+ livres
- **Usuario**: root ou sudo
- **Dominio**: Um dominio valido configurado

---

## Proximos Passos Apos Instalacao

### 1. Configure o DNS
```
fluxos.SEU-DOMINIO.com   -> IP_DO_SERVIDOR
webhook.SEU-DOMINIO.com  -> IP_DO_SERVIDOR
traefik.SEU-DOMINIO.com  -> IP_DO_SERVIDOR (opcional)
```

### 2. Configure SSL (Recomendado)
```bash
sudo ./update-ssl.sh
```
- Configura certificados Let's Encrypt automaticamente
- Aguarde ~2 minutos para emissao dos certificados

### 3. Aguarde ~2 minutos
Os servicos precisam de um tempo para inicializar completamente.

### 4. Acesse o n8n
- URL: https://fluxos.SEU-DOMINIO.com
- Use as credenciais mostradas no final da instalacao

### 5. Monitore no Portainer
- URL: https://IP_DO_SERVIDOR:9443
- Crie senha do admin no primeiro acesso
- IMPORTANTE: Acesse em ate 10 minutos apos instalacao

### 6. Acesse pgAdmin (se necessario)
- URL: http://IP_DO_SERVIDOR:4040
- Login: email da instalacao / senha gerada automaticamente

---

## Estrutura do Projeto

```
rdd-n8n/
├── install-simple.sh          # Instalador principal
├── update-n8n.sh              # Atualizador de versao (2.x+)
├── upgrade-n8n-v2.sh          # Migracao v1 -> v2
├── rollback-n8n-v2.sh         # Rollback do upgrade v2
├── update-ssl.sh              # Configuracao SSL
├── setup-smtp.sh              # Configuracao SMTP
├── debug.sh                   # Diagnostico
├── cleanup.sh                 # Limpeza rapida
├── uninstall.sh               # Desinstalacao completa
├── .env                       # Credenciais (gerado na instalacao)
├── smtp.conf.example          # Template SMTP
├── n8n/queue-v2/
│   ├── orq_editor.yaml        # n8n Editor
│   ├── orq_webhook.yaml       # n8n Webhook
│   └── orq_worker.yaml        # n8n Worker
├── postgres16/postgres.yaml   # PostgreSQL 16
├── redis/redis.yaml           # Redis 7
├── traefik/traefik.yaml       # Traefik v3
├── portainer/portainer.yaml   # Portainer
└── pgadmin/pgadmin.yaml       # pgAdmin 4
```

---

## Principais Recursos

- **Docker Swarm** - Orquestracao robusta
- **n8n v2 Queue Mode** - Editor + Webhook + Worker
- **PostgreSQL 16** - Banco de dados robusto
- **Redis 7** - Cache e filas de trabalho
- **Traefik v3** - Proxy reverso com SSL automatico
- **Portainer** - Interface de gerenciamento
- **pgAdmin 4** - Administracao PostgreSQL
- **Let's Encrypt** - Certificados SSL gratuitos
- **Sistema SMTP** - Envio seguro de credenciais
- **Scripts de Manutencao** - Atualizacao, diagnostico, limpeza
