# 🚀 Instalação Automática do n8n + PostgreSQL + Redis

## ⚡ Instalação Completamente Automática em Uma Execução

### 🎯 O que é instalado automaticamente:
- Docker Swarm + Portainer + Traefik (SSL automático)
- PostgreSQL 16 + Redis 7 
- n8n completo (editor + webhook + worker) em modo queue
- Todas as redes, volumes e configurações necessárias

---

## 📋 Como Instalar

### 1️⃣ Execute o instalador

```bash
git clone <url-do-repositorio>
cd install
chmod +x install-simple.sh
sudo ./install-simple.sh
```

### 2️⃣ (Opcional) Configure SMTP para envio de credenciais:

```bash
sudo ./setup-smtp.sh
```

### 3️⃣ Responda 5-6 perguntas simples:

1. **Email do administrador**: seu-email@exemplo.com
2. **Domínio principal**: exemplo.com  
3. **Nome do banco** [ENTER = n8n]: nome_do_banco (opcional)
4. **Senha do PostgreSQL** [ENTER = auto-gerar]: senha (opcional)
5. **Receber credenciais por email** [ENTER = Sim]: Y/n (se SMTP configurado)
6. **Deploy automático** [ENTER = Sim]: Y/n

> 💡 **Recomendado**: Tecle ENTER em tudo para usar os padrões

### 4️⃣ Aguarde ~5 minutos e pronto! 

✅ **Tudo instalado automaticamente!**

---

## 🌐 Configure o DNS (Obrigatório)

Aponte os domínios para o IP do seu servidor:

```
fluxos.SEU-DOMINIO.com   → IP_DO_SERVIDOR
webhook.SEU-DOMINIO.com  → IP_DO_SERVIDOR
traefik.SEU-DOMINIO.com  → IP_DO_SERVIDOR (opcional)
```

**Nota**: pgAdmin não precisa de DNS, acesso direto via IP:4040

---

## 🔑 URLs de Acesso

### n8n (Automação de Workflows)
- **Editor**: https://fluxos.SEU-DOMINIO.com
- **Webhook**: https://webhook.SEU-DOMINIO.com
- **Credenciais**: Mostradas no final da instalação (salvas em `.env`)

### Portainer (Monitoramento Docker)
- **URL**: https://IP_DO_SERVIDOR:9443
- **Primeiro acesso**: Defina senha do admin
- **Função**: Monitorar containers e serviços

### Traefik (Dashboard do Proxy)
- **URL**: https://traefik.SEU-DOMINIO.com
- **Login**: admin / senha_gerada_automaticamente
- **Função**: Monitoramento do proxy reverso e SSL

### pgAdmin (Administração PostgreSQL)
- **URL**: http://IP_DO_SERVIDOR:4040
- **Login**: mesmo email da instalação / senha_gerada_automaticamente
- **Função**: Interface web para administração do PostgreSQL

---

## ⏱️ Tempo de Instalação

- **Interação**: 60-90 segundos (responder perguntas)
- **Instalação**: ~5 minutos (automática)
- **Aguardar serviços**: ~2 minutos adicionais

**Total**: ~8 minutos do início ao acesso

## 📧 Sistema de Envio de Credenciais

### 🔐 Configuração Segura
- **Configuração externa**: Credenciais SMTP fora do código fonte
- **Arquivo protegido**: `/etc/n8n-installer/smtp.conf` com permissões 600
- **Fallback inteligente**: Se email falhar, exibe na tela
- **Backup local**: Arquivo `.env` sempre mantido como backup

### 📨 Como configurar:

#### 1️⃣ Configure o SMTP (uma vez apenas):
```bash
sudo ./setup-smtp.sh
```

#### 2️⃣ Durante a instalação:
- Se SMTP configurado: pergunta se quer email
- Se SMTP não configurado: apenas credenciais na tela
- Credenciais sempre exibidas na tela também
- Arquivo `.env` sempre salvo localmente

### 🔧 Configuração Manual (alternativa):
```bash
sudo mkdir -p /etc/n8n-installer
sudo tee /etc/n8n-installer/smtp.conf > /dev/null <<EOF
SMTP_API_TOKEN=sua_chave_api_aqui
SMTP_API_URL=https://api.smtplw.com.br/v1/messages
EOF
sudo chmod 600 /etc/n8n-installer/smtp.conf
```

---

## 🔧 Scripts Auxiliares Inclusos

### Atualização do n8n
```bash
sudo ./update-n8n.sh
```
- Atualiza n8n para qualquer versão disponível
- Busca versões automaticamente no Docker Hub
- Interface interativa com seleção por menu
- Backup automático dos arquivos YAML
- Deploy sequencial otimizado (Editor → Webhook → Worker)
- Validação de imagens antes da atualização

### Configuração SSL/TLS
```bash
sudo ./update-ssl.sh
```
- Configura certificados Let's Encrypt automaticamente
- Atualiza Traefik com resolver SSL
- Redeploy de todos os serviços com certificados
- Certificados automáticos para todos os domínios

### Configuração SMTP
```bash
sudo ./setup-smtp.sh
```
- Configura credenciais para envio de email
- Cria arquivo seguro `/etc/n8n-installer/smtp.conf`
- Necessário apenas uma vez por servidor
- Habilita envio de credenciais por email

### Diagnóstico e Monitoramento
```bash
./debug.sh
```
- Verifica status do Docker Swarm
- Lista nodes, redes, volumes e stacks
- Mostra logs dos serviços
- Comandos úteis para troubleshooting

### Limpeza Rápida
```bash
./cleanup.sh
```
- Remove stacks principais (traefik, portainer)
- Limpa sistema Docker
- Desativa Docker Swarm
- Rápido e direto

