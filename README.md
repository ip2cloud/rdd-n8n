# 🚀 Instalação Rápida do n8n com Portainer

## ⚡ Instalação em 2 Etapas

### 🎯 Etapa 1: Preparar o Ambiente (Automática)

### 🎯 Etapa 2: Deploy dos Serviços (Via Portainer)

## 📋 ETAPA 1: Preparar o Ambiente

### 1️⃣ Clone e execute o instalador

```bash
git clone <url-do-repositorio>
cd install
chmod +x install-simple.sh
sudo ./install-simple.sh
```

### 2️⃣ O script vai instalar:

- ✅ Docker e Docker Swarm
- ✅ Portainer (gerenciador visual)
- ✅ Traefik (proxy reverso)
- ✅ Criar volumes e redes
- ✅ Gerar arquivo .env com senhas

### 3️⃣ Scripts auxiliares inclusos:

- 🔧 `./debug.sh` - Diagnóstico de problemas
- 🗑️ `./uninstall.sh` - Desinstalação completa
- 🛠️ `./fix-linux.sh` - Correção de quebras de linha

### 4️⃣ Tempo: ~3 minutos

## 🎛️ ETAPA 2: Deploy via Portainer

### 1️⃣ Acesse o Portainer

```
https://SEU-IP:9443
```

- Crie senha do admin no primeiro acesso
- Conecte ao ambiente local

### 2️⃣ Deploy dos Stacks

No Portainer, vá em **Stacks > Add Stack** e crie:

#### Stack 1: PostgreSQL

- **Name**: postgres
- **Build method**: Upload
- **Upload file**: `postgres16/postgres.yaml`
- **Environment variables**: Adicione do arquivo .env

#### Stack 2: Redis

- **Name**: redis
- **Build method**: Upload
- **Upload file**: `redis/redis.yaml`

#### Stack 3: n8n Editor

- **Name**: n8n_editor
- **Build method**: Upload
- **Upload file**: `n8n/queue/orq_editor.yaml`
- **Environment variables**: Adicione do arquivo .env

#### Stack 4: n8n Webhook

- **Name**: n8n_webhook
- **Build method**: Upload
- **Upload file**: `n8n/queue/orq_webhook.yaml`
- **Environment variables**: Adicione do arquivo .env

#### Stack 5: n8n Worker

- **Name**: n8n_worker
- **Build method**: Upload
- **Upload file**: `n8n/queue/orq_worker.yaml`
- **Environment variables**: Adicione do arquivo .env

### 3️⃣ Configure o DNS

- `fluxos.SEU-DOMINIO.com` → IP do servidor
- `webhook.SEU-DOMINIO.com` → IP do servidor

## 🔧 Scripts Auxiliares

### Debug e Diagnóstico
```bash
./debug.sh
```
- Verifica status do Docker Swarm
- Lista nodes, redes e volumes
- Mostra stacks e serviços
- Exibe logs dos serviços
- Comandos para deploy manual

### Desinstalação Completa
```bash
sudo ./uninstall.sh
```
- Remove todos os stacks
- Apaga volumes (⚠️ DADOS PERDIDOS!)
- Desativa Docker Swarm
- Remove redes overlay
- Mantém backup do .env

### Correção de Arquivos
```bash
./fix-linux.sh
```
- Corrige quebras de linha Windows→Linux
- Torna scripts executáveis

## 🔧 Variáveis de Ambiente

Copie estas variáveis do arquivo `.env` para usar no Portainer:

```env
DOMAIN=seu-dominio.com
DATABASE=n8n
DATABASE_PASSWORD=senha_gerada
N8N_ENCRYPTION_KEY=chave_gerada
POSTGRES_PASSWORD=senha_gerada
INITIAL_ADMIN_EMAIL=seu@email.com
INITIAL_ADMIN_PASSWORD=senha_gerada
```

## 🔧 Requisitos

- **Sistema**: Debian/Ubuntu
- **Memória**: Mínimo 2GB RAM
- **Usuário**: root ou sudo
- **Domínio**: Um domínio válido

## 💬 Durante a instalação

O script perguntará apenas 4 coisas:

1. **Email do administrador**: seu-email@exemplo.com
2. **Domínio principal**: exemplo.com
3. **Nome do banco** (opcional): Tecle ENTER para usar padrão
4. **Senha do PostgreSQL** (opcional): Tecle ENTER para gerar automaticamente

## ⏱️ Tempo de instalação

- **Total**: ~5 minutos
- **Interação**: 30 segundos

## 🎯 Após a instalação

### URLs de acesso:

#### 🎛️ Portainer (Gerenciador Docker):

- **URL**: https://SEU-IP-PUBLICO:9443
- **Primeiro acesso**: Defina a senha do admin
- **Função**: Interface visual para gerenciar containers

#### 🔄 n8n (Automação):

- **Editor**: https://fluxos.SEU-DOMINIO.com
- **Webhooks**: https://webhook.SEU-DOMINIO.com
- **Login inicial**: Use o email e senha mostrados ao final da instalação
- **Nota**: O Nginx já está configurado com SSL auto-assinado!

### Arquivo de configuração:

- Todas as senhas estão em `.env`
- **GUARDE ESTE ARQUIVO!**
- Inclui credenciais do admin inicial do n8n

### Comandos úteis:

```bash
docker service ls          # Ver serviços rodando
docker-ctop               # Monitor em tempo real
docker service logs n8n   # Ver logs
source .env              # Carregar variáveis
./debug.sh               # Script de diagnóstico
```

## ❓ Problemas?

### Script não executa?

```bash
# Corrija as quebras de linha
sed -i 's/\r$//' install-simple.sh
chmod +x install-simple.sh
```

### Problemas na instalação?

```bash
# Execute o script de diagnóstico
./debug.sh

# Mostra status de tudo:
# - Docker Swarm
# - Nodes do cluster
# - Redes e volumes
# - Stacks e serviços
# - Logs dos serviços
```

### Serviços não sobem?

```bash
# Verifique os logs
docker service ls
docker service logs nome_do_servico

# Ou use o diagnóstico completo
./debug.sh
```

### Deploy manual do Portainer?

```bash
# Se o Portainer não subir automaticamente
docker volume create portainer_data
docker stack deploy -c portainer/portainer.yaml portainer
```

## 🗑️ Desinstalação

### Remover tudo completamente?

```bash
# Script de desinstalação completa
sudo ./uninstall.sh

# Remove:
# - Todos os stacks e serviços
# - Todos os volumes (DADOS PERDIDOS!)
# - Docker Swarm
# - Redes overlay
# - Opção: imagens não utilizadas
# - Mantém: arquivo .env como backup
```

### Precisa reinstalar?

```bash
# Após desinstalar, reinstale com:
sudo ./install-simple.sh
```

---

**✅ Pronto! Instalação super simplificada do n8n com PostgreSQL e Redis!**
