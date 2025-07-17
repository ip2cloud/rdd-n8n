# 🚀 Instalação Rápida do n8n

## ⚡ Instalação em 3 Passos

### 1️⃣ Clone o projeto
```bash
git clone <url-do-repositorio>
cd install
```

### 2️⃣ Execute o instalador
```bash
sudo ./install-simple.sh
```

### 3️⃣ Configure o DNS
Aponte os domínios para o IP do servidor:
- `fluxos.SEU-DOMINIO.com` → IP do servidor
- `webhook.SEU-DOMINIO.com` → IP do servidor

## 📋 O que será instalado

- ✅ Docker e Docker Swarm
- ✅ PostgreSQL 16 (banco de dados)
- ✅ Redis 7 (cache e filas)
- ✅ n8n em modo distribuído
- ✅ ctop (monitor de containers)

## 🔧 Requisitos

- **Sistema**: Debian/Ubuntu
- **Memória**: Mínimo 2GB RAM
- **Usuário**: root ou sudo
- **Domínio**: Um domínio válido

## 💬 Durante a instalação

O script perguntará apenas 3 coisas:

1. **Domínio principal**: exemplo.com
2. **Nome do banco** (opcional): Tecle ENTER para usar padrão
3. **Senha do PostgreSQL** (opcional): Tecle ENTER para gerar automaticamente

## ⏱️ Tempo de instalação

- **Total**: ~5 minutos
- **Interação**: 30 segundos

## 🎯 Após a instalação

### URLs de acesso:
- **Editor n8n**: https://fluxos.SEU-DOMINIO.com
- **Webhooks**: https://webhook.SEU-DOMINIO.com

### Arquivo de configuração:
- Todas as senhas estão em `.env`
- **GUARDE ESTE ARQUIVO!**

### Comandos úteis:
```bash
docker service ls          # Ver serviços rodando
docker-ctop               # Monitor em tempo real
docker service logs n8n   # Ver logs
source .env              # Carregar variáveis
```

## ❓ Problemas?

### Script não executa?
```bash
# Corrija as quebras de linha
sed -i 's/\r$//' install-simple.sh
chmod +x install-simple.sh
```

### Serviços não sobem?
```bash
# Verifique os logs
docker service ls
docker service logs nome_do_servico
```

### Precisa reinstalar?
```bash
# Remove tudo e instala novamente
docker stack rm $(docker stack ls --format "{{.Name}}")
docker volume prune -f
./install-simple.sh
```

---

**✅ Pronto! Instalação super simplificada do n8n com PostgreSQL e Redis!**