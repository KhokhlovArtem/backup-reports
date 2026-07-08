<#
.SYNOPSIS
    Backup Files Report Generator.

.DESCRIPTION
    Рекурсивный обход каталога бэкапов, генерация CSV-отчётов,
    создание триггер-файлов. Конфигурация через .env.

.PARAMETER EnvFile
    Путь к файлу .env.

.PARAMETER Help
    Показать справку.

.EXAMPLE
    .\BackupMonitor.ps1

.NOTES
    Коды возврата: 0 (успех), 1 (ошибка), 10 (инцидент)
#>

param(
    [string]$EnvFile,
    [switch]$Help
)

$ScriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$ProjectRoot = Split-Path -Path $ScriptDir -Parent

if (-not $EnvFile) { $EnvFile = Join-Path $ProjectRoot '.env' }

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

function Get-EnvValue {
    param([string]$Key, $DefaultValue)
    $val = [System.Environment]::GetEnvironmentVariable($Key, 'Process')
    if ($val) { return $val }
    return $DefaultValue
}

function Resolve-ProjectPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $ProjectRoot $Path
}

# ==================================================================
# НАСТРАИВАЕМЫЕ ПАРАМЕТРЫ (из .env)
# ==================================================================

$RootPath = Get-EnvValue -Key 'BACKUP_PATH' -DefaultValue 'E:\share\backup'

$ExcludeFoldersRaw = Get-EnvValue -Key 'EXCLUDE_FOLDERS' -DefaultValue 'LongTermCopy,!Основание'
$ExcludeFolders = $ExcludeFoldersRaw -split ','

$LogsDir = Resolve-ProjectPath (Get-EnvValue -Key 'LOG_PATH' -DefaultValue '.\logs')
$OutputDir = Resolve-ProjectPath (Get-EnvValue -Key 'OUTPUT_PATH' -DefaultValue '.\reports')
$TriggersDir = Resolve-ProjectPath (Get-EnvValue -Key 'TRIGGER_PATH' -DefaultValue '.\triggers')

$DailyDaysOld = [int](Get-EnvValue -Key 'DAILY_THRESHOLD' -DefaultValue 10)
$WeeklyDaysOld = [int](Get-EnvValue -Key 'WEEKLY_THRESHOLD' -DefaultValue 45)
$MonthlyDaysOld = [int](Get-EnvValue -Key 'MONTHLY_THRESHOLD' -DefaultValue 60)

$LogRetentionDays = [int](Get-EnvValue -Key 'LOG_RETENTION_DAYS' -DefaultValue 7)
$ReportRetentionDays = [int](Get-EnvValue -Key 'REPORT_RETENTION_DAYS' -DefaultValue 7)

$CsvDelimiter = ";"

# ==================================================================
# ЛОГИРОВАНИЕ
# ==================================================================

if (!(Test-Path $LogsDir)) {
    New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
}

$LogTimestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = Join-Path $LogsDir "${LogTimestamp}_backup-report-generator.log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Level : $Message"

    switch ($Level) {
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "WARN"    { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "INFO"    { Write-Host $logEntry -ForegroundColor White }
        "TRIGGER" { Write-Host $logEntry -ForegroundColor Magenta }
        default   { Write-Host $logEntry }
    }

    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

# ==================================================================
# ОЧИСТКА УСТАРЕВШИХ ФАЙЛОВ
# ==================================================================

function Remove-OldFiles {
    param(
        [string]$Path,
        [int]$RetentionDays,
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) { return }

    $cutoff = (Get-Date).AddDays(-$RetentionDays)
    $removed = 0

    Get-ChildItem -Path $Path -File -Recurse | Where-Object { $_.LastWriteTime -lt $cutoff } | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Force
        $removed++
    }

    if ($removed -gt 0) {
        Write-Log -Message "[$Label] Удалено $removed файл(ов) старше $RetentionDays дн." -Level "INFO"
    }
}

Remove-OldFiles -Path $LogsDir -RetentionDays $LogRetentionDays -Label "LOGS"
Remove-OldFiles -Path $OutputDir -RetentionDays $ReportRetentionDays -Label "REPORTS"

# ==================================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ==================================================================

