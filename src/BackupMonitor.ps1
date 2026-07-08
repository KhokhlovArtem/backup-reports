<#
.SYNOPSIS
    Мониторинг и отчётность по бэкапам.

.DESCRIPTION
    Сканирует директорию бэкапов, классифицирует файлы по давности,
    генерирует отчёты и триггер-файлы.

.PARAMETER Config
    Путь к файлу конфигурации JSON.

.PARAMETER Help
    Показать справку.

.EXAMPLE
    .\BackupMonitor.ps1 -Config .\config\config.json

.NOTES
    Коды возврата: 0 (успех), 1 (ошибка), 10 (инцидент)
#>

param(
    [string]$Config = ".\config\config.json",
    [switch]$Help
)

$DefaultLogRetentionDays = 7
$DefaultReportRetentionDays = 7

# --- Загрузка конфигурации ---
if (-not (Test-Path -LiteralPath $Config)) {
    Write-Host "ОШИБКА: Файл конфигурации не найден: $Config"
    exit 1
}

$cfg = Get-Content -Path $Config -Raw | ConvertFrom-Json

$LogRetentionDays = if ($cfg.LogRetentionDays) { $cfg.LogRetentionDays } else { $DefaultLogRetentionDays }
$ReportRetentionDays = if ($cfg.ReportRetentionDays) { $cfg.ReportRetentionDays } else { $DefaultReportRetentionDays }

$LogPath = $cfg.LogPath
$ReportPath = $cfg.OutputPath

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

if ($ReportPath) {
    Remove-OldFiles -Path $ReportPath -RetentionDays $ReportRetentionDays -Label "REPORTS"
}

# TODO: Вставь свой скрипт мониторинга бэкапов сюда
Write-Host "Backup Monitor - заглушка. Вставь основной скрипт в src\BackupMonitor.ps1"
exit 0
