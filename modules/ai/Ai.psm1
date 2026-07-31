#requires -Version 7.0
# ai — capa genérica de agentes. Providers enchufables (cursor, futuros, etc.).

$script:DsAiProviders = [ordered]@{}

function Register-DsAiProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Invoke,

        [string]$Description = '',

        [scriptblock]$Detect,

        [switch]$Force
    )

    $key = $Name.ToLowerInvariant()
    if ($script:DsAiProviders.Contains($key) -and -not $Force) {
        Write-DsLog -Level Debug -Module ai -Message "Provider '$key' already registered"
        return
    }

    $script:DsAiProviders[$key] = [pscustomobject]@{
        Name        = $key
        Description = $Description
        Invoke      = $Invoke
        Detect      = $Detect
    }
    Write-DsLog -Level Debug -Module ai -Message "Registered AI provider '$key'"
}

function Get-DsAiProvider {
    [CmdletBinding()]
    param(
        [string]$Name
    )
    if ($Name) {
        $key = $Name.ToLowerInvariant()
        if ($script:DsAiProviders.Contains($key)) {
            return $script:DsAiProviders[$key]
        }
        return $null
    }
    return @($script:DsAiProviders.Values)
}

function Get-DsAiDefaultProvider {
    [CmdletBinding()]
    param()
    $configured = $null
    try { $configured = Get-DsConfig -Path 'Ai.DefaultProvider' } catch { }
    if (-not $configured) { $configured = 'cursor' }

    $key = ([string]$configured).ToLowerInvariant()
    if ($script:DsAiProviders.Contains($key)) {
        return $key
    }
    foreach ($p in $script:DsAiProviders.Values) {
        if ($p.Detect) {
            try {
                if (& $p.Detect) { return $p.Name }
            }
            catch { }
        }
    }
    if ($script:DsAiProviders.Count -gt 0) {
        return @($script:DsAiProviders.Keys)[0]
    }
    return $null
}

function Test-DsAiProvider {
    [CmdletBinding()]
    param(
        [string]$Name
    )
    $p = Get-DsAiProvider -Name $(if ($Name) { $Name } else { Get-DsAiDefaultProvider })
    if (-not $p) { return $false }
    if (-not $p.Detect) { return $true }
    try {
        return [bool](& $p.Detect)
    }
    catch {
        Write-DsLog -Level Debug -Module ai -Message "Detect $($p.Name) failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-DsAi {
    <#
    .SYNOPSIS
      One-shot AI print, or interactive Agent chat with -Chat.
    .DESCRIPTION
      Without -Chat: sends a prompt to the provider (e.g. agent -p "...").
      With -Chat: opens the provider's interactive TTY session (e.g. agent without -p).
    .EXAMPLE
      Invoke-DsAi 'explica este repo'
      dsa 'explica este repo'
    .EXAMPLE
      Invoke-DsAi -Chat
      dsa -Chat
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]]$Prompt,

        [string]$Provider,

        [hashtable]$Arguments,

        [switch]$Chat
    )

    $name = if ($Provider) { $Provider.ToLowerInvariant() } else { Get-DsAiDefaultProvider }
    $p = Get-DsAiProvider -Name $name
    if (-not $p) {
        Write-Host "No AI provider registered (wanted: $name). See modules/ai." -ForegroundColor Yellow
        return
    }

    if ($p.Detect -and -not (& $p.Detect)) {
        Write-Host "AI provider '$name' is not available on this machine." -ForegroundColor Yellow
        Write-Host "Install its CLI or set Ai.$name path in user.psd1" -ForegroundColor DarkGray
        return
    }

    if (-not $Arguments) { $Arguments = @{} }

    if ($Chat) {
        $Arguments['Chat'] = $true
        Write-Host "ai:$name → interactive Agent (Chat). Exit the agent session to return here." -ForegroundColor DarkGray
        Write-DsLog -Level Info -Module ai -Message "Invoke provider=$name mode=chat"
        & $p.Invoke -Prompt '' -Arguments $Arguments
        return
    }

    $text = ($Prompt -join ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        Write-Host "One-shot: dsa 'tu pregunta'   |   Chat: dsa -Chat   |   IDE: Invoke-DsIde" -ForegroundColor DarkGray
        $text = Read-Host 'AI prompt'
        if ([string]::IsNullOrWhiteSpace($text)) { return }
    }

    Write-DsLog -Level Info -Module ai -Message "Invoke provider=$name"
    & $p.Invoke -Prompt $text -Arguments $Arguments
}

function Invoke-DsIde {
    <#
    .SYNOPSIS
      Abre el IDE gráfico bajo demanda (no es el flujo default).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path = (Get-Location).Path
    )

    $open = $null
    try { $open = Get-DsConfig -Path 'Ai.IdeCommand' } catch { }
    if (-not $open) {
        foreach ($c in @('cursor', 'code')) {
            if (Get-Command $c -ErrorAction SilentlyContinue) { $open = $c; break }
        }
    }
    if (-not $open) {
        Write-Host 'No IDE CLI found (cursor/code). Opening folder with shell.' -ForegroundColor Yellow
        if (Get-Command Invoke-DsOpen -ErrorAction SilentlyContinue) {
            Invoke-DsOpen -Path $Path
        }
        else {
            Start-Process -FilePath $Path
        }
        return
    }

    $target = $Path
    if (Get-Command Expand-DsPath -ErrorAction SilentlyContinue) {
        $target = Expand-DsPath -Path $Path
    }
    & $open $target
}

function Register-DsAiOnLoad {
    Write-DsLog -Level Debug -Module ai -Message ("AI providers: " + ((Get-DsAiProvider | ForEach-Object Name) -join ', '))
}

function Register-DsAiKeys {
    $null = Register-DsKey -Chord 'Ctrl+Shift+A' -Module ai -Description 'Invoke AI (Invoke-DsAi)' -Action {
        Invoke-DsAi
    }
    $null = Register-DsKey -Chord 'Ctrl+Shift+I' -Module ai -Description 'Open IDE (Invoke-DsIde)' -Action {
        Invoke-DsIde
    }
}

Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'providers') -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

Export-ModuleMember -Function @(
    'Register-DsAiProvider',
    'Get-DsAiProvider',
    'Get-DsAiDefaultProvider',
    'Test-DsAiProvider',
    'Invoke-DsAi',
    'Invoke-DsIde',
    'Register-DsAiOnLoad',
    'Register-DsAiKeys'
)
