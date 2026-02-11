# 🚀 Quick Start - Sistema SOAR

Guia rápido para colocar o sistema SOAR em funcionamento em **30 minutos**.

---

## Pré-requisitos ✅

- [ ] n8n instalado e acessível
- [ ] Wazuh funcionando com agentes
- [ ] GLPI acessível
- [ ] TacticalRMM com agentes
- [ ] Conta Telegram

---

## 1. Obter Credenciais (10 min)

### VirusTotal
```bash
# Acesse: https://www.virustotal.com/gui/my-apikey
# Crie conta gratuita e copie API Key
```

### OpenAI
```bash
# Acesse: https://platform.openai.com/api-keys
# Crie API key e copie
# OU use Ollama local (gratuito)
```

### GLPI
```bash
# 1. App Token
# GLPI → Setup → General → API → Add API Client
# Copie o token

# 2. User Token
# GLPI → Meu Perfil → Configurações → Tokens API → Adicionar
# Copie o token

# 3. Session Token
curl -X POST https://glpi.dlino.us/apirest.php/initSession \
  -H "App-Token: SEU_APP_TOKEN" \
  -H "Authorization: user_token SEU_USER_TOKEN"
# Copie "session_token" do resultado
```

### TacticalRMM
```bash
# TacticalRMM → Settings → Global Settings → API Keys → Generate
# Copie a chave
```

### Telegram
```bash
# 1. Bot Token
# Abra @BotFather no Telegram
# Envie: /newbot
# Siga instruções e copie token

# 2. Chat ID
# Abra @userinfobot no Telegram
# Envie: /start
# Copie seu User ID
```

---

## 2. Configurar n8n (10 min)

### Importar Workflow

1. Acesse n8n: `https://n8n.dlino.us`
2. **Workflows** → **Import from File**
3. Selecione: `workflows/workflow_soar_principal.json`

### ⚠️ CORRIGIR NÓ DE IA (IMPORTANTE!)

O workflow usa OpenAI (pago). **OBRIGATÓRIO corrigir para IA gratuita:**

**Opção Recomendada: Groq (5 min)**

1. Obtenha API Key: https://console.groq.com/ → API Keys → Create
2. No n8n: Settings → Credentials → Add → HTTP Header Auth
   - Name: `Groq API`
   - Header: `Authorization`
   - Value: `Bearer gsk_sua_key`
3. No workflow: DELETE o nó "IA Analysis (OpenAI)"
4. Adicione HTTP Request:
   - URL: `https://api.groq.com/openai/v1/chat/completions`
   - Method: POST
   - Auth: Groq API
   - Body: Ver [docs/CORRIGIR-WORKFLOW.md](docs/CORRIGIR-WORKFLOW.md)
5. Conecte: Load IA Prompt → IA Analysis → Parse

**📖 Guia Completo:** [docs/CORRIGIR-WORKFLOW.md](docs/CORRIGIR-WORKFLOW.md)

**Alternativas:** Ollama (local) ou Gemini (grátis)

### Configurar Credenciais

**Settings → Credentials → Add Credential**

#### 1. VirusTotal
- Tipo: **HTTP Header Auth**
- Nome: `VirusTotal API`
- Header Name: `x-apikey`
- Header Value: `sua-virustotal-api-key`

#### 2. GLPI
- Tipo: **HTTP Header Auth**
- Nome: `GLPI API`
- Headers (adicione 3):
  - `Session-Token`: seu-session-token
  - `App-Token`: seu-app-token
  - `Content-Type`: application/json

#### 3. TacticalRMM
- Tipo: **HTTP Header Auth**
- Nome: `TacticalRMM API`
- Header Name: `X-API-KEY`
- Header Value: `sua-tactical-api-key`

#### 4. Telegram
- Tipo: **Telegram**
- Bot Token: `123456:ABC...`
- Em "Additional Fields" → Chat ID: `seu-chat-id`

### Ativar Workflow

No workflow importado, clique em **Activate** (canto superior direito).

---

## 3. Configurar Wazuh (5 min)

### Editar ossec.conf

```bash
ssh user@soc.dlino.us
sudo nano /var/ossec/etc/ossec.conf
```

### Adicionar Webhook

Dentro de `<ossec_config>`:

```xml
<integration>
  <name>custom-webhook</name>
  <hook_url>https://n8n.dlino.us/webhook/wazuh-alert</hook_url>
  <level>7</level>
  <alert_format>json</alert_format>
</integration>
```

