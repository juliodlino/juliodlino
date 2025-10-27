# ============================================
# Script: Coleta de Evidências Forenses
# Descrição: Coleta informações do sistema para análise
# Uso: Investigação de incidentes
# ============================================

param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\ProgramData\SOAR\Evidence",

    [Parameter(Mandatory=$false)]
    [string]$IncidentId = "UNK"
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage
}

try {
    Write-Log "Iniciando coleta de evidências"
    Write-Log "Incident ID: $IncidentId"

    # Cria diretório de evidências
    $evidenceDir = Join-Path $OutputPath "INC-$IncidentId-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null
    Write-Log "Diretório de evidências: $evidenceDir"

    $evidence = @{}

    # 1. Informações do Sistema
    Write-Log "Coletando informações do sistema..."
    $evidence.SystemInfo = @{
        Hostname = $env:COMPUTERNAME
        OS = (Get-CimInstance Win32_OperatingSystem).Caption
        OSVersion = (Get-CimInstance Win32_OperatingSystem).Version
        Architecture = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
        LastBootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString("o")
        CurrentTime = (Get-Date).ToString("o")
        Domain = (Get-CimInstance Win32_ComputerSystem).Domain
        Manufacturer = (Get-CimInstance Win32_ComputerSystem).Manufacturer
        Model = (Get-CimInstance Win32_ComputerSystem).Model
    }

    # 2. Processos em execução
    Write-Log "Coletando lista de processos..."
    $evidence.Processes = Get-Process | Select-Object Name, Id, Path, StartTime, Company, FileVersion, ProductVersion |
        ForEach-Object {
            @{
                Name = $_.Name
                Id = $_.Id
                Path = $_.Path
                StartTime = if ($_.StartTime) { $_.StartTime.ToString("o") } else { $null }
                Company = $_.Company
                FileVersion = $_.FileVersion
            }
        }

    # 3. Conexões de rede ativas
    Write-Log "Coletando conexões de rede..."
    $evidence.NetworkConnections = Get-NetTCPConnection | Where-Object State -eq 'Established' |
        Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess |
        ForEach-Object {
            $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
            @{
                LocalAddress = $_.LocalAddress
                LocalPort = $_.LocalPort
                RemoteAddress = $_.RemoteAddress
                RemotePort = $_.RemotePort
                State = $_.State
                ProcessId = $_.OwningProcess
                ProcessName = if ($proc) { $proc.Name } else { "Unknown" }
            }
        }

    # 4. Serviços em execução
    Write-Log "Coletando serviços..."
    $evidence.Services = Get-Service | Where-Object Status -eq 'Running' |
        Select-Object Name, DisplayName, Status, StartType |
        ForEach-Object {
            @{
                Name = $_.Name
                DisplayName = $_.DisplayName
                Status = $_.Status.ToString()
                StartType = $_.StartType.ToString()
            }
        }

    # 5. Tarefas agendadas suspeitas
    Write-Log "Coletando tarefas agendadas..."
    $evidence.ScheduledTasks = Get-ScheduledTask | Where-Object State -ne 'Disabled' |
        Select-Object TaskName, TaskPath, State |
        ForEach-Object {
            $taskInfo = Get-ScheduledTaskInfo -TaskName $_.TaskName -ErrorAction SilentlyContinue
            @{
                TaskName = $_.TaskName
                TaskPath = $_.TaskPath
                State = $_.State.ToString()
                LastRunTime = if ($taskInfo) { $taskInfo.LastRunTime.ToString("o") } else { $null }
                NextRunTime = if ($taskInfo) { $taskInfo.NextRunTime.ToString("o") } else { $null }
            }
        }

    # 6. Entradas de registro de autorun
    Write-Log "Coletando chaves de registro de autorun..."
    $runKeys = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    )

    $evidence.AutorunRegistry = @()
    foreach ($key in $runKeys) {
        if (Test-Path $key) {
            $entries = Get-ItemProperty -Path $key
            foreach ($prop in $entries.PSObject.Properties) {
                if ($prop.Name -notmatch '^PS') {
                    $evidence.AutorunRegistry += @{
                        Key = $key
                        Name = $prop.Name
                        Value = $prop.Value
                    }
                }
            }
        }
    }

    # 7. Logs de eventos recentes (Security)
    Write-Log "Coletando eventos de segurança recentes..."
    $evidence.SecurityEvents = Get-WinEvent -FilterHashtable @{
        LogName='Security'
        StartTime=(Get-Date).AddHours(-24)
    } -MaxEvents 1000 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Id, LevelDisplayName, Message |
        ForEach-Object {
            @{
                TimeCreated = $_.TimeCreated.ToString("o")
                EventId = $_.Id
                Level = $_.LevelDisplayName
                Message = $_.Message.Substring(0, [Math]::Min(200, $_.Message.Length))
            }
        }

    # 8. Usuários logados
    Write-Log "Coletando usuários logados..."
    $evidence.LoggedOnUsers = query user 2>$null | Select-Object -Skip 1 |
        ForEach-Object {
            $_ -replace '\s{2,}', '|'
        } | ConvertFrom-Csv -Delimiter '|' -Header 'USERNAME','SESSIONNAME','ID','STATE','IDLE','LOGON TIME'

    # 9. Arquivos modificados recentemente em locais sensíveis
    Write-Log "Coletando arquivos modificados recentemente..."
    $sensitivePaths = @(
        "$env:SystemRoot\System32",
        "$env:SystemRoot\SysWOW64",
        "$env:ProgramData",
        "$env:APPDATA"
    )

    $evidence.RecentFiles = @()
    foreach ($path in $sensitivePaths) {
        if (Test-Path $path) {
            $recentFiles = Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 50 |
                ForEach-Object {
                    @{
                        Path = $_.FullName
                        LastWriteTime = $_.LastWriteTime.ToString("o")
                        Size = $_.Length
                        Extension = $_.Extension
                    }
                }
            $evidence.RecentFiles += $recentFiles
        }
    }

    # 10. Configurações de rede
    Write-Log "Coletando configurações de rede..."
    $evidence.NetworkConfiguration = Get-NetIPConfiguration | ForEach-Object {
        @{
            InterfaceAlias = $_.InterfaceAlias
            IPv4Address = ($_.IPv4Address.IPAddress -join ', ')
            IPv4DefaultGateway = ($_.IPv4DefaultGateway.NextHop -join ', ')
            DNSServer = ($_.DNSServer.ServerAddresses -join ', ')
        }
    }

    # Salva evidências em JSON
    $jsonPath = Join-Path $evidenceDir "evidence.json"
    $evidence | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath
    Write-Log "Evidências salvas em JSON: $jsonPath"

    # Cria relatório em texto legível
    $reportPath = Join-Path $evidenceDir "report.txt"
    $report = @"
