#requires -Version 7.0
# fuzzy — selector fuzzy con fzf si existe; fallback numerado.

function Test-DsFzfAvailable {
    [CmdletBinding()]
    param()
    [bool](Get-Command fzf -ErrorAction SilentlyContinue)
}

function Invoke-DsFuzzy {
    <#
    .SYNOPSIS
      Selecciona un ítem de una lista (fzf o menú numerado).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyCollection()]
        [string[]]$Items,

        [string]$Prompt = 'select',

        [switch]$Multi
    )

    begin {
        $all = [System.Collections.Generic.List[string]]::new()
    }
    process {
        foreach ($i in $Items) {
            if ($null -ne $i -and $i -ne '') { $all.Add([string]$i) | Out-Null }
        }
    }
    end {
        if ($all.Count -eq 0) {
            Write-DsLog -Level Warn -Module fuzzy -Message 'No items to select'
            return
        }

        if (Test-DsFzfAvailable) {
            return Invoke-DsFuzzyWithFzf -Items @($all) -Prompt $Prompt -Multi:$Multi
        }
        return Invoke-DsFuzzyFallback -Items @($all) -Prompt $Prompt -Multi:$Multi
    }
}

function Invoke-DsFuzzyWithFzf {
    [CmdletBinding()]
    param(
        [string[]]$Items,
        [string]$Prompt,
        [switch]$Multi
    )

    $fzfArgs = @('--prompt', "$Prompt> ", '--height', '40%', '--reverse', '--border')
    if ($Multi) { $fzfArgs += '--multi' }

    $selected = $Items | & fzf @fzfArgs
    if ($Multi) {
        return @($selected | Where-Object { $_ })
    }
    if ($selected) { return [string]$selected }
}

function Invoke-DsFuzzyFallback {
    [CmdletBinding()]
    param(
        [string[]]$Items,
        [string]$Prompt,
        [switch]$Multi
    )

    Write-Host ''
    Write-Host $Prompt -ForegroundColor Cyan
    Write-Host ('─' * 40) -ForegroundColor DarkGray
    $max = [Math]::Min(30, $Items.Count)
    for ($i = 0; $i -lt $max; $i++) {
        Write-Host ("  {0,2}. {1}" -f ($i + 1), $Items[$i])
    }
    if ($Items.Count -gt $max) {
        Write-Host "  ... +$($Items.Count - $max) more (type partial name)" -ForegroundColor DarkGray
    }

    $hint = if ($Multi) { 'números separados por coma, o texto; vacío=cancelar' } else { 'número o texto parcial; vacío=cancelar' }
    $sel = Read-Host $hint
    if ([string]::IsNullOrWhiteSpace($sel)) { return }

    if ($Multi) {
        $parts = $sel -split '[,\s]+' | Where-Object { $_ }
        $out = [System.Collections.Generic.List[string]]::new()
        foreach ($p in $parts) {
            $hit = Resolve-DsFuzzyChoice -Items $Items -Selection $p
            if ($hit) { $out.Add($hit) | Out-Null }
        }
        return @($out)
    }

    return Resolve-DsFuzzyChoice -Items $Items -Selection $sel
}

function Resolve-DsFuzzyChoice {
    [CmdletBinding()]
    param(
        [string[]]$Items,
        [string]$Selection
    )

    if ($Selection -match '^\d+$') {
        $idx = [int]$Selection - 1
        if ($idx -ge 0 -and $idx -lt $Items.Count) { return $Items[$idx] }
        return $null
    }

    $exact = @($Items | Where-Object { $_ -eq $Selection })
    if ($exact.Count -eq 1) { return $exact[0] }

    $partial = @($Items | Where-Object { $_ -like "*$Selection*" })
    if ($partial.Count -ge 1) { return $partial[0] }
    return $null
}

function Register-DsFuzzyOnLoad {
    Write-DsLog -Level Debug -Module fuzzy -Message "fuzzy ready (fzf=$(Test-DsFzfAvailable))"
}

Export-ModuleMember -Function @(
    'Invoke-DsFuzzy',
    'Test-DsFzfAvailable',
    'Register-DsFuzzyOnLoad'
)