function Get-FileInfo {
    param(
        [string]$Path,
        [string]$SearchPattern,
        [int]$DaysOld,
        [string]$ReportType
    )

    $CutoffDate = (Get-Date).AddDays(-$DaysOld)
    $Results = @()
    $TotalScanned = 0
    $TotalExcluded = 0

    Write-Log -Message "Start scanning for $ReportType (pattern: '$SearchPattern', older than $DaysOld days)" -Level "INFO"

    Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
    ForEach-Object {
        $TotalScanned++
        $filePath = $_.FullName

        $exclude = $false
        foreach ($folder in $ExcludeFolders) {
            if ($filePath -match "\\$folder\\") {
                $exclude = $true
                $TotalExcluded++
                break
            }
        }

        if ($exclude) { return }

        $containsPattern = $filePath -match $SearchPattern
        $isOldEnough = $_.LastWriteTime -lt $CutoffDate

        if ($containsPattern -and $isOldEnough) {
            $Results += [PSCustomObject]@{
                Type          = $ReportType
                FULLPATHTOFILE = $filePath
                SIZE          = $_.Length
                "DATA change" = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                "DATA Create" = $_.CreationTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
    }

    Write-Log -Message "Scanning completed for $ReportType`: $($Results.Count) files found (scanned: $TotalScanned, excluded: $TotalExcluded)" -Level "INFO"

    return $Results
}

function Export-ToCsvFile {
    param(
        [array]$Data,
        [string]$ReportType,
        [string]$OutputPath
    )

    if ($Data.Count -gt 0) {
        $CsvFileName = "${ReportType}_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $CsvFullPath = Join-Path $OutputPath $CsvFileName

        $Data | Export-Csv -Path $CsvFullPath -NoTypeInformation -Delimiter $CsvDelimiter -Encoding UTF8
        Write-Log -Message "$ReportType`: $($Data.Count) files exported to $CsvFullPath" -Level "SUCCESS"
        return $CsvFullPath
    } else {
        Write-Log -Message "$ReportType`: No matching files found" -Level "WARN"
        return $null
    }
}

function Create-TriggerFile {
    param(
        [string]$ReportType,
        [int]$FileCount,
        [string]$TriggersPath
    )

    if (!(Test-Path $TriggersPath)) {
        New-Item -ItemType Directory -Path $TriggersPath -Force | Out-Null
        Write-Log -Message "Created triggers directory: $TriggersPath" -Level "INFO"
    }

    $TriggerFileName = "$ReportType.txt"
    $TriggerFullPath = Join-Path $TriggersPath $TriggerFileName

    $FileCount | Out-File -FilePath $TriggerFullPath -Encoding UTF8 -Force

    if ($FileCount -gt 0) {
        Write-Log -Message "TRIGGER CREATED: $ReportType - $FileCount files found. Trigger file: $TriggerFullPath" -Level "TRIGGER"
    } else {
        Write-Log -Message "Trigger file updated: $ReportType - No files found. Trigger file: $TriggerFullPath" -Level "INFO"
    }

    return $TriggerFullPath
}

# ==================================================================
# ПРОВЕРКИ
# ==================================================================

Write-Log -Message "========================================" -Level "INFO"
Write-Log -Message "Starting Backup Files Report Generator" -Level "INFO"
Write-Log -Message "========================================" -Level "INFO"

Write-Log -Message "Script directory: $ScriptDir" -Level "INFO"
Write-Log -Message "Logs directory: $LogsDir" -Level "INFO"
Write-Log -Message "Reports directory: $OutputDir" -Level "INFO"
Write-Log -Message "Triggers directory: $TriggersDir" -Level "INFO"

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Log -Message "Running with Administrator privileges" -Level "SUCCESS"
} else {
    Write-Log -Message "Warning: Running without Administrator privileges. Some files may be inaccessible." -Level "WARN"
}

if (!(Test-Path $RootPath)) {
    Write-Log -Message "Root directory not found: $RootPath" -Level "ERROR"
    Write-Log -Message "Script terminated" -Level "ERROR"
    exit 1
}
Write-Log -Message "Root directory exists: $RootPath" -Level "SUCCESS"

foreach ($folder in $ExcludeFolders) {
    $folderPath = Join-Path $RootPath $folder
    if (Test-Path $folderPath) {
        Write-Log -Message "Excluded folder found: $folderPath" -Level "INFO"
    } else {
        Write-Log -Message "Excluded folder not found (skipping): $folderPath" -Level "WARN"
    }
}

if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Log -Message "Created output directory: $OutputDir" -Level "SUCCESS"
} else {
    Write-Log -Message "Output directory exists: $OutputDir" -Level "INFO"
}

# ==================================================================
# ОСНОВНАЯ ЛОГИКА
# ==================================================================

