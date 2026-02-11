# ============================================
# Script: Verificação de Remediação
# Descrição: Valida se remediação foi bem-sucedida
# Uso: Pós-remediação para confirmar sucesso
# ============================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('FileQuarantine', 'ProcessKill', 'NetworkIsolation', 'ServiceDisable')]
    [string]$RemediationType,

    [Parameter(Mandatory=$false)]
    [string]$TargetPath,

    [Parameter(Mandatory=$false)]
    [string]$TargetProcess,

    [Parameter(Mandatory=$false)]
    [string]$TargetService
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] [$Level] $Message"
}

try {
    Write-Log "Iniciando verificação de remediação"
    Write-Log "Tipo: $RemediationType"

    $verificationResult = @{
        RemediationType = $RemediationType
        Success = $false
        Details = @()
        Timestamp = (Get-Date).ToString("o")
    }

    switch ($RemediationType) {
        'FileQuarantine' {
            if (-not $TargetPath) {
                throw "TargetPath é obrigatório para FileQuarantine"
            }

            Write-Log "Verificando se arquivo foi removido: $TargetPath"

            # Verifica se arquivo não existe mais no local original
            if (Test-Path $TargetPath) {
                Write-Log "FALHA: Arquivo ainda existe no local original!" "ERROR"
                $verificationResult.Success = $false
                $verificationResult.Details += "Arquivo ainda presente em: $TargetPath"
            } else {
                Write-Log "OK: Arquivo removido do local original" "SUCCESS"

                # Verifica se está na quarentena
                $quarantinePath = "C:\ProgramData\SOAR\Quarantine"
                $fileName = Split-Path $TargetPath -Leaf
                $quarantinedFiles = Get-ChildItem $quarantinePath -Filter "*$fileName*" -ErrorAction SilentlyContinue

                if ($quarantinedFiles) {
                    Write-Log "OK: Arquivo encontrado na quarentena: $($quarantinedFiles[0].FullName)" "SUCCESS"
                    $verificationResult.Success = $true
                    $verificationResult.Details += "Arquivo em quarentena: $($quarantinedFiles[0].FullName)"
                } else {
                    Write-Log "AVISO: Arquivo não encontrado na quarentena" "WARNING"
                    $verificationResult.Success = $true
                    $verificationResult.Details += "Arquivo removido mas não encontrado na quarentena"
                }
            }

            # Verifica se processos relacionados estão ativos
            $processes = Get-Process | Where-Object { $_.Path -eq $TargetPath }
            if ($processes) {
                Write-Log "AVISO: Processos ainda ativos usando este arquivo!" "WARNING"
                $verificationResult.Details += "Processos ativos: $($processes.Count)"
                $verificationResult.Success = $false
            }
        }

        'ProcessKill' {
            if (-not $TargetProcess) {
                throw "TargetProcess é obrigatório para ProcessKill"
            }

            Write-Log "Verificando se processo foi encerrado: $TargetProcess"

            # Tenta encontrar processo
            $processes = Get-Process -Name $TargetProcess -ErrorAction SilentlyContinue

            if ($processes) {
                Write-Log "FALHA: Processo ainda está em execução!" "ERROR"
                $verificationResult.Success = $false
                $verificationResult.Details += "Processo ativo com PID: $($processes.Id -join ', ')"
            } else {
                Write-Log "OK: Processo não está em execução" "SUCCESS"
                $verificationResult.Success = $true
                $verificationResult.Details += "Processo encerrado com sucesso"
            }

            # Verifica se persistence foi removida
            $runKeys = @(
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
            )

            $persistenceFound = $false
            foreach ($key in $runKeys) {
                if (Test-Path $key) {
                    $entries = Get-ItemProperty -Path $key
                    foreach ($entry in $entries.PSObject.Properties) {
                        if ($entry.Value -like "*$TargetProcess*") {
                            Write-Log "AVISO: Persistence ainda presente: $key\$($entry.Name)" "WARNING"
                            $verificationResult.Details += "Persistence: $key\$($entry.Name)"
                            $persistenceFound = $true
                        }
                    }
                }
            }

            if (-not $persistenceFound) {
                Write-Log "OK: Nenhuma persistence detectada" "SUCCESS"
            }
        }

        'NetworkIsolation' {
            Write-Log "Verificando isolamento de rede..."

            # Verifica regras de firewall
            $isolationRules = Get-NetFirewallRule -DisplayName "SOAR-Isolation-*" -ErrorAction SilentlyContinue

            if ($isolationRules) {
                Write-Log "OK: Regras de isolamento ativas" "SUCCESS"
                $verificationResult.Success = $true
                $verificationResult.Details += "Regras ativas: $($isolationRules.Count)"

                # Testa conectividade externa
                $testConnections = @(
                    @{ Host = "8.8.8.8"; Port = 53; Name = "Google DNS" },
                    @{ Host = "1.1.1.1"; Port = 53; Name = "Cloudflare DNS" }
                )

                foreach ($test in $testConnections) {
                    $result = Test-NetConnection -ComputerName $test.Host -Port $test.Port -WarningAction SilentlyContinue
                    if ($result.TcpTestSucceeded) {
                        Write-Log "FALHA: Conexão externa ainda funciona para $($test.Name)!" "ERROR"
                        $verificationResult.Success = $false
                        $verificationResult.Details += "Conexão ativa: $($test.Name)"
                    } else {
                        Write-Log "OK: Conexão bloqueada para $($test.Name)" "SUCCESS"
                    }
                }
            } else {
                Write-Log "FALHA: Regras de isolamento não encontradas!" "ERROR"
                $verificationResult.Success = $false
                $verificationResult.Details += "Regras de isolamento ausentes"
            }
        }

        'ServiceDisable' {
            if (-not $TargetService) {
                throw "TargetService é obrigatório para ServiceDisable"
            }

            Write-Log "Verificando se serviço foi desabilitado: $TargetService"

            $service = Get-Service -Name $TargetService -ErrorAction SilentlyContinue

            if (-not $service) {
                Write-Log "AVISO: Serviço não encontrado (pode ter sido removido)" "WARNING"
                $verificationResult.Success = $true
                $verificationResult.Details += "Serviço não encontrado no sistema"
            } else {
                if ($service.Status -eq 'Running') {
                    Write-Log "FALHA: Serviço ainda está em execução!" "ERROR"
                    $verificationResult.Success = $false
                    $verificationResult.Details += "Status: Running"
                } else {
                    Write-Log "OK: Serviço não está em execução" "SUCCESS"

                    if ($service.StartType -eq 'Disabled') {
                        Write-Log "OK: Serviço está desabilitado" "SUCCESS"
                        $verificationResult.Success = $true
                        $verificationResult.Details += "Status: Stopped, StartType: Disabled"
                    } else {
                        Write-Log "AVISO: Serviço parado mas não desabilitado" "WARNING"
                        $verificationResult.Success = $false
                        $verificationResult.Details += "Status: Stopped, StartType: $($service.StartType)"
                    }
                }
            }
        }
    }

    # Verificações adicionais gerais
    Write-Log "Executando verificações adicionais..."

    # Verifica alertas recentes do Windows Defender
    $defenderThreats = Get-MpThreat -ErrorAction SilentlyContinue
    if ($defenderThreats) {
        Write-Log "AVISO: Ameaças detectadas pelo Windows Defender: $($defenderThreats.Count)" "WARNING"
        $verificationResult.Details += "Defender Threats: $($defenderThreats.Count)"
    }

    # Verifica eventos de segurança recentes
    $recentSecurityEvents = Get-WinEvent -FilterHashtable @{
        LogName='Security'
        Level=2
        StartTime=(Get-Date).AddMinutes(-15)
    } -MaxEvents 10 -ErrorAction SilentlyContinue

    if ($recentSecurityEvents) {
        Write-Log "AVISO: Eventos de segurança críticos recentes: $($recentSecurityEvents.Count)" "WARNING"
        $verificationResult.Details += "Recent Security Events: $($recentSecurityEvents.Count)"
    }

    # Resultado final
    if ($verificationResult.Success) {
        Write-Log "=== VERIFICAÇÃO BEM-SUCEDIDA ===" "SUCCESS"
    } else {
        Write-Log "=== VERIFICAÇÃO FALHOU ===" "ERROR"
    }

    Write-Output ($verificationResult | ConvertTo-Json -Depth 3 -Compress)
    exit $(if ($verificationResult.Success) { 0 } else { 1 })

} catch {
    Write-Log "ERRO: $($_.Exception.Message)" "ERROR"

    $errorResult = @{
        Status = "Error"
        Message = $_.Exception.Message
        RemediationType = $RemediationType
    }

    Write-Output ($errorResult | ConvertTo-Json -Compress)
    exit 1
}
