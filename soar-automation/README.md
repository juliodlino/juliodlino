# 🛡️ Sistema SOAR - Automação de Resposta a Incidentes

Sistema completo de **Security Orchestration, Automation and Response** integrado com Wazuh, n8n, GLPI, TacticalRMM e Telegram.

> ⚠️ **IMPORTANTE:** Após importar o workflow, você precisa corrigir o nó de IA que usa OpenAI (pago).
> 📖 **Guia de Correção:** [docs/CORRIGIR-WORKFLOW.md](docs/CORRIGIR-WORKFLOW.md)
> 🚀 **Recomendado:** Use **Groq** (gratuito e extremamente rápido) - setup em 5 minutos!

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Configuração](#configuração)
- [Uso](#uso)
- [Scripts Disponíveis](#scripts-disponíveis)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

---

## 🎯 Visão Geral

Este sistema automatiza todo o ciclo de resposta a incidentes de segurança:

1. **Detecção** → Wazuh detecta vulnerabilidade ou ameaça
2. **Enriquecimento** → Consulta VirusTotal para contexto adicional
3. **Análise** → IA analisa o incidente e sugere solução
4. **Ticketing** → Cria ticket no GLPI automaticamente
5. **Aprovação** → Solicita aprovação humana via Telegram
6. **Remediação** → Executa script via TacticalRMM
7. **Verificação** → Valida se remediação funcionou
8. **Notificação** → Informa resultado e fecha ticket

### Fluxo Visual

```
┌─────────┐     ┌─────────┐     ┌────────────┐     ┌──────┐
│  Wazuh  │────▶│   n8n   │────▶│ VirusTotal │────▶│  IA  │
└─────────┘     └─────────┘     └────────────┘     └──────┘
                     │                                  │
                     │            ┌──────┐              │
                     └───────────▶│ GLPI │◀─────────────┘
                                  └──────┘
                                     │
                     ┌───────────────┴────────────────┐
                     ▼                                ▼
              ┌──────────┐                    ┌──────────────┐
              │ Telegram │                    │ TacticalRMM  │
              │(Aprovação)│                    │ (Remediação) │
              └──────────┘                    └──────────────┘
                     │                                │
                     └────────────┬───────────────────┘
                                  ▼
                          ┌──────────────┐
                          │   Resultado  │
                          │ (Notificação)│
                          └──────────────┘
```

---

## 🏗️ Arquitetura

### Componentes

| Componente | URL | Função |
|------------|-----|--------|
| **n8n** | n8n.dlino.us | Orquestração do workflow |
| **Wazuh** | soc.dlino.us | Detecção de ameaças |
| **GLPI** | glpi.dlino.us | Sistema de tickets |
| **TacticalRMM** | rmm.dlino.us | Execução remota |
| **Telegram** | - | Interface de aprovação |
| **VirusTotal** | - | Threat intelligence |
| **OpenAI/Claude** | - | Análise de IA |

### Identificação de Ativos (Wazuh ↔ TacticalRMM)

**Campo Comum:** `hostname` ou `IP`

- **Wazuh:** `agent.name` ou `agent.ip`
- **TacticalRMM:** `hostname` ou `IP address`

O workflow busca o agente no RMM usando o hostname reportado pelo Wazuh.

---

## ✅ Pré-requisitos

### Serviços Necessários

1. **n8n** instalado e acessível
2. **Wazuh** com agentes instalados nas estações
3. **GLPI** com API habilitada
4. **TacticalRMM** com agentes nas estações
5. **Telegram Bot** criado (via @BotFather)
6. **API Keys:**
   - VirusTotal API key (gratuita)
   - OpenAI API key ou Ollama local
   - GLPI Session Token + App Token
   - TacticalRMM API Key

### Software nas Estações

- Windows 10/11 ou Windows Server
- PowerShell 5.1 ou superior
- Wazuh Agent instalado
- TacticalRMM Agent instalado

---

## 📥 Instalação

### 1. Clone ou Baixe os Arquivos

```bash
git clone https://github.com/seu-usuario/soar-automation.git
cd soar-automation
```

### 2. Estrutura de Diretórios

```
soar-automation/
├── workflows/
│   └── workflow_soar_principal.json
├── prompts/
│   └── ia_soar_prompt.md
├── scripts/
│   ├── powershell/
│   │   ├── quarantine-file.ps1
│   │   ├── kill-suspicious-process.ps1
│   │   ├── network-isolate.ps1
│   │   └── collect-evidence.ps1
│   └── verification/
│       └── verify-remediation.ps1
├── configs/
│   └── credentials.example.env
├── docs/
│   ├── setup-n8n.md
│   ├── setup-wazuh.md
│   ├── setup-telegram.md
│   └── setup-glpi.md
└── README.md
```

---

## ⚙️ Configuração

### 1. Configurar Credenciais

Copie o arquivo de exemplo e preencha com suas credenciais:

```bash
cp configs/credentials.example.env configs/credentials.env
```

Edite `configs/credentials.env`:

```env
# VirusTotal
VIRUSTOTAL_API_KEY=sua-api-key-aqui

# OpenAI (ou use Ollama local)
OPENAI_API_KEY=sk-sua-key-aqui

# GLPI
GLPI_BASE_URL=https://glpi.dlino.us
GLPI_APP_TOKEN=seu-app-token
GLPI_SESSION_TOKEN=seu-session-token

# TacticalRMM
TACTICAL_RMM_URL=https://rmm.dlino.us
TACTICAL_RMM_API_KEY=sua-api-key

# Telegram
TELEGRAM_BOT_TOKEN=123456:ABC-DEF...
TELEGRAM_CHAT_ID=seu-chat-id
```

### 2. Importar Workflow no n8n

1. Acesse n8n: `https://n8n.dlino.us`
2. Clique em **Import from File**
3. Selecione: `workflows/workflow_soar_principal.json`
4. O workflow será importado com todos os nós

### 3. Configurar Credenciais no n8n

#### VirusTotal
1. No n8n, vá em **Settings** → **Credentials**
2. Clique em **Add Credential**
3. Escolha **HTTP Header Auth**
4. Nome: `VirusTotal API`
5. Header Name: `x-apikey`
6. Header Value: `sua-virustotal-api-key`

#### GLPI
1. Crie nova credencial **HTTP Header Auth**
2. Nome: `GLPI API`
3. Adicione 3 headers:
   - `Session-Token`: seu-session-token
   - `App-Token`: seu-app-token
   - `Content-Type`: application/json

**Como obter tokens GLPI:**
```bash
# 1. App Token: GLPI → Setup → General → API
# 2. Session Token via API:
curl -X POST https://glpi.dlino.us/apirest.php/initSession \
  -H "App-Token: SEU_APP_TOKEN" \
  -H "Authorization: user_token SEU_USER_TOKEN"
```

#### TacticalRMM
1. Crie nova credencial **HTTP Header Auth**
2. Nome: `TacticalRMM API`
3. Header Name: `X-API-KEY`
4. Header Value: `sua-tactical-api-key`

**Como obter API Key do TacticalRMM:**
- TacticalRMM → Settings → Global Settings → API Keys → Generate

#### OpenAI
1. Crie nova credencial **OpenAI**
2. API Key: `sk-sua-key`

**Alternativa: Usar Ollama Local**
- Substitua o nó "IA Analysis (OpenAI)" por **HTTP Request** apontando para seu Ollama
- Endpoint: `http://localhost:11434/api/generate`

#### Telegram
1. Crie nova credencial **Telegram**
2. Bot Token: obtido via @BotFather
3. Chat ID: envie mensagem para @userinfobot

### 4. Configurar Webhooks

#### Webhook Wazuh (Recebe Alertas)

No workflow n8n, copie a URL do webhook "Webhook Wazuh":
```
https://n8n.dlino.us/webhook/wazuh-alert
```

Configure no Wazuh (`ossec.conf`):

```xml
<integration>
  <name>custom-webhook</name>
  <hook_url>https://n8n.dlino.us/webhook/wazuh-alert</hook_url>
  <level>7</level>
  <alert_format>json</alert_format>
</integration>
```

Reinicie Wazuh:
```bash
systemctl restart wazuh-manager
```

#### Webhook Telegram (Recebe Callbacks)

No workflow n8n, copie a URL do webhook "Webhook Telegram Callback":
```
https://n8n.dlino.us/webhook/telegram-callback
```

Configure no Telegram Bot:
```bash
curl -X POST https://api.telegram.org/bot<BOT_TOKEN>/setWebhook \
  -d "url=https://n8n.dlino.us/webhook/telegram-callback"
```

### 5. Upload de Scripts para TacticalRMM

1. Acesse TacticalRMM → **Settings** → **Scripts**
2. Clique em **Add Script**
3. Upload de cada script:
   - `quarantine-file.ps1`
   - `kill-suspicious-process.ps1`
   - `network-isolate.ps1`
   - `collect-evidence.ps1`
   - `verify-remediation.ps1`

**Ou via API:**
```bash
for script in scripts/powershell/*.ps1; do
  curl -X POST https://rmm.dlino.us/api/v3/scripts/ \
    -H "X-API-KEY: sua-api-key" \
    -F "name=$(basename $script)" \
    -F "script=@$script"
done
```

---

## 🚀 Uso

### Ativação do Workflow

1. No n8n, abra o workflow **SOAR - Automação de Resposta a Incidentes**
2. Clique em **Activate** no canto superior direito
3. Workflow ficará aguardando alertas do Wazuh

### Testando o Sistema

#### Teste Manual (sem Wazuh)

Envie um alerta fake para o webhook:

```bash
curl -X POST https://n8n.dlino.us/webhook/wazuh-alert \
  -H "Content-Type: application/json" \
  -d '{
    "id": "test-123",
    "agent": {
      "name": "WORKSTATION-01",
      "ip": "192.168.1.100",
      "id": "001"
    },
    "rule": {
      "id": "87101",
      "description": "Malware detected - Windows Defender",
      "level": 12
    },
    "syscheck": {
      "path": "C:\\Users\\test\\Downloads\\malware.exe",
      "md5_after": "5d41402abc4b2a76b9719d911017c592"
    },
    "timestamp": "2025-10-27T10:30:00.000Z"
  }'
```

#### Teste com Wazuh Real

Crie um arquivo de teste em uma estação monitorada:

```powershell
# Na estação Windows
echo "X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*" > C:\Users\Public\eicar.txt
```

O Wazuh deve detectar e enviar alerta para o n8n.

### Fluxo Esperado

1. **Alerta detectado** → Você verá execução no n8n
2. **VirusTotal consultado** → Hash verificado
3. **IA analisa** → Sugere solução
4. **Ticket criado** → Verifique GLPI
5. **Mensagem no Telegram** → Você recebe notificação com botões
6. **Clique "✅ Aplicar Agora"** → Script é executado via RMM
7. **Aguarde 30s** → Sistema verifica resultado
8. **Notificação final** → Sucesso ou falha

---

## 📜 Scripts Disponíveis

### 1. Quarentena de Arquivo
**Arquivo:** `quarantine-file.ps1`

**Uso:**
```powershell
.\quarantine-file.ps1 -FilePath "C:\Users\test\malware.exe"
```

**O que faz:**
- Move arquivo para `C:\ProgramData\SOAR\Quarantine`
- Salva metadados (hash, timestamp, etc.)
- Verifica processos ativos
- Retorna JSON com resultado

---

### 2. Matar Processo Suspeito
**Arquivo:** `kill-suspicious-process.ps1`

**Uso:**
```powershell
# Por nome
.\kill-suspicious-process.ps1 -ProcessName "malware" -RemovePersistence

# Por PID
.\kill-suspicious-process.ps1 -ProcessId 1234
```

**O que faz:**
- Encerra processo
- Remove entradas de registro (Run keys)
- Remove scheduled tasks relacionadas
- Remove itens de startup

---

### 3. Isolamento de Rede
**Arquivo:** `network-isolate.ps1`

**Uso:**
```powershell
# Isolar
.\network-isolate.ps1 -Isolate

# Restaurar
.\network-isolate.ps1 -Restore
```

**O que faz:**
- Cria regras de firewall que bloqueiam tudo exceto RMM
- Faz backup das regras atuais
- Permite restaurar conectividade depois

⚠️ **CUIDADO:** Use apenas em emergências! Bloqueia toda conectividade.

---

### 4. Coletar Evidências
**Arquivo:** `collect-evidence.ps1`

**Uso:**
```powershell
.\collect-evidence.ps1 -IncidentId "INC-2025-001"
```

**O que faz:**
- Coleta processos, conexões de rede, serviços
- Coleta logs de eventos
- Identifica arquivos modificados recentemente
- Gera relatório JSON + TXT
- Compacta tudo em ZIP

**Output:** `C:\ProgramData\SOAR\Evidence\INC-2025-001-YYYYMMDD-HHMMSS.zip`

---

### 5. Verificar Remediação
**Arquivo:** `verify-remediation.ps1`

**Uso:**
```powershell
# Verificar quarentena
.\verify-remediation.ps1 -RemediationType FileQuarantine -TargetPath "C:\malware.exe"

# Verificar processo
.\verify-remediation.ps1 -RemediationType ProcessKill -TargetProcess "malware"

# Verificar isolamento
.\verify-remediation.ps1 -RemediationType NetworkIsolation
```

**O que faz:**
- Valida se remediação foi bem-sucedida
- Retorna JSON com status (Success/Failure)
- Exit code 0 = sucesso, 1 = falha

---

## 🔧 Troubleshooting

### Problema: Workflow não recebe alertas do Wazuh

**Solução:**
1. Verifique se webhook está configurado no Wazuh (`/var/ossec/etc/ossec.conf`)
2. Teste manualmente:
   ```bash
   curl -X POST https://n8n.dlino.us/webhook/wazuh-alert -d '{"test":"data"}'
   ```
3. Verifique logs do Wazuh: `/var/ossec/logs/ossec.log`
4. Certifique-se que o level no `<integration>` está correto (ex: 7)

### Problema: VirusTotal retorna erro 403

**Solução:**
- API key incorreta ou expirada
- Verifique em: https://www.virustotal.com/gui/my-apikey
- Limite de requests excedido (free tier: 4 req/min)

### Problema: GLPI não cria ticket

**Solução:**
1. Verifique se API está habilitada: GLPI → Setup → General → API
2. Teste a API:
   ```bash
   curl https://glpi.dlino.us/apirest.php/getFullSession \
     -H "Session-Token: seu-token" \
     -H "App-Token: seu-app-token"
   ```
3. Session tokens expiram! Gere novo se necessário.

### Problema: TacticalRMM não executa script

**Solução:**
1. Verifique se agente está online: TacticalRMM → Agents
2. Verifique se hostname bate com o reportado pelo Wazuh
3. Teste execução manual no RMM
4. Verifique permissões do script (precisa ser PowerShell)

### Problema: Telegram não envia mensagens

**Solução:**
1. Verifique bot token: `curl https://api.telegram.org/bot<TOKEN>/getMe`
2. Verifique chat ID: envie mensagem para @userinfobot
3. Certifique-se que o bot foi iniciado (envie `/start`)
4. Webhook configurado? Verifique com:
   ```bash
   curl https://api.telegram.org/bot<TOKEN>/getWebhookInfo
   ```

### Problema: IA retorna JSON inválido

**Solução:**
- O nó "Parse IA Response" já trata isso com fallback
- Ajuste temperature para 0.1 (mais determinístico)
- Use modelo mais recente (gpt-4o-mini, claude-3-5-sonnet)
- Ou use Ollama local: `llama3.2:3b`

---

## 🔐 Segurança

### Boas Práticas

1. **Credenciais:**
   - Nunca commite `credentials.env` no git
   - Use `.env` no n8n para variáveis sensíveis
   - Rotacione API keys periodicamente

2. **Acesso:**
   - n8n deve ter autenticação habilitada
   - Use HTTPS em todos os endpoints
   - Whitelist de IPs no webhook (se possível)

3. **Scripts:**
   - Sempre valide input antes de executar
   - Nunca execute scripts de fontes não confiáveis
   - Mantenha logs de todas as execuções

4. **Aprovação Humana:**
   - NUNCA remova aprovação para ações críticas
   - Configure timeout de 30min para aprovações
   - Defina níveis de severidade (CRITICAL = só notifica)

### Níveis de Severidade Recomendados

```yaml
CRITICAL:
  - Ação: Apenas notifica, não auto-remedia
  - Exemplos: Ransomware, RCE, lateral movement

HIGH:
  - Ação: Pede aprovação (fluxo atual)
  - Exemplos: Malware detectado, exploit attempt

MEDIUM:
  - Ação: Auto-remedia + notifica depois
  - Exemplos: Arquivo suspeito, comportamento anômalo

LOW:
  - Ação: Log apenas
  - Exemplos: Scan de portas, tentativa de acesso
```

---

## 📚 Documentação Adicional

- [Setup detalhado do n8n](docs/setup-n8n.md)
- [Configuração do Wazuh](docs/setup-wazuh.md)
- [Criando Telegram Bot](docs/setup-telegram.md)
- [API do GLPI](docs/setup-glpi.md)
- [Prompt da IA explicado](prompts/ia_soar_prompt.md)

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Abra uma issue ou PR.

---

## 📝 Licença

MIT License - use como quiser!

---

## 📞 Suporte

- Issues: https://github.com/seu-usuario/soar-automation/issues
- Documentação oficial:
  - [n8n](https://docs.n8n.io/)
  - [Wazuh](https://documentation.wazuh.com/)
  - [TacticalRMM](https://docs.tacticalrmm.com/)
  - [GLPI](https://glpi-project.org/documentation/)

---

## 🎉 Próximos Passos

Após configuração completa:

1. ✅ Teste com alerta fake
2. ✅ Teste com Wazuh real (arquivo EICAR)
3. ✅ Valide criação de ticket no GLPI
4. ✅ Teste aprovação no Telegram
5. ✅ Verifique execução via RMM
6. ✅ Monitore por 1 semana em modo observação
7. ✅ Ative remediação automática para casos LOW/MEDIUM

---

**Versão:** 1.0
**Última atualização:** 2025-10-27
**Autor:** dlino.us
**Status:** ✅ Pronto para produção
