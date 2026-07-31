#requires -Version 7.0

function Invoke-DsDoctor {
    [CmdletBinding()]
    param(
        [switch]$Quiet,
        [switch]$PassThru
    )

    $results = [System.Collections.Generic.List[object]]::new()

    function Add-Check([string]$Name, [bool]$Ok, [string]$Detail) {
        $results.Add([pscustomobject]@{ Name = $Name; Ok = $Ok; Detail = $Detail }) | Out-Null
    }

    Add-Check 'PowerShell' ($PSVersionTable.PSVersion.Major -ge 7) "v$($PSVersionTable.PSVersion)"

    try {
        $homePath = (Get-DsContext).Home
        Add-Check 'DevShell Home' (Test-Path -LiteralPath $homePath) $homePath
        $themeName = (Get-DsConfig -Path 'Theme')
        if (-not $themeName) { $themeName = 'default' }
        $themePath = Join-Path $homePath "themes/$themeName/theme.psd1"
        Add-Check 'Theme pack' (Test-Path -LiteralPath $themePath) $themePath

        $loaded = @((Get-DsContext).LoadedModules)
        Add-Check 'Modules loaded' ($loaded.Count -gt 0) ($loaded -join ', ')
        Add-Check 'Module ai' ($loaded -contains 'ai') $(if ($loaded -contains 'ai') { 'loaded' } else { 'not loaded' })
    }
    catch {
        Add-Check 'Context' $false $_.Exception.Message
    }

    # Tools via tools module if present
    $toolNames = @('git', 'fzf', 'rg', 'pwsh')
    if (Get-Command Get-DsTool -ErrorAction SilentlyContinue) {
        foreach ($t in Get-DsTool) {
            Add-Check "Tool:$($t.Name)" $t.Available $(if ($t.Available) { $t.Path } else { 'missing (optional)' })
        }
    }
    else {
        foreach ($name in $toolNames) {
            $cmd = Get-Command $name -ErrorAction SilentlyContinue
            Add-Check "Tool:$name" ([bool]$cmd) $(if ($cmd) { $cmd.Source } else { 'missing (optional)' })
        }
    }

    # AI providers
    if (Get-Command Get-DsAiProvider -ErrorAction SilentlyContinue) {
        $default = Get-DsAiDefaultProvider
        Add-Check 'AI default' ([bool]$default) $(if ($default) { $default } else { 'none' })
        foreach ($p in Get-DsAiProvider) {
            $ok = $true
            if ($p.Detect) {
                try { $ok = [bool](& $p.Detect) } catch { $ok = $false }
            }
            Add-Check "AI:$($p.Name)" $ok $(if ($ok) { 'available' } else { 'CLI not found' })
        }
    }
    else {
        Add-Check 'AI module' $false 'not loaded'
    }

    # Knowledge Engine
    if (Get-Command Get-DsKnowledgeProvider -ErrorAction SilentlyContinue) {
        try {
            $kroot = Get-DsKnowledgeRoot
            Add-Check 'Knowledge root' ([bool]$kroot) $kroot
        }
        catch {
            Add-Check 'Knowledge root' $false $_.Exception.Message
        }
        foreach ($p in Get-DsKnowledgeProvider) {
            $det = $true
            if ($p.Detect) {
                try { $det = [bool](& $p.Detect) } catch { $det = $false }
            }
            Add-Check "Knowledge:$($p.Name)" $det $(if ($det) { "priority $($p.Priority)" } else { 'not detected' })
        }
    }
    else {
        Add-Check 'Knowledge module' $false 'not loaded'
    }

    # Keybindings
    if (Get-Command Get-DsKeyBinding -ErrorAction SilentlyContinue) {
        $keys = @(Get-DsKeyBinding)
        Add-Check 'Keybindings' ($keys.Count -gt 0) "$($keys.Count) registered"
    }

    # Aliases
    if (Get-Command Get-DsAlias -ErrorAction SilentlyContinue) {
        foreach ($a in @(Get-DsAlias)) {
            $detail = if ($a.Ok) { $a.Target } else { "$($a.Status): $($a.Detail)" }
            Add-Check "Alias:$($a.Name)" ([bool]$a.Ok) $detail
        }
    }

    try {
        $map = @{}
        foreach ($r in $results) {
            if ($r.Name -like 'Tool:*') {
                $map[$r.Name.Substring(5)] = $r.Ok
            }
        }
        if ($map.Count -gt 0) {
            Set-DsContext -Properties @{ Tools = $map }
        }
    }
    catch { }

    if (-not $Quiet) {
        Write-Host ''
        Write-Host 'DevShell doctor' -ForegroundColor Cyan
        Write-Host ('─' * 40)
        foreach ($r in $results) {
            $mark = if ($r.Ok) { 'OK' } else { '!!' }
            $color = if ($r.Ok) { 'Green' } else { 'Yellow' }
            Write-Host ("[{0}] {1,-16} {2}" -f $mark, $r.Name, $r.Detail) -ForegroundColor $color
        }
        Write-Host ''
        Write-Host 'Tip: Get-DsHelp | Show-DsKeys | Get-DsAiProvider | Get-DsTool' -ForegroundColor DarkGray
    }

    if ($Quiet -or $PassThru) {
        return $results
    }
}

function Register-DsDoctorOnLoad {
    Write-DsLog -Level Debug -Module doctor -Message 'doctor OnLoad'
}

Export-ModuleMember -Function Invoke-DsDoctor, Register-DsDoctorOnLoad