**Substitua a URL pelo webhook real do n8n!**

Copie de: n8n → workflow → nó "Webhook Wazuh" → Production URL

### Reiniciar Wazuh

```bash
sudo systemctl restart wazuh-manager
```

---

## 4. Configurar Telegram Webhook (2 min)

```bash
# Copie URL do webhook do n8n
# n8n → workflow → nó "Webhook Telegram Callback" → Production URL

# Configure webhook
curl -X POST https://api.telegram.org/bot<SEU_BOT_TOKEN>/setWebhook \
  -d "url=https://n8n.dlino.us/webhook/telegram-callback"
```

---

## 5. Testar Sistema (3 min)

### Teste Simples

Envie alerta fake para o n8n:

```bash
curl -X POST https://n8n.dlino.us/webhook/wazuh-alert \
  -H "Content-Type: application/json" \
  -d '{
    "id": "test-001",
    "agent": {"name": "TEST-PC", "ip": "192.168.1.100", "id": "001"},
    "rule": {"id": "87101", "description": "Test alert", "level": 12},
    "timestamp": "2025-10-27T10:30:00Z"
  }'
```

**Você deve:**
1. Ver execução no n8n (Executions)
2. Receber mensagem no Telegram
3. Ver ticket criado no GLPI

### Teste Real (com Wazuh)

Em uma estação com Wazuh Agent:

```powershell
# Windows PowerShell
echo "X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*" > C:\Users\Public\eicar.txt
```

Aguarde alguns segundos e verifique:
- [ ] Alerta no Wazuh
- [ ] Execução no n8n
- [ ] Mensagem no Telegram
- [ ] Ticket no GLPI

---

## 6. Aprovar Remediação (via Telegram)

Quando receber mensagem no Telegram:

1. Clique em **"✅ Aplicar Agora"**
2. Aguarde ~30 segundos
3. Receba notificação de sucesso ou falha
4. Verifique ticket no GLPI (deve estar fechado se sucesso)

---

## 🎉 Pronto!

Seu sistema SOAR está funcionando!

---

## Próximos Passos

1. **Upload de Scripts no RMM**
   ```bash
   # TacticalRMM → Settings → Scripts → Add Script
   # Upload de todos os .ps1 da pasta scripts/powershell/
   ```

2. **Ajustar Severidade**
   - Edite workflow para definir quais níveis auto-remediam
   - Recomendado: CRITICAL = só notifica, HIGH = pede aprovação

3. **Customizar IA**
   - Edite o prompt em: `prompts/ia_soar_prompt.md`
   - Ajuste para seu ambiente específico

4. **Monitorar**
   - Observe execuções por 1 semana
   - Ajuste regras do Wazuh conforme necessário
   - Valide que remediações estão funcionando

5. **Documentar Playbooks**
   - Documente remediações aprovadas
   - Crie biblioteca de scripts personalizados

---

## Troubleshooting Rápido

### Workflow não executa
- Verifique se está **Activated**
- Teste webhook manualmente com curl
- Veja logs em n8n → Executions

### Telegram não envia mensagem
```bash
# Teste bot
curl https://api.telegram.org/bot<TOKEN>/getMe

# Teste envio
curl -X POST https://api.telegram.org/bot<TOKEN>/sendMessage \
  -d "chat_id=<CHAT_ID>" \
  -d "text=Teste"
```

### GLPI não cria ticket
```bash
# Teste session token
curl https://glpi.dlino.us/apirest.php/getFullSession \
  -H "Session-Token: TOKEN" \
  -H "App-Token: TOKEN"

# Se expirou, gere novo
curl -X POST https://glpi.dlino.us/apirest.php/initSession \
  -H "App-Token: TOKEN" \
  -H "Authorization: user_token TOKEN"
```

### TacticalRMM não executa
- Verifique se hostname bate (Wazuh vs RMM)
- Teste script manual no RMM
- Verifique se agente está online

---

## Suporte

- 📖 [Documentação completa](README.md)
- 🔧 [Setup Wazuh](docs/setup-wazuh.md)
- 💬 [Setup Telegram](docs/setup-telegram.md)
- 🎫 [Setup GLPI](docs/setup-glpi.md)

---

**Tempo total:** ~30 minutos
**Dificuldade:** ⭐⭐⭐ (Intermediário)
**Status:** ✅ Pronto para usar
