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

### 2️⃣ Responda 5 perguntas simples:

1. **Email do administrador**: seu-email@exemplo.com
2. **Domínio principal**: exemplo.com  
3. **Nome do banco** [ENTER = n8n]: nome_do_banco (opcional)
4. **Senha do PostgreSQL** [ENTER = auto-gerar]: senha (opcional)
5. **Deploy automático** [ENTER = Sim]: Y/n

> 💡 **Recomendado**: Tecle ENTER em tudo para usar os padrões

### 3️⃣ Aguarde ~5 minutos e pronto! 

✅ **Tudo instalado automaticamente!**

---

## 🌐 Configure o DNS (Obrigatório)

Aponte os domínios para o IP do seu servidor:

```
fluxos.SEU-DOMINIO.com   → IP_DO_SERVIDOR
webhook.SEU-DOMINIO.com  → IP_DO_SERVIDOR
```

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

---

## ⏱️ Tempo de Instalação

- **Interação**: 60 segundos (responder perguntas)
- **Instalação**: ~5 minutos (automática)
- **Aguardar serviços**: ~2 minutos adicionais

**Total**: ~8 minutos do início ao acesso

---

## 🔧 Scripts Auxiliares Inclusos

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
```

### 2️⃣ Aguarde ~2 minutos
Os serviços precisam de um tempo para inicializar completamente.

### 3️⃣ Acesse o n8n
- URL: https://fluxos.SEU-DOMINIO.com
- Use as credenciais mostradas no final da instalação

### 4️⃣ Monitore no Portainer (opcional)
- URL: https://IP_DO_SERVIDOR:9443
- Crie senha do admin no primeiro acesso

---

## 🎉 Pronto!

**✅ Instalação super simplificada do n8n com PostgreSQL e Redis!**

Tudo funciona automaticamente com SSL via Traefik e modo queue para alta performance.