### Desinstalação Completa
```bash
sudo ./uninstall.sh
```
- Remove todos os stacks e serviços
- Apaga volumes (⚠️ **DADOS PERDIDOS!**)
- Desativa Docker Swarm
- Remove redes overlay
- Mantém backup do `.env`

### Deploy Manual via API (se necessário)
```bash
./deploy-api.sh
```
- Para casos onde o deploy automático falhou
- Usa API do Portainer para deploy
- Não requer upload manual de arquivos

### Criação Manual do Banco (se necessário)
```bash
./create-database.sh
```
- Cria o banco n8n manualmente se não foi criado automaticamente
- Conecta no PostgreSQL e executa CREATE DATABASE
- Útil para resolver erro "database does not exist"

---

## 🔧 Variáveis de Ambiente

Todas as configurações ficam salvas no arquivo `.env`:

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
EDITOR_URL=https://fluxos.seu-dominio.com
WEBHOOK_URL=https://webhook.seu-dominio.com
```

---

## 📊 Comandos Úteis

```bash
# Ver status dos serviços
docker service ls

# Monitorar containers em tempo real
docker-ctop

# Ver logs de um serviço específico
docker service logs nome_do_servico

# Ver stacks instalados
docker stack ls

# Carregar variáveis do .env
source .env

# Script de diagnóstico completo
./debug.sh
```

---

## ❓ Resolução de Problemas

### Script não executa?
```bash
# Corrigir permissões e quebras de linha
sed -i 's/\r$//' *.sh
chmod +x *.sh
```

### Serviços não sobem?
```bash
# Diagnóstico completo
./debug.sh

# Ver logs específicos
docker service logs postgres_postgres
docker service logs n8n_editor_n8n
```

### n8n não acessa?
1. ✅ Verifique se o DNS está configurado
2. ✅ Aguarde ~2 minutos para todos os serviços subirem
3. ✅ Verifique no Portainer se todos estão rodando

### Erro "database does not exist"?
```bash
# Criar banco manualmente se necessário
./create-database.sh
```

### Portainer não acessa?
```bash
# Verificar se está rodando
docker service ls | grep portainer

# Reinstalar se necessário
docker stack deploy -c portainer/portainer.yaml portainer
```

---

## 🗑️ Desinstalação

### Limpeza Rápida (mantém dados)
```bash
./cleanup.sh
```

### Remoção Completa (apaga tudo)
```bash
sudo ./uninstall.sh
```

### Reinstalar
```bash
# Após desinstalar, reinstale com:
sudo ./install-simple.sh
```

---

## 🔧 Requisitos do Sistema

- **OS**: Debian/Ubuntu (64-bit)
- **RAM**: Mínimo 2GB (recomendado 4GB+)
- **CPU**: 1 core (recomendado 2+ cores)
- **Disco**: 10GB+ livres
- **Usuário**: root ou sudo
- **Domínio**: Um domínio válido configurado

---

## ✅ Próximos Passos Após Instalação

### 1️⃣ Configure o DNS
```
fluxos.SEU-DOMINIO.com   → IP_DO_SERVIDOR
webhook.SEU-DOMINIO.com  → IP_DO_SERVIDOR
traefik.SEU-DOMINIO.com  → IP_DO_SERVIDOR (opcional)
```

### 2️⃣ Configure SSL (Recomendado)
```bash
sudo ./update-ssl.sh
```
- Configura certificados Let's Encrypt automaticamente
- Aguarde ~2 minutos para emissão dos certificados

### 3️⃣ Aguarde ~2 minutos
Os serviços precisam de um tempo para inicializar completamente.

### 4️⃣ Acesse o n8n
- URL: https://fluxos.SEU-DOMINIO.com
- Use as credenciais mostradas no final da instalação

### 5️⃣ Monitore no Portainer (opcional)
- URL: https://IP_DO_SERVIDOR:9443
- Crie senha do admin no primeiro acesso
- ⚠️ **IMPORTANTE**: Acesse em até 10 minutos após instalação

### 6️⃣ Acesse pgAdmin (se necessário)
- URL: http://IP_DO_SERVIDOR:4040
- Login: email da instalação / senha gerada automaticamente
- Para administração do PostgreSQL

---

## 🔄 Manutenção e Atualizações

### Atualizar n8n para Nova Versão
```bash
sudo ./update-n8n.sh
```
- Interface interativa para selecionar versões
- Backup automático antes da atualização
- Deploy otimizado com delays apropriados

### Configurar SSL/TLS
```bash
sudo ./update-ssl.sh
```
- Configura certificados Let's Encrypt
- Redeploy automático com SSL ativo

### Verificar Status dos Serviços
```bash
./debug.sh
docker service ls
docker stack ls
```

---

## 🎉 Pronto!

**✅ Instalação super simplificada do n8n com PostgreSQL e Redis!**

Tudo funciona automaticamente com SSL via Traefik e modo queue para alta performance.

### 🚀 Principais Recursos:
- ✅ **Docker Swarm** - Orquestração robusta
- ✅ **n8n Queue Mode** - Editor + Webhook + Worker  
- ✅ **PostgreSQL 16** - Banco de dados principal
- ✅ **Redis 7** - Cache e filas de trabalho
- ✅ **Traefik v3** - Proxy reverso com SSL automático
- ✅ **Portainer** - Interface de gerenciamento
- ✅ **pgAdmin 4** - Administração PostgreSQL
- ✅ **Let's Encrypt** - Certificados SSL gratuitos
- ✅ **Sistema SMTP** - Envio seguro de credenciais
- ✅ **Scripts de Manutenção** - Atualização, diagnóstico, limpeza