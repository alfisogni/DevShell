#requires -Version 7.0
# Keymap.ps1 — registro central + cableado opcional a PSReadLine.

$script:DsKeyBindings = [System.Collections.Generic.List[object]]::new()

function Clear-DsKeyBindings {
    [CmdletBinding()]
    param()
    $script:DsKeyBindings = [System.Collections.Generic.List[object]]::new()
}

function ConvertTo-DsPsReadLineChord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Chord
    )
    # DevShell: Ctrl+Shift+P  →  PSReadLine: Ctrl+Shift+p
    $parts = $Chord -split '\+'
    $normalized = foreach ($p in $parts) {
        $t = $p.Trim()
        if ($t.Length -eq 1 -and $t -match '[A-Za-z]') {
            $t.ToLowerInvariant()
        }
        else {
            # Keep modifiers Pascal-ish as PSReadLine expects Ctrl, Alt, Shift
            switch -Regex ($t) {
                '^(?i)ctrl$'  { 'Ctrl'; break }
                '^(?i)alt$'   { 'Alt'; break }
                '^(?i)shift$' { 'Shift'; break }
                '^(?i)win$'   { 'Win'; break }
                default       { $t }
            }
        }
    }
    return ($normalized -join '+')
}

function Register-DsKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Chord,

        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter(Mandatory)]
        [scriptblock]$Action,

        [string]$Module = 'unknown',

        [switch]$Force,

        [switch]$SkipPsReadLine
    )

    $existing = @($script:DsKeyBindings | Where-Object { $_.Chord -eq $Chord }) | Select-Object -First 1
    if ($existing -and -not $Force) {
        Write-DsLog -Level Warn -Module keymap -Message "Key conflict on '$Chord' ($Module vs $($existing.Module)). Skipping."
        return $false
    }
    if ($existing -and $Force) {
        [void]$script:DsKeyBindings.Remove($existing)
    }

    $binding = [pscustomobject]@{
        Chord       = $Chord
        Description = $Description
        Action      = $Action
        Module      = $Module
        PsChord     = (ConvertTo-DsPsReadLineChord -Chord $Chord)
    }
    $script:DsKeyBindings.Add($binding) | Out-Null

    if (-not $SkipPsReadLine) {
        Set-DsPsReadLineHandler -Binding $binding
    }
    return $true
}

function Set-DsPsReadLineHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Binding
    )

    if (-not (Get-Module PSReadLine -ErrorAction SilentlyContinue)) {
        try { Import-Module PSReadLine -ErrorAction Stop } catch {
            Write-DsLog -Level Debug -Module keymap -Message 'PSReadLine not available; chord stored only in catalog'
            return $false
        }
    }

    $psChord = $Binding.PsChord
    $chordLiteral = $Binding.Chord.Replace("'", "''")
    $desc = $Binding.Description
    $handler = [scriptblock]::Create(@"
param(`$key, `$arg)
try {
    Invoke-DsKey -Chord '$chordLiteral'
}
catch {
    Write-Host "`nDevShell key action failed: `$(`$_.Exception.Message)" -ForegroundColor Yellow
}
[Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
"@)

    try {
        Set-PSReadLineKeyHandler -Chord $psChord -BriefDescription "DevShell:$($Binding.Module)" -Description $desc -ScriptBlock $handler -ErrorAction Stop
        Write-DsLog -Level Debug -Module keymap -Message "PSReadLine bound $($Binding.Chord) → $psChord"
        return $true
    }
    catch {
        Write-DsLog -Level Warn -Module keymap -Message "Could not bind PSReadLine chord '$psChord': $($_.Exception.Message)"
        return $false
    }
}

function Sync-DsPsReadLineKeys {
    [CmdletBinding()]
    param()
    $ok = 0
    foreach ($b in @($script:DsKeyBindings)) {
        if (Set-DsPsReadLineHandler -Binding $b) { $ok++ }
    }
    Write-DsLog -Level Debug -Module keymap -Message "Synced $ok/$($script:DsKeyBindings.Count) PSReadLine handlers"
}

function Get-DsKeyBinding {
    [CmdletBinding()]
    param(
        [string]$Chord
    )
    if ($Chord) {
        return @($script:DsKeyBindings | Where-Object { $_.Chord -eq $Chord })
    }
    return @($script:DsKeyBindings)
}

function Invoke-DsKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Chord
    )
    $binding = Get-DsKeyBinding -Chord $Chord | Select-Object -First 1
    if (-not $binding) {
        Write-DsLog -Level Warn -Module keymap -Message "No binding for '$Chord'"
        return
    }
    & $binding.Action
}
