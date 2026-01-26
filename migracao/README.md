# 🚀 Migração do n8n v1.x → v2.4.3

## ⚡ Início Rápido

```bash
# 1. Entre na pasta
cd /caminho/para/rdd-n8n/migracao

# 2. Leia o guia
cat COMECE-AQUI.txt

# 3. Execute a migração
sudo ./migrate.sh
```

**É ISSO!** O resto é automático! 🎉

---

## 📋 Arquivos do Pacote

| Arquivo | Descrição | Para Quem |
|---------|-----------|-----------|
| **migrate.sh** | Script de migração automática v1.x → v2.4.3 | ✅ TODOS |
| **restaurar.sh** | Script de restauração (rollback) | ✅ TODOS |
| **COMECE-AQUI.txt** | Guia visual de 3 passos | 👥 Usuários |
| **LEIA-ME.txt** | Manual completo em português | 👥 Usuários |
| **README.md** | Documentação técnica (este arquivo) | 🔧 Técnicos |

---

## 🎯 O Que Cada Script Faz?

### `migrate.sh` (Principal)
- ✅ Backup automático completo (banco + arquivos + .env)
- ✅ Atualização inteligente de variáveis de ambiente
- ✅ Limpeza de migrações problemáticas do banco
- ✅ Migração em 2 etapas seguras (v1.x → v2.0.0 → v2.4.3)
- ✅ Validação de cada serviço após atualização
- ✅ Detecção e restauração automática em caso de erro
- ⏱️ Tempo: 8-12 minutos

### `restaurar.sh` (Rollback)
- 🔄 Restaura versão anterior
- 📦 Usa backup criado pelo migrate.sh
- ⏱️ Tempo: ~3 minutos

---

## 📖 Fluxo de Uso

### Para Leigos
```
1. Ler COMECE-AQUI.txt
2. Executar migrate.sh
3. Testar n8n
4. FIM! 🎉
```

### Para Técnicos
```
1. Ler README.md (este arquivo)
2. Ler LEIA-ME.txt para detalhes
3. Executar migrate.sh
4. Monitorar logs
5. Validar serviços
```

---

## ⚠️ Informações Importantes

### Requisitos
- ✅ Acesso root/sudo
- ✅ n8n v1.x instalado
- ✅ PostgreSQL como banco de dados
- ✅ ~5GB de espaço em disco
- ✅ Conexão com internet

### Downtime Esperado
- ⏸️ **~5 minutos** de indisponibilidade do n8n
- ⏱️ **8-12 minutos** de processo total (migração em 2 etapas)

### O Que é Preservado
- ✅ Todos os workflows
- ✅ Todas as credenciais
- ✅ Todas as execuções
- ✅ Todas as configurações
- ✅ Dados do banco de dados

### Variáveis de Ambiente Atualizadas
O script atualiza automaticamente o arquivo `.env`:

**Removidas (obsoletas na v2.x):**
- ❌ `N8N_CONFIG_FILES`
- ❌ `QUEUE_WORKER_MAX_STALLED_COUNT`

**Adicionadas (necessárias para v2.x):**
- ✅ `N8N_SECURE_COOKIE=true`
- ✅ `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true` (obrigatório)
- ✅ `N8N_RUNNERS_ENABLED=true`
- ✅ `N8N_RUNNERS_MODE=internal`
- ✅ `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`
- ✅ `N8N_SKIP_AUTH_ON_OAUTH_CALLBACK=false`
- ✅ `NODE_EXCLUDE="[]"`
- ✅ `N8N_GIT_NODE_DISABLE_BARE_REPOS=true`
- ✅ `EXECUTIONS_DATA_PRUNE=true`
- ✅ `EXECUTIONS_DATA_MAX_AGE=336` (14 dias)
- ✅ `N8N_LOG_LEVEL=info`

**Importante:** O script verifica se cada variável já existe antes de adicionar, respeitando personalizações existentes.

### Backups Criados
- 📦 Banco de dados PostgreSQL (SQL dump)
- 📋 Arquivos YAML de configuração
- 📄 Arquivo .env
- 📝 Logs da migração

---

## 🆘 Em Caso de Problemas

### Durante a Migração
O script `migrate.sh` restaura **automaticamente** se detectar erro.

### Após a Migração
Se quiser voltar para a versão anterior:
```bash
sudo ./restaurar.sh
```

### Suporte
- 📖 Leia: `cat LEIA-ME.txt`
- 🌐 Comunidade n8n: https://community.n8n.io/
- 📚 Documentação: https://docs.n8n.io/

---

## 📊 Estrutura do Pacote

```
migracao/
├── migrate.sh                     ← Script principal (EXECUTE ESTE!)
├── restaurar.sh                   ← Script de restauração (rollback)
├── COMECE-AQUI.txt               ← Guia visual de 3 passos
├── LEIA-ME.txt                   ← Manual completo em português
└── README.md                     ← Este arquivo (documentação técnica)

Após executar migrate.sh, serão criados:
├── backup_YYYYMMDD_HHMMSS/       ← Backup completo
│   ├── database.sql              (dump do PostgreSQL)
│   ├── orq_editor.yaml           (config do Editor)
│   ├── orq_webhook.yaml          (config do Webhook)
│   ├── orq_worker.yaml           (config do Worker)
│   ├── .env                      (variáveis originais)
│   └── .env.backup               (backup antes de modificar)
├── migracao_YYYYMMDD_HHMMSS.log  ← Log completo da migração
└── ultimo_backup.txt             ← Referência para restaurar.sh
```

---

## ✅ Checklist Pré-Migração

Antes de começar, verifique:

- [ ] Você tem acesso SSH ao servidor
- [ ] Você tem permissões de root/sudo
- [ ] O n8n está funcionando normalmente
- [ ] Há pelo menos 5GB de espaço livre em disco
- [ ] Você avisou os usuários sobre a manutenção
- [ ] Você escolheu um horário com menos movimento
- [ ] Você tem 10-15 minutos disponíveis

---

## 🎉 Após a Migração

1. ✅ Acesse o n8n: `https://fluxos.SEU-DOMINIO`
2. ✅ Faça login normalmente
3. ✅ Execute a ferramenta de verificação (se aparecer)
4. ✅ Teste seus principais workflows
5. ✅ Verifique se tudo funciona corretamente

---

## 🔍 Comandos Úteis

### Verificar Status
```bash
# Status dos serviços
docker service ls | grep n8n

# Logs do editor
docker service logs $(docker service ls --format '{{.Name}}' | grep n8n_editor)
```

### Diagnóstico
```bash
# Verificar Docker
docker info

# Verificar PostgreSQL
docker exec $(docker ps -qf name=postgres) pg_isready

# Verificar espaço em disco
df -h
```

### Backups
```bash
# Listar backups criados
ls -lht backup_*/

# Ver tamanho dos backups
du -sh backup_*/
```

---

## 💡 Dica

**Se você não tem certeza do que fazer, leia o arquivo COMECE-AQUI.txt - ele explica tudo de forma super simples!**

---

## 📞 Contato

- **Projeto**: rdd-n8n
- **Versão**: 1.0
- **Data**: Janeiro 2026
- **Compatibilidade**: n8n v1.x → v2.4.3

---

**Boa migração! 🚀**
