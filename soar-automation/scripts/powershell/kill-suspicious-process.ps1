# ============================================
# Script: Encerrar Processo Suspeito
# Descrição: Para processo malicioso e remove persistence
# Uso: Via TacticalRMM ou manual
# ============================================

param(
    [Parameter(Mandatory=$false)]
    [string]$ProcessName,

    [Parameter(Mandatory=$false)]
    [int]$ProcessId,

    [Parameter(Mandatory=$false)]
    [switch]$RemovePersistence
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage

    $logFile = "C:\ProgramData\SOAR\Logs\process-kill.log"
    if (-not (Test-Path (Split-Path $logFile))) {
        New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null
    }
    Add-Content -Path $logFile -Value $logMessage
}

try {
    if (-not $ProcessName -and -not $ProcessId) {
        throw "Deve fornecer ProcessName ou ProcessId"
    }

    Write-Log "Iniciando encerramento de processo"

    # Busca processo
    if ($ProcessId) {
        $processes = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        Write-Log "Buscando por PID: $ProcessId"
    } else {
        $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        Write-Log "Buscando por nome: $ProcessName"
    }

    if (-not $processes) {
        Write-Log "Processo não encontrado (pode já ter sido encerrado)" "WARNING"
        exit 0
    }

    $killedProcesses = @()

    foreach ($proc in $processes) {
        Write-Log "Processo encontrado: $($proc.Name) (PID: $($proc.Id))"

        # Coleta informações antes de matar
        $procInfo = @{
            Name = $proc.Name
            Id = $proc.Id
            Path = $proc.Path
            CommandLine = (Get-CimInstance Win32_Process | Where-Object ProcessId -eq $proc.Id).CommandLine
            StartTime = $proc.StartTime
            UserName = $proc.UserName
        }

        Write-Log "Caminho: $($procInfo.Path)"
        Write-Log "Usuário: $($procInfo.UserName)"
        Write-Log "Linha de comando: $($procInfo.CommandLine)"

        # Encerra processo
        Write-Log "Encerrando processo..."
        Stop-Process -Id $proc.Id -Force

        Start-Sleep -Seconds 2

        # Verifica se foi encerrado
        $stillRunning = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
        if ($stillRunning) {
            Write-Log "FALHA ao encerrar processo!" "ERROR"
        } else {
            Write-Log "Processo encerrado com sucesso" "SUCCESS"
            $killedProcesses += $procInfo
        }
    }

    # Remove persistence se solicitado
    $persistenceRemoved = @()
    if ($RemovePersistence) {
        Write-Log "Verificando mecanismos de persistence..."

        # Verifica Registry Run keys
        $runKeys = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
        )

        foreach ($key in $runKeys) {
            if (Test-Path $key) {
                $entries = Get-ItemProperty -Path $key
                foreach ($entry in $entries.PSObject.Properties) {
                    if ($entry.Value -like "*$($killedProcesses[0].Path)*") {
                        Write-Log "Removendo entrada de registro: $key\$($entry.Name)"
                        Remove-ItemProperty -Path $key -Name $entry.Name -Force
                        $persistenceRemoved += "$key\$($entry.Name)"
                    }
                }
            }
        }

        # Verifica Scheduled Tasks
        $tasks = Get-ScheduledTask | Where-Object {
            $_.Actions.Execute -like "*$($killedProcesses[0].Path)*"
        }

        foreach ($task in $tasks) {
            Write-Log "Removendo task agendada: $($task.TaskName)"
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
            $persistenceRemoved += "Task: $($task.TaskName)"
        }

        # Verifica Startup folder
        $startupFolders = @(
            "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
            "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
        )

        foreach ($folder in $startupFolders) {
            if (Test-Path $folder) {
                $items = Get-ChildItem $folder | Where-Object {
                    (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -like "*$($killedProcesses[0].Path)*"
                }

                foreach ($item in $items) {
                    Write-Log "Removendo item de startup: $($item.FullName)"
                    Remove-Item $item.FullName -Force
                    $persistenceRemoved += "Startup: $($item.Name)"
                }
            }
        }
    }

    # Resultado
    $result = @{
        Status = "Success"
        Message = "Processo(s) encerrado(s) com sucesso"
        KilledProcesses = $killedProcesses
        PersistenceRemoved = $persistenceRemoved
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
