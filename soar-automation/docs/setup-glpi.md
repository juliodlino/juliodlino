# Configuração da API do GLPI para SOAR

## Objetivo

Habilitar e configurar a API REST do GLPI para criação e atualização automática de tickets.

---

## 1. Habilitar API REST no GLPI

### Passo 1: Acessar Configurações

1. Acesse GLPI: `https://glpi.dlino.us`
2. Login como admin
3. Vá em: **Setup** → **General** → **API**

### Passo 2: Ativar API

Marque as opções:
- ✅ **Enable Rest API**
- ✅ **Enable login with credentials**
- ✅ **Enable login with external token**

Clique em **Save**.

---

## 2. Gerar App Token

App Token identifica sua aplicação (n8n).

### Criar API Client

1. No GLPI, vá em: **Setup** → **General** → **API**
2. Clique em **Add API Client**
3. Preencha:
   - **Name**: `SOAR n8n Integration`
   - **Active**: ✅ Yes
   - **IPv4 address range**: `0.0.0.0/0` (ou IP do n8n para mais segurança)
   - **IPv6 address range**: `::/0`

4. Clique em **Add**

5. **Copie o App Token** gerado (formato: `abcd1234efgh5678...`)

⚠️ **Importante:** Guarde este token, não será mostrado novamente!

---

## 3. Gerar User Token

User Token identifica o usuário que criará tickets.

### Método 1: Via Interface

1. Login no GLPI com usuário desejado
2. Vá em: **Meu Perfil** (canto superior direito)
3. Aba **Configurações**
4. Seção **Tokens de API remota**
5. Clique em **Adicionar**
6. **Copie o User Token** gerado

### Método 2: Via Banco de Dados (para usuário específico)

```sql
-- Conecte no MySQL do GLPI
mysql -u glpi -p glpidb

-- Gerar token para usuário
INSERT INTO glpi_users_tokens (users_id, token, creation_date)
VALUES (
  (SELECT id FROM glpi_users WHERE name = 'glpi'),
  SHA2(CONCAT('soar-', NOW(), RAND()), 256),
  NOW()
);

-- Ver token gerado
SELECT token FROM glpi_users_tokens WHERE users_id = (SELECT id FROM glpi_users WHERE name = 'glpi') ORDER BY id DESC LIMIT 1;
```

---

## 4. Gerar Session Token

Session Token é temporário e expira. Precisa ser renovado periodicamente.

### Iniciar Sessão via API

```bash
curl -X POST https://glpi.dlino.us/apirest.php/initSession \
  -H "App-Token: SEU_APP_TOKEN" \
  -H "Authorization: user_token SEU_USER_TOKEN" \
  -H "Content-Type: application/json"
```

**Resposta:**
```json
{
  "session_token": "abc123def456..."
}
```

**Copie o `session_token`.**

### Duração do Token

Session tokens expiram após:
- **1 hora** de inatividade (padrão)
- **24 horas** máximo

Para renovar, repita o comando `initSession`.

---

## 5. Testar API

### Verificar Sessão

```bash
curl https://glpi.dlino.us/apirest.php/getFullSession \
  -H "Session-Token: SEU_SESSION_TOKEN" \
  -H "App-Token: SEU_APP_TOKEN"
```

**Resposta:** Dados da sessão ativa.

### Criar Ticket de Teste

```bash
curl -X POST https://glpi.dlino.us/apirest.php/Ticket \
  -H "Session-Token: SEU_SESSION_TOKEN" \
  -H "App-Token: SEU_APP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "name": "[TESTE] Ticket criado via API",
      "content": "Este é um ticket de teste criado pela API REST do GLPI.",
      "urgency": 3,
      "impact": 3,
      "priority": 3,
      "status": 2,
      "type": 1
    }
  }'
```

**Resposta:**
```json
{
  "id": 1234,
  "message": "Item successfully added: Ticket"
}
```

Verifique no GLPI: o ticket #1234 deve ter sido criado!

### Atualizar Ticket

```bash
curl -X PUT https://glpi.dlino.us/apirest.php/Ticket/1234 \
  -H "Session-Token: SEU_SESSION_TOKEN" \
  -H "App-Token: SEU_APP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "status": 5,
      "solution": "Problema resolvido via SOAR"
    }
  }'
```

**Status:**
- 1 = New
- 2 = Processing (assigned)
- 3 = Planning
- 4 = Pending
- 5 = Solved
- 6 = Closed

---

## 6. Estrutura de Ticket SOAR

O workflow cria tickets com esta estrutura:

```json
{
  "input": {
    "name": "[SOAR] MALWARE - WORKSTATION-01",
    "content": "<h3>Incidente de Segurança Detectado</h3>...",
    "urgency": 5,
    "impact": 5,
    "priority": 5,
    "status": 2,
    "type": 1,
    "itilcategories_id": 0
  }
}
```

### Mapeamento de Severidade

| Severidade Wazuh | Urgency | Impact | Priority |
|------------------|---------|--------|----------|
| CRITICAL (12+) | 5 (muito alta) | 5 | 5 |
| HIGH (7-11) | 4 (alta) | 4 | 4 |
| MEDIUM (5-6) | 3 (média) | 3 | 3 |
| LOW (<5) | 2 (baixa) | 2 | 2 |

### Categorias (opcional)

Para organizar tickets, crie categoria no GLPI:

