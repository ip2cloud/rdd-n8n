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

## 📋 Arquivos Disponíveis

| Arquivo | Descrição | Para Quem |
|---------|-----------|-----------|
| **COMECE-AQUI.txt** | Guia visual de 3 passos | 👥 Leigos |
| **LEIA-ME.txt** | Manual completo em português | 👥 Leigos |
| **migrate.sh** | Script de migração automática | ✅ TODOS |
| **restaurar.sh** | Restaurar versão anterior | ✅ TODOS |
| **README.md** | Este arquivo | 🔧 Técnicos |

---

## 🎯 O Que Cada Script Faz?

### `migrate.sh` (Principal)
- ✅ Backup automático completo
- ✅ Atualização para v2.4.3
- ✅ Verificação de funcionamento
- ✅ Restauração automática se houver erro
- ⏱️ Tempo: 5-8 minutos

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
- ⏸️ **3-5 minutos** de indisponibilidade do n8n
- ⏱️ **5-8 minutos** de processo total

### O Que é Preservado
- ✅ Todos os workflows
- ✅ Todas as credenciais
- ✅ Todas as execuções
- ✅ Todas as configurações
- ✅ Dados do banco de dados

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

## 📊 Estrutura Após Migração

```
migracao/
├── COMECE-AQUI.txt           ← Leia primeiro!
├── LEIA-ME.txt               ← Manual completo
├── migrate.sh                ← Execute este!
├── restaurar.sh              ← Restauração
├── README.md                 ← Este arquivo
├── backup_YYYYMMDD_HHMMSS/   ← Criado automaticamente
│   ├── database.sql
│   ├── orq_editor.yaml
│   ├── orq_webhook.yaml
│   ├── orq_worker.yaml
│   └── .env
└── migracao_YYYYMMDD_HHMMSS.log  ← Log (criado automaticamente)
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
