#requires -Version 7.0
Describe 'DevShell Loader' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        Import-Module (Join-Path $repoRoot 'core\Core.psd1') -Force
    }

    It 'validates a good manifest' {
        $json = @{
            name = 'doctor'
            version = '0.1.0'
            description = 'test'
            dependsOn = @()
            enabledByDefault = $true
        } | ConvertTo-Json | ConvertFrom-Json
        $r = Test-DsModuleManifest -Manifest $json -DirectoryName 'doctor'
        $r.Ok | Should -BeTrue
    }

    It 'rejects name/folder mismatch' {
        $json = @{
            name = 'nope'
            version = '0.1.0'
            description = 'test'
        } | ConvertTo-Json | ConvertFrom-Json
        $r = Test-DsModuleManifest -Manifest $json -DirectoryName 'doctor'
        $r.Ok | Should -BeFalse
    }

    It 'topo-sorts dependencies' {
        $manifests = @{
            fuzzy = [pscustomobject]@{ dependsOn = @() }
            navigation = [pscustomobject]@{ dependsOn = @('fuzzy') }
            projects = [pscustomobject]@{ dependsOn = @('fuzzy', 'navigation') }
        }
        $order = Get-DsModuleLoadOrder -ManifestsByName $manifests -EnabledNames @('projects', 'fuzzy', 'navigation')
        $order.IndexOf('fuzzy') | Should -BeLessThan $order.IndexOf('navigation')
        $order.IndexOf('navigation') | Should -BeLessThan $order.IndexOf('projects')
    }

    It 'pascal-cases module names' {
        ConvertTo-DsPascalName 'aesthetic' | Should -Be 'Aesthetic'
        ConvertTo-DsPascalName 'my-mod' | Should -Be 'MyMod'
    }

    It 'merges hashtables deeply' {
        $a = @{ A = 1; Nested = @{ X = 1; Y = 2 } }
        $b = @{ Nested = @{ Y = 9; Z = 3 }; B = 2 }
        $m = Merge-DsHashtable -Base $a -Override $b
        $m.A | Should -Be 1
        $m.B | Should -Be 2
        $m.Nested.X | Should -Be 1
        $m.Nested.Y | Should -Be 9
        $m.Nested.Z | Should -Be 3
    }
}

Describe 'DevShell Start' {
    It 'starts and loads doctor' {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        Import-Module (Join-Path $repoRoot 'DevShell.psd1') -Force
        $result = Start-DevShell -Quiet -SkipBanner
        $result.Loaded | Should -Contain 'doctor'
        { Get-DsContext } | Should -Not -Throw
        { Invoke-DsDoctor -Quiet } | Should -Not -Throw
    }
}
