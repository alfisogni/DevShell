#requires -Version 7.0
Describe 'Fuzzy fallback resolve' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        Import-Module (Join-Path $repoRoot 'DevShell.psd1') -Force
        $null = Start-DevShell -Quiet -SkipBanner
    }

    It 'exports Invoke-DsFuzzy' {
        Get-Command Invoke-DsFuzzy | Should -Not -BeNullOrEmpty
    }

    It 'lists projects under source when present' {
        $projects = @(Get-DsProject)
        $projects | Should -Not -BeNullOrEmpty
        $projects.Name | Should -Contain 'devshell'
    }

    It 'Set-DsLocation updates context' {
        $dsHome = (Get-DsHome)
        Set-DsLocation -Path $dsHome
        (Get-DsContext).Location | Should -Be $dsHome
    }
}

Describe 'PSReadLine chord normalize' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        Import-Module (Join-Path $repoRoot 'core\Core.psd1') -Force
    }

    It 'normalizes Ctrl+Shift+P' {
        ConvertTo-DsPsReadLineChord 'Ctrl+Shift+P' | Should -Be 'Ctrl+Shift+p'
    }
}
