# ============================================
# Script: Quarentena de Arquivo Suspeito
# Descrição: Move arquivo malicioso para quarentena
# Uso: Via TacticalRMM ou manual
# ============================================

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath,

    [Parameter(Mandatory=$false)]
    [string]$QuarantinePath = "C:\ProgramData\SOAR\Quarantine"
)

# Função para log
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage

    # Log em arquivo
    $logFile = "C:\ProgramData\SOAR\Logs\quarantine.log"
    if (-not (Test-Path (Split-Path $logFile))) {
        New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null
    }
    Add-Content -Path $logFile -Value $logMessage
}

try {
    Write-Log "Iniciando processo de quarentena"
    Write-Log "Arquivo alvo: $FilePath"

    # Valida se arquivo existe
    if (-not (Test-Path $FilePath)) {
        Write-Log "Arquivo não encontrado. Pode ter sido removido pelo antivírus." "WARNING"
        exit 0
    }

    # Cria diretório de quarentena
    if (-not (Test-Path $QuarantinePath)) {
        Write-Log "Criando diretório de quarentena: $QuarantinePath"
        New-Item -ItemType Directory -Path $QuarantinePath -Force | Out-Null
    }

    # Captura metadados do arquivo
    $fileInfo = Get-Item $FilePath
    $fileHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash

    Write-Log "Hash SHA256: $fileHash"
    Write-Log "Tamanho: $($fileInfo.Length) bytes"
    Write-Log "Criado em: $($fileInfo.CreationTime)"

    # Salva metadados
    $metadataFile = Join-Path $QuarantinePath "$($fileInfo.Name).metadata.json"
    $metadata = @{
        OriginalPath = $FilePath
        FileName = $fileInfo.Name
        SHA256 = $fileHash
        Size = $fileInfo.Length
        CreationTime = $fileInfo.CreationTime.ToString("o")
        QuarantineTime = (Get-Date).ToString("o")
        QuarantinedBy = "SOAR-System"
    }
    $metadata | ConvertTo-Json | Set-Content -Path $metadataFile

    # Move arquivo para quarentena
    $destinationFile = Join-Path $QuarantinePath $fileInfo.Name

    # Se arquivo já existe na quarentena, adiciona timestamp
    if (Test-Path $destinationFile) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $destinationFile = Join-Path $QuarantinePath "$($fileInfo.BaseName)-$timestamp$($fileInfo.Extension)"
    }

    Move-Item -Path $FilePath -Destination $destinationFile -Force
    Write-Log "Arquivo movido para: $destinationFile" "SUCCESS"

    # Verifica processos que possam estar usando o arquivo
    $processes = Get-Process | Where-Object { $_.Path -eq $FilePath }
    if ($processes) {
        Write-Log "ALERTA: Processos ativos detectados usando este arquivo!" "WARNING"
        foreach ($proc in $processes) {
            Write-Log "  - Processo: $($proc.Name) (PID: $($proc.Id))" "WARNING"
        }
    }

    # Retorna resultado
    $result = @{
        Status = "Success"
        Message = "Arquivo movido para quarentena com sucesso"
        QuarantinePath = $destinationFile
        MetadataPath = $metadataFile
        Hash = $fileHash
    }

    Write-Output ($result | ConvertTo-Json -Compress)
    exit 0

} catch {
    Write-Log "ERRO: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"

    $errorResult = @{
        Status = "Error"
        Message = $_.Exception.Message
        FilePath = $FilePath
    }

    Write-Output ($errorResult | ConvertTo-Json -Compress)
    exit 1
}
