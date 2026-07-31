#requires -Version 7.0
# keymap — descubrimiento de comandos y listado de atajos (Fase 2 base).
# Los chords de PSReadLine se agregan de a poco; el registro vive en el core.

function Get-DsCommandCatalog {
    [CmdletBinding()]
    param(
        [string]$Filter
    )

    $cmds = Get-Command -Name '*-Ds*', 'Ds*' -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandType -in @('Function', 'Alias', 'Cmdlet') } |
        Sort-Object Name -Unique

    if ($Filter) {
        $cmds = $cmds | Where-Object { $_.Name -like "*$Filter*" }
    }

    foreach ($c in $cmds) {
        [pscustomobject]@{
            Name        = $c.Name
            CommandType = $c.CommandType
            Source      = $c.Source
        }
    }
}

function Show-DsKeys {
    [CmdletBinding()]
    param()

    $bindings = @(Get-DsKeyBinding)
    if ($bindings.Count -eq 0) {
        Write-Host 'No hay keybindings registrados aún.' -ForegroundColor DarkGray
        Write-Host 'Los módulos registran atajos con Register-DsKey (hook OnKeymap).'
        return
    }

    Write-Host ''
    Write-Host 'Keybindings' -ForegroundColor Cyan
    Write-Host ('─' * 50)
    foreach ($b in ($bindings | Sort-Object Chord)) {
        Write-Host ("  {0,-16} {1,-12} {2}" -f $b.Chord, "[$($b.Module)]", $b.Description)
    }
    Write-Host ''
}

function Invoke-DsPalette {
    [CmdletBinding()]
    param()

    $items = @(Get-DsCommandCatalog | Select-Object -ExpandProperty Name)
    if ($items.Count -eq 0) {
        Write-Host 'No hay comandos Ds* visibles.' -ForegroundColor Yellow
        return
    }

    if (Get-Command Invoke-DsFuzzy -ErrorAction SilentlyContinue) {
        $target = Invoke-DsFuzzy -Items $items -Prompt 'command'
    }
    else {
        Write-Host 'Command palette (número o nombre parcial). Vacío = cancelar.' -ForegroundColor Cyan
        for ($i = 0; $i -lt [Math]::Min(20, $items.Count); $i++) {
            Write-Host ("  {0,2}. {1}" -f ($i + 1), $items[$i])
        }
        $sel = Read-Host 'Elegir'
        if ([string]::IsNullOrWhiteSpace($sel)) { return }
        if ($sel -match '^\d+$') {
            $idx = [int]$sel - 1
            $target = if ($idx -ge 0 -and $idx -lt $items.Count) { $items[$idx] } else { $null }
        }
        else {
            $target = $items | Where-Object { $_ -like "*$sel*" } | Select-Object -First 1
        }
    }

    if (-not $target) { return }
    Write-Host "→ $target" -ForegroundColor Green
    & $target
}

function Register-DsKeymapOnLoad {
    Write-DsLog -Level Debug -Module keymap -Message 'keymap OnLoad'
}

function Register-DsKeymapKeys {
    $null = Register-DsKey -Chord 'Ctrl+Shift+P' -Module keymap -Description 'Command palette (Invoke-DsPalette)' -Action { Invoke-DsPalette }
    $null = Register-DsKey -Chord 'Ctrl+Shift+?' -Module keymap -Description 'Show keybindings (Show-DsKeys)' -Action { Show-DsKeys }
    # PSReadLine chord wiring: Fase 2+
}

Export-ModuleMember -Function @(
    'Get-DsCommandCatalog',
    'Show-DsKeys',
    'Invoke-DsPalette',
    'Register-DsKeymapOnLoad',
    'Register-DsKeymapKeys'
)
