# Configuração do Wazuh para SOAR

## Objetivo

Configurar o Wazuh para enviar alertas automaticamente para o workflow n8n.

---

## 1. Habilitar Integração com Webhook

### Editar ossec.conf

Conecte no servidor Wazuh:

```bash
ssh user@soc.dlino.us
```

Edite o arquivo de configuração:

```bash
sudo nano /var/ossec/etc/ossec.conf
```

### Adicionar Integração

Adicione dentro da tag `<ossec_config>`:

```xml
<integration>
  <name>custom-webhook</name>
  <hook_url>https://n8n.dlino.us/webhook/wazuh-alert</hook_url>
  <level>7</level>
  <alert_format>json</alert_format>
  <options>{"Content-Type":"application/json"}</options>
</integration>
```

**Parâmetros:**
- `hook_url`: URL do webhook do n8n
- `level`: Nível mínimo de alerta (7 = HIGH, 12 = CRITICAL)
- `alert_format`: Sempre `json`

### Reiniciar Wazuh

```bash
sudo systemctl restart wazuh-manager
```

Verificar status:

```bash
sudo systemctl status wazuh-manager
```

---

## 2. Testar Integração

### Enviar Alerta de Teste

Em uma estação com agente Wazuh instalado:

```powershell
# Windows - Criar arquivo EICAR (teste de antivírus)
echo "X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*" > C:\Users\Public\eicar.txt
```

Ou:

```bash
# Linux
echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > /tmp/eicar.txt
```

### Verificar Logs do Wazuh

```bash
tail -f /var/ossec/logs/ossec.log | grep "custom-webhook"
```

Você deve ver algo como:

```
2025/10/27 10:30:00 wazuh-integratord: INFO: Sending alert to custom-webhook
2025/10/27 10:30:01 wazuh-integratord: INFO: Successfully sent alert to custom-webhook
```

### Verificar no n8n

No n8n, vá em **Executions** e verifique se o workflow foi acionado.

---

## 3. Configurações Avançadas

### Filtrar por Regra Específica

Se quiser enviar apenas alertas específicos:

```xml
<integration>
  <name>custom-webhook</name>
  <hook_url>https://n8n.dlino.us/webhook/wazuh-alert</hook_url>
  <rule_id>87101,87102,87103</rule_id>
  <alert_format>json</alert_format>
</integration>
```

### Filtrar por Grupo

Enviar apenas alertas de malware:

```xml
<integration>
  <name>custom-webhook</name>
  <hook_url>https://n8n.dlino.us/webhook/wazuh-alert</hook_url>
  <group>malware</group>
  <alert_format>json</alert_format>
</integration>
```

### Múltiplas Integrações

Você pode ter múltiplas integrações:

```xml
<!-- Alertas críticos -->
<integration>
  <name>soar-critical</name>
  <hook_url>https://n8n.dlino.us/webhook/wazuh-alert</hook_url>
  <level>12</level>
  <alert_format>json</alert_format>
</integration>

<!-- Alertas de malware -->
<integration>
  <name>soar-malware</name>
  <hook_url>https://n8n.dlino.us/webhook/wazuh-alert</hook_url>
  <group>malware</group>
  <alert_format>json</alert_format>
</integration>
```

---

## 4. Regras Úteis para SOAR

### Windows Defender

**Rule ID:** 87101 - Malware detected

Detecta quando Windows Defender encontra malware.

### Syscheck (File Integrity)

**Rule ID:** 550-554 - File changes

Detecta modificações em arquivos monitorados.

### Failed Login Attempts

**Rule ID:** 60122 - Multiple authentication failures

Detecta tentativas de brute force.

### Vulnerability Detection

**Rule ID:** 23503 - High severity vulnerability

Detecta vulnerabilidades via scans do Wazuh.

### Custom Rules

Crie regras personalizadas em `/var/ossec/etc/rules/local_rules.xml`:

```xml
<group name="custom_malware">
  <rule id="100001" level="12">
    <if_sid>550</if_sid>
    <field name="file">C:\\Windows\\System32\\evil.exe</field>
    <description>Malware detected: evil.exe</description>
  </rule>
</group>
```

---

## 5. Monitoramento

### Dashboard Wazuh

Acesse: `https://soc.dlino.us`

Vá em **Security Events** para ver todos os alertas.

### Logs em Tempo Real

```bash
tail -f /var/ossec/logs/alerts/alerts.json | jq .
```

### Estatísticas de Integração

```bash
grep "custom-webhook" /var/ossec/logs/ossec.log | tail -20
```

---

## 6. Troubleshooting

### Webhook não está sendo chamado

**Verificar:**
1. URL está correta?
2. n8n está acessível do servidor Wazuh?
3. Level configurado é menor ou igual ao do alerta?

**Testar conectividade:**
```bash
curl -X POST https://n8n.dlino.us/webhook/wazuh-alert \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

### Erros 403/401

- n8n requer autenticação? Desabilite para webhooks ou configure Basic Auth.
- Firewall bloqueando? Libere IP do Wazuh.

### Alertas duplicados

Wazuh pode enviar mesmo alerta múltiplas vezes. Use deduplicação no n8n:

No workflow, adicione nó **Deduplicate** antes do processamento.

---

## 7. Exemplo de Alerta JSON

```json
{
  "id": "1730030400.123456",
  "timestamp": "2025-10-27T10:30:00.000Z",
  "rule": {
    "id": "87101",
    "description": "Malware detected - Windows Defender",
    "level": 12,
    "groups": ["windows", "malware"]
  },
  "agent": {
    "id": "001",
    "name": "WORKSTATION-01",
    "ip": "192.168.1.100"
  },
  "data": {
    "win": {
      "eventdata": {
        "threatName": "Trojan:Win32/Wacatac.B!ml",
        "path": "C:\\Users\\test\\Downloads\\malware.exe"
      }
    }
  },
  "syscheck": {
    "path": "C:\\Users\\test\\Downloads\\malware.exe",
    "md5_after": "5d41402abc4b2a76b9719d911017c592",
    "sha256_after": "..."
  }
}
```

Este JSON é processado pelo nó "Parse Wazuh Data" no workflow.

---

## Recursos

- [Documentação Oficial](https://documentation.wazuh.com/current/user-manual/manager/manual-integration.html)
- [Regras padrão](https://github.com/wazuh/wazuh/tree/master/ruleset/rules)
- [Custom rules guide](https://documentation.wazuh.com/current/user-manual/ruleset/custom.html)

---

**Próximo passo:** [Configurar Telegram Bot](setup-telegram.md)
