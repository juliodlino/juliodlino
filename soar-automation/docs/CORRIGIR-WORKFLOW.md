# 🔧 Como Corrigir o Workflow (Problema no nó IA)

## ⚠️ Problema Identificado

O workflow original usa o nó `@n8n/n8n-nodes-langchain.openAi` que:
- Pode não estar instalado no seu n8n
- Requer pacote LangChain adicional
- É pago (OpenAI)

## ✅ Solução: Usar HTTP Request Simples

Vamos substituir o nó problemático por um **HTTP Request** comum que funciona com IAs gratuitas.

---

## 🚀 Opção 1: Groq (RECOMENDADO - Grátis e Super Rápido)

### Passo 1: Obter API Key do Groq

1. Acesse: https://console.groq.com/
2. Crie conta gratuita
3. Vá em **API Keys** → **Create API Key**
4. Copie a chave (começa com `gsk_...`)

### Passo 2: Configurar Credencial no n8n

1. No n8n, vá em **Settings** → **Credentials**
2. Clique em **Add Credential**
3. Escolha **HTTP Header Auth**
4. Preencha:
   - **Name**: `Groq API`
   - **Header Name**: `Authorization`
   - **Header Value**: `Bearer gsk_sua_api_key_aqui`
5. Salve

### Passo 3: Modificar o Workflow

1. Abra o workflow no n8n
2. **DELETE** o nó "IA Analysis (OpenAI)"
3. Adicione um nó **HTTP Request**
4. Renomeie para: `IA Analysis (Groq)`
5. Configure assim:

**Authentication:**
- ✅ Generic Credential Type
- Credential Type: **HTTP Header Auth**
- Credential: Selecione **Groq API**

**Request:**
- Method: **POST**
- URL: `https://api.groq.com/openai/v1/chat/completions`

**Headers:**
Adicione 2 headers:

| Name | Value |
|------|-------|
| `Authorization` | `=Bearer {{ $credentials.groqApiKey }}` |
| `Content-Type` | `application/json` |

**Body:**
- Send Body: ✅ Yes
- Body Content Type: **JSON**
- Specify Body: Using Fields Below

Adicione 1 parâmetro:

**Name:** `body`
**Value:**
```javascript
={{ JSON.stringify({
  model: "llama-3.1-70b-versatile",
  messages: [
    {
      role: "system",
      content: $('Load IA Prompt').item.json.system_prompt
    },
    {
      role: "user",
      content: $('Load IA Prompt').item.json.user_prompt
    }
  ],
  temperature: 0.3,
  max_tokens: 1000
}) }}
```

### Passo 4: Conectar

Conecte os nós:
```
Load IA Prompt → IA Analysis (Groq) → Parse IA Response
```

### Passo 5: Testar

Clique em **Execute Workflow** para testar!

---

## 💻 Opção 2: Ollama (Local - 100% Grátis)

### Passo 1: Instalar Ollama

**Linux/macOS:**
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

**Windows:**
- Baixe: https://ollama.com/download/windows

### Passo 2: Baixar Modelo

```bash
# Modelo leve (2GB)
ollama pull llama3.2:3b

# OU modelo melhor (4.7GB)
ollama pull llama3.1:8b
```

### Passo 3: Iniciar Servidor

```bash
ollama serve
```

Servidor roda em: `http://localhost:11434`

### Passo 4: Modificar Workflow

1. Delete o nó "IA Analysis (OpenAI)"
2. Adicione **HTTP Request**
3. Renomeie para: `IA Analysis (Ollama)`
4. Configure:

**Request:**
- Method: **POST**
- URL: `http://localhost:11434/api/generate`
- Authentication: **None** (é local!)

**Body:**
```javascript
={{ JSON.stringify({
  model: "llama3.2:3b",
  prompt: $('Load IA Prompt').item.json.system_prompt + '\n\n' + $('Load IA Prompt').item.json.user_prompt,
  stream: false,
  format: "json",
  options: {
    temperature: 0.3,
    num_predict: 1000
  }
}) }}
```

### Passo 5: Ajustar Parse

**IMPORTANTE:** A resposta do Ollama é diferente!

Abra o nó **"Parse IA Response"** e modifique linha 3:

**De:**
```javascript
const iaResponse = $input.first().json.message?.content || $input.first().json.choices?.[0]?.message?.content || '';
```

**Para:**
```javascript
const iaResponse = $input.first().json.response || $input.first().json.choices?.[0]?.message?.content || '';
```

---

## 🌐 Opção 3: Google Gemini (Grátis)

### Passo 1: Obter API Key

1. Acesse: https://aistudio.google.com/app/apikey
2. Login com conta Google
3. **Get API Key**
4. Copie a chave

### Passo 2: Modificar Workflow

1. Delete o nó "IA Analysis (OpenAI)"
2. Adicione **HTTP Request**
3. Renomeie para: `IA Analysis (Gemini)`
4. Configure:

**Request:**
- Method: **POST**
- URL: `=https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={{ $credentials.geminiApiKey }}`

**Body:**
```javascript
={{ JSON.stringify({
  contents: [{
    parts: [{
      text: $('Load IA Prompt').item.json.system_prompt + '\n\n' + $('Load IA Prompt').item.json.user_prompt
    }]
  }],
  generationConfig: {
    temperature: 0.3,
    maxOutputTokens: 1000
  }
}) }}
```

### Passo 3: Ajustar Parse

No nó **"Parse IA Response"**, linha 3:

**Para:**
```javascript
const iaResponse = $input.first().json.candidates?.[0]?.content?.parts?.[0]?.text || '';
```

---

## 📊 Comparação Rápida

| IA | Setup | Velocidade | Qualidade | Custo |
|----|-------|------------|-----------|-------|
| **Groq** | 5min ⭐ | ⚡⚡⚡⚡⚡ | ⭐⭐⭐⭐⭐ | 🟢 Grátis |
| **Ollama** | 15min ⭐⭐ | ⚡⚡⚡ | ⭐⭐⭐⭐ | 🟢 Grátis |
| **Gemini** | 5min ⭐ | ⚡⚡⚡⚡ | ⭐⭐⭐⭐ | 🟢 Grátis |

**Recomendação:** Comece com **Groq** (mais fácil e rápido).

---

## 🎬 Video Tutorial

Se preferir um guia visual, aqui está o passo a passo:

### Para Groq:

1. **Obter API Key**
   - Console Groq → API Keys → Create → Copiar

2. **No n8n:**
   - Credenciais → Add → HTTP Header Auth
   - Name: Groq API
   - Header: Authorization
   - Value: Bearer gsk_...

3. **No Workflow:**
   - Delete nó OpenAI
   - Add HTTP Request
   - URL: `https://api.groq.com/openai/v1/chat/completions`
   - Auth: Groq API
   - Body: (copiar código acima)
   - Conectar: Load IA Prompt → IA Analysis → Parse

4. **Testar!**

---

## ❌ Problemas Comuns

### Erro: "Could not connect to remote server"
- **Groq/Gemini:** Verifique sua conexão com internet
- **Ollama:** Execute `ollama serve` em outro terminal

### Erro: "Invalid API key"
- Verifique se copiou a chave completa
- Para Groq, deve começar com `gsk_`
- Recrie a credencial no n8n

### Erro: "Model not found" (Ollama)
```bash
# Verifique modelos instalados
ollama list

# Baixe o modelo correto
ollama pull llama3.2:3b
```

### IA retorna texto mas não JSON
- Adicione no body do Groq: `response_format: { type: "json_object" }`
- O nó "Parse IA Response" já tem fallback para isso

---

## 📚 Mais Informações

- [Groq Docs](https://console.groq.com/docs)
- [Ollama Docs](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Gemini Docs](https://ai.google.dev/docs)

---

## ✅ Checklist

Após modificar, verifique:

- [ ] Nó "IA Analysis" foi substituído por HTTP Request
- [ ] Credencial configurada corretamente
- [ ] Body do request está correto
- [ ] Conexões entre nós estão OK
- [ ] Parse IA Response ajustado (se Ollama ou Gemini)
- [ ] Workflow ativado
- [ ] Teste manual funcionou

---

**Pronto!** Agora seu workflow usa IA gratuita e rápida! 🚀

**Próximo:** Teste com alerta real do Wazuh