1. **Setup** → **Dropdowns** → **Tickets** → **Categories**
2. Crie: `Incidentes de Segurança`
3. Copie o ID da categoria
4. Use no workflow: `"itilcategories_id": 10`

---

## 7. Renovar Session Token Automaticamente

Session tokens expiram. Você tem duas opções:

### Opção 1: Renovar Manualmente

Sempre que expirar, execute:
```bash
curl -X POST https://glpi.dlino.us/apirest.php/initSession \
  -H "App-Token: SEU_APP_TOKEN" \
  -H "Authorization: user_token SEU_USER_TOKEN"
```

Atualize o Session Token no n8n.

### Opção 2: Criar Workflow de Renovação no n8n

Crie workflow separado que:
1. Executa a cada 30 minutos (Schedule Trigger)
2. Chama `/initSession`
3. Atualiza credencial no n8n via API

**Exemplo:**
```javascript
// Nó HTTP Request
const response = await $http.request({
  method: 'POST',
  url: 'https://glpi.dlino.us/apirest.php/initSession',
  headers: {
    'App-Token': $credentials.glpiAppToken,
    'Authorization': `user_token ${$credentials.glpiUserToken}`
  }
});

// Atualizar credencial (requer API do n8n habilitada)
await $http.request({
  method: 'PATCH',
  url: 'http://localhost:5678/api/v1/credentials/CREDENTIAL_ID',
  auth: {
    username: 'n8n-user',
    password: 'n8n-password'
  },
  json: {
    data: {
      glpiSessionToken: response.session_token
    }
  }
});
```

---

## 8. Permissões Necessárias

O usuário que gera o User Token precisa de:

**Profile:** Technician ou Super-Admin

**Permissões mínimas:**
- Tickets → Create: ✅
- Tickets → Update own: ✅
- Tickets → Update all: ✅ (recomendado)
- Tickets → Close: ✅
- Tickets → Add followup: ✅

Verificar em: **Administration** → **Profiles** → **Technician** → **Assistance**

---

## 9. Endpoints Úteis

### Listar Tickets

```bash
curl https://glpi.dlino.us/apirest.php/Ticket \
  -H "Session-Token: TOKEN" \
  -H "App-Token: TOKEN"
```

### Buscar Ticket por ID

```bash
curl https://glpi.dlino.us/apirest.php/Ticket/1234 \
  -H "Session-Token: TOKEN" \
  -H "App-Token: TOKEN"
```

### Adicionar Followup (comentário)

```bash
curl -X POST https://glpi.dlino.us/apirest.php/Ticket/1234/TicketFollowup \
  -H "Session-Token: TOKEN" \
  -H "App-Token: TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "tickets_id": 1234,
      "content": "Atualização: Script executado com sucesso"
    }
  }'
```

### Adicionar Solução

```bash
curl -X POST https://glpi.dlino.us/apirest.php/Ticket/1234/ITILSolution \
  -H "Session-Token: TOKEN" \
  -H "App-Token: TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "tickets_id": 1234,
      "content": "Malware removido via quarentena automática"
    }
  }'
```

---

## 10. Troubleshooting

### Erro 401 (Unauthorized)

**Causa:** Session Token expirou ou App Token inválido.

**Solução:**
1. Gere novo Session Token
2. Verifique App Token em **Setup** → **General** → **API**

### Erro 403 (Forbidden)

**Causa:** Usuário sem permissões.

**Solução:**
1. Verifique profile do usuário
2. Dê permissões de Technician ou Super-Admin

### Erro 400 (Bad Request)

**Causa:** JSON malformado ou campos obrigatórios faltando.

**Solução:**
- Valide JSON em: https://jsonlint.com
- Campos obrigatórios para Ticket: `name`, `content`

### Session Token expira muito rápido

**Aumentar timeout:**

Edite `/var/www/html/glpi/config/config_db.php`:

```php
// Aumentar para 4 horas
$CFG_GLPI['session_timeout'] = 14400;
```

---

## 11. Segurança

### Boas Práticas

1. **Não exponha tokens:**
   - Use variáveis de ambiente
   - Nunca commite no git

2. **Restrinja IP:**
   - Em **API Client**, configure range de IP permitido
   - Exemplo: `192.168.1.0/24` (somente sua rede)

3. **Use HTTPS:**
   - Sempre use HTTPS (não HTTP)
   - Verifique certificado SSL válido

4. **Rotação de tokens:**
   - Revogue e recrie User Tokens periodicamente
   - Use tokens específicos por integração

5. **Logs:**
   - GLPI loga todas as chamadas de API
   - Verifique em: **Administration** → **Logs** → **Historical**

---

## 12. Referências

- [GLPI REST API Documentation](https://github.com/glpi-project/glpi/blob/master/apirest.md)
- [GLPI API Examples](https://github.com/glpi-project/glpi/wiki/GLPI-REST-API)
- [Ticket Status Reference](https://glpi-project.org/documentation/)

---

## 13. Checklist de Configuração

- [ ] API REST habilitada
- [ ] App Token criado e copiado
- [ ] User Token criado e copiado
- [ ] Session Token gerado via `initSession`
- [ ] Teste de criação de ticket bem-sucedido
- [ ] Teste de atualização de ticket bem-sucedido
- [ ] Credenciais configuradas no n8n
- [ ] Permissões verificadas
- [ ] Workflow SOAR testado end-to-end

---

**Próximo passo:** [Testar workflow completo](../README.md#uso)
