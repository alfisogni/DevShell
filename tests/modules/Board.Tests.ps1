#requires -Version 7.0
Describe 'Board pinboard' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        Import-Module (Join-Path $repoRoot 'DevShell.psd1') -Force
        $null = Start-DevShell -Quiet -SkipBanner
        $script:BoardPath = Join-Path $TestDrive 'pinboard.json'
        # Isolate board data via env is not supported — use temp by swapping after load
    }

    It 'adds task and shows on board' {
        $item = Add-DsBoardTask -Text 'Review PR' -Board 'Today'
        $item.Type | Should -Be 'task'
        $item.Text | Should -Be 'Review PR'
        $data = Get-DsBoardData -Refresh
        $found = $false
        foreach ($b in $data.boards.Keys) {
            foreach ($it in @($data.boards[$b])) {
                if ($it.Id -eq $item.Id) { $found = $true }
            }
        }
        $found | Should -Be $true
    }

    It 'toggles task done' {
        $item = Add-DsBoardTask -Text 'Toggle me' -Board 'Today'
        Complete-DsBoardTask -Id $item.Id | Out-Null
        $data = Get-DsBoardData -Refresh
        $done = $false
        foreach ($b in $data.boards.Keys) {
            foreach ($it in @($data.boards[$b])) {
                if ($it.Id -eq $item.Id) { $done = [bool]$it.Done }
            }
        }
        $done | Should -Be $true
    }
}
