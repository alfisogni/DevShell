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
        if ($text -is [pscustomobject] -and $text.PSObject.Properties['Style']) {
            $text.Style | Should -Be 'warp'
            $text.Path | Should -Not -BeNullOrEmpty
            $text.Name | Should -Not -BeNullOrEmpty
        }
        elseif ($text -is [hashtable]) {
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
        ($memo -join "`n") | Should -Match 'QUICK REF'
        ($memo -join "`n") | Should -Match 'KEYS'
        ($memo -join "`n") | Should -Match 'dsp'
        # KEYS sits to the right of QUICK REF on the header row
        $header = @($memo | Where-Object { $_ -match 'QUICK REF' } | Select-Object -First 1)
        $header | Should -Match 'KEYS'
        # Compact: not dumping entire alias catalog
        $bodyLines = @($memo | Where-Object { $_ -match '│' })
        $bodyLines.Count | Should -BeLessOrEqual 14
    }

    It 'loads lennerk theme with Interactive and Knowledge' {
        $theme = Import-DsTheme -Name lennerk
        $theme.Name | Should -Be 'lennerk'
        $theme.Colors.Accent | Should -Be '#a6e3a1'
        $theme.Colors.Interactive | Should -Be '#89dceb'
        $theme.Colors.Knowledge | Should -Be '#cba6f7'
        (Get-DsThemeColor -Role Interactive).Hex | Should -Be '#89dceb'
    }

    It 'builds dashboard widget panels' {
        $null = Import-DsTheme -Name lennerk
        $dash = @(Get-DsDashboardWidget)
        $dash[0] | Should -Be 'DEVSHELL'
        ($dash -join "`n") | Should -Match 'WORKSPACE'
        ($dash -join "`n") | Should -Match 'GIT'
    }

    It 'loads tokyo-night theme pack' {
        $theme = Import-DsTheme -Name tokyo-night
        $theme.Name | Should -Be 'tokyo-night'
        $theme.Colors.Bg | Should -Be '#1a1b26'
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
