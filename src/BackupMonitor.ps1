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

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# TODO: Вставь свой скрипт мониторинга бэкапов сюда
Write-Host "Backup Monitor - заглушка. Вставь основной скрипт в src\BackupMonitor.ps1"
exit 0
