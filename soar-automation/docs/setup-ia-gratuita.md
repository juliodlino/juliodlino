# 🤖 Alternativas de IA Gratuitas para SOAR

## Por que usar alternativas gratuitas?

O workflow original usa OpenAI (pago). Estas alternativas são:
- ✅ **Gratuitas** (ou locais)
- ✅ **Rápidas** (Groq é extremamente rápido)
- ✅ **Sem limites de custo** (Ollama é local)

---

## 🚀 Opção 1: Groq (RECOMENDADO)

**Características:**
- ✅ **Gratuito** (6.000 requests/dia, 30 req/min)
- ✅ **Extremamente rápido** (até 10x mais rápido que OpenAI)
- ✅ **API compatível com OpenAI**
- ✅ **Vários modelos:** Llama 3, Mixtral, Gemma

### Setup Groq

#### 1. Obter API Key

1. Acesse: https://console.groq.com/
2. Crie conta gratuita
3. Vá em **API Keys**
4. Clique em **Create API Key**
5. Copie a chave (formato: `gsk_...`)

#### 2. Configurar no n8n

**Opção A: HTTP Request Node (SIMPLES)**

No workflow, substitua o nó "IA Analysis (OpenAI)" por **HTTP Request**:

```json
{
  "parameters": {
    "method": "POST",
    "url": "https://api.groq.com/openai/v1/chat/completions",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "=Bearer {{ $credentials.groqApiKey }}"
        },
        {
          "name": "Content-Type",
          "value": "application/json"
        }
      ]
    },
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "body",
          "value": "={{ JSON.stringify({\n  model: 'llama-3.1-70b-versatile',\n  messages: [\n    {\n      role: 'system',\n      content: $('Load IA Prompt').item.json.system_prompt\n    },\n    {\n      role: 'user',\n      content: $('Load IA Prompt').item.json.user_prompt\n    }\n  ],\n  temperature: 0.3,\n  max_tokens: 1000\n}) }}"
        }
      ]
    },
    "options": {}
  },
  "name": "IA Analysis (Groq)",
  "type": "n8n-nodes-base.httpRequest"
}
```

**Credencial HTTP Header Auth:**
- Nome: `Groq API`
- Header Name: `Authorization`
- Header Value: `Bearer gsk_sua_api_key_aqui`

#### 3. Modelos Disponíveis (Groq)

| Modelo | Descrição | Velocidade | Qualidade |
|--------|-----------|------------|-----------|
| `llama-3.1-70b-versatile` | **RECOMENDADO** | ⚡⚡⚡ | ⭐⭐⭐⭐⭐ |
| `llama-3.1-8b-instant` | Mais rápido | ⚡⚡⚡⚡⚡ | ⭐⭐⭐⭐ |
| `mixtral-8x7b-32768` | Contexto longo | ⚡⚡⚡ | ⭐⭐⭐⭐ |
| `gemma2-9b-it` | Google Gemma | ⚡⚡⚡⚡ | ⭐⭐⭐⭐ |

**Recomendação:** Use `llama-3.1-70b-versatile` (melhor custo-benefício).

#### 4. Limites Gratuitos

- **Requests/dia:** 14.400 (mais que suficiente)
- **Requests/minuto:** 30
- **Tokens/minuto:** 7.000

---

## 💻 Opção 2: Ollama (Local - SEM CUSTOS)

**Características:**
- ✅ **100% Gratuito**
- ✅ **Sem limites**
- ✅ **Privacidade total** (roda local)
- ✅ **Offline** (não precisa internet)
- ⚠️ Requer GPU ou CPU potente

### Setup Ollama

#### 1. Instalar Ollama

**Linux:**
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

**Windows:**
- Baixe: https://ollama.com/download/windows
- Execute o instalador

**macOS:**
```bash
brew install ollama
```

#### 2. Baixar Modelo

```bash
# Modelo recomendado (3GB)
ollama pull llama3.2:3b

# Ou modelo maior (4.7GB)
ollama pull llama3.1:8b

# Ou Mixtral (26GB - requer GPU)
ollama pull mixtral:8x7b
```

#### 3. Iniciar Servidor

```bash
# Linux/macOS
ollama serve

# Windows (já inicia automaticamente)
```

Servidor fica em: `http://localhost:11434`

#### 4. Configurar no n8n

**HTTP Request Node:**

```json
{
  "parameters": {
    "method": "POST",
    "url": "http://localhost:11434/api/generate",
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "body",
          "value": "={{ JSON.stringify({\n  model: 'llama3.2:3b',\n  prompt: $('Load IA Prompt').item.json.system_prompt + '\\n\\n' + $('Load IA Prompt').item.json.user_prompt,\n  stream: false,\n  format: 'json',\n  options: {\n    temperature: 0.3,\n    num_predict: 1000\n  }\n}) }}"
        }
      ]
    },
    "options": {}
  },
  "name": "IA Analysis (Ollama)",
  "type": "n8n-nodes-base.httpRequest"
}
```

**Sem credenciais necessárias!** (roda local)

#### 5. Modelos Recomendados (Ollama)

| Modelo | Tamanho | RAM Mínimo | GPU | Qualidade |
|--------|---------|------------|-----|-----------|
| `llama3.2:3b` | 2GB | 8GB | Opcional | ⭐⭐⭐⭐ |
| `llama3.1:8b` | 4.7GB | 8GB | Recomendado | ⭐⭐⭐⭐⭐ |
| `phi3:medium` | 7.9GB | 16GB | Recomendado | ⭐⭐⭐⭐ |
| `mixtral:8x7b` | 26GB | 32GB | Necessário | ⭐⭐⭐⭐⭐ |

