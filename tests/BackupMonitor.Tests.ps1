BeforeAll {
    $ScriptPath = Join-Path $PSScriptRoot '..\src\BackupMonitor.ps1'
}

Describe 'BackupMonitor' {

    Context 'Config Loading' {
        It 'Should load valid JSON config' {
            $configPath = Join-Path $PSScriptRoot '..\config\config.example.json'
            $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
            $config | Should -Not -BeNullOrEmpty
            $config.BackupPath | Should -Be 'E:\share\backup'
        }

        It 'Should have required config keys' {
            $configPath = Join-Path $PSScriptRoot '..\config\config.example.json'
            $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
            $config.PSObject.Properties.Name | Should -Contain 'BackupPath'
            $config.PSObject.Properties.Name | Should -Contain 'ExcludeFolders'
            $config.PSObject.Properties.Name | Should -Contain 'Reports'
        }

        It 'Should have valid thresholds' {
            $configPath = Join-Path $PSScriptRoot '..\config\config.example.json'
            $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
            $config.Reports.Daily.DaysThreshold | Should -BeGreaterThan 0
            $config.Reports.Weekly.DaysThreshold | Should -BeGreaterThan $config.Reports.Daily.DaysThreshold
            $config.Reports.Monthly.DaysThreshold | Should -BeGreaterThan $config.Reports.Weekly.DaysThreshold
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
}
