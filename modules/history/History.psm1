#requires -Version 7.0
# history — historial inteligente sobre PSReadLine.

function Get-DsHistory {
    [CmdletBinding()]
    param(
        [int]$Last = 200,
        [string]$Filter
    )

    $items = @(Get-History -Count $Last -ErrorAction SilentlyContinue)
    if ($Filter) {
        $items = $items | Where-Object { $_.CommandLine -like "*$Filter*" }
    }
    $items | ForEach-Object {
        [pscustomobject]@{
            Id      = $_.Id
            Command = $_.CommandLine
            When    = $_.StartExecutionTime
        }
    }
}

function Invoke-DsHistory {
    <#
    .SYNOPSIS
      Busca en el historial (fuzzy) y re-ejecuta o inserta el comando.
    #>
    [CmdletBinding()]
    param(
        [string]$Filter,
        [switch]$InsertOnly
    )

    $entries = @(Get-DsHistory -Last 500 -Filter $Filter)
    if ($entries.Count -eq 0) {
        Write-Host 'No history matches.' -ForegroundColor Yellow
        return
    }

    # Newest first, unique by command text
    $unique = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($e in ($entries | Sort-Object Id -Descending)) {
        if ($seen.Add($e.Command)) {
            $unique.Add($e.Command) | Out-Null
        }
        if ($unique.Count -ge 100) { break }
    }

    $pick = $null
    if (Get-Command Invoke-DsFuzzy -ErrorAction SilentlyContinue) {
        $pick = Invoke-DsFuzzy -Items @($unique) -Prompt 'history'
    }
    else {
        $pick = $unique | Select-Object -First 1
    }
    if (-not $pick) { return }

    if ($InsertOnly -and (Get-Module PSReadLine -ErrorAction SilentlyContinue)) {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($pick)
        return
    }

    Write-Host "→ $pick" -ForegroundColor Green
    Invoke-Expression $pick
}

function Enable-DsHistorySearch {
    [CmdletBinding()]
    param()

    if (-not (Get-Module PSReadLine -ErrorAction SilentlyContinue)) {
        try { Import-Module PSReadLine -ErrorAction Stop } catch {
            Write-DsLog -Level Warn -Module history -Message 'PSReadLine unavailable'
            return
        }
    }

    try {
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd -ErrorAction SilentlyContinue
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward -ErrorAction SilentlyContinue
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward -ErrorAction SilentlyContinue
        # Ctrl+R style: our fuzzy history
        Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -BriefDescription 'DevShell:History' -Description 'Fuzzy history search' -ScriptBlock {
            try { Invoke-DsHistory -InsertOnly } catch {
                Write-Host "`nHistory search failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
        } -ErrorAction SilentlyContinue
        Write-DsLog -Level Debug -Module history -Message 'PSReadLine history search enabled'
    }
    catch {
        Write-DsLog -Level Warn -Module history -Message "Could not configure history keys: $($_.Exception.Message)"
    }
}

function Register-DsHistoryOnLoad {
    Enable-DsHistorySearch
    Write-DsLog -Level Debug -Module history -Message 'history ready'
}

function Register-DsHistoryKeys {
    $null = Register-DsKey -Chord 'Ctrl+Shift+H' -Module history -Description 'Fuzzy history (Invoke-DsHistory)' -Action {
        Invoke-DsHistory
    } -SkipPsReadLine
    # Ctrl+r is wired directly in Enable-DsHistorySearch for InsertOnly UX
}

Export-ModuleMember -Function @(
    'Get-DsHistory',
    'Invoke-DsHistory',
    'Enable-DsHistorySearch',
    'Register-DsHistoryOnLoad',
    'Register-DsHistoryKeys'
)
