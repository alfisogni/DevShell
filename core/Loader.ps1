#requires -Version 7.0
# Loader.ps1 — discover, validate, topo-sort, import, hooks (fail-soft).

function Get-DsModuleRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HomePath
    )
    Join-Path $HomePath 'modules'
}

function Find-DsModuleDirectories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModulesRoot
    )

    if (-not (Test-Path -LiteralPath $ModulesRoot)) { return @() }

    Get-ChildItem -LiteralPath $ModulesRoot -Directory |
        Where-Object { $_.Name -notlike '_*' } |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'module.json') }
}

function ConvertTo-DsPascalName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $Name }
    $parts = $Name -split '[-_]'
    ($parts | ForEach-Object {
        if ($_.Length -eq 0) { return '' }
        $_.Substring(0, 1).ToUpper() + $_.Substring(1).ToLower()
    }) -join ''
}

function Get-DsModuleEntryPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleDir,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $pascal = ConvertTo-DsPascalName $Name
    $candidate = Join-Path $ModuleDir "$pascal.psm1"
    if (Test-Path -LiteralPath $candidate) { return $candidate }

    $any = Get-ChildItem -LiteralPath $ModuleDir -Filter '*.psm1' -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($any) { return $any.FullName }
    return $null
}

function Get-DsEnabledModuleNames {
    [CmdletBinding()]
    param(
        [hashtable]$ModulesConfig,
        [object[]]$Discovered
    )

    $disabled = @()
    if ($ModulesConfig -and $ModulesConfig.Disabled) {
        $disabled = @($ModulesConfig.Disabled)
    }

    $enabledExplicit = $null
    if ($ModulesConfig -and $ModulesConfig.Enabled) {
        $enabledExplicit = @($ModulesConfig.Enabled)
    }

    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($dir in $Discovered) {
        $name = $dir.Name
        if ($disabled -contains $name) { continue }

        $manifestPath = Join-Path $dir.FullName 'module.json'
        try {
            $m = Read-DsModuleManifest -Path $manifestPath
        }
        catch {
            Write-DsLog -Level Warn -Module loader -Message "Cannot read manifest for '$name': $($_.Exception.Message)"
            continue
        }

        if ($enabledExplicit) {
            if ($enabledExplicit -contains $name) {
                $result.Add($name) | Out-Null
            }
        }
        else {
            $byDefault = $true
            if ($null -ne $m.enabledByDefault) { $byDefault = [bool]$m.enabledByDefault }
            if ($byDefault) { $result.Add($name) | Out-Null }
        }
    }
    return @($result)
}

function Get-DsModuleLoadOrder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ManifestsByName,

        [Parameter(Mandatory)]
        [string[]]$EnabledNames
    )

    $enabled = @($EnabledNames | Select-Object -Unique)
    $indegree = @{}
    $reverse = @{} # dep -> modules that depend on it

    foreach ($name in $enabled) {
        $indegree[$name] = 0
        $reverse[$name] = [System.Collections.Generic.List[string]]::new()
    }

    foreach ($name in $enabled) {
        if (-not $ManifestsByName.ContainsKey($name)) {
            Write-DsLog -Level Warn -Module loader -Message "Unknown module '$name' in dependency graph"
            continue
        }
        foreach ($dep in @($ManifestsByName[$name].dependsOn | Where-Object { $_ })) {
            if ($enabled -notcontains $dep) {
                Write-DsLog -Level Warn -Module loader -Message "Module '$name' depends on '$dep' which is not enabled"
                continue
            }
            $indegree[$name] = [int]$indegree[$name] + 1
            $reverse[$dep].Add($name) | Out-Null
        }
    }

    $queue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($name in ($enabled | Sort-Object)) {
        if ([int]$indegree[$name] -eq 0) { $queue.Enqueue($name) }
    }

    $sorted = [System.Collections.Generic.List[string]]::new()
    while ($queue.Count -gt 0) {
        $n = $queue.Dequeue()
        $sorted.Add($n) | Out-Null
        foreach ($child in $reverse[$n]) {
            $indegree[$child] = [int]$indegree[$child] - 1
            if ([int]$indegree[$child] -eq 0) { $queue.Enqueue($child) }
        }
    }

    if ($sorted.Count -lt $enabled.Count) {
        $missing = @($enabled | Where-Object { -not $sorted.Contains($_) })
        Write-DsLog -Level Warn -Module loader -Message "Dependency cycle or unresolved: $($missing -join ', ')"
        foreach ($m in $missing) { $sorted.Add($m) | Out-Null }
    }

    return @($sorted)
}