=====================================
RELATÓRIO DE COLETA DE EVIDÊNCIAS
=====================================
Incident ID: $IncidentId
Data/Hora: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Hostname: $($evidence.SystemInfo.Hostname)
Sistema Operacional: $($evidence.SystemInfo.OS)

RESUMO:
- Processos coletados: $($evidence.Processes.Count)
- Conexões de rede ativas: $($evidence.NetworkConnections.Count)
- Serviços em execução: $($evidence.Services.Count)
- Tarefas agendadas: $($evidence.ScheduledTasks.Count)
- Entradas de autorun: $($evidence.AutorunRegistry.Count)
- Eventos de segurança: $($evidence.SecurityEvents.Count)
- Arquivos recentes: $($evidence.RecentFiles.Count)

PRÓXIMOS PASSOS:
1. Analisar conexões de rede para IPs suspeitos
2. Revisar processos desconhecidos ou sem assinatura
3. Verificar tarefas agendadas incomuns
4. Correlacionar com logs do Wazuh

Evidências completas disponíveis em:
$evidenceDir
=====================================
"@

    $report | Set-Content -Path $reportPath
    Write-Log "Relatório salvo: $reportPath"

    # Compacta evidências
    Write-Log "Compactando evidências..."
    $zipPath = "$evidenceDir.zip"
    Compress-Archive -Path $evidenceDir -DestinationPath $zipPath -Force
    Write-Log "Evidências compactadas: $zipPath"

    $result = @{
        Status = "Success"
        Message = "Evidências coletadas com sucesso"
        EvidenceDirectory = $evidenceDir
        JsonFile = $jsonPath
        ReportFile = $reportPath
        ZipFile = $zipPath
        Summary = @{
            ProcessesCollected = $evidence.Processes.Count
            NetworkConnections = $evidence.NetworkConnections.Count
            Services = $evidence.Services.Count
            ScheduledTasks = $evidence.ScheduledTasks.Count
            AutorunEntries = $evidence.AutorunRegistry.Count
            SecurityEvents = $evidence.SecurityEvents.Count
        }
    }

    Write-Output ($result | ConvertTo-Json -Depth 3 -Compress)
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