try {
    Write-Log -Message "Starting data collection..." -Level "INFO"

    $DailyFiles = Get-FileInfo -Path $RootPath -SearchPattern "Daily" -DaysOld $DailyDaysOld -ReportType "Daily"
    $WeeklyFiles = Get-FileInfo -Path $RootPath -SearchPattern "Weekly" -DaysOld $WeeklyDaysOld -ReportType "Weekly"
    $MonthlyFiles = Get-FileInfo -Path $RootPath -SearchPattern "Monthly" -DaysOld $MonthlyDaysOld -ReportType "Monthly"

    Write-Log -Message "Exporting reports to CSV..." -Level "INFO"

    $DailyCsv = Export-ToCsvFile -Data $DailyFiles -ReportType "Daily" -OutputPath $OutputDir
    $WeeklyCsv = Export-ToCsvFile -Data $WeeklyFiles -ReportType "Weekly" -OutputPath $OutputDir
    $MonthlyCsv = Export-ToCsvFile -Data $MonthlyFiles -ReportType "Monthly" -OutputPath $OutputDir

    Write-Log -Message "Creating trigger files..." -Level "INFO"

    $DailyTrigger = Create-TriggerFile -ReportType "Daily" -FileCount $DailyFiles.Count -TriggersPath $TriggersDir
    $WeeklyTrigger = Create-TriggerFile -ReportType "Weekly" -FileCount $WeeklyFiles.Count -TriggersPath $TriggersDir
    $MonthlyTrigger = Create-TriggerFile -ReportType "Monthly" -FileCount $MonthlyFiles.Count -TriggersPath $TriggersDir

    # ==================================================================
    # ИТОГОВАЯ СВОДКА
    # ==================================================================

    $TotalFiles = $DailyFiles.Count + $WeeklyFiles.Count + $MonthlyFiles.Count
    $HasIncidents = ($DailyFiles.Count -gt 0) -or ($WeeklyFiles.Count -gt 0) -or ($MonthlyFiles.Count -gt 0)

    Write-Log -Message "========================================" -Level "INFO"
    Write-Log -Message "SUMMARY" -Level "INFO"
    Write-Log -Message "========================================" -Level "INFO"
    Write-Log -Message "Daily files found:   $($DailyFiles.Count)" -Level "INFO"
    Write-Log -Message "Weekly files found:  $($WeeklyFiles.Count)" -Level "INFO"
    Write-Log -Message "Monthly files found: $($MonthlyFiles.Count)" -Level "INFO"
    Write-Log -Message "Total files:         $TotalFiles" -Level "INFO"
    Write-Log -Message "========================================" -Level "INFO"

    if ($HasIncidents) {
        Write-Log -Message "INCIDENT DETECTED: Files found matching criteria!" -Level "TRIGGER"

        if ($DailyFiles.Count -gt 0) {
            Write-Log -Message "   - Daily: $($DailyFiles.Count) files (older than $DailyDaysOld days)" -Level "TRIGGER"
        }
        if ($WeeklyFiles.Count -gt 0) {
            Write-Log -Message "   - Weekly: $($WeeklyFiles.Count) files (older than $WeeklyDaysOld days)" -Level "TRIGGER"
        }
        if ($MonthlyFiles.Count -gt 0) {
            Write-Log -Message "   - Monthly: $($MonthlyFiles.Count) files (older than $MonthlyDaysOld days)" -Level "TRIGGER"
        }
    } else {
        Write-Log -Message "No incidents detected. All criteria satisfied." -Level "SUCCESS"
    }

    Write-Log -Message "========================================" -Level "INFO"

    if ($DailyCsv) { Write-Log -Message "Daily CSV:   $DailyCsv" -Level "SUCCESS" }
    if ($WeeklyCsv) { Write-Log -Message "Weekly CSV:  $WeeklyCsv" -Level "SUCCESS" }
    if ($MonthlyCsv) { Write-Log -Message "Monthly CSV: $MonthlyCsv" -Level "SUCCESS" }

    Write-Log -Message "Daily Trigger:   $DailyTrigger" -Level "INFO"
    Write-Log -Message "Weekly Trigger:  $WeeklyTrigger" -Level "INFO"
    Write-Log -Message "Monthly Trigger: $MonthlyTrigger" -Level "INFO"

    Write-Log -Message "Script completed successfully!" -Level "SUCCESS"
    Write-Log -Message "Log file: $LogFile" -Level "INFO"

    if ($HasIncidents) {
        exit 10
    } else {
        exit 0
    }

} catch {
    Write-Log -Message "An error occurred during execution: $($_.Exception.Message)" -Level "ERROR"
    Write-Log -Message "Error details: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}
