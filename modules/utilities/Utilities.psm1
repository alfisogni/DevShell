#requires -Version 7.0
# utilities — helpers de productividad diaria (no solo desarrollo).

function Get-DsWhich {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Name
    )
    process {
        $cmd = Get-Command $Name -ErrorAction SilentlyContinue
        if (-not $cmd) {
            Write-Host "Not found: $Name" -ForegroundColor Yellow
            return
        }
        [pscustomobject]@{
            Name = $cmd.Name
            Type = $cmd.CommandType
            Path = if ($cmd.Path) { $cmd.Path } elseif ($cmd.Source) { $cmd.Source } else { $null }
            Version = try { $cmd.Version } catch { $null }
        }
    }
}

function Get-DsEnv {
    [CmdletBinding()]
    param(
        [string]$Filter
    )
    Get-ChildItem Env: |
        Where-Object { -not $Filter -or $_.Name -like "*$Filter*" -or $_.Value -like "*$Filter*" } |
        Sort-Object Name |
        Select-Object Name, Value
}

function Invoke-DsOpen {
    <#
    .SYNOPSIS
      Abre un path con el handler default del SO (explorador / app asociada).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path = (Get-Location).Path
    )
    $target = $Path
    if (Get-Command Expand-DsPath -ErrorAction SilentlyContinue) {
        $target = Expand-DsPath -Path $Path
    }
    elseif ($Path.StartsWith('~/') -or $Path -eq '~') {
        $target = Join-Path $HOME ($Path.Substring(1).TrimStart('\', '/'))
    }
    if (-not (Test-Path -LiteralPath $target)) {
        Write-DsLog -Level Warn -Module utilities -Message "Path not found: $target"
        return
    }
    Start-Process -FilePath $target
}

function Invoke-DsNote {
    <#
    .SYNOPSIS
      Append de una nota rápida a un archivo de texto diario.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
        [string[]]$Text,

        [string]$Directory
    )

    if (-not $Directory) {
        try {
            $Directory = Get-DsConfig -Path 'Utilities.NotesDir'
        }
        catch { }
        if (-not $Directory) {
            $Directory = Join-Path $HOME 'Documents\DevShellNotes'
        }
    }

    if (Get-Command Expand-DsPath -ErrorAction SilentlyContinue) {
        $Directory = Expand-DsPath -Path $Directory
    }

    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    }

    $file = Join-Path $Directory ("{0:yyyy-MM-dd}.md" -f (Get-Date))
    $line = "- {0:HH:mm} {1}" -f (Get-Date), ($Text -join ' ')
    Add-Content -LiteralPath $file -Value $line -Encoding UTF8
    Write-Host "Noted → $file" -ForegroundColor DarkGray
}

function Register-DsUtilitiesOnLoad {
    Write-DsLog -Level Debug -Module utilities -Message 'utilities ready'
}

function Register-DsUtilitiesKeys {
    # Avoid Ctrl+Shift+N (Windows Terminal: new window). Avoid Alt+* (Komorebi).
    $null = Register-DsKey -Chord 'Ctrl+Shift+J' -Module utilities -Description 'Quick note prompt' -Action {
        $t = Read-Host 'note'
        if ($t) { Invoke-DsNote $t }
    }
}

Export-ModuleMember -Function @(
    'Get-DsWhich',
    'Get-DsEnv',
    'Invoke-DsOpen',
    'Invoke-DsNote',
    'Register-DsUtilitiesOnLoad',
    'Register-DsUtilitiesKeys'
)
