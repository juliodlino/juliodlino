# Configuração do Telegram Bot para SOAR

## Objetivo

Criar e configurar um bot do Telegram para enviar notificações de incidentes e receber aprovações de remediação.

---

## 1. Criar Bot no Telegram

### Passo 1: Abrir @BotFather

1. Abra o Telegram
2. Busque por **@BotFather**
3. Inicie conversa com `/start`

### Passo 2: Criar Novo Bot

Digite:
```
/newbot
```

BotFather vai pedir:
1. **Nome do bot**: `SOAR Security Bot` (ou qualquer nome)
2. **Username**: `dlino_soar_bot` (deve terminar com `_bot`)

### Passo 3: Copiar Token

BotFather retorna algo como:
```
Done! Congratulations on your new bot. You will find it at t.me/dlino_soar_bot.
You can now add a description, about section and profile picture for your bot.

Use this token to access the HTTP API:
123456789:ABCdefGHIjklMNOpqrsTUVwxyz

For a description of the Bot API, see this page: https://core.telegram.org/bots/api
```

**Copie o token!**

---

## 2. Obter Chat ID

### Método 1: Usando @userinfobot

1. Busque por **@userinfobot** no Telegram
2. Inicie conversa com `/start`
3. O bot retorna seu **User ID** (este é seu Chat ID)

### Método 2: Via API

1. Envie qualquer mensagem para seu bot
2. Execute:
   ```bash
   curl https://api.telegram.org/bot<SEU_TOKEN>/getUpdates
   ```
3. Procure por `"chat":{"id":123456789`
4. Este número é seu Chat ID

### Método 3: Para Grupos

Se quiser receber em um grupo:

1. Adicione o bot ao grupo
2. Faça o bot admin (opcional)
3. Envie uma mensagem no grupo
4. Execute:
   ```bash
   curl https://api.telegram.org/bot<SEU_TOKEN>/getUpdates
   ```
5. Procure por `"chat":{"id":-100123456789` (negativo para grupos)

---

## 3. Configurar Webhook

O webhook permite que o Telegram envie callbacks (cliques em botões) para o n8n.

### Obter URL do Webhook n8n

No workflow n8n, copie a URL do nó "Webhook Telegram Callback":
```
https://n8n.dlino.us/webhook/telegram-callback
```

### Configurar Webhook

```bash
curl -X POST https://api.telegram.org/bot<SEU_TOKEN>/setWebhook \
  -d "url=https://n8n.dlino.us/webhook/telegram-callback"
```

**Resposta esperada:**
```json
{"ok":true,"result":true,"description":"Webhook was set"}
```

### Verificar Webhook

```bash
curl https://api.telegram.org/bot<SEU_TOKEN>/getWebhookInfo
```

**Resposta:**
```json
{
  "ok": true,
  "result": {
    "url": "https://n8n.dlino.us/webhook/telegram-callback",
    "has_custom_certificate": false,
    "pending_update_count": 0
  }
}
```

---

## 4. Testar Bot

### Teste Simples

Envie mensagem de teste:

```bash
curl -X POST https://api.telegram.org/bot<SEU_TOKEN>/sendMessage \
  -d "chat_id=<SEU_CHAT_ID>" \
  -d "text=🚨 Teste do SOAR Bot!"
```

Você deve receber a mensagem no Telegram.

### Teste com Botões

```bash
curl -X POST https://api.telegram.org/bot<SEU_TOKEN>/sendMessage \
  -H "Content-Type: application/json" \
  -d '{
    "chat_id": "<SEU_CHAT_ID>",
    "text": "🚨 *TESTE DE INCIDENTE*\n\nDeseja aplicar remediação?",
    "parse_mode": "Markdown",
    "reply_markup": {
      "inline_keyboard": [[
        {"text": "✅ Sim", "callback_data": "approve:test123"},
        {"text": "❌ Não", "callback_data": "reject:test123"}
      ]]
    }
  }'
```

Ao clicar nos botões, o callback será enviado para o webhook do n8n.

---

## 5. Configurar Notificações

### Silenciar Notificações (Opcional)

Para enviar mensagem sem notificação sonora:

```bash
curl -X POST https://api.telegram.org/bot<SEU_TOKEN>/sendMessage \
  -d "chat_id=<SEU_CHAT_ID>" \
  -d "text=Mensagem silenciosa" \
  -d "disable_notification=true"
```

### Formatar Mensagens

