# 🚀 Docker Swarm - Stack de Automação Completa

Esta é uma solução completa para deploy automatizado de uma stack de automação de workflows usando **Docker Swarm**, incluindo **PostgreSQL**, **Redis**, **n8n** e **Portainer**.

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Componentes](#componentes)
- [Pré-requisitos](#pré-requisitos)
- [Instalação Rápida](#instalação-rápida)
- [Instalação Manual](#instalação-manual)
- [Configurações](#configurações)
- [URLs de Acesso](#urls-de-acesso)
- [Gerenciamento](#gerenciamento)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Troubleshooting](#troubleshooting)
- [Contribuição](#contribuição)

## 🎯 Visão Geral

Este projeto oferece uma instalação automatizada e completa de uma infraestrutura de automação de workflows baseada em Docker Swarm, incluindo todas as dependências necessárias para um ambiente de produção robusto.

### ✨ Características Principais

- 🔧 **Instalação 100% automatizada** com um único comando
- 🐳 **Docker Swarm** para alta disponibilidade e escalabilidade
- 📊 **PostgreSQL 16** como banco de dados principal
- ⚡ **Redis 7** para cache e gerenciamento de filas
- 🔄 **n8n** em modo regular ou distribuído (queue)
- 🎛️ **Portainer** para gestão visual dos containers
- 🔒 **Configurações de segurança** automáticas
- 📝 **Logs detalhados** durante toda a instalação

## 🧩 Componentes

| Componente | Versão | Função | Porto |
|------------|--------|--------|-------|
| **PostgreSQL** | 16 | Banco de dados principal | 5432 (interno) |
| **Redis** | 7 | Cache e gerenciamento de filas | 6379 (interno) |
| **RedisInsight** | Latest | Interface web para Redis | 5540 |
| **n8n** | 1.100.1+ | Plataforma de automação | Conforme domínio |
| **Portainer** | Latest | Gestão de containers | Conforme configuração |

## ⚙️ Pré-requisitos

### Sistema Operacional
- **Debian/Ubuntu** (testado em Debian 11/12 e Ubuntu 20.04/22.04)
- **Acesso root** ou usuário com sudo

### Hardware Mínimo
- **CPU**: 2 cores
- **RAM**: 4GB
- **Disco**: 20GB livres
- **Rede**: Conectividade com a internet

### Domínios
- Um domínio principal (ex: `exemplo.com`)
- Acesso aos subdomínios:
  - `fluxos.exemplo.com` (Editor n8n)
  - `webhook.exemplo.com` (Webhooks n8n)

## 🚀 Instalação Rápida

### 1. Clone o repositório
```bash
git clone <repository-url>
cd install
```

### 2. Execute a instalação automatizada
```bash
sudo ./install.sh
```

### 3. Processo de Instalação Interativa

O script irá executar as seguintes etapas automaticamente:

#### 📋 **Etapa 1: Verificações Iniciais**
- Verifica se está rodando como root/sudo
- Confirma que é um sistema Debian/Ubuntu
- Exibe banner de início

#### 🏷️ **Etapa 2: Configuração do Hostname**
```
Digite o hostname desejado para esta máquina (ex: manager1): mgt01
```
- Define hostname do servidor
- Atualiza `/etc/hosts`
- Configura identificação no cluster

#### 🐳 **Etapa 3: Instalação do Docker**
```
=== INSTALANDO DOCKER ===
Atualizando sistema e instalando dependências...
Adicionando chave GPG do Docker...
Instalando Docker...
Docker instalado com sucesso!
```
- Instala dependências do sistema
- Adiciona repositório oficial do Docker
- Instala Docker CE, CLI e plugins
- Habilita serviços para inicialização automática

#### 🔗 **Etapa 4: Configuração do Docker Swarm**
```
Escolha uma opção:
1) Inicializar um novo Swarm (Manager)
2) Juntar-se a um Swarm existente (Worker)
Digite sua escolha (1 ou 2): 1

Digite o IP deste servidor para anunciar o Swarm: 192.168.1.100
```
- **Opção 1**: Inicializa novo cluster (primeiro servidor)
- **Opção 2**: Conecta a cluster existente (servidores adicionais)
- Cria redes overlay necessárias automaticamente

#### 🛠️ **Etapa 5: Ferramentas Opcionais**
```
Deseja instalar ctop (monitor de containers)? (y/N): y
Instalando ctop...
ctop instalado com sucesso!
```
- Oferece instalação do ctop para monitoramento

#### 📦 **Etapa 6: Criação de Volumes**
```
=== CRIANDO VOLUMES DOCKER ===
Criando volume postgres_data...
Criando volume redis_data...
Criando volume redis_insigth_data...
```
- Cria volumes persistentes para bancos de dados

#### 🗄️ **Etapa 7: Deploy do PostgreSQL**
```
Deseja fazer deploy do PostgreSQL? (Y/n): y
Digite a senha para o PostgreSQL (deixe vazio para usar padrão): [ENTER]
Fazendo deploy do PostgreSQL...
PostgreSQL deployado com sucesso!
```
- Deploy do PostgreSQL 16
- Configuração automática de senha
- Aguarda disponibilidade do serviço

#### ⚡ **Etapa 8: Deploy do Redis**
```
Deseja fazer deploy do Redis? (Y/n): y
Fazendo deploy do Redis...
Redis deployado com sucesso!

Deseja instalar RedisInsight (interface web)? (y/N): y
RedisInsight deployado com sucesso!
```
- Deploy do Redis 7 para cache e filas
- Opção de instalar interface web (porta 5540)

#### 🎛️ **Etapa 9: Deploy do Portainer (Opcional)**
```
Deseja fazer deploy do Portainer? (y/N): y
Fazendo pull da imagem do Portainer...
Fazendo deploy do Portainer...
Portainer deployado com sucesso!
```
- Interface web para gerenciar Docker Swarm

#### 🔄 **Etapa 10: Configuração do n8n**
```
=== CONFIGURANDO VARIÁVEIS DE AMBIENTE DO N8N ===
Digite o domínio principal (ex: exemplo.com): meusite.com
Subdomínios configurados:
  - Workflow Editor: fluxos
  - Webhooks: webhook

Digite o nome do banco de dados PostgreSQL: n8n_production
Digite a senha do banco de dados PostgreSQL: [senha oculta]
Digite a chave de criptografia N8N (deixe vazio para gerar automaticamente): [ENTER]
Chave de criptografia gerada automaticamente

Deseja configurar SMTP personalizado? (y/N): y
=== CONFIGURANDO SMTP ===
Host SMTP: smtp.gmail.com
Porta SMTP: 587
Usuário SMTP: seuemail@gmail.com
Senha SMTP: [senha oculta]
Email do remetente: seuemail@gmail.com
```
- Coleta domínio principal
- **Subdomínios fixos**: fluxos.meusite.com e webhook.meusite.com
- Configuração do banco de dados
- Geração automática de chave de criptografia
- Configuração SMTP opcional

#### 🚀 **Etapa 11: Deploy do n8n**
```
Escolha o modo de deploy do n8n:
1) Modo Regular (single instance)
2) Modo Queue (editor + webhook + worker)
3) Pular deploy do n8n
Digite sua escolha (1, 2 ou 3): 2

Fazendo deploy do n8n (modo queue)...
Deployando editor...
Deployando webhook...
Deployando worker...
n8n (modo queue) deployado com sucesso!
```
- **Modo Regular**: Uma instância única
- **Modo Queue**: Distribuído para alta performance
- Deploy automático com variáveis configuradas

#### ✅ **Etapa 12: Status Final**
```
=== STATUS FINAL ===
=== CONFIGURAÇÕES DAS APLICAÇÕES ===
PostgreSQL instalado:
  - Host: postgres (interno do Swarm)
  - Porta: 5432
  - Usuário: postgres
  - Senha: (salva no .env)

Redis instalado:
  - Host: redis (interno do Swarm)
  - Porta: 6379
  - RedisInsight: porta 5540

n8n instalado:
  - Editor URL: https://fluxos.meusite.com/
  - Webhook URL: https://webhook.meusite.com/
  - Banco de Dados: n8n_production

Arquivo .env criado com as variáveis de ambiente
IMPORTANTE: Guarde o arquivo .env em local seguro!
```

### 4. Tempo de Instalação
- **Tempo total**: 10-15 minutos
- **Maior parte**: Download de imagens Docker
- **Interação**: 2-3 minutos de prompts

## 🔧 Instalação Manual

Se preferir controlar cada etapa individualmente:

### 1. Configuração básica
```bash
# Configurar hostname
sudo bash infra/1.setup-base.sh

# Instalar Docker
sudo bash infra/2.setup-docker.sh

# Configurar Docker Swarm
sudo bash infra/3.setup-swarm.sh

# Instalar ferramentas opcionais
sudo bash infra/4.setup-optional.sh
```

### 2. Criar volumes
```bash
docker volume create postgres_data
docker volume create redis_data
docker volume create redis_insigth_data
```

### 3. Deploy das aplicações
```bash
# PostgreSQL
docker stack deploy -c postgres16/postgres.yaml postgres

# Redis
docker stack deploy -c redis/redis.yaml redis
docker stack deploy -c redis/redisInsight.yaml redisinsight  # Opcional

# Portainer
docker stack deploy -c portainer/portainer.yaml portainer

# n8n (modo queue)
export DOMAIN="seu-dominio.com"
export DATABASE="n8n_db"
export DATABASE_PASSWORD="sua_senha"

docker stack deploy -c n8n/queue/orq_editor.yaml n8n_editor
docker stack deploy -c n8n/queue/orq_webhook.yaml n8n_webhook
docker stack deploy -c n8n/queue/orq_worker.yaml n8n_worker
```

## ⚙️ Configurações

### Variáveis de Ambiente

O script cria automaticamente um arquivo `.env` com todas as configurações:

```bash
# Configurações de Domínio
DOMAIN=exemplo.com
WORKFLOW=fluxos
WEBHOOK=webhook

# Configurações de Banco de Dados
DATABASE=n8n_production
DATABASE_PASSWORD=senha_super_segura

# Configurações de Segurança
N8N_ENCRYPTION_KEY=chave_criptografia_32_chars

# Configurações PostgreSQL
POSTGRES_PASSWORD=senha_postgres

# Configurações SMTP (opcional)
N8N_SMTP_HOST=smtp.gmail.com
N8N_SMTP_PORT=587
N8N_SMTP_USER=seuemail@gmail.com
N8N_SMTP_PASS=sua_senha_app
N8N_SMTP_SENDER=seuemail@gmail.com
```

### Modos de Deploy do n8n

#### Modo Regular (Single Instance)
- Uma única instância do n8n
- Ideal para cargas de trabalho pequenas/médias
- Mais simples de gerenciar

#### Modo Queue (Distribuído)
- **Editor**: Interface principal
- **Webhook**: Recebe webhooks externos
- **Worker**: Executa workflows em background
- Ideal para alta disponibilidade e cargas pesadas

## 🌐 URLs de Acesso

Após a instalação completa, você terá acesso às seguintes URLs:

| Serviço | URL | Função |
|---------|-----|--------|
| **n8n Editor** | `https://fluxos.SEU_DOMINIO.com` | Interface principal do n8n |
| **n8n Webhooks** | `https://webhook.SEU_DOMINIO.com` | Endpoint para webhooks |
| **RedisInsight** | `http://SEU_SERVIDOR:5540` | Interface do Redis |
| **Portainer** | Conforme configuração YAML | Gestão de containers |

## 🛠️ Gerenciamento

### Comandos Úteis

```bash
# Ver status dos stacks
docker stack ls

# Ver serviços de um stack
docker stack services n8n_editor

# Ver logs de um serviço
docker service logs n8n_editor_n8n_editor_ip2

# Atualizar um serviço
docker service update n8n_editor_n8n_editor_ip2

# Remover um stack
docker stack rm n8n_editor

# Monitorar containers (se ctop instalado)
docker-ctop

# Carregar variáveis de ambiente
source .env
```

### Backup e Restore

#### PostgreSQL
```bash
# Backup
docker exec $(docker ps -q -f name=postgres) pg_dumpall -U postgres > backup.sql

# Restore
cat backup.sql | docker exec -i $(docker ps -q -f name=postgres) psql -U postgres
```

#### Redis
```bash
# Backup
docker exec $(docker ps -q -f name=redis) redis-cli SAVE
docker cp $(docker ps -q -f name=redis):/data/dump.rdb ./redis-backup.rdb

# Restore
docker cp ./redis-backup.rdb $(docker ps -q -f name=redis):/data/dump.rdb
docker restart $(docker ps -q -f name=redis)
```

## 📁 Estrutura do Projeto

```
install/
├── 📄 install.sh              # Script principal de instalação
├── 📄 README.md              # Este arquivo
├── 📄 CLAUDE.md              # Documentação para Claude Code
├── 📄 .env                   # Variáveis de ambiente (criado na instalação)
│
├── 📁 infra/                 # Scripts de infraestrutura
│   ├── 1.setup-base.sh      # Configuração de hostname
│   ├── 2.setup-docker.sh    # Instalação do Docker
│   ├── 3.setup-swarm.sh     # Configuração do Swarm
│   ├── 4.setup-optional.sh  # Ferramentas opcionais
│   └── 5.setup-ssh.md       # Documentação SSH
│
├── 📁 postgres16/           # PostgreSQL
│   └── postgres.yaml        # Configuração do PostgreSQL
│
├── 📁 redis/                # Redis
│   ├── redis.yaml           # Configuração do Redis
│   └── redisInsight.yaml    # Interface web do Redis
│
├── 📁 portainer/            # Portainer
│   └── portainer.yaml       # Configuração do Portainer
│
└── 📁 n8n/                  # n8n
    ├── 📁 regular/           # Modo single instance
    │   └── n8n-regular.yaml
    └── 📁 queue/             # Modo distribuído
        ├── orq_editor.yaml   # Editor
        ├── orq_webhook.yaml  # Webhook handler
        └── orq_worker.yaml   # Worker
```

## 🐛 Troubleshooting

### Problemas Comuns

#### Docker não inicia
```bash
sudo systemctl status docker
sudo systemctl restart docker
```

#### Swarm não inicializa
```bash
# Verificar se já existe um Swarm
docker info | grep Swarm

# Forçar nova inicialização
docker swarm leave --force
docker swarm init --advertise-addr=SEU_IP
```

#### Serviços não sobem
```bash
# Verificar logs
docker service logs NOME_DO_SERVICO

# Verificar recursos
docker node ls
docker system df
```

#### n8n não conecta com PostgreSQL
```bash
# Verificar se PostgreSQL está rodando
docker service ls | grep postgres

# Verificar logs do PostgreSQL
docker service logs postgres_postgres

# Verificar conectividade de rede
docker network ls | grep database
```

### Logs e Monitoramento

```bash
# Logs do script de instalação
tail -f /var/log/install.log

# Status dos serviços
docker service ls

# Uso de recursos
docker stats

# Monitoramento contínuo (se ctop instalado)
docker-ctop
```

## 🔒 Segurança

### Boas Práticas Implementadas

- ✅ **Senhas geradas automaticamente** para todos os serviços
- ✅ **Redes isoladas** para bancos de dados
- ✅ **Criptografia de dados** do n8n
- ✅ **Usuários não-root** nos containers
- ✅ **Limites de recursos** para todos os serviços

### Recomendações Adicionais

- 🔐 Altere as senhas padrão após a instalação
- 🔥 Configure firewall adequadamente
- 🔄 Implemente backups regulares
- 📊 Configure monitoramento de logs
- 🔒 Use certificados SSL válidos

## 🤝 Contribuição

Contribuições são bem-vindas! Para contribuir:

1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/nova-feature`)
3. Commit suas mudanças (`git commit -am 'Adiciona nova feature'`)
4. Push para a branch (`git push origin feature/nova-feature`)
5. Abra um Pull Request

## 📞 Suporte

Para suporte e dúvidas:

- 📧 Abra uma issue no repositório
- 📖 Consulte a documentação em `CLAUDE.md`
- 🔍 Verifique os logs de instalação

## 📝 Licença

Este projeto está sob a licença [MIT](LICENSE) - veja o arquivo LICENSE para detalhes.

---

**⚡ Feito com ❤️ para automação de workflows**

> 💡 **Dica**: Guarde o arquivo `.env` em local seguro - ele contém todas as credenciais do seu ambiente!