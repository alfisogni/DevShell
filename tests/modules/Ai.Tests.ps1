#requires -Version 7.0
Describe 'AI module' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        Import-Module (Join-Path $repoRoot 'DevShell.psd1') -Force
        $null = Start-DevShell -Quiet -SkipBanner
    }

    It 'registers cursor provider' {
        $providers = @(Get-DsAiProvider)
        $providers.Name | Should -Contain 'cursor'
    }

    It 'detects agent CLI when present' {
        $path = Join-Path $env:LOCALAPPDATA 'cursor-agent\agent.ps1'
        if (-not (Test-Path -LiteralPath $path)) {
            Set-ItResult -Skipped -Because 'Cursor agent.ps1 not installed on this machine'
            return
        }
        Test-DsAiProvider -Name cursor | Should -BeTrue
    }

    It 'documents one-shot and Chat usage in help text' {
        $help = (Get-Help Invoke-DsAi -Full | Out-String)
        $help | Should -Match '-Chat'
        $help | Should -Match 'one-shot|One-shot|agent'
    }

    It 'Invoke-DsAi supports -Chat parameter' {
        (Get-Command Invoke-DsAi).Parameters.Keys | Should -Contain 'Chat'
    }

    It 'lists tools' {
        $tools = @(Get-DsTool)
        $tools.Name | Should -Contain 'git'
        $tools.Name | Should -Contain 'fzf'
    }
}
