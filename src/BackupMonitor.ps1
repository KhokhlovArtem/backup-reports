<#
.SYNOPSIS
    Мониторинг и отчётность по бэкапам.

.DESCRIPTION
    Сканирует директорию бэкапов, классифицирует файлы по давности,
    генерирует отчёты и триггер-файлы.

.PARAMETER Config
    Путь к файлу конфигурации JSON.

.PARAMETER EnvFile
    Путь к файлу .env с переменными окружения.

.PARAMETER Help
    Показать справку.

.EXAMPLE
    .\BackupMonitor.ps1 -Config .\config\config.json -EnvFile .\.env

.NOTES
    Коды возврата: 0 (успех), 1 (ошибка), 10 (инцидент)
#>

param(
    [string]$Config = ".\config\config.json",
    [string]$EnvFile = ".\.env",
    [switch]$Help
)

# --- Загрузка .env ---
function Import-EnvFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    Get-Content -Path $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^\s*#' -or $line -eq '') { return }
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            [System.Environment]::SetEnvironmentVariable($key, $value, 'Process')
        }
    }
}

Import-EnvFile -Path $EnvFile

# --- Загрузка конфигурации ---
if (-not (Test-Path -LiteralPath $Config)) {
    Write-Host "ОШИБКА: Файл конфигурации не найден: $Config"
    exit 1
}

$cfg = Get-Content -Path $Config -Raw | ConvertFrom-Json

function Get-EnvOrConfig {
    param(
        [string]$EnvKey,
        $ConfigValue,
        $DefaultValue
    )
    $envVal = [System.Environment]::GetEnvironmentVariable($EnvKey, 'Process')
    if ($envVal) { return $envVal }
    if ($ConfigValue) { return $ConfigValue }
    return $DefaultValue
}

$BackupPath = Get-EnvOrConfig -EnvKey 'BACKUP_PATH' -ConfigValue $cfg.BackupPath
$ExcludeFolders = if ([System.Environment]::GetEnvironmentVariable('EXCLUDE_FOLDERS', 'Process')) {
    [System.Environment]::GetEnvironmentVariable('EXCLUDE_FOLDERS', 'Process') -split ','
} else {
    $cfg.ExcludeFolders
}
$DailyThreshold = [int](Get-EnvOrConfig -EnvKey 'DAILY_THRESHOLD' -ConfigValue $cfg.Reports.Daily.DaysThreshold -DefaultValue 10)
$WeeklyThreshold = [int](Get-EnvOrConfig -EnvKey 'WEEKLY_THRESHOLD' -ConfigValue $cfg.Reports.Weekly.DaysThreshold -DefaultValue 45)
$MonthlyThreshold = [int](Get-EnvOrConfig -EnvKey 'MONTHLY_THRESHOLD' -ConfigValue $cfg.Reports.Monthly.DaysThreshold -DefaultValue 60)
$OutputPath = Get-EnvOrConfig -EnvKey 'OUTPUT_PATH' -ConfigValue $cfg.OutputPath -DefaultValue '.\reports'
$LogPath = Get-EnvOrConfig -EnvKey 'LOG_PATH' -ConfigValue $cfg.LogPath -DefaultValue '.\logs'
$TriggerPath = Get-EnvOrConfig -EnvKey 'TRIGGER_PATH' -ConfigValue $cfg.TriggerPath -DefaultValue '.\triggers'
$LogRetentionDays = [int](Get-EnvOrConfig -EnvKey 'LOG_RETENTION_DAYS' -ConfigValue $cfg.LogRetentionDays -DefaultValue 7)
$ReportRetentionDays = [int](Get-EnvOrConfig -EnvKey 'REPORT_RETENTION_DAYS' -ConfigValue $cfg.ReportRetentionDays -DefaultValue 7)

# --- Очистка устаревших файлов ---
function Remove-OldFiles {
    param(
        [string]$Path,
        [int]$RetentionDays,
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $cutoff = (Get-Date).AddDays(-$RetentionDays)
    $removed = 0

    Get-ChildItem -Path $Path -File -Recurse | Where-Object { $_.LastWriteTime -lt $cutoff } | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Force
        $removed++
    }

    if ($removed -gt 0) {
        Write-Host "[$Label] Удалено $removed файл(ов) старше $RetentionDays дн."
    }
}

if ($LogPath) {
    Remove-OldFiles -Path $LogPath -RetentionDays $LogRetentionDays -Label "LOGS"
}

if ($OutputPath) {
    Remove-OldFiles -Path $OutputPath -RetentionDays $ReportRetentionDays -Label "REPORTS"
}

# TODO: Вставь свой скрипт мониторинга бэкапов сюда
Write-Host "Backup Monitor - заглушка. Вставь основной скрипт в src\BackupMonitor.ps1"
exit 0
