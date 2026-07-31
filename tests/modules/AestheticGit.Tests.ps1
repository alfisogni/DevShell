#requires -Version 7.0
Describe 'Aesthetic and prompt' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        Import-Module (Join-Path $repoRoot 'DevShell.psd1') -Force
        $null = Start-DevShell -Quiet -SkipBanner
    }

    It 'loads default theme' {
        $theme = Get-DsTheme
        $theme.Name | Should -Be 'default'
        $theme.Colors.Accent | Should -Be '#00C853'
    }

    It 'builds prompt text with location' {
        $text = Get-DsPromptText
        if ($text -is [hashtable]) {
            $text.Body | Should -Not -BeNullOrEmpty
            $text.Sep | Should -Be '>'
        }
        else {
            $text | Should -Match '>'
        }
    }

    It 'loads banner art file' {
        $lines = @(Get-DsBannerArtLines)
        $lines.Count | Should -BeGreaterThan 10
    }

    It 'builds memo side panel' {
        $memo = @(Get-DsMemoWidget)
        $memo[0] | Should -Be 'QUICK REF'
        ($memo -join "`n") | Should -Match 'dsp'
        ($memo -join "`n") | Should -Match 'palette'
    }

    It 'resolves git alias after start' {
        Get-Alias dsg -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        (Get-Alias dsg).Definition | Should -Be 'Invoke-DsGitStatus'
        Get-Alias dsp -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        Get-Alias dsa -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'reports git root inside repo' {
        Set-Location (Get-DsHome)
        $root = Get-DsGitRoot
        $root | Should -Not -BeNullOrEmpty
        Get-DsGitBranch | Should -Not -BeNullOrEmpty
    }
}
