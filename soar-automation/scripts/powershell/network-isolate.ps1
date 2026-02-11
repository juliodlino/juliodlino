# ============================================
# Script: Isolamento de Rede
# Descrição: Isola host da rede (exceto RMM)
# Uso: Para contenção de incidentes críticos
# ============================================

param(
    [Parameter(Mandatory=$false)]
    [switch]$Isolate,

    [Parameter(Mandatory=$false)]
    [switch]$Restore,

    [Parameter(Mandatory=$false)]
    [string]$RmmServerIP = "rmm.dlino.us"
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage

    $logFile = "C:\ProgramData\SOAR\Logs\network-isolation.log"
    if (-not (Test-Path (Split-Path $logFile))) {
        New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null
    }
    Add-Content -Path $logFile -Value $logMessage
}

try {
    if (-not $Isolate -and -not $Restore) {
        throw "Deve especificar -Isolate ou -Restore"
    }

    # Resolve IP do servidor RMM
    $rmmIP = (Resolve-DnsName $RmmServerIP -ErrorAction SilentlyContinue).IPAddress
    if (-not $rmmIP) {
        Write-Log "AVISO: Não foi possível resolver IP do RMM" "WARNING"
        $rmmIP = "0.0.0.0"
    }

    Write-Log "IP do RMM Server: $rmmIP"

    if ($Isolate) {
        Write-Log "=== INICIANDO ISOLAMENTO DE REDE ===" "WARNING"

        # Backup das regras de firewall atuais
        $backupPath = "C:\ProgramData\SOAR\Backups\firewall-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').wfw"
        Write-Log "Criando backup das regras de firewall..."

        if (-not (Test-Path (Split-Path $backupPath))) {
            New-Item -ItemType Directory -Path (Split-Path $backupPath) -Force | Out-Null
        }

        netsh advfirewall export $backupPath | Out-Null
        Write-Log "Backup salvo em: $backupPath"

        # Cria regra de firewall que bloqueia tudo exceto RMM
        Write-Log "Criando regra de isolamento..."

        # Remove regras antigas do SOAR se existirem
        Remove-NetFirewallRule -DisplayName "SOAR-Isolation-*" -ErrorAction SilentlyContinue

        # Bloqueia todo tráfego de saída (exceto RMM)
        New-NetFirewallRule -DisplayName "SOAR-Isolation-Block-Outbound" `
            -Direction Outbound `
            -Action Block `
            -Enabled True `
            -Profile Any `
            -Priority 1 | Out-Null

        # Permite apenas RMM
        if ($rmmIP -ne "0.0.0.0") {
            New-NetFirewallRule -DisplayName "SOAR-Isolation-Allow-RMM" `
                -Direction Outbound `
                -Action Allow `
                -RemoteAddress $rmmIP `
                -Enabled True `
                -Profile Any `
                -Priority 0 | Out-Null
        }

        # Bloqueia todo tráfego de entrada
        New-NetFirewallRule -DisplayName "SOAR-Isolation-Block-Inbound" `
            -Direction Inbound `
            -Action Block `
            -Enabled True `
            -Profile Any `
            -Priority 1 | Out-Null

        Write-Log "HOST ISOLADO DA REDE!" "WARNING"
        Write-Log "Apenas comunicação com RMM ($rmmIP) é permitida" "WARNING"

        # Salva estado de isolamento
        $isolationState = @{
            IsolatedAt = (Get-Date).ToString("o")
            BackupFile = $backupPath
            RmmIP = $rmmIP
            IsolatedBy = "SOAR-System"
        }
        $isolationState | ConvertTo-Json | Set-Content "C:\ProgramData\SOAR\isolation-state.json"

        $result = @{
            Status = "Success"
            Message = "Host isolado da rede com sucesso"
            BackupFile = $backupPath
            RmmIP = $rmmIP
        }

    } elseif ($Restore) {
        Write-Log "=== RESTAURANDO CONECTIVIDADE DE REDE ===" "INFO"

        # Remove regras de isolamento
        Write-Log "Removendo regras de isolamento..."
        Remove-NetFirewallRule -DisplayName "SOAR-Isolation-*" -ErrorAction SilentlyContinue

        # Busca arquivo de backup mais recente
        $backupFiles = Get-ChildItem "C:\ProgramData\SOAR\Backups\firewall-backup-*.wfw" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending

        if ($backupFiles) {
            $latestBackup = $backupFiles[0].FullName
            Write-Log "Restaurando backup: $latestBackup"
            netsh advfirewall import $latestBackup | Out-Null
        } else {
            Write-Log "Nenhum backup encontrado. Regras de isolamento removidas." "WARNING"
        }

        # Remove arquivo de estado
        Remove-Item "C:\ProgramData\SOAR\isolation-state.json" -ErrorAction SilentlyContinue

        Write-Log "Conectividade de rede restaurada" "SUCCESS"

        $result = @{
            Status = "Success"
            Message = "Conectividade de rede restaurada"
            BackupRestored = $latestBackup
        }
    }

    Write-Output ($result | ConvertTo-Json -Compress)
    exit 0

} catch {
    Write-Log "ERRO: $($_.Exception.Message)" "ERROR"

    $errorResult = @{
        Status = "Error"
        Message = $_.Exception.Message
    }

    Write-Output ($errorResult | ConvertTo-Json -Compress)
    exit 1
}