function Invoke-DsModuleHook {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        $Manifest,

        [Parameter(Mandatory)]
        [string]$HookName
    )

    $hooks = $Manifest.hooks
    if (-not $hooks) { return }

    $fnName = $null
    if ($hooks.PSObject.Properties.Name -contains $HookName) {
        $fnName = [string]$hooks.$HookName
    }
    if ([string]::IsNullOrWhiteSpace($fnName)) { return }

    $cmd = Get-Command -Name $fnName -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-DsLog -Level Debug -Module loader -Message "Hook $HookName → $fnName not found (module $ModuleName)"
        return
    }

    try {
        & $fnName
    }
    catch {
        Write-DsLog -Level Warn -Module loader -Message "Hook $HookName on '$ModuleName' failed: $($_.Exception.Message)"
    }
}

function Import-DsModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$ModuleDir,

        [Parameter(Mandatory)]
        $Manifest
    )

    $entry = Get-DsModuleEntryPath -ModuleDir $ModuleDir -Name $Name
    if (-not $entry) {
        Write-DsLog -Level Warn -Module loader -Message "No .psm1 entry for module '$Name'"
        return $false
    }

    # Skip requires.commands soft-check: warn only
    if ($Manifest.requires -and $Manifest.requires.commands) {
        foreach ($cmdName in @($Manifest.requires.commands)) {
            if ($cmdName -and -not (Get-Command $cmdName -ErrorAction SilentlyContinue)) {
                Write-DsLog -Level Warn -Module loader -Message "Module '$Name' prefers command '$cmdName' (not found)"
            }
        }
    }

    try {
        Import-Module -Name $entry -Force -Global -ErrorAction Stop
        Add-DsLoadedModule -Name $Name
        Write-DsLog -Level Debug -Module loader -Message "Loaded module '$Name' from $entry"
        Invoke-DsModuleHook -ModuleName $Name -Manifest $Manifest -HookName 'OnLoad'
        return $true
    }
    catch {
        Write-DsLog -Level Warn -Module loader -Message "Failed to load '$Name': $($_.Exception.Message)"
        return $false
    }
}

function Start-DsModuleLoader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HomePath
    )

    $modulesRoot = Get-DsModuleRoot -HomePath $HomePath
    $discovered = @(Find-DsModuleDirectories -ModulesRoot $modulesRoot)
    Write-DsLog -Level Info -Module loader -Message "Discovered $($discovered.Count) module(s)"

    $manifests = @{}
    $dirsByName = @{}
    foreach ($dir in $discovered) {
        $manifestPath = Join-Path $dir.FullName 'module.json'
        try {
            $raw = Read-DsModuleManifest -Path $manifestPath
            $check = Test-DsModuleManifest -Manifest $raw -DirectoryName $dir.Name
            if (-not $check.Ok) {
                Write-DsLog -Level Warn -Module loader -Message "Invalid manifest '$($dir.Name)': $($check.Errors -join '; ')"
                continue
            }
            $manifests[$dir.Name] = $check.Manifest
            $dirsByName[$dir.Name] = $dir.FullName
        }
        catch {
            Write-DsLog -Level Warn -Module loader -Message "Manifest error in '$($dir.Name)': $($_.Exception.Message)"
        }
    }

    $modulesConfig = @{}
    $cfg = Get-DsConfig
    if ($cfg.Modules -is [hashtable]) { $modulesConfig = $cfg.Modules }

    $enabled = Get-DsEnabledModuleNames -ModulesConfig $modulesConfig -Discovered $discovered
    $order = Get-DsModuleLoadOrder -ManifestsByName $manifests -EnabledNames $enabled

    Write-DsLog -Level Info -Module loader -Message "Load order: $($order -join ', ')"

    $loaded = [System.Collections.Generic.List[string]]::new()
    foreach ($name in $order) {
        $ok = Import-DsModule -Name $name -ModuleDir $dirsByName[$name] -Manifest $manifests[$name]
        if ($ok) { $loaded.Add($name) | Out-Null }
    }

    # Second pass: OnKeymap for successfully loaded modules
    foreach ($name in $loaded) {
        Invoke-DsModuleHook -ModuleName $name -Manifest $manifests[$name] -HookName 'OnKeymap'
    }

    # Ensure PSReadLine handlers exist even if a module used -SkipPsReadLine
    Sync-DsPsReadLineKeys

    Invoke-DsEvent -Name 'ModulesLoaded' -ArgumentList @(,@($loaded))

    return [pscustomobject]@{
        Discovered = $discovered.Count
        Enabled    = $enabled
        Loaded     = @($loaded)
        Order      = $order
    }
}