**Para hardware humilde:** `llama3.2:3b`

---

## 🌐 Opção 3: Google Gemini (Gratuito)

**Características:**
- ✅ **Gratuito** (60 req/min)
- ✅ **Qualidade alta**
- ✅ **Multimodal** (aceita imagens)
- ⚠️ Requer conta Google

### Setup Gemini

#### 1. Obter API Key

1. Acesse: https://aistudio.google.com/app/apikey
2. Login com conta Google
3. Clique em **Get API Key**
4. Copie a chave

#### 2. Configurar no n8n

**HTTP Request Node:**

```json
{
  "parameters": {
    "method": "POST",
    "url": "=https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={{ $credentials.geminiApiKey }}",
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "body",
          "value": "={{ JSON.stringify({\n  contents: [{\n    parts: [{\n      text: $('Load IA Prompt').item.json.system_prompt + '\\n\\n' + $('Load IA Prompt').item.json.user_prompt\n    }]\n  }],\n  generationConfig: {\n    temperature: 0.3,\n    maxOutputTokens: 1000\n  }\n}) }}"
        }
      ]
    },
    "options": {}
  },
  "name": "IA Analysis (Gemini)",
  "type": "n8n-nodes-base.httpRequest"
}
```

**Credencial (armazenada como variável):**
- Nome: `geminiApiKey`
- Valor: `sua_api_key_aqui`

#### 3. Modelos Disponíveis

| Modelo | Grátis? | Velocidade | Qualidade |
|--------|---------|------------|-----------|
| `gemini-1.5-flash` | ✅ 60 req/min | ⚡⚡⚡⚡⚡ | ⭐⭐⭐⭐ |
| `gemini-1.5-pro` | ✅ 2 req/min | ⚡⚡⚡ | ⭐⭐⭐⭐⭐ |

**Recomendação:** `gemini-1.5-flash` (rápido e gratuito)

---

## 📊 Comparação

| IA | Custo | Velocidade | Setup | Offline | Qualidade | Limites |
|----|-------|------------|-------|---------|-----------|---------|
| **Groq** | 🟢 Grátis | ⚡⚡⚡⚡⚡ | ⭐ Fácil | ❌ | ⭐⭐⭐⭐⭐ | 14.4k/dia |
| **Ollama** | 🟢 Grátis | ⚡⚡⚡ | ⭐⭐ Médio | ✅ | ⭐⭐⭐⭐ | Ilimitado |
| **Gemini** | 🟢 Grátis | ⚡⚡⚡⚡ | ⭐ Fácil | ❌ | ⭐⭐⭐⭐ | 60/min |
| **OpenAI** | 🔴 Pago | ⚡⚡⚡ | ⭐ Fácil | ❌ | ⭐⭐⭐⭐⭐ | Depende $ |

---

## 🎯 Recomendação por Cenário

### Hardware Humilde + Internet Boa
**→ Use Groq** 🏆
- Extremamente rápido
- Gratuito
- Sem instalação local

### Hardware Humilde + Internet Instável
**→ Use Ollama (llama3.2:3b)** 🏆
- Funciona offline
- Sem custos
- 2GB de download

### Hardware Potente
**→ Use Ollama (llama3.1:8b ou mixtral)** 🏆
- Melhor qualidade
- Privacidade total
- Sem limites

### Necessita Multimodal (análise de imagens)
**→ Use Gemini** 🏆
- Aceita imagens
- Gratuito
- Alta qualidade

---

## 🛠️ Como Trocar no Workflow

### Passo 1: Abra o workflow no n8n

### Passo 2: Delete o nó "IA Analysis (OpenAI)"

### Passo 3: Adicione um nó "HTTP Request"

### Passo 4: Configure conforme a IA escolhida (veja exemplos acima)

### Passo 5: Conecte:
```
Load IA Prompt → IA Analysis (Groq/Ollama/Gemini) → Parse IA Response
```

### Passo 6: Ajuste o nó "Parse IA Response"

O parse precisa extrair a resposta do formato específico de cada API:

**Para Groq/OpenAI:**
```javascript
const iaResponse = $input.first().json.choices[0].message.content;
```

**Para Ollama:**
```javascript
const iaResponse = $input.first().json.response;
```

**Para Gemini:**
```javascript
const iaResponse = $input.first().json.candidates[0].content.parts[0].text;
```

---

## 🔧 Troubleshooting

### Groq: Erro 429 (Rate Limit)
- Você atingiu o limite de 30 req/min
- Aguarde 1 minuto ou use modelo mais rápido

### Ollama: Connection refused
```bash
# Verifique se está rodando
curl http://localhost:11434/api/tags

# Se não, inicie
ollama serve
```

### Gemini: Erro 400
- Verifique formato do JSON
- API Key está correta?
- Modelo existe? (use gemini-1.5-flash)

---

## 📚 Links Úteis

- **Groq:** https://console.groq.com/
- **Ollama:** https://ollama.com/
- **Gemini:** https://aistudio.google.com/

---

**Recomendação final:** Comece com **Groq** (mais fácil). Se precisar de privacidade, migre para **Ollama**.