Telegram suporta:
- **Markdown**: `*bold*`, `_italic_`, `[link](url)`, `` `code` ``
- **HTML**: `<b>bold</b>`, `<i>italic</i>`, `<a href="url">link</a>`

No workflow n8n, usamos Markdown.

---

## 6. Melhorias Opcionais

### Adicionar Foto de Perfil

1. No Telegram, envie para @BotFather:
   ```
   /setuserpic
   ```
2. Selecione seu bot
3. Envie uma imagem (ex: logo de segurança)

### Adicionar Descrição

```
/setdescription
```

Exemplo:
```
Bot de automação SOAR para resposta a incidentes de segurança.
Integrado com Wazuh, GLPI e TacticalRMM.
```

### Adicionar Comandos

```
/setcommands
```

Exemplo:
```
status - Ver status do sistema
help - Ajuda sobre comandos
```

### Configurar Privacy Mode

Por padrão, bots em grupos só veem mensagens que começam com `/`.

Para ver todas as mensagens:
```
/setprivacy
```
Selecione: **Disable**

---

## 7. Segurança

### Proteger Token

⚠️ **NUNCA** compartilhe o token do bot!

Se vazou, revogue:
```
/revoke
```

BotFather gerará novo token.

### Whitelist de Usuários

No workflow n8n, adicione validação de usuário:

```javascript
// No nó "Parse Telegram Callback"
const allowedUsers = [123456789, 987654321]; // IDs permitidos

if (!allowedUsers.includes($json.user_id)) {
  throw new Error('Usuário não autorizado');
}
```

### Timeout de Aprovação

Configure timeout no workflow (já incluído):

- Após 30 minutos sem resposta, escala para outro canal
- Ou marca ticket como "Aguardando aprovação manual"

---

## 8. Exemplo de Mensagem do SOAR

Quando um incidente é detectado, você recebe:

```
🚨 ALERTA DE SEGURANÇA 🚨

Incidente: INC-1730030400-001
Severidade: HIGH
Ativo: WORKSTATION-01 (192.168.1.100)

📋 Resumo:
Malware detectado pelo Windows Defender em arquivo
baixado. Confirmado por 30 engines no VirusTotal.

🔍 Análise Técnica:
Arquivo executável suspeito detectado como
Win32/Trojan.Banker. Hash confirmado em bases
de threat intelligence.

💡 Solução Proposta:
Move arquivo malicioso para quarentena do Windows
Defender e verifica se há outros arquivos relacionados.

🦠 VirusTotal: 30 detecções
📊 Ticket GLPI: #1234

⚡ Deseja aplicar a solução automaticamente?

[✅ Aplicar Agora] [❌ Recusar]
[🔍 Mais Informações] [🚨 Investigar Manualmente]
```

Ao clicar em um botão, o workflow continua automaticamente.

---

## 9. Comandos Úteis para Debugging

### Ver Mensagens Pendentes

```bash
curl https://api.telegram.org/bot<TOKEN>/getUpdates
```

### Limpar Webhooks

Se quiser voltar para polling:

```bash
curl -X POST https://api.telegram.org/bot<TOKEN>/deleteWebhook
```

### Logs de Erro

Se webhook falhar, Telegram tenta algumas vezes e depois:

```bash
curl https://api.telegram.org/bot<TOKEN>/getWebhookInfo
```

Verá erros em `last_error_message`.

---

## 10. Referências

- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Inline Keyboards](https://core.telegram.org/bots/features#inline-keyboards)
- [Webhooks Guide](https://core.telegram.org/bots/webhooks)
- [Best Practices](https://core.telegram.org/bots/features#botfather)

---

## 11. Troubleshooting

### Bot não responde

**Verificar:**
1. Token correto?
   ```bash
   curl https://api.telegram.org/bot<TOKEN>/getMe
   ```
2. Chat ID correto?
3. Bot foi iniciado? Envie `/start` para o bot.

### Webhook não funciona

**Verificar:**
1. URL é HTTPS? Telegram não aceita HTTP.
2. Certificado SSL válido?
3. n8n está acessível publicamente?

**Testar manualmente:**
```bash
curl -X POST https://n8n.dlino.us/webhook/telegram-callback \
  -H "Content-Type: application/json" \
  -d '{"callback_query":{"data":"approve:test"}}'
```

### Botões não aparecem

- Certifique-se de usar `reply_markup` com `inline_keyboard`
- Formato deve ser array de arrays: `[[button1, button2]]`

---

**Próximo passo:** [Configurar GLPI API](setup-glpi.md)
