#requires -Version 7.0
Describe 'Aliases and adaptive banner' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        Import-Module (Join-Path $repoRoot 'DevShell.psd1') -Force
        $null = Start-DevShell -Quiet -SkipBanner
    }

    It 'Get-DsAlias includes dsg -> Invoke-DsGitStatus' {
        $row = @(Get-DsAlias) | Where-Object { $_.Name -eq 'dsg' } | Select-Object -First 1
        $row | Should -Not -BeNullOrEmpty
        $row.Target | Should -Be 'Invoke-DsGitStatus'
        $row.Ok | Should -BeTrue
    }

    It 'memo widget lines come from alias catalog' {
        $catalog = Get-DsAliasCatalog
        $memo = @(Get-DsMemoWidget) -join "`n"
        foreach ($name in $catalog.Keys) {
            $memo | Should -BeLike "*$name*"
        }
    }

    It 'Resolve-DsBannerLayout stacks when narrow' {
        Resolve-DsBannerLayout -ArtWidth 70 -MemoWidth 40 -Gap 4 -WindowWidth 80 -ForceLayout Auto |
            Should -Be 'Stack'
        Resolve-DsBannerLayout -ArtWidth 70 -MemoWidth 40 -Gap 4 -WindowWidth 200 -ForceLayout Auto |
            Should -Be 'Side'
        Resolve-DsBannerLayout -ArtWidth 10 -MemoWidth 10 -Gap 4 -WindowWidth 200 -ForceLayout Stack |
            Should -Be 'Stack'
    }

    It 'memo KEYS include live knowledge chord when registered' {
        $memo = @(Get-DsMemoWidget) -join "`n"
        $hasKnowledgeKey = $memo -match 'Alt\+K' -or $memo -match 'knowledge|report'
        $bindings = @(Get-DsKeyBinding -Chord 'Ctrl+Alt+K')
        if ($bindings.Count -gt 0) {
            $hasKnowledgeKey | Should -BeTrue
        }
    }

    It 'Show-DsBanner -ForceLayout Stack does not throw' {
        { Show-DsBanner -ForceLayout Stack } | Should -Not -Throw
    }

    It 'doctor reports Alias:dsg' {
        $results = @(Invoke-DsDoctor -Quiet)
        ($results | Where-Object { $_.Name -eq 'Alias:dsg' }).Count | Should -Be 1
    }
}
