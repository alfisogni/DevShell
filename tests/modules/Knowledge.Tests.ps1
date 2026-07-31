#requires -Version 7.0
Describe 'Knowledge Engine module' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        $script:TestKnowledgeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("DevShellKnowledgeTests-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TestKnowledgeRoot -Force | Out-Null
        $env:DEVSHELL_KNOWLEDGE_ROOT = $script:TestKnowledgeRoot

        Import-Module (Join-Path $repoRoot 'DevShell.psd1') -Force
        $null = Start-DevShell -Quiet -SkipBanner
    }

    AfterAll {
        Remove-Item -Path Env:DEVSHELL_KNOWLEDGE_ROOT -ErrorAction SilentlyContinue
        if ($script:TestKnowledgeRoot -and (Test-Path -LiteralPath $script:TestKnowledgeRoot)) {
            Remove-Item -LiteralPath $script:TestKnowledgeRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'registers core knowledge providers' {
        $names = @(Get-DsKnowledgeProvider | ForEach-Object Name)
        $names | Should -Contain 'git'
        $names | Should -Contain 'notes'
        $names | Should -Contain 'github'
        $names | Should -Contain 'linear'
        $names | Should -Contain 'azure'
        $names | Should -Contain 'cursor'
    }

    It 'orders providers by priority (git first)' {
        $ordered = @(Get-DsKnowledgeProvider)
        $ordered[0].Name | Should -Be 'git'
        ($ordered | Where-Object Name -EQ 'notes').Priority | Should -BeLessThan 50
    }

    It 'writes journal files for today in non-interactive mode' {
        $null = Add-DsKnowledgeNote 'Test decision: keep Company.depot as fallback'
        $result = Invoke-DsReport -Period today -NonInteractive -SkipAuth
        $result.Journal | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath (Join-Path $result.Journal 'executive.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $result.Journal 'technical.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $result.Journal 'knowledge.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $result.Journal 'metadata.json') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $result.Journal 'context.json') | Should -BeTrue
    }

    It 'merges notes claim into knowledge.md' {
        $result = Invoke-DsReport -Period today -NonInteractive -SkipAuth
        $knowledge = Get-Content -LiteralPath (Join-Path $result.Journal 'knowledge.md') -Raw
        $knowledge | Should -Match 'Company\.depot'
    }

    It 'updates knowledge graph with entities' {
        $null = Invoke-DsReport -Period today -NonInteractive -SkipAuth
        $graph = Get-DsKnowledgeGraph
        @($graph.Entities).Count | Should -BeGreaterThan 0
    }

    It 'Search-DsKnowledge finds note content' {
        $null = Invoke-DsReport -Period today -NonInteractive -SkipAuth
        $hits = @(Search-DsKnowledge -Query 'Company.depot')
        $hits.Count | Should -BeGreaterThan 0
    }

    It 'Invoke-DsReport -Json returns structured result' {
        $jsonOut = Invoke-DsReport -Period today -NonInteractive -SkipAuth -Json
        if ($jsonOut -is [string]) {
            { $jsonOut | ConvertFrom-Json } | Should -Not -Throw
        }
        else {
            $jsonOut.Journal | Should -Not -BeNullOrEmpty
        }
    }

    It 'Invoke-DsReport -Path returns journal directory' {
        $path = Invoke-DsReport -Period today -Path
        $path | Should -Match 'journal'
        Test-Path -LiteralPath $path | Should -BeTrue
    }

    It 'Export-DsKnowledge copies journal days' {
        $null = Invoke-DsReport -Period today -NonInteractive -SkipAuth
        $out = Join-Path $script:TestKnowledgeRoot 'export-out'
        $bundle = Export-DsKnowledge -Period today -OutPath $out
        Test-Path -LiteralPath $bundle | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $bundle 'graph') | Should -BeTrue
    }

    It 'exposes Invoke-DsDev and dev alias' {
        (Get-Command Invoke-DsDev).Name | Should -Be 'Invoke-DsDev'
        (Get-Command dev -ErrorAction SilentlyContinue).Name | Should -Be 'dev'
    }

    It 'Merge raises confidence when sources agree' {
        InModuleScope knowledge {
            $a = New-DsKnowledgeFragment -Provider git -Claims @(
                New-DsKnowledgeClaim -Text 'Same claim text' -Sources git -Confidence 80 -Kind fact
            )
            $b = New-DsKnowledgeFragment -Provider notes -Claims @(
                New-DsKnowledgeClaim -Text 'Same claim text' -Sources notes -Confidence 70 -Kind fact
            )
            $merged = Merge-DsKnowledgeFragments -Fragments @($a, $b) -ProviderPriority @{ git = 100; notes = 10 }
            $claim = @($merged.Claims | Where-Object Text -EQ 'Same claim text')[0]
            $claim.Sources | Should -Contain 'git'
            $claim.Sources | Should -Contain 'notes'
            $claim.Confidence | Should -BeGreaterThan 80
        }
    }

    It 'scope include/exclude filters project names' {
        InModuleScope knowledge {
            $scope = New-DsKnowledgeScope -Project DemoApp -ExcludeProject DevShell
            Test-DsKnowledgeNameInScope -Name DemoApp -Scope $scope | Should -BeTrue
            Test-DsKnowledgeNameInScope -Name DevShell -Scope $scope | Should -BeFalse
            Test-DsKnowledgeTextInScope -Text '[DemoApp] done' -Scope $scope | Should -BeTrue
            Test-DsKnowledgeTextInScope -Text '[DevShell] meta' -Scope $scope | Should -BeFalse
        }
    }

    It 'Invoke-DsReport accepts -Project and records scope in metadata' {
        $null = Add-DsKnowledgeNote -Project DemoApp -Text 'scoped note for DemoApp'
        $result = Invoke-DsReport -Period today -Project DemoApp -NonInteractive -SkipAuth
        $meta = Get-Content -LiteralPath (Join-Path $result.Journal 'metadata.json') -Raw | ConvertFrom-Json
        $meta.scope | Should -Not -BeNullOrEmpty
        $meta.scope.include | Should -Contain 'DemoApp'
    }

    It 'preserves multi-line note body for scoped reports' {
        $long = @"
Functional summary for tests
- Finding A
- Risk B
"@
        $null = Add-DsKnowledgeNote -Project Acme -Text $long
        $result = Invoke-DsReport -Period today -Project Acme -NonInteractive -SkipAuth
        $knowledge = Get-Content -LiteralPath (Join-Path $result.Journal 'knowledge.md') -Raw
        $knowledge | Should -Match 'Functional summary for tests'
        $knowledge | Should -Not -Match 'No notes matched report scope'
    }

    It 'keeps newlines from a single here-string argument' {
        $path = Add-DsKnowledgeNote -Project DemoApp -Text @'
linea uno
linea dos
'@
        $raw = Get-Content -LiteralPath $path -Raw
        $raw | Should -Match 'linea uno'
        $raw | Should -Match 'linea dos'
    }
}
