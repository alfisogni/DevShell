#requires -Version 7.0
# fuzzy — fzf Catppuccin picker with preview/borders; gum/menu fallback.

function Test-DsFzfAvailable {
    [CmdletBinding()]
    param()
    [bool](Get-Command fzf -ErrorAction SilentlyContinue)
}

function Get-DsFzfColorArgs {
    [CmdletBinding()]
    param()
    # Catppuccin Mocha / Lennerk
    @(
        '--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#a6e3a1'
        '--color=fg:#cdd6f4,header:#a6e3a1,info:#89dceb,pointer:#f5e0dc'
        '--color=marker:#b4befe,fg+:#cdd6f4,prompt:#a6e3a1,hl+:#a6e3a1'
        '--color=border:#585b70,label:#89dceb'
    )
}

function Get-DsFzfBaseArgs {
    [CmdletBinding()]
    param(
        [string]$Prompt = 'select',
        [switch]$Multi,
        [string]$Preview,
        [string]$PreviewWindow = 'right:50%:wrap'
    )

    $args = [System.Collections.Generic.List[string]]::new()
    $args.Add('--ansi') | Out-Null
    $args.Add('--reverse') | Out-Null
    $args.Add('--border=rounded') | Out-Null
    $args.Add('--height=60%') | Out-Null
    $args.Add('--prompt') | Out-Null
    $args.Add(" $Prompt  ") | Out-Null
    $args.Add('--pointer') | Out-Null
    $args.Add('▶') | Out-Null
    $args.Add('--marker') | Out-Null
    $args.Add('✓') | Out-Null
    $args.Add('--info=inline') | Out-Null
    $args.Add('--padding=1,2') | Out-Null
    $args.Add('--margin=1,2') | Out-Null
    foreach ($c in Get-DsFzfColorArgs) { $args.Add($c) | Out-Null }
    if ($Multi) { $args.Add('--multi') | Out-Null }
    if ($Preview) {
        $args.Add('--preview') | Out-Null
        $args.Add($Preview) | Out-Null
        $args.Add('--preview-window') | Out-Null
        $args.Add($PreviewWindow) | Out-Null
    }
    return @($args)
}

function Invoke-DsFuzzy {
    <#
    .SYNOPSIS
      Selecciona un ítem (fzf Catppuccin + preview, o gum/menú).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyCollection()]
        [string[]]$Items,

        [string]$Prompt = 'select',

        [switch]$Multi,

        [string]$Preview,

        [string]$PreviewWindow = 'right:50%:wrap'
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
            return Invoke-DsFuzzyWithFzf -Items @($all) -Prompt $Prompt -Multi:$Multi -Preview $Preview -PreviewWindow $PreviewWindow
        }
        if (Get-Command Invoke-DsGumChoose -ErrorAction SilentlyContinue) {
            return Invoke-DsGumChoose -Items @($all) -Prompt $Prompt -Multi:$Multi
        }
        return Invoke-DsFuzzyFallback -Items @($all) -Prompt $Prompt -Multi:$Multi
    }
}

function Invoke-DsFuzzyWithFzf {
    [CmdletBinding()]
    param(
        [string[]]$Items,
        [string]$Prompt,
        [switch]$Multi,
        [string]$Preview,
        [string]$PreviewWindow
    )

    $fzfArgs = Get-DsFzfBaseArgs -Prompt $Prompt -Multi:$Multi -Preview $Preview -PreviewWindow $PreviewWindow
    $selected = $Items | & fzf @fzfArgs
    if ($Multi) {
        return @($selected | Where-Object { $_ })
    }
    if ($selected) { return [string]$selected }
}

function Invoke-DsFuzzyFile {
    <#
    .SYNOPSIS
      File picker with bat/cat preview (Catppuccin fzf).
    #>
    [CmdletBinding()]
    param(
        [string]$Root = (Get-Location).Path,
        [string]$Prompt = 'file',
        [switch]$Multi
    )

    if (-not (Test-DsFzfAvailable)) {
        Write-DsLog -Level Warn -Module fuzzy -Message 'fzf required for Invoke-DsFuzzyFile'
        return
    }

    $preview = if (Get-Command bat -ErrorAction SilentlyContinue) {
        'bat --style=numbers --color=always --line-range=:120 {}'
    }
    elseif (Get-Command Get-Content -ErrorAction SilentlyContinue) {
        'powershell -NoProfile -Command "Get-Content -LiteralPath ''{}'' -TotalCount 80"'
    }
    else { $null }

    Push-Location -LiteralPath $Root
    try {
        $finder = if (Get-Command fd -ErrorAction SilentlyContinue) {
            { fd --type f --hidden --exclude .git }
        }
        else {
            { Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Substring((Get-Location).Path.Length).TrimStart('\', '/') } }
        }
        $items = @(& $finder)
        if ($items.Count -eq 0) { return }
        return Invoke-DsFuzzy -Items $items -Prompt $Prompt -Multi:$Multi -Preview $preview
    }
    finally {
        Pop-Location
    }
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
        foreach ($part in $parts) {
            $hit = Resolve-DsFuzzyChoice -Items $Items -Selection $part
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
    # Apply Mocha fzf defaults for child processes
    if (-not $env:FZF_DEFAULT_OPTS) {
        $env:FZF_DEFAULT_OPTS = ((Get-DsFzfColorArgs) + @(
                '--border=rounded'
                '--reverse'
                '--height=60%'
                '--padding=1,2'
            )) -join ' '
    }
    Write-DsLog -Level Debug -Module fuzzy -Message "fuzzy ready (fzf=$(Test-DsFzfAvailable))"
}

Export-ModuleMember -Function @(
    'Invoke-DsFuzzy',
    'Invoke-DsFuzzyFile',
    'Test-DsFzfAvailable',
    'Get-DsFzfBaseArgs',
    'Get-DsFzfColorArgs',
    'Register-DsFuzzyOnLoad'
)
