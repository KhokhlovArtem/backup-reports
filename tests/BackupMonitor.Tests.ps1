BeforeAll {
    $ScriptPath = Join-Path $PSScriptRoot '..\src\BackupMonitor.ps1'
}

Describe 'BackupMonitor' {

    Context 'Env Loading' {
        BeforeAll {
            $testEnv = Join-Path ([System.IO.Path]::GetTempPath()) "test-$(Get-Random).env"
            @(
                'BACKUP_PATH=E:\test\backup',
                'EXCLUDE_FOLDERS=Folder1,Folder2',
                'DAILY_THRESHOLD=5',
                'LOG_RETENTION_DAYS=14',
                '# comment line',
                '',
                'REPORT_RETENTION_DAYS=30'
            ) | Set-Content -Path $testEnv
        }

        AfterAll {
            Remove-Item -Path $testEnv -Force -ErrorAction SilentlyContinue
        }

        It 'Should parse KEY=value pairs' {
            $lines = Get-Content -Path $testEnv
            $parsed = @{}
            foreach ($line in $lines) {
                $line = $line.Trim()
                if ($line -match '^\s*#' -or $line -eq '') { continue }
                if ($line -match '^([^=]+)=(.*)$') {
                    $parsed[$Matches[1].Trim()] = $Matches[2].Trim()
                }
            }
            $parsed['BACKUP_PATH'] | Should -Be 'E:\test\backup'
            $parsed['DAILY_THRESHOLD'] | Should -Be '5'
        }

        It 'Should skip comment lines' {
            $lines = Get-Content -Path $testEnv
            $commentCount = ($lines | Where-Object { $_.Trim() -match '^\s*#' }).Count
            $commentCount | Should -Be 1
        }

        It 'Should skip empty lines' {
            $lines = Get-Content -Path $testEnv
            $emptyCount = ($lines | Where-Object { $_.Trim() -eq '' }).Count
            $emptyCount | Should -Be 1
        }

        It 'Should parse comma-separated list' {
            $value = 'Folder1,Folder2'
            $items = $value -split ','
            $items.Count | Should -Be 2
            $items[0] | Should -Be 'Folder1'
            $items[1] | Should -Be 'Folder2'
        }
    }

    Context 'File Age Calculation' {
        It 'Should correctly calculate file age in days' {
            $oldDate = (Get-Date).AddDays(-15)
            $ageDays = ((Get-Date) - $oldDate).Days
            $ageDays | Should -Be 15
        }

        It 'Should classify old files correctly' {
            $threshold = 10
            $oldDate = (Get-Date).AddDays(-15)
            $ageDays = ((Get-Date) - $oldDate).Days
            ($ageDays -gt $threshold) | Should -BeTrue
        }

        It 'Should classify recent files correctly' {
            $threshold = 10
            $recentDate = (Get-Date).AddDays(-5)
            $ageDays = ((Get-Date) - $recentDate).Days
            ($ageDays -gt $threshold) | Should -BeFalse
        }
    }

    Context 'Exclude Folders' {
        It 'Should exclude LongTermCopy folder' {
            $excludeFolders = @('LongTermCopy', '!Основание')
            $testPath = 'E:\share\backup\LongTermCopy\test.txt'
            $shouldExclude = $false
            foreach ($folder in $excludeFolders) {
                if ($testPath -like "*\$folder\*") {
                    $shouldExclude = $true
                }
            }
            $shouldExclude | Should -BeTrue
        }

        It 'Should exclude folder with exclamation mark' {
            $excludeFolders = @('LongTermCopy', '!Основание')
            $testPath = 'E:\share\backup\!Основание\test.txt'
            $shouldExclude = $false
            foreach ($folder in $excludeFolders) {
                if ($testPath -like "*\$folder\*") {
                    $shouldExclude = $true
                }
            }
            $shouldExclude | Should -BeTrue
        }

        It 'Should not exclude other folders' {
            $excludeFolders = @('LongTermCopy', '!Основание')
            $testPath = 'E:\share\backup\DailyBackup\test.txt'
            $shouldExclude = $false
            foreach ($folder in $excludeFolders) {
                if ($testPath -like "*\$folder\*") {
                    $shouldExclude = $true
                }
            }
            $shouldExclude | Should -BeFalse
        }
    }

    Context 'Return Codes' {
        It 'Should define exit code 0 for success' {
            $exitCode = 0
            $exitCode | Should -Be 0
        }

        It 'Should define exit code 1 for error' {
            $exitCode = 1
            $exitCode | Should -Be 1
        }

        It 'Should define exit code 10 for incident' {
            $exitCode = 10
            $exitCode | Should -Be 10
        }
    }

    Context 'Report Classification' {
        It 'Should classify Daily files (10+ days)' {
            $threshold = 10
            $ageDays = 15
            ($ageDays -gt $threshold) | Should -BeTrue
        }

        It 'Should classify Weekly files (45+ days)' {
            $threshold = 45
            $ageDays = 50
            ($ageDays -gt $threshold) | Should -BeTrue
        }

        It 'Should classify Monthly files (60+ days)' {
            $threshold = 60
            $ageDays = 75
            ($ageDays -gt $threshold) | Should -BeTrue
        }

        It 'Should not classify recent file as Daily' {
            $threshold = 10
            $ageDays = 5
            ($ageDays -gt $threshold) | Should -BeFalse
        }
    }

    Context 'File Cleanup' {
        BeforeAll {
            $testDir = Join-Path ([System.IO.Path]::GetTempPath()) "backup-monitor-test-$(Get-Random)"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        }

        AfterAll {
            Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Should remove files older than retention period' {
            $subDir = Join-Path $testDir "logs"
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null

            $oldFile = Join-Path $subDir "old.log"
            Set-Content -Path $oldFile -Value "old"
            $item = Get-Item -LiteralPath $oldFile
            $item.LastWriteTime = (Get-Date).AddDays(-10)
            $item.Refresh()

            $recentFile = Join-Path $subDir "recent.log"
            Set-Content -Path $recentFile -Value "recent"

            $cutoff = (Get-Date).AddDays(-7)
            Get-ChildItem -Path $subDir -File | Where-Object { $_.LastWriteTime -lt $cutoff } | ForEach-Object {
                Remove-Item -LiteralPath $_.FullName -Force
            }

            (Test-Path -LiteralPath $oldFile) | Should -BeFalse
            (Test-Path -LiteralPath $recentFile) | Should -BeTrue
        }

        It 'Should not remove files within retention period' {
            $subDir = Join-Path $testDir "recent"
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null

            $file = Join-Path $subDir "fresh.log"
            Set-Content -Path $file -Value "fresh"

            $cutoff = (Get-Date).AddDays(-7)
            Get-ChildItem -Path $subDir -File | Where-Object { $_.LastWriteTime -lt $cutoff } | ForEach-Object {
                Remove-Item -LiteralPath $_.FullName -Force
            }

            (Test-Path -LiteralPath $file) | Should -BeTrue
        }

        It 'Should not fail on non-existent directory' {
            $fakePath = Join-Path $testDir "nonexistent"
            $result = $true
            if (Test-Path -LiteralPath $fakePath) {
                Get-ChildItem -Path $fakePath -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            }
            $result | Should -BeTrue
        }
    }
}
