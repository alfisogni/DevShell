#requires -Version 7.0
Describe 'History and utilities' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        Import-Module (Join-Path $repoRoot 'DevShell.psd1') -Force
        $null = Start-DevShell -Quiet -SkipBanner
    }

    It 'exports history helpers' {
        Get-Command Get-DsHistory | Should -Not -BeNullOrEmpty
        Get-Command Invoke-DsHistory | Should -Not -BeNullOrEmpty
    }

    It 'resolves which for pwsh' {
        $w = Get-DsWhich pwsh
        $w.Name | Should -Match 'pwsh'
        $w.Path | Should -Not -BeNullOrEmpty
    }

    It 'writes a quick note' {
        $dir = Join-Path $env:TEMP ("DevShellNotes-" + [guid]::NewGuid().ToString('n'))
        Invoke-DsNote 'test note from pester' -Directory $dir
        $file = Get-ChildItem -LiteralPath $dir -Filter '*.md' | Select-Object -First 1
        $file | Should -Not -BeNullOrEmpty
        (Get-Content -LiteralPath $file.FullName -Raw) | Should -Match 'test note from pester'
        Remove-Item -LiteralPath $dir -Recurse -Force
    }
}
